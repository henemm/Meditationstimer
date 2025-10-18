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

#if !os(iOS)
public struct AtemView: View {
    @Environment(\.scenePhase) private var scenePhase
    public init() {}
    public var body: some View {
        Text("Atem ist nur auf iOS verfügbar.")
    }
}
#else

// MARK: - Atem Tab

public struct AtemView: View {
    // MARK: - Preset Model
    struct Preset: Identifiable, Hashable {
        let id: UUID
        var name: String
        var emoji: String
        var inhale: Int
        var holdIn: Int
        var exhale: Int
        var holdOut: Int
        var repetitions: Int

        init(id: UUID = UUID(), name: String, emoji: String, inhale: Int, holdIn: Int, exhale: Int, holdOut: Int, repetitions: Int) {
            self.id = id
            self.name = name
            self.emoji = emoji
            self.inhale = inhale
            self.holdIn = holdIn
            self.exhale = exhale
            self.holdOut = holdOut
            self.repetitions = repetitions
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
    enum Phase: String { case inhale = "Einatmen", holdIn = "Halten (ein)", exhale = "Ausatmen", holdOut = "Halten (aus)" }

    // MARK: - Session Engine
    final class SessionEngine: ObservableObject {
        enum State: Equatable {
            case idle
            case running(phase: Phase, remaining: Int, rep: Int, totalReps: Int)
            case finished
        }

        @Published private(set) var state: State = .idle
        private var timer: Timer?
        private let gong = GongPlayer()

        func start(preset: Preset) {
            cancel()
            advance(preset: preset, rep: 1)
        }

        func cancel() {
            timer?.invalidate()
            timer = nil
            state = .idle
        }

        private func advance(preset: Preset, rep: Int) {
            let steps: [(Phase, Int, String)] = [
                (.inhale, preset.inhale, "einatmen"),
                (.holdIn, preset.holdIn, "eingeatmet-halten"),
                (.exhale, preset.exhale, "ausatmen"),
                (.holdOut, preset.holdOut, "ausgeatmet-halten")
            ].filter { $0.1 > 0 }

            guard !steps.isEmpty else { state = .finished; return }
            run(steps, index: 0, rep: rep, total: preset.repetitions)
        }

        private func run(_ steps: [(Phase, Int, String)], index: Int, rep: Int, total: Int) {
            if index >= steps.count {
                if rep >= total { state = .finished; return }
                run(steps, index: 0, rep: rep + 1, total: total)
                return
            }

            let (phase, duration, sound) = steps[index]
            gong.play(named: sound)
            state = .running(phase: phase, remaining: duration, rep: rep, totalReps: total)

            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
                guard let self else { return }
                if case .running(let p, let remaining, let r, let tot) = self.state {
                    let next = remaining - 1
                    if next <= 0 {
                        t.invalidate(); self.timer = nil
                        self.run(steps, index: index + 1, rep: r, total: tot)
                    } else {
                        self.state = .running(phase: p, remaining: next, rep: r, totalReps: tot)
                    }
                } else {
                    t.invalidate(); self.timer = nil
                }
            }
            RunLoop.main.add(timer!, forMode: .common)
        }
    }

    // MARK: - Local GongPlayer (only for AtemView)
    final class GongPlayer: NSObject, AVAudioPlayerDelegate {
        func stopAll() {
            for p in active { p.stop() }
            active.removeAll()
        }
        private var active: [AVAudioPlayer] = []

        private func activateSession() {
            let s = AVAudioSession.sharedInstance()
            try? s.setCategory(.playback, options: [.mixWithOthers])
            try? s.setActive(true, options: [])
        }

        func play(named name: String) {
            activateSession()
            // try bundled caf/wav/mp3
            for ext in ["caf","wav","mp3"] {
                if let url = Bundle.main.url(forResource: name, withExtension: ext),
                   let p = try? AVAudioPlayer(contentsOf: url) {
                    p.delegate = self
                    p.prepareToPlay()
                    p.play()
                    active.append(p)
                    return
                }
            }
            print("Audio file '\(name)' not found, no fallback sound played") // fallback
        }
        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            if let i = active.firstIndex(where: { $0 === player }) { active.remove(at: i) }
        }
    }

    // MARK: - Sample Presets & State
    @State private var presets: [Preset] = [
        .init(name: "Box 4-4-4-4", emoji: "🧘", inhale: 4, holdIn: 4, exhale: 4, holdOut: 4, repetitions: 10),
        .init(name: "4-0-6-0",    emoji: "🌬️", inhale: 4, holdIn: 0, exhale: 6, holdOut: 0, repetitions: 10),
        .init(name: "7-0-5-0",    emoji: "🪷", inhale: 7, holdIn: 0, exhale: 5, holdOut: 0, repetitions: 8),
        .init(name: "4-7-8",      emoji: "🌿", inhale: 4, holdIn: 7, exhale: 8, holdOut: 0, repetitions: 10),
        .init(name: "Rectangle 6-3-6-3", emoji: "🫁", inhale: 6, holdIn: 3, exhale: 6, holdOut: 3, repetitions: 8)
    ]

    @State private var showSettings = false
    @State private var showingEditor: Preset? = nil
    @State private var runningPreset: Preset? = nil

    private let emojiChoices: [String] = ["🧘","🪷","🌬️","🫁","🌿","🌀","✨","🔷","🔶","💠"]
    private func randomEmoji() -> String { emojiChoices.randomElement() ?? "🧘" }

    // MARK: - Main View
    public init() {}

    public var body: some View {
        ZStack {
            NavigationStack {
                List {
                    ForEach(presets) { preset in
                        Row(
                            preset: preset,
                            play: { runningPreset = preset },
                            edit: { showingEditor = preset }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onDelete { presets.remove(atOffsets: $0) }
                }
                .listStyle(.plain)
                .padding(.horizontal, 4)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            showingEditor = Preset(name: "Neues Preset",
                                                   emoji: randomEmoji(),
                                                   inhale: 4, holdIn: 0, exhale: 4, holdOut: 0, repetitions: 10)
                        } label: { Image(systemName: "plus") }

                        Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsSheet()
                        .presentationDetents([PresentationDetent.medium, PresentationDetent.large])
                }
                .sheet(item: $showingEditor) { preset in
                    EditorView(
                        preset: preset,
                        isNew: !presets.contains(where: { $0.id == preset.id }),
                        onSave: { edited in
                            if let i = presets.firstIndex(where: { $0.id == edited.id }) {
                                presets[i] = edited
                            } else {
                                presets.append(edited)
                            }
                        },
                        onDelete: { id in
                            if let i = presets.firstIndex(where: { $0.id == id }) {
                                presets.remove(at: i)
                            }
                        }
                    )
                }
            }
            .modifier(OverlayBackgroundEffect(isDimmed: runningPreset != nil))

            // When overlay is up, dim & blur the background to show depth
            if runningPreset != nil {
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

            if let preset = runningPreset {
                SessionCard(preset: preset) { runningPreset = nil }
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(2)
            }
        }
        // removed floating + overlay
    }

// MARK: - OverlayBackgroundEffect (blur/dim background when overlay is shown)
private struct OverlayBackgroundEffect: ViewModifier {
    let isDimmed: Bool
    func body(content: Content) -> some View {
        content
            .blur(radius: isDimmed ? 6 : 0)
            .saturation(isDimmed ? 0.95 : 1)
            .brightness(isDimmed ? -0.02 : 0)
            .animation(.easeInOut(duration: 0.2), value: isDimmed)
            .allowsHitTesting(!isDimmed)
    }
}

// iOS-only code continues below; closing #endif is at the end of file

    // MARK: - Row View (list item)
    struct Row: View {
        let preset: Preset
        let play: () -> Void
        let edit: () -> Void

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

                    // BOTTOM ~1/3: details left, edit right
                    HStack(alignment: .center) {
                        Text("\(preset.rhythmString) · \(preset.repetitions)x · ≈ \(preset.totalDurationString)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
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

    // MARK: - SessionCard (overlay during run)
    struct SessionCard: View {
    // scenePhase-Automatik entfernt – führte zu unerwünschten Beendigungen beim App-Wechsel
        let preset: Preset
        var close: () -> Void
        @StateObject private var engine = SessionEngine()
    @StateObject private var liveActivity = LiveActivityController()
    @State private var showConflictAlert: Bool = false
    @State private var conflictOwnerId: String? = nil
    @State private var conflictTitle: String? = nil
        @State private var sessionStart: Date = .now
        @State private var sessionTotal: TimeInterval = 1
        @State private var phaseStart: Date? = nil
        @State private var phaseDuration: Double = 1
        @State private var lastPhase: Phase? = nil
    // Live Activity removed
        @AppStorage("logMeditationAsYogaWorkout") private var logMeditationAsYogaWorkout: Bool = false

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

        var body: some View {
            ZStack {
                Color(.systemGray6).ignoresSafeArea()
                VStack(spacing: 12) {
                    switch engine.state {
                    case .idle:
                        ProgressView().onAppear {
                            // Set sessionStart and sessionTotal at session start
                            let start = Date()
                            sessionStart = start
                            sessionTotal = TimeInterval(preset.totalSeconds)
                            engine.start(preset: preset)
                            let endDate = start.addingTimeInterval(TimeInterval(preset.totalSeconds))
                            let result = liveActivity.requestStart(title: preset.name, phase: 1, endDate: endDate, ownerId: "AtemTab")
                            if case .conflict(let existingOwner, let existingTitle) = result {
                                conflictOwnerId = existingOwner
                                conflictTitle = existingTitle.isEmpty ? "Ein anderer Timer" : existingTitle
                                showConflictAlert = true
                            }
                        }
                    case .running(let phase, let remaining, let rep, let totalReps):
                        Text(preset.name).font(.headline)
                        // Dual rings: outer = session, inner = per-phase (resets at each phase)
                        TimelineView(.animation, content: { (timeline: TimelineViewDefaultContext) in
                            VStack(spacing: 8) {
                                let now = timeline.date
                                
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
                                Text("Runde \(rep) / \(totalReps)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        })
                    case .finished:
                        VStack {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 40))
                            Text("Fertig").font(.subheadline.weight(.semibold))
                        }
                        // Snap outer progress to full on finish
                        .onAppear {
                            sessionTotal = max(sessionTotal, Date().timeIntervalSince(sessionStart))
                            Task {
                                await liveActivity.end()
                                await endSession(manual: false)
                            }
                        }
                    }
                    Button("Beenden") {
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
            .onChange(of: engine.state) { newState in
                if case .running(let ph, _, _, _) = newState {
                    if ph != lastPhase {
                        lastPhase = ph
                        phaseStart = Date()
                        phaseDuration = Double(duration(for: ph))
                        // Update Live Activity to reflect inner-phase change (emoji/icon only)
                        let phaseNumber: Int
                        switch ph {
                        case .inhale: phaseNumber = 1
                        case .holdIn: phaseNumber = 2
                        case .exhale: phaseNumber = 3
                        case .holdOut: phaseNumber = 4
                        }
                        // Fire-and-forget: update only the small icon/phase; do not alter endDate
                        let sessionEnd = sessionStart.addingTimeInterval(sessionTotal)
                        Task { await liveActivity.update(phase: phaseNumber, endDate: sessionEnd, isPaused: false) }
                    }
                }
            }
            .alert("Timer läuft bereits", isPresented: $showConflictAlert, actions: {
                Button("Abbrechen", role: .cancel) {
                    // user cancelled; just close overlay
                    close()
                }
                Button("Erzwingen", role: .destructive) {
                    // Force the Live Activity and start local engine regardless (per spec allow local start if force fails)
                    Task {
                        liveActivity.forceStart(title: preset.name, phase: 1, endDate: sessionStart.addingTimeInterval(sessionTotal), ownerId: "AtemTab")
                        engine.start(preset: preset)
                    }
                }
            }, message: {
                Text(conflictTitle ?? "Ein anderer Timer läuft")
            })
            // Keine automatische Beendigung bei App-Wechsel
        }

        private func endSession(manual: Bool) async {
            // 1. Stop Engine (immer, nicht nur manuell)
            engine.cancel()

            // 2. Stoppe alle Sounds (falls vorhanden)
            gong.stopAll()

            // 3. HealthKit Logging, wenn Session > 3s
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

            // 4. Beende Live Activity garantiert
            await liveActivity.end(immediate: true)

            // 5. Optional: kurze Verzögerung für UI-Feedback
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s

            // 6. Schließe die View
            close()
        }

        private static func iconName(for phase: Phase) -> String {
            switch phase {
            case .inhale: return "arrow.up"
            case .exhale: return "arrow.down"
            case .holdIn, .holdOut: return "arrow.right"
            }
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
                    Section("Icon") {
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
                    Section("Name") {
                        TextField("Name", text: $draft.name)
                            .textInputAutocapitalization(.words)
                    }
                    Section("Rhythmus (Sekunden)") {
                        pickerRow(title: "Einatmen", value: $draft.inhale)
                        pickerRow(title: "Halten (ein)", value: $draft.holdIn)
                        pickerRow(title: "Ausatmen", value: $draft.exhale)
                        pickerRow(title: "Halten (aus)", value: $draft.holdOut)
                    }
                    Section("Wiederholungen") {
                        AtemWheelPicker("Runden", selection: $draft.repetitions, range: 1...99)
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
                .navigationTitle(isNew ? "Neues Atem-Preset" : "Atem-Preset")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") {
                            onSave(draft); dismiss()
                        }.disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }

        @ViewBuilder
        private func pickerRow(title: String, value: Binding<Int>) -> some View {
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


