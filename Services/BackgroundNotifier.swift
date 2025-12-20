//
//  BackgroundNotifier.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 27.09.25.
//


//
//  BackgroundNotifier.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 27.09.25.
//

import Foundation
import UserNotifications

/// Schlanker Helfer für lokale Benachrichtigungen im Hintergrund.
/// Aktuell nur Minimalfunktionen, damit `OffenView` sauber kompiliert:
///  - `start()` fragt einmal die Berechtigung an.
///  - `stop()` räumt optionale, von hier geplante Notifications wieder weg.
final class BackgroundNotifier {

    private let center = UNUserNotificationCenter.current()
    private var didRequestAuth = false

    /// Einmalig Berechtigung anfragen (leise; nur beim ersten Start relevant).
    func start() {
        guard !didRequestAuth else { return }
        didRequestAuth = true
        center.getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            self?.center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                // Absichtlich kein weiteres Handling – stiller Minimal-Helper.
            }
        }
    }

    /// Optional: alle von hier geplanten Benachrichtigungen entfernen.
    func stop() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Optional: Einfache API zum Planen (derzeit ungenutzt)
    /// Plant eine einfache Benachrichtigung nach `seconds` Sekunden.
    func schedule(message: String, in seconds: TimeInterval, identifier: String = UUID().uuidString) {
        let content = UNMutableNotificationContent()
        content.title = "Healthy Habits"
        content.body = message
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }
}
