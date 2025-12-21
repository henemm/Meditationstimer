//
//  WorkoutTab.swift
//  Meditationstimer iOS
//
//  Created by Claude Code on 15.12.2025.
//
//  Combines WorkoutsView (Free HIIT) and WorkoutProgramsView into a unified tab.
//  Phase 1.1: Flat card structure - all cards visible in a single ScrollView.
//
//  Layout:
//  - ScrollView containing:
//    - FreeWorkoutCard (HIIT Timer at top)
//    - Workout Program Rows (all programs visible)
//    - AddSetCard (create new program)

import SwiftUI
import HealthKit
import AVFoundation

#if os(iOS)

struct WorkoutTab: View {
    @EnvironmentObject var streakManager: StreakManager
    @EnvironmentObject var liveActivity: LiveActivityController

    // Free Workout state (from WorkoutsView)
    @AppStorage("intervalSec") private var intervalSec: Int = 30
    @AppStorage("restSec") private var restSec: Int = 10
    @AppStorage("repeats") private var repeats: Int = 10
    @State private var showFreeWorkoutRunner = false
    @State private var showHealthAlert = false
    @State private var showFreiInfo = false

    // Workout Programs state (from WorkoutProgramsView)
    @State private var sets: [WorkoutSet] = []
    @State private var showingEditor: WorkoutSet? = nil
    @State private var showingInfo: WorkoutSet? = nil
    @State private var runningSet: WorkoutSet? = nil

    @State private var showSettings = false
    @AppStorage("countdownBeforeStart") private var countdownBeforeStart: Int = 0
    @State private var showCountdown = false

    private let setsKey = "workoutProgramSets"
    private let emojiChoices: [String] = ["💪","🔥","🏃","⚡","🦵","🏃‍♀️","🧘‍♂️","🌱","🤸","🏋️","🚴","⛹️","🤾","🧗"]

    private var totalSeconds: Int {
        max(0, repeats) * max(0, intervalSec) + max(0, repeats - 1) * max(0, restSec)
    }

    private var totalString: String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private var isSessionActive: Bool {
        showFreeWorkoutRunner || runningSet != nil
    }

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        // MARK: - Free Workout Card
                        freeWorkoutCard
                            .padding(.horizontal, 16)

                        // MARK: - Section Divider
                        HStack {
                            Text(NSLocalizedString("Workout Programs", comment: "Section title"))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        // MARK: - Workout Program Rows
                        ForEach(sets) { set in
                            WorkoutProgramsView.WorkoutSetRow(
                                set: set,
                                play: { runningSet = set },
                                edit: { showingEditor = set },
                                showInfo: { showingInfo = set }
                            )
                            .padding(.horizontal, 16)
                        }

                        // MARK: - Add Set Card
                        WorkoutProgramsView.AddSetCard {
                            showingEditor = WorkoutSet(
                                name: NSLocalizedString("New Workout", comment: "Default workout name"),
                                emoji: emojiChoices.randomElement() ?? "💪",
                                phases: [],
                                repetitions: 3
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100) // Space for tab bar
                    }
                    .padding(.top, 8)
                }
                .toolbar {
                    if !isSessionActive {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: { showSettings = true }) {
                                Image(systemName: "gearshape")
                                    .accessibilityLabel("Settings")
                            }
                        }
                    }
                }
                .toolbar(isSessionActive ? .hidden : .visible, for: .tabBar)
                .fullScreenCover(isPresented: $showSettings) {
                    SettingsSheet()
                }
                .sheet(isPresented: $showFreiInfo) {
                    InfoSheet(
                        title: "Free Workout",
                        description: "The free workout offers you a flexible HIIT timer with individually adjustable work and rest phases. You determine the intensity and the number of repetitions.",
                        usageTips: [
                            "Choose work time, rest time, and repetitions",
                            "Work phase: Intense training",
                            "Rest phase: Active or passive break",
                            "Gong signals mark phase transitions",
                            "Activity is automatically logged in Apple Health"
                        ]
                    )
                }
                .sheet(item: $showingEditor) { set in
                    WorkoutProgramsView.SetEditorView(
                        set: set,
                        isNew: !sets.contains(where: { $0.id == set.id }),
                        onSave: { edited in
                            if let i = sets.firstIndex(where: { $0.id == edited.id }) {
                                sets[i] = edited
                            } else {
                                sets.append(edited)
                            }
                            saveSets()
                        },
                        onDelete: { id in
                            if let i = sets.firstIndex(where: { $0.id == id }) {
                                sets.remove(at: i)
                            }
                            saveSets()
                        }
                    )
                }
                .sheet(item: $showingInfo) { set in
                    WorkoutProgramsView.PresetInfoSheet(set: set)
                }
                .onAppear {
                    loadSets()
                    if repeats < 1 { repeats = 10 }
                }
                .alert("Health Access", isPresented: $showHealthAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Allow") {
                        Task {
                            do {
                                try await HealthKitManager.shared.requestAuthorization()
                                if countdownBeforeStart > 0 {
                                    showCountdown = true
                                } else {
                                    showFreeWorkoutRunner = true
                                }
                            } catch {
                                print("HealthKit authorization failed: \(error)")
                            }
                        }
                    }
                } message: {
                    Text("This app can record your workouts in Apple Health to track your progress. Would you like to allow this?")
                }
                .fullScreenCover(isPresented: $showCountdown) {
                    CountdownOverlayView(
                        totalSeconds: countdownBeforeStart,
                        onComplete: {
                            showCountdown = false
                            showFreeWorkoutRunner = true
                        },
                        onCancel: {
                            showCountdown = false
                        }
                    )
                }
            }
            .modifier(OverlayBackgroundEffect(isDimmed: isSessionActive))

            // MARK: - Free Workout Runner Overlay
            if showFreeWorkoutRunner {
                // Dim gradient
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.06), Color.black.opacity(0.28)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(1)

                WorkoutRunnerView(intervalSec: intervalSec, restSec: restSec, repeats: $repeats) {
                    showFreeWorkoutRunner = false
                }
                .environmentObject(liveActivity)
                .transition(.scale.combined(with: .opacity))
                .animation(.smooth(duration: 0.3), value: showFreeWorkoutRunner)
                .zIndex(2)
            }

            // MARK: - Workout Program Session Overlay
            if let set = runningSet {
                // Dim gradient
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.06), Color.black.opacity(0.28)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(1)

                WorkoutProgramsView.WorkoutProgramSessionCard(set: set) {
                    runningSet = nil
                }
                .environmentObject(liveActivity)
                .environmentObject(streakManager)
                .transition(.scale.combined(with: .opacity))
                .zIndex(2)
            }
        }
    }

    // MARK: - Free Workout Card
    private var freeWorkoutCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    Text(NSLocalizedString("Free Workout", comment: "Card title"))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    InfoButton { showFreiInfo = true }
                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)

                // Picker Section
                HStack(alignment: .center, spacing: 20) {
                    // Left column: Emojis + Labels
                    VStack(spacing: 28) {
                        VStack(spacing: 6) {
                            Text("🔥").font(.system(size: 50))
                            Text("Work")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .frame(height: 90, alignment: .center)
                        VStack(spacing: 6) {
                            Text("🧊").font(.system(size: 50))
                            Text("Rest")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .frame(height: 90, alignment: .center)
                        VStack(spacing: 6) {
                            Text("↻").font(.system(size: 50))
                            Text("Repetitions")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .frame(height: 90, alignment: .center)
                    }
                    .frame(minWidth: 110, alignment: .center)

                    // Right column: Wheel pickers
                    VStack(spacing: 24) {
                        Picker("Work (s)", selection: $intervalSec) {
                            ForEach(0..<601) { v in Text("\(v)").font(.title3).tag(v) }
                        }
                        .labelsHidden()
                        .pickerStyle(.wheel)
                        .frame(width: 144, height: 90)
                        .clipped()

                        Picker("Rest (s)", selection: $restSec) {
                            ForEach(0..<601) { v in Text("\(v)").font(.title3).tag(v) }
                        }
                        .labelsHidden()
                        .pickerStyle(.wheel)
                        .frame(width: 144, height: 90)
                        .clipped()

                        Picker("Repetitions", selection: $repeats) {
                            ForEach(1..<201) { v in Text("\(v)").font(.title3).tag(v) }
                        }
                        .labelsHidden()
                        .pickerStyle(.wheel)
                        .frame(width: 144, height: 90)
                        .clipped()
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                // Total Duration
                HStack {
                    Text("Total Duration")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    Text(totalString)
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
                .padding(.trailing, 20)

                // Start Button
                Button(action: startFreeWorkout) {
                    Image(systemName: "play.circle.fill")
                        .resizable()
                        .frame(width: 86, height: 86)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private func startFreeWorkout() {
        Task {
            if await HealthKitManager.shared.isAuthorized() {
                if countdownBeforeStart > 0 {
                    showCountdown = true
                } else {
                    showFreeWorkoutRunner = true
                }
            } else {
                showHealthAlert = true
            }
        }
    }

    // MARK: - Persistence

    private func loadSets() {
        if let data = UserDefaults.standard.data(forKey: setsKey),
           let decoded = try? JSONDecoder().decode([WorkoutSet].self, from: data) {
            sets = decoded
            migrateSets()
        } else {
            sets = defaultWorkoutSets
        }
    }

    private func migrateSets() {
        var needsSave = false
        for defaultSet in defaultWorkoutSets {
            if !sets.contains(where: { $0.name == defaultSet.name }) {
                sets.append(defaultSet)
                needsSave = true
            }
        }
        for i in 0..<sets.count {
            if let defaultSet = defaultWorkoutSets.first(where: { $0.name == sets[i].name }) {
                if sets[i].description == nil && defaultSet.description != nil {
                    sets[i].description = defaultSet.description
                    needsSave = true
                }
            }
        }
        if needsSave { saveSets() }
    }

    private func saveSets() {
        if let data = try? JSONEncoder().encode(sets) {
            UserDefaults.standard.set(data, forKey: setsKey)
        }
    }
}

// MARK: - Sound Cues für Free Workout
private enum Cue: String {
    case countdownTransition = "countdown-transition"
    case auftakt
    case ausklang
}

// MARK: - SoundPlayer für Free Workout (kopiert aus WorkoutProgramsView)
private final class SoundPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    private var urls: [Cue: URL] = [:]
    private var activePlayers: [AVAudioPlayer] = []
    private var prepared = false

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true, options: [])
    }

    func prepare() {
        guard !prepared else { return }
        activateSession()
        print("[Sound] Audio session configured (WorkoutTab)")
        for cue in [Cue.countdownTransition, .auftakt, .ausklang] {
            let name = cue.rawValue
            for ext in ["caff", "caf", "wav", "mp3", "aiff"] {
                if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                    urls[cue] = url
                    print("[Sound] found \(name)")
                    break
                }
            }
        }
        prepared = true
    }

    func play(_ cue: Cue) {
        prepare()
        activateSession()
        guard let url = urls[cue] else {
            print("[Sound] cannot play \(cue.rawValue): URL not found")
            return
        }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.prepareToPlay()
            p.play()
            activePlayers.append(p)
            print("[Sound] play \(cue.rawValue) (active: \(activePlayers.count))")
        } catch {
            print("[Sound] failed: \(cue.rawValue) - \(error)")
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if let idx = activePlayers.firstIndex(where: { $0 === player }) {
            activePlayers.remove(at: idx)
        }
    }

    func duration(of cue: Cue) -> TimeInterval {
        prepare()
        guard let url = urls[cue] else { return 0 }
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return 0 }
        return p.duration
    }

    func stopAll() {
        for p in activePlayers { p.stop() }
        activePlayers.removeAll()
    }
}

// MARK: - WorkoutRunnerView (embedded from WorkoutsView)
private struct WorkoutRunnerView: View {
    let intervalSec: Int
    let restSec: Int
    @Binding var repeats: Int
    let onClose: () -> Void

    @EnvironmentObject private var liveActivity: LiveActivityController
    @StateObject private var sounds = SoundPlayer()
    @State private var workoutStart: Date?
    @State private var sessionStart: Date = .now
    @AppStorage("logWorkoutsAsMindfulness") private var logWorkoutsAsMindfulness: Bool = false

    @State private var phase: IntervalPhase = .work
    @State private var phaseStart: Date? = nil
    @State private var phaseDuration: Double = 1
    @State private var finished = false
    @State private var started = false
    @State private var isPaused = false
    @State private var pausedAt: Date? = nil
    @State private var pausedSessionAccum: TimeInterval = 0
    @State private var pausedPhaseAccum: TimeInterval = 0
    @State private var phaseEndFired = false
    @State private var repIndex: Int = 1
    @State private var plannedRepeats: Int = 0
    @State private var cfgRepeats: Int = 0
    @State private var cfgInterval: Int = 0
    @State private var cfgRest: Int = 0

    private enum IntervalPhase: String { case work, rest }

    private var sessionTotal: TimeInterval {
        let work = intervalSec * repeats
        let rest = max(0, repeats - 1) * restSec
        return TimeInterval(work + rest)
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemGray6).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("\(plannedRepeats) x \(intervalSec)s/\(restSec)s").font(.headline)

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
                                CircularRing(
                                    progress: progressTotal,
                                    lineWidth: 22,
                                    gradient: LinearGradient(
                                        colors: [Color.workoutViolet.opacity(0.8), Color.workoutViolet],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                CircularRing(
                                    progress: fractionPhase,
                                    lineWidth: 14,
                                    gradient: LinearGradient(
                                        colors: [Color.workoutViolet.opacity(0.5), Color.workoutViolet.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .scaleEffect(0.72)
                                Image(systemName: phase == .work ? "flame" : "pause")
                                    .font(.system(size: 64))
                                    .foregroundStyle(Color.workoutViolet)
                            }
                            .frame(width: 320, height: 320)
                            .padding(.top, 6)
                            Text("Set \(repIndex) / \(plannedRepeats) — \(phase == .work ? "Work" : "Rest")")
                                .font(.subheadline)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .onChange(of: fractionPhase) { _, newVal in
                            if newVal >= 1.0 && !phaseEndFired {
                                phaseEndFired = true
                                advance()
                            } else if newVal < 1.0 {
                                phaseEndFired = false
                            }
                        }
                    }
                }

                if !finished {
                    Button(isPaused ? "Continue" : "Pause") {
                        togglePause()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                }
            }
            .frame(minWidth: 280, maxWidth: 360)
            .padding(16)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                Task { await endSession(completed: false) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderedProminent)
            .tint(.secondary)
            .clipShape(Circle())
            .padding(8)
        }
        .task {
            do { try await HealthKitManager.shared.requestAuthorization() } catch {}

            // Sound vorbereiten und Auftakt spielen
            sounds.prepare()
            sounds.play(.auftakt)
            let auftaktDuration = sounds.duration(of: .auftakt)
            let delay = max(0.5, auftaktDuration)

            plannedRepeats = max(1, repeats)
            cfgRepeats = plannedRepeats
            cfgInterval = intervalSec
            cfgRest = restSec
            setIdleTimer(true)

            // Warte auf Auftakt-Ende, dann starte Workout
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            started = true
            sessionStart = Date()
            workoutStart = sessionStart
            let endDate = sessionStart.addingTimeInterval(sessionTotal)
            let _ = liveActivity.requestStart(title: "Workout", phase: 1, endDate: endDate, ownerId: "WorkoutsTab")
            setPhase(.work)
        }
        .onDisappear {
            sounds.stopAll()
            setIdleTimer(false)
        }
    }

    private func setIdleTimer(_ disabled: Bool) {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = disabled
        #endif
    }

    private func setPhase(_ p: IntervalPhase) {
        phase = p
        pausedPhaseAccum = 0
        phaseEndFired = false
        phaseStart = Date()
        phaseDuration = Double(p == .work ? max(1, cfgInterval) : max(1, cfgRest))

        let phaseNumber = p == .work ? 1 : 2
        let now = Date()
        let elapsedSession = started ? max(0, now.timeIntervalSince(sessionStart) - pausedSessionAccum) : 0
        let remaining = max(0, sessionTotal - elapsedSession)
        let updatedEndDate = now.addingTimeInterval(remaining)
        Task { await liveActivity.update(phase: phaseNumber, endDate: updatedEndDate, isPaused: isPaused) }
    }

    private func advance() {
        if finished { return }
        switch phase {
        case .work:
            if repIndex >= cfgRepeats {
                finished = true
                Task { await endSession(completed: true) }
                return
            }
            if cfgRest > 0 {
                setPhase(.rest)
            } else {
                repIndex = min(cfgRepeats, repIndex + 1)
                setPhase(.work)
            }
        case .rest:
            repIndex = min(cfgRepeats, repIndex + 1)
            setPhase(.work)
        }
    }

    private func togglePause() {
        if !isPaused {
            isPaused = true
            pausedAt = Date()
        } else {
            if let p = pausedAt {
                let delta = Date().timeIntervalSince(p)
                pausedSessionAccum += delta
                pausedPhaseAccum += delta
            }
            pausedAt = nil
            isPaused = false
        }
    }

    @MainActor
    private func endSession(completed: Bool) async {
        setIdleTimer(false)
        let endDate = Date()
        if let start = workoutStart {
            Task.detached(priority: .userInitiated) { [logWorkoutsAsMindfulness] in
                do {
                    if logWorkoutsAsMindfulness {
                        try await HealthKitManager.shared.logMindfulness(start: start, end: endDate)
                    } else {
                        try await HealthKitManager.shared.logWorkout(start: start, end: endDate, activity: HKWorkoutActivityType.highIntensityIntervalTraining)
                    }
                } catch {}
            }
        }
        await liveActivity.end(immediate: true)
        onClose()
    }
}

// MARK: - OverlayBackgroundEffect
private struct OverlayBackgroundEffect: ViewModifier {
    let isDimmed: Bool
    func body(content: Content) -> some View {
        content
            .blur(radius: isDimmed ? 6 : 0)
            .saturation(isDimmed ? 0.95 : 1)
            .brightness(isDimmed ? -0.02 : 0)
            .animation(.smooth(duration: 0.3), value: isDimmed)
            .allowsHitTesting(!isDimmed)
    }
}

// MARK: - Default Workout Sets (same as WorkoutProgramsView)
private let defaultWorkoutSets: [WorkoutSet] = [
    WorkoutSet(
        name: "Tabata Classic",
        emoji: "🔥",
        phases: [
            WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
            WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
            WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
            WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
            WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
            WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
            WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
            WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 0),
        ],
        repetitions: 1,
        description: NSLocalizedString("Original Tabata protocol (Izumi Tabata, 1996): 8 rounds of 20s maximum intensity / 10s rest.", comment: "")
    ),
    WorkoutSet(
        name: "Core Circuit",
        emoji: "💪",
        phases: [
            WorkoutPhase(name: "Planke", workDuration: 45, restDuration: 15),
            WorkoutPhase(name: "Seitliche Planke links", workDuration: 30, restDuration: 15),
            WorkoutPhase(name: "Seitliche Planke rechts", workDuration: 30, restDuration: 15),
            WorkoutPhase(name: "Fahrrad-Crunches", workDuration: 40, restDuration: 15),
            WorkoutPhase(name: "Beinheben", workDuration: 30, restDuration: 15),
            WorkoutPhase(name: "Russian Twists", workDuration: 40, restDuration: 10),
        ],
        repetitions: 3,
        description: NSLocalizedString("Focuses on core stability and rotational strength.", comment: "")
    ),
    WorkoutSet(
        name: "Full Body Burn",
        emoji: "🏃",
        phases: [
            WorkoutPhase(name: "Burpees", workDuration: 30, restDuration: 20),
            WorkoutPhase(name: "Kniebeugen", workDuration: 40, restDuration: 20),
            WorkoutPhase(name: "Liegestütze", workDuration: 30, restDuration: 20),
            WorkoutPhase(name: "Mountain Climbers", workDuration: 30, restDuration: 20),
            WorkoutPhase(name: "Ausfallschritte", workDuration: 40, restDuration: 20),
            WorkoutPhase(name: "Planke", workDuration: 45, restDuration: 10),
        ],
        repetitions: 3,
        description: NSLocalizedString("Full-body HIIT focused on functional movement patterns.", comment: "")
    ),
    WorkoutSet(
        name: "Quick Burn",
        emoji: "🔥",
        phases: [
            WorkoutPhase(name: "Burpees", workDuration: 30, restDuration: 15),
            WorkoutPhase(name: "Mountain Climbers", workDuration: 30, restDuration: 15),
            WorkoutPhase(name: "Hampelmänner", workDuration: 30, restDuration: 15),
            WorkoutPhase(name: "Planke", workDuration: 30, restDuration: 0),
        ],
        repetitions: 3,
        description: NSLocalizedString("Compact 6-minute workout for maximum efficiency.", comment: "")
    ),
]

#if DEBUG
#Preview {
    WorkoutTab()
        .environmentObject(StreakManager())
        .environmentObject(LiveActivityController())
}
#endif

#endif // os(iOS)
