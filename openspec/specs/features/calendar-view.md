# Calendar View

## Overview

Monthly calendar view displaying activity history with concentric ring visualization. Located in the **Achievements Tab / Erfolge** (4th tab), serves as the central dashboard for viewing progress, streaks, and rewards.

**Visualization Logic:**
- **Outer Rings** = Timer-based activities (Meditation, Workout) - show progress toward daily goal
- **Inner Fill** = NoAlc level (color-coded by consumption level)
- **Center Segments** = Tracker awareness (did user reflect today?) - segmented by Focus Trackers

**Core Insight:** Timer-based activities show HOW MUCH (progress rings), while Awareness Trackers show WHETHER (reflected or not).

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
The system SHALL display concentric rings for timer-based activities and segmented center for awareness trackers.

#### Scenario: Ring Layering Order
- GIVEN calendar day has activity data
- WHEN rendering day cell
- THEN visualization displays in this order (outside to inside):
  1. **Outer Ring:** Mindfulness ring (42x42 points, blue)
  2. **Middle Ring:** Workout ring (32x32 points, purple)
  3. **Inner Fill:** NoAlc level (28x28 points, color by level)
  4. **Center Segments:** Focus Trackers (20x20 points, segmented)

#### Scenario: Mindfulness Ring (Outer) - Timer-Based
- GIVEN day has mindfulness minutes
- WHEN rendering outer ring
- THEN ring shows progress toward meditationGoalMinutes
- AND fill percentage = min(1.0, actualMinutes / goalMinutes)
- AND color is blue gradient
- AND full ring indicates goal met

#### Scenario: Workout Ring (Middle) - Timer-Based
- GIVEN day has workout minutes
- WHEN rendering middle ring
- THEN ring shows progress toward workoutGoalMinutes
- AND fill percentage = min(1.0, actualMinutes / goalMinutes)
- AND color is purple gradient
- AND full ring indicates goal met

#### Scenario: NoAlc Fill (Inner) - Level-Based
- GIVEN day has NoAlc entry
- WHEN rendering inner fill
- THEN solid circle displays in center
- AND color matches consumption level:
  - Steady: #0EBF6E (green)
  - Easy: #89D6B2 (light green)
  - Wild: #B6B6B6 (gray)

#### Scenario: Focus Tracker Segments (Center) - Awareness-Based
- GIVEN user has configured Focus Trackers (max 2)
- AND day has tracker logs
- WHEN rendering center area
- THEN center is divided into segments (1-2 based on Focus Tracker count)
- AND each segment shows: filled (reflected) or empty (not reflected)
- AND segment color matches tracker icon color
- AND single unified color when reflected (no quality gradient)

#### Scenario: Focus Tracker - Single Tracker
- GIVEN user has 1 Focus Tracker configured
- WHEN rendering center
- THEN center shows single circle (not segmented)
- AND filled = reflected today, empty = not yet

#### Scenario: Focus Tracker - Two Trackers
- GIVEN user has 2 Focus Trackers configured
- WHEN rendering center
- THEN center is split into 2 half-circles (left/right or top/bottom)
- AND each half independently shows reflected/not reflected

#### Scenario: No Focus Tracker Configured
- GIVEN user has NOT configured any Focus Trackers
- WHEN rendering center
- THEN center shows only NoAlc fill (if logged)
- AND no additional segmentation

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
- AND Tracker awareness logs show (if any Focus Trackers logged)
- AND individual session times display

#### Scenario: Day Detail - Tracker Section
- GIVEN DayDetailSheet is open
- AND day has tracker logs
- WHEN displaying tracker section
- THEN shows each logged tracker with:
  - Icon + Name
  - What was logged (e.g., "😌 Entspannt" for Mood)
  - Timestamp of reflection
- AND non-judgmental presentation

#### Scenario: Empty Day Tap
- GIVEN user taps a day with no activity
- WHEN tap occurs
- THEN DayDetailSheet still opens
- AND shows "Keine Aktivität" / "No activity" message
- AND allows user to add NoAlc entry
- AND allows user to add missed tracker reflection (backlog)

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

### Requirement: Focus Tracker Configuration
The system SHALL allow users to select which trackers appear as Focus Trackers in the calendar.

#### Scenario: Focus Tracker Selection
- GIVEN user is editing a Tracker in app
- WHEN viewing tracker settings
- THEN "Show in Calendar" toggle is available
- AND maximum 2 trackers can be enabled as Focus Trackers
- AND setting persists to SwiftData

#### Scenario: Focus Tracker Limit
- GIVEN user has 2 Focus Trackers enabled
- WHEN user tries to enable a 3rd tracker for calendar
- THEN warning appears: "Maximum 2 Focus Trackers allowed"
- AND user must disable one before enabling another

#### Scenario: Default Focus Trackers
- GIVEN user has created new trackers
- WHEN "Show in Calendar" default is applied
- THEN default is OFF
- AND user explicitly chooses which trackers to focus on

---

## Visual Mockup

### Day Cell Structure
```
      ┌─────────────────────┐
      │   ╭───────────╮     │
      │  ╱   ╭─────╮   ╲    │  ← Outer: Meditation Ring (blue, progress)
      │ │   ╱ ╭───╮ ╲   │   │  ← Middle: Workout Ring (purple, progress)
      │ │  │ ╱ ╭─╮ ╲ │  │   │  ← Inner: NoAlc Fill (green/gray, level)
      │ │  │ │ │●│ │ │  │   │  ← Center: Focus Trackers (segmented)
      │ │  │ ╲ ╰─╯ ╱ │  │   │
      │ │   ╲ ╰───╯ ╱   │   │
      │  ╲   ╰─────╯   ╱    │
      │   ╰───────────╯     │
      │        14           │  ← Day number
      └─────────────────────┘
```

### Focus Tracker Segmentation
```
┌────────────────────────────────────────┐
│ 0 Focus Trackers    1 Focus Tracker    │
│                                        │
│     ╭───╮              ╭───╮           │
│    │ ○ │             │ ● │           │  ← Single circle
│     ╰───╯              ╰───╯           │
│   (just NoAlc)     (filled if logged)  │
│                                        │
├────────────────────────────────────────┤
│ 2 Focus Trackers                       │
│                                        │
│     ╭───╮              ╭───╮           │
│    │◐ │             │● │           │  ← Split: left/right
│     ╰───╯              ╰───╯           │
│   (1 of 2 logged)  (both logged)       │
└────────────────────────────────────────┘
```

---

## Technical Notes

- **Data Sources:** `HealthKitManager.fetchActivityDaysDetailedFiltered(forMonth:)` for rings
- **NoAlc Data:** Separate `NoAlcManager` query, stored as `alcoholDays` dictionary
- **Tracker Data:** SwiftData query for TrackerLogs by date
- **Focus Tracker Config:** SwiftData `Tracker.showInCalendar` field
- **Streak Calculation:** Forward iteration for NoAlc (see noalc-tracker.md)
- **Ring Sizing:** Hardcoded sizes (42, 32, 28, 20) for consistent appearance
- **AppStorage Keys:** `meditationGoalMinutes`, `workoutGoalMinutes`, `calendarFilterEnabled`

Reference Standards:
- `.agent-os/standards/healthkit/date-semantics.md`
- `.agent-os/standards/healthkit/data-consistency.md`

---

## References

- `openspec/specs/app-vision.md` - Achievements Tab location (4th tab)
- `openspec/specs/features/app-navigation.md` - Tab structure
- `openspec/specs/features/trackers.md` - Focus Tracker concept
- `openspec/specs/features/noalc-tracker.md` - NoAlc visualization
- `openspec/specs/features/streaks-rewards.md` - Streak calculation
