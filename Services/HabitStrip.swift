//
//  HabitStrip.swift
//  Meditationstimer
//
//  Reine Logik der Gewohnheiten-Leiste über dem Kalender (#50).
//  Keine View, kein ModelContext, kein HealthKit-Zugriff.
//

import Foundation

enum HabitStrip {

    /// Zustand eines der sieben Punkte einer Karte
    enum DotState: Equatable {
        case filled, open, todayOpen
    }

    /// Aktive Nicht-NoAlc-Tracker mit Schalter "Im Kalender anzeigen", sortiert wie die Tagesansicht.
    static func trackers(from trackers: [Tracker]) -> [Tracker] {
        trackers
            .filter { $0.isActive && $0.showInCalendar && !TrackerDayEntries.isNoAlc($0) }
            .sorted(by: TrackerDayEntries.isOrderedBefore)
    }

    /// Tage mit mindestens einem Log; Tageszuordnung genau einmal über DayAssignment (kein zweites cutoffHour).
    static func entryDays(for tracker: Tracker, calendar: Calendar) -> Set<Date> {
        let assignment = tracker.effectiveDayAssignment
        return Set(tracker.logs.map { assignment.assignedDay(for: $0.timestamp, calendar: calendar) })
    }

    /// Sieben Punkte: Index 0 = heute minus 6 Tage, Index 6 = heute.
    static func dots(entryDays: Set<Date>, today: Date = Date(), calendar: Calendar) -> [DotState] {
        let todayKey = calendar.startOfDay(for: today)
        return (0..<7).map { index in
            let day = calendar.date(byAdding: .day, value: index - 6, to: todayKey) ?? todayKey
            if entryDays.contains(day) { return .filled }
            return day == todayKey ? .todayOpen : .open
        }
    }

    /// "Serie 1 Tag" bei 1, sonst "Serie N Tage" (lokalisiert)
    static func streakText(_ days: Int) -> String {
        if days == 1 {
            return String(localized: "Serie 1 Tag")
        }
        return String(localized: "Serie \(days) Tage")
    }
}
