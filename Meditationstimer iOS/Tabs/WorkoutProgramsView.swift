//
//  WorkoutProgramsView.swift
//  Meditationstimer
//
//  Created by Claude Code on 04.01.2025.
//
//  Preset-basierte Workout-Programme mit benannten Phasen, flexiblen Dauern und Wiederholungen.
//  Analog zu AtemView.swift, aber für heterogene HIIT/Calisthenics/Stretching-Programme.
//

// MARK: - AI ORIENTATION (Read me first)
// Purpose:
//   WorkoutProgramsView manages the "Workouts" tab - preset-based workout programs with named phases.
//   Unlike the "Frei" tab (homogeneous intervals), this tab supports heterogeneous phases:
//   e.g., "Planke 45s → Side Plank L 30s → Crunches 40s" repeated 3 times.
//
// Files & Responsibilities (where to look next):
//   • WorkoutProgramsView.swift  – This file: models, list, editor, session runner
//   • ContentView.swift          – Tab container
//   • HealthKitManager           – Logs workouts as HIIT (already implemented)
//   • LiveActivityController     – Dynamic Island / Lock Screen (already implemented)
//
// Control Flow (high level):
//   1. User sees list of preset workout sets (10 defaults + custom)
//   2. Play → opens full-screen session runner
//   3. Session runs through phases: Work → Rest → Next Phase → Next Round
//   4. Audio cues (countdown, auftakt, ausklang) + TTS for rounds
//   5. Completion → HealthKit logging + LiveActivity end
//
// AI Editing Guidelines:
//   • Keep models simple (WorkoutSet, WorkoutPhase)
//   • Analog to AtemView structure (list, editor, runner)
//   • Reuse SoundPlayer pattern from WorkoutsView
//   • Maintain Liquid Glass design (ultraThinMaterial, smooth animations)

import SwiftUI
import AVFoundation
import HealthKit
#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)

// MARK: - Models

/// Represents a complete workout program with multiple phases
struct WorkoutSet: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String                 // "Core Circuit"
    var emoji: String                // "💪"
    var phases: [WorkoutPhase]       // Array of exercise phases
    var repetitions: Int             // How many times to repeat the entire set (1-99)
    var description: String?         // Scientific rationale (optional)

    init(id: UUID = UUID(), name: String, emoji: String, phases: [WorkoutPhase], repetitions: Int, description: String? = nil) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.phases = phases
        self.repetitions = repetitions
        self.description = description
    }

    /// Total duration in seconds (all phases × repetitions)
    var totalSeconds: Int {
        let singleRound = phases.reduce(0) { $0 + $1.workDuration + $1.restDuration }
        return singleRound * max(1, repetitions)
    }

    /// Formatted duration string (e.g., "14:00 min")
    var totalDurationString: String {
        let s = totalSeconds
        let m = s / 60, r = s % 60
        return String(format: "%d:%02d min", m, r)
    }

    /// Number of phases in this set
    var phaseCount: Int {
        phases.count
    }
}

/// Represents a single phase (exercise) within a workout set
struct WorkoutPhase: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String            // "Diamond-Liegestütze", "Planke", etc.
    var workDuration: Int       // Seconds of work (1-600)
    var restDuration: Int       // Seconds of rest (0-600)
                                // IMPORTANT: Last phase in set should have restDuration = 0

    init(id: UUID = UUID(), name: String, workDuration: Int, restDuration: Int) {
        self.id = id
        self.name = name
        self.workDuration = workDuration
        self.restDuration = restDuration
    }
}

// MARK: - Exercise Suggestions List

/// Pre-defined exercise suggestions for the phase editor dropdown (60+ exercises, German/English mixed)
private let exerciseSuggestions: [String] = [
    // Core
    "Planke",
    "Seitliche Planke links",
    "Seitliche Planke rechts",
    "Hollow Hold",
    "Dead Bug",
    "Fahrrad-Crunches",
    "Russian Twists",
    "Beinheben",
    "Flutter Kicks",
    "Mountain Climbers",
    "V-Ups",
    "Sit-ups",
    "Crunches",
    "Planke zu Herabschauender Hund",

    // Push (Upper body pushing)
    "Liegestütze",
    "Diamond-Liegestütze",
    "Breite Liegestütze",
    "Pike-Liegestütze",
    "Archer-Liegestütze",
    "Decline-Liegestütze",
    "Wandliegestütze",
    "Dips",

    // Pull (Upper body pulling)
    "Klimmzüge",
    "Chin-ups",
    "Australian Pull-ups",
    "Inverted Rows",

    // Legs
    "Kniebeugen",
    "Jump-Kniebeugen",
    "Ausfallschritte",
    "Reverse-Ausfallschritte",
    "Ausfallschritte gehend",
    "Bulgarische Split-Kniebeugen",
    "Einbeiniges Kreuzheben",
    "Wadenheben",
    "Glute Bridges",
    "Step-ups",
    "Wall-Sit",
    "Knieheben stehend",

    // Cardio / Full Body
    "Burpees",
    "Hampelmänner",
    "High Knees",
    "Butt Kicks",
    "Box Jumps",
    "Skater Hops",
    "Jumping Jacks",
    "Bergsteiger",
    "Seilspringen",
    "Marschieren auf der Stelle",

    // Stretching
    "Herabschauender Hund",
    "Kindspose",
    "Kobra-Dehnung",
    "Katze-Kuh",
    "Vorbeuge im Sitzen",
    "Schmetterlings-Dehnung",
    "Hüftbeuger-Dehnung",
    "Quadrizeps-Dehnung",
    "Hamstring-Dehnung",
    "Waden-Dehnung",
    "Schulter-Dehnung",
    "Beinpendel",
    "Hüftkreisen",
].sorted()

// MARK: - Default Presets (10 scientifically-founded workout programs)

private let defaultWorkoutSets: [WorkoutSet] = [
    // 1. Tabata Classic 🔥
    WorkoutSet(
        name: "Tabata Classic",
        emoji: "🔥",
        phases: [
            WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
            WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
            WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
            WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
            WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
            WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
            WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
            WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 0),
        ],
        repetitions: 1,
        description: "Original Tabata-Protokoll (Izumi Tabata, 1996): 8 Runden à 20s maximale Intensität / 10s Pause. Nachweislich VO2max-Steigerung um bis zu 14% in 6 Wochen. Erfordert 170% VO2max Intensität."
    ),

    // 2. Core Circuit 💪
    WorkoutSet(
        name: "Core Circuit",
        emoji: "💪",
        phases: [
            WorkoutPhase(name: "Planke", workDuration: 45, restDuration: 15),
            WorkoutPhase(name: "Seitliche Planke links", workDuration: 30, restDuration: 15),
            WorkoutPhase(name: "Seitliche Planke rechts", workDuration: 30, restDuration: 15),
            WorkoutPhase(name: "Fahrrad-Crunches", workDuration: 40, restDuration: 15),
            WorkoutPhase(name: "Beinheben", workDuration: 30, restDuration: 15),
            WorkoutPhase(name: "Russian Twists", workDuration: 40, restDuration: 0),
        ],
        repetitions: 3,
        description: "Fokussiert auf Core-Stabilität und Rotationskraft. Kombiniert isometrische (Planken) und dynamische Übungen für ganzheitliche Rumpfstärkung. Verbessert Haltung und reduziert Rückenschmerzen."
    ),

    // 3. Full Body Burn 🏃
    WorkoutSet(
        name: "Full Body Burn",
        emoji: "🏃",
        phases: [
            WorkoutPhase(name: "Burpees", workDuration: 30, restDuration: 20),
            WorkoutPhase(name: "Kniebeugen", workDuration: 40, restDuration: 20),
            WorkoutPhase(name: "Liegestütze", workDuration: 30, restDuration: 20),
            WorkoutPhase(name: "Mountain Climbers", workDuration: 30, restDuration: 20),
            WorkoutPhase(name: "Ausfallschritte", workDuration: 40, restDuration: 20),
            WorkoutPhase(name: "Planke", workDuration: 45, restDuration: 0),
        ],
        repetitions: 3,
        description: "Ganzkörper-HIIT mit Fokus auf funktionelle Bewegungsmuster. Kombiniert Kraft, Cardio und Core-Stabilität. Maximale Kalorienverbrennung durch Einbindung großer Muskelgruppen."
    ),

    // 4. Power Intervals ⚡
    WorkoutSet(
        name: "Power Intervals",
        emoji: "⚡",
        phases: [
            WorkoutPhase(name: "Jump-Kniebeugen", workDuration: 40, restDuration: 20),
            WorkoutPhase(name: "Burpees", workDuration: 40, restDuration: 20),
            WorkoutPhase(name: "High Knees", workDuration: 40, restDuration: 20),
            WorkoutPhase(name: "Mountain Climbers", workDuration: 40, restDuration: 20),
            WorkoutPhase(name: "Hampelmänner", workDuration: 40, restDuration: 0),
        ],
        repetitions: 4,
        description: "Explosive plyometrische Übungen zur Steigerung von Schnellkraft und anaerober Kapazität. Optimal für Fettverbrennung und kardiovaskuläre Fitness. EPOC-Effekt (Nachbrenneffekt) bis 24h."
    ),

    // 5. Hintere Kette 🦵
    WorkoutSet(
        name: "Hintere Kette",
        emoji: "🦵",
        phases: [
            WorkoutPhase(name: "Glute Bridges", workDuration: 45, restDuration: 15),
            WorkoutPhase(name: "Einbeiniges Kreuzheben", workDuration: 40, restDuration: 15),
            WorkoutPhase(name: "Bulgarische Split-Kniebeugen", workDuration: 40, restDuration: 15),
            WorkoutPhase(name: "Reverse-Ausfallschritte", workDuration: 40, restDuration: 15),
            WorkoutPhase(name: "Wadenheben", workDuration: 30, restDuration: 0),
        ],
        repetitions: 3,
        description: "Gezieltes Training der posterior chain (Gesäß, Hamstrings, unterer Rücken, Waden). Essentiell für Laufökonomie, Sprintgeschwindigkeit und Verletzungsprävention. Korrigiert Dysbalancen durch Sitzposition."
    ),

    // 6. Jogging Warm-up 🏃‍♀️
    WorkoutSet(
        name: "Jogging Warm-up",
        emoji: "🏃‍♀️",
        phases: [
            WorkoutPhase(name: "High Knees", workDuration: 30, restDuration: 10),
            WorkoutPhase(name: "Butt Kicks", workDuration: 30, restDuration: 10),
            WorkoutPhase(name: "Beinpendel", workDuration: 30, restDuration: 10),
            WorkoutPhase(name: "Ausfallschritte gehend", workDuration: 40, restDuration: 10),
            WorkoutPhase(name: "Hüftkreisen", workDuration: 30, restDuration: 0),
        ],
        repetitions: 2,
        description: "Dynamisches Aufwärmen für Läufer. Aktiviert Hüftmuskulatur, erhöht Bewegungsumfang und bereitet den Körper auf Laufbelastung vor. Reduziert Verletzungsrisiko um bis zu 35%."
    ),

    // 7. Post-Run Stretching 🧘‍♂️
    WorkoutSet(
        name: "Post-Run Stretching",
        emoji: "🧘‍♂️",
        phases: [
            WorkoutPhase(name: "Quadrizeps-Dehnung", workDuration: 45, restDuration: 10),
            WorkoutPhase(name: "Hamstring-Dehnung", workDuration: 45, restDuration: 10),
            WorkoutPhase(name: "Hüftbeuger-Dehnung", workDuration: 45, restDuration: 10),
            WorkoutPhase(name: "Waden-Dehnung", workDuration: 45, restDuration: 10),
            WorkoutPhase(name: "Schmetterlings-Dehnung", workDuration: 60, restDuration: 10),
            WorkoutPhase(name: "Kindspose", workDuration: 60, restDuration: 0),
        ],
        repetitions: 1,
        description: "Statisches Stretching zur Regeneration nach dem Laufen. Fokus auf Hüft- und Beinmuskulatur. Reduziert Muskelkater (DOMS), verbessert Beweglichkeit und fördert Durchblutung. Mindestens 30s pro Stretch halten."
    ),

    // 8. Beginner Flow 🌱
    WorkoutSet(
        name: "Beginner Flow",
        emoji: "🌱",
        phases: [
            WorkoutPhase(name: "Marschieren auf der Stelle", workDuration: 40, restDuration: 20),
            WorkoutPhase(name: "Wandliegestütze", workDuration: 30, restDuration: 20),
            WorkoutPhase(name: "Kniebeugen", workDuration: 30, restDuration: 20),
            WorkoutPhase(name: "Planke (Knie)", workDuration: 30, restDuration: 20),
            WorkoutPhase(name: "Knieheben stehend", workDuration: 30, restDuration: 0),
        ],
        repetitions: 2,
        description: "Sanfter Einstieg ins HIIT-Training. Gelenkschonende Varianten mit längeren Pausen (1:1 Ratio). Ideal zum Aufbau von Grundfitness und Technik. Progressiv steigerbar durch mehr Runden oder kürzere Pausen."
    ),

    // 9. Quick Burn 🔥
    WorkoutSet(
        name: "Quick Burn",
        emoji: "🔥",
        phases: [
            WorkoutPhase(name: "Burpees", workDuration: 30, restDuration: 15),
            WorkoutPhase(name: "Mountain Climbers", workDuration: 30, restDuration: 15),
            WorkoutPhase(name: "Hampelmänner", workDuration: 30, restDuration: 15),
            WorkoutPhase(name: "Planke", workDuration: 30, restDuration: 0),
        ],
        repetitions: 3,
        description: "Kompaktes 6-Minuten-Workout für maximale Effizienz. Kombiniert Cardio und Core für schnelle Kalorienverbrennung. Perfekt für zeitknappe Tage oder als Finisher nach Krafttraining."
    ),

    // 10. Upper Body Push 💪
    WorkoutSet(
        name: "Upper Body Push",
        emoji: "💪",
        phases: [
            WorkoutPhase(name: "Liegestütze", workDuration: 40, restDuration: 20),
            WorkoutPhase(name: "Diamond-Liegestütze", workDuration: 30, restDuration: 20),
            WorkoutPhase(name: "Breite Liegestütze", workDuration: 30, restDuration: 20),
            WorkoutPhase(name: "Pike-Liegestütze", workDuration: 30, restDuration: 20),
            WorkoutPhase(name: "Planke zu Herabschauender Hund", workDuration: 30, restDuration: 0),
        ],
        repetitions: 3,
        description: "Fokussiertes Training der Druckmuskulatur (Brust, Trizeps, Schultern). Progression durch Push-up-Varianten mit unterschiedlichen Schwerpunkten. Ergänzt Pull-Training für ausgewogene Oberkörperentwicklung."
    ),
]

// MARK: - Main View (Placeholder for Phase 1)

public struct WorkoutProgramsView: View {
    @State private var sets: [WorkoutSet] = defaultWorkoutSets
    @State private var showingInfo: WorkoutSet? = nil
    @State private var showingEditor: WorkoutSet? = nil
    @State private var showSettings = false
    @State private var showingCalendar = false
    @State private var showingNoAlcLog = false
    @State private var runningSet: WorkoutSet? = nil

    @EnvironmentObject private var streakManager: StreakManager

    private let setsKey = "workoutProgramSets"

    public init() {}

    public var body: some View {
        ZStack {
            NavigationStack {
            List {
                ForEach(sets) { set in
                    WorkoutSetRow(
                        set: set,
                        play: {
                            runningSet = set
                        },
                        edit: {
                            showingEditor = set
                        },
                        showInfo: {
                            showingInfo = set
                        }
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onDelete { sets.remove(atOffsets: $0); saveSets() }

                // Add Set Card
                AddSetCard {
                    showingEditor = WorkoutSet(
                        name: "Neues Workout",
                        emoji: randomEmoji(),
                        phases: [],
                        repetitions: 3
                    )
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .padding(.horizontal, 4)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showingNoAlcLog = true } label: { Image(systemName: "drop.fill") }
                    Button { showingCalendar = true } label: { Image(systemName: "calendar") }
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
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
            .sheet(item: $showingInfo) { set in
                PresetInfoSheet(set: set)
            }
            .sheet(item: $showingEditor) { set in
                SetEditorView(
                    set: set,
                    isNew: !sets.contains(where: { $0.id == set.id }),
                    onSave: { edited in
                        if let i = sets.firstIndex(where: { $0.id == edited.id }) {
                            sets[i] = edited
                        } else {
                            sets.append(edited)
                        }
                        saveSets()
                    },
                    onDelete: { id in
                        if let i = sets.firstIndex(where: { $0.id == id }) {
                            sets.remove(at: i)
                        }
                        saveSets()
                    }
                )
            }
            .onAppear { loadSets() }
            }
            .modifier(OverlayBackgroundEffect(isDimmed: runningSet != nil))
            .toolbar(runningSet != nil ? .hidden : .visible, for: .tabBar)

            // Overlay dim effect
            if runningSet != nil {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.06), Color.black.opacity(0.28)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(1)
            }

            // Session Card Overlay
            if let set = runningSet {
                WorkoutProgramSessionCard(set: set) {
                    runningSet = nil
                }
                .transition(.scale.combined(with: .opacity))
                .zIndex(2)
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

    // MARK: - Persistence

    private func loadSets() {
        if let data = UserDefaults.standard.data(forKey: setsKey),
           let decoded = try? JSONDecoder().decode([WorkoutSet].self, from: data) {
            sets = decoded
            migrateSets()
        } else {
            sets = defaultWorkoutSets  // Initial load
        }
    }

    /// Adds missing default presets (migration after app update)
    private func migrateSets() {
        var needsSave = false

        // Add missing default presets
        for defaultSet in defaultWorkoutSets {
            if !sets.contains(where: { $0.name == defaultSet.name }) {
                sets.append(defaultSet)
                needsSave = true
                print("[WorkoutPrograms] Added missing default preset: \(defaultSet.name)")
            }
        }

        // Update descriptions for existing defaults
        for i in 0..<sets.count {
            if let defaultSet = defaultWorkoutSets.first(where: { $0.name == sets[i].name }) {
                if sets[i].description == nil && defaultSet.description != nil {
                    sets[i].description = defaultSet.description
                    needsSave = true
                    print("[WorkoutPrograms] Updated description for preset: \(sets[i].name)")
                }
            }
        }

        if needsSave {
            saveSets()
            print("[WorkoutPrograms] Migration completed, sets saved")
        }
    }

    private func saveSets() {
        if let data = try? JSONEncoder().encode(sets) {
            UserDefaults.standard.set(data, forKey: setsKey)
        }
    }

    private let emojiChoices: [String] = ["💪","🔥","🏃","⚡","🦵","🏃‍♀️","🧘‍♂️","🌱","🤸","🏋️","🚴","⛹️","🤾","🧗"]
    private func randomEmoji() -> String { emojiChoices.randomElement() ?? "💪" }

    // MARK: - Session Phase Enum
    enum SessionPhase: Equatable {
        case work(phaseIndex: Int)
        case rest(phaseIndex: Int)

        var isWork: Bool {
            if case .work = self { return true }
            return false
        }

        var phaseIndex: Int {
            switch self {
            case .work(let index), .rest(let index): return index
            }
        }
    }

    // MARK: - WorkoutProgramSessionCard (overlay during run)
    struct WorkoutProgramSessionCard: View {
        let set: WorkoutSet
        var close: () -> Void

        @EnvironmentObject private var liveActivity: LiveActivityController
        @EnvironmentObject private var streakManager: StreakManager

        private let gong = GongPlayer()

        @State private var sessionStart: Date = .now
        @State private var currentPhase: SessionPhase = .work(phaseIndex: 0)
        @State private var currentRound: Int = 1
        @State private var phaseStart: Date = .now
        @State private var finished = false

        var body: some View {
            ZStack {
                Color(.systemGray6).ignoresSafeArea()
                VStack(spacing: 12) {
                    if !finished {
                        Text(set.name).font(.headline)

                        // Dual Ring Progress + Timer
                        ProgressRingsView(
                            set: set,
                            currentPhase: $currentPhase,
                            currentRound: $currentRound,
                            phaseStart: $phaseStart,
                            finished: $finished,
                            sessionStart: sessionStart,
                            gong: gong,
                            onSessionEnd: { await endSession(manual: false) }
                        )
                    } else {
                        VStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.workoutViolet)
                            Text("Fertig").font(.subheadline.weight(.semibold))
                        }
                    }

                    Button("Beenden") {
                        Task {
                            await endSession(manual: true)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                }
                .frame(minWidth: 280, maxWidth: 360)
                .padding(16)
            }
            .overlay(alignment: .topTrailing) {
                Button(action: {
                    Task {
                        await endSession(manual: true)
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderedProminent)
                .tint(.secondary)
                .clipShape(Circle())
                .padding(8)
            }
            .task {
                // 1. Disable idle timer
                setIdleTimer(true)

                // 2. Play start sound
                gong.play(named: "gong")

                // 3. Start Live Activity
                let endDate = sessionStart.addingTimeInterval(TimeInterval(set.totalSeconds))
                liveActivity.start(
                    title: set.name,
                    phase: 1,
                    endDate: endDate,
                    ownerId: "WorkoutsTab"
                )
            }
            .onDisappear {
                // Cleanup when session card closes
                Task {
                    await endSession(manual: true)
                }
            }
        }

        private func setIdleTimer(_ disabled: Bool) {
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = disabled
            #endif
        }

        func endSession(manual: Bool) async {
            print("[WorkoutPrograms] endSession(manual: \(manual)) called")

            // 1. Re-enable idle timer
            setIdleTimer(false)

            // 2. Stop all sounds (no active players to stop for GongPlayer)
            // GongPlayer handles cleanup automatically via delegate

            // 3. HealthKit Logging if session > 3s
            let endDate = Date()
            if sessionStart.distance(to: endDate) > 3 {
                do {
                    try await HealthKitManager.shared.logWorkout(
                        start: sessionStart,
                        end: endDate,
                        activity: .highIntensityIntervalTraining
                    )
                    print("[WorkoutPrograms] HealthKit workout logged")

                    // 4. Update streaks after successful HealthKit log
                    await streakManager.updateStreaks()
                } catch {
                    print("[WorkoutPrograms] HealthKit logging failed: \(error)")
                }
            }

            // 5. End Live Activity
            await liveActivity.end(immediate: true)
            print("[WorkoutPrograms] LiveActivity ended")

            // 6. Play end sound if session completed
            if !manual {
                gong.play(named: "gong-ende")
            }

            // 7. Small delay for UI feedback
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s

            // 8. Close the view
            print("[WorkoutPrograms] close() called")
            close()
        }
    }

    // MARK: - ProgressRingsView (timer + dual rings)
    struct ProgressRingsView: View {
        let set: WorkoutSet
        @Binding var currentPhase: SessionPhase
        @Binding var currentRound: Int
        @Binding var phaseStart: Date
        @Binding var finished: Bool
        let sessionStart: Date
        let gong: GongPlayer
        let onSessionEnd: () async -> Void

        @State private var currentTime: Date = Date()
        @State private var timer: Timer?

        var body: some View {
            VStack(spacing: 8) {
                let now = currentTime

                // Calculate total session progress
                let totalSeconds = Double(set.totalSeconds)
                let elapsedTotal = now.timeIntervalSince(sessionStart)
                let progressTotal = max(0.0, min(1.0, elapsedTotal / totalSeconds))

                // Calculate current phase progress
                let phase = set.phases[currentPhase.phaseIndex]
                let phaseDuration = Double(currentPhase.isWork ? phase.workDuration : phase.restDuration)
                let elapsedPhase = now.timeIntervalSince(phaseStart)
                let progressPhase = max(0.0, min(1.0, elapsedPhase / phaseDuration))

                ZStack {
                    // Outer ring: total session
                    CircularRing(progress: progressTotal, lineWidth: 22)
                        .foregroundStyle(Color.workoutViolet)
                    // Inner ring: current phase
                    CircularRing(progress: progressPhase, lineWidth: 14)
                        .scaleEffect(0.72)
                        .foregroundStyle(.secondary)
                    // Center: Phase name + icon
                    VStack(spacing: 8) {
                        Image(systemName: currentPhase.isWork ? "flame" : "pause")
                            .font(.system(size: 48, weight: .regular))
                            .foregroundStyle(Color.workoutViolet)
                        Text(phase.name)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text(currentPhase.isWork ? "Belastung" : "Erholung")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 200)
                }
                .frame(width: 320, height: 320)
                .padding(.top, 6)

                Text("Runde \(currentRound) / \(set.repetitions)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .onAppear {
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
        }

        private func startTimer() {
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                currentTime = Date()
                checkProgress()
            }
        }

        private func stopTimer() {
            timer?.invalidate()
            timer = nil
        }

        private func checkProgress() {
            let now = currentTime
            let phase = set.phases[currentPhase.phaseIndex]
            let phaseDuration = Double(currentPhase.isWork ? phase.workDuration : phase.restDuration)
            let elapsed = now.timeIntervalSince(phaseStart)

            if elapsed >= phaseDuration {
                advancePhase()
            }
        }

        private func advancePhase() {
            switch currentPhase {
            case .work(let index):
                // Work finished → go to rest (if restDuration > 0)
                if set.phases[index].restDuration > 0 {
                    currentPhase = .rest(phaseIndex: index)
                    phaseStart = Date()
                    // No sound for work → rest transition (too frequent)
                } else {
                    // No rest, go to next phase
                    goToNextPhase(from: index)
                }

            case .rest(let index):
                // Rest finished → go to next phase
                goToNextPhase(from: index)
            }
        }

        private func goToNextPhase(from index: Int) {
            let nextIndex = index + 1
            if nextIndex < set.phases.count {
                // Next phase in current round
                currentPhase = .work(phaseIndex: nextIndex)
                phaseStart = Date()
                // Play phase transition sound
                gong.play(named: "gong-dreimal")
            } else {
                // Round finished
                if currentRound < set.repetitions {
                    // Start next round
                    currentRound += 1
                    currentPhase = .work(phaseIndex: 0)
                    phaseStart = Date()
                    // Play round transition sound
                    gong.play(named: "gong-dreimal")
                } else {
                    // All rounds finished
                    finished = true
                    // Call session end automatically
                    Task {
                        await onSessionEnd()
                    }
                }
            }
        }
    }

    // MARK: - WorkoutSetRow (list item)
    struct WorkoutSetRow: View {
        let set: WorkoutSet
        let play: () -> Void
        let edit: () -> Void
        let showInfo: (() -> Void)?

        var body: some View {
            WorkoutGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    // TOP ~2/3: Emoji, Title, Play
                    HStack(alignment: .center, spacing: 14) {
                        Text(set.emoji)
                            .font(.system(size: 42))
                        Text(set.name)
                            .font(.system(size: 22, weight: .bold))
                        Spacer()
                        Button(action: play) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .bold))
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .clipShape(Circle())
                        .accessibilityLabel("Start")
                    }

                    // Spacer to bias layout so bottom feels like lower third
                    Spacer(minLength: 8)

                    // BOTTOM ~1/3: details left, info + edit right
                    HStack(alignment: .center) {
                        Text("\(set.phaseCount) Phasen · \(set.repetitions) Runden · ≈ \(set.totalDurationString)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()

                        // Info button (only if description exists)
                        if set.description != nil, let showInfo = showInfo {
                            Button(action: showInfo) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 18, weight: .regular))
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Info")
                        }

                        Button(action: edit) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18, weight: .regular))
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Bearbeiten")
                    }
                }
                .frame(minHeight: 140)
            }
        }
    }

    // MARK: - Add Set Card
    struct AddSetCard: View {
        let action: () -> Void

        var body: some View {
            WorkoutGlassCard {
                HStack {
                    Spacer()
                    Button(action: action) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22, weight: .regular))
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .clipShape(Circle())
                    .accessibilityLabel("Neues Workout-Set hinzufügen")
                    Spacer()
                }
                .frame(minHeight: 70)
            }
        }
    }

    // MARK: - PresetInfoSheet
    struct PresetInfoSheet: View {
        let set: WorkoutSet
        @Environment(\.dismiss) private var dismiss

        private var recommendedUsage: String {
            // Extract recommended usage based on set name
            // These match the descriptions from the default presets
            switch set.name {
            case "Tabata Classic":
                return "Ideal als Warm-up vor Krafttraining oder als eigenständiges HIIT-Workout. Maximale Intensität erforderlich."
            case "Core Circuit":
                return "2-3x pro Woche für starke Rumpfmuskulatur. Perfekt als Ergänzung zu anderen Workouts."
            case "Full Body Burn":
                return "Als Haupt-Workout 3-4x pro Woche. Kombiniert Kraft, Ausdauer und funktionelle Bewegungen."
            case "Power Intervals":
                return "Für fortgeschrittene Athleten 2-3x pro Woche. Fokus auf explosive Kraft und Schnelligkeit."
            case "Hintere Kette":
                return "Ergänzend zu Sitz-Tätigkeit oder nach dem Laufen. Korrigiert muskuläre Dysbalancen."
            case "Jogging Warm-up":
                return "Vor jedem Lauf-Training. Bereitet Gelenke, Sehnen und Muskeln auf die Belastung vor."
            case "Post-Run Stretching":
                return "Direkt nach dem Laufen (innerhalb 10 min). Fördert Regeneration und Beweglichkeit."
            case "Beginner Flow":
                return "Perfekter Einstieg für Anfänger. Täglich oder jeden 2. Tag für Gewöhnung an regelmäßige Bewegung."
            case "Quick Burn":
                return "Täglich in der Mittagspause oder morgens. Kurz, effektiv, keine Ausreden."
            case "Upper Body Push":
                return "2x pro Woche als Push-Day. Kombiniere mit Pull-Workout für ausgewogenes Training."
            default:
                return "Regelmäßige Durchführung für beste Ergebnisse."
            }
        }

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header: Emoji + Name
                        HStack(spacing: 16) {
                            Text(set.emoji)
                                .font(.system(size: 60))
                            Text(set.name)
                                .font(.system(size: 28, weight: .bold))
                            Spacer()
                        }
                        .padding(.top, 8)

                        // Structure Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Struktur")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("\(set.phaseCount) Phasen · \(set.repetitions) Runden")
                                .font(.title3)
                            Text("Gesamtdauer: ≈ \(set.totalDurationString)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        // Phases Overview Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Übungen")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(set.phases.enumerated()), id: \.offset) { index, phase in
                                    HStack {
                                        Text("\(index + 1).")
                                            .foregroundStyle(.tertiary)
                                            .frame(width: 24, alignment: .trailing)
                                        Text(phase.name)
                                            .font(.body)
                                        Spacer()
                                        Text("\(phase.workDuration)s")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        // Description Section
                        if let description = set.description {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Beschreibung")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text(description)
                                    .font(.body)
                            }
                        }

                        // Recommended Usage Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Empfohlene Anwendung")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text(recommendedUsage)
                                .font(.body)
                        }
                    }
                    .padding()
                }
                .navigationTitle("Workout-Info")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Fertig") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    // MARK: - SetEditorView (create/edit workout set)
    struct SetEditorView: View {
        @Environment(\.dismiss) private var dismiss
        @State private var draft: WorkoutSet
        @State private var editingPhase: WorkoutPhase? = nil
        let isNew: Bool
        let onSave: (WorkoutSet) -> Void
        let onDelete: ((UUID) -> Void)?

        init(set: WorkoutSet, isNew: Bool, onSave: @escaping (WorkoutSet) -> Void, onDelete: ((UUID) -> Void)? = nil) {
            self._draft = State(initialValue: set)
            self.isNew = isNew
            self.onSave = onSave
            self.onDelete = onDelete
        }

        private var totalString: String {
            let s = draft.totalSeconds
            let m = s / 60, r = s % 60
            return String(format: "≈ %d:%02d min", m, r)
        }

        var body: some View {
            NavigationView {
                Form {
                    Section("Icon") {
                        let choices = ["💪","🔥","🏃","⚡","🦵","🏃‍♀️","🧘‍♂️","🌱","🤸","🏋️","🚴","⛹️","🤾","🧗"]
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(choices, id: \.self) { e in
                                    Button {
                                        draft.emoji = e
                                    } label: {
                                        Text(e)
                                            .font(.system(size: 28))
                                            .padding(8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(draft.emoji == e ? Color.secondary.opacity(0.15) : Color.clear)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .strokeBorder(draft.emoji == e ? Color.secondary.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    Section("Name") {
                        TextField("Name", text: $draft.name)
                            .textInputAutocapitalization(.words)
                    }
                    Section("Runden") {
                        WorkoutWheelPicker("Wiederholungen", selection: $draft.repetitions, range: 1...99)
                    }
                    Section("Phasen") {
                        if draft.phases.isEmpty {
                            Text("Keine Phasen")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        } else {
                            ForEach(Array(draft.phases.enumerated()), id: \.element.id) { index, phase in
                                Button {
                                    editingPhase = phase
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(phase.name)
                                                .foregroundStyle(.primary)
                                            Text("Work: \(phase.workDuration)s  Rest: \(phase.restDuration)s")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .onDelete { indexSet in
                                draft.phases.remove(atOffsets: indexSet)
                            }
                            .onMove { from, to in
                                draft.phases.move(fromOffsets: from, toOffset: to)
                            }
                        }
                        Button {
                            // Create new phase with first exercise suggestion
                            let newPhase = WorkoutPhase(
                                name: exerciseSuggestions.first ?? "Neue Übung",
                                workDuration: 30,
                                restDuration: 15
                            )
                            editingPhase = newPhase
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Phase hinzufügen")
                            }
                        }
                    }
                    Section {
                        HStack {
                            Text("Gesamtdauer")
                            Spacer()
                            Text(totalString).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                    if !isNew, let onDelete {
                        Section {
                            Button(role: .destructive) {
                                onDelete(draft.id)
                                dismiss()
                            } label: { Text("Löschen") }
                        }
                    }
                }
                .navigationTitle(isNew ? "Neues Workout-Set" : "Workout-Set")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") {
                            onSave(draft); dismiss()
                        }
                        .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.phases.isEmpty)
                    }
                }
            }
            .sheet(item: $editingPhase) { phase in
                let phaseIndex = draft.phases.firstIndex(where: { $0.id == phase.id })
                let isLastPhase = phaseIndex == draft.phases.count - 1
                let isNewPhase = phaseIndex == nil

                PhaseEditorView(
                    phase: phase,
                    isNew: isNewPhase,
                    isLastPhase: isLastPhase,
                    onSave: { edited in
                        if let index = phaseIndex {
                            // Edit existing phase
                            draft.phases[index] = edited
                        } else {
                            // Add new phase
                            draft.phases.append(edited)
                        }
                    },
                    onDelete: {
                        if let index = phaseIndex {
                            draft.phases.remove(at: index)
                        }
                    }
                )
            }
        }
    }

    // MARK: - PhaseEditorView (create/edit individual phase)
    struct PhaseEditorView: View {
        @Environment(\.dismiss) private var dismiss
        @State private var draft: WorkoutPhase
        @State private var customExerciseName: String = ""
        @State private var useCustomExercise: Bool = false
        let isNew: Bool
        let isLastPhase: Bool
        let onSave: (WorkoutPhase) -> Void
        let onDelete: (() -> Void)?

        init(phase: WorkoutPhase, isNew: Bool, isLastPhase: Bool, onSave: @escaping (WorkoutPhase) -> Void, onDelete: (() -> Void)? = nil) {
            self._draft = State(initialValue: phase)
            self.isNew = isNew
            self.isLastPhase = isLastPhase
            self.onSave = onSave
            self.onDelete = onDelete

            // Check if phase uses a custom exercise (not in suggestions)
            let isCustom = !exerciseSuggestions.contains(phase.name)
            self._useCustomExercise = State(initialValue: isCustom)
            self._customExerciseName = State(initialValue: isCustom ? phase.name : "")
        }

        private var totalString: String {
            let total = draft.workDuration + draft.restDuration
            return "\(total)s"
        }

        var body: some View {
            NavigationView {
                Form {
                    Section("Übung") {
                        Picker("Name", selection: Binding(
                            get: { useCustomExercise ? "Eigene Übung..." : draft.name },
                            set: { newValue in
                                if newValue == "Eigene Übung..." {
                                    useCustomExercise = true
                                } else {
                                    useCustomExercise = false
                                    draft.name = newValue
                                }
                            }
                        )) {
                            ForEach(exerciseSuggestions, id: \.self) { exercise in
                                Text(exercise).tag(exercise)
                            }
                            Text("Eigene Übung...").tag("Eigene Übung...")
                        }
                        .pickerStyle(.menu)

                        if useCustomExercise {
                            TextField("Übungsname", text: $customExerciseName)
                                .textInputAutocapitalization(.words)
                        }
                    }
                    Section("Belastung") {
                        HStack {
                            Text("Dauer")
                            Spacer()
                            WorkoutWheelPicker("", selection: $draft.workDuration, range: 1...600)
                                .frame(width: 120, height: 100)
                            Text("s").foregroundStyle(.secondary)
                        }
                    }
                    Section(footer: isLastPhase ? Text("Letzte Phase im Set hat keine Pause.") : nil) {
                        HStack {
                            Text("Pause")
                            Spacer()
                            if isLastPhase {
                                Text("0s")
                                    .foregroundStyle(.secondary)
                            } else {
                                WorkoutWheelPicker("", selection: $draft.restDuration, range: 0...600)
                                    .frame(width: 120, height: 100)
                                Text("s").foregroundStyle(.secondary)
                            }
                        }
                    }
                    Section {
                        HStack {
                            Text("Gesamtdauer")
                            Spacer()
                            Text(totalString).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                    if !isNew, let onDelete {
                        Section {
                            Button(role: .destructive) {
                                onDelete()
                                dismiss()
                            } label: { Text("Löschen") }
                        }
                    }
                }
                .navigationTitle(isNew ? "Neue Phase" : "Phase bearbeiten")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") {
                            // Use custom exercise name if selected
                            if useCustomExercise {
                                draft.name = customExerciseName
                            }

                            // Force restDuration to 0 for last phase
                            if isLastPhase {
                                draft.restDuration = 0
                            }

                            onSave(draft)
                            dismiss()
                        }
                        .disabled(
                            useCustomExercise
                                ? customExerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                : draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                    }
                }
            }
        }
    }

    // MARK: - WorkoutWheelPicker (number wheel)
    struct WorkoutWheelPicker: View {
        let title: String
        @Binding var selection: Int
        let range: ClosedRange<Int>

        init(_ title: String, selection: Binding<Int>, range: ClosedRange<Int>) {
            self.title = title
            self._selection = selection
            self.range = range
        }

        var body: some View {
            Picker(title, selection: $selection) {
                ForEach(Array(range), id: \.self) { n in Text("\(n)").tag(n) }
            }
            .labelsHidden()
            .pickerStyle(.wheel)
        }
    }

    // MARK: - WorkoutGlassCard (styling container)
    struct WorkoutGlassCard<Content: View>: View {
        @ViewBuilder var content: () -> Content
        var body: some View {
            content()
                .padding(16)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.32), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
    }
}

#else
// Fallback for non-iOS platforms
public struct WorkoutProgramsView: View {
    public init() {}
    public var body: some View {
        Text("Workout-Programme sind nur auf iOS verfügbar.")
    }
}
#endif
