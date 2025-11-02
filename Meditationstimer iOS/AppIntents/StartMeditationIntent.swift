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
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Meditation (Minuten)", default: 15, controlStyle: .field, inclusiveRange: (1, 120))
    var phase1Minutes: Int

    @Parameter(title: "Besinnung (Minuten)", default: 0, controlStyle: .field, inclusiveRange: (0, 30))
    var phase2Minutes: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Starte \(\.$phase1Minutes) Min Meditation + \(\.$phase2Minutes) Min Besinnung")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Update AppStorage values (OffenView will pick them up)
        UserDefaults.standard.set(phase1Minutes, forKey: "phase1Minutes")
        UserDefaults.standard.set(phase2Minutes, forKey: "phase2Minutes")

        // Trigger session start via NotificationCenter
        NotificationCenter.default.post(name: .startMeditationSession, object: nil)

        print("[StartMeditationIntent] Triggered meditation: \(phase1Minutes)min + \(phase2Minutes)min")

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
