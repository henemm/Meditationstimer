//
//  StartBreathingIntent.swift
//  Lean Health Timer
//
//  App Intent for starting breathing exercises from Shortcuts.
//

import Foundation
import AppIntents

struct StartBreathingIntent: AppIntent {
    static var title: LocalizedStringResource = "Starte Atem-Session"
    static var description = IntentDescription("Startet eine geführte Atem-Übung mit einem ausgewählten Preset.")

    @Parameter(title: "Preset")
    var preset: BreathingPresetEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Starte Atem-Session: \(\.$preset)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // URL-encode preset name (handles spaces)
        guard let encodedPreset = preset.id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw IntentError.message("Preset-Name konnte nicht kodiert werden")
        }

        let urlString = "henemm-lht://start?tab=atem&preset=\(encodedPreset)"

        guard let url = URL(string: urlString) else {
            throw IntentError.message("Ungültige URL")
        }

        // Open URL (this will trigger .onOpenURL in ContentView)
        await UIApplication.shared.open(url)

        return .result()
    }
}
