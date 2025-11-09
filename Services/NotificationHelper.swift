import Foundation
import UserNotifications

/// Kapselt lokale Benachrichtigungen auf watchOS.
/// Damit planen wir das Ende von Phase 1 und Phase 2.
/// Achtung: Der System-Prompt für Mitteilungen kommt beim ersten requestAuthorization().
struct NotificationHelper {

    enum NotifyError: Error {
        case notAuthorized
    }

    /// Fragt die Berechtigung an (einmalig beim ersten App-Start sinnvoll).
    func requestAuthorization() async throws {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        if settings.authorizationStatus == .notDetermined {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if !granted { throw NotifyError.notAuthorized }
        } else if settings.authorizationStatus != .authorized && settings.authorizationStatus != .provisional {
            throw NotifyError.notAuthorized
        }
    }

    /// Plant eine einfache Benachrichtigung in `seconds`.
    /// - Parameters:
    ///   - seconds: Zeit bis zur Benachrichtigung.
    ///   - title/body: Texte für die Notification.
    ///   - identifier: Eindeutige ID, um sie ggf. wiederzu­finden/stornieren.
    func schedulePhaseEndNotification(
        in seconds: TimeInterval,
        title: String,
        body: String,
        identifier: String
    ) async throws {
        let center = UNUserNotificationCenter.current()

        // Trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)

        // Content
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        // Standard-Haptik kommt mit der Notification automatisch.
        content.sound = .default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await center.add(request)
    }

    /// Storniert alle geplanten Benachrichtigungen.
    func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
