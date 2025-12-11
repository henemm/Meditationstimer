# App Intents (Siri Shortcuts)

## Overview

App Intents integration for Siri Shortcuts support. Allows users to start meditation, breathing exercises, and workouts via Siri voice commands or Shortcuts app automations.

## Requirements

### Requirement: Start Meditation Intent
The system SHALL provide an intent to start meditation sessions.

#### Scenario: Intent Definition
- GIVEN Shortcuts app is open
- WHEN user searches for app actions
- THEN "Starte Meditation" intent is available
- AND description explains the action

#### Scenario: Parameter Configuration
- GIVEN user adds Start Meditation intent
- WHEN configuring parameters
- THEN phase1Minutes is configurable (1-120, default 15)
- AND phase2Minutes is configurable (0-30, default 2)
- AND summary shows "Starte X Min Meditation + Y Min Besinnung"

#### Scenario: Intent Execution
- GIVEN intent is triggered (Siri or Shortcut)
- WHEN perform() runs
- THEN app opens (openAppWhenRun = true)
- AND UserDefaults are updated with configured durations
- AND NotificationCenter posts .startMeditationSession
- AND OffenView picks up values and starts session

#### Scenario: Siri Voice Trigger
- GIVEN user has added Shortcut with intent
- WHEN user says Siri phrase
- THEN intent executes
- AND meditation starts with configured parameters

### Requirement: Start Breathing Intent
The system SHALL provide an intent to start breathing exercises.

#### Scenario: Intent Definition
- GIVEN Shortcuts app is open
- WHEN user searches for app actions
- THEN "Starte Atemübung" intent is available
- AND description explains breathing exercise start

#### Scenario: Parameter Configuration
- GIVEN user adds Start Breathing intent
- WHEN configuring parameters
- THEN preset selection is available (if implemented)
- OR default preset is used

#### Scenario: Intent Execution
- GIVEN intent is triggered
- WHEN perform() runs
- THEN app opens
- AND navigates to Atem-Tab
- AND starts breathing session with configured preset

### Requirement: Start Workout Intent
The system SHALL provide an intent to start workouts.

#### Scenario: Intent Definition
- GIVEN Shortcuts app is open
- WHEN user searches for app actions
- THEN "Starte Workout" intent is available
- AND description explains workout start

#### Scenario: Intent Execution
- GIVEN intent is triggered
- WHEN perform() runs
- THEN app opens
- AND navigates to Workout-Tab
- AND starts free workout or configured program

### Requirement: App Shortcuts Provider
The system SHALL register intents with system.

#### Scenario: Shortcut Registration
- GIVEN app launches
- WHEN AppShortcutsProvider is initialized
- THEN all intents are registered with system
- AND available in Shortcuts app
- AND available to Siri

#### Scenario: Shortcut Phrases
- GIVEN intents are registered
- WHEN user views Siri phrases
- THEN suggested phrases are available
- AND phrases match app localization (German)

### Requirement: Notification-Based Triggering
The system SHALL use NotificationCenter for intent-to-view communication.

#### Scenario: Notification Names
- GIVEN intent needs to trigger UI action
- WHEN posting notification
- THEN uses defined names:
  - `.startMeditationSession`
  - `.startBreathingSession`
  - `.startWorkoutSession`

#### Scenario: View Response
- GIVEN notification is posted
- WHEN main view receives notification
- THEN appropriate action is triggered
- AND session starts with intent parameters

### Requirement: Intent Error Handling
The system SHALL handle intent errors gracefully.

#### Scenario: Error Definition
- GIVEN intent execution fails
- WHEN error occurs
- THEN IntentError with message is thrown
- AND error is localized for user display

#### Scenario: App Not Ready
- GIVEN app is in unexpected state
- WHEN intent tries to start session
- THEN appropriate error or fallback occurs
- AND user is informed

### Requirement: Parameter Validation
The system SHALL validate intent parameters.

#### Scenario: Duration Validation
- GIVEN user configures meditation duration
- WHEN setting phase1Minutes
- THEN value must be in range 1-120
- AND inclusiveRange enforces bounds

#### Scenario: Default Values
- GIVEN user doesn't customize parameters
- WHEN intent executes
- THEN default values are used:
  - phase1Minutes: 15
  - phase2Minutes: 2

### Requirement: Localization
The system SHALL support German localization for intents.

#### Scenario: Intent Titles
- GIVEN device language is German
- WHEN displaying intent
- THEN title shows "Starte Meditation"
- AND parameters show German labels

#### Scenario: Parameter Summaries
- GIVEN user views intent in Shortcuts
- WHEN summary displays
- THEN text is in German
- AND uses proper localization format

## Technical Notes

- **Framework:** AppIntents framework (iOS 16+)
- **Entry Point:** `AppShortcutsProvider` conformance
- **Communication:** NotificationCenter for intent → view triggering
- **UserDefaults:** Stores configured parameters for view pickup
- **openAppWhenRun:** Set to true - intents require app to be open

Reference Standards:
- `.agent-os/standards/swiftui/localization.md`
