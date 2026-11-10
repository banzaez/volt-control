import SwiftUI

public struct PowerFlowView: View {
    public let info: BatteryInfo

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Label("Потоки мощности", systemImage: "bolt.horizontal.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("В реальном времени")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            // 3-Card Grid
            HStack(spacing: 8) {
                // 1. Battery Power Flow
                flowCard(
                    title: batteryFlowTitle,
                    value: batteryFlowValue,
                    icon: batteryFlowIcon,
                    color: batteryFlowColor,
                    subtitle: batteryFlowSubtitle
                )

                // 2. Mac System Power Draw
                flowCard(
                    title: "Расход Mac",
                    value: String(format: "%.1f Вт", info.systemPowerWatts),
                    icon: "laptopcomputer",
                    color: .purple,
                    subtitle: "Потребление системы"
                )

                // 3. Adapter Input Power
                flowCard(
                    title: "Адаптер",
                    value: adapterValue,
                    icon: "powerplug.fill",
                    color: info.isACConnected ? .orange : .secondary,
                    subtitle: info.isACConnected ? "Входная мощность" : "От аккумулятора"
                )
            }

            // Visual Power Distribution Diagram
            if info.isACConnected {
                HStack(spacing: 6) {
                    Image(systemName: "powerplug.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text(String(format: "%.1f Вт", info.adapterPowerWatts))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "laptopcomputer")
                            .font(.system(size: 10))
                        Text(String(format: "%.1f Вт", info.systemPowerWatts))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    Text("+")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "battery.100")
                            .font(.system(size: 10))
                        Text(String(format: "%+.1f Вт", info.batteryPowerWatts))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(batteryFlowColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func flowCard(title: String, value: String, icon: String, color: Color, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.8)

            Text(subtitle)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(0.08))
        )
    }

    private var batteryFlowTitle: String {
        if info.isCharging && info.batteryPowerWatts > 0.1 {
            return "В батарею"
        } else if info.batteryPowerWatts < -0.1 {
            return "Из батареи"
        } else {
            return "Батарея"
        }
    }

    private var batteryFlowValue: String {
        if abs(info.batteryPowerWatts) <= 0.1 && info.isACConnected {
            return "0.0 Вт"
        }
        return String(format: "%+.1f Вт", info.batteryPowerWatts)
    }

    private var batteryFlowIcon: String {
        if info.isCharging && info.batteryPowerWatts > 0.1 {
            return "bolt.down.fill"
        } else if info.batteryPowerWatts < -0.1 {
            return "arrow.up.right"
        } else {
            return "pause.fill"
        }
    }

    private var batteryFlowColor: Color {
        if info.isCharging && info.batteryPowerWatts > 0.1 {
            return .green
        } else if info.isChargingInhibited {
            return .orange
        } else {
            return .blue
        }
    }

    private var batteryFlowSubtitle: String {
        if info.isCharging && info.batteryPowerWatts > 0.1 {
            return "Зарядка аккумулятора"
        } else if info.isChargingInhibited && info.isACConnected {
            return "Обход (Bypass)"
        } else {
            return "Разряд"
        }
    }

    private var adapterValue: String {
        if info.isACConnected {
            return String(format: "%.1f Вт", info.adapterPowerWatts)
        } else {
            return "Отключен"
        }
    }
}
