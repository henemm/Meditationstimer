// probe: second-test
// probe: work-with-apps
//
//  ContentView.swift
//  Meditationstimer iOS
//
//  Created by Henning Emmrich on 01.09.25.
//

import SwiftUI
import AVFoundation
import HealthKit
import ActivityKit
import UIKit

// MARK: - AI ORIENTATION (Read me first)
// Purpose:
//   ContentView is ONLY the tab container and the cross-cutting session controller for the
//   two-phase meditation (start/stop, phase change, notifications, live activity, idle timer).
//   UI for each tab lives in its own file.
//
// Files & Responsibilities (where to look next):
//   • OffenView.swift       – "Offen" tab UI, including the circular ring overlay.
//   • AtemView.swift        – Breathing presets list, editor, and run card.
//   • WorkoutsView.swift    – Placeholder tab (kept minimal by design).
//   • SettingsSheet.swift   – Shared settings sheet used by all tabs.
//   • CircularRing.swift    – Reusable progress ring view.
//   • TwoPhaseTimerEngine   – Timer state machine (model) for Offen tab sessions.
//   • MeditationAttributes  – ActivityKit attributes/content for Dynamic Island / Live Activity.
//   • NotificationHelper    – Local notifications (backup when app backgrounds).
//   • HealthKitManager      – Logs mindfulness to Health.
//   • BackgroundAudioKeeper – Keeps audio session alive so timers/gongs aren’t killed.
//
// Control Flow (high level):
//   startSession() → plays start gong, enables idle timer, schedules notifications,
//   engine.start(phase1, phase2) → engine.state changes drive UI and side-effects below:
//   onChange(engine.state):
//     • phase1 → phase2  : play triple gong, update Live Activity (phase 2 end date)
//     • finished         : play end gong, disable idle timer, stop bg audio, end Live Activity
//
// AI Editing Guidelines:
//   • Keep ContentView lightweight: do NOT reintroduce tab-specific UI here.
//   • When adding features, prefer putting UI in the respective tab file; only wire cross-cutting
//     effects here (gongs, idle timer, notifications, live activity).
//   • Maintain function names used across files (startSession, cancelSession, finishSession…).
//   • Keep comments and MARKs—tools rely on them for quick navigation.

struct ContentView: View {
    // Einstellungen (merken letzte Werte)
    @AppStorage("phase1Minutes") private var phase1Minutes: Int = 15
    @AppStorage("phase2Minutes") private var phase2Minutes: Int = 3

    // Services
    private let hk = HealthKitManager()
    private let notifier = NotificationHelper()
    @StateObject private var engine = TwoPhaseTimerEngine()
    @StateObject private var session = SessionManager()
    // Removed audio helpers as per instructions

    // UI State
    @State private var showingError: String?
    @State private var askedPermissions = false
    @State private var lastState: TwoPhaseTimerEngine.State = .idle
    @Environment(\.scenePhase) private var scenePhase
    @State private var currentActivity: Activity<MeditationAttributes>?
    @State private var showSettings = false


    var body: some View {
        // MARK: Tabs & global background
        TabView {
            OffenView().environmentObject(engine)
                .tabItem { Label("Offen", systemImage: "figure.mind.and.body") }

            AtemView()
                .tabItem { Label("Atem", systemImage: "wind") }

            WorkoutsView()
                .tabItem { Label("Workouts", systemImage: "dumbbell") }
        }
        .background(
            LinearGradient(colors: [Color.blue.opacity(0.20), Color.purple.opacity(0.15)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onAppear {
            // One-time permission requests (Notifications, Health)
            #if DEBUG
            let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            #else
            let isPreview = false
            #endif
            // Berechtigungen einmalig anfragen
            if !askedPermissions && !isPreview {
                askedPermissions = true
                Task {
                    do {
                        try await notifier.requestAuthorization()
                        try await hk.requestAuthorization()
                    } catch {
                        showingError = "Berechtigungen eingeschränkt: \(error.localizedDescription)"
                    }
                }
            }
        }
        .onChange(of: engine.state) { newValue in
            // Drive cross-cutting side effects based on engine state transitions
            let oldValue = lastState
            // Übergang Phase1 -> Phase2: Live Activity aktualisieren (Sound wird in Tab-View gehandhabt)
            if case .phase1 = oldValue, case .phase2 = newValue {
                Task {
                    await session.updateLiveActivity(
                        phase: 2,
                        endDate: Date().addingTimeInterval(TimeInterval(phase2Minutes * 60))
                    )
                }
            }
            // Natürliches Ende: nur Systemeffekte (Sound wird in Tab-View gehandhabt)
            if newValue == .finished {
                setIdleTimer(false)
                finishSessionLogPhase1Only()
                Task {
                    await session.endLiveActivityImmediate()
                    currentActivity = nil
                }
            }
            lastState = newValue
        }
        .alert("Hinweis", isPresented: .constant(showingError != nil), actions: {
            Button("OK") { showingError = nil }
        }, message: { Text(showingError ?? "") })
    }

    // MARK: - Cross-cutting helpers

    // Bildschirm an/aus verhindern/erlauben
    private func setIdleTimer(_ disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }

    // (UI helpers kept minimal here; tab-specific UI lives in OffenView/AtemView/WorkoutsView)
    // MARK: - Subviews

    private var pickerSection: some View {
        HStack(alignment: .center, spacing: 20) {

            // Linke Spalte: Emojis + Labels
            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    Text("🧘")
                        .font(.system(size: 64))
                    Text("Meditation")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 6) {
                    Text("🪷")
                        .font(.system(size: 64))
                    Text("Besinnung")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 110, alignment: .center)

            // Rechte Spalte: große „Drehräder“ (Wheel-Picker) für Zeiten
            VStack(spacing: 24) {
                WheelPicker(label: "Meditation", selection: $phase1Minutes, range: 0...60, unit: "min")
                    .frame(width: 160, height: 130)

                WheelPicker(label: "Besinnung", selection: $phase2Minutes, range: 0...60, unit: "min")
                    .frame(width: 160, height: 130)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }


    private func phaseView(title: String, remaining: Int, total: Int) -> some View {
        let totalSafe = max(1, total)
        let progress = Double(remaining) / Double(totalSafe)   // 1.0 → 0.0 (schrumpft)

        return VStack(spacing: 16) {
            Text(title).font(.headline)
            ZStack {
                CircularRing(progress: progress, lineWidth: 30)
                    .frame(width: 240, height: 240)
                Text(format(remaining))
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Actions

    private func startSession() {
        setIdleTimer(true)
        // Sound & AVAudioSession werden im aktiven Tab (Offen/Atem) gestartet
        // Notifications als Backup, falls App in den Hintergrund geht
        let p1 = TimeInterval(max(0, phase1Minutes) * 60)
        let total = TimeInterval(max(0, phase1Minutes + phase2Minutes) * 60)

        Task {
            do {
                try await notifier.schedulePhaseEndNotification(
                    in: p1,
                    title: "Meditation – Phase 1 beendet",
                    body: "Weiter mit Besinnung.",
                    identifier: "phase1-end"
                )
                try await notifier.schedulePhaseEndNotification(
                    in: total,
                    title: "Meditation – fertig",
                    body: "Sitzung abgeschlossen.",
                    identifier: "phase2-end"
                )
            } catch {
                showingError = "Konnte Benachrichtigung nicht planen: \(error.localizedDescription)"
            }
        }

        // Engine starten (UI)
        engine.start(phase1Minutes: phase1Minutes, phase2Minutes: phase2Minutes)
        lastState = TwoPhaseTimerEngine.State.phase1(remaining: phase1Minutes * 60)

        session.requestLiveActivity(
            phase: 1,
            endDate: Date().addingTimeInterval(TimeInterval(phase1Minutes * 60))
        )
    }

    private func cancelSession() {
        setIdleTimer(false)
        // Audio-Stopp erfolgt in der jeweiligen Tab-View
        Task { await notifier.cancelAll() }
        Task { await logPhase1OnCancel() } // immer loggen
        engine.cancel()
        Task {
            await endLiveActivityImmediate()
            currentActivity = nil
        }
        lastState = TwoPhaseTimerEngine.State.idle
    }

    /// Natürliches Ende: nur Phase 1 wird geloggt.
    private func finishSessionLogPhase1Only() {
        Task {
            await notifier.cancelAll()
            if let start = engine.startDate,
               let p1End = engine.phase1EndDate,
               p1End > start {
                do { try await hk.logMindfulness(start: start, end: p1End) }
                catch { showingError = "Health-Logging fehlgeschlagen: \(error.localizedDescription)" }
            }
        }
    }

    /// Abbruch: in Phase 1 bis „jetzt“ loggen, in Phase 2 bis Ende Phase 1 loggen.
    private func logPhase1OnCancel() async {
        guard let start = engine.startDate else { return }
        let now = Date()
        let end = min(engine.phase1EndDate ?? now, now)
        guard end > start else { return }
        do { try await hk.logMindfulness(start: start, end: end) }
        catch { showingError = "Health-Logging fehlgeschlagen: \(error.localizedDescription)" }
    }

    // Live Activity helpers (keep calls tidy and compatible with ActivityKit API)
    private func liveActivityUpdate(_ state: MeditationAttributes.ContentState) async {
        await currentActivity?.update(ActivityContent(state: state, staleDate: nil))
    }

    private func endLiveActivityImmediate() async {
        await currentActivity?.end(dismissalPolicy: .immediate)
    }

    private func format(_ s: Int) -> String {
        String(format: "%02d:%02d", s/60, s%60)
    }
}


#Preview {
    ContentView()
}
