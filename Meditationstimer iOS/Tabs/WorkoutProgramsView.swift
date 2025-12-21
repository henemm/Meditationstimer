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

// MARK: - Sound Cues for Workout
fileprivate enum Cue: String {
    case countdownTransition = "countdown-transition" // 3x beep + long tone (combined)
    case auftakt    // pre-start cue before first work
    case ausklang   // final chime at end of last work
}

fileprivate final class SoundPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    private var urls: [Cue: URL] = [:]  // Cache URLs, not players
    private var activePlayers: [AVAudioPlayer] = []  // Currently playing sounds
    private var prepared = false
    private let speech = AVSpeechSynthesizer()

    /// Aktiviert die Audio-Session vor jeder Wiedergabe (EXAKT wie GongPlayer!)
    private func activateSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        // WICHTIG: Exakt wie GongPlayer - OHNE mode: Parameter!
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true, options: [])
        #endif
    }

    func prepare() {
        guard !prepared else { return }
        activateSession()
        print("[Sound] Audio session configured successfully")
        // Cache URLs for each cue (check .caff, .caf, .wav, .mp3, .aiff)
        for cue in [Cue.countdownTransition, .auftakt, .ausklang] {
            let name = cue.rawValue
            let exts = ["caff", "caf", "wav", "mp3", "aiff"]
            var found: URL? = nil
            for ext in exts {
                if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                    found = url
                    break
                }
            }
            if let url = found {
                urls[cue] = url
                print("[Sound] found \(name)")
            } else {
                print("[Sound] MISSING \(name).(caff|caf|wav|mp3|aiff)")
            }
        }
        prepared = true
    }

    func play(_ cue: Cue) {
        prepare()
        activateSession()  // Reaktiviere Audio-Session vor jeder Wiedergabe
        guard let url = urls[cue] else {
            print("[Sound] cannot play \(cue.rawValue): URL not found")
            return
        }

        // Create NEW player for each playback (allows parallel sounds)
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.prepareToPlay()
            p.play()
            activePlayers.append(p)
            print("[Sound] play \(cue.rawValue) (active players: \(activePlayers.count))")
        } catch {
            print("[Sound] failed to create player for \(cue.rawValue): \(error)")
        }
    }

    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if let idx = activePlayers.firstIndex(where: { $0 === player }) {
            activePlayers.remove(at: idx)
            print("[Sound] removed finished player (remaining: \(activePlayers.count))")
        }
    }

    func play(_ cue: Cue, after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.play(cue)
        }
    }

    func speak(_ text: String) {
        prepare()
        activateSession()  // Reaktiviere Audio-Session vor jeder Wiedergabe
        let u = AVSpeechUtterance(string: text)
        // Sprache automatisch aus App-Locale ermitteln
        let languageCode = Locale.current.language.languageCode?.identifier ?? "de"
        let voiceLanguage = languageCode == "en" ? "en-US" : "de-DE"
        u.voice = AVSpeechSynthesisVoice(language: voiceLanguage)
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        speech.speak(u)
    }

    func speak(_ text: String, after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.speak(text)
        }
    }

    func stopAll() {
        for p in activePlayers {
            p.stop()
        }
        activePlayers.removeAll()
        speech.stopSpeaking(at: .immediate)
    }

    func duration(of cue: Cue) -> TimeInterval {
        prepare()
        guard let url = urls[cue] else { return 0 }
        // Create temporary player to get duration
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return 0 }
        return p.duration
    }
}

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
                                // NOTE: restDuration of last phase is used for pauses between rounds

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
    "Plank",
    "Side Plank Left",
    "Side Plank Right",
    "Hollow Hold",
    "Dead Bug",
    "Bicycle Crunches",
    "Russian Twists",
    "Leg Raises",
    "Flutter Kicks",
    "Mountain Climbers",
    "V-Ups",
    "Sit-ups",
    "Crunches",
    "Plank to Downward Dog",

    // Push (Upper body pushing)
    "Push-ups",
    "Diamond Push-ups",
    "Wide Push-ups",
    "Pike Push-ups",
    "Archer Push-ups",
    "Decline Push-ups",
    "Wall Push-ups",
    "Dips",

    // Pull (Upper body pulling)
    "Pull-ups",
    "Chin-ups",
    "Australian Pull-ups",
    "Inverted Rows",

    // Legs
    "Squats",
    "Jump Squats",
    "Lunges",
    "Reverse Lunges",
    "Walking Lunges",
    "Bulgarian Split Squats Left",
    "Bulgarian Split Squats Right",
    "Single-Leg Deadlift Left",
    "Single-Leg Deadlift Right",
    "Calf Raises",
    "Glute Bridges",
    "Step-ups",
    "Wall-Sit",
    "Standing Knee Raises",

    // Cardio / Full Body
    "Burpees",
    "Jumping Jacks",
    "High Knees",
    "Butt Kicks",
    "Box Jumps",
    "Skater Hops",
    "Jump Rope",
    "Marching in Place",

    // Stretching
    "Downward Dog",
    "Child's Pose",
    "Cobra Stretch",
    "Cat-Cow",
    "Seated Forward Bend",
    "Butterfly Stretch",
    "Hip Flexor Stretch Left",
    "Hip Flexor Stretch Right",
    "Quadriceps Stretch Left",
    "Quadriceps Stretch Right",
    "Hamstring Stretch Left",
    "Hamstring Stretch Right",
    "Calf Stretch Left",
    "Calf Stretch Right",
    "Shoulder Stretch Left",
    "Shoulder Stretch Right",
    "Leg Swing Left",
    "Leg Swing Right",
    "Beinpendel links",
    "Beinpendel rechts",
    "Hip Circles",
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
        description: NSLocalizedString("Original Tabata protocol (Izumi Tabata, 1996): 8 rounds of 20s maximum intensity / 10s rest. Proven to increase VO2max by up to 14% in 6 weeks. Requires 170% VO2max intensity.", comment: "Tabata workout description")
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
            WorkoutPhase(name: "Russian Twists", workDuration: 40, restDuration: 10),
        ],
        repetitions: 3,
        description: NSLocalizedString("Focuses on core stability and rotational strength. Combines isometric (planks) and dynamic exercises for comprehensive core strengthening. Improves posture and reduces back pain.", comment: "Core Circuit workout description")
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
            WorkoutPhase(name: "Planke", workDuration: 45, restDuration: 10),
        ],
        repetitions: 3,
        description: NSLocalizedString("Full-body HIIT focused on functional movement patterns. Combines strength, cardio, and core stability. Maximum calorie burn through engagement of large muscle groups.", comment: "Full Body Burn workout description")
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
            WorkoutPhase(name: "Hampelmänner", workDuration: 40, restDuration: 10),
        ],
        repetitions: 4,
        description: NSLocalizedString("Explosive plyometric exercises to increase power and anaerobic capacity. Optimal for fat burning and cardiovascular fitness. EPOC effect (afterburn) lasts up to 24 hours.", comment: "Power Intervals workout description")
    ),

    // 5. Hintere Kette 🦵
    WorkoutSet(
        name: "Hintere Kette",
        emoji: "🦵",
        phases: [
            WorkoutPhase(name: "Glute Bridges", workDuration: 45, restDuration: 15),
            WorkoutPhase(name: "Einbeiniges Kreuzheben links", workDuration: 20, restDuration: 10),
            WorkoutPhase(name: "Einbeiniges Kreuzheben rechts", workDuration: 20, restDuration: 15),
            WorkoutPhase(name: "Bulgarische Split-Kniebeugen links", workDuration: 20, restDuration: 10),
            WorkoutPhase(name: "Bulgarische Split-Kniebeugen rechts", workDuration: 20, restDuration: 15),
            WorkoutPhase(name: "Reverse-Ausfallschritte", workDuration: 40, restDuration: 15),
            WorkoutPhase(name: "Wadenheben", workDuration: 30, restDuration: 10),
        ],
        repetitions: 3,
        description: NSLocalizedString("Targeted training of the posterior chain (glutes, hamstrings, lower back, calves). Essential for running economy, sprint speed, and injury prevention. Corrects imbalances from sitting.", comment: "Hintere Kette workout description")
    ),

    // 6. Jogging Warm-up 🏃‍♀️
    WorkoutSet(
        name: "Jogging Warm-up",
        emoji: "🏃‍♀️",
        phases: [
            WorkoutPhase(name: "High Knees", workDuration: 30, restDuration: 10),
            WorkoutPhase(name: "Butt Kicks", workDuration: 30, restDuration: 10),
            WorkoutPhase(name: "Beinpendel links", workDuration: 15, restDuration: 5),
            WorkoutPhase(name: "Beinpendel rechts", workDuration: 15, restDuration: 10),
            WorkoutPhase(name: "Ausfallschritte gehend", workDuration: 40, restDuration: 10),
            WorkoutPhase(name: "Hüftkreisen", workDuration: 30, restDuration: 10),
        ],
        repetitions: 2,
        description: NSLocalizedString("Dynamic warm-up for runners. Activates hip muscles, increases range of motion, and prepares the body for running load. Reduces injury risk by up to 35%.", comment: "Jogging Warm-up workout description")
    ),

    // 7. Post-Run Stretching 🧘‍♂️
    WorkoutSet(
        name: "Post-Run Stretching",
        emoji: "🧘‍♂️",
        phases: [
            WorkoutPhase(name: "Quadrizeps-Dehnung links", workDuration: 22, restDuration: 5),
            WorkoutPhase(name: "Quadrizeps-Dehnung rechts", workDuration: 22, restDuration: 10),
            WorkoutPhase(name: "Hamstring-Dehnung links", workDuration: 22, restDuration: 5),
            WorkoutPhase(name: "Hamstring-Dehnung rechts", workDuration: 22, restDuration: 10),
            WorkoutPhase(name: "Hüftbeuger-Dehnung links", workDuration: 22, restDuration: 5),
            WorkoutPhase(name: "Hüftbeuger-Dehnung rechts", workDuration: 22, restDuration: 10),
            WorkoutPhase(name: "Waden-Dehnung links", workDuration: 22, restDuration: 5),
            WorkoutPhase(name: "Waden-Dehnung rechts", workDuration: 22, restDuration: 10),
            WorkoutPhase(name: "Schmetterlings-Dehnung", workDuration: 60, restDuration: 10),
            WorkoutPhase(name: "Kindspose", workDuration: 60, restDuration: 0),
        ],
        repetitions: 1,
        description: NSLocalizedString("Static stretching for recovery after running. Focus on hip and leg muscles. Reduces muscle soreness (DOMS), improves flexibility, and promotes circulation. Hold each stretch for at least 30 seconds.", comment: "Post-Run Stretching workout description")
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
        description: NSLocalizedString("Gentle introduction to HIIT training. Joint-friendly variations with longer rest periods (1:1 ratio). Ideal for building basic fitness and technique. Progressive by adding rounds or reducing rest.", comment: "Beginner Flow workout description")
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
        description: NSLocalizedString("Compact 6-minute workout for maximum efficiency. Combines cardio and core for quick calorie burn. Perfect for time-constrained days or as a finisher after strength training.", comment: "Quick Burn workout description")
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
        description: NSLocalizedString("Focused training of push muscles (chest, triceps, shoulders). Progression through push-up variations with different focus points. Complements pull training for balanced upper body development.", comment: "Upper Body Push workout description")
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

        @AppStorage("speakExerciseNames") private var speakExerciseNames: Bool = false

        @StateObject private var sounds = SoundPlayer()

        @State private var sessionStart: Date = .now
        @State private var currentPhase: SessionPhase = .work(phaseIndex: 0)
        @State private var currentRound: Int = 1
        @State private var phaseStart: Date = .now
        @State private var finished = false
        @State private var isPaused = false
        @State private var pausedAt: Date?
        @State private var pausedPhaseAccum: TimeInterval = 0
        @State private var pausedSessionAccum: TimeInterval = 0
        @State private var sessionEnded: Bool = false  // Prevent double HealthKit logging
        @AppStorage("countdownBeforeStart") private var countdownBeforeStart: Int = 0
        @State private var showCountdown = false

        var body: some View {
            ZStack {
                Color(.systemGray6).ignoresSafeArea()
                VStack(spacing: 12) {
                    if !finished {
                        Text(LocalizedStringKey(set.name)).font(.headline)

                        // Dual Ring Progress + Timer
                        ProgressRingsView(
                            set: set,
                            currentPhase: $currentPhase,
                            currentRound: $currentRound,
                            phaseStart: $phaseStart,
                            finished: $finished,
                            sessionStart: sessionStart,
                            sounds: sounds,
                            speakExerciseNames: speakExerciseNames,
                            isPaused: $isPaused,
                            pausedPhaseAccum: $pausedPhaseAccum,
                            pausedSessionAccum: $pausedSessionAccum,
                            onSessionEnd: { await endSession(manual: false) }
                        )
                    } else {
                        VStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.workoutViolet)
                            Text(NSLocalizedString("Done", comment: "Session completed")).font(.subheadline.weight(.semibold))
                        }
                    }

                    Button(isPaused ? NSLocalizedString("Continue", comment: "Button") : NSLocalizedString("Pause", comment: "Button")) {
                        togglePause()
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
                // 0. Prepare audio session
                sounds.prepare()

                // 1. Disable idle timer
                setIdleTimer(true)

                // 2. Countdown vor Start (wenn aktiviert)
                if countdownBeforeStart > 0 {
                    showCountdown = true
                } else {
                    beginSessionAfterCountdown()
                }
            }
            .fullScreenCover(isPresented: $showCountdown) {
                CountdownOverlayView(
                    totalSeconds: countdownBeforeStart,
                    onComplete: {
                        showCountdown = false
                        beginSessionAfterCountdown()
                    },
                    onCancel: {
                        showCountdown = false
                        close()
                    }
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

        /// Starts the actual workout session (called after optional countdown)
        private func beginSessionAfterCountdown() {
            // 1. Announce first exercise (if TTS enabled)
            if speakExerciseNames {
                let totalExercises = set.phases.count
                let text = String(format: NSLocalizedString("Exercise %d of %d: %@", comment: "TTS announcement for exercise number"), 1, totalExercises, set.phases[0].name)
                sounds.speak(text)
            }

            // 2. Play start sound (Auftakt)
            sounds.play(.auftakt)

            // 3. Start Live Activity
            let endDate = sessionStart.addingTimeInterval(TimeInterval(set.totalSeconds))
            liveActivity.start(
                title: set.name,
                phase: 1,
                endDate: endDate,
                ownerId: "WorkoutsTab"
            )
        }

        func endSession(manual: Bool) async {
            print("[WorkoutPrograms] endSession(manual: \(manual)) called")

            // Guard: Prevent double execution (callback + onDisappear)
            if sessionEnded {
                print("[WorkoutPrograms] endSession already executed, skipping duplicate call")
                return
            }

            // 1. Re-enable idle timer
            setIdleTimer(false)

            // 2. Stop all sounds
            // GongPlayer handles cleanup automatically via delegate
            // Scheduled sounds cancelled by ProgressRingsView.onDisappear

            // 3. HealthKit Logging if session > 3s (runs in background)
            let endDate = Date()
            if sessionStart.distance(to: endDate) > 3 {
                // Mark session as ended BEFORE async logging starts
                sessionEnded = true

                Task.detached(priority: .userInitiated) {
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
            } else {
                // Session < 3s: no HealthKit logging, but still mark as ended
                sessionEnded = true
            }

            // 5. End Live Activity
            await liveActivity.end(immediate: true)
            print("[WorkoutPrograms] LiveActivity ended")

            // 6. Play end sound if session completed naturally
            // Wait for sound to finish before closing (prevents cutoff)
            if !manual {
                let soundDuration = sounds.duration(of: .ausklang)
                sounds.play(.ausklang)
                // Wait for sound duration + 0.3s buffer
                let waitNanoseconds = UInt64((soundDuration + 0.3) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: waitNanoseconds)
            } else {
                // Manual stop: small delay for UI feedback
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            }

            // 7. Close the view
            print("[WorkoutPrograms] close() called")
            close()
        }

        private func togglePause() {
            if !isPaused {
                // PAUSE
                isPaused = true
                pausedAt = Date()
                sounds.stopAll()
                // Scheduled sounds cancelled by ProgressRingsView's checkProgress guard
                print("[WorkoutPrograms] Session PAUSED")
                // LiveActivity: Pause-Status setzen
                let now = Date()
                let elapsedSession = max(0, now.timeIntervalSince(sessionStart) - pausedSessionAccum)
                let remaining = max(0, TimeInterval(set.totalSeconds) - elapsedSession)
                let pausedEndDate = now.addingTimeInterval(remaining)
                Task { await liveActivity.update(phase: currentPhase.isWork ? 1 : 2, endDate: pausedEndDate, isPaused: true) }
            } else {
                // RESUME
                if let p = pausedAt {
                    let delta = Date().timeIntervalSince(p)
                    pausedSessionAccum += delta
                    pausedPhaseAccum += delta
                }
                pausedAt = nil
                isPaused = false
                print("[WorkoutPrograms] Session RESUMED")

                // Re-schedule auftakt sound if we're in REST phase
                if case .rest(let index) = currentPhase {
                    let now = Date()
                    let restDuration = Double(set.phases[index].restDuration)
                    let elapsedRest = now.timeIntervalSince(phaseStart) - pausedPhaseAccum
                    let remainingRest = max(0, restDuration - elapsedRest)

                    let auftaktDuration = sounds.duration(of: .auftakt)
                    let delay = max(0, remainingRest - auftaktDuration)

                    // Schedule auftakt sound directly
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        sounds.play(.auftakt)
                        print("[WorkoutPrograms] auftakt re-scheduled after resume, delay: \(delay)s")
                    }
                }

                // LiveActivity: Pause-Status zurücknehmen
                let now = Date()
                let elapsedSession = max(0, now.timeIntervalSince(sessionStart) - pausedSessionAccum)
                let remaining = max(0, TimeInterval(set.totalSeconds) - elapsedSession)
                let resumedEndDate = now.addingTimeInterval(remaining)
                Task { await liveActivity.update(phase: currentPhase.isWork ? 1 : 2, endDate: resumedEndDate, isPaused: false) }
            }
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
        fileprivate let sounds: SoundPlayer
        let speakExerciseNames: Bool
        @Binding var isPaused: Bool
        @Binding var pausedPhaseAccum: TimeInterval
        @Binding var pausedSessionAccum: TimeInterval
        let onSessionEnd: () async -> Void

        @State private var currentTime: Date = Date()
        @State private var timer: Timer?
        @State private var countdownTriggered = false  // Track countdown sound per phase
        @State private var scheduled: [DispatchWorkItem] = []  // Cancellable scheduled sounds
        @State private var showExerciseSheet = false  // For exercise detail sheet
        @State private var selectedExerciseName: String = ""  // Exercise name for sheet

        // MARK: - Computed Properties

        /// Returns what's coming next: "Als nächstes: Planke" or "Als nächstes: Runde 3 mit Planke"
        /// Used for REST phase display AND pause display
        private var nextExerciseInfo: String {
            let index = currentPhase.phaseIndex
            let nextIndex = index + 1

            if nextIndex < set.phases.count {
                // Next exercise in current round
                return "Als nächstes: \(set.phases[nextIndex].name)"
            } else if currentRound < set.repetitions {
                // Next round, first exercise
                let nextRound = currentRound + 1
                let firstExercise = set.phases[0].name
                if nextRound == set.repetitions {
                    return "Als nächstes: Letzte Runde mit \(firstExercise)"
                } else {
                    return "Als nächstes: Runde \(nextRound) mit \(firstExercise)"
                }
            } else {
                return "Erholung"  // Fallback (session ending)
            }
        }

        var body: some View {
            VStack(spacing: 8) {
                let now = currentTime

                // Calculate total session progress (accounting for paused time)
                let totalSeconds = Double(set.totalSeconds)
                let elapsedTotal = now.timeIntervalSince(sessionStart) - pausedSessionAccum
                let progressTotal = max(0.0, min(1.0, elapsedTotal / totalSeconds))

                // Calculate current phase progress (accounting for paused time)
                let phase = set.phases[currentPhase.phaseIndex]
                let phaseDuration = Double(currentPhase.isWork ? phase.workDuration : phase.restDuration)
                let elapsedPhase = now.timeIntervalSince(phaseStart) - pausedPhaseAccum
                let progressPhase = max(0.0, min(1.0, elapsedPhase / phaseDuration))

                ZStack {
                    // Outer ring: total session
                    CircularRing(
                        progress: progressTotal,
                        lineWidth: 22,
                        gradient: LinearGradient(
                            colors: [Color.workoutViolet.opacity(0.8), Color.workoutViolet],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    // Inner ring: current phase
                    CircularRing(
                        progress: progressPhase,
                        lineWidth: 14,
                        gradient: LinearGradient(
                            colors: [Color.workoutViolet.opacity(0.5), Color.workoutViolet.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(0.72)
                    // Center: Phase name + icon (or Pause message)
                    VStack(spacing: 8) {
                        if isPaused {
                            // During PAUSE
                            if currentPhase.isWork {
                                // WORK phase paused: show current exercise
                                exerciseNameWithInfoButton(phase.name)

                                Text(nextExerciseInfo)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            } else {
                                // REST phase paused: show ONLY next exercise (same as running)
                                Image(systemName: "pause")
                                    .font(.system(size: 48, weight: .regular))
                                    .foregroundStyle(Color.workoutViolet)

                                nextExerciseNameWithInfoButton()
                            }
                        } else {
                            // During SESSION
                            if currentPhase.isWork {
                                // WORK phase: show flame icon + current exercise
                                Image(systemName: "flame")
                                    .font(.system(size: 48, weight: .regular))
                                    .foregroundStyle(Color.workoutViolet)

                                exerciseNameWithInfoButton(phase.name)

                                Text("Exercise")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                // REST phase: show pause icon + ONLY next exercise
                                Image(systemName: "pause")
                                    .font(.system(size: 48, weight: .regular))
                                    .foregroundStyle(Color.workoutViolet)

                                // Show next exercise name with info button
                                nextExerciseNameWithInfoButton()
                            }
                        }
                    }
                    .frame(width: 200)
                }
                .frame(width: 320, height: 320)
                .padding(.top, 6)

                // Exercise counter + Round counter
                VStack(spacing: 2) {
                    Text(String(format: NSLocalizedString("Exercise %lld / %lld", comment: ""), currentPhase.phaseIndex + 1, set.phases.count))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(String(format: NSLocalizedString("Round %lld / %lld", comment: ""), currentRound, set.repetitions))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                startTimer()
            }
            .onDisappear {
                stopTimer()
                cancelScheduled()  // Clean up scheduled sounds on disappear
            }
            .onChange(of: isPaused) { _, newValue in
                if newValue {  // Paused
                    cancelScheduled()  // Cancel all scheduled sounds
                    countdownTriggered = false  // Reset countdown flag
                    print("[WorkoutPrograms] ProgressRingsView: Pause detected, cancelled scheduled sounds")
                }
            }
            .sheet(isPresented: $showExerciseSheet) {
                ExerciseDetailSheet(exerciseName: selectedExerciseName)
            }
        }

        @ViewBuilder
        private func exerciseNameWithInfoButton(_ name: String) -> some View {
            HStack(spacing: 6) {
                Text(name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Button {
                    selectedExerciseName = name
                    showExerciseSheet = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(Color.workoutViolet)
                }
                .buttonStyle(.plain)
            }
        }

        @ViewBuilder
        private func nextExerciseNameWithInfoButton() -> some View {
            let index = currentPhase.phaseIndex

            // Determine next exercise info
            let nextInfo = getNextExerciseInfo(afterIndex: index)

            VStack(spacing: 4) {
                // "Up next" prefix in small font
                Text(nextInfo.prefix)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // Exercise name in large font with info button
                HStack(spacing: 6) {
                    Text(LocalizedStringKey(nextInfo.name))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Button {
                        selectedExerciseName = nextInfo.name
                        showExerciseSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(Color.workoutViolet)
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        /// Helper function to determine next exercise name, prefix text, and full label
        private func getNextExerciseInfo(afterIndex index: Int) -> (name: String, prefix: String, label: String) {
            let nextIndex = index + 1

            if nextIndex < set.phases.count {
                // Next exercise in current round
                let nextExerciseName = set.phases[nextIndex].name
                return (nextExerciseName, "Up next", "Up next: \(nextExerciseName)")
            } else if currentRound < set.repetitions {
                // Next round, first exercise
                let firstExercise = set.phases[0].name
                let nextRound = currentRound + 1
                if nextRound == set.repetitions {
                    return (firstExercise, "Up next", "Up next: Last round with \(firstExercise)")
                } else {
                    return (firstExercise, "Up next", "Up next: Round \(nextRound) with \(firstExercise)")
                }
            } else {
                // Fallback (should not happen during REST)
                return ("Recovery", "", "Recovery")
            }
        }

        private func startTimer() {
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                // Only update time if NOT paused (freeze UI during pause)
                if !isPaused {
                    currentTime = Date()
                }
                checkProgress()
            }
        }

        private func stopTimer() {
            timer?.invalidate()
            timer = nil
        }

        private func checkProgress() {
            // SKIP progress check during PAUSE
            if isPaused { return }

            let now = currentTime
            let phase = set.phases[currentPhase.phaseIndex]
            let phaseDuration = Double(currentPhase.isWork ? phase.workDuration : phase.restDuration)
            let elapsed = now.timeIntervalSince(phaseStart) - pausedPhaseAccum

            // COUNTDOWN MONITORING (exactly like Frei-Tab)
            // During WORK phase: play countdown-transition at remaining <= 3.0s
            if currentPhase.isWork && !countdownTriggered {
                let remaining = phaseDuration - elapsed
                if remaining <= 3.0 && remaining > 0 {
                    countdownTriggered = true
                    sounds.play(.countdownTransition)
                    print("[WorkoutPrograms] countdown-transition triggered, remaining: \(remaining)s")
                }
            }

            if elapsed >= phaseDuration {
                advancePhase()
            }
        }

        // MARK: - Sound Scheduling Helpers

        /// Cancel all scheduled sounds (called during pause and session end)
        private func cancelScheduled() {
            scheduled.forEach { $0.cancel() }
            scheduled.removeAll()
        }

        /// Schedule a sound with a delay (cancellable via cancelScheduled)
        private func schedule(_ delay: TimeInterval, action: @escaping () -> Void) {
            let w = DispatchWorkItem(block: action)
            scheduled.append(w)
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay), execute: w)
        }

        /// Returns announcement text for what's coming next after current REST phase (FOR UI DISPLAY)
        private func getNextAnnouncementText(afterIndex index: Int) -> String {
            let nextIndex = index + 1
            if nextIndex < set.phases.count {
                // Next exercise in current round
                return "Up next: \(set.phases[nextIndex].name)"
            } else if currentRound < set.repetitions {
                // Next round, first exercise
                let nextRound = currentRound + 1
                let firstExercise = set.phases[0].name
                if nextRound == set.repetitions {
                    return "Up next: Last round with \(firstExercise)"
                } else {
                    return "Up next: Round \(nextRound) with \(firstExercise)"
                }
            } else {
                return ""  // No next (shouldn't happen)
            }
        }

        /// Returns TTS announcement for next exercise with number: "Up next exercise 2 of 5 Plank"
        private func getNextExerciseNameForTTS(afterIndex index: Int) -> String {
            let nextIndex = index + 1
            if nextIndex < set.phases.count {
                // Next exercise in current round
                let exerciseName = set.phases[nextIndex].name
                let exerciseNum = nextIndex + 1
                let totalExercises = set.phases.count

                // Check if last exercise AND last round
                if nextIndex == set.phases.count - 1 && currentRound == set.repetitions {
                    return String(format: NSLocalizedString("Last exercise: %@", comment: "TTS for last exercise"), exerciseName)
                } else {
                    return String(format: NSLocalizedString("Exercise %d of %d: %@", comment: "TTS announcement for exercise number"), exerciseNum, totalExercises, exerciseName)
                }
            } else if currentRound < set.repetitions {
                // Next round, first exercise
                let nextRound = currentRound + 1
                let firstExercise = set.phases[0].name
                if nextRound == set.repetitions {
                    return String(format: NSLocalizedString("Last round: %@", comment: "TTS for last round"), firstExercise)
                } else {
                    return String(format: NSLocalizedString("Round %d: %@", comment: "TTS for round number"), nextRound, firstExercise)
                }
            } else {
                return ""  // No next (shouldn't happen)
            }
        }

        private func advancePhase() {
            switch currentPhase {
            case .work(let index):
                // Work finished → check if we need a REST phase
                let isLastPhaseInSet = (index == set.phases.count - 1)
                let isFinalRound = (currentRound == set.repetitions)
                let needsRest = set.phases[index].restDuration > 0 && !(isLastPhaseInSet && isFinalRound)

                if needsRest {
                    currentPhase = .rest(phaseIndex: index)
                    phaseStart = Date()
                    countdownTriggered = false  // Reset for next phase

                    // TTS ANNOUNCEMENT (if enabled) - speak ONLY exercise name
                    if speakExerciseNames {
                        let ttsText = getNextExerciseNameForTTS(afterIndex: index)
                        if !ttsText.isEmpty {
                            sounds.speak(ttsText)
                            print("[WorkoutPrograms] TTS: \(ttsText)")
                        }
                    }

                    // PRE-ROLL AUFTAKT SCHEDULING (exactly like Frei-Tab lines 564-566)
                    // Play auftakt so it ENDS exactly when next WORK phase starts
                    let restDuration = Double(set.phases[index].restDuration)
                    let auftaktDuration = sounds.duration(of: .auftakt)
                    let delay = max(0, restDuration - auftaktDuration)
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        sounds.play(.auftakt)
                        print("[WorkoutPrograms] auftakt triggered (pre-roll), delay: \(delay)s")
                    }
                } else {
                    // No rest needed (either restDuration=0 OR last phase of final round)
                    countdownTriggered = false  // Reset for next phase
                    goToNextPhase(from: index)
                }

            case .rest(let index):
                // Rest finished → go to next phase
                countdownTriggered = false  // Reset for next phase
                goToNextPhase(from: index)
            }
        }

        private func goToNextPhase(from index: Int) {
            let nextIndex = index + 1
            if nextIndex < set.phases.count {
                // Next phase in current round
                currentPhase = .work(phaseIndex: nextIndex)
                phaseStart = Date()
                // Sound will be handled by continuous monitoring system
            } else {
                // Round finished
                if currentRound < set.repetitions {
                    // Start next round
                    currentRound += 1
                    currentPhase = .work(phaseIndex: 0)
                    phaseStart = Date()
                    // Sound will be handled by continuous monitoring system
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
                        Text(LocalizedStringKey(set.name))
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
                        Text("\(set.phaseCount) x \(set.repetitions) = \(set.totalDurationString)")
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
                                .font(.system(size: 24, weight: .regular))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
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
        @State private var showExerciseSheet = false  // For exercise detail sheet
        @State private var selectedExerciseName: String = ""  // Exercise name for sheet

        private var recommendedUsage: String {
            // Extract recommended usage based on set name
            // These match the descriptions from the default presets
            switch set.name {
            case "Tabata Classic":
                return NSLocalizedString("Ideal as warm-up before strength training or as standalone HIIT workout. Maximum intensity required.", comment: "")
            case "Core Circuit":
                return NSLocalizedString("2-3x per week for strong core muscles. Perfect as supplement to other workouts.", comment: "")
            case "Full Body Burn":
                return NSLocalizedString("As main workout 3-4x per week. Combines strength, endurance and functional movements.", comment: "")
            case "Power Intervals":
                return NSLocalizedString("For advanced athletes 2-3x per week. Focus on explosive strength and speed.", comment: "")
            case "Hintere Kette":
                return NSLocalizedString("Complementary to sedentary activities or after running. Corrects muscular imbalances.", comment: "")
            case "Jogging Warm-up":
                return NSLocalizedString("Before every running session. Prepares joints, tendons and muscles for the stress.", comment: "")
            case "Post-Run Stretching":
                return NSLocalizedString("Directly after running (within 10 min). Promotes recovery and mobility.", comment: "")
            case "Beginner Flow":
                return NSLocalizedString("Perfect start for beginners. Daily or every 2nd day to get used to regular exercise.", comment: "")
            case "Quick Burn":
                return NSLocalizedString("Daily during lunch break or in the morning. Short, effective, no excuses.", comment: "")
            case "Upper Body Push":
                return NSLocalizedString("2x per week as push day. Combine with pull workout for balanced training.", comment: "")
            default:
                return NSLocalizedString("Regular execution for best results.", comment: "")
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
                            Text(LocalizedStringKey(set.name))
                                .font(.system(size: 28, weight: .bold))
                            Spacer()
                        }
                        .padding(.top, 8)

                        // Structure Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("Structure", comment: ""))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text(String(format: NSLocalizedString("Exercises and Rounds", comment: ""), set.phaseCount, set.repetitions))
                                .font(.title3)
                            Text(String(format: NSLocalizedString("Total Duration: ≈ %@", comment: ""), set.totalDurationString))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        // Phases Overview Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("Exercises", comment: ""))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(set.phases.enumerated()), id: \.offset) { index, phase in
                                    phaseRow(index: index, phase: phase)
                                }
                            }
                        }

                        // Description Section
                        if let description = set.description {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(NSLocalizedString("Description", comment: ""))
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text(LocalizedStringKey(description))
                                    .font(.body)
                            }
                        }

                        // Recommended Usage Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("Recommended Application", comment: ""))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text(recommendedUsage)
                                .font(.body)
                        }
                    }
                    .padding()
                }
                .navigationTitle(NSLocalizedString("Workout Info", comment: ""))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(NSLocalizedString("Done", comment: "")) {
                            dismiss()
                        }
                    }
                }
                .sheet(isPresented: $showExerciseSheet) {
                    ExerciseDetailSheet(exerciseName: selectedExerciseName)
                }
            }
        }

        // MARK: - Helper Views

        /// Helper function to avoid compiler timeout with complex HStack
        @ViewBuilder
        private func phaseRow(index: Int, phase: WorkoutPhase) -> some View {
            HStack {
                Text("\(index + 1).")
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, alignment: .trailing)
                Text(LocalizedStringKey(phase.name))
                    .font(.body)
                Spacer()
                Button {
                    selectedExerciseName = phase.name
                    showExerciseSheet = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.workoutViolet)
                        .font(.body)
                }
                .buttonStyle(.plain)
                Text("\(phase.workDuration)s")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
            .frame(minHeight: 44)  // Apple HIG minimum touch target
            .padding(.vertical, 4)
            .contentShape(Rectangle())  // Make entire row tappable
        }
    }

    // Helper struct to make String identifiable for .sheet(item:)
    struct ExerciseSheetWrapper: Identifiable {
        let id = UUID()
        let name: String
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
                    Section(NSLocalizedString("Icon", comment: "Section header")) {
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
                    Section(NSLocalizedString("Name", comment: "Section header")) {
                        TextField(NSLocalizedString("Name", comment: "TextField placeholder"), text: $draft.name)
                            .textInputAutocapitalization(.words)
                    }
                    Section(NSLocalizedString("Rounds", comment: "Section header")) {
                        WorkoutWheelPicker(NSLocalizedString("Repetitions", comment: "Picker label"), selection: $draft.repetitions, range: 1...99)
                    }
                    Section(NSLocalizedString("Exercises", comment: "Section header")) {
                        if draft.phases.isEmpty {
                            Text(NSLocalizedString("No Exercises", comment: "Empty state"))
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        } else {
                            ForEach(Array(draft.phases.enumerated()), id: \.element.id) { index, phase in
                                Button {
                                    editingPhase = phase
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(LocalizedStringKey(phase.name))
                                                .foregroundStyle(.primary)
                                            Text(String(format: NSLocalizedString("Work: %llds  Rest: %llds", comment: ""), Int64(phase.workDuration), Int64(phase.restDuration)))
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
                                name: exerciseSuggestions.first ?? NSLocalizedString("New Exercise", comment: "Default name for new exercise"),
                                workDuration: 30,
                                restDuration: 15
                            )
                            editingPhase = newPhase
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text(NSLocalizedString("Add Exercise", comment: "Button"))
                            }
                        }
                    }
                    Section {
                        HStack {
                            Text(NSLocalizedString("Total Duration", comment: "Label"))
                            Spacer()
                            Text(totalString).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                    if !isNew, let onDelete {
                        Section {
                            Button(role: .destructive) {
                                onDelete(draft.id)
                                dismiss()
                            } label: { Text(NSLocalizedString("Delete", comment: "Button")) }
                        }
                    }
                }
                .navigationTitle(isNew ? NSLocalizedString("New Workout Set", comment: "Navigation title") : NSLocalizedString("Workout Set", comment: "Navigation title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(NSLocalizedString("Cancel", comment: "Button")) { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(NSLocalizedString("Save", comment: "Button")) {
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
            .onChange(of: draft.repetitions) { oldValue, newValue in
                // Update last phase rest duration based on repetitions
                guard !draft.phases.isEmpty else { return }
                let lastIndex = draft.phases.count - 1

                if newValue > 1 && oldValue == 1 {
                    // Changed from 1 round to multiple rounds: set 10s rest on last phase
                    draft.phases[lastIndex].restDuration = 10
                } else if newValue == 1 && oldValue > 1 {
                    // Changed from multiple rounds to 1 round: set 0s rest on last phase
                    draft.phases[lastIndex].restDuration = 0
                }
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
                    Section(NSLocalizedString("Exercise", comment: "Section header")) {
                        Picker(NSLocalizedString("Name", comment: "Picker label"), selection: Binding(
                            get: { useCustomExercise ? "Custom Exercise..." : draft.name },
                            set: { newValue in
                                if newValue == "Custom Exercise..." {
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
                            Text(NSLocalizedString("Custom Exercise...", comment: "Picker option")).tag("Custom Exercise...")
                        }
                        .pickerStyle(.menu)

                        if useCustomExercise {
                            TextField(NSLocalizedString("Exercise Name", comment: "TextField placeholder"), text: $customExerciseName)
                                .textInputAutocapitalization(.words)
                        }
                    }
                    Section(NSLocalizedString("Work", comment: "Section header")) {
                        HStack {
                            Text(NSLocalizedString("Duration", comment: "Label"))
                            Spacer()
                            WorkoutWheelPicker("", selection: $draft.workDuration, range: 1...600)
                                .frame(width: 120, height: 100)
                            Text(NSLocalizedString("s", comment: "Seconds abbreviation")).foregroundStyle(.secondary)
                        }
                    }
                    Section(footer: isLastPhase ? Text(NSLocalizedString("Pause is used for pauses between rounds.", comment: "Section footer")) : nil) {
                        HStack {
                            Text(NSLocalizedString("Rest", comment: "Label"))
                            Spacer()
                            WorkoutWheelPicker("", selection: $draft.restDuration, range: 0...600)
                                .frame(width: 120, height: 100)
                            Text(NSLocalizedString("s", comment: "Seconds abbreviation")).foregroundStyle(.secondary)
                        }
                    }
                    Section {
                        HStack {
                            Text(NSLocalizedString("Total Duration", comment: "Label"))
                            Spacer()
                            Text(totalString).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                    if !isNew, let onDelete {
                        Section {
                            Button(role: .destructive) {
                                onDelete()
                                dismiss()
                            } label: { Text(NSLocalizedString("Delete", comment: "Button")) }
                        }
                    }
                }
                .navigationTitle(isNew ? NSLocalizedString("New Exercise", comment: "Navigation title") : NSLocalizedString("Edit Exercise", comment: "Navigation title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(NSLocalizedString("Cancel", comment: "Button")) { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(NSLocalizedString("Save", comment: "Button")) {
                            // Use custom exercise name if selected
                            if useCustomExercise {
                                draft.name = customExerciseName
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
        Text("Workout programs are only available on iOS.")
    }
}
#endif
