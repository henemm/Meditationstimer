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

// Kleiner, eingebauter Gong-Player: spielt "gong.caf"/"gong.wav", sonst System-Bell.
fileprivate final class GongPlayer {
    private var player: AVAudioPlayer?

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        // Playback = spielt auch bei Stummschalter; mixWithOthers lässt andere Audio leise weiterlaufen
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true, options: [])
    }

    /// Spielt eine Audiodatei ohne Erweiterung; versucht .caf, .wav, .mp3 in dieser Reihenfolge.
    /// Optional mit Completion, die nach Ende der Wiedergabe aufgerufen wird.
    func play(named name: String, completion: (() -> Void)? = nil) {
        activateSession()
        // Versuche nacheinander die unterstützten Endungen
        for ext in ["caf", "wav", "mp3"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                do {
                    let p = try AVAudioPlayer(contentsOf: url)
                    p.prepareToPlay()
                    p.play()
                    self.player = p
                    if let completion = completion {
                        // Aufruf nach tatsächlicher Dauer
                        let delay = max(0.0, p.duration)
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            completion()
                        }
                    }
                    return
                } catch {
                    // Versuche nächste Extension
                }
            }
        }
        // Fallback: Systemton und ggf. kurze Completion-Verzögerung
        playDefault()
        if let completion = completion {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: completion)
        }
    }

    /// Alter Default: spielt "gong" falls vorhanden, sonst Fallback.
    func play() {
        play(named: "gong", completion: nil)
    }

    /// System-Fallback
    private func playDefault() {
        AudioServicesPlaySystemSound(1005)
    }
}

struct ContentView: View {
    // Einstellungen (merken letzte Werte)
    @AppStorage("phase1Minutes") private var phase1Minutes: Int = 15
    @AppStorage("phase2Minutes") private var phase2Minutes: Int = 3

    // Services
    private let hk = HealthKitManager()
    private let notifier = NotificationHelper()
    @StateObject private var engine = TwoPhaseTimerEngine()
    private let gong = GongPlayer()
    private let bgAudio = BackgroundAudioKeeper()

    // UI State
    @State private var showingError: String?
    @State private var askedPermissions = false
    @State private var lastState: TwoPhaseTimerEngine.State = .idle
    @Environment(\.scenePhase) private var scenePhase
    @State private var currentActivity: Activity<MeditationAttributes>?
    @State private var showSettings = false

    private var offenTab: some View {
        NavigationView {
            GlassCard {
                VStack(spacing: 16) {
                    switch engine.state {
                    case .idle, .finished:
                        pickerSection
                        Button("Start") { startSession() }
                            .font(.title2.weight(.semibold))
                            .padding(.horizontal, 84)
                            .padding(.vertical, 14)
                            .buttonStyle(.borderedProminent)

                    case .phase1(let remaining):
                        phaseView(title: "Meditation", remaining: remaining)
                        Button("Abbrechen", role: .destructive) { cancelSession() }

                    case .phase2(let remaining):
                        phaseView(title: "Besinnung", remaining: remaining)
                        Button("Abbrechen", role: .destructive) { cancelSession() }
                    }
                }
            }
            .padding()
            .toolbarBackground(.regularMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Meditationstimer")
                        .font(.title3)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                    .accessibilityLabel("Einstellungen")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
                    .presentationDetents([.medium, .large])
            }
        }
    }

    var body: some View {
        TabView {
            offenTab
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
            // Berechtigungen einmalig anfragen
            if !askedPermissions {
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
        .onChange(of: engine.state) { oldValue, new in
            // Übergang Phase1 -> Phase2: dreifacher Gong
            if case .phase1 = oldValue, case .phase2 = new {
                gong.play(named: "gong-dreimal")
                Task {
                    let state = MeditationAttributes.ContentState(
                        endDate: Date().addingTimeInterval(TimeInterval(phase2Minutes * 60)),
                        phase: 2
                    )
                    await currentActivity?.update(using: state)
                }
            }
            // Natürliches Ende: End-Gong + Logging
            if new == .finished {
                gong.play(named: "gong-ende") {
                    setIdleTimer(false)
                    bgAudio.stop()
                    finishSessionLogPhase1Only()
                    Task {
                        await currentActivity?.end(dismissalPolicy: .immediate)
                        currentActivity = nil
                    }
                }
            }
        }
        .alert("Hinweis", isPresented: .constant(showingError != nil), actions: {
            Button("OK") { showingError = nil }
        }, message: { Text(showingError ?? "") })
    }

    // Bildschirm an/aus verhindern/erlauben
    private func setIdleTimer(_ disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }

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

    private func phaseView(title: String, remaining: Int) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.headline)
            Text(format(remaining))
                .font(.system(size: 56, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
    }

    // MARK: - Actions

    private func startSession() {
        setIdleTimer(true)
        gong.play(named: "gong-ende")
        bgAudio.start()
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
        lastState = .phase1(remaining: phase1Minutes * 60)

        if ActivityAuthorizationInfo().areActivitiesEnabled {
            let attributes = MeditationAttributes(title: "Meditation")
            let state = MeditationAttributes.ContentState(
                endDate: Date().addingTimeInterval(TimeInterval(phase1Minutes * 60)),
                phase: 1
            )
            do {
                currentActivity = try Activity<MeditationAttributes>.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: nil
                )
            } catch {
                print("Live Activity request failed: \(error)")
            }
        }
    }

    private func cancelSession() {
        setIdleTimer(false)
        bgAudio.stop()
        Task { await notifier.cancelAll() }
        Task { await logPhase1OnCancel() } // immer loggen
        engine.cancel()
        Task {
            await currentActivity?.end(dismissalPolicy: .immediate)
            currentActivity = nil
        }
        lastState = .idle
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

    private func format(_ s: Int) -> String {
        String(format: "%02d:%02d", s/60, s%60)
    }
}

private struct GlassCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

private struct SettingsSheet: View {
    @AppStorage("phase1Minutes") private var defaultP1: Int = 15
    @AppStorage("phase2Minutes") private var defaultP2: Int = 3
    @AppStorage("soundEnabled")  private var soundEnabled: Bool = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true

    var body: some View {
        NavigationView {
            Form {
                Section("Feedback") {
                    Toggle("Ton (iPhone)", isOn: $soundEnabled)
                    Toggle("Haptik (Watch)", isOn: $hapticsEnabled)
                }
                Section {
                    Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                        Label("System‑Einstellungen öffnen", systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle("Einstellungen")
        }
    }
}

private struct AtemView: View {
    var body: some View {
        NavigationView {
            GlassCard {
                VStack(spacing: 12) {
                    Text("Atem‑Meditationen")
                        .font(.headline)
                    Text("Bald verfügbar")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationTitle("Atem")
        }
    }
}

private struct WorkoutsView: View {
    var body: some View {
        NavigationView {
            GlassCard {
                VStack(spacing: 12) {
                    Text("Workouts")
                        .font(.headline)
                    Text("Bald verfügbar")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationTitle("Workouts")
        }
    }
}

#Preview {
    ContentView()
}
