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
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!

        do {
            // Calculate meditation streak with expand-on-demand
            let meditationDays = try await calculateExpandingStreak(
                endDate: tomorrow,
                fetchMinutes: { start, end in
                    let data = try await self.healthKitManager.fetchDailyMinutesFiltered(from: start, to: end)
                    return data.mapValues { $0.mindfulnessMinutes }
                }
            )

            // Calculate workout streak with expand-on-demand
            let workoutDays = try await calculateExpandingStreak(
                endDate: tomorrow,
                fetchMinutes: { start, end in
                    let data = try await self.healthKitManager.fetchDailyMinutesFiltered(from: start, to: end)
                    return data.mapValues { $0.workoutMinutes }
                }
            )

            await MainActor.run {
                let today = calendar.startOfDay(for: Date())

                meditationStreak.currentStreakDays = meditationDays
                meditationStreak.rewardsEarned = min(3, meditationDays / streakThreshold)
                if meditationDays > 0 { meditationStreak.lastActivityDate = today }

                workoutStreak.currentStreakDays = workoutDays
                workoutStreak.rewardsEarned = min(3, workoutDays / streakThreshold)
                if workoutDays > 0 { workoutStreak.lastActivityDate = today }

                saveStreaks()
                print("🔍 Streak update: Meditation=\(meditationDays), Workout=\(workoutDays)")
            }
        } catch {
            print("Error updating streaks: \(error)")
        }
    }

    /// Calculates streak using expand-on-demand: loads 30-day batches until streak breaks.
    /// Performant for short streaks (1 query), scales for long streaks.
    private func calculateExpandingStreak(
        endDate: Date,
        fetchMinutes: @escaping (Date, Date) async throws -> [Date: Double]
    ) async throws -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let batchSize = 30
        let maxBatches = 40 // Safety limit: ~3.3 years

        var allMinutes: [Date: Double] = [:]
        var batchesLoaded = 0

        while batchesLoaded < maxBatches {
            // Calculate batch range (going backwards)
            let batchEnd = calendar.date(byAdding: .day, value: -(batchesLoaded * batchSize), to: endDate)!
            let batchStart = calendar.date(byAdding: .day, value: -batchSize, to: batchEnd)!

            // Fetch this batch
            let batchData = try await fetchMinutes(batchStart, batchEnd)
            allMinutes.merge(batchData) { existing, _ in existing }
            batchesLoaded += 1

            // Calculate streak with all loaded data
            let todayMinutes = allMinutes[today] ?? 0
            let hasDataToday = round(todayMinutes) >= Double(minMinutes)
            var checkDate = hasDataToday ? today : calendar.date(byAdding: .day, value: -1, to: today)!
            var streakCount = 0

            while true {
                let minutes = allMinutes[checkDate] ?? 0
                if round(minutes) >= Double(minMinutes) {
                    streakCount += 1
                    guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                    checkDate = prev
                } else {
                    // Streak broken - return result
                    return streakCount
                }

                // Check if we've reached the edge of loaded data
                if checkDate < batchStart {
                    // Need more data - break inner loop to load next batch
                    break
                }
            }

            // If streak continues to edge, load more; otherwise we found the break
            if checkDate >= batchStart {
                return streakCount
            }
        }

        // Reached max batches - calculate final streak from all loaded data
        let todayMinutes = allMinutes[today] ?? 0
        let hasDataToday = round(todayMinutes) >= Double(minMinutes)
        var checkDate = hasDataToday ? today : calendar.date(byAdding: .day, value: -1, to: today)!
        var finalStreak = 0
        while let minutes = allMinutes[checkDate], round(minutes) >= Double(minMinutes) {
            finalStreak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return finalStreak
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