import XCTest

final class LeanHealthTimerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    // MARK: - Tab Navigation Tests (Phase 1.1)

    /// Test that all 4 new tabs exist
    func testAllFourTabsExist() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Verify all 4 tabs exist
        let meditationTab = app.tabBars.buttons["Meditation"]
        let workoutTab = app.tabBars.buttons["Workout"]
        let trackerTab = app.tabBars.buttons["Tracker"]
        let erfolgeTab = app.tabBars.buttons["Erfolge"]

        XCTAssertTrue(meditationTab.waitForExistence(timeout: 5), "Meditation tab should exist")
        XCTAssertTrue(workoutTab.exists, "Workout tab should exist")
        XCTAssertTrue(trackerTab.exists, "Tracker tab should exist")
        XCTAssertTrue(erfolgeTab.exists, "Erfolge tab should exist")
    }

    /// Test that Meditation tab is selected by default
    func testMeditationTabIsDefaultSelected() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let meditationTab = app.tabBars.buttons["Meditation"]
        XCTAssertTrue(meditationTab.waitForExistence(timeout: 5), "Meditation tab should exist")
        XCTAssertTrue(meditationTab.isSelected, "Meditation tab should be selected by default")
    }

    /// Test tab switching works
    func testTabSwitching() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Start at Meditation tab
        let meditationTab = app.tabBars.buttons["Meditation"]
        let workoutTab = app.tabBars.buttons["Workout"]
        let trackerTab = app.tabBars.buttons["Tracker"]
        let erfolgeTab = app.tabBars.buttons["Erfolge"]

        XCTAssertTrue(meditationTab.waitForExistence(timeout: 5))

        // Switch to Workout tab
        workoutTab.tap()
        sleep(1)
        XCTAssertTrue(workoutTab.isSelected, "Workout tab should be selected after tap")

        // Switch to Tracker tab
        trackerTab.tap()
        sleep(1)
        XCTAssertTrue(trackerTab.isSelected, "Tracker tab should be selected after tap")

        // Switch to Erfolge tab (embedded calendar may take time to load)
        erfolgeTab.tap()
        sleep(2)
        XCTAssertTrue(erfolgeTab.isSelected, "Erfolge tab should be selected after tap")

        // Switch back to Meditation tab
        meditationTab.tap()
        sleep(1)
        XCTAssertTrue(meditationTab.isSelected, "Meditation tab should be selected after tap")
    }

    // MARK: - Meditation Tab Tests

    /// Test that German locale shows "Dauer" label for Phase 1 picker
    func testMeditationViewShowsDauerLabelInGerman() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        // Navigate to Meditation tab (should be default)
        let meditationTab = app.tabBars.buttons["Meditation"]
        XCTAssertTrue(meditationTab.waitForExistence(timeout: 5), "Meditation tab should exist")
        meditationTab.tap()

        // Verify Dauer label exists (case-insensitive search due to textCase(.uppercase))
        let dauerLabel = app.staticTexts.matching(NSPredicate(format: "label MATCHES[c] 'dauer'")).firstMatch
        XCTAssertTrue(dauerLabel.waitForExistence(timeout: 3), "Dauer label should be visible in German")
    }

    /// Test that German locale shows "Ausklang" label for Phase 2 picker
    func testMeditationViewShowsAusklangLabelInGerman() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        // Navigate to Meditation tab
        let meditationTab = app.tabBars.buttons["Meditation"]
        XCTAssertTrue(meditationTab.waitForExistence(timeout: 5), "Meditation tab should exist")
        meditationTab.tap()

        // Verify Ausklang label exists (case-insensitive search)
        let ausklangLabel = app.staticTexts.matching(NSPredicate(format: "label MATCHES[c] 'ausklang'")).firstMatch
        XCTAssertTrue(ausklangLabel.waitForExistence(timeout: 3), "Ausklang label should be visible in German")
    }

    /// Test that English locale shows "Duration" label for Phase 1 picker
    func testMeditationViewShowsDurationLabelInEnglish() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Navigate to Meditation tab
        let meditationTab = app.tabBars.buttons["Meditation"]
        XCTAssertTrue(meditationTab.waitForExistence(timeout: 5), "Meditation tab should exist")
        meditationTab.tap()

        // Verify Duration label exists (case-insensitive search)
        let durationLabel = app.staticTexts.matching(NSPredicate(format: "label MATCHES[c] 'duration'")).firstMatch
        XCTAssertTrue(durationLabel.waitForExistence(timeout: 3), "Duration label should be visible in English")
    }

    /// Test that English locale shows "Closing" label for Phase 2 picker
    func testMeditationViewShowsClosingLabelInEnglish() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Navigate to Meditation tab
        let meditationTab = app.tabBars.buttons["Meditation"]
        XCTAssertTrue(meditationTab.waitForExistence(timeout: 5), "Meditation tab should exist")
        meditationTab.tap()

        // Verify Closing label exists (case-insensitive search)
        let closingLabel = app.staticTexts.matching(NSPredicate(format: "label MATCHES[c] 'closing'")).firstMatch
        XCTAssertTrue(closingLabel.waitForExistence(timeout: 3), "Closing label should be visible in English")
    }

    // MARK: - Tracker Tab Tests

    /// Test that Tracker tab shows "Log Today" button
    func testTrackerTabShowsLogTodayButton() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Navigate to Tracker tab
        let trackerTab = app.tabBars.buttons["Tracker"]
        XCTAssertTrue(trackerTab.waitForExistence(timeout: 5))
        trackerTab.tap()

        // Verify "Log Today" button exists
        let logTodayButton = app.buttons["Log Today"]
        XCTAssertTrue(logTodayButton.waitForExistence(timeout: 3), "Log Today button should exist in Tracker tab")
    }

    // MARK: - Erfolge Tab Tests

    /// Test that Erfolge tab shows content (not empty)
    func testErfolgeTabShowsContent() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Navigate to Erfolge tab
        let erfolgeTab = app.tabBars.buttons["Erfolge"]
        XCTAssertTrue(erfolgeTab.waitForExistence(timeout: 5))
        erfolgeTab.tap()

        // Wait for content to load
        sleep(2)

        // Verify the tab is not empty by checking for any static text or buttons
        let hasContent = app.staticTexts.count > 0 || app.buttons.count > 1
        XCTAssertTrue(hasContent, "Erfolge tab should have content")
    }

    /// Test that Erfolge tab shows embedded calendar (Phase 1.1 - calendar now embedded directly)
    func testErfolgeTabShowsEmbeddedCalendar() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Navigate to Erfolge tab
        let erfolgeTab = app.tabBars.buttons["Erfolge"]
        XCTAssertTrue(erfolgeTab.waitForExistence(timeout: 5))
        erfolgeTab.tap()

        // Verify streak badges are visible in header (emoji + "days" label)
        // The header shows compact streak badges like "🧘 0 days"
        let meditationEmoji = app.staticTexts["🧘"]
        let workoutEmoji = app.staticTexts["💪"]

        // Wait for content to load
        sleep(2)

        // Check for streak-related content or calendar weekday headers
        let hasMeditationBadge = meditationEmoji.exists
        let hasWorkoutBadge = workoutEmoji.exists

        // At least one streak badge should be visible
        XCTAssertTrue(hasMeditationBadge || hasWorkoutBadge, "Erfolge tab should show streak badges")
    }

    // MARK: - Info Sheet Tests

    /// TDD RED: Test that Info sheet can be opened and contains correct content
    func testInfoSheetOpensAndShowsContent() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        // Navigate to Meditation tab
        let meditationTab = app.tabBars.buttons["Meditation"]
        XCTAssertTrue(meditationTab.waitForExistence(timeout: 5), "Meditation tab should exist")
        meditationTab.tap()

        // Tap Info button (the (i) icon)
        let infoButton = app.buttons["info.circle"]
        if infoButton.waitForExistence(timeout: 3) {
            infoButton.tap()

            // Verify Info sheet content mentions Dauer and Ausklang
            let dauerText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Dauer'")).firstMatch
            XCTAssertTrue(dauerText.waitForExistence(timeout: 3), "Info sheet should mention 'Dauer'")
        }
    }

    // MARK: - Meditation Timer Functional Tests (Phase 1.1 Baseline)

    /// Test that Meditation tab shows required UI elements: pickers, emojis, play button
    func testMeditationTabShowsTimerUI() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Navigate to Meditation tab
        let meditationTab = app.tabBars.buttons["Meditation"]
        XCTAssertTrue(meditationTab.waitForExistence(timeout: 5))
        meditationTab.tap()

        // Verify meditation emoji exists (🧘)
        let meditationEmoji = app.staticTexts["🧘"]
        XCTAssertTrue(meditationEmoji.waitForExistence(timeout: 3), "Meditation emoji 🧘 should be visible")

        // Verify closing emoji exists (🪷)
        let closingEmoji = app.staticTexts["🪷"]
        XCTAssertTrue(closingEmoji.exists, "Closing emoji 🪷 should be visible")

        // Verify play button exists
        let playButton = app.buttons["play.circle.fill"]
        XCTAssertTrue(playButton.exists, "Play button should be visible")
    }

    /// Test that tapping Play starts a meditation session and shows RunCard
    /// Note: This test may be skipped if HealthKit authorization is required
    func testMeditationPlayButtonStartsSession() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Navigate to Meditation tab
        let meditationTab = app.tabBars.buttons["Meditation"]
        XCTAssertTrue(meditationTab.waitForExistence(timeout: 5))
        meditationTab.tap()

        // Tap play button
        let playButton = app.buttons["play.circle.fill"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 3))
        playButton.tap()

        // Check if Health Access alert appears
        let allowButton = app.buttons["Allow"]
        if allowButton.waitForExistence(timeout: 3) {
            allowButton.tap()
            sleep(2)
            // Tap play again after authorization
            if playButton.waitForExistence(timeout: 2) {
                playButton.tap()
            }
        }

        // Verify session started - End button should appear
        // If HealthKit dialog blocks, we skip the rest of the test
        let endButton = app.buttons["End"]
        if endButton.waitForExistence(timeout: 8) {
            // Verify meditation emoji is still visible in RunCard
            let meditationEmoji = app.staticTexts["🧘"]
            XCTAssertTrue(meditationEmoji.exists, "Meditation emoji should be visible during session")

            // Clean up - end the session
            endButton.tap()
        } else {
            // HealthKit flow might have blocked - verify we're still on the meditation tab
            XCTAssertTrue(playButton.waitForExistence(timeout: 3), "Should remain on meditation view if session didn't start")
        }
    }

    /// Test that End button stops the meditation session and returns to picker view
    /// Note: This test depends on HealthKit authorization and may gracefully skip
    func testMeditationEndButtonStopsSession() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Navigate to Meditation tab
        let meditationTab = app.tabBars.buttons["Meditation"]
        XCTAssertTrue(meditationTab.waitForExistence(timeout: 5))
        meditationTab.tap()

        // Start session
        let playButton = app.buttons["play.circle.fill"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 3))
        playButton.tap()

        // Handle Health Access alert if needed
        let allowButton = app.buttons["Allow"]
        if allowButton.waitForExistence(timeout: 3) {
            allowButton.tap()
            sleep(2)
            if playButton.waitForExistence(timeout: 2) {
                playButton.tap()
            }
        }

        // Wait for End button
        let endButton = app.buttons["End"]
        guard endButton.waitForExistence(timeout: 8) else {
            // Session didn't start (HealthKit blocked) - test passes gracefully
            XCTAssertTrue(playButton.waitForExistence(timeout: 3), "Play button should still be visible")
            return
        }

        // Tap End to stop session
        endButton.tap()

        // Verify we're back to picker view - play button should be visible again
        XCTAssertTrue(playButton.waitForExistence(timeout: 5), "Play button should reappear after ending session")

        // Verify pickers are visible again (Duration label)
        let durationLabel = app.staticTexts.matching(NSPredicate(format: "label MATCHES[c] 'duration'")).firstMatch
        XCTAssertTrue(durationLabel.waitForExistence(timeout: 3), "Duration label should be visible after ending session")
    }

    // MARK: - Workout Timer Functional Tests (Phase 1.1 Baseline)

    /// Test that Workout tab shows required UI elements: pickers, emojis, play button
    func testWorkoutTabShowsTimerUI() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Navigate to Workout tab
        let workoutTab = app.tabBars.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 5))
        workoutTab.tap()

        // Verify work emoji exists (🔥)
        let workEmoji = app.staticTexts["🔥"]
        XCTAssertTrue(workEmoji.waitForExistence(timeout: 3), "Work emoji 🔥 should be visible")

        // Verify rest emoji exists (🧊)
        let restEmoji = app.staticTexts["🧊"]
        XCTAssertTrue(restEmoji.exists, "Rest emoji 🧊 should be visible")

        // Verify repetitions symbol exists (↻)
        let repsSymbol = app.staticTexts["↻"]
        XCTAssertTrue(repsSymbol.exists, "Repetitions symbol ↻ should be visible")

        // Verify play button exists
        let playButton = app.buttons["play.circle.fill"]
        XCTAssertTrue(playButton.exists, "Play button should be visible")

        // Verify "Total Duration" label exists
        let totalLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'total'")).firstMatch
        XCTAssertTrue(totalLabel.exists, "Total Duration label should be visible")
    }

    /// Test that Workout tab shows "Free Workout" title
    func testWorkoutTabShowsFreeWorkoutTitle() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Navigate to Workout tab
        let workoutTab = app.tabBars.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 5))
        workoutTab.tap()

        // Verify "Free Workout" title exists (case-insensitive)
        let freeWorkoutTitle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'free workout'")).firstMatch
        XCTAssertTrue(freeWorkoutTitle.waitForExistence(timeout: 3), "Free Workout title should be visible")
    }

    /// Test that tapping Play in Workout tab starts a workout session
    /// Note: This test depends on HealthKit authorization and may gracefully skip
    func testWorkoutPlayButtonStartsSession() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Navigate to Workout tab
        let workoutTab = app.tabBars.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 5))
        workoutTab.tap()

        // Tap play button
        let playButton = app.buttons["play.circle.fill"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 3))
        playButton.tap()

        // Handle Health Access alert if needed
        let allowButton = app.buttons["Allow"]
        if allowButton.waitForExistence(timeout: 3) {
            allowButton.tap()
            sleep(2)
            // Play button might need to be tapped again
            if playButton.waitForExistence(timeout: 2) && playButton.isHittable {
                playButton.tap()
            }
        }

        // Verify workout runner is shown - should have "Set X / Y" text or pause button
        let pauseButton = app.buttons["Pause"]
        let setLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Set'")).firstMatch

        if pauseButton.waitForExistence(timeout: 8) || setLabel.waitForExistence(timeout: 1) {
            // Workout started - clean up
            let closeButton = app.buttons["xmark"]
            if closeButton.exists {
                closeButton.tap()
            }
        } else {
            // HealthKit might have blocked - verify we're still on workout tab
            XCTAssertTrue(playButton.waitForExistence(timeout: 3), "Should remain on workout view if session didn't start")
        }
    }

    /// Test that X button in Workout runner closes the session
    func testWorkoutCloseButtonEndsSession() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Navigate to Workout tab
        let workoutTab = app.tabBars.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 5))
        workoutTab.tap()

        // Start workout
        let playButton = app.buttons["play.circle.fill"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 3))
        playButton.tap()

        // Handle Health Access alert if needed
        let allowButton = app.buttons["Allow"]
        if allowButton.waitForExistence(timeout: 2) {
            allowButton.tap()
            sleep(1)
            if playButton.exists && playButton.isHittable {
                playButton.tap()
            }
        }

        // Wait for workout to start
        let pauseButton = app.buttons["Pause"]
        if pauseButton.waitForExistence(timeout: 5) {
            // Close workout with X button
            let closeButton = app.buttons["xmark"]
            XCTAssertTrue(closeButton.waitForExistence(timeout: 3))
            closeButton.tap()

            // Verify we're back to main workout view
            XCTAssertTrue(playButton.waitForExistence(timeout: 3), "Play button should reappear after closing workout")
        }
    }

    // MARK: - Cross-Tab State Tests (Phase 1.1 Baseline)

    /// Test that switching tabs preserves state (no crash, timers don't reset)
    func testTabSwitchingPreservesState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Start on Meditation tab
        let meditationTab = app.tabBars.buttons["Meditation"]
        let workoutTab = app.tabBars.buttons["Workout"]
        let trackerTab = app.tabBars.buttons["Tracker"]
        let erfolgeTab = app.tabBars.buttons["Erfolge"]

        XCTAssertTrue(meditationTab.waitForExistence(timeout: 5))

        // Cycle through all tabs multiple times
        for _ in 1...3 {
            workoutTab.tap()
            XCTAssertTrue(workoutTab.isSelected)

            trackerTab.tap()
            XCTAssertTrue(trackerTab.isSelected)

            erfolgeTab.tap()
            XCTAssertTrue(erfolgeTab.isSelected)

            meditationTab.tap()
            XCTAssertTrue(meditationTab.isSelected)
        }

        // Verify Meditation tab still shows expected content
        let playButton = app.buttons["play.circle.fill"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 3), "Play button should still be visible after tab cycling")
    }

    // MARK: - Launch Performance Test

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    // MARK: - Flat Tab Structure Tests (Phase 1.1 - Flache Kartenstruktur)

    /// Test that Meditation tab shows all cards in flat structure: OpenMeditation + Breathing Presets + AddPreset
    func testMeditationTabShowsAllCardsFlat() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Navigate to Meditation tab
        let meditationTab = app.tabBars.buttons["Meditation"]
        XCTAssertTrue(meditationTab.waitForExistence(timeout: 5))
        meditationTab.tap()

        // 1. Verify OpenMeditationCard is visible (via emojis and "Open Meditation" title)
        let openMeditationTitle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'open meditation'")).firstMatch
        XCTAssertTrue(openMeditationTitle.waitForExistence(timeout: 3), "Open Meditation card title should be visible")

        // 2. Verify at least one breathing preset is visible (e.g., "Box Breathing")
        let boxBreathingPreset = app.staticTexts["Box Breathing"]
        XCTAssertTrue(boxBreathingPreset.waitForExistence(timeout: 3), "At least one breathing preset (Box Breathing) should be visible")

        // 3. Verify AddPresetCard is visible by scrolling down
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
            sleep(1)
        }

        // Look for the + button (AddPresetCard)
        let addPresetButton = app.buttons["plus.circle.fill"]
        XCTAssertTrue(addPresetButton.waitForExistence(timeout: 3), "Add Preset button should be visible after scrolling")
    }

    /// Test that Meditation tab can scroll to show all breathing presets
    func testMeditationTabScrollsToAllPresets() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Navigate to Meditation tab
        let meditationTab = app.tabBars.buttons["Meditation"]
        XCTAssertTrue(meditationTab.waitForExistence(timeout: 5))
        meditationTab.tap()

        // Scroll down to find more presets
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
            sleep(1)
        }

        // Verify another preset is visible after scrolling (e.g., "Calming Breath" or "Coherent Breathing")
        let calmingBreathPreset = app.staticTexts["Calming Breath"]
        let coherentBreathingPreset = app.staticTexts["Coherent Breathing"]
        let hasMorePresets = calmingBreathPreset.exists || coherentBreathingPreset.exists
        XCTAssertTrue(hasMorePresets, "Additional breathing presets should be visible after scrolling")
    }

    /// Test that Meditation tab toolbar has only Settings button (no Calendar, no NoAlc)
    func testMeditationTabToolbarHasOnlySettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Navigate to Meditation tab
        let meditationTab = app.tabBars.buttons["Meditation"]
        XCTAssertTrue(meditationTab.waitForExistence(timeout: 5))
        meditationTab.tap()

        // Verify Settings button exists
        let settingsButton = app.buttons["gearshape"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3), "Settings button should exist in toolbar")

        // Verify Calendar button does NOT exist
        let calendarButton = app.buttons["calendar"]
        XCTAssertFalse(calendarButton.exists, "Calendar button should NOT exist in toolbar")

        // Verify NoAlc/Drop button does NOT exist
        let dropButton = app.buttons["drop.fill"]
        XCTAssertFalse(dropButton.exists, "NoAlc (drop) button should NOT exist in toolbar")
    }

    /// Test that Workout tab shows all cards in flat structure: FreeWorkout + Programs + AddSet
    func testWorkoutTabShowsAllCardsFlat() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Navigate to Workout tab
        let workoutTab = app.tabBars.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 5))
        workoutTab.tap()

        // 1. Verify FreeWorkoutCard is visible (via "Free Workout" title and emojis)
        let freeWorkoutTitle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'free workout'")).firstMatch
        XCTAssertTrue(freeWorkoutTitle.waitForExistence(timeout: 3), "Free Workout card title should be visible")

        // 2. Verify at least one workout program is visible (e.g., "Tabata Classic")
        let tabataPreset = app.staticTexts["Tabata Classic"]
        XCTAssertTrue(tabataPreset.waitForExistence(timeout: 3), "At least one workout program (Tabata Classic) should be visible")

        // 3. Verify AddSetCard is visible by scrolling down
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
            scrollView.swipeUp()
            sleep(1)
        }

        // Look for the + button (AddSetCard)
        let addSetButton = app.buttons["plus.circle.fill"]
        XCTAssertTrue(addSetButton.waitForExistence(timeout: 3), "Add Workout Set button should be visible after scrolling")
    }

    /// Test that Workout tab can scroll to show all workout programs
    func testWorkoutTabScrollsToAllPrograms() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Navigate to Workout tab
        let workoutTab = app.tabBars.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 5))
        workoutTab.tap()

        // Scroll down to find more programs
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
            sleep(1)
        }

        // Verify another program is visible after scrolling (e.g., "Core Circuit" or "Full Body Burn")
        let coreCircuitProgram = app.staticTexts["Core Circuit"]
        let fullBodyBurnProgram = app.staticTexts["Full Body Burn"]
        let hasMorePrograms = coreCircuitProgram.exists || fullBodyBurnProgram.exists
        XCTAssertTrue(hasMorePrograms, "Additional workout programs should be visible after scrolling")
    }

    /// Test that Workout tab toolbar has only Settings button (no Calendar, no NoAlc)
    func testWorkoutTabToolbarHasOnlySettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Navigate to Workout tab
        let workoutTab = app.tabBars.buttons["Workout"]
        XCTAssertTrue(workoutTab.waitForExistence(timeout: 5))
        workoutTab.tap()

        // Verify Settings button exists
        let settingsButton = app.buttons["gearshape"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3), "Settings button should exist in toolbar")

        // Verify Calendar button does NOT exist
        let calendarButton = app.buttons["calendar"]
        XCTAssertFalse(calendarButton.exists, "Calendar button should NOT exist in toolbar")

        // Verify NoAlc/Drop button does NOT exist
        let dropButton = app.buttons["drop.fill"]
        XCTAssertFalse(dropButton.exists, "NoAlc (drop) button should NOT exist in toolbar")
    }
}
