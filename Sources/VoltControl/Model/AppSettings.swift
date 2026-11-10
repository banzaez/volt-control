import Foundation
import SwiftUI
import ServiceManagement

public enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case iconOnly = "iconOnly"
    case iconAndPercent = "iconAndPercent"
    case iconAndWatts = "iconAndWatts"
    case iconPercentAndWatts = "iconPercentAndWatts"

    public var id: String { rawValue }

    public var localizedTitle: String {
        switch self {
        case .iconOnly:
            return "Только иконка"
        case .iconAndPercent:
            return "Иконка + Процент (62%)"
        case .iconAndWatts:
            return "Иконка + Мощность (+24W / -6W)"
        case .iconPercentAndWatts:
            return "Иконка + Процент + Мощность"
        }
    }
}

@MainActor
@Observable
public final class AppSettings {
    public static let shared = AppSettings()

    // MARK: - Charge Limit Settings
    public var chargeLimit: Int {
        didSet {
            UserDefaults.standard.set(chargeLimit, forKey: "chargeLimit")
        }
    }

    /// When true, limits are bypassed to charge to 100% once
    public var isTopUpActive: Bool {
        didSet {
            UserDefaults.standard.set(isTopUpActive, forKey: "isTopUpActive")
        }
    }

    /// Automatically turn off Top-Up and restore charge limit once 100% is reached
    public var autoResetTopUp: Bool {
        didSet {
            UserDefaults.standard.set(autoResetTopUp, forKey: "autoResetTopUp")
        }
    }

    /// Manual charging pause (bypass power to run on AC without charging)
    public var isChargingPaused: Bool {
        didSet {
            UserDefaults.standard.set(isChargingPaused, forKey: "isChargingPaused")
        }
    }

    /// Sailing mode: don't restart charging immediately when dropping 1%, wait until delta
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

    // MARK: - Temperature Protection
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

    // MARK: - Appearance & Menu Bar
    public var menuBarDisplayMode: MenuBarDisplayMode {
        didSet {
            UserDefaults.standard.set(menuBarDisplayMode.rawValue, forKey: "menuBarDisplayMode")
        }
    }

    // MARK: - Notifications
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

    // MARK: - Launch at login
    public var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLaunchAtLogin()
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        self.chargeLimit = defaults.object(forKey: "chargeLimit") != nil ? defaults.integer(forKey: "chargeLimit") : 80
        self.isTopUpActive = defaults.bool(forKey: "isTopUpActive")
        self.autoResetTopUp = defaults.object(forKey: "autoResetTopUp") != nil ? defaults.bool(forKey: "autoResetTopUp") : true
        self.isChargingPaused = defaults.bool(forKey: "isChargingPaused")
        self.sailingModeEnabled = defaults.object(forKey: "sailingModeEnabled") != nil ? defaults.bool(forKey: "sailingModeEnabled") : true
        self.sailingDelta = defaults.object(forKey: "sailingDelta") != nil ? defaults.integer(forKey: "sailingDelta") : 4
        self.tempProtectionEnabled = defaults.object(forKey: "tempProtectionEnabled") != nil ? defaults.bool(forKey: "tempProtectionEnabled") : true
        self.maxAllowedTempCelsius = defaults.object(forKey: "maxAllowedTempCelsius") != nil ? defaults.double(forKey: "maxAllowedTempCelsius") : 38.0

        let modeRaw = defaults.string(forKey: "menuBarDisplayMode") ?? MenuBarDisplayMode.iconAndPercent.rawValue
        self.menuBarDisplayMode = MenuBarDisplayMode(rawValue: modeRaw) ?? .iconAndPercent

        self.notifyOnLimitReached = defaults.object(forKey: "notifyOnLimitReached") != nil ? defaults.bool(forKey: "notifyOnLimitReached") : true
        self.notifyOnFull = defaults.object(forKey: "notifyOnFull") != nil ? defaults.bool(forKey: "notifyOnFull") : true
        self.notifyOnOverheat = defaults.object(forKey: "notifyOnOverheat") != nil ? defaults.bool(forKey: "notifyOnOverheat") : true

        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
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
