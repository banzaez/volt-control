import Foundation
import VoltCore

public enum ChargePolicyEvent: Sendable, Equatable {
    case topUpCompleted
    case limitReached(Int)
    case overheat(Double)
    case dischargeFloorReached
}

public struct ChargeSettingsSnapshot: Sendable {
    public var appChargeLimit: Int
    public var isTopUpActive: Bool
    public var autoResetTopUp: Bool
    public var isManualDischarge: Bool
    public var sailingModeEnabled: Bool
    public var sailingDelta: Int
    public var tempProtectionEnabled: Bool
    public var maxAllowedTempCelsius: Double

    public init(
        appChargeLimit: Int = 80,
        isTopUpActive: Bool = false,
        autoResetTopUp: Bool = true,
        isManualDischarge: Bool = false,
        sailingModeEnabled: Bool = true,
        sailingDelta: Int = 4,
        tempProtectionEnabled: Bool = true,
        maxAllowedTempCelsius: Double = 38.0
    ) {
        self.appChargeLimit = appChargeLimit
        self.isTopUpActive = isTopUpActive
        self.autoResetTopUp = autoResetTopUp
        self.isManualDischarge = isManualDischarge
        self.sailingModeEnabled = sailingModeEnabled
        self.sailingDelta = sailingDelta
        self.tempProtectionEnabled = tempProtectionEnabled
        self.maxAllowedTempCelsius = maxAllowedTempCelsius
    }
}

public struct ChargeDecision: Sendable, Equatable {
    public var mode: ChargeMode
    public var overheatLatched: Bool
    public var events: [ChargePolicyEvent]
    public var clearTopUp: Bool
    public var clearManualDischarge: Bool

    public init(
        mode: ChargeMode,
        overheatLatched: Bool,
        events: [ChargePolicyEvent] = [],
        clearTopUp: Bool = false,
        clearManualDischarge: Bool = false
    ) {
        self.mode = mode
        self.overheatLatched = overheatLatched
        self.events = events
        self.clearTopUp = clearTopUp
        self.clearManualDischarge = clearManualDischarge
    }
}

public enum ChargePolicy {
    public static let dischargeFloorPercentage = 10
    public static let overheatHysteresisCelsius = 2.0

    public static func evaluate(
        level: Int,
        isACConnected: Bool,
        isFullyCharged: Bool,
        temperatureCelsius: Double?,
        settings: ChargeSettingsSnapshot,
        systemChargeLimit: Int?,
        previousMode: ChargeMode?,
        wasOverheatLatched: Bool
    ) -> ChargeDecision {
        var events: [ChargePolicyEvent] = []
        var clearTopUp = false
        var clearManualDischarge = false

        // Update overheat latch with 2°C hysteresis
        var overheatLatched = wasOverheatLatched
        if settings.tempProtectionEnabled, let temp = temperatureCelsius {
            if temp >= settings.maxAllowedTempCelsius {
                if !wasOverheatLatched {
                    events.append(.overheat(temp))
                }
                overheatLatched = true
            } else if temp <= settings.maxAllowedTempCelsius - overheatHysteresisCelsius {
                overheatLatched = false
            }
        } else {
            overheatLatched = false
        }

        // 1. Manual Discharge ("Работать от батареи") takes priority over thermal inhibit
        if settings.isManualDischarge {
            if level <= dischargeFloorPercentage {
                clearManualDischarge = true
                events.append(.dischargeFloorReached)
                return ChargeDecision(
                    mode: .normal,
                    overheatLatched: overheatLatched,
                    events: events,
                    clearTopUp: false,
                    clearManualDischarge: true
                )
            }
            return ChargeDecision(
                mode: .discharge,
                overheatLatched: overheatLatched,
                events: events
            )
        }

        // 2. Overheat protection
        if overheatLatched {
            return ChargeDecision(
                mode: .inhibit,
                overheatLatched: true,
                events: events
            )
        }

        // 3. Not on AC -> normal
        guard isACConnected else {
            return ChargeDecision(
                mode: .normal,
                overheatLatched: false,
                events: events
            )
        }

        // 4. Top-up mode
        if settings.isTopUpActive {
            if level < 100 && !isFullyCharged {
                return ChargeDecision(
                    mode: .normal,
                    overheatLatched: false,
                    events: events
                )
            }
            if settings.autoResetTopUp {
                clearTopUp = true
                events.append(.topUpCompleted)
                // Fall through to step 5 (effective limit)
            } else {
                return ChargeDecision(
                    mode: .normal,
                    overheatLatched: false,
                    events: events
                )
            }
        }

        // 5. Effective charge limit = min(appLimit, systemLimit ?? 100)
        let effectiveLimit = min(settings.appChargeLimit, systemChargeLimit ?? 100)
        if effectiveLimit >= 100 {
            return ChargeDecision(
                mode: .normal,
                overheatLatched: false,
                events: events,
                clearTopUp: clearTopUp
            )
        }

        if level >= effectiveLimit {
            events.append(.limitReached(effectiveLimit))
            return ChargeDecision(
                mode: .inhibit,
                overheatLatched: false,
                events: events,
                clearTopUp: clearTopUp,
                clearManualDischarge: clearManualDischarge
            )
        }

        if settings.sailingModeEnabled {
            let threshold = effectiveLimit - settings.sailingDelta
            if level <= threshold {
                return ChargeDecision(
                    mode: .normal,
                    overheatLatched: false,
                    events: events,
                    clearTopUp: clearTopUp
                )
            }
            let preserved = previousMode ?? .normal
            return ChargeDecision(
                mode: preserved,
                overheatLatched: false,
                events: events,
                clearTopUp: clearTopUp
            )
        }

        return ChargeDecision(
            mode: .normal,
            overheatLatched: false,
            events: events,
            clearTopUp: clearTopUp
        )
    }
}
