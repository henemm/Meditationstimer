//
//  GongVsWorkoutSoundTests.swift
//  LeanHealthTimerTests
//
//  TDD RED Test: Dieser Test soll den Unterschied zwischen
//  funktionierendem GongPlayer und nicht-funktionierendem Workout SoundPlayer zeigen.
//
//  BEKANNTES PROBLEM:
//  - Meditation (GongPlayer): Sound funktioniert ✅
//  - Freie Workouts (SoundPlayer): Kein Sound ❌
//

import XCTest
import AVFoundation
@testable import Lean_Health_Timer

final class GongVsWorkoutSoundTests: XCTestCase {

    // MARK: - GongPlayer Tests (sollten GRÜN sein - funktioniert auf Device)

    /// GongPlayer kann Audio-Datei finden und Player erstellen
    func testGongPlayerCanFindAndPlayGongEnde() {
        // GongPlayer sucht in dieser Reihenfolge: ["caf", "wav", "mp3"]
        let extensions = ["caf", "wav", "mp3"]
        var url: URL?

        for ext in extensions {
            if let foundUrl = Bundle.main.url(forResource: "gong-ende", withExtension: ext) {
                url = foundUrl
                break
            }
        }

        XCTAssertNotNil(url, "gong-ende sollte im Bundle gefunden werden")

        guard let audioUrl = url else { return }

        // Aktiviere Session wie GongPlayer es macht
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)

        // Erstelle Player
        do {
            let player = try AVAudioPlayer(contentsOf: audioUrl)
            player.prepareToPlay()
            XCTAssertTrue(player.duration > 0, "gong-ende sollte abspielbar sein")
        } catch {
            XCTFail("GongPlayer-Ansatz sollte funktionieren: \(error)")
        }
    }

    // MARK: - Workout SoundPlayer Tests (sollten das Problem zeigen)

    /// SoundPlayer kann Audio-Datei finden und Player erstellen
    func testWorkoutSoundPlayerCanFindAndPlayAuftakt() {
        // SoundPlayer sucht in dieser Reihenfolge: ["caff", "caf", "wav", "mp3", "aiff"]
        let extensions = ["caff", "caf", "wav", "mp3", "aiff"]
        var url: URL?

        for ext in extensions {
            if let foundUrl = Bundle.main.url(forResource: "auftakt", withExtension: ext) {
                url = foundUrl
                break
            }
        }

        XCTAssertNotNil(url, "auftakt sollte im Bundle gefunden werden")

        guard let audioUrl = url else { return }

        // Aktiviere Session wie SoundPlayer es macht
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        // Erstelle Player
        do {
            let player = try AVAudioPlayer(contentsOf: audioUrl)
            player.prepareToPlay()
            XCTAssertTrue(player.duration > 0, "auftakt sollte abspielbar sein")
        } catch {
            XCTFail("Workout SoundPlayer-Ansatz sollte funktionieren: \(error)")
        }
    }

    // MARK: - Vergleichstest: Unterschiede zwischen GongPlayer und SoundPlayer

    /// Vergleicht die Audio-Session-Konfiguration
    func testAudioSessionConfigurationDifference() {
        let session = AVAudioSession.sharedInstance()

        // GongPlayer-Stil (ohne mode)
        do {
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
            XCTAssertTrue(true, "GongPlayer-Stil funktioniert")
        } catch {
            XCTFail("GongPlayer-Stil Audio-Session fehlgeschlagen: \(error)")
        }

        // SoundPlayer-Stil (mit mode: .default)
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            XCTAssertTrue(true, "SoundPlayer-Stil funktioniert")
        } catch {
            XCTFail("SoundPlayer-Stil Audio-Session fehlgeschlagen: \(error)")
        }
    }

    // MARK: - TDD RED: Dieser Test MUSS fehlschlagen bis der Bug gefixt ist

    /// Testet, ob beide Player gleichzeitig funktionieren können
    func testBothPlayersCanWorkSequentially() {
        let session = AVAudioSession.sharedInstance()

        // 1. Spiele Gong (wie Meditation)
        let gongUrl = Bundle.main.url(forResource: "gong-ende", withExtension: "caf")
        XCTAssertNotNil(gongUrl, "gong-ende.caf muss existieren")

        // 2. Spiele Auftakt (wie Workout)
        let auftaktUrl = Bundle.main.url(forResource: "auftakt", withExtension: "caf")
        XCTAssertNotNil(auftaktUrl, "auftakt.caf muss existieren")

        // Beide mit gleicher Session-Konfiguration
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)

        if let url1 = gongUrl {
            let player1 = try? AVAudioPlayer(contentsOf: url1)
            XCTAssertNotNil(player1, "Gong-Player sollte erstellt werden können")
            XCTAssertGreaterThan(player1?.duration ?? 0, 0, "Gong sollte Dauer > 0 haben")
        }

        if let url2 = auftaktUrl {
            let player2 = try? AVAudioPlayer(contentsOf: url2)
            XCTAssertNotNil(player2, "Auftakt-Player sollte erstellt werden können")
            XCTAssertGreaterThan(player2?.duration ?? 0, 0, "Auftakt sollte Dauer > 0 haben")
        }
    }

    // MARK: - Debug: Prüfe ob alle Workout-Sounds existieren

    func testAllWorkoutSoundsExist() {
        let workoutSounds = ["auftakt", "ausklang", "countdown-transition", "last-round"]
        let extensions = ["caff", "caf", "wav", "mp3", "aiff"]

        for sound in workoutSounds {
            var found = false
            var foundExtension = ""

            for ext in extensions {
                if Bundle.main.url(forResource: sound, withExtension: ext) != nil {
                    found = true
                    foundExtension = ext
                    break
                }
            }

            XCTAssertTrue(found, "\(sound) sollte im Bundle sein")
            if found {
                print("[DEBUG] \(sound).\(foundExtension) gefunden ✅")
            } else {
                print("[DEBUG] \(sound) NICHT gefunden ❌")
            }
        }
    }
}
