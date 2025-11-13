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
    @AppStorage("ambientSound") private var ambientSoundRaw: String = AmbientSound.none.rawValue
    @AppStorage("ambientSoundOffenEnabled") private var ambientSoundOffenEnabled: Bool = false
    @AppStorage("ambientSoundAtemEnabled") private var ambientSoundAtemEnabled: Bool = false
    @AppStorage("ambientSoundVolume") private var ambientSoundVolume: Int = 45
    @AppStorage("atemSoundTheme") private var selectedAtemTheme: AtemView.AtemSoundTheme = .distinctive
    @AppStorage("speakExerciseNames") private var speakExerciseNames: Bool = false

    @State private var previewPlayer = AmbientSoundPlayer()
    @State private var gongPlayer = GongPlayer()
    @State private var isPreviewPlaying = false

    private var ambientSound: Binding<AmbientSound> {
        Binding(
            get: { AmbientSound(rawValue: ambientSoundRaw) ?? .none },
            set: { ambientSoundRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Tägliche Ziele in Minuten")) {
                    Text("Setze deine täglichen Ziele für Meditation und Workouts. Der Fortschritt wird im Kalender als teilgefüllter Kreis angezeigt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

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

                Section(header: Text("Hintergrundsounds")) {
                    Picker("Ambient-Sound", selection: ambientSound) {
                        ForEach(AmbientSound.allCases) { sound in
                            Text(sound.rawValue).tag(sound)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(.menu)
                    #endif

                    Text("Wähle einen Hintergrundsound und aktiviere ihn für Offen und/oder Atem.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle("Für Offen (freie Meditation) aktivieren", isOn: $ambientSoundOffenEnabled)
                        .disabled(ambientSound.wrappedValue == .none)

                    Toggle("Für Atem (Atemübungen) aktivieren", isOn: $ambientSoundAtemEnabled)
                        .disabled(ambientSound.wrappedValue == .none)

                    if ambientSound.wrappedValue != .none {
                        // TEST BUTTON - Preview des gewählten Sounds
                        if isPreviewPlaying {
                            Button("Stop Hintergrundsound") {
                                previewPlayer.stop()
                                isPreviewPlaying = false
                            }
                        } else {
                            Button("Play Hintergrundsound") {
                                previewPlayer.stop()
                                previewPlayer.setVolume(percent: ambientSoundVolume)
                                previewPlayer.start(sound: ambientSound.wrappedValue)
                                isPreviewPlaying = true
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

                Section(header: Text("Atem-Sounds")) {
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
                    Text("Intelligente Erinnerungen werden automatisch storniert, wenn du die Aktivität bereits durchgeführt hast. So vermeidest du unnötige Benachrichtigungen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    NavigationLink(destination: SmartRemindersView()) {
                        Label("Smart Reminders", systemImage: "bell.badge")
                            .help("Konfiguriere intelligente Erinnerungen, die automatisch storniert werden wenn du die Aktivität bereits durchgeführt hast.")
                    }

                    NavigationLink(destination: SmartReminderDebugView()) {
                        Label("Smart Reminder Debug", systemImage: "ant.circle")
                            .help("Zeigt alle Smart Reminder Details: Reminders, Cancelled List, Pending Notifications, Permissions.")
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
