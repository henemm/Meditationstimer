//
//  WorkoutsView.swift
//  Meditationstimer
//
//  Rebuilt as 1:1 layout copy of OffenView with three wheels (Belastung/Erholung/Wiederholungen)
//

// MARK: - AI ORIENTATION (Read me first)
// Purpose:
//   WorkoutsView manages the "Workouts" tab - a High Intensity Interval Training (HIIT) timer.
//   Users configure work duration, rest duration, and repetitions for structured interval workouts.
//   Features audio cues, progress tracking, and HealthKit logging as mindfulness sessions.
//
// Files & Responsibilities (where to look next):
//   • SoundPlayer (local)       – Workout-specific audio system with cues and speech
//   • WorkoutRunnerView (local) – Full-screen workout execution overlay
//   • CircularRing.swift        – Dual-ring progress visualization (session + phase)
//   • HealthKitManager          – Logs completed workouts as mindfulness sessions
//   • SettingsSheet.swift       – Shared settings UI
//
// Control Flow (high level):
//   1. User sets work/rest/repetitions with three wheel pickers
//   2. Start button → opens full-screen WorkoutRunnerView
//   3. Auftakt sound → countdown → first work phase begins
//   4. Work phase → visual flame icon, countdown cues (3-2-1), round announcements
//   5. Phase transitions → "lang" sound, optional "last round" announcement
//   6. Rest phase → pause icon, pre-roll auftakt for next work phase
//   7. Completion → "ausklang" sound, HealthKit logging, return to main view
//
// Audio System (SoundPlayer):
//   • Supports .caff, .caf, .wav, .mp3, .aiff formats
//   • Dynamic loading of round-1.caff through round-20.caff
//   • AVSpeechSynthesizer for German voice announcements
//   • Comprehensive cue system: kurz, lang, auftakt, ausklang, last-round
//
// Progress Visualization:
//   • Outer ring: total workout progress (continuous)
//   • Inner ring: current phase progress (resets each work/rest)
//   • Icons change per phase: flame (work) vs pause (rest)
//
// State Management:
//   • Pause/resume functionality with time accumulation
//   • Robust scheduling system with DispatchWorkItem cancellation
//   • Phase transition logic with proper cleanup
//
// HealthKit Integration:
//   • Logs entire workout duration as "Mindfulness" session
//   • Covers all exit scenarios: natural end, manual finish, X-button cancel
//   • Graceful error handling without UI interruption

import SwiftUI
import HealthKit
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(ActivityKit)
import ActivityKit
#endif

#if os(iOS)

// MARK: - Sound Cues for Workout
private enum Cue: String {
    case kurz       // short tick for countdown (3, 2, 1s before)
    case lang       // long tone on phase switch (work→rest)
    case auftakt    // pre-start cue before first work
    case ausklang   // final chime at end of last work
    case lastRound = "last-round" // announce penultimate→last set
}

private final class SoundPlayer: ObservableObject {
    private var players: [Cue: AVAudioPlayer] = [:]
    private var prepared = false
    private let speech = AVSpeechSynthesizer()
    private var roundPlayers: [Int: AVAudioPlayer] = [:] // caches round-1..round-20

    func prepare() {
        guard !prepared else { return }
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // ignore
        }
        #endif
        // Try to load each cue from the app bundle. We look for .caff first, then .caf, then .wav, then .mp3
        for cue in [Cue.kurz, .lang, .auftakt, .ausklang, .lastRound] {
            let name = cue.rawValue
            let exts = ["caff", "caf", "wav", "mp3", "aiff"]
            var found: URL? = nil
            for ext in exts {
                if let url = Bundle.main.url(forResource: name, withExtension: ext) { found = url; break }
            }
            if let url = found, let p = try? AVAudioPlayer(contentsOf: url) {
                p.prepareToPlay()
                players[cue] = p
                print("[Sound] loaded \(name): duration=\(p.duration)s")
            } else {
                print("[Sound] MISSING \(name).(caff|caf|wav|mp3|aiff)")
            }
        }
        prepared = true
    }

    func play(_ cue: Cue) {
        prepare()
        if let p = players[cue] {
            p.currentTime = 0
            p.play()
            print("[Sound] play \(cue.rawValue)")
        } else {
            print("[Sound] cannot play \(cue.rawValue): player missing")
        }
    }

    func playRound(_ number: Int) {
        guard number >= 1 && number <= 20 else { return }
        prepare()
        if let p = roundPlayers[number] {
            p.currentTime = 0
            p.play()
            print("[Sound] play round-\(number)")
            return
        }
        let name = "round-\(number)"
        let exts = ["caff", "caf", "wav", "mp3", "aiff"]
        var found: URL? = nil
        for ext in exts {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) { found = url; break }
        }
        if let url = found, let p = try? AVAudioPlayer(contentsOf: url) {
            p.prepareToPlay()
            roundPlayers[number] = p
            p.currentTime = 0
            p.play()
            print("[Sound] loaded+play \(name)")
        } else {
            print("[Sound] MISSING \(name).(caff|caf|wav|mp3|aiff)")
        }
    }

    func play(_ cue: Cue, after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.play(cue)
        }
    }

    func speak(_ text: String, language: String = "de-DE") {
        prepare()
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: language)
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        speech.speak(u)
    }

    func speak(_ text: String, after delay: TimeInterval, language: String = "de-DE") {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.speak(text, language: language)
        }
    }

    func stopAll() {
        for (_, p) in players { p.stop() }
        speech.stopSpeaking(at: .immediate)
    }

    func duration(of cue: Cue) -> TimeInterval {
        prepare()
        return players[cue]?.duration ?? 0
    }
}

// MARK: - Workout Runner (identisch zu vorher; kein Layout-Tuning)
private enum WorkoutPhase: String { case work, rest }

private struct WorkoutRunnerView: View {
    // scenePhase-Automatik entfernt – führte zu unerwünschten Beendigungen beim App-Wechsel
    let intervalSec: Int
    let restSec: Int
    @Binding var repeats: Int
    let onClose: () -> Void

    @StateObject private var sounds = SoundPlayer()
    
    @State private var workoutStart: Date?
    @State private var isSaving = false
    @State private var saveFailed = false
    #if canImport(ActivityKit)
    @State private var currentActivity: Activity<MeditationAttributes>? = nil
    #endif

    @State private var sessionStart: Date = .now
    @AppStorage("logWorkoutsAsMindfulness") private var logWorkoutsAsMindfulness: Bool = false
    @State private var scheduled: [DispatchWorkItem] = []

    private func cancelScheduled() {
        scheduled.forEach { $0.cancel() }
        scheduled.removeAll()
    }

    private func schedule(_ delay: TimeInterval, action: @escaping () -> Void) {
        let w = DispatchWorkItem(block: action)
        scheduled.append(w)
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay), execute: w)
    }
    private var sessionTotal: TimeInterval {
        let work = intervalSec * repeats
        let rest = max(0, repeats - 1) * restSec
        return TimeInterval(work + rest)
    }

    @State private var phaseStart: Date? = nil
    @State private var phaseDuration: Double = 1
    @State private var phase: WorkoutPhase = .work
    @State private var finished = false
    @State private var started = false
    @State private var isPaused = false
    @State private var pausedAt: Date? = nil
    @State private var pausedSessionAccum: TimeInterval = 0
    @State private var pausedPhaseAccum: TimeInterval = 0
    @State private var phaseEndFired = false
    @State private var repIndex: Int = 1  // 1…repeats
    @State private var plannedRepeats: Int = 0 // snapshot at launch for display
    @State private var cfgRepeats: Int = 0 // frozen repeats for engine logic
    @State private var cfgInterval: Int = 0 // frozen interval seconds
    @State private var cfgRest: Int = 0     // frozen rest seconds

    var body: some View {
        ZStack {
            #if canImport(UIKit)
            Color(UIColor.systemGray6).ignoresSafeArea()
            #else
            Color.gray.opacity(0.1).ignoresSafeArea()
            #endif
            VStack(spacing: 12) {
                Text("Intervall-Workout").font(.headline)
                Text("HIIT • \(plannedRepeats) Wiederholungen • \(intervalSec)s / \(restSec)s")
                    .font(.footnote).foregroundStyle(.secondary)
                #if DEBUG
                Text("DBG repeats(binding)=\(repeats) • snapshot=\(plannedRepeats)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                #endif

                if !finished {
                    TimelineView(.animation) { ctx in
                        let nowRaw = ctx.date
                        let nowEff = pausedAt ?? nowRaw

                        let total = max(0.001, sessionTotal)
                        let elapsedSession = started ? max(0, nowEff.timeIntervalSince(sessionStart) - pausedSessionAccum) : 0
                        let progressTotal = started ? max(0.0, min(1.0, elapsedSession / total)) : 0

                        let dur = max(0.001, phaseDuration)
                        let start = phaseStart ?? nowEff
                        let elapsedInPhase = max(0, nowEff.timeIntervalSince(start) - pausedPhaseAccum)
                        let fractionPhase = max(0.0, min(1.0, elapsedInPhase / dur))

                        VStack(spacing: 8) {
                            ZStack {
                                CircularRing(progress: progressTotal, lineWidth: 22).foregroundStyle(.tint)
                                CircularRing(progress: fractionPhase, lineWidth: 14).scaleEffect(0.72).foregroundStyle(.secondary)
                                Image(systemName: iconName(for: phase)).font(.system(size: 64)).foregroundStyle(.tint)
                            }
                            .frame(width: 320, height: 320)
                            .padding(.top, 6)
                            Text("Satz \(repIndex) / \(plannedRepeats) — \(label(for: phase))")
                                .font(.subheadline)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .onChange(of: fractionPhase) { newVal in
                            if newVal >= 1.0 {
                                if !phaseEndFired {
                                    phaseEndFired = true
                                    advance()
                                }
                            } else {
                                phaseEndFired = false
                            }
                        }
                    }
                } else {
                    // Show completion state; logging is handled by endSession(completed:)
                    Color.clear.frame(height: 1)
                }

                Button(finished ? "Fertig" : (isPaused ? "Weiter" : "Pause")) {
                    if finished {
                        Task { await endSession(completed: true) }
                    } else {
                        togglePause()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
                .disabled(isSaving)
            }
            .frame(minWidth: 280, maxWidth: 360)
            .padding(16)
            .overlay(alignment: .topTrailing) {
                Button {
                    Task { await endSession(completed: false) }
                } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .semibold)).frame(width: 28, height: 28)
                }
                .buttonStyle(.borderedProminent).tint(.secondary).clipShape(Circle()).padding(8)
                .disabled(isSaving)
            }
            
            // Saving overlay
            if isSaving {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView("Speichern…")
                        .progressViewStyle(.circular)
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
                .transition(.opacity)
            }
            // Failure toast (brief)
            if saveFailed {
                VStack {
                    Spacer()
                    Text("Konnte nicht in Health sichern")
                        .font(.footnote)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .padding(.bottom, 24)
                }
                .transition(.opacity)
                .task {
                    // Auto-hide after 2 seconds
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    saveFailed = false
                }
            }
        }
        .task {
            // Request HealthKit authorization
            do { 
                try await HealthKitManager.shared.requestAuthorization() 
            } catch {
                print("HealthKit authorization failed: \(error)")
            }
            
            sounds.prepare()
            plannedRepeats = max(1, repeats)
            cfgRepeats = plannedRepeats
            cfgInterval = intervalSec
            cfgRest     = restSec

            // AUFTAKT: play, then start workout exactly at first work
            let aDur = sounds.duration(of: .auftakt)
            if aDur > 0 {
                sounds.play(.auftakt)
                schedule(aDur) {
                    started = true
                    sessionStart = Date()
                    workoutStart = sessionStart // Store for HealthKit logging
                    // Start Live Activity for total workout countdown
                    #if canImport(ActivityKit)
                    if ActivityAuthorizationInfo().areActivitiesEnabled {
                        let attributes = MeditationAttributes(title: "Workout")
                        let state = MeditationAttributes.ContentState(
                            endDate: sessionStart.addingTimeInterval(sessionTotal),
                            phase: 1
                        )
                        do {
                            currentActivity = try Activity<MeditationAttributes>.request(
                                attributes: attributes,
                                content: ActivityContent(state: state, staleDate: nil),
                                pushType: nil
                            )
                        } catch {}
                    }
                    #endif
                    setPhase(.work)
                    scheduleCuesForCurrentPhase()
                }
            } else {
                // No file present → start immediately
                started = true
                sessionStart = Date()
                workoutStart = sessionStart // Store for HealthKit logging
                #if canImport(ActivityKit)
                if ActivityAuthorizationInfo().areActivitiesEnabled {
                    let attributes = MeditationAttributes(title: "Workout")
                    let state = MeditationAttributes.ContentState(
                        endDate: sessionStart.addingTimeInterval(sessionTotal),
                        phase: 1
                    )
                    do {
                        currentActivity = try Activity<MeditationAttributes>.request(
                            attributes: attributes,
                            content: ActivityContent(state: state, staleDate: nil),
                            pushType: nil
                        )
                    } catch {}
                }
                #endif
                setPhase(.work)
                scheduleCuesForCurrentPhase()
            }
        }
        .onDisappear {
            sounds.stopAll()
            cancelScheduled()
        }
        .onChange(of: phase) { _ in }
        // Keine automatische Beendigung bei App-Wechsel
    }

    /// Zentraler Beendigungsablauf. completed=true: regulär abgeschlossen; false: abgebrochen.
    @MainActor
    private func endSession(completed: Bool) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        sounds.stopAll()
        cancelScheduled()

        let endDate = Date()
        if let start = workoutStart {
            do {
                if logWorkoutsAsMindfulness {
                    try await HealthKitManager.shared.logMindfulness(start: start, end: endDate)
                } else {
                    // Workouts als echtes HKWorkout
                    try await HealthKitManager.shared.logWorkout(start: start, end: endDate, activity: HKWorkoutActivityType.highIntensityIntervalTraining)
                }
            } catch {
                print("HealthKit workout logging failed: \(error)")
                saveFailed = true
                // UX-Entscheidung: View dennoch schließen, kurzer Hinweis bleibt optional
            }
        }

        // End Live Activity
    #if canImport(ActivityKit)
    await currentActivity?.end(dismissalPolicy: .immediate)
    currentActivity = nil
    #endif

        // Optional: kurze Verzögerung, damit Overlay wahrnehmbar ist
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s
        onClose()
    }

    private func iconName(for phase: WorkoutPhase) -> String { phase == .work ? "flame" : "pause" }
    private func label(for phase: WorkoutPhase) -> String { phase == .work ? "Belastung" : "Erholung" }

    private func setPhase(_ p: WorkoutPhase) {
        cancelScheduled()
        phase = p
        pausedPhaseAccum = 0
        phaseEndFired = false

        if p == .work {
            phaseStart = Date()
            phaseDuration = Double(max(1, cfgInterval))
        } else {
            phaseStart = Date()
            phaseDuration = Double(max(1, cfgRest))
        }
        scheduleCuesForCurrentPhase()

        // Announce round number exactly at the start of WORK (after Auftakt)
        if p == .work {
            let current = repIndex
            if current >= 2 && current < cfgRepeats {
                schedule(0.05) { sounds.playRound(current) }
            }
        }
    }

    private func scheduleCuesForCurrentPhase() {
        guard !finished else { return }
        guard let start = phaseStart else { return }

        // Announce upcoming REST during work; on the last rep, play the countdown and use AUSKLANG at the end.
        if phase == .work {
            let dur = max(1, cfgInterval)
            let isLast = (repIndex >= cfgRepeats)
            let willRest = (cfgRest > 0 && !isLast)

            // Only schedule a countdown if either rest follows or this is the final rep.
            if willRest || isLast {
                let now = Date()
                let elapsed = max(0, now.timeIntervalSince(start) - pausedPhaseAccum)
                func scheduleIfFuture(at targetFromStart: TimeInterval, cue: Cue) {
                    let delay = targetFromStart - elapsed
                    if delay > 0.001 { schedule(delay) { sounds.play(cue) } }
                }

                if dur >= 4 {
                    scheduleIfFuture(at: TimeInterval(dur - 3), cue: .kurz)
                    scheduleIfFuture(at: TimeInterval(dur - 2), cue: .kurz)
                    scheduleIfFuture(at: TimeInterval(dur - 1), cue: .kurz)
                } else if dur == 3 {
                    scheduleIfFuture(at: 2, cue: .kurz)
                } else if dur == 2 {
                    scheduleIfFuture(at: 1, cue: .kurz)
                }

            }
        }
        else if phase == .rest {
            // Pre-roll: play Auftakt so that it ENDS exactly at the next work start
            let aDur = sounds.duration(of: .auftakt)
            let dur = max(1, cfgRest)
            let now = Date()
            let elapsed = max(0, now.timeIntervalSince(start) - pausedPhaseAccum)
            let targetFromStart = max(0, Double(dur) - aDur)
            let delay = targetFromStart - elapsed
            if aDur > 0, aDur < Double(dur) {
                if delay > 0.001 { schedule(delay) { sounds.play(.auftakt) } }
            }
            // (Round announcement scheduling removed)
        }
    }

    private func advance() {
        if finished { return }
        // Take a snapshot of plannedRepeats for this advance (frozen at workout start)
        let cfgRepeats = plannedRepeats
        switch phase {
        case .work:
            // Wenn letzter Satz beendet wurde → Workout fertig
            if repIndex >= cfgRepeats {
                finished = true
                cancelScheduled()
                sounds.play(.ausklang)
                return
            }
            // Sonst: bei vorhandener Erholung lang.cue auf dem Wechsel spielen
            if cfgRest > 0 {
                sounds.play(.lang)
                let next = repIndex + 1
                // Vorletzter → letzter Satz: "last-round" kurz nach lang
                if next == cfgRepeats {
                    sounds.play(.lastRound, after: 0.15) // untracked delay; won't be cancelled by setPhase
                }
                setPhase(.rest)
            } else {
                // Keine Erholung: direkt auf nächsten Satz schalten
                repIndex = min(cfgRepeats, repIndex + 1)
                setPhase(.work)
            }
        case .rest:
            // Erholung beendet → nächster Satz beginnt
            repIndex = min(cfgRepeats, repIndex + 1)
            setPhase(.work)
        }
    }

    private func togglePause() {
        if !isPaused {
            isPaused = true
            pausedAt = Date()
            sounds.stopAll()
            cancelScheduled()
        } else {
            if let p = pausedAt {
                let delta = Date().timeIntervalSince(p)
                pausedSessionAccum += delta
                pausedPhaseAccum += delta
            }
            pausedAt = nil
            isPaused = false
            scheduleCuesForCurrentPhase()
        }
    }
}

// MARK: - WorkoutsView (1:1 Offen-Layout + drittes Wheel)
struct WorkoutsView: View {

    @State private var showSettings = false
    @State private var showRunner = false

    @State private var intervalSec: Int = 30
    @State private var restSec: Int = 10
    @State private var repeats: Int = 10

    // TODO: compute total duration once repetition logic is re-added
    private var totalSeconds: Int {
        // Gesamtdauer ohne Ausklang/Auftakt: (Belastung * Wdh) + (Erholung * (Wdh-1))
        max(0, repeats) * max(0, intervalSec) + max(0, repeats - 1) * max(0, restSec)
    }
    private var totalString: String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // 1:1: identischer Aufbau wie OffenView, nur andere Labels/Werte und ein drittes Wheel
    private var pickerSection: some View {
        HStack(alignment: .center, spacing: 20) {
            // Linke Spalte: Emojis + Labels
            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    Text("🔥").font(.system(size: 50))
                    Text("Belastung").font(.footnote).foregroundStyle(.secondary)
                }
                .frame(height: 90, alignment: .center)
                VStack(spacing: 6) {
                    Text("🧊").font(.system(size: 50))
                    Text("Erholung").font(.footnote).foregroundStyle(.secondary)
                }
                .frame(height: 90, alignment: .center)
                VStack(spacing: 6) {
                    Text("↻").font(.system(size: 50))
                    Text("Wiederholungen").font(.footnote).foregroundStyle(.secondary)
                }
                .frame(height: 90, alignment: .center)
            }
            .frame(minWidth: 110, alignment: .center)

            // Rechte Spalte: Wheel-Picker in exakt derselben Größe wie Offen (160x130)
            VStack(spacing: 24) {
                Picker("Belastung (s)", selection: $intervalSec) {
                    ForEach(0..<601) { v in Text("\(v)").font(.title3).tag(v) }
                }
                .labelsHidden()
                #if os(iOS)
                .pickerStyle(.wheel)
                #else
                .pickerStyle(.automatic)
                #endif
                .frame(width: 144, height: 90)
                .clipped()

                Picker("Erholung (s)", selection: $restSec) {
                    ForEach(0..<601) { v in Text("\(v)").font(.title3).tag(v) }
                }
                .labelsHidden()
                #if os(iOS)
                .pickerStyle(.wheel)
                #else
                .pickerStyle(.automatic)
                #endif
                .frame(width: 144, height: 90)
                .clipped()

                Picker("Wiederholungen", selection: $repeats) {
                    ForEach(1..<201) { v in Text("\(v)").font(.title3).tag(v) }
                }
                .labelsHidden()
                #if os(iOS)
                .pickerStyle(.wheel)
                #else
                .pickerStyle(.automatic)
                #endif
                .frame(width: 144, height: 90)
                .clipped()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var startButton: some View {
        Button(action: {
            showRunner = true
        }) {
            Image(systemName: "play.circle.fill")
                .resizable()
                .frame(width: 86, height: 86)
                .foregroundStyle(.tint)
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    GlassCard {
                        VStack(spacing: 16) {
                            pickerSection
                            HStack {
                                Text("Gesamtdauer")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(totalString)
                                    .font(.footnote)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 2)
                            .padding(.trailing, 20)
                            startButton
                        }
                    }
                    .padding()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape").accessibilityLabel("Einstellungen")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
                #if os(iOS)
                .presentationDetents([.medium, .large])
                #endif
            }
            .fullScreenCover(isPresented: $showRunner) {
                WorkoutRunnerView(intervalSec: intervalSec, restSec: restSec, repeats: $repeats) {
                    showRunner = false
                }
                .ignoresSafeArea()
            }
        }
    }
}

#if DEBUG
#Preview { WorkoutsView() }
#endif

#else
// Fallback for non-iOS analyzers/targets
struct WorkoutsView: View {
    var body: some View { Text("Workouts sind nur auf iOS verfügbar.") }
}
#endif
