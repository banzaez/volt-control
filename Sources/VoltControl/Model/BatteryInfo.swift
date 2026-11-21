import Foundation
import SwiftUI
import VoltCore

public enum ChargeControlStatus: Sendable, Equatable {
    case helperMissing
    case needsApproval
    case active(ChargeMode)
    case unsupported(ChargeMode)
    case failed(String)
}

/// Represents the high-level power state of the MacBook
public enum BatteryState: String, Sendable {
    case charging = "Заряжается"
    case discharging = "Разряжается"
    case pluggedInPaused = "Пауза (Лимит)"
    case pluggedInFull = "Заряжен (От сети)"
    case unknown = "Определение..."

    public var iconName: String {
        switch self {
        case .charging: return "bolt.fill"
        case .discharging: return "arrow.down.right"
        case .pluggedInPaused: return "pause.fill"
        case .pluggedInFull: return "checkmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    public var statusColor: Color {
        switch self {
        case .charging: return .green
        case .discharging: return .blue
        case .pluggedInPaused: return .orange
        case .pluggedInFull: return .teal
        case .unknown: return .secondary
        }
    }
}

/// Complete battery and power telemetry snapshot
public struct BatteryInfo: Sendable {
    public var currentPercentage: Int = 0
    public var isCharging: Bool = false
    public var isACConnected: Bool = false
    public var isFullyCharged: Bool = false

    /// Power into (+) or out of (-) battery in Watts
    public var batteryPowerWatts: Double = 0.0

    /// Power delivered by the AC adapter in Watts
    public var adapterPowerWatts: Double = 0.0

    /// Total system power consumption by the MacBook in Watts
    public var systemPowerWatts: Double = 0.0

    public var voltageVolts: Double = 0.0
    public var amperageMilliAmps: Int = 0
    public var temperatureCelsius: Double? = nil

    public var cycleCount: Int = 0
    public var designCapacityMah: Int = 0
    public var currentMaxCapacityMah: Int = 0
    public var remainingCapacityMah: Int = 0

    public var timeRemainingMinutes: Int? = nil
    public var elapsedTimeSeconds: Int = 0
    public var isTopUpActive: Bool = false
    public var appChargeLimit: Int = 80
    public var systemChargeLimit: Int? = nil
    public var controlStatus: ChargeControlStatus = .helperMissing

    /// Effective charge limit = min(appChargeLimit, systemChargeLimit ?? 100)
    public var chargeLimit: Int {
        min(appChargeLimit, systemChargeLimit ?? 100)
    }

    public var isEffectivelyCharging: Bool {
        isCharging || (isACConnected && batteryPowerWatts > 0.25)
    }

    public var isChargingInhibited: Bool {
        switch controlStatus {
        case .active(.inhibit), .active(.discharge):
            return true
        default:
            return false
        }
    }

    public var state: BatteryState {
        if !isACConnected {
            return .discharging
        }
        if isCharging && batteryPowerWatts > 0.1 {
            return .charging
        }
        if isFullyCharged || currentPercentage >= 100 {
            return .pluggedInFull
        }
        if isChargingInhibited || batteryPowerWatts <= 0.1 {
            return .pluggedInPaused
        }
        return .discharging
    }

    /// Health percentage: (Current Max Capacity / Design Capacity) * 100
    public var healthPercentage: Double {
        guard designCapacityMah > 0 else { return 100.0 }
        let health = (Double(currentMaxCapacityMah) / Double(designCapacityMah)) * 100.0
        return min(max(health, 0.0), 100.0)
    }

    public var timeRemainingLabel: String {
        if !isACConnected {
            return "Осталось работы"
        }
        if isFullyCharged || currentPercentage >= 100 {
            return "Состояние"
        }
        if isACConnected && !isTopUpActive && chargeLimit < 100 && currentPercentage >= chargeLimit {
            return "Состояние"
        }
        if isCharging {
            if !isTopUpActive && chargeLimit < 100 {
                return "До лимита"
            } else {
                return "До полной зарядки"
            }
        }
        return "Питание"
    }

    public var timeRemainingFormatted: String {
        if isFullyCharged || currentPercentage >= 100 {
            return "Полностью заряжен"
        }
        if isACConnected {
            if !isTopUpActive && chargeLimit < 100 && currentPercentage >= chargeLimit {
                return "Лимит достигнут"
            }
            if !isCharging {
                return "Питание от сети"
            }
        }
        guard let minutes = timeRemainingMinutes, minutes > 0, minutes < 65535 else {
            return "Расчёт..."
        }
        return Formatting.duration(minutes: minutes)
    }

    public var elapsedTimeFormatted: String {
        Formatting.duration(seconds: elapsedTimeSeconds)
    }

    public var appModeDescription: String {
        if !isACConnected {
            return "Работа от батареи"
        }
        switch controlStatus {
        case .helperMissing:
            return "Требуется демон SMC"
        case .needsApproval:
            return "Требуется разрешение в Настройках"
        case .unsupported:
            if let sys = systemChargeLimit {
                return "Системный лимит macOS (\(sys)%)"
            }
            return "Управление SMC недоступно"
        case .failed:
            return "Ошибка управления SMC"
        case .active(.discharge):
            return "Работа от батареи (от сети)"
        case .active(.inhibit):
            return "Обход батареи"
        case .active(.normal):
            if isTopUpActive {
                return "Полная зарядка"
            }
            if chargeLimit < 100 && currentPercentage >= chargeLimit {
                return "Поддержание лимита"
            }
            if isCharging {
                return chargeLimit < 100 ? "Ограничение заряда" : "Зарядка"
            }
            return "Питание от сети"
        }
    }

    public static let initial = BatteryInfo()
}
