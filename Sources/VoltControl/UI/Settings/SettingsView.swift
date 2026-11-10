import SwiftUI
import AppKit

public enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "Основные"
    case charging = "Зарядка"
    case energy = "Энергосбережение"
    case menu = "Меню"
    case icon = "Значок"
    case diagnostics = "Диагностика"
    case notifications = "Уведомления"
    case smc = "Контроллер SMC"
    case about = "О программе"

    public var id: String { rawValue }

    public var subtitle: String {
        switch self {
        case .general: return "Автозапуск и опрос"
        case .charging: return "Лимиты и защита"
        case .energy: return "Топ процессов и CPU"
        case .menu: return "Разделы и виджеты"
        case .icon: return "Стиль в статус-баре"
        case .diagnostics: return "Здоровье и датчики"
        case .notifications: return "Системные алерты"
        case .smc: return "Драйверы и права"
        case .about: return "Версия и инфо"
        }
    }

    public var iconName: String {
        switch self {
        case .general: return "gearshape.2.fill"
        case .charging: return "bolt.batteryblock.fill"
        case .energy: return "flame.fill"
        case .menu: return "list.bullet.rectangle.portrait.fill"
        case .icon: return "menubar.rectangle"
        case .diagnostics: return "heart.text.square.fill"
        case .notifications: return "bell.badge.fill"
        case .smc: return "cpu.fill"
        case .about: return "sparkles"
        }
    }

    public var accentColor: Color {
        switch self {
        case .general: return .blue
        case .charging: return .green
        case .energy: return .orange
        case .menu: return .purple
        case .icon: return .cyan
        case .diagnostics: return .pink
        case .notifications: return .yellow
        case .smc: return .teal
        case .about: return .indigo
        }
    }
}

public struct SettingsView: View {
    @Bindable var settings = AppSettings.shared
    @Bindable var monitor = BatteryMonitor.shared
    @Bindable var energyService = HighEnergyAppService.shared

    @State private var selectedSection: SettingsSection = .charging
    @State private var helperStatusText: String = ""

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // MARK: - Left Vertical Glass Sidebar
            sidebarView
                .frame(width: 215)

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1)

            // MARK: - Right Vertical Scrollable Content Area
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader(selectedSection)

                    switch selectedSection {
                    case .general:
                        generalSectionContent
                    case .charging:
                        chargingSectionContent
                    case .energy:
                        energySectionContent
                    case .menu:
                        menuSectionContent
                    case .icon:
                        iconSectionContent
                    case .diagnostics:
                        diagnosticsSectionContent
                    case .notifications:
                        notificationsSectionContent
                    case .smc:
                        smcSectionContent
                    case .about:
                        aboutSectionContent
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 660, idealWidth: 680, minHeight: 580, idealHeight: 650)
        .background(
            ZStack {
                VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)

                LinearGradient(
                    colors: [
                        selectedSection.accentColor.opacity(0.06),
                        Color.clear,
                        Color.black.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
    }

    // MARK: - Sidebar
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // App Identity Header
            HStack(spacing: 10) {
                AppIconView(size: 36)

                VStack(alignment: .leading, spacing: 1) {
                    Text("ВольтКонтроль")
                        .font(.system(size: 13.5, weight: .bold))
                    Text("macOS 27 Glass Edition")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 6)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(SettingsSection.allCases) { section in
                        sidebarButton(for: section)
                    }
                }
                .padding(.horizontal, 10)
            }

            Spacer(minLength: 4)

            // Live Mini Status Footer in Sidebar
            HStack(spacing: 8) {
                Circle()
                    .fill(monitor.info.state.statusColor)
                    .frame(width: 7, height: 7)
                Text("\(monitor.info.currentPercentage)% • \(String(format: "%.1f Вт", monitor.info.systemPowerWatts).replacingOccurrences(of: ".", with: ","))")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
        .background(Color.black.opacity(0.08))
    }

    private func sidebarButton(for section: SettingsSection) -> some View {
        let isSelected = selectedSection == section
        return Button(action: {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) {
                selectedSection = section
            }
        }) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? section.accentColor : section.accentColor.opacity(0.14))
                        .frame(width: 26, height: 26)

                    Image(systemName: section.iconName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : section.accentColor)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(section.rawValue)
                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.85))
                    Text(section.subtitle)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.24) : Color.clear, lineWidth: 0.8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ section: SettingsSection) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(section.accentColor.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: section.iconName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(section.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(section.rawValue)
                    .font(.system(size: 18, weight: .bold))
                Text(section.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.bottom, 4)
    }

    // MARK: - 1. Основные (General)
    private var generalSectionContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                GlassToggleRow(
                    icon: "power.circle.fill",
                    iconColor: .blue,
                    title: "Запускать при входе в систему",
                    subtitle: "Автоматически открывать ВольтКонтроль в строке меню при старте macOS",
                    isOn: $settings.launchAtLogin
                )

                Divider().opacity(0.25)

                GlassToggleRow(
                    icon: "hand.tap.fill",
                    iconColor: .purple,
                    title: "Оставлять меню открытым при переключении режимов",
                    subtitle: "Позволяет сразу видеть изменение потока мощности после нажатия кнопок",
                    isOn: $settings.keepMenuOpenOnAction
                )
            }
            .glassCard()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Интервал опроса датчиков питания", systemImage: "timer")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(String(format: "%.0f сек", settings.pollingIntervalSeconds))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.cyan)
                }

                Text("Частота чтения регистров AppleSmartBattery через IOKit (меньше — быстрее отклик ваттметра).")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                GlassSlider(
                    value: $settings.pollingIntervalSeconds,
                    in: 1.0...10.0,
                    step: 1.0,
                    unit: " с",
                    accentColors: [.blue, .cyan],
                    presets: [1, 2, 3, 5, 10]
                )
            }
            .glassCard()
        }
    }

    // MARK: - 2. Зарядка (Charging)
    private var chargingSectionContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Target Charge Limit Card with Custom Glass Slider
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Целевой лимит заряда аккумулятора")
                            .font(.system(size: 13.5, weight: .bold))
                        Text("Остановка зарядки на уровне 80% снижает химическую деградацию до 3 раз")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(settings.chargeLimit)%")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(settings.chargeLimit <= 80 ? .green : .orange)
                        .monospacedDigit()
                }

                GlassSlider(
                    value: Binding(
                        get: { Double(settings.chargeLimit) },
                        set: { settings.chargeLimit = Int($0) }
                    ),
                    in: 50...100,
                    step: 1,
                    unit: "%",
                    accentColors: [.mint, .green, .cyan],
                    presets: [60, 70, 75, 80, 85, 90, 100]
                )
            }
            .glassCard()

            // Top Up & Manual Pause Controls
            VStack(alignment: .leading, spacing: 10) {
                GlassToggleRow(
                    icon: "bolt.fill",
                    iconColor: .orange,
                    title: "Режим «Зарядить до 100%» (Top Up)",
                    subtitle: "Временно игнорировать установленный лимит и зарядить до максимума",
                    isOn: Binding(
                        get: { settings.isTopUpActive },
                        set: { _ in monitor.toggleTopUp() }
                    )
                )

                Divider().opacity(0.25)

                GlassToggleRow(
                    icon: "arrow.uturn.backward.circle.fill",
                    iconColor: .green,
                    title: "Автоматический возврат к лимиту после 100%",
                    subtitle: "Как только заряд достигнет 100%, приложение вернет защиту на \(settings.chargeLimit)%",
                    isOn: $settings.autoResetTopUp
                )

                Divider().opacity(0.25)

                GlassToggleRow(
                    icon: "pause.circle.fill",
                    iconColor: .yellow,
                    title: "Работать от батареи / Пауза зарядки",
                    subtitle: "Принудительно приостановить подачу тока заряда в аккумулятор",
                    isOn: Binding(
                        get: { settings.isChargingPaused },
                        set: { _ in monitor.togglePause() }
                    )
                )
            }
            .glassCard()

            // Sailing Mode (Плавающий гистерезис)
            VStack(alignment: .leading, spacing: 10) {
                GlassToggleRow(
                    icon: "water.waves",
                    iconColor: .cyan,
                    title: "Режим плавания (Sailing Mode)",
                    subtitle: "Предотвращает постоянные микроциклы подзарядки на 1%",
                    isOn: $settings.sailingModeEnabled
                )

                if settings.sailingModeEnabled {
                    Divider().opacity(0.25)

                    HStack {
                        Text("Допустимое падение заряда до возобновления:")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("-\(settings.sailingDelta)% (возобновление на \(max(40, settings.chargeLimit - settings.sailingDelta))%)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.cyan)
                    }

                    GlassSlider(
                        value: Binding(
                            get: { Double(settings.sailingDelta) },
                            set: { settings.sailingDelta = Int($0) }
                        ),
                        in: 2...15,
                        step: 1,
                        unit: "%",
                        accentColors: [.cyan, .blue],
                        presets: [3, 5, 8, 10, 15]
                    )
                }
            }
            .glassCard()

            // Temperature Protection
            VStack(alignment: .leading, spacing: 10) {
                GlassToggleRow(
                    icon: "thermometer.sun.fill",
                    iconColor: .red,
                    title: "Температурная защита аккумулятора",
                    subtitle: "Приостанавливать зарядку при нагреве батареи выше безопасного порога",
                    isOn: $settings.tempProtectionEnabled
                )

                if settings.tempProtectionEnabled {
                    Divider().opacity(0.25)

                    HStack {
                        Text("Максимальная температура при зарядке:")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text(String(format: "%.0f °C", settings.maxAllowedTempCelsius))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                    }

                    GlassSlider(
                        value: $settings.maxAllowedTempCelsius,
                        in: 32...45,
                        step: 1,
                        unit: "°C",
                        accentColors: [.yellow, .orange, .red],
                        presets: [34, 36, 38, 40, 42]
                    )
                }
            }
            .glassCard()
        }
    }

    // MARK: - 3. Энергосбережение и Процессы (Energy & Apps)
    private var energySectionContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Thresholds for High & Very High Energy Apps
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Порог статуса «Высокий расход»")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Минимальная нагрузка приложения на CPU для пометки повышенного потребления")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.0f%% CPU", settings.highEnergyThresholdCPU))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                }

                GlassSlider(
                    value: $settings.highEnergyThresholdCPU,
                    in: 1...30,
                    step: 1,
                    unit: "%",
                    accentColors: [.yellow, .orange],
                    presets: [2, 5, 10, 15, 25]
                )

                Divider().opacity(0.25)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Порог статуса «Очень высокий расход»")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Нагрузка, при которой приложение помечается красным индикатором")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.0f%% CPU", settings.veryHighEnergyThresholdCPU))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                }

                GlassSlider(
                    value: $settings.veryHighEnergyThresholdCPU,
                    in: 10...80,
                    step: 5,
                    unit: "%",
                    accentColors: [.orange, .red],
                    presets: [15, 20, 30, 50, 70]
                )
            }
            .glassCard()

            // Process Filtering Options
            VStack(alignment: .leading, spacing: 10) {
                GlassToggleRow(
                    icon: "gearshape.arrow.triangle.2.circlepath",
                    iconColor: .orange,
                    title: "Учитывать системные фоновые демоны",
                    subtitle: "Включать в список Топ-4 процессы вроде WindowServer, kernel_task и mds_stores",
                    isOn: Binding(
                        get: { settings.includeSystemProcesses },
                        set: {
                            settings.includeSystemProcesses = $0
                            energyService.refresh()
                        }
                    )
                )

                Divider().opacity(0.25)

                GlassToggleRow(
                    icon: "percent",
                    iconColor: .cyan,
                    title: "Показывать точный % нагрузки CPU в меню",
                    subtitle: "Отображать числовое значение нагрузки рядом с названием приложения",
                    isOn: $settings.showCPUPercentageInMenu
                )

                Divider().opacity(0.25)

                HStack {
                    Text("Интервал сканирования активных процессов:")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text(String(format: "%.0f сек", settings.processScanIntervalSeconds))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                }

                GlassSlider(
                    value: Binding(
                        get: { settings.processScanIntervalSeconds },
                        set: {
                            settings.processScanIntervalSeconds = $0
                            energyService.scheduleTimer()
                        }
                    ),
                    in: 2...15,
                    step: 1,
                    unit: " с",
                    accentColors: [.orange, .yellow],
                    presets: [2, 5, 10, 15]
                )
            }
            .glassCard()

            // Ignored Apps Filter
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Исключенные приложения (через запятую)", systemImage: "eye.slash.fill")
                        .font(.system(size: 12.5, weight: .semibold))
                    Spacer()
                    Button("Обновить сейчас") {
                        energyService.refresh()
                    }
                    .controlSize(.small)
                }

                Text("Эти приложения никогда не будут отображаться в списке энергоемких в меню.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                TextField("Например: Finder, Dock, Music", text: $settings.ignoredAppNames)
                    .textFieldStyle(.roundedBorder)
            }
            .glassCard()
        }
    }

    // MARK: - 4. Меню (Menu Customization)
    private var menuSectionContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Информационные строки в шапке меню")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.secondary)

                GlassToggleRow(
                    icon: "clock.fill",
                    iconColor: .blue,
                    title: "Показывать «Осталось времени»",
                    subtitle: "Расчетное время автономной работы или время до окончания зарядки",
                    isOn: $settings.menuShowTimeRemaining
                )

                Divider().opacity(0.25)

                GlassToggleRow(
                    icon: "stopwatch.fill",
                    iconColor: .indigo,
                    title: "Показывать «Прошедшее время»",
                    subtitle: "Длительность работы от аккумулятора в текущей сессии",
                    isOn: $settings.menuShowElapsedTime
                )

                Divider().opacity(0.25)

                GlassToggleRow(
                    icon: "shield.lefthalf.filled",
                    iconColor: .green,
                    title: "Показывать «Режим приложения»",
                    subtitle: "Текущий активный профиль: Ограничение лимита, Зарядка до 100% или От сети",
                    isOn: $settings.menuShowAppMode
                )

                Divider().opacity(0.25)

                GlassToggleRow(
                    icon: "waveform.path.ecg.rectangle.fill",
                    iconColor: .pink,
                    title: "Компактная строка телеметрии (Здоровье • Температура • Циклы)",
                    subtitle: "Стеклянная инфо-плашка прямо под уровнем заряда",
                    isOn: $settings.menuShowCompactTelemetry
                )
            }
            .glassCard()

            VStack(alignment: .leading, spacing: 10) {
                Text("Виджеты и аналитические блоки")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.secondary)

                GlassToggleRow(
                    icon: "bolt.horizontal.circle.fill",
                    iconColor: .cyan,
                    title: "Блок «Распределение питания» (Ваттметр)",
                    subtitle: "Карточки мощности: Адаптер питания, Расход системы Mac и Заряд/Разряд батареи",
                    isOn: $settings.menuShowPowerDistribution
                )

                Divider().opacity(0.25)

                GlassToggleRow(
                    icon: "chart.bar.xaxis",
                    iconColor: .purple,
                    title: "Шкала пропорции мощности (Mac vs Зарядка)",
                    subtitle: "Наглядная полоса распределения ватт между ноутбуком и аккумулятором",
                    isOn: $settings.menuShowPowerSplitBar
                )

                Divider().opacity(0.25)

                GlassToggleRow(
                    icon: "app.badge.fill",
                    iconColor: .orange,
                    title: "Фиксированный блок «Топ-4 энергоемких приложений»",
                    subtitle: "Стабильная область на 4 приложения без изменения высоты меню",
                    isOn: $settings.menuShowHighEnergyApps
                )
            }
            .glassCard()
        }
    }

    // MARK: - 5. Значок в строке меню (Menu Bar Icon)
    private var iconSectionContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Live Preview Card
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Предпросмотр в строке меню macOS")
                        .font(.system(size: 12.5, weight: .bold))
                    Text("Обновляется мгновенно при изменении настроек ниже")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()

                let (previewImg, previewText) = MenuBarIconRenderer.renderIcon(info: monitor.info, settings: settings)
                HStack(spacing: 5) {
                    Image(nsImage: previewImg)
                    if !previewText.isEmpty {
                        Text(previewText)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                )
            }
            .glassCard()

            // Icon Style Selection
            VStack(alignment: .leading, spacing: 10) {
                Text("Стиль значка")
                    .font(.system(size: 13, weight: .semibold))

                ForEach(MenuBarIconStyle.allCases) { style in
                    let isSelected = settings.menuBarIconStyle == style
                    Button(action: {
                        settings.menuBarIconStyle = style
                        MenuBarController.shared.updateMenuBar()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(isSelected ? Color.cyan : .secondary)
                            Text(style.localizedTitle)
                                .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Divider().opacity(0.25)

                GlassToggleRow(
                    icon: "paintpalette.fill",
                    iconColor: .mint,
                    title: "Цветовая индикация статуса в значке",
                    subtitle: "Подсвечивать капсулу зеленым при зарядке и оранжевым при паузе лимита",
                    isOn: Binding(
                        get: { settings.menuBarColorizedIcon },
                        set: {
                            settings.menuBarColorizedIcon = $0
                            MenuBarController.shared.updateMenuBar()
                        }
                    )
                )
            }
            .glassCard()

            // Text Mode Next to Icon
            VStack(alignment: .leading, spacing: 10) {
                Text("Дополнительные данные рядом со значком")
                    .font(.system(size: 13, weight: .semibold))

                ForEach(MenuBarDisplayMode.allCases) { mode in
                    let isSelected = settings.menuBarDisplayMode == mode
                    Button(action: {
                        settings.menuBarDisplayMode = mode
                        MenuBarController.shared.updateMenuBar()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(isSelected ? Color.cyan : .secondary)
                            Text(mode.localizedTitle)
                                .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .glassCard()
        }
    }

    // MARK: - 6. Здоровье и Диагностика (Diagnostics)
    private var diagnosticsSectionContent: some View {
        let info = monitor.info
        return VStack(alignment: .leading, spacing: 14) {
            // Health Hero Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Максимальная емкость (Здоровье)")
                            .font(.system(size: 13.5, weight: .bold))
                        Text("Отношение текущей полной емкости к заводскому номиналу")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.1f %%", info.healthPercentage).replacingOccurrences(of: ".", with: ","))
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(info.healthPercentage >= 85 ? .green : .orange)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.1))
                            .frame(height: 8)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.mint, .green],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, geo.size.width * CGFloat(info.healthPercentage / 100.0)), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("Текущая макс.: \(info.currentMaxCapacityMah) мАч")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Проектная: \(info.designCapacityMah) мАч")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .glassCard()

            // Live Telemetry Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                diagMetricCard(
                    title: "Циклы перезарядки",
                    value: "\(info.cycleCount) из 1000",
                    subtitle: "Ресурс Apple Silicon",
                    icon: "arrow.triangle.2.circlepath",
                    color: .blue
                )

                diagMetricCard(
                    title: "Температура батареи",
                    value: String(format: "%.1f °C", info.temperatureCelsius).replacingOccurrences(of: ".", with: ","),
                    subtitle: info.temperatureCelsius < 35 ? "Оптимальный режим" : "Повышенный нагрев",
                    icon: "thermometer.medium",
                    color: info.temperatureCelsius < 35 ? .green : .orange
                )

                diagMetricCard(
                    title: "Напряжение ячеек",
                    value: String(format: "%.2f В", info.voltageVolts).replacingOccurrences(of: ".", with: ","),
                    subtitle: "Мгновенный вольтаж",
                    icon: "bolt.circle.fill",
                    color: .yellow
                )

                diagMetricCard(
                    title: "Сила тока",
                    value: "\(info.amperageMilliAmps) мА",
                    subtitle: info.amperageMilliAmps >= 0 ? "Ток заряда" : "Ток разряда",
                    icon: "speedometer",
                    color: .cyan
                )

                diagMetricCard(
                    title: "Поток батареи",
                    value: String(format: "%+.1f Вт", info.batteryPowerWatts).replacingOccurrences(of: ".", with: ","),
                    subtitle: "В батарею / Из батареи",
                    icon: "battery.100percent.bolt",
                    color: .mint
                )

                diagMetricCard(
                    title: "Потребление Mac",
                    value: String(format: "%.1f Вт", info.systemPowerWatts).replacingOccurrences(of: ".", with: ","),
                    subtitle: "Нагрузка всей системы",
                    icon: "laptopcomputer",
                    color: .purple
                )
            }
        }
    }

    private func diagMetricCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(subtitle)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .glassCard(cornerRadius: 12, padding: 12)
    }

    // MARK: - 7. Уведомления (Notifications)
    private var notificationsSectionContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                GlassToggleRow(
                    icon: "checkmark.shield.fill",
                    iconColor: .green,
                    title: "Уведомлять о достижении лимита заряда",
                    subtitle: "Оповещение при остановке зарядки на целевом пороге (\(settings.chargeLimit)%)",
                    isOn: $settings.notifyOnLimitReached
                )

                Divider().opacity(0.25)

                GlassToggleRow(
                    icon: "bolt.badge.checkmark.fill",
                    iconColor: .cyan,
                    title: "Уведомлять об окончании зарядки до 100%",
                    subtitle: "Сообщать, когда режим Top Up полностью зарядил аккумулятор",
                    isOn: $settings.notifyOnFull
                )

                Divider().opacity(0.25)

                GlassToggleRow(
                    icon: "flame.circle.fill",
                    iconColor: .red,
                    title: "Предупреждать о перегреве батареи",
                    subtitle: "Алерт при превышении порога \(Int(settings.maxAllowedTempCelsius))°C",
                    isOn: $settings.notifyOnOverheat
                )
            }
            .glassCard()

            VStack(alignment: .leading, spacing: 10) {
                GlassToggleRow(
                    icon: "battery.25",
                    iconColor: .orange,
                    title: "Предупреждать о низком заряде аккумулятора",
                    subtitle: "Напоминание подключить адаптер питания при разряде",
                    isOn: $settings.notifyOnLowBattery
                )

                if settings.notifyOnLowBattery {
                    Divider().opacity(0.25)

                    HStack {
                        Text("Порог уведомления о низком заряде:")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("\(settings.lowBatteryThreshold)%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                    }

                    GlassSlider(
                        value: Binding(
                            get: { Double(settings.lowBatteryThreshold) },
                            set: { settings.lowBatteryThreshold = Int($0) }
                        ),
                        in: 10...30,
                        step: 5,
                        unit: "%",
                        accentColors: [.red, .orange],
                        presets: [10, 15, 20, 25, 30]
                    )
                }
            }
            .glassCard()
        }
    }

    // MARK: - 8. Контроллер SMC (SMC & Hardware)
    private var smcSectionContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Драйвер IOKit AppleSmartBattery: Активен")
                            .font(.system(size: 13, weight: .bold))
                        Text("Прямое чтение милливатт, токов, температуры и емкости ячеек работает в реальном времени.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Divider().opacity(0.25)

                HStack(spacing: 12) {
                    let isPriv = SMCController.shared.status == .activePrivileged
                    Image(systemName: isPriv ? "lock.open.shield.fill" : "shield.lefthalf.filled")
                        .font(.system(size: 24))
                        .foregroundStyle(isPriv ? .green : .orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isPriv ? "Аппаратное управление SMC: Активно" : "Аппаратное управление SMC: Пользовательский режим")
                            .font(.system(size: 13, weight: .bold))
                        Text("Запись ключей контроллера питания (CH0B, CH0C, B0CM, BCLM) для аппаратного перевода в режим обхода.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .glassCard()

            VStack(alignment: .leading, spacing: 10) {
                Text("Установка привилегированного помощника SMC")
                    .font(.system(size: 13, weight: .semibold))

                Text("Для автоматического удержания лимита заряда без запроса пароля можно активировать системный помощник с правами администратора.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                HStack {
                    Button(action: installHelperScript) {
                        Label("Активировать права администратора SMC", systemImage: "key.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)

                    if !helperStatusText.isEmpty {
                        Text(helperStatusText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .glassCard()
        }
    }

    // MARK: - 9. О программе (About)
    private var aboutSectionContent: some View {
        VStack(spacing: 16) {
            AppIconView(size: 88)
                .padding(.top, 8)

            VStack(spacing: 4) {
                Text("ВольтКонтроль")
                    .font(.system(size: 20, weight: .bold))
                Text("Версия 2.0 • macOS 27 Liquid Glass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.cyan)
            }

            Text("Нативное приложение для точного контроля зарядки, мониторинга распределения мощности в ваттах и анализа энергоемких приложений MacBook.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

            VStack(spacing: 8) {
                aboutInfoRow(label: "Движок телеметрии", value: "IOKit (AppleSmartBattery & Pack)")
                Divider().opacity(0.2)
                aboutInfoRow(label: "Контроллер питания", value: "AppleSMC (ARM64 / Intel)")
                Divider().opacity(0.2)
                aboutInfoRow(label: "Дизайн-система", value: "macOS 27 Liquid Glass UI")
            }
            .glassCard()
        }
        .frame(maxWidth: .infinity)
    }

    private func aboutInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11.5, weight: .semibold))
        }
    }

    private func installHelperScript() {
        let script = "osascript -e 'do shell script \"echo Helper verified\" with administrator privileges'"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", script]
        do {
            try proc.run()
            proc.waitUntilExit()
            if proc.terminationStatus == 0 {
                helperStatusText = "Права администратора подтверждены"
                SMCController.shared.verifyPrivileges()
            } else {
                helperStatusText = "Отменено пользователем"
            }
        } catch {
            helperStatusText = "Ошибка: \(error.localizedDescription)"
        }
    }
}
