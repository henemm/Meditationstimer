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

    // MARK: - Geführtes Workout: Hintergrund-Wechsel + natürlicher Abschluss (BUG-25d)

    /// Positionsbasierter Tab-Zugriff (siehe Bug #21, `LeanHealthTimerUITests.swift` Zeile 9-16 —
    /// dasselbe, dort bereits erprobte Muster, unverändert übernommen). Die Tab-Knöpfe selbst
    /// tragen KEINE Kennung, nur eine übersetzte Beschriftung ("Erfolge"/"Achievements"); die
    /// Kennungen (z.B. "trophy.fill") gehören den BILDERN innerhalb der Knöpfe und sind zudem
    /// zustandsabhängig (z.B. "flame" im unausgewählten, "flame.fill" im ausgewählten Zustand) —
    /// beides per Messlauf belegt, siehe
    /// docs/artifacts/bug-25d-hintergrund-meditation/. Ein früherer Diagnose-Befund in dieser Datei
    /// hatte die Kennung des Kindbilds fälschlich dem Knopf zugeschrieben; die daraufhin verwendete
    /// identifier-basierte Zugriffsvariante ist deshalb wieder entfernt. Sprach- UND
    /// zustandsunabhängig ist nur die Position.
    private func tab(_ index: Int) -> XCUIElement {
        let count = app.tabBars.buttons.count
        guard count == 4 else {
            XCTFail("Erwartet 4 Tabs (Meditation/Workout/Tracker/Erfolge), gefunden \(count) — Tab-Reihenfolge geändert?")
            return app.tabBars.buttons.firstMatch
        }
        return app.tabBars.buttons.element(boundBy: index)
    }

    /// Sucht ein Element über eine von mehreren möglichen Beschriftungen. Notwendig, weil der
    /// Simulator hier auf Deutsch läuft (belegt: `defaults read -g AppleLanguages` → `de-DE`) und
    /// mehrere hier benötigte Beschriftungen tatsächlich lokalisiert sind (siehe
    /// `Meditationstimer iOS/Localizable.xcstrings`: "Done"→"Fertig", "Skip"→"Überspringen") — im
    /// Unterschied zu "Start"/"Pause", die laut Diagnose der ersten Korrekturrunde fest codierte,
    /// NICHT lokalisierte `accessibilityLabel`s tragen und deshalb unverändert direkt über
    /// `app.buttons["Start"]` bzw. `app.buttons["Pause"]` angesprochen werden.
    private func element(anyOf labels: [String], in query: XCUIElementQuery) -> XCUIElement {
        query.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
    }

    /// Schließt das Effort-Score-Sheet zuverlässig, falls es sichtbar ist (iOS 18+, siehe
    /// `WorkoutProgramSessionCard.endSession` — nach natürlichem Abschluss gezeigt, BEVOR die
    /// Übersicht mit der Tab-Leiste wieder erreichbar wird). Das Wegtippen ist NICHT optional:
    /// Solange ein Blatt modal offen ist, bleibt die Tab-Leiste unerreichbar (belegt: zwei von drei
    /// Durchgängen der letzten Korrekturrunde scheiterten genau daran). "Skip" ist lokalisiert (DE
    /// "Überspringen"); "Save"/"Speichern" wird zusätzlich akzeptiert, falls stattdessen dieser
    /// Knopf sichtbar ist — beide schließen das Sheet gleichermaßen.
    ///
    /// Gibt `true` zurück, wenn kein Sheet (mehr) offen ist (entweder war nie eines da, oder es
    /// wurde erfolgreich geschlossen). Gibt `false` zurück, wenn ein Skip/Save-Knopf nach mehreren
    /// Tap-Versuchen weiterhin sichtbar ist — das Blatt ließ sich nicht schließen.
    private func closeEffortSheetIfPresent() -> Bool {
        let dismissButton = element(anyOf: ["Skip", "Überspringen", "Save", "Speichern"], in: app.buttons)
        guard dismissButton.waitForExistence(timeout: 20) else {
            return true // Kein Sheet erschienen — nichts zu tun.
        }

        for _ in 0..<3 {
            if dismissButton.exists {
                dismissButton.tap()
            }
            let tick = expectation(description: "Warte auf Schließen des Effort-Sheets")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { tick.fulfill() }
            wait(for: [tick], timeout: 2)
            if !dismissButton.exists {
                return true
            }
        }
        return !dismissButton.exists
    }

    /// Bringt die App in einen definierten Ausgangszustand, BEVOR der eigentliche Ablauf beginnt.
    /// Notwendig, weil das Test-Skript mit mehreren Wiederholungen auf DERSELBEN Simulator-Instanz
    /// läuft (`Scripts/run-uitests.sh`): Ein Durchgang, der mitten im Ablauf abbricht, hinterlässt
    /// die App in einem Zwischenzustand (offenes Effort-Sheet, offene Kalender-Detailansicht,
    /// laufende Sitzung) — belegt: ein Durchgang der letzten Korrekturrunde scheiterte dadurch
    /// bereits am Session-Start. Kein Neustart, keine Sprachvorgabe — nur Aufräumen im laufenden
    /// Prozess. Scheitert das Aufräumen selbst, wird das als eigene Vorbedingung gemeldet statt
    /// stillschweigend weiterzumachen.
    @discardableResult
    private func ensureCleanStartingState() -> Bool {
        // 1. Offene Kalender-Detailansicht schließen. Der Schließen-Knopf ist ein hartcodiertes
        //    Literal "Fertig" im App-Code (DayDetailSheet.swift), unabhängig von der
        //    Simulator-Sprache — siehe openDayDetailSheet() weiter unten.
        let dayDetailFertigButton = app.buttons["Fertig"].firstMatch
        if dayDetailFertigButton.waitForExistence(timeout: 2) {
            dayDetailFertigButton.tap()
        }

        // 2. Offenes Effort-Sheet aus einem vorherigen Durchgang schließen.
        guard closeEffortSheetIfPresent() else {
            XCTFail(
                "VORBEDINGUNG FEHLGESCHLAGEN (nicht der zu prüfende Bug): Aufräumen zu Testbeginn " +
                "erfolglos — ein Effort-Score-Sheet aus einem vorherigen Durchgang ließ sich nicht " +
                "schließen."
            )
            return false
        }

        // 3. Laufende Workout-Sitzung beenden, falls der Pause-Knopf noch sichtbar ist
        //    (accessibilityLabel "Pause" ist NICHT lokalisiert, siehe oben).
        if app.buttons["Pause"].firstMatch.waitForExistence(timeout: 2) {
            var closed = false
            for btn in app.buttons.allElementsBoundByIndex {
                let label = btn.label
                if label.contains("xmark") || label.contains("close") || label.contains("Close")
                    || label.contains("✕") || label.isEmpty {
                    btn.tap()
                    closed = true
                    break
                }
            }
            guard closed else {
                XCTFail(
                    "VORBEDINGUNG FEHLGESCHLAGEN (nicht der zu prüfende Bug): Aufräumen zu " +
                    "Testbeginn erfolglos — eine laufende Sitzung aus einem vorherigen Durchgang " +
                    "war noch aktiv (Pause-Button sichtbar), der Abbruch-Knopf (xmark) wurde nicht " +
                    "gefunden."
                )
                return false
            }
        }

        // 4. Erst wenn die Tab-Leiste wieder erreichbar ist, beginnt der eigentliche Ablauf.
        //    Timeout großzügig (45s): Laut Diagnose-Lauf
        //    (docs/artifacts/bug-25d-hintergrund-meditation/tabbar-hierarchy.txt) braucht die
        //    Tab-Leiste in dieser Umgebung rund 20s, um sich nach einem Zustandswechsel neu
        //    aufzubauen.
        guard app.tabBars.buttons.firstMatch.waitForExistence(timeout: 45) else {
            XCTFail(
                "VORBEDINGUNG FEHLGESCHLAGEN (nicht der zu prüfende Bug): Aufräumen zu Testbeginn " +
                "erfolglos — Tab-Leiste nicht innerhalb von 45s erreichbar."
            )
            return false
        }
        return true
    }

    /// Erkennt den natürlichen Abschluss der Sitzung (Checkmark-Bildschirm mit "Done"/"Fertig").
    /// Primäres Signal: der AX-Identifier des Checkmark-Symbols (`checkmark.circle.fill`), nach
    /// demselben Muster, das für die Tab-Icons per Diagnose-Lauf belegt ist (auto-generierter
    /// Identifier aus dem `systemImage`-Namen, siehe
    /// docs/artifacts/bug-25d-hintergrund-meditation/tabbar-hierarchy.txt). Für DIESES konkrete
    /// Element liegt kein eigener Diagnose-Beleg vor — der lange, ~5-minütige Testlauf durfte dafür
    /// nicht extra gestartet werden (Vorgabe: den langen Test nicht selbst ausführen). Deshalb NICHT
    /// als alleiniges Kriterium verwendet: zusätzlich wird der Text in beiden im Projekt vorhandenen
    /// Sprachen als Rückfalloption geprüft ("Done"/"Fertig").
    private func waitForNaturalCompletionCheckmark(timeout: TimeInterval) -> Bool {
        let checkmarkImage = app.images["checkmark.circle.fill"]
        let doneText = element(anyOf: ["Done", "Fertig"], in: app.staticTexts)

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if checkmarkImage.exists || doneText.exists {
                return true
            }
            let tick = expectation(description: "Warte auf Abschluss-Checkmark")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { tick.fulfill() }
            wait(for: [tick], timeout: 2)
        }
        return checkmarkImage.exists || doneText.exists
    }

    /// Sucht die Tages-Zelle mit der gegebenen Tagesnummer im Kalender (Erfolge-Tab) und tippt sie
    /// an. Da derselbe Tages-Text (z.B. "22") in mehreren geladenen Monaten vorkommen kann,
    /// verifiziert diese Methode über den Navigationsleisten-Titel des sich öffnenden
    /// DayDetailSheet ("dd.MM.yyyy"), dass tatsächlich der heutige Tag getroffen wurde. Trifft ein
    /// Tap eine falsche Zelle (anderer Monat, gleiche Tagesnummer) oder eine Zelle ohne Aktivität
    /// (nicht antippbar, siehe CalendarView.dayView: onTapGesture nur bei hasActivity), wird erneut
    /// probiert, bis das Sheet mit dem erwarteten Titel erscheint oder das Zeitlimit erreicht ist.
    private func openDayDetailSheet(dayLabel: String, expectedNavigationTitle: String) -> Bool {
        let candidates = app.staticTexts.matching(NSPredicate(format: "label == %@", dayLabel))
        let deadline = Date().addingTimeInterval(40)

        while Date() < deadline {
            var triedAny = false
            let count = candidates.count
            if count > 0 {
                for index in 0..<count {
                    let candidate = candidates.element(boundBy: index)
                    guard candidate.exists, candidate.isHittable else { continue }
                    triedAny = true
                    candidate.tap()

                    if app.navigationBars[expectedNavigationTitle].waitForExistence(timeout: 3) {
                        return true
                    }

                    // Falsche Zelle getroffen oder Tap ohne Wirkung — ggf. offenes Sheet schließen
                    // und mit der nächsten Kandidatin bzw. dem nächsten Versuch weitermachen.
                    let fertigButton = app.buttons["Fertig"].firstMatch
                    if fertigButton.waitForExistence(timeout: 1) {
                        fertigButton.tap()
                    }
                }
            }

            if !triedAny {
                // Kalender lädt HealthKit-Daten noch asynchron und scrollt danach automatisch zum
                // aktuellen Monat — kurz erneut probieren statt blind zu warten.
                let retryWait = expectation(description: "Kalender lädt/scrollt")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { retryWait.fulfill() }
                wait(for: [retryWait], timeout: 2)
            }
        }
        return false
    }

    /// Verhalten: Ein Hintergrund-Wechsel mitten im geführten Workout darf die Sitzung nicht
    /// vorzeitig beenden. Läuft "Tabata Classic" danach ungestört bis zum natürlichen Abschluss
    /// durch, muss der geschriebene HealthKit-Eintrag die VOLLE Programmdauer tragen (≈ 3:50 Min),
    /// nicht nur die ~30s bis zum Hintergrund-Wechsel.
    ///
    /// Bug: WorkoutProgramSessionCard.onDisappear ruft endSession(manual:true) beim
    /// Hintergrund-Wechsel auf (siehe test_backgroundForeground_sessionStillRunning oben). Der
    /// dabei geschriebene Eintrag trägt nur die bis dahin verstrichene, kurze Dauer (≈30s) und
    /// wird von der 2-Minuten-Schwelle in DayDetailSheet.fetchSessions() ausgefiltert — der
    /// erwartete lange Eintrag bliebe für heute unsichtbar
    /// (siehe docs/specs/bugfix/BUG-25d-hintergrund-workout.md, Test Plan / AC-2 / AC-4).
    ///
    /// Hinweis: Es gibt keinen HealthKit-Reset-Mechanismus im Simulator (siehe Spec). Statt einer
    /// exakten Eintrags-Anzahl wird deshalb die GRÖSSTE an diesem Tag sichtbare Dauer geprüft —
    /// das ist robust gegenüber bereits vorhandenen Alt-Einträgen aus früheren Testläufen und
    /// misst trotzdem eindeutig, ob die volle Programmdauer geschrieben wurde.
    ///
    /// RED: Dieser Test MUSS fehlschlagen, solange der Bug existiert — es wird kein Eintrag mit
    /// mindestens 3:30 Min Dauer gefunden (weder eine antippbare Tages-Zelle mit ausreichender
    /// Aktivität, noch ein passender Sessions-Eintrag im Detail-Sheet).
    func test_backgroundDuringSession_thenNaturalCompletion_writesFullDurationEntry() throws {
        // Aufräumen zu Testbeginn: Das Skript wiederholt diesen Test bis zu 3x auf DERSELBEN
        // Simulator-Instanz. Ein vorheriger, mittendrin abgebrochener Durchgang kann ein offenes
        // Blatt oder eine laufende Sitzung hinterlassen haben — belegt: genau das ließ einen
        // Durchgang der letzten Korrekturrunde bereits am Session-Start scheitern. Kein Neustart,
        // keine Sprachvorgabe — nur Aufräumen im laufenden Prozess.
        guard ensureCleanStartingState() else {
            // ensureCleanStartingState() hat bereits einen präzisen XCTFail mit
            // "VORBEDINGUNG FEHLGESCHLAGEN"-Präfix ausgegeben.
            return
        }

        // Arrange: Kürzestes Programm "Tabata Classic" starten (erstes Programm in der Liste,
        // Gesamtdauer 8×20s Arbeit + 7×10s Pause ≈ 3:50 Min). Identischer Anlauf wie
        // test_backgroundForeground_sessionStillRunning oben — derselbe Helper, kein eigener
        // Neustart mit erzwungener Sprache: Der Neustart war die eigentliche Fehlerursache (siehe
        // docs/artifacts/bug-25d-hintergrund-meditation/tabbar-hierarchy.txt und
        // docs/artifacts/bug-25d-hintergrund-meditation/test-red-output.txt) und wird hier bewusst
        // nicht wiederholt.
        let sessionStarted = startFirstWorkoutSession()
        XCTAssertTrue(sessionStarted, "Tabata-Classic-Session konnte nicht gestartet werden")

        let pauseButton = app.buttons["Pause"].firstMatch
        XCTAssertTrue(
            pauseButton.waitForExistence(timeout: 5),
            "Pause-Button sollte nach Session-Start sichtbar sein"
        )

        // Act 1: ca. 30 Sekunden laufen lassen, dann Hintergrund/Vordergrund-Zyklus
        let runningWait = expectation(description: "Session läuft ~30s vor dem Hintergrund-Wechsel")
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { runningWait.fulfill() }
        wait(for: [runningWait], timeout: 35)

        backgroundForegroundCycle()

        // Vorbedingung für den restlichen Ablauf: Session muss nach der Rückkehr weiterhin laufen.
        // Der eigentliche Beweis für AC-1 liefert bereits test_backgroundForeground_sessionStillRunning
        // separat — hier geht es nur darum, dass der Testlauf überhaupt fortgesetzt werden kann.
        guard pauseButton.waitForExistence(timeout: 5) else {
            XCTFail(
                "Session wurde beim Hintergrund-Wechsel bereits beendet (Pause-Button fehlt nach " +
                "Rückkehr) — der natürliche Abschluss kann dadurch nicht mehr gemessen werden."
            )
            return
        }

        // Act 2: Session ungestört bis zum natürlichen Abschluss durchlaufen lassen.
        // Tabata Classic dauert insgesamt ≈3:50 Min (230s); nach ~30s Vorlauf und dem
        // Hintergrund-Zyklus (~10s) bleiben ≈190s. 300s Timeout statt der ursprünglichen 240s, um
        // ausreichend Reserve für Sound-Wiedergabe/HealthKit-Schreiben am Ende zu haben (siehe
        // BUG-25d-Korrekturrunde 5: 240s ließen im belegten Lauf nur ~40s Puffer).
        let naturalCompletion = waitForNaturalCompletionCheckmark(timeout: 300)
        if !naturalCompletion {
            // Zustand VOR dem Fehlschlag abfragen, um zwischen "Bug aktiv" (vorzeitig beendet) und
            // "nur zu knapper Zeitrahmen" (Sitzung lief noch) unterscheiden zu können.
            let startButtonReappeared = app.buttons["Start"].firstMatch.exists
            let sessionStillRunning = pauseButton.exists

            if startButtonReappeared {
                XCTFail(
                    "BUG AKTIV vermutet: Die Sitzung wurde vorzeitig beendet — der Start-Button der " +
                    "Workout-Übersicht ist bereits wieder sichtbar, obwohl der natürliche Abschluss " +
                    "(Checkmark) nie erreicht wurde. Das entspricht dem BUG-25d-Symptom: die Sitzung " +
                    "endet beim/nach dem Hintergrund-Wechsel statt regulär durchzulaufen."
                )
            } else if sessionStillRunning {
                XCTFail(
                    "VORBEDINGUNG FEHLGESCHLAGEN (nicht der zu prüfende Bug): Die Sitzung lief nach " +
                    "300s immer noch (Pause-Button weiterhin sichtbar) — der natürliche Abschluss " +
                    "wurde nicht erreicht. Zeitrahmen zu knapp bemessen oder Workout hängt fest, " +
                    "keine Aussage über BUG-25d."
                )
            } else {
                XCTFail(
                    "VORBEDINGUNG FEHLGESCHLAGEN (nicht der zu prüfende Bug): Nach 300s ist weder " +
                    "das Abschluss-Checkmark noch der Start- oder der Pause-Button sichtbar — " +
                    "unklarer Zwischenzustand (z.B. Phasenübergang, Sound-Wiedergabe), keine Aussage " +
                    "über BUG-25d."
                )
            }
            return
        }

        // Effort-Score-Sheet (iOS 18+) schließen, falls es erscheint, um zur Übersicht
        // zurückzukehren. Der HealthKit-Eintrag ist zu diesem Zeitpunkt bereits geschrieben
        // (WorkoutProgramSessionCard.endSession loggt VOR dem Anzeigen des Effort-Sheets). Das
        // Schließen ist NICHT optional — solange das Sheet offen bleibt, ist die Tab-Leiste
        // unerreichbar (belegt: zwei von drei Durchgängen der letzten Korrekturrunde scheiterten
        // genau daran). Eigene, benannte Vorbedingung, falls das Schließen fehlschlägt.
        guard closeEffortSheetIfPresent() else {
            XCTFail(
                "VORBEDINGUNG FEHLGESCHLAGEN (nicht der zu prüfende Bug): Das Effort-Score-Sheet " +
                "ließ sich nach dem natürlichen Abschluss nicht schließen (Skip/Überspringen/Save/" +
                "Speichern-Knopf bleibt nach mehreren Tap-Versuchen sichtbar) — die Tab-Leiste " +
                "bleibt dadurch unerreichbar."
            )
            return
        }

        // Übersicht sollte wieder sichtbar sein (Start-Button der Programmliste)
        let startButton = app.buttons["Start"].firstMatch
        XCTAssertTrue(
            startButton.waitForExistence(timeout: 10),
            "Workout-Übersicht sollte nach Sitzungsende wieder sichtbar sein"
        )

        // Assert: Erfolge-Tab → heutiger Tag → Eintrag mit voller Dauer prüfen. Timeout großzügig
        // (45s): Laut Diagnose-Lauf (docs/artifacts/bug-25d-hintergrund-meditation/) braucht die
        // Tab-Leiste in dieser Umgebung rund 20s, um sich nach einem Zustandswechsel (hier: Ende
        // der ausgeblendeten Session-Card) neu aufzubauen. Das Sheet ist an dieser Stelle laut
        // obigem Guard bereits zuverlässig geschlossen — ein Fehlschlag hier ist also ein reines
        // Timing-Problem der Tab-Leiste, kein verstecktes Sheet mehr.
        guard app.tabBars.buttons.firstMatch.waitForExistence(timeout: 45) else {
            XCTFail(
                "VORBEDINGUNG FEHLGESCHLAGEN (nicht der zu prüfende Bug): Tab-Leiste wurde nach " +
                "Sitzungsende nicht innerhalb von 45s im Accessibility-Baum gefunden."
            )
            return
        }
        let erfolgeTab = tab(3)
        erfolgeTab.tap()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"
        let expectedTitle = dateFormatter.string(from: Date())
        let dayLabel = "\(Calendar.current.component(.day, from: Date()))"

        let sheetOpened = openDayDetailSheet(dayLabel: dayLabel, expectedNavigationTitle: expectedTitle)
        guard sheetOpened else {
            XCTFail(
                "BUG AKTIV vermutet: Der heutige Tag im Kalender ist nicht antippbar (kein Eintrag " +
                "mit ausreichender Aktivität, siehe CalendarView.dayView hasActivity) oder das " +
                "Detail-Sheet öffnete nicht. Erwartet wäre ein Eintrag mit ≥3:30 Min — bei aktivem " +
                "Bug bleibt nur eine ~30s-Sitzung übrig, die unter der 2-Minuten-Schwelle liegt und " +
                "deshalb gar nicht sichtbar wird."
            )
            return
        }

        // Detail-Sheet zeigt Dauern im festen (nicht lokalisierten) Format "<Zahl> Min", sowohl in
        // der Zusammenfassung als auch pro Einzel-Session (siehe DayDetailSheet/SessionRow). Wir
        // werten die GRÖSSTE gefundene Zahl aus: Bug-Fall ≈0-1 Min (verkürzte ~30s-Sitzung),
        // Fix-Fall ≥4 Min (volle ≈3:50-Min-Sitzung — "≥3:30 Min" gerundet auf ganze Minuten ist
        // immer ≥4, siehe AC-4).
        let durationValues = app.staticTexts.allElementsBoundByIndex.compactMap { staticText -> Int? in
            let label = staticText.label
            guard label.hasSuffix(" Min") else { return nil }
            return Int(label.dropLast(4))
        }
        let maxDurationMinutes = durationValues.max() ?? 0

        XCTAssertGreaterThanOrEqual(
            maxDurationMinutes, 4,
            "BUG AKTIV: Größter am heutigen Tag gefundener Eintrag hat nur \(maxDurationMinutes) " +
            "Min (alle gefundenen Werte: \(durationValues)). Erwartet: mindestens 4 Min (≙ ≥3:30 " +
            "Min gerundet), weil die Sitzung trotz Hintergrund-Wechsel bis zum natürlichen " +
            "Abschluss (≈3:50 Min) hätte weiterlaufen müssen, statt beim Hintergrund-Wechsel " +
            "abgebrochen zu werden."
        )
    }
}
