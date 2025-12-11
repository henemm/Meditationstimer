# Widget Extension

## Overview

WidgetKit extension providing Live Activity support for active sessions. Home Screen widget is **not yet developed** (placeholder only).

**Status:** Live Activity functional, Home Screen Widget placeholder only.

## Requirements

### Requirement: Live Activity Display
The system SHALL provide Live Activity for active meditation/workout sessions.

#### Scenario: Live Activity Widget Content
- GIVEN Live Activity is requested from main app
- WHEN Live Activity displays
- THEN MeditationstimerWidgetLiveActivity view renders
- AND remaining time shows prominently
- AND phase indicator is visible
- AND session title displays

#### Scenario: Dynamic Island Compact View
- GIVEN Live Activity is active
- WHEN Dynamic Island shows compact view
- THEN minimal information displays (time, icon)
- AND fits in Dynamic Island pill shape

#### Scenario: Dynamic Island Expanded View
- GIVEN user taps Dynamic Island
- WHEN expanded view shows
- THEN full session information displays
- AND progress visualization is visible
- AND remaining time is prominent

#### Scenario: Lock Screen Widget
- GIVEN Live Activity is active
- WHEN device is locked
- THEN Lock Screen widget shows
- AND timer information is visible
- AND updates in real-time

### Requirement: Live Activity Updates
The system SHALL update Live Activity state from main app.

#### Scenario: Timer Update
- GIVEN Live Activity is displaying
- WHEN main app updates ContentState
- THEN displayed time updates
- AND phase indicator updates if changed

#### Scenario: Pause State Update
- GIVEN user pauses session in main app
- WHEN ContentState updates with isPaused=true
- THEN Live Activity shows paused state
- AND time freezes

#### Scenario: Activity End
- GIVEN session completes or is cancelled
- WHEN main app ends Live Activity
- THEN widget dismisses from Dynamic Island
- AND removes from Lock Screen

### Requirement: Live Activity Attributes
The system SHALL use MeditationActivityAttributes for Live Activity.

#### Scenario: Attribute Structure
- GIVEN Live Activity is created
- WHEN defining attributes
- THEN MeditationActivityAttributes contains:
  - sessionTitle: String (static)
  - ContentState with: remainingSeconds, phase, isPaused (dynamic)

#### Scenario: Content State Updates
- GIVEN Live Activity is running
- WHEN state changes
- THEN only ContentState is updated (not attributes)
- AND updates happen via Activity.update(using:)

### Requirement: Home Screen Widget (NOT IMPLEMENTED)
The Home Screen widget is **placeholder only** - not yet developed.

#### Scenario: Current State (Placeholder)
- GIVEN user adds widget to Home Screen
- WHEN widget displays
- THEN only placeholder content shows (emoji + time)
- AND no real app data is displayed
- AND this is a **future development** item

### Requirement: Widget Timeline
The system SHALL provide timeline entries for widget updates.

#### Scenario: Timeline Generation
- GIVEN widget needs content
- WHEN timeline is requested
- THEN Provider generates timeline entries
- AND entries are spaced appropriately (hourly default)

#### Scenario: Timeline Refresh Policy
- GIVEN timeline is generated
- WHEN setting refresh policy
- THEN .atEnd policy is used
- AND widget refreshes after last entry

### Requirement: Widget Bundle
The system SHALL bundle multiple widget types.

#### Scenario: Bundle Contents
- GIVEN app widget bundle is queried
- WHEN listing available widgets
- THEN MeditationstimerWidgetBundle provides:
  - MeditationstimerWidget (static Home Screen)
  - MeditationstimerWidgetLiveActivity (Live Activity)
  - MeditationstimerWidgetControl (Control Center, iOS 18+)

### Requirement: Control Center Widget (iOS 18+)
The system SHALL provide Control Center widget on iOS 18+.

#### Scenario: Control Widget Display
- GIVEN iOS 18+ device
- WHEN user adds Control Center widget
- THEN MeditationstimerWidgetControl is available
- AND provides quick access to app functions

## Technical Notes

- **Live Activity:** Uses ActivityKit with `Activity<MeditationActivityAttributes>`
- **Widget Provider:** `AppIntentTimelineProvider` for modern configuration
- **Bundle:** `MeditationstimerWidgetBundle` with `@main` entry point
- **Attributes File:** `MeditationActivityAttributes.swift` shared with main app
- **Timer Logic:** `LiveActivityTimerLogic.swift` for countdown calculations

Reference Standards:
- `.agent-os/standards/swiftui/lifecycle-patterns.md`
