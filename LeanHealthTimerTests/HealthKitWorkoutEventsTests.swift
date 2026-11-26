//
//  HealthKitWorkoutEventsTests.swift
//  LeanHealthTimerTests
//
//  #35 Schnitt 2 — Pausen als HealthKit-Events und Kalorien aus aktiven Sekunden.
//

import XCTest
import HealthKit
@testable import Lean_Health_Timer

/// Prueft die reine Events-Funktion `HealthKitManager.workoutEvents(pauses:in:)` und die
/// Kalorienrechnung aus aktiven Sekunden `HealthKitManager.estimatedCalories(activity:activeSeconds:)`.
/// Kein HealthKit-Zugriff, alle Zeiten injiziert.
final class HealthKitWorkoutEventsTests: XCTestCase {

    private let t0 = Date(timeIntervalSinceReferenceDate: 0)
    private func at(_ s: TimeInterval) -> Date { t0.addingTimeInterval(s) }
    private var span: DateInterval { DateInterval(start: t0, end: at(100)) }

    private func summary(_ events: [HKWorkoutEvent]) -> [String] {
        events.map { e in
            let kind = e.type == .pause ? "pause" : (e.type == .resume ? "resume" : "other")
            return "\(kind)@\(e.dateInterval.start.timeIntervalSince(t0))"
        }
    }

    // MARK: - AC-4

    /// Verhalten (AC-4): Ohne Pausen entstehen keine Events.
    func testEventsLeer() {
        XCTAssertTrue(HealthKitManager.workoutEvents(pauses: [], in: span).isEmpty)
    }

    /// Verhalten (AC-4): Ein Intervall ergibt .pause(start) und .resume(end).
    func testEventsEinIntervall() {
        let events = HealthKitManager.workoutEvents(
            pauses: [DateInterval(start: at(10), end: at(25))], in: span)
        XCTAssertEqual(summary(events), ["pause@10.0", "resume@25.0"])
    }

    /// Verhalten (AC-4): Zwei Intervalle in beliebiger Reihenfolge ergeben vier Events, nach Zeit
    /// sortiert, abwechselnd pause/resume.
    func testEventsZweiIntervalleSortiert() {
        let events = HealthKitManager.workoutEvents(
            pauses: [DateInterval(start: at(40), end: at(45)),
                     DateInterval(start: at(10), end: at(25))], in: span)
        XCTAssertEqual(summary(events), ["pause@10.0", "resume@25.0", "pause@40.0", "resume@45.0"])
    }

    // MARK: - AC-5

    /// Verhalten (AC-5): Intervalle, die ueber [start, end] hinausragen, werden geklemmt.
    func testEventsWerdenAufSpanneGeklemmt() {
        let events = HealthKitManager.workoutEvents(
            pauses: [DateInterval(start: at(-10), end: at(20)),
                     DateInterval(start: at(80), end: at(130))], in: span)
        // zweites Intervall reicht bis zum Ende: nur .pause
        XCTAssertEqual(summary(events), ["pause@0.0", "resume@20.0", "pause@80.0"])
    }

    /// Verhalten (AC-5): Intervalle der Laenge 0 (auch durch Klemmen) werden verworfen.
    func testEventsLaengeNullVerworfen() {
        let events = HealthKitManager.workoutEvents(
            pauses: [DateInterval(start: at(30), end: at(30)),
                     DateInterval(start: at(-5), end: at(0)),
                     DateInterval(start: at(100), end: at(120))], in: span)
        XCTAssertTrue(events.isEmpty, "Erhalten: \(summary(events))")
    }

    /// Verhalten (AC-5): Eine Pause bis genau zum Ende liefert nur .pause, kein .resume auf dem Ende.
    func testPauseBisEndeLiefertNurPause() {
        let events = HealthKitManager.workoutEvents(
            pauses: [DateInterval(start: at(70), end: at(100))], in: span)
        XCTAssertEqual(summary(events), ["pause@70.0"])
    }

    // MARK: - AC-6

    /// Verhalten (AC-6): 600 s Wand und 120 s Pause -> Kalorien fuer 480 aktive Sekunden (12 kcal/min).
    func testKalorienAusAktivenSekunden() {
        let kcal = HealthKitManager.estimatedCalories(
            activity: .highIntensityIntervalTraining, activeSeconds: 600 - 120)
        XCTAssertEqual(kcal, 480.0 / 60.0 * 12.0, accuracy: 0.001)
        XCTAssertNotEqual(kcal, 600.0 / 60.0 * 12.0, accuracy: 0.001)
    }

    /// Verhalten (AC-6): Ohne Pausen gilt wie bisher Wandzeit x 12/min.
    func testKalorienOhnePausenWieBisher() {
        let kcal = HealthKitManager.estimatedCalories(
            activity: .highIntensityIntervalTraining, activeSeconds: 600)
        XCTAssertEqual(kcal, 120.0, accuracy: 0.001)
    }

    // MARK: - AC-7

    /// Verhalten (AC-7): Der Standardwert (keine Pausen) laesst andere Workouts unveraendert:
    /// keine Events, Kalorien aus der gesamten Dauer.
    func testLogWorkoutStandardwertOhnePausenOhneEvents() {
        XCTAssertTrue(HealthKitManager.workoutEvents(pauses: [], in: span).isEmpty)
        let whole = span.duration
        XCTAssertEqual(
            HealthKitManager.estimatedCalories(activity: .highIntensityIntervalTraining, activeSeconds: whole),
            whole / 60.0 * 12.0, accuracy: 0.001)
    }
}
