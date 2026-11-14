//
//  TrackerDayEntries.swift
//  Meditationstimer
//
//  Reine Gruppierung der Tracker-Einträge je Kalendertag für die Tagesansicht (#47).
//  Keine View, kein ModelContext, kein HealthKit-Zugriff.
//

import Foundation
import HealthKit

enum TrackerDayEntries {

    /// Eintrag eines Trackers an einem Tag (Anzeigewert, Notiz und Uhrzeit des spätesten Logs)
    struct Entry: Equatable {
        let value: String
        let note: String?
        let time: Date
    }

    /// Zeile der Tagesansicht: ein aktiver Tracker, `entry == nil` heißt "kein Eintrag"
    struct Row: Identifiable, Equatable {
        let trackerID: UUID
        let name: String
        let icon: String
        let entry: Entry?

        var id: UUID { trackerID }
    }

    /// Bündelt die Bedingung für "Tag hat Aktivität" plus Tracker-Einträge.
    static func hasActivity(mindfulnessMinutes: Double, workoutMinutes: Double, hasNoAlc: Bool, hasTrackerEntries: Bool) -> Bool {
        mindfulnessMinutes >= 2.0 || workoutMinutes >= 2.0 || hasNoAlc || hasTrackerEntries
    }

    /// Zeilen je Tag. Ein Tag ist nur enthalten, wenn mindestens ein Tracker dort einen Log hat.
    static func group(trackers: [Tracker], calendar: Calendar = .current) -> [Date: [Row]] {
        let relevant = trackers
            .filter { $0.isActive && !isNoAlc($0) }
            .sorted(by: isOrderedBefore)

        // Tageszuordnung genau einmal über DayAssignment (kein zweites cutoffHour)
        var perTracker: [(tracker: Tracker, days: [Date: [TrackerLog]])] = []
        var allDays = Set<Date>()
        for tracker in relevant {
            let assignment = tracker.effectiveDayAssignment
            let days = Dictionary(grouping: tracker.logs) {
                assignment.assignedDay(for: $0.timestamp, calendar: calendar)
            }
            allDays.formUnion(days.keys)
            perTracker.append((tracker, days))
        }

        var result: [Date: [Row]] = [:]
        for day in allDays {
            result[day] = perTracker.map { item in
                Row(
                    trackerID: item.tracker.id,
                    name: item.tracker.name,
                    icon: item.tracker.icon,
                    entry: item.days[day].flatMap { entry(for: item.tracker, logs: $0) }
                )
            }
        }
        return result
    }

    // MARK: - Helpers

    private static func isNoAlc(_ tracker: Tracker) -> Bool {
        tracker.name == "NoAlc"
            || tracker.healthKitType == HKQuantityTypeIdentifier.numberOfAlcoholicBeverages.rawValue
    }

    private static func isOrderedBefore(_ a: Tracker, _ b: Tracker) -> Bool {
        if a.displayOrder != b.displayOrder { return a.displayOrder < b.displayOrder }
        if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
        return a.name < b.name
    }

    private static func entry(for tracker: Tracker, logs: [TrackerLog]) -> Entry? {
        guard let latest = logs.max(by: { $0.timestamp < $1.timestamp }) else { return nil }
        let value = displayValue(for: tracker, logs: logs, latest: latest)
        // Level-Logs speichern "Icon Label" selbst als Notiz: gleicht sie dem Anzeigewert, ist es keine Notiz
        let note = latest.note.flatMap { $0.isEmpty || $0 == value ? nil : $0 }
        return Entry(value: value, note: note, time: latest.timestamp)
    }

    private static func displayValue(for tracker: Tracker, logs: [TrackerLog], latest: TrackerLog) -> String {
        switch tracker.effectiveValueType {
        case .levels(let levels):
            let id = latest.value ?? 0
            if let level = levels.first(where: { $0.id == id }) {
                return "\(level.icon) \(level.localizedLabel)"
            }
            return String(id)
        case .integer(let goal):
            let sum = logs.reduce(0) { $0 + ($1.value ?? 1) }
            if let goal { return "\(sum) / \(goal)" }
            return String(sum)
        case .boolean:
            return "✓"
        }
    }
}
