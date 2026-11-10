import SwiftUI

public struct BatteryGaugeView: View {
    public let info: BatteryInfo
    public let settings: AppSettings

    public var body: some View {
        HStack(spacing: 16) {
            // Circular Ring Gauge
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 8)
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0, to: CGFloat(info.currentPercentage) / 100.0)
                    .stroke(
                        ringGradient,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 72, height: 72)
                    .animation(.easeInOut(duration: 0.4), value: info.currentPercentage)

                VStack(spacing: 1) {
                    Text("\(info.currentPercentage)%")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    if info.isACConnected && !info.isCharging {
                        Image(systemName: "powerplug.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    } else if info.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                    }
                }
            }

            // Status Description
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(info.state.statusColor)
                        .frame(width: 8, height: 8)

                    Text(stateTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                Text(info.timeRemainingFormatted)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                if settings.isTopUpActive {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.badge.clock.fill")
                            .font(.system(size: 10))
                        Text("Режим зарядки до 100% активен")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.orange)
                    .padding(.top, 2)
                } else if info.isChargingInhibited {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 10))
                        Text("Защита батареи активна (лимит \(settings.chargeLimit)%)")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.blue)
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var stateTitle: String {
        if settings.isTopUpActive {
            return "Зарядка до 100%"
        }
        if info.isChargingInhibited {
            return "Лимит \(settings.chargeLimit)% (Пауза)"
        }
        return info.state.rawValue
    }

    private var ringGradient: AngularGradient {
        if info.isCharging {
            return AngularGradient(
                colors: [.green, .mint, .green],
                center: .center
            )
        } else if info.currentPercentage <= 20 {
            return AngularGradient(
                colors: [.red, .orange, .red],
                center: .center
            )
        } else if info.isChargingInhibited {
            return AngularGradient(
                colors: [.orange, .yellow, .orange],
                center: .center
            )
        } else {
            return AngularGradient(
                colors: [.blue, .cyan, .blue],
                center: .center
            )
        }
    }
}
