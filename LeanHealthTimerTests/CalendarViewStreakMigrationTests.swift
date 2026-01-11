//
//  CalendarViewStreakMigrationTests.swift
//  LeanHealthTimerTests
//
//  TDD Test: Vergleich alte CalendarView Logik vs. neue StreakManager Joker-Logik
//
//  Dieser Test beweist:
//  1. Die ALTE Logik (ohne Joker) bricht den Streak bei einem Gap
//  2. Die NEUE Logik (mit Joker) heilt den Gap wenn ein Joker verfügbar ist
//

import XCTest
@testable import Lean_Health_Timer

final class CalendarViewStreakMigrationTests: XCTestCase {

    private let calendar = Calendar.current

    // MARK: - Helper: Alte CalendarView Logik (ohne Joker)

    /// Die ALTE Streak-Berechnung aus CalendarView VOR der Migration
    /// Diese Logik kennt KEINE Joker - ein Gap bricht immer den Streak
    private func oldCalendarViewStreak(dailyMinutes: [Date: Double], minMinutes: Double = 2.0) -> Int {
        let today = calendar.startOfDay(for: Date())
        let todayMinutes = dailyMinutes[today] ?? 0
        let hasDataToday = round(todayMinutes) >= minMinutes

        var currentStreak = 0
        var checkDate = hasDataToday ? today : calendar.date(byAdding: .day, value: -1, to: today)!

        while true {
            let minutes = dailyMinutes[checkDate] ?? 0
            if round(minutes) >= minMinutes {
                currentStreak += 1
                guard let previousDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = previousDate
            } else {
                break  // Gap = Streak bricht IMMER (keine Joker!)
            }
        }

        return currentStreak
    }

    // MARK: - Helper: Datum-Builder

    private func daysAgo(_ days: Int) -> Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -days, to: today)!
    }

    private func buildDailyMinutes(_ entries: [(daysAgo: Int, minutes: Double)]) -> [Date: Double] {
        var dict: [Date: Double] = [:]
        for entry in entries {
            dict[daysAgo(entry.daysAgo)] = entry.minutes
        }
        return dict
    }

    // MARK: - TDD RED: Dieser Test MUSS mit alter Logik fehlschlagen

    func testJokerHealsGap_OldLogicFails_NewLogicSucceeds() {
        // SZENARIO:
        // - 7 gute Tage (Tag 8-2) → verdient 1 Joker
        // - 1 Gap-Tag (Tag 1) → kein Eintrag
        // - 1 guter Tag (Tag 0 = heute)
        //
        // ALTE LOGIK (ohne Joker): Streak = 1 (nur heute, Gap bricht Streak)
        // NEUE LOGIK (mit Joker):  Streak = 9 (Joker heilt den Gap)

        var entries: [(daysAgo: Int, minutes: Double)] = []
        // 7 gute Tage: Tag 8, 7, 6, 5, 4, 3, 2
        for i in (2...8).reversed() {
            entries.append((i, 5.0))
        }
        // Tag 1 ist LÜCKE (kein Eintrag)
        // Heute (Tag 0)
        entries.append((0, 5.0))

        let dailyMinutes = buildDailyMinutes(entries)

        // ========== ALTE LOGIK (CalendarView vor Migration) ==========
        let oldStreak = oldCalendarViewStreak(dailyMinutes: dailyMinutes)

        // Alte Logik: Gap bricht Streak → nur heute zählt
        XCTAssertEqual(oldStreak, 1,
            "ALTE LOGIK: Gap sollte Streak brechen, nur heute zählt")

        // ========== NEUE LOGIK (StreakManager mit Joker) ==========
        let newResult = StreakManager.calculateStreakAndRewards(
            dailyMinutes: dailyMinutes,
            minMinutes: 2,
            calendar: calendar
        )

        // Neue Logik: Joker heilt den Gap → 9 Tage Streak
        XCTAssertEqual(newResult.streak, 9,
            "NEUE LOGIK: Joker sollte Gap heilen, Streak = 9")

        // Joker wurde verdient (nach 7 Tagen) und konsumiert (für den Gap)
        XCTAssertEqual(newResult.rewardsEarned, 1,
            "1 Joker sollte nach 7 Tagen verdient werden")
        XCTAssertEqual(newResult.rewardsConsumed, 1,
            "1 Joker sollte für Gap-Heilung konsumiert werden")

        // ========== BEWEIS: Alte und neue Logik sind UNTERSCHIEDLICH ==========
        XCTAssertNotEqual(oldStreak, newResult.streak,
            "MIGRATION BEWEIS: Alte und neue Logik MÜSSEN unterschiedliche Ergebnisse liefern!")
    }

    func testNoGap_BothLogicsAgree() {
        // SZENARIO: Keine Lücke → beide Logiken sollten gleich sein
        // 5 konsekutive gute Tage

        let entries: [(daysAgo: Int, minutes: Double)] = [
            (4, 5.0), (3, 5.0), (2, 5.0), (1, 5.0), (0, 5.0)
        ]
        let dailyMinutes = buildDailyMinutes(entries)

        let oldStreak = oldCalendarViewStreak(dailyMinutes: dailyMinutes)
        let newResult = StreakManager.calculateStreakAndRewards(
            dailyMinutes: dailyMinutes,
            minMinutes: 2,
            calendar: calendar
        )

        // Ohne Lücke sollten beide 5 Tage zählen
        XCTAssertEqual(oldStreak, 5, "Alte Logik: 5 Tage Streak")
        XCTAssertEqual(newResult.streak, 5, "Neue Logik: 5 Tage Streak")
        XCTAssertEqual(oldStreak, newResult.streak,
            "Ohne Gap sollten beide Logiken übereinstimmen")
    }

    func testGapWithoutJoker_BothLogicsBreakStreak() {
        // SZENARIO: Gap ohne verfügbaren Joker → beide Logiken brechen
        // 3 gute Tage (nicht genug für Joker), dann Gap, dann heute

        let entries: [(daysAgo: Int, minutes: Double)] = [
            (4, 5.0), (3, 5.0), (2, 5.0),  // 3 Tage (kein Joker verdient)
            // Tag 1 ist LÜCKE
            (0, 5.0)  // heute
        ]
        let dailyMinutes = buildDailyMinutes(entries)

        let oldStreak = oldCalendarViewStreak(dailyMinutes: dailyMinutes)
        let newResult = StreakManager.calculateStreakAndRewards(
            dailyMinutes: dailyMinutes,
            minMinutes: 2,
            calendar: calendar
        )

        // Beide sollten nur heute zählen (kein Joker zum Heilen)
        XCTAssertEqual(oldStreak, 1, "Alte Logik: Gap bricht Streak")
        XCTAssertEqual(newResult.streak, 1, "Neue Logik: Kein Joker verfügbar, Gap bricht")
        XCTAssertEqual(newResult.rewardsEarned, 0, "Kein Joker verdient (< 7 Tage)")
    }
}
