# Streaks & Rewards

## Overview

Streak tracking system that counts consecutive days of activity for meditation, workouts, NoAlc, and custom Trackers. Includes a reward system for NoAlc that provides "forgiveness" credits for occasional moderate days.

**Streak Types:**
- **Timer-based:** Meditation, Workout (consecutive days with ≥2 min activity)
- **Level-based:** NoAlc (consecutive Steady/healed Easy days with reward system)
- **Tracker-based:** Custom Trackers (consecutive days with log entry, optional per Tracker)

## Requirements

### Requirement: Streak Calculation for Meditation/Workout
The system SHALL calculate consecutive day streaks for meditation and workouts.

#### Scenario: Streak Definition
- GIVEN user has activity data in HealthKit
- WHEN calculating streak
- THEN streak = consecutive days with ≥2 minutes of activity
- AND days are counted from most recent backward
- AND minimum threshold is configurable (default 2 min)

#### Scenario: Streak Continues
- GIVEN current streak is X days
- AND user completes ≥2 min activity today
- WHEN streak is recalculated
- THEN streak becomes X+1 days

#### Scenario: Streak Breaks
- GIVEN current streak is X days
- AND yesterday had no activity (or <2 min)
- WHEN streak is recalculated
- THEN streak resets to count from most recent activity day

#### Scenario: Incomplete Today Grace
- GIVEN today has no activity yet
- AND yesterday had activity
- WHEN calculating streak
- THEN streak counts from yesterday (don't penalize incomplete today)
- AND streak shows "X days" without breaking

#### Scenario: Separate Streaks
- GIVEN user has both meditation and workout data
- WHEN displaying streaks
- THEN meditation streak is calculated separately
- AND workout streak is calculated separately
- AND each uses its own activity type data

### Requirement: NoAlc Streak with Reward System
The system SHALL calculate NoAlc streaks with reward-based forgiveness.

#### Scenario: NoAlc Streak Definition
- GIVEN user has NoAlc entries
- WHEN calculating streak
- THEN streak = consecutive days with Steady or healed Easy entries
- AND Wild entries always break streak

#### Scenario: Reward Earning
- GIVEN user has active NoAlc streak
- AND 7 consecutive Steady days are reached
- WHEN milestone is reached
- THEN 1 reward is earned
- AND rewards cap at 3 maximum
- AND reward milestone resets (next reward at day 14)

#### Scenario: Reward Usage (Healing)
- GIVEN user has Easy day entry
- AND available rewards > 0
- WHEN streak is calculated
- THEN 1 reward is consumed
- AND streak continues (Easy day is "healed")
- AND available rewards decrease by 1

#### Scenario: No Reward Available
- GIVEN user has Easy day entry
- AND available rewards = 0
- WHEN streak is calculated
- THEN streak breaks
- AND streak counter resets

#### Scenario: Wild Day Always Breaks
- GIVEN user has Wild day entry
- WHEN streak is calculated
- THEN streak breaks immediately
- AND rewards are NOT consumed for Wild
- AND reward count decreases by 1 (penalty)

### Requirement: Custom Tracker Streaks
The system SHALL calculate streaks for custom Trackers when enabled.

#### Scenario: Tracker Streak Definition
- GIVEN Tracker has "Enable Streak" setting ON
- WHEN calculating streak
- THEN streak = consecutive days with at least 1 TrackerLog entry
- AND days are counted from most recent backward
- AND no minimum duration (any log counts)

#### Scenario: Tracker Streak Continues
- GIVEN Tracker streak is X days
- AND user logs Tracker today
- WHEN streak is recalculated
- THEN streak becomes X+1 days

#### Scenario: Tracker Streak Breaks
- GIVEN Tracker streak is X days
- AND yesterday had no TrackerLog
- WHEN streak is recalculated
- THEN streak resets to count from most recent log day

#### Scenario: Awareness Tracker Streak Logic
- GIVEN Tracker is Awareness type (Stimmung, Gefühle, Dankbarkeit)
- WHEN checking if day counts toward streak
- THEN ANY log entry counts (regardless of selected value)
- AND it's about "did I reflect today" not "what did I reflect"

#### Scenario: Saboteur Tracker Streak (Awareness Mode)
- GIVEN Saboteur Tracker is in Awareness mode
- AND streak is enabled
- WHEN calculating streak
- THEN streak counts consecutive days of noticing
- AND it's about awareness, not avoidance
- AND no judgment on number of times noticed

#### Scenario: Saboteur Tracker Streak (Avoidance Mode)
- GIVEN Saboteur Tracker is in Avoidance mode
- AND streak is enabled
- WHEN calculating streak
- THEN streak = consecutive days with ZERO logs
- AND any log breaks the streak
- AND this is the "traditional" habit-breaking approach

#### Scenario: Tracker Streak Configuration
- GIVEN user is editing a Tracker
- WHEN viewing settings
- THEN "Enable Streak" toggle is available
- AND default is ON for Awareness Trackers
- AND default is OFF for Activity Trackers (Wasser)

### Requirement: Forward Chronological Iteration
The system SHALL iterate forward (past → present) for NoAlc streak calculation.

#### Scenario: Why Forward Iteration
- GIVEN streak data spans multiple days
- WHEN calculating rewards and streak
- THEN iterate from earliest date to today
- AND earn rewards chronologically as milestones are reached
- AND consume rewards after they are earned

#### Scenario: Backward Iteration Bug
- GIVEN backwards iteration is used
- WHEN processing Easy day before reward-earning days
- THEN rewards appear as 0 (not yet counted)
- AND healing fails incorrectly
- THEREFORE forward iteration is REQUIRED

### Requirement: Streak Data Persistence
The system SHALL persist streak data.

#### Scenario: Data Model
- GIVEN streak is calculated
- WHEN storing to persistence
- THEN StreakData contains:
  - currentStreakDays: Int
  - rewardsEarned: Int (max 3)
  - lastActivityDate: Date?

#### Scenario: UserDefaults Storage
- GIVEN streak is updated
- WHEN saving
- THEN JSON-encoded StreakData is saved to UserDefaults
- AND key is "meditationStreak" or "workoutStreak"

#### Scenario: Data Load on Launch
- GIVEN app launches
- WHEN StreakManager initializes
- THEN persisted streak data is loaded
- AND displayed immediately (cached)
- AND fresh calculation updates if needed

### Requirement: Streak Display
The system SHALL display streak information in UI.

#### Scenario: Achievements Tab Header Display
- GIVEN user views Achievements Tab (Erfolge)
- WHEN header renders
- THEN meditation streak shows with 🧘 emoji
- AND workout streak shows with 💪 emoji
- AND NoAlc streak shows with 🍀 emoji and reward count
- AND available rewards show with ⭐ emoji

#### Scenario: Custom Tracker Streaks Display
- GIVEN user has Trackers with streaks enabled
- WHEN viewing streak overview (expandable section)
- THEN each enabled Tracker streak displays
- AND format: "[Tracker Icon] [X days]"
- AND sorted by streak length (longest first)

#### Scenario: Reward Visual Indicator
- GIVEN NoAlc streak has rewards
- WHEN displaying streak
- THEN reward count is visible (e.g., "🍀 14 days (2 rewards)")
- AND rewards are shown as badges or dots

#### Scenario: Zero Streak Display
- GIVEN user has no active streak
- WHEN displaying
- THEN "0 days" shows
- AND no rewards display

### Requirement: Streak Update Triggers
The system SHALL update streaks at appropriate times.

#### Scenario: Update After Activity Logged
- GIVEN user completes meditation/workout
- WHEN activity is logged to HealthKit
- THEN `StreakManager.updateStreaks()` is called
- AND displayed streak updates

#### Scenario: Update on Calendar Open
- GIVEN user opens Calendar view
- WHEN view appears
- THEN streaks are recalculated from HealthKit
- AND display updates with fresh data

#### Scenario: Batch Update
- GIVEN streak update is triggered
- WHEN updateStreaks() runs
- THEN fetches last 30 days of activity
- AND calculates current streak
- AND calculates reward count (for NoAlc)

### Requirement: Minimum Activity Threshold
The system SHALL enforce minimum activity duration for streak eligibility.

#### Scenario: Minimum 2 Minutes
- GIVEN activity is logged
- AND duration < 2 minutes
- WHEN streak is calculated
- THEN day does NOT count toward streak
- AND is treated as no activity

#### Scenario: Round to Nearest Minute
- GIVEN activity duration is 1.8 minutes
- WHEN checking threshold
- THEN round(1.8) = 2 minutes
- AND day DOES count toward streak

## Technical Notes

- **StreakManager:** Singleton service with `@Published` properties for reactive updates
- **CalendarView Calculation:** Inline calculation using `calculateNoAlcStreakAndRewards()` for NoAlc
- **HealthKit Query:** Uses `fetchDailyMinutesFiltered(from:to:)` with tomorrow as endDate
- **Tracker Query:** SwiftData query for `TrackerLog` grouped by date
- **Forward Iteration:** CRITICAL for NoAlc - see CLAUDE.md "Forward vs. Backward Iteration"
- **Threshold:** `minMinutes = 2` is configurable constant in StreakManager (not for Trackers)
- **Tracker Streak Storage:** Stored in SwiftData as part of Tracker model

Reference Standards:
- `.agent-os/standards/healthkit/date-semantics.md` (Forward Iteration)
- `.agent-os/standards/healthkit/data-consistency.md`

---

## References

- `openspec/specs/app-vision.md` - "Motivation durch Sichtbarkeit" design principle
- `openspec/specs/features/calendar-view.md` - Streak header display in Achievements Tab
- `openspec/specs/features/trackers.md` - Tracker streak configuration
- `openspec/specs/features/noalc-tracker.md` - NoAlc reward system details
