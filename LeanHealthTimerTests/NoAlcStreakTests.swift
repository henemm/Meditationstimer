//
//  NoAlcStreakTests.swift
//  LeanHealthTimerTests
//
//  Created by Claude on 19.12.2025.
//

import XCTest
@testable import Lean_Health_Timer

final class NoAlcStreakTests: XCTestCase {

    private let calendar = Calendar.current

    // MARK: - Helper

    /// Creates a date X days ago from today
    private func daysAgo(_ days: Int) -> Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -days, to: today)!
    }

    /// Helper to build alcoholDays dictionary
    private func buildAlcoholDays(_ entries: [(daysAgo: Int, level: NoAlcManager.ConsumptionLevel)]) -> [Date: NoAlcManager.ConsumptionLevel] {
        var dict: [Date: NoAlcManager.ConsumptionLevel] = [:]
        for entry in entries {
            dict[daysAgo(entry.daysAgo)] = entry.level
        }
        return dict
    }

    // MARK: - Basic Streak Tests

    func testStreakWithAllSteadyDays() {
        // 7 consecutive Steady days → Streak 7, 1 Joker earned
        let alcoholDays = buildAlcoholDays([
            (6, .steady), (5, .steady), (4, .steady), (3, .steady),
            (2, .steady), (1, .steady), (0, .steady)  // today
        ])

        let result = NoAlcManager.calculateStreakAndRewards(alcoholDays: alcoholDays, calendar: calendar)

        XCTAssertEqual(result.streak, 7, "7 Steady days should give streak of 7")
        XCTAssertEqual(result.rewards, 1, "7 Steady days should earn 1 Joker")
    }

    func testStreakBreaksOnEasyWithoutJoker() {
        // Steady, Easy → Streak breaks (no Joker available)
        let alcoholDays = buildAlcoholDays([
            (1, .steady), (0, .easy)  // today is Easy
        ])

        let result = NoAlcManager.calculateStreakAndRewards(alcoholDays: alcoholDays, calendar: calendar)

        XCTAssertEqual(result.streak, 0, "Easy day without Joker should break streak")
        XCTAssertEqual(result.rewards, 0, "No Jokers should be available")
    }

    func testStreakBreaksOnWildWithoutJoker() {
        // Steady, Wild → Streak breaks (no Joker available)
        let alcoholDays = buildAlcoholDays([
            (1, .steady), (0, .wild)  // today is Wild
        ])

        let result = NoAlcManager.calculateStreakAndRewards(alcoholDays: alcoholDays, calendar: calendar)

        XCTAssertEqual(result.streak, 0, "Wild day without Joker should break streak")
        XCTAssertEqual(result.rewards, 0, "No Jokers should be available")
    }

    // MARK: - Joker Healing Tests

    func testJokerHealsEasyDay() {
        // 7 Steady (earn 1 Joker), then Easy → Joker consumed, Streak 8
        var entries: [(daysAgo: Int, level: NoAlcManager.ConsumptionLevel)] = []
        for i in (1...7).reversed() {
            entries.append((i, .steady))
        }
        entries.append((0, .easy))  // today is Easy

        let alcoholDays = buildAlcoholDays(entries)
        let result = NoAlcManager.calculateStreakAndRewards(alcoholDays: alcoholDays, calendar: calendar)

        XCTAssertEqual(result.streak, 8, "Joker should heal Easy day, streak continues to 8")
        XCTAssertEqual(result.rewards, 0, "Joker should be consumed (1 earned - 1 used = 0)")
    }

    func testJokerHealsWildDay() {
        // 7 Steady (earn 1 Joker), then Wild → Joker consumed, Streak 8
        var entries: [(daysAgo: Int, level: NoAlcManager.ConsumptionLevel)] = []
        for i in (1...7).reversed() {
            entries.append((i, .steady))
        }
        entries.append((0, .wild))  // today is Wild

        let alcoholDays = buildAlcoholDays(entries)
        let result = NoAlcManager.calculateStreakAndRewards(alcoholDays: alcoholDays, calendar: calendar)

        XCTAssertEqual(result.streak, 8, "Joker should heal Wild day, streak continues to 8")
        XCTAssertEqual(result.rewards, 0, "Joker should be consumed")
    }

    // MARK: - Gap (Missing Day) Tests

    func testGapRequiresJoker() {
        // D1 Steady, D2 missing, D3 Steady → Without Joker, streak = 1 (only D3)
        let alcoholDays = buildAlcoholDays([
            (2, .steady),  // D1
            // D2 missing (daysAgo 1)
            (0, .steady)   // D3 = today
        ])

        let result = NoAlcManager.calculateStreakAndRewards(alcoholDays: alcoholDays, calendar: calendar)

        XCTAssertEqual(result.streak, 1, "Gap without Joker should break streak, only today counts")
        XCTAssertEqual(result.rewards, 0, "No Jokers available")
    }

    func testJokerHealsGap() {
        // 7 Steady, 1 gap, Steady → Streak 9 (Joker heals the gap)
        var entries: [(daysAgo: Int, level: NoAlcManager.ConsumptionLevel)] = []
        for i in (2...8).reversed() {  // Days 8-2 ago = 7 Steady days
            entries.append((i, .steady))
        }
        // Day 1 ago is missing (gap)
        entries.append((0, .steady))  // today

        let alcoholDays = buildAlcoholDays(entries)
        let result = NoAlcManager.calculateStreakAndRewards(alcoholDays: alcoholDays, calendar: calendar)

        XCTAssertEqual(result.streak, 9, "Joker should heal gap, streak = 7 + 1 (healed gap) + 1 (today)")
        XCTAssertEqual(result.rewards, 0, "Joker consumed for gap (1 earned - 1 used)")
    }

    func testMultipleGapsNeedMultipleJokers() {
        // 14 Steady (earn 2 Jokers), 2 gaps, Steady → Streak 17, 0 Jokers
        var entries: [(daysAgo: Int, level: NoAlcManager.ConsumptionLevel)] = []
        for i in (3...16).reversed() {  // Days 16-3 ago = 14 Steady days
            entries.append((i, .steady))
        }
        // Days 2 and 1 ago are missing (2 gaps)
        entries.append((0, .steady))  // today

        let alcoholDays = buildAlcoholDays(entries)
        let result = NoAlcManager.calculateStreakAndRewards(alcoholDays: alcoholDays, calendar: calendar)

        XCTAssertEqual(result.streak, 17, "2 Jokers should heal 2 gaps")
        XCTAssertEqual(result.rewards, 0, "Both Jokers consumed (2 earned - 2 used)")
    }

    func testTooManyGapsBreaksStreak() {
        // 7 Steady (earn 1 Joker), 2 gaps → Only 1 Joker, streak breaks at second gap
        var entries: [(daysAgo: Int, level: NoAlcManager.ConsumptionLevel)] = []
        for i in (3...9).reversed() {  // Days 9-3 ago = 7 Steady days
            entries.append((i, .steady))
        }
        // Days 2 and 1 ago are missing (2 gaps) - only 1 Joker available!
        entries.append((0, .steady))  // today

        let alcoholDays = buildAlcoholDays(entries)
        let result = NoAlcManager.calculateStreakAndRewards(alcoholDays: alcoholDays, calendar: calendar)

        XCTAssertEqual(result.streak, 1, "Second gap without Joker breaks streak, only today counts")
        XCTAssertEqual(result.rewards, 0, "Joker was consumed for first gap")
    }

    // MARK: - Joker Cap Tests

    func testMaxThreeJokersOnHand() {
        // 28 Steady days → Should earn 4 Jokers but cap at 3
        var entries: [(daysAgo: Int, level: NoAlcManager.ConsumptionLevel)] = []
        for i in (0...27).reversed() {
            entries.append((i, .steady))
        }

        let alcoholDays = buildAlcoholDays(entries)
        let result = NoAlcManager.calculateStreakAndRewards(alcoholDays: alcoholDays, calendar: calendar)

        XCTAssertEqual(result.streak, 28, "28 Steady days = streak 28")
        XCTAssertEqual(result.rewards, 3, "Max 3 Jokers on hand (capped)")
    }

    func testJokerCapResetsAfterUse() {
        // 21 Steady (earn 3 Jokers), 3 Easy (consume 3 Jokers), 7 Steady (earn 1 Joker)
        var entries: [(daysAgo: Int, level: NoAlcManager.ConsumptionLevel)] = []

        // Days 30-10: 21 Steady days (earn 3 Jokers)
        for i in (10...30).reversed() {
            entries.append((i, .steady))
        }
        // Days 9-7: 3 Easy days (consume 3 Jokers)
        entries.append((9, .easy))
        entries.append((8, .easy))
        entries.append((7, .easy))
        // Days 6-0: 7 Steady days (earn 1 new Joker)
        for i in (0...6).reversed() {
            entries.append((i, .steady))
        }

        let alcoholDays = buildAlcoholDays(entries)
        let result = NoAlcManager.calculateStreakAndRewards(alcoholDays: alcoholDays, calendar: calendar)

        XCTAssertEqual(result.streak, 31, "Full streak: 21 + 3 (healed) + 7 = 31")
        XCTAssertEqual(result.rewards, 1, "New Joker earned after using all 3")
    }

    // MARK: - Earn Before Consume Tests

    func testEarnJokerBeforeConsume() {
        // 6 Steady, Day 7 is Easy → Earn Joker first (day 7 milestone), then consume it
        var entries: [(daysAgo: Int, level: NoAlcManager.ConsumptionLevel)] = []
        for i in (1...6).reversed() {
            entries.append((i, .steady))
        }
        entries.append((0, .easy))  // Day 7 (today) is Easy

        let alcoholDays = buildAlcoholDays(entries)
        let result = NoAlcManager.calculateStreakAndRewards(alcoholDays: alcoholDays, calendar: calendar)

        XCTAssertEqual(result.streak, 7, "Day 7 Easy should be healed: earn Joker first, then use it")
        XCTAssertEqual(result.rewards, 0, "Joker earned and immediately consumed")
    }

    // MARK: - Today Not Logged Tests

    func testTodayNotLoggedIsIgnored() {
        // Yesterday Steady, today not logged → Streak = 1 (yesterday counts)
        let alcoholDays = buildAlcoholDays([
            (1, .steady)  // yesterday
            // today not logged
        ])

        let result = NoAlcManager.calculateStreakAndRewards(alcoholDays: alcoholDays, calendar: calendar)

        XCTAssertEqual(result.streak, 1, "Today not logged should be ignored, streak counts yesterday")
    }

    func testTodayLoggedCounts() {
        // Yesterday Steady, today Steady → Streak = 2
        let alcoholDays = buildAlcoholDays([
            (1, .steady),  // yesterday
            (0, .steady)   // today
        ])

        let result = NoAlcManager.calculateStreakAndRewards(alcoholDays: alcoholDays, calendar: calendar)

        XCTAssertEqual(result.streak, 2, "Both yesterday and today should count")
    }

    // MARK: - Edge Cases

    func testEmptyAlcoholDays() {
        // No entries at all
        let alcoholDays: [Date: NoAlcManager.ConsumptionLevel] = [:]

        let result = NoAlcManager.calculateStreakAndRewards(alcoholDays: alcoholDays, calendar: calendar)

        XCTAssertEqual(result.streak, 0, "No entries = no streak")
        XCTAssertEqual(result.rewards, 0, "No entries = no rewards")
    }

    func testOnlyTodayLogged() {
        // Only today is logged (Steady)
        let alcoholDays = buildAlcoholDays([
            (0, .steady)  // only today
        ])

        let result = NoAlcManager.calculateStreakAndRewards(alcoholDays: alcoholDays, calendar: calendar)

        XCTAssertEqual(result.streak, 1, "Only today logged = streak 1")
        XCTAssertEqual(result.rewards, 0, "Not enough days for Joker")
    }
}
