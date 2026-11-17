//
//  WorkoutHintUITests.swift
//  LeanHealthTimerUITests
//
//  TDD RED fuer #48: Uebungskatalog und Hinweis je Uebungsschritt.
//  Aufruf: ./Scripts/run-uitests.sh WorkoutHintUITests/<methode>
//
//  Testdaten: Vorgabe "Core Circuit" (erster Schritt "Planke"). UserDefaults bleiben zwischen
//  Laeufen erhalten; Tests nehmen ihre Aenderungen im Teardown ueber die Oberflaeche zurueck.
//

import XCTest

final class WorkoutHintUITests: XCTestCase {
    var app: XCUIApplication!
    private let presetName = "Core Circuit"
    private let hintText = "12 Wiederholungen, langsam"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Helfer

    private func launch(language: String = "de", locale: String = "de_DE") {
        app.launchArguments = ["enable-testing", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        app.launch()
        dismissSystemAlertsIfAny()
    }

    /// Beliebiges Element per Kennung (unabhaengig vom Elementtyp).
    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func dismissSystemAlertsIfAny() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let hosts: [XCUIApplication] = [
            app!,
            XCUIApplication(bundleIdentifier: "com.apple.HealthPrivacyService"),
            springboard,
        ]
        let labels = ["OK", "Nicht erlauben", "Don’t Allow", "Don't Allow"]
        for _ in 0..<6 {
            var handled = false
            for host in hosts {
                for label in labels {
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
        XCTAssertEqual(app.tabBars.buttons.count, 4, "Erwartet 4 Tabs")
        app.tabBars.buttons.element(boundBy: 1).tap()
    }

    private func openPresetEditor() {
        openWorkoutTab()
        let edit = element("workout.programRow.\(presetName).edit")
        XCTAssertTrue(edit.waitForExistence(timeout: 20), "Bearbeiten-Knopf von \(presetName) fehlt")
        edit.tap()
        XCTAssertTrue(element("workout.setEditor.save").waitForExistence(timeout: 15), "Programm-Editor oeffnet nicht")
    }

    private func openPhaseEditor(row: Int) {
        let r = element("workout.setEditor.phaseRow.\(row)")
        XCTAssertTrue(r.waitForExistence(timeout: 10), "Schrittzeile \(row) fehlt")
        r.tap()
        XCTAssertTrue(element("workout.phaseEditor.save").waitForExistence(timeout: 10), "Schrittdialog oeffnet nicht")
    }

    private func hintField() -> XCUIElement {
        let f = element("workout.phaseEditor.hintField")
        XCTAssertTrue(f.waitForExistence(timeout: 10), "Hinweisfeld fehlt")
        return f
    }

    private func clearAndType(_ field: XCUIElement, _ text: String) {
        field.tap()
        if let current = field.value as? String, !current.isEmpty, current != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        if !text.isEmpty { field.typeText(text) }
    }

    private func saveStepAndProgram() {
        element("workout.phaseEditor.save").tap()
        let save = element("workout.setEditor.save")
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
    }

    private func setHintOnFirstStep(_ text: String) {
        openPresetEditor()
        openPhaseEditor(row: 0)
        clearAndType(hintField(), text)
        saveStepAndProgram()
    }

    private func startPreset() {
        let start = element("workout.programRow.\(presetName).start")
        XCTAssertTrue(start.waitForExistence(timeout: 20), "Start-Knopf von \(presetName) fehlt")
        start.tap()
        dismissSystemAlertsIfAny()
    }

    /// Wartet auf Countdown-Ende: Ring zeigt "Uebung"/"Exercise".
    private func waitForTrainingRing() -> XCUIElement {
        let ring = app.staticTexts.matching(NSPredicate(format: "label == 'Übung' OR label == 'Exercise'")).firstMatch
        XCTAssertTrue(ring.waitForExistence(timeout: 60), "Trainingsring mit Text 'Übung' erscheint nicht")
        return ring
    }

    private func endTrainingIfRunning() {
        for label in ["Beenden", "End", "Stop", "Stopp"] {
            let b = app.buttons[label]
            if b.exists && b.isHittable {
                b.tap()
                break
            }
        }
        dismissSystemAlertsIfAny()
    }

    /// Nimmt den Hinweis am ersten Schritt zurueck (Ausgangslage fuer Folgelaeufe).
    private func resetHintOnFirstStep() {
        endTrainingIfRunning()
        guard app.tabBars.firstMatch.waitForExistence(timeout: 45) else { return }
        openPresetEditor()
        openPhaseEditor(row: 0)
        clearAndType(hintField(), "")
        saveStepAndProgram()
    }

    /// Oeffnet die Uebungsauswahl und tippt die Option mit der Kennung `id`.
    private func pickExercise(_ id: String) {
        let picker = element("workout.phaseEditor.exercisePicker")
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "Uebungsauswahl fehlt im Schrittdialog")
        picker.tap()
        let option = element(id)
        XCTAssertTrue(option.waitForExistence(timeout: 10), "Option \(id) fehlt")
        option.tap()
    }

    /// Angezeigte Auswahl der geschlossenen Uebungsauswahl (Wert, sonst letzter Teil der Beschriftung).
    private func shownSelection() -> String {
        let picker = element("workout.phaseEditor.exercisePicker")
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "Uebungsauswahl fehlt im Schrittdialog")
        if let value = picker.value as? String, !value.isEmpty { return value }
        return picker.label.components(separatedBy: ", ").last ?? picker.label
    }

    /// Stellt Schritt 2 und 3 von "Core Circuit" ueber die Auswahl wieder her (Ausgangslage).
    private func restoreCoreCircuitSteps() {
        app.terminate()
        launch()
        openPresetEditor()
        openPhaseEditor(row: 1)
        pickExercise("workout.exercisePicker.option.builtin.seitliche-planke-links")
        element("workout.phaseEditor.save").tap()
        openPhaseEditor(row: 2)
        pickExercise("workout.exercisePicker.option.builtin.seitliche-planke-rechts")
        saveStepAndProgram()
    }

    // MARK: - Tests

    /// Verhalten (AC-18, AC-19): Given Hinweis "12 Wiederholungen, langsam" am ersten Schritt von
    /// "Core Circuit", When das Programm laeuft, Then steht der Text in `workout.training.hint`
    /// unter dem Ringtext "Uebung"; beim Anhalten bleibt er; in der Pause existiert er nicht;
    /// ein Schritt ohne Hinweis zeigt keine Zeile.
    func test_hintEnteredInEditor_visibleUnderRingInTraining() throws {
        launch()
        addTeardownBlock { [self] in resetHintOnFirstStep() }
        setHintOnFirstStep(hintText)

        startPreset()
        let ring = waitForTrainingRing()
        let hint = element("workout.training.hint")
        XCTAssertTrue(hint.waitForExistence(timeout: 20), "Hinweiszeile fehlt in der Arbeitsphase")
        XCTAssertTrue(hint.label.contains(hintText) || (hint.value as? String)?.contains(hintText) == true,
                      "Hinweistext stimmt nicht: \(hint.label)")
        XCTAssertGreaterThan(hint.frame.minY, ring.frame.minY, "Hinweis muss unter dem Ringtext stehen")

        let pause = app.buttons["Pause"]
        if pause.waitForExistence(timeout: 10) {
            pause.tap()
            XCTAssertTrue(element("workout.training.hint").waitForExistence(timeout: 5),
                          "Hinweis muss beim Anhalten sichtbar bleiben")
            let resume = app.buttons["Start"].exists ? app.buttons["Start"] : app.buttons["Fortsetzen"]
            if resume.waitForExistence(timeout: 5) { resume.tap() }
        }

        // Pause nach dem ersten Schritt: Hinweis verschwindet (nie in der Vorschau "Als nächstes").
        let gone = NSPredicate(format: "exists == false")
        let goneExp = XCTNSPredicateExpectation(predicate: gone, object: element("workout.training.hint"))
        XCTAssertEqual(XCTWaiter().wait(for: [goneExp], timeout: 180), .completed,
                       "In der Pause darf keine Hinweiszeile stehen")

        // AC-19: zweiter Schritt (ohne Hinweis) in der Arbeitsphase zeigt keine Zeile.
        _ = waitForTrainingRing()
        XCTAssertFalse(element("workout.training.hint").waitForExistence(timeout: 5),
                       "Schritt ohne Hinweis darf keine Hinweiszeile zeigen")
    }

    /// Erreichbarkeitsnachweis (Rueckfallregel Auswahl, erster RED-Test der Runde): Given der offene
    /// Schrittdialog, When die Uebungsauswahl geoeffnet und eine Option per Kennung angetippt wird,
    /// Then schliesst das Menue und die Auswahl zeigt die getippte Uebung. Scheitert das nach der
    /// Umsetzung, gilt die Rueckfallregel (Stil `.navigationLink`, vorher Entwurf an den PO).
    func test_exercisePickerOption_isTappableById() throws {
        launch()
        openPresetEditor()
        openPhaseEditor(row: 0)
        let picker = element("workout.phaseEditor.exercisePicker")
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "Uebungsauswahl fehlt im Schrittdialog")
        picker.tap()
        let option = element("workout.exercisePicker.option.builtin.liegestuetze")
        XCTAssertTrue(option.waitForExistence(timeout: 10), "Option per Kennung nicht auffindbar")
        XCTAssertTrue(option.isHittable, "Option per Kennung nicht antippbar")
        option.tap()
        XCTAssertFalse(element("workout.exercisePicker.option.builtin.liegestuetze").waitForExistence(timeout: 2),
                       "Menue schliesst nach dem Tippen nicht")
        XCTAssertEqual(shownSelection(), "Liegestütze", "Auswahl uebernimmt die getippte Option nicht")
        // Nichts speichern: der Neustart im naechsten Test verwirft den offenen Dialog.
    }

    /// Verhalten (AC-23, AC-19): Given am zweiten Schritt "Eigene Uebung…" mit "Mein Lauf" und am dritten
    /// Schritt "Planke" aus der Auswahl (beide vorher anders benannt), When gespeichert und die App neu
    /// gestartet wird, Then zeigt die Auswahl genau "Planke" bzw. "Eigene Uebung…" mit "Mein Lauf";
    /// im Training zeigt der Info-Knopf fuer "Planke" Wirkung und Anleitung, und der Schritt ohne
    /// Hinweis hat keine Hinweiszeile.
    func test_pickedExercise_persistsAfterRelaunch() throws {
        launch()
        addTeardownBlock { [self] in restoreCoreCircuitSteps() }
        openPresetEditor()
        openPhaseEditor(row: 1)
        pickExercise("workout.exercisePicker.own")
        let ownName = element("workout.phaseEditor.ownNameField")
        XCTAssertTrue(ownName.waitForExistence(timeout: 10), "Namensfeld fuer eigene Uebung fehlt")
        clearAndType(ownName, "Mein Lauf")
        element("workout.phaseEditor.save").tap()
        openPhaseEditor(row: 2)
        pickExercise("workout.exercisePicker.option.builtin.planke")
        saveStepAndProgram()

        app.terminate()
        launch()
        openPresetEditor()
        openPhaseEditor(row: 2)
        XCTAssertEqual(shownSelection(), "Planke", "Auswahl am dritten Schritt steht nach Neustart nicht auf Planke")
        XCTAssertFalse(element("workout.phaseEditor.ownNameField").exists, "Katalogwahl darf kein Namensfeld zeigen")
        element("workout.phaseEditor.save").tap()
        openPhaseEditor(row: 1)
        let ownNameAgain = element("workout.phaseEditor.ownNameField")
        XCTAssertTrue(ownNameAgain.waitForExistence(timeout: 10), "Eigene Uebung nach Neustart nicht erhalten")
        XCTAssertEqual(ownNameAgain.value as? String, "Mein Lauf")
        element("workout.phaseEditor.save").tap()
        element("workout.setEditor.save").tap()

        startPreset()
        _ = waitForTrainingRing()
        XCTAssertFalse(element("workout.training.hint").waitForExistence(timeout: 3),
                       "Schritt ohne Hinweis darf keine Hinweiszeile zeigen")
        let info = element("workout.training.infoButton")
        XCTAssertTrue(info.waitForExistence(timeout: 20), "Info-Knopf fehlt im Training")
        info.tap()
        XCTAssertTrue(element("exerciseDetail.effect").waitForExistence(timeout: 10), "Wirkungstext fehlt")
        XCTAssertTrue(element("exerciseDetail.instructions").waitForExistence(timeout: 10), "Anleitungstext fehlt")
        XCTAssertFalse(element("exerciseDetail.effect").label.isEmpty, "Wirkung leer")
    }

    /// Verhalten (AC-24): Given das Hinweisfeld, When 90 Zeichen bzw. ein Zeilenumbruch eingegeben
    /// werden, Then hoechstens 80 Zeichen und einzeilig; leer gespeichert -> leer, keine Zeile im Training.
    func test_hintField_limitsLengthAndLines() throws {
        launch()
        addTeardownBlock { [self] in resetHintOnFirstStep() }
        openPresetEditor()
        openPhaseEditor(row: 0)
        let field = hintField()
        clearAndType(field, String(repeating: "a", count: 90))
        XCTAssertLessThanOrEqual((field.value as? String)?.count ?? 999, 80, "Hinweis ueber 80 Zeichen")

        clearAndType(field, "")
        field.typeText("eins\nzwei")
        let v = (field.value as? String) ?? ""
        XCTAssertFalse(v.contains("\n"), "Hinweisfeld muss einzeilig bleiben")

        clearAndType(hintField(), "")
        saveStepAndProgram()
        openPhaseEditor(row: 0)
        let reopened = (hintField().value as? String) ?? ""
        XCTAssertTrue(reopened.isEmpty || reopened == hintField().placeholderValue,
                      "Leeres Feld muss leer bleiben: \(reopened)")
        element("workout.phaseEditor.save").tap()
        element("workout.setEditor.save").tap()

        startPreset()
        _ = waitForTrainingRing()
        XCTAssertFalse(element("workout.training.hint").waitForExistence(timeout: 5),
                       "Ohne Hinweis darf keine Hinweiszeile stehen")
    }

    /// Verhalten (AC-22): Given Deutsch und offener Schrittdialog, When die Uebungsauswahl geoeffnet
    /// wird, Then gibt es Katalognamen ("Planke") und "Eigene Uebung...", aber keine englischen
    /// Vorschlagsnamen wie "Plank" oder "Push-ups".
    func test_exercisePicker_showsOnlyCatalogNames_german() throws {
        launch()
        openPresetEditor()
        openPhaseEditor(row: 0)
        let picker = element("workout.phaseEditor.exercisePicker")
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "Uebungsauswahl fehlt im Schrittdialog")
        picker.tap()
        XCTAssertTrue(element("workout.exercisePicker.option.builtin.planke").waitForExistence(timeout: 10),
                      "Katalogeintrag 'Planke' fehlt")
        XCTAssertTrue(element("workout.exercisePicker.own").exists, "'Eigene Übung…' fehlt")
        let options = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'workout.exercisePicker.option.'"))
        XCTAssertEqual(options.count, 67, "Auswahl muss genau die 67 Katalogübungen zeigen")
        XCTAssertFalse(app.staticTexts["Plank"].exists, "Englischer Vorschlagsname 'Plank' in der Auswahl")
        XCTAssertFalse(app.staticTexts["Push-ups"].exists, "Englischer Vorschlagsname 'Push-ups' in der Auswahl")
        XCTAssertFalse(app.buttons["Plank"].exists)
        XCTAssertFalse(app.buttons["Push-ups"].exists)
    }

    /// Verhalten (AC-28): Given Vorgabe "Core Circuit" im Training, When der Info-Knopf getippt wird,
    /// Then zeigt das Blatt nicht leere Texte fuer Wirkung und Anleitung der Planke.
    func test_infoButton_forPresetPlanke_showsContent() throws {
        launch()
        openWorkoutTab()
        startPreset()
        _ = waitForTrainingRing()
        let info = element("workout.training.infoButton")
        XCTAssertTrue(info.waitForExistence(timeout: 20), "Info-Knopf fehlt im Training")
        info.tap()
        let effect = element("exerciseDetail.effect")
        let instructions = element("exerciseDetail.instructions")
        XCTAssertTrue(effect.waitForExistence(timeout: 10), "Wirkungstext fehlt")
        XCTAssertTrue(instructions.waitForExistence(timeout: 10), "Anleitungstext fehlt")
        XCTAssertFalse(effect.label.isEmpty, "Wirkung leer")
        XCTAssertFalse(instructions.label.isEmpty, "Anleitung leer")
    }

    /// Verhalten (AC-25, Deutsch): Given Deutsch, When der Schrittdialog erscheint, Then lauten
    /// Beschriftung und Platzhalter "Hinweis (optional)" / "z. B. 12 Wiederholungen, langsam",
    /// nicht in Grossbuchstaben.
    func test_hintField_localized_german() throws {
        launch(language: "de", locale: "de_DE")
        assertHintFieldTexts(label: "Hinweis (optional)", placeholder: "z. B. 12 Wiederholungen, langsam")
    }

    /// Verhalten (AC-25, Englisch): Given Englisch, When der Schrittdialog erscheint, Then lauten
    /// Beschriftung und Platzhalter "Hint (optional)" / "e.g. 12 reps, slow", nicht in Grossbuchstaben.
    func test_hintField_localized_english() throws {
        launch(language: "en", locale: "en_US")
        assertHintFieldTexts(label: "Hint (optional)", placeholder: "e.g. 12 reps, slow")
    }

    private func assertHintFieldTexts(label: String, placeholder: String) {
        openPresetEditor()
        openPhaseEditor(row: 0)
        let field = hintField()
        let texts = [field.label, field.placeholderValue ?? "", field.value as? String ?? ""]
        let labelShown = texts.contains(label) || app.staticTexts[label].exists
        XCTAssertTrue(labelShown, "Beschriftung '\(label)' fehlt; gefunden: \(texts)")
        XCTAssertTrue(texts.contains(placeholder), "Platzhalter '\(placeholder)' fehlt; gefunden: \(texts)")
        XCTAssertFalse(texts.contains(label.uppercased()) || app.staticTexts[label.uppercased()].exists,
                       "Beschriftung darf nicht in Grossbuchstaben stehen")
    }
}
