//
//  WorkoutsView.swift
//  Meditationstimer
//
//  Rebuilt as 1:1 layout copy of OffenView with three wheels (Belastung/Erholung/Wiederholungen)
//

import SwiftUI
import HealthKit
import AVFoundation

// MARK: - Sound Cues for Workout
private enum Cue: String {
    case kurz       // short tick for countdown (3, 2, 1s before)
    case lang       // long tone on phase switch (work→rest)
    case auftakt    // pre-start cue before first work
    case ausklang   // final chime at end of last work
}

private final class SoundPlayer: ObservableObject {
    private var players: [Cue: AVAudioPlayer] = [:]
    private var prepared = false
    private let speech = AVSpeechSynthesizer()

    func prepare() {
        guard !prepared else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // ignore
        }
        // Try to load each cue from the app bundle. We look for .caf first, then .wav, then .mp3
        for cue in [Cue.kurz, .lang, .auftakt, .ausklang] {
            let name = cue.rawValue
            let exts = ["caf", "wav", "mp3", "aiff"]
            var found: URL? = nil
            for ext in exts {
                if let url = Bundle.main.url(forResource: name, withExtension: ext) { found = url; break }
            }
            if let url = found, let p = try? AVAudioPlayer(contentsOf: url) {
                p.prepareToPlay()
                players[cue] = p
            }
        }
        prepared = true
    }

    func play(_ cue: Cue) {
        prepare()
        if let p = players[cue] {
            p.currentTime = 0
            p.play()
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

// MARK: - HealthKit Manager (simple; start/end; pause/resume no-ops on iOS)
final class HealthKitWorkoutManager: ObservableObject {
    private let healthStore = HKHealthStore()
    private var startDate: Date?

    func requestAuthorizationIfNeeded() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        let typesToRead: Set<HKSampleType> = []
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }

    func start() { startDate = Date() }
    func pause() { /* no-op */ }
    func resume() { /* no-op */ }

    func end(completed: Bool = true) {
        let endDate = Date()
        guard completed, let start = startDate else { startDate = nil; return }
        let workout = HKWorkout(activityType: .highIntensityIntervalTraining, start: start, end: endDate)
        healthStore.save(workout) { _, _ in }
        startDate = nil
    }
}

// MARK: - Workout Runner (identisch zu vorher; kein Layout-Tuning)
private enum WorkoutPhase: String { case work, rest }

private struct WorkoutRunnerView: View {
    let intervalSec: Int
    let restSec: Int
    @Binding var repeats: Int
    let onClose: () -> Void

    @StateObject private var hk = HealthKitWorkoutManager()
    @StateObject private var sounds = SoundPlayer()

    @State private var sessionStart: Date = .now
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
    @State private var isPaused = false
    @State private var pausedAt: Date? = nil
    @State private var pausedSessionAccum: TimeInterval = 0
    @State private var pausedPhaseAccum: TimeInterval = 0
    @State private var phaseEndFired = false
    @State private var repIndex: Int = 1  // 1…repeats
    @State private var plannedRepeats: Int = 0 // snapshot at launch for display

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
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
                        let elapsedSession = max(0, nowEff.timeIntervalSince(sessionStart) - pausedSessionAccum)
                        let progressTotal = max(0.0, min(1.0, elapsedSession / total))

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
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 44))
                        Text("Fertig").font(.subheadline.weight(.semibold))
                    }
                    .onAppear { hk.end(completed: true) }
                }

                Button(isPaused ? "Weiter" : "Pause") {
                    togglePause()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
                .disabled(finished)
            }
            .frame(minWidth: 280, maxWidth: 360)
            .padding(16)
            .overlay(alignment: .topTrailing) {
                Button {
                    hk.end(completed: false)
                    onClose()
                } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .semibold)).frame(width: 28, height: 28)
                }
                .buttonStyle(.borderedProminent).tint(.secondary).clipShape(Circle()).padding(8)
            }
        }
        .task {
            do { try await hk.requestAuthorizationIfNeeded() } catch {}
            sounds.prepare()
            plannedRepeats = max(1, repeats)

            // AUFTAKT: play, then start workout exactly at first work
            let aDur = sounds.duration(of: .auftakt)
            if aDur > 0 {
                sounds.play(.auftakt)
                schedule(aDur) {
                    hk.start()
                    sessionStart = Date()
                    setPhase(.work)
                    scheduleCuesForCurrentPhase()
                }
            } else {
                // No file present → start immediately
                hk.start()
                sessionStart = Date()
                setPhase(.work)
                scheduleCuesForCurrentPhase()
            }
        }
        .onDisappear {
            sounds.stopAll()
            cancelScheduled()
        }
        .onChange(of: phase) { _ in }
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
            phaseDuration = Double(max(1, intervalSec))
        } else {
            phaseStart = Date()
            phaseDuration = Double(max(1, restSec))
        }
        scheduleCuesForCurrentPhase()
    }

    private func scheduleCuesForCurrentPhase() {
        guard !finished else { return }
        guard let start = phaseStart else { return }

        // Only announce upcoming rest during work, and not in the last rep
        if phase == .work && repIndex < repeats && restSec > 0 {
            let dur = max(1, intervalSec)
            // times relative to now
            let now = Date()
            let elapsed = max(0, now.timeIntervalSince(start) - pausedPhaseAccum)
            func scheduleIfFuture(at targetFromStart: TimeInterval, cue: Cue) {
                let delay = targetFromStart - elapsed
                if delay > 0.001 { schedule(delay) { sounds.play(cue) } }
            }
            // 3 × kurz at B-3, B-2, B-1; lang at B
            if dur >= 4 {
                scheduleIfFuture(at: TimeInterval(dur - 3), cue: .kurz)
                scheduleIfFuture(at: TimeInterval(dur - 2), cue: .kurz)
                scheduleIfFuture(at: TimeInterval(dur - 1), cue: .kurz)
            } else if dur == 3 {
                scheduleIfFuture(at: 2, cue: .kurz)
                scheduleIfFuture(at: 3, cue: .lang)
                return
            } else if dur == 2 {
                scheduleIfFuture(at: 1, cue: .kurz)
                scheduleIfFuture(at: 2, cue: .lang)
                return
            }
            scheduleIfFuture(at: TimeInterval(dur), cue: .lang)
        }
    }

    private func advance() {
        if finished { return }
        switch phase {
        case .work:
            // Wenn letzter Satz beendet wurde → Workout fertig
            if repIndex >= repeats {
                finished = true
                cancelScheduled()
                sounds.play(.ausklang)
                return
            }
            // Sonst ggf. in Erholung oder direkt nächste Belastung
            if restSec > 0 {
                setPhase(.rest)
            } else {
                // Keine Erholung: direkt auf nächsten Satz schalten
                repIndex = min(repeats, repIndex + 1)
                setPhase(.work)
            }
        case .rest:
            // Erholung beendet → nächster Satz beginnt
            repIndex = min(repeats, repIndex + 1)
            setPhase(.work)
        }
    }

    private func togglePause() {
        if !isPaused {
            isPaused = true
            pausedAt = Date()
            hk.pause()
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
            hk.resume()
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
                    Text("🔁").font(.system(size: 50))
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
                .labelsHidden().pickerStyle(.wheel)
                .frame(width: 144, height: 90)
                .clipped()

                Picker("Erholung (s)", selection: $restSec) {
                    ForEach(0..<601) { v in Text("\(v)").font(.title3).tag(v) }
                }
                .labelsHidden().pickerStyle(.wheel)
                .frame(width: 144, height: 90)
                .clipped()

                Picker("Wiederholungen", selection: $repeats) {
                    ForEach(1..<201) { v in Text("\(v)").font(.title3).tag(v) }
                }
                .labelsHidden().pickerStyle(.wheel)
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
            .sheet(isPresented: $showSettings) { SettingsSheet().presentationDetents([.medium, .large]) }
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
