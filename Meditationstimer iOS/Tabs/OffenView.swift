//
//  OffenView.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 27.09.25.
//

// MARK: - AI ORIENTATION (Read me first)
// Purpose:
//   OffenView manages the "Offen" tab - a flexible two-phase meditation timer.
//   Users set custom durations for Phase 1 (Meditation) and Phase 2 (Besinnung/Reflection).
//   Features Live Activity integration, gong sounds, and HealthKit logging.
//
// Files & Responsibilities (where to look next):
//   • TwoPhaseTimerEngine   – Timer state machine and countdown logic
//   • CircularRing.swift    – Progress ring visual component
//   • GongPlayer.swift      – Audio playback system
//   • BackgroundAudioKeeper – Keeps audio session alive during meditation
//   • SessionManager.swift  – Live Activity (Dynamic Island) management
//   • HealthKitManager      – Logs completed sessions to Apple Health
//   • SettingsSheet.swift   – Shared settings UI
//
// Control Flow (high level):
//   1. User sets phase durations with wheel pickers
//   2. Start button → plays gong, starts timer engine, creates Live Activity
//   3. Phase 1 overlay → circular progress, time remaining, manual end option
//   4. Automatic phase transition → triple gong, updates Live Activity
//   5. Phase 2 overlay → separate progress ring, different title
//   6. Natural/manual end → final gong, logs to HealthKit, cleanup
//
// State Management:
//   • @AppStorage: phase1Minutes, phase2Minutes (persistent settings)
//   • @State: sessionStart, UI states, Live Activity reference
//   • @EnvironmentObject: TwoPhaseTimerEngine (from ContentView)
//
// Audio Strategy:
//   • BackgroundAudioKeeper: prevents iOS from killing audio during meditation
//   • GongPlayer: plays start, transition, and end sounds
//   • Careful timing to avoid audio conflicts with phase transitions
//
// HealthKit Integration:
//   • Logs only Phase 1 duration as "Mindfulness" session
//   • Both manual end and natural completion trigger logging
//   • Error handling with graceful fallback (no UI blocking)

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Live Activity integration for Dynamic Island
#if os(iOS)
import AVFoundation
#endif

#if !os(iOS)
struct OffenView: View { var body: some View { Text("Open is only available on iOS.") } }
#else

struct OffenView: View {
    // Zentrale Reset-Funktion für alle States, Timer, WorkItems, Audio, LiveActivity
    // stopAudio: false wenn Audio bereits extern gestoppt wurde (z.B. nach End-Gong)
    // logPartialSession: true wenn abgebrochene Session trotzdem geloggt werden soll (min 60s Phase 1)
    private func resetSession(stopAudio: Bool = true, logPartialSession: Bool = false) {
        // 1. HealthKit Logging bei vorzeitigem Abbruch (wenn gewünscht)
        if logPartialSession, let phase1End = engine.phase1EndDate {
            let elapsed = sessionStart.distance(to: phase1End)
            if elapsed >= 60 { // Min 1 Minute für Logging
                Task {
                    do {
                        if logMeditationAsYogaWorkout {
                            try await HealthKitManager.shared.logWorkout(start: sessionStart, end: phase1End, activity: .yoga)
                        } else {
                            try await HealthKitManager.shared.logMindfulness(start: sessionStart, end: phase1End)
                        }
                        print("[OffenView] Partial session logged: \(Int(elapsed))s")
                    } catch {
                        print("[OffenView] Partial session logging failed: \(error)")
                    }
                }
            } else {
                print("[OffenView] Partial session too short for logging: \(Int(elapsed))s")
            }
        }

        // 2. Cleanup (wie bisher)
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
        print("[DBG] resetSession: alle States und Tasks zurückgesetzt (stopAudio=\(stopAudio), logPartialSession=\(logPartialSession))")
    }
    @AppStorage("phase1Minutes") private var phase1Minutes: Int = 10
    @AppStorage("phase2Minutes") private var phase2Minutes: Int = 5

    @State private var sessionStart = Date()
    @State private var showSettings = false
    @State private var showingCalendar = false
    @State private var showingNoAlcLog = false
    @State private var showOffenInfo = false

    @EnvironmentObject var engine: TwoPhaseTimerEngine
    @State private var lastState: TwoPhaseTimerEngine.State = .idle
    @EnvironmentObject private var liveActivity: LiveActivityController
    @EnvironmentObject private var streakManager: StreakManager
    @State private var showConflictAlert: Bool = false
    @State private var conflictOwnerId: String? = nil
    @State private var conflictTitle: String? = nil
    @State private var showLocalConflictAlert: Bool = false
    @State private var notifier = BackgroundNotifier()
    @State private var gong = GongPlayer()
    @State private var bgAudio = BackgroundAudioKeeper()
    @State private var ambientPlayer = AmbientSoundPlayer()
    @State private var didPlayPhase2Gong = false
    @State private var pendingEndStop: DispatchWorkItem?
    @State private var showHealthAlert = false
    @AppStorage("logMeditationAsYogaWorkout") private var logMeditationAsYogaWorkout: Bool = false
    @AppStorage("ambientSound") private var ambientSoundRaw: String = AmbientSound.none.rawValue
    @AppStorage("ambientSoundOffenEnabled") private var ambientSoundOffenEnabled: Bool = false
    @AppStorage("ambientSoundVolume") private var ambientSoundVolume: Int = 45

    private var ambientSound: AmbientSound {
        AmbientSound(rawValue: ambientSoundRaw) ?? .none
    }

    private var isSessionActive: Bool {
        if case .phase1 = engine.state { return true }
        if case .phase2 = engine.state { return true }
        return false
    }

    private var pickerSection: some View {
        HStack(alignment: .center, spacing: 20) {
            // Linke Spalte: Emojis + Labels
            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    Text("🧘")
                        .font(.system(size: 56))
                    Text("Meditation")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 6) {
                    Text("🪷")
                        .font(.system(size: 56))
                    Text("Contemplation")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 110, alignment: .center)

            // Rechte Spalte: große Wheel-Picker für Zeiten
            VStack(spacing: 24) {
                Picker("Meditation (min)", selection: $phase1Minutes) {
                    ForEach(0..<61) { Text("\($0)") }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                .frame(width: 160, height: 130)
                .clipped()

                Picker("Contemplation (min)", selection: $phase2Minutes) {
                    ForEach(0..<61) { Text("\($0)") }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                .frame(width: 160, height: 130)
                .clipped()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
                    .alert(isPresented: $showConflictAlert) {
                conflictAlert
            }
            .alert(isPresented: $showLocalConflictAlert) {
                localConflictAlert
            }
            .alert("Health Access", isPresented: $showHealthAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Allow") {
                    Task {
                        do {
                            try await HealthKitManager.shared.requestAuthorization()
                            // After authorization, proceed with start
                            Task { @MainActor in
                                // Copy the start logic here
                                guard engine.state == .idle else {
                                    showLocalConflictAlert = true
                                    return
                                }
                                let now = Date()
                                engine.start(phase1Minutes: phase1Minutes, phase2Minutes: phase2Minutes)
                                guard let phase1End = engine.phase1EndDate else { return }
                                let result = liveActivity.requestStart(title: "Meditation", phase: 1, endDate: phase1End, ownerId: "OffenTab")
                                switch result {
                                case .started:
                                    sessionStart = now
                                    setIdleTimer(true)
                                    bgAudio.start()
                                    if ambientSoundOffenEnabled {
                                        ambientPlayer.setVolume(percent: ambientSoundVolume)
                                        ambientPlayer.start(sound: ambientSound)
                                    }
                                    gong.play(named: "gong-ende")
                                    engine.start(phase1Minutes: phase1Minutes, phase2Minutes: phase2Minutes)
                                case .conflict(let existingOwner, let existingTitle):
                                    conflictOwnerId = existingOwner
                                    conflictTitle = existingTitle.isEmpty ? "Another Timer" : existingTitle
                                    showConflictAlert = true
                                case .failed:
                                    sessionStart = now
                                    setIdleTimer(true)
                                    bgAudio.start()
                                    if ambientSoundOffenEnabled {
                                        ambientPlayer.setVolume(percent: ambientSoundVolume)
                                        ambientPlayer.start(sound: ambientSound)
                                    }
                                    gong.play(named: "gong-ende")
                                    engine.start(phase1Minutes: phase1Minutes, phase2Minutes: phase2Minutes)
                                }
                            }
                        } catch {
                            print("HealthKit authorization failed: \(error)")
                        }
                    }
                }
            } message: {
                Text("This app can record your meditations in Apple Health to track your progress. Do you want to allow this?")
            }
    }

    private var startButton: some View {
        Button(action: {
            Task { @MainActor in
                if !(await HealthKitManager.shared.isAuthorized()) {
                    showHealthAlert = true
                    return
                }
                // Wenn Engine läuft, verhindere doppelten Start
                guard engine.state == .idle else {
                    showLocalConflictAlert = true
                    return
                }
                // Engine bestimmt Endzeit, keine lokale Berechnung mehr
                let now = Date()
                engine.start(phase1Minutes: phase1Minutes, phase2Minutes: phase2Minutes)
                guard let phase1End = engine.phase1EndDate else { return }
                let result = liveActivity.requestStart(title: "Meditation", phase: 1, endDate: phase1End, ownerId: "OffenTab")
                switch result {
                case .started:
                    // Proceed to start local engine and audio
                    sessionStart = now
                    setIdleTimer(true)
                    bgAudio.start()
                    if ambientSoundOffenEnabled {
                        ambientPlayer.setVolume(percent: ambientSoundVolume)
                        ambientPlayer.start(sound: ambientSound)
                    }
                    gong.play(named: "gong-ende")
                    engine.start(phase1Minutes: phase1Minutes, phase2Minutes: phase2Minutes)
                case .conflict(let existingOwner, let existingTitle):
                    conflictOwnerId = existingOwner
                    conflictTitle = existingTitle.isEmpty ? "Another Timer" : existingTitle
                    showConflictAlert = true
                case .failed:
                    // If Activity start failed, we still allow the engine to start locally
                    sessionStart = now
                    setIdleTimer(true)
                    bgAudio.start()
                    if ambientSoundOffenEnabled {
                        ambientPlayer.setVolume(percent: ambientSoundVolume)
                        ambientPlayer.start(sound: ambientSound)
                    }
                    gong.play(named: "gong-ende")
                    engine.start(phase1Minutes: phase1Minutes, phase2Minutes: phase2Minutes)
                }
            }
        }) {
            Image(systemName: "play.circle.fill")
                .resizable()
                .frame(width: 96, height: 96)
                .foregroundStyle(.tint)
        }
        .buttonStyle(.plain)
    }

    // Alert for existing timer conflict
    private var conflictAlert: Alert {
        Alert(
            title: Text("Another Timer Running"),
            message: Text(String(format: "The timer '%@' is already running. Should it be stopped and the new one started?", conflictTitle ?? "Active Timer")),
            primaryButton: .destructive(Text("Stop & Start Timer"), action: {
                // Force start now
                if let phase1End = engine.phase1EndDate {
                    liveActivity.forceStart(title: "Meditation", phase: 1, endDate: phase1End, ownerId: "OffenTab")
                }
            }),
            secondaryButton: .cancel(Text("Cancel"))
        )
    }

    // Local alert when engine.state != .idle and user presses Start
    private var localConflictAlert: Alert {
        Alert(
            title: Text("Session Already Running"),
            message: Text("A session is already running. Should it be stopped and the new one started?"),
            primaryButton: .destructive(Text("Stop & Start"), action: {
                Task { @MainActor in
                    // End current session and start fresh
                    await liveActivity.end()
                    engine.cancel()
                    // Start new one immediately (reuse start flow)
                    sessionStart = Date()
                    setIdleTimer(true)
                    bgAudio.start()
                    if ambientSoundOffenEnabled {
                        ambientPlayer.setVolume(percent: ambientSoundVolume)
                        ambientPlayer.start(sound: ambientSound)
                    }
                    gong.play(named: "gong-ende")
                    engine.start(phase1Minutes: phase1Minutes, phase2Minutes: phase2Minutes)
                    if let sessionEnd = engine.endDate {
                        liveActivity.forceStart(title: "Meditation", phase: 1, endDate: sessionEnd, ownerId: "OffenTab")
                    }
                }
            }),
            secondaryButton: .cancel(Text("Cancel"))
        )
    }

    private func phaseView(title: String, remaining: Int, total: Int) -> some View {
        let totalSafe = max(1, total)
        let progress = Double(remaining) / Double(totalSafe)
        return VStack(spacing: 12) {
            Text(title).font(.headline)
            ZStack {
                CircularRing(progress: progress, lineWidth: 30)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 320, height: 320)
                Text(format(remaining))
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: 360)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Base (idle & finished)
                VStack {
                    GlassCard {
                        VStack(spacing: 16) {
                            HStack(spacing: 8) {
                                Text("Open Meditation")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                InfoButton { showOffenInfo = true }
                                Spacer()
                            }
                            .padding(.horizontal, 4)

                            switch engine.state {
                            case .idle, .finished:
                                pickerSection
                                startButton
                            case .phase1, .phase2:
                                // The active states are handled by the overlay run card below
                                EmptyView()
                            }
                        }
                    }
                    .padding()
                }
                .modifier(OverlayBackgroundEffect(isDimmed: isSessionActive))

                // Overlay for active session (phase1/phase2)
                if case .phase1 = engine.state {
                    RunCard(title: "Meditation", endDate: engine.phase1EndDate ?? Date(), totalSeconds: phase1Minutes * 60) {
                        Task { await endSession(manual: true) }
                    }
                    .padding(.horizontal, 20)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.smooth(duration: 0.3), value: engine.state)
                    .zIndex(2)
                } else if case .phase2 = engine.state {
                    RunCard(title: "Contemplation", endDate: engine.endDate ?? Date(), totalSeconds: phase2Minutes * 60) {
                        Task { await endSession(manual: true) }
                    }
                    .padding(.horizontal, 20)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.smooth(duration: 0.3), value: engine.state)
                    .zIndex(2)
                }
            }
            .toolbar {
                if engine.state == .idle || engine.state == .finished {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button { showingNoAlcLog = true } label: { Image(systemName: "drop.fill") }
                        Button { showingCalendar = true } label: { Image(systemName: "calendar") }
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape")
                                .accessibilityLabel("Settings")
                        }
                    }
                }
            }
            .toolbar(engine.state != .idle && engine.state != .finished ? .hidden : .visible, for: .tabBar)
            .fullScreenCover(isPresented: $showSettings) {
                SettingsSheet()
            }
            .fullScreenCover(isPresented: $showingCalendar) {
                CalendarView()
                    .environmentObject(streakManager)
            }
            .sheet(isPresented: $showingNoAlcLog) {
                NoAlcLogSheet()
            }
            .sheet(isPresented: $showOffenInfo) {
                InfoSheet(
                    title: "Open Meditation",
                    description: "The two-phase timer helps you practice meditation with a structured approach. Choose your meditation duration and an optional contemplation phase.",
                    usageTips: [
                        "Phase 1: Main meditation session",
                        "Phase 2: Reflection and contemplation (optional)",
                        "Gong sounds mark phase transitions",
                        "Sessions are automatically logged in Apple Health",
                        "Timer runs in foreground only"
                    ]
                )
            }
            .onChange(of: engine.state) { _, newValue in
                // Übergang Phase 1 -> Phase 2: dreifacher Gong und Live Activity auf Phase 2 updaten
                if case .phase1 = lastState, case .phase2 = newValue {
                    gong.play(named: "gong-dreimal")
                    didPlayPhase2Gong = true
                    // Debug: show engine dates at transition
                    print("DBG TRANSITION: now=\(Date()), phase1End=\(String(describing: engine.phase1EndDate)), engine.endDate=\(String(describing: engine.endDate)), phase2Minutes=\(phase2Minutes)")
                    // Update Live Activity for Phase 2 with staleDate to ensure background updates work
                    if let phase2End = engine.endDate {
                        Task {
                            await liveActivity.update(phase: 2, endDate: phase2End, isPaused: false)
                            print("🔔 [OffenView] Live Activity UPDATE: Phase 2, endDate=\(phase2End)")
                        }
                    }
                }
                // Fallback: Wenn wir ohne vorherige phase1 direkt in phase2 eintreten (z. B. phase1Minutes == 0), trotzdem den Dreifach-Gong spielen – aber nur einmal
                else if case .phase2 = newValue, didPlayPhase2Gong == false {
                    // Direkter Einstieg in Phase 2 (z. B. wenn phase1Minutes == 0)
                    gong.play(named: "gong-dreimal")
                    didPlayPhase2Gong = true
                    // Update Live Activity for Phase 2 directly
                    if let phase2End = engine.endDate {
                        Task {
                            await liveActivity.update(phase: 2, endDate: phase2End, isPaused: false)
                            print("🔔 [OffenView] Live Activity UPDATE: Direct Phase 2, endDate=\(phase2End)")
                        }
                    }
                }
                // Natürliches Ende
                if newValue == .finished {
                    Task { await endSession(manual: false) }
                }
                // Manuelles Ende oder Abbruch
                if case .idle = newValue, lastState != .idle, lastState != .finished {
                    pendingEndStop?.cancel()
                    pendingEndStop = nil
                    didPlayPhase2Gong = false
                }
                lastState = newValue
            }
            .onAppear { lastState = engine.state }
            .onAppear {
                notifier.start()
            }
            .onDisappear {
                notifier.stop()
                resetSession(logPartialSession: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .startMeditationSession)) { _ in
                Task { @MainActor in
                    print("[OffenView] Received startMeditationSession notification")
                    // Auto-end any running session (requirement 3A)
                    if engine.state != .idle {
                        await liveActivity.end()
                        engine.cancel()
                    }
                    // Start new session
                    startMeditationSession()
                }
            }
        }
    }

    private func format(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    private func setIdleTimer(_ disabled: Bool) {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = disabled
        #endif
    }
    
    private func startMeditationSession() {
        Task { @MainActor in
            if !(await HealthKitManager.shared.isAuthorized()) {
                showHealthAlert = true
                return
            }
            // Engine should be idle at this point (already cleaned up)
            let now = Date()
            engine.start(phase1Minutes: phase1Minutes, phase2Minutes: phase2Minutes)
            guard let phase1End = engine.phase1EndDate else { return }

            // Force start (conflict already handled above)
            liveActivity.forceStart(title: "Meditation", phase: 1, endDate: phase1End, ownerId: "OffenTab")
            sessionStart = now
            setIdleTimer(true)
            bgAudio.start()
            if ambientSoundOffenEnabled {
                ambientPlayer.setVolume(percent: ambientSoundVolume)
                ambientPlayer.start(sound: ambientSound)
            }
            gong.play(named: "gong-ende")
            print("[OffenView] Session started via Shortcut")
        }
    }

    private func endSession(manual: Bool) async {
    #if DEBUG
    print("DBG endSession: invoked manual=\(manual) engine.state=\(engine.state) owner=\(liveActivity.ownerId ?? "nil") ownerTitle=\(liveActivity.ownerTitle ?? "")")
    #endif
        // 1. Log Health entry - nur Phase 1 (Meditation), nicht die Besinnung
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

        // 2. End-Gong nur bei natürlichem Ende (nicht beim manuellen Abbrechen)
        if !manual {
            gong.play(named: "gong-ende") {
                // 3. Stoppe die Hintergrund-Audio-Session nachdem der Gong fertig ist
                self.pendingEndStop?.cancel()
                let work = DispatchWorkItem { [bgAudio = self.bgAudio, ambientPlayer = self.ambientPlayer] in
                    bgAudio.stop()
                    ambientPlayer.stop()  // Fade-out ambient sound
                }
                self.pendingEndStop = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work) // Extra-Verzögerung für Safety
            }
            // Session-State wird nach Gong zurückgesetzt
            resetSession(stopAudio: false)
        } else {
            // Bei manuellem Abbruch: sofort stoppen ohne Gong
            bgAudio.stop()
            ambientPlayer.stop()
            resetSession(stopAudio: false)
        }
    }
}

private struct RunCard: View {
    let title: String
    let endDate: Date
    let totalSeconds: Int
    var onEnd: () -> Void

    @State private var currentTime = Date()
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text(title)
                .font(.title3.weight(.semibold))
                .textCase(.uppercase)
            // Progress ring + icon
            let progress = max(0, min(1, (endDate.timeIntervalSince(currentTime)) / Double(totalSeconds)))
            ZStack {
                CircularRing(progress: progress, lineWidth: 30)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 320, height: 320)
                if title == "Meditation" {
                    Text("🧘")
                        .font(.system(size: 64, weight: .semibold))
                } else {
                    Text("🪷")
                        .font(.system(size: 64, weight: .semibold))
                }
            }

            // Centered End button (same look & size as Atem run card)
            Button("End") {
                onEnd()
            }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)
                .accessibilityLabel("End Session")
        }
        .frame(maxWidth: 420)
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

// MARK: - OverlayBackgroundEffect (blur/dim background when overlay is shown)
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
    OffenView()
        .environmentObject(TwoPhaseTimerEngine())
}
#endif

#endif // os(iOS)

