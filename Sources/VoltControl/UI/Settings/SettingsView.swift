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
        case .general: return "Автозапуск и опрос датчиков"
        case .charging: return "Лимиты заряда и защита батареи"
        case .energy: return "Мониторинг нагрузки процессов"
        case .menu: return "Отображаемые строки и блоки"
        case .icon: return "Вид иконки в строке меню"
        case .diagnostics: return "Здоровье, циклы и датчики"
        case .notifications: return "Системные уведомления"
        case .smc: return "Статус драйверов IOKit и SMC"
        case .about: return "Информация о приложении"
        }
    }

    public var iconName: String {
        switch self {
        case .general: return "gearshape"
        case .charging: return "bolt.batteryblock"
        case .energy: return "gauge.with.dots.needle.67percent"
        case .menu: return "list.bullet.rectangle"
        case .icon: return "menubar.rectangle"
        case .diagnostics: return "waveform.path.ecg.rectangle"
        case .notifications: return "bell"
        case .smc: return "cpu"
        case .about: return "info.circle"
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
            // MARK: - Left Sidebar (Standard macOS Settings Sidebar)
            sidebarView
                .frame(width: 200)

            Divider()

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
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 640, idealWidth: 660, minHeight: 560, idealHeight: 620)
    }

    // MARK: - Sidebar
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                AppIconView(size: 30)

                VStack(alignment: .leading, spacing: 1) {
                    Text("VoltControl")
                        .font(.system(size: 13, weight: .semibold))
                    Text("\(monitor.info.currentPercentage)% • \(String(format: "%.1f Вт", monitor.info.systemPowerWatts).replacingOccurrences(of: ".", with: ","))")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 6)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(SettingsSection.allCases) { section in
                        sidebarButton(for: section)
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer()
        }
        .background(VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow))
    }

    private func sidebarButton(for section: SettingsSection) -> some View {
        let isSelected = selectedSection == section
        return Button(action: {
            selectedSection = section
        }) {
            HStack(spacing: 9) {
                Image(systemName: section.iconName)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .frame(width: 18, alignment: .center)

                Text(section.rawValue)
                    .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(Color.primary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6.5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.10) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ section: SettingsSection) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(section.rawValue)
                .font(.system(size: 16, weight: .semibold))
            Text(section.subtitle)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 2)
    }

    // MARK: - 1. Основные (General)
    private var generalSectionContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                GlassToggleRow(
                    icon: "power",
                    title: "Запускать при входе в систему",
                    subtitle: "Автоматически открывать VoltControl в строке меню при старте macOS",
                    isOn: $settings.launchAtLogin
                )

                Divider().opacity(0.35)

                GlassToggleRow(
                    icon: "menubar.arrow.up.rectangle",
                    title: "Оставлять меню открытым при переключении режимов",
                    subtitle: "Позволяет сразу видеть изменение потока мощности после нажатия кнопок",
                    isOn: $settings.keepMenuOpenOnAction
                )
            }
            .glassCard()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Интервал опроса датчиков питания")
                        .font(.system(size: 12.5, weight: .medium))
                    Spacer()
                    Text(String(format: "%.0f сек", settings.pollingIntervalSeconds))
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }

                Text("Частота чтения регистров AppleSmartBattery и SMC (меньше — быстрее отклик ваттметра).")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                GlassSlider(
                    value: $settings.pollingIntervalSeconds,
                    in: 1.0...10.0,
                    step: 1.0,
                    unit: " с",
                    presets: [1, 2, 3, 5, 10]
                )
            }
            .glassCard()
        }
    }

    // MARK: - 2. Зарядка (Charging)
    private var chargingSectionContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Целевой лимит заряда аккумулятора")
                            .font(.system(size: 13, weight: .medium))
                        Text("Остановка зарядки на уровне 80% замедляет химическое старение батареи")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(settings.chargeLimit)%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
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
                    presets: [60, 70, 75, 80, 85, 90, 100]
                )
            }
            .glassCard()

            VStack(alignment: .leading, spacing: 10) {
                GlassToggleRow(
                    icon: "bolt",
                    title: "Зарядить до 100% (Top Up)",
                    subtitle: "Временно игнорировать установленный лимит и зарядить до максимума",
                    isOn: Binding(
                        get: { settings.isTopUpActive },
                        set: { _ in monitor.toggleTopUp() }
                    )
                )

                Divider().opacity(0.35)

                GlassToggleRow(
                    icon: "arrow.uturn.backward",
                    title: "Автоматический возврат к лимиту после 100%",
                    subtitle: "После достижения 100% автоматически вернуть ограничение \(settings.chargeLimit)%",
                    isOn: $settings.autoResetTopUp
                )

                Divider().opacity(0.35)

                GlassToggleRow(
                    icon: "pause",
                    title: "Работать от батареи / Пауза зарядки",
                    subtitle: "Принудительно приостановить подачу тока заряда в аккумулятор",
                    isOn: Binding(
                        get: { settings.isChargingPaused },
                        set: { _ in monitor.togglePause() }
                    )
                )
            }
            .glassCard()

            VStack(alignment: .leading, spacing: 10) {
                GlassToggleRow(
                    icon: "water.waves",
                    title: "Режим плавания (Sailing Mode)",
                    subtitle: "Предотвращает частые микроциклы подзарядки на 1%",
                    isOn: $settings.sailingModeEnabled
                )

                if settings.sailingModeEnabled {
                    Divider().opacity(0.35)

                    HStack {
                        Text("Допустимое падение заряда до возобновления:")
                            .font(.system(size: 12))
                        Spacer()
                        Text("-\(settings.sailingDelta)% (до \(max(40, settings.chargeLimit - settings.sailingDelta))%)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }

                    GlassSlider(
                        value: Binding(
                            get: { Double(settings.sailingDelta) },
                            set: { settings.sailingDelta = Int($0) }
                        ),
                        in: 2...15,
                        step: 1,
                        unit: "%",
                        presets: [3, 5, 8, 10, 15]
                    )
                }
            }
            .glassCard()

            VStack(alignment: .leading, spacing: 10) {
                GlassToggleRow(
                    icon: "thermometer.medium",
                    title: "Температурная защита аккумулятора",
                    subtitle: "Приостанавливать зарядку при нагреве батареи выше порога",
                    isOn: $settings.tempProtectionEnabled
                )

                if settings.tempProtectionEnabled {
                    Divider().opacity(0.35)

                    HStack {
                        Text("Максимальная температура при зарядке:")
                            .font(.system(size: 12))
                        Spacer()
                        Text(String(format: "%.0f °C", settings.maxAllowedTempCelsius))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }

                    GlassSlider(
                        value: $settings.maxAllowedTempCelsius,
                        in: 32...45,
                        step: 1,
                        unit: "°C",
                        presets: [34, 36, 38, 40, 42]
                    )
                }
            }
            .glassCard()
        }
    }

    // MARK: - 3. Энергосбережение (Energy & Apps)
    private var energySectionContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Порог статуса «Высокий расход»")
                            .font(.system(size: 12.5, weight: .medium))
                        Text("Минимальная нагрузка приложения на CPU для пометки повышенного потребления")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.0f%% CPU", settings.highEnergyThresholdCPU))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }

                GlassSlider(
                    value: $settings.highEnergyThresholdCPU,
                    in: 1...30,
                    step: 1,
                    unit: "%",
                    presets: [2, 5, 10, 15, 25]
                )

                Divider().opacity(0.35)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Порог статуса «Очень высокий расход»")
                            .font(.system(size: 12.5, weight: .medium))
                        Text("Порог высокой нагрузки процессора")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.0f%% CPU", settings.veryHighEnergyThresholdCPU))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }

                GlassSlider(
                    value: $settings.veryHighEnergyThresholdCPU,
                    in: 10...80,
                    step: 5,
                    unit: "%",
                    presets: [15, 20, 30, 50, 70]
                )
            }
            .glassCard()

            VStack(alignment: .leading, spacing: 10) {
                GlassToggleRow(
                    icon: "gearshape.2",
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

                Divider().opacity(0.35)

                GlassToggleRow(
                    icon: "percent",
                    title: "Показывать процент нагрузки CPU в меню",
                    subtitle: "Отображать числовое значение рядом с названием приложения",
                    isOn: $settings.showCPUPercentageInMenu
                )

                Divider().opacity(0.35)

                HStack {
                    Text("Интервал сканирования процессов:")
                        .font(.system(size: 12))
                    Spacer()
                    Text(String(format: "%.0f сек", settings.processScanIntervalSeconds))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
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
                    presets: [2, 5, 10, 15]
                )
            }
            .glassCard()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Исключенные приложения (через запятую)")
                        .font(.system(size: 12.5, weight: .medium))
                    Spacer()
                    Button("Обновить") {
                        energyService.refresh()
                    }
                    .controlSize(.small)
                }

                Text("Указанные приложения не будут включаться в список Топ-4 энергоемких.")
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
                Text("Строки сводки в верхней части меню")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                GlassToggleRow(
                    icon: "clock",
                    title: "Показывать «Осталось времени»",
                    subtitle: "Расчетное время автономной работы или время до окончания зарядки",
                    isOn: $settings.menuShowTimeRemaining
                )

                Divider().opacity(0.35)

                GlassToggleRow(
                    icon: "stopwatch",
                    title: "Показывать «Прошедшее время»",
                    subtitle: "Длительность работы от аккумулятора",
                    isOn: $settings.menuShowElapsedTime
                )

                Divider().opacity(0.35)

                GlassToggleRow(
                    icon: "slider.horizontal.below.rectangle",
                    title: "Показывать «Режим приложения»",
                    subtitle: "Текущий активный профиль: ограничение лимита, зарядка до 100% или от сети",
                    isOn: $settings.menuShowAppMode
                )

                Divider().opacity(0.35)

                GlassToggleRow(
                    icon: "info.circle",
                    title: "Строка телеметрии (Здоровье • Температура • Циклы)",
                    subtitle: "Компактная сводка параметров аккумулятора под основным блоком",
                    isOn: $settings.menuShowCompactTelemetry
                )
            }
            .glassCard()

            VStack(alignment: .leading, spacing: 10) {
                Text("Блоки меню")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                GlassToggleRow(
                    icon: "bolt.horizontal",
                    title: "Блок «Распределение питания»",
                    subtitle: "Поток мощности в ваттах: Адаптер питания → На Mac + В батарею",
                    isOn: $settings.menuShowPowerDistribution
                )

                Divider().opacity(0.35)

                GlassToggleRow(
                    icon: "chart.bar",
                    title: "Индикатор пропорции мощности",
                    subtitle: "Тонкая полоса баланса мощности между системой и зарядкой батареи",
                    isOn: $settings.menuShowPowerSplitBar
                )

                Divider().opacity(0.35)

                GlassToggleRow(
                    icon: "app.badge",
                    title: "Блок «Приложения с высоким энергопотреблением» (Топ 4)",
                    subtitle: "Фиксированная область на 4 приложения без изменения высоты меню",
                    isOn: $settings.menuShowHighEnergyApps
                )
            }
            .glassCard()
        }
    }

    // MARK: - 5. Значок (Menu Bar Icon)
    private var iconSectionContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Предпросмотр в строке меню")
                        .font(.system(size: 12.5, weight: .medium))
                    Text("Текущий вид значка в статус-баре macOS")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()

                let (previewImg, previewText) = MenuBarIconRenderer.renderIcon(info: monitor.info, settings: settings)
                HStack(spacing: 5) {
                    Image(nsImage: previewImg)
                    if !previewText.isEmpty {
                        Text(previewText)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
            }
            .glassCard()

            VStack(alignment: .leading, spacing: 8) {
                Text("Стиль значка")
                    .font(.system(size: 12.5, weight: .medium))

                ForEach(MenuBarIconStyle.allCases) { style in
                    let isSelected = settings.menuBarIconStyle == style
                    Button(action: {
                        settings.menuBarIconStyle = style
                        MenuBarController.shared.updateMenuBar()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                            Text(style.localizedTitle)
                                .font(.system(size: 12))
                            Spacer()
                        }
                        .padding(.vertical, 3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Divider().opacity(0.35)

                GlassToggleRow(
                    icon: "circle.lefthalf.filled",
                    title: "Цветовая индикация статуса в значке",
                    subtitle: "Выделять значок цветом при активной зарядке или паузе (выкл. — строго монохромный)",
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

            VStack(alignment: .leading, spacing: 8) {
                Text("Текст рядом со значком")
                    .font(.system(size: 12.5, weight: .medium))

                ForEach(MenuBarDisplayMode.allCases) { mode in
                    let isSelected = settings.menuBarDisplayMode == mode
                    Button(action: {
                        settings.menuBarDisplayMode = mode
                        MenuBarController.shared.updateMenuBar()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                            Text(mode.localizedTitle)
                                .font(.system(size: 12))
                            Spacer()
                        }
                        .padding(.vertical, 3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .glassCard()
        }
    }

    // MARK: - 6. Диагностика (Diagnostics)
    private var diagnosticsSectionContent: some View {
        let info = monitor.info
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Здоровье аккумулятора")
                            .font(.system(size: 13, weight: .medium))
                        Text("Отношение текущей максимальной емкости к заводской проектной")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.1f %%", info.healthPercentage).replacingOccurrences(of: ".", with: ","))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.10))
                            .frame(height: 6)
                        Capsule()
                            .fill(Color.primary.opacity(0.65))
                            .frame(width: max(6, geo.size.width * CGFloat(info.healthPercentage / 100.0)), height: 6)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("Текущая макс.: \(info.currentMaxCapacityMah) мАч")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Проектная: \(info.designCapacityMah) мАч")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .glassCard()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                diagMetricCard(
                    title: "Циклы перезарядки",
                    value: "\(info.cycleCount)",
                    subtitle: "Из 1000 расчетных",
                    icon: "arrow.triangle.2.circlepath"
                )

                diagMetricCard(
                    title: "Температура",
                    value: String(format: "%.1f °C", info.temperatureCelsius).replacingOccurrences(of: ".", with: ","),
                    subtitle: "Датчик аккумулятора",
                    icon: "thermometer.medium"
                )

                diagMetricCard(
                    title: "Напряжение",
                    value: String(format: "%.2f В", info.voltageVolts).replacingOccurrences(of: ".", with: ","),
                    subtitle: "Текущий вольтаж",
                    icon: "bolt"
                )

                diagMetricCard(
                    title: "Сила тока",
                    value: "\(info.amperageMilliAmps) мА",
                    subtitle: info.amperageMilliAmps >= 0 ? "Ток заряда" : "Ток разряда",
                    icon: "speedometer"
                )

                diagMetricCard(
                    title: "В батарею / Из батареи",
                    value: String(format: "%+.1f Вт", info.batteryPowerWatts).replacingOccurrences(of: ".", with: ","),
                    subtitle: "Мощность аккумулятора",
                    icon: "battery.100"
                )

                diagMetricCard(
                    title: "Расход Mac",
                    value: String(format: "%.1f Вт", info.systemPowerWatts).replacingOccurrences(of: ".", with: ","),
                    subtitle: info.isACConnected ? String(format: "Адаптер: %.1f Вт", info.adapterPowerWatts).replacingOccurrences(of: ".", with: ",") : "От аккумулятора",
                    icon: "laptopcomputer"
                )
            }
        }
    }

    private func diagMetricCard(title: String, value: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .glassCard(cornerRadius: 8, padding: 10)
    }

    // MARK: - 7. Уведомления (Notifications)
    private var notificationsSectionContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                GlassToggleRow(
                    icon: "checkmark.circle",
                    title: "Уведомлять о достижении лимита заряда",
                    subtitle: "Оповещение при остановке зарядки на целевом пороге (\(settings.chargeLimit)%)",
                    isOn: $settings.notifyOnLimitReached
                )

                Divider().opacity(0.35)

                GlassToggleRow(
                    icon: "bolt.circle",
                    title: "Уведомлять об окончании зарядки до 100%",
                    subtitle: "Сообщать, когда режим полной зарядки завершен",
                    isOn: $settings.notifyOnFull
                )

                Divider().opacity(0.35)

                GlassToggleRow(
                    icon: "thermometer.high",
                    title: "Предупреждать о перегреве батареи",
                    subtitle: "Оповещение при превышении порога \(Int(settings.maxAllowedTempCelsius))°C",
                    isOn: $settings.notifyOnOverheat
                )
            }
            .glassCard()

            VStack(alignment: .leading, spacing: 10) {
                GlassToggleRow(
                    icon: "battery.25",
                    title: "Предупреждать о низком заряде",
                    subtitle: "Напоминание подключить адаптер питания при разряде",
                    isOn: $settings.notifyOnLowBattery
                )

                if settings.notifyOnLowBattery {
                    Divider().opacity(0.35)

                    HStack {
                        Text("Порог уведомления о низком заряде:")
                            .font(.system(size: 12))
                        Spacer()
                        Text("\(settings.lowBatteryThreshold)%")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }

                    GlassSlider(
                        value: Binding(
                            get: { Double(settings.lowBatteryThreshold) },
                            set: { settings.lowBatteryThreshold = Int($0) }
                        ),
                        in: 10...30,
                        step: 5,
                        unit: "%",
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
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Телеметрия IOKit и датчики SMC (PSTR / PDTR): Активны")
                            .font(.system(size: 12.5, weight: .medium))
                        Text("Прямое чтение мощности адаптера, потребления системы Mac и заряда батареи в реальном времени.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Divider().opacity(0.35)

                HStack(spacing: 12) {
                    let isPriv = SMCController.shared.status == .activePrivileged
                    Image(systemName: isPriv ? "lock.open" : "lock")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isPriv ? "Аппаратная запись SMC: Активна" : "Аппаратная запись SMC: Пользовательский режим")
                            .font(.system(size: 12.5, weight: .medium))
                        Text("Управление ключами контроллера заряда (CH0B, CH0C, B0CM, BCLM) для аппаратной остановки зарядки.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .glassCard()

            VStack(alignment: .leading, spacing: 10) {
                Text("Привилегированный доступ SMC")
                    .font(.system(size: 12.5, weight: .medium))

                Text("Для аппаратного переключения ключей ограничения заряда на уровне SMC требуются права администратора.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                HStack {
                    Button(action: installHelperScript) {
                        Text("Запросить права администратора")
                    }
                    .controlSize(.regular)

                    if !helperStatusText.isEmpty {
                        Text(helperStatusText)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .glassCard()
        }
    }

    // MARK: - 9. О программе (About)
    private var aboutSectionContent: some View {
        VStack(spacing: 14) {
            AppIconView(size: 72)
                .padding(.top, 8)

            VStack(spacing: 3) {
                Text("VoltControl")
                    .font(.system(size: 18, weight: .semibold))
                Text("Версия 2.0")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Text("Утилита для мониторинга распределения мощности в ваттах, контроля энергоемких процессов и управления зарядкой аккумулятора MacBook.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

            VStack(spacing: 8) {
                aboutInfoRow(label: "Телеметрия питания", value: "IOKit AppleSmartBattery + AppleSMC")
                Divider().opacity(0.3)
                aboutInfoRow(label: "Датчики мощности", value: "PDTR (Вход), PSTR (Система), BatteryPower")
                Divider().opacity(0.3)
                aboutInfoRow(label: "Платформа", value: "macOS (Apple Silicon & Intel)")
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
                .font(.system(size: 11.5, weight: .medium))
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
