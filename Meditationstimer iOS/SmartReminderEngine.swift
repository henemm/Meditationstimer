import Foundation
import SwiftUI
import UserNotifications
import os
#if os(iOS)
import UIKit
#endif

/// Represents a temporarily cancelled notification (until next natural trigger)
struct CancelledNotification: Codable, Equatable {
    let reminderID: UUID
    let weekday: Weekday
    let cancelledUntil: Date  // Next natural trigger time - auto-expires after this
}

/// Engine für Smart Reminders: Lädt/Speichert Reminders, triggert Notifications, und cancelled sie basierend auf Aktivität.
public final class SmartReminderEngine {
    public static let shared = SmartReminderEngine()

    private let logger = Logger(subsystem: "com.henemm.Meditationstimer", category: "SmartReminderEngine")

    @AppStorage("smartReminders") private var remindersData: Data = Data()
    @AppStorage("smartRemindersPaused") var isPaused: Bool = false
    @AppStorage("cancelledNotifications") private var cancelledData: Data = Data()

    private var reminders: [SmartReminder] = []
    private var cancelled: [CancelledNotification] = []

    private init() {
        logger.info("🚀 SmartReminderEngine initializing...")
        loadReminders()
        loadCancelled()
        logger.info("📊 State after load: \(self.reminders.count) reminders, \(self.cancelled.count) cancelled, isPaused: \(self.isPaused)")
        #if os(iOS)
        // Initial scheduling beim App-Start
        scheduleNotifications()
        #endif
        logger.info("✅ SmartReminderEngine initialization complete")
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

    /// Lädt cancelled notifications aus AppStorage.
    private func loadCancelled() {
        guard !cancelledData.isEmpty else {
            cancelled = []
            return
        }
        do {
            let decoded = try JSONDecoder().decode([CancelledNotification].self, from: cancelledData)
            cancelled = decoded
            logger.info("Loaded \(self.cancelled.count) cancelled notifications")
        } catch {
            logger.error("Failed to load cancelled notifications: \(error.localizedDescription)")
            cancelled = []
        }
    }

    /// Speichert cancelled notifications in AppStorage.
    private func saveCancelled() {
        do {
            let encoded = try JSONEncoder().encode(cancelled)
            cancelledData = encoded
            logger.info("Saved \(self.cancelled.count) cancelled notifications")
        } catch {
            logger.error("Failed to save cancelled notifications: \(error.localizedDescription)")
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

    // MARK: - Reverse Smart Reminders Logic

    /// Cancels matching reminders based on completed activity (Reverse Smart Reminders approach).
    /// Called from HealthKitManager after logging activity.
    ///
    /// - Parameters:
    ///   - activityType: Type of activity that was completed (mindfulness, workout, noalc)
    ///   - completedAt: Date when activity was completed
    public func cancelMatchingReminders(for activityType: ActivityType, completedAt: Date) {
        let now = Date()
        let lookAheadEnd = now.addingTimeInterval(24 * 3600)  // 24h window
        let calendar = Calendar.current

        logger.info("🔍 cancelMatchingReminders called:")
        logger.info("  → activityType: \(activityType.rawValue)")
        logger.info("  → completedAt: \(completedAt)")
        logger.info("  → now: \(now)")
        logger.info("  → lookAheadEnd: \(lookAheadEnd)")

        let matchingReminders = reminders.filter { $0.isEnabled && $0.activityType == activityType }
        logger.info("  → Enabled reminders for type '\(activityType.rawValue)': \(matchingReminders.count)")

        var cancelledCount = 0

        for reminder in matchingReminders {
            logger.info("  🔎 Processing reminder '\(reminder.title)' (lookback: \(reminder.lookbackHours)h, days: \(reminder.selectedDays.map { $0.displayName }.joined(separator: ", ")))")

            for weekday in reminder.selectedDays {
                // Calculate next trigger for this reminder+weekday
                guard let nextTrigger = calculateNextTrigger(reminder: reminder, weekday: weekday, after: now, calendar: calendar) else {
                    logger.info("    ❌ Could not calculate next trigger for \(weekday.displayName)")
                    continue
                }

                logger.info("    → \(weekday.displayName): next trigger = \(nextTrigger)")

                // Outside 24h look-ahead window?
                if nextTrigger > lookAheadEnd {
                    logger.info("    ⏭️ Outside 24h window, skipping")
                    continue
                }

                // Calculate look-back window for that trigger
                let lookBackStart = nextTrigger.addingTimeInterval(-Double(reminder.lookbackHours) * 3600)
                let lookBackEnd = nextTrigger

                logger.info("    → Look-back window: \(lookBackStart) to \(lookBackEnd)")
                logger.info("    → completedAt in window? \(completedAt >= lookBackStart && completedAt <= lookBackEnd)")

                // Does completedAt fall into look-back window?
                if completedAt >= lookBackStart && completedAt <= lookBackEnd {
                    // YES → Cancel this notification
                    let cancelledNotification = CancelledNotification(
                        reminderID: reminder.id,
                        weekday: weekday,
                        cancelledUntil: nextTrigger
                    )

                    // Only add if not already cancelled
                    if !cancelled.contains(cancelledNotification) {
                        cancelled.append(cancelledNotification)

                        // Bug 33 Fix: Remove the pending notification from iOS immediately
                        #if os(iOS)
                        let identifier = "activity-reminder-\(reminder.id.uuidString)-\(weekday.rawValue)"
                        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
                        logger.info("    ✅ CANCELLED reminder '\(reminder.title)' for \(weekday.displayName) (notification removed)")
                        #else
                        logger.info("    ✅ CANCELLED reminder '\(reminder.title)' for \(weekday.displayName)")
                        #endif

                        cancelledCount += 1
                    } else {
                        logger.info("    ℹ️ Already cancelled")
                    }
                } else {
                    logger.info("    ⏭️ completedAt not in look-back window, skipping")
                }
            }
        }

        if cancelledCount > 0 {
            logger.info("💾 Saving \(cancelledCount) new cancellation(s), total cancelled: \(self.cancelled.count)")
            saveCancelled()
            logger.info("🎯 Cancelled \(cancelledCount) reminder(s) based on activity completion")
        } else {
            logger.info("ℹ️ No matching reminders found to cancel")
        }
    }

    /// Calculates the next trigger date for a reminder on a specific weekday.
    private func calculateNextTrigger(reminder: SmartReminder, weekday: Weekday, after date: Date, calendar: Calendar) -> Date? {
        let hour = calendar.component(.hour, from: reminder.triggerTime)
        let minute = calendar.component(.minute, from: reminder.triggerTime)

        // Find next occurrence of this weekday at the specified time
        var components = DateComponents()
        components.weekday = weekday.calendarWeekday
        components.hour = hour
        components.minute = minute

        // nextDate(after:matching:matchingPolicy:) finds the next date matching these components
        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
    }

    /// Checks if a reminder+weekday combination is currently cancelled.
    private func isCancelled(_ reminderID: UUID, _ weekday: Weekday) -> Bool {
        return cancelled.contains { $0.reminderID == reminderID && $0.weekday == weekday }
    }

    /// Removes expired cancellations (where cancelledUntil < now).
    private func cleanupExpiredCancellations() {
        let now = Date()
        let beforeCount = cancelled.count
        cancelled = cancelled.filter { $0.cancelledUntil > now }

        if beforeCount != cancelled.count {
            saveCancelled()
            logger.info("🧹 Cleaned up \(beforeCount - self.cancelled.count) expired cancellation(s)")
        }
    }

    // MARK: - Notification Scheduling (KOMPLETT NEU - basierend auf funktionierendem Debug-Code)

    #if os(iOS)
    /// Schedules UNCalendarNotificationTrigger for each enabled reminder.
    /// Respects cancelled list (Reverse Smart Reminders).
    func scheduleNotifications() {
        logger.info("📅 Scheduling smart reminders...")
        logger.info("📊 Total reminders: \(self.reminders.count), Enabled: \(self.reminders.filter { $0.isEnabled }.count), Disabled: \(self.reminders.filter { !$0.isEnabled }.count)")

        if isPaused {
            logger.warning("⏸️ WARNING: Smart reminders are PAUSED globally (isPaused = true)")
        }

        // 1. Clean up expired cancellations
        cleanupExpiredCancellations()

        // 2. Cancel all existing activity reminder notifications
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let reminderIdentifiers = requests
                .filter { $0.identifier.hasPrefix("activity-reminder-") }
                .map { $0.identifier }

            if !reminderIdentifiers.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIdentifiers)
                self.logger.info("🗑️ Removed \(reminderIdentifiers.count) pending activity reminder(s)")
            }

            // 3. Schedule notifications for each enabled reminder (respecting cancelled list)
            let enabledReminders = self.reminders.filter { $0.isEnabled }
            self.logger.info("🔄 Scheduling \(enabledReminders.count) enabled reminder(s)...")

            for reminder in enabledReminders {
                self.logger.info("  → Processing '\(reminder.title)' (type: \(reminder.activityType.rawValue), days: \(reminder.selectedDays.count))")
                self.scheduleNotification(for: reminder)
            }

            self.logger.info("✅ Smart reminder scheduling complete")
        }
    }

    /// Schedules a single UNNotificationRequest for a reminder.
    /// Skips weekdays that are currently cancelled.
    private func scheduleNotification(for reminder: SmartReminder) {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: reminder.triggerTime)
        let minute = calendar.component(.minute, from: reminder.triggerTime)

        let currentWeekday = calendar.component(.weekday, from: now)
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)

        // Schedule one notification PER selected weekday (unless cancelled)
        for weekday in reminder.selectedDays {
            // CHECK: Is this reminder+weekday cancelled?
            if isCancelled(reminder.id, weekday) {
                logger.info("⏭️ Skipping '\(reminder.title)' for \(weekday.displayName) (cancelled)")
                continue
            }

            // Determine if we should trigger TODAY or let iOS find the next occurrence
            // If it's the same weekday and the time hasn't passed yet, iOS will trigger today
            // If the time has passed, iOS will wait until next week
            // This is correct behavior - we just need to accept it

            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.weekday = weekday.calendarWeekday  // 1=Sunday, 2=Monday, etc.

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

            // Log whether this will trigger today or next week (for debugging)
            let willTriggerToday = (weekday.calendarWeekday == currentWeekday) &&
                                   (hour > currentHour || (hour == currentHour && minute > currentMinute))
            let triggerInfo = willTriggerToday ? "today" : "next week"

            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.message
            content.sound = .default

            // NoAlc: Add notification actions for direct logging
            if reminder.activityType == .noalc {
                content.categoryIdentifier = "NOALC_LOG_CATEGORY"
            }

            // Unique identifier per weekday
            let identifier = "activity-reminder-\(reminder.id.uuidString)-\(weekday.rawValue)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            // Schedule notification
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    self.logger.error("❌ Failed to schedule '\(reminder.title)' for \(weekday.displayName): \(error.localizedDescription)")
                } else {
                    self.logger.info("✅ Scheduled '\(reminder.title)' for \(weekday.displayName) at \(String(format: "%02d:%02d", hour, minute)) (\(triggerInfo))")
                }
            }
        }
    }
    #endif
}
