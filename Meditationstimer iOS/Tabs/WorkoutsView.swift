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
    case takt       // short tick for countdown (3, 2)
    case lang       // longer tone for the final 1
    case auftakt    // start cue when work begins
    case ausklang   // end of work / transition to rest
    case abschluss  // workout finished
    case lastRound  // voice-like cue for final round
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
        for cue in [Cue.takt, .lang, .auftakt, .ausklang, .abschluss, .lastRound] {
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

    func duration(of cue: Cue) -> TimeInterval {
        prepare()
        return players[cue]?.duration ?? 0
    }
}

// MARK: - HealthKit Manager (minimal HIIT start/stop)
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
    let repeats: Int
    let onClose: () -> Void

    @StateObject private var hk = HealthKitWorkoutManager()
    @StateObject private var sounds = SoundPlayer()

    @State private var sessionStart: Date = .now
    private var sessionTotal: TimeInterval {
        let work = intervalSec * repeats
        let rest = max(0, repeats - 1) * restSec
        return TimeInterval(work + rest)
    }

    @State private var phaseStart: Date? = nil
    @State private var phaseDuration: Double = 1
    @State private var phase: WorkoutPhase = .work
    @State private var rep: Int = 1
    @State private var finished = false

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Intervall-Workout").font(.headline)
                Text("HIIT • \(repeats) Sätze • \(intervalSec)s / \(restSec)s")
                    .font(.footnote).foregroundStyle(.secondary)

                if !finished {
                    TimelineView(.animation) { ctx in
                        let now = ctx.date
                        let total = max(0.001, sessionTotal)
                        let elapsedSession = now.timeIntervalSince(sessionStart)
                        let progressTotal = max(0.0, min(1.0, elapsedSession / total))

                        let dur = max(0.001, phaseDuration)
                        let start = phaseStart ?? now
                        let elapsedInPhase = max(0, now.timeIntervalSince(start))
                        let fractionPhase = max(0.0, min(1.0, elapsedInPhase / dur))

                        VStack(spacing: 8) {
                            ZStack {
                                CircularRing(progress: progressTotal, lineWidth: 22).foregroundStyle(.tint)
                                CircularRing(progress: fractionPhase, lineWidth: 14).scaleEffect(0.72).foregroundStyle(.secondary)
                                Image(systemName: iconName(for: phase)).font(.system(size: 64)).foregroundStyle(.tint)
                            }
                            .frame(width: 320, height: 320)
                            .padding(.top, 6)
                            Text("Satz \(rep) / \(repeats) – \(label(for: phase))")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        .onChange(of: Int(fractionPhase >= 1.0 ? 1 : 0)) { newValue in
                            if newValue == 1 { advance() }
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 44))
                        Text("Fertig").font(.subheadline.weight(.semibold))
                    }
                    .onAppear { hk.end(completed: true) }
                }

                Button("Beenden") {
                    hk.end(completed: false)
                    onClose()
                }
                .buttonStyle(.borderedProminent).tint(.red).controlSize(.large)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
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
            sessionStart = .now
            do { try await hk.requestAuthorizationIfNeeded() } catch {}
            hk.start()
            sounds.prepare()
            setPhase(.work)
        }
        .onChange(of: phase) { _ in
            phaseStart = Date()
            switch phase {
            case .work: phaseDuration = Double(max(1, intervalSec))
            case .rest: phaseDuration = Double(max(1, restSec))
            }
        }
    }

    private func iconName(for phase: WorkoutPhase) -> String { phase == .work ? "flame" : "pause" }
    private func label(for phase: WorkoutPhase) -> String { phase == .work ? "Belastung" : "Erholung" }

    /// Schedule a 3-2-1 countdown before a work phase and return the delay to apply before starting the ring.
    private func scheduleWorkCountdown() -> TimeInterval {
        // 3-2-1-los: 3x takt? The user suggested 3x takt and once lang; we do two takt (3,2), lang for 1, then auftakt at start.
        // Play ticks at t+0, t+1, final at t+2, then start cue at t+3.
        sounds.play(.takt,    after: 0.0) // 3
        sounds.play(.takt,    after: 1.0) // 2
        sounds.play(.lang,    after: 2.0) // 1 (longer)
        sounds.play(.auftakt, after: 3.0) // start of work
        return 3.0
    }

    private func setPhase(_ p: WorkoutPhase) {
        phase = p

        if p == .work {
            // Compute pre-delay: optional last-round cue, then auftakt; phase starts after both finished
            var preDelay: TimeInterval = 0
            if rep >= repeats { // entering the final work interval
                sounds.play(.lastRound)
                preDelay += sounds.duration(of: .lastRound)
            }
            // Play auftakt and add its duration to preDelay
            sounds.play(.auftakt, after: preDelay)
            preDelay += sounds.duration(of: .auftakt)

            // Start timing after preDelay so the ring begins when the cue finishes
            phaseStart = Date().addingTimeInterval(preDelay)
            phaseDuration = Double(max(1, intervalSec))

            // Schedule 3x kurz (takt), 1x lang toward the END of Belastung, aligned to the delayed start
            let dur = phaseDuration
            if dur > 3 { sounds.play(.takt, after: preDelay + dur - 3) }
            if dur > 2 { sounds.play(.takt, after: preDelay + dur - 2) }
            if dur > 1 { sounds.play(.lang, after: preDelay + dur - 1) }
        } else {
            // Rest phase starts immediately, no pre-delay
            phaseStart = Date()
            phaseDuration = Double(max(1, restSec))
        }
    }

    private func advance() {
        if phase == .work {
            if restSec > 0 {
                setPhase(.rest)
            } else {
                advanceRepOrFinish()
            }
        } else {
            advanceRepOrFinish()
        }
    }

    private func advanceRepOrFinish() {
        if rep >= repeats {
            sounds.play(.abschluss)
            finished = true
        } else {
            rep += 1
            setPhase(.work)
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

    private var totalSeconds: Int { repeats * intervalSec + max(0, repeats - 1) * restSec }
    private var totalString: String { String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60) }

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
                Picker("Belastung (s)", selection: $intervalSec) { ForEach(0..<601) { Text("\($0)").font(.title3) } }
                    .labelsHidden().pickerStyle(.wheel)
                    .frame(width: 144, height: 90)
                    .clipped()

                Picker("Erholung (s)", selection: $restSec) { ForEach(0..<601) { Text("\($0)").font(.title3) } }
                    .labelsHidden().pickerStyle(.wheel)
                    .frame(width: 144, height: 90)
                    .clipped()

                Picker("Wiederholungen", selection: $repeats) { ForEach(1..<201) { Text("\($0)").font(.title3) } }
                    .labelsHidden().pickerStyle(.wheel)
                    .frame(width: 144, height: 90)
                    .clipped()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var startButton: some View {
        Button(action: { showRunner = true }) {
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
                WorkoutRunnerView(intervalSec: intervalSec, restSec: restSec, repeats: repeats) {
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
