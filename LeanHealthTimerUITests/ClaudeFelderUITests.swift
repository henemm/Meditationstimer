//
//  ClaudeFelderUITests.swift
//  LeanHealthTimerUITests
//
//  #51 Schnitt 2a-1: Absicherung (kein RED). Programme und Atemuebungen tragen kuenftig zwei neue optionale
//  Felder; gespeicherte Listen muessen nach einem Neustart weiter gelesen werden (nicht durch die
//  Code-Vorgaben ersetzt). Aufruf: ./Scripts/run-uitests.sh ClaudeFelderUITests/testProgrammeUndAtemuebungenUeberstehenNeustart
//
//  Programme und Atemuebungen liegen in UserDefaults und bleiben zwischen Laeufen erhalten. Die App legt
//  fehlende Vorgaben (nach Namen) beim Laden wieder an; deshalb wird kein Vorgabe-Eintrag umbenannt,
//  sondern je ein neuer Eintrag mit eigenem Namen angelegt. Der Teardown loescht beide ueber die
//  Oberflaeche (Muster wie WorkoutHintUITests: Aufraeumen im Teardown).
//

import XCTest

final class ClaudeFelderUITests: XCTestCase {
    var app: XCUIApplication!
    private let workoutName = "Workout Neustart"
    private let breathName = "Atem Neustart"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Helfer

    private func launch() {
        app.launchArguments = ["enable-testing", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        dismissSystemAlertsIfAny()
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func dismissSystemAlertsIfAny() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let hosts: [XCUIApplication] = [app!, XCUIApplication(bundleIdentifier: "com.apple.HealthPrivacyService"), springboard]
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

    /// Tabs haben keine Kennung: positionsbasiert (0 = Meditation/Atem, 1 = Workout).
    private func openTab(_ index: Int) {
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 30), "Tab-Leiste erscheint nicht")
        XCTAssertEqual(app.tabBars.buttons.count, 4, "Erwartet 4 Tabs")
        app.tabBars.buttons.element(boundBy: index).tap()
    }

    private func clearAndType(_ field: XCUIElement, _ text: String) {
        field.tap()
        if let current = field.value as? String, !current.isEmpty, current != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(text)
    }

    /// Scrollt, bis der Knopf antippbar ist (verdeckte Knoepfe bleiben im Zugaenglichkeitsbaum).
    private func scrollUntilHittable(_ button: XCUIElement, up: Bool = true) {
        _ = button.waitForExistence(timeout: 20)
        for _ in 0..<10 where !button.isHittable {
            if up { app.swipeUp() } else { app.swipeDown() }
        }
        XCTAssertTrue(button.isHittable, "Knopf \(button.identifier) \(button.label) nicht antippbar")
    }

    /// Sichtbare Namen der Programme im Workout-Tab (aus den Kennungen der Bearbeiten-Knoepfe), sortiert.
    private func workoutNames() -> [String] {
        openTab(1)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'workout.programRow.'"))
            .firstMatch.waitForExistence(timeout: 20), "Keine Programmzeile sichtbar")
        let ids = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'workout.programRow.' AND identifier ENDSWITH '.edit'"))
            .allElementsBoundByIndex.map(\.identifier)
        return ids.map { $0.replacingOccurrences(of: "workout.programRow.", with: "")
            .replacingOccurrences(of: ".edit", with: "") }.sorted()
    }

    private func breathEditButtons() -> XCUIElementQuery {
        openTab(0)
        XCTAssertTrue(app.buttons["Bearbeiten"].firstMatch.waitForExistence(timeout: 20),
                      "Keine Atemuebung mit Bearbeiten-Knopf sichtbar")
        return app.buttons.matching(identifier: "Bearbeiten")
    }

    /// Sichtbare Texte des Meditation-Tabs (die Namen der Atemuebungen stehen darunter), sortiert.
    private func breathTexts() -> [String] {
        _ = breathEditButtons()
        return app.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }.sorted()
    }

    // MARK: - Anlegen und Aufraeumen

    private func createWorkout() {
        openTab(1)
        scrollUntilHittable(app.buttons["Neues Workout-Set hinzufügen"])
        app.buttons["Neues Workout-Set hinzufügen"].tap()
        let name = app.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 15), "Namensfeld im Programm-Editor fehlt")
        clearAndType(name, workoutName)
        let addExercise = app.buttons["Übung hinzufügen"]
        scrollUntilHittable(addExercise)
        addExercise.tap()
        let phaseSave = element("workout.phaseEditor.save")
        XCTAssertTrue(phaseSave.waitForExistence(timeout: 10), "Schrittdialog oeffnet nicht")
        phaseSave.tap()
        let save = element("workout.setEditor.save")
        XCTAssertTrue(save.waitForExistence(timeout: 10), "Speichern fehlt im Programm-Editor")
        save.tap()
        XCTAssertTrue(element("workout.programRow.\(workoutName).edit").waitForExistence(timeout: 10),
                      "Neues Programm \(workoutName) nicht in der Liste")
    }

    private func createBreath() {
        openTab(0)
        let add = app.buttons["Neues Preset hinzufügen"]
        scrollUntilHittable(add)
        add.tap()
        let name = app.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 15), "Namensfeld im Atem-Editor fehlt")
        clearAndType(name, breathName)
        let save = app.buttons["Speichern"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "Speichern fehlt im Atem-Editor")
        save.tap()
        XCTAssertTrue(app.staticTexts[breathName].waitForExistence(timeout: 10), "Neue Atemuebung \(breathName) nicht sichtbar")
    }

    private func deleteViaEditor(_ editButton: XCUIElement, scrollUp: Bool = true) {
        scrollUntilHittable(editButton, up: scrollUp)
        editButton.tap()
        let delete = app.buttons["Löschen"]
        scrollUntilHittable(delete)
        delete.tap()
    }

    private func cleanUp() {
        if app.state != .runningForeground { launch() }
        openTab(1)
        let workoutEdit = element("workout.programRow.\(workoutName).edit")
        if workoutEdit.waitForExistence(timeout: 5) { deleteViaEditor(workoutEdit) }
        openTab(0)
        let texts = app.staticTexts[breathName]
        if texts.waitForExistence(timeout: 5) {
            // Die neue Atemuebung steht als letzte Zeile: ihr Bearbeiten-Knopf ist der letzte.
            let last = app.buttons.matching(identifier: "Bearbeiten").allElementsBoundByIndex.last
            if let last { deleteViaEditor(last) }
        }
    }

    // MARK: - Test

    /// Verhalten: Given ein neu angelegtes und benanntes Programm und eine neu angelegte und benannte Atemuebung,
    /// When die App beendet und neu gestartet wird, Then zeigt der Workout-Tab dieselben Programme (gleiche Namen,
    /// gleiche Anzahl) und der Atem-Bereich dieselben Atemuebungen einschliesslich der zwei neuen (die gespeicherte
    /// Liste wurde gelesen, nicht durch die Vorgaben aus dem Code ersetzt).
    func testProgrammeUndAtemuebungenUeberstehenNeustart() throws {
        launch()
        addTeardownBlock { [self] in cleanUp() }

        createWorkout()
        createBreath()

        let workoutBefore = workoutNames()
        let breathBefore = breathTexts()
        let breathCount = breathEditButtons().count
        XCTAssertTrue(workoutBefore.contains(workoutName))
        XCTAssertTrue(breathBefore.contains(breathName))
        XCTAssertGreaterThan(breathCount, 1)

        app.terminate()
        launch()

        let workoutAfter = workoutNames()
        XCTAssertEqual(workoutAfter, workoutBefore, "Programme nach Neustart nicht gleich")
        XCTAssertEqual(workoutAfter.count, workoutBefore.count)
        XCTAssertTrue(workoutAfter.contains(workoutName), "Neues Programm fehlt nach Neustart")

        let breathAfter = breathTexts()
        XCTAssertTrue(breathAfter.contains(breathName), "Neue Atemuebung fehlt nach Neustart")
        XCTAssertEqual(breathEditButtons().count, breathCount, "Anzahl der Atemuebungen nach Neustart nicht gleich")
        XCTAssertEqual(breathAfter, breathBefore, "Atemuebungen nach Neustart nicht gleich")
    }
}
