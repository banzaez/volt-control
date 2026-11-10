import Foundation
import UserNotifications

public final class NotificationService: Sendable {
    public static let shared = NotificationService()

    private init() {}

    private var canUseNotifications: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    public func requestAuthorization() {
        guard canUseNotifications else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    public func sendNotification(title: String, subtitle: String? = nil, body: String, identifier: String) {
        guard canUseNotifications else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        if let sub = subtitle {
            content.subtitle = sub
        }
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to deliver notification \(identifier): \(error.localizedDescription)")
            }
        }
    }

    public func notifyLimitReached(level: Int, target: Int) {
        sendNotification(
            title: "VoltControl",
            subtitle: "Лимит заряда \(target)% достигнут",
            body: "Заряд аккумулятора составляет \(level)%. Зарядка приостановлена для сохранения ресурса батареи.",
            identifier: "voltcontrol.limit.reached"
        )
    }

    public func notifyTopUpCompleted() {
        sendNotification(
            title: "VoltControl",
            subtitle: "Зарядка до 100% завершена",
            body: "Аккумулятор полностью заряжен. VoltControl вернулся к обычному режиму ограничения.",
            identifier: "voltcontrol.topup.completed"
        )
    }

    public func notifyOverheating(temperature: Double) {
        sendNotification(
            title: "VoltControl",
            subtitle: String(format: "Температура батареи: %.1f°C", temperature),
            body: "Температура превысила заданный порог. Зарядка временно приостановлена.",
            identifier: "voltcontrol.temperature.warning"
        )
    }

    public func notifyLowBattery(level: Int) {
        sendNotification(
            title: "VoltControl",
            subtitle: "Низкий уровень заряда (\(level)%)",
            body: "Рекомендуется подключить адаптер питания.",
            identifier: "voltcontrol.low.battery"
        )
    }
}
