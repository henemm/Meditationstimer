//
//  ClaudeKennzeichenUITests.swift
//  LeanHealthTimerUITests
//
//  TDD RED #51 Schnitt 3: Kennzeichen "von Claude", Herkunft in den Info-Ansichten, Texte gelieferter Uebungen.
//  Rundenspec: DOCS/specs/features/feature-51-s3-kennzeichen.md (AC-6 bis AC-13).
//  Aufruf: ./Scripts/run-uitests.sh ClaudeKennzeichenUITests/<Methode>
//
//  Lieferung ueber den DEBUG-Testeinstieg (`uitest-claude-apply`, `UITEST_CLAUDE_DELIVERY`), Muster wie
//  ClaudeSpeichernUITests. Alle Bausteine tragen eindeutige ASCII-Namen; der Teardown nimmt sie zurueck
//  (Paket bzw. itemId) und loescht von Henning geaenderte Programme im Editor.
//

import XCTest

final class ClaudeKennzeichenUITests: XCTestCase {
    var app: XCUIApplication!
    private var withdrawals: [String] = []
    private var editedProgramNames: [String] = []

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() {
        if !editedProgramNames.isEmpty {
            if app.state != .notRunning { app.terminate() }
            launch()
            openTab(1)
            for name in editedProgramNames {
                let edit = element("workout.programRow.\(name).edit")
                guard edit.waitForExistence(timeout: 8) else { continue }
                for _ in 0..<10 where !edit.isHittable { app.swipeUp() }
                edit.tap()
                let delete = app.buttons["Löschen"]
                if delete.waitForExistence(timeout: 8) { delete.tap() }
            }
            app.terminate()
            editedProgramNames = []
        }
        for withdrawal in withdrawals {
            if app.state != .notRunning { app.terminate() }
            launch(delivery: withdrawal)
            _ = app.tabBars.firstMatch.waitForExistence(timeout: 30)
            app.terminate()
        }
        withdrawals = []
        super.tearDown()
    }

    // MARK: - Lieferungen

    private struct Names {
        let suffix: String
        var package: String { "claude.uitest-kz-\(suffix)" }
        var packageName: String { "UITest Paket \(suffix)" }
        var program: String { "UITest KZ Prog \(suffix)" }
        var breath: String { "UITest KZ Atem \(suffix)" }
        var exercise: String { "UITest KZ Uebung \(suffix)" }
        var why: String { "Warum-Text \(suffix) fuer den Ruecken" }
        var effectText: String { "Wirkung \(suffix) staerkt den Rumpf" }
        var instructionsText: String { "Ausfuehrung \(suffix) langsam und kontrolliert" }
    }

    private func makeNames() -> Names { Names(suffix: String(UUID().uuidString.prefix(6)).lowercased()) }

    private func json(_ object: [String: Any]) -> String {
        String(decoding: try! JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }

    private func envelope(_ items: [[String: Any]], why: String, package: [String: Any]?) -> String {
        var object: [String: Any] = ["format": "hhhaven.delivery/1", "deliveryId": UUID().uuidString.lowercased(),
                                     "source": "claude", "createdAt": "2026-11-13T10:15:00Z", "why": why, "items": items]
        if let package { object["package"] = package }
        return json(object)
    }

    private func withdrawalJSON(_ key: String, _ value: String) -> String {
        json(["format": "hhhaven.delivery/1", "deliveryId": UUID().uuidString.lowercased(), "source": "claude",
              "createdAt": "2026-11-14T10:15:00Z", "why": "UI-Test Ruecknahme",
              "items": [["kind": "withdrawal", key: value]]])
    }

    private func programItem(_ names: Names, exerciseId: String = "builtin.planke") -> [String: Any] {
        ["kind": "program", "itemId": "claude.uitest-kz-prog-\(names.suffix)", "revision": 1, "name": names.program,
         "symbol": "💪", "rounds": 2, "steps": [["exerciseId": exerciseId, "workSeconds": 30, "restSeconds": 10]]]
    }

    private func breathItem(_ names: Names, description: String?) -> [String: Any] {
        var item: [String: Any] = ["kind": "breath", "itemId": "claude.uitest-kz-atem-\(names.suffix)", "revision": 1,
                                   "name": names.breath, "symbol": "🌙", "inhaleSeconds": 4, "holdInSeconds": 2,
                                   "exhaleSeconds": 6, "holdOutSeconds": 0, "rounds": 10]
        if let description { item["description"] = description }
        return item
    }

    /// Paket mit Programm und Atemuebung (Form von package-mixed.json), Rücknahme per Paket.
    private func mixedDelivery(_ names: Names) -> String {
        withdrawals.append(withdrawalJSON("packageId", names.package))
        return envelope([programItem(names), breathItem(names, description: "Ruhige Atmung am Abend.")], why: names.why,
                        package: ["packageId": names.package, "name": names.packageName])
    }

    /// Paket mit gelieferter Uebung und einem Programm, dessen Schritt sie nutzt.
    private func exerciseDelivery(_ names: Names) -> String {
        withdrawals.append(withdrawalJSON("packageId", names.package))
        let exId = "claude.uitest-kz-ex-\(names.suffix)"
        let exercise: [String: Any] = ["kind": "exercise", "itemId": exId, "revision": 1, "name": names.exercise,
                                       "category": "core", "effect": names.effectText, "instructions": names.instructionsText]
        return envelope([exercise, programItem(names, exerciseId: exId)], why: names.why,
                        package: ["packageId": names.package, "name": names.packageName])
    }

    /// Nur eine Atemuebung ohne Beschreibung und ohne Paket (Form von breath-minimal.json), Rücknahme per itemId.
    private func minimalBreathDelivery(_ names: Names) -> String {
        withdrawals.append(withdrawalJSON("itemId", "claude.uitest-kz-atem-\(names.suffix)"))
        return envelope([breathItem(names, description: nil)], why: names.why, package: nil)
    }

    // MARK: - Start und Tabs

    private func launch(delivery: String? = nil, language: String = "de", locale: String = "de_DE") {
        app.launchArguments = ["enable-testing", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        app.launchEnvironment = [:]
        if let delivery {
            app.launchArguments.append("uitest-claude-apply")
            app.launchEnvironment["UITEST_CLAUDE_DELIVERY"] = delivery
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
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 30), "Tab-Leiste erscheint nicht")
        XCTAssertEqual(app.tabBars.buttons.count, 4, "Erwartet 4 Tabs")
        app.tabBars.buttons.element(boundBy: index).tap()
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// Wartet auf das Element, scrollt es ins Bild und prueft, dass es antippbar (sichtbar) ist.
    private func scrollUntilHittable(_ el: XCUIElement, _ what: String) {
        XCTAssertTrue(el.waitForExistence(timeout: 20), "\(what) fehlt")
        for _ in 0..<10 where !el.isHittable { app.swipeUp() }
        if !el.isHittable { for _ in 0..<10 where !el.isHittable { app.swipeDown() } }
        XCTAssertTrue(el.isHittable, "\(what) nicht sichtbar/antippbar")
    }

    private func waitUntilGone(_ el: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: el)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }

    /// Vorbedingung: die Lieferung wurde angenommen, der Baustein steht mit seinem Namen in der Liste.
    /// Sichert, dass ein RED an fehlender Kapsel/Info liegt und nicht an einer abgelehnten Lieferung.
    private func assertDelivered(_ name: String) {
        scrollUntilHittable(app.staticTexts[name].firstMatch, "Gelieferter Baustein \(name) (Lieferung angenommen?)")
    }

    // MARK: - Pruefungen am Info-Blatt

    /// Abschnitt "Von Claude" im Blatt: Datum, optional Paket, Warum; kein "Empfohlene Anwendung", kein Gesundheitshinweis.
    private func assertOriginSection(header: String, delivered: String, package: String?, why: String,
                                     recommended: String = "Empfohlene Anwendung") {
        let heading = app.staticTexts[header]
        scrollUntilHittable(heading, "Abschnitt \(header)")
        let date = element("claudeOrigin.deliveredAt")
        scrollUntilHittable(date, "Zeile Geliefert am")
        XCTAssertTrue(date.label.contains(delivered), "Lieferdatum falsch: \(date.label)")
        let pkg = element("claudeOrigin.package")
        if let package {
            scrollUntilHittable(pkg, "Zeile Paket")
            XCTAssertTrue(pkg.label.contains(package), "Paketname fehlt: \(pkg.label)")
        } else {
            XCTAssertFalse(pkg.exists, "Ohne Paket darf es keine Paketzeile geben")
        }
        let reason = element("claudeOrigin.why")
        scrollUntilHittable(reason, "Warum-Text")
        XCTAssertTrue(reason.label.contains(why), "Warum fehlt: \(reason.label)")
        XCTAssertFalse(app.staticTexts[recommended].exists, "\(recommended) darf bei Claude-Bausteinen nicht erscheinen")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'medizin' OR label CONTAINS[c] 'medical'"))
            .firstMatch.exists, "Kein Gesundheitshinweis erwartet")
    }

    // MARK: - AC-6 und AC-7

    /// Verhalten: Ein gelieferte Programm traegt die Kapsel "von Claude"; die Info zeigt Abschnitt "Von Claude"
    /// mit Datum, Paket und Warum, ohne "Empfohlene Anwendung" und ohne Gesundheitshinweis.
    func testWorkoutRowShowsClaudeBadgeAndInfoShowsPackageAndWhy() throws {
        let names = makeNames()
        launch(delivery: mixedDelivery(names))
        openTab(1)
        assertDelivered(names.program)
        let badge = element("workout.programRow.\(names.program).claudeBadge")
        scrollUntilHittable(badge, "Kapsel der Programmzeile")
        XCTAssertTrue(badge.label.contains("von Claude"), "Kapseltext falsch: \(badge.label)")
        XCTAssertFalse(badge.label.contains("angepasst"), "Unbearbeitet darf nicht 'angepasst' stehen: \(badge.label)")
        let info = element("workout.programRow.\(names.program).info")
        scrollUntilHittable(info, "Info-Knopf der Programmzeile")
        info.tap()
        assertOriginSection(header: "Von Claude", delivered: "13.11.2026", package: names.packageName, why: names.why)
    }

    /// Verhalten: Eingebaute Programme (Tabata Classic) haben keine Kapsel; das gelieferte daneben schon.
    func testBuiltinProgramHasNoClaudeBadge() throws {
        let names = makeNames()
        launch(delivery: mixedDelivery(names))
        openTab(1)
        assertDelivered(names.program)
        scrollUntilHittable(element("workout.programRow.\(names.program).claudeBadge"), "Kapsel des gelieferten Programms")
        scrollUntilHittable(element("workout.programRow.Tabata Classic.edit"), "Zeile Tabata Classic")
        XCTAssertFalse(element("workout.programRow.Tabata Classic.claudeBadge").exists, "Eingebautes Programm darf keine Kapsel tragen")
        XCTAssertEqual(app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier ENDSWITH '.claudeBadge' AND identifier BEGINSWITH 'workout.programRow.'")).count, 1,
            "Nur das gelieferte Programm darf eine Kapsel tragen")
    }

    // MARK: - AC-8 und AC-9

    /// Verhalten: Eine gelieferte Atemuebung traegt die Kapsel; ihre Info zeigt Datum, Paket und Warum.
    func testBreathRowShowsClaudeBadgeAndInfo() throws {
        let names = makeNames()
        launch(delivery: mixedDelivery(names))
        openTab(0)
        assertDelivered(names.breath)
        let badge = element("atem.row.\(names.breath).claudeBadge")
        scrollUntilHittable(badge, "Kapsel der Atem-Zeile")
        XCTAssertTrue(badge.label.contains("von Claude"), "Kapseltext falsch: \(badge.label)")
        let info = element("atem.row.\(names.breath).info")
        scrollUntilHittable(info, "Info-Knopf der Atem-Zeile")
        info.tap()
        assertOriginSection(header: "Von Claude", delivered: "13.11.2026", package: names.packageName, why: names.why)
    }

    /// Verhalten: Auch eine Atemuebung ohne Beschreibung und ohne Paket hat einen Info-Knopf; das Blatt zeigt
    /// Datum und Warum, aber keine Paketzeile.
    func testBreathMinimalDeliveryStillHasInfoButton() throws {
        let names = makeNames()
        launch(delivery: minimalBreathDelivery(names))
        openTab(0)
        assertDelivered(names.breath)
        let info = element("atem.row.\(names.breath).info")
        scrollUntilHittable(info, "Info-Knopf der Atem-Zeile ohne Beschreibung")
        info.tap()
        assertOriginSection(header: "Von Claude", delivered: "13.11.2026", package: nil, why: names.why)
    }

    // MARK: - AC-10

    /// Verhalten: Beim ersten Antippen der Info einer gelieferten Uebung zeigt das Blatt ihre Texte, die Kategorie
    /// und die Zeile "Von Claude geliefert am", nicht "Uebungsinformationen nicht verfuegbar".
    func testClaudeExerciseInfoShowsTextsOnFirstTap() throws {
        let names = makeNames()
        launch(delivery: exerciseDelivery(names))
        openTab(1)
        assertDelivered(names.program)
        let info = element("workout.programRow.\(names.program).info")
        scrollUntilHittable(info, "Info-Knopf der Programmzeile")
        info.tap()
        let stepInfo = app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS %@", names.exercise)).firstMatch
        scrollUntilHittable(stepInfo, "Schritt-Zeile mit der gelieferten Uebung im Programm-Info")
        stepInfo.tap()
        let effect = element("exerciseDetail.effect")
        XCTAssertTrue(effect.waitForExistence(timeout: 10), "Wirkungstext fehlt beim ersten Tippen")
        XCTAssertTrue(effect.label.contains(names.effectText), "Wirkung falsch: \(effect.label)")
        let instructions = element("exerciseDetail.instructions")
        XCTAssertTrue(instructions.waitForExistence(timeout: 10), "Ausfuehrungstext fehlt")
        XCTAssertTrue(instructions.label.contains(names.instructionsText), "Ausfuehrung falsch: \(instructions.label)")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'core'")).firstMatch.exists, "Kategorie fehlt")
        let origin = element("exerciseDetail.claudeOrigin")
        scrollUntilHittable(origin, "Zeile Von Claude geliefert am")
        XCTAssertTrue(origin.label.contains("Von Claude geliefert am"), "Zeile falsch: \(origin.label)")
        XCTAssertTrue(origin.label.contains("13.11.2026"), "Lieferdatum fehlt: \(origin.label)")
        XCTAssertFalse(app.staticTexts["Übungsinformationen nicht verfügbar"].exists, "Fallback 'nicht verfuegbar' darf nicht erscheinen")
    }

    // MARK: - AC-11

    /// Verhalten: Nach dem Umbenennen und Speichern im Editor steht an der Kapsel "von Claude · angepasst";
    /// vorher stand dort "von Claude".
    func testEditedClaudeProgramShowsAngepasst() throws {
        let names = makeNames()
        let henning = "KZ Henning Fassung \(names.suffix.uppercased())"
        editedProgramNames.append(henning)
        launch(delivery: mixedDelivery(names))
        openTab(1)
        assertDelivered(names.program)
        let before = element("workout.programRow.\(names.program).claudeBadge")
        scrollUntilHittable(before, "Kapsel vor dem Bearbeiten")
        XCTAssertFalse(before.label.contains("angepasst"), "Vorher darf nicht 'angepasst' stehen: \(before.label)")
        let edit = element("workout.programRow.\(names.program).edit")
        scrollUntilHittable(edit, "Bearbeiten-Knopf")
        edit.tap()
        let field = app.textFields["Name"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Namensfeld im Programm-Editor fehlt")
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: ((field.value as? String) ?? "").count))
        field.typeText(henning)
        let save = element("workout.setEditor.save")
        XCTAssertTrue(save.isHittable, "Speichern nicht antippbar")
        save.tap()
        XCTAssertTrue(waitUntilGone(save), "Programm-Editor schliesst nicht")
        let after = element("workout.programRow.\(henning).claudeBadge")
        scrollUntilHittable(after, "Kapsel nach dem Bearbeiten")
        XCTAssertTrue(after.label.contains("von Claude · angepasst"), "Kapsel zeigt nicht 'angepasst': \(after.label)")
    }

    // MARK: - AC-13

    /// Verhalten: Mit englischer Gerätesprache lauten Kapsel und Abschnitt "from Claude", "From Claude" und
    /// "Delivered on 11/13/2026"; keine deutschen Texte und keine Grossbuchstaben-Schluessel.
    func testClaudeBadgeIsLocalizedInEnglish() throws {
        let names = makeNames()
        launch(delivery: mixedDelivery(names), language: "en", locale: "en_US")
        openTab(1)
        assertDelivered(names.program)
        let badge = element("workout.programRow.\(names.program).claudeBadge")
        scrollUntilHittable(badge, "Kapsel der Programmzeile")
        XCTAssertTrue(badge.label.contains("from Claude"), "Englischer Kapseltext falsch: \(badge.label)")
        XCTAssertFalse(badge.label.contains("von Claude"), "Deutscher Kapseltext in englischer App: \(badge.label)")
        XCTAssertNotEqual(badge.label, badge.label.uppercased(), "Kapseltext als Grossbuchstaben-Schluessel: \(badge.label)")
        let info = element("workout.programRow.\(names.program).info")
        scrollUntilHittable(info, "Info-Knopf")
        info.tap()
        assertOriginSection(header: "From Claude", delivered: "Delivered on 11/13/2026", package: names.packageName,
                            why: names.why, recommended: "Recommended Application")
        XCTAssertFalse(app.staticTexts["Von Claude"].exists, "Deutsche Ueberschrift in englischer App")
        XCTAssertFalse(app.staticTexts["FROM CLAUDE"].exists, "Grossbuchstaben-Schluessel in englischer App")
        XCTAssertFalse(element("claudeOrigin.deliveredAt").label.contains("Geliefert"), "Deutscher Text in englischer App")
    }
}
