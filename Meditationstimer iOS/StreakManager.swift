//
//  StreakManager.swift
//  Meditationstimer
//
//  Created by GitHub Copilot on 2024.
//

import Foundation
import HealthKit

struct StreakData: Codable {
    var currentStreakDays: Int
    var rewardsEarned: Int // total earned
    var rewardsConsumed: Int // total consumed for healing
    var lastActivityDate: Date?

    /// Available rewards (earned - consumed), max 3
    var availableRewards: Int {
        min(3, rewardsEarned - rewardsConsumed)
    }

    init() {
        self.currentStreakDays = 0
        self.rewardsEarned = 0
        self.rewardsConsumed = 0
        self.lastActivityDate = nil
    }

    // Migration: handle old data without rewardsConsumed
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentStreakDays = try container.decode(Int.self, forKey: .currentStreakDays)
        rewardsEarned = try container.decode(Int.self, forKey: .rewardsEarned)
        rewardsConsumed = try container.decodeIfPresent(Int.self, forKey: .rewardsConsumed) ?? 0
        lastActivityDate = try container.decodeIfPresent(Date.self, forKey: .lastActivityDate)
    }
}

/// Result from streak calculation with Joker system
struct JokerStreakResult {
    let streak: Int
    let rewardsEarned: Int
    let rewardsConsumed: Int

    var availableRewards: Int {
        min(3, rewardsEarned - rewardsConsumed)
    }
}

class StreakManager: ObservableObject {
    private let healthKitManager = HealthKitManager.shared

    // Separate streaks for meditation and workout
    @Published var meditationStreak = StreakData()
    @Published var workoutStreak = StreakData()

    private let streakThreshold = 7 // days to earn a reward
    private let minMinutes = 2 // minimum minutes to count as activity

    init() {
        loadStreaks()
    }

    // MARK: - Static Calculation (Testable)

    /// Calculate streak and rewards using forward iteration with Joker healing
    /// - Parameters:
    ///   - dailyMinutes: Dictionary of date -> minutes of activity
    ///   - minMinutes: Minimum minutes to count as a "good" day
    ///   - calendar: Calendar for date calculations
    /// - Returns: StreakResult with streak count and reward info
    static func calculateStreakAndRewards(
        dailyMinutes: [Date: Double],
        minMinutes: Int,
        calendar: Calendar = .current
    ) -> JokerStreakResult {
        let today = calendar.startOfDay(for: Date())

        // Find first day with data
        guard let firstDate = dailyMinutes.keys.min() else {
            return JokerStreakResult(streak: 0, rewardsEarned: 0, rewardsConsumed: 0)
        }

        // Determine end date: today if logged, otherwise yesterday
        // (don't penalize for not having logged today yet)
        let hasEntryToday = dailyMinutes[today] != nil &&
                           round(dailyMinutes[today]!) >= Double(minMinutes)
        let endDate = hasEntryToday ? today : calendar.date(byAdding: .day, value: -1, to: today)!

        // Don't process if first date is after end date
        guard firstDate <= endDate else {
            return JokerStreakResult(streak: 0, rewardsEarned: 0, rewardsConsumed: 0)
        }

        var consecutiveDays = 0
        var earnedRewards = 0
        var consumedRewards = 0

        // Forward iteration: iterate over ALL days from first entry to end date
        var currentDate = firstDate
        while currentDate <= endDate {
            let minutes = dailyMinutes[currentDate] ?? 0
            let isGoodDay = round(minutes) >= Double(minMinutes)

            if isGoodDay {
                // Good day: count it
                consecutiveDays += 1

                // Earn Joker at every 7-day milestone (max 3 on hand)
                if consecutiveDays % 7 == 0 && (earnedRewards - consumedRewards) < 3 {
                    earnedRewards += 1
                }
            } else {
                // Gap or insufficient minutes: needs Joker to continue

                // First check if we would earn a Joker at this milestone
                // (earn before consume rule for day 7)
                let wouldBeMilestone = (consecutiveDays + 1) % 7 == 0
                if wouldBeMilestone && (earnedRewards - consumedRewards) < 3 {
                    earnedRewards += 1
                }

                // Now try to heal with available Joker
                let availableJokers = earnedRewards - consumedRewards
                if availableJokers > 0 {
                    consumedRewards += 1
                    consecutiveDays += 1  // Streak continues (healed)
                } else {
                    // No Joker available: streak breaks
                    consecutiveDays = 0
                    earnedRewards = 0
                    consumedRewards = 0
                }
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return JokerStreakResult(
            streak: consecutiveDays,
            rewardsEarned: earnedRewards,
            rewardsConsumed: consumedRewards
        )
    }
    
    func updateStreaks(for date: Date = Date()) async {
        // Get daily minutes for the past 30 days or so
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -30, to: date)!

        // CRITICAL FIX: Use start of tomorrow as endDate to include ALL samples from today
        // With .strictStartDate, samples must start BEFORE endDate (exclusive)
        // If we pass Date() (now), samples from later today won't be found
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!

        do {
            let dailyMinutes = try await healthKitManager.fetchDailyMinutesFiltered(from: startDate, to: tomorrow)

            print("🔍 StreakManager - Fetched \(dailyMinutes.count) days of data")
            print("🔍 Date range: \(startDate) to \(tomorrow)")

            // Debug: Print meditation minutes
            let meditationMinutes = dailyMinutes.mapValues { $0.mindfulnessMinutes }
            let meditationDaysWithData = meditationMinutes.filter { $0.value >= Double(minMinutes) }
            print("🔍 Meditation days with >= \(minMinutes) min: \(meditationDaysWithData.count)")
            for (date, mins) in meditationDaysWithData.sorted(by: { $0.key > $1.key }).prefix(5) {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                print("   \(formatter.string(from: date)): \(mins) min")
            }

            await MainActor.run {
                // Update meditation streak
                updateStreak(&meditationStreak, dailyMinutes: dailyMinutes.mapValues { $0.mindfulnessMinutes })
                print("🔍 After update - Meditation streak: \(meditationStreak.currentStreakDays) days")

                // Update workout streak
                updateStreak(&workoutStreak, dailyMinutes: dailyMinutes.mapValues { $0.workoutMinutes })
                print("🔍 After update - Workout streak: \(workoutStreak.currentStreakDays) days")

                saveStreaks()
            }
        } catch {
            print("Error updating streaks: \(error)")
        }
    }
    
    private func updateStreak(_ streak: inout StreakData, dailyMinutes: [Date: Double]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Use new Joker-based calculation
        let result = StreakManager.calculateStreakAndRewards(
            dailyMinutes: dailyMinutes,
            minMinutes: minMinutes,
            calendar: calendar
        )

        print("🔍 updateStreak() - streak: \(result.streak), earned: \(result.rewardsEarned), consumed: \(result.rewardsConsumed)")

        // Update streak data
        streak.currentStreakDays = result.streak
        streak.rewardsEarned = result.rewardsEarned
        streak.rewardsConsumed = result.rewardsConsumed

        // Update lastActivityDate if today has data
        let todayMinutes = dailyMinutes[today] ?? 0
        if round(todayMinutes) >= Double(minMinutes) {
            streak.lastActivityDate = today
        }
    }
    
    private func loadStreaks() {
        // Load from UserDefaults or similar
        let defaults = UserDefaults.standard
        if let medData = defaults.data(forKey: "meditationStreak"),
           let medStreak = try? JSONDecoder().decode(StreakData.self, from: medData) {
            meditationStreak = medStreak
        }
        if let workData = defaults.data(forKey: "workoutStreak"),
           let workStreak = try? JSONDecoder().decode(StreakData.self, from: workData) {
            workoutStreak = workStreak
        }
    }
    
    private func saveStreaks() {
        let defaults = UserDefaults.standard
        if let medData = try? JSONEncoder().encode(meditationStreak) {
            defaults.set(medData, forKey: "meditationStreak")
        }
        if let workData = try? JSONEncoder().encode(workoutStreak) {
            defaults.set(workData, forKey: "workoutStreak")
        }
    }
}