//
//  NoAlcManagerTests.swift
//  LeanHealthTimerTests
//
//  Created by Claude on 30.10.2025.
//

import XCTest
import HealthKit
@testable import Lean_Health_Timer

final class NoAlcManagerTests: XCTestCase {

    // MARK: - Day Assignment Logic Tests

    func testTargetDayBefore18() {
        // Test: Notification before 18:00 should reference yesterday
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Create time at 09:00 (before 18:00)
        let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today)!

        let targetDay = NoAlcManager.shared.targetDay(for: morning)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        XCTAssertEqual(targetDay, yesterday, "Morning notification (< 18:00) should target yesterday")
    }

    func testTargetDayAt18() {
        // Test: Notification at exactly 18:00 should reference today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Create time at 18:00
        let evening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: today)!

        let targetDay = NoAlcManager.shared.targetDay(for: evening)

        XCTAssertEqual(targetDay, today, "Evening notification (>= 18:00) should target today")
    }

    func testTargetDayAfter18() {
        // Test: Notification after 18:00 should reference today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Create time at 23:00 (after 18:00)
        let night = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: today)!

        let targetDay = NoAlcManager.shared.targetDay(for: night)

        XCTAssertEqual(targetDay, today, "Night notification (>= 18:00) should target today")
    }

    // MARK: - HealthKit Value Encoding Tests

    func testSteadyValueEncoding() {
        // Test: Steady (0-1 drinks) maps to value 0
        XCTAssertEqual(NoAlcManager.ConsumptionLevel.steady.healthKitValue, 0)
    }

    func testEasyValueEncoding() {
        // Test: Easy (2-5 drinks) maps to value 4
        XCTAssertEqual(NoAlcManager.ConsumptionLevel.easy.healthKitValue, 4)
    }

    func testWildValueEncoding() {
        // Test: Wild (6+ drinks) maps to value 6
        XCTAssertEqual(NoAlcManager.ConsumptionLevel.wild.healthKitValue, 6)
    }

    func testValueDecoding() {
        // Test: Decoding HealthKit values back to levels
        XCTAssertEqual(NoAlcManager.ConsumptionLevel.fromHealthKitValue(0), .steady)
        XCTAssertEqual(NoAlcManager.ConsumptionLevel.fromHealthKitValue(4), .easy)
        XCTAssertEqual(NoAlcManager.ConsumptionLevel.fromHealthKitValue(6), .wild)
    }

    func testInvalidValueDecoding() {
        // Test: Invalid values default to nil or steady
        XCTAssertNil(NoAlcManager.ConsumptionLevel.fromHealthKitValue(99))
        XCTAssertNil(NoAlcManager.ConsumptionLevel.fromHealthKitValue(-1))
    }

    // MARK: - Calendar Day Boundary Tests

    func testDayBoundaryAt00() {
        // Test: Midnight (00:00) is start of new day
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let midnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: today)!

        let targetDay = NoAlcManager.shared.targetDay(for: midnight)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        XCTAssertEqual(targetDay, yesterday, "Midnight should still reference yesterday (< 18:00)")
    }

    func testDayBoundaryAt1759() {
        // Test: 17:59 is last minute of "yesterday" reference
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let justBefore18 = calendar.date(bySettingHour: 17, minute: 59, second: 59, of: today)!

        let targetDay = NoAlcManager.shared.targetDay(for: justBefore18)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        XCTAssertEqual(targetDay, yesterday, "17:59:59 should still reference yesterday")
    }
}
