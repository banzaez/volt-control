import SwiftUI

public struct BatteryHealthView: View {
    public let info: BatteryInfo

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Аналитика и здоровье", systemImage: "chart.xyaxis.line")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)

            // Health Progress Bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Здоровье аккумулятора")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text(String(format: "%.1f%%", info.healthPercentage))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(healthColor)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 6)

                        Capsule()
                            .fill(healthColor)
                            .frame(width: max(0, min(geo.size.width * CGFloat(info.healthPercentage / 100.0), geo.size.width)), height: 6)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("\(info.currentMaxCapacityMah) из \(info.designCapacityMah) мАч")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(healthDescription)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(healthColor)
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Metrics Grid (Cycles, Temperature, Voltage, Amperage)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                metricTile(
                    title: "Циклы зарядки",
                    value: "\(info.cycleCount)",
                    icon: "arrow.triangle.2.circlepath",
                    color: .blue
                )

                metricTile(
                    title: "Температура",
                    value: String(format: "%.1f °C", info.temperatureCelsius),
                    icon: "thermometer.medium",
                    color: tempColor
                )

                metricTile(
                    title: "Напряжение",
                    value: String(format: "%.2f В", info.voltageVolts),
                    icon: "bolt.badge.a.fill",
                    color: .yellow
                )

                metricTile(
                    title: "Сила тока",
                    value: "\(info.amperageMilliAmps) мА",
                    icon: "speedometer",
                    color: .teal
                )
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

    private func metricTile(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
        .padding(8)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var healthColor: Color {
        if info.healthPercentage >= 85 {
            return .green
        } else if info.healthPercentage >= 80 {
            return .yellow
        } else {
            return .red
        }
    }

    private var healthDescription: String {
        if info.healthPercentage >= 90 {
            return "Отличное"
        } else if info.healthPercentage >= 80 {
            return "Нормальное"
        } else {
            return "Рекомендуется сервис"
        }
    }

    private var tempColor: Color {
        if info.temperatureCelsius < 34.0 {
            return .green
        } else if info.temperatureCelsius < 39.0 {
            return .orange
        } else {
            return .red
        }
    }
}
