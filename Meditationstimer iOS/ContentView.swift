//
//  ContentView.swift
//  Meditationstimer iOS
//
//  Created by Henning Emmrich on 01.09.25.
//

import SwiftUI
import AVFoundation
import HealthKit

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
    func play(named name: String) {
        activateSession()
        for ext in ["caf", "wav", "mp3"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                do {
                    let p = try AVAudioPlayer(contentsOf: url)
                    p.prepareToPlay()
                    p.play()
                    self.player = p
                    return
                } catch {
                    // Versuche nächste Extension
                }
            }
        }
        playDefault()
    }

    /// Alter Default: spielt "gong" falls vorhanden, sonst Fallback.
    func play() {
        play(named: "gong")
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

    // UI State
    @State private var showingError: String?
    @State private var askedPermissions = false
    @State private var lastState: TwoPhaseTimerEngine.State = .idle

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                switch engine.state {
                case .idle, .finished:
                    pickerSection
                    Button("Start") { startSession() }
                        .buttonStyle(.borderedProminent)

                case .phase1(let remaining):
                    phaseView(title: "Meditation", remaining: remaining)
                    Button("Abbrechen", role: .destructive) { cancelSession() }

                case .phase2(let remaining):
                    phaseView(title: "Besinnung", remaining: remaining)
                    Button("Abbrechen", role: .destructive) { cancelSession() }
                }
            }
            .padding()
            .navigationTitle("Meditationstimer")
        }
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
        .onChange(of: engine.state) { new in
            // Übergang Phase1 -> Phase2: dreifacher Gong
            if case .phase1 = lastState, case .phase2 = new {
                gong.play(named: "gong-dreimal")
            }
            // Natürliches Ende: End-Gong + Logging
            if new == .finished {
                gong.play(named: "gong-ende")
                finishSessionLogPhase1Only()
            }
            lastState = new
        }
        .alert("Hinweis", isPresented: .constant(showingError != nil), actions: {
            Button("OK") { showingError = nil }
        }, message: { Text(showingError ?? "") })
    }

    // MARK: - Subviews

    private var pickerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Meditation")
                Spacer()
                Picker("Meditation (min)", selection: $phase1Minutes) {
                    ForEach(0..<61) { Text("\($0)") }
                }
                .frame(width: 100)
                .labelsHidden()
                .pickerStyle(.wheel)
            }
            HStack {
                Text("Besinnung")
                Spacer()
                Picker("Besinnung (min)", selection: $phase2Minutes) {
                    ForEach(0..<61) { Text("\($0)") }
                }
                .frame(width: 100)
                .labelsHidden()
                .pickerStyle(.wheel)
            }
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
        gong.play(named: "gong-ende")
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
    }

    private func cancelSession() {
        Task { await notifier.cancelAll() }
        Task { await logPhase1OnCancel() } // immer loggen
        engine.cancel()
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

#Preview {
    ContentView()
}
