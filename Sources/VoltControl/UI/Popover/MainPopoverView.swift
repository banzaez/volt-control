import SwiftUI
import AppKit

public struct MainPopoverView: View {
    @Bindable var monitor = BatteryMonitor.shared
    @Bindable var settings = AppSettings.shared
    @Bindable var energyService = HighEnergyAppService.shared

    public let onOpenSettings: () -> Void
    public let onQuit: () -> Void

    @State private var isDetailsExpanded: Bool = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - 1. Top Section (Аккумулятор, Осталось, Прошедшее, Режим)
            VStack(spacing: 5) {
                // Row 1: Аккумулятор & %
                HStack {
                    Text("Аккумулятор")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    Text("\(monitor.info.currentPercentage) %")
                        .font(.system(size: 13, weight: .bold))
                }

                // Row 2: Осталось времени
                HStack {
                    Text("Осталось времени")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(monitor.info.timeRemainingFormatted)
                        .font(.system(size: 12))
                }

                // Row 3: Прошедшее время
                HStack {
                    Text("Прошедшее время")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(monitor.info.elapsedTimeFormatted)
                        .font(.system(size: 12))
                }

                // Row 4: Режим приложения
                HStack(alignment: .top) {
                    Text("Режим\nприложения")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(monitor.info.appModeDescription)
                        .font(.system(size: 12))
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            menuDivider

            // MARK: - 2. Распределение питания
            VStack(alignment: .leading, spacing: 8) {
                Text("Распределение питания")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                powerDistributionRow
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            menuDivider

            // MARK: - 3. Приложения с высоким энергопотреблением
            VStack(alignment: .leading, spacing: 6) {
                Text("Приложения с высоким\nэнергопотреблением")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                if energyService.apps.isEmpty {
                    Text("Нет приложений с высоким потреблением")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 2)
                } else {
                    ForEach(energyService.apps) { app in
                        HStack(spacing: 8) {
                            if let icon = energyService.appIcons[app.name] {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 18, height: 18)
                            } else {
                                Image(systemName: "app.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }

                            Text(app.name)
                                .font(.system(size: 12))
                                .lineLimit(1)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 0) {
                                if app.energyLevel.contains(" ") {
                                    let parts = app.energyLevel.split(separator: " ")
                                    Text(parts[0])
                                    Text(parts[1])
                                } else {
                                    Text(app.energyLevel)
                                }
                            }
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)

                            Image(systemName: "gauge.with.needle")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            menuDivider

            // MARK: - 4. Интерактивные пункты меню
            VStack(spacing: 1) {
                // Зарядить до 100%
                NativeMenuItem(
                    title: "Зарядить до 100%",
                    checkmark: settings.isTopUpActive,
                    action: {
                        monitor.toggleTopUp()
                    }
                )

                // Работать от батареи (Пауза)
                NativeMenuItem(
                    title: "Работать от батареи",
                    checkmark: settings.isChargingPaused,
                    action: {
                        monitor.togglePause()
                    }
                )

                menuDivider.padding(.horizontal, 6).padding(.vertical, 2)

                // Ещё > (раскрывает аналитику: здоровье, циклы, температура)
                NativeMenuItem(
                    title: "Ещё",
                    hasSubmenuArrow: true,
                    isSubmenuOpen: isDetailsExpanded,
                    action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isDetailsExpanded.toggle()
                        }
                    }
                )

                if isDetailsExpanded {
                    expandedDetailsView
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Настройки... ⌘,
                NativeMenuItem(
                    title: "Настройки...",
                    shortcut: "⌘,",
                    action: {
                        onOpenSettings()
                    }
                )

                menuDivider.padding(.horizontal, 6).padding(.vertical, 2)

                // Завершить ВольтКонтроль ⌘Q
                NativeMenuItem(
                    title: "Завершить ВольтКонтроль",
                    shortcut: "⌘Q",
                    action: {
                        onQuit()
                    }
                )
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
        .frame(width: 275)
        .background(VisualEffectBlur(material: .popover, blendingMode: .behindWindow))
    }

    // MARK: - Power Distribution Row
    @ViewBuilder
    private var powerDistributionRow: some View {
        let isAC = monitor.info.isACConnected
        let isChg = monitor.info.isCharging && monitor.info.batteryPowerWatts > 0.1

        HStack(spacing: 6) {
            if !isAC {
                // On Battery: [ 🔋 3,7 Вт ] ➔ [ 💻 3,7 Вт ]
                pill(icon: "battery.100", text: formattedWatts(abs(monitor.info.batteryPowerWatts)))
                arrowView
                pill(icon: "laptopcomputer", text: formattedWatts(monitor.info.systemPowerWatts))
            } else if isChg {
                // AC Charging: [ 🔌 45,0 Вт ] ➔ [ 💻 15,0 Вт ] + [ 🔋 30,0 Вт ]
                pill(icon: "powerplug.fill", text: formattedWatts(monitor.info.adapterPowerWatts))
                arrowView
                pill(icon: "laptopcomputer", text: formattedWatts(monitor.info.systemPowerWatts))
                Text("+")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                pill(icon: "battery.100", text: formattedWatts(monitor.info.batteryPowerWatts))
            } else {
                // AC Bypass / Paused: [ 🔌 12,5 Вт ] ➔ [ 💻 12,5 Вт ]
                pill(icon: "powerplug.fill", text: formattedWatts(monitor.info.adapterPowerWatts > 0 ? monitor.info.adapterPowerWatts : monitor.info.systemPowerWatts))
                arrowView
                pill(icon: "laptopcomputer", text: formattedWatts(monitor.info.systemPowerWatts))
            }
        }
    }

    private func pill(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }

    private var arrowView: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func formattedWatts(_ watts: Double) -> String {
        let val = String(format: "%.1f", watts).replacingOccurrences(of: ".", with: ",")
        return "\(val) Вт"
    }

    private var menuDivider: some View {
        Divider()
            .opacity(0.35)
    }

    // MARK: - Expanded Details View (Ещё >)
    private var expandedDetailsView: some View {
        VStack(spacing: 4) {
            detailRow(title: "Здоровье аккумулятора", value: String(format: "%.1f %%", monitor.info.healthPercentage))
            detailRow(title: "Емкость батареи", value: "\(monitor.info.currentMaxCapacityMah) / \(monitor.info.designCapacityMah) мАч")
            detailRow(title: "Циклы зарядки", value: "\(monitor.info.cycleCount)")
            detailRow(title: "Температура", value: String(format: "%.1f °C", monitor.info.temperatureCelsius))
            detailRow(title: "Напряжение", value: String(format: "%.2f В", monitor.info.voltageVolts))
            detailRow(title: "Сила тока", value: "\(monitor.info.amperageMilliAmps) мА")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .rounded))
        }
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

public struct NativeMenuItem: View {
    public let title: String
    public var shortcut: String? = nil
    public var checkmark: Bool = false
    public var hasSubmenuArrow: Bool = false
    public var isSubmenuOpen: Bool = false
    public let action: () -> Void

    @State private var isHovered: Bool = false

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // Checkmark space
                if checkmark {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isHovered ? .white : Color.primary)
                        .frame(width: 14)
                } else {
                    Spacer()
                        .frame(width: 14)
                }

                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(isHovered ? .white : Color.primary)

                Spacer()

                if let sc = shortcut {
                    Text(sc)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isHovered ? Color.white.opacity(0.8) : Color.secondary)
                }

                if hasSubmenuArrow {
                    Image(systemName: isSubmenuOpen ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isHovered ? Color.white.opacity(0.8) : Color.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
