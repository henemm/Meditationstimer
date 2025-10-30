//
//  AmbientSoundPlayer.swift
//  Meditationstimer
//
//  Created by Claude Code on 27.10.25.
//

// MARK: - AI ORIENTATION (Read me first)
// Purpose:
//   AmbientSoundPlayer provides seamless background sound loops for meditation sessions.
//   Supports cross-fade looping, fade-in/out transitions, and multiple ambient sound options.
//
// Features:
//   • Smooth cross-fade looping (7s overlap between iterations)
//   • Fade-in on start (3s), fade-out on stop (3s)
//   • Volume: 45% (balance with gongs)
//   • Two AVAudioPlayer instances for seamless transitions
//   • No audio ducking (gongs play at full volume over ambient)
//
// Integration Points:
//   • OffenView: starts ambient on session begin, stops on session end
//   • AtemView: starts ambient on breathing session begin, stops on end
//   • SettingsSheet: user selects ambient sound (None, Waves, Spring, Fire)
//
// Audio File Requirements:
//   • waves.caf/mp3, spring.caf/mp3, fire.caf/mp3 in main bundle
//   • Loopable sounds (seamless start/end points)
//   • Recommended duration: 30-60 seconds per file
//
// Technical Implementation:
//   • Player A plays full sound → at T-7s, Player B starts (fade-in)
//   • Player A fades out over 7s while Player B fades in
//   • When Player A finishes, Player B is at full volume
//   • Repeat with roles swapped
//
// Usage Pattern:
//   let player = AmbientSoundPlayer()
//   player.start(sound: .waves)  // Fade-in, then loop
//   player.stop()                // Fade-out, then cleanup

import AVFoundation
import Foundation

/// Ambient sound options for meditation background
enum AmbientSound: String, CaseIterable, Identifiable, Codable {
    case none = "Kein Sound"
    case waves = "Waves"
    case spring = "Spring"
    case fire = "Fire"

    var id: String { rawValue }

    /// Filename (without extension) for audio file lookup
    var filename: String? {
        switch self {
        case .none: return nil
        case .waves: return "waves"
        case .spring: return "spring"
        case .fire: return "fire"
        }
    }
}

/// Manages ambient background sound playback with cross-fade looping
final class AmbientSoundPlayer: NSObject, AVAudioPlayerDelegate {

    // MARK: - Configuration

    private var targetVolume: Float = 0.45  // Default 45% volume (balance with gongs)
    private let fadeInDuration: TimeInterval = 3.0
    private let fadeOutDuration: TimeInterval = 3.0
    private let crossFadeDuration: TimeInterval = 9.0  // Overlap duration for seamless loop (increased by 2s)

    // MARK: - State

    private var playerA: AVAudioPlayer?
    private var playerB: AVAudioPlayer?
    private var currentSound: AmbientSound = .none
    private var fadeTimer: Timer?
    private var crossFadeTimer: Timer?
    private var isPlayerAActive = true  // Tracks which player is primary

    private(set) var isPlaying: Bool = false

    // MARK: - Volume Control

    /// Sets the target volume (relative to gong, 0-100%)
    /// - Parameter percent: Volume percentage (0-100)
    func setVolume(percent: Int) {
        let clampedPercent = max(0, min(100, percent))
        targetVolume = Float(clampedPercent) / 100.0

        // Update active players immediately if playing
        if isPlaying {
            playerA?.volume = targetVolume
            playerB?.volume = targetVolume
        }
    }

    // MARK: - Public API

    /// Starts ambient sound with fade-in
    func start(sound: AmbientSound) {
        guard sound != .none, !isPlaying else { return }
        guard let filename = sound.filename else { return }

        // Find audio file
        guard let url = findAudioFile(named: filename) else {
            print("[AmbientSound] Audio file not found: \(filename)")
            return
        }

        // Setup audio session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("[AmbientSound] Failed to setup audio session: \(error)")
            return
        }

        // Create players
        do {
            let pA = try AVAudioPlayer(contentsOf: url)
            pA.delegate = self
            pA.volume = 0.0  // Start silent for fade-in
            pA.numberOfLoops = 0  // Manual loop control for cross-fade
            pA.prepareToPlay()

            let pB = try AVAudioPlayer(contentsOf: url)
            pB.delegate = self
            pB.volume = 0.0
            pB.numberOfLoops = 0
            pB.prepareToPlay()

            playerA = pA
            playerB = pB

            currentSound = sound
            isPlaying = true
            isPlayerAActive = true

            // Start Player A with fade-in
            pA.play()
            fadeIn(player: pA)

            // Schedule cross-fade before Player A ends
            scheduleCrossFade()

            print("[AmbientSound] Started: \(sound.rawValue) with fade-in")
        } catch {
            print("[AmbientSound] Failed to create players: \(error)")
        }
    }

    /// Stops ambient sound with fade-out
    func stop() {
        guard isPlaying else { return }

        // Cancel timers
        fadeTimer?.invalidate()
        fadeTimer = nil
        crossFadeTimer?.invalidate()
        crossFadeTimer = nil

        // Fade out active player
        let activePlayer = isPlayerAActive ? playerA : playerB
        fadeOut(player: activePlayer) { [weak self] in
            self?.cleanup()
        }

        isPlaying = false
        print("[AmbientSound] Stopping with fade-out")
    }

    // MARK: - Private Methods

    /// Finds audio file in bundle (priority: .caf, .mp3, .wav)
    private func findAudioFile(named filename: String) -> URL? {
        let extensions = ["caf", "mp3", "wav"]
        for ext in extensions {
            if let url = Bundle.main.url(forResource: filename, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    /// Fade in player over fadeInDuration
    private func fadeIn(player: AVAudioPlayer?) {
        guard let player = player else { return }

        let steps = 30  // 30 steps for smooth fade
        let stepDuration = fadeInDuration / Double(steps)
        let volumeIncrement = targetVolume / Float(steps)

        var currentStep = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self, weak player] timer in
            guard let self = self, let player = player else {
                timer.invalidate()
                return
            }

            currentStep += 1
            player.volume = min(self.targetVolume, Float(currentStep) * volumeIncrement)

            if currentStep >= steps {
                timer.invalidate()
                self.fadeTimer = nil
            }
        }
    }

    /// Fade out player over fadeOutDuration
    private func fadeOut(player: AVAudioPlayer?, completion: (() -> Void)? = nil) {
        guard let player = player else {
            completion?()
            return
        }

        let steps = 30
        let stepDuration = fadeOutDuration / Double(steps)
        let startVolume = player.volume
        let volumeDecrement = startVolume / Float(steps)

        var currentStep = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak player] timer in
            guard let player = player else {
                timer.invalidate()
                completion?()
                return
            }

            currentStep += 1
            player.volume = max(0.0, startVolume - Float(currentStep) * volumeDecrement)

            if currentStep >= steps {
                timer.invalidate()
                player.stop()
                completion?()
            }
        }
    }

    /// Schedules cross-fade before current player ends (continuous monitoring)
    private func scheduleCrossFade() {
        crossFadeTimer?.invalidate()

        let activePlayer = isPlayerAActive ? playerA : playerB
        guard let player = activePlayer else { return }

        var crossFadeTriggered = false

        // Continuous monitoring every 0.1s (prevents timing gaps)
        crossFadeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self, weak player] timer in
            guard let self = self, let player = player, self.isPlaying else {
                timer.invalidate()
                return
            }

            guard !crossFadeTriggered else { return }

            // Use player.currentTime (playback position) NOT deviceCurrentTime (system uptime)!
            let remaining = player.duration - player.currentTime

            // Trigger cross-fade when remaining time <= crossFadeDuration (+ 0.2s safety buffer)
            if remaining <= self.crossFadeDuration + 0.2 {
                crossFadeTriggered = true
                timer.invalidate()
                self.startCrossFade()
            }
        }
    }

    /// Starts cross-fade from active player to inactive player
    private func startCrossFade() {
        guard isPlaying else { return }

        let fadingOutPlayer = isPlayerAActive ? playerA : playerB
        let fadingInPlayer = isPlayerAActive ? playerB : playerA

        guard let outPlayer = fadingOutPlayer, let inPlayer = fadingInPlayer else { return }

        // Start fading-in player
        inPlayer.volume = 0.0
        inPlayer.play()

        // Cross-fade
        let steps = 30
        let stepDuration = crossFadeDuration / Double(steps)
        let volumeStep = targetVolume / Float(steps)

        var currentStep = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            currentStep += 1
            let progress = Float(currentStep) / Float(steps)

            inPlayer.volume = min(self.targetVolume, progress * self.targetVolume)
            outPlayer.volume = max(0.0, self.targetVolume * (1.0 - progress))

            if currentStep >= steps {
                timer.invalidate()
                self.fadeTimer = nil

                // Swap active player
                self.isPlayerAActive.toggle()

                // Schedule next cross-fade
                self.scheduleCrossFade()
            }
        }
    }

    /// Cleanup all resources
    private func cleanup() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        crossFadeTimer?.invalidate()
        crossFadeTimer = nil

        playerA?.stop()
        playerA = nil
        playerB?.stop()
        playerB = nil

        currentSound = .none
        isPlaying = false

        print("[AmbientSound] Cleanup complete")
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Cross-fade should handle looping; this is fallback
        if isPlaying {
            print("[AmbientSound] WARNING: Player finished without cross-fade handoff")
        }
    }
}
