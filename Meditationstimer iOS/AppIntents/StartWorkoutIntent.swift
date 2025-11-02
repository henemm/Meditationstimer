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
    static var openAppWhenRun: Bool = true

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
        // Update AppStorage values (WorkoutsView will pick them up)
        UserDefaults.standard.set(intervalSec, forKey: "intervalSec")
        UserDefaults.standard.set(restSec, forKey: "restSec")
        UserDefaults.standard.set(repeats, forKey: "repeats")

        // Trigger session start via NotificationCenter
        NotificationCenter.default.post(name: .startWorkoutSession, object: nil)

        print("[StartWorkoutIntent] Triggered workout: \(intervalSec)s/\(restSec)s x\(repeats)")

        return .result()
    }
}
