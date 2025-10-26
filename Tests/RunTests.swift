#!/usr/bin/env swift
import Foundation

// Simple test framework
var passedTests = 0
var failedTests = 0

func assert(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if condition {
        passedTests += 1
        print("✅ PASS: \(message)")
    } else {
        failedTests += 1
        print("❌ FAIL: \(message) (\(file):\(line))")
    }
}

func assertEqual<T: Equatable>(_ lhs: T, _ rhs: T, _ message: String) {
    assert(lhs == rhs, "\(message) (expected: \(rhs), got: \(lhs))")
}

// MARK: - Date Calculation Tests

print("🧪 Testing Date Calculations (for HealthKit/StreakManager)...")

let calendar = Calendar.current
let now = Date()

// Test 1: Month boundary calculation
let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

assert(calendar.isDate(startOfMonth, inSameDayAs: now) || startOfMonth < now,
       "Start of month should be on or before today")
assert(endOfMonth >= now || calendar.isDate(endOfMonth, inSameDayAs: now),
       "End of month should be on or after today")

// Test 2: Day difference calculation
let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
let dayDiff = calendar.dateComponents([.day], from: yesterday, to: now).day ?? 0
assertEqual(dayDiff, 1, "Day difference between yesterday and today")

// Test 3: Week start calculation (for streak logic)
let weekday = calendar.component(.weekday, from: now)
assert(weekday >= 1 && weekday <= 7, "Weekday should be between 1-7")

// Test 4: Hour calculation (for time-based reminders)
let hour = calendar.component(.hour, from: now)
assert(hour >= 0 && hour < 24, "Hour should be between 0-23")

// Test 5: Time interval accuracy
let futureDate = calendar.date(byAdding: .minute, value: 5, to: now)!
let interval = futureDate.timeIntervalSince(now)
assert(abs(interval - 300) < 1, "5 minutes should be ~300 seconds")

print("\n🧪 Testing Timer Duration Calculations...")

// Test 6: Phase duration calculation (like TwoPhaseTimerEngine)
func calculatePhaseDuration(startDate: Date, endDate: Date) -> TimeInterval {
    return endDate.timeIntervalSince(startDate)
}

let phase1Start = Date()
let phase1End = calendar.date(byAdding: .minute, value: 15, to: phase1Start)!
let phase1Duration = calculatePhaseDuration(startDate: phase1Start, endDate: phase1End)
assert(abs(phase1Duration - 900) < 1, "15 minutes = 900 seconds")

// Test 7: Remaining time calculation
func calculateRemaining(from now: Date, until endDate: Date) -> TimeInterval {
    return max(0, endDate.timeIntervalSince(now))
}

let target = calendar.date(byAdding: .second, value: 30, to: Date())!
Thread.sleep(forTimeInterval: 0.1) // Small delay
let remaining = calculateRemaining(from: Date(), until: target)
assert(remaining > 29 && remaining <= 30, "Remaining time should be ~29-30 seconds")

print("\n🧪 Testing Streak Logic (StreakManager-like)...")

// Test 8: Consecutive days detection
func isConsecutiveDays(_ date1: Date, _ date2: Date, calendar: Calendar) -> Bool {
    let day1 = calendar.startOfDay(for: date1)
    let day2 = calendar.startOfDay(for: date2)
    return calendar.dateComponents([.day], from: day1, to: day2).day == 1
}

let today = calendar.startOfDay(for: Date())
let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: today)!
assert(isConsecutiveDays(yesterdayStart, today, calendar: calendar),
       "Yesterday and today should be consecutive")

// Test 9: Streak reward calculation (every 7 days = 1 reward)
func calculateRewards(streakDays: Int) -> Int {
    return min(3, streakDays / 7)
}

assertEqual(calculateRewards(streakDays: 0), 0, "0 days = 0 rewards")
assertEqual(calculateRewards(streakDays: 6), 0, "6 days = 0 rewards")
assertEqual(calculateRewards(streakDays: 7), 1, "7 days = 1 reward")
assertEqual(calculateRewards(streakDays: 14), 2, "14 days = 2 rewards")
assertEqual(calculateRewards(streakDays: 21), 3, "21 days = 3 rewards (max)")
assertEqual(calculateRewards(streakDays: 50), 3, "50 days = 3 rewards (capped)")

print("\n🧪 Testing Weekday Conversion (Smart Reminders)...")

// Test 10: Calendar weekday to custom enum mapping
enum Weekday: Int, CaseIterable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    static func from(calendarWeekday: Int) -> Weekday? {
        return Weekday(rawValue: calendarWeekday)
    }
}

for day in 1...7 {
    assert(Weekday.from(calendarWeekday: day) != nil,
           "Should convert calendar day \(day) to Weekday enum")
}

// Test 11: Current weekday extraction
let todayWeekday = calendar.component(.weekday, from: Date())
let weekdayEnum = Weekday.from(calendarWeekday: todayWeekday)
assert(weekdayEnum != nil, "Today's weekday should be valid")

print("\n🧪 Testing Time Window Logic (Smart Reminders trigger windows)...")

// Test 12: Time window check
func isWithinWindow(now: Date, triggerHour: Int, windowMinutes: Int, calendar: Calendar) -> Bool {
    guard let triggerStart = calendar.date(bySettingHour: triggerHour, minute: 0, second: 0, of: now),
          let triggerEnd = calendar.date(byAdding: .minute, value: windowMinutes, to: triggerStart) else {
        return false
    }
    return now >= triggerStart && now <= triggerEnd
}

let currentHour = calendar.component(.hour, from: Date())
// Should be within window if we set trigger to current hour with 60 min window
assert(isWithinWindow(now: Date(), triggerHour: currentHour, windowMinutes: 60, calendar: calendar),
       "Current time should be within current hour + 60 min window")

// Should NOT be within window if trigger was 2 hours ago with 30 min window
let twoHoursAgo = (currentHour - 2 + 24) % 24
assert(!isWithinWindow(now: Date(), triggerHour: twoHoursAgo, windowMinutes: 30, calendar: calendar),
       "Should not be within window from 2 hours ago")

print("\n🧪 Testing Audio Duration Calculations...")

// Test 13: Audio file duration parsing (simulated)
func estimateGongDuration(filename: String) -> TimeInterval {
    // Typical gong durations based on filename
    switch filename {
    case "gong": return 2.0
    case "gong-dreimal": return 6.0  // 3 gongs
    case "gong-ende": return 3.0
    case "kurz": return 0.5
    case "lang": return 1.5
    default: return 1.0
    }
}

assert(estimateGongDuration(filename: "gong-ende") >= 2.0,
       "End gong should be at least 2 seconds")
assert(estimateGongDuration(filename: "kurz") < 1.0,
       "Short beep should be less than 1 second")

print("\n" + String(repeating: "=", count: 50))
print("📊 Test Results:")
print("   ✅ Passed: \(passedTests)")
print("   ❌ Failed: \(failedTests)")
print("   📈 Success Rate: \(passedTests)/\(passedTests + failedTests) (\(Int(Double(passedTests)/Double(passedTests + failedTests) * 100))%)")
print(String(repeating: "=", count: 50))

exit(failedTests == 0 ? 0 : 1)
