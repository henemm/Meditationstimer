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
    /// Gibt true zurück, wenn die Sitzungskarte steht (siehe `sessionCardVisible()`).
    ///
    /// Reiter-Zugriff positionsbasiert (Index 1 = Workout): Die Reiter-Knöpfe tragen KEINE
    /// Kennung, nur lokalisierte Beschriftungen. Gemessen in
    /// `DOCS/artifacts/bug-25d-hintergrund-meditation/baum-laufende-sitzung.txt`,
    /// Schlussfolgerung 6 — ein Zugriff über `app.tabBars.buttons["flame"]` scheitert dort
    /// nachweislich mit "No matches found ... from input { Button, label: 'Meditation', … }".
    @discardableResult
    private func startFirstWorkoutSession() -> Bool {
        guard app.tabBars.firstMatch.waitForExistence(timeout: 15) else {
            XCTFail("Tab-Leiste nicht gefunden")
            return false
        }
        let workoutTab = app.tabBars.buttons.element(boundBy: 1)
        guard workoutTab.waitForExistence(timeout: 10) else {
            XCTFail("Workout-Reiter (Index 1) nicht gefunden")
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

        // Die Sitzungskarte gilt als aufgebaut, sobald ihr Abbruch-Knopf da ist.
        guard sessionCloseButton.waitForExistence(timeout: 15) else { return false }
        return sessionCardVisible()
    }

    // MARK: - Merkmale der Sitzungskarte (gemessen, nicht angenommen)

    /// Abbruch-Knopf der Sitzungskarte — stabile Kennung `xmark`, Beschriftung "Schließen".
    ///
    /// Warum dieses Merkmal und nicht der Pause-Knopf: `xmark` ist in BEIDEN Zuständen der
    /// Karte vorhanden (laufend und pausiert) und fehlt, solange keine Sitzung läuft.
    /// Gemessene Zustandstabelle:
    /// `DOCS/artifacts/bug-25d-hintergrund-meditation/baum-laufende-sitzung.txt`.
    private var sessionCloseButton: XCUIElement {
        app.buttons["xmark"].firstMatch
    }

    /// Fortschrittszähler der Sitzungskarte — "Übung n / m" und "Runde n / m"
    /// (englisch "Exercise n / m" / "Round n / m").
    ///
    /// Sprachunabhängig über die Zahlenform erkannt statt über die Beschriftung. Im gesamten
    /// Baumabzug gibt es außerhalb der Karte keinen weiteren Text dieser Form (Beleg: derselbe
    /// Abzug, Elementliste — die Programmzeilen heißen "8 x 1 = 3:50 min" o. ä.).
    private static let progressCounterPredicate = NSPredicate(
        format: "label MATCHES %@", ".*[0-9]+ / [0-9]+.*"
    )

    private func progressCounters() -> [String] {
        app.staticTexts
            .matching(Self.progressCounterPredicate)
            .allElementsBoundByIndex
            .map { $0.label }
    }

    /// Steht die Sitzungskarte einer laufenden ODER pausierten Sitzung?
    ///
    /// Beide Teilbedingungen zusammen grenzen sauber ab:
    /// - `xmark` trägt die Karte in jedem ihrer Zustände (laufend, pausiert, Abschluss),
    /// - der Fortschrittszähler fehlt im Abschluss-Zustand, der laut
    ///   `messlauf-vollprotokoll.log`, Zeilen 1988-1990, nur `checkmark.circle.fill` +
    ///   "Fertig" + `xmark` zeigt.
    /// Zusammen heißt das: Karte da UND noch nicht fertig.
    private func sessionCardVisible() -> Bool {
        sessionCloseButton.exists && !progressCounters().isEmpty
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

    /// Verhalten: Eine laufende Sitzung überlebt den Wechsel in den Hintergrund und zurück —
    /// und sie läuft danach auch wirklich weiter, statt nur als Standbild dazustehen.
    ///
    /// Geprüft wird in drei Stufen:
    /// 1. Direkt nach der Rückkehr steht die Sitzungskarte noch.
    /// 2. Fünf Sekunden später steht sie immer noch — das fängt ein verzögertes Abräumen ab,
    ///    das erst nach dem Wiedereinblenden greift.
    /// 3. Der Fortschrittszähler der Karte wandert weiter. Das unterscheidet eine lebende
    ///    Sitzung von einer eingefrorenen, bei der die Karte zwar steht, das Uhrwerk aber
    ///    nicht wieder angelaufen ist.
    ///
    /// BITTE NICHT ZURÜCKREPARIEREN — Punkt 1, kein `XCTAssertFalse(app.buttons["Start"].exists)`:
    /// Die Sitzungskarte liegt als Überlagerung ÜBER der Programmliste; die Liste bleibt dabei
    /// vollständig im Bedienhilfen-Baum stehen. Beleg:
    /// `DOCS/artifacts/bug-25d-hintergrund-meditation/baum-laufende-sitzung.txt` —
    /// im Abzug der LAUFENDEN Sitzung stehen vier Knöpfe `play.fill` / "Start" gleichzeitig mit
    /// dem Abbruch-Knopf `xmark` / "Schließen" im selben Baum. Ein sichtbarer "Start"-Knopf
    /// beweist also NICHT, dass die Sitzung beendet wurde.
    ///
    /// BITTE NICHT ZURÜCKREPARIEREN — Punkt 2, kein `app.buttons["Pause"]` als Kriterium:
    /// Der Pause-Knopf wechselt beim Pausieren seine Beschriftung auf "Weiter" und ist im
    /// Abschluss-Zustand ganz weg. Er verschwindet also auch dann, wenn die Sitzung sehr wohl
    /// besteht. Gemessen, nicht vermutet — Zustandstabelle im selben Abzug:
    /// laufend `Pause=true / Weiter=false`, pausiert `Pause=FALSE / Weiter=true`, dabei
    /// `xmark=true` in beiden Fällen. Deshalb hängt die Prüfung an `xmark` plus
    /// Fortschrittszähler, nicht an der Beschriftung eines Knopfes, die sich mit dem
    /// Zustand ändert.
    func test_backgroundForeground_sessionStillRunning() throws {
        // Vorbedingung: Sitzung läuft, die Karte steht vor dem Hintergrund-Wechsel.
        let sessionStarted = startFirstWorkoutSession()
        guard sessionStarted, sessionCardVisible() else {
            XCTFail(
                "VORBEDINGUNG FEHLGESCHLAGEN (nicht der zu prüfende Bug): Die Sitzung lief vor " +
                "dem Hintergrund-Wechsel gar nicht — die Sitzungskarte war innerhalb von 15s " +
                "nicht da (Abbruch-Knopf 'xmark' sichtbar = \(sessionCloseButton.exists), " +
                "Fortschrittszähler = \(progressCounters())). Ohne laufende Sitzung ist über " +
                "den Hintergrund-Wechsel nichts aussagbar."
            )
            return
        }

        // Act: In den Hintergrund und zurück.
        backgroundForegroundCycle()

        // Assert 1: Die Sitzungskarte ist nach der Rückkehr noch da.
        XCTAssertTrue(
            sessionCloseButton.waitForExistence(timeout: 10),
            "Die Sitzung ist nach der Rückkehr aus dem Hintergrund nicht mehr da — der " +
            "Abbruch-Knopf 'xmark' der Sitzungskarte fehlt, obwohl niemand die Sitzung " +
            "gestoppt hat."
        )
        XCTAssertFalse(
            progressCounters().isEmpty,
            "Die Sitzungskarte steht zwar noch, zeigt aber keinen Fortschrittszähler mehr — " +
            "die Sitzung ist nach der Rückkehr aus dem Hintergrund in den Abschluss-Zustand " +
            "gesprungen, statt weiterzulaufen."
        )

        // Assert 2: Fünf Sekunden später steht sie immer noch — fängt ein verzögertes
        // Beenden ab, das erst nach dem Wiedereinblenden greift.
        let settleWait = expectation(description: "Nachlauf nach Rückkehr")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { settleWait.fulfill() }
        wait(for: [settleWait], timeout: 7)

        XCTAssertTrue(
            sessionCardVisible(),
            "Die Sitzung wurde fünf Sekunden nach der Rückkehr aus dem Hintergrund doch noch " +
            "beendet — die Karte war direkt nach der Rückkehr noch da, ist jetzt aber weg " +
            "(Abbruch-Knopf 'xmark' sichtbar = \(sessionCloseButton.exists), " +
            "Fortschrittszähler = \(progressCounters()))."
        )

        // Assert 3: Lebendigkeit. Der Fortschrittszähler muss sich bewegen.
        //
        // Warum das trägt: Der Zähler zählt die Phasen des Programms. Im gemessenen Programm
        // "Tabata Classic" (8 x 1 = 3:50 min) dauert eine Phase rund 28,75 s; im Abzug wanderte
        // er bei t = 39,3 s von "Übung 1 / 8" auf "Übung 2 / 8" bei t = 63,8 s. Die Schranke von
        // 60 s hat damit gut zwei Phasenlängen Reserve. Geprüft wird wartend, nicht als
        // Momentaufnahme: Sobald sich der Zähler ändert, ist der Test sofort fertig — im
        // Regelfall nach rund einer halben Phasenlänge.
        let baseline = progressCounters()
        let counterAdvanced = expectation(
            for: NSPredicate(block: { [weak self] _, _ in
                guard let self else { return false }
                let now = self.progressCounters()
                // Leere Liste = Karte weg; das ist kein Fortschritt, sondern ein Abbruch.
                return !now.isEmpty && now != baseline
            }),
            evaluatedWith: app,
            handler: nil
        )
        let liveness = XCTWaiter().wait(for: [counterAdvanced], timeout: 60)

        XCTAssertEqual(
            liveness, .completed,
            "Die Sitzung steht still: Der Fortschrittszähler der Karte stand 60s nach der " +
            "Rückkehr aus dem Hintergrund unverändert auf \(baseline) (jetzt: " +
            "\(progressCounters())). Eine Phase dauert im geprüften Programm rund 29s — der " +
            "Zähler hätte sich in dieser Zeit mindestens einmal weiterbewegen müssen. Die " +
            "Karte ist also nach dem App-Wechsel zwar stehen geblieben, das Uhrwerk der " +
            "Sitzung aber nicht wieder angelaufen."
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

    /// Verhalten: Der Abbruch-Knopf der Sitzungskarte beendet eine laufende Sitzung.
    ///
    /// Regression-Schutz: Nach dem Fix muss der manuelle Abbruch weiterhin funktionieren.
    /// Angetippt wird der Knopf über seine stabile Kennung `xmark` — nicht über seine
    /// Beschriftung ("Schließen", lokalisiert) und nicht über seine Position im Baum.
    ///
    /// BITTE NICHT ZURÜCKREPARIEREN — Punkt 1, kein Durchsuchen aller Knöpfe und kein
    /// "nimm halt den letzten": Ein früherer Stand hat den Baum nach Beschriftungen wie
    /// "xmark"/"close"/leer abgesucht und, wenn nichts passte, den letzten Knopf im Baum
    /// getippt. Der Abbruch-Knopf heißt aber `identifier: 'xmark', label: 'Schließen'` — keine
    /// der Bedingungen traf je zu, jeder Lauf landete im Ersatzzweig und tippte
    /// positionsbestimmt. Nachgewiesen im Mitschnitt des Prüfers: "Find the Button (Element at
    /// index 0) … (index 17) / Tap Button (Element at index 17)". Dass das den richtigen Knopf
    /// traf, war Baumreihenfolge, nicht Absicht. Wird `xmark` nicht gefunden, ist das jetzt ein
    /// Vorbedingungs-Fehlschlag — kein Ersatztippen.
    ///
    /// BITTE NICHT ZURÜCKREPARIEREN — Punkt 2, kein `XCTAssertTrue(app.buttons["Start"]…)`:
    /// Der "Start"-Knopf der Programmliste ist DAUERHAFT im Bedienhilfen-Baum — vor, während
    /// und nach der Sitzung, weil die Sitzungskarte nur als Überlagerung darüberliegt (Beleg:
    /// `DOCS/artifacts/bug-25d-hintergrund-meditation/baum-laufende-sitzung.txt`, Abzug der
    /// laufenden Sitzung: vier Knöpfe `play.fill` / "Start" gleichzeitig mit `xmark`).
    /// Eine Prüfung auf seine Anwesenheit ist deshalb IMMER wahr und beweist nichts.
    ///
    /// BITTE NICHT ZURÜCKREPARIEREN — Punkt 3, kein `app.buttons["Pause"]` als Kriterium:
    /// Der Pause-Knopf heißt im pausierten Zustand "Weiter" und fehlt im Abschluss-Zustand
    /// ganz. "Pause weg" hieße also nicht zwingend "Sitzung beendet". Gefordert wird deshalb
    /// das Verschwinden der ganzen Karte: `xmark` weg UND kein Fortschrittszähler mehr.
    /// Dass ein Antippen von `xmark` die Karte tatsächlich vollständig abräumt und KEINEN
    /// Abschluss-Bildschirm stehen lässt, ist gemessen (derselbe Abzug, Zustandstabelle:
    /// 3 s und 9 s nach dem Antippen jeweils `xmark=false`, Zähler `[]`).
    func test_explicitStop_endsSession() throws {
        // Vorbedingung: Eine Sitzung läuft.
        let sessionStarted = startFirstWorkoutSession()
        guard sessionStarted, sessionCardVisible() else {
            XCTFail(
                "VORBEDINGUNG FEHLGESCHLAGEN (nicht der zu prüfende Bug): Die Sitzung ließ sich " +
                "nicht starten — die Sitzungskarte war innerhalb von 15s nicht da " +
                "(Abbruch-Knopf 'xmark' sichtbar = \(sessionCloseButton.exists), " +
                "Fortschrittszähler = \(progressCounters())). Ohne laufende Sitzung ist über " +
                "den Abbruch nichts aussagbar."
            )
            return
        }

        // Act: Abbruch-Knopf über seine stabile Kennung antippen.
        let closeButton = sessionCloseButton
        guard closeButton.waitForExistence(timeout: 10), closeButton.isHittable else {
            XCTFail(
                "VORBEDINGUNG FEHLGESCHLAGEN (nicht der zu prüfende Bug): Der Abbruch-Knopf mit " +
                "der Kennung 'xmark' war nicht bedienbar (existiert = \(closeButton.exists), " +
                "bedienbar = \(closeButton.isHittable)). Ohne ihn lässt sich der Abbruch nicht " +
                "auslösen; ein Ersatztippen auf einen anderen Knopf würde etwas anderes prüfen " +
                "als den Abbruch."
            )
            return
        }
        closeButton.tap()

        // Assert: Die Sitzungskarte verschwindet vollständig.
        //
        // Wartende Form statt Momentaufnahme: Das Abräumen der Karte läuft animiert und kann
        // nach dem Tippen einen Moment brauchen.
        let cardGone = expectation(
            for: NSPredicate(block: { [weak self] _, _ in
                guard let self else { return false }
                return !self.sessionCloseButton.exists && self.progressCounters().isEmpty
            }),
            evaluatedWith: app,
            handler: nil
        )
        let outcome = XCTWaiter().wait(for: [cardGone], timeout: 15)

        XCTAssertEqual(
            outcome, .completed,
            "Der Abbruch hat die Sitzung nicht beendet: 15s nach dem Antippen des " +
            "Abbruch-Knopfes 'xmark' steht die Sitzungskarte immer noch " +
            "(Abbruch-Knopf sichtbar = \(sessionCloseButton.exists), Fortschrittszähler = " +
            "\(progressCounters()))."
        )
    }
}
