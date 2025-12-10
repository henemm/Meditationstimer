# Live Activities Integration

## Overview

Dynamic Island and Lock Screen activity support for active timers.

## Requirements

### Requirement: Single Activity
The system SHALL manage single activity at a time.

#### Scenario: Activity Ownership
- WHEN new activity starts
- THEN previous activity ends
- AND ownership transfers to new tab

### Requirement: Activity Display
The system SHALL show relevant information.

#### Scenario: Compact Display (Dynamic Island)
- WHEN activity is active
- THEN remaining time is shown
- AND phase indicator is visible

#### Scenario: Expanded Display (Lock Screen)
- WHEN user expands activity
- THEN full timer is shown
- AND pause/resume controls available

### Requirement: State Updates
The system SHALL update activity state.

#### Scenario: Timer Progress
- WHEN timer ticks
- THEN Live Activity updates
- AND remaining time decreases

#### Scenario: Pause State
- WHEN timer is paused
- THEN Live Activity shows paused state
- AND time freezes

### Requirement: Activity Lifecycle
The system SHALL manage activity lifecycle.

#### Scenario: Activity End
- WHEN session completes
- THEN Live Activity ends
- AND dismisses from Dynamic Island

## Technical Notes

- LiveActivityController is singleton via @EnvironmentObject
- Ownership model tracks which tab owns current activity
- Conflict resolution: auto-ends conflicting activities
- Requires iOS 16.1+ (Dynamic Island on physical devices)
