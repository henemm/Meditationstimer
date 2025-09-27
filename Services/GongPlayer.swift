//
//  GongPlayer.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 27.09.25.
//


//
//  GongPlayer.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 27.09.25.
//

import AVFoundation
import AudioToolbox

/// Kleiner Gong/Sound-Player: spielt benannte Audio-Dateien (caf/wav/mp3) vollständig aus.
final class GongPlayer: NSObject, AVAudioPlayerDelegate {
    private var activePlayers: [AVAudioPlayer] = []  // hält Referenzen, damit Sounds ausklingen

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
        // Fallback: Systemton
        AudioServicesPlaySystemSound(1005)
        if let completion = completion {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: completion)
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
