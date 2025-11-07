//
//  SettingsSheet.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 27.09.25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Gemeinsames Einstellungs‑Sheet für alle Tabs.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("logWorkoutsAsMindfulness") private var logWorkoutsAsMindfulness: Bool = false
    @AppStorage("logMeditationAsYogaWorkout") private var logMeditationAsYogaWorkout: Bool = false
    @AppStorage("meditationGoalMinutes") private var meditationGoalMinutes: Int = 10
    @AppStorage("workoutGoalMinutes") private var workoutGoalMinutes: Int = 10
    @AppStorage("ambientSoundOffen") private var ambientSoundOffenRaw: String = AmbientSound.none.rawValue
    @AppStorage("ambientSoundAtem") private var ambientSoundAtemRaw: String = AmbientSound.none.rawValue
    @AppStorage("ambientSoundVolume") private var ambientSoundVolume: Int = 45
    @AppStorage("atemSoundTheme") private var selectedAtemTheme: AtemView.AtemSoundTheme = .distinctive
    @AppStorage("speakExerciseNames") private var speakExerciseNames: Bool = false

    @State private var previewPlayer = AmbientSoundPlayer()
    @State private var gongPlayer = GongPlayer()
    @State private var isPreviewPlaying = false
    @State private var previewingSound: AmbientSound = .none  // Track which sound is currently previewing

    private var ambientSoundOffen: Binding<AmbientSound> {
        Binding(
            get: { AmbientSound(rawValue: ambientSoundOffenRaw) ?? .none },
            set: { ambientSoundOffenRaw = $0.rawValue }
        )
    }

    private var ambientSoundAtem: Binding<AmbientSound> {
        Binding(
            get: { AmbientSound(rawValue: ambientSoundAtemRaw) ?? .none },
            set: { ambientSoundAtemRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Tägliche Ziele in Minuten")) {
                    HStack {
                        Text("Meditation")
                            .help("Setze dein tägliches Meditation-Ziel. Der Fortschritt wird als teilgefüllter blauer Kreis im Kalender angezeigt.")
                        Spacer()
                        Picker("", selection: $meditationGoalMinutes) {
                            ForEach(1...120, id: \.self) { minutes in
                                Text("\(minutes)").tag(minutes)
                            }
                        }
                        #if os(iOS)
                        .pickerStyle(.wheel)
                        #endif
                        .frame(width: 80, height: 120)
                        .help("Wähle dein tägliches Meditation-Ziel in Minuten.")
                    }
                    HStack {
                        Text("Workouts")
                            .help("Setze dein tägliches Workout-Ziel. Der Fortschritt wird als teilgefüllter violetter Kreis im Kalender angezeigt.")
                        Spacer()
                        Picker("", selection: $workoutGoalMinutes) {
                            ForEach(1...120, id: \.self) { minutes in
                                Text("\(minutes)").tag(minutes)
                            }
                        }
                        #if os(iOS)
                        .pickerStyle(.wheel)
                        #endif
                        .frame(width: 80, height: 120)
                        .help("Wähle dein tägliches Workout-Ziel in Minuten.")
                    }
                }

                Section(header: Text("Hintergrundsounds - Offen (freie Meditation)")) {
                    Picker("Ambient-Sound", selection: ambientSoundOffen) {
                        ForEach(AmbientSound.allCases) { sound in
                            Text(sound.rawValue).tag(sound)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(.menu)
                    #endif

                    Text("Hintergrundsound für Meditation im Offen-Tab.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if ambientSoundOffen.wrappedValue != .none {
                        // PREVIEW - spielt NUR den Ambient Sound
                        if isPreviewPlaying && previewingSound == ambientSoundOffen.wrappedValue {
                            Button("Stop Hintergrundsound") {
                                previewPlayer.stop()
                                isPreviewPlaying = false
                            }
                        } else {
                            Button("Play Hintergrundsound") {
                                previewPlayer.stop()  // Stop any currently playing preview
                                previewPlayer.setVolume(percent: ambientSoundVolume)
                                previewPlayer.start(sound: ambientSoundOffen.wrappedValue)
                                isPreviewPlaying = true
                                previewingSound = ambientSoundOffen.wrappedValue
                            }
                        }
                    }
                }

                Section(header: Text("Hintergrundsounds - Atem (Atemübungen)")) {
                    Picker("Ambient-Sound", selection: ambientSoundAtem) {
                        ForEach(AmbientSound.allCases) { sound in
                            Text(sound.rawValue).tag(sound)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(.menu)
                    #endif

                    Text("Hintergrundsound für Atemübungen im Atem-Tab.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if ambientSoundAtem.wrappedValue != .none {
                        // PREVIEW - spielt NUR den Ambient Sound
                        if isPreviewPlaying && previewingSound == ambientSoundAtem.wrappedValue {
                            Button("Stop Hintergrundsound") {
                                previewPlayer.stop()
                                isPreviewPlaying = false
                            }
                        } else {
                            Button("Play Hintergrundsound") {
                                previewPlayer.stop()  // Stop any currently playing preview
                                previewPlayer.setVolume(percent: ambientSoundVolume)
                                previewPlayer.start(sound: ambientSoundAtem.wrappedValue)
                                isPreviewPlaying = true
                                previewingSound = ambientSoundAtem.wrappedValue
                            }
                        }
                    }
                }

                Section(header: Text("Hintergrundsound Einstellungen")) {
                    // GONG TEST - spielt NUR den Gong
                    Button("Gong testen") {
                        gongPlayer.play(named: "gong-ende") {}
                    }

                    Text("Stelle zuerst die Systemlautstärke mit dem Gong ein. Die Lautstärke des Hintergrundgeräuschs ist relativ zum Gong.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // VOLUME SLIDER
                    VStack(alignment: .leading, spacing: 8) {
                        Text("relative Lautstärke: \(ambientSoundVolume)%")
                            .font(.subheadline)

                        Slider(value: Binding(
                            get: { Double(ambientSoundVolume) },
                            set: { ambientSoundVolume = Int($0); previewPlayer.setVolume(percent: ambientSoundVolume) }
                        ), in: 0...100, step: 5)
                    }
                }

                Section(header: Text("Atem-Sounds 🎵")) {
                    Picker("Sound-Theme", selection: $selectedAtemTheme) {
                        ForEach(AtemView.AtemSoundTheme.allCases, id: \.self) { theme in
                            Text("\(theme.emoji) \(theme.displayName)")
                                .tag(theme)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(.menu)
                    #endif

                    Text(selectedAtemTheme.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(action: {
                        gongPlayer.play(named: "\(selectedAtemTheme.rawValue)-in")
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Sound testen")
                        }
                    }
                }

                Section(header: Text("Workout-Programme")) {
                    Toggle("Übungsnamen ansagen", isOn: $speakExerciseNames)
                        .help("Spricht Übungsnamen vor jeder Übung per Sprachsynthese an")

                    Text("Verwendet die Systemsprache für Ansagen (Deutsch/Englisch).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    NavigationLink(destination: SmartRemindersView()) {
                        Label("Smart Reminders", systemImage: "bell.badge")
                            .help("Konfiguriere intelligente Erinnerungen, die automatisch storniert werden wenn du die Aktivität bereits durchgeführt hast.")
                    }
                }

                #if os(iOS)
                Section {
                    Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                        Label("System‑Einstellungen öffnen", systemImage: "gearshape")
                    }
                }
                #endif
            }
            .navigationTitle("Einstellungen")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
            #endif
            .onDisappear {
                // Stop preview if playing when sheet is dismissed
                if isPreviewPlaying {
                    previewPlayer.stop()
                    isPreviewPlaying = false
                }
            }
        }
    }

}
