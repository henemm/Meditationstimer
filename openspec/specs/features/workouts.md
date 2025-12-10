# Workouts (Workout-Tab)

## Overview

HIIT workout timer with customizable programs, exercise database, and HealthKit logging.

## Requirements

### Requirement: Free Workout Timer
The system SHALL provide a free-form workout timer.

#### Scenario: Free Workout
- WHEN user starts free workout
- THEN timer counts up
- AND user can stop manually
- AND session is logged to HealthKit

### Requirement: Workout Programs
The system SHALL provide pre-defined workout programs.

#### Scenario: Program Selection
- WHEN user selects a program
- THEN exercises are displayed with durations
- AND work/rest intervals are configured

#### Scenario: Work Phase
- WHEN work phase is active
- THEN current exercise name is displayed
- AND countdown timer shows remaining time
- AND audio cue plays at phase end

#### Scenario: Rest Phase
- WHEN rest phase is active
- THEN "Rest" is displayed
- AND next exercise is previewed
- AND countdown timer shows remaining time

### Requirement: Exercise Database
The system SHALL include a library of exercises.

#### Scenario: Exercise Info
- WHEN user taps info button on exercise
- THEN InfoSheet shows exercise details
- AND affected muscle groups
- AND form tips

### Requirement: Audio Cues
The system SHALL play audio cues during workouts.

#### Scenario: Phase Transitions
| Event | Audio |
|-------|-------|
| Work phase start | Einatmen sound |
| Rest phase start | Ausatmen sound |
| Program complete | End gong |

### Requirement: HealthKit Integration
The system SHALL log workouts to HealthKit.

#### Scenario: Workout Logging
- WHEN workout completes
- THEN HKWorkout is created with duration
- AND calories are estimated (MET-based)
- AND activity type is highIntensityIntervalTraining

### Requirement: Conditional Rest Skip
The system SHALL skip final rest phase.

#### Scenario: No Rest After Last Exercise
- WHEN last exercise completes
- THEN program ends immediately
- AND no rest countdown occurs

## Technical Notes

- MET-based calorie estimation (HIIT: 12 kcal/min)
- Guard Flag Pattern prevents duplicate HealthKit logging
- REST phase pause shows next exercise (not current)
