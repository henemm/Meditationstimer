//
//  TrackerModels.swift
//  Meditationstimer
//
//  Created by Claude on 19.12.2025.
//  Updated: 25.12.2025 - Generic Tracker System components added
//
//  SwiftData models for Custom Trackers.
//  See openspec/specs/features/generic-tracker-system.md for full specification.
//

import Foundation
import SwiftData

// MARK: - Legacy Enums (for backward compatibility)

/// Type of tracker: positive habits or negative autopilots
enum TrackerType: String, Codable, CaseIterable {
    case good       // Positive habits to build
    case saboteur   // Negative autopilots to notice
}

/// How the tracker is used (legacy - will be replaced by TrackerValueType + SuccessCondition)
enum TrackingMode: String, Codable, CaseIterable {
    case counter     // +/- Buttons (e.g., glasses of water)
    case yesNo       // Single tap = done for today
    case awareness   // Saboteur: Log when noticed (streak = days aware)
    case avoidance   // Saboteur: Streak = days without logging
    case levels      // Custom levels with configurable streak effects
}

// MARK: - Generic Tracker System Components

/// Effect of a level on streak calculation
enum StreakEffect: String, Codable, Hashable {
    case success       // Day counts as successful, streak +1
    case needsGrace    // Requires reward/joker to continue streak
    case breaksStreak  // Immediately breaks streak, resets to 0
}

/// A single level for level-based trackers (2-5 levels per tracker)
struct TrackerLevel: Identifiable, Codable, Hashable {
    let id: Int                    // Sort order + HealthKit value
    let key: String                // Internal identifier ("steady", "easy")
    let icon: String               // Emoji or SF Symbol
    let labelKey: String           // Localization key
    let streakEffect: StreakEffect

    /// Localized display name
    var localizedLabel: String {
        NSLocalizedString(labelKey, comment: "Tracker level label")
    }
}

/// What value type is stored per log entry
enum TrackerValueType: Codable, Hashable {
    case boolean                    // Yes/No (yesNo, awareness modes)
    case integer(goal: Int?)        // Number with optional daily goal
    case levels([TrackerLevel])     // 2-5 predefined levels

    /// Validates that levels array has 2-5 entries
    var isValid: Bool {
        switch self {
        case .boolean, .integer:
            return true
        case .levels(let levels):
            return levels.count >= 2 && levels.count <= 5
        }
    }
}

/// When a day counts as "successful" for streak calculation
enum SuccessCondition: Codable, Hashable {
    case logExists              // At least 1 log present
    case logNotExists           // No log present (avoidance)
    case meetsGoal              // integer value >= dailyGoal
    case levelMatches([String]) // Logged level.key is in this list
}

/// Configuration for joker/reward system (optional)
struct RewardConfig: Codable, Hashable {
    let earnEveryDays: Int      // Earn 1 reward every X successful days
    let maxOnHand: Int          // Maximum rewards at once
    let canHealGrace: Bool      // Can heal needsGrace days

    /// Default NoAlc-style reward config
    static let noAlcDefault = RewardConfig(earnEveryDays: 7, maxOnHand: 3, canHealGrace: true)
}

/// Determines which calendar day a log belongs to
enum DayAssignment: Codable, Hashable {
    case timestamp                 // Log.timestamp determines day
    case cutoffHour(Int)           // Before hour X = previous day

    /// Calculates the assigned day for a given timestamp
    func assignedDay(for timestamp: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .timestamp:
            return calendar.startOfDay(for: timestamp)
        case .cutoffHour(let hour):
            let logHour = calendar.component(.hour, from: timestamp)
            let startOfDay = calendar.startOfDay(for: timestamp)
            if logHour < hour {
                return calendar.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay
            }
            return startOfDay
        }
    }
}

/// Where tracker data is stored
enum StorageStrategy: Codable, Hashable {
    case local                     // SwiftData only
    case healthKit(String)         // HealthKit only (with identifier)
    case both(String)              // SwiftData + HealthKit sync

    /// HealthKit type identifier if applicable
    var healthKitIdentifier: String? {
        switch self {
        case .local:
            return nil
        case .healthKit(let id), .both(let id):
            return id
        }
    }

    /// Whether to save to HealthKit
    var savesToHealthKit: Bool {
        switch self {
        case .local:
            return false
        case .healthKit, .both:
            return true
        }
    }
}

/// Result of a day's evaluation for streak calculation
enum DayOutcome {
    case success           // Day meets SuccessCondition
    case needsGrace        // Needs reward to save streak
    case breaksStreak      // Immediately breaks streak
    case noData            // No logs for this day
}

/// Result of streak calculation
struct StreakResult: Equatable {
    let currentStreak: Int       // Current streak length
    let longestStreak: Int       // All-time longest streak
    let availableRewards: Int    // Available jokers (0 if no reward system)
    let totalRewardsEarned: Int  // Total jokers earned
    let totalRewardsUsed: Int    // Total jokers consumed

    static let zero = StreakResult(currentStreak: 0, longestStreak: 0, availableRewards: 0, totalRewardsEarned: 0, totalRewardsUsed: 0)
}

// MARK: - Predefined Level Configurations

extension TrackerLevel {
    /// NoAlc consumption levels (for migration)
    static let noAlcLevels: [TrackerLevel] = [
        TrackerLevel(id: 0, key: "steady", icon: "💧", labelKey: "NoAlc.Steady", streakEffect: .success),
        TrackerLevel(id: 1, key: "easy", icon: "✨", labelKey: "NoAlc.Easy", streakEffect: .needsGrace),
        TrackerLevel(id: 2, key: "wild", icon: "💥", labelKey: "NoAlc.Wild", streakEffect: .needsGrace)
    ]

    /// Mood levels (5 levels, all count as success - logging is the exercise)
    static let moodLevels: [TrackerLevel] = [
        TrackerLevel(id: 1, key: "awful", icon: "😢", labelKey: "Awful", streakEffect: .success),
        TrackerLevel(id: 2, key: "bad", icon: "😕", labelKey: "Bad", streakEffect: .success),
        TrackerLevel(id: 3, key: "okay", icon: "😐", labelKey: "Okay", streakEffect: .success),
        TrackerLevel(id: 4, key: "good", icon: "🙂", labelKey: "Good", streakEffect: .success),
        TrackerLevel(id: 5, key: "great", icon: "😊", labelKey: "Great", streakEffect: .success)
    ]

    /// Energy levels (3 levels)
    static let energyLevels: [TrackerLevel] = [
        TrackerLevel(id: 1, key: "low", icon: "🔋", labelKey: "Low", streakEffect: .success),
        TrackerLevel(id: 2, key: "medium", icon: "⚡", labelKey: "Medium", streakEffect: .success),
        TrackerLevel(id: 3, key: "high", icon: "🔥", labelKey: "High", streakEffect: .success)
    ]
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
    var trackingMode: TrackingMode  // Legacy - use effectiveValueType/effectiveSuccessCondition
    var createdAt: Date
    var isActive: Bool

    // MARK: Legacy Settings
    var healthKitType: String?    // HealthKit identifier (nil if no mapping)
    var saveToHealthKit: Bool     // User toggle (default: true if healthKitType exists)
    var showInWidget: Bool        // Show in Tracker Widget
    var widgetOrder: Int          // Position in Widget (lower = higher priority)
    var dailyGoal: Int?           // Target for counter-based trackers
    var showInCalendar: Bool      // Show as Focus Tracker ring in calendar

    // MARK: Generic Tracker System (NEW - optional for backward compatibility)

    /// Custom levels for level-based trackers (stored as JSON Data)
    var levelsData: Data?

    /// Custom success condition (stored as JSON Data)
    var successConditionData: Data?

    /// Reward/Joker configuration (stored as JSON Data)
    var rewardConfigData: Data?

    /// Day assignment strategy (stored as raw value)
    var dayAssignmentRaw: String?

    /// Storage strategy (stored as raw value + identifier)
    var storageStrategyRaw: String?

    /// SmartReminder integration
    var supportsReminders: Bool = false
    var smartReminderID: UUID?
    var defaultLookbackHours: Int = 24

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
        showInCalendar: Bool = false,
        supportsReminders: Bool = false,
        smartReminderID: UUID? = nil,
        defaultLookbackHours: Int = 24
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
        self.supportsReminders = supportsReminders
        self.smartReminderID = smartReminderID
        self.defaultLookbackHours = defaultLookbackHours
    }

    // MARK: - Generic Tracker System Computed Properties

    /// Decoded levels (nil if not a level-based tracker)
    var levels: [TrackerLevel]? {
        get {
            guard let data = levelsData else { return nil }
            return try? JSONDecoder().decode([TrackerLevel].self, from: data)
        }
        set {
            levelsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Decoded reward config (nil if no reward system)
    var rewardConfig: RewardConfig? {
        get {
            guard let data = rewardConfigData else { return nil }
            return try? JSONDecoder().decode(RewardConfig.self, from: data)
        }
        set {
            rewardConfigData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Effective value type (from explicit config or derived from legacy trackingMode)
    var effectiveValueType: TrackerValueType {
        // If we have explicit levels, use them
        if let levels = levels {
            return .levels(levels)
        }
        // Otherwise derive from legacy trackingMode
        switch trackingMode {
        case .counter:
            return .integer(goal: dailyGoal)
        case .yesNo, .awareness, .avoidance:
            return .boolean
        case .levels:
            // If trackingMode is .levels but levels array is nil, use boolean as fallback
            return .boolean
        }
    }

    /// Effective success condition (from explicit config or derived from legacy trackingMode)
    var effectiveSuccessCondition: SuccessCondition {
        // If we have explicit levels with specific success keys
        if let levels = levels {
            let successKeys = levels.filter { $0.streakEffect == .success }.map { $0.key }
            if !successKeys.isEmpty {
                return .levelMatches(successKeys)
            }
        }
        // Otherwise derive from legacy trackingMode
        switch trackingMode {
        case .counter:
            return dailyGoal != nil ? .meetsGoal : .logExists
        case .yesNo, .awareness:
            return .logExists
        case .avoidance:
            return .logNotExists
        case .levels:
            // If trackingMode is .levels but no levels defined, use logExists as fallback
            return .logExists
        }
    }

    /// Effective day assignment (from explicit config or default)
    var effectiveDayAssignment: DayAssignment {
        guard let raw = dayAssignmentRaw else { return .timestamp }
        // Support both formats: "cutoffHour:18" (preset format) and "cutoff:18" (legacy)
        if raw.hasPrefix("cutoffHour:"), let hour = Int(raw.replacingOccurrences(of: "cutoffHour:", with: "")) {
            return .cutoffHour(hour)
        }
        if raw.hasPrefix("cutoff:"), let hour = Int(raw.replacingOccurrences(of: "cutoff:", with: "")) {
            return .cutoffHour(hour)
        }
        return .timestamp
    }

    /// Effective storage strategy (from explicit config or derived from healthKitType)
    var effectiveStorageStrategy: StorageStrategy {
        if let hkType = healthKitType {
            return saveToHealthKit ? .both(hkType) : .local
        }
        return .local
    }

    // MARK: - Configuration Helpers

    /// Configures this tracker with generic system settings
    func configureGeneric(
        levels: [TrackerLevel]? = nil,
        rewardConfig: RewardConfig? = nil,
        dayAssignment: DayAssignment = .timestamp,
        storageStrategy: StorageStrategy? = nil
    ) {
        self.levels = levels
        self.rewardConfig = rewardConfig

        switch dayAssignment {
        case .timestamp:
            self.dayAssignmentRaw = "timestamp"
        case .cutoffHour(let hour):
            self.dayAssignmentRaw = "cutoff:\(hour)"
        }

        if let strategy = storageStrategy {
            switch strategy {
            case .local:
                self.storageStrategyRaw = "local"
                self.healthKitType = nil
                self.saveToHealthKit = false
            case .healthKit(let id):
                self.storageStrategyRaw = "healthKit"
                self.healthKitType = id
                self.saveToHealthKit = true
            case .both(let id):
                self.storageStrategyRaw = "both"
                self.healthKitType = id
                self.saveToHealthKit = true
            }
        }
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

    // Generic Tracker System extensions
    let levels: [TrackerLevel]?
    let rewardConfig: RewardConfig?
    let dayAssignmentRaw: String?

    enum PresetCategory: String, CaseIterable {
        case awareness   // Stimmung, Gefühle, Dankbarkeit
        case activity    // Wasser
        case saboteur    // Doomscrolling, etc.
        case levelBased  // Level-basierte Tracker wie NoAlc
    }

    // Default initializer for legacy presets (without levels)
    init(
        name: String,
        localizedName: String,
        icon: String,
        type: TrackerType,
        trackingMode: TrackingMode,
        healthKitType: String?,
        dailyGoal: Int?,
        category: PresetCategory,
        levels: [TrackerLevel]? = nil,
        rewardConfig: RewardConfig? = nil,
        dayAssignmentRaw: String? = nil
    ) {
        self.name = name
        self.localizedName = localizedName
        self.icon = icon
        self.type = type
        self.trackingMode = trackingMode
        self.healthKitType = healthKitType
        self.dailyGoal = dailyGoal
        self.category = category
        self.levels = levels
        self.rewardConfig = rewardConfig
        self.dayAssignmentRaw = dayAssignmentRaw
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
            trackingMode: .levels,  // Level-based tracker with 5 mood levels
            healthKitType: "HKStateOfMind",
            dailyGoal: nil,
            category: .levelBased,
            levels: TrackerLevel.moodLevels,
            rewardConfig: nil,  // No rewards for mood tracking
            dayAssignmentRaw: nil  // Default: timestamp-based
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
        ),

        // Level-Based Trackers (Generic Tracker System)
        TrackerPreset(
            name: "NoAlc",
            localizedName: "NoAlc",
            icon: "🍷",
            type: .saboteur,
            trackingMode: .levels,  // Level-basierter Tracker
            healthKitType: "HKQuantityTypeIdentifierNumberOfAlcoholicBeverages",
            dailyGoal: nil,
            category: .levelBased,
            levels: TrackerLevel.noAlcLevels,
            rewardConfig: .noAlcDefault,
            dayAssignmentRaw: "cutoffHour:18"
        )
    ]

    /// Create a Tracker from this preset
    func createTracker() -> Tracker {
        let tracker = Tracker(
            name: name,
            icon: icon,
            type: type,
            trackingMode: trackingMode,
            healthKitType: healthKitType,
            saveToHealthKit: healthKitType != nil,
            dailyGoal: dailyGoal
        )

        // Generic Tracker System: Set levels, reward config, day assignment
        if let levels = levels {
            tracker.levels = levels
        }
        if let rewardConfig = rewardConfig {
            tracker.rewardConfig = rewardConfig
        }
        if let dayAssignmentRaw = dayAssignmentRaw {
            tracker.dayAssignmentRaw = dayAssignmentRaw
        }

        return tracker
    }
}

// MARK: - Streak Calculator

/// Universal streak calculator for all tracker types.
/// Uses forward iteration (past → present) for correct reward handling.
final class StreakCalculator {

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Calculates streak for a tracker with the given configuration
    func calculate(
        logs: [TrackerLog],
        valueType: TrackerValueType,
        successCondition: SuccessCondition,
        dayAssignment: DayAssignment,
        rewardConfig: RewardConfig?
    ) -> StreakResult {
        let today = calendar.startOfDay(for: Date())

        // Group logs by assigned day
        let logsByDay = groupLogsByDay(logs: logs, dayAssignment: dayAssignment)

        // No logs → no streak
        guard let firstDate = logsByDay.keys.min() else {
            return .zero
        }

        // End date: today if logged, OR for avoidance trackers (no log = success)
        let hasLogToday = logsByDay[today] != nil
        let isAvoidance = successCondition == .logNotExists
        let endDate = (hasLogToday || isAvoidance) ? today : calendar.date(byAdding: .day, value: -1, to: today) ?? today

        guard firstDate <= endDate else {
            return .zero
        }

        var currentStreak = 0
        var longestStreak = 0
        var earnedRewards = 0
        var usedRewards = 0

        // Forward iteration: first log → end date
        var checkDate = firstDate
        while checkDate <= endDate {
            let dayLogs = logsByDay[checkDate] ?? []
            let outcome = evaluateDayOutcome(logs: dayLogs, valueType: valueType, successCondition: successCondition)

            switch outcome {
            case .success:
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
                earnedRewards += checkRewardMilestone(streak: currentStreak, config: rewardConfig, earned: earnedRewards, used: usedRewards)

            case .needsGrace:
                // Earn before consume rule
                let wouldBeMilestone = rewardConfig.map { (currentStreak + 1) % $0.earnEveryDays == 0 } ?? false
                if wouldBeMilestone, let config = rewardConfig, (earnedRewards - usedRewards) < config.maxOnHand {
                    earnedRewards += 1
                }

                let availableRewards = earnedRewards - usedRewards
                if availableRewards > 0 && (rewardConfig?.canHealGrace ?? false) {
                    usedRewards += 1
                    currentStreak += 1
                    longestStreak = max(longestStreak, currentStreak)
                } else {
                    currentStreak = 0
                    earnedRewards = 0
                    usedRewards = 0
                }

            case .breaksStreak:
                currentStreak = 0
                earnedRewards = 0
                usedRewards = 0

            case .noData:
                handleNoData(successCondition: successCondition, rewardConfig: rewardConfig,
                           currentStreak: &currentStreak, longestStreak: &longestStreak,
                           earnedRewards: &earnedRewards, usedRewards: &usedRewards)
            }

            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate
        }

        return StreakResult(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            availableRewards: max(0, earnedRewards - usedRewards),
            totalRewardsEarned: earnedRewards,
            totalRewardsUsed: usedRewards
        )
    }

    private func groupLogsByDay(logs: [TrackerLog], dayAssignment: DayAssignment) -> [Date: [TrackerLog]] {
        var result: [Date: [TrackerLog]] = [:]
        for log in logs {
            let day = dayAssignment.assignedDay(for: log.timestamp, calendar: calendar)
            result[day, default: []].append(log)
        }
        return result
    }

    private func evaluateDayOutcome(logs: [TrackerLog], valueType: TrackerValueType, successCondition: SuccessCondition) -> DayOutcome {
        switch successCondition {
        case .logExists:
            return logs.isEmpty ? .noData : .success
        case .logNotExists:
            return logs.isEmpty ? .success : .breaksStreak
        case .meetsGoal:
            guard case .integer(let goal) = valueType, let goal = goal else {
                return logs.isEmpty ? .noData : .success
            }
            let total = logs.compactMap { $0.value }.reduce(0, +)
            return total >= goal ? .success : .noData
        case .levelMatches:
            guard case .levels(let levels) = valueType,
                  let lastLog = logs.last, let levelId = lastLog.value,
                  let level = levels.first(where: { $0.id == levelId }) else {
                return .noData
            }
            switch level.streakEffect {
            case .success: return .success
            case .needsGrace: return .needsGrace
            case .breaksStreak: return .breaksStreak
            }
        }
    }

    private func handleNoData(successCondition: SuccessCondition, rewardConfig: RewardConfig?,
                              currentStreak: inout Int, longestStreak: inout Int,
                              earnedRewards: inout Int, usedRewards: inout Int) {
        if successCondition == .logNotExists {
            currentStreak += 1
            longestStreak = max(longestStreak, currentStreak)
            earnedRewards += checkRewardMilestone(streak: currentStreak, config: rewardConfig, earned: earnedRewards, used: usedRewards)
            return
        }

        if let config = rewardConfig {
            let availableRewards = earnedRewards - usedRewards
            if availableRewards > 0 && config.canHealGrace {
                usedRewards += 1
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                currentStreak = 0
                earnedRewards = 0
                usedRewards = 0
            }
        }
    }

    private func checkRewardMilestone(streak: Int, config: RewardConfig?, earned: Int, used: Int) -> Int {
        guard let config = config, streak > 0, streak % config.earnEveryDays == 0, (earned - used) < config.maxOnHand else {
            return 0
        }
        return 1
    }
}

// MARK: - TrackerMigration

/// Migration service for transitioning from NoAlcManager to Generic Tracker System
final class TrackerMigration {

    // MARK: - Singleton

    static let shared = TrackerMigration()

    private init() {}

    // MARK: - NoAlc Migration

    /// Migrates existing NoAlc data from HealthKit to Tracker system
    /// - Parameter context: SwiftData ModelContext to insert Tracker and TrackerLogs
    /// - Throws: HealthKit or SwiftData errors
    ///
    /// This migration is idempotent - it checks if NoAlc Tracker already exists
    /// and skips migration if found.
    func migrateNoAlcIfNeeded(context: ModelContext) async throws {
        // Check if NoAlc Tracker already exists
        let descriptor = FetchDescriptor<Tracker>(
            predicate: #Predicate { $0.name == "NoAlc" }
        )

        if let _ = try context.fetch(descriptor).first {
            print("[TrackerMigration] NoAlc Tracker already exists, skipping migration")
            return
        }

        print("[TrackerMigration] Starting NoAlc migration...")

        // Create NoAlc Tracker from preset
        guard let noAlcPreset = TrackerPreset.all.first(where: { $0.name == "NoAlc" }) else {
            print("[TrackerMigration] ERROR: NoAlc preset not found in TrackerPreset.all")
            return
        }

        let tracker = noAlcPreset.createTracker()
        context.insert(tracker)

        // TODO: Fetch historical NoAlc data from HealthKit and create TrackerLogs
        // For now, we just create the tracker structure
        // Future implementation: NoAlcManager.shared.fetchHistoricalData()

        try context.save()
        print("[TrackerMigration] NoAlc Tracker created successfully")
    }

    // MARK: - Default Trackers

    /// Creates default trackers (NoAlc + Mood) if no trackers exist
    /// - Parameter context: SwiftData ModelContext
    /// - Throws: SwiftData errors
    func createDefaultTrackersIfNeeded(context: ModelContext) throws {
        // Check if any trackers exist
        let descriptor = FetchDescriptor<Tracker>()
        let existingCount = try context.fetchCount(descriptor)

        if existingCount > 0 {
            print("[TrackerMigration] Trackers already exist (\(existingCount)), skipping default creation")
            return
        }

        print("[TrackerMigration] Creating default trackers (NoAlc + Mood)...")

        // Create NoAlc tracker
        if let noAlcPreset = TrackerPreset.all.first(where: { $0.name == "NoAlc" }) {
            let noAlc = noAlcPreset.createTracker()
            context.insert(noAlc)
            print("[TrackerMigration] ✓ NoAlc tracker created")
        }

        // Create Mood tracker
        if let moodPreset = TrackerPreset.all.first(where: { $0.name == "Mood" }) {
            let mood = moodPreset.createTracker()
            context.insert(mood)
            print("[TrackerMigration] ✓ Mood tracker created")
        }

        try context.save()
        print("[TrackerMigration] Default trackers created successfully")
    }
}
