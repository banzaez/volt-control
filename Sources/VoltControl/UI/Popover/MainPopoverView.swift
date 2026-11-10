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
            // MARK: - 1. Верхняя сводка по аккумулятору (macOS 27 Glass)
            headerSummarySection
                .padding(.horizontal, 14)
                .padding(.top, 13)
                .padding(.bottom, 10)

            glassDivider

            // MARK: - 2. Распределение питания (От батареи / Зарядка / Обход)
            if settings.menuShowPowerDistribution {
                powerDistributionSection
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                glassDivider
            }

            // MARK: - 3. Фиксированный блок на 4 приложения (без прыжков высоты)
            if settings.menuShowHighEnergyApps {
                highEnergyAppsSection
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                glassDivider
            }

            // MARK: - 4. Пункты действий (без раздела «Ещё»)
            VStack(spacing: 2) {
                NativeMenuItem(
                    title: "Зарядить до 100%",
                    icon: "bolt.fill",
                    badgeText: settings.isTopUpActive ? "Активно" : nil,
                    checkmark: settings.isTopUpActive,
                    action: {
                        monitor.toggleTopUp()
                    }
                )

                NativeMenuItem(
                    title: "Работать от батареи",
                    icon: "battery.100",
                    badgeText: settings.isChargingPaused ? "Пауза" : nil,
                    checkmark: settings.isChargingPaused,
                    action: {
                        monitor.togglePause()
                    }
                )

                glassDivider
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)

                NativeMenuItem(
                    title: "Настройки...",
                    icon: "slider.horizontal.3",
                    shortcut: "⌘,",
                    action: {
                        onOpenSettings()
                    }
                )

                glassDivider
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)

                NativeMenuItem(
                    title: "Завершить ВольтКонтроль",
                    icon: "power",
                    shortcut: "⌘Q",
                    action: {
                        onQuit()
                    }
                )
            }
            .padding(.horizontal, 6)
            .padding(.top, 5)
            .padding(.bottom, 8)
        }
        .frame(width: 306)
        .background(
            ZStack {
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        Color.clear,
                        Color.black.opacity(0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.28),
                            Color.white.opacity(0.07),
                            Color.white.opacity(0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
    }

    // MARK: - 1. Header Summary Section
    private var headerSummarySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Main Row: Аккумулятор + %
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(monitor.info.state.statusColor)
                        .frame(width: 7, height: 7)
                        .shadow(color: monitor.info.state.statusColor.opacity(0.6), radius: 3)

                    Text("Аккумулятор")
                        .font(.system(size: 13.5, weight: .bold))
                }

                Spacer()

                Text("\(monitor.info.currentPercentage) %")
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            // Progress Bar inside Header
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.10))
                        .frame(height: 5)

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: headerBarColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(5, geo.size.width * CGFloat(monitor.info.currentPercentage) / 100.0),
                            height: 5
                        )
                }
            }
            .frame(height: 5)
            .padding(.bottom, 2)

            if settings.menuShowTimeRemaining {
                summaryRow(label: "Осталось времени", value: monitor.info.timeRemainingFormatted)
            }

            if settings.menuShowElapsedTime {
                summaryRow(label: "Прошедшее время", value: monitor.info.elapsedTimeFormatted)
            }

            if settings.menuShowAppMode {
                HStack(alignment: .top) {
                    Text("Режим приложения")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(monitor.info.appModeDescription)
                        .font(.system(size: 11.5, weight: .medium))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                }
            }

            // Compact Glass Telemetry Strip (Health • Temp • Cycles)
            if settings.menuShowCompactTelemetry {
                HStack(spacing: 0) {
                    telemetryBadge(
                        icon: "heart.fill",
                        color: .green,
                        text: String(format: "%.0f%% здоровье", monitor.info.healthPercentage)
                    )
                    Spacer()
                    Text("•")
                        .font(.system(size: 9))
                        .foregroundStyle(.quaternary)
                    Spacer()
                    telemetryBadge(
                        icon: "thermometer.medium",
                        color: monitor.info.temperatureCelsius >= 36 ? .orange : .cyan,
                        text: String(format: "%.1f°C", monitor.info.temperatureCelsius).replacingOccurrences(of: ".", with: ",")
                    )
                    Spacer()
                    Text("•")
                        .font(.system(size: 9))
                        .foregroundStyle(.quaternary)
                    Spacer()
                    telemetryBadge(
                        icon: "arrow.triangle.2.circlepath",
                        color: .blue,
                        text: "\(monitor.info.cycleCount) цикл."
                    )
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
                )
                .padding(.top, 2)
            }
        }
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11.5, weight: .medium))
                .monospacedDigit()
        }
    }

    private func telemetryBadge(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9.5))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var headerBarColors: [Color] {
        if monitor.info.isCharging {
            return [.mint, .green]
        } else if monitor.info.isChargingInhibited {
            return [.orange, .yellow]
        } else if monitor.info.currentPercentage <= 20 {
            return [.red, .orange]
        } else {
            return [.cyan, .blue]
        }
    }

    // MARK: - 2. Power Distribution Section (Красивое распределение питания)
    private var powerDistributionSection: some View {
        let info = monitor.info
        let isAC = info.isACConnected
        let isChg = info.isCharging && info.batteryPowerWatts > 0.1
        let battWatts = abs(info.batteryPowerWatts)
        let sysWatts = info.systemPowerWatts
        let adapterWatts = max(info.adapterPowerWatts, isChg ? (sysWatts + battWatts) : sysWatts)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Распределение питания")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(isAC ? (isChg ? "Зарядка + Система" : "От сети (Обход)") : "От аккумулятора")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isAC ? (isChg ? .green : .orange) : .cyan)
            }

            if !isAC {
                // РЕЖИМ 1: РАБОТА ОТ АККУМУЛЯТОРА (Батарея ➔ Mac)
                HStack(spacing: 6) {
                    glassPowerNode(
                        icon: "battery.75",
                        iconColor: .cyan,
                        title: "Из батареи",
                        watts: "-\(formattedWatts(battWatts))",
                        subtitle: String(format: "%.1f В • %d мА", info.voltageVolts, info.amperageMilliAmps).replacingOccurrences(of: ".", with: ",")
                    )

                    flowConnector(color: .cyan)

                    glassPowerNode(
                        icon: "laptopcomputer",
                        iconColor: .purple,
                        title: "Расход Mac",
                        watts: formattedWatts(sysWatts),
                        subtitle: "Потребление системы"
                    )
                }
            } else {
                // РЕЖИМ 2 И 3: РАБОТА ОТ СЕТИ (Адаптер ➔ Система Mac + В батарею)
                VStack(spacing: 6) {
                    // Top Row: Adapter input total
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.orange.opacity(0.16))
                                .frame(width: 24, height: 24)
                            Image(systemName: "powerplug.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.orange)
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            Text("Адаптер питания")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                            Text("Входная мощность")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        Text(formattedWatts(adapterWatts))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 0.7)
                    )

                    // Split Destinations: Mac System & Battery Charge
                    HStack(spacing: 6) {
                        glassPowerNode(
                            icon: "laptopcomputer",
                            iconColor: .purple,
                            title: "Расход Mac",
                            watts: formattedWatts(sysWatts),
                            subtitle: "Питание системы"
                        )

                        glassPowerNode(
                            icon: isChg ? "bolt.batteryblock.fill" : "pause.circle.fill",
                            iconColor: isChg ? .green : .orange,
                            title: isChg ? "В батарею" : "Батарея",
                            watts: isChg ? "+\(formattedWatts(battWatts))" : "0,0 Вт",
                            subtitle: isChg ? "Идет на заряд" : "Обход (Пауза)"
                        )
                    }
                }
            }

            // Visual Power Split Bar
            if settings.menuShowPowerSplitBar {
                powerSplitProportionBar(isAC: isAC, isCharging: isChg, sysWatts: sysWatts, battWatts: battWatts)
            }
        }
    }

    private func glassPowerNode(
        icon: String,
        iconColor: Color,
        title: String,
        watts: String,
        subtitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(watts)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .monospacedDigit()

            Text(subtitle)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [iconColor.opacity(0.35), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
    }

    private func flowConnector(color: Color) -> some View {
        VStack(spacing: 2) {
            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(width: 18)
    }

    private func powerSplitProportionBar(isAC: Bool, isCharging: Bool, sysWatts: Double, battWatts: Double) -> some View {
        let total = max(0.5, isAC && isCharging ? (sysWatts + battWatts) : max(sysWatts, 30.0))
        let sysRatio = min(max(0.08, sysWatts / total), 1.0)
        let battRatio = isAC && isCharging ? min(max(0.08, battWatts / total), 1.0 - sysRatio) : 0.0

        return VStack(spacing: 3) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.85), .indigo],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * CGFloat(sysRatio)), height: 4)

                    if isAC && isCharging && battRatio > 0.01 {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.mint, .green],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, geo.size.width * CGFloat(battRatio)), height: 4)
                    } else {
                        Capsule(style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                            .frame(maxWidth: .infinity)
                            .frame(height: 4)
                    }
                }
            }
            .frame(height: 4)

            HStack {
                HStack(spacing: 4) {
                    Circle().fill(Color.purple).frame(width: 5, height: 5)
                    Text("Mac: \(formattedWatts(sysWatts))")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                if isAC && isCharging {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 5, height: 5)
                        Text("Заряд: +\(formattedWatts(battWatts))")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                } else {
                    Text(isAC ? "Батарея не расходуется" : "Питание от аккумулятора")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.top, 2)
    }

    // MARK: - 3. Fixed 4-Slot High Energy Apps Section
    private var highEnergyAppsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Энергоемкие приложения")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Топ 4")
                    .font(.system(size: 9.5, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
                    .foregroundStyle(.tertiary)
            }

            // Fixed 4 rows container so popover height NEVER jumps
            VStack(spacing: 4) {
                ForEach(Array(energyService.topFourSlots.prefix(4).enumerated()), id: \.offset) { _, app in
                    fixedAppRow(app: app)
                        .frame(height: 26)
                }
            }
            .frame(height: 26 * 4 + 4 * 3) // Strictly locked to 116pt
        }
    }

    private func fixedAppRow(app: HighEnergyApp) -> some View {
        HStack(spacing: 8) {
            if app.isPlaceholder {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: 18, height: 18)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.quaternary)
                    )

                Text(app.name)
                    .font(.system(size: 11))
                    .foregroundStyle(.quaternary)
                    .lineLimit(1)

                Spacer()
            } else {
                if let icon = energyService.appIcons[app.name] {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                }

                Text(app.name)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if settings.showCPUPercentageInMenu {
                    Text(String(format: "%.1f%%", app.cpuUsage).replacingOccurrences(of: ".", with: ","))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }

                Text(app.impact.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(app.impact == .low ? .secondary : app.impact.badgeColor)
                    .lineLimit(1)

                Image(systemName: app.impact.iconName)
                    .font(.system(size: 10.5))
                    .foregroundStyle(app.impact.badgeColor)
                    .frame(width: 13)
            }
        }
        .padding(.horizontal, 7)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(app.isPlaceholder ? Color.primary.opacity(0.015) : Color.primary.opacity(0.035))
        )
    }

    private func formattedWatts(_ watts: Double) -> String {
        let val = String(format: "%.1f", watts).replacingOccurrences(of: ".", with: ",")
        return "\(val) Вт"
    }

    private var glassDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.03),
                        Color.primary.opacity(0.14),
                        Color.white.opacity(0.03)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 0.8)
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

// MARK: - Native macOS 27 Glass Menu Item Row
public struct NativeMenuItem: View {
    public let title: String
    public var icon: String? = nil
    public var badgeText: String? = nil
    public var shortcut: String? = nil
    public var checkmark: Bool = false
    public let action: () -> Void

    @State private var isHovered: Bool = false

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    if checkmark {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(isHovered ? .white : Color.accentColor)
                    } else if let ic = icon {
                        Image(systemName: ic)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isHovered ? .white : .secondary)
                    }
                }
                .frame(width: 16)

                Text(title)
                    .font(.system(size: 12, weight: checkmark ? .semibold : .regular))
                    .foregroundStyle(isHovered ? .white : Color.primary)

                Spacer()

                if let badge = badgeText {
                    Text(badge)
                        .font(.system(size: 9.5, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isHovered ? Color.white.opacity(0.24) : Color.accentColor.opacity(0.16))
                        )
                        .foregroundStyle(isHovered ? .white : Color.accentColor)
                }

                if let sc = shortcut {
                    Text(sc)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isHovered ? Color.white.opacity(0.85) : Color.secondary)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        isHovered
                            ? LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isHovered ? Color.white.opacity(0.28) : Color.clear, lineWidth: 0.6)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = inside
            }
        }
    }
}
