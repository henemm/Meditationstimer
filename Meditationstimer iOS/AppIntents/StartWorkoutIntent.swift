//
//  StartWorkoutIntent.swift
//  Lean Health Timer
//
//  App Intent for starting workout sessions from Shortcuts.
//

import Foundation
import AppIntents
import UIKit

struct StartWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Starte Workout"
    static var description = IntentDescription("Startet eine HIIT-Workout-Session mit konfigurierbaren Intervallen.")

    @Parameter(title: "Belastung (Sekunden)", default: 30, controlStyle: .field, inclusiveRange: (5, 600))
    var intervalSec: Int

    @Parameter(title: "Erholung (Sekunden)", default: 10, controlStyle: .field, inclusiveRange: (0, 600))
    var restSec: Int

    @Parameter(title: "Wiederholungen", default: 10, controlStyle: .field, inclusiveRange: (1, 200))
    var repeats: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Starte Workout: \(\.$intervalSec)s Belastung / \(\.$restSec)s Erholung × \(\.$repeats)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Encode parameters as URL
        let urlString = "henemm-lht://start?tab=workouts&interval=\(intervalSec)&rest=\(restSec)&repeats=\(repeats)"

        guard let url = URL(string: urlString) else {
            throw IntentError.message("Ungültige URL")
        }

        // Open URL (this will trigger .onOpenURL in ContentView)
        await UIApplication.shared.open(url)

        return .result()
    }
}
