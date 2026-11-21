import Foundation
import IOKit
import IOKit.ps
import SwiftUI
import VoltCore

@MainActor
@Observable
public final class BatteryMonitor {
    public static let shared = BatteryMonitor()

    public private(set) var info: BatteryInfo = .initial
    public private(set) var isMonitoring: Bool = false

    @ObservationIgnored public var onUpdate: ((BatteryInfo) -> Void)?

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var powerSourceRunLoopSource: CFRunLoopSource?
    @ObservationIgnored private var lastNotifiedLimit: Int?
    @ObservationIgnored private var lastNotifiedLowBattery: Bool = false
    @ObservationIgnored private var lastNotifiedOverheatTime: Date?
    @ObservationIgnored private var lastDisconnectDate: Date? = nil
    @ObservationIgnored private var lastSystemLimitCheck: Date = .distantPast
    @ObservationIgnored private var isFetchingSystemLimit: Bool = false
    @ObservationIgnored private var cachedSystemLimit: Int? = nil
    @ObservationIgnored private var previousPolicyMode: ChargeMode? = nil
    @ObservationIgnored private var isOverheatLatched: Bool = false

    @ObservationIgnored private let settings = AppSettings.shared
    @ObservationIgnored private let sensors = SMCSensors.shared
    @ObservationIgnored private let controller = ChargeController.shared
    @ObservationIgnored private let notifications = NotificationService.shared

    private init() {}

    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        registerPowerSourceNotifications()
        refreshSystemChargeLimitIfNeeded()
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

    public func fetchSnapshot() {
        refreshSystemChargeLimitIfNeeded()

        let battDict = readIORegistryDictionary(serviceName: "AppleSmartBattery")
        let packDict = readIORegistryDictionary(serviceName: "AppleSmartBatteryPack")
        let iops = readIOPSSnapshot()
        let sensorReadings = sensors.readPowerAndTemp()

        let effectiveLimit = min(settings.chargeLimit, cachedSystemLimit ?? 100)
        let reading = BatteryTelemetryParser.parse(
            battDict: battDict,
            packDict: packDict,
            iops: iops,
            sensors: sensorReadings,
            effectiveChargeLimit: effectiveLimit,
            isTopUpActive: settings.isTopUpActive
        )

        var newInfo = BatteryInfo()
        newInfo.currentPercentage = reading.currentPercentage
        newInfo.isCharging = reading.isCharging
        newInfo.isACConnected = reading.isACConnected
        newInfo.isFullyCharged = reading.isFullyCharged
        newInfo.batteryPowerWatts = reading.batteryPowerWatts
        newInfo.adapterPowerWatts = reading.adapterPowerWatts
        newInfo.systemPowerWatts = reading.systemPowerWatts
        newInfo.voltageVolts = reading.voltageVolts
        newInfo.amperageMilliAmps = reading.amperageMilliAmps
        newInfo.temperatureCelsius = reading.temperatureCelsius
        newInfo.cycleCount = reading.cycleCount
        newInfo.currentMaxCapacityMah = reading.currentMaxCapacityMah
        newInfo.designCapacityMah = reading.designCapacityMah
        newInfo.remainingCapacityMah = reading.remainingCapacityMah
        newInfo.timeRemainingMinutes = reading.timeRemainingMinutes
        newInfo.isTopUpActive = settings.isTopUpActive
        newInfo.appChargeLimit = settings.chargeLimit
        newInfo.systemChargeLimit = cachedSystemLimit

        if reading.isACConnected {
            lastDisconnectDate = nil
            newInfo.elapsedTimeSeconds = 0
            lastNotifiedLowBattery = false
        } else {
            if lastDisconnectDate == nil {
                lastDisconnectDate = Date()
            }
            newInfo.elapsedTimeSeconds = Int(Date().timeIntervalSince(lastDisconnectDate ?? Date()))

            if settings.notifyOnLowBattery && reading.currentPercentage <= settings.lowBatteryThreshold && !lastNotifiedLowBattery {
                notifications.notifyLowBattery(level: reading.currentPercentage)
                lastNotifiedLowBattery = true
            }
        }

        let snapshotSettings = ChargeSettingsSnapshot(
            appChargeLimit: settings.chargeLimit,
            isTopUpActive: settings.isTopUpActive,
            autoResetTopUp: settings.autoResetTopUp,
            isManualDischarge: settings.isChargingPaused,
            sailingModeEnabled: settings.sailingModeEnabled,
            sailingDelta: settings.sailingDelta,
            tempProtectionEnabled: settings.tempProtectionEnabled,
            maxAllowedTempCelsius: settings.maxAllowedTempCelsius
        )

        let decision = ChargePolicy.evaluate(
            level: reading.currentPercentage,
            isACConnected: reading.isACConnected,
            isFullyCharged: reading.isFullyCharged,
            temperatureCelsius: reading.temperatureCelsius,
            settings: snapshotSettings,
            systemChargeLimit: cachedSystemLimit,
            previousMode: previousPolicyMode,
            wasOverheatLatched: isOverheatLatched
        )

        previousPolicyMode = decision.mode
        isOverheatLatched = decision.overheatLatched

        if decision.clearTopUp {
            settings.isTopUpActive = false
            newInfo.isTopUpActive = false
        }
        if decision.clearManualDischarge {
            settings.isChargingPaused = false
        }

        handlePolicyEvents(decision.events, level: reading.currentPercentage)

        if decision.mode == .normal {
            lastNotifiedLimit = nil
        }

        controller.syncStatusOnly()
        newInfo.controlStatus = controller.controlStatus
        if newInfo.isChargingInhibited {
            newInfo.isCharging = false
        }

        self.info = newInfo
        onUpdate?(newInfo)

        let targetMode = decision.mode
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.controller.apply(targetMode)
            var updated = self.info
            updated.controlStatus = self.controller.controlStatus
            if updated.isChargingInhibited {
                updated.isCharging = false
            }
            self.info = updated
            self.onUpdate?(updated)
        }
    }

    private func handlePolicyEvents(_ events: [ChargePolicyEvent], level: Int) {
        for event in events {
            switch event {
            case .topUpCompleted:
                if settings.notifyOnFull {
                    notifications.notifyTopUpCompleted()
                }
            case .limitReached(let limit):
                if settings.notifyOnLimitReached && lastNotifiedLimit != limit {
                    notifications.notifyLimitReached(level: level, target: limit)
                    lastNotifiedLimit = limit
                }
            case .overheat(let temp):
                if settings.notifyOnOverheat {
                    let now = Date()
                    if lastNotifiedOverheatTime == nil || now.timeIntervalSince(lastNotifiedOverheatTime!) > 1800 {
                        notifications.notifyOverheating(temperature: temp)
                        lastNotifiedOverheatTime = now
                    }
                }
            case .dischargeFloorReached:
                break
            }
        }
    }

    // MARK: - User Intent Actions
    public func toggleTopUp() {
        settings.isTopUpActive.toggle()
        if settings.isTopUpActive {
            settings.isChargingPaused = false
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
        }
        fetchSnapshot()
    }

    // MARK: - IOKit Helpers
    private func readIORegistryDictionary(serviceName: String) -> [String: Any] {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(serviceName))
        guard service != 0 else { return [:] }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
           let dict = props?.takeRetainedValue() as? [String: Any] {
            return dict
        }
        return [:]
    }

    private func readIOPSSnapshot() -> IOPSPowerSnapshot {
        var isAC = false
        var isCharging = false
        if let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] {
            for ps in list {
                if let desc = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any] {
                    if let powerState = desc[kIOPSPowerSourceStateKey as String] as? String,
                       powerState == (kIOPSACPowerValue as String) {
                        isAC = true
                    }
                    if let chg = desc[kIOPSIsChargingKey as String] as? Bool, chg {
                        isCharging = true
                    }
                }
            }
        }
        return IOPSPowerSnapshot(isACConnected: isAC, isCharging: isCharging)
    }

    // MARK: - Native macOS 15+ System Charge Limit Detection (async, 60s cache)
    private func refreshSystemChargeLimitIfNeeded() {
        let now = Date()
        guard !isFetchingSystemLimit else { return }
        guard now.timeIntervalSince(lastSystemLimitCheck) >= 60.0 else { return }

        isFetchingSystemLimit = true
        lastSystemLimitCheck = now

        Task.detached(priority: .utility) { [weak self] in
            let limit = Self.readSystemChargeLimit()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.cachedSystemLimit = limit
                self.isFetchingSystemLimit = false
            }
        }
    }

    private nonisolated static func readSystemChargeLimit() -> Int? {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        proc.arguments = ["-g", "battlimit"]
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            // Read before waitUntilExit to avoid pipe buffer deadlock
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            guard let str = String(data: data, encoding: .utf8) else { return nil }
            let pattern = "chargeSocLimitSoc\\s*=\\s*(\\d+);"
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)),
               let range = Range(match.range(at: 1), in: str),
               let limit = Int(str[range]), limit >= 50 && limit <= 100 {
                return limit
            }
        } catch {
            return nil
        }
        return nil
    }
}
