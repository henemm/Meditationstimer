# Data Source Consistency

## Core Rule

**Visualization and calculation MUST use the SAME data source.**

User insight: *"What you see = What gets counted"*

## Problem Pattern

```swift
// WRONG: Different data sources
// CalendarView displays from:
let dailyMinutes = fetchDailyMinutes()  // Source A

// StreakManager calculates from:
let streakData = fetchFromHealthKit()   // Source B (separate query!)

// Result: What user sees != what system counts
```

## Solution Pattern

```swift
// CORRECT: Same data source
// CalendarView uses dailyMinutes for display:
ForEach(dailyMinutes) { day in
    CalendarDay(minutes: day.minutes)  // Display
}

// StreakManager uses SAME dailyMinutes:
computed var currentStreak: Int {
    calculateStreak(from: dailyMinutes)  // Calculate
}
```

## Implementation

Add computed properties that use SAME dictionary:
```swift
struct CalendarView: View {
    @State private var dailyMinutes: [Date: Int] = [:]

    // Display uses dailyMinutes
    var body: some View {
        ForEach(dailyMinutes.keys.sorted()) { date in
            DayView(minutes: dailyMinutes[date] ?? 0)
        }
    }

    // Calculation ALSO uses dailyMinutes
    var totalMinutesThisMonth: Int {
        dailyMinutes.values.reduce(0, +)
    }

    var daysWithActivity: Int {
        dailyMinutes.filter { $0.value >= 2 }.count
    }
}
```

## The Rules

- DO use same data for visualization AND calculation
- DON'T query separately for display vs. calculation
- DO trace complete data flow from source to consumption
- DO map ALL usages before making changes

## Why This Matters

- User trusts what they see in UI
- If calculation differs, system feels "broken"
- Debugging is harder with multiple data sources
- Single source = single point of truth
