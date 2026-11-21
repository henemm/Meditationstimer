//
//  ClaudeSpeichernUITests.swift
//  LeanHealthTimerUITests
//
//  TDD RED #51 Schnitt 2b, Runde 2b-1: Lieferungen von Claude werden gespeichert und in den Tabs gezeigt.
//  Rundenspec: DOCS/specs/features/feature-51-s2b-speichern.md (AC-11 bis AC-15).
//  Aufruf: ./Scripts/run-uitests.sh ClaudeSpeichernUITests/<Methode>
//
//  Die Lieferung kommt ueber den DEBUG-Testeinstieg: Startargument `uitest-claude-apply`, Umgebungsvariable
//  `UITEST_CLAUDE_DELIVERY` (JSON-Text), optional `UITEST_CLAUDE_DELAY` (Sekunden). Programme und Atemuebungen
//  liegen in UserDefaults und bleiben zwischen Laeufen im Simulator; deshalb tragen die gelieferten Bausteine
//  eindeutige Namen und eine packageId, und der Teardown nimmt sie per Paket-Ruecknahme wieder zurueck.
//
//  Abweichung zur Spec (AC-11): Verzoegerung 8 statt 3 Sekunden, damit der Tab sicher sichtbar ist, bevor die Lieferung eintrifft.
//

import XCTest

final class ClaudeSpeichernUITests: XCTestCase {
    var app: XCUIApplication!
    private var packageIds: [String] = []

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() {
        // Rest-Bausteine zuruecknehmen (AC-14); eine bereits erfolgte Ruecknahme ist ohne Wirkung.
        for id in packageIds {
            if app.state != .notRunning { app.terminate() }
            launch(delivery: withdrawalJSON(packageId: id))
            _ = app.tabBars.firstMatch.waitForExistence(timeout: 30)
            app.terminate()
        }
        packageIds = []
        super.tearDown()
    }

    // MARK: - Lieferungen

    private struct Names {
        let suffix: String
        let package: String
        var program: String { "UITest Prog \(suffix)" }
        var breath: String { "UITest Atem \(suffix)" }
    }

    private func makeNames() -> Names {
        let suffix = String(UUID().uuidString.prefix(6)).lowercased()
        let names = Names(suffix: suffix, package: "claude.uitest-\(suffix)")
        packageIds.append(names.package)
        return names
    }

    private func json(_ object: [String: Any]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: object)
        return String(decoding: data, as: UTF8.self)
    }

    private func deliveryJSON(_ names: Names, program: Bool = true, breath: Bool = true) -> String {
        var items: [[String: Any]] = []
        if program {
            items.append(["kind": "program", "itemId": "claude.uitest-prog-\(names.suffix)", "revision": 1,
                          "name": names.program, "symbol": "💪", "rounds": 2,
                          "steps": [["exerciseId": "builtin.planke", "workSeconds": 30, "restSeconds": 10]]])
        }
        if breath {
            items.append(["kind": "breath", "itemId": "claude.uitest-atem-\(names.suffix)", "revision": 1,
                          "name": names.breath, "symbol": "🌙", "inhaleSeconds": 4, "holdInSeconds": 2,
                          "exhaleSeconds": 6, "holdOutSeconds": 0, "rounds": 10])
        }
        return json(["format": "hhhaven.delivery/1", "deliveryId": UUID().uuidString.lowercased(), "source": "claude",
                     "createdAt": "2026-11-13T10:15:00Z", "why": "UI-Test Lieferung",
                     "package": ["packageId": names.package, "name": "UITest Paket \(names.suffix)"],
                     "items": items])
    }

    private func withdrawalJSON(packageId: String) -> String {
        json(["format": "hhhaven.delivery/1", "deliveryId": UUID().uuidString.lowercased(), "source": "claude",
              "createdAt": "2026-11-14T10:15:00Z", "why": "UI-Test Ruecknahme",
              "items": [["kind": "withdrawal", "packageId": packageId]]])
    }

    // MARK: - Start und Tabs

    /// Startet die App; ohne `delivery` ohne Testeinstieg (normaler Start).
    private func launch(delivery: String? = nil, delay: Double = 0) {
        app.launchArguments = ["enable-testing", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launchEnvironment = [:]
        if let delivery {
            app.launchArguments.append("uitest-claude-apply")
            app.launchEnvironment["UITEST_CLAUDE_DELIVERY"] = delivery
            if delay > 0 { app.launchEnvironment["UITEST_CLAUDE_DELAY"] = String(delay) }
        }
        app.launch()
        dismissSystemAlertsIfAny()
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

    /// Wartet ohne Schlaf-Aufruf (nie vorzeitig erfuellte, umgekehrte Erwartung).
    private func wait(seconds: TimeInterval) {
        let never = XCTestExpectation(description: "Wartezeit")
        never.isInverted = true
        _ = XCTWaiter().wait(for: [never], timeout: seconds)
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func scrollUntilHittable(_ button: XCUIElement, up: Bool = true) {
        _ = button.waitForExistence(timeout: 20)
        for _ in 0..<10 where !button.isHittable {
            if up { app.swipeUp() } else { app.swipeDown() }
        }
        XCTAssertTrue(button.isHittable, "Knopf \(button.identifier) \(button.label) nicht antippbar")
    }

    // MARK: - Lesen der Listen

    private func programEditId(_ name: String) -> String { "workout.programRow.\(name).edit" }

    /// Namen der Programme im Workout-Tab (aus den Kennungen der Bearbeiten-Knoepfe), sortiert.
    private func workoutNames() -> [String] {
        openTab(1)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'workout.programRow.'"))
            .firstMatch.waitForExistence(timeout: 20), "Keine Programmzeile sichtbar")
        let ids = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'workout.programRow.' AND identifier ENDSWITH '.edit'"))
            .allElementsBoundByIndex.map(\.identifier)
        return ids.map { $0.replacingOccurrences(of: "workout.programRow.", with: "")
            .replacingOccurrences(of: ".edit", with: "") }.sorted()
    }

    /// Sichtbare Namen/Texte des Meditation-Tabs, sortiert (die Atemuebungen stehen darunter).
    private func breathTexts() -> [String] {
        openTab(0)
        XCTAssertTrue(app.buttons["Bearbeiten"].firstMatch.waitForExistence(timeout: 20),
                      "Keine Atemuebung mit Bearbeiten-Knopf sichtbar")
        return app.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }.sorted()
    }

    private func breathEditCount() -> Int {
        openTab(0)
        XCTAssertTrue(app.buttons["Bearbeiten"].firstMatch.waitForExistence(timeout: 20))
        return app.buttons.matching(identifier: "Bearbeiten").count
    }

    /// Wartet, bis die Programmzeile existiert, scrollt sie ins Bild und prueft, dass sie antippbar (sichtbar) ist.
    private func assertProgramVisible(_ name: String, _ ctx: String = "") {
        let edit = element(programEditId(name))
        XCTAssertTrue(edit.waitForExistence(timeout: 20), "Programm \(name) nicht in der Liste \(ctx)")
        scrollUntilHittable(edit)
    }

    private func assertBreathVisible(_ name: String, _ ctx: String = "") {
        let text = app.staticTexts[name]
        XCTAssertTrue(text.waitForExistence(timeout: 20), "Atemuebung \(name) nicht sichtbar \(ctx)")
        for _ in 0..<10 where !text.isHittable { app.swipeUp() }
        XCTAssertTrue(text.isHittable, "Atemuebung \(name) liegt nicht im sichtbaren Bereich \(ctx)")
    }

    /// Mindestens ein Vorgabe-Programm steht noch da (eines, das nicht von der Lieferung stammt).
    private func assertDefaultProgramVisible(excluding names: Names) {
        let others = workoutNames().filter { $0 != names.program }
        XCTAssertFalse(others.isEmpty, "Kein Vorgabe-Programm mehr sichtbar")
    }

    // MARK: - AC-11

    /// Verhalten (AC-11, Workout): Given ein Start mit Testeinstieg und Verzoegerung, When der Workout-Tab schon sichtbar ist
    /// und die Verzoegerung ablaeuft, Then erscheint das gelieferte Programm in der Liste (ohne Tabwechsel), und mindestens
    /// ein Vorgabe-Programm ist weiterhin sichtbar.
    func testAC11_GeliefertesProgrammErscheintImSichtbarenWorkoutTab() throws {
        let names = makeNames()
        let before = Date()
        launch(delivery: deliveryJSON(names), delay: 8)
        openTab(1)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'workout.programRow.'"))
            .firstMatch.waitForExistence(timeout: 20), "Keine Programmzeile sichtbar")
        if Date().timeIntervalSince(before) < 8 {
            XCTAssertFalse(element(programEditId(names.program)).exists, "Programm darf vor Ablauf der Verzoegerung noch nicht da sein")
        }
        XCTAssertTrue(element(programEditId(names.program)).waitForExistence(timeout: 30),
                      "Gelieferte Programm \(names.program) erscheint nicht im sichtbaren Workout-Tab")
        assertProgramVisible(names.program)
        assertDefaultProgramVisible(excluding: names)
    }

    /// Verhalten (AC-11, Atem): Given ein Start mit Testeinstieg und Verzoegerung, When der Meditation-Tab schon sichtbar ist
    /// und die Verzoegerung ablaeuft, Then erscheint die gelieferte Atemuebung in der Liste, und Vorgaben bleiben sichtbar.
    func testAC11_GelieferteAtemuebungErscheintImSichtbarenMeditationTab() throws {
        let names = makeNames()
        launch(delivery: deliveryJSON(names), delay: 8)
        openTab(0)
        let editButtons = app.buttons["Bearbeiten"].firstMatch
        XCTAssertTrue(editButtons.waitForExistence(timeout: 20), "Keine Atemuebung sichtbar")
        XCTAssertTrue(app.staticTexts[names.breath].waitForExistence(timeout: 30),
                      "Gelieferte Atemuebung \(names.breath) erscheint nicht im sichtbaren Meditation-Tab")
        assertBreathVisible(names.breath)
        XCTAssertGreaterThan(app.buttons.matching(identifier: "Bearbeiten").count, 1, "Vorgabe-Atemuebungen fehlen")
    }

    // MARK: - AC-12

    /// Verhalten (AC-12, Workout): Given die Lieferung trifft ein, waehrend ein anderer Tab sichtbar ist, When danach zum Workout-Tab
    /// gewechselt und ein anderer Eintrag im Editor gespeichert wird, Then ist das gelieferte Programm sichtbar und bleibt
    /// nach dem Speichern (auch nach erneutem Tabwechsel) in der Liste (keine veraltete Kopie ueberschreibt es).
    func testAC12_GeliefertesProgrammNachTabwechselUndSpeichernEinesAnderenEintrags() throws {
        let names = makeNames()
        launch(delivery: deliveryJSON(names), delay: 3)
        openTab(2)
        wait(seconds: 6)
        openTab(1)
        assertProgramVisible(names.program, "nach Tabwechsel")

        let others = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'workout.programRow.' AND identifier ENDSWITH '.edit' AND NOT identifier CONTAINS %@", names.program))
        let other = others.firstMatch
        XCTAssertTrue(other.waitForExistence(timeout: 10), "Kein anderer Eintrag zum Bearbeiten")
        scrollUntilHittable(other, up: false)
        other.tap()
        let save = element("workout.setEditor.save")
        XCTAssertTrue(save.waitForExistence(timeout: 10), "Speichern fehlt im Programm-Editor")
        save.tap()

        assertProgramVisible(names.program, "nach Speichern eines anderen Eintrags")
        openTab(2)
        openTab(1)
        assertProgramVisible(names.program, "nach erneutem Tabwechsel")
    }

    /// Verhalten (AC-12, Atem): Gleiches fuer die gelieferte Atemuebung im Meditation-Tab.
    func testAC12_GelieferteAtemuebungNachTabwechselUndSpeichernEinesAnderenEintrags() throws {
        let names = makeNames()
        launch(delivery: deliveryJSON(names), delay: 3)
        openTab(2)
        wait(seconds: 6)
        openTab(0)
        assertBreathVisible(names.breath, "nach Tabwechsel")

        // Die Vorgaben stehen vor der gelieferten Atemuebung: der erste Bearbeiten-Knopf gehoert zu einem anderen Eintrag.
        let other = app.buttons.matching(identifier: "Bearbeiten").firstMatch
        scrollUntilHittable(other, up: false)
        other.tap()
        let save = app.buttons["Speichern"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "Speichern fehlt im Atem-Editor")
        save.tap()

        assertBreathVisible(names.breath, "nach Speichern eines anderen Eintrags")
        openTab(2)
        openTab(0)
        assertBreathVisible(names.breath, "nach erneutem Tabwechsel")
    }

    // MARK: - AC-13 und AC-14

    /// Verhalten (AC-13 und AC-14): Given gelieferte Bausteine, When die App beendet und ohne Testeinstieg neu gestartet wird,
    /// Then sind Programm und Atemuebung weiter da und die Vorgaben unveraendert; When danach eine Ruecknahme per packageId
    /// geliefert wird, Then sind beide weg, Vorgaben und Stand wie vorher, und auch ein weiterer Neustart zeigt das so.
    func testAC13_AC14_LieferungUebersteht_NeustartUndRuecknahmeRaeumtAuf() throws {
        let names = makeNames()
        launch()
        let workoutBaseline = workoutNames()
        let breathCountBaseline = breathEditCount()

        app.terminate()
        launch(delivery: deliveryJSON(names))
        let workoutDelivered = workoutNames()
        XCTAssertTrue(workoutDelivered.contains(names.program), "Programm nach Lieferung nicht in der Liste")
        XCTAssertEqual(workoutDelivered.filter { $0 != names.program }, workoutBaseline, "Vorgaben/Eigenes veraendert")
        assertBreathVisible(names.breath, "nach Lieferung")
        let breathCountDelivered = breathEditCount()
        XCTAssertEqual(breathCountDelivered, breathCountBaseline + 1)

        // AC-13: Neustart ohne Startargument
        app.terminate()
        launch()
        let workoutRestart = workoutNames()
        XCTAssertEqual(workoutRestart, workoutDelivered, "Programme nach Neustart nicht gleich")
        assertBreathVisible(names.breath, "nach Neustart")
        XCTAssertEqual(breathEditCount(), breathCountDelivered, "Anzahl der Atemuebungen nach Neustart nicht gleich")

        // AC-14: Ruecknahme per Paket
        app.terminate()
        launch(delivery: withdrawalJSON(packageId: names.package))
        XCTAssertEqual(workoutNames(), workoutBaseline, "Programm nach Ruecknahme noch da oder Vorgaben veraendert")
        XCTAssertEqual(breathEditCount(), breathCountBaseline)
        XCTAssertFalse(breathTexts().contains(names.breath), "Atemuebung nach Ruecknahme noch da")

        app.terminate()
        launch()
        XCTAssertEqual(workoutNames(), workoutBaseline, "Programm nach Neustart wieder da")
        XCTAssertEqual(breathEditCount(), breathCountBaseline)
        XCTAssertFalse(breathTexts().contains(names.breath))
    }

    // MARK: - AC-15

    /// Verhalten (AC-15): Given der Testeinstieg mit unlesbarem Inhalt, When die App startet, Then erscheinen die Tabs wie ohne
    /// Lieferung (gleiche Programme und Atemuebungen); eine anschliessende gueltige Lieferung zeigt, dass der Einstieg existiert.
    func testAC15_UnlesbareLieferungBrichtNichtsUndGueltigeWirkt() throws {
        let names = makeNames()
        launch()
        let workoutBaseline = workoutNames()
        let breathCountBaseline = breathEditCount()
        app.terminate()

        launch(delivery: "{ das ist kein json", delay: 0)
        XCTAssertEqual(workoutNames(), workoutBaseline, "Programme mit unlesbarer Lieferung veraendert")
        XCTAssertEqual(breathEditCount(), breathCountBaseline, "Atemuebungen mit unlesbarer Lieferung veraendert")
        XCTAssertEqual(app.state, .runningForeground, "App nach unlesbarer Lieferung nicht mehr im Vordergrund")
        app.terminate()

        // Positivkontrolle: derselbe Weg mit gueltiger Lieferung wirkt.
        launch(delivery: deliveryJSON(names))
        XCTAssertTrue(workoutNames().contains(names.program), "Testeinstieg wendet gueltige Lieferung nicht an")
    }
}
