//
//  BreathPreset.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 27.09.25.
//

import Foundation

/// Datenmodell für eine Atem-Übung
struct BreathPreset: Identifiable, Hashable {
    let id: UUID
    var name: String
    var emoji: String
    var inhale: Int      // Dauer Einatmen (Sekunden)
    var holdIn: Int      // Dauer Halten nach Einatmen
    var exhale: Int      // Dauer Ausatmen
    var holdOut: Int     // Dauer Halten nach Ausatmen
    var repetitions: Int

    init(id: UUID = UUID(),
         name: String,
         emoji: String,
         inhale: Int,
         holdIn: Int,
         exhale: Int,
         holdOut: Int,
         repetitions: Int) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.inhale = inhale
        self.holdIn = holdIn
        self.exhale = exhale
        self.holdOut = holdOut
        self.repetitions = repetitions
    }

    /// Gesamtdauer in Sekunden
    var totalDuration: Int {
        let cycle = inhale + holdIn + exhale + holdOut
        return cycle * repetitions
    }

    /// Gesamtdauer formatiert (z. B. "2:24 min")
    var formattedDuration: String {
        let minutes = totalDuration / 60
        let seconds = totalDuration % 60
        return String(format: "%d:%02d min", minutes, seconds)
    }
}

// MARK: - UI Helpers
extension BreathPreset {
    /// z.B. "4-0-6-0"
    var rhythmString: String { "\(inhale)-\(holdIn)-\(exhale)-\(holdOut)" }
    /// z.B. "2:24 min" (re-use formattedDuration)
    var totalDurationString: String { formattedDuration }
}
