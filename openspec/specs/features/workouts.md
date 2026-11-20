# Workouts (Workout Tab)

## Overview

HIIT workout system with two modes: Free Workout (count-up timer, **top section**) and Workout Programs (structured interval training, **scrollable section below**). Includes exercise database, audio cues, and HealthKit logging with MET-based calorie estimation.

See `app-navigation.md` for tab structure.

## Requirements

### Requirement: Free Workout Timer
The system SHALL provide a free-form workout timer that counts up.

#### Scenario: Start Free Workout
- GIVEN user is on Workout Tab (free workout section)
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
- THEN 4 default programs are available (Tabata Classic, Core Circuit, Full Body Burn, Quick Burn; `defaultWorkoutSets` in `WorkoutTab.swift`)
- AND each step of a default program carries an explicit catalog exercise identifier (`builtin.*`)
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

#### Scenario: Exercise Hint Line
- GIVEN a step has a hint (entered in the step editor, field "Hint (optional)")
- AND workout program is running
- WHEN the current phase is WORK (running or paused)
- THEN the hint shows as a text line directly under the progress ring (`workout.training.hint`), between ring and exercise counter
- AND the hint is not shown in the REST phase and not in the "Als nächstes" preview of the next exercise
- AND a step without hint (empty or whitespace-only input is stored as no hint) shows no hint line
- AND the stored hint is a single line of at most 80 UTF-16 units (line breaks, control characters and repeated spaces are normalized to single spaces; longer input is cut at 80)
- AND the training view shows the hint in at most two lines

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

#### Scenario: Exercise Catalog Identifiers
- GIVEN the exercise catalog (`ExerciseDatabase`, mirrored in `Contracts/catalog/builtin-exercises.json`, `catalogVersion` 2)
- WHEN the catalog is read
- THEN it contains 67 exercises, each with a unique identifier of the form `builtin.<slug>`
- AND identifiers of user-defined exercises start with `own.`, those added by Claude with `claude.` (the origin is derived from the prefix)
- AND a workout step stores its exercise identifier next to the display name
- AND a stored step without identifier (older data) gets one derived from its name: German catalog name, earlier English name, or a name with suffix "links"/"rechts" of a catalog exercise resolve to the `builtin.*` identifier, any other name to `own.<slug>`
- AND an identifier that is stored is kept as is and not recomputed
- AND the info button looks up the exercise by identifier (falling back to the identifier derived from the name), so stored English names still show the info sheet
- AND the displayed name of a `builtin.*` exercise is the catalog name in the app language, of an `own.*` exercise the stored name

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
- WHEN the first exercise starts after the optional countdown, or when a rest phase begins (the announcement names what comes next)
- THEN TTS announces one of four sentences with the exercise name
- AND the German sentences are "Übung %d von %d: [Exercise]", "letzte Übung: [Exercise]", "Runde %d von %d: [Exercise]" and "Letzte Runde: [Exercise]"
- AND the English sentences are "Exercise %d of %d: [Exercise]", "Last exercise: [Exercise]", "Round %d of %d: [Exercise]" and "Last round: [Exercise]"
- AND the first exercise is announced as "Übung 1 von N", the next exercise within a round as "Übung n von N" (or "letzte Übung" for the final one), the first exercise of a following round as "Runde n von M" (or "Letzte Runde")
- AND no announcement is spoken when a step has no rest phase
- AND the visible rest text "Als nächstes: [Exercise]" is display only and is not spoken
- AND voice language matches app locale (de-DE or en-US)

#### Scenario: Exercise Hint TTS
- GIVEN "Speak Exercise Names" is enabled in Settings
- AND the announced step has a hint
- WHEN one of the four exercise sentences is spoken (first exercise after countdown, or start of a rest phase)
- THEN the hint is appended verbatim after ". " (e.g. "Übung 2 von 6: Planke. 12 Wiederholungen, langsam")
- AND a step without hint is announced word for word as before, without a trailing ". "
- AND with "Speak Exercise Names" disabled neither name nor hint is spoken
- AND the spoken text is built in one place (`WorkoutAnnouncement.spokenText`/`textToSpeak`) used by both speaking points

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
