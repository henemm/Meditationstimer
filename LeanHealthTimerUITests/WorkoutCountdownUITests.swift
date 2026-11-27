//
//  WorkoutCountdownUITests.swift
//  LeanHealthTimerUITests
//
//  TDD RED fuer #35 Schnitt 2 (AC-9): Beim Workout-Programm beginnt Uhr, Ringe und Rundenanzeige
//  erst nach dem Countdown.
//  Aufruf: ./Scripts/run-uitests.sh WorkoutCountdownUITests/testWorkoutProgramStartetErstNachCountdown
//
//  Testdaten: "Tabata Classic" (erste Uebung 20 s Arbeit, dann 10 s Pause) mit 20 s Countdown. Laeuft die
//  Uhr (wie heute) schon waehrend des Countdowns, ist die erste Arbeitsphase beim Countdown-Ende
//  vorbei und die Karte steht in der Pause; zeigt sie erst nach dem Countdown bei null, steht sie
//  in der Arbeitsphase (Ringtext "Exercise").
//
//  Der Countdown wird per Launch-Argument `-countdownBeforeStart <integer>20</integer>` gesetzt (AppStorage-Schluessel
//  `countdownBeforeStart`, Argument-Domain ueberschreibt den gespeicherten Wert, keine App-Aenderung).
//

import XCTest

final class WorkoutCountdownUITests: XCTestCase {
    var app: XCUIApplication!
    private let presetName = "Tabata Classic"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["enable-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                               "-countdownBeforeStart", "<integer>20</integer>"]
        app.launch()
        app.dismissStartHealthSheetIfAny()
        dismissSystemAlertsIfAny()
    }

    // MARK: - Helfer

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func dismissSystemAlertsIfAny() {
        let hosts: [XCUIApplication] = [
            app!,
            XCUIApplication(bundleIdentifier: "com.apple.HealthPrivacyService"),
            XCUIApplication(bundleIdentifier: "com.apple.springboard"),
        ]
        for _ in 0..<6 {
            var handled = false
            for host in hosts {
                for label in ["OK", "Don’t Allow", "Don't Allow"] {
                    let b = host.buttons[label]
                    if b.waitForExistence(timeout: host === app ? 1 : 0.5), b.isHittable {
                        b.tap()
                        handled = true
                        break
                    }
                }
                if handled { break }
            }
            if !handled { return }
        }
    }

    /// Tabs haben keine Kennung: positionsbasiert (1 = Workout).
    private func openWorkoutTab() {
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 30), "Tab-Leiste erscheint nicht")
        app.tabBars.buttons.element(boundBy: 1).tap()
    }

    private func startPreset() {
        let start = element("workout.programRow.\(presetName).start")
        XCTAssertTrue(start.waitForExistence(timeout: 20), "Start-Knopf von \(presetName) fehlt")
        // Kein Alert-Abfangen nach dem Tippen: Schnappschuesse waehrend des laufenden Countdowns
        // sind langsam und wuerden den kurzen Countdown aufbrauchen. Nur der optionale Health-Alert
        // des Programmstarts (#122, AC-9) wird kurz bedient; der Countdown ist 20 s lang.
        start.tap()
        app.handleProgramStartHealthPrompts()
    }

    private var countdownText: XCUIElement { app.staticTexts["Get ready..."] }

    private var roundLabel: XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Round 1 /'")).firstMatch
    }

    /// Ringtext der Arbeitsphase (in der Pause nicht vorhanden).
    private var workRingText: XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label == 'Exercise'")).firstMatch
    }

    private var exerciseLabel: XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Exercise 1 /'")).firstMatch
    }

    private func endTrainingIfRunning() {
        for label in ["End", "Stop", "Beenden"] {
            let b = app.buttons[label]
            if b.exists && b.isHittable {
                b.tap()
                break
            }
        }
        dismissSystemAlertsIfAny()
    }

    // MARK: - Test

    /// Verhalten (AC-9): Given Programmstart mit Countdown, When der Countdown laeuft, Then ist die
    /// Rundenanzeige der Karte nicht da (Uhr und Ringe existieren noch nicht); When er endet, Then
    /// zeigt die Karte Uebung 1 und Runde 1. Given Abbruch im Countdown, Then schliesst die Karte
    /// ohne Effort-Sheet.
    func testWorkoutProgramStartetErstNachCountdown() throws {
        openWorkoutTab()

        // Teil 1: Abbruch im Countdown schliesst die Karte ohne Abschluss-Sheet.
        startPreset()
        XCTAssertTrue(countdownText.waitForExistence(timeout: 10), "Countdown erscheint nicht")
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "Abbrechen im Countdown fehlt")
        cancel.tap()
        XCTAssertTrue(element("workout.programRow.\(presetName).start").waitForExistence(timeout: 10),
                      "Nach Abbruch muss die Programmliste wieder da sein")
        XCTAssertFalse(countdownText.exists, "Countdown steht nach Abbruch noch")
        XCTAssertEqual(app.sheets.count, 0, "Nach Abbruch im Countdown darf kein Sheet erscheinen")

        // Teil 2: Waehrend des Countdowns keine Rundenanzeige, danach Uebung 1 / Runde 1.
        startPreset()
        XCTAssertTrue(countdownText.waitForExistence(timeout: 10), "Countdown erscheint nicht")
        XCTAssertFalse(roundLabel.exists && roundLabel.isHittable,
                       "Waehrend des Countdowns darf die Rundenanzeige der Karte nicht sichtbar sein")
        XCTAssertFalse(exerciseLabel.exists && exerciseLabel.isHittable,
                       "Waehrend des Countdowns darf die Uebungsanzeige der Karte nicht sichtbar sein")

        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: countdownText)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 40), .completed, "Countdown endet nicht")

        // Sofort nach dem Countdown: Uebung 1, Runde 1 und die erste Arbeitsphase bei null.
        XCTAssertTrue(roundLabel.waitForExistence(timeout: 3), "Nach dem Countdown fehlt 'Round 1 / N'")
        XCTAssertTrue(exerciseLabel.waitForExistence(timeout: 3), "Nach dem Countdown fehlt 'Exercise 1 / N'")
        XCTAssertTrue(workRingText.waitForExistence(timeout: 3),
                      "Nach dem Countdown muss die erste Arbeitsphase bei null stehen (Ringtext 'Exercise'); "
                      + "die Uhr lief schon waehrend des Countdowns, die Karte steht in der Pause")

        endTrainingIfRunning()
    }
}
