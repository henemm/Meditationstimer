//
//  StartBreathingIntent.swift
//  Lean Health Timer
//
//  App Intent for starting breathing exercises from Shortcuts.
//

import Foundation
import AppIntents
import UIKit

struct StartBreathingIntent: AppIntent {
    static var title: LocalizedStringResource = "Starte Atem-Session"
    static var description = IntentDescription("Startet eine geführte Atem-Übung mit einem ausgewählten Preset.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Preset")
    var preset: BreathingPresetEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Starte Atem-Session: \(\.$preset)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Trigger session start via NotificationCenter with preset name
        NotificationCenter.default.post(
            name: .startBreathingSession,
            object: nil,
            userInfo: ["presetName": preset.id]
        )

        print("[StartBreathingIntent] Triggered breathing: \(preset.id)")

        return .result()
    }
}
