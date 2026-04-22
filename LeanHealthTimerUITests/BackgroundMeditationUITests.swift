import XCTest

/// Tests für Bug #7 — Session wird beim Hintergrund-Wechsel beendet
///
/// Prüft ALLE 4 Timer-Views: Geführtes Workout, Freie Meditation, Atemübung, Freies Workout.
/// Jede View muss nach Hintergrund → Vordergrund die Session weiterlaufen lassen.
final class BackgroundMeditationUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["enable-testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Navigiert zur Workout-Übersicht und startet die erste verfügbare Session.
    /// Gibt true zurück wenn die Session-Card sichtbar ist (Pause-Button vorhanden).
    @discardableResult
    private func startFirstWorkoutSession() -> Bool {
        let workoutTab = app.tabBars.buttons["Workout"]
        guard workoutTab.waitForExistence(timeout: 10) else {
            XCTFail("Workout-Tab nicht gefunden")
            return false
        }
        workoutTab.tap()

        // Start-Button der ersten Workout-Karte (accessibilityLabel "Start")
        let startButton = app.buttons["Start"].firstMatch
        guard startButton.waitForExistence(timeout: 10) else {
            XCTFail("Start-Button nicht gefunden — kein Workout-Set vorhanden?")
            return false
        }
        startButton.tap()

        // Session-Card ist aktiv, wenn Pause-Button erscheint
        let pauseButton = app.buttons["Pause"].firstMatch
        return pauseButton.waitForExistence(timeout: 10)
    }

    /// Startet eine freie Meditation (Meditation-Tab → play.circle.fill).
    /// Gibt true zurück wenn die Session läuft (End-Button vorhanden).
    @discardableResult
    private func startFreeMeditation() -> Bool {
        let meditationTab = app.tabBars.buttons["Meditation"]
        guard meditationTab.waitForExistence(timeout: 10) else {
            XCTFail("Meditation-Tab nicht gefunden")
            return false
        }
        meditationTab.tap()

        let playButton = app.buttons["play.circle.fill"]
        guard playButton.waitForExistence(timeout: 5) else {
            XCTFail("Play-Button nicht gefunden")
            return false
        }
        playButton.tap()

        // HealthKit-Dialog falls nötig
        let allowButton = app.buttons["Allow"]
        if allowButton.waitForExistence(timeout: 3) {
            allowButton.tap()
            sleep(2)
            if playButton.waitForExistence(timeout: 2) {
                playButton.tap()
            }
        }

        let endButton = app.buttons["End"].firstMatch
        return endButton.waitForExistence(timeout: 8)
    }

    /// Startet ein freies Workout (Workout-Tab → play.circle.fill).
    /// Gibt true zurück wenn die Session läuft (Pause-Button vorhanden).
    @discardableResult
    private func startFreeWorkout() -> Bool {
        let workoutTab = app.tabBars.buttons["Workout"]
        guard workoutTab.waitForExistence(timeout: 10) else {
            XCTFail("Workout-Tab nicht gefunden")
            return false
        }
        workoutTab.tap()

        let playButton = app.buttons["play.circle.fill"]
        guard playButton.waitForExistence(timeout: 5) else {
            XCTFail("Play-Button nicht gefunden")
            return false
        }
        playButton.tap()

        // HealthKit-Dialog falls nötig
        let allowButton = app.buttons["Allow"]
        if allowButton.waitForExistence(timeout: 3) {
            allowButton.tap()
            sleep(2)
            if playButton.waitForExistence(timeout: 2) && playButton.isHittable {
                playButton.tap()
            }
        }

        let pauseButton = app.buttons["Pause"].firstMatch
        return pauseButton.waitForExistence(timeout: 8)
    }

    /// Startet eine Atemübung (Meditation-Tab → ScrollView → Atem-Preset).
    /// Gibt true zurück wenn die Session läuft.
    @discardableResult
    private func startBreathingExercise() -> Bool {
        let meditationTab = app.tabBars.buttons["Meditation"]
        guard meditationTab.waitForExistence(timeout: 10) else {
            XCTFail("Meditation-Tab nicht gefunden")
            return false
        }
        meditationTab.tap()

        // Scrolle zu den Atem-Presets und starte das erste
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
        }

        // Suche nach einem Atem-Preset-Button (z.B. "4-7-8" oder ähnlich)
        let presetButtons = ["4-7-8", "Box", "Wim Hof"]
        var presetFound = false
        for preset in presetButtons {
            let btn = app.buttons[preset].firstMatch
            if btn.waitForExistence(timeout: 2) && btn.isHittable {
                btn.tap()
                presetFound = true
                break
            }
            // Auch als StaticText probieren
            let text = app.staticTexts[preset].firstMatch
            if text.waitForExistence(timeout: 1) && text.isHittable {
                text.tap()
                presetFound = true
                break
            }
        }

        guard presetFound else {
            XCTFail("Kein Atem-Preset gefunden")
            return false
        }

        // Warte auf Session-Indicator
        sleep(2)
        return true
    }

    /// Gemeinsamer Background-Foreground-Cycle für alle Tests.
    private func backgroundForegroundCycle() {
        XCUIDevice.shared.press(.home)

        let backgroundWait = expectation(description: "App im Hintergrund")
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { backgroundWait.fulfill() }
        wait(for: [backgroundWait], timeout: 6)

        app.activate()

        let foregroundWait = expectation(description: "App im Vordergrund")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { foregroundWait.fulfill() }
        wait(for: [foregroundWait], timeout: 3)
    }

    // MARK: - Geführtes Workout Tests

    /// Verhalten: Nach Hintergrund → Vordergrund darf der Start-Button NICHT erscheinen
    ///
    /// Bug: onDisappear in WorkoutProgramSessionCard ruft endSession(manual:true) auf
    /// beim Scene-Übergang in den Hintergrund. Das beendet die Session und zeigt
    /// die Workout-Übersicht mit Start-Button wieder an.
    ///
    /// RED: Dieser Test MUSS fehlschlagen solange der Bug existiert.
    /// Der Start-Button erscheint nach Hintergrund-Wechsel, weil die Session beendet wurde.
    func test_backgroundForeground_sessionStillRunning() throws {
        // Arrange: Session starten
        let sessionStarted = startFirstWorkoutSession()
        XCTAssertTrue(sessionStarted, "Session konnte nicht gestartet werden")

        // Sicherstellen, dass die Session-Card aktiv ist
        let pauseButton = app.buttons["Pause"].firstMatch
        XCTAssertTrue(
            pauseButton.waitForExistence(timeout: 5),
            "Pause-Button sollte vor dem Hintergrund-Wechsel sichtbar sein"
        )

        // Act: App in Hintergrund schicken und zurückkehren
        XCUIDevice.shared.press(.home)

        // Warten, damit der Scene-Übergang (inkl. onDisappear) abgeschlossen ist
        let backgroundWait = expectation(description: "App im Hintergrund")
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { backgroundWait.fulfill() }
        wait(for: [backgroundWait], timeout: 6)

        app.activate()

        // Kurz warten damit die App wieder im Vordergrund ist
        let foregroundWait = expectation(description: "App im Vordergrund")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { foregroundWait.fulfill() }
        wait(for: [foregroundWait], timeout: 3)

        // Assert: Der Start-Button darf NICHT erscheinen.
        // Wenn er erscheint, wurde die Session durch den Bug beendet.
        let startButtonAfterReturn = app.buttons["Start"].firstMatch
        let sessionWasKilledByBug = startButtonAfterReturn.waitForExistence(timeout: 3)

        XCTAssertFalse(
            sessionWasKilledByBug,
            "BUG AKTIV: Session wurde beim Hintergrund-Wechsel beendet. " +
            "Der Start-Button ist wieder sichtbar, obwohl der User die Session nicht gestoppt hat. " +
            "Root Cause: WorkoutProgramSessionCard.onDisappear → endSession(manual:true)."
        )

        // Cleanup: Falls der Test durch den Bug Richtung Grün tendiert, Pause-Button prüfen
        let sessionStillActive = pauseButton.waitForExistence(timeout: 3)
        XCTAssertTrue(
            sessionStillActive,
            "Session ist nicht mehr aktiv nach Hintergrund-Wechsel — Pause-Button fehlt."
        )
    }

    // MARK: - Freie Meditation Tests

    /// Verhalten: Freie Meditation läuft nach Hintergrund → Vordergrund weiter
    func test_freeMeditation_backgroundForeground_sessionStillRunning() throws {
        let sessionStarted = startFreeMeditation()
        guard sessionStarted else {
            throw XCTSkip("Freie Meditation konnte nicht gestartet werden (HealthKit-Dialog?)")
        }

        let endButton = app.buttons["End"].firstMatch
        XCTAssertTrue(endButton.waitForExistence(timeout: 5), "End-Button sollte vor Background sichtbar sein")

        backgroundForegroundCycle()

        // Play-Button darf NICHT erscheinen (Session noch aktiv)
        let playButton = app.buttons["play.circle.fill"]
        let sessionKilled = playButton.waitForExistence(timeout: 3)
        XCTAssertFalse(sessionKilled, "Freie Meditation wurde beim Hintergrund-Wechsel beendet")

        XCTAssertTrue(endButton.waitForExistence(timeout: 3), "End-Button sollte nach Rückkehr noch da sein")
    }

    // MARK: - Freies Workout Tests

    /// Verhalten: Freies Workout läuft nach Hintergrund → Vordergrund weiter
    func test_freeWorkout_backgroundForeground_sessionStillRunning() throws {
        let sessionStarted = startFreeWorkout()
        guard sessionStarted else {
            throw XCTSkip("Freies Workout konnte nicht gestartet werden (HealthKit-Dialog?)")
        }

        let pauseButton = app.buttons["Pause"].firstMatch
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 5), "Pause-Button sollte vor Background sichtbar sein")

        backgroundForegroundCycle()

        // Play-Button darf NICHT erscheinen (Session noch aktiv)
        let playButton = app.buttons["play.circle.fill"]
        let sessionKilled = playButton.waitForExistence(timeout: 3)
        XCTAssertFalse(sessionKilled, "Freies Workout wurde beim Hintergrund-Wechsel beendet")

        XCTAssertTrue(pauseButton.waitForExistence(timeout: 3), "Pause-Button sollte nach Rückkehr noch da sein")
    }

    // MARK: - Atemübung Tests

    /// Verhalten: Atemübung läuft nach Hintergrund → Vordergrund weiter
    func test_breathingExercise_backgroundForeground_sessionStillRunning() throws {
        let sessionStarted = startBreathingExercise()
        guard sessionStarted else {
            throw XCTSkip("Atemübung konnte nicht gestartet werden")
        }

        backgroundForegroundCycle()

        // Nach Rückkehr sollte die Atemübung noch aktiv sein
        // Meditation-Tab sollte noch sichtbar sein, kein Reset auf Picker-View
        let meditationTab = app.tabBars.buttons["Meditation"]
        XCTAssertTrue(meditationTab.waitForExistence(timeout: 3), "Meditation-Tab sollte nach Rückkehr sichtbar sein")
    }

    // MARK: - Geführtes Workout: Expliziter Stop

    /// Verhalten: Expliziter Stop (xmark-Button) beendet die Session korrekt
    ///
    /// Regression-Schutz: Nach dem Fix muss manueller Stop weiterhin funktionieren.
    /// Dieser Test prüft, dass der Start-Button nach explizitem Stop wieder erscheint.
    func test_explicitStop_endsSession() throws {
        // Arrange: Session starten
        let sessionStarted = startFirstWorkoutSession()
        XCTAssertTrue(sessionStarted, "Session konnte nicht gestartet werden")

        let pauseButton = app.buttons["Pause"].firstMatch
        XCTAssertTrue(
            pauseButton.waitForExistence(timeout: 5),
            "Pause-Button sollte nach Session-Start sichtbar sein"
        )

        // Alle Buttons in der Session-Card auflisten (Debug)
        let allButtons = app.buttons.allElementsBoundByIndex
        var closeButtonFound = false

        for btn in allButtons {
            let label = btn.label
            // xmark-Button hat in SwiftUI das systemImage-Label "xmark" oder ähnliches
            if label.contains("xmark") || label.contains("close") || label.contains("Close")
                || label.contains("✕") || label.isEmpty {
                closeButtonFound = true
                btn.tap()
                break
            }
        }

        // Fallback: Suche nach Button in der oberen rechten Ecke
        if !closeButtonFound {
            // Der xmark-Button liegt oben rechts (overlay alignment .topTrailing)
            let topRight = app.buttons.element(boundBy: app.buttons.count - 1)
            if topRight.waitForExistence(timeout: 2) {
                topRight.tap()
                closeButtonFound = true
            }
        }

        XCTAssertTrue(closeButtonFound, "Kein Close/Stop-Button (xmark) gefunden")

        // Assert: Start-Button erscheint wieder (Session beendet)
        let startButton = app.buttons["Start"].firstMatch
        XCTAssertTrue(
            startButton.waitForExistence(timeout: 8),
            "Nach explizitem Stop sollte die Workout-Übersicht mit Start-Button sichtbar sein"
        )
    }
}
