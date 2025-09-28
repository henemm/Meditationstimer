//
//  OffenView.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 27.09.25.
//

import SwiftUI
import UIKit
import AVFoundation

struct OffenView: View {
    @AppStorage("phase1Minutes") private var phase1Minutes: Int = 10
    @AppStorage("phase2Minutes") private var phase2Minutes: Int = 5

    @State private var showSettings = false

    @EnvironmentObject var engine: TwoPhaseTimerEngine
    @State private var lastState: TwoPhaseTimerEngine.State = .idle
    private let gong = GongPlayer()
    private let notifier = BackgroundNotifier()

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
            setIdleTimer(true)
            activateAudioSession()
            gong.play(named: "gong")
            engine.start(phase1Minutes: phase1Minutes, phase2Minutes: phase2Minutes)
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
        NavigationView {
            GlassCard {
                VStack(spacing: 16) {
                    switch engine.state {
                    case .idle, .finished:
                        pickerSection
                        startButton

                    case .phase1(let remaining):
                        phaseView(title: "Meditation", remaining: remaining, total: phase1Minutes * 60)
                        Button("Abbrechen", role: .destructive) {
                            setIdleTimer(false)
                            engine.cancel()
                        }

                    case .phase2(let remaining):
                        phaseView(title: "Besinnung", remaining: remaining, total: phase2Minutes * 60)
                        Button("Abbrechen", role: .destructive) {
                            setIdleTimer(false)
                            engine.cancel()
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Meditationstimer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            .onChange(of: engine.state) { newValue in
                // Übergang Phase 1 -> Phase 2: dreifacher Gong
                if case .phase1 = lastState, case .phase2 = newValue {
                    activateAudioSession()
                    gong.play(named: "gong-dreimal")
                }
                // Natürliches Ende
                if newValue == .finished {
                    activateAudioSession()
                    gong.play(named: "gong-ende")
                    setIdleTimer(false)
                }
                lastState = newValue
            }
            .onAppear { lastState = engine.state }
            .onAppear { notifier.start() }
            .onDisappear { notifier.stop() }
        }
    }

    private func format(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    private func activateAudioSession() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, options: [.mixWithOthers])
        try? s.setActive(true, options: [])
    }

    private func setIdleTimer(_ disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }
#if DEBUG
#Preview {
    OffenView()
        .environmentObject(TwoPhaseTimerEngine())
}
#endif
