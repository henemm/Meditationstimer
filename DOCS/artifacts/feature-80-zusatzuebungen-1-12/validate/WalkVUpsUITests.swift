// Wegwerf-Durchlauf #80 (nur Scratchpad-Kopie, nie im Repo): V-Ups im Schritt-Editor wählen,
// Info-Blatt in Deutsch und Englisch öffnen, Bildschirmfotos ablegen.
import XCTest

final class WalkVUpsUITests: XCTestCase {
    let shots = "/private/tmp/claude-501/-Users-hem-Developer-Meditationstimer-Meditationstimer--claude-worktrees-glistening-jingling-rivest/f65bbe13-661e-4377-a992-3e42fd13661c/scratchpad/shots"
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ lang: String, _ locale: String) {
        app.launchArguments = ["enable-testing", "-AppleLanguages", "(\(lang))", "-AppleLocale", locale]
        app.launch()
        for label in ["OK", "Nicht erlauben", "Don’t Allow", "Don't Allow"] {
            let b = app.buttons[label]
            if b.waitForExistence(timeout: 1), b.isHittable { b.tap() }
        }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 30))
        app.tabBars.buttons.element(boundBy: 1).tap()
    }

    private func shot(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "\(shots)/\(name).png"))
        let a = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        a.name = name; a.lifetime = .keepAlways; add(a)
    }

    private func dump(_ name: String) {
        try? app.debugDescription.write(toFile: "\(shots)/\(name).txt", atomically: true, encoding: .utf8)
    }

    private func firstButton(_ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func openInfoSheet(lang: String) {
        let tabata = app.staticTexts["Tabata Classic"].firstMatch
        XCTAssertTrue(tabata.waitForExistence(timeout: 20)); dump("workout-\(lang)")
        let info = app.buttons.matching(identifier: "info.circle").allElementsBoundByIndex
            .filter { $0.frame.minY > tabata.frame.minY }.min { $0.frame.minY < $1.frame.minY }!
        info.tap()
        let vups = app.staticTexts["V-Ups"].firstMatch
        XCTAssertTrue(vups.waitForExistence(timeout: 10), "V-Ups fehlt im Programm-Info"); dump("proginfo-\(lang)")
        shot("proginfo-\(lang)")
        tapRowInfo(vups); sleep(2); dump("sheet-\(lang)"); shot("vups-\(lang)-1")
        closeSheet()
        tapRowInfo(vups); sleep(2); shot("vups-\(lang)-2")
        closeSheet()
        let burpees = app.staticTexts["Burpees"].firstMatch
        tapRowInfo(burpees); sleep(2); shot("burpees-\(lang)")
        closeSheet()
    }

    private func tapRowInfo(_ text: XCUIElement) {
        let target = app.buttons.matching(identifier: "info.circle").allElementsBoundByIndex
            .filter { abs($0.frame.midY - text.frame.midY) < 20 && $0.frame.minX > 250 }.last
        XCTAssertNotNil(target, "Info-Knopf neben \(text.label) fehlt")
        target!.tap()
    }

    private func closeSheet() {
        let done = app.buttons.matching(NSPredicate(format: "label == 'Fertig' OR label == 'Done'")).allElementsBoundByIndex.last!
        done.tap(); sleep(1)
    }

    func test_walk() throws {
        launch("de", "de_DE")
        firstButton("Bearbeiten").tap()
        let firstPhase = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Belastung:'")).firstMatch
        sleep(2); dump("seteditor")
        XCTAssertTrue(firstPhase.waitForExistence(timeout: 10))
        firstPhase.tap()
        sleep(2); dump("phaseeditor")
        let picker = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Name'")).firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        picker.tap()
        sleep(2); dump("menu")
        let opt = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'V-Ups'")).firstMatch
        let menu = app.collectionViews.allElementsBoundByIndex.last { $0.frame.minX > 50 }!
        var tries = 0
        while !(opt.exists && opt.isHittable) && tries < 25 { menu.swipeUp(velocity: .slow); tries += 1 }
        XCTAssertTrue(opt.exists, "V-Ups nicht in der Vorschlagsliste")
        opt.tap()
        shot("editor-vups-de")
        app.navigationBars.buttons.matching(NSPredicate(format: "label == 'Sichern' OR label == 'Speichern' OR label == 'Save'")).firstMatch.tap()
        sleep(1)
        app.navigationBars.buttons.matching(NSPredicate(format: "label == 'Sichern' OR label == 'Speichern' OR label == 'Save'")).firstMatch.tap()
        sleep(1)
        openInfoSheet(lang: "de")
        app.terminate()
        launch("en", "en_US")
        openInfoSheet(lang: "en")
    }
}
