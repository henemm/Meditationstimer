//
//  TrackerModels.swift
//  Meditationstimer
//
//  Created by Claude on 19.12.2025.
//
//  SwiftData models for Custom Trackers.
//  See openspec/specs/features/trackers.md for full specification.
//

import Foundation
import SwiftData

// MARK: - Enums

/// Type of tracker: positive habits or negative autopilots
enum TrackerType: String, Codable, CaseIterable {
    case good       // Positive habits to build
    case saboteur   // Negative autopilots to notice
}

/// How the tracker is used
enum TrackingMode: String, Codable, CaseIterable {
    case counter     // +/- Buttons (e.g., glasses of water)
    case yesNo       // Single tap = done for today
    case awareness   // Saboteur: Log when noticed (streak = days aware)
    case avoidance   // Saboteur: Streak = days without logging
}

// MARK: - Tracker Model

/// A custom tracker defined by the user
@Model
final class Tracker {
    // MARK: Core Properties
    var id: UUID
    var name: String
    var icon: String  // SF Symbol name or Emoji
    var type: TrackerType
    var trackingMode: TrackingMode
    var createdAt: Date
    var isActive: Bool

    // MARK: Optional Settings
    var healthKitType: String?    // HealthKit identifier (nil if no mapping)
    var saveToHealthKit: Bool     // User toggle (default: true if healthKitType exists)
    var showInWidget: Bool        // Show in Tracker Widget
    var widgetOrder: Int          // Position in Widget (lower = higher priority)
    var dailyGoal: Int?           // Target for counter-based trackers
    var showInCalendar: Bool      // Show as Focus Tracker ring in calendar

    // MARK: Relationships
    @Relationship(deleteRule: .cascade, inverse: \TrackerLog.tracker)
    var logs: [TrackerLog] = []

    // MARK: Initializer
    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        type: TrackerType,
        trackingMode: TrackingMode,
        createdAt: Date = Date(),
        isActive: Bool = true,
        healthKitType: String? = nil,
        saveToHealthKit: Bool = false,
        showInWidget: Bool = false,
        widgetOrder: Int = 999,
        dailyGoal: Int? = nil,
        showInCalendar: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.type = type
        self.trackingMode = trackingMode
        self.createdAt = createdAt
        self.isActive = isActive
        self.healthKitType = healthKitType
        self.saveToHealthKit = saveToHealthKit
        self.showInWidget = showInWidget
        self.widgetOrder = widgetOrder
        self.dailyGoal = dailyGoal
        self.showInCalendar = showInCalendar
    }
}

// MARK: - TrackerLog Model

/// A single log entry for a tracker
@Model
final class TrackerLog {
    // MARK: Core Properties
    var id: UUID
    var timestamp: Date

    // MARK: Optional Data
    var value: Int?        // For counter-based trackers
    var note: String?      // Free text (e.g., gratitude entry)
    var trigger: String?   // For saboteur trackers (what triggered the behavior)
    var location: String?  // Optional: Home, Work, On the go
    var syncedToHealthKit: Bool  // Track if successfully synced

    // MARK: Relationship
    var tracker: Tracker?

    // MARK: Initializer
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        value: Int? = nil,
        note: String? = nil,
        trigger: String? = nil,
        location: String? = nil,
        syncedToHealthKit: Bool = false,
        tracker: Tracker? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.value = value
        self.note = note
        self.trigger = trigger
        self.location = location
        self.syncedToHealthKit = syncedToHealthKit
        self.tracker = tracker
    }
}

// MARK: - Tracker Presets

/// Predefined tracker templates for easy setup
struct TrackerPreset: Identifiable {
    let id = UUID()
    let name: String
    let localizedName: String  // DE translation
    let icon: String
    let type: TrackerType
    let trackingMode: TrackingMode
    let healthKitType: String?
    let dailyGoal: Int?
    let category: PresetCategory

    enum PresetCategory: String, CaseIterable {
        case awareness   // Stimmung, Gefühle, Dankbarkeit
        case activity    // Wasser
        case saboteur    // Doomscrolling, etc.
    }
}

extension TrackerPreset {
    /// All predefined presets
    static let all: [TrackerPreset] = [
        // Awareness Trackers (Logging = The Exercise)
        TrackerPreset(
            name: "Mood",
            localizedName: "Stimmung",
            icon: "😊",
            type: .good,
            trackingMode: .awareness,  // Fixed: must be .awareness to show Notice button & open MoodSelectionView
            healthKitType: "HKStateOfMind",
            dailyGoal: nil,
            category: .awareness
        ),
        TrackerPreset(
            name: "Feelings",
            localizedName: "Gefühle",
            icon: "💭",
            type: .good,
            trackingMode: .awareness,  // Fixed: must be .awareness to show Notice button & open FeelingsSelectionView
            healthKitType: "HKStateOfMind",
            dailyGoal: nil,
            category: .awareness
        ),
        TrackerPreset(
            name: "Gratitude",
            localizedName: "Dankbarkeit",
            icon: "🙏",
            type: .good,
            trackingMode: .awareness,  // Fixed: must be .awareness to show Notice button & open GratitudeLogView
            healthKitType: nil,
            dailyGoal: nil,
            category: .awareness
        ),

        // Activity Trackers (Logging = Documentation)
        TrackerPreset(
            name: "Drink Water",
            localizedName: "Wasser trinken",
            icon: "💧",
            type: .good,
            trackingMode: .counter,
            healthKitType: "HKQuantityTypeIdentifierDietaryWater",
            dailyGoal: 8,
            category: .activity
        ),

        // Saboteur Trackers (Awareness Mode)
        TrackerPreset(
            name: "Doomscrolling",
            localizedName: "Doomscrolling",
            icon: "📱",
            type: .saboteur,
            trackingMode: .awareness,
            healthKitType: nil,
            dailyGoal: nil,
            category: .saboteur
        ),
        TrackerPreset(
            name: "Snacking",
            localizedName: "Snacking",
            icon: "🍫",
            type: .saboteur,
            trackingMode: .awareness,
            healthKitType: nil,
            dailyGoal: nil,
            category: .saboteur
        ),
        TrackerPreset(
            name: "Procrastination",
            localizedName: "Prokrastination",
            icon: "🛋️",
            type: .saboteur,
            trackingMode: .awareness,
            healthKitType: nil,
            dailyGoal: nil,
            category: .saboteur
        ),
        TrackerPreset(
            name: "Rumination",
            localizedName: "Grübeln",
            icon: "🌀",
            type: .saboteur,
            trackingMode: .awareness,
            healthKitType: nil,
            dailyGoal: nil,
            category: .saboteur
        ),
        TrackerPreset(
            name: "Phone During Conversations",
            localizedName: "Handy im Gespräch",
            icon: "📵",
            type: .saboteur,
            trackingMode: .awareness,
            healthKitType: nil,
            dailyGoal: nil,
            category: .saboteur
        )
    ]

    /// Create a Tracker from this preset
    func createTracker() -> Tracker {
        Tracker(
            name: name,
            icon: icon,
            type: type,
            trackingMode: trackingMode,
            healthKitType: healthKitType,
            saveToHealthKit: healthKitType != nil,
            dailyGoal: dailyGoal
        )
    }
}
