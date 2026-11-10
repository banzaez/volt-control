import Foundation
import IOKit
import IOKit.ps
import SwiftUI

@MainActor
@Observable
public final class BatteryMonitor {
    public static let shared = BatteryMonitor()

    public private(set) var info: BatteryInfo = .initial
    public private(set) var isMonitoring: Bool = false

    private var timer: Timer?
    private var powerSourceRunLoopSource: CFRunLoopSource?
    private var lastNotifiedLevel: Int?
    private var lastNotifiedLowBattery: Bool = false
    private var lastNotifiedOverheatTime: Date?
    private var lastDisconnectDate: Date? = Date().addingTimeInterval(-7800)
    private let settings = AppSettings.shared
    private let smc = SMCController.shared
    private let notifications = NotificationService.shared

    private init() {}

    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        registerPowerSourceNotifications()
        fetchSnapshot()
        rescheduleTimer()
    }

    public func rescheduleTimer() {
        timer?.invalidate()
        let interval = max(1.0, settings.pollingIntervalSeconds)
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchSnapshot()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        self.timer = newTimer
    }

    public func stopMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
        if let src = powerSourceRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            powerSourceRunLoopSource = nil
        }
    }

    private func registerPowerSourceNotifications() {
        guard powerSourceRunLoopSource == nil else { return }
        let callback: IOPowerSourceCallbackType = { _ in
            Task { @MainActor in
                BatteryMonitor.shared.fetchSnapshot()
            }
        }
        if let source = IOPSNotificationCreateRunLoopSource(callback, nil)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            self.powerSourceRunLoopSource = source
        }
    }

    /// Safely converts an IOKit CFNumber (which may store negative values as 64-bit unsigned two's complement) into signed Int64
    private nonisolated func signedInt64(_ anyVal: Any?) -> Int64 {
        guard let num = anyVal as? NSNumber else { return 0 }
        return Int64(bitPattern: num.uint64Value)
    }

    /// Converts signed milliwatts from IOKit dictionary entry to Watts
    private nonisolated func signedMilliwattsToWatts(_ anyVal: Any?) -> Double {
        Double(signedInt64(anyVal)) / 1000.0
    }

    private func computeTimeRemainingMinutes(
        isAC: Bool,
        isCharging: Bool,
        currentLevel: Int,
        battDict: [String: Any],
        fcc: Int,
        remCap: Int,
        amps: Int,
        volts: Double,
        battWatts: Double,
        sysWatts: Double
    ) -> Int? {
        if !isAC {
            // 1. Работа от батареи (разрядка)
            let iokitVal = (battDict["AvgTimeToEmpty"] as? Int)
                ?? (battDict["TimeRemaining"] as? Int)
                ?? (battDict["InstantTimeToEmpty"] as? Int)

            if let val = iokitVal, val > 0, val < 65535 {
                return val
            }

            // Физический расчет времени разряда при задержке IOKit (65535 / nil)
            let dischargeAmps = abs(amps) > 50 ? abs(amps) : Int((sysWatts / max(1.0, volts)) * 1000.0)
            if dischargeAmps > 50 && remCap > 0 {
                let estimatedMinutes = Int((Double(remCap) / Double(dischargeAmps)) * 60.0)
                if estimatedMinutes > 0 && estimatedMinutes < 2400 {
                    return estimatedMinutes
                }
            }
            return nil
        }

        // 2. Подключено к сети, но зарядка не идет (пауза / 100%)
        guard isCharging else {
            return nil
        }

        // 3. Зарядка
        let isFullTarget = settings.isTopUpActive || settings.chargeLimit >= 100
        if isFullTarget {
            // Расчет до 100%
            let iokitVal = (battDict["AvgTimeToFull"] as? Int)
                ?? (battDict["TimeRemaining"] as? Int)

            if let val = iokitVal, val > 0, val < 65535 {
                return val
            }

            let chargeAmps = amps > 50 ? amps : Int((battWatts / max(1.0, volts)) * 1000.0)
            let neededMah = max(0, fcc - remCap)
            if chargeAmps > 50 && neededMah > 0 {
                return max(1, Int((Double(neededMah) / Double(chargeAmps)) * 60.0))
            }
            return nil
        } else {
            // Расчет до пользовательского лимита (например, 80%)
            let limit = settings.chargeLimit
            if currentLevel >= limit {
                return 0
            }

            let targetMah = Double(fcc) * (Double(limit) / 100.0)
            let neededMah = max(0.0, targetMah - Double(remCap))
            let chargeAmps = amps > 50 ? amps : Int((battWatts / max(1.0, volts)) * 1000.0)

            if chargeAmps > 50 && neededMah > 0 {
                let minutesToLimit = max(1, Int((neededMah / Double(chargeAmps)) * 60.0))
                return minutesToLimit
            } else if let iokitVal = (battDict["AvgTimeToFull"] as? Int) ?? (battDict["TimeRemaining"] as? Int),
                      iokitVal > 0, iokitVal < 65535 {
                let remainingPercentTo100 = max(1, 100 - currentLevel)
                let neededPercentToLimit = max(1, limit - currentLevel)
                return max(1, (iokitVal * neededPercentToLimit) / remainingPercentTo100)
            }
            return nil
        }
    }

    public func fetchSnapshot() {
        var newInfo = BatteryInfo()

        // 1. AppleSmartBattery Registry Entry
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        var battDict: [String: Any] = [:]
        if service != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
               let dict = props?.takeRetainedValue() as? [String: Any] {
                battDict = dict
            }
            IOObjectRelease(service)
        }

        // 2. AppleSmartBatteryPack Registry Entry (for accurate pack temperature)
        let packService = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBatteryPack"))
        var packDict: [String: Any] = [:]
        if packService != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(packService, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
               let dict = props?.takeRetainedValue() as? [String: Any] {
                packDict = dict
            }
            IOObjectRelease(packService)
        }

        // 3. IOPSCopyPowerSourcesInfo for instantaneous AC / charging state
        var iopsACConnected = false
        var iopsIsCharging = false
        if let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] {
            for ps in list {
                if let desc = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any] {
                    if let powerState = desc[kIOPSPowerSourceStateKey as String] as? String,
                       powerState == (kIOPSACPowerValue as String) {
                        iopsACConnected = true
                    }
                    if let chg = desc[kIOPSIsChargingKey as String] as? Bool, chg {
                        iopsIsCharging = true
                    }
                }
            }
        }

        let level = battDict["CurrentCapacity"] as? Int ?? 0
        let bData = battDict["BatteryData"] as? [String: Any] ?? [:]
        let pDist = battDict["PowerDistribution"] as? [String: Any] ?? [:]
        let ptd = battDict["PowerTelemetryData"] as? [String: Any] ?? [:]
        let packBData = packDict["BatteryData"] as? [String: Any] ?? [:]

        // Signed telemetry values from PowerTelemetryData & BatteryData (in mW -> W)
        let ptdSystemPowerInWatts = max(0.0, signedMilliwattsToWatts(ptd["SystemPowerIn"]))
        let ptdSystemLoadWatts = max(0.0, signedMilliwattsToWatts(ptd["SystemLoad"]))
        let ptdBattWatts = signedMilliwattsToWatts(ptd["BatteryPower"])
        let bDataBattWatts = signedMilliwattsToWatts(bData["BatteryPower"])
        let ipdInputWatts = max(0.0, signedMilliwattsToWatts(pDist["IPDInputPower"]))

        // Primary real-time SMC float sensors (exact keys used by BatFiHelper):
        // SBAP = Smart Battery Average Power (+W when discharging on battery, -W when charging into battery)
        // PDTR = DC-In Adapter Total Power (+W from charger)
        // PSTR = System Total Power
        let smcSBAP = smc.readFloat(key: "SBAP")
        let smcPDTR = smc.readFloat(key: "PDTR")
        let smcPSTR = smc.readFloat(key: "PSTR")

        let rawPDTR = max(0.0, (smcPDTR ?? 0.0) < 0.05 ? 0.0 : (smcPDTR ?? 0.0))
        let regExternalConnected = battDict["ExternalConnected"] as? Bool ?? false
        let isAC = regExternalConnected || iopsACConnected || rawPDTR > 0.5 || ptdSystemPowerInWatts > 0.5

        let adapterWatts: Double
        let systemWatts: Double
        let battWatts: Double

        if let sbap = smcSBAP, smcPDTR != nil {
            // Exact hardware power balance from SMC:
            // When on battery: pdtr = 0, sbap > 0 (e.g. +10.2W) -> system = 10.2W, batt = -10.2W
            // When charging on AC: pdtr > 0 (e.g. +35.0W), sbap < 0 (e.g. -22.0W) -> system = 35.0 - 22.0 = 13.0W, batt = +22.0W
            // When on AC paused/full: pdtr > 0 (e.g. +11.5W), sbap ~ 0 -> system = 11.5W, batt = 0.0W
            let cleanSBAP = abs(sbap) < 0.03 ? 0.0 : sbap
            let cleanPDTR = isAC ? max(rawPDTR, ptdSystemPowerInWatts, ipdInputWatts) : 0.0

            adapterWatts = cleanPDTR
            battWatts = -cleanSBAP

            let computedSys = cleanPDTR + cleanSBAP
            if computedSys > 0.2 {
                systemWatts = computedSys
            } else if let pstr = smcPSTR, pstr > 0.2 {
                systemWatts = pstr
            } else if ptdSystemLoadWatts > 0.2 {
                systemWatts = ptdSystemLoadWatts
            } else {
                systemWatts = max(0.5, abs(cleanSBAP))
            }
        } else {
            // Fallback to signed IOKit PowerTelemetryData
            if isAC {
                adapterWatts = max(rawPDTR, ptdSystemPowerInWatts, ipdInputWatts)
                battWatts = abs(ptdBattWatts) > 0.05 ? ptdBattWatts : bDataBattWatts
                if ptdSystemLoadWatts > 0.2 {
                    systemWatts = ptdSystemLoadWatts
                } else if let pstr = smcPSTR, pstr > 0.2 {
                    systemWatts = pstr
                } else {
                    systemWatts = max(0.5, adapterWatts - max(0.0, battWatts))
                }
            } else {
                adapterWatts = 0.0
                let discharge = max(abs(ptdBattWatts), abs(bDataBattWatts), ptdSystemLoadWatts, smcPSTR ?? 0.5)
                systemWatts = max(0.3, discharge)
                battWatts = -systemWatts
            }
        }

        let regIsCharging = battDict["IsCharging"] as? Bool ?? false
        let isChg = isAC && (regIsCharging || iopsIsCharging || battWatts > 0.25)

        // Temperature (pack temperature in hundredths of a degree Celsius, fallback to AppleSmartBattery Temperature)
        let rawPackTemp = (packBData["Temperature"] as? NSNumber)?.doubleValue ?? 0.0
        let rawBattTemp = (battDict["Temperature"] as? NSNumber)?.doubleValue ?? 0.0
        let tempCelsius: Double
        if rawPackTemp > 100 {
            tempCelsius = rawPackTemp / 100.0
        } else if rawBattTemp > 100 {
            tempCelsius = rawBattTemp / 100.0
        } else {
            tempCelsius = 28.0
        }

        // Capacities
        let fcc = (battDict["AppleRawMaxCapacity"] as? NSNumber)?.intValue
            ?? (bData["AppleRawMaxCapacity"] as? NSNumber)?.intValue
            ?? (bData["FullChargeCapacity"] as? NSNumber)?.intValue ?? 0
        let dc = (battDict["DesignCapacity"] as? NSNumber)?.intValue
            ?? (bData["DesignCapacity"] as? NSNumber)?.intValue ?? 0
        let remCap = (battDict["AppleRawCurrentCapacity"] as? NSNumber)?.intValue
            ?? (bData["RemainingCapacity"] as? NSNumber)?.intValue ?? 0

        let cycles = battDict["CycleCount"] as? Int
            ?? (bData["CycleCount"] as? NSNumber)?.intValue ?? 0
        let rawVolt = (battDict["Voltage"] as? NSNumber)?.doubleValue
            ?? (bData["Voltage"] as? NSNumber)?.doubleValue ?? 0.0
        let volts = rawVolt / 1000.0
        let amps = Int(signedInt64(battDict["Amperage"] ?? battDict["InstantAmperage"]))
        let fullyCharged = (battDict["FullyCharged"] as? Bool ?? false) || (level >= 100 && !isChg)

        let timeRemaining = computeTimeRemainingMinutes(
            isAC: isAC,
            isCharging: isChg,
            currentLevel: level,
            battDict: battDict,
            fcc: fcc,
            remCap: remCap,
            amps: amps,
            volts: volts,
            battWatts: battWatts,
            sysWatts: systemWatts
        )

        newInfo.currentPercentage = level
        newInfo.isCharging = isChg
        newInfo.isACConnected = isAC
        newInfo.isFullyCharged = fullyCharged
        newInfo.batteryPowerWatts = battWatts
        newInfo.adapterPowerWatts = adapterWatts
        newInfo.systemPowerWatts = systemWatts
        newInfo.voltageVolts = volts
        newInfo.amperageMilliAmps = amps
        newInfo.temperatureCelsius = tempCelsius
        newInfo.cycleCount = cycles
        newInfo.currentMaxCapacityMah = fcc
        newInfo.designCapacityMah = dc
        newInfo.remainingCapacityMah = remCap
        newInfo.timeRemainingMinutes = timeRemaining
        newInfo.isTopUpActive = settings.isTopUpActive
        newInfo.chargeLimit = settings.chargeLimit

        if isAC {
            lastDisconnectDate = nil
            newInfo.elapsedTimeSeconds = 0
            lastNotifiedLowBattery = false
        } else {
            if lastDisconnectDate == nil {
                lastDisconnectDate = Date()
            }
            newInfo.elapsedTimeSeconds = Int(Date().timeIntervalSince(lastDisconnectDate ?? Date()))

            if settings.notifyOnLowBattery && level <= settings.lowBatteryThreshold && !lastNotifiedLowBattery {
                notifications.notifyLowBattery(level: level)
                lastNotifiedLowBattery = true
            }
        }

        evaluateChargeControl(info: &newInfo)

        self.info = newInfo
        MenuBarController.shared.updateMenuBar(with: newInfo)
    }

    private func evaluateChargeControl(info: inout BatteryInfo) {
        guard info.isACConnected else {
            info.isChargingInhibited = false
            info.requiresPrivilegedHelper = false
            return
        }

        let isPrivileged = smc.isPrivileged
        let wantsInhibit = settings.isChargingPaused || (info.currentPercentage >= settings.chargeLimit && !settings.isTopUpActive)
        info.requiresPrivilegedHelper = wantsInhibit && !isPrivileged

        // 1. Temperature Protection
        if settings.tempProtectionEnabled && info.temperatureCelsius >= settings.maxAllowedTempCelsius {
            let ok = smc.pauseCharging()
            info.isChargingInhibited = ok || !isPrivileged
            if info.isChargingInhibited {
                info.isCharging = false
            }

            if settings.notifyOnOverheat {
                let now = Date()
                if lastNotifiedOverheatTime == nil || now.timeIntervalSince(lastNotifiedOverheatTime!) > 1800 {
                    notifications.notifyOverheating(temperature: info.temperatureCelsius)
                    lastNotifiedOverheatTime = now
                }
            }
            return
        }

        // 2. Manual Pause Mode ("Работать от батареи" / Force Discharge)
        if settings.isChargingPaused {
            let ok = smc.forceDischarge()
            info.isChargingInhibited = ok || !isPrivileged
            if info.isChargingInhibited {
                info.isCharging = false
            }
            return
        }

        // 3. Top Up Mode (Charge to 100%)
        if settings.isTopUpActive {
            if info.currentPercentage >= 100 || info.isFullyCharged {
                if settings.autoResetTopUp {
                    settings.isTopUpActive = false
                    if settings.notifyOnFull {
                        notifications.notifyTopUpCompleted()
                    }
                    _ = smc.pauseCharging()
                    info.isChargingInhibited = true
                    info.isCharging = false
                    return
                }
            } else {
                _ = smc.resumeCharging()
                info.isChargingInhibited = false
                return
            }
        }

        // 4. Target Charge Limit
        let limit = settings.chargeLimit
        if info.currentPercentage >= limit {
            _ = smc.pauseCharging()
            info.isChargingInhibited = true
            info.isCharging = false

            if settings.notifyOnLimitReached && lastNotifiedLevel != limit {
                notifications.notifyLimitReached(level: info.currentPercentage, target: limit)
                lastNotifiedLevel = limit
            }
        } else {
            if settings.sailingModeEnabled {
                let threshold = limit - settings.sailingDelta
                if info.currentPercentage <= threshold {
                    _ = smc.setHardwareChargeLimit(percentage: limit)
                    info.isChargingInhibited = false
                    lastNotifiedLevel = nil
                }
            } else {
                _ = smc.setHardwareChargeLimit(percentage: limit)
                info.isChargingInhibited = false
                lastNotifiedLevel = nil
            }
        }
    }

    // MARK: - User Intent Actions
    public func toggleTopUp() {
        settings.isTopUpActive.toggle()
        if settings.isTopUpActive {
            settings.isChargingPaused = false
            if !smc.isPrivileged {
                _ = smc.installPrivilegedHelper()
            }
            _ = smc.resumeCharging()
        }
        fetchSnapshot()
    }

    public func setQuickLimit(_ limit: Int) {
        settings.chargeLimit = limit
        settings.isTopUpActive = false
        if !smc.isPrivileged {
            _ = smc.installPrivilegedHelper()
        }
        fetchSnapshot()
    }

    public func togglePause() {
        settings.isChargingPaused.toggle()
        if settings.isChargingPaused {
            settings.isTopUpActive = false
            if !smc.isPrivileged {
                _ = smc.installPrivilegedHelper()
            }
            _ = smc.forceDischarge()
        } else {
            _ = smc.setHardwareChargeLimit(percentage: settings.chargeLimit)
        }
        fetchSnapshot()
    }
}
