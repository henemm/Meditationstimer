# Meditation Timer (Offen-Tab)

## Overview

Two-phase meditation timer with customizable durations, audio cues, HealthKit logging, and Live Activity support. The timer runs in foreground-only mode to avoid iOS background execution limits.

## Requirements

### Requirement: Two-Phase Timer
The system SHALL provide a meditation timer with two sequential phases.

#### Scenario: Start Phase 1 (Meditation)
- GIVEN user is on Offen-Tab
- AND timer is in idle state
- WHEN user taps "Start" button
- THEN timer transitions to Phase 1 state
- AND countdown begins from configured Phase 1 duration
- AND start gong plays (gong.caf)
- AND Live Activity starts showing "Phase 1"

#### Scenario: Phase Transition to Phase 2 (Reflection)
- GIVEN timer is in Phase 1 state
- AND Phase 1 countdown reaches 0
- WHEN phase transition occurs
- THEN transition gong plays (gong-dreimal.caf)
- AND timer transitions to Phase 2 state
- AND countdown begins from fixed 3 minutes
- AND Live Activity updates to "Phase 2"

#### Scenario: Session Completion
- GIVEN timer is in Phase 2 state
- AND Phase 2 countdown reaches 0
- WHEN session completes
- THEN end gong plays (gong-Ende.caf)
- AND timer transitions to finished state
- AND Live Activity ends
- AND Phase 1 duration is logged to HealthKit

#### Scenario: Manual Cancellation
- GIVEN timer is in Phase 1 or Phase 2 state
- WHEN user taps "Stop" button
- THEN timer transitions to idle state
- AND no gong plays
- AND Live Activity ends immediately
- AND no HealthKit logging occurs

#### Scenario: App Termination During Session
- GIVEN timer is running (Phase 1 or Phase 2)
- WHEN app is terminated by user or system
- THEN timer cancels automatically
- AND no HealthKit logging occurs
- AND Live Activity ends

### Requirement: Timer Configuration
The system SHALL allow users to configure Phase 1 duration.

#### Scenario: Duration Selection
- GIVEN user is on Offen-Tab
- AND timer is in idle state
- WHEN user adjusts time picker wheel
- THEN Phase 1 duration updates (1-60 minutes)
- AND duration is persisted to AppStorage

#### Scenario: Fixed Phase 2 Duration
- GIVEN any timer state
- WHEN Phase 1 duration is configured
- THEN Phase 2 remains fixed at 3 minutes
- AND Phase 2 is not user-configurable

### Requirement: Audio Cues
The system SHALL play audio cues at key moments during meditation.

#### Scenario: Start Gong Playback
- GIVEN user taps "Start" button
- WHEN meditation session begins
- THEN gong.caf plays once
- AND audio mixes with other apps (mixWithOthers option)

#### Scenario: Transition Gong Playback
- GIVEN Phase 1 completes
- WHEN transitioning to Phase 2
- THEN gong-dreimal.caf plays (triple gong)
- AND playback completes before Phase 2 timer starts visually

#### Scenario: End Gong Playback
- GIVEN Phase 2 completes
- WHEN session ends
- THEN gong-Ende.caf plays completely
- AND ambient sound stops AFTER gong finishes (completion handler pattern)

#### Scenario: Missing Audio File
- GIVEN audio file is not found in bundle
- WHEN playback is requested
- THEN silent fallback occurs (no crash)
- AND completion handler still fires after 0.1s delay

### Requirement: HealthKit Integration
The system SHALL log completed meditation sessions to HealthKit.

#### Scenario: Successful Mindfulness Logging
- GIVEN session completes normally (Phase 2 ends)
- AND Phase 1 duration was ≥ 2 minutes
- WHEN logging to HealthKit
- THEN HKCategoryTypeIdentifier.mindfulSession is created
- AND duration equals Phase 1 duration only (not Phase 2)
- AND sample is tagged with app source

#### Scenario: Short Session Not Logged
- GIVEN session completes normally
- AND Phase 1 duration was < 2 minutes
- WHEN session ends
- THEN no HealthKit sample is created
- AND session does not count toward streak

#### Scenario: Cancelled Session Not Logged
- GIVEN user cancels session manually
- WHEN timer returns to idle
- THEN no HealthKit sample is created
- AND partial duration is discarded

### Requirement: Live Activity
The system SHALL display progress on Dynamic Island and Lock Screen.

#### Scenario: Live Activity Start
- GIVEN user starts meditation
- WHEN session begins
- THEN Live Activity appears on Dynamic Island
- AND Lock Screen widget shows timer
- AND remaining time displays in MM:SS format

#### Scenario: Live Activity Phase Update
- GIVEN Live Activity is active
- WHEN phase transitions from 1 to 2
- THEN phase indicator updates
- AND remaining time resets to Phase 2 duration

#### Scenario: Live Activity During Pause
- GIVEN session is paused (if implemented)
- WHEN timer is not counting down
- THEN Live Activity shows paused state
- AND time remains frozen

#### Scenario: Live Activity Conflict Resolution
- GIVEN another tab's Live Activity is active
- WHEN user starts meditation on Offen-Tab
- THEN previous Live Activity ends
- AND new Offen-Tab activity starts
- AND ownership transfers to Offen-Tab

#### Scenario: Live Activity on App Background
- GIVEN timer is running
- WHEN app moves to background
- THEN Live Activity remains visible
- AND countdown continues (date-based calculation)

### Requirement: Timer Precision
The system SHALL maintain accurate timing regardless of UI interruptions.

#### Scenario: Date-Based Calculation
- GIVEN timer is running
- WHEN app is interrupted (backgrounded, overlaid)
- THEN remaining time is calculated from stored dates
- AND UI updates correctly when app returns to foreground

#### Scenario: Timer Update Frequency
- GIVEN timer is running in foreground
- WHEN UI is visible
- THEN timer updates every 50ms (Timer.publish interval)
- AND displayed time is always accurate to the second

## Technical Notes

- **Engine:** `TwoPhaseTimerEngine` with state machine: `.idle` → `.phase1(remaining)` → `.phase2(remaining)` → `.finished`
- **Date Properties:** `startDate`, `phase1EndDate`, `endDate` for external systems
- **Foreground-Only:** Timer uses `Timer.publish` which only fires in foreground
- **App Termination:** Automatic cleanup via `UIApplication.willTerminateNotification`
- **Audio:** `GongPlayer` searches .caf, .wav, .mp3 in priority order
- **Completion Handlers:** Used for audio sequencing (gong-Ende → ambient stop)

Reference Standards:
- `.agent-os/standards/audio/completion-handlers.md`
- `.agent-os/standards/healthkit/date-semantics.md`
