# Calendar View

## Overview

Monthly calendar view displaying activity history with concentric ring visualization for meditation, workout, and NoAlc tracking. Serves as the central dashboard for viewing progress and streaks.

## Requirements

### Requirement: Monthly Grid Display
The system SHALL display a monthly calendar grid.

#### Scenario: Month Grid Layout
- GIVEN user opens Calendar view
- WHEN calendar renders
- THEN current month displays in grid format
- AND each day shows as a circular cell
- AND days are arranged in 7 columns (Sun-Sat)
- AND current day is highlighted

#### Scenario: Month Navigation
- GIVEN calendar is displaying a month
- WHEN user swipes left/right or taps navigation arrows
- THEN previous/next month displays
- AND data loads for new month
- AND loading indicator shows during fetch

#### Scenario: Scroll to Today
- GIVEN user is viewing a past/future month
- WHEN user taps "Today" button
- THEN calendar scrolls to current month
- AND current day is highlighted

### Requirement: Activity Ring Visualization
The system SHALL display concentric rings for each activity type.

#### Scenario: Ring Layering Order
- GIVEN calendar day has activity data
- WHEN rendering day cell
- THEN rings display concentrically in this order:
  - Outer: Mindfulness ring (42x42 points, blue)
  - Middle: Workout ring (32x32 points, purple)
  - Inner: NoAlc fill (28x28 points, color by level)

#### Scenario: Mindfulness Ring (Outer)
- GIVEN day has mindfulness minutes
- WHEN rendering outer ring
- THEN ring shows progress toward meditationGoalMinutes
- AND fill percentage = min(1.0, actualMinutes / goalMinutes)
- AND color is blue gradient
- AND full ring indicates goal met

#### Scenario: Workout Ring (Middle)
- GIVEN day has workout minutes
- WHEN rendering middle ring
- THEN ring shows progress toward workoutGoalMinutes
- AND fill percentage = min(1.0, actualMinutes / goalMinutes)
- AND color is purple gradient
- AND full ring indicates goal met

#### Scenario: NoAlc Fill (Inner)
- GIVEN day has NoAlc entry
- WHEN rendering inner fill
- THEN solid circle displays in center
- AND color matches consumption level:
  - Steady: #0EBF6E (green)
  - Easy: #89D6B2 (light green)
  - Wild: #B6B6B6 (gray)

#### Scenario: No Activity Day
- GIVEN day has no activity data
- WHEN rendering day cell
- THEN day number displays
- AND no rings appear
- AND cell appears empty/minimal

### Requirement: Day Detail Interaction
The system SHALL show details when user taps a day.

#### Scenario: Day Tap Opens Detail Sheet
- GIVEN calendar displays with activity data
- WHEN user taps on a day with activity
- THEN DayDetailSheet presents as modal
- AND shows date prominently
- AND lists all sessions for that day

#### Scenario: Day Detail Content
- GIVEN DayDetailSheet is open
- WHEN displaying day details
- THEN mindfulness total minutes show (with session list)
- AND workout total minutes show (with session list)
- AND NoAlc status shows (if entry exists)
- AND individual session times display

#### Scenario: Empty Day Tap
- GIVEN user taps a day with no activity
- WHEN tap occurs
- THEN DayDetailSheet still opens
- AND shows "No activity recorded" message
- AND allows user to add NoAlc entry

### Requirement: Streak Display
The system SHALL display current streaks for all activity types.

#### Scenario: Meditation Streak Display
- GIVEN user views calendar header area
- WHEN streaks are calculated
- THEN meditation streak count displays
- AND format is "🧘 X days"
- AND streak = consecutive days with ≥2 min mindfulness

#### Scenario: Workout Streak Display
- GIVEN user views calendar header area
- WHEN streaks are calculated
- THEN workout streak count displays
- AND format is "💪 X days"
- AND streak = consecutive days with ≥2 min workout

#### Scenario: NoAlc Streak Display
- GIVEN user views calendar header area
- WHEN NoAlc streak is calculated
- THEN streak count displays
- AND format is "🍀 X days (Y rewards)"
- AND uses forward chronological iteration
- AND shows available rewards count

#### Scenario: Streak Info Buttons
- GIVEN streak displays are visible
- WHEN user taps info button next to streak
- THEN InfoSheet explains streak rules
- AND describes minimum requirements
- AND explains reward system (for NoAlc)

### Requirement: Goal Progress Calculation
The system SHALL calculate progress based on configurable goals.

#### Scenario: Goal Configuration Source
- GIVEN calendar needs to calculate progress
- WHEN reading goal values
- THEN meditationGoalMinutes from AppStorage is used
- AND workoutGoalMinutes from AppStorage is used
- AND default values are 10 and 30 minutes respectively

#### Scenario: Progress Percentage Calculation
- GIVEN day has X minutes of activity
- AND goal is Y minutes
- WHEN calculating ring fill
- THEN percentage = min(1.0, X / Y)
- AND 100%+ shows as full ring (no overflow)

### Requirement: Data Loading
The system SHALL load activity data from HealthKit.

#### Scenario: Initial Data Load
- GIVEN user opens Calendar view
- WHEN view appears
- THEN HealthKit query executes for visible month
- AND loading state shows during fetch
- AND data populates rings when complete

#### Scenario: NoAlc Data Load
- GIVEN calendar loads activity data
- WHEN querying NoAlc entries
- THEN numberOfAlcoholicBeverages samples are fetched
- AND filtered by app source
- AND mapped to ConsumptionLevel

#### Scenario: Data Refresh
- GIVEN calendar is already displayed
- WHEN user pulls to refresh
- THEN fresh HealthKit query executes
- AND rings update with new data

#### Scenario: Load Error Handling
- GIVEN HealthKit query fails
- WHEN error occurs
- THEN error message displays
- AND cached data shows if available
- AND retry option is provided

### Requirement: NoAlc Quick Entry
The system SHALL allow quick NoAlc logging from calendar.

#### Scenario: NoAlc Entry from Day Tap
- GIVEN user taps a day in calendar
- WHEN DayDetailSheet opens
- THEN NoAlc entry buttons are accessible
- AND user can log Steady/Easy/Wild for that date

#### Scenario: NoAlc Log Success
- GIVEN user selects NoAlc level from detail sheet
- WHEN entry is saved
- THEN HealthKit sample is created for selected date
- AND calendar updates to show new entry
- AND detail sheet closes

## Technical Notes

- **Data Sources:** `HealthKitManager.fetchActivityDaysDetailedFiltered(forMonth:)` for rings
- **NoAlc Data:** Separate `NoAlcManager` query, stored as `alcoholDays` dictionary
- **Streak Calculation:** Forward iteration for NoAlc (see noalc-tracker.md)
- **Ring Sizing:** Hardcoded sizes (42, 32, 28) for consistent appearance
- **AppStorage Keys:** `meditationGoalMinutes`, `workoutGoalMinutes`, `calendarFilterEnabled`

Reference Standards:
- `.agent-os/standards/healthkit/date-semantics.md`
- `.agent-os/standards/healthkit/data-consistency.md`
