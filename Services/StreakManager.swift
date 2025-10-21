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
    private let healthKitManager = HealthKitManager()
    
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
        
        do {
            let dailyMinutes = try await healthKitManager.fetchDailyMinutes(from: startDate, to: date)
            
            // Update meditation streak
            updateStreak(&meditationStreak, dailyMinutes: dailyMinutes.mapValues { $0.mindfulnessMinutes })
            
            // Update workout streak
            updateStreak(&workoutStreak, dailyMinutes: dailyMinutes.mapValues { $0.workoutMinutes })
            
            saveStreaks()
        } catch {
            print("Error updating streaks: \(error)")
        }
    }
    
    private func updateStreak(_ streak: inout StreakData, dailyMinutes: [Date: Double]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Calculate current streak: consecutive days with at least minMinutes
        var currentStreak = 0
        var checkDate = today
        
        while true {
            let minutes = dailyMinutes[checkDate] ?? 0
            if minutes >= Double(minMinutes) {
                currentStreak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }
        
        // Calculate rewards based on streak
        let newRewards = min(3, currentStreak / streakThreshold)
        
        // Check if today has activity
        let todayMinutes = dailyMinutes[today] ?? 0
        let hasActivityToday = todayMinutes >= Double(minMinutes)
        
        if hasActivityToday {
            // Update streak and rewards
            streak.currentStreakDays = currentStreak
            streak.rewardsEarned = newRewards
            streak.lastActivityDate = today
        } else {
            // No activity today: apply decay
            if streak.rewardsEarned > 0 {
                streak.rewardsEarned -= 1
                // Streak remains
            } else {
                // No rewards left, reset streak
                streak.currentStreakDays = 0
                streak.lastActivityDate = nil
            }
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