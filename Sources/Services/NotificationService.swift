import Foundation
import UserNotifications

/// Handles local notification alerts for completed extractions and compressions.
public final class NotificationService: @unchecked Sendable {
    public static let shared = NotificationService()

    private init() {}

    /// Requests user authorization for notification alerts and badges.
    public func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Schedules a notification upon task completion.
    public func notifyCompletion(title: String, body: String, isSuccess: Bool = true) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = isSuccess ? .default : .defaultCritical

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.2, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to dispatch local notification: \(error)")
            }
        }
    }
}
