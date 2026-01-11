//
//  StreakManagerJokerTests.swift
//  LeanHealthTimerTests
//
//  TDD RED: Diese Tests werden fehlschlagen bis calculateStreakAndRewards() implementiert ist
//

import XCTest
@testable import Lean_Health_Timer

final class StreakManagerJokerTests: XCTestCase {

    private let calendar = Calendar.current

    // MARK: - Helper

    /// Creates a date X days ago from today
    private func daysAgo(_ days: Int) -> Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -days, to: today)!
    }

    /// Helper to build dailyMinutes dictionary
    private func buildDailyMinutes(_ entries: [(daysAgo: Int, minutes: Double)]) -> [Date: Double] {
        var dict: [Date: Double] = [:]
        for entry in entries {
            dict[daysAgo(entry.daysAgo)] = entry.minutes
        }
        return dict
    }

    // MARK: - Basic Streak Tests

    func testStreakWithAllGoodDays() {
        // 7 consecutive days with ≥2 min → Streak 7, 1 Joker earned
        let dailyMinutes = buildDailyMinutes([
            (6, 5.0), (5, 5.0), (4, 5.0), (3, 5.0),
            (2, 5.0), (1, 5.0), (0, 5.0)  // today
        ])

        let result = StreakManager.calculateStreakAndRewards(
            dailyMinutes: dailyMinutes,
            minMinutes: 2,
            calendar: calendar
        )

        XCTAssertEqual(result.streak, 7, "7 good days should give streak of 7")
        XCTAssertEqual(result.availableRewards, 1, "7 good days should earn 1 Joker")
    }

    func testStreakBreaksOnGapWithoutJoker() {
        // 6 days with activity, 1 gap → Streak breaks (no Joker available)
        let dailyMinutes = buildDailyMinutes([
            (6, 5.0), (5, 5.0), (4, 5.0),
            // (3, missing) - GAP
            (2, 5.0), (1, 5.0), (0, 5.0)
        ])

        let result = StreakManager.calculateStreakAndRewards(
            dailyMinutes: dailyMinutes,
            minMinutes: 2,
            calendar: calendar
        )

        XCTAssertEqual(result.streak, 3, "Gap without Joker should break streak, only last 3 days count")
    }

    // MARK: - Joker Healing Tests

    func testJokerHealsGap() {
        // 7 good days (earn 1 Joker), then 1 gap, then 1 good day → Streak 9
        var entries: [(daysAgo: Int, minutes: Double)] = []
        for i in (2...8).reversed() {  // Days 8-2 ago = 7 good days
            entries.append((i, 5.0))
        }
        // Day 1 ago is missing (gap)
        entries.append((0, 5.0))  // today

        let dailyMinutes = buildDailyMinutes(entries)
        let result = StreakManager.calculateStreakAndRewards(
            dailyMinutes: dailyMinutes,
            minMinutes: 2,
            calendar: calendar
        )

        XCTAssertEqual(result.streak, 9, "Joker should heal gap, streak = 7 + 1 (healed gap) + 1 (today)")
        XCTAssertEqual(result.availableRewards, 0, "Joker consumed (1 earned - 1 used)")
    }

    func testMultipleGapsNeedMultipleJokers() {
        // 14 good days (earn 2 Jokers), 2 gaps, 1 good day → Streak 17
        var entries: [(daysAgo: Int, minutes: Double)] = []
        for i in (3...16).reversed() {  // Days 16-3 ago = 14 good days
            entries.append((i, 5.0))
        }
        // Days 2 and 1 ago are missing (2 gaps)
        entries.append((0, 5.0))  // today

        let dailyMinutes = buildDailyMinutes(entries)
        let result = StreakManager.calculateStreakAndRewards(
            dailyMinutes: dailyMinutes,
            minMinutes: 2,
            calendar: calendar
        )

        XCTAssertEqual(result.streak, 17, "2 Jokers should heal 2 gaps")
        XCTAssertEqual(result.availableRewards, 0, "Both Jokers consumed")
    }

    func testTooManyGapsBreaksStreak() {
        // 7 good days (earn 1 Joker), 2 gaps → Only 1 Joker, streak breaks at second gap
        var entries: [(daysAgo: Int, minutes: Double)] = []
        for i in (3...9).reversed() {  // Days 9-3 ago = 7 good days
            entries.append((i, 5.0))
        }
        // Days 2 and 1 ago are missing (2 gaps) - only 1 Joker available!
        entries.append((0, 5.0))  // today

        let dailyMinutes = buildDailyMinutes(entries)
        let result = StreakManager.calculateStreakAndRewards(
            dailyMinutes: dailyMinutes,
            minMinutes: 2,
            calendar: calendar
        )

        XCTAssertEqual(result.streak, 1, "Second gap without Joker breaks streak, only today counts")
    }

    // MARK: - Joker Cap Tests

    func testMaxThreeJokersOnHand() {
        // 28 good days → Should earn 4 Jokers but cap at 3
        var entries: [(daysAgo: Int, minutes: Double)] = []
        for i in (0...27).reversed() {
            entries.append((i, 5.0))
        }

        let dailyMinutes = buildDailyMinutes(entries)
        let result = StreakManager.calculateStreakAndRewards(
            dailyMinutes: dailyMinutes,
            minMinutes: 2,
            calendar: calendar
        )

        XCTAssertEqual(result.streak, 28, "28 good days = streak 28")
        XCTAssertEqual(result.availableRewards, 3, "Max 3 Jokers on hand (capped)")
    }

    // MARK: - Earn Before Consume Tests

    func testEarnJokerBeforeConsume() {
        // 6 good days, Day 7 is gap → Earn Joker first (day 7 milestone), then consume it
        var entries: [(daysAgo: Int, minutes: Double)] = []
        for i in (1...6).reversed() {
            entries.append((i, 5.0))
        }
        // Day 0 (today) is gap (no entry)

        let dailyMinutes = buildDailyMinutes(entries)
        let result = StreakManager.calculateStreakAndRewards(
            dailyMinutes: dailyMinutes,
            minMinutes: 2,
            calendar: calendar
        )

        // Today not logged = tolerated, so streak = 6
        XCTAssertEqual(result.streak, 6, "Today not logged is tolerated")
    }

    func testDay7IsGapWithEarnBeforeConsume() {
        // 6 good days (days 7-2), day 1 is gap, today is good
        // → Day 7 milestone reached at gap, earn Joker, consume immediately
        var entries: [(daysAgo: Int, minutes: Double)] = []
        for i in (2...7).reversed() {  // Days 7-2 = 6 good days
            entries.append((i, 5.0))
        }
        // Day 1 is gap (would be day 7 of streak)
        entries.append((0, 5.0))  // today

        let dailyMinutes = buildDailyMinutes(entries)
        let result = StreakManager.calculateStreakAndRewards(
            dailyMinutes: dailyMinutes,
            minMinutes: 2,
            calendar: calendar
        )

        XCTAssertEqual(result.streak, 8, "Day 7 gap healed: earn Joker first, then consume")
        XCTAssertEqual(result.availableRewards, 0, "Joker earned and immediately consumed")
    }

    // MARK: - Today Not Logged Tests

    func testTodayNotLoggedIsIgnored() {
        // Yesterday good, today not logged → Streak = 1 (yesterday counts)
        let dailyMinutes = buildDailyMinutes([
            (1, 5.0)  // yesterday
            // today not logged
        ])

        let result = StreakManager.calculateStreakAndRewards(
            dailyMinutes: dailyMinutes,
            minMinutes: 2,
            calendar: calendar
        )

        XCTAssertEqual(result.streak, 1, "Today not logged should be ignored")
    }

    func testTodayLoggedCounts() {
        // Yesterday good, today good → Streak = 2
        let dailyMinutes = buildDailyMinutes([
            (1, 5.0),  // yesterday
            (0, 5.0)   // today
        ])

        let result = StreakManager.calculateStreakAndRewards(
            dailyMinutes: dailyMinutes,
            minMinutes: 2,
            calendar: calendar
        )

        XCTAssertEqual(result.streak, 2, "Both yesterday and today should count")
    }

    // MARK: - Edge Cases

    func testEmptyDailyMinutes() {
        // No entries at all
        let dailyMinutes: [Date: Double] = [:]

        let result = StreakManager.calculateStreakAndRewards(
            dailyMinutes: dailyMinutes,
            minMinutes: 2,
            calendar: calendar
        )

        XCTAssertEqual(result.streak, 0, "No entries = no streak")
        XCTAssertEqual(result.availableRewards, 0, "No entries = no rewards")
    }

    func testOnlyTodayLogged() {
        // Only today is logged
        let dailyMinutes = buildDailyMinutes([
            (0, 5.0)  // only today
        ])

        let result = StreakManager.calculateStreakAndRewards(
            dailyMinutes: dailyMinutes,
            minMinutes: 2,
            calendar: calendar
        )

        XCTAssertEqual(result.streak, 1, "Only today logged = streak 1")
        XCTAssertEqual(result.availableRewards, 0, "Not enough days for Joker")
    }

    func testMinimumThreshold() {
        // Day with only 1.4 min (< 2 min after rounding) = fail day
        // Note: round(1.5) = 2 due to banker's rounding, so we use 1.4
        let dailyMinutes = buildDailyMinutes([
            (2, 5.0),
            (1, 1.4),  // below threshold (round(1.4) = 1)
            (0, 5.0)
        ])

        let result = StreakManager.calculateStreakAndRewards(
            dailyMinutes: dailyMinutes,
            minMinutes: 2,
            calendar: calendar
        )

        XCTAssertEqual(result.streak, 1, "Day with < 2 min breaks streak, only today counts")
    }

    func testRoundingToThreshold() {
        // Day with 1.8 min → rounds to 2 → counts as good
        let dailyMinutes = buildDailyMinutes([
            (1, 5.0),
            (0, 1.8)  // rounds to 2
        ])

        let result = StreakManager.calculateStreakAndRewards(
            dailyMinutes: dailyMinutes,
            minMinutes: 2,
            calendar: calendar
        )

        XCTAssertEqual(result.streak, 2, "1.8 rounds to 2, should count as good day")
    }

    // MARK: - Screenshot Scenario Test (January 11, 2026)

    func testScreenshotScenario_33DaysGapThen8Days() {
        // Scenario from Screenshot:
        // - 31 days December + 2 days Jan (1st, 2nd) = 33 workout days
        // - Jan 3rd: NO WORKOUT (gap)
        // - Jan 4th-11th: 8 workout days
        // - Today = Jan 11th
        //
        // Expected with Joker system:
        // - After 7 days: 1 Joker, after 14: 2 Jokers, after 21: 3 Jokers (cap)
        // - At day 34 (Jan 3rd gap): consume 1 Joker → streak continues
        // - Total streak: 33 + 1 (healed) + 8 = 42 days
        // - Jokers: earned at 7,14,21,35,42 = 5, consumed = 1, available = min(3, 4) = 3

        var entries: [(daysAgo: Int, minutes: Double)] = []

        // Today is Jan 11th = daysAgo(0)
        // Jan 4th-11th = daysAgo(0-7) = 8 days
        for i in 0...7 {
            entries.append((i, 5.0))
        }

        // Jan 3rd = daysAgo(8) = GAP (no entry!)

        // Jan 1st-2nd = daysAgo(9-10) = 2 days
        entries.append((9, 5.0))
        entries.append((10, 5.0))

        // December 1st-31st = daysAgo(11-41) = 31 days
        for i in 11...41 {
            entries.append((i, 5.0))
        }

        let dailyMinutes = buildDailyMinutes(entries)
        let result = StreakManager.calculateStreakAndRewards(
            dailyMinutes: dailyMinutes,
            minMinutes: 2,
            calendar: calendar
        )

        // With Joker healing: 33 days + 1 healed gap + 8 days = 42
        XCTAssertEqual(result.streak, 42, "Gap on Jan 3rd should be healed by Joker")

        // After 42 days: earned at days 7,14,21,35,42 = 5 Jokers
        // (day 28 and beyond cap doesn't earn because cap=3)
        // Wait, let me recalculate:
        // Days 1-7: earn 1 (total: 1)
        // Days 8-14: earn 1 (total: 2)
        // Days 15-21: earn 1 (total: 3, capped)
        // Days 22-28: would earn but capped
        // Days 29-33: no milestone
        // Day 34 (gap): consume 1 → available: 2
        // Days 35: 35%7=0, available<3 → earn 1 (total: 4)
        // Days 36-41: no milestone
        // Day 42: 42%7=0, available<3 → earn 1 (total: 5)
        // Final: earned=5, consumed=1, available=min(3, 4)=3

        XCTAssertEqual(result.availableRewards, 3, "Should have 3 available (capped)")
        XCTAssertEqual(result.rewardsConsumed, 1, "1 Joker consumed for Jan 3rd gap")
    }
}
