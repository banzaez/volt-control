import SwiftUI

public struct QuickActionsView: View {
    public let info: BatteryInfo
    public let settings: AppSettings
    public let onToggleTopUp: () -> Void
    public let onSetLimit: (Int) -> Void
    public let onTogglePause: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Быстрые действия", systemImage: "sparkles")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)

            // Primary Big Button: Charge to 100% (Top Up)
            Button(action: onToggleTopUp) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(settings.isTopUpActive ? Color.orange : Color.orange.opacity(0.15))
                            .frame(width: 34, height: 34)

                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(settings.isTopUpActive ? .white : .orange)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Зарядить до 100%")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.primary)

                            if settings.isTopUpActive {
                                Text("АКТИВНО")
                                    .font(.system(size: 9, weight: .black))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                        }

                        Text(settings.isTopUpActive ? "Зарядка до максимума включена" : "Разовая зарядка перед выходом/поездкой")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: settings.isTopUpActive ? "checkmark.circle.fill" : "chevron.forward")
                        .font(.system(size: 14))
                        .foregroundStyle(settings.isTopUpActive ? .orange : .secondary.opacity(0.5))
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(settings.isTopUpActive ? Color.orange.opacity(0.12) : Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(settings.isTopUpActive ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Secondary Quick Actions: Limit Presets and Pause
            HStack(spacing: 6) {
                // Preset 80%
                limitPresetButton(target: 80, label: "Лимит 80%", recommended: true)

                // Preset 70% or 90%
                limitPresetButton(target: 90, label: "Лимит 90%", recommended: false)

                // Pause button
                Button(action: onTogglePause) {
                    HStack(spacing: 4) {
                        Image(systemName: settings.isChargingPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 10))
                        Text(settings.isChargingPaused ? "Продолжить" : "Пауза")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(settings.isChargingPaused ? Color.orange.opacity(0.2) : Color.primary.opacity(0.05))
                    )
                    .foregroundStyle(settings.isChargingPaused ? .orange : .primary)
                }
                .buttonStyle(.plain)
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

    private func limitPresetButton(target: Int, label: String, recommended: Bool) -> some View {
        let isSelected = settings.chargeLimit == target && !settings.isTopUpActive
        return Button(action: { onSetLimit(target) }) {
            VStack(spacing: 1) {
                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                if recommended {
                    Text("Рекомендовано")
                        .font(.system(size: 8))
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, recommended ? 5 : 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.05))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
