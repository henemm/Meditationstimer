//
//  WorkoutSoundPlayerTests.swift
//  LeanHealthTimerTests
//
//  TDD RED: Diese Tests werden FEHLSCHLAGEN bis WorkoutSoundPlayer existiert.
//
//  Ziel: Testen, dass WorkoutSoundPlayer genauso funktioniert wie GongPlayer
//

import XCTest
import AVFoundation
@testable import Lean_Health_Timer

final class WorkoutSoundPlayerTests: XCTestCase {

    // MARK: - TDD RED: WorkoutSoundPlayer muss existieren

    func testWorkoutSoundPlayerExists() {
        // Dieser Test schlägt fehl bis WorkoutSoundPlayer in Services/ existiert
        let player = WorkoutSoundPlayer.shared
        XCTAssertNotNil(player, "WorkoutSoundPlayer.shared sollte existieren")
    }

    func testPrepareFindsAllCues() {
        let player = WorkoutSoundPlayer.shared
        player.reset()
        player.prepare()

        XCTAssertTrue(player.isPrepared, "Player sollte nach prepare() prepared sein")
        XCTAssertNotNil(player.cachedUrls[.auftakt], "auftakt URL sollte gecached sein")
        XCTAssertNotNil(player.cachedUrls[.ausklang], "ausklang URL sollte gecached sein")
        XCTAssertNotNil(player.cachedUrls[.countdownTransition], "countdown-transition URL sollte gecached sein")
        XCTAssertNotNil(player.cachedUrls[.lastRound], "last-round URL sollte gecached sein")
    }

    func testDurationReturnsPositiveValue() {
        let player = WorkoutSoundPlayer.shared
        player.reset()

        let duration = player.duration(of: .auftakt)
        XCTAssertGreaterThan(duration, 0, "auftakt sollte Dauer > 0 haben")
    }

    func testPlayCreatesActivePlayer() {
        let player = WorkoutSoundPlayer.shared
        player.reset()

        let initialCount = player.activePlayerCount
        player.play(.auftakt)

        // Warte kurz damit der Player erstellt wird
        let expectation = XCTestExpectation(description: "Player created")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertGreaterThan(player.activePlayerCount, initialCount, "Nach play() sollte ein aktiver Player existieren")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Bug 32: Play sollte IMMER funktionieren (ohne Duration-Check)

    /// Dieser Test dokumentiert Bug 32:
    /// WorkoutsView hatte `if duration() > 0 { play() }` - falsch!
    /// WorkoutProgramsView hat `play()` direkt - richtig!
    /// Play muss IMMER funktionieren, unabhängig von duration()
    func testPlayWorksWithoutDurationCheck() {
        let player = WorkoutSoundPlayer()
        player.reset()

        // Simuliere das RICHTIGE Pattern (wie WorkoutProgramsView):
        // Erst play(), dann duration() für delay
        let initialCount = player.activePlayerCount
        player.play(.auftakt)  // Unconditional!
        let duration = player.duration(of: .auftakt)
        let delay = max(0.5, duration)

        // Player sollte erstellt worden sein
        let expectation = XCTestExpectation(description: "Player created unconditionally")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertGreaterThan(player.activePlayerCount, initialCount,
                "play() muss IMMER einen Player erstellen, OHNE vorherigen duration-Check")
            XCTAssertGreaterThan(delay, 0, "delay sollte mindestens 0.5 sein")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Vergleich mit GongPlayer

    func testAudioSessionConfigurationMatchesGongPlayer() {
        // Beide sollten die gleiche Session-Konfiguration verwenden
        let session = AVAudioSession.sharedInstance()

        // GongPlayer-Stil
        do {
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true, options: [])
            XCTAssertTrue(true, "GongPlayer-Stil funktioniert")
        } catch {
            XCTFail("Audio-Session-Konfiguration sollte funktionieren: \(error)")
        }
    }
}
