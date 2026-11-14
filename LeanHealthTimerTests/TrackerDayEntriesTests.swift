//
//  TrackerDayEntriesTests.swift
//  LeanHealthTimerTests
//
//  TDD RED fuer #47 (Tagesansicht zeigt alle Gewohnheiten).
//  Kompiliert erst, wenn `TrackerDayEntries` (Services/TrackerDayEntries.swift) existiert.
//
//  Angenommene API (Entwickler implementiert dagegen):
//    TrackerDayEntries.group(trackers: [Tracker], calendar: Calendar = .current) -> [Date: [TrackerDayEntries.Row]]
//    TrackerDayEntries.hasActivity(mindfulnessMinutes:workoutMinutes:hasNoAlc:hasTrackerEntries:) -> Bool
//    TrackerDayEntries.Row   { trackerID: UUID, name: String, icon: String, entry: Entry? }
//    TrackerDayEntries.Entry { value: String, note: String?, time: Date }
//

import XCTest
import SwiftData
@testable import Lean_Health_Timer

final class TrackerDayEntriesTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var calendar: Calendar!

    override func setUp() {
        super.setUp()
        let schema = Schema([Tracker.self, TrackerLog.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        calendar = cal
    }

    override func tearDown() {
        context = nil
        container = nil
        calendar = nil
        super.tearDown()
    }

    // MARK: - Helfer

    private func date(_ day: Int, _ hour: Int = 12, _ minute: Int = 0, month: Int = 11) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func dayKey(_ day: Int) -> Date {
        calendar.startOfDay(for: date(day))
    }

    @discardableResult
    private func makeTracker(
        name: String = "Doomscrolling",
        icon: String = "📱",
        mode: TrackingMode = .awareness,
        dayAssignmentRaw: String? = nil,
        displayOrder: Int = 0,
        isActive: Bool = true,
        healthKitType: String? = nil,
        dailyGoal: Int? = nil,
        levels: [TrackerLevel]? = nil,
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> Tracker {
        let tracker = Tracker(
            name: name,
            icon: icon,
            type: .good,
            trackingMode: mode,
            createdAt: createdAt,
            isActive: isActive,
            healthKitType: healthKitType,
            displayOrder: displayOrder,
            dailyGoal: dailyGoal
        )
        tracker.dayAssignmentRaw = dayAssignmentRaw
        if let levels {
            tracker.levelsData = try! JSONEncoder().encode(levels)
        }
        context.insert(tracker)
        return tracker
    }

    @discardableResult
    private func addLog(_ tracker: Tracker, at timestamp: Date, value: Int? = nil, note: String? = nil) -> TrackerLog {
        let log = TrackerLog(timestamp: timestamp, value: value, note: note, tracker: tracker)
        context.insert(log)
        try! context.save()
        return log
    }

    private func rows(_ result: [Date: [TrackerDayEntries.Row]], day: Int) -> [TrackerDayEntries.Row] {
        result[dayKey(day)] ?? []
    }

    // MARK: - AC-1 bis AC-3: Tageszuordnung

    /// Verhalten: Zeitstempel-Tracker, Eintrag 13.11. 17:00 erscheint nur am 13.11.
    func test_timestampAssignment_logAt17_belongsToSameDay() {
        let t = makeTracker(dayAssignmentRaw: nil)
        addLog(t, at: date(13, 17, 0))

        let result = TrackerDayEntries.group(trackers: [t], calendar: calendar)

        XCTAssertEqual(Set(result.keys), [dayKey(13)], "Eintrag darf nur am 13.11. erscheinen")
        XCTAssertNotNil(rows(result, day: 13).first?.entry)
    }

    /// Verhalten: cutoffHour 18, Eintrag 13.11. 17:00 gehoert zum 12.11.
    func test_cutoff18_logAt17_belongsToPreviousDay() {
        let t = makeTracker(dayAssignmentRaw: "cutoffHour:18")
        addLog(t, at: date(13, 17, 0))

        let result = TrackerDayEntries.group(trackers: [t], calendar: calendar)

        XCTAssertEqual(Set(result.keys), [dayKey(12)])
        XCTAssertNotNil(rows(result, day: 12).first?.entry)
    }

    /// Verhalten: cutoffHour 18, Eintrag 13.11. 18:00 gehoert zum 13.11.
    func test_cutoff18_logAt18_belongsToSameDay() {
        let t = makeTracker(dayAssignmentRaw: "cutoffHour:18")
        addLog(t, at: date(13, 18, 0))

        let result = TrackerDayEntries.group(trackers: [t], calendar: calendar)

        XCTAssertEqual(Set(result.keys), [dayKey(13)])
    }

    /// Verhalten: cutoffHour 18, Eintrag 13.11. 00:30 wird genau einmal verschoben (12.11., nicht 11.11.)
    func test_cutoff18_logAfterMidnight_shiftedOnlyOnce() {
        let t = makeTracker(dayAssignmentRaw: "cutoffHour:18")
        addLog(t, at: date(13, 0, 30))

        let result = TrackerDayEntries.group(trackers: [t], calendar: calendar)

        XCTAssertEqual(Set(result.keys), [dayKey(12)], "Doppelverschiebung auf den 11.11. ist ein Fehler")
    }

    // MARK: - AC-4 bis AC-7: Anzeigewerte

    /// Verhalten: Level-Tracker zeigt das lokalisierte Label des geloggten Levels
    func test_levelTracker_showsLocalizedLevelLabel() throws {
        let levels = TrackerLevel.moodLevels
        let great = try XCTUnwrap(levels.first { $0.id == 5 })
        let t = makeTracker(name: "Mood", icon: "🙂", mode: .levels, levels: levels)
        addLog(t, at: date(13, 9, 0), value: great.id)

        let result = TrackerDayEntries.group(trackers: [t], calendar: calendar)

        let entry = try XCTUnwrap(rows(result, day: 13).first?.entry)
        XCTAssertTrue(entry.value.contains(great.localizedLabel),
                      "Wert '\(entry.value)' muss das Label '\(great.localizedLabel)' enthalten")
    }

    /// Verhalten: unbekannte Level-Id zaehlt als Eintrag, Wert ist die Zahl als Text
    func test_levelTracker_unknownLevelId_showsNumber() throws {
        let t = makeTracker(name: "Mood", mode: .levels, levels: TrackerLevel.moodLevels)
        addLog(t, at: date(13, 9, 0), value: 42)

        let result = TrackerDayEntries.group(trackers: [t], calendar: calendar)

        let entry = try XCTUnwrap(rows(result, day: 13).first?.entry)
        XCTAssertEqual(entry.value, "42")
    }

    /// Verhalten: Zaehler zeigt die Summe der Tages-Logs (1+2+1 = 4)
    func test_counter_sumsValuesOfDay() throws {
        let t = makeTracker(name: "Wasser", mode: .counter, dailyGoal: nil)
        addLog(t, at: date(13, 8, 0), value: 1)
        addLog(t, at: date(13, 12, 0), value: 2)
        addLog(t, at: date(13, 16, 0), value: 1)

        let result = TrackerDayEntries.group(trackers: [t], calendar: calendar)

        let entry = try XCTUnwrap(rows(result, day: 13).first?.entry)
        XCTAssertEqual(entry.value, "4")
    }

    /// Verhalten: Zaehler mit Tagesziel 5 zeigt "4 / 5"
    func test_counter_withDailyGoal_showsSumOfGoal() throws {
        let t = makeTracker(name: "Wasser", mode: .counter, dailyGoal: 5)
        addLog(t, at: date(13, 8, 0), value: 1)
        addLog(t, at: date(13, 12, 0), value: 2)
        addLog(t, at: date(13, 16, 0), value: 1)

        let result = TrackerDayEntries.group(trackers: [t], calendar: calendar)

        let entry = try XCTUnwrap(rows(result, day: 13).first?.entry)
        XCTAssertEqual(entry.value, "4 / 5")
    }

    /// Verhalten: Log ohne Wert zaehlt beim Zaehler als 1
    func test_counter_nilValueCountsAsOne() throws {
        let t = makeTracker(name: "Wasser", mode: .counter)
        addLog(t, at: date(13, 8, 0), value: nil)
        addLog(t, at: date(13, 9, 0), value: nil)

        let result = TrackerDayEntries.group(trackers: [t], calendar: calendar)

        let entry = try XCTUnwrap(rows(result, day: 13).first?.entry)
        XCTAssertEqual(entry.value, "2")
    }

    /// Verhalten: Ja/Nein-, Achtsamkeits- und Vermeiden-Tracker zeigen ein Haekchen ("✓")
    func test_boolean_showsCheckmark() throws {
        let yesNo = makeTracker(name: "Dehnen", mode: .yesNo, displayOrder: 0)
        let awareness = makeTracker(name: "Doomscrolling", mode: .awareness, displayOrder: 1)
        let avoidance = makeTracker(name: "Snacking", mode: .avoidance, displayOrder: 2)
        for t in [yesNo, awareness, avoidance] { addLog(t, at: date(13, 10, 0)) }

        let result = TrackerDayEntries.group(trackers: [yesNo, awareness, avoidance], calendar: calendar)

        let dayRows = rows(result, day: 13)
        XCTAssertEqual(dayRows.count, 3)
        for row in dayRows {
            XCTAssertEqual(row.entry?.value, "✓", "Zeile \(row.name) muss ein Haekchen zeigen")
        }
    }

    /// Verhalten: Notiz und Uhrzeit stammen vom spaetesten Log des Tages
    func test_noteAndLatestTime_ofLatestLog() throws {
        let t = makeTracker(name: "Dankbarkeit", mode: .awareness)
        addLog(t, at: date(13, 8, 15), note: "frueh")
        addLog(t, at: date(13, 20, 45), note: "abends")
        addLog(t, at: date(13, 14, 0), note: "mittags")

        let result = TrackerDayEntries.group(trackers: [t], calendar: calendar)

        let entry = try XCTUnwrap(rows(result, day: 13).first?.entry)
        XCTAssertEqual(entry.note, "abends")
        XCTAssertEqual(entry.time, date(13, 20, 45))
    }

    /// Verhalten: leere oder fehlende Notiz des spaetesten Logs erzeugt keine Notizzeile (note == nil)
    func test_emptyOrMissingNote_isNil() {
        let empty = makeTracker(name: "A", mode: .awareness, displayOrder: 0)
        let missing = makeTracker(name: "B", mode: .awareness, displayOrder: 1)
        addLog(empty, at: date(13, 10, 0), note: "")
        addLog(missing, at: date(13, 10, 0), note: nil)

        let result = TrackerDayEntries.group(trackers: [empty, missing], calendar: calendar)

        let dayRows = rows(result, day: 13)
        XCTAssertEqual(dayRows.count, 2)
        for row in dayRows {
            XCTAssertNotNil(row.entry)
            XCTAssertNil(row.entry?.note, "Zeile \(row.name): keine Notizzeile erwartet")
        }
    }

    /// Verhalten (AC-7): Speichert die App das Level selbst als Notiz ("🙂 Good"), ist das keine Notiz
    /// und darf nicht zusaetzlich zum Wert erscheinen; eine echte Notiz bleibt erhalten.
    func test_levelTracker_noteEqualToLevelLabel_isNotShownAsNote() throws {
        let levels = TrackerLevel.moodLevels
        let great = try XCTUnwrap(levels.first { $0.id == 5 })
        let autoNote = "\(great.icon) \(great.localizedLabel)"

        let auto = makeTracker(name: "Mood", icon: "🙂", mode: .levels, displayOrder: 0, levels: levels)
        addLog(auto, at: date(13, 9, 0), value: great.id, note: autoNote)

        let real = makeTracker(name: "Mood2", icon: "🙂", mode: .levels, displayOrder: 1, levels: levels)
        addLog(real, at: date(13, 9, 0), value: great.id, note: "nach dem Spaziergang")

        let result = TrackerDayEntries.group(trackers: [auto, real], calendar: calendar)

        let dayRows = rows(result, day: 13)
        let autoEntry = try XCTUnwrap(dayRows.first { $0.name == "Mood" }?.entry)
        XCTAssertTrue(autoEntry.value.contains(great.localizedLabel))
        XCTAssertNil(autoEntry.note, "Notiz '\(autoNote)' gleicht dem Anzeigewert und ist keine Notiz")

        let realEntry = try XCTUnwrap(dayRows.first { $0.name == "Mood2" }?.entry)
        XCTAssertEqual(realEntry.note, "nach dem Spaziergang")
    }

    // MARK: - AC-8, AC-9: leere Zeilen

    /// Verhalten: aktive Tracker ohne Log erscheinen als leere Zeile (entry == nil), wenn ein anderer Tracker Eintrag hat
    func test_trackerWithoutLog_emptyRowWhenOtherTrackerHasEntry() throws {
        let filled = makeTracker(name: "Mood", mode: .levels, displayOrder: 0, levels: TrackerLevel.moodLevels)
        let empty1 = makeTracker(name: "Doomscrolling", mode: .awareness, displayOrder: 1)
        let empty2 = makeTracker(name: "Snacking", mode: .awareness, displayOrder: 2)
        addLog(filled, at: date(13, 9, 0), value: 4)

        let result = TrackerDayEntries.group(trackers: [filled, empty1, empty2], calendar: calendar)

        let dayRows = rows(result, day: 13)
        XCTAssertEqual(dayRows.count, 3, "Alle drei aktiven Tracker muessen eine Zeile haben")
        XCTAssertNotNil(dayRows.first { $0.trackerID == filled.id }?.entry)
        XCTAssertNil(try XCTUnwrap(dayRows.first { $0.trackerID == empty1.id }).entry)
        XCTAssertNil(try XCTUnwrap(dayRows.first { $0.trackerID == empty2.id }).entry)
    }

    // MARK: - AC-10, AC-11: Ausnahmen

    /// Verhalten: NoAlc (nach Name und nach HealthKit-Typ) fehlt im Abschnitt Gewohnheiten
    func test_noAlcTracker_excluded() {
        let byName = makeTracker(name: "NoAlc", mode: .levels, displayOrder: 0)
        let byHK = makeTracker(
            name: "Alkohol",
            mode: .levels,
            displayOrder: 1,
            healthKitType: "HKQuantityTypeIdentifierNumberOfAlcoholicBeverages"
        )
        let normal = makeTracker(name: "Doomscrolling", mode: .awareness, displayOrder: 2)
        addLog(byName, at: date(13, 9, 0), value: 0)
        addLog(byHK, at: date(13, 9, 0), value: 0)
        addLog(normal, at: date(13, 9, 0))

        let result = TrackerDayEntries.group(trackers: [byName, byHK, normal], calendar: calendar)

        XCTAssertEqual(rows(result, day: 13).map(\.trackerID), [normal.id], "Nur der normale Tracker darf erscheinen")
    }

    /// Verhalten: ein Tag nur mit NoAlc-Eintrag taucht in der Gruppierung nicht auf
    func test_noAlcOnlyDay_notInResult() {
        let noAlc = makeTracker(name: "NoAlc", mode: .levels)
        addLog(noAlc, at: date(13, 9, 0), value: 0)

        let result = TrackerDayEntries.group(trackers: [noAlc], calendar: calendar)

        XCTAssertNil(result[dayKey(13)])
    }

    /// Verhalten: inaktive Tracker erscheinen nicht und oeffnen keinen Tag
    func test_inactiveTracker_notIncluded() {
        let inactive = makeTracker(name: "Alt", mode: .awareness, isActive: false)
        let active = makeTracker(name: "Aktiv", mode: .awareness)
        addLog(inactive, at: date(12, 10, 0))
        addLog(active, at: date(13, 10, 0))

        let result = TrackerDayEntries.group(trackers: [inactive, active], calendar: calendar)

        XCTAssertNil(result[dayKey(12)], "Tag mit Log nur eines inaktiven Trackers darf nicht enthalten sein")
        XCTAssertEqual(rows(result, day: 13).map(\.trackerID), [active.id])
    }

    // MARK: - AC-12: Reihenfolge

    /// Verhalten: Zeilen stehen nach displayOrder aufsteigend (Reihenfolge der Tracker-Liste)
    func test_rowsSortedByDisplayOrder() {
        let two = makeTracker(name: "Zwei", mode: .awareness, displayOrder: 2)
        let zero = makeTracker(name: "Null", mode: .awareness, displayOrder: 0)
        let one = makeTracker(name: "Eins", mode: .awareness, displayOrder: 1)
        addLog(two, at: date(13, 10, 0))

        let result = TrackerDayEntries.group(trackers: [two, zero, one], calendar: calendar)

        XCTAssertEqual(rows(result, day: 13).map(\.trackerID), [zero.id, one.id, two.id])
    }

    // MARK: - AC-13, AC-14: Tag im Ergebnis

    /// Verhalten: ein Tag ohne jeden Log ist nicht im Ergebnis (Fenster oeffnet nicht)
    func test_dayWithoutAnyLog_notInResult() {
        let t = makeTracker(name: "Doomscrolling", mode: .awareness)
        addLog(t, at: date(13, 10, 0))

        let result = TrackerDayEntries.group(trackers: [t], calendar: calendar)

        XCTAssertNil(result[dayKey(12)], "Tag ohne Log darf nicht enthalten sein")
        XCTAssertNil(result[dayKey(14)])
    }

    /// Verhalten: ein Tag mit mindestens einem Log ist im Ergebnis
    func test_dayWithOneLog_inResult() {
        let t = makeTracker(name: "Doomscrolling", mode: .awareness)
        addLog(t, at: date(13, 10, 0))

        let result = TrackerDayEntries.group(trackers: [t], calendar: calendar)

        XCTAssertNotNil(result[dayKey(13)])
    }

    /// Verhalten: ohne Tracker ist das Ergebnis leer
    func test_noTrackers_emptyResult() {
        XCTAssertTrue(TrackerDayEntries.group(trackers: [], calendar: calendar).isEmpty)
    }

    // MARK: - hasActivity (AC-13, AC-14, AC-16)

    /// Verhalten: nur Tracker-Eintraege reichen, damit der Tag aktiv ist
    func test_hasActivity_onlyTrackerEntries_true() {
        XCTAssertTrue(TrackerDayEntries.hasActivity(
            mindfulnessMinutes: 0, workoutMinutes: 0, hasNoAlc: false, hasTrackerEntries: true))
    }

    /// Verhalten: ohne alles ist der Tag nicht aktiv
    func test_hasActivity_nothing_false() {
        XCTAssertFalse(TrackerDayEntries.hasActivity(
            mindfulnessMinutes: 0, workoutMinutes: 0, hasNoAlc: false, hasTrackerEntries: false))
    }

    /// Verhalten: bisherige Bedingungen unveraendert (Schwelle 2 min, NoAlc)
    func test_hasActivity_existingConditionsUnchanged() {
        XCTAssertTrue(TrackerDayEntries.hasActivity(
            mindfulnessMinutes: 2, workoutMinutes: 0, hasNoAlc: false, hasTrackerEntries: false))
        XCTAssertFalse(TrackerDayEntries.hasActivity(
            mindfulnessMinutes: 1.9, workoutMinutes: 0, hasNoAlc: false, hasTrackerEntries: false))
        XCTAssertTrue(TrackerDayEntries.hasActivity(
            mindfulnessMinutes: 0, workoutMinutes: 2, hasNoAlc: false, hasTrackerEntries: false))
        XCTAssertFalse(TrackerDayEntries.hasActivity(
            mindfulnessMinutes: 0, workoutMinutes: 1.9, hasNoAlc: false, hasTrackerEntries: false))
        XCTAssertTrue(TrackerDayEntries.hasActivity(
            mindfulnessMinutes: 0, workoutMinutes: 0, hasNoAlc: true, hasTrackerEntries: false))
    }

    // MARK: - AC-18: Lokalisierung

    /// Verhalten: "Gewohnheiten"/"kein Eintrag" (DE) und "Habits"/"no entry" (EN) sind lokalisiert, nicht als Schluessel in Grossschreibung
    func test_localization_habitsAndNoEntry_DEandEN() throws {
        let appBundle = Bundle(for: Tracker.self)
        let missing = "__MISSING__"

        func lookup(_ key: String, lang: String) throws -> String {
            let path = try XCTUnwrap(appBundle.path(forResource: lang, ofType: "lproj"),
                                     "\(lang).lproj fehlt im App-Bundle")
            let langBundle = try XCTUnwrap(Bundle(path: path))
            return langBundle.localizedString(forKey: key, value: missing, table: nil)
        }

        XCTAssertEqual(try lookup("Gewohnheiten", lang: "de"), "Gewohnheiten")
        XCTAssertEqual(try lookup("kein Eintrag", lang: "de"), "kein Eintrag")
        XCTAssertEqual(try lookup("Gewohnheiten", lang: "en"), "Habits")
        XCTAssertEqual(try lookup("kein Eintrag", lang: "en"), "no entry")
        XCTAssertNotEqual(try lookup("Gewohnheiten", lang: "de"), "GEWOHNHEITEN")
        XCTAssertNotEqual(try lookup("kein Eintrag", lang: "de"), "KEIN EINTRAG")
    }
}
