import Foundation
import SwiftUI

/// Represents the high-level power state of the MacBook
public enum BatteryState: String, Sendable {
    case charging = "Заряжается"
    case discharging = "Разряжается"
    case pluggedInPaused = "Пауза (Лимит)"
    case pluggedInFull = "Заряжен (От сети)"
    case unknown = "Определение..."

    public var iconName: String {
        switch self {
        case .charging:
            return "bolt.fill"
        case .discharging:
            return "arrow.down.right"
        case .pluggedInPaused:
            return "pause.fill"
        case .pluggedInFull:
            return "checkmark.circle.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }

    public var statusColor: Color {
        switch self {
        case .charging:
            return .green
        case .discharging:
            return .blue
        case .pluggedInPaused:
            return .orange
        case .pluggedInFull:
            return .teal
        case .unknown:
            return .secondary
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
    public var temperatureCelsius: Double = 0.0

    public var cycleCount: Int = 0
    public var designCapacityMah: Int = 0
    public var currentMaxCapacityMah: Int = 0
    public var remainingCapacityMah: Int = 0

    public var timeRemainingMinutes: Int? = nil
    public var isChargingInhibited: Bool = false

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

    public var timeRemainingFormatted: String {
        guard let minutes = timeRemainingMinutes, minutes > 0, minutes < 65535 else {
            if isFullyCharged {
                return "Полностью заряжен"
            }
            if isACConnected && !isCharging {
                return "Питание напрямую от сети"
            }
            return "Расчёт..."
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if isCharging {
            if hours > 0 {
                return "До полной зарядки: \(hours) ч \(mins) мин"
            } else {
                return "До полной зарядки: \(mins) мин"
            }
        } else {
            if hours > 0 {
                return "Осталось: \(hours) ч \(mins) мин работы"
            } else {
                return "Осталось: \(mins) мин работы"
            }
        }
    }

    public static let initial = BatteryInfo()
}
