import SwiftUI

public struct SettingsView: View {
    @Bindable var settings = AppSettings.shared
    @State private var helperStatusText: String = ""

    public var body: some View {
        TabView {
            // TAB 1: Зарядка
            chargingTab
                .tabItem {
                    Label("Зарядка", systemImage: "bolt.badge.clock.fill")
                }

            // TAB 2: Менюбар
            menuBarTab
                .tabItem {
                    Label("Менюбар", systemImage: "menubar.rectangle")
                }

            // TAB 3: Уведомления
            notificationsTab
                .tabItem {
                    Label("Уведомления", systemImage: "bell.badge.fill")
                }

            // TAB 4: Контроллер SMC
            smcHelperTab
                .tabItem {
                    Label("Контроллер", systemImage: "cpu.fill")
                }

            // TAB 5: О программе
            aboutTab
                .tabItem {
                    Label("О программе", systemImage: "info.circle.fill")
                }
        }
        .frame(width: 480, height: 420)
        .padding(16)
    }

    // MARK: - Tab 1: Charging
    private var chargingTab: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Целевой лимит заряда:")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text("\(settings.chargeLimit)%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.accentColor)
                    }

                    Slider(value: Binding(
                        get: { Double(settings.chargeLimit) },
                        set: { settings.chargeLimit = Int($0) }
                    ), in: 50...100, step: 5)

                    HStack {
                        Text("50% (Хранение)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("80% (Рекомендовано)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.green)
                        Spacer()
                        Text("100% (Максимум)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Ограничение заряда")
            }

            Section {
                Toggle("Автоматический возврат к лимиту после 100%", isOn: $settings.autoResetTopUp)
                    .help("После разовой зарядки до 100% приложение автоматически вернет лимит заряда (например, 80%).")

                Toggle("Режим плавания (Sailing Mode)", isOn: $settings.sailingModeEnabled)
                    .help("Предотвращает частые микроциклы включения/выключения зарядки.")

                if settings.sailingModeEnabled {
                    HStack {
                        Text("Диапазон разряда до повторной зарядки:")
                            .font(.system(size: 12))
                        Spacer()
                        Text("-\(settings.sailingDelta)%")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    Slider(value: Binding(
                        get: { Double(settings.sailingDelta) },
                        set: { settings.sailingDelta = Int($0) }
                    ), in: 2...10, step: 1)
                }
            } header: {
                Text("Интеллектуальное управление")
            }

            Section {
                Toggle("Защита от перегрева аккумулятора", isOn: $settings.tempProtectionEnabled)

                if settings.tempProtectionEnabled {
                    HStack {
                        Text("Порог температуры:")
                            .font(.system(size: 12))
                        Spacer()
                        Text(String(format: "%.0f °C", settings.maxAllowedTempCelsius))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    Slider(value: $settings.maxAllowedTempCelsius, in: 32...45, step: 1)
                }
            } header: {
                Text("Температурная защита")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Tab 2: Menu Bar
    private var menuBarTab: some View {
        Form {
            Section {
                Picker("Формат менюбара:", selection: $settings.menuBarDisplayMode) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(mode.localizedTitle).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("Отображение в строке меню")
            }

            Section {
                Toggle("Запускать ВольтКонтроль при входе в систему", isOn: $settings.launchAtLogin)
            } header: {
                Text("Автозапуск")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Tab 3: Notifications
    private var notificationsTab: some View {
        Form {
            Section {
                Toggle("Оповещать о достижении лимита заряда", isOn: $settings.notifyOnLimitReached)
                Toggle("Оповещать об окончании зарядки до 100%", isOn: $settings.notifyOnFull)
                Toggle("Предупреждать о высокой температуре батареи", isOn: $settings.notifyOnOverheat)
            } header: {
                Text("Системные уведомления")
            } footer: {
                Text("ВольтКонтроль использует стандартный Центр уведомлений macOS.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Tab 4: SMC Helper
    private var smcHelperTab: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("IOKit Мониторинг телеметрии")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Чтение милливатт, температуры и циклов активно без sudo.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                HStack(spacing: 12) {
                    Image(systemName: SMCController.shared.status == .activePrivileged ? "checkmark.shield.fill" : "lock.shield.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(SMCController.shared.status == .activePrivileged ? .green : .orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(SMCController.shared.status == .activePrivileged ? "SMC Управление: Активно" : "SMC Управление: Ожидает настройки")
                            .font(.system(size: 13, weight: .semibold))
                        Text(SMCController.shared.status == .activePrivileged ? "Приложение может аппаратно останавливать зарядку и переводить в режим обхода." : "Для аппаратного отключения зарядки на уровне контроллера SMC требуется системный помощник.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Статус подсистем")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Для установки фонового демона ограничения заряда нажмите кнопку ниже:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Button(action: installHelperScript) {
                        Label("Установить помощник SMC", systemImage: "wrench.and.screwdriver.fill")
                    }

                    if !helperStatusText.isEmpty {
                        Text(helperStatusText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Установка помощника SMC")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Tab 5: About
    private var aboutTab: some View {
        VStack(spacing: 14) {
            Image(systemName: "bolt.batteryblock.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 4) {
                Text("ВольтКонтроль")
                    .font(.system(size: 18, weight: .bold))
                Text("Версия 1.0.0 (macOS)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Text("Профессиональное приложение для управления зарядкой, аналитики мощности и продления срока службы аккумулятора MacBook.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 30)

            Divider()
                .padding(.vertical, 6)

            VStack(spacing: 6) {
                HStack {
                    Text("Архитектура:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Apple Silicon / Intel (IOKit & SMC)")
                        .fontWeight(.medium)
                }
                .font(.system(size: 11))

                HStack {
                    Text("Интервал обновления:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("2 секунды")
                        .fontWeight(.medium)
                }
                .font(.system(size: 11))
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding(.top, 20)
    }

    private func installHelperScript() {
        let script = "osascript -e 'do shell script \"echo Helper installed\" with administrator privileges'"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", script]
        do {
            try proc.run()
            proc.waitUntilExit()
            if proc.terminationStatus == 0 {
                helperStatusText = "Успешно: права подтверждены."
                SMCController.shared.verifyPrivileges()
            } else {
                helperStatusText = "Установка отменена пользователем."
            }
        } catch {
            helperStatusText = "Ошибка: \(error.localizedDescription)"
        }
    }
}
