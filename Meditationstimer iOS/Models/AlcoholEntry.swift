//
//  AlcoholEntry.swift
//  Meditationstimer iOS
//
//  Created by Claude Code on 30.10.25.
//

// MARK: - AI ORIENTATION (Read me first)
// Purpose:
//   AlcoholEntry represents a single day's alcohol consumption record.
//   Integrated with HealthKit for data persistence and supports NoAlk streak tracking.
//
// Features:
//   • Daily consumption tracking (number of standard drinks)
//   • Three-level color coding (low/medium/high)
//   • NoAlk streak eligibility (0-1 drinks)
//   • Optional notes for context
//   • HealthKit integration via HKCategoryType.alcoholConsumption
//
// Integration Points:
//   • AlcoholManager: Manages entries and HealthKit sync
//   • StreakManager: Calculates NoAlk streaks (0-1 drinks = eligible)
//   • CalendarView: Displays green color indicators
//   • AlcoholLogPopover: User input for logging consumption
//
// Data Model:
//   • date: Start of day (normalized to 00:00:00)
//   • drinks: Number of standard drinks (1 drink = 14g pure alcohol)
//   • note: Optional context (e.g., "Geburtstag", "Business Dinner")
//   • id: UUID for SwiftUI list management
//
// Color Levels:
//   • Low (0-1): Deep green - NoAlk streak eligible
//   • Medium (2-6): Medium green - Moderate consumption
//   • High (7+): Light green - Heavy consumption
//
// Technical Notes:
//   • Always uses startOfDay for date normalization (prevents duplicates)
//   • Codable for UserDefaults/CoreData persistence
//   • Equatable for SwiftUI change detection

import Foundation

/// Represents a single day's alcohol consumption record
public struct AlcoholEntry: Identifiable, Codable, Equatable {
    public let id: UUID
    public var date: Date  // Start of day (normalized to 00:00:00)
    public var drinks: Int  // Number of standard drinks
    public var note: String?  // Optional context note

    public init(id: UUID = UUID(), date: Date = Date(), drinks: Int = 0, note: String? = nil) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.drinks = max(0, drinks)  // Prevent negative drinks
        self.note = note
    }

    /// Color level based on drinks count
    public var colorLevel: AlcoholColorLevel {
        switch drinks {
        case 0...1:
            return .low
        case 2...6:
            return .medium
        default:
            return .high
        }
    }

    /// Whether this entry is eligible for NoAlk streak (0-1 drinks)
    public var isNoAlkEligible: Bool {
        drinks <= 1
    }

    /// Display summary for UI
    public var summary: String {
        let drinkText = drinks == 1 ? "1 Drink" : "\(drinks) Drinks"
        if let note = note, !note.isEmpty {
            return "\(drinkText) · \(note)"
        }
        return drinkText
    }
}

/// Color level classification for alcohol consumption
public enum AlcoholColorLevel: String, Codable {
    case low    // 0-1 drinks (deep green - NoAlk eligible)
    case medium // 2-6 drinks (medium green - moderate)
    case high   // 7+ drinks (light green - heavy)

    /// Display name for UI
    public var displayName: String {
        switch self {
        case .low: return "Niedrig"
        case .medium: return "Moderat"
        case .high: return "Hoch"
        }
    }
}
