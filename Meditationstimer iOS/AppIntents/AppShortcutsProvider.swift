//
//  AppShortcutsProvider.swift
//  Lean Health Timer
//
//  Registers all App Intents in the Shortcuts app.
//

import Foundation
import AppIntents

struct LeanHealthTimerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Meditation Shortcut
        AppShortcut(
            intent: StartMeditationIntent(),
            phrases: [
                "Starte \(.applicationName) Meditation",
                "Meditiere mit \(.applicationName)",
                "Starte eine Meditation"
            ],
            shortTitle: "Meditation starten",
            systemImageName: "figure.mind.and.body"
        )

        // Breathing Shortcut
        AppShortcut(
            intent: StartBreathingIntent(),
            phrases: [
                "Starte \(.applicationName) Atem-Session",
                "Atme mit \(.applicationName)",
                "Starte Atemübung"
            ],
            shortTitle: "Atem-Session starten",
            systemImageName: "wind"
        )

        // Workout Shortcut
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Starte \(.applicationName) Workout",
                "Trainiere mit \(.applicationName)",
                "Starte ein Workout"
            ],
            shortTitle: "Workout starten",
            systemImageName: "flame"
        )
    }
}
