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
struct OffenView: View { var body: some View { Text("Offen ist nur auf iOS verfügbar.") } }
#else

struct OffenView: View {
    @AppStorage("phase1Minutes") private var phase1Minutes: Int = 10
    @AppStorage("phase2Minutes") private var phase2Minutes: Int = 5

    @State private var sessionStart = Date()
    @State private var showSettings = false

    @EnvironmentObject var engine: TwoPhaseTimerEngine
    @State private var lastState: TwoPhaseTimerEngine.State = .idle
    @StateObject private var liveActivity = LiveActivityController()
    @State private var notifier = BackgroundNotifier()
    @State private var gong = GongPlayer()
    @State private var bgAudio = BackgroundAudioKeeper()
    @State private var didPlayPhase2Gong = false
    @State private var pendingEndStop: DispatchWorkItem?
    @AppStorage("logMeditationAsYogaWorkout") private var logMeditationAsYogaWorkout: Bool = false

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
                    Text("Besinnung")
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

                Picker("Besinnung (min)", selection: $phase2Minutes) {
                    ForEach(0..<61) { Text("\($0)") }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                .frame(width: 160, height: 130)
                .clipped()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var startButton: some View {
        Button(action: {
            // Align start flow with AtemView: keep screen awake, **activate audio session first**, then play short gong
            sessionStart = Date()
            setIdleTimer(true)
            bgAudio.start()
            gong.play(named: "gong-ende")

            // Start engine
            engine.start(phase1Minutes: phase1Minutes, phase2Minutes: phase2Minutes)

            // Start Live Activity
            if let phase1End = engine.phase1EndDate {
                liveActivity.start(title: "Meditation", phase: 1, endDate: phase1End)
            }
        }) {
            Image(systemName: "play.circle.fill")
                .resizable()
                .frame(width: 96, height: 96)
                .foregroundStyle(.tint)
        }
        .buttonStyle(.plain)
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
                // Base (idle & finished) – same as before
                VStack {
                    GlassCard {
                        VStack(spacing: 16) {
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

                // Overlay for active session (phase1/phase2) – styled like Atem's run card
                if case .phase1(let remaining) = engine.state {
                    Color.black.opacity(0.08).ignoresSafeArea()
                    RunCard(title: "Meditation", remaining: remaining, total: phase1Minutes * 60) {
                        Task { await endSession(manual: true) }
                    }
                    .padding(.horizontal, 20)
                } else if case .phase2(let remaining) = engine.state {
                    Color.black.opacity(0.08).ignoresSafeArea()
                    RunCard(title: "Besinnung", remaining: remaining, total: phase2Minutes * 60) {
                        Task { await endSession(manual: true) }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                            .accessibilityLabel("Einstellungen")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
                    .presentationDetents([.medium, .large])
            }
            .onChange(of: engine.state) { newValue in
                // Übergang Phase 1 -> Phase 2: dreifacher Gong und Live Activity auf Phase 2 updaten
                if case .phase1 = lastState, case .phase2 = newValue {
                    gong.play(named: "gong-dreimal")
                    didPlayPhase2Gong = true
                    // Update Live Activity to Phase 2
                    if let phase2End = engine.endDate {
                        Task {
                            await liveActivity.update(phase: 2, endDate: phase2End)
                        }
                        print("🔔 [LiveActivity] Phase 2 gestartet: Timer bis \(phase2End), Emoji 🪷")
                    }
                }
                // Fallback: Wenn wir ohne vorherige phase1 direkt in phase2 eintreten (z. B. phase1Minutes == 0), trotzdem den Dreifach-Gong spielen – aber nur einmal
                else if case .phase2 = newValue, didPlayPhase2Gong == false {
                    // Direkter Einstieg in Phase 2 (z. B. wenn phase1Minutes == 0)
                    gong.play(named: "gong-dreimal")
                    didPlayPhase2Gong = true
                    // Start Live Activity for Phase 2 directly
                    if let phase2End = engine.endDate {
                        liveActivity.start(title: "Besinnung", phase: 2, endDate: phase2End)
                        print("🔔 [LiveActivity] Direkter Start Phase 2: Timer bis \(phase2End), Emoji 🪷")
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
                // Do not cut off audio if a gong is playing or a phase is running
                switch engine.state {
                case .idle, .finished:
                    if pendingEndStop == nil {
                        bgAudio.stop()
                    }
                    setIdleTimer(false)
                default:
                    break
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
    
    private func endSession(manual: Bool) async {
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

        // 2. Spiele den End-Gong
        gong.play(named: "gong-ende")

        // 3. End Live Activity
        await liveActivity.end()

        // 4. Stoppe den Timer-Engine, falls manuell beendet
        if manual {
            engine.cancel()
        }

        // 5. Stoppe die Hintergrund-Audio-Session mit einer leichten Verzögerung, damit der Gong ausklingen kann
        pendingEndStop?.cancel()
        let work = DispatchWorkItem { [weak bgAudio = self.bgAudio] in
            bgAudio?.stop()
        }
        pendingEndStop = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: work)

        // 6. Erlaube dem Bildschirm wieder, sich auszuschalten
        setIdleTimer(false)
        
        // 7. Setze den Status für den nächsten Lauf zurück
        didPlayPhase2Gong = false
    }
}

private struct RunCard: View {
    let title: String
    let remaining: Int
    let total: Int
    var onEnd: () -> Void

    private func format(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                // Title
                Text(title)
                    .font(.title3.weight(.semibold))
                // Progress ring + timer (match Offen phaseView sizing)
                let totalSafe = max(1, total)
                let progress = Double(remaining) / Double(totalSafe)
                ZStack {
                    CircularRing(progress: progress, lineWidth: 30)
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: 320, height: 320)
                    Text(format(remaining))
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }

                // Centered Beenden button (same look & size as Atem run card)
                Button("Beenden") {
                    onEnd()
                }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.red)
                    .accessibilityLabel("Sitzung beenden")
            }
        }
        .frame(maxWidth: 420)
    }
}

#if DEBUG
#Preview {
    OffenView()
        .environmentObject(TwoPhaseTimerEngine())
}
#endif

#endif // os(iOS)

