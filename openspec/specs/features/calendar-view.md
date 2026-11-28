# Calendar View

## Overview

Monthly calendar view displaying activity history with concentric ring visualization. Located in the **Achievements Tab / Erfolge** (4th tab), serves as the central dashboard for viewing progress, streaks, and rewards.

**Visualization Logic:**
- **Outer Rings** = Timer-based activities (Meditation, Workout) - show progress toward daily goal
- **Inner Fill** = NoAlc level (color-coded by consumption level)
- **Habit Strip** (above the calendar, #50) = one card per ongoing habit (tracker with "Show in Calendar"); tapping a card marks its entry days in the calendar

**Core Insight:** Timer-based activities show HOW MUCH (progress rings); habits show WHETHER (entered or not) in the strip, not in the day cell.

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
The system SHALL display concentric rings for timer-based activities and the NoAlc fill in the center.

#### Scenario: Ring Layering Order
- GIVEN calendar day has activity data
- WHEN rendering day cell
- THEN visualization displays in this order (outside to inside):
  1. **Outer Ring:** Mindfulness ring (42x42 points, blue)
  2. **Middle Ring:** Workout ring (32x32 points, purple)
  3. **Inner Fill:** NoAlc level (28x28 points, color by level)
  - Behind all layers: habit marking (48x48 points, habit color at 20 % opacity), only while a habit card is selected (see Habit Strip)

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
- AND tracker entries show (habits section, #47)
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

### Requirement: Habit Strip (#50)
The system SHALL show a strip of habit cards above the month list.

#### Scenario: Strip Content
- GIVEN active trackers with "Show in Calendar" on (NoAlc never; it stays the inner fill)
- WHEN the Achievements tab is shown
- THEN one card per tracker appears above the month list (order: displayOrder, createdAt, name)
- AND each card shows icon, name (bold), "ongoing" (small, uppercase, muted), "Streak N days" and seven dots for the last seven days (oldest left, today right): entered = filled, open = grey outline, today without entry = thick outline in habit color
- AND with more than three cards the strip is limited to the height of three cards and scrolls
- AND without such a tracker there is no strip and no empty space
- AND `calendarFilterEnabled` does not affect the strip

#### Scenario: Selecting a Card
- GIVEN the strip is visible
- WHEN the user taps a card
- THEN it is selected (border in habit color) and every day with an entry of this habit gets a faint circle (habit color, 20 %, 48 pt) behind the day rings
- AND tapping it again removes selection and marking; tapping another card switches the selection (at most one)
- AND the selection is view state only (not persisted); rings, fill, day tap and detail sheet stay unchanged

#### Scenario: Entry Days
- GIVEN a tracker log
- WHEN its day is determined
- THEN `effectiveDayAssignment.assignedDay(for:)` is applied exactly once (no second cutoffHour shift)

Habit color: `#d6457a` (light), `#f06d9c` (dark). Accessibility: strip `calendar.habitStrip`, card `calendar.habit.card` (accessibilityValue "ausgewählt" when selected, localized), marked day cell accessibilityValue "markiert" (localized).

---

## Visual Mockup

### Day Cell Structure
```
      ┌─────────────────────┐
      │   ╭───────────╮     │
      │  ╱   ╭─────╮   ╲    │  ← Outer: Meditation Ring (blue, progress)
      │ │   ╱ ╭───╮ ╲   │   │  ← Middle: Workout Ring (purple, progress)
      │ │  │ ╱ ╭─╮ ╲ │  │   │  ← Inner: NoAlc Fill (green/gray, level)
      │ │  │ │ │ │ │ │  │   │
      │ │  │ ╲ ╰─╯ ╱ │  │   │
      │ │   ╲ ╰───╯ ╱   │   │
      │  ╲   ╰─────╯   ╱    │
      │   ╰───────────╯     │
      │        14           │  ← Day number
      └─────────────────────┘
```

---

## Technical Notes

- **Data Sources:** `HealthKitManager.fetchActivityDaysDetailedFiltered(forMonth:)` for rings
- **NoAlc Data:** Separate `NoAlcManager` query, stored as `alcoholDays` dictionary
- **Tracker Data:** SwiftData query for TrackerLogs by date
- **Habit Strip:** SwiftData `Tracker.showInCalendar` field; logic in `Services/HabitStrip.swift`, view `HabitStripView`
- **Streak Calculation:** Forward iteration for NoAlc (see noalc-tracker.md)
- **Ring Sizing:** Hardcoded sizes (42, 32, 28; habit marking 48) for consistent appearance
- **AppStorage Keys:** `meditationGoalMinutes`, `workoutGoalMinutes`, `calendarFilterEnabled`

Reference Standards:
- `.agent-os/standards/healthkit/date-semantics.md`
- `.agent-os/standards/healthkit/data-consistency.md`

---

## References

- `openspec/specs/app-vision.md` - Achievements Tab location (4th tab)
- `openspec/specs/features/app-navigation.md` - Tab structure
- `openspec/specs/features/trackers.md` - Tracker concept
- `DOCS/specs/features/feature-50-gewohnheiten-leiste.md` - Habit Strip
- `openspec/specs/features/noalc-tracker.md` - NoAlc visualization
- `openspec/specs/features/streaks-rewards.md` - Streak calculation
