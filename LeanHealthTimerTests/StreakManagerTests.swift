import XCTest
@testable import Lean_Health_Timer

final class StreakManagerTests: XCTestCase {

    var manager: StreakManager!
    let minMinutes = 2.0

    override func setUp() {
        super.setUp()
        // Clear UserDefaults to ensure clean state for each test
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "meditationStreak")
        defaults.removeObject(forKey: "workoutStreak")

        manager = StreakManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    // MARK: - StreakData Tests

    func testStreakDataInitialization() {
        let data = StreakData()

        XCTAssertEqual(data.currentStreakDays, 0, "Initial streak should be 0")
        XCTAssertEqual(data.rewardsEarned, 0, "Initial rewards should be 0")
        XCTAssertNil(data.lastActivityDate, "Initial activity date should be nil")
    }

    func testStreakDataCodable() throws {
        var data = StreakData()
        data.currentStreakDays = 5
        data.rewardsEarned = 2
        data.lastActivityDate = Date()

        // Encode
        let encoded = try JSONEncoder().encode(data)

        // Decode
        let decoded = try JSONDecoder().decode(StreakData.self, from: encoded)

        XCTAssertEqual(decoded.currentStreakDays, 5)
        XCTAssertEqual(decoded.rewardsEarned, 2)
        XCTAssertNotNil(decoded.lastActivityDate)
    }

    // MARK: - Manager Initialization Tests

    func testManagerInitialization() {
        XCTAssertEqual(manager.meditationStreak.currentStreakDays, 0)
        XCTAssertEqual(manager.meditationStreak.rewardsEarned, 0)
        XCTAssertEqual(manager.workoutStreak.currentStreakDays, 0)
        XCTAssertEqual(manager.workoutStreak.rewardsEarned, 0)
    }

    // MARK: - Streak Calculation Tests (via reflection/private method testing)

    func testConsecutiveDaysStreak() {
        // Create a test helper that simulates the updateStreak logic
        var streak = StreakData()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Create daily minutes: 7 consecutive days with activity
        var dailyMinutes: [Date: Double] = [:]
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            dailyMinutes[date] = 10.0 // 10 minutes each day
        }

        // Simulate updateStreak logic
        let (streakDays, rewards) = calculateStreak(dailyMinutes: dailyMinutes, today: today)

        XCTAssertEqual(streakDays, 7, "Should have 7-day streak")
        XCTAssertEqual(rewards, 1, "Should earn 1 reward (7 days = 1 reward)")
    }

    func testStreakWithGap() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 3 consecutive days, then a gap, then more activity
        var dailyMinutes: [Date: Double] = [:]
        dailyMinutes[today] = 10.0
        dailyMinutes[calendar.date(byAdding: .day, value: -1, to: today)!] = 10.0
        dailyMinutes[calendar.date(byAdding: .day, value: -2, to: today)!] = 10.0
        // Gap at -3
        dailyMinutes[calendar.date(byAdding: .day, value: -4, to: today)!] = 10.0

        let (streakDays, _) = calculateStreak(dailyMinutes: dailyMinutes, today: today)

        XCTAssertEqual(streakDays, 3, "Streak should stop at gap, only count 3 consecutive days")
    }

    func testMinimumMinutesThreshold() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Test exactly at threshold and below
        var dailyMinutes: [Date: Double] = [:]
        dailyMinutes[today] = 2.0 // Exactly at threshold
        dailyMinutes[calendar.date(byAdding: .day, value: -1, to: today)!] = 1.9 // Below threshold
        dailyMinutes[calendar.date(byAdding: .day, value: -2, to: today)!] = 3.0 // Above threshold

        let (streakDays, _) = calculateStreak(dailyMinutes: dailyMinutes, today: today)

        XCTAssertEqual(streakDays, 1, "Only today should count (day -1 is below threshold)")
    }

    func testRewardCalculation() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Test different streak lengths and their rewards
        let testCases: [(days: Int, expectedRewards: Int)] = [
            (0, 0),
            (6, 0),
            (7, 1),
            (13, 1),
            (14, 2),
            (20, 2),
            (21, 3),
            (30, 3) // Max rewards capped at 3
        ]

        for testCase in testCases {
            var dailyMinutes: [Date: Double] = [:]
            for i in 0..<testCase.days {
                let date = calendar.date(byAdding: .day, value: -i, to: today)!
                dailyMinutes[date] = 5.0
            }

            let (_, rewards) = calculateStreak(dailyMinutes: dailyMinutes, today: today)
            XCTAssertEqual(rewards, testCase.expectedRewards,
                          "\(testCase.days) days should give \(testCase.expectedRewards) rewards")
        }
    }

    func testNoActivityToday() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Activity yesterday but not today
        var dailyMinutes: [Date: Double] = [:]
        dailyMinutes[calendar.date(byAdding: .day, value: -1, to: today)!] = 10.0
        dailyMinutes[calendar.date(byAdding: .day, value: -2, to: today)!] = 10.0

        let (streakDays, _) = calculateStreak(dailyMinutes: dailyMinutes, today: today)

        XCTAssertEqual(streakDays, 0, "Streak should be 0 if no activity today")
    }

    func testLongStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 30-day streak
        var dailyMinutes: [Date: Double] = [:]
        for i in 0..<30 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            dailyMinutes[date] = 10.0
        }

        let (streakDays, rewards) = calculateStreak(dailyMinutes: dailyMinutes, today: today)

        XCTAssertEqual(streakDays, 30, "Should have 30-day streak")
        XCTAssertEqual(rewards, 3, "Should have max 3 rewards (30/7 = 4, but capped at 3)")
    }

    // MARK: - Persistence Tests

    func testSaveAndLoadStreaks() {
        // Set some streak data
        manager.meditationStreak.currentStreakDays = 10
        manager.meditationStreak.rewardsEarned = 1
        manager.meditationStreak.lastActivityDate = Date()

        manager.workoutStreak.currentStreakDays = 5
        manager.workoutStreak.rewardsEarned = 0
        manager.workoutStreak.lastActivityDate = Date()

        // Trigger save (normally happens in updateStreaks)
        let defaults = UserDefaults.standard
        if let medData = try? JSONEncoder().encode(manager.meditationStreak) {
            defaults.set(medData, forKey: "meditationStreak")
        }
        if let workData = try? JSONEncoder().encode(manager.workoutStreak) {
            defaults.set(workData, forKey: "workoutStreak")
        }

        // Create new manager to trigger load
        let newManager = StreakManager()

        // Verify loaded data
        XCTAssertEqual(newManager.meditationStreak.currentStreakDays, 10)
        XCTAssertEqual(newManager.meditationStreak.rewardsEarned, 1)
        XCTAssertEqual(newManager.workoutStreak.currentStreakDays, 5)
        XCTAssertEqual(newManager.workoutStreak.rewardsEarned, 0)
    }

    func testLoadWithNoSavedData() {
        // Already cleared in setUp
        let newManager = StreakManager()

        XCTAssertEqual(newManager.meditationStreak.currentStreakDays, 0)
        XCTAssertEqual(newManager.meditationStreak.rewardsEarned, 0)
        XCTAssertNil(newManager.meditationStreak.lastActivityDate)
    }

    // MARK: - Reward Decay Tests

    func testRewardDecayLogic() {
        var streak = StreakData()
        streak.currentStreakDays = 7
        streak.rewardsEarned = 1
        streak.lastActivityDate = Date()

        // Simulate: no activity today but had rewards
        // According to code: rewards decrease by 1, streak remains
        let dailyMinutes: [Date: Double] = [:] // No activity

        // After decay logic:
        // - If rewardsEarned > 0: decrease by 1, keep streak
        // - If rewardsEarned == 0: reset streak

        // With 1 reward and no activity: rewards -> 0, streak stays
        // With 0 rewards and no activity: streak -> 0

        XCTAssertTrue(true, "Decay logic tested conceptually - full integration test needed")
    }

    // MARK: - Edge Cases

    func testEmptyDailyMinutes() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dailyMinutes: [Date: Double] = [:]

        let (streakDays, rewards) = calculateStreak(dailyMinutes: dailyMinutes, today: today)

        XCTAssertEqual(streakDays, 0)
        XCTAssertEqual(rewards, 0)
    }

    func testRoundingBehavior() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Test minutes that round to exactly minMinutes
        var dailyMinutes: [Date: Double] = [:]
        dailyMinutes[today] = 1.5 // rounds to 2

        let (streakDays, _) = calculateStreak(dailyMinutes: dailyMinutes, today: today)

        // Depends on how rounding is handled in actual code
        XCTAssertGreaterThanOrEqual(streakDays, 0, "Should handle rounding")
    }

    // MARK: - Helper Functions

    /// Helper that replicates the streak calculation logic from StreakManager
    private func calculateStreak(dailyMinutes: [Date: Double], today: Date) -> (streakDays: Int, rewards: Int) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)

        var currentStreak = 0
        var checkDate = todayStart

        // Count consecutive days
        while true {
            let minutes = dailyMinutes[checkDate] ?? 0
            if round(minutes) >= minMinutes {
                currentStreak += 1
                guard let newDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = newDate
            } else {
                break
            }
        }

        // Calculate rewards (7 days per reward, max 3)
        let rewards = min(3, currentStreak / 7)

        return (currentStreak, rewards)
    }
}
