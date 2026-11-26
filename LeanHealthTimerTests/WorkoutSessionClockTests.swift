//
//  WorkoutSessionClockTests.swift
//  LeanHealthTimerTests
//
//  #35 Schnitt 1 und 2 — Sitzungsuhr, Pausen und Schreib-Schnittstelle fuer Workout-Programme.
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
            let pauses: [DateInterval]
        }
        private(set) var aufrufe: [Aufruf] = []
        var wirft = false

        func logWorkout(start: Date, end: Date, activity: HKWorkoutActivityType,
                        pauses: [DateInterval]) async throws -> HKWorkout? {
            aufrufe.append(Aufruf(start: start, end: end, activity: activity, pauses: pauses))
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

    /// Verhalten (AC-3): Die Schwelle gilt auf aktive Zeit: 3,0 s aktiv reicht nicht (auch mit Pause
    /// bei laengerer Wandzeit), 3,1 s aktiv reicht.
    func testSchwelleGrenzwerteAufAktiverZeit() {
        var ohne30 = WorkoutSessionClock(start: t0)
        ohne30.end(at: at(3.0), reason: .manual)
        XCTAssertFalse(ohne30.meetsMinimum, "3,0 s aktiv ohne Pause")
        var ohne31 = WorkoutSessionClock(start: t0)
        ohne31.end(at: at(3.1), reason: .manual)
        XCTAssertTrue(ohne31.meetsMinimum, "3,1 s aktiv ohne Pause")
        // Wand 20 s, Pause 17 s -> aktiv 3,0 s
        var mit30 = WorkoutSessionClock(start: t0)
        mit30.pause(at: at(1))
        mit30.resume(at: at(18))
        mit30.end(at: at(20), reason: .manual)
        XCTAssertEqual(mit30.activeDuration, 3.0, accuracy: 0.001)
        XCTAssertFalse(mit30.meetsMinimum, "3,0 s aktiv bei 20 s Wand")
        // Wand 20 s, Pause 16,9 s -> aktiv 3,1 s
        var mit31 = WorkoutSessionClock(start: t0)
        mit31.pause(at: at(1))
        mit31.resume(at: at(17.9))
        mit31.end(at: at(20), reason: .manual)
        XCTAssertEqual(mit31.activeDuration, 3.1, accuracy: 0.001)
        XCTAssertTrue(mit31.meetsMinimum, "3,1 s aktiv bei 20 s Wand")
    }

    /// Verhalten (AC-3): 10 s Wand und 8 s Pause (aktiv 2 s) erfuellen die Mindestdauer nicht.
    func testZehnSekundenWandAchtPauseWirdVerworfen() {
        var clock = WorkoutSessionClock(start: t0)
        clock.pause(at: at(1))
        clock.resume(at: at(9))
        clock.end(at: at(10), reason: .manual)
        XCTAssertEqual(clock.activeDuration, 2, accuracy: 0.001)
        XCTAssertFalse(clock.meetsMinimum)
    }

    // MARK: - Schnitt 2: Pausenintervalle (AC-1, AC-2)

    /// Verhalten (AC-1): Zwei abgeschlossene Pausen erscheinen als zwei Intervalle in Reihenfolge.
    func testPausenIntervalleDerUhr() {
        var clock = WorkoutSessionClock(start: t0)
        clock.pause(at: at(10))
        clock.resume(at: at(25))
        clock.pause(at: at(40))
        clock.resume(at: at(45))
        clock.end(at: at(60), reason: .natural)
        XCTAssertEqual(clock.pauses, [DateInterval(start: at(10), end: at(25)),
                                      DateInterval(start: at(40), end: at(45))])
    }

    /// Verhalten (AC-1): Eine beim Ende offene Pause erscheint als Intervall bis zum Ende.
    func testOffenePauseWirdBisZumEndeIntervall() {
        var clock = WorkoutSessionClock(start: t0)
        clock.pause(at: at(30))
        clock.end(at: at(50), reason: .manual)
        XCTAssertEqual(clock.pauses, [DateInterval(start: at(30), end: at(50))])
    }

    /// Verhalten (AC-1): Doppeltes pause und resume ohne Pause aendern die Pausenliste nicht.
    func testDoppelteUndUnpassendeAufrufeAendernKeinePause() {
        var clock = WorkoutSessionClock(start: t0)
        clock.resume(at: at(5))
        XCTAssertEqual(clock.pauses, [], "resume ohne Pause")
        clock.pause(at: at(10))
        clock.pause(at: at(20))
        clock.resume(at: at(30))
        clock.resume(at: at(35))
        clock.end(at: at(60), reason: .natural)
        XCTAssertEqual(clock.pauses, [DateInterval(start: at(10), end: at(30))])
    }

    /// Verhalten (AC-2): Aktive Dauer aus Intervallen: 60 s Wand, Pausen 15 s + 5 s -> 40 s.
    func testAktiveDauerAusIntervallen() {
        var clock = WorkoutSessionClock(start: t0)
        clock.pause(at: at(10))
        clock.resume(at: at(25))
        clock.pause(at: at(40))
        clock.resume(at: at(45))
        clock.end(at: at(60), reason: .natural)
        XCTAssertEqual(clock.wallDuration, 60, accuracy: 0.001)
        XCTAssertEqual(clock.activeDuration, 40, accuracy: 0.001)
        XCTAssertEqual(clock.pauses.count, 2)
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

    // MARK: - Schnitt 2: Aussagen statt Charakterisierung

    /// Verhalten: Pausen werden als Pause uebergeben und nicht von der Spanne abgezogen
    /// (Start/Ende ueber die volle Spanne 120 s, Pause 40..70 als Intervall, aktiv 90 s).
    func testPausenWerdenAlsPauseUebergebenUndNichtAbgezogen() async throws {
        var clock = WorkoutSessionClock(start: t0)
        clock.pause(at: at(40))
        clock.resume(at: at(70))
        clock.end(at: at(120), reason: .natural)
        let logger = FakeWorkoutLogger()
        _ = try await WorkoutSessionLog.write(
            clock: clock, activity: .highIntensityIntervalTraining, logger: logger)
        let aufruf = try XCTUnwrap(logger.aufrufe.first)
        XCTAssertEqual(aufruf.start, t0)
        XCTAssertEqual(aufruf.end, at(120))
        XCTAssertEqual(aufruf.pauses, [DateInterval(start: at(40), end: at(70))])
        XCTAssertEqual(clock.activeDuration, 90, accuracy: 0.001)
    }

    /// Verhalten: 10 s Wand mit 8 s Pause (aktiv 2 s) wird nicht geschrieben (Mindestdauer
    /// zaehlt aktive Zeit); der Logger wird nicht aufgerufen.
    func testMindestdauerZaehltAktiveZeit() async throws {
        var clock = WorkoutSessionClock(start: t0)
        clock.pause(at: at(1))
        clock.resume(at: at(9))
        clock.end(at: at(10), reason: .manual)
        let logger = FakeWorkoutLogger()
        let result = try await WorkoutSessionLog.write(
            clock: clock, activity: .highIntensityIntervalTraining, logger: logger)
        XCTAssertFalse(clock.meetsMinimum)
        XCTAssertEqual(logger.aufrufe.count, 0)
        guard case .skipped = result else { return XCTFail("Ergebnis war \(result), erwartet .skipped") }
    }

    /// Verhalten: Das Ende ist genau der uebergebene Zeitpunkt (Ende vor dem Gong, nicht
    /// spaeter); der Logger bekommt exakt diesen.
    func testEndeIstDerUebergebeneZeitpunktOhneGong() async throws {
        var clock = WorkoutSessionClock(start: t0)
        clock.end(at: at(60), reason: .natural)
        let logger = FakeWorkoutLogger()
        _ = try await WorkoutSessionLog.write(
            clock: clock, activity: .highIntensityIntervalTraining, logger: logger)
        XCTAssertEqual(clock.writtenEnd, at(60))
        XCTAssertEqual(try XCTUnwrap(logger.aufrufe.first).end, at(60))
    }

    /// Verhalten: Der Start ist der Zeitpunkt der Anlage der Uhr (Countdown-Ende); Zeit davor
    /// kommt nicht vor.
    func testStartIstDerUebergabezeitpunktNachDemCountdown() async throws {
        // Countdown 0..15, Uhr wird bei t0+15 angelegt
        var clock = WorkoutSessionClock(start: at(15))
        clock.end(at: at(75), reason: .natural)
        let logger = FakeWorkoutLogger()
        _ = try await WorkoutSessionLog.write(
            clock: clock, activity: .highIntensityIntervalTraining, logger: logger)
        XCTAssertEqual(clock.writtenStart, at(15))
        XCTAssertEqual(try XCTUnwrap(logger.aufrufe.first).start, at(15))
        XCTAssertEqual(clock.wallDuration, 60, accuracy: 0.001)
    }

    /// Verhalten (AC-8): Der Schreibweg reicht genau einen Aufruf mit den Pausen der Uhr durch.
    func testSchreibwegReichtPausenDurch() async throws {
        var clock = WorkoutSessionClock(start: t0)
        clock.pause(at: at(10))
        clock.resume(at: at(25))
        clock.pause(at: at(40))
        clock.resume(at: at(45))
        clock.end(at: at(60), reason: .natural)
        let logger = FakeWorkoutLogger()
        let result = try await WorkoutSessionLog.write(
            clock: clock, activity: .highIntensityIntervalTraining, logger: logger)
        XCTAssertEqual(logger.aufrufe.count, 1)
        XCTAssertEqual(logger.aufrufe.first?.pauses, clock.pauses)
        XCTAssertEqual(logger.aufrufe.first?.pauses.count, 2)
        XCTAssertEqual(logger.aufrufe.first?.start, clock.writtenStart)
        XCTAssertEqual(logger.aufrufe.first?.end, clock.writtenEnd)
        guard case .written = result else { return XCTFail("Ergebnis war \(result), erwartet .written") }
    }

    /// Verhalten (AC-8): 10 s Wand und 8 s Pause werden nicht geschrieben, Ergebnis .skipped.
    func testSchreibwegUeberspringtZehnWandAchtPause() async throws {
        var clock = WorkoutSessionClock(start: t0)
        clock.pause(at: at(2))
        clock.resume(at: at(10))
        clock.end(at: at(10), reason: .manual)
        let logger = FakeWorkoutLogger()
        let result = try await WorkoutSessionLog.write(
            clock: clock, activity: .highIntensityIntervalTraining, logger: logger)
        XCTAssertEqual(logger.aufrufe.count, 0)
        guard case .skipped = result else { return XCTFail("Ergebnis war \(result), erwartet .skipped") }
    }

    /// Verhalten (AC-12, Unit-Anteil): Ein zweites `end` aendert Ende und Pausen nicht.
    func testZweitesEndeAendertNichts() {
        var clock = WorkoutSessionClock(start: t0)
        clock.pause(at: at(10))
        clock.end(at: at(30), reason: .manual)
        clock.end(at: at(50), reason: .natural)
        XCTAssertEqual(clock.writtenEnd, at(30))
        XCTAssertEqual(clock.pauses, [DateInterval(start: at(10), end: at(30))])
    }
}
