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
    var rewardsEarned: Int // max 3
    var lastActivityDate: Date?
    
    init() {
        self.currentStreakDays = 0
        self.rewardsEarned = 0
        self.lastActivityDate = nil
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

        // Check if today has data
        let todayMinutes = dailyMinutes[today] ?? 0
        let hasDataToday = round(todayMinutes) >= Double(minMinutes)

        print("🔍 updateStreak() - today: \(today), todayMinutes: \(todayMinutes), hasDataToday: \(hasDataToday)")

        // Calculate current streak: consecutive days with at least minMinutes
        // Start from yesterday if today has no data (don't break streak for incomplete today)
        var currentStreak = 0
        var checkDate = hasDataToday ? today : calendar.date(byAdding: .day, value: -1, to: today)!

        print("🔍 Starting streak calculation from: \(checkDate)")

        while true {
            let minutes = dailyMinutes[checkDate] ?? 0
            print("🔍   Checking \(checkDate): \(minutes) min (rounded: \(round(minutes)))")
            if round(minutes) >= Double(minMinutes) {
                currentStreak += 1
                guard let previousDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                    print("🔍   Reached beginning of calendar")
                    break
                }
                checkDate = previousDate
            } else {
                print("🔍   Day has < \(minMinutes) min, stopping. Final streak: \(currentStreak)")
                break
            }
        }

        // Calculate rewards based on streak
        let newRewards = min(3, currentStreak / streakThreshold)

        if hasDataToday {
            // Update streak and rewards
            streak.currentStreakDays = currentStreak
            streak.rewardsEarned = newRewards
            streak.lastActivityDate = today
        } else {
            // No data today: show streak from yesterday (don't penalize for incomplete day)
            streak.currentStreakDays = currentStreak
            streak.rewardsEarned = newRewards
            // Keep lastActivityDate as is (don't update)
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