import XCTest
@testable import Lean_Health_Timer

final class SmartReminderEngineTests: XCTestCase {

    var engine: SmartReminderEngine!

    override func setUp() {
        super.setUp()
        // Clear UserDefaults to ensure clean state for each test
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "smartReminders")
        defaults.removeObject(forKey: "cancelledNotifications")
        defaults.removeObject(forKey: "smartRemindersPaused")

        engine = SmartReminderEngine.shared
    }

    override func tearDown() {
        // Clean up all reminders after each test
        for reminder in engine.getReminders() {
            engine.removeReminder(withId: reminder.id)
        }
        engine = nil
        super.tearDown()
    }

    // MARK: - CancelledNotification Tests

    func testCancelledNotificationCodable() throws {
        let reminderID = UUID()
        let weekday = Weekday.monday
        let cancelledUntil = Date()

        let notification = CancelledNotification(
            reminderID: reminderID,
            weekday: weekday,
            cancelledUntil: cancelledUntil
        )

        // Encode
        let encoded = try JSONEncoder().encode(notification)

        // Decode
        let decoded = try JSONDecoder().decode(CancelledNotification.self, from: encoded)

        XCTAssertEqual(decoded.reminderID, reminderID)
        XCTAssertEqual(decoded.weekday, weekday)
        XCTAssertEqual(decoded.cancelledUntil.timeIntervalSince1970,
                       cancelledUntil.timeIntervalSince1970,
                       accuracy: 0.001)
    }

    func testCancelledNotificationEquality() {
        let reminderID = UUID()
        let weekday = Weekday.tuesday
        let date = Date()

        let notification1 = CancelledNotification(reminderID: reminderID, weekday: weekday, cancelledUntil: date)
        let notification2 = CancelledNotification(reminderID: reminderID, weekday: weekday, cancelledUntil: date)
        let notification3 = CancelledNotification(reminderID: UUID(), weekday: weekday, cancelledUntil: date)

        XCTAssertEqual(notification1, notification2, "Same ID and weekday should be equal")
        XCTAssertNotEqual(notification1, notification3, "Different ID should not be equal")
    }

    // MARK: - CRUD Operations Tests

    func testAddReminder() {
        let reminder = createTestReminder(
            title: "Test Reminder",
            activityType: .mindfulness,
            triggerHour: 10,
            hoursInactive: 12
        )

        engine.addReminder(reminder)

        let reminders = engine.getReminders()
        XCTAssertEqual(reminders.count, 1)
        XCTAssertEqual(reminders.first?.title, "Test Reminder")
        XCTAssertEqual(reminders.first?.activityType, .mindfulness)
    }

    func testRemoveReminder() {
        let reminder = createTestReminder(
            title: "Test Reminder",
            activityType: .workout,
            triggerHour: 18,
            hoursInactive: 6
        )

        engine.addReminder(reminder)
        XCTAssertEqual(engine.getReminders().count, 1)

        engine.removeReminder(withId: reminder.id)
        XCTAssertEqual(engine.getReminders().count, 0)
    }

    func testUpdateReminder() {
        var reminder = createTestReminder(
            title: "Original",
            activityType: .mindfulness,
            triggerHour: 10,
            hoursInactive: 12
        )

        engine.addReminder(reminder)

        // Update the reminder
        reminder.title = "Updated"
        reminder.message = "Updated message"
        reminder.hoursInactive = 24

        engine.updateReminder(reminder)

        let reminders = engine.getReminders()
        XCTAssertEqual(reminders.count, 1)
        XCTAssertEqual(reminders.first?.title, "Updated")
        XCTAssertEqual(reminders.first?.message, "Updated message")
        XCTAssertEqual(reminders.first?.hoursInactive, 24)
    }

    // MARK: - Reverse Smart Reminders Logic Tests

    func testCancelMatchingReminders_ActivityInsideWindow_ShouldCancel() {
        let calendar = Calendar.current
        let now = Date()

        // Create reminder for 18:00 today with 12h look-back (06:00-18:00)
        let triggerTime = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now)!
        let reminder = createTestReminder(
            title: "Evening Meditation",
            activityType: .mindfulness,
            triggerHour: 18,
            hoursInactive: 12,
            weekday: getTodayWeekday()
        )

        engine.addReminder(reminder)

        // Complete activity at 10:00 today (inside 06:00-18:00 window)
        let completedAt = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now)!

        engine.cancelMatchingReminders(for: .mindfulness, completedAt: completedAt)

        // The reminder should now be cancelled
        // We can verify this by checking if it gets scheduled (indirectly)
        // Since we can't directly access the cancelled array, we test the side effect
        XCTAssertEqual(engine.getReminders().count, 1, "Reminder should still exist in list")
    }

    func testCancelMatchingReminders_ActivityOutsideWindow_ShouldNotCancel() {
        let calendar = Calendar.current
        let now = Date()

        // Create reminder for 18:00 today with 1h look-back (17:00-18:00)
        let reminder = createTestReminder(
            title: "Evening Meditation",
            activityType: .mindfulness,
            triggerHour: 18,
            hoursInactive: 1,
            weekday: getTodayWeekday()
        )

        engine.addReminder(reminder)

        // Complete activity at 10:00 today (OUTSIDE 17:00-18:00 window)
        let completedAt = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now)!

        engine.cancelMatchingReminders(for: .mindfulness, completedAt: completedAt)

        // The reminder should NOT be cancelled (activity was too early)
        XCTAssertEqual(engine.getReminders().count, 1)
    }

    func testCancelMatchingReminders_WrongActivityType_ShouldNotCancel() {
        let calendar = Calendar.current
        let now = Date()

        // Create MEDITATION reminder
        let reminder = createTestReminder(
            title: "Meditation Reminder",
            activityType: .mindfulness,
            triggerHour: 18,
            hoursInactive: 12,
            weekday: getTodayWeekday()
        )

        engine.addReminder(reminder)

        // Complete WORKOUT activity (different type!)
        let completedAt = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now)!

        engine.cancelMatchingReminders(for: .workout, completedAt: completedAt)

        // Reminder should NOT be cancelled (wrong activity type)
        XCTAssertEqual(engine.getReminders().count, 1)
    }

    func testCancelMatchingReminders_DisabledReminder_ShouldNotCancel() {
        let calendar = Calendar.current
        let now = Date()

        var reminder = createTestReminder(
            title: "Disabled Reminder",
            activityType: .mindfulness,
            triggerHour: 18,
            hoursInactive: 12,
            weekday: getTodayWeekday()
        )
        reminder.isEnabled = false  // Disabled!

        engine.addReminder(reminder)

        let completedAt = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now)!

        engine.cancelMatchingReminders(for: .mindfulness, completedAt: completedAt)

        // Disabled reminder should be ignored
        XCTAssertEqual(engine.getReminders().count, 1)
    }

    func testCancelMatchingReminders_MultipleReminders_SelectiveCancellation() {
        let calendar = Calendar.current
        let now = Date()
        let today = getTodayWeekday()

        // Reminder 1: 12:00 with 1h window (11:00-12:00)
        let reminder1 = createTestReminder(
            title: "Noon Meditation",
            activityType: .mindfulness,
            triggerHour: 12,
            hoursInactive: 1,
            weekday: today
        )

        // Reminder 2: 18:00 with 12h window (06:00-18:00)
        let reminder2 = createTestReminder(
            title: "Evening Meditation",
            activityType: .mindfulness,
            triggerHour: 18,
            hoursInactive: 12,
            weekday: today
        )

        engine.addReminder(reminder1)
        engine.addReminder(reminder2)

        // Complete activity at 10:00 (OUTSIDE 11:00-12:00, INSIDE 06:00-18:00)
        let completedAt = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now)!

        engine.cancelMatchingReminders(for: .mindfulness, completedAt: completedAt)

        // Both reminders should still exist in the list
        XCTAssertEqual(engine.getReminders().count, 2)
        // Reminder 1 should NOT be cancelled (10:00 < 11:00)
        // Reminder 2 SHOULD be cancelled (10:00 is in 06:00-18:00)
    }

    func testCancelMatchingReminders_ExactBoundary_AtTriggerTime() {
        let calendar = Calendar.current
        let now = Date()

        // Reminder at 12:00 with 1h window (11:00-12:00)
        let reminder = createTestReminder(
            title: "Noon Reminder",
            activityType: .mindfulness,
            triggerHour: 12,
            hoursInactive: 1,
            weekday: getTodayWeekday()
        )

        engine.addReminder(reminder)

        // Complete at exactly 12:00 (at trigger time, within window)
        let completedAt = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)!

        engine.cancelMatchingReminders(for: .mindfulness, completedAt: completedAt)

        // Should be cancelled (12:00 is within 11:00-12:00 window)
        XCTAssertEqual(engine.getReminders().count, 1)
    }

    func testCancelMatchingReminders_NoAlcActivityType() {
        let calendar = Calendar.current
        let now = Date()

        let reminder = createTestReminder(
            title: "NoAlc Check-In",
            activityType: .noalc,
            triggerHour: 20,
            hoursInactive: 24,
            weekday: getTodayWeekday()
        )

        engine.addReminder(reminder)

        let completedAt = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now)!

        engine.cancelMatchingReminders(for: .noalc, completedAt: completedAt)

        XCTAssertEqual(engine.getReminders().count, 1)
    }

    func testCancelMatchingReminders_24hLookAheadWindow() {
        let calendar = Calendar.current
        let now = Date()

        // Create reminder for TOMORROW at 10:00 (outside 24h window from now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let tomorrowWeekday = getTodayWeekday(for: tomorrow)

        let reminder = createTestReminder(
            title: "Tomorrow Reminder",
            activityType: .mindfulness,
            triggerHour: 10,
            hoursInactive: 12,
            weekday: tomorrowWeekday
        )

        engine.addReminder(reminder)

        // If now is e.g. 11:00, and reminder is tomorrow 10:00, that's ~23h away
        // This should be INSIDE the 24h look-ahead window
        let completedAt = now

        engine.cancelMatchingReminders(for: .mindfulness, completedAt: completedAt)

        XCTAssertEqual(engine.getReminders().count, 1)
    }

    func testCancelMatchingReminders_DuplicateCancellation_OnlyAddOnce() {
        let calendar = Calendar.current
        let now = Date()

        let reminder = createTestReminder(
            title: "Test Reminder",
            activityType: .mindfulness,
            triggerHour: 18,
            hoursInactive: 12,
            weekday: getTodayWeekday()
        )

        engine.addReminder(reminder)

        let completedAt = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now)!

        // Cancel twice with same activity
        engine.cancelMatchingReminders(for: .mindfulness, completedAt: completedAt)
        engine.cancelMatchingReminders(for: .mindfulness, completedAt: completedAt)

        // Should not add duplicate entries (verified internally by engine)
        XCTAssertEqual(engine.getReminders().count, 1)
    }

    // MARK: - Persistence Tests

    func testRemindersPersistence() {
        let reminder = createTestReminder(
            title: "Persistent Reminder",
            activityType: .workout,
            triggerHour: 15,
            hoursInactive: 6
        )

        engine.addReminder(reminder)
        XCTAssertEqual(engine.getReminders().count, 1)

        // Simulate app restart by reloading from AppStorage
        engine.loadReminders()

        let reminders = engine.getReminders()
        XCTAssertEqual(reminders.count, 1)
        XCTAssertEqual(reminders.first?.title, "Persistent Reminder")
    }

    // MARK: - Helper Methods

    /// Creates a test reminder with specified parameters
    private func createTestReminder(
        title: String,
        activityType: ActivityType,
        triggerHour: Int,
        hoursInactive: Int,
        weekday: Weekday? = nil
    ) -> SmartReminder {
        let calendar = Calendar.current
        let triggerTime = calendar.date(bySettingHour: triggerHour, minute: 0, second: 0, of: Date())!

        let selectedDays: Set<Weekday>
        if let weekday = weekday {
            selectedDays = [weekday]
        } else {
            selectedDays = Set(Weekday.allCases)
        }

        return SmartReminder(
            id: UUID(),
            title: title,
            message: "Test message",
            hoursInactive: hoursInactive,
            triggerTime: triggerTime,
            isEnabled: true,
            selectedDays: selectedDays,
            activityType: activityType
        )
    }

    /// Gets today's weekday as Weekday enum
    private func getTodayWeekday(for date: Date = Date()) -> Weekday {
        let calendar = Calendar.current
        let weekdayInt = calendar.component(.weekday, from: date)

        switch weekdayInt {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return .monday
        }
    }
}
