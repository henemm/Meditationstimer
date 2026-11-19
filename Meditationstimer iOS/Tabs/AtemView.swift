//
//  AtemView.swift
//  Meditationstimer
//
//  Restored Atem tab with presets list, Play/Edit actions and centered run overlay.
//  Includes a reusable SettingsSheet (temporarily kept in this file).
//
// MARK: - AI ORIENTATION (Read me first)
// Purpose:
//   AtemView manages the "Atem" tab. It displays a list of breathing presets, lets users create,
//   edit, delete presets, and run a breathing session with gong cues.
//
// Files & Responsibilities (where to look next):
//   • AtemView.swift        – This file: list, editor, run card, local gong logic.
//   • ContentView.swift     – Tab container, cross-cutting session handling (Offen tab logic).
//   • SettingsSheet.swift   – Shared settings (sound/haptics toggles).
//   • GongPlayer (local)    – Defined here, separate from OffenView GongPlayer.
//
// Control Flow (high level):
//   • User taps Play on a preset → runningPreset is set → SessionCard appears.
//   • SessionCard uses SessionEngine → advances through phases with Timer + gong sounds.
//   • User taps Beenden or session ends → SessionEngine resets → overlay closes.
//
// AI Editing Guidelines:
//   • Keep AtemView focused: preset model, list, editor, session card.
//   • Do not mix cross-tab logic here (belongs in ContentView).
//   • Keep GongPlayer nested here to avoid conflicts with Offen tab GongPlayer.
//   • Maintain clear MARKs for sections: Model, Engine, Gong, State, Views.

import SwiftUI
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif
// Dynamic Island / Live Activity removed

#if os(iOS)

// MARK: - Atem Tab

enum AtemView {
    // MARK: - Preset Model
    struct Preset: Identifiable, Hashable, Codable {
        var id: UUID
        var name: String
        var emoji: String
        var inhale: Int
        var holdIn: Int
        var exhale: Int
        var holdOut: Int
        var repetitions: Int
        var description: String?

        init(id: UUID = UUID(), name: String, emoji: String, inhale: Int, holdIn: Int, exhale: Int, holdOut: Int, repetitions: Int, description: String? = nil) {
            self.id = id
            self.name = name
            self.emoji = emoji
            self.inhale = inhale
            self.holdIn = holdIn
            self.exhale = exhale
            self.holdOut = holdOut
            self.repetitions = repetitions
            self.description = description
        }

        var rhythmString: String { "\(inhale)-\(holdIn)-\(exhale)-\(holdOut)" }
        var cycleSeconds: Int { inhale + holdIn + exhale + holdOut }
        var totalSeconds: Int { cycleSeconds * max(1, repetitions) }

        var totalDurationString: String {
            let s = totalSeconds
            let m = s / 60, r = s % 60
            return m > 0 ? String(format: "%d:%02d min", m, r) : "\(s) sec"
        }
    }

    // MARK: - Session Phase
    enum Phase: String { case inhale = "Inhale", holdIn = "Hold (in)", exhale = "Exhale", holdOut = "Hold (out)" }

    // MARK: - Sound Theme
    enum AtemSoundTheme: String, Codable, CaseIterable {
        case distinctive = "distinctive"
        case marimba = "marimba"
        case harp = "harp"
        case guitar = "guitar"
        case epiano = "epiano"

        var displayName: String {
            switch self {
            case .distinctive: return NSLocalizedString("Distinctive", comment: "Atem sound theme: clear, distinctive signals")
            case .marimba: return NSLocalizedString("Marimba", comment: "Atem sound theme: warm, wooden sounds")
            case .harp: return NSLocalizedString("Harp", comment: "Atem sound theme: gentle, flowing tones")
            case .guitar: return NSLocalizedString("Guitar", comment: "Atem sound theme: acoustic plucked tones")
            case .epiano: return NSLocalizedString("E-Piano", comment: "Atem sound theme: soft piano tones")
            }
        }

        var emoji: String {
            switch self {
            case .distinctive: return "🔔"
            case .marimba: return "🎵"
            case .harp: return "🪕"
            case .guitar: return "🎸"
            case .epiano: return "🎹"
            }
        }

        var description: String {
            switch self {
            case .distinctive: return NSLocalizedString("Clear, distinctive signals", comment: "Atem sound theme description: distinctive")
            case .marimba: return NSLocalizedString("Warm, wooden sounds", comment: "Atem sound theme description: marimba")
            case .harp: return NSLocalizedString("Gentle, flowing tones", comment: "Atem sound theme description: harp")
            case .guitar: return NSLocalizedString("Acoustic plucked tones", comment: "Atem sound theme description: guitar")
            case .epiano: return NSLocalizedString("Soft, electronic sounds", comment: "Atem sound theme description: e-piano")
            }
        }
    }

    // MARK: - Local GongPlayer (only for AtemView)
    final class GongPlayer: NSObject, AVAudioPlayerDelegate {
        func stopAll() {
            for p in active { p.stop() }
            active.removeAll()
            completions.removeAll()
        }
        private var active: [AVAudioPlayer] = []
        private var completions: [AVAudioPlayer: () -> Void] = [:]

        private func activateSession() {
            let s = AVAudioSession.sharedInstance()
            try? s.setCategory(.playback, options: [.mixWithOthers])
            try? s.setActive(true, options: [])
        }

        func play(named name: String, completion: (() -> Void)? = nil) {
            activateSession()
            // try bundled caf/wav/mp3
            for ext in ["caf","wav","mp3"] {
                if let url = Bundle.main.url(forResource: name, withExtension: ext),
                   let p = try? AVAudioPlayer(contentsOf: url) {
                    p.delegate = self
                    p.prepareToPlay()
                    p.play()
                    active.append(p)
                    if let completion = completion {
                        completions[p] = completion
                    }
                    return
                }
            }
            print("Audio file '\(name)' not found, no fallback sound played") // fallback
        }
        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            if let i = active.firstIndex(where: { $0 === player }) { active.remove(at: i) }
            if let completion = completions[player] {
                completions.removeValue(forKey: player)
                completion()
            }
        }
    }

// iOS-only code continues below; closing #endif is at the end of file

    // MARK: - Row View (list item)
    struct Row: View {
        let preset: Preset
        let play: () -> Void
        let edit: () -> Void
        let showInfo: (() -> Void)?

        var body: some View {
            AtemGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    // TOP ~2/3: Emoji, Title, Play
                    HStack(alignment: .center, spacing: 14) {
                        Text(preset.emoji)
                            .font(.system(size: 42))
                        Text(preset.name)
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
                        Text("\(preset.rhythmString) · \(preset.repetitions)x · ≈ \(preset.totalDurationString)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()

                        // Info button (only if description exists)
                        if preset.description != nil, let showInfo = showInfo {
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
                        .accessibilityLabel("Edit")
                    }
                }
                .frame(minHeight: 140)
            }
        }
    }

    // MARK: - Add Preset Card
    struct AddPresetCard: View {
        let action: () -> Void

        var body: some View {
            AtemGlassCard {
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
                    .accessibilityLabel("Add new preset")
                    Spacer()
                }
                .frame(minHeight: 70)
            }
        }
    }

    // MARK: - Preset Info Sheet
    struct PresetInfoSheet: View {
        let preset: Preset
        @Environment(\.dismiss) private var dismiss

        private var recommendedUsage: LocalizedStringKey {
            switch preset.name {
            case "Box Breathing":
                return "During acute stress, before important appointments or presentations. Ideal for quick calming in demanding situations."
            case "Calming Breath":
                return "In the evening for relaxation or before bedtime. Extended exhalation activates the body's rest mode."
            case "Coherent Breathing":
                return "Daily in the morning or midday for HRV optimization. Regular practice improves stress resilience long-term."
            case "Deep Calm":
                return "During inner restlessness or when mental clarity is needed. Promotes focus and deep relaxation."
            case "Relaxing Breath":
                return "In the evening directly before falling asleep or with sleep problems. Calming effect for stress and anxiety."
            case "Rhythmic Breath":
                return "Anytime as a daily routine. Balanced rhythm for balance in everyday life."
            default:
                return "Regular practice for best results."
            }
        }

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header: Emoji + Name
                        HStack(spacing: 16) {
                            Text(preset.emoji)
                                .font(.system(size: 60))
                            Text(preset.name)
                                .font(.system(size: 28, weight: .bold))
                            Spacer()
                        }
                        .padding(.top, 8)

                        // Rhythm Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("Rhythm", comment: "Section header in preset info"))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text(preset.rhythmString)
                                .font(.title3)
                            Text(String(format: NSLocalizedString("%lld Repetitions · ≈ %@", comment: "Repetitions count in preset info"), Int64(preset.repetitions), preset.totalDurationString))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        // Description Section
                        if let description = preset.description {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(NSLocalizedString("Effect", comment: "Section header in preset info"))
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text(description)
                                    .font(.body)
                            }
                        }

                        // Recommended Usage Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("Recommended Application", comment: "Section header in preset info"))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text(recommendedUsage)
                                .font(.body)
                        }
                    }
                    .padding()
                }
                .navigationTitle(NSLocalizedString("Preset Info", comment: "Navigation title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(NSLocalizedString("Done", comment: "Button")) {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

        // MARK: - SessionCard (overlay during run)
    struct SessionCard: View {
    // scenePhase-Automatik entfernt – führte zu unerwünschten Beendigungen beim App-Wechsel
        let preset: Preset
        var close: () -> Void
    // @StateObject private var engine = SessionEngine() entfernt
        @EnvironmentObject private var liveActivity: LiveActivityController
        @State private var showConflictAlert: Bool = false
        @State private var conflictOwnerId: String? = nil
        @State private var conflictTitle: String? = nil
        @State private var sessionStart: Date = .now
        @State private var sessionTotal: TimeInterval = 1
        @State private var phaseStart: Date? = nil
        @State private var phaseDuration: Double = 1
        @State private var lastPhase: Phase? = nil
        @AppStorage("logMeditationAsYogaWorkout") private var logMeditationAsYogaWorkout: Bool = false

        // Neue State Variablen wie in WorkoutsView
        @State private var phase: Phase = .inhale
        @State private var repIndex: Int = 1
        @State private var phaseEndFired = false
        @State private var finished = false
        @State private var started = false

        // GongPlayer instance
        @State private var gong = GongPlayer()
        @State private var ambientPlayer = AmbientSoundPlayer()
        @State private var pendingEndStop: DispatchWorkItem?  // For delayed audio cleanup after gong
        @AppStorage("ambientSound") private var ambientSoundRaw: String = AmbientSound.none.rawValue
        @AppStorage("ambientSoundAtemEnabled") private var ambientSoundAtemEnabled: Bool = false
        @AppStorage("ambientSoundVolume") private var ambientSoundVolume: Int = 45
        @AppStorage("atemSoundTheme") private var soundTheme: AtemSoundTheme = .distinctive
        @AppStorage("countdownBeforeStart") private var countdownBeforeStart: Int = 0
        @State private var showCountdown = false

        private var ambientSound: AmbientSound {
            AmbientSound(rawValue: ambientSoundRaw) ?? .none
        }

        // Helper properties for dual ring progress
        private var cycleSeconds: Int { preset.inhale + preset.holdIn + preset.exhale + preset.holdOut }
        private func duration(for phase: Phase) -> Int {
            switch phase {
            case .inhale: return preset.inhale
            case .holdIn: return preset.holdIn
            case .exhale: return preset.exhale
            case .holdOut: return preset.holdOut
            }
        }

        // Callback for phase changes to update Live Activity
        private func onPhaseChanged(to newPhase: Phase) {
            let phaseNumber: Int
            switch newPhase {
            case .inhale: phaseNumber = 1  // ↑
            case .holdIn: phaseNumber = 2  // →
            case .exhale: phaseNumber = 3  // ↓
            case .holdOut: phaseNumber = 4 // →
            }
            
            let timestamp = Date().timeIntervalSince1970
            print("🫁 [AtemView] PHASE CHANGED: \(newPhase.rawValue) → phaseNumber=\(phaseNumber), round=\(repIndex), timestamp=\(String(format: "%.3f", timestamp))")
            
            Task {
                let endDate = sessionStart.addingTimeInterval(TimeInterval(preset.totalSeconds))
                print("🫁 [AtemView] SENDING Live Activity update: phase=\(phaseNumber), round=\(repIndex)")
                await liveActivity.update(phase: phaseNumber, endDate: endDate, isPaused: false)
                print("🫁 [AtemView] Live Activity update COMPLETED for phase \(phaseNumber)")
            }
        }

        func soundName(for phase: Phase) -> String {
            let suffix: String
            switch phase {
            case .inhale: suffix = "in"
            case .holdIn: suffix = "inhold"
            case .exhale: suffix = "out"
            case .holdOut: suffix = "outhold"
            }
            return "\(soundTheme.rawValue)-\(suffix)"
        }

        func setPhase(_ p: Phase) {
            phase = p
            phaseStart = Date()
            phaseDuration = Double(duration(for: p))
            gong.play(named: soundName(for: p))
        }

        /// Starts the actual breathing session (called after optional countdown)
        func beginSessionAfterCountdown() {
            let start = Date()
            sessionStart = start
            sessionTotal = TimeInterval(preset.totalSeconds)
            started = true
            setPhase(.inhale)
            // Live Activity starten
            let endDate = start.addingTimeInterval(TimeInterval(preset.totalSeconds))
            let result = liveActivity.requestStart(title: preset.name, phase: 1, endDate: endDate, ownerId: "AtemTab")
            print("🫁 [AtemView] REQUESTING Live Activity start: title='\(preset.name)', ownerId='AtemTab'")
            if case .conflict(let existingOwner, let existingTitle) = result {
                print("🫁 [AtemView] Live Activity CONFLICT: existingOwner='\(existingOwner)', existingTitle='\(existingTitle)'")
                conflictOwnerId = existingOwner
                conflictTitle = existingTitle.isEmpty ? NSLocalizedString("Another Timer", comment: "Fallback title for unknown timer") : existingTitle
                showConflictAlert = true
            } else {
                print("🫁 [AtemView] Live Activity request submitted (no immediate conflict)")
            }
        }

        func advance() {
            switch phase {
            case .inhale:
                if preset.holdIn > 0 {
                    setPhase(.holdIn)
                } else {
                    setPhase(.exhale)
                }
            case .holdIn:
                setPhase(.exhale)
            case .exhale:
                if preset.holdOut > 0 {
                    setPhase(.holdOut)
                } else {
                    if repIndex >= preset.repetitions {
                        finished = true
                    } else {
                        repIndex += 1
                        setPhase(.inhale)
                    }
                }
            case .holdOut:
                if repIndex >= preset.repetitions {
                    finished = true
                } else {
                    repIndex += 1
                    setPhase(.inhale)
                }
            }
        }

        var body: some View {
            ZStack {
                Color(.systemGray6).ignoresSafeArea()
                VStack(spacing: 12) {
                    if !finished {
                        Text(preset.name).font(.headline)
                        PhaseProgressView(preset: preset, phase: $phase, repIndex: $repIndex, phaseEndFired: $phaseEndFired, finished: $finished, phaseStart: $phaseStart, phaseDuration: $phaseDuration, gong: gong, soundTheme: soundTheme, sessionStart: sessionStart, sessionTotal: sessionTotal, onPhaseChanged: onPhaseChanged)
                    } else {
                        VStack {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 40))
                            Text(NSLocalizedString("Done", comment: "Session completed")).font(.subheadline.weight(.semibold))
                        }
                        // Snap outer progress to full on finish
                        .onAppear {
                            sessionTotal = max(sessionTotal, Date().timeIntervalSince(sessionStart))
                            // Live Activity entfernt für Debugging
                            // Task {
                            //     await liveActivity.end()
                            //     await endSession(manual: false)
                            // }
                        }
                    }
                    Button(NSLocalizedString("End", comment: "Button to end session")) {
                        Task { await endSession(manual: true) }
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
                Button(action: { Task { await endSession(manual: true) } }) {
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
                // Disable idle timer to keep display on during session
                setIdleTimer(true)

                // Start ambient sound (starts during countdown if enabled)
                if ambientSoundAtemEnabled {
                    ambientPlayer.setVolume(percent: ambientSoundVolume)
                    ambientPlayer.start(sound: ambientSound)
                }

                // Countdown vor Start (wenn aktiviert)
                if countdownBeforeStart > 0 {
                    showCountdown = true
                } else {
                    beginSessionAfterCountdown()
                }
            }
            // Keine automatische Beendigung bei App-Wechsel
            .alert(isPresented: $showConflictAlert) {
                conflictAlert
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
                        ambientPlayer.stop()
                        close()
                    }
                )
            }
            .onChange(of: finished) { _, newValue in
                if newValue {
                    Task { await endSession(manual: false) }
                }
            }
        }

        // MARK: - PhaseProgressView (handles timeline and phase advancement)
        struct PhaseProgressView: View {
            let preset: Preset
            @Binding var phase: Phase
            @Binding var repIndex: Int
            @Binding var phaseEndFired: Bool
            @Binding var finished: Bool
            @Binding var phaseStart: Date?
            @Binding var phaseDuration: Double
            let gong: GongPlayer
            let soundTheme: AtemSoundTheme
            let sessionStart: Date
            let sessionTotal: TimeInterval
            let onPhaseChanged: (Phase) -> Void

            @State private var currentTime: Date = Date()
            @State private var timer: Timer?

            var body: some View {
                VStack(spacing: 8) {
                    let now = currentTime
                    
                    // ---- OUTER (session) PROGRESS: continuous 0→1 over the whole session ----
                    let totalDuration = max(0.001, sessionTotal)
                    let elapsedSession = now.timeIntervalSince(sessionStart)
                    let progressTotal = max(0.0, min(1.0, elapsedSession / totalDuration))

                    // ---- INNER (phase) PROGRESS: reset on phase change, linear 0→1 ----
                    let dur = max(0.001, phaseDuration)
                    let start = phaseStart ?? now
                    let elapsedInPhase = max(0, now.timeIntervalSince(start))
                    let fractionPhase = max(0.0, min(1.0, elapsedInPhase / dur))

                    ZStack {
                        // Outer ring: total session progress (continuous)
                        CircularRing(progress: progressTotal, lineWidth: 22)
                            .foregroundStyle(.tint)
                        // Inner ring: current phase progress (resets each phase)
                        CircularRing(progress: fractionPhase, lineWidth: 14)
                            .scaleEffect(0.72)
                            .foregroundStyle(.secondary)
                        // Center icon: phase direction
                        Image(systemName: SessionCard.iconName(for: phase))
                            .font(.system(size: 64, weight: .regular))
                            .foregroundStyle(.tint)
                    }
                    .frame(width: 320, height: 320)
                    .padding(.top, 6)
                    .contentShape(Rectangle())
                    Text(String(format: NSLocalizedString("Round %d / %d", comment: "Round counter"), repIndex, preset.repetitions))
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
                    checkPhaseProgress()
                }
            }

            private func stopTimer() {
                timer?.invalidate()
                timer = nil
            }

            private func checkPhaseProgress() {
                let now = currentTime
                let dur = max(0.001, phaseDuration)
                let start = phaseStart ?? now
                let elapsedInPhase = max(0, now.timeIntervalSince(start))
                let fractionPhase = max(0.0, min(1.0, elapsedInPhase / dur))
                
                if fractionPhase >= 1.0 && !phaseEndFired {
                    phaseEndFired = true
                    advance()
                } else if fractionPhase < 1.0 {
                    phaseEndFired = false
                }
            }

            func soundName(for phase: Phase) -> String {
                let suffix: String
                switch phase {
                case .inhale: suffix = "in"
                case .holdIn: suffix = "inhold"
                case .exhale: suffix = "out"
                case .holdOut: suffix = "outhold"
                }
                return "\(soundTheme.rawValue)-\(suffix)"
            }

            func setPhase(_ p: Phase) {
                phase = p
                phaseStart = Date()
                phaseDuration = Double(SessionCard(preset: preset, close: {}).duration(for: p))
                gong.play(named: soundName(for: p))
            }

            func advance() {
                let oldPhase = phase
                switch phase {
                case .inhale:
                    if preset.holdIn > 0 {
                        setPhase(.holdIn)
                    } else {
                        setPhase(.exhale)
                    }
                case .holdIn:
                    setPhase(.exhale)
                case .exhale:
                    if preset.holdOut > 0 {
                        setPhase(.holdOut)
                    } else {
                        if repIndex >= preset.repetitions {
                            finished = true
                        } else {
                            repIndex += 1
                            setPhase(.inhale)
                        }
                    }
                case .holdOut:
                    if repIndex >= preset.repetitions {
                        finished = true
                    } else {
                        repIndex += 1
                        setPhase(.inhale)
                    }
                }
                // Notify about phase change for Live Activity update
                if phase != oldPhase {
                    onPhaseChanged(phase)
                }
            }
        }

        private func setIdleTimer(_ disabled: Bool) {
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = disabled
            #endif
        }

        func endSession(manual: Bool) async {
            print("[AtemView] endSession(manual: \(manual)) called")

            // 1. Re-enable idle timer
            setIdleTimer(false)

            // 2. HealthKit Logging, wenn Session > 3s
            let endDate = Date()
            if sessionStart.distance(to: endDate) > 3 {
                do {
                    if logMeditationAsYogaWorkout {
                        try await HealthKitManager.shared.logWorkout(start: sessionStart, end: endDate, activity: .yoga)
                    } else {
                        try await HealthKitManager.shared.logMindfulness(start: sessionStart, end: endDate)
                    }
                } catch {
                    print("HealthKit logging failed: \(error)")
                }
            }

            // 3. End-Gong nur bei natürlichem Ende (nicht beim manuellen Abbrechen)
            // IMPORTANT: Use completion handler + delayed audio stop (exactly like OffenView)
            if !manual {
                gong.play(named: "gong-ende") {
                    // Completion handler: called after gong finishes playing
                    self.pendingEndStop?.cancel()
                    let work = DispatchWorkItem { [ambientPlayer = self.ambientPlayer] in
                        ambientPlayer.stop()  // Fade-out ambient sound
                    }
                    self.pendingEndStop = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work) // Extra delay for safety
                }
            } else {
                // Bei manuellem Abbruch: sofort stoppen ohne Gong
                gong.stopAll()
                ambientPlayer.stop()
            }

            // 4. Beende Live Activity garantiert
            await liveActivity.end(immediate: true)
            print("[AtemView] liveActivity.end(immediate: true) called")

            // 5. Schließe die View
            print("[AtemView] close() called")
            close()
        }

        static func iconName(for phase: Phase) -> String {
            switch phase {
            case .inhale: return "arrow.up"
            case .exhale: return "arrow.down"
            case .holdIn, .holdOut: return "arrow.right"
            }
        }

        // Alert for existing timer conflict
        private var conflictAlert: Alert {
            let timerName = conflictTitle ?? NSLocalizedString("Active Timer", comment: "Fallback for active timer name")
            let messageFormat = NSLocalizedString("The timer '%@' is already running. Should it be stopped and the new one started?", comment: "Alert message for timer conflict")
            let messageText = String(format: messageFormat, timerName)

            return Alert(
                title: Text(NSLocalizedString("Another Timer Running", comment: "Alert title")),
                message: Text(messageText),
                primaryButton: .destructive(Text(NSLocalizedString("Stop Timer and Start", comment: "Alert button")), action: {
                    // Force start now
                    let endDate = sessionStart.addingTimeInterval(TimeInterval(preset.totalSeconds))
                    liveActivity.forceStart(title: preset.name, phase: 1, endDate: endDate, ownerId: "AtemTab")
                }),
                secondaryButton: .cancel(Text(NSLocalizedString("Cancel", comment: "Alert button")))
            )
        }
    }

    // MARK: - EditorView (create/edit preset)
    struct EditorView: View {
        @Environment(\.dismiss) private var dismiss
        @State private var draft: Preset
        let isNew: Bool
        let onSave: (Preset) -> Void
        let onDelete: ((UUID) -> Void)?

        init(preset: Preset, isNew: Bool, onSave: @escaping (Preset) -> Void, onDelete: ((UUID) -> Void)? = nil) {
            self._draft = State(initialValue: preset)
            self.isNew = isNew
            self.onSave = onSave
            self.onDelete = onDelete
        }

        private var totalString: String {
            let total = (draft.inhale + draft.holdIn + draft.exhale + draft.holdOut) * max(1, draft.repetitions)
            if total >= 60 { return String(format: "≈ %d:%02d min", total/60, total%60) }
            return "≈ \(total) sec"
        }

        var body: some View {
            NavigationView {
                Form {
                    Section(NSLocalizedString("Icon", comment: "Section header")) {
                        let choices = ["🧘","🪷","🌬️","🫁","🌿","🌀","✨","🔷","🔶","💠"]
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
                    Section(NSLocalizedString("Rhythm (Seconds)", comment: "Section header")) {
                        pickerRow(title: "Inhale", value: $draft.inhale)
                        pickerRow(title: "Hold (in)", value: $draft.holdIn)
                        pickerRow(title: "Exhale", value: $draft.exhale)
                        pickerRow(title: "Hold (out)", value: $draft.holdOut)
                    }
                    Section(NSLocalizedString("Repetitions", comment: "Section header")) {
                        AtemWheelPicker(NSLocalizedString("Rounds", comment: "Picker label"), selection: $draft.repetitions, range: 1...99)
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
                .navigationTitle(isNew ? NSLocalizedString("New Breathe Preset", comment: "Navigation title") : NSLocalizedString("Breathe Preset", comment: "Navigation title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(NSLocalizedString("Cancel", comment: "Button")) { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(NSLocalizedString("Save", comment: "Button")) {
                            onSave(draft); dismiss()
                        }.disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }

        @ViewBuilder
        private func pickerRow(title: LocalizedStringKey, value: Binding<Int>) -> some View {
            HStack {
                Text(title)
                Spacer()
                AtemWheelPicker("", selection: value, range: 0...60)
                    .frame(width: 120, height: 100)
            }
        }
    }

    // MARK: - WheelPicker (number wheel)
    struct AtemWheelPicker: View {
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

    // MARK: - GlassCard (styling container)
    struct AtemGlassCard<Content: View>: View {
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

// End of iOS-only implementation
#endif // os(iOS)


