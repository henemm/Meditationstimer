// probe: second-test
// probe: work-with-apps
//
//  ContentView.swift
//  Meditationstimer iOS
//
//  Created by Henning Emmrich on 01.09.25.
//

import SwiftUI
import AVFoundation
import HealthKit
import ActivityKit
import UIKit


struct ContentView: View {
    // Einstellungen (merken letzte Werte)
    @AppStorage("phase1Minutes") private var phase1Minutes: Int = 15
    @AppStorage("phase2Minutes") private var phase2Minutes: Int = 3

    // Services
    private let hk = HealthKitManager()
    private let notifier = NotificationHelper()
    @StateObject private var engine = TwoPhaseTimerEngine()
    private let gong = GongPlayer()
    private let bgAudio = BackgroundAudioKeeper()

    // UI State
    @State private var showingError: String?
    @State private var askedPermissions = false
    @State private var lastState: TwoPhaseTimerEngine.State = .idle
    @Environment(\.scenePhase) private var scenePhase
    @State private var currentActivity: Activity<MeditationAttributes>?
    @State private var showSettings = false

    private var offenTab: some View {
        NavigationView {
            GlassCard {
                VStack(spacing: 16) {
                    switch engine.state {
                    case .idle, .finished:
                        pickerSection
                        Button(action: { startSession() }) {
                            Image(systemName: "play.circle.fill")
                                .resizable()
                                .frame(width: 72, height: 72)
                                .foregroundStyle(.tint)
                        }
                        .buttonStyle(.plain)

                    case .phase1(let remaining):
                        phaseView(title: "Meditation", remaining: remaining, total: phase1Minutes * 60)
                        Button("Abbrechen", role: .destructive) { cancelSession() }

                    case .phase2(let remaining):
                        phaseView(title: "Besinnung", remaining: remaining, total: phase2Minutes * 60)
                        Button("Abbrechen", role: .destructive) { cancelSession() }
                    }
                }
            }
            .padding()
            .toolbarBackground(.regularMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Meditationstimer")
                        .font(.headline)
                }
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
        }
    }

    var body: some View {
        TabView {
            offenTab
                .tabItem { Label("Offen", systemImage: "figure.mind.and.body") }

            AtemView()
                .tabItem { Label("Atem", systemImage: "wind") }

            WorkoutsView()
                .tabItem { Label("Workouts", systemImage: "dumbbell") }
        }
        .background(
            LinearGradient(colors: [Color.blue.opacity(0.20), Color.purple.opacity(0.15)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
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
        .onChange(of: engine.state) { oldValue, new in
            // Übergang Phase1 -> Phase2: dreifacher Gong
            if case .phase1 = oldValue, case .phase2 = new {
                gong.play(named: "gong-dreimal")
                Task {
                    let state = MeditationAttributes.ContentState(
                        endDate: Date().addingTimeInterval(TimeInterval(phase2Minutes * 60)),
                        phase: 2
                    )
                    await currentActivity?.update(using: state)
                }
            }
            // Natürliches Ende: End-Gong + Logging
            if new == .finished {
                gong.play(named: "gong-ende") {
                    setIdleTimer(false)
                    bgAudio.stop()
                    finishSessionLogPhase1Only()
                    Task {
                        await currentActivity?.end(dismissalPolicy: .immediate)
                        currentActivity = nil
                    }
                }
            }
        }
        .alert("Hinweis", isPresented: .constant(showingError != nil), actions: {
            Button("OK") { showingError = nil }
        }, message: { Text(showingError ?? "") })
    }

    // Bildschirm an/aus verhindern/erlauben
    private func setIdleTimer(_ disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }

    // MARK: - Subviews

    private var pickerSection: some View {
        HStack(alignment: .center, spacing: 20) {

            // Linke Spalte: Emojis + Labels
            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    Text("🧘")
                        .font(.system(size: 64))
                    Text("Meditation")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 6) {
                    Text("🪷")
                        .font(.system(size: 64))
                    Text("Besinnung")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 110, alignment: .center)

            // Rechte Spalte: große „Drehräder“ (Wheel-Picker) für Zeiten
            VStack(spacing: 24) {
                WheelPicker("", selection: $phase1Minutes, range: 0...60)
                    .frame(width: 160, height: 130)

                WheelPicker("", selection: $phase2Minutes, range: 0...60)
                    .frame(width: 160, height: 130)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }


    private func phaseView(title: String, remaining: Int, total: Int) -> some View {
        let totalSafe = max(1, total)
        let progress = Double(remaining) / Double(totalSafe)   // 1.0 → 0.0 (schrumpft)

        return VStack(spacing: 16) {
            Text(title).font(.headline)
            ZStack {
                CircularRing(progress: progress, lineWidth: 30)
                    .frame(width: 240, height: 240)
                Text(format(remaining))
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Actions

    private func startSession() {
        setIdleTimer(true)
        gong.play(named: "gong-ende")
        bgAudio.start()
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

        if ActivityAuthorizationInfo().areActivitiesEnabled {
            let attributes = MeditationAttributes(title: "Meditation")
            let state = MeditationAttributes.ContentState(
                endDate: Date().addingTimeInterval(TimeInterval(phase1Minutes * 60)),
                phase: 1
            )
            do {
                currentActivity = try Activity<MeditationAttributes>.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: nil
                )
            } catch {
                print("Live Activity request failed: \(error)")
            }
        }
    }

    private func cancelSession() {
        setIdleTimer(false)
        bgAudio.stop()
        Task { await notifier.cancelAll() }
        Task { await logPhase1OnCancel() } // immer loggen
        engine.cancel()
        Task {
            await currentActivity?.end(dismissalPolicy: .immediate)
            currentActivity = nil
        }
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


private struct SettingsSheet: View {
    @AppStorage("phase1Minutes") private var defaultP1: Int = 15
    @AppStorage("phase2Minutes") private var defaultP2: Int = 3
    @AppStorage("soundEnabled")  private var soundEnabled: Bool = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true

    var body: some View {
        NavigationView {
            Form {
                Section("Feedback") {
                    Toggle("Ton (iPhone)", isOn: $soundEnabled)
                    Toggle("Haptik (Watch)", isOn: $hapticsEnabled)
                }
                Section {
                    Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                        Label("System‑Einstellungen öffnen", systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle("Einstellungen")
        }
    }
}

// MARK: - Atem: Datenmodell & Helfer

private struct BreathPreset: Identifiable, Hashable {
    let id: UUID
    var name: String
    var inhale: Int      // seconds
    var holdIn: Int      // seconds (0 = skip)
    var exhale: Int      // seconds
    var holdOut: Int     // seconds (0 = skip)
    var repetitions: Int
    var emoji: String

    init(id: UUID = UUID(), name: String, inhale: Int, holdIn: Int, exhale: Int, holdOut: Int, repetitions: Int, emoji: String) {
        self.id = id
        self.name = name
        self.inhale = inhale
        self.holdIn = holdIn
        self.exhale = exhale
        self.holdOut = holdOut
        self.repetitions = repetitions
        self.emoji = emoji
    }

    var cycleSeconds: Int { inhale + holdIn + exhale + holdOut }
    var totalSeconds: Int { cycleSeconds * max(1, repetitions) }

    var rhythmString: String { "\(inhale)-\(holdIn)-\(exhale)-\(holdOut)" }

    var totalDurationString: String {
        let s = totalSeconds
        let m = s / 60
        let r = s % 60
        return m > 0 ? String(format: "%d:%02d min", m, r) : "\(s) sec"
    }
}

/// Kleiner Helfer zum sequenziellen Abspielen einer *Testrunde* (ein Zyklus) eines Presets.
private final class BreathPreviewPlayer {
    private let gong = GongPlayer()

    func previewOneCycle(_ p: BreathPreset) {
        // Spiele nur die vier Schritte *einmal* nacheinander, Zeiten in Sekunden.
        // 0-Sekunden-Schritte werden übersprungen.
        var delay: TimeInterval = 0
        func schedule(_ sound: String, seconds: Int) {
            guard seconds > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.gong.play(named: sound)
            }
            delay += TimeInterval(seconds)
        }
        schedule("einatmen", seconds: p.inhale)
        schedule("eingeatmet-halten", seconds: p.holdIn)
        schedule("ausatmen", seconds: p.exhale)
        schedule("ausgeatmet-halten", seconds: p.holdOut)
    }
}

// MARK: - Atem: Editor (Wheel-Picker + Text-Dauer)
private struct BreathEditorView: View {
    @Environment(\.dismiss) private var dismiss

    // The preset currently being edited (mutable copy)
    @State private var draft: BreathPreset
    let isNew: Bool
    let onSave: (BreathPreset) -> Void
    let onDelete: ((UUID) -> Void)?

    init(preset: BreathPreset, isNew: Bool, onSave: @escaping (BreathPreset) -> Void, onDelete: ((UUID) -> Void)? = nil) {
        self._draft = State(initialValue: preset)
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete
    }

    private var totalString: String {
        let cycle = draft.inhale + draft.holdIn + draft.exhale + draft.holdOut
        let total = cycle * max(1, draft.repetitions)
        if total >= 60 {
            return String(format: "≈ %d:%02d min", total/60, total%60)
        } else {
            return "≈ \(total) sec"
        }
    }

    var body: some View {
        NavigationView {
            Form {
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
                    WheelPicker("Runden", selection: $draft.repetitions, range: 1...99)
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        onSave(draft)
                        dismiss()
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
            WheelPicker("", selection: value, range: 0...60)
                .frame(width: 120, height: 100)
        }
    }
}


// MARK: - Atem: Lauf-Engine & Run-UI

private enum BreathPhase: String {
    case inhale = "Einatmen"
    case holdIn = "Halten (ein)"
    case exhale = "Ausatmen"
    case holdOut = "Halten (aus)"
}

private final class BreathSessionEngine: ObservableObject {
    enum State: Equatable {
        case idle
        case running(phase: BreathPhase, remaining: Int, stepTotal: Int, rep: Int, totalReps: Int)
        case finished
    }

    @Published private(set) var state: State = .idle
    private var timer: Timer?
    private let gong = GongPlayer()

    func start(preset: BreathPreset) {
        cancel()
        advanceThrough(preset: preset, rep: 1)
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        state = .idle
    }

    private func advanceThrough(preset: BreathPreset, rep: Int) {
        let steps: [(BreathPhase, Int, String)] = [
            (.inhale, preset.inhale, "einatmen"),
            (.holdIn, preset.holdIn, "eingeatmet-halten"),
            (.exhale, preset.exhale, "ausatmen"),
            (.holdOut, preset.holdOut, "ausgeatmet-halten")
        ].filter { $0.1 > 0 }

        guard !steps.isEmpty else {
            state = .finished
            return
        }

        runSteps(steps, index: 0, currentRep: rep, totalReps: preset.repetitions)
    }

    private func runSteps(_ steps: [(BreathPhase, Int, String)], index: Int, currentRep: Int, totalReps: Int) {
        if index >= steps.count {
            // Nächste Wiederholung oder fertig
            if currentRep >= totalReps {
                state = .finished
                return
            } else {
                runSteps(steps, index: 0, currentRep: currentRep + 1, totalReps: totalReps)
                return
            }
        }

        let (phase, duration, sound) = steps[index]
        gong.play(named: sound)
        state = .running(phase: phase, remaining: duration, stepTotal: duration, rep: currentRep, totalReps: totalReps)

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            guard let self = self else { return }
            switch self.state {
            case .running(let p, let remaining, let stepTotal, let rep, let total):
                let next = remaining - 1
                if next <= 0 {
                    t.invalidate()
                    self.timer = nil
                    self.runSteps(steps, index: index + 1, currentRep: rep, totalReps: total)
                } else {
                    self.state = .running(phase: p, remaining: next, stepTotal: stepTotal, rep: rep, totalReps: total)
                }
            default:
                t.invalidate()
                self.timer = nil
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
}

private struct AtemSessionView: View {
    let preset: BreathPreset
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = BreathSessionEngine()

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                switch engine.state {
                case .idle:
                    ProgressView().onAppear { engine.start(preset: preset) }
                case .running(let phase, let remaining, _, let rep, let total):
                    Text(preset.name)
                        .font(.headline)
                    Text("\(phase.rawValue)")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%02d", remaining))
                        .font(.system(size: 72, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("Runde \(rep) / \(total)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .finished:
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 46))
                    Text("Fertig")
                        .font(.title3.weight(.semibold))
                        .padding(.top, 4)
                }
                Button("Beenden") {
                    engine.cancel()
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Atem")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// Kompakte, zentrierte Karte für die Atem-Session (statt Sheet am unteren Rand)
private struct AtemSessionCard: View {
    let preset: BreathPreset
    var close: () -> Void
    @StateObject private var engine = BreathSessionEngine()

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                switch engine.state {
                case .idle:
                    ProgressView().onAppear { engine.start(preset: preset) }
                case .running(let phase, let remaining, let stepTotal, let rep, let total):
                    Text(preset.name)
                        .font(.headline)
                    VStack(spacing: 8) {
                        Image(systemName: iconName(for: phase))
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(.secondary)
                        Gauge(value: stepTotal > 0 ? (1 - Double(remaining) / Double(stepTotal)) : 0) {
                            EmptyView()
                        } currentValueLabel: {
                            Text(String(format: "%02d", remaining))
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                        }
                        .gaugeStyle(.accessoryCircular)
                        .tint(.accentColor)
                        .frame(width: 72, height: 72)
                    }
                    Text("Runde \(rep) / \(total)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .finished:
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 40))
                    Text("Fertig").font(.subheadline.weight(.semibold))
                }
                HStack {
                    Spacer()
                    Button("Beenden") {
                        engine.cancel()
                        close()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(minWidth: 260, maxWidth: 340)
        }
        .padding(16)
    }

    private func iconName(for phase: BreathPhase) -> String {
        switch phase {
        case .inhale:   return "arrow.up.circle"
        case .exhale:   return "arrow.down.circle"
        case .holdIn, .holdOut: return "arrow.right.circle"
        }
    }
}

private struct AtemView: View {
    @State private var presets: [BreathPreset] = [
        .init(name: "Box 4-4-4-4", inhale: 4, holdIn: 4, exhale: 4, holdOut: 4, repetitions: 10, emoji: "🧘"),
        .init(name: "4-0-6-0", inhale: 4, holdIn: 0, exhale: 6, holdOut: 0, repetitions: 10, emoji: "🌬️"),
        .init(name: "7-0-5-0", inhale: 7, holdIn: 0, exhale: 5, holdOut: 0, repetitions: 8, emoji: "🪷"),
        .init(name: "4-7-8", inhale: 4, holdIn: 7, exhale: 8, holdOut: 0, repetitions: 10, emoji: "🌿"),
        .init(name: "Rectangle 6-3-6-3", inhale: 6, holdIn: 3, exhale: 6, holdOut: 3, repetitions: 8, emoji: "🫁")
    ]

    @State private var showingEditor: BreathPreset? = nil
    @State private var runningPreset: BreathPreset? = nil
    private let emojiChoices: [String] = ["🧘","🪷","🌬️","🫁","🌿","🌀","✨","🔷","🔶","💠"]
    private func randomEmoji() -> String { emojiChoices.randomElement() ?? "🧘" }
    private let preview = BreathPreviewPlayer()

    var body: some View {
        ZStack {
            NavigationView {
                List {
                    ForEach(presets) { preset in
                        AtemRow(preset: preset,
                                play: { runningPreset = preset },
                                edit: { showingEditor = preset })
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onDelete { indexSet in
                        presets.remove(atOffsets: indexSet)
                    }
                }
                .listStyle(.plain)
                .padding(.horizontal, 4)
                .navigationTitle("Atem")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingEditor = BreathPreset(name: "Neues Preset", inhale: 4, holdIn: 0, exhale: 4, holdOut: 0, repetitions: 10, emoji: randomEmoji())
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .accessibilityLabel("Neues Preset")
                    }
                }
                .sheet(item: $showingEditor) { preset in
                    BreathEditorView(
                        preset: preset,
                        isNew: !presets.contains(where: { $0.id == preset.id }),
                        onSave: { edited in
                            if let idx = presets.firstIndex(where: { $0.id == edited.id }) {
                                presets[idx] = edited
                            } else {
                                presets.append(edited)
                            }
                        },
                        onDelete: { id in
                            if let idx = presets.firstIndex(where: { $0.id == id }) {
                                presets.remove(at: idx)
                            }
                        }
                    )
                }
            }
            // Centered overlay card instead of bottom sheet
            if let preset = runningPreset {
                Color.black.opacity(0.25).ignoresSafeArea()
                    .onTapGesture {
                        // tap outside closes
                        runningPreset = nil
                    }
                AtemSessionCard(preset: preset) {
                    runningPreset = nil
                }
            }
        }
    }
}

// Einzellistenzeile im Glass-Stil
private struct AtemRow: View {
    let preset: BreathPreset
    let play: () -> Void
    let edit: () -> Void

    var body: some View {
        GlassCard {
            HStack(alignment: .center, spacing: 12) {
                Text(preset.emoji)
                    .font(.system(size: 28))
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(.headline)
                    Text("\(preset.rhythmString) · \(preset.repetitions)x · ≈ \(preset.totalDurationString)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 14) {
                    Button(action: play) {
                        Image(systemName: "play.circle.fill")
                            .imageScale(.large)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    Button(action: edit) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .regular))
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(minHeight: 96)
        }
    }
}

private struct WorkoutsView: View {
    var body: some View {
        NavigationView {
            GlassCard {
                VStack(spacing: 12) {
                    Text("Workouts")
                        .font(.headline)
                    Text("Bald verfügbar")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationTitle("Workouts")
        }
    }
}

#Preview {
    ContentView()
}

