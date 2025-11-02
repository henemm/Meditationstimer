//
//  ShortcutModels.swift
//  Lean Health Timer
//
//  Shared models and enums for App Intents.
//

import Foundation
import AppIntents

// MARK: - Breathing Preset Entity
struct BreathingPresetEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Atem-Preset"
    static var defaultQuery = BreathingPresetQuery()

    var id: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)")
    }

    static let allPresets: [BreathingPresetEntity] = [
        BreathingPresetEntity(id: "Box Breathing"),
        BreathingPresetEntity(id: "Calming Breath"),
        BreathingPresetEntity(id: "Coherent Breathing"),
        BreathingPresetEntity(id: "Deep Calm"),
        BreathingPresetEntity(id: "Relaxing Breath"),
        BreathingPresetEntity(id: "Rhythmic Breath")
    ]
}

// MARK: - Breathing Preset Query
struct BreathingPresetQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [BreathingPresetEntity] {
        BreathingPresetEntity.allPresets.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [BreathingPresetEntity] {
        BreathingPresetEntity.allPresets
    }
}
