//
//  WorkoutAudioTests.swift
//  LeanHealthTimerTests
//
//  Created by Claude on 21.12.25.
//
//  Tests für Workout Audio-Dateien und Audio-Session-Konfiguration
//

import XCTest
import AVFoundation
@testable import Lean_Health_Timer

/// Tests für die Audio-Funktionalität der Workout-Views
/// Diese Tests prüfen, ob die benötigten Audio-Dateien im Bundle vorhanden sind
/// und ob die Audio-Session korrekt konfiguriert werden kann.
final class WorkoutAudioTests: XCTestCase {

    // MARK: - Audio-Dateien im Bundle Tests

    /// Prüft, ob die Auftakt-Datei im Bundle vorhanden ist
    func testAuftaktAudioFileExists() {
        let extensions = ["caff", "caf", "wav", "mp3", "aiff"]
        var found = false

        for ext in extensions {
            if Bundle.main.url(forResource: "auftakt", withExtension: ext) != nil {
                found = true
                break
            }
        }

        XCTAssertTrue(found, "auftakt Audio-Datei sollte im Bundle vorhanden sein")
    }

    /// Prüft, ob die Ausklang-Datei im Bundle vorhanden ist
    func testAusklangAudioFileExists() {
        let extensions = ["caff", "caf", "wav", "mp3", "aiff"]
        var found = false

        for ext in extensions {
            if Bundle.main.url(forResource: "ausklang", withExtension: ext) != nil {
                found = true
                break
            }
        }

        XCTAssertTrue(found, "ausklang Audio-Datei sollte im Bundle vorhanden sein")
    }

    /// Prüft, ob die Countdown-Transition-Datei im Bundle vorhanden ist
    func testCountdownTransitionAudioFileExists() {
        let extensions = ["caff", "caf", "wav", "mp3", "aiff"]
        var found = false

        for ext in extensions {
            if Bundle.main.url(forResource: "countdown-transition", withExtension: ext) != nil {
                found = true
                break
            }
        }

        XCTAssertTrue(found, "countdown-transition Audio-Datei sollte im Bundle vorhanden sein")
    }

    /// Prüft, ob die Last-Round-Datei im Bundle vorhanden ist
    func testLastRoundAudioFileExists() {
        let extensions = ["caff", "caf", "wav", "mp3", "aiff"]
        var found = false

        for ext in extensions {
            if Bundle.main.url(forResource: "last-round", withExtension: ext) != nil {
                found = true
                break
            }
        }

        XCTAssertTrue(found, "last-round Audio-Datei sollte im Bundle vorhanden sein")
    }

    // MARK: - Audio-Session Tests

    /// Prüft, ob die Audio-Session konfiguriert werden kann
    func testAudioSessionCanBeConfigured() {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            XCTAssertTrue(true, "Audio-Session konnte konfiguriert werden")
        } catch {
            XCTFail("Audio-Session-Konfiguration fehlgeschlagen: \(error)")
        }
    }

    /// Prüft, ob die Audio-Session mehrfach aktiviert werden kann (wie GongPlayer)
    func testAudioSessionCanBeReactivated() {
        let session = AVAudioSession.sharedInstance()

        // Erste Aktivierung
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            XCTFail("Erste Audio-Session-Aktivierung fehlgeschlagen: \(error)")
            return
        }

        // Zweite Aktivierung (simuliert wiederholte Aufrufe wie in GongPlayer)
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            XCTAssertTrue(true, "Audio-Session konnte reaktiviert werden")
        } catch {
            XCTFail("Audio-Session-Reaktivierung fehlgeschlagen: \(error)")
        }
    }

    // MARK: - AVAudioPlayer Tests

    /// Prüft, ob ein AVAudioPlayer für die Auftakt-Datei erstellt werden kann
    func testCanCreateAudioPlayerForAuftakt() {
        let extensions = ["caff", "caf", "wav", "mp3", "aiff"]
        var url: URL?

        for ext in extensions {
            if let foundUrl = Bundle.main.url(forResource: "auftakt", withExtension: ext) {
                url = foundUrl
                break
            }
        }

        guard let audioUrl = url else {
            XCTFail("auftakt Audio-Datei nicht gefunden")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: audioUrl)
            XCTAssertGreaterThan(player.duration, 0, "Audio-Datei sollte eine Dauer > 0 haben")
        } catch {
            XCTFail("AVAudioPlayer konnte nicht erstellt werden: \(error)")
        }
    }

    /// Prüft, ob ein AVAudioPlayer für die Countdown-Transition-Datei erstellt werden kann
    func testCanCreateAudioPlayerForCountdownTransition() {
        let extensions = ["caff", "caf", "wav", "mp3", "aiff"]
        var url: URL?

        for ext in extensions {
            if let foundUrl = Bundle.main.url(forResource: "countdown-transition", withExtension: ext) {
                url = foundUrl
                break
            }
        }

        guard let audioUrl = url else {
            XCTFail("countdown-transition Audio-Datei nicht gefunden")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: audioUrl)
            XCTAssertGreaterThan(player.duration, 0, "Audio-Datei sollte eine Dauer > 0 haben")
        } catch {
            XCTFail("AVAudioPlayer konnte nicht erstellt werden: \(error)")
        }
    }

    // MARK: - Vergleich GongPlayer vs SoundPlayer

    /// Prüft, ob die Gong-Dateien (die funktionieren) im Bundle sind
    func testGongAudioFilesExist() {
        // Diese Dateien werden von GongPlayer verwendet und funktionieren
        let gongFiles = ["gong-ende", "gong-dreimal", "kurz", "lang"]
        let extensions = ["caf", "wav", "mp3"]

        for file in gongFiles {
            var found = false
            for ext in extensions {
                if Bundle.main.url(forResource: file, withExtension: ext) != nil {
                    found = true
                    break
                }
            }
            XCTAssertTrue(found, "\(file) Audio-Datei sollte im Bundle vorhanden sein (GongPlayer verwendet diese)")
        }
    }
}
