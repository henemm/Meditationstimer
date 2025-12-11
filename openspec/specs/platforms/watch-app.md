# Watch App

## Overview

Standalone Apple Watch companion app for meditation sessions with heart rate monitoring, haptic feedback, and HealthKit integration. Uses the same TwoPhaseTimerEngine as the iOS app for consistent behavior.

## Requirements

### Requirement: Two-Phase Meditation Timer
The system SHALL provide the same two-phase meditation timer as iOS.

#### Scenario: Phase Configuration
- GIVEN user is on Watch app idle screen
- WHEN configuring session
- THEN Phase 1 (Meditation) duration is adjustable via Digital Crown
- AND Phase 2 (Besinnung) duration is adjustable via Digital Crown
- AND values persist to AppStorage

#### Scenario: Start Session
- GIVEN timer is configured
- WHEN user taps "Start" button
- THEN TwoPhaseTimerEngine starts
- AND Phase 1 countdown begins
- AND heart rate streaming starts
- AND extended runtime session starts

#### Scenario: Phase 1 Display
- GIVEN session is in Phase 1
- WHEN displaying timer
- THEN "Meditation" title shows
- AND remaining time displays prominently
- AND cancel button is available

#### Scenario: Phase 2 Transition
- GIVEN Phase 1 completes
- WHEN transitioning to Phase 2
- THEN strong haptic feedback plays
- AND "Besinnung" title shows
- AND heart rate streaming stops
- AND Phase 2 countdown begins

#### Scenario: Session Completion
- GIVEN Phase 2 completes
- WHEN session ends
- THEN strong haptic feedback plays
- AND Phase 1 duration is logged to HealthKit
- AND timer returns to idle state
- AND heart rate summary is available

#### Scenario: Cancel Session
- GIVEN session is running
- WHEN user taps "Abbrechen" (cancel)
- THEN session ends immediately
- AND no HealthKit logging occurs
- AND timer returns to idle

### Requirement: Heart Rate Monitoring
The system SHALL stream heart rate during meditation.

#### Scenario: Start Heart Rate Stream
- GIVEN session starts
- WHEN Phase 1 begins
- THEN HeartRateStream starts
- AND HealthKit workout session begins (for HR access)

#### Scenario: Heart Rate Data Collection
- GIVEN heart rate stream is active
- WHEN heart rate samples are received
- THEN samples are collected in array
- AND can be displayed after session

#### Scenario: Stop Heart Rate Stream
- GIVEN Phase 1 ends (or session cancels)
- WHEN transition occurs
- THEN heart rate stream stops
- AND collected samples are retained

#### Scenario: Heart Rate Summary
- GIVEN session completed
- AND heart rate samples were collected
- WHEN user taps "Herzfrequenz anzeigen"
- THEN HeartRateListView presents
- AND shows min/avg/max heart rate
- AND lists individual samples with timestamps

### Requirement: Extended Runtime Session
The system SHALL use extended runtime for long sessions.

#### Scenario: Runtime Session Start
- GIVEN user starts meditation
- WHEN session begins
- THEN RuntimeSessionHelper.start() is called
- AND WKExtendedRuntimeSession keeps app active
- AND allows ~30 minute sessions

#### Scenario: Runtime Session End
- GIVEN session completes or cancels
- WHEN session ends
- THEN RuntimeSessionHelper.stop() is called
- AND extended runtime ends

#### Scenario: Runtime Expiration
- GIVEN extended runtime expires (~30 min)
- WHEN expiration callback fires
- THEN session continues in degraded mode
- OR user is notified

### Requirement: Haptic Feedback
The system SHALL provide haptic feedback at key moments.

#### Scenario: Phase Transition Haptic
- GIVEN Phase 1 completes
- WHEN transitioning to Phase 2
- THEN strong haptic pattern plays
- AND uses WKInterfaceDevice.current().play(.notification)

#### Scenario: Session End Haptic
- GIVEN Phase 2 completes
- WHEN session ends
- THEN strong haptic pattern plays
- AND alerts user session is complete

### Requirement: Notifications
The system SHALL support end-of-phase notifications.

#### Scenario: Permission Request
- GIVEN app launches for first time
- WHEN onAppear triggers
- THEN notification authorization is requested
- AND HealthKit authorization is requested

#### Scenario: Phase End Notification
- GIVEN session is running
- AND app is in background (wrist down)
- WHEN phase ends
- THEN local notification can be scheduled
- AND alerts user of phase transition

### Requirement: HealthKit Integration
The system SHALL log meditation sessions to HealthKit.

#### Scenario: Mindfulness Logging
- GIVEN session completes normally
- WHEN logging to HealthKit
- THEN HKCategoryTypeIdentifier.mindfulSession is created
- AND duration equals Phase 1 duration only
- AND sample syncs to iPhone

#### Scenario: Permission Handling
- GIVEN app needs HealthKit access
- WHEN requesting authorization
- THEN read/write for mindfulSession is requested
- AND read for heartRate is requested
- AND errors are handled gracefully

### Requirement: Watch Connectivity
The system SHALL sync with iPhone when available.

#### Scenario: Data Sync
- GIVEN iPhone app is available
- WHEN meditation is logged on Watch
- THEN HealthKit automatically syncs data
- AND iPhone app sees Watch sessions

#### Scenario: Standalone Operation
- GIVEN iPhone is not available
- WHEN user uses Watch app
- THEN all features work standalone
- AND data syncs when iPhone is available later

### Requirement: UI Layout
The system SHALL provide watchOS-optimized interface.

#### Scenario: Idle State UI
- GIVEN timer is idle
- WHEN displaying main view
- THEN Digital Crown pickers for Phase 1/2 duration show
- AND "Start" button is prominent
- AND layout fits Watch screen

#### Scenario: Running State UI
- GIVEN timer is running
- WHEN displaying session
- THEN phase title shows at top
- AND remaining time is large and centered
- AND "Abbrechen" button is available
- AND layout is minimal/focused

#### Scenario: Finished State UI
- GIVEN session just completed
- WHEN displaying post-session
- THEN picker section returns
- AND "Start" button available for new session
- AND "Herzfrequenz anzeigen" button if HR data exists

## Technical Notes

- **Engine:** Same `TwoPhaseTimerEngine` as iOS for consistency
- **HR Stream:** `HeartRateStream` uses HKWorkoutSession for background HR access
- **Runtime:** `RuntimeSessionHelper` wraps WKExtendedRuntimeSession
- **Haptics:** `WKInterfaceDevice.current().play(.notification)` for strong feedback
- **Standalone:** No iPhone required for core functionality
- **State Management:** `@StateObject` for engine, `@State` for UI state

Reference Standards:
- `.agent-os/standards/swiftui/lifecycle-patterns.md`
