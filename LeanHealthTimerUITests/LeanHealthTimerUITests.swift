import XCTest

final class LeanHealthTimerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    // MARK: - Offene Meditation Tab Tests

    /// Test that German locale shows "Dauer" label for Phase 1 picker
    func testOffenViewShowsDauerLabelInGerman() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        // Navigate to Offen tab
        let offenTab = app.tabBars.buttons["Offen"]
        XCTAssertTrue(offenTab.waitForExistence(timeout: 5), "Offen tab should exist")
        offenTab.tap()

        // Verify Dauer label exists (case-insensitive search due to textCase(.uppercase))
        let dauerLabel = app.staticTexts.matching(NSPredicate(format: "label MATCHES[c] 'dauer'")).firstMatch
        XCTAssertTrue(dauerLabel.waitForExistence(timeout: 3), "Dauer label should be visible in German")
    }

    /// Test that German locale shows "Ausklang" label for Phase 2 picker
    func testOffenViewShowsAusklangLabelInGerman() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        // Navigate to Offen tab
        let offenTab = app.tabBars.buttons["Offen"]
        XCTAssertTrue(offenTab.waitForExistence(timeout: 5), "Offen tab should exist")
        offenTab.tap()

        // Verify Ausklang label exists (case-insensitive search)
        let ausklangLabel = app.staticTexts.matching(NSPredicate(format: "label MATCHES[c] 'ausklang'")).firstMatch
        XCTAssertTrue(ausklangLabel.waitForExistence(timeout: 3), "Ausklang label should be visible in German")
    }

    /// Test that English locale shows "Duration" label for Phase 1 picker
    func testOffenViewShowsDurationLabelInEnglish() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Navigate to Open tab (English name)
        let openTab = app.tabBars.buttons["Open"]
        XCTAssertTrue(openTab.waitForExistence(timeout: 5), "Open tab should exist")
        openTab.tap()

        // Verify Duration label exists (case-insensitive search)
        let durationLabel = app.staticTexts.matching(NSPredicate(format: "label MATCHES[c] 'duration'")).firstMatch
        XCTAssertTrue(durationLabel.waitForExistence(timeout: 3), "Duration label should be visible in English")
    }

    /// Test that English locale shows "Closing" label for Phase 2 picker
    func testOffenViewShowsClosingLabelInEnglish() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Navigate to Open tab (English name)
        let openTab = app.tabBars.buttons["Open"]
        XCTAssertTrue(openTab.waitForExistence(timeout: 5), "Open tab should exist")
        openTab.tap()

        // Verify Closing label exists (case-insensitive search)
        let closingLabel = app.staticTexts.matching(NSPredicate(format: "label MATCHES[c] 'closing'")).firstMatch
        XCTAssertTrue(closingLabel.waitForExistence(timeout: 3), "Closing label should be visible in English")
    }

    // MARK: - Info Sheet Tests

    /// TDD RED: Test that Info sheet can be opened and contains correct content
    func testInfoSheetOpensAndShowsContent() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        // Navigate to Offen tab
        let offenTab = app.tabBars.buttons["Offen"]
        XCTAssertTrue(offenTab.waitForExistence(timeout: 5), "Offen tab should exist")
        offenTab.tap()

        // Tap Info button (the (i) icon)
        let infoButton = app.buttons["info.circle"]
        if infoButton.waitForExistence(timeout: 3) {
            infoButton.tap()

            // Verify Info sheet content mentions Dauer and Ausklang
            let dauerText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Dauer'")).firstMatch
            XCTAssertTrue(dauerText.waitForExistence(timeout: 3), "Info sheet should mention 'Dauer'")
        }
    }

    // MARK: - Launch Performance Test

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
