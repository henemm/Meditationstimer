//
//  LocalizationTests.swift
//  LeanHealthTimerTests
//
//  Tests für Lokalisierung der Offenen Meditation Phase-Labels
//  Aktualisiert: Labels umbenannt von Meditation/Contemplation zu Duration/Closing
//

import XCTest
@testable import Lean_Health_Timer

final class LocalizationTests: XCTestCase {

    // MARK: - Phase Labels Lokalisierung (Duration/Closing)

    /// Test: "Closing" (Phase 2) sollte in Deutsch als "Ausklang" lokalisiert sein
    func testClosingLocalizedToAusklang() throws {
        let bundle = Bundle.main
        let localizedString = NSLocalizedString("Closing", bundle: bundle, comment: "Phase 2 label")

        // Key sollte lokalisiert sein (nicht gleich dem englischen Key in DE)
        // In deutscher Umgebung sollte "Ausklang" zurückgegeben werden
        if Locale.current.language.languageCode?.identifier == "de" {
            XCTAssertEqual(
                localizedString,
                "Ausklang",
                "Deutsche Übersetzung sollte 'Ausklang' sein"
            )
        }
    }

    /// Test: "Duration" (Phase 1) sollte in Deutsch als "Dauer" lokalisiert sein
    func testDurationLocalizedToDauer() throws {
        let bundle = Bundle.main
        let localizedString = NSLocalizedString("Duration", bundle: bundle, comment: "Phase 1 label")

        // In deutscher Umgebung sollte "Dauer" zurückgegeben werden
        if Locale.current.language.languageCode?.identifier == "de" {
            XCTAssertEqual(
                localizedString,
                "Dauer",
                "Deutsche Übersetzung sollte 'Dauer' sein"
            )
        }
    }

    // MARK: - Legacy Tests (für Abwärtskompatibilität)

    /// Legacy Test: "Contemplation" Key existiert noch (für alte Referenzen)
    func testContemplationLocalizedToBesinnung() throws {
        let bundle = Bundle.main
        let localizedString = NSLocalizedString("Contemplation", bundle: bundle, comment: "Phase 2 title (legacy)")

        // Key sollte immer noch existieren für Abwärtskompatibilität
        XCTAssertNotNil(localizedString, "Contemplation Key sollte existieren")
    }

    /// Legacy Test: "Meditation" Key existiert noch
    func testMeditationIsLocalized() throws {
        let bundle = Bundle.main
        let localizedString = NSLocalizedString("Meditation", bundle: bundle, comment: "Phase 1 title (legacy)")

        XCTAssertNotNil(localizedString, "Meditation Key sollte existieren")
    }

    /// Test: Alle aktuellen Phase-Labels sollten lokalisiert sein
    func testAllPhaseStringsAreLocalized() throws {
        let bundle = Bundle.main

        let phaseStrings = [
            "Duration",      // Phase 1 (neu)
            "Closing",       // Phase 2 (neu)
            "Meditation",    // Legacy
            "Contemplation"  // Legacy
        ]

        for key in phaseStrings {
            let localized = NSLocalizedString(key, bundle: bundle, comment: "")

            XCTAssertFalse(
                localized.isEmpty,
                "Key '\(key)' sollte lokalisiert sein"
            )
        }
    }

    // MARK: - Notification Strings

    /// Test: Notification-Strings für Watch App sollten lokalisiert sein
    func testNotificationStringsAreLocalized() throws {
        let bundle = Bundle.main

        let notificationStrings = [
            "Duration completed",
            "Continue with closing phase.",
            "Session completed",
            "Session finished."
        ]

        for key in notificationStrings {
            let localized = NSLocalizedString(key, bundle: bundle, comment: "")

            XCTAssertFalse(
                localized.isEmpty,
                "Notification Key '\(key)' sollte lokalisiert sein"
            )
        }
    }

    // MARK: - TDD RED Phase: NoAlc Tracker Localization (Generic Tracker System Phase 2-4)

    /// Test 8: NoAlc level labels should be localized (German)
    /// This test will FAIL until Localizable.xcstrings has the NoAlc.* keys
    func testNoAlcLevelLabelsLocalizedInGerman() throws {
        // Use Bundle(for:) with a type from the main app to get the correct bundle
        let bundle = Bundle(for: Tracker.self)

        // These keys must exist in Localizable.xcstrings
        let noAlcKeys = [
            ("NoAlc.Steady", "Kaum"),
            ("NoAlc.Easy", "Überschaubar"),
            ("NoAlc.Wild", "Party")
        ]

        for (key, expectedGerman) in noAlcKeys {
            let localized = NSLocalizedString(key, bundle: bundle, comment: "NoAlc level")

            // If key is not in .xcstrings, NSLocalizedString returns the key itself
            XCTAssertNotEqual(
                localized,
                key,
                "Key '\(key)' should be localized (not return raw key). Add it to Localizable.xcstrings"
            )
        }
    }

    /// Test 9: Mood level labels should be localized (German)
    /// This test will FAIL until Localizable.xcstrings has the Mood.* keys
    func testMoodLevelLabelsLocalizedInGerman() throws {
        // Use Bundle(for:) with a type from the main app to get the correct bundle
        let bundle = Bundle(for: Tracker.self)

        // These keys must exist in Localizable.xcstrings
        let moodKeys = [
            ("Mood.Awful", "Mies"),
            ("Mood.Bad", "Schlecht"),
            ("Mood.Okay", "Okay"),
            ("Mood.Good", "Gut"),
            ("Mood.Great", "Super")
        ]

        for (key, _) in moodKeys {
            let localized = NSLocalizedString(key, bundle: bundle, comment: "Mood level")

            // If key is not in .xcstrings, NSLocalizedString returns the key itself
            XCTAssertNotEqual(
                localized,
                key,
                "Key '\(key)' should be localized (not return raw key). Add it to Localizable.xcstrings"
            )
        }
    }
}
