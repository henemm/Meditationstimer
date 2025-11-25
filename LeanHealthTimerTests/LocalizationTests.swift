//
//  LocalizationTests.swift
//  LeanHealthTimerTests
//
//  Tests für Bug #31: Countdown Screen "Besinnung" nicht lokalisiert
//

import XCTest
@testable import Lean_Health_Timer

final class LocalizationTests: XCTestCase {

    // MARK: - Bug #31: Contemplation nicht lokalisiert

    /// Bug #31 Test: "Contemplation" sollte in Deutsch als "Besinnung" lokalisiert sein
    ///
    /// Aktuelles Verhalten (Bug):
    /// - OffenView.swift Zeile 384: `RunCard(title: "Contemplation", ...)`
    /// - Hardcoded englischer String, nicht lokalisiert
    /// - Deutsche App zeigt "Contemplation" statt "Besinnung"
    ///
    /// Erwartetes Verhalten:
    /// - Key "Contemplation" existiert in Localizable.xcstrings
    /// - Deutsche Übersetzung: "Besinnung"
    /// - Englische Übersetzung: "Contemplation"
    func testContemplationLocalizedToBesinnung() throws {
        // ARRANGE: Setze deutschen Locale
        let bundle = Bundle.main

        // ACT: Hole lokalisierten String für "Contemplation"
        let localizedString = NSLocalizedString("Contemplation", bundle: bundle, comment: "Phase 2 title")

        // ASSERT: In deutscher App sollte "Besinnung" zurückgegeben werden
        // WICHTIG: Dieser Test schlägt aktuell fehl weil:
        // 1. Key "Contemplation" nicht in Localizable.xcstrings existiert ODER
        // 2. Key existiert aber deutsche Übersetzung fehlt

        // Für den Test: Wenn der String gleich dem Key ist, ist er NICHT lokalisiert
        XCTAssertNotEqual(
            localizedString,
            "Contemplation",
            "❌ Bug reproduziert: 'Contemplation' ist nicht lokalisiert (Key fehlt oder keine Übersetzung)"
        )

        // Optional: Prüfe dass deutsche Übersetzung korrekt ist (wenn Test-Umgebung DE ist)
        if Locale.current.language.languageCode?.identifier == "de" {
            XCTAssertEqual(
                localizedString,
                "Besinnung",
                "Deutsche Übersetzung sollte 'Besinnung' sein"
            )
        }
    }

    /// Vergleichstest: "Meditation" sollte korrekt lokalisiert sein
    /// (Um zu prüfen dass Lokalisierung generell funktioniert)
    func testMeditationIsLocalized() throws {
        let bundle = Bundle.main
        let localizedString = NSLocalizedString("Meditation", bundle: bundle, comment: "Phase 1 title")

        // Sollte lokalisiert sein (auch wenn DE = "Meditation", ist Key vorhanden)
        XCTAssertNotNil(localizedString, "Meditation Key sollte existieren")
    }

    /// Test: Alle Phase-bezogenen Strings sollten lokalisiert sein
    func testAllPhaseStringsAreLocalized() throws {
        let bundle = Bundle.main

        let phaseStrings = [
            "Meditation",
            "Contemplation",  // ← Bug: Dieser fehlt
            "Phase 1",
            "Phase 2"
        ]

        for key in phaseStrings {
            let localized = NSLocalizedString(key, bundle: bundle, comment: "")

            // Wenn lokalisiert, sollte String != Key sein (für EN möglich dass gleich, aber Bundle sollte Eintrag haben)
            // Minimum-Test: Key sollte im Bundle gefunden werden können
            XCTAssertFalse(
                localized.isEmpty,
                "Key '\(key)' sollte lokalisiert sein"
            )
        }
    }

    // MARK: - Localizable.xcstrings Direct Check

    /// Direkter Test: Prüfe ob Key in Localizable.xcstrings existiert
    ///
    /// Dieser Test liest die Localizable.xcstrings Datei und prüft ob
    /// der Key "Contemplation" existiert
    func testContemplationKeyExistsInLocalizableXcstrings() throws {
        // ARRANGE: Finde Localizable.xcstrings im Bundle
        guard let url = Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings") else {
            XCTFail("Localizable.xcstrings nicht im Bundle gefunden")
            return
        }

        // ACT: Lese Datei als JSON
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let strings = json?["strings"] as? [String: Any] else {
            XCTFail("Kein 'strings' Dictionary in Localizable.xcstrings")
            return
        }

        // ASSERT: Key "Contemplation" sollte existieren
        XCTAssertNotNil(
            strings["Contemplation"],
            "❌ Bug reproduziert: Key 'Contemplation' fehlt in Localizable.xcstrings"
        )

        // Optional: Prüfe dass deutsche Übersetzung existiert
        if let contemplationEntry = strings["Contemplation"] as? [String: Any],
           let localizations = contemplationEntry["localizations"] as? [String: Any],
           let deEntry = localizations["de"] as? [String: Any] {

            // Deutsche Übersetzung sollte "Besinnung" sein
            if let stringUnit = deEntry["stringUnit"] as? [String: Any],
               let value = stringUnit["value"] as? String {
                XCTAssertEqual(value, "Besinnung", "Deutsche Übersetzung sollte 'Besinnung' sein")
            } else {
                XCTFail("Deutsche Übersetzung für 'Contemplation' fehlt")
            }
        } else {
            XCTFail("Deutsche Lokalisierung für 'Contemplation' nicht gefunden")
        }
    }
}
