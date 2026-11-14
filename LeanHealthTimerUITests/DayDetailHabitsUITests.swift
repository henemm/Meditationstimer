//
//  DayDetailHabitsUITests.swift
//  LeanHealthTimerUITests
//
//  TDD RED fuer #47: Tagesansicht zeigt alle Gewohnheiten.
//  Aufruf: ./Scripts/run-uitests.sh DayDetailHabitsUITests/<methode>
//
//  Testdaten entstehen ueber die echte Oberflaeche (kein Seeding-Hook):
//  Standard-Tracker NoAlc und Mood, dazu "Doomscrolling" (Preset ohne HealthKit)
//  hinzufuegen und heute eine Stimmung (Mood-Level) eintragen.
//

import XCTest

final class DayDetailHabitsUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Helfer

    private func launchArguments(calendarFilter: Bool) -> [String] {
        var args = ["enable-testing", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        if calendarFilter { args += ["-calendarFilterEnabled", "YES"] }
        return args
    }

    /// Tabs haben keine Kennung: nur positionsbasiert (0 Meditation, 1 Workout, 2 Tracker, 3 Erfolge).
    private func tab(_ index: Int) -> XCUIElement {
        let count = app.tabBars.buttons.count
        XCTAssertEqual(count, 4, "Erwartet 4 Tabs (Meditation/Workout/Tracker/Erfolge), gefunden \(count)")
        return app.tabBars.buttons.element(boundBy: index)
    }

    private func dayIdentifier(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = Calendar.current.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return "calendar.day.\(f.string(from: date))"
    }

    /// Frischer Simulator: HealthKit zeigt das Zugriffsblatt im App-Prozess ("Erlauben" ist dort
    /// gesperrt, bis Schalter gesetzt sind). Fuer diese Tests reicht Ablehnen; die Tracker-Eintraege
    /// liegen in SwiftData. Mehrfach pruefen, weil je HealthKit-Typ ein eigenes Blatt kommen kann.
    private func dismissPermissionAlertsIfAny() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let denyPredicate = NSPredicate(
            format: "identifier == 'UIA.Health.DoNotAllow.Button' OR label == 'Nicht erlauben' OR label == 'Don’t Allow' OR label == \"Don't Allow\""
        )
        // Das HealthKit-Blatt kann im App-Prozess oder in einem fremden Prozess (Remote-View) liegen.
        let hosts: [XCUIApplication] = [
            app!,
            XCUIApplication(bundleIdentifier: "com.apple.HealthPrivacyService"),
            XCUIApplication(bundleIdentifier: "com.apple.Health"),
            springboard,
        ]
        // Ablauf je Blatt: "Nicht erlauben", danach Bestaetigungsdialog "OK". Beide liegen im
        // Health-Dienst-Prozess, nicht im App-Prozess; dort erst "OK" (liegt oben), dann "Nicht erlauben".
        // Normales tap() scheitert ("Element nicht mehr gueltig"), daher per Bildschirmkoordinate.
        func tapByCoordinate(_ element: XCUIElement) {
            let frame = element.frame
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
        }
        for _ in 0..<8 {
            var handled = false
            for host in hosts {
                let ok = host.buttons["OK"]
                if ok.waitForExistence(timeout: host === app ? 2 : 1) {
                    tapByCoordinate(ok)
                    handled = true
                    break
                }
            }
            if handled { continue }
            for host in hosts {
                let deny = host.buttons.matching(denyPredicate).firstMatch
                if deny.waitForExistence(timeout: host === app ? 3 : 1) {
                    tapByCoordinate(deny)
                    handled = true
                    break
                }
            }
            if handled { continue }
            // Langes Blatt (10 Themen): "Nicht erlauben" liegt unterhalb des sichtbaren Bereichs und
            // ist erst nach dem Scrollen als Knopf im Baum. Blatt erkennt man an der Titelleiste.
            let sheetBar = app.navigationBars["Health-Zugriff"]
            if sheetBar.exists, app.tables.firstMatch.exists {
                app.tables.firstMatch.swipeUp()
                continue
            }
            break
        }
    }

    /// Legt "Doomscrolling" an (bleibt leer) und loggt heute eine Stimmung. Gibt das Label des geloggten Levels zurueck.
    private func prepareTrackersAndLogMood() throws -> String {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20), "Tab-Leiste fehlt")
        dismissPermissionAlertsIfAny()

        tab(2).tap()

        let addButton = app.buttons.matching(
            NSPredicate(format: "identifier == 'addTrackerButton' OR label == 'Add Tracker' OR label == 'Tracker hinzufügen'")
        ).firstMatch
        var swipes = 0
        while !addButton.exists && swipes < 4 {
            app.scrollViews.firstMatch.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "addTrackerButton nicht gefunden")
        addButton.tap()

        let preset = app.staticTexts["Doomscrolling"]
        XCTAssertTrue(preset.waitForExistence(timeout: 5), "Preset Doomscrolling fehlt")
        preset.tap()

        XCTAssertTrue(app.staticTexts["Doomscrolling"].waitForExistence(timeout: 5),
                      "Doomscrolling muss nach dem Anlegen in der Liste stehen")

        // Mood-Level 'Gut' (Icon 🙂): Kennung ist das Icon, im Level-Layout 'generic_<Icon>'.
        let moodLevel = app.buttons.matching(
            NSPredicate(format: "identifier == '🙂' OR identifier == 'generic_🙂'")
        ).firstMatch
        swipes = 0
        while !moodLevel.exists && swipes < 4 {
            app.scrollViews.firstMatch.swipeDown()
            swipes += 1
        }
        XCTAssertTrue(moodLevel.waitForExistence(timeout: 5), "Mood-Level-Knopf 🙂 nicht gefunden")
        let levelLabel = moodLevel.label
        XCTAssertFalse(levelLabel.isEmpty, "Level-Knopf hat kein Label")
        moodLevel.tap()
        dismissPermissionAlertsIfAny()
        return levelLabel
    }

    private func habitValues() -> XCUIElementQuery {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'dayDetail.habitValue.'")
        )
    }

    private func runFilledAndEmptyRowScenario(calendarFilter: Bool) throws {
        app.launchArguments = launchArguments(calendarFilter: calendarFilter)
        app.launch()

        let moodLabel = try prepareTrackersAndLogMood()
        tab(3).tap()
        dismissPermissionAlertsIfAny()

        let todayCellID = dayIdentifier(Date())
        let todayCell = app.descendants(matching: .any)[todayCellID]
        XCTAssertTrue(todayCell.waitForExistence(timeout: 10), "Tageszelle \(todayCellID) fehlt im Kalender")
        todayCell.tap()

        let section = app.descendants(matching: .any)["dayDetail.habitsSection"]
        XCTAssertTrue(section.waitForExistence(timeout: 10),
                      "Tag nur mit Tracker-Eintrag muss das Fenster mit Abschnitt Gewohnheiten oeffnen")
        XCTAssertTrue(section.isHittable, "Abschnitt Gewohnheiten muss im geoeffneten Fenster sichtbar sein")

        XCTAssertTrue(habitValues().firstMatch.waitForExistence(timeout: 5), "Keine Wertzeile gefunden")

        let filled = habitValues().matching(NSPredicate(format: "label CONTAINS %@", moodLabel))
        XCTAssertGreaterThanOrEqual(filled.count, 1,
                                    "Gefuellte Zeile muss das Level-Label '\(moodLabel)' zeigen")

        let empty = habitValues().matching(NSPredicate(format: "label == 'kein Eintrag'"))
        XCTAssertGreaterThanOrEqual(empty.count, 1, "Leere Zeile muss 'kein Eintrag' zeigen")

        let rows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'dayDetail.habitRow.'")
        )
        XCTAssertGreaterThanOrEqual(rows.count, 2, "Mindestens Mood und Doomscrolling als Zeilen erwartet")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "DayDetail_Gewohnheiten"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Tests

    /// Verhalten (AC-13, AC-8, AC-6/4): Tag ohne Sessions, nur mit Tracker-Eintrag, oeffnet das Fenster;
    /// gefuellte Zeile zeigt das Level, leere Zeile "kein Eintrag".
    func test_dayWithOnlyTrackerEntry_opensSheet_showsFilledAndEmptyRow() throws {
        try runFilledAndEmptyRowScenario(calendarFilter: false)
    }

    /// Verhalten (AC-14): Tag ohne Aktivitaet und ohne Tracker-Eintrag oeffnet kein Fenster.
    func test_dayWithOnlyEmptyTrackers_doesNotOpenSheet() throws {
        let calendar = Calendar.current
        guard calendar.component(.day, from: Date()) >= 2 else {
            throw XCTSkip("Heute ist der 1.: kein vergangener Tag im sichtbaren Monat ohne Aktivitaet verfuegbar")
        }
        let pastDay = calendar.date(byAdding: .day, value: -1, to: Date())!

        app.launchArguments = launchArguments(calendarFilter: false)
        app.launch()

        _ = try prepareTrackersAndLogMood()
        tab(3).tap()
        dismissPermissionAlertsIfAny()

        let cellID = dayIdentifier(pastDay)
        let cell = app.descendants(matching: .any)[cellID]
        XCTAssertTrue(cell.waitForExistence(timeout: 10), "Tageszelle \(cellID) fehlt im Kalender")
        cell.tap()

        let section = app.descendants(matching: .any)["dayDetail.habitsSection"]
        XCTAssertFalse(section.waitForExistence(timeout: 3),
                       "Fuer einen Tag ohne Eintraege darf sich kein Fenster mit Gewohnheiten oeffnen")
    }

    /// Verhalten (AC-15): Auch mit eingeschaltetem Kalenderfilter oeffnet ein Tag mit Tracker-Eintrag das Fenster.
    func test_calendarFilterEnabled_dayWithTrackerEntry_opensSheet() throws {
        try runFilledAndEmptyRowScenario(calendarFilter: true)
    }
}
