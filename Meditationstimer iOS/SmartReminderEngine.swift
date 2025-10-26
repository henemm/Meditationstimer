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
        scheduleNextCheck()
        #endif
    }

    /// Entfernt einen Reminder.
    public func removeReminder(withId id: UUID) {
        reminders.removeAll { $0.id == id }
        saveReminders()
        #if os(iOS)
        scheduleNextCheck()
        #endif
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

    // MARK: - Background Task Handling

    #if os(iOS)
    /// Hauptfunktion für BGTask: Prüft alle Reminders und triggert Notifications falls nötig.
    func handleReminderCheck(task: BGAppRefreshTask) {
        logger.info("🔔 Starting smart reminder check")

        task.expirationHandler = {
            self.logger.warning("⚠️ BGTask expired before completion")
            task.setTaskCompleted(success: false)
        }

        Task {
            if self.isPaused {
                logger.info("⏸️ Reminders are paused, skipping check")
                task.setTaskCompleted(success: true)
                self.scheduleNextCheck()
                return
            }

            // Rate limiting: Max 1 Notification pro Stunde
            if let last = self.lastTrigger, Date().timeIntervalSince(last) < 3600 {
                let elapsed = Int(Date().timeIntervalSince(last))
                logger.info("⏱️ Rate limited: last trigger was \(elapsed)s ago (< 3600s)")
                task.setTaskCompleted(success: true)
                self.scheduleNextCheck()
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

            if triggeredCount > 0 {
                logger.info("✅ Completed check: triggered \(triggeredCount) notification(s)")
            } else {
                logger.info("✅ Completed check: no notifications triggered")
            }

            task.setTaskCompleted(success: true)
            self.scheduleNextCheck()
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

    // MARK: - Scheduling Logic (NEU!)

    #if os(iOS)
    /// Berechnet den nächsten Check-Zeitpunkt basierend auf allen enabled Reminders.
    /// Testbar: Separate Funktion mit klarer Logik.
    func calculateNextCheckDate() -> Date? {
        let calendar = Calendar.current
        let now = Date()

        var nextCheckDates: [Date] = []

        for reminder in reminders where reminder.isEnabled {
            if let nextTrigger = calculateNextTriggerDate(for: reminder, from: now, calendar: calendar) {
                // Schedule 5 Minuten VOR Trigger-Zeit
                if let checkDate = calendar.date(byAdding: .minute, value: -5, to: nextTrigger) {
                    nextCheckDates.append(checkDate)
                }
            }
        }

        guard !nextCheckDates.isEmpty else {
            logger.info("⚠️ No enabled reminders found, no check scheduled")
            return nil
        }

        // Wähle frühesten Check-Zeitpunkt
        let earliestCheck = nextCheckDates.min()!

        // Wenn Check in weniger als 5 Minuten: Schedule in 60 Sekunden
        if earliestCheck.timeIntervalSince(now) < 300 {
            let immediateCheck = Date(timeIntervalSinceNow: 60)
            logger.info("⚡ Next reminder <5min away, scheduling immediate check at \(self.formatDate(immediateCheck))")
            return immediateCheck
        }

        logger.info("📅 Next check scheduled at \(self.formatDate(earliestCheck))")
        return earliestCheck
    }

    /// Berechnet den nächsten Trigger-Zeitpunkt für einen Reminder.
    /// Berücksichtigt Wochentage und findet den nächsten passenden Tag.
    private func calculateNextTriggerDate(for reminder: SmartReminder, from now: Date, calendar: Calendar) -> Date? {
        // Trigger-Zeit heute
        guard let todayTrigger = calendar.date(bySettingHour: reminder.triggerHour, minute: 0, second: 0, of: now) else {
            return nil
        }

        let todayWeekday = calendar.component(.weekday, from: now)
        let today = Weekday.from(calendarWeekday: todayWeekday)

        // Prüfe ob heute im Zeitfenster und in selectedDays
        if reminder.selectedDays.contains(today) {
            if let triggerEnd = calendar.date(byAdding: .minute, value: reminder.windowMinutes, to: todayTrigger),
               now <= triggerEnd {
                // Heute noch im Zeitfenster
                return todayTrigger
            }
        }

        // Suche nächsten passenden Tag (max 7 Tage voraus)
        for daysAhead in 1...7 {
            guard let futureDate = calendar.date(byAdding: .day, value: daysAhead, to: now),
                  let futureTrigger = calendar.date(bySettingHour: reminder.triggerHour, minute: 0, second: 0, of: futureDate) else {
                continue
            }

            let futureWeekday = calendar.component(.weekday, from: futureDate)
            let futureDay = Weekday.from(calendarWeekday: futureWeekday)

            if reminder.selectedDays.contains(futureDay) {
                return futureTrigger
            }
        }

        return nil
    }

    /// Plant die nächste BGTask-Prüfung (NEU: basierend auf calculateNextCheckDate).
    private func scheduleNextCheck() {
        // Cancel alle vorherigen Tasks
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "com.henemm.smartreminders.check")

        guard let nextCheckDate = calculateNextCheckDate() else {
            logger.info("⚠️ No next check date calculated, not scheduling BGTask")
            return
        }

        let request = BGAppRefreshTaskRequest(identifier: "com.henemm.smartreminders.check")
        request.earliestBeginDate = nextCheckDate

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("✅ Scheduled next reminder check at \(self.formatDate(nextCheckDate))")
        } catch {
            logger.error("❌ Failed to schedule BGTask: \(error.localizedDescription)")
        }
    }
    #endif

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
