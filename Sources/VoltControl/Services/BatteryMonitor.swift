import Foundation
import IOKit
import SwiftUI

@MainActor
@Observable
public final class BatteryMonitor {
    public static let shared = BatteryMonitor()

    public private(set) var info: BatteryInfo = .initial
    public private(set) var isMonitoring: Bool = false

    private var timer: Timer?
    private var lastNotifiedLevel: Int?
    private var lastNotifiedOverheatTime: Date?
    private var lastDisconnectDate: Date? = Date().addingTimeInterval(-7800)
    private let settings = AppSettings.shared
    private let smc = SMCController.shared
    private let notifications = NotificationService.shared

    private init() {
        startMonitoring()
    }

    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        fetchSnapshot()

        DispatchQueue.main.async { [weak self] in
            self?.timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.fetchSnapshot()
                }
            }
        }
    }

    public func stopMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
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

        // 2. AppleSmartBatteryPack Registry Entry (for accurate temperature)
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

        let isAC = battDict["ExternalConnected"] as? Bool ?? false
        let isChg = battDict["IsCharging"] as? Bool ?? false
        let level = battDict["CurrentCapacity"] as? Int ?? 0
        let bData = battDict["BatteryData"] as? [String: Any] ?? [:]
        let pDist = battDict["PowerDistribution"] as? [String: Any] ?? [:]
        let ptd = battDict["PowerTelemetryData"] as? [String: Any] ?? [:]
        let packBData = packDict["BatteryData"] as? [String: Any] ?? [:]

        // Telemetry values from PowerTelemetryData (in mW)
        let ptdSystemPowerInWatts = ((ptd["SystemPowerIn"] as? NSNumber)?.doubleValue ?? 0.0) / 1000.0
        let ptdSystemLoadWatts = ((ptd["SystemLoad"] as? NSNumber)?.doubleValue ?? 0.0) / 1000.0
        let ptdBattWatts = ((ptd["BatteryPower"] as? NSNumber)?.doubleValue ?? 0.0) / 1000.0

        // Gas gauge BatteryPower (in mW)
        let bDataBattWatts = ((bData["BatteryPower"] as? NSNumber)?.doubleValue ?? 0.0) / 1000.0
        let ipdInputWatts = ((pDist["IPDInputPower"] as? NSNumber)?.doubleValue ?? 0.0) / 1000.0

        // Real-time SMC float sensors (PSTR = System Load, PDTR = DC-In Adapter Power)
        let smcAdapterWatts = smc.readFloat(key: "PDTR")
        let smcSystemWatts = smc.readFloat(key: "PSTR")

        let adapterWatts: Double
        let systemWatts: Double
        let battWatts: Double

        if isAC {
            // 1. Adapter Power Input
            if let pdtr = smcAdapterWatts, pdtr > 0.2 {
                adapterWatts = pdtr
            } else if ptdSystemPowerInWatts > 0.2 {
                adapterWatts = ptdSystemPowerInWatts
            } else {
                adapterWatts = ipdInputWatts
            }

            // 2. Mac System Power Consumption
            if let pstr = smcSystemWatts, pstr > 0.2 {
                systemWatts = pstr
            } else if ptdSystemLoadWatts > 0.2 {
                systemWatts = ptdSystemLoadWatts
            } else {
                systemWatts = max(0.5, adapterWatts - max(0, bDataBattWatts))
            }

            // 3. Power going into (or out of) Battery
            if isChg {
                if adapterWatts > systemWatts + 0.1 {
                    battWatts = adapterWatts - systemWatts
                } else if ptdBattWatts > 0.1 {
                    battWatts = ptdBattWatts
                } else {
                    battWatts = max(0.1, bDataBattWatts)
                }
            } else {
                if ptdBattWatts < -0.2 {
                    battWatts = ptdBattWatts
                } else {
                    battWatts = 0.0
                }
            }
        } else {
            adapterWatts = 0.0
            if let pstr = smcSystemWatts, pstr > 0.2 {
                systemWatts = pstr
                battWatts = -pstr
            } else if abs(bDataBattWatts) > 0.1 {
                systemWatts = abs(bDataBattWatts)
                battWatts = -abs(bDataBattWatts)
            } else {
                systemWatts = max(0.5, ptdSystemLoadWatts)
                battWatts = -systemWatts
            }
        }

        // Temperature (pack temperature in hundredths of a degree Celsius)
        let rawTemp = (packBData["Temperature"] as? NSNumber)?.doubleValue ?? 0.0
        let tempCelsius = rawTemp > 0 ? (rawTemp / 100.0) : 25.0

        // Capacities
        let fcc = (bData["AppleRawMaxCapacity"] as? NSNumber)?.intValue ?? 0
        let dc = (bData["DesignCapacity"] as? NSNumber)?.intValue ?? 0
        let remCap = (bData["RemainingCapacity"] as? NSNumber)?.intValue ?? 0

        let cycles = battDict["CycleCount"] as? Int ?? 0
        let rawVolt = (battDict["Voltage"] as? NSNumber)?.doubleValue ?? 0.0
        let volts = rawVolt / 1000.0
        let amps = (battDict["Amperage"] as? NSNumber)?.intValue ?? 0
        let timeRemaining = battDict["TimeRemaining"] as? Int
        let fullyCharged = battDict["FullyCharged"] as? Bool ?? (level >= 100)

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
        } else {
            if lastDisconnectDate == nil {
                lastDisconnectDate = Date()
            }
            newInfo.elapsedTimeSeconds = Int(Date().timeIntervalSince(lastDisconnectDate ?? Date()))
        }

        evaluateChargeControl(info: &newInfo)

        DispatchQueue.main.async {
            self.info = newInfo
        }
    }

    private func evaluateChargeControl(info: inout BatteryInfo) {
        guard info.isACConnected else {
            info.isChargingInhibited = false
            return
        }

        // 1. Temperature Protection
        if settings.tempProtectionEnabled && info.temperatureCelsius >= settings.maxAllowedTempCelsius {
            info.isChargingInhibited = true
            smc.setChargeInhibited(true)

            if settings.notifyOnOverheat {
                let now = Date()
                if lastNotifiedOverheatTime == nil || now.timeIntervalSince(lastNotifiedOverheatTime!) > 1800 {
                    notifications.notifyOverheating(temperature: info.temperatureCelsius)
                    lastNotifiedOverheatTime = now
                }
            }
            return
        }

        // 2. Manual Pause Mode
        if settings.isChargingPaused {
            info.isChargingInhibited = true
            smc.setChargeInhibited(true)
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
                    info.isChargingInhibited = true
                    smc.setChargeInhibited(true)
                    return
                }
            } else {
                info.isChargingInhibited = false
                smc.setChargeInhibited(false)
                return
            }
        }

        // 4. Target Charge Limit
        let limit = settings.chargeLimit
        if info.currentPercentage >= limit {
            info.isChargingInhibited = true
            smc.setChargeInhibited(true)

            if settings.notifyOnLimitReached && lastNotifiedLevel != limit {
                notifications.notifyLimitReached(level: info.currentPercentage, target: limit)
                lastNotifiedLevel = limit
            }
        } else {
            if settings.sailingModeEnabled {
                let threshold = limit - settings.sailingDelta
                if info.currentPercentage <= threshold {
                    info.isChargingInhibited = false
                    smc.setChargeInhibited(false)
                    lastNotifiedLevel = nil
                }
            } else {
                info.isChargingInhibited = false
                smc.setChargeInhibited(false)
                lastNotifiedLevel = nil
            }
        }
    }

    // MARK: - User Intent Actions
    public func toggleTopUp() {
        settings.isTopUpActive.toggle()
        if settings.isTopUpActive {
            settings.isChargingPaused = false
            smc.setChargeInhibited(false)
        }
        fetchSnapshot()
    }

    public func setQuickLimit(_ limit: Int) {
        settings.chargeLimit = limit
        settings.isTopUpActive = false
        fetchSnapshot()
    }

    public func togglePause() {
        settings.isChargingPaused.toggle()
        if settings.isChargingPaused {
            settings.isTopUpActive = false
            smc.setChargeInhibited(true)
        } else {
            smc.setChargeInhibited(false)
        }
        fetchSnapshot()
    }
}
