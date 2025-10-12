//
//  WorkoutsView.swift
//  Meditationstimer
//
//  Replaced with a simplified copy of AtemView tailored for interval workouts.
//  Differences vs AtemView:
//   - Preset model simplified to work/rest durations and repetitions
//   - Only two phases: work (flame) and rest (pause)
//   - Icons: flame / pause
//   - LiveActivity ownerId uses "WorkoutsTab"
//

import SwiftUI
import HealthKit
import AVFoundation
import os
// Dynamic Island / Live Activity removed

#if !os(iOS)
public struct WorkoutsView: View { public init() {} public var body: some View { Text("Workouts nur auf iOS") } }
#else

// MARK: - Workouts Tab (simplified from Atem)

public struct WorkoutsView: View {
    struct Preset: Identifiable, Hashable {
        let id: UUID
        var name: String
        var emoji: String
        var work: Int
        var rest: Int
        var repetitions: Int

        init(id: UUID = UUID(), name: String, emoji: String, work: Int, rest: Int, repetitions: Int) {
            self.id = id
            self.name = name
            self.emoji = emoji
            self.work = work
            self.rest = rest
            self.repetitions = repetitions
        }

        var cycleSeconds: Int { work + rest }
        var totalSeconds: Int { cycleSeconds * max(1, repetitions) }
    }

    enum Phase: String { case work = "Belastung", rest = "Erholung" }

    // Simplified engine that only tracks work/rest and repeats
    final class SessionEngine: ObservableObject {
        enum State: Equatable {
            case idle
            case running(phase: Phase, remaining: Int, rep: Int, totalReps: Int)
            case finished
        }
        @Published private(set) var state: State = .idle
        private var task: Task<Void, Never>? = nil
        private let gong = GongPlayer()
        private let logger = Logger(subsystem: "henemm.Meditationstimer", category: "TIMER-BUG")

        func start(preset: Preset) {
            cancel()
            logger.debug("SessionEngine start preset=\(preset.name, privacy: .public) id=\(preset.id.uuidString, privacy: .public)")
            run(preset: preset, rep: 1, phaseIsWork: true)

        #endif
        switch phase {
        //
        //  WorkoutsView.swift
        //  Meditationstimer
        //
        //  Simplified Workouts tab: two-phase interval timer (work/rest) based on AtemView.
        //
        import SwiftUI
        import AVFoundation
        import os

        #if !os(iOS)
        public struct WorkoutsView: View {
            public init() {}
            public var body: some View { Text("Workouts nur auf iOS") }
        }
        #else

        public struct WorkoutsView: View {
            struct Preset: Identifiable, Hashable {
                let id: UUID
                var name: String
                var emoji: String
                var work: Int
                var rest: Int
                var repetitions: Int

                init(id: UUID = UUID(), name: String, emoji: String, work: Int, rest: Int, repetitions: Int) {
                    self.id = id
                    self.name = name
                    self.emoji = emoji
                    self.work = work
                    self.rest = rest
                    self.repetitions = repetitions
                }

                var cycleSeconds: Int { work + rest }
                var totalSeconds: Int { cycleSeconds * max(1, repetitions) }
            }

            enum Phase { case work, rest }

            final class SessionEngine: ObservableObject {
                enum State: Equatable {
                    case idle
                    case running(phase: Phase, remaining: Int, rep: Int, totalReps: Int)
                    case finished
                }
                @Published private(set) var state: State = .idle
                private var task: Task<Void, Never>? = nil
                private let gong = GongPlayer()
                private let logger = Logger(subsystem: "henemm.Meditationstimer", category: "TIMER-BUG")

                func start(preset: Preset) {
                    cancel()
                    logger.debug("SessionEngine start preset=\(preset.name, privacy: .public) id=\(preset.id.uuidString, privacy: .public)")
                    run(preset: preset, rep: 1, phaseIsWork: true)
                }

                func cancel() {
                    task?.cancel(); task = nil
                    Task { await MainActor.run { self.state = .idle } }
                }

                private func run(preset: Preset, rep: Int, phaseIsWork: Bool) {
                    task?.cancel()
                    task = Task { [weak self] in
                        guard let self = self else { return }
                        var currentRep = rep
                        var isWork = phaseIsWork

                        while !Task.isCancelled {
                            // WorkoutsView.swift

                            import SwiftUI
                            import HealthKit
                            import AVFoundation
                            import os

                            #if !os(iOS)
                            public struct WorkoutsView: View {
                                public init() {}
                                public var body: some View { Text("Workouts nur auf iOS") }
                            }
                            #else

                            public struct WorkoutsView: View {
                                // Simple preset model for interval workouts
                                struct Preset: Identifiable, Hashable {
                                    let id: UUID
                                    var name: String
                                    var emoji: String
                                    var work: Int
                                    var rest: Int
                                    var repetitions: Int

                                    init(id: UUID = UUID(), name: String, emoji: String, work: Int, rest: Int, repetitions: Int) {
                                        self.id = id
                                        self.name = name
                                        self.emoji = emoji
                                        self.work = work
                                        self.rest = rest
                                        self.repetitions = repetitions
                                    }

                                    var cycleSeconds: Int { work + rest }
                                    var totalSeconds: Int { cycleSeconds * max(1, repetitions) }
                                }

                                enum Phase { case work, rest }

                                // Minimal session engine (work/rest loop)
                                final class SessionEngine: ObservableObject {
                                    enum State: Equatable {
                                        case idle
                                        case running(phase: Phase, remaining: Int, rep: Int, totalReps: Int)
                                        case finished
                                    }

                                    @Published private(set) var state: State = .idle
                                    private var task: Task<Void, Never>? = nil
                                    private let gong = GongPlayer()
                                    private let logger = Logger(subsystem: "henemm.Meditationstimer", category: "TIMER-BUG")

                                    func start(preset: Preset) {
                                        cancel()
                                        logger.debug("SessionEngine start preset=\(preset.name, privacy: .public) id=\(preset.id.uuidString, privacy: .public)")
                                        run(preset: preset, rep: 1, phaseIsWork: true)
                                    }

                                    func cancel() {
                                        task?.cancel(); task = nil
                                        Task { await MainActor.run { self.state = .idle } }
                                    }

                                    private func run(preset: Preset, rep: Int, phaseIsWork: Bool) {
                                        task?.cancel()
                                        task = Task { [weak self] in
                                            guard let self = self else { return }
                                            var currentRep = rep
                                            var isWork = phaseIsWork

                                            while !Task.isCancelled {
                                                if currentRep > preset.repetitions {
                                                    await MainActor.run { self.state = .finished }
                                                    break
                                                }
                                                let duration = isWork ? preset.work : max(1, preset.rest)
                                                let phase = isWork ? Phase.work : Phase.rest
                                                await MainActor.run {
                                                    self.gong.play(named: isWork ? "auftakt" : "lang")
                                                    self.state = .running(phase: phase, remaining: duration, rep: currentRep, totalReps: preset.repetitions)
                                                }

                                                var remaining = duration
                                                while remaining > 0 && !Task.isCancelled {
                                                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                                                    remaining -= 1
                                                    if Task.isCancelled { break }
                                                    await MainActor.run { self.state = .running(phase: phase, remaining: remaining, rep: currentRep, totalReps: preset.repetitions) }
                                                }

                                                if Task.isCancelled { break }
                                                if !isWork { currentRep += 1 }
                                                isWork.toggle()
                                            }

                                            await MainActor.run { if case .running = self.state { self.state = .idle } }
                                        }
                                    }
                                }

                                // Small audio helper
                                final class GongPlayer: NSObject, AVAudioPlayerDelegate {
                                    private var active: [AVAudioPlayer] = []
                                    private func activate() { let s = AVAudioSession.sharedInstance(); try? s.setCategory(.playback, options: [.mixWithOthers]); try? s.setActive(true, options: []) }
                                    func play(named name: String) {
                                        activate()
                                        for ext in ["caff","caf","wav","mp3"] {
                                            if let url = Bundle.main.url(forResource: name, withExtension: ext), let p = try? AVAudioPlayer(contentsOf: url) {
                                                p.delegate = self
                                                p.prepareToPlay()
                                                p.play()
                                                active.append(p)
                                                return
                                            }
                                        }
                                    }
                                    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) { if let i = active.firstIndex(where: { $0 === player }) { active.remove(at: i) } }
                                }

                                @State private var presets: [Preset] = [
                                    .init(name: "HIIT 30/10 x10", emoji: "🔥", work: 30, rest: 10, repetitions: 10),
                                    .init(name: "Tabata 20/10 x8", emoji: "🔥", work: 20, rest: 10, repetitions: 8)
                                ]

                                @State private var runningPreset: Preset? = nil
                                @State private var showSettings = false
                                @StateObject private var engine = SessionEngine()
                                @StateObject private var liveActivity = LiveActivityController()

                                public init() {}

                                public var body: some View {
                                    ZStack {
                                        NavigationStack {
                                            List {
                                                ForEach(presets) { preset in
                                                    Row(preset: preset, play: { runningPreset = preset })
                                                        .listRowBackground(Color.clear)
                                                }
                                            }
                                            .listStyle(.plain)
                                            .navigationTitle("")
                                            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showSettings = true } label: { Image(systemName: "gearshape") } } }
                                            .sheet(isPresented: $showSettings) { SettingsSheet().presentationDetents([.medium, .large]) }
                                        }

                                        if runningPreset != nil {
                                            Rectangle().fill(LinearGradient(colors: [Color.black.opacity(0.06), Color.black.opacity(0.28)], startPoint: .top, endPoint: .bottom)).ignoresSafeArea().zIndex(1)
                                        }

                                        if let preset = runningPreset {
                                            SessionCard(preset: preset, onClose: stopSession, engine: engine, liveActivity: liveActivity).zIndex(2)
                                                .transition(.scale.combined(with: .opacity))
                                        }
                                    }
                                }

                                private func stopSession() {
                                    Task {
                                        engine.cancel()
                                        await liveActivity.end()
                                        await MainActor.run { runningPreset = nil }
                                    }
                                }

                                struct Row: View {
                                    let preset: Preset
                                    let play: () -> Void
                                    var body: some View {
                                        VStack(alignment: .leading) {
                                            HStack { Text(preset.emoji).font(.system(size: 42)); Text(preset.name).font(.title3.weight(.bold)); Spacer(); Button(action: play) { Image(systemName: "play.fill").frame(width: 40, height: 40) }.buttonStyle(.borderedProminent).clipShape(Circle()) }
                                            Text("\(preset.repetitions)x • \(preset.work)s / \(preset.rest)s") .font(.subheadline).foregroundStyle(.secondary)
                                        }
                                        .padding(12)
                                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                }

                                struct SessionCard: View {
                                    let preset: Preset
                                    var onClose: () -> Void
                                    @ObservedObject var engine: SessionEngine
                                    @ObservedObject var liveActivity: LiveActivityController

                                    @State private var sessionStart: Date = .now
                                    @State private var sessionTotal: TimeInterval = 1
                                    @State private var phaseStart: Date? = nil
                                    @State private var phaseDuration: Double = 1
                                    @State private var lastIsWork: Bool? = nil
                                    @State private var didInitiate: Bool = false

                                    var body: some View {
                                        ZStack {
                                            Color(.systemGray6).ignoresSafeArea()
                                            VStack(spacing: 12) {
                                                switch engine.state {
                                                case .idle:
                                                    ProgressView().onAppear {
                                                        let now = Date(); sessionStart = now; sessionTotal = TimeInterval(preset.totalSeconds)
                                                        guard !didInitiate else { return }
                                                        didInitiate = true
                                                        let endDate = sessionStart.addingTimeInterval(sessionTotal)
                                                        let res = liveActivity.requestStart(title: preset.name, phase: 1, endDate: endDate, ownerId: "WorkoutsTab")
                                                        switch res {
                                                        case .started: engine.start(preset: preset)
                                                        case .conflict(_, _): engine.start(preset: preset)
                                                        case .failed: engine.start(preset: preset)
                                                        }
                                                    }
                                                case .running(let phase, _, let rep, let totalReps):
                                                    Text(preset.name).font(.headline)
                                                    TimelineView(.animation) { ctx in
                                                        let now = ctx.date
                                                        let totalDuration = max(0.001, sessionTotal)
                                                        let elapsedSession = now.timeIntervalSince(sessionStart)
                                                        let progressTotal = max(0.0, min(1.0, elapsedSession / totalDuration))
                                                        let dur = max(0.001, phaseDuration)
                                                        let start = phaseStart ?? now
                                                        let elapsedInPhase = max(0, now.timeIntervalSince(start))
                                                        let fractionPhase = max(0.0, min(1.0, elapsedInPhase / dur))

                                                        ZStack {
                                                            CircularRing(progress: progressTotal, lineWidth: 22).foregroundStyle(.tint)
                                                            CircularRing(progress: fractionPhase, lineWidth: 14).scaleEffect(0.72).foregroundStyle(.secondary)
                                                            Image(systemName: SessionCard.iconName(isWork: phase == .work)).font(.system(size: 64)).foregroundStyle(.tint)
                                                        }
                                                        .frame(width: 320, height: 320).padding(.top, 6)
                                                        Text("Satz \(rep) / \(totalReps)").font(.footnote).foregroundStyle(.secondary)
                                                    }
                                                case .finished:
                                                    VStack { Image(systemName: "checkmark.circle.fill").font(.system(size: 40)); Text("Fertig") }
                                                        .onAppear { sessionTotal = max(sessionTotal, Date().timeIntervalSince(sessionStart)); Task { await endSession(manual: false) } }
                                                }

                                                Button("Beenden") { Task { await endSession(manual: true) } }
                                                    .buttonStyle(.borderedProminent).tint(.red).controlSize(.large).frame(maxWidth: .infinity).padding(.top, 8)
                                            }
                                            .frame(minWidth: 280, maxWidth: 360).padding(16)
                                        }
                                        .overlay(alignment: .topTrailing) {
                                            Button(action: { Task { await endSession(manual: true) } }) { Image(systemName: "xmark").frame(width: 28, height: 28) }
                                                .buttonStyle(.borderedProminent).tint(.secondary).clipShape(Circle()).padding(8)
                                        }
                                        .onChange(of: engine.state) { newState in
                                            if case .running(let ph, _, _, _) = newState {
                                                let isWork = (ph == .work)
                                                if lastIsWork == nil || lastIsWork != isWork {
                                                    lastIsWork = isWork
                                                    phaseStart = Date()
                                                    phaseDuration = Double(isWork ? preset.work : preset.rest)
                                                    let phaseNumber = isWork ? 1 : 2
                                                    let sessionEnd = sessionStart.addingTimeInterval(sessionTotal)
                                                    Task { await liveActivity.update(phase: phaseNumber, endDate: sessionEnd) }
                                                }
                                            }
                                        }
                                        .onDisappear { onClose() }

                                        func endSession(manual: Bool) async {
                                            if sessionStart.distance(to: Date()) > 3 {
                                                do { try await HealthKitManager.shared.logWorkout(start: sessionStart, end: Date(), activity: .highIntensityIntervalTraining) } catch { DebugLog.error("HealthKit failed: \(error)", category: "HEALTH") }
                                            }
                                            if manual { engine.cancel() }
                                            await liveActivity.end()
                                            onClose()
                                        }

                                        static func iconName(isWork: Bool) -> String { isWork ? "flame" : "pause" }
                                    }
                                }

                            #endif

                                                let phaseNumber = isWork ? 1 : 2
                                                let sessionEnd = sessionStart.addingTimeInterval(sessionTotal)
                                                Task { await liveActivity.update(phase: phaseNumber, endDate: sessionEnd) }
                                            }
                                        }
                                    }
                                    .onDisappear { performClose() }

                                    func endSession(manual: Bool) async {
                                        if sessionStart.distance(to: Date()) > 3 {
                                            do { try await HealthKitManager.shared.logWorkout(start: sessionStart, end: Date(), activity: .highIntensityIntervalTraining) } catch { DebugLog.error("HealthKit failed: \(error)", category: "HEALTH") }
                                        }
                                        if manual { engine.cancel() }
                                        await liveActivity.end()
                                        performClose()
                                    }

                                    func performClose() { close() }

                                    static func iconName(isWork: Bool) -> String { isWork ? "flame" : "pause" }
                                }
                            }

                        #endif
