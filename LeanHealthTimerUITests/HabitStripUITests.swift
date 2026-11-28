//
//  HabitStripUITests.swift
//  LeanHealthTimerUITests
//
//  TDD RED fuer #50: Gewohnheiten-Leiste ueber dem Kalender.
//  Aufruf: ./Scripts/run-uitests.sh HabitStripUITests/<methode>
//
//  Testdaten entstehen ueber die echte Oberflaeche (kein Seeding-Hook):
//  Presets "Doomscrolling" und "Snacking" (Awareness, ohne HealthKit) anlegen, Eintrag ueber
//  den Knopf "Hinweis", Schalter "Im Kalender anzeigen" (showInCalendarToggle) im Editor.
//  Tab-Knoepfe haben keine Kennung: positionsbasiert (3 = Erfolge).
//

import XCTest

final class HabitStripUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "enable-testing", "uitest-disk-store", "uitest-reset-store",
            "-AppleLanguages", "(de)", "-AppleLocale", "de_DE",
        ]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20), "Tab-Leiste fehlt")
        app.dismissHealthSheetIfAny()
    }

    // MARK: - Helfer

    private func tab(_ index: Int) -> XCUIElement {
        let count = app.tabBars.buttons.count
        XCTAssertEqual(count, 4, "Erwartet 4 Tabs, gefunden \(count)")
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

    /// Ein vom heutigen Tag verschiedener Tag im sichtbaren Monat (gestern, am Monatsersten morgen).
    private var otherDay: Date {
        let cal = Calendar.current
        let offset = cal.component(.day, from: Date()) >= 2 ? -1 : 1
        return cal.date(byAdding: .day, value: offset, to: Date())!
    }

    private func scrollTo(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < 5 {
            app.scrollViews.firstMatch.swipeUp()
            swipes += 1
        }
        swipes = 0
        while !(element.exists && element.isHittable) && swipes < 5 {
            app.scrollViews.firstMatch.swipeDown()
            swipes += 1
        }
        XCTAssertTrue(element.exists && element.isHittable, "Element nicht erreichbar: \(element)", file: file, line: line)
    }

    /// Knopf aus `query`, dessen Mitte vertikal am naechsten an `anchor` liegt (gleiche Zeile).
    private func nearest(_ query: XCUIElementQuery, to anchor: XCUIElement) -> XCUIElement {
        let y = anchor.frame.midY
        var best: XCUIElement = query.firstMatch
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for element in query.allElementsBoundByIndex {
            let distance = abs(element.frame.midY - y)
            if distance < bestDistance {
                bestDistance = distance
                best = element
            }
        }
        return best
    }

    private func addPreset(_ name: String) {
        tab(2).tap()
        app.dismissHealthSheetIfAny()
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
        let preset = app.staticTexts[name]
        XCTAssertTrue(preset.waitForExistence(timeout: 5), "Preset \(name) fehlt")
        preset.tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5), "\(name) muss in der Liste stehen")
    }

    /// Tracker-Reiter: Eintrag heute ueber den Knopf "Hinweis" in der Zeile des Trackers.
    private func logToday(_ name: String) {
        tab(2).tap()
        let title = app.staticTexts[name]
        scrollTo(title)
        let buttons = app.buttons.matching(NSPredicate(format: "label == 'Hinweis' OR label == 'Notice'"))
        let button = nearest(buttons, to: title)
        XCTAssertTrue(button.exists, "Knopf Hinweis in der Zeile von \(name) fehlt")
        button.tap()
        app.dismissHealthSheetIfAny()
    }

    /// Tracker-Reiter: Editor des Trackers oeffnen, Schalter "Im Kalender anzeigen" setzen, Editor schliessen.
    private func setCalendarSwitch(_ name: String, on: Bool) {
        tab(2).tap()
        let title = app.staticTexts[name]
        scrollTo(title)
        let edits = app.buttons.matching(identifier: "trackerEditButton")
        let edit = nearest(edits, to: title)
        XCTAssertTrue(edit.exists, "Bearbeiten-Knopf von \(name) fehlt")
        edit.tap()

        let toggle = app.descendants(matching: .any)["showInCalendarToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "showInCalendarToggle fehlt im Editor")
        var swipes = 0
        while !toggle.isHittable && swipes < 5 {
            app.swipeUp()
            swipes += 1
        }
        let want = on ? "1" : "0"
        if (toggle.value as? String) != want {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        XCTAssertEqual(toggle.value as? String, want, "Schalter 'Im Kalender anzeigen' hat nicht den Wert \(want)")

        let done = app.buttons.matching(NSPredicate(format: "label == 'Fertig' OR label == 'Done'")).firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5), "Fertig-Knopf des Editors fehlt")
        done.tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }

    private func openAchievements() {
        tab(3).tap()
        app.dismissHealthSheetIfAny()
    }

    private var strip: XCUIElement { app.descendants(matching: .any)["calendar.habitStrip"] }

    private func card(_ name: String) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'calendar.habit.card' AND label == %@", name)
        ).firstMatch
    }

    private func cell(_ date: Date) -> XCUIElement {
        app.descendants(matching: .any)[dayIdentifier(date)]
    }

    private func value(_ element: XCUIElement) -> String {
        (element.value as? String) ?? ""
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Tests

    /// Verhalten (AC-1, AC-10): Tracker mit Eintrag heute und Schalter "Im Kalender anzeigen" an:
    /// im Reiter Erfolge steht die Leiste mit einer Karte, deren Bezeichnung der Trackername ist.
    func test_switchOn_cardVisible() throws {
        addPreset("Doomscrolling")
        logToday("Doomscrolling")
        setCalendarSwitch("Doomscrolling", on: true)

        openAchievements()

        XCTAssertTrue(strip.waitForExistence(timeout: 10), "calendar.habitStrip fehlt bei eingeschaltetem Schalter")
        XCTAssertTrue(strip.isHittable, "Leiste muss sichtbar sein")
        let c = card("Doomscrolling")
        XCTAssertTrue(c.waitForExistence(timeout: 5), "Karte calendar.habit.card mit Label 'Doomscrolling' fehlt")
        XCTAssertTrue(c.isHittable, "Karte muss sichtbar sein")
        XCTAssertEqual(value(c), "", "Ohne Auswahl ist der Kartenwert leer")
        attach("Leiste_ohne_Auswahl")
    }

    /// Verhalten (AC-2): Schalter aus (Standard): keine Leiste im Reiter Erfolge.
    func test_switchOff_noStrip() throws {
        addPreset("Doomscrolling")
        logToday("Doomscrolling")
        setCalendarSwitch("Doomscrolling", on: false)

        openAchievements()

        XCTAssertTrue(cell(Date()).waitForExistence(timeout: 10), "Kalender muss sichtbar sein")
        XCTAssertFalse(strip.exists, "Ohne eingeschalteten Schalter darf calendar.habitStrip nicht existieren")
        XCTAssertFalse(card("Doomscrolling").exists, "Keine Karte ohne eingeschalteten Schalter")
    }

    /// Verhalten (AC-11): Karte antippen waehlt sie aus; der Tag mit Eintrag (heute) ist "markiert",
    /// ein anderer Tag ohne Eintrag nicht.
    func test_tapCard_marksDayWithEntry_notOtherDay() throws {
        addPreset("Doomscrolling")
        logToday("Doomscrolling")
        setCalendarSwitch("Doomscrolling", on: true)
        openAchievements()

        let today = cell(Date())
        let other = cell(otherDay)
        XCTAssertTrue(today.waitForExistence(timeout: 10), "Tageszelle heute fehlt")
        XCTAssertTrue(other.waitForExistence(timeout: 5), "Tageszelle eines anderen Tages fehlt")
        XCTAssertNotEqual(value(today), "markiert", "Vor dem Antippen darf nichts markiert sein")

        let c = card("Doomscrolling")
        XCTAssertTrue(c.waitForExistence(timeout: 10), "Karte fehlt")
        XCTAssertTrue(c.isHittable, "Karte muss antippbar sein")
        c.tap()

        XCTAssertEqual(value(c), "ausgewählt", "Angetippte Karte muss 'ausgewählt' melden")
        XCTAssertTrue(c.isSelected, "Angetippte Karte muss den Trait isSelected tragen")
        XCTAssertEqual(value(today), "markiert", "Tag mit Eintrag muss 'markiert' sein")
        XCTAssertNotEqual(value(other), "markiert", "Tag ohne Eintrag darf nicht markiert sein")
        attach("Leiste_mit_Auswahl")
    }

    /// Verhalten (AC-12): Erneutes Antippen hebt Auswahl und Markierung auf. Wechsel auf eine zweite Karte
    /// (ohne Eintraege): nur diese ist ausgewaehlt, der Tag der ersten ist nicht mehr markiert.
    func test_tapCardAgain_removesMarking() throws {
        addPreset("Doomscrolling")
        addPreset("Snacking")
        logToday("Doomscrolling")
        setCalendarSwitch("Doomscrolling", on: true)
        setCalendarSwitch("Snacking", on: true)
        openAchievements()

        let today = cell(Date())
        XCTAssertTrue(today.waitForExistence(timeout: 10), "Tageszelle heute fehlt")
        let a = card("Doomscrolling")
        let b = card("Snacking")
        XCTAssertTrue(a.waitForExistence(timeout: 10), "Karte Doomscrolling fehlt")
        XCTAssertTrue(b.waitForExistence(timeout: 5), "Karte Snacking fehlt")

        a.tap()
        XCTAssertEqual(value(a), "ausgewählt")
        XCTAssertEqual(value(today), "markiert")

        a.tap()
        XCTAssertNotEqual(value(a), "ausgewählt", "Erneutes Antippen muss die Auswahl aufheben")
        XCTAssertFalse(a.isSelected)
        XCTAssertNotEqual(value(today), "markiert", "Nach dem Aufheben darf nichts markiert sein")

        a.tap()
        XCTAssertEqual(value(today), "markiert")
        b.tap()
        XCTAssertEqual(value(b), "ausgewählt", "Zweite Karte muss ausgewaehlt sein")
        XCTAssertNotEqual(value(a), "ausgewählt", "Hoechstens eine Auswahl gleichzeitig")
        XCTAssertNotEqual(value(today), "markiert",
                          "Snacking hat keinen Eintrag heute: nur Tage der gewaehlten Karte sind markiert")
    }

    /// Verhalten (AC-13, AC-14): Mit gewaehlter Karte oeffnet das Antippen eines Tages mit Aktivitaet
    /// weiterhin die Tagesansicht mit dem Abschnitt Gewohnheiten.
    func test_dayTap_stillOpensDetailSheet_withSelection() throws {
        addPreset("Doomscrolling")
        logToday("Doomscrolling")
        setCalendarSwitch("Doomscrolling", on: true)
        openAchievements()

        let c = card("Doomscrolling")
        XCTAssertTrue(c.waitForExistence(timeout: 10), "Karte fehlt")
        c.tap()
        XCTAssertEqual(value(c), "ausgewählt")

        let today = cell(Date())
        XCTAssertTrue(today.waitForExistence(timeout: 5), "Tageszelle heute fehlt")
        XCTAssertEqual(value(today), "markiert")
        today.tap()

        let section = app.descendants(matching: .any)["dayDetail.habitsSection"]
        XCTAssertTrue(section.waitForExistence(timeout: 10),
                      "Tagesansicht mit Abschnitt Gewohnheiten muss trotz Markierung oeffnen")
        XCTAssertTrue(section.isHittable, "Abschnitt Gewohnheiten muss sichtbar sein")
    }
}
