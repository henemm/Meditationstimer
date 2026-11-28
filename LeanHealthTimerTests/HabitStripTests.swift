//
//  HabitStripTests.swift
//  LeanHealthTimerTests
//
//  TDD RED fuer #50 (Gewohnheiten-Leiste ueber dem Kalender).
//  Kompiliert erst, wenn `HabitStrip` (Services/HabitStrip.swift) existiert.
//
//  API laut Spec feature-50-gewohnheiten-leiste.md:
//    HabitStrip.trackers(from: [Tracker]) -> [Tracker]
//    HabitStrip.entryDays(for: Tracker, calendar: Calendar) -> Set<Date>
//    HabitStrip.DotState { filled, open, todayOpen }
//    HabitStrip.dots(entryDays: Set<Date>, today: Date, calendar: Calendar) -> [HabitStrip.DotState]
//    HabitStrip.streakText(_ days: Int) -> String
//

import XCTest
import SwiftData
@testable import Lean_Health_Timer

final class HabitStripTests: XCTestCase {

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
        mode: TrackingMode = .awareness,
        dayAssignmentRaw: String? = nil,
        displayOrder: Int = 0,
        isActive: Bool = true,
        showInCalendar: Bool = true,
        healthKitType: String? = nil,
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> Tracker {
        let tracker = Tracker(
            name: name,
            icon: "📱",
            type: .good,
            trackingMode: mode,
            createdAt: createdAt,
            isActive: isActive,
            healthKitType: healthKitType,
            displayOrder: displayOrder
        )
        tracker.dayAssignmentRaw = dayAssignmentRaw
        tracker.showInCalendar = showInCalendar
        context.insert(tracker)
        return tracker
    }

    @discardableResult
    private func addLog(_ tracker: Tracker, at timestamp: Date) -> TrackerLog {
        let log = TrackerLog(timestamp: timestamp, value: nil, note: nil, tracker: tracker)
        context.insert(log)
        try! context.save()
        return log
    }

    // MARK: - AC-1 bis AC-3: Auswahl und Reihenfolge der Karten

    /// Verhalten: nur aktive Nicht-NoAlc-Tracker mit Schalter "Im Kalender anzeigen" bekommen eine Karte.
    func test_trackers_onlyActiveShowInCalendarNonNoAlc() {
        let shown = makeTracker(name: "Dehnen", displayOrder: 0)
        let switchedOff = makeTracker(name: "Aus", displayOrder: 1, showInCalendar: false)
        let inactive = makeTracker(name: "Inaktiv", displayOrder: 2, isActive: false)
        let noAlcByName = makeTracker(name: "NoAlc", mode: .levels, displayOrder: 3)
        let noAlcByHK = makeTracker(
            name: "Alkohol", mode: .levels, displayOrder: 4,
            healthKitType: "HKQuantityTypeIdentifierNumberOfAlcoholicBeverages")

        let result = HabitStrip.trackers(from: [shown, switchedOff, inactive, noAlcByName, noAlcByHK])

        XCTAssertEqual(result.map(\.id), [shown.id],
                       "Nur aktiver Nicht-NoAlc-Tracker mit Schalter an darf eine Karte bekommen")
    }

    /// Verhalten: ohne passenden Tracker ist die Liste leer (keine Leiste, kein Leerplatz).
    func test_trackers_noneEnabled_isEmpty() {
        let off = makeTracker(name: "Aus", showInCalendar: false)
        let noAlc = makeTracker(name: "NoAlc", mode: .levels)

        XCTAssertTrue(HabitStrip.trackers(from: [off, noAlc]).isEmpty)
        XCTAssertTrue(HabitStrip.trackers(from: []).isEmpty)
    }

    /// Verhalten: Karten stehen nach displayOrder aufsteigend (wie Tagesansicht und Tracker-Liste).
    func test_trackers_sortedByDisplayOrder() {
        let two = makeTracker(name: "Zwei", displayOrder: 2)
        let zero = makeTracker(name: "Null", displayOrder: 0)
        let one = makeTracker(name: "Eins", displayOrder: 1)

        let result = HabitStrip.trackers(from: [two, zero, one])

        XCTAssertEqual(result.map(\.id), [zero.id, one.id, two.id])
    }

    // MARK: - AC-4 bis AC-6: Eingetragene Tage

    /// Verhalten: Zeitstempel-Zuordnung, Eintrag 13.11. 17:00 zaehlt nur fuer den 13.11.
    func test_entryDays_timestampAssignment_sameDay() {
        let t = makeTracker(dayAssignmentRaw: nil)
        addLog(t, at: date(13, 17, 0))

        let days = HabitStrip.entryDays(for: t, calendar: calendar)

        XCTAssertEqual(days, [dayKey(13)])
    }

    /// Verhalten: cutoffHour 18: 17:00 -> Vortag, 18:00 -> gleicher Tag, 00:30 -> Vortag (genau eine Verschiebung).
    func test_entryDays_cutoff18_boundaryAndMidnightShiftedOnce() {
        let before = makeTracker(name: "Vor", dayAssignmentRaw: "cutoffHour:18", displayOrder: 0)
        let atCutoff = makeTracker(name: "Genau", dayAssignmentRaw: "cutoffHour:18", displayOrder: 1)
        let afterMidnight = makeTracker(name: "Nacht", dayAssignmentRaw: "cutoffHour:18", displayOrder: 2)
        addLog(before, at: date(13, 17, 0))
        addLog(atCutoff, at: date(13, 18, 0))
        addLog(afterMidnight, at: date(13, 0, 30))

        XCTAssertEqual(HabitStrip.entryDays(for: before, calendar: calendar), [dayKey(12)],
                       "13.11. 17:00 gehoert zum 12.11.")
        XCTAssertEqual(HabitStrip.entryDays(for: atCutoff, calendar: calendar), [dayKey(13)],
                       "13.11. 18:00 gehoert zum 13.11.")
        XCTAssertEqual(HabitStrip.entryDays(for: afterMidnight, calendar: calendar), [dayKey(12)],
                       "13.11. 00:30 gehoert zum 12.11., nicht zum 11.11. (Doppelverschiebung)")
    }

    /// Verhalten: mehrere Logs am selben Tag zaehlen einmal; Vermeiden-Tracker zeigt "eingetragen" ohne Wertung;
    /// Tage ohne Log sind nie eingetragen.
    func test_entryDays_multipleLogsOneDay_andAvoidTracker_noLogNotEntered() {
        let multi = makeTracker(name: "Mehrfach", displayOrder: 0)
        addLog(multi, at: date(13, 8, 0))
        addLog(multi, at: date(13, 12, 0))
        addLog(multi, at: date(13, 20, 0))

        let avoid = makeTracker(name: "Snacking", mode: .avoidance, displayOrder: 1)
        addLog(avoid, at: date(14, 10, 0))

        let empty = makeTracker(name: "Leer", displayOrder: 2)

        XCTAssertEqual(HabitStrip.entryDays(for: multi, calendar: calendar), [dayKey(13)])
        XCTAssertEqual(HabitStrip.entryDays(for: avoid, calendar: calendar), [dayKey(14)])
        XCTAssertTrue(HabitStrip.entryDays(for: empty, calendar: calendar).isEmpty)
        XCTAssertFalse(HabitStrip.entryDays(for: avoid, calendar: calendar).contains(dayKey(15)))
    }

    // MARK: - AC-7, AC-8: Punkte

    /// Verhalten: sieben Punkte 22.-28.11. (ältester links, heute rechts); Eintraege am 22., 25., 28.
    /// ergeben [filled, open, open, filled, open, open, filled]; ohne Eintrag heute ist der letzte Punkt todayOpen.
    func test_dots_filledOpenAndTodayOpen() {
        let today = date(28, 15, 0)

        let withToday = HabitStrip.dots(
            entryDays: [dayKey(22), dayKey(25), dayKey(28)], today: today, calendar: calendar)
        XCTAssertEqual(withToday, [.filled, .open, .open, .filled, .open, .open, .filled])

        let withoutToday = HabitStrip.dots(
            entryDays: [dayKey(22), dayKey(25)], today: today, calendar: calendar)
        XCTAssertEqual(withoutToday, [.filled, .open, .open, .filled, .open, .open, .todayOpen])
    }

    /// Verhalten: Tage vor Anlage des Trackers sind offen, kein vierter Zustand.
    func test_dots_daysBeforeCreation_areOpen() {
        let t = makeTracker(name: "Neu", createdAt: date(27, 9, 0))
        addLog(t, at: date(27, 10, 0))
        addLog(t, at: date(28, 10, 0))
        let today = date(28, 15, 0)

        let days = HabitStrip.entryDays(for: t, calendar: calendar)
        let dots = HabitStrip.dots(entryDays: days, today: today, calendar: calendar)

        XCTAssertEqual(dots.count, 7)
        XCTAssertEqual(Array(dots.prefix(5)), [.open, .open, .open, .open, .open])
        XCTAssertEqual(Array(dots.suffix(2)), [.filled, .filled])
    }

    // MARK: - AC-9: Serie-Text

    /// Verhalten: "Serie 0 Tage" / "Serie 1 Tag" / "Serie 5 Tage" (EN "Streak 0 days" / "Streak 1 day" / "Streak 5 days").
    /// Die Sprache des Testprozesses ist nicht steuerbar: Katalogwerte kommen aus de.lproj/en.lproj, und
    /// streakText muss in der laufenden Sprache genau einen dieser Werte liefern (nie den Schluessel in Grossschreibung).
    func test_streakText_zeroOneMany_DEandEN() throws {
        let appBundle = Bundle(for: Tracker.self)
        let missing = "__MISSING__"

        func catalog(_ key: String, lang: String) throws -> String {
            let path = try XCTUnwrap(appBundle.path(forResource: lang, ofType: "lproj"),
                                     "\(lang).lproj fehlt im App-Bundle")
            let langBundle = try XCTUnwrap(Bundle(path: path))
            return langBundle.localizedString(forKey: key, value: missing, table: nil)
        }
        func formatted(_ key: String, lang: String, _ n: Int) throws -> String {
            String(format: try catalog(key, lang: lang), n)
        }

        XCTAssertEqual(try formatted("Serie %lld Tage", lang: "de", 0), "Serie 0 Tage")
        XCTAssertEqual(try formatted("Serie %lld Tage", lang: "de", 5), "Serie 5 Tage")
        XCTAssertEqual(try catalog("Serie 1 Tag", lang: "de"), "Serie 1 Tag")
        XCTAssertEqual(try formatted("Serie %lld Tage", lang: "en", 0), "Streak 0 days")
        XCTAssertEqual(try formatted("Serie %lld Tage", lang: "en", 5), "Streak 5 days")
        XCTAssertEqual(try catalog("Serie 1 Tag", lang: "en"), "Streak 1 day")

        XCTAssertTrue(["Serie 0 Tage", "Streak 0 days"].contains(HabitStrip.streakText(0)),
                      "Ist: \(HabitStrip.streakText(0))")
        XCTAssertTrue(["Serie 1 Tag", "Streak 1 day"].contains(HabitStrip.streakText(1)),
                      "Ist: \(HabitStrip.streakText(1))")
        XCTAssertTrue(["Serie 5 Tage", "Streak 5 days"].contains(HabitStrip.streakText(5)),
                      "Ist: \(HabitStrip.streakText(5))")
    }

    // MARK: - AC-16: Lokalisierung

    /// Verhalten: "dauerhaft"/"ongoing", "ausgewählt"/"selected", "markiert"/"marked" sind lokalisiert,
    /// nicht als Schluessel in Grossschreibung.
    func test_localization_ongoingAndSelectedAndMarked_DEandEN() throws {
        let appBundle = Bundle(for: Tracker.self)
        let missing = "__MISSING__"

        func lookup(_ key: String, lang: String) throws -> String {
            let path = try XCTUnwrap(appBundle.path(forResource: lang, ofType: "lproj"),
                                     "\(lang).lproj fehlt im App-Bundle")
            let langBundle = try XCTUnwrap(Bundle(path: path))
            return langBundle.localizedString(forKey: key, value: missing, table: nil)
        }

        XCTAssertEqual(try lookup("dauerhaft", lang: "de"), "dauerhaft")
        XCTAssertEqual(try lookup("ausgewählt", lang: "de"), "ausgewählt")
        XCTAssertEqual(try lookup("markiert", lang: "de"), "markiert")
        XCTAssertEqual(try lookup("dauerhaft", lang: "en"), "ongoing")
        XCTAssertEqual(try lookup("ausgewählt", lang: "en"), "selected")
        XCTAssertEqual(try lookup("markiert", lang: "en"), "marked")
        XCTAssertNotEqual(try lookup("dauerhaft", lang: "de"), "DAUERHAFT")
        XCTAssertNotEqual(try lookup("ausgewählt", lang: "de"), "AUSGEWÄHLT")
        XCTAssertNotEqual(try lookup("markiert", lang: "de"), "MARKIERT")
    }
}
