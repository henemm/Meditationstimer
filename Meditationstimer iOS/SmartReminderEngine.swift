import Foundation
import SwiftUI
import BackgroundTasks
import os
#if os(iOS)
import UIKit
#endif

/// Engine für Smart Reminders: Lädt/Speichert Reminders, prüft HealthKit und triggert Notifications.
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
        scheduleNextCheck()
        #endif
    }

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

    /// Gibt alle Reminders zurück.
    public func getReminders() -> [SmartReminder] {
        return reminders
    }

    /// Fügt einen neuen Reminder hinzu.
    public func addReminder(_ reminder: SmartReminder) {
        reminders.append(reminder)
        saveReminders()
        #if os(iOS)
        scheduleNextCheck()
        #endif
    }

    /// Entfernt einen Reminder.
    public func removeReminder(withId id: UUID) {
        reminders.removeAll { $0.id == id }
        saveReminders()
    }

    /// Aktualisiert einen Reminder.
    public func updateReminder(_ updated: SmartReminder) {
        if let index = reminders.firstIndex(where: { $0.id == updated.id }) {
            reminders[index] = updated
            saveReminders()
            #if os(iOS)
            scheduleNextCheck()
            #endif
        }
    }

    #if os(iOS)
    /// Hauptfunktion für BGTask: Prüft alle Reminders und triggert Notifications falls nötig.
    func handleReminderCheck(task: BGAppRefreshTask) {
        logger.info("Starting smart reminder check")

        task.expirationHandler = {
            self.logger.warning("BGTask expired")
            task.setTaskCompleted(success: false)
        }

        Task {
            do {
                if self.isPaused {
                    logger.info("Reminders are paused")
                    task.setTaskCompleted(success: true)
                    return
                }

                // Rate limiting: Max 1 Notification pro Stunde
                if let last = self.lastTrigger, Date().timeIntervalSince(last) < 3600 {
                    logger.info("Rate limited: last trigger was \(Date().timeIntervalSince(last)) seconds ago")
                    task.setTaskCompleted(success: true)
                    return
                }

                var triggeredCount = 0

                for reminder in self.reminders {
                    if await self.shouldTriggerReminder(reminder) {
                        await self.triggerNotification(for: reminder)
                        triggeredCount += 1
                        self.lastTrigger = Date()
                        // Nur eine Notification pro Check
                        break
                    }
                }

                logger.info("Completed check: triggered \(triggeredCount) notifications")
                task.setTaskCompleted(success: true)
                self.scheduleNextCheck()

            } catch {
                logger.error("Error during reminder check: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
        }
    }
    #endif

    /// Prüft, ob ein Reminder getriggert werden sollte.
    private func shouldTriggerReminder(_ reminder: SmartReminder) async -> Bool {
        let now = Date()
        let calendar = Calendar.current

        // Berechne Trigger-Zeitfenster
        guard let triggerStart = calendar.date(bySettingHour: reminder.triggerHour, minute: 0, second: 0, of: now),
              let triggerEnd = calendar.date(byAdding: .minute, value: reminder.windowMinutes, to: triggerStart) else {
            return false
        }

        // Prüfe, ob wir im Trigger-Zeitfenster sind
        guard now >= triggerStart && now <= triggerEnd else {
            return false
        }

        // Look-back-Zeitraum: von triggerStart minus lookbackHours bis triggerStart
        guard let lookbackStart = calendar.date(byAdding: .hour, value: -reminder.lookbackHours, to: triggerStart) else {
            return false
        }

        do {
            let hasActivity = try await HealthKitManager.shared.hasActivity(ofType: reminder.checkType.rawValue, inRange: lookbackStart, end: triggerStart)
            return !hasActivity // Trigger nur wenn KEINE Aktivität
        } catch {
            logger.error("Failed to check activity for reminder \(reminder.title): \(error.localizedDescription)")
            return false
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

            logger.info("Triggered notification for reminder: \(reminder.title)")
        } catch {
            logger.error("Failed to trigger notification for \(reminder.title): \(error.localizedDescription)")
        }
    }

    #if os(iOS)
    /// Plant die nächste BGTask-Prüfung.
    private func scheduleNextCheck() {
        let request = BGAppRefreshTaskRequest(identifier: "com.henemm.smartreminders.check")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // In 1 Stunde

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled next reminder check")
        } catch {
            logger.error("Failed to schedule BGTask: \(error.localizedDescription)")
        }
    }
    #endif

    /// Test-Funktion: Prüft einen Reminder sofort.
    func testReminder(_ reminder: SmartReminder) async {
        logger.info("Testing reminder: \(reminder.title)")
        if await shouldTriggerReminder(reminder) {
            await triggerNotification(for: reminder)
        } else {
            logger.info("Test: No notification triggered for \(reminder.title)")
        }
    }
}