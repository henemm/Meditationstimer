//
//  TrackerModelTests.swift
//  LeanHealthTimerTests
//
//  Created by Claude on 19.12.2025.
//
//  Unit tests for Custom Tracker SwiftData models.
//

import XCTest
import SwiftData
@testable import Lean_Health_Timer

final class TrackerModelTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        // Create in-memory container for testing
        let schema = Schema([Tracker.self, TrackerLog.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - TDD RED Phase Tests (Generic Tracker System)

    // Test 6: Mood Preset Exists
    func testMoodPresetExists() {
        // GIVEN: TrackerPreset.all array
        let allPresets = TrackerPreset.all

        // WHEN: Searching for "Mood" preset
        let moodPreset = allPresets.first { $0.name == "Mood" }

        // THEN: Preset exists with 5 mood levels
        // NOTE: This will FAIL because Mood preset doesn't exist yet
        XCTAssertNotNil(moodPreset, "Mood preset should exist in TrackerPreset.all")

        if let preset = moodPreset {
            XCTAssertEqual(preset.localizedName, "Stimmung")
            XCTAssertEqual(preset.icon, "😊")
            XCTAssertEqual(preset.type, .good)
            XCTAssertEqual(preset.trackingMode, .levels)
            XCTAssertEqual(preset.healthKitType, "HKStateOfMind")
            XCTAssertEqual(preset.levels?.count, 5, "Mood should have 5 levels")
            XCTAssertNil(preset.rewardConfig, "Mood should not have reward config")
        }
    }

    // Test 7: NoAlc Labels Localized
    func testNoAlcLabelsLocalized() {
        // GIVEN: NoAlc TrackerLevel
        let noAlcLevels = TrackerLevel.noAlcLevels

        XCTAssertEqual(noAlcLevels.count, 3, "NoAlc should have 3 levels")

        // THEN: Labels should use localization keys
        // NOTE: This will FAIL because labels are still "Steady"/"Easy"/"Wild" instead of "NoAlc.Steady" etc
        let steady = noAlcLevels[0]
        XCTAssertEqual(steady.labelKey, "NoAlc.Steady", "Should use localization key")
        XCTAssertEqual(steady.key, "steady")
        XCTAssertEqual(steady.icon, "💧")

        let easy = noAlcLevels[1]
        XCTAssertEqual(easy.labelKey, "NoAlc.Easy", "Should use localization key")
        XCTAssertEqual(easy.key, "easy")
        XCTAssertEqual(easy.icon, "✨")

        let wild = noAlcLevels[2]
        XCTAssertEqual(wild.labelKey, "NoAlc.Wild", "Should use localization key")
        XCTAssertEqual(wild.key, "wild")
        XCTAssertEqual(wild.icon, "💥")
    }

    // MARK: - Tracker Creation Tests

    func testCreateTracker() {
        // Given
        let tracker = Tracker(
            name: "Water",
            icon: "💧",
            type: .good,
            trackingMode: .counter,
            dailyGoal: 8
        )

        // When
        context.insert(tracker)
        try! context.save()

        // Then
        let descriptor = FetchDescriptor<Tracker>()
        let trackers = try! context.fetch(descriptor)
        XCTAssertEqual(trackers.count, 1)
        XCTAssertEqual(trackers.first?.name, "Water")
        XCTAssertEqual(trackers.first?.icon, "💧")
        XCTAssertEqual(trackers.first?.type, .good)
        XCTAssertEqual(trackers.first?.trackingMode, .counter)
        XCTAssertEqual(trackers.first?.dailyGoal, 8)
        XCTAssertTrue(trackers.first?.isActive ?? false)
    }

    func testCreateSaboteurTracker() {
        // Given
        let tracker = Tracker(
            name: "Doomscrolling",
            icon: "📱",
            type: .saboteur,
            trackingMode: .awareness
        )

        // When
        context.insert(tracker)
        try! context.save()

        // Then
        let descriptor = FetchDescriptor<Tracker>()
        let trackers = try! context.fetch(descriptor)
        XCTAssertEqual(trackers.first?.type, .saboteur)
        XCTAssertEqual(trackers.first?.trackingMode, .awareness)
    }

    // MARK: - TrackerLog Tests

    func testLogEntry() {
        // Given
        let tracker = Tracker(
            name: "Water",
            icon: "💧",
            type: .good,
            trackingMode: .counter
        )
        context.insert(tracker)

        // When
        let log = TrackerLog(value: 1, tracker: tracker)
        context.insert(log)
        tracker.logs.append(log)
        try! context.save()

        // Then
        XCTAssertEqual(tracker.logs.count, 1)
        XCTAssertEqual(tracker.logs.first?.value, 1)
        XCTAssertNotNil(tracker.logs.first?.timestamp)
    }

    func testLogWithNote() {
        // Given
        let tracker = Tracker(
            name: "Gratitude",
            icon: "🙏",
            type: .good,
            trackingMode: .yesNo
        )
        context.insert(tracker)

        // When
        let log = TrackerLog(note: "Thankful for sunny day", tracker: tracker)
        context.insert(log)
        tracker.logs.append(log)
        try! context.save()

        // Then
        XCTAssertEqual(tracker.logs.first?.note, "Thankful for sunny day")
    }

    func testLogWithTrigger() {
        // Given
        let tracker = Tracker(
            name: "Snacking",
            icon: "🍫",
            type: .saboteur,
            trackingMode: .awareness
        )
        context.insert(tracker)

        // When
        let log = TrackerLog(trigger: "Bored at work", tracker: tracker)
        context.insert(log)
        tracker.logs.append(log)
        try! context.save()

        // Then
        XCTAssertEqual(tracker.logs.first?.trigger, "Bored at work")
    }

    // MARK: - Preset Tests

    func testPresetCreation() {
        // Given
        let waterPreset = TrackerPreset.all.first { $0.name == "Drink Water" }!

        // When
        let tracker = waterPreset.createTracker()
        context.insert(tracker)
        try! context.save()

        // Then
        XCTAssertEqual(tracker.name, "Drink Water")
        XCTAssertEqual(tracker.icon, "💧")
        XCTAssertEqual(tracker.type, .good)
        XCTAssertEqual(tracker.trackingMode, .counter)
        XCTAssertEqual(tracker.dailyGoal, 8)
        XCTAssertEqual(tracker.healthKitType, "HKQuantityTypeIdentifierDietaryWater")
        XCTAssertTrue(tracker.saveToHealthKit)
    }

    func testAllPresetsExist() {
        // Check all expected presets are available
        let presets = TrackerPreset.all
        XCTAssertGreaterThanOrEqual(presets.count, 8)

        let names = presets.map { $0.name }
        XCTAssertTrue(names.contains("Mood"))
        XCTAssertTrue(names.contains("Feelings"))
        XCTAssertTrue(names.contains("Gratitude"))
        XCTAssertTrue(names.contains("Drink Water"))
        XCTAssertTrue(names.contains("Doomscrolling"))
        XCTAssertTrue(names.contains("Snacking"))
        XCTAssertTrue(names.contains("Procrastination"))
        XCTAssertTrue(names.contains("Rumination"))
    }

    // MARK: - TrackerManager Tests

    func testTrackerManagerCreateFromPreset() {
        // Given
        let preset = TrackerPreset.all.first { $0.name == "Mood" }!

        // When
        let tracker = TrackerManager.shared.createFromPreset(preset, in: context)
        try! context.save()

        // Then
        XCTAssertEqual(tracker.name, "Mood")
        XCTAssertEqual(tracker.type, .good)
    }

    func testTrackerManagerQuickLog() {
        // Given
        let tracker = Tracker(
            name: "Water",
            icon: "💧",
            type: .good,
            trackingMode: .counter
        )
        context.insert(tracker)

        // When
        _ = TrackerManager.shared.quickLog(for: tracker, in: context)
        try! context.save()

        // Then
        XCTAssertEqual(tracker.logs.count, 1)
    }

    func testTrackerManagerTodayLogs() {
        // Given
        let tracker = Tracker(
            name: "Water",
            icon: "💧",
            type: .good,
            trackingMode: .counter
        )
        context.insert(tracker)

        // Create logs for today
        let log1 = TrackerLog(value: 1, tracker: tracker)
        let log2 = TrackerLog(value: 1, tracker: tracker)
        context.insert(log1)
        context.insert(log2)
        tracker.logs.append(log1)
        tracker.logs.append(log2)
        try! context.save()

        // When
        let todayLogs = TrackerManager.shared.todayLogs(for: tracker, in: context)

        // Then
        XCTAssertEqual(todayLogs.count, 2)
    }

    func testTrackerManagerIsLoggedToday() {
        // Given
        let tracker = Tracker(
            name: "Meditation",
            icon: "🧘",
            type: .good,
            trackingMode: .yesNo
        )
        context.insert(tracker)

        // When (no logs yet)
        XCTAssertFalse(TrackerManager.shared.isLoggedToday(for: tracker, in: context))

        // When (add a log)
        let log = TrackerLog(tracker: tracker)
        context.insert(log)
        tracker.logs.append(log)
        try! context.save()

        // Then
        XCTAssertTrue(TrackerManager.shared.isLoggedToday(for: tracker, in: context))
    }

    // MARK: - Streak Calculation Tests

    func testActiveStreakNoLogs() {
        // Given
        let tracker = Tracker(
            name: "Water",
            icon: "💧",
            type: .good,
            trackingMode: .counter
        )
        context.insert(tracker)

        // When
        let streak = TrackerManager.shared.streak(for: tracker, in: context)

        // Then
        XCTAssertEqual(streak, 0)
    }

    func testActiveStreakWithTodayLog() {
        // Given
        let tracker = Tracker(
            name: "Water",
            icon: "💧",
            type: .good,
            trackingMode: .counter
        )
        context.insert(tracker)

        let log = TrackerLog(value: 1, tracker: tracker)
        context.insert(log)
        tracker.logs.append(log)
        try! context.save()

        // When
        let streak = TrackerManager.shared.streak(for: tracker, in: context)

        // Then
        XCTAssertEqual(streak, 1)
    }

    func testActiveStreakConsecutiveDays() {
        // Given
        let tracker = Tracker(
            name: "Water",
            icon: "💧",
            type: .good,
            trackingMode: .counter
        )
        context.insert(tracker)

        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        // Add logs for 3 consecutive days
        let log1 = TrackerLog(timestamp: twoDaysAgo, value: 1, tracker: tracker)
        let log2 = TrackerLog(timestamp: yesterday, value: 1, tracker: tracker)
        let log3 = TrackerLog(timestamp: today, value: 1, tracker: tracker)

        context.insert(log1)
        context.insert(log2)
        context.insert(log3)
        tracker.logs.append(contentsOf: [log1, log2, log3])
        try! context.save()

        // When
        let streak = TrackerManager.shared.streak(for: tracker, in: context)

        // Then
        XCTAssertEqual(streak, 3)
    }

    func testAvoidanceStreakNoLogs() {
        // Given - Avoidance tracker created "today"
        let tracker = Tracker(
            name: "NoSmoking",
            icon: "🚭",
            type: .saboteur,
            trackingMode: .avoidance
        )
        context.insert(tracker)
        try! context.save()

        // When
        let streak = TrackerManager.shared.streak(for: tracker, in: context)

        // Then - Streak should be 0 (created today)
        XCTAssertEqual(streak, 0)
    }

    func testAvoidanceStreakAfterRelapse() {
        // Given
        let calendar = Calendar.current
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: Date())!

        let tracker = Tracker(
            name: "NoSmoking",
            icon: "🚭",
            type: .saboteur,
            trackingMode: .avoidance,
            createdAt: calendar.date(byAdding: .day, value: -10, to: Date())!
        )
        context.insert(tracker)

        // Log a relapse 2 days ago
        let relapseLog = TrackerLog(timestamp: twoDaysAgo, tracker: tracker)
        context.insert(relapseLog)
        tracker.logs.append(relapseLog)
        try! context.save()

        // When
        let streak = TrackerManager.shared.streak(for: tracker, in: context)

        // Then - 2 days since last relapse
        XCTAssertEqual(streak, 2)
    }

    // MARK: - DayAssignment Tests

    func testDayAssignmentTimestamp() {
        // Given: Default assignment (timestamp)
        let assignment = DayAssignment.timestamp
        let calendar = Calendar.current

        // When: Log at 9:00 on Tuesday
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 31 // Tuesday
        components.hour = 9
        components.minute = 0
        let tuesdayMorning = calendar.date(from: components)!

        let assignedDay = assignment.assignedDay(for: tuesdayMorning, calendar: calendar)

        // Then: Should be Tuesday (same day)
        let expectedDay = calendar.startOfDay(for: tuesdayMorning)
        XCTAssertEqual(assignedDay, expectedDay)
    }

    func testDayAssignmentCutoffHourBeforeCutoff() {
        // Given: Cutoff at 18:00
        let assignment = DayAssignment.cutoffHour(18)
        let calendar = Calendar.current

        // When: Log at 9:00 on Tuesday (BEFORE cutoff)
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 31 // Tuesday
        components.hour = 9
        components.minute = 0
        let tuesdayMorning = calendar.date(from: components)!

        let assignedDay = assignment.assignedDay(for: tuesdayMorning, calendar: calendar)

        // Then: Should be Monday (previous day)
        let tuesdayStart = calendar.startOfDay(for: tuesdayMorning)
        let expectedMonday = calendar.date(byAdding: .day, value: -1, to: tuesdayStart)!
        XCTAssertEqual(assignedDay, expectedMonday)
    }

    func testDayAssignmentCutoffHourAtCutoff() {
        // Given: Cutoff at 18:00
        let assignment = DayAssignment.cutoffHour(18)
        let calendar = Calendar.current

        // When: Log at exactly 18:00 on Tuesday (AT cutoff)
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 31 // Tuesday
        components.hour = 18
        components.minute = 0
        let tuesdayEvening = calendar.date(from: components)!

        let assignedDay = assignment.assignedDay(for: tuesdayEvening, calendar: calendar)

        // Then: Should be Tuesday (current day, cutoff hour counts as current day)
        let expectedTuesday = calendar.startOfDay(for: tuesdayEvening)
        XCTAssertEqual(assignedDay, expectedTuesday)
    }

    func testDayAssignmentCutoffHourAfterCutoff() {
        // Given: Cutoff at 18:00
        let assignment = DayAssignment.cutoffHour(18)
        let calendar = Calendar.current

        // When: Log at 20:00 on Tuesday (AFTER cutoff)
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 31 // Tuesday
        components.hour = 20
        components.minute = 0
        let tuesdayNight = calendar.date(from: components)!

        let assignedDay = assignment.assignedDay(for: tuesdayNight, calendar: calendar)

        // Then: Should be Tuesday (current day)
        let expectedTuesday = calendar.startOfDay(for: tuesdayNight)
        XCTAssertEqual(assignedDay, expectedTuesday)
    }

    func testTrackerEffectiveDayAssignmentParsesCorrectly() {
        // Given: NoAlc preset with cutoffHour:18
        let noAlcPreset = TrackerPreset.all.first { $0.name == "NoAlc" }!
        let tracker = noAlcPreset.createTracker()
        context.insert(tracker)

        // When
        let dayAssignment = tracker.effectiveDayAssignment

        // Then: Should parse as cutoffHour(18)
        if case .cutoffHour(let hour) = dayAssignment {
            XCTAssertEqual(hour, 18)
        } else {
            XCTFail("Expected .cutoffHour(18), got \(dayAssignment)")
        }
    }

    // MARK: - Delete Cascade Test

    func testDeleteTrackerCascadesLogs() {
        // Given
        let tracker = Tracker(
            name: "Water",
            icon: "💧",
            type: .good,
            trackingMode: .counter
        )
        context.insert(tracker)

        let log1 = TrackerLog(value: 1, tracker: tracker)
        let log2 = TrackerLog(value: 1, tracker: tracker)
        context.insert(log1)
        context.insert(log2)
        tracker.logs.append(contentsOf: [log1, log2])
        try! context.save()

        // Verify logs exist
        let logsBeforeDelete = try! context.fetch(FetchDescriptor<TrackerLog>())
        XCTAssertEqual(logsBeforeDelete.count, 2)

        // When
        TrackerManager.shared.deleteTracker(tracker, from: context)
        try! context.save()

        // Then
        let trackersAfterDelete = try! context.fetch(FetchDescriptor<Tracker>())
        let logsAfterDelete = try! context.fetch(FetchDescriptor<TrackerLog>())

        XCTAssertEqual(trackersAfterDelete.count, 0)
        XCTAssertEqual(logsAfterDelete.count, 0, "Logs should be cascade deleted with tracker")
    }

    // MARK: - TDD RED Phase 2-3: Generic Level Logging

    /// Test 10: Tracker has logLevel convenience method
    /// This test will FAIL until Tracker.logLevel() is implemented
    func testTrackerHasLogLevelMethod() {
        // GIVEN: A NoAlc tracker created from preset
        guard let noAlcPreset = TrackerPreset.all.first(where: { $0.name == "NoAlc" }) else {
            XCTFail("NoAlc preset should exist")
            return
        }
        let tracker = noAlcPreset.createTracker()
        context.insert(tracker)
        try! context.save()

        // WHEN: We try to log a level using the convenience method
        // This method should create a TrackerLog with the level's id as value
        let steadyLevel = TrackerLevel.noAlcLevels[0] // "steady"

        // THEN: The method should exist and work
        // NOTE: This will FAIL because logLevel() doesn't exist yet
        tracker.logLevel(steadyLevel, context: context)

        // Verify log was created
        XCTAssertEqual(tracker.logs.count, 1, "Should have created 1 log")
        XCTAssertEqual(tracker.logs.first?.value, steadyLevel.id, "Log value should be level id")
    }

    /// Test 11: NoAlc tracker can log different levels
    /// This test will FAIL until Tracker.logLevel() is implemented
    func testNoAlcTrackerCanLogAllLevels() {
        // GIVEN: A NoAlc tracker
        guard let noAlcPreset = TrackerPreset.all.first(where: { $0.name == "NoAlc" }) else {
            XCTFail("NoAlc preset should exist")
            return
        }
        let tracker = noAlcPreset.createTracker()
        context.insert(tracker)

        // WHEN: Logging each level
        for level in TrackerLevel.noAlcLevels {
            tracker.logLevel(level, context: context)
        }
        try! context.save()

        // THEN: Should have 3 logs with correct values
        XCTAssertEqual(tracker.logs.count, 3, "Should have 3 logs")

        let logValues = tracker.logs.map { $0.value }.compactMap { $0 }
        XCTAssertTrue(logValues.contains(0), "Should have log with steady level (0)")
        XCTAssertTrue(logValues.contains(1), "Should have log with easy level (1)")
        XCTAssertTrue(logValues.contains(2), "Should have log with wild level (2)")
    }

    /// Test 12: Tracker.todayLog returns today's log if exists
    /// This test will FAIL until Tracker.todayLog is implemented
    func testTrackerTodayLogProperty() {
        // GIVEN: A NoAlc tracker with a log for today
        guard let noAlcPreset = TrackerPreset.all.first(where: { $0.name == "NoAlc" }) else {
            XCTFail("NoAlc preset should exist")
            return
        }
        let tracker = noAlcPreset.createTracker()
        context.insert(tracker)

        let steadyLevel = TrackerLevel.noAlcLevels[0]
        tracker.logLevel(steadyLevel, context: context)
        try! context.save()

        // WHEN: Accessing todayLog property
        // THEN: Should return today's log
        // NOTE: This will FAIL because todayLog doesn't exist yet
        let todayLog = tracker.todayLog

        XCTAssertNotNil(todayLog, "Should have a log for today")
        XCTAssertEqual(todayLog?.value, steadyLevel.id)
    }

    // MARK: - FEAT-37d: HealthKit Value Mapping Tests (TDD RED)

    /// Test: TrackerLevel.healthKitValue for "steady" returns 0
    /// This test will FAIL because healthKitValue property doesn't exist yet
    func testTrackerLevelHealthKitValueSteady() {
        // GIVEN: NoAlc steady level
        let steadyLevel = TrackerLevel.noAlcLevels[0]
        XCTAssertEqual(steadyLevel.key, "steady")

        // WHEN: Accessing healthKitValue
        // THEN: Should return 0 (HealthKit encoding for steady)
        XCTAssertEqual(steadyLevel.healthKitValue, 0,
            "Steady level should map to HealthKit value 0")
    }

    /// Test: TrackerLevel.healthKitValue for "easy" returns 4
    /// This test will FAIL because healthKitValue property doesn't exist yet
    func testTrackerLevelHealthKitValueEasy() {
        // GIVEN: NoAlc easy level
        let easyLevel = TrackerLevel.noAlcLevels[1]
        XCTAssertEqual(easyLevel.key, "easy")

        // WHEN: Accessing healthKitValue
        // THEN: Should return 4 (HealthKit encoding for easy)
        XCTAssertEqual(easyLevel.healthKitValue, 4,
            "Easy level should map to HealthKit value 4")
    }

    /// Test: TrackerLevel.healthKitValue for "wild" returns 6
    /// This test will FAIL because healthKitValue property doesn't exist yet
    func testTrackerLevelHealthKitValueWild() {
        // GIVEN: NoAlc wild level
        let wildLevel = TrackerLevel.noAlcLevels[2]
        XCTAssertEqual(wildLevel.key, "wild")

        // WHEN: Accessing healthKitValue
        // THEN: Should return 6 (HealthKit encoding for wild)
        XCTAssertEqual(wildLevel.healthKitValue, 6,
            "Wild level should map to HealthKit value 6")
    }

    // MARK: - Edit-Mode Tests (Generic Tracker System Completion)

    /// Test: Tracker levels can be modified
    func testTrackerLevelsCanBeModified() {
        // GIVEN: A NoAlc tracker
        guard let noAlcPreset = TrackerPreset.all.first(where: { $0.name == "NoAlc" }) else {
            XCTFail("NoAlc preset should exist")
            return
        }
        let tracker = noAlcPreset.createTracker()
        context.insert(tracker)

        // Verify initial levels
        XCTAssertEqual(tracker.levels?.count, 3)

        // WHEN: Modifying levels
        let newLevels = [
            TrackerLevel(id: 0, key: "perfect", icon: "🌟", labelKey: "Perfect", streakEffect: .success),
            TrackerLevel(id: 1, key: "good", icon: "✅", labelKey: "Good", streakEffect: .success),
            TrackerLevel(id: 2, key: "okay", icon: "😐", labelKey: "Okay", streakEffect: .needsGrace),
            TrackerLevel(id: 3, key: "bad", icon: "❌", labelKey: "Bad", streakEffect: .breaksStreak)
        ]
        tracker.levels = newLevels
        try! context.save()

        // THEN: Levels should be updated
        XCTAssertEqual(tracker.levels?.count, 4)
        XCTAssertEqual(tracker.levels?[0].key, "perfect")
        XCTAssertEqual(tracker.levels?[3].streakEffect, .breaksStreak)
    }

    /// Test: Tracker rewardConfig (Joker System) can be modified
    func testTrackerJokerConfigCanBeModified() {
        // GIVEN: A NoAlc tracker with default joker config
        guard let noAlcPreset = TrackerPreset.all.first(where: { $0.name == "NoAlc" }) else {
            XCTFail("NoAlc preset should exist")
            return
        }
        let tracker = noAlcPreset.createTracker()
        context.insert(tracker)

        // Verify initial joker config
        XCTAssertNotNil(tracker.rewardConfig)
        XCTAssertEqual(tracker.rewardConfig?.earnEveryDays, 7)
        XCTAssertEqual(tracker.rewardConfig?.maxOnHand, 3)

        // WHEN: Modifying joker config
        tracker.rewardConfig = RewardConfig(
            earnEveryDays: 14,
            maxOnHand: 5,
            canHealGrace: true
        )
        try! context.save()

        // THEN: Config should be updated
        XCTAssertEqual(tracker.rewardConfig?.earnEveryDays, 14)
        XCTAssertEqual(tracker.rewardConfig?.maxOnHand, 5)
    }

    /// Test: Tracker rewardConfig can be disabled
    func testTrackerJokerConfigCanBeDisabled() {
        // GIVEN: A NoAlc tracker with joker config
        guard let noAlcPreset = TrackerPreset.all.first(where: { $0.name == "NoAlc" }) else {
            XCTFail("NoAlc preset should exist")
            return
        }
        let tracker = noAlcPreset.createTracker()
        context.insert(tracker)
        XCTAssertNotNil(tracker.rewardConfig)

        // WHEN: Disabling joker config
        tracker.rewardConfig = nil
        try! context.save()

        // THEN: Config should be nil
        XCTAssertNil(tracker.rewardConfig)
    }

    /// Test: Tracker dayAssignmentRaw can be modified
    func testTrackerDayBoundaryCanBeModified() {
        // GIVEN: A NoAlc tracker with 18:00 cutoff
        guard let noAlcPreset = TrackerPreset.all.first(where: { $0.name == "NoAlc" }) else {
            XCTFail("NoAlc preset should exist")
            return
        }
        let tracker = noAlcPreset.createTracker()
        context.insert(tracker)

        // Verify initial day boundary
        if case .cutoffHour(let hour) = tracker.effectiveDayAssignment {
            XCTAssertEqual(hour, 18)
        } else {
            XCTFail("Expected cutoffHour(18)")
        }

        // WHEN: Changing to different cutoff hour
        tracker.dayAssignmentRaw = "cutoffHour:20"
        try! context.save()

        // THEN: Day boundary should be updated
        if case .cutoffHour(let hour) = tracker.effectiveDayAssignment {
            XCTAssertEqual(hour, 20)
        } else {
            XCTFail("Expected cutoffHour(20)")
        }
    }

    /// Test: Tracker dayAssignmentRaw can be set to midnight
    func testTrackerDayBoundaryCanBeSetToMidnight() {
        // GIVEN: A NoAlc tracker with 18:00 cutoff
        guard let noAlcPreset = TrackerPreset.all.first(where: { $0.name == "NoAlc" }) else {
            XCTFail("NoAlc preset should exist")
            return
        }
        let tracker = noAlcPreset.createTracker()
        context.insert(tracker)

        // WHEN: Setting to midnight (nil = timestamp/midnight)
        tracker.dayAssignmentRaw = nil
        try! context.save()

        // THEN: Should use timestamp (midnight)
        if case .timestamp = tracker.effectiveDayAssignment {
            // Success
        } else {
            XCTFail("Expected .timestamp")
        }
    }

    // MARK: - TDD RED: Drag & Drop Sorting (FEAT-tracker-drag-drop)

    /// Test: Tracker has displayOrder property that defaults to 0
    /// This test will FAIL because displayOrder property doesn't exist yet
    func testTrackerHasDisplayOrderProperty() {
        // GIVEN: A new tracker
        let tracker = Tracker(
            name: "Test",
            icon: "📝",
            type: .good,
            trackingMode: .yesNo
        )
        context.insert(tracker)
        try! context.save()

        // THEN: displayOrder should exist and default to 0
        // NOTE: This will FAIL because displayOrder doesn't exist yet
        XCTAssertEqual(tracker.displayOrder, 0,
            "New tracker should have displayOrder = 0")
    }

    /// Test: Tracker displayOrder can be modified
    /// This test will FAIL because displayOrder property doesn't exist yet
    func testTrackerDisplayOrderCanBeModified() {
        // GIVEN: Two trackers
        let tracker1 = Tracker(
            name: "First",
            icon: "1️⃣",
            type: .good,
            trackingMode: .yesNo
        )
        let tracker2 = Tracker(
            name: "Second",
            icon: "2️⃣",
            type: .good,
            trackingMode: .yesNo
        )
        context.insert(tracker1)
        context.insert(tracker2)

        // WHEN: Setting displayOrder
        tracker1.displayOrder = 2
        tracker2.displayOrder = 1
        try! context.save()

        // THEN: Order should be persisted
        XCTAssertEqual(tracker1.displayOrder, 2)
        XCTAssertEqual(tracker2.displayOrder, 1)
    }

    /// Test: Trackers can be sorted by displayOrder
    /// This test will FAIL because displayOrder property doesn't exist yet
    func testTrackersSortByDisplayOrder() {
        // GIVEN: Three trackers with different displayOrder
        let trackerA = Tracker(name: "A", icon: "🅰️", type: .good, trackingMode: .yesNo)
        let trackerB = Tracker(name: "B", icon: "🅱️", type: .good, trackingMode: .yesNo)
        let trackerC = Tracker(name: "C", icon: "©️", type: .good, trackingMode: .yesNo)

        context.insert(trackerA)
        context.insert(trackerB)
        context.insert(trackerC)

        trackerA.displayOrder = 3
        trackerB.displayOrder = 1
        trackerC.displayOrder = 2
        try! context.save()

        // WHEN: Sorting by displayOrder
        let sortDescriptor = SortDescriptor(\Tracker.displayOrder)
        let descriptor = FetchDescriptor<Tracker>(sortBy: [sortDescriptor])
        let sortedTrackers = try! context.fetch(descriptor)

        // THEN: Should be sorted B, C, A
        XCTAssertEqual(sortedTrackers[0].name, "B", "First should be B (order=1)")
        XCTAssertEqual(sortedTrackers[1].name, "C", "Second should be C (order=2)")
        XCTAssertEqual(sortedTrackers[2].name, "A", "Third should be A (order=3)")
    }
}
