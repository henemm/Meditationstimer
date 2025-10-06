//
//  BreathPreset.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 27.09.25.
//

// MARK: - AI ORIENTATION (Read me first)
// Purpose:
//   BreathPreset defines the data model for structured breathing exercises in AtemView.
//   Represents four-phase breathing patterns: inhale → hold → exhale → hold.
//   Supports custom configurations and provides calculated properties for UI display.
//
// Data Model:
//   • Four timing phases: inhale, holdIn, exhale, holdOut (seconds)
//   • Repetitions: how many complete cycles to perform
//   • Metadata: name, emoji for user-friendly identification
//   • UUID for stable identity in SwiftUI lists
//
// Calculated Properties:
//   • totalDuration: complete session time in seconds
//   • formattedDuration: human-readable time string ("2:24 min")
//   • rhythmString: compact notation ("4-0-6-0")
//
// Usage in AtemView:
//   • SessionEngine iterates through phases with preset timings
//   • UI displays preset metadata and calculated durations
//   • Editor allows creating/modifying custom presets
//   • List view shows rhythm patterns and total times
//
// Default Presets (in AtemView):
//   • Box Breathing: 4-4-4-4 (equal timing)
//   • 4-7-8: Relaxation technique
//   • Simple patterns: 4-0-6-0, 7-0-5-0
//   • Rectangle: 6-3-6-3
//
// Extension Helpers:
//   • UI-specific computed properties for display formatting
//   • Maintains separation between data model and presentation

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
