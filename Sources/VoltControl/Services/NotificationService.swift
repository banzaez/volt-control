import Foundation
import UserNotifications

public final class NotificationService: Sendable {
    public static let shared = NotificationService()

    private init() {}

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    public func sendNotification(title: String, subtitle: String? = nil, body: String, identifier: String) {
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
            title: "Лимит заряда достигнут",
            subtitle: "\(level)% заряда",
            body: "Аккумулятор достиг целевого лимита \(target)%. Зарядка остановлена для сохранения ресурса батареи.",
            identifier: "voltcontrol.limit.reached"
        )
    }

    public func notifyTopUpCompleted() {
        sendNotification(
            title: "Зарядка до 100% завершена",
            subtitle: "Аккумулятор полностью заряжен",
            body: "Режим полной зарядки выполнен. ВольтКонтроль вернулся к режиму защиты аккумулятора.",
            identifier: "voltcontrol.topup.completed"
        )
    }

    public func notifyOverheating(temperature: Double) {
        sendNotification(
            title: "Предупреждение о температуре",
            subtitle: String(format: "Температура: %.1f°C", temperature),
            body: "Температура аккумулятора превысила безопасный порог. Зарядка временно приостановлена для охлаждения.",
            identifier: "voltcontrol.temperature.warning"
        )
    }
}
