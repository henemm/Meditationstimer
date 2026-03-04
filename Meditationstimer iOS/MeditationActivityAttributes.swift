//
//  MeditationActivityAttributes.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 12.09.25.
//


import ActivityKit
import Foundation

/// Definiert die Attribute und den dynamischen Status einer Meditationstimer Live Activity.
struct MeditationAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Zeitpunkt, an dem die aktuell angezeigte Phase endet.
        /// Die UI zeigt daraus automatisch einen Live-Countdown (Text(..., style: .timer)).
    var endDate: Date
    /// Phase: 1 = Meditation, 2 = Besinnung
    var phase: Int
    /// Optional owner identifier (e.g. "AtemTab", "OffenTab") so widgets can render per-tab styles
    var ownerId: String?
    /// Zeigt an, ob die Aktivität pausiert ist
    var isPaused: Bool
    /// Optional: Ende des aktuellen Workout-Intervalls (Work/Rest).
    /// Wenn gesetzt, zeigt das Widget zwei Timer: Intervall-Countdown + Gesamt-Countdown.
    var phaseEndDate: Date?
    }

    /// Titel oder Bezeichnung der Aktivität
    var title: String
}
