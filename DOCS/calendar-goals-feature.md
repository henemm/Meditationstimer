# Calendar Goals Feature

## Overview
Implement daily goals for meditation and workout minutes, visualized as partially filled circles in the calendar view.

## Requirements
- User can set daily goals for meditation and workout minutes in Settings (default: 10 min each)
- Calendar shows progress as filled quarters (0-25%, 25-50%, 50-75%, 75-100%)
- Overachievement (>100%) is capped at full circle
- No data: Show nothing (rely on HealthKit)
- Separate visualization: Circle for meditation, ring for workout
- Daily goals only
- Settings changes apply only to future days (past calculations cached)

## Implementation Details

### Settings Integration
- Add to SettingsSheet.swift:
  - @AppStorage for "meditationGoalMinutes" (Int, default 10)
  - @AppStorage for "workoutGoalMinutes" (Int, default 10)
  - UI: Two Steppers with labels "Tägliches Meditation-Ziel (Min)" and "Tägliches Workout-Ziel (Min)"

### Data Calculation
- Extend HealthKitManager with method to get daily totals:
  - `fetchDailyMinutes(for date: Date, type: ActivityType) -> Double`
- Cache results in CalendarView to avoid recalculating
- Progress = min(totalMinutes / goalMinutes, 1.0) // cap at 1.0

### UI Changes in CalendarView.swift
- Modify `dayView` in MonthView:
  - For meditation: `Circle().trim(from: 0, to: progress).fill(Color.mindfulnessBlue)`
  - For workout: `Circle().trim(from: 0, to: progress).stroke(Color.workoutViolet, lineWidth: 2)`
  - For both: Combine both trims
- Ensure text remains readable (black on light backgrounds)

### Edge Cases
- No goal set: Fall back to current behavior (full circle on activity)
- Data unavailable: No fill
- Progress > 1.0: Cap at 1.0 (full circle)

## Testing
- Unit tests for progress calculation
- UI tests for different progress levels
- Integration tests with HealthKit data