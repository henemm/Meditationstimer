//
//  OffenView.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 27.09.25.
//

import SwiftUI
import UIKit
import AVFoundation
import ActivityKit

struct OffenView: View {
    @AppStorage("phase1Minutes") private var phase1Minutes: Int = 10
    @AppStorage("phase2Minutes") private var phase2Minutes: Int = 5

    @State private var showSettings = false

    @EnvironmentObject var engine: TwoPhaseTimerEngine
    @State private var lastState: TwoPhaseTimerEngine.State = .idle
    @State private var currentActivity: Activity<MeditationAttributes>?
    @State private var notifier = BackgroundNotifier()
    @State private var gong = GongPlayer()
    @State private var bgAudio = BackgroundAudioKeeper()
    @State private var didPlayPhase2Gong = false

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
            setIdleTimer(true)
            bgAudio.start()
            gong.play(named: "gong-ende")

            // Start engine
            engine.start(phase1Minutes: phase1Minutes, phase2Minutes: phase2Minutes)

            // Live Activity
            let liveEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
            if liveEnabled {
                let attributes = MeditationAttributes(title: "Meditation")
                let state = MeditationAttributes.ContentState(
                    endDate: Date().addingTimeInterval(TimeInterval(phase1Minutes * 60)),
                    phase: 1
                )
                do {
                    currentActivity = try Activity<MeditationAttributes>.request(
                        attributes: attributes,
                        content: ActivityContent(state: state, staleDate: nil),
                        pushType: nil
                    )
                } catch {
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
                            bgAudio.stop()
                            engine.cancel()
                        }

                    case .phase2(let remaining):
                        phaseView(title: "Besinnung", remaining: remaining, total: phase2Minutes * 60)
                        Button("Abbrechen", role: .destructive) {
                            setIdleTimer(false)
                            bgAudio.stop()
                            engine.cancel()
                        }
                    }
                }
            }
            .padding()
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
                // Übergang Phase 1 -> Phase 2: dreifacher Gong
                if case .phase1 = lastState, case .phase2 = newValue {
                    gong.play(named: "gong-dreimal")
                    didPlayPhase2Gong = true
                    if case .phase2(let remaining) = newValue {
                        Task {
                            let state = MeditationAttributes.ContentState(
                                endDate: Date().addingTimeInterval(TimeInterval(remaining)),
                                phase: 2
                            )
                            await currentActivity?.update(ActivityContent(state: state, staleDate: nil))
                        }
                    }
                }
                // Fallback: Wenn wir ohne vorherige phase1 direkt in phase2 eintreten (z. B. phase1Minutes == 0), trotzdem den Dreifach-Gong spielen – aber nur einmal
                else if case .phase2 = newValue, didPlayPhase2Gong == false {
                    gong.play(named: "gong-dreimal")
                    didPlayPhase2Gong = true
                }
                // Natürliches Ende
                if newValue == .finished {
                    gong.play(named: "gong-ende")
                    // **Delay** stopping the background audio so the end gong can fully play out
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        bgAudio.stop()
                    }
                    Task {
                        await currentActivity?.end(dismissalPolicy: .immediate)
                        currentActivity = nil
                    }
                    setIdleTimer(false)
                    // Reset phase2 gong guard for next run
                    didPlayPhase2Gong = false
                }
                if case .idle = newValue, case .idle = lastState {
                    // no-op
                } else if case .idle = newValue {
                    Task {
                        await currentActivity?.end(dismissalPolicy: .immediate)
                        currentActivity = nil
                    }
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
                    bgAudio.stop()
                    setIdleTimer(false)
                default:
                    break
                }
                Task {
                    await currentActivity?.end(dismissalPolicy: .immediate)
                    currentActivity = nil
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
        UIApplication.shared.isIdleTimerDisabled = disabled
    }
}
#if DEBUG
#Preview {
    OffenView()
        .environmentObject(TwoPhaseTimerEngine())
}
#endif
