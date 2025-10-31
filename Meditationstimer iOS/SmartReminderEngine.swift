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

    // MARK: - Notification Scheduling (KOMPLETT NEU - basierend auf funktionierendem Debug-Code)

    #if os(iOS)
    /// Schedules UNCalendarNotificationTrigger for each enabled reminder.
    /// SIMPLIFIED - exactly like working debug code!
    func scheduleNotifications() {
        logger.info("📅 Scheduling activity reminders...")

        // 1. Cancel all existing activity reminder notifications
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let reminderIdentifiers = requests
                .filter { $0.identifier.hasPrefix("activity-reminder-") }
                .map { $0.identifier }

            if !reminderIdentifiers.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIdentifiers)
                self.logger.info("🗑️ Removed \(reminderIdentifiers.count) pending activity reminder(s)")
            }

            // 2. Schedule notifications for each enabled reminder
            for reminder in self.reminders where reminder.isEnabled {
                self.scheduleNotification(for: reminder)
            }

            self.logger.info("✅ Activity reminder scheduling complete")
        }
    }

    /// Schedules a single UNNotificationRequest for a reminder.
    /// SIMPLIFIED - exactly like working debug code!
    private func scheduleNotification(for reminder: SmartReminder) {
        let calendar = Calendar.current

        // Extract hour and minute from triggerTime
        let hour = calendar.component(.hour, from: reminder.triggerTime)
        let minute = calendar.component(.minute, from: reminder.triggerTime)

        // Create DateComponents for trigger
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

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
                self.logger.info("✅ Scheduled notification for '\(reminder.title)' at \(String(format: "%02d:%02d", hour, minute))")
            }
        }
    }
    #endif
}
