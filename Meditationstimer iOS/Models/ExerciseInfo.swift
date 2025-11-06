//
//  ExerciseInfo.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 06.11.25.
//

import Foundation

/// Information about a workout exercise including instructions and effects
struct ExerciseInfo {
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

    init(name: String, category: ExerciseCategory, effect: String, instructions: String, notes: String? = nil) {
        self.name = name
        self.category = category
        self.effect = effect
        self.instructions = instructions
        self.notes = notes
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
