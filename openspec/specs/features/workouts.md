# Workouts (Workout-Tab)

## Overview

HIIT workout system with two modes: Free Workout (count-up timer) and Workout Programs (structured interval training). Includes exercise database, audio cues, and HealthKit logging with MET-based calorie estimation.

## Requirements

### Requirement: Free Workout Timer
The system SHALL provide a free-form workout timer that counts up.

#### Scenario: Start Free Workout
- GIVEN user is on Frei-Tab (Free Workout)
- AND no workout is active
- WHEN user taps "Start" button
- THEN timer begins counting up from 00:00
- AND Live Activity starts
- AND session start time is recorded

#### Scenario: Stop Free Workout
- GIVEN free workout timer is running
- WHEN user taps "Stop" button
- THEN timer stops
- AND workout is logged to HealthKit
- AND Live Activity ends

#### Scenario: Free Workout Duration Display
- GIVEN free workout is active
- WHEN timer is running
- THEN elapsed time displays in MM:SS format
- AND time updates every second

### Requirement: Workout Programs
The system SHALL provide structured workout programs with work/rest intervals.

#### Scenario: Program Selection
- GIVEN user is on Workout Programs tab
- WHEN user views program list
- THEN 10+ default programs are available
- AND custom programs are listed if created
- AND each shows name, duration, exercise count

#### Scenario: Start Workout Program
- GIVEN user has selected a program
- WHEN user taps "Start" button
- THEN countdown overlay appears (if configured)
- AND first work phase begins after countdown
- AND Live Activity starts showing program info

#### Scenario: Work Phase Active
- GIVEN workout program is running
- AND current phase is WORK
- WHEN work phase is active
- THEN current exercise name displays prominently
- AND countdown timer shows remaining work time
- AND flame icon indicates work phase
- AND info button available for exercise details

#### Scenario: Work Phase Countdown Cues
- GIVEN work phase is active
- AND 3 seconds remain
- WHEN countdown reaches 3, 2, 1
- THEN countdown audio cues play
- AND visual countdown appears

#### Scenario: Rest Phase Active
- GIVEN work phase completes
- AND this is not the last exercise
- WHEN rest phase begins
- THEN "Rest" or pause icon displays
- AND next exercise name previews ("Als nächstes: [Exercise]")
- AND countdown shows remaining rest time

#### Scenario: Rest Phase Pause Display
- GIVEN workout is in rest phase
- AND user pauses workout
- WHEN paused during rest
- THEN display shows next exercise (same as running rest)
- AND pause icon indicates paused state
- AND "Als nächstes" text in small font, exercise name in large font

#### Scenario: Work Phase Pause Display
- GIVEN workout is in work phase
- AND user pauses workout
- WHEN paused during work
- THEN current exercise name displays
- AND pause icon indicates paused state
- AND next exercise preview shows below

#### Scenario: Skip Final Rest
- GIVEN last exercise in program completes
- WHEN work phase ends
- THEN program ends immediately
- AND no rest phase occurs after final exercise
- AND completion sound plays

#### Scenario: Round Progression
- GIVEN program has multiple rounds
- WHEN completing all exercises in a round
- THEN round counter increments
- AND "Round X" announcement plays (TTS)
- AND exercises repeat for next round

### Requirement: Exercise Database
The system SHALL include a library of exercises with details.

#### Scenario: Exercise Info Button
- GIVEN exercise is displayed (work or preview)
- WHEN user taps info button (ⓘ)
- THEN ExerciseDetailSheet appears
- AND shows exercise name, category, emoji
- AND shows effects/benefits
- AND shows form instructions

#### Scenario: Info During Active Workout
- GIVEN workout is running (work phase)
- WHEN user taps info button
- THEN workout pauses automatically
- AND exercise info sheet displays
- AND workout resumes when sheet dismisses

### Requirement: Audio Cues
The system SHALL play audio cues during workouts.

#### Scenario: Work Phase Start Audio
- GIVEN transitioning to work phase
- WHEN work phase begins
- THEN "auftakt" or work-start sound plays
- AND prepares user for exercise

#### Scenario: Rest Phase Start Audio
- GIVEN work phase completes
- WHEN transitioning to rest phase
- THEN "ausatmen" or rest-start sound plays

#### Scenario: Program Completion Audio
- GIVEN all exercises and rounds complete
- WHEN program ends
- THEN "ausklang" or completion sound plays
- AND sound plays completely before cleanup

#### Scenario: Countdown Audio (3-2-1)
- GIVEN work phase is about to begin
- AND countdown is enabled in settings
- WHEN countdown reaches 3, 2, 1
- THEN distinct countdown sounds play
- AND provides audible preparation cue

#### Scenario: Round Announcement
- GIVEN program has multiple rounds
- AND round announcement is enabled
- WHEN new round begins
- THEN TTS announces "Round [X]" or "Letzte Runde"
- AND uses AVSpeechSynthesizer with German voice

#### Scenario: Exercise Name TTS (Workout Programs)
- GIVEN "Speak Exercise Names" is enabled in Settings
- AND workout program is running
- WHEN transitioning from REST to WORK phase
- THEN TTS announces next exercise name
- AND uses localized announcement ("Als nächstes: [Exercise]" / "Up next: [Exercise]")
- AND voice language matches app locale (de-DE or en-US)

#### Scenario: Exercise Name TTS (Free Workout)
- GIVEN "Speak Exercise Names" is enabled in Settings
- AND free workout is running with multiple exercises
- WHEN transitioning to next exercise
- THEN TTS announces next exercise name
- AND uses same announcement pattern as Workout Programs
- AND respects `@AppStorage("speakExerciseNames")` toggle

#### Scenario: TTS Language Matching
- GIVEN TTS announcement is triggered
- WHEN AVSpeechSynthesizer speaks
- THEN voice language matches current app locale
- AND German app uses "de-DE" voice
- AND English app uses "en-US" voice
- AND prevents mismatch between localized text and voice

### Requirement: HealthKit Integration
The system SHALL log workouts to HealthKit with calorie estimation.

#### Scenario: Successful Workout Logging
- GIVEN workout completes (free or program)
- AND duration ≥ 3 seconds
- WHEN logging to HealthKit
- THEN HKWorkout is created
- AND activity type is `.highIntensityIntervalTraining`
- AND duration is recorded
- AND estimated calories are included

#### Scenario: MET-Based Calorie Estimation
- GIVEN workout is being logged
- WHEN calculating calories
- THEN HIIT uses 12 kcal/min MET value
- AND calories = duration(min) × 12
- AND logged as `.activeEnergyBurned`

#### Scenario: Short Workout Not Logged
- GIVEN workout duration < 3 seconds
- WHEN workout ends
- THEN no HealthKit entry is created
- AND prevents accidental taps from logging

#### Scenario: Prevent Duplicate Logging
- GIVEN workout is ending
- AND endSession() has been called
- WHEN endSession() is called again (e.g., from onDisappear)
- THEN Guard Flag Pattern prevents second execution
- AND only one HealthKit entry is created

### Requirement: Workout Program Creation
The system SHALL allow custom workout program creation.

#### Scenario: Create Custom Program
- GIVEN user is on program list
- WHEN user taps "Create" or "+"
- THEN program editor appears
- AND user can set program name
- AND user can add/remove/reorder exercises
- AND user can set work/rest durations per exercise

#### Scenario: Edit Existing Program
- GIVEN custom program exists
- WHEN user selects edit
- THEN program editor opens with current values
- AND all parameters are editable

#### Scenario: Delete Custom Program
- GIVEN custom program exists
- WHEN user deletes program
- THEN program is removed
- AND default programs cannot be deleted

### Requirement: Live Activity Integration
The system SHALL display workout progress on Dynamic Island.

#### Scenario: Program Live Activity
- GIVEN workout program is active
- WHEN Live Activity displays
- THEN current exercise name shows
- AND remaining time shows
- AND phase indicator (work/rest) shows

#### Scenario: Free Workout Live Activity
- GIVEN free workout is active
- WHEN Live Activity displays
- THEN elapsed time shows
- AND "Free Workout" label shows

## Technical Notes

- **Guard Flag Pattern:** `sessionEnded` flag prevents duplicate `endSession()` calls from callbacks + `onDisappear`
- **MET Values:** HIIT = 12 kcal/min (validated against fitness standards)
- **Calorie Logging:** Uses `HKQuantitySample` with `.activeEnergyBurned` type
- **REST Phase UI:** Pause shows next exercise (matches running REST display)
- **Audio Files:** Supports .caff, .caf, .wav, .mp3, .aiff formats
- **TTS:** AVSpeechSynthesizer with German voice for round announcements

Reference Standards:
- `.agent-os/standards/swiftui/lifecycle-patterns.md` (Guard Flag Pattern)
- `.agent-os/standards/healthkit/data-consistency.md`
