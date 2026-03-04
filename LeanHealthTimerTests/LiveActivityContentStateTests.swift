//
//  LiveActivityContentStateTests.swift
//  LeanHealthTimerTests
//
//  TDD RED: Tests für Workout Phase Timer in Live Activity
//  Feature: phaseEndDate Feld im ContentState für Dual-Timer-Anzeige
//

import XCTest
@testable import Lean_Health_Timer

#if canImport(ActivityKit)
import ActivityKit

final class LiveActivityContentStateTests: XCTestCase {

    // MARK: - phaseEndDate Field Exists

    /// RED: ContentState soll ein optionales phaseEndDate Feld haben
    func testContentState_hasPhaseEndDate() {
        let now = Date()
        let phaseEnd = now.addingTimeInterval(30)
        let sessionEnd = now.addingTimeInterval(600)

        let state = MeditationAttributes.ContentState(
            endDate: sessionEnd,
            phase: 1,
            ownerId: "WorkoutsTab",
            isPaused: false,
            phaseEndDate: phaseEnd
        )

        XCTAssertEqual(state.phaseEndDate, phaseEnd, "phaseEndDate sollte gesetzt sein")
    }

    /// RED: phaseEndDate soll optional (nil) sein für Nicht-Workout-Activities
    func testContentState_phaseEndDate_nilForMeditation() {
        let sessionEnd = Date().addingTimeInterval(600)

        let state = MeditationAttributes.ContentState(
            endDate: sessionEnd,
            phase: 1,
            ownerId: "OffenTab",
            isPaused: false,
            phaseEndDate: nil
        )

        XCTAssertNil(state.phaseEndDate, "phaseEndDate sollte nil sein für Meditation")
    }

    // MARK: - Codable (Serialisierung für ActivityKit)

    /// RED: ContentState mit phaseEndDate muss korrekt serialisiert/deserialisiert werden
    func testContentState_encodeDecode_withPhaseEndDate() throws {
        let now = Date()
        let phaseEnd = now.addingTimeInterval(30)
        let sessionEnd = now.addingTimeInterval(600)

        let original = MeditationAttributes.ContentState(
            endDate: sessionEnd,
            phase: 1,
            ownerId: "WorkoutsTab",
            isPaused: false,
            phaseEndDate: phaseEnd
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MeditationAttributes.ContentState.self, from: data)

        XCTAssertEqual(decoded.phaseEndDate, original.phaseEndDate, "phaseEndDate sollte nach Encode/Decode identisch sein")
        XCTAssertEqual(decoded.endDate, original.endDate)
        XCTAssertEqual(decoded.phase, original.phase)
        XCTAssertEqual(decoded.ownerId, original.ownerId)
        XCTAssertEqual(decoded.isPaused, original.isPaused)
    }

    /// RED: ContentState OHNE phaseEndDate muss weiterhin korrekt deserialisiert werden (Backward Compatibility)
    func testContentState_decode_withoutPhaseEndDate_backwardCompatible() throws {
        // Simuliere altes JSON ohne phaseEndDate Feld
        let json = """
        {
            "endDate": 1000000000,
            "phase": 2,
            "isPaused": false
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let state = try decoder.decode(MeditationAttributes.ContentState.self, from: json)

        XCTAssertNil(state.phaseEndDate, "phaseEndDate sollte nil sein wenn nicht im JSON vorhanden")
        XCTAssertEqual(state.phase, 2)
        XCTAssertFalse(state.isPaused)
    }

    // MARK: - Hashable (für ActivityKit State Diffing)

    /// RED: Zwei States mit unterschiedlichem phaseEndDate sollen NICHT gleich sein
    func testContentState_hashable_differentPhaseEndDate() {
        let now = Date()
        let sessionEnd = now.addingTimeInterval(600)

        let state1 = MeditationAttributes.ContentState(
            endDate: sessionEnd,
            phase: 1,
            ownerId: "WorkoutsTab",
            isPaused: false,
            phaseEndDate: now.addingTimeInterval(30)
        )

        let state2 = MeditationAttributes.ContentState(
            endDate: sessionEnd,
            phase: 1,
            ownerId: "WorkoutsTab",
            isPaused: false,
            phaseEndDate: now.addingTimeInterval(15)
        )

        XCTAssertNotEqual(state1, state2, "States mit unterschiedlichem phaseEndDate sollen ungleich sein")
    }

    /// RED: Zwei States mit gleichem phaseEndDate (nil) sollen gleich sein
    func testContentState_hashable_bothNilPhaseEndDate() {
        let sessionEnd = Date().addingTimeInterval(600)

        let state1 = MeditationAttributes.ContentState(
            endDate: sessionEnd,
            phase: 1,
            ownerId: "OffenTab",
            isPaused: false,
            phaseEndDate: nil
        )

        let state2 = MeditationAttributes.ContentState(
            endDate: sessionEnd,
            phase: 1,
            ownerId: "OffenTab",
            isPaused: false,
            phaseEndDate: nil
        )

        XCTAssertEqual(state1, state2, "States mit gleichem phaseEndDate (nil) sollen gleich sein")
    }
}
#endif
