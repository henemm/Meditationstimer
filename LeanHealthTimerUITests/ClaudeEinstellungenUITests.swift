//
//  ClaudeEinstellungenUITests.swift
//  LeanHealthTimerUITests
//
//  TDD RED #57 Schnitt 5a: Einstellungsseite "Claude-Verbindung" (AC-9 bis AC-14).
//  Spec: DOCS/specs/features/feature-57-s5-einstellungen.md
//  Aufruf: ./Scripts/run-uitests.sh ClaudeEinstellungenUITests/<Methode>
//
//  Start mit `enable-testing` (Stand-in-Anmeldung gegen eine Attrappe, kein Netz). Einstellungen ueber `gearshape`.
//  Verdeckte Elemente bleiben im Zugriffsbaum: Sichtbarkeit wird ueber `isHittable` bzw. Verschwinden mit Wartezeit geprueft.
//  Rueckfrage-Knoepfe: erst per Kennung, mit Rueckfall auf den sichtbaren Text (Spec, Risiken).
//

import XCTest

final class ClaudeEinstellungenUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Hilfen

    private func launch(_ extra: [String] = []) {
        app.launchArguments = ["enable-testing", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"] + extra
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

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func text(of el: XCUIElement) -> String {
        "\(el.label) \(el.value as? String ?? "")"
    }

    private func waitUntilGone(_ el: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false OR isHittable == false"), object: el)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }

    private func waitUntilHittable(_ el: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        _ = el.waitForExistence(timeout: timeout)
        let ok = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND isHittable == true"), object: el)
        return XCTWaiter().wait(for: [ok], timeout: timeout) == .completed
    }

    private func waitForText(_ el: XCUIElement, containing part: String, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate { _, _ in self.text(of: el).contains(part) }
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: timeout) == .completed
    }

    private func openSettings() {
        let button = app.buttons["gearshape"]
        XCTAssertTrue(button.waitForExistence(timeout: 30), "Einstellungen-Knopf fehlt")
        button.tap()
        XCTAssertTrue(element("claudeSettings.link").waitForExistence(timeout: 15), "Zeile Claude-Verbindung fehlt")
    }

    private func scrollUntilHittable(_ el: XCUIElement) {
        for _ in 0..<8 where !el.isHittable { app.swipeUp() }
    }

    private func openClaudePage() {
        openSettings()
        let link = element("claudeSettings.link")
        scrollUntilHittable(link)
        XCTAssertTrue(link.isHittable, "Zeile nicht antippbar")
        link.tap()
        XCTAssertTrue(element("claudeSettings.signInStandIn").waitForExistence(timeout: 10)
                      || element("claudeSettings.status").waitForExistence(timeout: 5), "Claude-Seite oeffnet nicht")
    }

    private func backToSettings() {
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 10), "Rueckknopf fehlt")
        back.tap()
        XCTAssertTrue(element("claudeSettings.link").waitForExistence(timeout: 10), "Zurueck in den Einstellungen fehlt die Zeile")
    }

    private func signInViaStandIn() {
        let button = element("claudeSettings.signInStandIn")
        XCTAssertTrue(waitUntilHittable(button), "Stand-in-Knopf nicht antippbar")
        button.tap()
    }

    private func assertSignedInPage() {
        XCTAssertTrue(element("claudeSettings.status").waitForExistence(timeout: 15), "Seite zeigt nicht angemeldet")
        XCTAssertTrue(element("claudeSettings.signOut").exists)
        XCTAssertTrue(element("claudeSettings.disconnect").exists)
        XCTAssertTrue(waitUntilGone(element("claudeSettings.signInStandIn")), "Stand-in-Knopf steht noch da")
    }

    private func assertSignedOutPage() {
        XCTAssertTrue(waitUntilHittable(element("claudeSettings.signInStandIn")), "Stand-in-Knopf nicht wieder da")
        XCTAssertTrue(waitUntilGone(element("claudeSettings.status")), "Statuszeile steht noch da")
        XCTAssertTrue(waitUntilGone(element("claudeSettings.signOut")), "Abmelden steht noch da")
    }

    /// Knopf der Rueckfrage: erst Kennung, sonst sichtbarer Text.
    private func dialogButton(id: String, label: String) -> XCUIElement {
        let byId = element(id)
        if byId.waitForExistence(timeout: 5) { return byId }
        let sheetButton = app.sheets.buttons[label].firstMatch
        if sheetButton.waitForExistence(timeout: 3) { return sheetButton }
        return app.buttons[label].firstMatch
    }

    // MARK: - AC-9

    /// Verhalten (AC-9): Die Zeile "Claude-Verbindung" steht mit "Nicht angemeldet" oberhalb von "System-Einstellungen oeffnen".
    func testZeileClaudeVerbindungSichtbarNichtAngemeldet() throws {
        launch()
        openSettings()
        let link = element("claudeSettings.link")
        XCTAssertTrue(waitForText(link, containing: "Nicht angemeldet"), "Zeile zeigt nicht 'Nicht angemeldet': \(text(of: link))")
        let system = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'System-Einstellungen'")).firstMatch
        for _ in 0..<8 where !system.exists { app.swipeUp() }
        XCTAssertTrue(system.exists, "Zeile 'System-Einstellungen oeffnen' nicht gefunden")
        XCTAssertLessThan(link.frame.maxY, system.frame.minY, "Claude-Zeile steht nicht oberhalb von System-Einstellungen")
    }

    // MARK: - AC-10

    /// Verhalten (AC-10): Nach der Stand-in-Anmeldung zeigt die Seite angemeldet, Abgleich "Noch nicht"; in den Einstellungen "Angemeldet".
    func testAnmeldenMitStandInZeigtAngemeldetUndNochNichtAbgeglichen() throws {
        launch()
        openClaudePage()
        signInViaStandIn()
        assertSignedInPage()
        let lastSync = element("claudeSettings.lastSync")
        XCTAssertTrue(lastSync.waitForExistence(timeout: 10), "Zeile Letzter Abgleich fehlt")
        XCTAssertTrue(text(of: lastSync).contains("Noch nicht"), "Letzter Abgleich: \(text(of: lastSync))")
        backToSettings()
        let link = element("claudeSettings.link")
        XCTAssertTrue(waitForText(link, containing: "Angemeldet"), "Zeile zeigt nicht 'Angemeldet': \(text(of: link))")
        XCTAssertFalse(text(of: link).contains("Nicht angemeldet"), "Zeile zeigt noch 'Nicht angemeldet'")
    }

    // MARK: - AC-11

    /// Verhalten (AC-11): Abmelden fuehrt zurueck in "nicht angemeldet", Seite und Einstellungen-Zeile.
    func testAbmeldenZeigtWiederNichtAngemeldet() throws {
        launch()
        openClaudePage()
        signInViaStandIn()
        assertSignedInPage()
        let signOut = element("claudeSettings.signOut")
        XCTAssertTrue(waitUntilHittable(signOut))
        signOut.tap()
        assertSignedOutPage()
        backToSettings()
        XCTAssertTrue(waitForText(element("claudeSettings.link"), containing: "Nicht angemeldet"),
                      "Zeile zeigt nach Abmelden nicht 'Nicht angemeldet'")
    }

    // MARK: - AC-12

    /// Verhalten (AC-12): Trennen fragt nach; Abbrechen aendert nichts; Bestaetigen trennt.
    func testTrennenFragtNachAbbrechenBehaeltBestaetigenTrennt() throws {
        launch()
        openClaudePage()
        signInViaStandIn()
        assertSignedInPage()

        let disconnect = element("claudeSettings.disconnect")
        XCTAssertTrue(waitUntilHittable(disconnect))
        disconnect.tap()
        XCTAssertTrue(app.staticTexts["Verbindung trennen?"].waitForExistence(timeout: 10), "Rueckfrage erscheint nicht")
        XCTAssertTrue(element("claudeSettings.status").exists, "vor der Bestaetigung ist noch nichts getrennt")
        XCTAssertFalse(element("claudeSettings.signInStandIn").isHittable, "Anmeldeknopf darf noch nicht bedienbar sein")

        let cancel = dialogButton(id: "claudeSettings.disconnectCancel", label: "Abbrechen")
        XCTAssertTrue(cancel.exists, "Abbrechen fehlt in der Rueckfrage")
        cancel.tap()
        XCTAssertTrue(waitUntilGone(app.staticTexts["Verbindung trennen?"]), "Rueckfrage bleibt nach Abbrechen")
        assertSignedInPage()

        XCTAssertTrue(waitUntilHittable(disconnect))
        disconnect.tap()
        XCTAssertTrue(app.staticTexts["Verbindung trennen?"].waitForExistence(timeout: 10), "Rueckfrage erscheint beim zweiten Mal nicht")
        let confirm = dialogButton(id: "claudeSettings.disconnectConfirm", label: "Verbindung trennen")
        XCTAssertTrue(confirm.exists, "Bestaetigen fehlt in der Rueckfrage")
        confirm.tap()
        assertSignedOutPage()
    }

    // MARK: - AC-13

    /// Verhalten (AC-13): Nicht zugelassen (401): Hinweis, weiter nicht angemeldet, neuer Versuch moeglich.
    func testNichtZugelassenZeigtHinweisUndErlaubtNeuenVersuch() throws {
        launch(["uitest-claude-not-allowed"])
        openClaudePage()
        signInViaStandIn()
        let hint = element("claudeSettings.hint")
        XCTAssertTrue(hint.waitForExistence(timeout: 15), "Hinweis fehlt")
        XCTAssertTrue(waitForText(hint, containing: "nicht zugelassen"), "Hinweistext: \(text(of: hint))")
        XCTAssertFalse(element("claudeSettings.status").exists, "darf nicht angemeldet sein")
        XCTAssertTrue(waitUntilHittable(element("claudeSettings.signInStandIn")), "Stand-in-Knopf nicht wieder bedienbar")
    }

    // MARK: - AC-14

    /// Verhalten (AC-14): Dienst nicht erreichbar (503): Hinweis "spaeter erneut", weiter nicht angemeldet, Knopf bedienbar.
    func testSpaeterErneutZeigtHinweis() throws {
        launch(["uitest-claude-retry-later"])
        openClaudePage()
        signInViaStandIn()
        let hint = element("claudeSettings.hint")
        XCTAssertTrue(hint.waitForExistence(timeout: 15), "Hinweis fehlt")
        XCTAssertTrue(waitForText(hint, containing: "später erneut"), "Hinweistext: \(text(of: hint))")
        XCTAssertFalse(element("claudeSettings.status").exists, "darf nicht angemeldet sein")
        XCTAssertTrue(waitUntilHittable(element("claudeSettings.signInStandIn")), "Stand-in-Knopf nicht wieder bedienbar")
    }
}
