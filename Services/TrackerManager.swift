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
    func logEntry(
        for tracker: Tracker,
        value: Int? = nil,
        note: String? = nil,
        trigger: String? = nil,
        location: String? = nil,
        timestamp: Date = Date(),
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
        if tracker.saveToHealthKit, let logValue = value {
            Task {
                await saveToHealthKit(tracker: tracker, value: logValue, date: log.timestamp)
            }
        }

        // Cancel matching Smart Reminders for this tracker (Reverse Smart Reminders)
        #if os(iOS)
        SmartReminderEngine.shared.cancelMatchingTrackerReminders(for: tracker.id, completedAt: log.timestamp)
        #endif

        return log
    }

    // MARK: - HealthKit Integration

    /// Saves a tracker value to HealthKit
    /// - Parameters:
    ///   - tracker: The tracker with HealthKit configuration
    ///   - value: The value to save (TrackerLevel.id for level-based trackers)
    ///   - date: The timestamp for the log
    private func saveToHealthKit(
        tracker: Tracker,
        value: Int,
        date: Date
    ) async {
        guard tracker.saveToHealthKit,
              let hkTypeId = tracker.healthKitType,
              let hkType = HKQuantityType.quantityType(
                  forIdentifier: HKQuantityTypeIdentifier(rawValue: hkTypeId)
              ) else { return }

        // Check HealthKit authorization status
        let authStatus = healthStore.authorizationStatus(for: hkType)
        guard authStatus == .sharingAuthorized else {
            print("[TrackerManager] HealthKit not authorized for \(tracker.name), skipping save")
            return
        }

        // For level-based trackers: Get HealthKit value from level mapping
        let hkValue: Int
        if let levels = tracker.levels,
           let level = levels.first(where: { $0.id == value }) {
            hkValue = level.healthKitValue
        } else {
            hkValue = value
        }

        do {
            let quantity = HKQuantity(unit: .count(), doubleValue: Double(hkValue))
            let assignedDay = tracker.effectiveDayAssignment.assignedDay(for: date, calendar: calendar)
            let sample = HKQuantitySample(type: hkType, quantity: quantity, start: assignedDay, end: assignedDay)
            try await healthStore.save(sample)
            print("[TrackerManager] HealthKit save succeeded: \(hkValue) for \(tracker.name)")
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

    // MARK: - Preset Access

    /// Get all predefined presets
    static func predefinedPresets() -> [TrackerPreset] {
        return TrackerPreset.all
    }

    /// Get presets by category
    static func presets(for category: TrackerPreset.PresetCategory) -> [TrackerPreset] {
        return TrackerPreset.all.filter { $0.category == category }
    }
}
