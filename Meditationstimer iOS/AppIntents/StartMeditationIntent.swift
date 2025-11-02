//
//  StartMeditationIntent.swift
//  Lean Health Timer
//
//  App Intent for starting meditation sessions from Shortcuts.
//

import Foundation
import AppIntents
import UIKit

struct StartMeditationIntent: AppIntent {
    static var title: LocalizedStringResource = "Starte Meditation"
    static var description = IntentDescription("Startet eine freie Meditations-Session mit konfigurierbaren Phasen.")

    @Parameter(title: "Meditation (Minuten)", default: 15, controlStyle: .field, inclusiveRange: (1, 120))
    var phase1Minutes: Int

    @Parameter(title: "Besinnung (Minuten)", default: 0, controlStyle: .field, inclusiveRange: (0, 30))
    var phase2Minutes: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Starte \(\.$phase1Minutes) Min Meditation + \(\.$phase2Minutes) Min Besinnung")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Encode parameters as URL
        let urlString = "henemm-lht://start?tab=offen&phase1=\(phase1Minutes)&phase2=\(phase2Minutes)"

        guard let url = URL(string: urlString) else {
            throw IntentError.message("Ungültige URL")
        }

        // Open URL (this will trigger .onOpenURL in ContentView)
        await UIApplication.shared.open(url)

        return .result()
    }
}

// MARK: - Intent Error
enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case message(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .message(let msg):
            return "\(msg)"
        }
    }
}
