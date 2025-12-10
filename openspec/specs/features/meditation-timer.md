# Meditation Timer (Offen-Tab)

## Overview

Two-phase meditation timer with customizable durations, audio cues, and HealthKit logging.

## Requirements

### Requirement: Two-Phase Timer
The system SHALL provide a meditation timer with two sequential phases.

#### Scenario: Phase 1 (Meditation)
- WHEN user starts meditation
- THEN timer begins Phase 1 countdown
- AND start gong plays
- AND Live Activity shows "Phase 1"

#### Scenario: Phase 2 (Reflection)
- WHEN Phase 1 completes
- THEN transition gong plays (gong-dreimal)
- AND Phase 2 countdown begins
- AND Live Activity updates to "Phase 2"

#### Scenario: Session End
- WHEN Phase 2 completes
- THEN end gong plays (gong-Ende)
- AND session is logged to HealthKit (Phase 1 duration only)
- AND Live Activity ends

### Requirement: Timer Configuration
The system SHALL allow users to configure timer duration.

#### Scenario: Duration Selection
- GIVEN user is on Offen-Tab
- WHEN user adjusts time picker
- THEN Phase 1 duration changes
- AND Phase 2 remains at 3 minutes (fixed)

### Requirement: Audio Cues
The system SHALL play audio cues at key moments.

#### Scenario: Gong Sequence
| Event | Audio File |
|-------|------------|
| Session start | gong.mp3 |
| Phase transition | gong-dreimal.mp3 |
| Session end | gong-Ende.mp3 |

### Requirement: HealthKit Integration
The system SHALL log completed sessions to HealthKit.

#### Scenario: Mindfulness Logging
- WHEN session completes normally
- THEN Phase 1 duration is logged as HKCategoryTypeIdentifier.mindfulSession
- AND data is filterable by app source

### Requirement: Live Activity
The system SHALL display progress on Dynamic Island and Lock Screen.

#### Scenario: Live Activity Display
- WHEN session is active
- THEN Live Activity shows remaining time
- AND phase indicator
- AND pause state

## Technical Notes

- Timer uses date-based calculation (survives backgrounding)
- Only Phase 1 logged to HealthKit (reflection is not meditation)
- Minimum 2 minutes for streak eligibility
