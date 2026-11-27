//
//  GongPlayer.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 27.09.25.
//

// MARK: - AI ORIENTATION (Read me first)
// Purpose:
//   GongPlayer is the central audio service for meditation sounds and chimes.
//   Handles playback of bundled audio files with fallback to system sounds.
//   Used by OffenView for meditation transitions and AtemView for breathing cues.
//
// Audio File Strategy:
//   • Searches for files in priority order: .caf, .wav, .mp3
//   • Graceful degradation: silent fallback if audio files are missing
//   • Concurrent playback: maintains array of active players
//   • Automatic cleanup via AVAudioPlayerDelegate
//
// Integration Points:
//   • OffenView: start gong, phase transition (triple gong), end gong
//   • AtemView: breathing phase cues (einatmen, ausatmen, halten variations)
//   • WorkoutsView: uses separate SoundPlayer class (different requirements)
//
// Audio Session Management:
//   • Sets .playback category with .mixWithOthers option
//   • Activates session before each playback
//   • Allows mixing with other apps (music, podcasts)
//   • No background audio requirements (foreground-only app)
//
// File Organization:
//   • Audio files stored in main bundle root
//   • Named descriptively: gong-ende, gong-dreimal, einatmen, ausatmen, etc.
//   • Supports completion handlers for timing-dependent operations
//
// Usage Pattern:
//   1. Call play(named: "filename") without extension
//   2. GongPlayer searches available formats automatically
//   3. Delegate handles cleanup when playback completes
//   4. Optional completion handlers for sequenced audio

//
//  GongPlayer.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 27.09.25.
//

import AVFoundation
import os

/// Kleiner Gong/Sound-Player: spielt benannte Audio-Dateien (caf/wav/mp3) vollständig aus.
final class GongPlayer: NSObject, AVAudioPlayerDelegate {
    private var activePlayers: [AVAudioPlayer] = []  // hält Referenzen, damit Sounds ausklingen
    private let volumeFactor: Float

    init(volumeFactor: Float = AudioTestMode.volumeFactor()) {
        self.volumeFactor = volumeFactor
        super.init()
    }

    /// Lesender Zugriff auf die Lautstärke der aktiven Player (für Tests).
    var currentVolumes: [Float] { activePlayers.map(\.volume) }

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true, options: [])
    }

    /// Spielt eine Audiodatei ohne Erweiterung; versucht .caf, .wav, .mp3 in dieser Reihenfolge.
    /// Optional mit Completion, die nach Ende der Wiedergabe aufgerufen wird.
    func play(named name: String, completion: (() -> Void)? = nil) {
        activateSession()
        for ext in ["caf", "wav", "mp3"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                do {
                    let p = try AVAudioPlayer(contentsOf: url)
                    p.delegate = self
                    p.volume = volumeFactor
                    AudioTestMode.logVolume("Gong", p.volume)
                    p.prepareToPlay()
                    p.play()
                    self.activePlayers.append(p)
                    if let completion = completion {
                        let delay = max(0.0, p.duration)
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            completion()
                        }
                    }
                    return
                } catch {
                    // nächste Extension versuchen
                }
            }
        }
        // Fallback: Stiller Fallback (kein Sound)
        print("Audio file '\(name)' not found, no fallback sound played")
        if let completion = completion {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: completion)
        }
    }

    /// Standard-Gong (nur Name "gong")
    func play() {
        play(named: "gong", completion: nil)
    }

    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if let idx = activePlayers.firstIndex(where: { $0 === player }) {
            activePlayers.remove(at: idx)
        }
    }
}

/// Stummschaltung im Testmodus (#131): Launch-Argument `enable-testing` setzt alle Klänge auf Lautstärke 0.
enum AudioTestMode {
    static func volumeFactor(arguments: [String] = ProcessInfo.processInfo.arguments) -> Float {
        arguments.contains("enable-testing") ? 0 : 1
    }

    static func logVolume(_ site: String, _ volume: Float) {
        #if DEBUG
        Logger(subsystem: Bundle.main.bundleIdentifier ?? "app", category: "AudioTestMode")
            .debug("\(site, privacy: .public) volume=\(volume, privacy: .public)")
        #endif
    }
}
