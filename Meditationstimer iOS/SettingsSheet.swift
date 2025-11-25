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
    @AppStorage("countdownBeforeStart") private var countdownBeforeStart: Int = 0

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
                Section(header: Text(NSLocalizedString("Daily Goals in Minutes", comment: "Settings section header"))) {
                    Text(NSLocalizedString("Set your daily goals for meditation and workouts. Progress is shown in the calendar as a partially filled circle.", comment: "Daily goals explanation"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text(NSLocalizedString("Meditation", comment: "Settings label"))
                            .help("Set your daily meditation goal. Progress is shown as a partially filled blue circle in the calendar.")
                        Spacer()
                        Picker("", selection: $meditationGoalMinutes) {
                            ForEach(1...120, id: \.self) { minutes in
                                Text("\(minutes)").tag(minutes)
                            }
                        }
                        #if os(iOS)
                        .pickerStyle(.wheel)
                        #endif
                        .frame(width: 100, height: 120)
                        .help("Choose your daily meditation goal in minutes.")
                    }
                    HStack {
                        Text(NSLocalizedString("Workouts", comment: "Settings label"))
                            .help("Set your daily workout goal. Progress is shown as a partially filled purple circle in the calendar.")
                        Spacer()
                        Picker("", selection: $workoutGoalMinutes) {
                            ForEach(1...120, id: \.self) { minutes in
                                Text("\(minutes)").tag(minutes)
                            }
                        }
                        #if os(iOS)
                        .pickerStyle(.wheel)
                        #endif
                        .frame(width: 100, height: 120)
                        .help("Choose your daily workout goal in minutes.")
                    }
                }

                Section(header: Text(NSLocalizedString("Background Sounds", comment: "Settings section header"))) {
                    Picker(NSLocalizedString("Ambient Sound", comment: "Settings picker label"), selection: ambientSound) {
                        ForEach(AmbientSound.allCases) { sound in
                            Text(LocalizedStringKey(sound.rawValue)).tag(sound)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(.menu)
                    #endif

                    Text(NSLocalizedString("Choose a background sound and activate it for Open and/or Breathe.", comment: "Background sound explanation"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle(NSLocalizedString("Enable for Open (free meditation)", comment: "Settings toggle"), isOn: $ambientSoundOffenEnabled)
                        .disabled(ambientSound.wrappedValue == .none)

                    Toggle(NSLocalizedString("Enable for Breathe (breathing exercises)", comment: "Settings toggle"), isOn: $ambientSoundAtemEnabled)
                        .disabled(ambientSound.wrappedValue == .none)

                    if ambientSound.wrappedValue != .none {
                        // TEST BUTTON - Preview des gewählten Sounds
                        if isPreviewPlaying {
                            Button(NSLocalizedString("Stop Background Sound", comment: "Settings button")) {
                                previewPlayer.stop()
                                isPreviewPlaying = false
                            }
                        } else {
                            Button(NSLocalizedString("Play Background Sound", comment: "Settings button")) {
                                previewPlayer.stop()
                                previewPlayer.setVolume(percent: ambientSoundVolume)
                                previewPlayer.start(sound: ambientSound.wrappedValue)
                                isPreviewPlaying = true
                            }
                        }
                    }
                }

                Section(header: Text(NSLocalizedString("Background Sound Settings", comment: "Settings section header"))) {
                    // GONG TEST - spielt NUR den Gong
                    Button(NSLocalizedString("Test Gong", comment: "Settings button")) {
                        gongPlayer.play(named: "gong-ende") {}
                    }

                    Text(NSLocalizedString("First adjust the system volume using the gong. The background sound volume is relative to the gong.", comment: "Volume explanation"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // VOLUME SLIDER
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(format: NSLocalizedString("relative volume: %d%%", comment: "Volume percentage"), ambientSoundVolume))
                            .font(.subheadline)

                        Slider(value: Binding(
                            get: { Double(ambientSoundVolume) },
                            set: { ambientSoundVolume = Int($0); previewPlayer.setVolume(percent: ambientSoundVolume) }
                        ), in: 0...100, step: 5)
                    }
                }

                Section(header: Text(NSLocalizedString("Breathe Sounds", comment: "Settings section header"))) {
                    Picker(NSLocalizedString("Sound Theme", comment: "Settings picker label"), selection: $selectedAtemTheme) {
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
                            Text(NSLocalizedString("Test Sound", comment: "Settings button"))
                        }
                    }
                }

                Section(header: Text(NSLocalizedString("Workout Programs", comment: "Settings section header"))) {
                    Toggle(NSLocalizedString("Announce exercise names", comment: "Settings toggle"), isOn: $speakExerciseNames)
                        .help("Announces exercise names before each exercise using speech synthesis")
                }

                Section(header: Text(NSLocalizedString("Countdown Before Start (in Seconds)", comment: "Settings section header"))) {
                    Text(NSLocalizedString("Get ready before sessions start. The countdown gives you time to settle in.", comment: "Countdown explanation"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text(NSLocalizedString("Countdown", comment: "Countdown label"))
                        Spacer()
                        Picker("", selection: $countdownBeforeStart) {
                            Text(NSLocalizedString("Off", comment: "Countdown off option")).tag(0)
                            ForEach(1...20, id: \.self) { seconds in
                                Text("\(seconds)").tag(seconds)
                            }
                        }
                        #if os(iOS)
                        .pickerStyle(.wheel)
                        #endif
                        .frame(width: 100, height: 120)
                    }
                }

                Section {
                    Text(NSLocalizedString("Smart reminders are automatically cancelled when you've already completed the activity. This helps you avoid unnecessary notifications.", comment: "Smart reminder explanation"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    NavigationLink(destination: SmartRemindersView()) {
                        Label(NSLocalizedString("Smart Reminders", comment: ""), systemImage: "bell.badge")
                            .help("Configure smart reminders that are automatically cancelled when you've already completed the activity.")
                    }

                }

                #if os(iOS)
                Section {
                    Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                        Label(NSLocalizedString("Open System Settings", comment: ""), systemImage: "gearshape")
                    }
                }
                #endif
            }
            .navigationTitle(NSLocalizedString("Settings", comment: ""))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("Done", comment: "")) {
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
