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

    @ObservationIgnored private let defaults: UserDefaults

    // MARK: - 1. Основные (General)
    public var launchAtLogin: Bool {
        didSet {
            persist(launchAtLogin, forKey: "launchAtLogin")
            updateLaunchAtLogin()
        }
    }

    public var pollingIntervalSeconds: Double {
        didSet { persist(pollingIntervalSeconds, forKey: "pollingIntervalSeconds") }
    }

    public var keepMenuOpenOnAction: Bool {
        didSet { persist(keepMenuOpenOnAction, forKey: "keepMenuOpenOnAction") }
    }

    public var autoCheckUpdates: Bool {
        didSet { persist(autoCheckUpdates, forKey: "autoCheckUpdates") }
    }

    // MARK: - 2. Зарядка (Charging)
    public var chargeLimit: Int {
        didSet { persist(chargeLimit, forKey: "chargeLimit") }
    }

    public var isTopUpActive: Bool {
        didSet { persist(isTopUpActive, forKey: "isTopUpActive") }
    }

    public var autoResetTopUp: Bool {
        didSet { persist(autoResetTopUp, forKey: "autoResetTopUp") }
    }

    public var isChargingPaused: Bool {
        didSet { persist(isChargingPaused, forKey: "isChargingPaused") }
    }

    public var sailingModeEnabled: Bool {
        didSet { persist(sailingModeEnabled, forKey: "sailingModeEnabled") }
    }

    public var sailingDelta: Int {
        didSet { persist(sailingDelta, forKey: "sailingDelta") }
    }

    public var tempProtectionEnabled: Bool {
        didSet { persist(tempProtectionEnabled, forKey: "tempProtectionEnabled") }
    }

    public var maxAllowedTempCelsius: Double {
        didSet { persist(maxAllowedTempCelsius, forKey: "maxAllowedTempCelsius") }
    }

    // MARK: - 3. Энергосбережение и Процессы (Energy & Apps)
    public var highEnergyThresholdCPU: Double {
        didSet { persist(highEnergyThresholdCPU, forKey: "highEnergyThresholdCPU") }
    }

    public var veryHighEnergyThresholdCPU: Double {
        didSet { persist(veryHighEnergyThresholdCPU, forKey: "veryHighEnergyThresholdCPU") }
    }

    public var includeSystemProcesses: Bool {
        didSet { persist(includeSystemProcesses, forKey: "includeSystemProcesses") }
    }

    public var showCPUPercentageInMenu: Bool {
        didSet { persist(showCPUPercentageInMenu, forKey: "showCPUPercentageInMenu") }
    }

    public var processScanIntervalSeconds: Double {
        didSet { persist(processScanIntervalSeconds, forKey: "processScanIntervalSeconds") }
    }

    public var ignoredAppNames: String {
        didSet { persist(ignoredAppNames, forKey: "ignoredAppNames") }
    }

    public var showModerateEnergyApps: Bool {
        didSet { persist(showModerateEnergyApps, forKey: "showModerateEnergyApps") }
    }

    public var showLowEnergyApps: Bool {
        didSet { persist(showLowEnergyApps, forKey: "showLowEnergyApps") }
    }

    // MARK: - 4. Меню (Menu Customization)
    public var menuShowTimeRemaining: Bool {
        didSet { persist(menuShowTimeRemaining, forKey: "menuShowTimeRemaining") }
    }

    public var menuShowElapsedTime: Bool {
        didSet { persist(menuShowElapsedTime, forKey: "menuShowElapsedTime") }
    }

    public var menuShowAppMode: Bool {
        didSet { persist(menuShowAppMode, forKey: "menuShowAppMode") }
    }

    public var menuShowCompactTelemetry: Bool {
        didSet { persist(menuShowCompactTelemetry, forKey: "menuShowCompactTelemetry") }
    }

    public var menuShowPowerDistribution: Bool {
        didSet { persist(menuShowPowerDistribution, forKey: "menuShowPowerDistribution") }
    }

    public var menuShowPowerSplitBar: Bool {
        didSet { persist(menuShowPowerSplitBar, forKey: "menuShowPowerSplitBar") }
    }

    public var menuShowHighEnergyApps: Bool {
        didSet { persist(menuShowHighEnergyApps, forKey: "menuShowHighEnergyApps") }
    }

    // MARK: - 5. Значок (Menu Bar Icon)
    public var menuBarIconStyle: MenuBarIconStyle {
        didSet { persist(menuBarIconStyle.rawValue, forKey: "menuBarIconStyle") }
    }

    public var menuBarDisplayMode: MenuBarDisplayMode {
        didSet { persist(menuBarDisplayMode.rawValue, forKey: "menuBarDisplayMode") }
    }

    public var menuBarColorizedIcon: Bool {
        didSet { persist(menuBarColorizedIcon, forKey: "menuBarColorizedIcon") }
    }

    // MARK: - 6. Уведомления (Notifications)
    public var notifyOnLimitReached: Bool {
        didSet { persist(notifyOnLimitReached, forKey: "notifyOnLimitReached") }
    }

    public var notifyOnFull: Bool {
        didSet { persist(notifyOnFull, forKey: "notifyOnFull") }
    }

    public var notifyOnOverheat: Bool {
        didSet { persist(notifyOnOverheat, forKey: "notifyOnOverheat") }
    }

    public var notifyOnLowBattery: Bool {
        didSet { persist(notifyOnLowBattery, forKey: "notifyOnLowBattery") }
    }

    public var lowBatteryThreshold: Int {
        didSet { persist(lowBatteryThreshold, forKey: "lowBatteryThreshold") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.launchAtLogin = Self.load(defaults, "launchAtLogin", default: false)
        self.pollingIntervalSeconds = Self.load(defaults, "pollingIntervalSeconds", default: 2.0)
        self.keepMenuOpenOnAction = Self.load(defaults, "keepMenuOpenOnAction", default: true)
        self.autoCheckUpdates = Self.load(defaults, "autoCheckUpdates", default: true)

        self.chargeLimit = Self.load(defaults, "chargeLimit", default: 80)
        self.isTopUpActive = Self.load(defaults, "isTopUpActive", default: false)
        self.autoResetTopUp = Self.load(defaults, "autoResetTopUp", default: true)
        self.isChargingPaused = Self.load(defaults, "isChargingPaused", default: false)
        self.sailingModeEnabled = Self.load(defaults, "sailingModeEnabled", default: true)
        self.sailingDelta = Self.load(defaults, "sailingDelta", default: 4)
        self.tempProtectionEnabled = Self.load(defaults, "tempProtectionEnabled", default: true)
        self.maxAllowedTempCelsius = Self.load(defaults, "maxAllowedTempCelsius", default: 38.0)

        self.highEnergyThresholdCPU = Self.load(defaults, "highEnergyThresholdCPU", default: 3.0)
        self.veryHighEnergyThresholdCPU = Self.load(defaults, "veryHighEnergyThresholdCPU", default: 20.0)
        self.includeSystemProcesses = Self.load(defaults, "includeSystemProcesses", default: false)
        self.showCPUPercentageInMenu = Self.load(defaults, "showCPUPercentageInMenu", default: true)
        self.processScanIntervalSeconds = Self.load(defaults, "processScanIntervalSeconds", default: 5.0)
        self.ignoredAppNames = Self.load(defaults, "ignoredAppNames", default: "Finder, Dock")
        self.showModerateEnergyApps = Self.load(defaults, "showModerateEnergyApps", default: true)
        self.showLowEnergyApps = Self.load(defaults, "showLowEnergyApps", default: false)

        self.menuShowTimeRemaining = Self.load(defaults, "menuShowTimeRemaining", default: true)
        self.menuShowElapsedTime = Self.load(defaults, "menuShowElapsedTime", default: true)
        self.menuShowAppMode = Self.load(defaults, "menuShowAppMode", default: true)
        self.menuShowCompactTelemetry = Self.load(defaults, "menuShowCompactTelemetry", default: true)
        self.menuShowPowerDistribution = Self.load(defaults, "menuShowPowerDistribution", default: true)
        self.menuShowPowerSplitBar = Self.load(defaults, "menuShowPowerSplitBar", default: true)
        self.menuShowHighEnergyApps = Self.load(defaults, "menuShowHighEnergyApps", default: true)

        let styleRaw = Self.load(defaults, "menuBarIconStyle", default: MenuBarIconStyle.glassPill.rawValue)
        self.menuBarIconStyle = MenuBarIconStyle(rawValue: styleRaw) ?? .glassPill

        let modeRaw = Self.load(defaults, "menuBarDisplayMode", default: MenuBarDisplayMode.iconOnly.rawValue)
        self.menuBarDisplayMode = MenuBarDisplayMode(rawValue: modeRaw) ?? .iconOnly

        self.menuBarColorizedIcon = Self.load(defaults, "menuBarColorizedIcon", default: false)

        self.notifyOnLimitReached = Self.load(defaults, "notifyOnLimitReached", default: true)
        self.notifyOnFull = Self.load(defaults, "notifyOnFull", default: true)
        self.notifyOnOverheat = Self.load(defaults, "notifyOnOverheat", default: true)
        self.notifyOnLowBattery = Self.load(defaults, "notifyOnLowBattery", default: true)
        self.lowBatteryThreshold = Self.load(defaults, "lowBatteryThreshold", default: 20)
    }

    private static func load<T>(_ defaults: UserDefaults, _ key: String, default defaultValue: T) -> T {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        if T.self == Bool.self, let val = defaults.bool(forKey: key) as? T { return val }
        if T.self == Int.self, let val = defaults.integer(forKey: key) as? T { return val }
        if T.self == Double.self, let val = defaults.double(forKey: key) as? T { return val }
        if T.self == String.self, let val = defaults.string(forKey: key) as? T { return val }
        return (defaults.object(forKey: key) as? T) ?? defaultValue
    }

    private func persist<T>(_ value: T, forKey key: String) {
        defaults.set(value, forKey: key)
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
