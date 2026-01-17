//
//  TrackerMigrationTests.swift
//  LeanHealthTimerTests
//
//  Created by Claude on 17.01.2026.
//
//  TDD RED Phase: Tests for TrackerMigration
//  These tests MUST FAIL because TrackerMigration.swift doesn't exist yet.
//

import XCTest
import SwiftData
@testable import Lean_Health_Timer

final class TrackerMigrationTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
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

    // MARK: - Test 1: Migrate Empty NoAlc Data

    func testMigrateEmptyNoAlcData() async throws {
        // GIVEN: Empty database (no trackers, no HealthKit data)
        let beforeDescriptor = FetchDescriptor<Tracker>()
        let beforeCount = try context.fetchCount(beforeDescriptor)
        XCTAssertEqual(beforeCount, 0, "Database should start empty")

        // WHEN: Migration runs with no HealthKit data
        // NOTE: This will FAIL because TrackerMigration doesn't exist yet
        try await TrackerMigration.shared.migrateNoAlcIfNeeded(context: context)

        // THEN: NoAlc Tracker should be created with 0 logs
        let afterDescriptor = FetchDescriptor<Tracker>(
            predicate: #Predicate { $0.name == "NoAlc" }
        )
        let trackers = try context.fetch(afterDescriptor)

        XCTAssertEqual(trackers.count, 1, "NoAlc Tracker should be created")
        let noAlc = try XCTUnwrap(trackers.first)
        XCTAssertEqual(noAlc.name, "NoAlc")
        XCTAssertEqual(noAlc.logs.count, 0, "Should have 0 logs for empty migration")
    }

    // MARK: - Test 2: Migrate NoAlc with Historical Data

    func testMigrateNoAlcWithHistoricalData() async throws {
        // GIVEN: Database with NO NoAlc Tracker yet
        // NOTE: In real scenario, HealthKit would have data
        // For this test, we assume TrackerMigration fetches and creates logs

        // WHEN: Migration runs
        // NOTE: This will FAIL because TrackerMigration doesn't exist
        try await TrackerMigration.shared.migrateNoAlcIfNeeded(context: context)

        // THEN: NoAlc Tracker exists
        let descriptor = FetchDescriptor<Tracker>(
            predicate: #Predicate { $0.name == "NoAlc" }
        )
        let trackers = try context.fetch(descriptor)

        XCTAssertEqual(trackers.count, 1, "NoAlc Tracker should be created")
        let noAlc = try XCTUnwrap(trackers.first)

        // Verify tracker has correct configuration
        XCTAssertEqual(noAlc.type, .saboteur)
        XCTAssertEqual(noAlc.trackingMode, .levels)
        XCTAssertEqual(noAlc.levels?.count, 3, "Should have 3 levels (steady, easy, wild)")
        XCTAssertNotNil(noAlc.rewardConfig, "Should have reward config")
    }

    // MARK: - Test 3: Skip Migration if Tracker Exists

    func testSkipMigrationIfTrackerExists() async throws {
        // GIVEN: NoAlc Tracker already exists
        let existingNoAlc = Tracker(
            name: "NoAlc",
            icon: "🍷",
            type: .saboteur,
            trackingMode: .levels
        )
        context.insert(existingNoAlc)
        try context.save()

        let beforeId = existingNoAlc.id

        // WHEN: Migration runs
        // NOTE: This will FAIL because TrackerMigration doesn't exist
        try await TrackerMigration.shared.migrateNoAlcIfNeeded(context: context)

        // THEN: No duplicate Tracker is created
        let descriptor = FetchDescriptor<Tracker>(
            predicate: #Predicate { $0.name == "NoAlc" }
        )
        let trackers = try context.fetch(descriptor)

        XCTAssertEqual(trackers.count, 1, "Should still have exactly 1 NoAlc Tracker")
        let tracker = try XCTUnwrap(trackers.first)
        XCTAssertEqual(tracker.id, beforeId, "Should be the same tracker (not recreated)")
    }

    // MARK: - Test 4: Streak Calculation After Migration

    func testStreakCalculationAfterMigration() throws {
        // GIVEN: Migrated NoAlc data with specific pattern
        let noAlc = Tracker(
            name: "NoAlc",
            icon: "🍷",
            type: .saboteur,
            trackingMode: .levels
        )

        // Configure as NoAlc preset
        noAlc.levels = TrackerLevel.noAlcLevels
        noAlc.rewardConfig = RewardConfig.noAlcDefault
        noAlc.dayAssignmentRaw = "cutoffHour:18"

        context.insert(noAlc)

        // Add logs: 7 steady days (should earn 1 reward)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let log = TrackerLog(
                timestamp: date,
                value: 0, // steady level (id=0)
                tracker: noAlc
            )
            context.insert(log)
        }

        try context.save()

        // WHEN: Calculate streak
        let result = TrackerManager.shared.calculateStreakResult(for: noAlc)

        // THEN: Streak should be 7 with 1 reward earned
        XCTAssertEqual(result.currentStreak, 7, "Should have 7-day streak")
        XCTAssertEqual(result.availableRewards, 1, "Should have earned 1 reward")
        XCTAssertEqual(result.totalRewardsEarned, 1)
        XCTAssertEqual(result.totalRewardsUsed, 0)
    }

    // MARK: - Test 5: Create Default Trackers

    func testCreateDefaultTrackers() throws {
        // GIVEN: Empty database (no trackers)
        let beforeDescriptor = FetchDescriptor<Tracker>()
        let beforeCount = try context.fetchCount(beforeDescriptor)
        XCTAssertEqual(beforeCount, 0, "Database should start empty")

        // WHEN: createDefaultTrackersIfNeeded runs
        // NOTE: This will FAIL because TrackerMigration doesn't exist
        try TrackerMigration.shared.createDefaultTrackersIfNeeded(context: context)

        // THEN: NoAlc and Mood trackers should be created
        let afterDescriptor = FetchDescriptor<Tracker>()
        let trackers = try context.fetch(afterDescriptor)

        XCTAssertEqual(trackers.count, 2, "Should create 2 default trackers")

        let names = trackers.map { $0.name }.sorted()
        XCTAssertTrue(names.contains("NoAlc"), "Should create NoAlc tracker")
        XCTAssertTrue(names.contains("Mood"), "Should create Mood tracker")
    }
}
