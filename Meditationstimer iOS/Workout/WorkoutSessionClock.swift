//
//  WorkoutSessionClock.swift
//  Meditationstimer iOS
//
//  #35 Schnitt 1 — Zeitrechnung einer Workout-Programm-Sitzung und Schreibweg nach HealthKit.
//  Alle Zeitpunkte kommen von aussen; dieser Typ liest nie die Uhr selbst.
//

import Foundation
import HealthKit

/// Sitzungsuhr eines Workout-Programms (reiner Werttyp, Zeiten werden injiziert).
struct WorkoutSessionClock: Sendable, Equatable {
    enum EndReason: Sendable, Equatable {
        case natural
        case manual
    }

    let start: Date
    private(set) var reason: EndReason?
    private var end: Date?
    private var pausedAt: Date?
    private var closed: [DateInterval] = []

    init(start: Date) {
        self.start = start
    }

    /// Nur wirksam, wenn nicht pausiert und nicht beendet.
    mutating func pause(at date: Date) {
        guard pausedAt == nil, end == nil else { return }
        pausedAt = date
    }

    /// Nur wirksam, wenn pausiert und nicht beendet.
    mutating func resume(at date: Date) {
        guard let p = pausedAt, end == nil else { return }
        closePause(from: p, at: date)
    }

    private mutating func closePause(from p: Date, at date: Date) {
        if date > p { closed.append(DateInterval(start: p, end: date)) }
        pausedAt = nil
    }

    /// Nur der erste Aufruf wirkt. Eine offene Pause zaehlt bis zum Ende.
    mutating func end(at date: Date, reason: EndReason) {
        guard end == nil else { return }
        if let p = pausedAt { closePause(from: p, at: date) }
        end = date
        self.reason = reason
    }

    /// Abgeschlossene Pausen (eine beim Ende offene Pause reicht bis zum Ende).
    var pauses: [DateInterval] { closed }

    /// Start der Sitzung (nach dem Countdown).
    var writtenStart: Date { start }

    /// Heutige Semantik: Ende ohne Abzug von Pausen; `nil` solange nicht beendet.
    var writtenEnd: Date? { end }

    var wallDuration: TimeInterval {
        guard let end else { return 0 }
        return end.timeIntervalSince(start)
    }

    /// Wandzeit minus Pausen. In Schnitt 1 nur berechnet, nicht verwendet.
    var activeDuration: TimeInterval {
        guard end != nil else { return 0 }
        return wallDuration - closed.reduce(0) { $0 + $1.duration }
    }

    /// Aktive Zeit strikt groesser als 3 s.
    var meetsMinimum: Bool { activeDuration > 3 }
}

/// Schreib-Schnittstelle fuer Workouts (injizierbar fuer Tests).
protocol WorkoutLogging {
    func logWorkout(start: Date, end: Date, activity: HKWorkoutActivityType, pauses: [DateInterval]) async throws -> HKWorkout?
}

extension HealthKitManager: WorkoutLogging {}

/// Schreibt eine beendete Sitzung, wenn sie die Mindestdauer erfuellt.
enum WorkoutSessionLog {
    enum Result {
        case skipped
        case written(HKWorkout?)
    }

    static func write(
        clock: WorkoutSessionClock,
        activity: HKWorkoutActivityType,
        logger: any WorkoutLogging
    ) async throws -> Result {
        guard let end = clock.writtenEnd, clock.meetsMinimum else { return .skipped }
        let workout = try await logger.logWorkout(start: clock.writtenStart, end: end, activity: activity, pauses: clock.pauses)
        return .written(workout)
    }
}
