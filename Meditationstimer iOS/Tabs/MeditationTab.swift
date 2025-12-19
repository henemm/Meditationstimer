//
//  MeditationTab.swift
//  Meditationstimer iOS
//
//  Created by Claude Code on 15.12.2025.
//
//  Combines OffenView (Free Meditation) and AtemView (Breathing Presets) into a unified tab.
//  Phase 1.1: Flat card structure - all cards visible in a single ScrollView.
//
//  Layout:
//  - ScrollView containing:
//    - OpenMeditationCard (Timer setup at top)
//    - Breathing Preset Rows (all presets visible)
//    - AddPresetCard (create new preset)

import SwiftUI

#if os(iOS)

struct MeditationTab: View {
    @EnvironmentObject var engine: TwoPhaseTimerEngine
    @EnvironmentObject var streakManager: StreakManager
    @EnvironmentObject var liveActivity: LiveActivityController

    // Breathing preset state (from AtemView)
    @State private var presets: [AtemView.Preset] = []
    @State private var showingEditor: AtemView.Preset? = nil
    @State private var showingInfo: AtemView.Preset? = nil
    @State private var runningPreset: AtemView.Preset? = nil
    @State private var showSettings = false

    // Open Meditation state (from OffenView)
    @AppStorage("phase1Minutes") private var phase1Minutes: Int = 10
    @AppStorage("phase2Minutes") private var phase2Minutes: Int = 5
    @State private var sessionStart = Date()
    @State private var showOffenInfo = false

    // Session-related states
    @State private var showHealthAlert = false
    @State private var showConflictAlert: Bool = false
    @State private var conflictOwnerId: String? = nil
    @State private var conflictTitle: String? = nil
    @State private var showLocalConflictAlert: Bool = false
    @State private var lastState: TwoPhaseTimerEngine.State = .idle

    // Audio players
    @State private var gong = GongPlayer()
    @State private var bgAudio = BackgroundAudioKeeper()
    @State private var ambientPlayer = AmbientSoundPlayer()
    @State private var pendingEndStop: DispatchWorkItem?
    @State private var didPlayPhase2Gong = false

    // AppStorage settings
    @AppStorage("logMeditationAsYogaWorkout") private var logMeditationAsYogaWorkout: Bool = false
    @AppStorage("ambientSound") private var ambientSoundRaw: String = AmbientSound.none.rawValue
    @AppStorage("ambientSoundOffenEnabled") private var ambientSoundOffenEnabled: Bool = false
    @AppStorage("ambientSoundVolume") private var ambientSoundVolume: Int = 45
    @AppStorage("countdownBeforeStart") private var countdownBeforeStart: Int = 0
    @State private var showCountdown = false

    private var ambientSound: AmbientSound {
        AmbientSound(rawValue: ambientSoundRaw) ?? .none
    }

    private let presetsKey = "atemPresets"
    private let emojiChoices: [String] = ["🧘","🪷","🌬️","🫁","🌿","🌀","✨","🔷","🔶","💠"]

    // Default presets (same as AtemView)
    private static let defaultPresets: [AtemView.Preset] = [
        .init(name: "Box Breathing", emoji: "🧘", inhale: 4, holdIn: 4, exhale: 4, holdOut: 4, repetitions: 10,
              description: NSLocalizedString("Navy SEAL technique for stress reduction. Proven effective at lowering cortisol levels.", comment: "")),
        .init(name: "Calming Breath", emoji: "🌬️", inhale: 4, holdIn: 0, exhale: 6, holdOut: 0, repetitions: 10,
              description: NSLocalizedString("Activates the parasympathetic nervous system through extended exhalation. Ideal for relaxation.", comment: "")),
        .init(name: "Coherent Breathing", emoji: "💠", inhale: 5, holdIn: 0, exhale: 5, holdOut: 0, repetitions: 12,
              description: NSLocalizedString("Optimizes heart coherence (HRV). Most scientifically studied for cardiovascular health. 6 breaths/min.", comment: "")),
        .init(name: "Deep Calm", emoji: "🪷", inhale: 7, holdIn: 0, exhale: 5, holdOut: 0, repetitions: 8,
              description: NSLocalizedString("Deep calming through gentle rhythm. Promotes mental clarity.", comment: "")),
        .init(name: "Relaxing Breath", emoji: "🌿", inhale: 4, holdIn: 7, exhale: 8, holdOut: 0, repetitions: 10,
              description: NSLocalizedString("Dr. Andrew Weil's sleep technique. Based on Pranayama, calming for stress and anxiety.", comment: "")),
        .init(name: "Rhythmic Breath", emoji: "🫁", inhale: 6, holdIn: 3, exhale: 6, holdOut: 3, repetitions: 8,
              description: NSLocalizedString("Balanced rhythm with brief holds. Balance between activation and relaxation.", comment: ""))
    ]

    private var isSessionActive: Bool {
        if case .phase1 = engine.state { return true }
        if case .phase2 = engine.state { return true }
        return false
    }

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        // MARK: - Open Meditation Card
                        openMeditationCard
                            .padding(.horizontal, 16)

                        // MARK: - Section Divider
                        HStack {
                            Text(NSLocalizedString("Breathing Exercises", comment: "Section title"))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        // MARK: - Breathing Presets
                        ForEach(presets) { preset in
                            AtemView.Row(
                                preset: preset,
                                play: { runningPreset = preset },
                                edit: { showingEditor = preset },
                                showInfo: { showingInfo = preset }
                            )
                            .padding(.horizontal, 16)
                        }

                        // MARK: - Add Preset Card
                        AtemView.AddPresetCard {
                            showingEditor = AtemView.Preset(
                                name: "New Preset",
                                emoji: emojiChoices.randomElement() ?? "🧘",
                                inhale: 4, holdIn: 0, exhale: 4, holdOut: 0, repetitions: 10
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100) // Space for tab bar
                    }
                    .padding(.top, 8)
                }
                .toolbar {
                    if !isSessionActive && runningPreset == nil {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: { showSettings = true }) {
                                Image(systemName: "gearshape")
                                    .accessibilityLabel("Settings")
                            }
                        }
                    }
                }
                .toolbar(isSessionActive || runningPreset != nil ? .hidden : .visible, for: .tabBar)
                .fullScreenCover(isPresented: $showSettings) {
                    SettingsSheet()
                }
                .sheet(isPresented: $showOffenInfo) {
                    InfoSheet(
                        title: "Open Meditation",
                        description: "The two-phase timer helps you practice meditation with a structured approach. Set your meditation duration and an optional closing phase.",
                        usageTips: [
                            "Duration: Main meditation session",
                            "Closing: Wind-down and reflection (optional)",
                            "Gong sounds mark phase transitions",
                            "Sessions are automatically logged in Apple Health",
                            "Timer runs in foreground only"
                        ]
                    )
                }
                .sheet(item: $showingEditor) { preset in
                    AtemView.EditorView(
                        preset: preset,
                        isNew: !presets.contains(where: { $0.id == preset.id }),
                        onSave: { edited in
                            if let i = presets.firstIndex(where: { $0.id == edited.id }) {
                                presets[i] = edited
                            } else {
                                presets.append(edited)
                            }
                            savePresets()
                        },
                        onDelete: { id in
                            if let i = presets.firstIndex(where: { $0.id == id }) {
                                presets.remove(at: i)
                            }
                            savePresets()
                        }
                    )
                }
                .sheet(item: $showingInfo) { preset in
                    AtemView.PresetInfoSheet(preset: preset)
                }
                .onAppear {
                    loadPresets()
                    lastState = engine.state
                    // Fix invalid stored values
                    if phase1Minutes < 1 { phase1Minutes = 10 }
                    if phase2Minutes < 1 { phase2Minutes = 5 }
                }
                .onChange(of: engine.state) { _, newValue in
                    handleEngineStateChange(newValue)
                }
                .alert(NSLocalizedString("Health Access", comment: "Alert title"), isPresented: $showHealthAlert) {
                    Button(NSLocalizedString("Cancel", comment: "Alert button"), role: .cancel) {}
                    Button(NSLocalizedString("Allow", comment: "Alert button")) {
                        Task {
                            do {
                                try await HealthKitManager.shared.requestAuthorization()
                                beginSessionAfterCountdown()
                            } catch {
                                print("HealthKit authorization failed: \(error)")
                            }
                        }
                    }
                } message: {
                    Text(NSLocalizedString("This app can record your meditations in Apple Health to track your progress. Do you want to allow this?", comment: ""))
                }
                .fullScreenCover(isPresented: $showCountdown) {
                    CountdownOverlayView(
                        totalSeconds: countdownBeforeStart,
                        onComplete: {
                            showCountdown = false
                            beginSessionAfterCountdown()
                        },
                        onCancel: {
                            showCountdown = false
                            ambientPlayer.stop()
                        }
                    )
                }
            }
            .modifier(OverlayBackgroundEffect(isDimmed: isSessionActive || runningPreset != nil))

            // MARK: - Open Meditation Session Overlay
            if case .phase1 = engine.state {
                RunCard(title: "Meditation", endDate: engine.phase1EndDate ?? Date(), totalSeconds: phase1Minutes * 60, phase: 1) {
                    Task { await endSession(manual: true) }
                }
                .padding(.horizontal, 20)
                .transition(.scale.combined(with: .opacity))
                .animation(.smooth(duration: 0.3), value: engine.state)
                .zIndex(2)
            } else if case .phase2 = engine.state {
                RunCard(title: NSLocalizedString("Closing", comment: "Phase 2 session title"), endDate: engine.endDate ?? Date(), totalSeconds: phase2Minutes * 60, phase: 2) {
                    Task { await endSession(manual: true) }
                }
                .padding(.horizontal, 20)
                .transition(.scale.combined(with: .opacity))
                .animation(.smooth(duration: 0.3), value: engine.state)
                .zIndex(2)
            }

            // MARK: - Breathing Session Overlay
            if let preset = runningPreset {
                AtemView.SessionCard(preset: preset) { runningPreset = nil }
                    .environmentObject(liveActivity)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(2)
            }
        }
    }

    // MARK: - Open Meditation Card
    private var openMeditationCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    Text(NSLocalizedString("Open Meditation", comment: "Tab title"))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    InfoButton { showOffenInfo = true }
                    Spacer()
                }
                .padding(.horizontal, 4)

                // Picker Section
                HStack(alignment: .center, spacing: 20) {
                    // Left column: Emojis + Labels
                    VStack(spacing: 28) {
                        VStack(spacing: 6) {
                            Text("🧘")
                                .font(.system(size: 56))
                            Text(NSLocalizedString("Duration", comment: "Phase 1 label"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                        }
                        VStack(spacing: 6) {
                            Text("🪷")
                                .font(.system(size: 56))
                            Text(NSLocalizedString("Closing", comment: "Phase 2 label"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                        }
                    }
                    .frame(minWidth: 110, alignment: .center)

                    // Right column: Wheel pickers
                    VStack(spacing: 24) {
                        Picker("Duration (min)", selection: $phase1Minutes) {
                            ForEach(1..<61) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.wheel)
                        .frame(width: 160, height: 130)
                        .clipped()

                        Picker("Closing (min)", selection: $phase2Minutes) {
                            ForEach(1..<61) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.wheel)
                        .frame(width: 160, height: 130)
                        .clipped()
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                // Start Button
                Button(action: startOpenMeditation) {
                    Image(systemName: "play.circle.fill")
                        .resizable()
                        .frame(width: 96, height: 96)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private func startOpenMeditation() {
        Task { @MainActor in
            if !(await HealthKitManager.shared.isAuthorized()) {
                showHealthAlert = true
                return
            }
            guard engine.state == .idle else {
                showLocalConflictAlert = true
                return
            }
            if countdownBeforeStart > 0 {
                if ambientSoundOffenEnabled {
                    ambientPlayer.setVolume(percent: ambientSoundVolume)
                    ambientPlayer.start(sound: ambientSound)
                }
                showCountdown = true
            } else {
                beginSessionAfterCountdown()
            }
        }
    }

    private func beginSessionAfterCountdown() {
        let now = Date()
        engine.start(phase1Minutes: phase1Minutes, phase2Minutes: phase2Minutes)
        guard let phase1End = engine.phase1EndDate else { return }

        let result = liveActivity.requestStart(title: "Meditation", phase: 1, endDate: phase1End, ownerId: "OffenTab")
        switch result {
        case .started, .failed:
            sessionStart = now
            setIdleTimer(true)
            bgAudio.start()
            if ambientSoundOffenEnabled {
                ambientPlayer.setVolume(percent: ambientSoundVolume)
                ambientPlayer.start(sound: ambientSound)
            }
            gong.play(named: "gong-ende")
        case .conflict(let existingOwner, let existingTitle):
            conflictOwnerId = existingOwner
            conflictTitle = existingTitle.isEmpty ? "Another Timer" : existingTitle
            showConflictAlert = true
        }
    }

    private func handleEngineStateChange(_ newValue: TwoPhaseTimerEngine.State) {
        // Phase 1 → Phase 2 transition
        if case .phase1 = lastState, case .phase2 = newValue {
            gong.play(named: "gong-dreimal")
            didPlayPhase2Gong = true
            if let phase2End = engine.endDate {
                Task { await liveActivity.update(phase: 2, endDate: phase2End, isPaused: false) }
            }
        }
        // Direct Phase 2 entry
        else if case .phase2 = newValue, didPlayPhase2Gong == false {
            gong.play(named: "gong-dreimal")
            didPlayPhase2Gong = true
            if let phase2End = engine.endDate {
                Task { await liveActivity.update(phase: 2, endDate: phase2End, isPaused: false) }
            }
        }
        // Natural end
        if newValue == .finished {
            Task { await endSession(manual: false) }
        }
        // Manual end/cancel
        if case .idle = newValue, lastState != .idle, lastState != .finished {
            pendingEndStop?.cancel()
            pendingEndStop = nil
            didPlayPhase2Gong = false
        }
        lastState = newValue
    }

    private func endSession(manual: Bool) async {
        // Log to HealthKit
        if let phase1End = engine.phase1EndDate, sessionStart.distance(to: phase1End) > 5 {
            do {
                if logMeditationAsYogaWorkout {
                    try await HealthKitManager.shared.logWorkout(start: sessionStart, end: phase1End, activity: .yoga)
                } else {
                    try await HealthKitManager.shared.logMindfulness(start: sessionStart, end: phase1End)
                }
            } catch {
                print("HealthKit logging failed: \(error)")
            }
        }

        if !manual {
            gong.play(named: "gong-ende") {
                self.pendingEndStop?.cancel()
                let work = DispatchWorkItem { [bgAudio = self.bgAudio, ambientPlayer = self.ambientPlayer] in
                    bgAudio.stop()
                    ambientPlayer.stop()
                }
                self.pendingEndStop = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
            }
            resetSession(stopAudio: false)
        } else {
            bgAudio.stop()
            ambientPlayer.stop()
            resetSession(stopAudio: false)
        }
    }

    private func resetSession(stopAudio: Bool = true) {
        engine.cancel()
        pendingEndStop?.cancel()
        pendingEndStop = nil
        didPlayPhase2Gong = false
        sessionStart = Date()
        showConflictAlert = false
        conflictOwnerId = nil
        conflictTitle = nil
        showLocalConflictAlert = false
        if stopAudio {
            bgAudio.stop()
            ambientPlayer.stop()
        }
        setIdleTimer(false)
        Task { await liveActivity.end() }
        lastState = .idle
    }

    private func setIdleTimer(_ disabled: Bool) {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = disabled
        #endif
    }

    // MARK: - Preset Persistence

    private func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: presetsKey),
           let decoded = try? JSONDecoder().decode([AtemView.Preset].self, from: data) {
            presets = decoded
            migratePresets()
        } else {
            presets = Self.defaultPresets
        }
    }

    private func migratePresets() {
        var needsSave = false
        for i in 0..<presets.count {
            if let defaultPreset = Self.defaultPresets.first(where: { $0.name == presets[i].name }) {
                if presets[i].description == nil && defaultPreset.description != nil {
                    presets[i].description = defaultPreset.description
                    needsSave = true
                }
            }
        }
        for defaultPreset in Self.defaultPresets {
            if !presets.contains(where: { $0.name == defaultPreset.name }) {
                presets.append(defaultPreset)
                needsSave = true
            }
        }
        if needsSave { savePresets() }
    }

    private func savePresets() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: presetsKey)
        }
    }
}

// MARK: - RunCard (from OffenView)
private struct RunCard: View {
    let title: String
    let endDate: Date
    let totalSeconds: Int
    let phase: Int
    var onEnd: () -> Void

    @State private var currentTime = Date()
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.title3.weight(.semibold))
                .textCase(.uppercase)

            let progress = max(0, min(1, (endDate.timeIntervalSince(currentTime)) / Double(totalSeconds)))
            ZStack {
                CircularRing(progress: progress, lineWidth: 30)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 320, height: 320)
                Text(phase == 1 ? "🧘" : "🪷")
                    .font(.system(size: 64, weight: .semibold))
            }

            Button(NSLocalizedString("End", comment: "Button to end session")) {
                onEnd()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.red)
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                currentTime = Date()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
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

#if DEBUG
#Preview {
    MeditationTab()
        .environmentObject(TwoPhaseTimerEngine())
        .environmentObject(StreakManager())
        .environmentObject(LiveActivityController())
}
#endif

#endif // os(iOS)
