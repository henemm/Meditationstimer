import Foundation
import SwiftUI
import UserNotifications
import os
#if os(iOS)
import UIKit
#endif

/// Engine für Activity Reminders: Lädt/Speichert Reminders und triggert Notifications.
public final class SmartReminderEngine {
    public static let shared = SmartReminderEngine()

    private let logger = Logger(subsystem: "com.henemm.Meditationstimer", category: "SmartReminderEngine")

    @AppStorage("smartReminders") private var remindersData: Data = Data()
    @AppStorage("smartRemindersPaused") var isPaused: Bool = false
    @AppStorage("lastReminderTrigger") private var lastTrigger: Date?

    private var reminders: [SmartReminder] = []

    private init() {
        loadReminders()
        #if os(iOS)
        // Initial scheduling beim App-Start
        scheduleNotifications()
        #endif
    }

    // MARK: - Persistence

    /// Lädt Reminders aus AppStorage.
    func loadReminders() {
        do {
            let decoded = try JSONDecoder().decode([SmartReminder].self, from: remindersData)
            reminders = decoded
            logger.info("Loaded \(self.reminders.count) smart reminders")
        } catch {
            logger.error("Failed to load reminders: \(error.localizedDescription)")
            reminders = []
        }
    }

    /// Speichert Reminders in AppStorage.
    func saveReminders() {
        do {
            let encoded = try JSONEncoder().encode(reminders)
            remindersData = encoded
            logger.info("Saved \(self.reminders.count) smart reminders")
        } catch {
            logger.error("Failed to save reminders: \(error.localizedDescription)")
        }
    }

    // MARK: - Public API

    /// Gibt alle Reminders zurück.
    public func getReminders() -> [SmartReminder] {
        return reminders
    }

    /// Fügt einen neuen Reminder hinzu.
    public func addReminder(_ reminder: SmartReminder) {
        reminders.append(reminder)
        saveReminders()
        #if os(iOS)
        scheduleNotifications()
        #endif
    }

    /// Entfernt einen Reminder.
    public func removeReminder(withId id: UUID) {
        reminders.removeAll { $0.id == id }
        saveReminders()
        #if os(iOS)
        scheduleNotifications()
        #endif
    }

    /// Aktualisiert einen Reminder.
    public func updateReminder(_ updated: SmartReminder) {
        if let index = reminders.firstIndex(where: { $0.id == updated.id }) {
            reminders[index] = updated
            saveReminders()
            #if os(iOS)
            scheduleNotifications()
            #endif
        }
    }

    // MARK: - Notification Scheduling

    #if os(iOS)
    /// Schedules UNCalendarNotificationTrigger for each enabled reminder.
    func scheduleNotifications() {
        logger.info("📅 Scheduling activity reminders...")

        // Cancel all existing activity reminder notifications
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let reminderIdentifiers = requests
                .filter { $0.identifier.hasPrefix("activity-reminder-") }
                .map { $0.identifier }

            if !reminderIdentifiers.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIdentifiers)
                self.logger.info("🗑️ Removed \(reminderIdentifiers.count) pending activity reminder(s)")
            }
        }

        // Schedule notifications for each enabled reminder
        for reminder in reminders where reminder.isEnabled {
            scheduleNotification(for: reminder)
        }

        logger.info("✅ Activity reminder scheduling complete")
    }

    /// Schedules a single UNNotificationRequest for a reminder.
    private func scheduleNotification(for reminder: SmartReminder) {
        let calendar = Calendar.current

        // Create DateComponents for trigger time
        var dateComponents = DateComponents()
        dateComponents.hour = reminder.triggerHour
        dateComponents.minute = 0

        // Create calendar trigger (repeats daily)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.message
        content.sound = .default

        // Create request with unique identifier
        let identifier = "activity-reminder-\(reminder.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        // Schedule notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("❌ Failed to schedule notification for '\(reminder.title)': \(error.localizedDescription)")
            } else {
                self.logger.info("✅ Scheduled notification for '\(reminder.title)' at \(reminder.triggerHour):00")
            }
        }
    }
    #endif

    // MARK: - Trigger Logic

    /// Prüft, ob ein Reminder getriggert werden sollte.
    /// Testbar: Alle Bedingungen in separater Funktion.
    private func shouldTriggerReminder(_ reminder: SmartReminder) async -> Bool {
        guard reminder.isEnabled else {
            logger.debug("❌ Reminder '\(reminder.title)' is disabled")
            return false
        }

        let now = Date()
        let calendar = Calendar.current

        // 1. Wochentage-Prüfung (NEU!)
        let todayWeekday = calendar.component(.weekday, from: now)
        let today = Weekday.from(calendarWeekday: todayWeekday)

        guard reminder.selectedDays.contains(today) else {
            logger.debug("❌ Reminder '\(reminder.title)' not active on \(today.displayName)")
            return false
        }

        // 2. Zeitfenster-Prüfung
        guard let triggerStart = calendar.date(bySettingHour: reminder.triggerHour, minute: 0, second: 0, of: now),
              let triggerEnd = calendar.date(byAdding: .minute, value: reminder.windowMinutes, to: triggerStart) else {
            logger.error("❌ Failed to calculate trigger window for '\(reminder.title)'")
            return false
        }

        guard now >= triggerStart && now <= triggerEnd else {
            logger.debug("❌ Reminder '\(reminder.title)' outside time window (\(triggerStart) - \(triggerEnd))")
            return false
        }

        // 3. HealthKit-Prüfung (KORRIGIERT: von NOW, nicht triggerStart!)
        guard let lookbackStart = calendar.date(byAdding: .hour, value: -reminder.lookbackHours, to: now) else {
            logger.error("❌ Failed to calculate lookback start for '\(reminder.title)'")
            return false
        }

        do {
            let hasActivity = try await HealthKitManager.shared.hasActivity(
                ofType: reminder.checkType.rawValue,
                inRange: lookbackStart,
                end: now  // ← KORRIGIERT: von NOW, nicht triggerStart!
            )

            if hasActivity {
                logger.info("✅ Reminder '\(reminder.title)' skipped: activity found in last \(reminder.lookbackHours)h")
                return false
            } else {
                logger.info("🔔 Reminder '\(reminder.title)' will trigger: no activity in last \(reminder.lookbackHours)h")
                return true
            }

        } catch {
            logger.error("❌ HealthKit check failed for '\(reminder.title)': \(error.localizedDescription)")
            return false // Bei HealthKit-Fehler: keine Notification
        }
    }

    /// Trigert eine Notification für einen Reminder.
    private func triggerNotification(for reminder: SmartReminder) async {
        do {
            let helper = NotificationHelper()
            try await helper.requestAuthorization()

            // Sofortige Notification (timeInterval: 1)
            try await helper.schedulePhaseEndNotification(
                in: 1,
                title: reminder.title,
                body: reminder.message,
                identifier: "smart-reminder-\(reminder.id.uuidString)"
            )

            logger.info("📬 Triggered notification for reminder: \(reminder.title)")
        } catch {
            logger.error("❌ Failed to trigger notification for '\(reminder.title)': \(error.localizedDescription)")
        }
    }


    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Weekday Extension

extension Weekday {
    /// Konvertiert Calendar.component(.weekday) zu Weekday enum.
    /// Calendar.weekday: 1=Sunday, 2=Monday, ..., 7=Saturday
    static func from(calendarWeekday: Int) -> Weekday {
        switch calendarWeekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return .sunday // Fallback
        }
    }
}
