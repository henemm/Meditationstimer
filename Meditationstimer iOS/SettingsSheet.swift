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
    @AppStorage("logWorkoutsAsMindfulness") private var logWorkoutsAsMindfulness: Bool = false
    @AppStorage("logMeditationAsYogaWorkout") private var logMeditationAsYogaWorkout: Bool = false
    @AppStorage("meditationGoalMinutes") private var meditationGoalMinutes: Int = 10
    @AppStorage("workoutGoalMinutes") private var workoutGoalMinutes: Int = 10
    @AppStorage("ambientSound") private var ambientSoundRaw: String = AmbientSound.none.rawValue

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
                    Text("Wird während Offen und Atem Meditationen abgespielt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    NavigationLink(destination: SmartRemindersView()) {
                        Label("Smart Reminders", systemImage: "bell.badge")
                            .help("Konfiguriere intelligente Erinnerungen basierend auf deiner Aktivität.")
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
            #endif
        }
    }
}
