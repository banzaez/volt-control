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

            // MARK: - 3. Приложения с высоким энергопотреблением (фиксировано 3 слота)
            if settings.menuShowHighEnergyApps {
                highEnergyAppsSection
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                menuDivider
            }

            // MARK: - 4. Пункты меню
            if !SMCController.shared.isPrivileged && monitor.info.isACConnected {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.orange)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Управление зарядкой SMC")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary)
                        Text("Требуется активация хелпера")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Включить") {
                        _ = SMCController.shared.installPrivilegedHelper()
                        monitor.fetchSnapshot()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.orange.opacity(0.12))
                )
                .padding(.horizontal, 10)
                .padding(.top, 4)
                .padding(.bottom, 2)

                menuDivider
            }

            VStack(spacing: 1) {
                NativeMenuItem(
                    title: "Зарядить до 100%",
                    checkmark: settings.isTopUpActive,
                    action: {
                        monitor.toggleTopUp()
                        MenuBarController.shared.closePopoverIfNeeded()
                    }
                )

                NativeMenuItem(
                    title: "Работать от батареи",
                    checkmark: settings.isChargingPaused,
                    action: {
                        monitor.togglePause()
                        MenuBarController.shared.closePopoverIfNeeded()
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
        .frame(width: 304)
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
                summaryRow(label: monitor.info.timeRemainingLabel, value: monitor.info.timeRemainingFormatted)
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

    // MARK: - 2. Power Distribution (Точное распределение ватт от батареи и от адаптера)
    private var powerDistributionSection: some View {
        let info = monitor.info
        let isAC = info.isACConnected
        let isChg = info.isCharging || (isAC && info.batteryPowerWatts > 0.25)
        let sysWatts = max(0.1, info.systemPowerWatts)
        let battChargeWatts = isChg ? max(0.0, info.batteryPowerWatts) : 0.0
        let battDischargeWatts = max(0.1, abs(info.batteryPowerWatts))
        let adapterWatts = max(info.adapterPowerWatts, sysWatts + battChargeWatts)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Распределение питания")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(isAC ? (isChg ? "От сети • Зарядка" : "От сети • Обход") : "От батареи")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(isAC ? Color.blue : Color.secondary)
            }

            if !isAC {
                // Работа от аккумулятора: [ 🔋 X,X Вт ] → [ 💻 X,X Вт ]
                HStack(spacing: 8) {
                    powerPill(
                        icon: "battery.75",
                        watts: formattedWatts(battDischargeWatts),
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
            } else {
                // Питание от адаптера: [ 🔌 Адаптер ] → [ 💻 На Mac ] + [ ⚡ В батарею ]
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
                        icon: isChg ? "bolt.fill" : "pause.fill",
                        watts: formattedWatts(battChargeWatts),
                        caption: isChg ? "В батарею" : "Пауза"
                    )
                }
            }

            if settings.menuShowPowerSplitBar && isAC {
                let total = max(0.5, sysWatts + battChargeWatts)
                let battShare = isChg ? min(max(0.12, battChargeWatts / total), 0.88) : 0.0
                GeometryReader { geo in
                    HStack(spacing: isChg ? 2 : 0) {
                        if isChg {
                            Capsule()
                                .fill(Color.blue.opacity(0.65))
                                .frame(width: geo.size.width * CGFloat(battShare), height: 3)
                        }
                        Capsule()
                            .fill(Color.primary.opacity(0.45))
                            .frame(maxWidth: .infinity)
                            .frame(height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
    }

    private func powerPill(icon: String, watts: String, caption: String) -> some View {
        VStack(spacing: 2.5) {
            HStack(spacing: 3.5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(watts)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 5)
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

    // MARK: - 3. Fixed 3-App Section (Приложения с высоким энергопотреблением)
    private var highEnergyAppsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Приложения с высоким\nэнергопотреблением")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Group {
                if energyService.hasRealApps {
                    VStack(spacing: 2) {
                        ForEach(Array(energyService.topThreeSlots.prefix(3).enumerated()), id: \.offset) { _, app in
                            fixedAppRow(app: app)
                                .frame(height: 24)
                        }
                    }
                } else {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.blue.opacity(0.12))
                                .frame(width: 28, height: 28)

                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.blue)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Нет энергоёмких приложений")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)

                            Text("Нагрузка всех процессов в норме")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.primary.opacity(0.035))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
            }
            .frame(height: 24 * 3 + 2 * 2) // Фиксированная высота 76pt (ровно на 3 слота) — меню не прыгает
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
