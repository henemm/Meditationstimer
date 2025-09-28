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
import AudioToolbox
import UIKit

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
            AudioServicesPlaySystemSound(1005) // fallback
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
            NavigationView {
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
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 10) {
                            Button {
                                showingEditor = Preset(name: "Neues Preset",
                                                       emoji: randomEmoji(),
                                                       inhale: 4, holdIn: 0, exhale: 4, holdOut: 0, repetitions: 10)
                            } label: {
                                Image(systemName: "plus")
                                    .imageScale(.large)
                                    .padding(8)
                            }
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gear")
                                    .imageScale(.large)
                                    .padding(8)
                            }
                        }
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

            if let preset = runningPreset {
                Color.black.opacity(0.08).ignoresSafeArea()
                    .onTapGesture { runningPreset = nil }
                SessionCard(preset: preset) { runningPreset = nil }
            }
        }
        // removed floating + overlay
    }

    // MARK: - Row View (list item)
    struct Row: View {
        let preset: Preset
        let play: () -> Void
        let edit: () -> Void

        var body: some View {
            GlassCard {
                HStack(alignment: .center, spacing: 12) {
                    Text(preset.emoji).font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preset.name).font(.headline)
                        Text("\(preset.rhythmString) · \(preset.repetitions)x · ≈ \(preset.totalDurationString)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 30) {
                        Button(action: play) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 30))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                                .padding(4)
                        }.buttonStyle(.plain)
                        Button(action: edit) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20, weight: .regular))
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                                .padding(4)
                        }.buttonStyle(.plain)
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(minHeight: 120)
            }
        }
    }

    // MARK: - SessionCard (overlay during run)
    struct SessionCard: View {
        let preset: Preset
        var close: () -> Void
        @StateObject private var engine = SessionEngine()
        @State private var stepStart: Date = .now
        @State private var stepDuration: TimeInterval = 1

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
        private func priorSum(before phase: Phase) -> Int {
            switch phase {
            case .inhale: return 0
            case .holdIn: return preset.inhale
            case .exhale: return preset.inhale + preset.holdIn
            case .holdOut: return preset.inhale + preset.holdIn + preset.exhale
            }
        }

        var body: some View {
            GlassCard {
                VStack(spacing: 12) {
                    switch engine.state {
                    case .idle:
                        ProgressView().onAppear { engine.start(preset: preset) }
                    case .running(let phase, let remaining, let rep, let total):
                        Text(preset.name).font(.headline)
                        // Continuous dual rings: inner = current phase, outer = full session
                        let phaseDuration = max(1, duration(for: phase))
                        // Reset phase timer baseline whenever the phase changes
                        EmptyView()
                            .task(id: phase) {
                                stepStart = .now
                                stepDuration = TimeInterval(phaseDuration)
                            }

                        TimelineView(.animation) { _ in
                            let elapsedPhase = Date().timeIntervalSince(stepStart)
                            let fractionPhase = max(0.0, min(1.0, elapsedPhase / max(0.001, stepDuration))) // 0…1

                            // Outer total progress uses continuous cycle progress
                            let prior = Double(priorSum(before: phase))
                            let progressCycle = cycleSeconds > 0 ? (prior + fractionPhase * Double(phaseDuration)) / Double(cycleSeconds) : 0.0
                            let progressTotal = (Double(rep - 1) + progressCycle) / Double(max(1, total))

                            ZStack {
                                // Outer ring: total session progress (continuous)
                                CircularRing(progress: progressTotal, lineWidth: 22)
                                    .foregroundStyle(.tint)
                                // Inner ring: current phase progress (continuous, scaled)
                                CircularRing(progress: fractionPhase, lineWidth: 14)
                                    .scaleEffect(0.72)
                                    .foregroundStyle(.secondary)
                                // Center icon: phase direction (no circle)
                                Image(systemName: iconName(for: phase))
                                    .font(.system(size: 64, weight: .regular))
                                    .foregroundStyle(.tint)
                            }
                            .frame(width: 320, height: 320)
                            .padding(.top, 6)
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
                .frame(minWidth: 280, maxWidth: 360)
            }
            .padding(16)
        }

        private func iconName(for phase: Phase) -> String {
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
                WheelPicker("", selection: value, range: 0...60)
                    .frame(width: 120, height: 100)
            }
        }
    }

    // MARK: - WheelPicker (number wheel)
    struct WheelPicker: View {
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
    struct GlassCard<Content: View>: View {
        @ViewBuilder var content: () -> Content
        var body: some View {
            content()
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
        }
    }
}

