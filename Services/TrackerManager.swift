//
//  TrackerManager.swift
//  Meditationstimer
//
//  Created by Claude on 19.12.2025.
//
//  Manager for Custom Trackers - CRUD operations, queries, and preset handling.
//

import Foundation
import SwiftData
import HealthKit

/// Manages Custom Trackers and their logs
final class TrackerManager {
    static let shared = TrackerManager()

    private let calendar = Calendar.current
    private let healthStore = HKHealthStore()

    private init() {}

    // MARK: - CRUD Operations

    /// Create a new tracker
    func createTracker(_ tracker: Tracker, in context: ModelContext) {
        context.insert(tracker)
    }

    /// Delete a tracker (cascade deletes logs)
    func deleteTracker(_ tracker: Tracker, from context: ModelContext) {
        context.delete(tracker)
    }

    /// Create a tracker from a preset
    func createFromPreset(_ preset: TrackerPreset, in context: ModelContext) -> Tracker {
        let tracker = preset.createTracker()
        context.insert(tracker)
        return tracker
    }

    // MARK: - Logging

    /// Log an entry for a tracker
    /// - Parameters:
    ///   - tracker: The tracker to log for
    ///   - value: Optional value (for counter/level trackers)
    ///   - note: Optional note text
    ///   - trigger: Optional trigger description (for saboteur trackers)
    ///   - location: Optional location
    ///   - timestamp: The timestamp for the log (defaults to now)
    ///   - context: The ModelContext to insert into
    /// - Parameter dayAssignmentOverride: When set, overrides the tracker's dayAssignment for HealthKit.
    ///   Use `.timestamp` when the user explicitly picks a date from a calendar picker,
    ///   so the cutoffHour logic doesn't shift the chosen date.
    func logEntry(
        for tracker: Tracker,
        value: Int? = nil,
        note: String? = nil,
        trigger: String? = nil,
        location: String? = nil,
        timestamp: Date = Date(),
        dayAssignmentOverride: DayAssignment? = nil,
        in context: ModelContext
    ) -> TrackerLog {
        let log = TrackerLog(
            timestamp: timestamp,
            value: value,
            note: note,
            trigger: trigger,
            location: location,
            tracker: tracker
        )
        context.insert(log)
        tracker.logs.append(log)

        // HealthKit-Write (async, fire-and-forget)
        // Resolve all values on MainActor BEFORE Task boundary to avoid SwiftData actor-isolation issues
        if tracker.saveToHealthKit, let logValue = value {
            let hkValue = resolveHealthKitValue(for: tracker, levelId: logValue)
            let hkTypeId = tracker.healthKitType
            let trackerName = tracker.name
            let dayAssignment = dayAssignmentOverride ?? tracker.effectiveDayAssignment

            Task {
                await saveToHealthKitDirect(hkTypeId: hkTypeId, hkValue: hkValue, date: log.timestamp, dayAssignment: dayAssignment, trackerName: trackerName)
            }
        }

        // Cancel matching Smart Reminders for this tracker (Reverse Smart Reminders)
        #if os(iOS)
        SmartReminderEngine.shared.cancelMatchingTrackerReminders(for: tracker.id, completedAt: log.timestamp)
        // Also cancel old-style NoAlc reminders that use activityType instead of trackerID
        if tracker.healthKitType == HKQuantityTypeIdentifier.numberOfAlcoholicBeverages.rawValue {
            SmartReminderEngine.shared.cancelMatchingReminders(for: .noalc, completedAt: log.timestamp)
        }
        #endif

        return log
    }

    // MARK: - HealthKit Integration

    /// Resolves the HealthKit value for a tracker level.
    /// For level-based trackers, maps level.id to level.healthKitValue (e.g., wild id=2 → drink count 6).
    /// For non-level trackers, returns the value as-is (fallback).
    ///
    /// IMPORTANT: Call this on MainActor where tracker.levels is accessible via SwiftData.
    func resolveHealthKitValue(for tracker: Tracker, levelId: Int) -> Int {
        if let levels = tracker.levels,
           let level = levels.first(where: { $0.id == levelId }) {
            return level.healthKitValue
        }
        return levelId
    }

    /// Saves a resolved HealthKit value. Only accepts primitive types (no @Model objects)
    /// to avoid SwiftData actor-isolation issues across Task boundaries.
    private func saveToHealthKitDirect(
        hkTypeId: String?,
        hkValue: Int,
        date: Date,
        dayAssignment: DayAssignment,
        trackerName: String
    ) async {
        guard let hkTypeId,
              let hkType = HKQuantityType.quantityType(
                  forIdentifier: HKQuantityTypeIdentifier(rawValue: hkTypeId)
              ) else { return }

        let authStatus = healthStore.authorizationStatus(for: hkType)
        guard authStatus == .sharingAuthorized else {
            print("[TrackerManager] HealthKit not authorized for \(trackerName), skipping save")
            return
        }

        do {
            let quantity = HKQuantity(unit: .count(), doubleValue: Double(hkValue))
            let assignedDay = dayAssignment.assignedDay(for: date, calendar: calendar)

            // Delete existing entries for the same day (last entry wins)
            // Separate do/catch so delete failure never blocks the save
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: assignedDay)!
            let dayPredicate = HKQuery.predicateForSamples(withStart: assignedDay, end: endOfDay, options: .strictStartDate)
            do {
                try await healthStore.deleteObjects(of: hkType, predicate: dayPredicate)
            } catch {
                print("[TrackerManager] HealthKit delete failed (continuing with save): \(error)")
            }

            let sample = HKQuantitySample(type: hkType, quantity: quantity, start: assignedDay, end: assignedDay)
            try await healthStore.save(sample)
            print("[TrackerManager] HealthKit save succeeded: \(hkValue) for \(trackerName)")
        } catch {
            print("[TrackerManager] HealthKit save failed: \(error)")
        }
    }

    /// Quick log (for counter +1 or yesNo)
    func quickLog(for tracker: Tracker, in context: ModelContext) -> TrackerLog {
        switch tracker.trackingMode {
        case .counter:
            // Increment counter by 1
            let todayTotal = todayTotal(for: tracker, in: context)
            return logEntry(for: tracker, value: todayTotal + 1, in: context)
        case .yesNo, .awareness:
            // Just log the moment
            return logEntry(for: tracker, in: context)
        case .avoidance:
            // Log = relapse (breaks streak)
            return logEntry(for: tracker, in: context)
        case .levels:
            // For levels, user should use LevelSelectionView; this is fallback
            return logEntry(for: tracker, in: context)
        }
    }

    // MARK: - Queries

    /// Get all logs for a tracker on a specific date
    func logs(for tracker: Tracker, on date: Date, in context: ModelContext) -> [TrackerLog] {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return tracker.logs.filter { log in
            log.timestamp >= startOfDay && log.timestamp < endOfDay
        }
    }

    /// Get all logs for today
    func todayLogs(for tracker: Tracker, in context: ModelContext) -> [TrackerLog] {
        return logs(for: tracker, on: Date(), in: context)
    }

    /// Get total value for today (for counter trackers)
    func todayTotal(for tracker: Tracker, in context: ModelContext) -> Int {
        let logs = todayLogs(for: tracker, in: context)
        return logs.compactMap { $0.value }.reduce(0, +)
    }

    /// Check if tracker was logged today
    func isLoggedToday(for tracker: Tracker, in context: ModelContext) -> Bool {
        return !todayLogs(for: tracker, in: context).isEmpty
    }

    // MARK: - Streak Calculation

    /// Calculate current streak for a tracker (legacy method - returns Int only)
    func streak(for tracker: Tracker, in context: ModelContext) -> Int {
        return calculateStreakResult(for: tracker).currentStreak
    }

    /// Calculate full streak result using the generic StreakCalculator
    /// Returns streak, rewards, and other metrics
    func calculateStreakResult(for tracker: Tracker) -> StreakResult {
        let calculator = StreakCalculator(calendar: calendar)

        return calculator.calculate(
            logs: tracker.logs,
            valueType: tracker.effectiveValueType,
            successCondition: tracker.effectiveSuccessCondition,
            dayAssignment: tracker.effectiveDayAssignment,
            rewardConfig: tracker.rewardConfig
        )
    }

    /// Calculate streak for trackers where logging = activity (counter, yesNo, awareness)
    /// Streak = consecutive days with at least 1 log
    /// @available(*, deprecated, message: "Use calculateStreakResult instead")
    private func calculateActiveStreak(for tracker: Tracker) -> Int {
        let today = calendar.startOfDay(for: Date())
        let todayHasLog = tracker.logs.contains { log in
            calendar.isDate(log.timestamp, inSameDayAs: today)
        }

        var currentStreak = 0
        var checkDate = todayHasLog ? today : calendar.date(byAdding: .day, value: -1, to: today)!

        while true {
            let hasLogOnDate = tracker.logs.contains { log in
                calendar.isDate(log.timestamp, inSameDayAs: checkDate)
            }

            if hasLogOnDate {
                currentStreak += 1
                guard let previousDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = previousDate
            } else {
                break
            }
        }

        return currentStreak
    }

    /// Calculate streak for avoidance trackers
    /// Streak = consecutive days WITHOUT any log
    /// @available(*, deprecated, message: "Use calculateStreakResult instead")
    private func calculateAvoidanceStreak(for tracker: Tracker) -> Int {
        let today = calendar.startOfDay(for: Date())

        // Find the most recent log
        let sortedLogs = tracker.logs.sorted { $0.timestamp > $1.timestamp }
        guard let lastLog = sortedLogs.first else {
            // No logs ever = streak from tracker creation date
            let daysSinceCreation = calendar.dateComponents([.day], from: tracker.createdAt, to: today).day ?? 0
            return max(0, daysSinceCreation)
        }

        // Streak = days since last log
        let lastLogDate = calendar.startOfDay(for: lastLog.timestamp)
        let daysSinceLastLog = calendar.dateComponents([.day], from: lastLogDate, to: today).day ?? 0
        return max(0, daysSinceLastLog)
    }

    // MARK: - Notification Action Mapping

    /// Maps a notification action identifier to a NoAlc level ID.
    /// Returns nil for unknown actions.
    static func levelIdForNotificationAction(_ actionIdentifier: String) -> Int? {
        switch actionIdentifier {
        case "NOALC_STEADY": return 0
        case "NOALC_EASY":   return 1
        case "NOALC_WILD":   return 2
        default: return nil
        }
    }

    // MARK: - Preset Access

    /// Get all predefined presets
    static func predefinedPresets() -> [TrackerPreset] {
        return TrackerPreset.all
    }

    /// Get presets by category
    static func presets(for category: TrackerPreset.PresetCategory) -> [TrackerPreset] {
        return TrackerPreset.all.filter { $0.category == category }
    }

    // MARK: - HealthKit NoAlc Queries (for backward compatibility during migration)

    /// Fetches NoAlc level from HealthKit for a specific day.
    /// Sums ALL entries for the day and maps the total to the highest matching level.
    /// With delete-before-write there should only be one entry per day;
    /// the sum is a safe fallback if the delete ever fails.
    func fetchNoAlcLevelFromHealthKit(for date: Date) async -> TrackerLevel? {
        guard let alcoholType = HKQuantityType.quantityType(forIdentifier: .numberOfAlcoholicBeverages) else {
            return nil
        }

        let targetDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: targetDay)!

        let predicate = HKQuery.predicateForSamples(withStart: targetDay, end: endOfDay, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: alcoholType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if error != nil {
                    continuation.resume(returning: nil)
                    return
                }

                guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                // Sum all entries for the day (multiple logs = total drink count)
                let total = quantitySamples.reduce(0) { $0 + Int($1.quantity.doubleValue(for: .count())) }

                // Map total to highest matching level (steady=0, easy=4, wild=6+)
                let level = TrackerLevel.noAlcLevels
                    .sorted { $0.healthKitValue > $1.healthKitValue }
                    .first { $0.healthKitValue <= total }
                    ?? TrackerLevel.noAlcLevels.first { $0.key == "steady" }
                continuation.resume(returning: level)
            }

            healthStore.execute(query)
        }
    }

    /// Calculates NoAlc streak from HealthKit data.
    /// Uses forward iteration with Joker system (earn every 7 days, max 3).
    ///
    /// - Parameter alcoholDays: Dictionary of dates to TrackerLevel
    /// - Returns: StreakResult with current streak and available rewards
    static func calculateNoAlcStreakFromHealthKit(
        alcoholDays: [Date: TrackerLevel],
        calendar: Calendar = .current
    ) -> StreakResult {
        let today = calendar.startOfDay(for: Date())

        guard let firstDate = alcoholDays.keys.min() else {
            return .zero
        }

        // End date: today if logged, otherwise yesterday (don't penalize for not logging today)
        let hasEntryToday = alcoholDays[today] != nil
        let endDate = hasEntryToday ? today : calendar.date(byAdding: .day, value: -1, to: today)!

        guard firstDate <= endDate else {
            return .zero
        }

        var consecutiveDays = 0
        var earnedRewards = 0
        var consumedRewards = 0

        // Forward iteration: first entry → end date
        var currentDate = firstDate
        while currentDate <= endDate {
            let level = alcoholDays[currentDate]

            if level?.streakEffect == .success {
                // Steady day: count it
                consecutiveDays += 1

                // Earn Joker at every 7-day milestone (max 3 on hand)
                if consecutiveDays % 7 == 0 && (earnedRewards - consumedRewards) < 3 {
                    earnedRewards += 1
                }
            } else {
                // Easy, Wild, or nil (gap): needs Joker to continue

                // Earn before consume rule for day 7
                let wouldBeMilestone = (consecutiveDays + 1) % 7 == 0
                if wouldBeMilestone && (earnedRewards - consumedRewards) < 3 {
                    earnedRewards += 1
                }

                // Try to heal with available Joker
                let availableJokers = earnedRewards - consumedRewards
                if availableJokers > 0 {
                    consumedRewards += 1
                    consecutiveDays += 1
                } else {
                    // No Joker available → streak breaks
                    consecutiveDays = 0
                    earnedRewards = 0
                    consumedRewards = 0
                }
            }

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        let availableRewards = max(0, earnedRewards - consumedRewards)
        return StreakResult(
            currentStreak: consecutiveDays,
            longestStreak: consecutiveDays, // Not tracking longest in this migration path
            availableRewards: availableRewards,
            totalRewardsEarned: earnedRewards,
            totalRewardsUsed: consumedRewards
        )
    }
}
