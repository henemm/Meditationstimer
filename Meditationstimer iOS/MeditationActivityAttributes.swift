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
    }

    /// Titel oder Bezeichnung der Aktivität
    var title: String
}
