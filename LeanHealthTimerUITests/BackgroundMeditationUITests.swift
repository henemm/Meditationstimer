import XCTest

/// Tests für Bug #7 — Session wird beim Hintergrund-Wechsel beendet
///
/// Root Cause: WorkoutProgramSessionCard.onDisappear ruft bedingungslos
/// endSession(manual: true) auf — auch beim Scene-Übergang in den Hintergrund.
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

    // MARK: - Tests

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
