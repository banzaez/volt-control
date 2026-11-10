import Foundation
import SwiftUI
import ServiceManagement

public enum MenuBarDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case iconOnly = "iconOnly"
    case iconAndPercent = "iconAndPercent"
    case iconAndWatts = "iconAndWatts"
    case iconPercentAndWatts = "iconPercentAndWatts"
    case iconAndTemp = "iconAndTemp"

    public var id: String { rawValue }

    public var localizedTitle: String {
        switch self {
        case .iconOnly:
            return "Только значок"
        case .iconAndPercent:
            return "Значок и процент (62%)"
        case .iconAndWatts:
            return "Значок и мощность (+24,5 Вт / -5,6 Вт)"
        case .iconPercentAndWatts:
            return "Значок, процент и мощность"
        case .iconAndTemp:
            return "Значок и температура (29,5°C)"
        }
    }
}

public enum MenuBarIconStyle: String, CaseIterable, Identifiable, Sendable {
    case glassPill = "glassPill"
    case classicBattery = "classicBattery"
    case minimalBolt = "minimalBolt"

    public var id: String { rawValue }

    public var localizedTitle: String {
        switch self {
        case .glassPill:
            return "Капсула с процентом внутри"
        case .classicBattery:
            return "Классический аккумулятор"
        case .minimalBolt:
            return "Минималистичный символ"
        }
    }
}

@MainActor
@Observable
public final class AppSettings {
    public static let shared = AppSettings()

    // MARK: - 1. Основные (General)
    public var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLaunchAtLogin()
        }
    }

    public var pollingIntervalSeconds: Double {
        didSet {
            UserDefaults.standard.set(pollingIntervalSeconds, forKey: "pollingIntervalSeconds")
            BatteryMonitor.shared.rescheduleTimer()
        }
    }

    public var keepMenuOpenOnAction: Bool {
        didSet {
            UserDefaults.standard.set(keepMenuOpenOnAction, forKey: "keepMenuOpenOnAction")
        }
    }

    // MARK: - 2. Зарядка (Charging)
    public var chargeLimit: Int {
        didSet {
            UserDefaults.standard.set(chargeLimit, forKey: "chargeLimit")
        }
    }

    public var isTopUpActive: Bool {
        didSet {
            UserDefaults.standard.set(isTopUpActive, forKey: "isTopUpActive")
        }
    }

    public var autoResetTopUp: Bool {
        didSet {
            UserDefaults.standard.set(autoResetTopUp, forKey: "autoResetTopUp")
        }
    }

    public var isChargingPaused: Bool {
        didSet {
            UserDefaults.standard.set(isChargingPaused, forKey: "isChargingPaused")
        }
    }

    public var sailingModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(sailingModeEnabled, forKey: "sailingModeEnabled")
        }
    }

    public var sailingDelta: Int {
        didSet {
            UserDefaults.standard.set(sailingDelta, forKey: "sailingDelta")
        }
    }

    public var tempProtectionEnabled: Bool {
        didSet {
            UserDefaults.standard.set(tempProtectionEnabled, forKey: "tempProtectionEnabled")
        }
    }

    public var maxAllowedTempCelsius: Double {
        didSet {
            UserDefaults.standard.set(maxAllowedTempCelsius, forKey: "maxAllowedTempCelsius")
        }
    }

    // MARK: - 3. Энергосбережение и Процессы (Energy & Apps)
    public var highEnergyThresholdCPU: Double {
        didSet {
            UserDefaults.standard.set(highEnergyThresholdCPU, forKey: "highEnergyThresholdCPU")
        }
    }

    public var veryHighEnergyThresholdCPU: Double {
        didSet {
            UserDefaults.standard.set(veryHighEnergyThresholdCPU, forKey: "veryHighEnergyThresholdCPU")
        }
    }

    public var includeSystemProcesses: Bool {
        didSet {
            UserDefaults.standard.set(includeSystemProcesses, forKey: "includeSystemProcesses")
        }
    }

    public var showCPUPercentageInMenu: Bool {
        didSet {
            UserDefaults.standard.set(showCPUPercentageInMenu, forKey: "showCPUPercentageInMenu")
        }
    }

    public var processScanIntervalSeconds: Double {
        didSet {
            UserDefaults.standard.set(processScanIntervalSeconds, forKey: "processScanIntervalSeconds")
        }
    }

    public var ignoredAppNames: String {
        didSet {
            UserDefaults.standard.set(ignoredAppNames, forKey: "ignoredAppNames")
        }
    }

    public var showModerateEnergyApps: Bool {
        didSet {
            UserDefaults.standard.set(showModerateEnergyApps, forKey: "showModerateEnergyApps")
        }
    }

    public var showLowEnergyApps: Bool {
        didSet {
            UserDefaults.standard.set(showLowEnergyApps, forKey: "showLowEnergyApps")
        }
    }

    // MARK: - 4. Меню (Menu Customization)
    public var menuShowTimeRemaining: Bool {
        didSet {
            UserDefaults.standard.set(menuShowTimeRemaining, forKey: "menuShowTimeRemaining")
        }
    }

    public var menuShowElapsedTime: Bool {
        didSet {
            UserDefaults.standard.set(menuShowElapsedTime, forKey: "menuShowElapsedTime")
        }
    }

    public var menuShowAppMode: Bool {
        didSet {
            UserDefaults.standard.set(menuShowAppMode, forKey: "menuShowAppMode")
        }
    }

    public var menuShowCompactTelemetry: Bool {
        didSet {
            UserDefaults.standard.set(menuShowCompactTelemetry, forKey: "menuShowCompactTelemetry")
        }
    }

    public var menuShowPowerDistribution: Bool {
        didSet {
            UserDefaults.standard.set(menuShowPowerDistribution, forKey: "menuShowPowerDistribution")
        }
    }

    public var menuShowPowerSplitBar: Bool {
        didSet {
            UserDefaults.standard.set(menuShowPowerSplitBar, forKey: "menuShowPowerSplitBar")
        }
    }

    public var menuShowHighEnergyApps: Bool {
        didSet {
            UserDefaults.standard.set(menuShowHighEnergyApps, forKey: "menuShowHighEnergyApps")
        }
    }

    // MARK: - 5. Значок (Menu Bar Icon)
    public var menuBarIconStyle: MenuBarIconStyle {
        didSet {
            UserDefaults.standard.set(menuBarIconStyle.rawValue, forKey: "menuBarIconStyle")
        }
    }

    public var menuBarDisplayMode: MenuBarDisplayMode {
        didSet {
            UserDefaults.standard.set(menuBarDisplayMode.rawValue, forKey: "menuBarDisplayMode")
        }
    }

    public var menuBarColorizedIcon: Bool {
        didSet {
            UserDefaults.standard.set(menuBarColorizedIcon, forKey: "menuBarColorizedIcon")
        }
    }

    // MARK: - 6. Уведомления (Notifications)
    public var notifyOnLimitReached: Bool {
        didSet {
            UserDefaults.standard.set(notifyOnLimitReached, forKey: "notifyOnLimitReached")
        }
    }

    public var notifyOnFull: Bool {
        didSet {
            UserDefaults.standard.set(notifyOnFull, forKey: "notifyOnFull")
        }
    }

    public var notifyOnOverheat: Bool {
        didSet {
            UserDefaults.standard.set(notifyOnOverheat, forKey: "notifyOnOverheat")
        }
    }

    public var notifyOnLowBattery: Bool {
        didSet {
            UserDefaults.standard.set(notifyOnLowBattery, forKey: "notifyOnLowBattery")
        }
    }

    public var lowBatteryThreshold: Int {
        didSet {
            UserDefaults.standard.set(lowBatteryThreshold, forKey: "lowBatteryThreshold")
        }
    }

    private init() {
        let d = UserDefaults.standard

        self.launchAtLogin = d.bool(forKey: "launchAtLogin")
        self.pollingIntervalSeconds = d.object(forKey: "pollingIntervalSeconds") != nil ? d.double(forKey: "pollingIntervalSeconds") : 2.0
        self.keepMenuOpenOnAction = d.object(forKey: "keepMenuOpenOnAction") != nil ? d.bool(forKey: "keepMenuOpenOnAction") : true

        self.chargeLimit = d.object(forKey: "chargeLimit") != nil ? d.integer(forKey: "chargeLimit") : 80
        self.isTopUpActive = d.bool(forKey: "isTopUpActive")
        self.autoResetTopUp = d.object(forKey: "autoResetTopUp") != nil ? d.bool(forKey: "autoResetTopUp") : true
        self.isChargingPaused = d.bool(forKey: "isChargingPaused")
        self.sailingModeEnabled = d.object(forKey: "sailingModeEnabled") != nil ? d.bool(forKey: "sailingModeEnabled") : true
        self.sailingDelta = d.object(forKey: "sailingDelta") != nil ? d.integer(forKey: "sailingDelta") : 4
        self.tempProtectionEnabled = d.object(forKey: "tempProtectionEnabled") != nil ? d.bool(forKey: "tempProtectionEnabled") : true
        self.maxAllowedTempCelsius = d.object(forKey: "maxAllowedTempCelsius") != nil ? d.double(forKey: "maxAllowedTempCelsius") : 38.0

        self.highEnergyThresholdCPU = d.object(forKey: "highEnergyThresholdCPU") != nil ? d.double(forKey: "highEnergyThresholdCPU") : 3.0
        self.veryHighEnergyThresholdCPU = d.object(forKey: "veryHighEnergyThresholdCPU") != nil ? d.double(forKey: "veryHighEnergyThresholdCPU") : 20.0
        self.includeSystemProcesses = d.object(forKey: "includeSystemProcesses") != nil ? d.bool(forKey: "includeSystemProcesses") : false
        self.showCPUPercentageInMenu = d.object(forKey: "showCPUPercentageInMenu") != nil ? d.bool(forKey: "showCPUPercentageInMenu") : true
        self.processScanIntervalSeconds = d.object(forKey: "processScanIntervalSeconds") != nil ? d.double(forKey: "processScanIntervalSeconds") : 5.0
        self.ignoredAppNames = d.string(forKey: "ignoredAppNames") ?? "Finder, Dock"
        self.showModerateEnergyApps = d.object(forKey: "showModerateEnergyApps") != nil ? d.bool(forKey: "showModerateEnergyApps") : true
        self.showLowEnergyApps = d.object(forKey: "showLowEnergyApps") != nil ? d.bool(forKey: "showLowEnergyApps") : false

        self.menuShowTimeRemaining = d.object(forKey: "menuShowTimeRemaining") != nil ? d.bool(forKey: "menuShowTimeRemaining") : true
        self.menuShowElapsedTime = d.object(forKey: "menuShowElapsedTime") != nil ? d.bool(forKey: "menuShowElapsedTime") : true
        self.menuShowAppMode = d.object(forKey: "menuShowAppMode") != nil ? d.bool(forKey: "menuShowAppMode") : true
        self.menuShowCompactTelemetry = d.object(forKey: "menuShowCompactTelemetry") != nil ? d.bool(forKey: "menuShowCompactTelemetry") : true
        self.menuShowPowerDistribution = d.object(forKey: "menuShowPowerDistribution") != nil ? d.bool(forKey: "menuShowPowerDistribution") : true
        self.menuShowPowerSplitBar = d.object(forKey: "menuShowPowerSplitBar") != nil ? d.bool(forKey: "menuShowPowerSplitBar") : true
        self.menuShowHighEnergyApps = d.object(forKey: "menuShowHighEnergyApps") != nil ? d.bool(forKey: "menuShowHighEnergyApps") : true

        let styleRaw = d.string(forKey: "menuBarIconStyle") ?? MenuBarIconStyle.glassPill.rawValue
        self.menuBarIconStyle = MenuBarIconStyle(rawValue: styleRaw) ?? .glassPill

        let modeRaw = d.string(forKey: "menuBarDisplayMode") ?? MenuBarDisplayMode.iconOnly.rawValue
        self.menuBarDisplayMode = MenuBarDisplayMode(rawValue: modeRaw) ?? .iconOnly

        self.menuBarColorizedIcon = d.object(forKey: "menuBarColorizedIcon") != nil ? d.bool(forKey: "menuBarColorizedIcon") : false

        self.notifyOnLimitReached = d.object(forKey: "notifyOnLimitReached") != nil ? d.bool(forKey: "notifyOnLimitReached") : true
        self.notifyOnFull = d.object(forKey: "notifyOnFull") != nil ? d.bool(forKey: "notifyOnFull") : true
        self.notifyOnOverheat = d.object(forKey: "notifyOnOverheat") != nil ? d.bool(forKey: "notifyOnOverheat") : true
        self.notifyOnLowBattery = d.object(forKey: "notifyOnLowBattery") != nil ? d.bool(forKey: "notifyOnLowBattery") : true
        self.lowBatteryThreshold = d.object(forKey: "lowBatteryThreshold") != nil ? d.integer(forKey: "lowBatteryThreshold") : 20
    }

    public func parsedIgnoredApps() -> Set<String> {
        let items = ignoredAppNames
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        return Set(items)
    }

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error.localizedDescription)")
        }
    }
}
