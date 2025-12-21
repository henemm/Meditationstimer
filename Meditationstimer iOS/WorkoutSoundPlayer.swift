//
//  WorkoutSoundPlayer.swift
//  Meditationstimer
//
//  Extrahiert aus WorkoutsView.swift für Testbarkeit.
//  Spielt Workout-spezifische Sounds: Auftakt, Ausklang, Countdown, TTS-Ansagen.
//
//  WICHTIG: Verwendet die gleiche Audio-Session-Konfiguration wie GongPlayer!
//

import AVFoundation

// MARK: - Sound Cues for Workout

public enum WorkoutCue: String {
    case countdownTransition = "countdown-transition"
    case auftakt
    case ausklang
    case lastRound = "last-round"
}

// MARK: - WorkoutSoundPlayer

public final class WorkoutSoundPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {

    // MARK: - Singleton
    public static let shared = WorkoutSoundPlayer()

    // MARK: - Properties
    private var urls: [WorkoutCue: URL] = [:]
    private var activePlayers: [AVAudioPlayer] = []
    private var prepared = false
    private let speech = AVSpeechSynthesizer()

    // MARK: - Testability
    public var isPrepared: Bool { prepared }
    public var cachedUrls: [WorkoutCue: URL] { urls }
    public var activePlayerCount: Int { activePlayers.count }

    // MARK: - Audio Session (GLEICH wie GongPlayer!)

    private func activateSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        // WICHTIG: Exakt wie GongPlayer - OHNE mode: Parameter!
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true, options: [])
        #endif
    }

    // MARK: - Prepare

    public func prepare() {
        guard !prepared else { return }
        activateSession()
        print("[WorkoutSound] Audio session configured successfully")

        for cue in [WorkoutCue.countdownTransition, .auftakt, .ausklang, .lastRound] {
            let name = cue.rawValue
            let exts = ["caff", "caf", "wav", "mp3", "aiff"]

            for ext in exts {
                if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                    urls[cue] = url
                    print("[WorkoutSound] found \(name).\(ext)")
                    break
                }
            }

            if urls[cue] == nil {
                print("[WorkoutSound] MISSING \(name)")
            }
        }
        prepared = true
    }

    public func reset() {
        stopAll()
        urls.removeAll()
        prepared = false
    }

    // MARK: - Play

    public func play(_ cue: WorkoutCue) {
        prepare()
        activateSession()

        guard let url = urls[cue] else {
            print("[WorkoutSound] cannot play \(cue.rawValue): URL not found")
            return
        }

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.prepareToPlay()
            p.play()
            activePlayers.append(p)
            print("[WorkoutSound] play \(cue.rawValue) (active: \(activePlayers.count))")
        } catch {
            print("[WorkoutSound] failed: \(error)")
        }
    }

    public func play(_ cue: WorkoutCue, after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.play(cue)
        }
    }

    // MARK: - Duration

    public func duration(of cue: WorkoutCue) -> TimeInterval {
        prepare()
        guard let url = urls[cue] else { return 0 }
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return 0 }
        return p.duration
    }

    // MARK: - TTS

    private var currentTTSLanguage: String {
        let languageCode = Locale.current.language.languageCode?.identifier ?? "de"
        return languageCode == "en" ? "en-US" : "de-DE"
    }

    public func speak(_ text: String, language: String? = nil) {
        prepare()
        activateSession()
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: language ?? currentTTSLanguage)
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        speech.speak(u)
    }

    public func speak(_ text: String, after delay: TimeInterval, language: String? = nil) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.speak(text, language: language)
        }
    }

    // MARK: - Round Announcement (legacy support - now uses TTS)

    public func playRound(_ number: Int) {
        guard number >= 1 && number <= 20 else { return }
        prepare()
        activateSession()
        // Round-Dateien werden nicht mehr verwendet - TTS stattdessen
        let text = String(format: NSLocalizedString("Round %d", comment: "TTS for round number"), number)
        speak(text)
    }

    // MARK: - Stop

    public func stopAll() {
        activePlayers.forEach { $0.stop() }
        activePlayers.removeAll()
        speech.stopSpeaking(at: .immediate)
    }

    // MARK: - AVAudioPlayerDelegate

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if let idx = activePlayers.firstIndex(where: { $0 === player }) {
            activePlayers.remove(at: idx)
        }
    }
}
