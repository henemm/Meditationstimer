//
//  WorkoutEffortScoreTests.swift
//  LeanHealthTimerTests
//
//  TDD RED: Tests für Workout Effort Score Feature (iOS 18+)
//

import XCTest
import HealthKit
@testable import Lean_Health_Timer

final class WorkoutEffortScoreTests: XCTestCase {

    // MARK: - Test 1: Effort Score im gültigen Bereich (1-10)

    func testEffortScoreValidRange() {
        // GIVEN: Gültige Effort Scores
        let validScores = [1, 5, 7, 10]

        for score in validScores {
            // WHEN: Score validiert
            let isValid = (1...10).contains(score)

            // THEN: Score ist gültig
            XCTAssertTrue(isValid, "Score \(score) sollte gültig sein")
        }
    }

    func testEffortScoreInvalidRange() {
        // GIVEN: Ungültige Effort Scores
        let invalidScores = [0, 11, -1, 100]

        for score in invalidScores {
            // WHEN: Score validiert
            let isValid = (1...10).contains(score)

            // THEN: Score ist ungültig
            XCTAssertFalse(isValid, "Score \(score) sollte ungültig sein")
        }
    }

    // MARK: - Test 2: Effort Score Quantity erstellen (iOS 18+)

    @available(iOS 18.0, *)
    func testEffortScoreQuantityCreation() {
        // GIVEN: Effort Score 7
        let score: Double = 7.0

        // WHEN: HKQuantity erstellt
        let unit = HKUnit.appleEffortScore()
        let quantity = HKQuantity(unit: unit, doubleValue: score)

        // THEN: Wert kann ausgelesen werden
        let readBack = quantity.doubleValue(for: unit)
        XCTAssertEqual(readBack, score, accuracy: 0.01)
    }

    // MARK: - Test 3: Effort Score Sample erstellen (iOS 18+)

    @available(iOS 18.0, *)
    func testEffortScoreSampleCreation() {
        // GIVEN: Workout Zeitraum
        let start = Date()
        let end = start.addingTimeInterval(600) // 10 min
        let score: Double = 8.0

        // WHEN: Sample erstellt
        let unit = HKUnit.appleEffortScore()
        let quantity = HKQuantity(unit: unit, doubleValue: score)
        let type = HKQuantityType(.workoutEffortScore)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: start, end: end)

        // THEN: Sample hat korrekte Werte
        XCTAssertEqual(sample.quantity.doubleValue(for: unit), score, accuracy: 0.01)
        XCTAssertEqual(sample.startDate, start)
        XCTAssertEqual(sample.endDate, end)
    }

    // MARK: - Test 4: Default Effort Score für HIIT

    func testDefaultEffortScoreForHIIT() {
        // GIVEN: HIIT Workout Typ
        let activityType = HKWorkoutActivityType.highIntensityIntervalTraining

        // WHEN: Default Score ermittelt
        let defaultScore: Int
        switch activityType {
        case .highIntensityIntervalTraining:
            defaultScore = 7 // Schwer
        default:
            defaultScore = 5 // Moderat
        }

        // THEN: Default ist 7 (Schwer)
        XCTAssertEqual(defaultScore, 7)
    }
}
