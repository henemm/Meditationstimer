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

/// Audio-Session-Anmeldung und Abspielen laufen auf `audioQueue` (AC-16): Im Simulator blockierte
/// `setActive` den Hauptablauf ~22 s. `activePlayers` wird nur auf der Warteschlange angefasst.
fileprivate final class SoundPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate, @unchecked Sendable {
    private let audioQueue = DispatchQueue(label: "workout.soundplayer.audio")
    private var urls: [Cue: URL] = [:]  // Cache URLs, not players
    private var activePlayers: [AVAudioPlayer] = []  // Currently playing sounds
    private var prepared = false
    private let speech = AVSpeechSynthesizer()

    /// Aktiviert die Audio-Session vor jeder Wiedergabe (EXAKT wie GongPlayer!).
    /// Nur auf `audioQueue` aufrufen.
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
        audioQueue.async { [self] in activateSession() }
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
        guard let url = urls[cue] else {
            print("[Sound] cannot play \(cue.rawValue): URL not found")
            return
        }
        audioQueue.async { [self] in
            activateSession()  // Reaktiviere Audio-Session vor jeder Wiedergabe
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
    }

    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        audioQueue.async { [self] in
            if let idx = activePlayers.firstIndex(where: { $0 === player }) {
                activePlayers.remove(at: idx)
                print("[Sound] removed finished player (remaining: \(activePlayers.count))")
            }
        }
    }

    func play(_ cue: Cue, after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.play(cue)
        }
    }

    func speak(_ text: String) {
        prepare()
        audioQueue.async { [self] in activateSession() }  // Reaktiviere Audio-Session
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
        audioQueue.async { [self] in
            for p in activePlayers { p.stop() }
            activePlayers.removeAll()
        }
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
    var claude: ClaudeOrigin?        // #51: origin if delivered by Claude
    var modifiedAt: Date?            // #51: last change by the user

    init(id: UUID = UUID(), name: String, emoji: String, phases: [WorkoutPhase], repetitions: Int, description: String? = nil,
         claude: ClaudeOrigin? = nil, modifiedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.phases = phases
        self.repetitions = repetitions
        self.description = description
        self.claude = claude
        self.modifiedAt = modifiedAt
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
    var exerciseId: String?     // #48: catalog id (builtin.*, own.*, claude.*); optional in stored JSON
    var hint: String?           // #48: optional one-line hint; optional in stored JSON

    init(id: UUID = UUID(), name: String, workDuration: Int, restDuration: Int,
         exerciseId: String? = nil, hint: String? = nil) {
        self.id = id
        self.name = name
        self.workDuration = workDuration
        self.restDuration = restDuration
        self.exerciseId = exerciseId
        self.hint = hint
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, workDuration, restDuration, exerciseId, hint
    }

    /// #48 A2b-0: missing/null/blank exerciseId is derived from the name; hint is normalized.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        workDuration = try c.decode(Int.self, forKey: .workDuration)
        restDuration = try c.decode(Int.self, forKey: .restDuration)
        let stored = try c.decodeIfPresent(String.self, forKey: .exerciseId)
        if let stored, !stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            exerciseId = stored
        } else {
            exerciseId = ExerciseDatabase.exerciseId(forName: name)
        }
        hint = Self.normalizedHint(try c.decodeIfPresent(String.self, forKey: .hint))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(workDuration, forKey: .workDuration)
        try c.encode(restDuration, forKey: .restDuration)
        try c.encodeIfPresent(exerciseId, forKey: .exerciseId)
        try c.encodeIfPresent(hint, forKey: .hint)
    }
}

// MARK: - #48 API scaffold (bodies follow in A2b-0 / A2b, not used by the app yet)

extension WorkoutPhase {
    private static func isHintControl(_ v: Unicode.Scalar) -> Bool {
        switch v.value {
        case 0x00...0x1F, 0x7F...0x9F, 0xA0, 0x2028, 0x2029, 0x061C, 0x200E, 0x200F,
             0x202A...0x202E, 0x2066...0x2069: return true
        default: return false
        }
    }

    /// One-line hint: control/format characters become spaces, runs collapse, trimmed, max 80 UTF-16 units.
    static func normalizedHint(_ raw: String?) -> String? {
        guard let raw else { return nil }
        var text = ""
        text.unicodeScalars.append(contentsOf: raw.unicodeScalars.map { isHintControl($0) ? " " : $0 })
        let words = text.split(separator: " ", omittingEmptySubsequences: true)
        let joined = words.joined(separator: " ")
        var result = ""
        var units = 0
        for ch in joined {
            units += ch.utf16.count
            if units > 80 { break }
            result.append(ch)
        }
        result = result.trimmingCharacters(in: .whitespaces)
        return result.isEmpty ? nil : result
    }

    /// #48 A2b: catalog choice sets id + German catalog name; own exercise sets own.<slug> + name verbatim.
    mutating func apply(_ selection: ExerciseSelection) {
        switch selection {
        case .catalog(let id):
            exerciseId = id
            name = ExerciseDatabase.info(forId: id)?.name ?? name
        case .own(let ownName):
            exerciseId = ExerciseDatabase.ownExerciseId(forName: ownName)
            name = ownName
        }
    }

    /// #51 2b-2: Schritt mit `claude.*`-Kennung behaelt sie, solange der Name unveraendert ist; sonst wie `apply(.own)`.
    mutating func applyKeepingClaudeId(ownName: String) {
        if exerciseId?.hasPrefix("claude.") == true, ownName == name { return }
        apply(.own(name: ownName))
    }

    /// The 67 catalog exercises with localized names, alphabetical by localized name.
    static func pickerCatalog(bundle: Bundle = .main) -> [(id: String, name: String)] {
        ExerciseDatabase.catalog
            .map { (id: $0.id, name: ExerciseDatabase.displayName(exerciseId: $0.id, storedName: $0.name, bundle: bundle)) }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    /// New step: alphabetically first catalog exercise.
    static func newDefault(bundle: Bundle = .main) -> WorkoutPhase {
        var phase = WorkoutPhase(name: "", workDuration: 30, restDuration: 15)
        if let first = pickerCatalog(bundle: bundle).first { phase.apply(.catalog(id: first.id)) }
        return phase
    }

    /// Hint field input: normalized value to store plus the text to show (keeps one typed trailing space).
    static func hintInput(_ raw: String) -> (hint: String?, shown: String) {
        let hint = normalizedHint(raw)
        guard let hint else { return (nil, "") }
        let keepsSpace = raw.last?.isWhitespace == true && hint.utf16.count < 80
        return (hint, keepsSpace ? hint + " " : hint)
    }
}

extension WorkoutSet {
    static let backupKeyPrefix = "workoutProgramSetsBackup."
    static func loadStored(from defaults: UserDefaults, key: String = "workoutProgramSets",
                           now: Date = Date()) -> [WorkoutSet]? {
        guard let data = defaults.data(forKey: key) else { return nil }
        if let decoded = try? JSONDecoder().decode([WorkoutSet].self, from: data) { return decoded }
        backUpUnreadable(data, prefix: backupKeyPrefix, in: defaults, now: now)
        return nil
    }

    /// Keeps unreadable raw data under a new backup key (never overwrites, no duplicate of identical bytes).
    static func backUpUnreadable(_ data: Data, prefix: String, in defaults: UserDefaults, now: Date) {
        let keys = defaults.dictionaryRepresentation().keys
        let existing = keys.filter { $0.hasPrefix(prefix) }
        if existing.contains(where: { defaults.data(forKey: $0) == data }) { return }
        let base = prefix + String(Int(now.timeIntervalSince1970))
        var candidate = base
        var n = 2
        while keys.contains(candidate) { candidate = "\(base)-\(n)"; n += 1 }
        defaults.set(data, forKey: candidate)
    }

    /// Pure preset migration (A2c-1): appends missing presets (by name, preset order) and
    /// back-fills a missing description of same-named programs. Nothing else is touched.
    static func migratingPresets(_ stored: [WorkoutSet], presets: [WorkoutSet]) -> [WorkoutSet] {
        var result = stored
        for preset in presets where !result.contains(where: { $0.name == preset.name || $0.id == preset.id }) {
            result.append(preset)
        }
        for i in result.indices where result[i].description == nil {
            if let preset = presets.first(where: { $0.name == result[i].name }), preset.description != nil {
                result[i].description = preset.description
            }
        }
        return result
    }
}

enum ExerciseSelection { case catalog(id: String), own(name: String) }

enum WorkoutAnnouncementForm: Equatable {
    case exercise(number: Int, total: Int), lastExercise, round(number: Int, total: Int), lastRound
}

enum WorkoutAnnouncement {
    static func spokenText(_ form: WorkoutAnnouncementForm, phase: WorkoutPhase, bundle: Bundle = .main) -> String {
        let name = ExerciseDatabase.displayName(exerciseId: phase.exerciseId, storedName: phase.name, bundle: bundle)
        func text(_ key: String) -> String { bundle.localizedString(forKey: key, value: key, table: nil) }
        let sentence: String
        switch form {
        case .exercise(let number, let total):
            sentence = String(format: text("Exercise %d of %d: %@"), number, total, name)
        case .lastExercise:
            sentence = String(format: text("Last exercise: %@"), name)
        case .round(let number, let total):
            sentence = String(format: text("Round %d of %d: %@"), number, total, name)
        case .lastRound:
            sentence = String(format: text("Last round: %@"), name)
        }
        guard let hint = phase.hint else { return sentence }
        return sentence + ". " + hint
    }
    static func textToSpeak(_ form: WorkoutAnnouncementForm, phase: WorkoutPhase, speakExerciseNames: Bool,
                            bundle: Bundle = .main) -> String? {
        speakExerciseNames ? spokenText(form, phase: phase, bundle: bundle) : nil
    }
}

// MARK: - Namespace

enum WorkoutProgramsView {
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
        var logger: any WorkoutLogging = HealthKitManager.shared

        @Environment(\.scenePhase) private var scenePhase
        @State private var isInBackground = false

        @EnvironmentObject private var liveActivity: LiveActivityController
        @EnvironmentObject private var streakManager: StreakManager

        @AppStorage("speakExerciseNames") private var speakExerciseNames: Bool = false

        @StateObject private var sounds = SoundPlayer()

        /// `nil` bis zum Ende des Countdowns (#35 S2: Countdown zaehlt nicht zum Training).
        @State private var clock: WorkoutSessionClock?
        private var sessionStart: Date { clock?.start ?? phaseStart }
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

        // Effort Score (iOS 18+)
        @State private var showEffortSheet = false
        @State private var effortScore: Double = 7
        @State private var lastWorkout: HKWorkout?

        var body: some View {
            ZStack {
                Color(.systemGray6).ignoresSafeArea()
                VStack(spacing: 12) {
                    if !finished, let clock {
                        Text(LocalizedStringKey(set.name)).font(.headline)

                        // Dual Ring Progress + Timer
                        ProgressRingsView(
                            set: set,
                            currentPhase: $currentPhase,
                            currentRound: $currentRound,
                            phaseStart: $phaseStart,
                            finished: $finished,
                            sessionStart: clock.start,
                            sounds: sounds,
                            speakExerciseNames: speakExerciseNames,
                            isPaused: $isPaused,
                            pausedPhaseAccum: $pausedPhaseAccum,
                            pausedSessionAccum: $pausedSessionAccum,
                            onSessionEnd: { await endSession(manual: false) }
                        )

                        Button(isPaused ? NSLocalizedString("Continue", comment: "Button") : NSLocalizedString("Pause", comment: "Button")) {
                            togglePause()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                    } else if finished {
                        VStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.workoutViolet)
                            Text(NSLocalizedString("Done", comment: "Session completed")).font(.subheadline.weight(.semibold))
                        }
                    }
                }
                .onChange(of: currentPhase) { _, newPhase in
                    guard !finished, !isPaused else { return }
                    let now = Date()
                    let elapsedSession = max(0, now.timeIntervalSince(sessionStart) - pausedSessionAccum)
                    let remaining = max(0, TimeInterval(set.totalSeconds) - elapsedSession)
                    let updatedEndDate = now.addingTimeInterval(remaining)
                    let phaseDur: Double = {
                        let idx = newPhase.phaseIndex
                        return Double(newPhase.isWork ? set.phases[idx].workDuration : set.phases[idx].restDuration)
                    }()
                    let phaseEnd = now.addingTimeInterval(phaseDur)
                    Task { await liveActivity.update(phase: newPhase.isWork ? 1 : 2, endDate: updatedEndDate, phaseEndDate: phaseEnd, isPaused: false) }
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
            .onChange(of: scenePhase) { _, newPhase in
                isInBackground = (newPhase == .background)
            }
            .onDisappear {
                // Gemessener Stand unter iOS 26.5 (Belege in
                // DOCS/artifacts/bug-25d-hintergrund-meditation/):
                // - Beim reinen Hintergrund-Wechsel feuert onDisappear gar nicht
                //   (diagnose-endSession-aufrufe.txt). Der Guard ist dort wirkungslos,
                //   aber unschaedlich. Eine Reihenfolge onChange-vor-onDisappear sichert
                //   Apple nirgends zu — darauf verlaesst sich dieser Code nicht.
                // - Der Pfad ist trotzdem noetig: Er ist die einzige Aufraeumstelle fuer
                //   zwei Vordergrund-Faelle — programmatischer Reiterwechsel per
                //   Deep-Link/Kurzbefehl und abgebrochener Startvorlauf. Ohne ihn bleiben
                //   Leerlaufsperre aktiv und Live Activity offen, und es wird kein
                //   HealthKit-Eintrag geschrieben (regressionspruefung-reiterwechsel.txt).
                // Siehe DOCS/specs/bugfix/BUG-25d-hintergrund-workout.md und Issue #36
                // (Aufraeumpfad bei Reiterwechsel/abgebrochenem Startvorlauf).
                guard !isInBackground else { return }
                Task {
                    await endSession(manual: true)
                }
            }
            .sheet(isPresented: $showEffortSheet) {
                effortScoreSheet
            }
        }

        // MARK: - Effort Score Sheet (iOS 18+)
        @available(iOS 18.0, *)
        private var effortScoreSheet: some View {
            VStack(spacing: 20) {
                Text(NSLocalizedString("How hard was that?", comment: "Effort score prompt"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)

                Text("\(Int(effortScore))")
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .foregroundStyle(effortColor)

                Text(effortLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(effortColor)

                Slider(value: $effortScore, in: 1...10, step: 1)
                    .tint(effortColor)
                    .padding(.horizontal, 32)

                HStack {
                    Text(NSLocalizedString("Light", comment: "Effort light")).font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text(NSLocalizedString("Very Hard", comment: "Effort very hard")).font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 36)

                Button(action: saveEffortScore) {
                    Text(NSLocalizedString("Save", comment: "Save button"))
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(effortColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 32)

                Button(NSLocalizedString("Skip", comment: "Skip button")) {
                    showEffortSheet = false
                    close()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }

        private var effortLabel: String {
            let score = Int(effortScore)
            switch score {
            case 1...3: return NSLocalizedString("Light", comment: "Effort light")
            case 4...6: return NSLocalizedString("Moderate", comment: "Effort moderate")
            case 7...8: return NSLocalizedString("Hard", comment: "Effort hard")
            case 9...10: return NSLocalizedString("Very Hard", comment: "Effort very hard")
            default: return NSLocalizedString("Hard", comment: "Effort hard")
            }
        }

        private var effortColor: Color {
            let score = Int(effortScore)
            switch score {
            case 1...3: return .green
            case 4...6: return .yellow
            case 7...8: return .orange
            case 9...10: return .red
            default: return .orange
            }
        }

        private func saveEffortScore() {
            showEffortSheet = false
            if #available(iOS 18.0, *), let workout = lastWorkout {
                Task {
                    do {
                        try await HealthKitManager.shared.relateEffortScore(Int(effortScore), to: workout)
                    } catch {
                        print("[EffortScore] Fehler: \(error)")
                    }
                }
            }
            close()
        }

        private func setIdleTimer(_ disabled: Bool) {
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = disabled
            #endif
        }

        /// Starts the actual workout session (called after optional countdown)
        private func beginSessionAfterCountdown() {
            guard clock == nil else { return }
            let startedAt = Date()
            clock = WorkoutSessionClock(start: startedAt)
            phaseStart = startedAt
            // 1. Announce first exercise (if TTS enabled)
            if let text = WorkoutAnnouncement.textToSpeak(.exercise(number: 1, total: set.phases.count), phase: set.phases[0],
                                                          speakExerciseNames: speakExerciseNames) {
                sounds.speak(text)
            }

            // 2. Play start sound (Auftakt)
            sounds.play(.auftakt)

            // 3. Start Live Activity
            let endDate = sessionStart.addingTimeInterval(TimeInterval(set.totalSeconds))
            let firstPhaseDuration = TimeInterval(set.phases.first?.workDuration ?? 30)
            let firstPhaseEnd = sessionStart.addingTimeInterval(firstPhaseDuration)
            liveActivity.start(
                title: set.name,
                phase: 1,
                endDate: endDate,
                phaseEndDate: firstPhaseEnd,
                ownerId: "WorkoutsTab"
            )
        }

        func endSession(manual: Bool) async {
            print("[WorkoutPrograms] endSession(manual: \(manual)) called")

            // Guard: Prevent double execution (callback + onDisappear); Flag vor jedem await
            if sessionEnded {
                print("[WorkoutPrograms] endSession already executed, skipping duplicate call")
                return
            }
            sessionEnded = true

            setIdleTimer(false)

            // Ende der Uhr VOR Live-Activity-Ende und Schlussgong (#35 S2)
            clock?.end(at: Date(), reason: manual ? .manual : .natural)

            await liveActivity.end(immediate: true)
            await playClosingSound(manual: manual)

            if await logSession() { return }  // Effort-Sheet ruft close()

            print("[WorkoutPrograms] close() called")
            close()
        }

        private func playClosingSound(manual: Bool) async {
            if !manual {
                let soundDuration = sounds.duration(of: .ausklang)
                sounds.play(.ausklang)
                try? await Task.sleep(nanoseconds: UInt64((soundDuration + 0.3) * 1_000_000_000))
            } else {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            }
        }

        /// Schreibt die Sitzung nach HealthKit. Liefert `true`, wenn das Effort-Sheet erscheint.
        private func logSession() async -> Bool {
            guard let clock, clock.meetsMinimum else { return false }
            do {
                let result = try await WorkoutSessionLog.write(
                    clock: clock,
                    activity: .highIntensityIntervalTraining,
                    logger: logger
                )
                var workout: HKWorkout?
                if case .written(let written) = result { workout = written }
                print("[WorkoutPrograms] HealthKit workout logged")

                await streakManager.updateStreaks()

                if #available(iOS 18.0, *), let workout = workout {
                    lastWorkout = workout
                    showEffortSheet = true
                    return true
                }
            } catch {
                print("[WorkoutPrograms] HealthKit logging failed: \(error)")
            }
            return false
        }

        private func togglePause() {
            if !isPaused {
                // PAUSE
                isPaused = true
                let pauseStart = Date()
                pausedAt = pauseStart
                clock?.pause(at: pauseStart)
                sounds.stopAll()
                // Scheduled sounds cancelled by ProgressRingsView's checkProgress guard
                print("[WorkoutPrograms] Session PAUSED")
                // LiveActivity: Pause-Status setzen
                let now = Date()
                let elapsedSession = max(0, now.timeIntervalSince(sessionStart) - pausedSessionAccum)
                let remaining = max(0, TimeInterval(set.totalSeconds) - elapsedSession)
                let pausedEndDate = now.addingTimeInterval(remaining)
                let elapsedPhase = max(0, now.timeIntervalSince(phaseStart) - pausedPhaseAccum)
                let phaseDur: Double = {
                    let idx = currentPhase.phaseIndex
                    return Double(currentPhase.isWork ? set.phases[idx].workDuration : set.phases[idx].restDuration)
                }()
                let remainingPhase = max(0, phaseDur - elapsedPhase)
                let pausedPhaseEnd = now.addingTimeInterval(remainingPhase)
                Task { await liveActivity.update(phase: currentPhase.isWork ? 1 : 2, endDate: pausedEndDate, phaseEndDate: pausedPhaseEnd, isPaused: true) }
            } else {
                // RESUME
                if let p = pausedAt {
                    let resumedAt = Date()
                    let delta = resumedAt.timeIntervalSince(p)
                    pausedSessionAccum += delta
                    pausedPhaseAccum += delta
                    clock?.resume(at: resumedAt)
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
                let elapsedPhaseR = max(0, now.timeIntervalSince(phaseStart) - pausedPhaseAccum)
                let phaseDurR: Double = {
                    let idx = currentPhase.phaseIndex
                    return Double(currentPhase.isWork ? set.phases[idx].workDuration : set.phases[idx].restDuration)
                }()
                let remainingPhaseR = max(0, phaseDurR - elapsedPhaseR)
                let resumedPhaseEnd = now.addingTimeInterval(remainingPhaseR)
                Task { await liveActivity.update(phase: currentPhase.isWork ? 1 : 2, endDate: resumedEndDate, phaseEndDate: resumedPhaseEnd, isPaused: false) }
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
        @State private var selectedExerciseId: String? = nil  // Exercise id for sheet (nil: derived from name)
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
                                exerciseNameWithInfoButton(phase)

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

                                exerciseNameWithInfoButton(phase)

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

                // #48: hint line under the ring, only in the work phase
                if currentPhase.isWork, let hint = phase.hint {
                    Text(hint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 24)
                        .accessibilityIdentifier("workout.training.hint")
                }

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
                ExerciseDetailSheet(exerciseName: selectedExerciseName, exerciseId: selectedExerciseId)
            }
        }

        @ViewBuilder
        private func exerciseNameWithInfoButton(_ phase: WorkoutPhase) -> some View {
            let shownName = ExerciseDatabase.displayName(exerciseId: phase.exerciseId, storedName: phase.name)
            HStack(spacing: 6) {
                Text(shownName)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Button {
                    selectedExerciseName = phase.name
                    selectedExerciseId = phase.exerciseId
                    showExerciseSheet = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(Color.workoutViolet)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("workout.training.infoButton")
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
                        selectedExerciseId = nil
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

        /// Announcement form and phase of what comes next (nil if nothing follows).
        private func nextAnnouncement(afterIndex index: Int) -> (form: WorkoutAnnouncementForm, phase: WorkoutPhase)? {
            let nextIndex = index + 1
            if nextIndex < set.phases.count {
                let isLast = nextIndex == set.phases.count - 1 && currentRound == set.repetitions
                return (isLast ? .lastExercise : .exercise(number: nextIndex + 1, total: set.phases.count), set.phases[nextIndex])
            } else if currentRound < set.repetitions {
                let nextRound = currentRound + 1
                let form: WorkoutAnnouncementForm = nextRound == set.repetitions
                    ? .lastRound : .round(number: nextRound, total: set.repetitions)
                return (form, set.phases[0])
            }
            return nil
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
                    if let next = nextAnnouncement(afterIndex: index),
                       let ttsText = WorkoutAnnouncement.textToSpeak(next.form, phase: next.phase, speakExerciseNames: speakExerciseNames) {
                        sounds.speak(ttsText)
                        print("[WorkoutPrograms] TTS: \(ttsText)")
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
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey(set.name))
                                .font(.system(size: 22, weight: .bold))
                            if set.claude != nil {
                                ClaudeOriginBadge(modifiedAt: set.modifiedAt,
                                                  identifier: "workout.programRow.\(set.name).claudeBadge")
                            }
                        }
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
                        .accessibilityIdentifier("workout.programRow.\(set.name).start")
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
                        if set.description != nil || set.claude != nil, let showInfo = showInfo {
                            Button(action: showInfo) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 18, weight: .regular))
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Info")
                            .accessibilityIdentifier("workout.programRow.\(set.name).info")
                        }

                        Button(action: edit) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 24, weight: .regular))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Bearbeiten")
                        .accessibilityIdentifier("workout.programRow.\(set.name).edit")
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
        @State private var exerciseSheet: ExerciseSheetWrapper?  // #90: item-based, first tap works

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

                        // Recommended Usage Section (not for Claude items)
                        if let origin = set.claude {
                            ClaudeOriginSection(origin: origin)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(NSLocalizedString("Recommended Application", comment: ""))
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text(recommendedUsage)
                                    .font(.body)
                            }
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
                .sheet(item: $exerciseSheet) { item in
                    ExerciseDetailSheet(exerciseName: item.name, exerciseId: item.exerciseId)
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
                    exerciseSheet = ExerciseSheetWrapper(name: phase.name, exerciseId: phase.exerciseId)
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
            .onTapGesture { exerciseSheet = ExerciseSheetWrapper(name: phase.name, exerciseId: phase.exerciseId) }
        }
    }

    // Helper struct to make String identifiable for .sheet(item:)
    struct ExerciseSheetWrapper: Identifiable {
        let id = UUID()
        let name: String
        var exerciseId: String? = nil
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
                                .accessibilityIdentifier("workout.setEditor.phaseRow.\(index)")
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
                            editingPhase = WorkoutPhase.newDefault()
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
                        .accessibilityIdentifier("workout.setEditor.save")
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
        @State private var hintText: String
        private let catalogOptions = WorkoutPhase.pickerCatalog()
        private static let ownTag = "own"
        let isNew: Bool
        let isLastPhase: Bool
        let onSave: (WorkoutPhase) -> Void
        let onDelete: (() -> Void)?

        init(phase: WorkoutPhase, isNew: Bool, isLastPhase: Bool, onSave: @escaping (WorkoutPhase) -> Void, onDelete: (() -> Void)? = nil) {
            var phase = phase
            let id = phase.exerciseId ?? ExerciseDatabase.exerciseId(forName: phase.name)
            phase.exerciseId = id
            self._draft = State(initialValue: phase)
            self.isNew = isNew
            self.isLastPhase = isLastPhase
            self.onSave = onSave
            self.onDelete = onDelete
            self._hintText = State(initialValue: phase.hint ?? "")

            // Custom exercise = not a catalog exercise (decided by id, not by name)
            let isCustom = !(id.hasPrefix("builtin.") && ExerciseDatabase.info(forId: id) != nil)
            self._useCustomExercise = State(initialValue: isCustom)
            self._customExerciseName = State(initialValue: isCustom ? phase.name : "")
        }

        private var totalString: String {
            let total = draft.workDuration + draft.restDuration
            return "\(total)s"
        }

        /// Selection value: catalog id, or `ownTag` for a free-text exercise.
        private var exercisePicker: some View {
            Picker(NSLocalizedString("Name", comment: "Picker label"), selection: Binding(
                get: { useCustomExercise ? Self.ownTag : (draft.exerciseId ?? "") },
                set: { newValue in
                    if newValue == Self.ownTag {
                        useCustomExercise = true
                    } else {
                        useCustomExercise = false
                        draft.apply(.catalog(id: newValue))
                    }
                }
            )) {
                ForEach(catalogOptions, id: \.id) { option in
                    Text(option.name).tag(option.id)
                        .accessibilityIdentifier("workout.exercisePicker.option.\(option.id)")
                }
                ForEach([Self.ownTag], id: \.self) { tag in
                    Text(NSLocalizedString("Custom Exercise...", comment: "Picker option")).tag(tag)
                        .accessibilityIdentifier("workout.exercisePicker.own")
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("workout.phaseEditor.exercisePicker")
        }

        /// One line, max 80 UTF-16 units (Spec #48, Entscheidung 9): capped in the setter, re-applied async so the field follows
        private var hintBinding: Binding<String> {
            Binding(get: { hintText }, set: { raw in
                let input = WorkoutPhase.hintInput(raw)
                draft.hint = input.hint
                hintText = raw
                if input.shown != raw { DispatchQueue.main.async { hintText = input.shown } }
            })
        }

        var body: some View {
            NavigationView {
                Form {
                    Section(NSLocalizedString("Exercise", comment: "Section header")) {
                        exercisePicker
                        if useCustomExercise {
                            TextField(NSLocalizedString("Exercise Name", comment: "TextField placeholder"), text: $customExerciseName)
                                .textInputAutocapitalization(.words)
                                .accessibilityIdentifier("workout.phaseEditor.ownNameField")
                        }
                        TextField(NSLocalizedString("Hinweis (optional)", comment: "Hint field label"), text: hintBinding,
                                  prompt: Text(NSLocalizedString("z. B. 12 Wiederholungen, langsam", comment: "Hint field placeholder")))
                            .accessibilityLabel(NSLocalizedString("Hinweis (optional)", comment: "Hint field label"))
                            .accessibilityIdentifier("workout.phaseEditor.hintField")
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
                            if useCustomExercise {
                                draft.applyKeepingClaudeId(ownName: customExerciseName)
                            }

                            onSave(draft)
                            dismiss()
                        }
                        .accessibilityIdentifier("workout.phaseEditor.save")
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

#endif
