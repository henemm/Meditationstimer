//
//  ProgrammFreigabeUITests.swift
//  LeanHealthTimerUITests
//
//  TDD RED fuer #122: Workout-Programm prueft vor dem Start die Health-Schreibfreigabe.
//  Aufruf: ./Scripts/run-uitests.sh ProgrammFreigabeUITests/<methode>
//
//  VORAUSSETZUNG: Der Zustand "nie gefragt" wird im Test selbst hergestellt: `app.resetAuthorizationStatus(for: .health)`
//  in setUp, vor `launch()` (WWDC20 10220; beendet die App). Kein externer Reset noetig
//  (`simctl privacy` kennt keinen Dienst "health").
//
//  Testdaten: "Tabata Classic" mit 20 s Countdown. "Programm laeuft" = Text "Get ready..." (Countdown) bzw.
//  "Round 1 /" (Rundenzaehler) ist sichtbar. Die Sprache ist Englisch (wie die Bestandstests, "Allow").
//

import XCTest

final class ProgrammFreigabeUITests: XCTestCase {
    var app: XCUIApplication!
    private let presetName = "Tabata Classic"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.resetAuthorizationStatus(for: .health)
        app.launchArguments = ["enable-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                               "-countdownBeforeStart", "<integer>300</integer>"]
        app.launch()
        // Nach dem Reset fragt der App-Start nach "Minuten der Achtsamkeit" (nicht Workout): ablehnen.
        app.dismissStartHealthSheetIfAny()
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 30), "Tab-Leiste erscheint nicht")
        // Beim ersten Start nach der Installation ignoriert die App "-AppleLanguages (en)" und startet deutsch
        // (Beleg: validate/fix-trotzdemStarten-run1.txt, Versuch 1). Dann einmal neu starten: Versuche 2 und 3 sind englisch.
        if app.descendants(matching: .any)["Erfolge"].exists {
            app.terminate()
            app.launch()
            app.dismissStartHealthSheetIfAny()
            XCTAssertTrue(bar.waitForExistence(timeout: 30), "Tab-Leiste nach Neustart fehlt")
        }
        // Tabs haben keine Kennung: positionsbasiert (1 = Workout).
        app.tabBars.buttons.element(boundBy: 1).tap()
    }

    // MARK: - Helfer

    private var startButton: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "workout.programRow.\(presetName).start").firstMatch
    }

    private var countdownText: XCUIElement { app.staticTexts["Get ready..."] }

    private var roundLabel: XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Round 1 /'")).firstMatch
    }

    private func tapStart() {
        XCTAssertTrue(startButton.waitForExistence(timeout: 20), "Start-Knopf von \(presetName) fehlt")
        startButton.tap()
    }

    /// Programm laeuft: Countdown oder Rundenzaehler sichtbar.
    private func assertProgramRuns(_ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let seen = countdownText.waitForExistence(timeout: 20) || roundLabel.waitForExistence(timeout: 5)
        XCTAssertTrue(seen, message, file: file, line: line)
    }

    /// Programm laeuft nicht: auch nach einigen Sekunden weder Countdown noch Rundenzaehler.
    private func assertProgramDoesNotRun(_ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let running = NSPredicate { _, _ in self.countdownText.exists || self.roundLabel.exists }
        let exp = XCTNSPredicateExpectation(predicate: running, object: nil)
        exp.isInverted = true
        XCTAssertEqual(XCTWaiter().wait(for: [exp], timeout: 5), .completed, message, file: file, line: line)
        XCTAssertTrue(startButton.exists, "Programmliste muss weiter sichtbar sein: \(message)", file: file, line: line)
    }

    /// Countdown 300 s statt 20 s: Das Programm startet hinter dem System-Blatt, dessen Bedienung > 60 s dauert;
    /// bei 20 s waere der Countdown vorher abgelaufen und "Cancel" weg.
    /// Beendet das laufende Programm ueber "Cancel" im Countdown und wartet auf die Programmliste.
    private func cancelRunningProgram() {
        XCTAssertTrue(countdownText.waitForExistence(timeout: 10), "Countdown zum Beenden fehlt")
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "Cancel im Countdown fehlt")
        cancel.tap()
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Programmliste nach Abbruch fehlt")
    }

    /// Stellt "verweigert" her: Start -> "Allow" -> im System-Blatt "Don't Allow". Beendet ein ggf. startendes Programm.
    private func makeWriteDenied() {
        tapStart()
        XCTAssertTrue(app.healthAccessAlert.waitForExistence(timeout: 10), "Health Access fehlt beim ersten Start")
        app.healthAccessAlert.buttons.matching(NSPredicate(format: "label == 'Allow' OR label == 'Erlauben'")).firstMatch.tap()
        app.dismissHealthSheetIfAny(until: countdownText)
        if countdownText.waitForExistence(timeout: 5) {
            cancelRunningProgram()
        }
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Programmliste fehlt nach Verweigern")
    }

    // MARK: - (a) nie gefragt

    /// Verhalten (AC-2): Nie gefragt -> "Health Access"; "Allow" -> Blatt komplett erlauben -> Programm laeuft.
    func test_nieGefragt_allow_programmLaeuft() throws {
        tapStart()
        let alert = app.healthAccessAlert
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "Alert 'Health Access' erscheint nicht")
        alert.buttons["Allow"].tap()
        XCTAssertTrue(app.allowHealthSheetCompletely(), "Health-Blatt (Alle auswaehlen / Erlauben) erscheint nicht")
        assertProgramRuns("Nach 'Allow' und Freigabe muss das Programm laufen")
    }

    /// Verhalten (AC-2): Nie gefragt -> "Health Access"; "Cancel" -> Programm startet nicht.
    func test_nieGefragt_cancel_programmLaeuftNicht() throws {
        tapStart()
        let alert = app.healthAccessAlert
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "Alert 'Health Access' erscheint nicht")
        alert.buttons["Cancel"].tap()
        assertProgramDoesNotRun("Nach 'Cancel' darf das Programm nicht starten")
    }

    // MARK: - (b) verweigert

    /// Verhalten (AC-3): Verweigert -> Rueckfrage statt "Health Access"; "Start Anyway" -> Programm laeuft.
    func test_verweigert_trotzdemStarten_programmLaeuft() throws {
        makeWriteDenied()
        tapStart()
        XCTAssertTrue(app.workoutNotSavedAlert.waitForExistence(timeout: 10),
                      "Rueckfrage 'Workout won't be saved' erscheint nicht")
        XCTAssertFalse(app.healthAccessAlert.exists, "'Health Access' darf bei Verweigerung nicht erscheinen")
        XCTAssertTrue(app.workoutNotSavedAlert.buttons["Settings"].exists, "Knopf 'Settings' fehlt")
        app.workoutNotSavedAlert.buttons["Start Anyway"].tap()
        assertProgramRuns("Nach 'Start Anyway' muss das Programm laufen")
    }

    /// Verhalten (AC-4): Verweigert -> Rueckfrage; "Settings" -> Programm startet nicht.
    func test_verweigert_einstellungen_programmLaeuftNicht() throws {
        makeWriteDenied()
        tapStart()
        XCTAssertTrue(app.workoutNotSavedAlert.waitForExistence(timeout: 10),
                      "Rueckfrage 'Workout won't be saved' erscheint nicht")
        app.workoutNotSavedAlert.buttons["Settings"].tap()
        // Die App wechselt in die Systemeinstellungen; zurueck in die App.
        app.activate()
        XCTAssertTrue(startButton.waitForExistence(timeout: 15), "Programmliste nach Rueckkehr fehlt")
        assertProgramDoesNotRun("Nach 'Settings' darf das Programm nicht starten")
    }

    // MARK: - AC-5 erlaubt

    /// Verhalten (AC-5): Nach voller Freigabe startet ein zweiter Start ohne jeden Dialog.
    func test_erlaubt_zweiterStartOhneDialog() throws {
        tapStart()
        XCTAssertTrue(app.healthAccessAlert.waitForExistence(timeout: 10), "Health Access fehlt beim ersten Start")
        app.healthAccessAlert.buttons["Allow"].tap()
        XCTAssertTrue(app.allowHealthSheetCompletely(), "Health-Blatt (Alle auswaehlen / Erlauben) erscheint nicht")
        cancelRunningProgram()

        tapStart()
        XCTAssertTrue(countdownText.waitForExistence(timeout: 10), "Zweiter Start muss direkt den Countdown zeigen")
        XCTAssertFalse(app.healthAccessAlert.exists, "Kein 'Health Access' bei erlaubter Freigabe")
        XCTAssertFalse(app.workoutNotSavedAlert.exists, "Keine Rueckfrage bei erlaubter Freigabe")
        XCTAssertEqual(app.alerts.count, 0, "Bei erlaubter Freigabe darf kein Alert erscheinen")
    }
}
