# Live Activities Integration

## Overview

Dynamic Island and Lock Screen activity support for active timers. Provides at-a-glance progress information without requiring the app to be in foreground.

## Requirements

### Requirement: Single Activity Management
The system SHALL manage exactly one Live Activity at a time.

#### Scenario: Activity Ownership Transfer
- GIVEN Live Activity is active for Tab A
- WHEN user starts activity on Tab B
- THEN Tab A's activity ends immediately
- AND Tab B's activity starts
- AND ownership transfers to Tab B

#### Scenario: Ownership Tracking
- GIVEN Live Activity is active
- WHEN checking ownership
- THEN `LiveActivityController` knows which tab owns it
- AND owner can update/end activity
- AND non-owners cannot modify

#### Scenario: No Concurrent Activities
- GIVEN meditation is running on Offen-Tab
- AND workout is started on Workout-Tab
- WHEN new activity starts
- THEN only ONE activity is ever active
- AND previous is ended before new starts

### Requirement: Activity Display
The system SHALL show relevant information on Dynamic Island and Lock Screen.

#### Scenario: Compact Display (Dynamic Island - Minimal)
- GIVEN Live Activity is active
- WHEN Dynamic Island shows minimal view
- THEN app icon/indicator is visible
- AND remaining time may show if space permits

#### Scenario: Compact Display (Dynamic Island - Leading/Trailing)
- GIVEN Live Activity is active
- WHEN Dynamic Island shows leading/trailing view
- THEN remaining time displays in MM:SS format
- AND phase indicator is visible (Phase 1/2, Work/Rest)

#### Scenario: Expanded Display (Dynamic Island Tap)
- GIVEN user taps Dynamic Island
- WHEN expanded view appears
- THEN full timer information shows
- AND session title/name displays
- AND progress visualization is visible

#### Scenario: Lock Screen Display
- GIVEN Live Activity is active
- AND device is locked
- WHEN Lock Screen shows activity
- THEN remaining time displays prominently
- AND phase indicator shows
- AND activity title shows

#### Scenario: Timer Format
- GIVEN timer is running
- WHEN displaying remaining time
- THEN format is MM:SS (e.g., "14:32")
- AND updates every second
- AND shows "00:00" at completion (briefly)

### Requirement: State Updates
The system SHALL keep Live Activity synchronized with timer state.

#### Scenario: Timer Progress Update
- GIVEN Live Activity is displaying
- WHEN timer ticks (every second)
- THEN Live Activity updates remaining time
- AND uses ContentState update mechanism

#### Scenario: Phase Transition Update
- GIVEN timer transitions between phases
- WHEN phase changes (Phase 1 → 2, Work → Rest)
- THEN Live Activity updates phase indicator
- AND remaining time updates to new phase duration

#### Scenario: Pause State Display
- GIVEN timer is paused
- WHEN pause occurs
- THEN Live Activity shows pause indicator
- AND remaining time freezes
- AND visual indicates paused state (e.g., pause icon)

#### Scenario: Resume State Display
- GIVEN timer was paused
- WHEN user resumes
- THEN pause indicator removes
- AND countdown resumes
- AND remaining time begins decreasing again

### Requirement: Activity Lifecycle
The system SHALL properly manage activity start and end.

#### Scenario: Activity Start
- GIVEN user starts timer
- AND Live Activities are authorized
- WHEN session begins
- THEN Live Activity is requested via ActivityKit
- AND attributes include session info (title, total duration)
- AND initial ContentState includes remaining time, phase

#### Scenario: Activity End (Normal Completion)
- GIVEN session completes normally
- WHEN timer reaches end
- THEN Live Activity ends
- AND dismisses from Dynamic Island
- AND removes from Lock Screen

#### Scenario: Activity End (Manual Stop)
- GIVEN user stops session manually
- WHEN stop is triggered
- THEN Live Activity ends immediately
- AND no lingering activity remains

#### Scenario: Activity End (App Termination)
- GIVEN app is terminated while activity is running
- WHEN termination occurs
- THEN Live Activity ends (best effort)
- AND stale activities are cleaned up on next launch

### Requirement: Authorization Handling
The system SHALL handle Live Activity authorization appropriately.

#### Scenario: Authorization Check
- GIVEN app wants to start Live Activity
- WHEN checking authorization
- THEN ActivityAuthorizationInfo is consulted
- AND activity only starts if authorized

#### Scenario: Not Authorized
- GIVEN Live Activities are not authorized
- WHEN timer starts
- THEN timer functions normally
- AND no Live Activity is created
- AND no error is shown to user

#### Scenario: Authorization Changed
- GIVEN user enables/disables Live Activities in Settings
- WHEN authorization changes
- THEN next timer start respects new setting
- AND existing activity may end if disabled

### Requirement: Conflict Resolution
The system SHALL resolve conflicts when multiple tabs compete.

#### Scenario: First-Come Priority
- GIVEN no active Live Activity
- WHEN Tab A starts activity
- THEN Tab A owns the activity
- AND Tab A can update/end it

#### Scenario: New Activity Wins
- GIVEN Tab A owns active Live Activity
- WHEN Tab B starts new timer
- THEN Tab A's activity ends
- AND Tab B's activity starts
- AND Tab B now owns activity

#### Scenario: Owner Identification
- GIVEN Live Activity is active
- WHEN determining owner
- THEN ownerId property identifies owning tab
- AND tabs can check if they own current activity

### Requirement: Background Behavior
The system SHALL function correctly when app is backgrounded.

#### Scenario: App Backgrounded
- GIVEN timer is running with Live Activity
- WHEN app moves to background
- THEN Live Activity remains visible
- AND countdown continues (date-based calculation)
- AND updates may reduce in frequency

#### Scenario: App Foregrounded
- GIVEN app returns to foreground
- WHEN app becomes active
- THEN Live Activity syncs with current time
- AND display matches actual remaining time

## Technical Notes

- **Controller:** `LiveActivityController` is singleton, injected via `@EnvironmentObject`
- **Attributes:** `MeditationActivityAttributes` defines static and dynamic content
- **ContentState:** Updated via `Activity.update(using:)` for state changes
- **Ownership Model:** `ownerId` property tracks which tab owns current activity
- **iOS Requirement:** Requires iOS 16.1+ (Dynamic Island on iPhone 14 Pro+)
- **Timer Calculation:** Uses date-based remaining time (survives background)

Reference Standards:
- `.agent-os/standards/swiftui/lifecycle-patterns.md`
