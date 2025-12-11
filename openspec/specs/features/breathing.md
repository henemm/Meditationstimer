# Breathing Exercises (Atem-Tab)

## Overview

Guided breathing exercises with customizable patterns, preset management, ambient sounds, visual guidance, and audio cues. Supports multiple breathing rhythms with configurable repetitions.

## Requirements

### Requirement: Breathing Patterns
The system SHALL support multiple breathing patterns with 4-phase rhythm.

#### Scenario: Select 4-7-8 Pattern
- GIVEN user is on Atem-Tab
- AND preset list is visible
- WHEN user selects "4-7-8" pattern
- THEN inhale duration is set to 4 seconds
- AND hold-in duration is set to 7 seconds
- AND exhale duration is set to 8 seconds
- AND hold-out duration is set to 0 seconds (disabled)

#### Scenario: Select Box Breathing Pattern
- GIVEN user is on Atem-Tab
- WHEN user selects "Box Breathing" pattern
- THEN all four phases are set to 4 seconds each
- AND total cycle duration is 16 seconds

#### Scenario: Select Relaxing Pattern
- GIVEN user is on Atem-Tab
- WHEN user selects "Relaxing" pattern
- THEN inhale is 4 seconds, exhale is 6 seconds
- AND both hold phases are disabled (0 seconds)

#### Scenario: Custom Preset Creation
- GIVEN user is on Atem-Tab
- WHEN user creates new preset
- THEN preset editor appears
- AND user can set name, emoji, and all four phase durations
- AND user can set repetition count
- AND preset is saved to persistent storage

#### Scenario: Preset Editing
- GIVEN preset list contains custom presets
- WHEN user long-presses or taps edit on preset
- THEN preset editor opens with current values
- AND user can modify any parameter
- AND changes are saved on confirmation

#### Scenario: Preset Deletion
- GIVEN preset list contains custom presets
- WHEN user deletes a preset
- THEN preset is removed from list
- AND default presets cannot be deleted

### Requirement: Visual Guidance
The system SHALL provide animated visual breathing guidance.

#### Scenario: Inhale Animation
- GIVEN breathing session is active
- WHEN inhale phase begins
- THEN visual element expands smoothly
- AND "Einatmen" label displays
- AND progress ring fills clockwise

#### Scenario: Exhale Animation
- GIVEN breathing session is active
- WHEN exhale phase begins
- THEN visual element contracts smoothly
- AND "Ausatmen" label displays
- AND progress ring shows phase progress

#### Scenario: Hold Animation
- GIVEN breathing session is active
- AND current phase is hold-in or hold-out
- WHEN hold phase is active
- THEN visual element remains static
- AND "Halten" label displays
- AND countdown shows remaining hold time

#### Scenario: Phase Transition
- GIVEN one breathing phase completes
- WHEN transitioning to next phase
- THEN animation smoothly transitions
- AND audio cue plays for new phase
- AND label updates immediately

### Requirement: Audio Guidance
The system SHALL provide audio cues for each breathing phase.

#### Scenario: Inhale Audio Cue
- GIVEN breathing session is active
- AND audio cues are enabled
- WHEN inhale phase begins
- THEN "einatmen" audio file plays
- AND audio matches selected sound theme

#### Scenario: Exhale Audio Cue
- GIVEN breathing session is active
- AND audio cues are enabled
- WHEN exhale phase begins
- THEN "ausatmen" audio file plays
- AND audio matches selected sound theme

#### Scenario: Hold-In Audio Cue
- GIVEN breathing session is active
- AND hold-in phase duration > 0
- WHEN hold-in phase begins
- THEN "halten-ein" audio file plays

#### Scenario: Hold-Out Audio Cue
- GIVEN breathing session is active
- AND hold-out phase duration > 0
- WHEN hold-out phase begins
- THEN "halten-aus" audio file plays

#### Scenario: Sound Theme Selection
- GIVEN user is configuring breathing session
- WHEN user selects sound theme
- THEN theme options include: Distinctive, Marimba, Harp, Guitar
- AND all audio cues use selected theme's files
- AND selection persists across sessions

### Requirement: Ambient Sounds
The system SHALL support ambient background sounds during breathing.

#### Scenario: Ambient Sound Selection
- GIVEN user is on Atem-Tab or Settings
- WHEN user selects ambient sound
- THEN options include: Waves, Spring, Fire, None
- AND selection persists to AppStorage

#### Scenario: Ambient Sound During Session
- GIVEN ambient sound is selected (not None)
- WHEN breathing session starts
- THEN ambient sound begins playing
- AND sound loops seamlessly (cross-fade pattern)
- AND volume is at configured level (default 45%)

#### Scenario: Volume Adjustment
- GIVEN Settings is open
- WHEN user adjusts ambient volume slider
- THEN volume updates immediately (0-100%)
- AND setting persists across app restarts

#### Scenario: Ambient Sound Stops After Session
- GIVEN breathing session is ending
- AND end gong is playing
- WHEN end gong playback completes
- THEN ambient sound stops (fade out)
- AND uses completion handler pattern for timing

### Requirement: Session Configuration
The system SHALL allow session customization.

#### Scenario: Repetition Selection
- GIVEN user is configuring breathing session
- WHEN user sets repetitions (1-50)
- THEN total session duration calculates
- AND progress shows "Cycle X of Y" during session

#### Scenario: Session Progress Display
- GIVEN breathing session is active
- WHEN cycles complete
- THEN outer ring shows overall session progress
- AND inner ring shows current cycle progress
- AND current/total cycle count displays

#### Scenario: Session Start
- GIVEN preset is selected
- AND repetitions are configured
- WHEN user taps "Start" button
- THEN countdown overlay appears (if configured)
- AND session begins after countdown
- AND Live Activity starts

#### Scenario: Session Pause
- GIVEN breathing session is active
- WHEN user taps pause button
- THEN timer pauses
- AND visual animation pauses
- AND ambient sound continues (or pauses based on setting)

#### Scenario: Session Cancel
- GIVEN breathing session is active
- WHEN user taps stop/cancel button
- THEN session ends immediately
- AND ambient sound stops
- AND no HealthKit logging occurs

### Requirement: Audio Completion Sequencing
The system SHALL properly sequence audio cleanup to prevent sound cutoff.

#### Scenario: End Gong Plays Completely
- GIVEN breathing session completes all repetitions
- WHEN session ends
- THEN end gong (gong-Ende) begins playing
- AND ambient sound continues during gong
- AND ambient sound stops ONLY after gong completes

#### Scenario: Completion Handler Pattern
- GIVEN end gong is playing
- WHEN gong playback finishes (AVAudioPlayerDelegate callback)
- THEN 0.5 second safety buffer applies
- AND THEN ambient sound stops via DispatchWorkItem
- AND cleanup is cancellable if user interrupts

### Requirement: HealthKit Integration
The system SHALL log completed breathing sessions to HealthKit.

#### Scenario: Mindfulness Logging
- GIVEN breathing session completes normally
- AND total duration ≥ 2 minutes
- WHEN session ends
- THEN HKCategoryTypeIdentifier.mindfulSession is created
- AND duration equals actual breathing time

## Technical Notes

- **Preset Model:** `BreathPreset` with id, name, emoji, inhale, holdIn, exhale, holdOut, repetitions, description
- **Sound Themes:** Audio files organized by theme in bundle (e.g., einatmen-marimba.caf)
- **Completion Handler:** `GongPlayer.play(named:completion:)` with `AVAudioPlayerDelegate`
- **Ambient Looping:** `AmbientSoundPlayer` with cross-fade between Player A and B (7s overlap)
- **DispatchWorkItem:** Cancellable delayed cleanup for audio sequencing

Reference Standards:
- `.agent-os/standards/audio/completion-handlers.md`
- `.agent-os/standards/swiftui/lifecycle-patterns.md`
