import SwiftUI
import AppKit

public struct MainPopoverView: View {
    @Bindable var monitor = BatteryMonitor.shared
    @Bindable var settings = AppSettings.shared
    @Bindable var energyService = HighEnergyAppService.shared

    public let onOpenSettings: () -> Void
    public let onQuit: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - 1. Верхний блок сводки
            headerSummarySection
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

            menuDivider

            // MARK: - 2. Распределение питания
            if settings.menuShowPowerDistribution {
                powerDistributionSection
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                menuDivider
            }

            // MARK: - 3. Приложения с высоким энергопотреблением (фиксировано 4 слота)
            if settings.menuShowHighEnergyApps {
                highEnergyAppsSection
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                menuDivider
            }

            // MARK: - 4. Пункты меню
            VStack(spacing: 1) {
                NativeMenuItem(
                    title: "Зарядить до 100%",
                    checkmark: settings.isTopUpActive,
                    action: {
                        monitor.toggleTopUp()
                    }
                )

                NativeMenuItem(
                    title: "Работать от батареи",
                    checkmark: settings.isChargingPaused,
                    action: {
                        monitor.togglePause()
                    }
                )

                menuDivider
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)

                NativeMenuItem(
                    title: "Настройки...",
                    shortcut: "⌘,",
                    action: {
                        onOpenSettings()
                    }
                )

                menuDivider
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)

                NativeMenuItem(
                    title: "Завершить VoltControl",
                    shortcut: "⌘Q",
                    action: {
                        onQuit()
                    }
                )
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
            .padding(.bottom, 6)
        }
        .frame(width: 288)
        .background(VisualEffectBlur(material: .popover, blendingMode: .behindWindow))
    }

    // MARK: - 1. Header Summary
    private var headerSummarySection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text("Аккумулятор")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text("\(monitor.info.currentPercentage) %")
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
            }

            if settings.menuShowTimeRemaining {
                summaryRow(label: "Осталось времени", value: monitor.info.timeRemainingFormatted)
            }

            if settings.menuShowElapsedTime && !monitor.info.isACConnected {
                summaryRow(label: "Прошедшее время", value: monitor.info.elapsedTimeFormatted)
            }

            if settings.menuShowAppMode {
                HStack(alignment: .top) {
                    Text("Режим приложения")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 10)
                    Text(monitor.info.appModeDescription)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }

            if settings.menuShowCompactTelemetry {
                HStack(spacing: 6) {
                    Text(String(format: "Здоровье %.0f%%", monitor.info.healthPercentage))
                    Text("•")
                    Text(String(format: "%.1f °C", monitor.info.temperatureCelsius).replacingOccurrences(of: ".", with: ","))
                    Text("•")
                    Text("\(monitor.info.cycleCount) цикл.")
                }
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .monospacedDigit()
                .padding(.top, 2)
            }
        }
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - 2. Power Distribution (Минималистичное и точное распределение ватт)
    private var powerDistributionSection: some View {
        let info = monitor.info
        let isAC = info.isACConnected
        let isChg = info.isCharging && info.batteryPowerWatts > 0.1
        let battWatts = abs(info.batteryPowerWatts)
        let sysWatts = info.systemPowerWatts
        let adapterWatts = max(info.adapterPowerWatts, isChg ? (sysWatts + battWatts) : sysWatts)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Распределение питания")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if !isAC {
                // Работа от аккумулятора: [ 🔋 5,6 Вт ] → [ 💻 5,6 Вт ]
                HStack(spacing: 8) {
                    powerPill(
                        icon: "battery.75",
                        watts: formattedWatts(battWatts),
                        caption: "Из батареи"
                    )

                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)

                    powerPill(
                        icon: "laptopcomputer",
                        watts: formattedWatts(sysWatts),
                        caption: "Расход Mac"
                    )
                }
            } else if isChg {
                // Зарядка от сети: [ 🔌 18,8 Вт ] → [ 💻 7,3 Вт ] + [ 🔋 11,5 Вт ]
                HStack(spacing: 5) {
                    powerPill(
                        icon: "powerplug.fill",
                        watts: formattedWatts(adapterWatts),
                        caption: "Адаптер"
                    )

                    Image(systemName: "arrow.right")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)

                    powerPill(
                        icon: "laptopcomputer",
                        watts: formattedWatts(sysWatts),
                        caption: "На Mac"
                    )

                    Text("+")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)

                    powerPill(
                        icon: "battery.100percent.bolt",
                        watts: formattedWatts(battWatts),
                        caption: "В батарею"
                    )
                }
            } else {
                // Питание от сети (пауза / лимит достигнут): [ 🔌 7,3 Вт ] → [ 💻 7,3 Вт ]
                HStack(spacing: 8) {
                    powerPill(
                        icon: "powerplug.fill",
                        watts: formattedWatts(adapterWatts),
                        caption: "Адаптер"
                    )

                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)

                    powerPill(
                        icon: "laptopcomputer",
                        watts: formattedWatts(sysWatts),
                        caption: "На Mac (обход)"
                    )
                }
            }

            if settings.menuShowPowerSplitBar && isAC && isChg {
                let total = max(0.5, sysWatts + battWatts)
                let sysShare = min(max(0.1, sysWatts / total), 0.9)
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        Capsule()
                            .fill(Color.primary.opacity(0.45))
                            .frame(width: geo.size.width * CGFloat(sysShare), height: 3)
                        Capsule()
                            .fill(Color.primary.opacity(0.20))
                            .frame(maxWidth: .infinity)
                            .frame(height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
    }

    private func powerPill(icon: String, watts: String, caption: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Text(watts)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )

            Text(caption)
                .font(.system(size: 9.5))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    // MARK: - 3. Fixed 4-App Section (Приложения с высоким энергопотреблением)
    private var highEnergyAppsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Приложения с высоким\nэнергопотреблением")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 2) {
                ForEach(Array(energyService.topFourSlots.prefix(4).enumerated()), id: \.offset) { _, app in
                    fixedAppRow(app: app)
                        .frame(height: 24)
                }
            }
            .frame(height: 24 * 4 + 2 * 3) // Фиксированная высота 102pt — меню не прыгает
        }
    }

    private func fixedAppRow(app: HighEnergyApp) -> some View {
        HStack(spacing: 8) {
            if app.isPlaceholder {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
                    .frame(width: 16, height: 16)

                Text("—")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.quaternary)

                Spacer()
            } else {
                if let icon = energyService.appIcons[app.name] {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 17, height: 17)
                } else {
                    Image(systemName: "app")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 17, height: 17)
                }

                Text(app.name)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if settings.showCPUPercentageInMenu {
                    Text(String(format: "%.0f%%", app.cpuUsage))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }

                Text(app.impact.rawValue)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formattedWatts(_ watts: Double) -> String {
        let val = String(format: "%.1f", watts).replacingOccurrences(of: ".", with: ",")
        return "\(val) Вт"
    }

    private var menuDivider: some View {
        Divider()
            .opacity(0.4)
    }
}

// MARK: - VisualEffectBlur
public struct VisualEffectBlur: NSViewRepresentable {
    public let material: NSVisualEffectView.Material
    public let blendingMode: NSVisualEffectView.BlendingMode

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Standard macOS Menu Item Row
public struct NativeMenuItem: View {
    public let title: String
    public var shortcut: String? = nil
    public var checkmark: Bool = false
    public let action: () -> Void

    @State private var isHovered: Bool = false

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if checkmark {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(isHovered ? .white : Color.primary)
                        .frame(width: 14)
                }

                Text(title)
                    .font(.system(size: 12.5))
                    .foregroundStyle(isHovered ? .white : Color.primary)

                Spacer()

                if let sc = shortcut {
                    Text(sc)
                        .font(.system(size: 11.5))
                        .foregroundStyle(isHovered ? Color.white.opacity(0.85) : Color.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in
            isHovered = inside
        }
    }
}
