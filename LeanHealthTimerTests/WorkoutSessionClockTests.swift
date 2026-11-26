//
//  WorkoutSessionClockTests.swift
//  LeanHealthTimerTests
//
//  #35 Schnitt 1 — Sitzungsuhr und Schreib-Schnittstelle fuer Workout-Programme.
//

import XCTest
import HealthKit
@testable import Lean_Health_Timer

/// Prueft die Zeitrechnung einer Workout-Sitzung (`WorkoutSessionClock`) und den Schreibweg
/// (`WorkoutSessionLog` mit `WorkoutLogging`). Alle Zeiten werden injiziert, kein `Date()`.
///
/// Nicht unit-geprueft: das Verbindungsstueck in der View (Aufruf der Helfer in `endSession`).
final class WorkoutSessionClockTests: XCTestCase {

    private let t0 = Date(timeIntervalSinceReferenceDate: 0)

    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    // MARK: - Fake

    private struct LoggerFehler: Error, Equatable {}

    private final class FakeWorkoutLogger: WorkoutLogging, @unchecked Sendable {
        struct Aufruf {
            let start: Date
            let end: Date
            let activity: HKWorkoutActivityType
        }
        private(set) var aufrufe: [Aufruf] = []
        var wirft = false

        func logWorkout(start: Date, end: Date, activity: HKWorkoutActivityType) async throws -> HKWorkout? {
            aufrufe.append(Aufruf(start: start, end: end, activity: activity))
            if wirft { throw LoggerFehler() }
            return nil
        }
    }

    // MARK: - AC-1

    /// Verhalten: Eine einfache Sitzung von 60 s meldet Start, Ende und Dauer unveraendert.
    func testGrundzeitenEinfacheSitzung() {
        // GIVEN Start t0, Ende t0+60 natuerlich
        var clock = WorkoutSessionClock(start: t0)
        // WHEN beendet
        clock.end(at: at(60), reason: .natural)
        // THEN
        XCTAssertEqual(clock.writtenStart, t0)
        XCTAssertEqual(clock.writtenEnd, at(60))
        XCTAssertEqual(clock.wallDuration, 60, accuracy: 0.001)
        XCTAssertEqual(clock.activeDuration, 60, accuracy: 0.001)
        XCTAssertEqual(clock.reason, .natural)
    }

    /// Verhalten: Eine noch laufende Sitzung hat kein Ende, Dauer 0 und erfuellt die Mindestdauer nicht.
    func testNichtBeendeteSitzungHatKeinEnde() {
        // GIVEN Sitzung ohne Ende
        let clock = WorkoutSessionClock(start: t0)
        // THEN
        XCTAssertNil(clock.writtenEnd)
        XCTAssertEqual(clock.wallDuration, 0, accuracy: 0.001)
        XCTAssertFalse(clock.meetsMinimum)
    }

    // MARK: - AC-2

    /// Verhalten: Die aktive Dauer ist Wandzeit minus alle Pausen (60 - 15 - 5 = 40).
    func testAktiveDauerZiehtPausenAb() {
        // GIVEN zwei Pausen 10..25 und 40..45
        var clock = WorkoutSessionClock(start: t0)
        clock.pause(at: at(10))
        clock.resume(at: at(25))
        clock.pause(at: at(40))
        clock.resume(at: at(45))
        // WHEN Ende bei 60
        clock.end(at: at(60), reason: .natural)
        // THEN
        XCTAssertEqual(clock.wallDuration, 60, accuracy: 0.001)
        XCTAssertEqual(clock.activeDuration, 40, accuracy: 0.001)
    }

    /// Verhalten: Eine beim Ende noch offene Pause zaehlt bis zum Ende (50 - 20 = 30).
    func testOffenePauseZaehltBisZumEnde() {
        // GIVEN Pause ab 30, nie fortgesetzt
        var clock = WorkoutSessionClock(start: t0)
        clock.pause(at: at(30))
        // WHEN Ende bei 50
        clock.end(at: at(50), reason: .manual)
        // THEN
        XCTAssertEqual(clock.wallDuration, 50, accuracy: 0.001)
        XCTAssertEqual(clock.activeDuration, 30, accuracy: 0.001)
    }

    // MARK: - AC-3

    /// Verhalten: Doppeltes pause, resume ohne Pause und zweites end aendern nichts.
    func testDoppelteUndUnpassendeAufrufeAendernNichts() {
        // GIVEN resume ohne Pause ist wirkungslos
        var clock = WorkoutSessionClock(start: t0)
        clock.resume(at: at(5))
        // WHEN pause, zweite pause (ignoriert), resume
        clock.pause(at: at(10))
        clock.pause(at: at(20))
        clock.resume(at: at(30))
        // Ende, dann zweites Ende mit anderem Grund
        clock.end(at: at(60), reason: .natural)
        clock.end(at: at(90), reason: .manual)
        // THEN Pause war 10..30 = 20 s, Ende und Grund vom ersten Aufruf
        XCTAssertEqual(clock.writtenEnd, at(60))
        XCTAssertEqual(clock.reason, .natural)
        XCTAssertEqual(clock.wallDuration, 60, accuracy: 0.001)
        XCTAssertEqual(clock.activeDuration, 40, accuracy: 0.001)
    }

    // MARK: - AC-4

    /// Verhalten: Mindestdauer ist strikt groesser als 3 s.
    func testMindestdauerGrenzwerte() {
        for (dauer, erwartet) in [(2.9, false), (3.0, false), (3.1, true)] as [(TimeInterval, Bool)] {
            // GIVEN Sitzung der Dauer
            var clock = WorkoutSessionClock(start: t0)
            clock.end(at: at(dauer), reason: .manual)
            // THEN
            XCTAssertEqual(clock.meetsMinimum, erwartet, "Dauer \(dauer) s")
        }
    }

    /// Verhalten: Die Mindestdauer zaehlt Wandzeit, nicht aktive Zeit.
    /// dokumentiert heutiges Verhalten, Änderung in #35 Schnitt 2
    func testMindestdauerZaehltWandzeitNichtAktiveZeit() {
        // GIVEN 10 s Wandzeit, davon 8 s Pause (aktiv 2 s)
        var clock = WorkoutSessionClock(start: t0)
        clock.pause(at: at(1))
        clock.resume(at: at(9))
        clock.end(at: at(10), reason: .manual)
        // THEN
        XCTAssertEqual(clock.activeDuration, 2, accuracy: 0.001)
        XCTAssertTrue(clock.meetsMinimum)
    }

    // MARK: - AC-5

    /// Verhalten: Der Endgrund wird unveraendert gehalten.
    func testEndgrundWirdGehalten() {
        var manuell = WorkoutSessionClock(start: t0)
        manuell.end(at: at(10), reason: .manual)
        var natuerlich = WorkoutSessionClock(start: t0)
        natuerlich.end(at: at(10), reason: .natural)
        XCTAssertEqual(manuell.reason, .manual)
        XCTAssertEqual(natuerlich.reason, .natural)
    }

    // MARK: - AC-6

    /// Verhalten: Der Schreibweg gibt Start und Ende der Uhr genau einmal an den Logger.
    func testSchreibwegReichtStartUndEndeDurch() async throws {
        // GIVEN beendete Uhr t0..t0+120 und Fake-Logger
        var clock = WorkoutSessionClock(start: t0)
        clock.end(at: at(120), reason: .natural)
        let logger = FakeWorkoutLogger()
        // WHEN
        let result = try await WorkoutSessionLog.write(
            clock: clock, activity: .highIntensityIntervalTraining, logger: logger)
        // THEN
        XCTAssertEqual(logger.aufrufe.count, 1)
        XCTAssertEqual(logger.aufrufe.first?.start, t0)
        XCTAssertEqual(logger.aufrufe.first?.end, at(120))
        XCTAssertEqual(logger.aufrufe.first?.activity, .highIntensityIntervalTraining)
        guard case .written = result else { return XCTFail("Ergebnis war \(result), erwartet .written") }
    }

    /// Verhalten: Zu kurze oder nicht beendete Sitzungen werden nicht geschrieben.
    func testSchreibwegUeberspringtKurzeSitzung() async throws {
        let logger = FakeWorkoutLogger()
        // GIVEN genau 3 s
        var kurz = WorkoutSessionClock(start: t0)
        kurz.end(at: at(3), reason: .manual)
        let r1 = try await WorkoutSessionLog.write(
            clock: kurz, activity: .highIntensityIntervalTraining, logger: logger)
        // GIVEN nicht beendet
        let offen = WorkoutSessionClock(start: t0)
        let r2 = try await WorkoutSessionLog.write(
            clock: offen, activity: .highIntensityIntervalTraining, logger: logger)
        // THEN
        XCTAssertEqual(logger.aufrufe.count, 0)
        guard case .skipped = r1 else { return XCTFail("3 s: \(r1), erwartet .skipped") }
        guard case .skipped = r2 else { return XCTFail("offen: \(r2), erwartet .skipped") }
    }

    /// Verhalten: Wirft der Logger, wirft der Schreibweg denselben Fehler.
    func testSchreibwegReichtFehlerDurch() async {
        // GIVEN Logger, der wirft
        var clock = WorkoutSessionClock(start: t0)
        clock.end(at: at(60), reason: .natural)
        let logger = FakeWorkoutLogger()
        logger.wirft = true
        // WHEN / THEN
        do {
            _ = try await WorkoutSessionLog.write(
                clock: clock, activity: .highIntensityIntervalTraining, logger: logger)
            XCTFail("Fehler wurde verschluckt")
        } catch {
            XCTAssertEqual(error as? LoggerFehler, LoggerFehler())
        }
    }

    // MARK: - AC-7 Charakterisierung

    /// Verhalten: Pausen werden in die geschriebene Dauer gezaehlt (120 s, nicht 90 s).
    /// dokumentiert heutiges Verhalten, Änderung in #35 Schnitt 2
    func testHeuteWerdenPausenInDieGeschriebeneDauerGezaehlt() async throws {
        // GIVEN 120 s Sitzung mit 30 s Pause
        var clock = WorkoutSessionClock(start: t0)
        clock.pause(at: at(40))
        clock.resume(at: at(70))
        clock.end(at: at(120), reason: .natural)
        let logger = FakeWorkoutLogger()
        // WHEN
        _ = try await WorkoutSessionLog.write(
            clock: clock, activity: .highIntensityIntervalTraining, logger: logger)
        // THEN Spanne 120 s, aktiv 90 s
        let aufruf = try XCTUnwrap(logger.aufrufe.first)
        XCTAssertEqual(aufruf.end.timeIntervalSince(aufruf.start), 120, accuracy: 0.001)
        XCTAssertEqual(clock.activeDuration, 90, accuracy: 0.001)
    }

    /// Verhalten: Das Ende liegt nach dem Schlussgong (t0+62,3 statt t0+60).
    /// dokumentiert heutiges Verhalten, Änderung in #35 Schnitt 2
    func testHeuteLiegtDasEndeNachDemSchlussgong() async throws {
        // GIVEN Sitzung endet planmaessig bei 60, Ende wird erst nach dem Gong bei 62,3 gesetzt
        var clock = WorkoutSessionClock(start: t0)
        clock.end(at: at(62.3), reason: .natural)
        let logger = FakeWorkoutLogger()
        // WHEN
        _ = try await WorkoutSessionLog.write(
            clock: clock, activity: .highIntensityIntervalTraining, logger: logger)
        // THEN
        let aufruf = try XCTUnwrap(logger.aufrufe.first)
        XCTAssertEqual(aufruf.end, at(62.3))
        XCTAssertNotEqual(aufruf.end, at(60))
    }

    /// Verhalten: Der Start ist der Zeitpunkt der Erzeugung, der Countdown zaehlt mit.
    /// dokumentiert heutiges Verhalten, Änderung in #35 Schnitt 2
    func testHeuteStartetDieSitzungBeiErzeugungUndCountdownZaehltMit() {
        // GIVEN Erzeugung bei t0, erste Pause erst bei t0+15 (nach Countdown)
        var clock = WorkoutSessionClock(start: t0)
        clock.pause(at: at(15))
        clock.resume(at: at(20))
        clock.end(at: at(60), reason: .natural)
        // THEN
        XCTAssertEqual(clock.writtenStart, t0)
        XCTAssertEqual(clock.start, t0)
    }
}
