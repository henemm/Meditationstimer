//
//  ExerciseInfo.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 06.11.25.
//

import Foundation

/// Information about a workout exercise including instructions and effects
struct ExerciseInfo {
    /// Fixed catalog identifier, e.g. "builtin.planke" (see Contracts/catalog/builtin-exercises.json)
    let id: String

    /// Display name of the exercise (matches WorkoutPhase.name)
    let name: String

    /// Category for grouping exercises
    let category: ExerciseCategory

    /// What muscles/tendons are trained or stretched
    let effect: String

    /// How to perform the exercise and what to watch out for
    let instructions: String

    /// Optional additional notes or variations
    let notes: String?

    /// Origin derived from the id prefix (builtin/own/claude); not stored
    var origin: ExerciseOrigin {
        ExerciseOrigin(exerciseId: id) ?? .own
    }

    init(id: String, name: String, category: ExerciseCategory, effect: String, instructions: String, notes: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.effect = effect
        self.instructions = instructions
        self.notes = notes
    }
}

/// Origin of an exercise, derived from the prefix of its id (`builtin.*`, `own.*`, `claude.*`)
enum ExerciseOrigin: String {
    case builtin, own, claude

    /// Prefix before the first dot; nil if there is no dot or the prefix is unknown
    init?(exerciseId: String) {
        guard let dot = exerciseId.firstIndex(of: ".") else { return nil }
        self.init(rawValue: String(exerciseId[..<dot]))
    }
}

/// Categories for grouping exercises
enum ExerciseCategory: String, CaseIterable {
    case strength = "Kraft"
    case stretching = "Dehnung"
    case core = "Core"
    case cardio = "Cardio"
    case legs = "Beine"
    case upperBody = "Oberkörper"
    case fullBody = "Ganzkörper"
    case warmup = "Aufwärmen"
    case cooldown = "Cool-Down"

    var emoji: String {
        switch self {
        case .strength: return "💪"
        case .stretching: return "🧘‍♂️"
        case .core: return "🎯"
        case .cardio: return "❤️"
        case .legs: return "🦵"
        case .upperBody: return "💪"
        case .fullBody: return "🏃"
        case .warmup: return "🔥"
        case .cooldown: return "❄️"
        }
    }
}
