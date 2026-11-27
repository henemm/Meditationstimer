//
//  WorkoutHealthGateTests.swift
//  LeanHealthTimerTests
//
//  TDD RED fuer #122: Programmstart prueft die Health-Schreibfreigabe, Schreibfehler werden gemeldet.
//

import XCTest
import HealthKit
@testable import Lean_Health_Timer

final class WorkoutHealthGateTests: XCTestCase {

    // MARK: - AC-1: Entscheidung vor dem Start

    /// Verhalten: Nie gefragt -> die App fragt vor dem Start.
    func test_nieGefragt_fragtNachFreigabe() {
        XCTAssertEqual(WorkoutHealthGate.startAction(for: .notDetermined), .askPermission)
    }

    /// Verhalten: Verweigert -> Hinweis auf die Einstellungen (Programm bleibt startbar).
    func test_verweigert_zeigtEinstellungenHinweis() {
        XCTAssertEqual(WorkoutHealthGate.startAction(for: .sharingDenied), .showSettingsHint)
    }

    /// Verhalten: Erlaubt -> Start ohne Dialog.
    func test_erlaubt_startetOhneDialog() {
        XCTAssertEqual(WorkoutHealthGate.startAction(for: .sharingAuthorized), .start)
    }

    // MARK: - AC-6 / AC-7: Hinweis nach dem Ende

    /// Verhalten: Wirft der Logger beim Schreiben, meldet die App den Fehler.
    func test_schreibenWirft_meldetFehler() {
        XCTAssertTrue(WorkoutSaveCheck.failed(nil))
    }

    /// Verhalten: HealthKit verwirft das Workout (z. B. ohne Freigabe, Ergebnis nil) -> Fehler wird gemeldet.
    func test_workoutVerworfen_meldetFehler() {
        XCTAssertTrue(WorkoutSaveCheck.failed(.written(nil)))
    }

    /// Verhalten: Zu kurze Sitzung (Mindestdauer) ist kein Fehler, kein falscher Alarm.
    func test_zuKurz_meldetKeinenFehler() {
        XCTAssertFalse(WorkoutSaveCheck.failed(.skipped))
    }

    /// Verhalten: Erfolgreich gespeichertes Workout -> kein Fehler-Hinweis.
    /// Der HKWorkout wird ohne HealthStore direkt gebaut (veralteter, aber store-freier Initialisierer).
    func test_gespeichert_meldetKeinenFehler() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let workout = HKWorkout(activityType: .highIntensityIntervalTraining,
                                start: start, end: start.addingTimeInterval(600))
        XCTAssertFalse(WorkoutSaveCheck.failed(.written(workout)))
    }
}
