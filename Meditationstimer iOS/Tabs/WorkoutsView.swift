//
//  WorkoutsView.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 27.09.25.
//

import SwiftUI
import HealthKit

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

    func start() {
        startDate = Date()
    }

    func end(completed: Bool = true) {
        let endDate = Date()
        guard completed, let start = startDate else {
            startDate = nil
            return
        }
        let workout = HKWorkout(activityType: .highIntensityIntervalTraining,
                                start: start,
                                end: endDate)
        healthStore.save(workout) { _, _ in }
        startDate = nil
    }
}

// MARK: - Workout Runner (dual rings like Atem)
private enum WorkoutPhase: String {
    case work, rest
}

private struct WorkoutRunnerView: View {
    let intervalSec: Int
    let restSec: Int
    let repeats: Int
    let onClose: () -> Void

    @StateObject private var hk = HealthKitWorkoutManager()

    // Session timeline
    @State private var sessionStart: Date = .now
    private var sessionTotal: TimeInterval {
        let work = intervalSec * repeats
        let rest = max(0, repeats - 1) * restSec
        return TimeInterval(work + rest)
    }

    // Phase timeline
    @State private var phaseStart: Date? = nil
    @State private var phaseDuration: Double = 1
    @State private var lastPhase: WorkoutPhase? = nil

    // Progression
    @State private var phase: WorkoutPhase = .work
    @State private var rep: Int = 1
    @State private var finished = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            GlassCard {
                VStack(spacing: 12) {
                    Text("Intervall-Workout")
                        .font(.headline)
                    Text("HIIT • \(repeats) Sätze • \(intervalSec)s / \(restSec)s")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if !finished {
                        TimelineView(.animation, content: { (timeline: TimelineViewDefaultContext) in
                            let now = timeline.date

                            // Outer: session progress
                            let total = max(0.001, sessionTotal)
                            let elapsedSession = now.timeIntervalSince(sessionStart)
                            let progressTotal = max(0.0, min(1.0, elapsedSession / total))

                            // Inner: phase progress (resets each phase)
                            let dur = max(0.001, phaseDuration)
                            let start = phaseStart ?? now
                            let elapsedInPhase = max(0, now.timeIntervalSince(start))
                            let fractionPhase = max(0.0, min(1.0, elapsedInPhase / dur))

                            VStack(spacing: 8) {
                                ZStack {
                                    CircularRing(progress: progressTotal, lineWidth: 22)
                                        .foregroundStyle(.tint)
                                    CircularRing(progress: fractionPhase, lineWidth: 14)
                                        .scaleEffect(0.72)
                                        .foregroundStyle(.secondary)
                                    Image(systemName: iconName(for: phase))
                                        .font(.system(size: 64, weight: .regular))
                                        .foregroundStyle(.tint)
                                }
                                .frame(width: 320, height: 320)
                                .padding(.top, 6)
                                Text("Satz \(rep) / \(repeats) – \(label(for: phase))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .onChange(of: Int(fractionPhase >= 1.0 ? 1 : 0)) { _ in
                                advance()
                            }
                        })
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 44))
                            Text("Fertig")
                                .font(.subheadline.weight(.semibold))
                        }
                        .onAppear {
                            hk.end(completed: true)
                        }
                    }

                    Button("Beenden") {
                        hk.end(completed: false)
                        onClose()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                }
                .frame(minWidth: 280, maxWidth: 360)
            }
            .padding(16)
            .overlay(alignment: .topTrailing) {
                Button {
                    hk.end(completed: false)
                    onClose()
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
        }
        .task {
            // Prepare session
            sessionStart = .now
            lastPhase = nil
            phaseStart = nil

            do {
                try await hk.requestAuthorizationIfNeeded()
            } catch { /* ignore for now */ }
            hk.start()

            // Initialize first phase
            setPhase(.work)
        }
        .onChange(of: phase) { _ in
            // Reset per-phase clock
            phaseStart = Date()
            switch phase {
            case .work: phaseDuration = Double(max(1, intervalSec))
            case .rest: phaseDuration = Double(max(1, restSec))
            }
        }
    }

    private func iconName(for phase: WorkoutPhase) -> String {
        switch phase {
        case .work: return "flame"
        case .rest: return "pause"
        }
    }
    private func label(for phase: WorkoutPhase) -> String {
        switch phase {
        case .work: return "Belastung"
        case .rest: return "Pause"
        }
    }
    private func setPhase(_ p: WorkoutPhase) {
        phase = p
        phaseStart = Date()
        switch p {
        case .work: phaseDuration = Double(max(1, intervalSec))
        case .rest: phaseDuration = Double(max(1, restSec))
        }
        lastPhase = p
    }
    private func advance() {
        // Decide next phase/rep or finish
        if phase == .work {
            if restSec > 0 {
                setPhase(.rest)
            } else {
                // No rest → immediately go to next rep
                advanceRepOrFinish()
            }
        } else {
            advanceRepOrFinish()
        }
    }
    private func advanceRepOrFinish() {
        if rep >= repeats {
            finished = true
        } else {
            rep += 1
            setPhase(.work)
        }
    }
}

// MARK: - Workouts Editor + Launcher
struct WorkoutsView: View {
    @State private var showSettings = false
    @State private var showRunner = false

    @State private var intervalSec: Int = 30
    @State private var restSec: Int = 10
    @State private var repeats: Int = 10

    private var totalSeconds: Int {
        // Rest after each work except the last one
        repeats * intervalSec + max(0, repeats - 1) * restSec
    }
    private var totalString: String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                VStack(spacing: 16) {
                    // Simple controls
                    Group {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Intervall")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Picker("Intervall", selection: $intervalSec) {
                                ForEach(1...600, id: \.self) { v in
                                    Text("\(v) Sekunden").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 120)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pause")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Picker("Pause", selection: $restSec) {
                                ForEach(0...600, id: \.self) { v in
                                    Text("\(v) Sekunden").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 120)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Wiederholungen")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Picker("Wiederholungen", selection: $repeats) {
                                ForEach(1...200, id: \.self) { v in
                                    Text("\(v) ×").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 120)
                        }
                    }
                    .font(.body)

                    HStack {
                        Text("Gesamtdauer (\(repeats) Sätze)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(totalString)
                            .monospacedDigit()
                    }

                    Button {
                        showRunner = true
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)

                    Spacer()
                    Text("Workouts – kommt demnächst")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Einstellungen")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
                    .presentationDetents([.medium, .large])
            }
            .fullScreenCover(isPresented: $showRunner) {
                WorkoutRunnerView(
                    intervalSec: intervalSec,
                    restSec: restSec,
                    repeats: repeats
                ) {
                    showRunner = false
                }
                .ignoresSafeArea()
            }
            .navigationTitle("Workouts")
        }
    }
}
