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
        BreathingPresetEntity(id: "Box 4-4-4-4"),
        BreathingPresetEntity(id: "4-0-6-0"),
        BreathingPresetEntity(id: "Coherent 5-0-5-0"),
        BreathingPresetEntity(id: "7-0-5-0"),
        BreathingPresetEntity(id: "4-7-8"),
        BreathingPresetEntity(id: "Rectangle 6-3-6-3")
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
