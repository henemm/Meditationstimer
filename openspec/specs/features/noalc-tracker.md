# NoAlc Tracker

## Overview

Alcohol consumption tracking with HealthKit integration, streak calculation with reward-based forgiveness system, and calendar visualization. Designed as a "passive" feature with notification-driven logging rather than prominent manual UI.

## Requirements

### Requirement: Consumption Levels
The system SHALL categorize alcohol consumption into three distinct levels.

#### Scenario: Steady Level (No/Minimal)
- GIVEN user is logging alcohol consumption
- WHEN user selects "Steady" level
- THEN consumption is categorized as 0-1 drinks
- AND HealthKit value is stored as 0
- AND calendar displays green color (#0EBF6E)
- AND streak continues/increments

#### Scenario: Easy Level (Moderate)
- GIVEN user is logging alcohol consumption
- WHEN user selects "Easy" level
- THEN consumption is categorized as 2-5 drinks
- AND HealthKit value is stored as 4
- AND calendar displays light green color (#89D6B2)
- AND streak may continue if rewards available

#### Scenario: Wild Level (High)
- GIVEN user is logging alcohol consumption
- WHEN user selects "Wild" level
- THEN consumption is categorized as 6+ drinks
- AND HealthKit value is stored as 6
- AND calendar displays gray color (#B6B6B6)
- AND streak breaks regardless of rewards

### Requirement: Calendar Visualization
The system SHALL display NoAlc status as innermost ring in calendar.

#### Scenario: NoAlc Ring Display
- GIVEN calendar day has NoAlc entry
- WHEN calendar renders day cell
- THEN inner fill circle appears (28x28 points)
- AND fill color matches consumption level
- AND ring is innermost (inside workout and mindfulness rings)

#### Scenario: Ring Layering Order
- GIVEN calendar day has multiple activity types
- WHEN rendering activity rings
- THEN NoAlc displays as innermost fill (28x28)
- AND Workout displays as middle ring (32x32)
- AND Mindfulness displays as outer ring (42x42)
- AND all rings are visible concentrically

#### Scenario: No NoAlc Entry
- GIVEN calendar day has no NoAlc entry
- WHEN calendar renders day cell
- THEN no inner fill circle appears
- AND other rings (workout, mindfulness) still display if present

### Requirement: Streak Calculation
The system SHALL calculate NoAlc streaks using reward-based forgiveness.

#### Scenario: Streak Continues on Steady Day
- GIVEN current streak is active
- WHEN day has Steady level entry
- THEN streak counter increments by 1
- AND consecutive days count toward reward earning

#### Scenario: Reward Earning
- GIVEN streak is active
- WHEN 7 consecutive Steady days are reached
- THEN 1 reward is earned
- AND maximum rewards cap at 3
- AND visual indicator shows reward count

#### Scenario: Easy Day Forgiveness (Healing)
- GIVEN day has Easy level entry
- AND available rewards > consumed rewards
- WHEN streak is calculated
- THEN 1 reward is consumed
- AND streak continues (not broken)
- AND reward balance decreases by 1

#### Scenario: Easy Day Without Reward
- GIVEN day has Easy level entry
- AND available rewards = consumed rewards (no spare)
- WHEN streak is calculated
- THEN streak breaks
- AND streak counter resets

#### Scenario: Easy Day Without Reward (Penalty)
- GIVEN day has Easy level entry
- AND available rewards = 0
- WHEN streak is calculated
- THEN streak breaks
- AND reward count decreases by 1 (penalty)

#### Scenario: Wild Day Breaks Streak (Penalty)
- GIVEN day has Wild level entry
- WHEN streak is calculated
- THEN streak breaks immediately
- AND reward count decreases by 1 (penalty)

### Requirement: Forward Chronological Iteration
The system SHALL iterate forward (past → present) for streak calculation.

#### Scenario: Reward Earning Before Consumption
- GIVEN streak data exists for multiple days
- WHEN calculating current streak and rewards
- THEN iterate from earliest date to today
- AND earn rewards on day 7, 14, 21 chronologically
- AND consume rewards chronologically after earning

#### Scenario: Why Forward Iteration
- GIVEN backwards iteration was attempted
- WHEN processing Easy day before reaching reward-earning days
- THEN rewards appear as 0 (not yet iterated)
- AND healing fails incorrectly
- THEREFORE forward iteration is REQUIRED

### Requirement: HealthKit Integration
The system SHALL store and retrieve NoAlc data via HealthKit.

#### Scenario: Data Storage
- GIVEN user logs consumption level
- WHEN saving to HealthKit
- THEN HKQuantitySample is created
- AND type is `.numberOfAlcoholicBeverages`
- AND value is representative count (0, 4, or 6)
- AND sample is tagged with app source

#### Scenario: Data Retrieval
- GIVEN calendar needs NoAlc data
- WHEN fetching from HealthKit
- THEN query filters by app source only
- AND groups by date
- AND returns level based on stored value

### Requirement: Manual Entry
The system SHALL provide UI for manual consumption logging.

#### Scenario: NoAlc Log Sheet Open
- GIVEN user taps NoAlc area in calendar
- OR user opens NoAlc sheet from notification action
- WHEN sheet appears
- THEN three level buttons display (Steady, Easy, Wild)
- AND each button shows color and description
- AND date picker shows target date

#### Scenario: Quick Log from Buttons
- GIVEN NoAlc sheet is open
- WHEN user taps level button
- THEN consumption is saved to HealthKit immediately
- AND sheet dismisses
- AND calendar updates to show entry

#### Scenario: Historical Entry
- GIVEN user wants to log past day
- WHEN user changes date in date picker
- THEN selected date is used for HealthKit sample
- AND entry appears in calendar for that date

#### Scenario: Info Button
- GIVEN NoAlc sheet is open
- WHEN user taps info button (ⓘ)
- THEN InfoSheet explains NoAlc tracking
- AND describes streak/reward system
- AND explains level meanings

### Requirement: Smart Reminders for NoAlc
The system SHALL support configurable NoAlc reminders.

#### Scenario: NoAlc Reminder Type
- GIVEN user configures smart reminder
- WHEN activity type is "NoAlc"
- THEN reminder checks numberOfAlcoholicBeverages in HealthKit
- AND default time is 09:00

#### Scenario: Day Assignment Logic
- GIVEN NoAlc reminder fires
- AND reminder time is < 18:00
- WHEN notification displays
- THEN message references "yesterday" (e.g., "Wie war gestern?")
- AND date picker defaults to yesterday

#### Scenario: Day Assignment After 18:00
- GIVEN NoAlc reminder fires
- AND reminder time is >= 18:00
- WHEN notification displays
- THEN message references "today"
- AND date picker defaults to today

#### Scenario: Reminder Edge Case at 18:00
- GIVEN reminder time is exactly 18:00
- WHEN reminder fires
- THEN message references "today" (>= threshold)

#### Scenario: Quick Actions from Notification
- GIVEN NoAlc notification appears
- WHEN user sees notification
- THEN three action buttons are available (Steady, Easy, Wild)
- AND tapping action logs directly to HealthKit
- AND no app open required

## Technical Notes

- **Forward Iteration:** CRITICAL for reward tracking - see CLAUDE.md "Forward vs. Backward Iteration"
- **Data Consistency:** Same HealthKit query for calendar display AND streak calculation
- **Day Assignment:** `targetDay(for:)` in NoAlcManager determines yesterday vs. today
- **HealthKit Values:** 0 (Steady), 4 (Easy), 6 (Wild) - representative counts
- **Feature Category:** PASSIVE - notification-driven, not prominent manual UI

Reference Standards:
- `.agent-os/standards/healthkit/date-semantics.md` (Forward Iteration)
- `.agent-os/standards/healthkit/data-consistency.md` (What you see = What gets counted)
