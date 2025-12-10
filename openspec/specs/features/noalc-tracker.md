# NoAlc Tracker

## Overview

Alcohol consumption tracking with HealthKit integration, streak calculation, and calendar visualization.

## Requirements

### Requirement: Consumption Levels
The system SHALL categorize consumption into three levels.

#### Scenario: Level Definitions
| Level | Drinks | HealthKit Value | Color | Meaning |
|-------|--------|-----------------|-------|---------|
| Steady | 0-1 | 0 | #0EBF6E | No/minimal |
| Easy | 2-5 | 4 | #89D6B2 | Moderate |
| Wild | 6+ | 6 | #B6B6B6 | High |

### Requirement: Calendar Visualization
The system SHALL display NoAlc status in calendar.

#### Scenario: Inner Fill Circle
- WHEN day has NoAlc entry
- THEN inner fill circle appears (28x28)
- AND color matches consumption level

#### Scenario: Ring Sizing
| Ring | Size | Content |
|------|------|---------|
| NoAlc | 28x28 | Inner fill |
| Workout | 32x32 | Middle ring |
| Mindfulness | 42x42 | Outer ring |

### Requirement: Streak Calculation
The system SHALL calculate NoAlc streaks.

#### Scenario: Streak Rules
- WHEN day has Steady level
- THEN streak continues
- AND every 7 consecutive days earns 1 reward (max 3)

#### Scenario: Easy Day Healing
- WHEN day has Easy level
- AND available rewards > 0
- THEN reward is consumed
- AND streak continues

#### Scenario: Wild Day
- WHEN day has Wild level
- THEN streak breaks
- AND rewards decrease by 1

### Requirement: Forward Iteration
The system SHALL use forward chronological iteration.

#### Scenario: Reward Calculation
- GIVEN streak data exists
- WHEN calculating streak
- THEN iterate from earliest date to today
- AND earn rewards chronologically before consumption

### Requirement: HealthKit Integration
The system SHALL store data in HealthKit.

#### Scenario: Data Storage
- WHEN user logs consumption
- THEN HKQuantitySample is created
- AND type is numberOfAlcoholicBeverages
- AND value is representative (0, 4, or 6)

### Requirement: Manual Entry
The system SHALL allow manual entry.

#### Scenario: NoAlc Sheet
- WHEN user opens NoAlc sheet
- THEN three level buttons are displayed
- AND date picker allows historical entry
- AND entry is saved to HealthKit

### Requirement: Smart Reminders
The system SHALL send configurable reminders.

#### Scenario: Daily Reminder
- WHEN reminder time is reached
- THEN notification prompts for logging
- AND uses UNCalendarNotificationTrigger (not BGTaskScheduler)

#### Scenario: Day Assignment
- WHEN reminder time < 18:00
- THEN notification references yesterday
- WHEN reminder time >= 18:00
- THEN notification references today

## Technical Notes

- Forward iteration critical for reward tracking
- Data source consistency: same data for display and calculation
- DateComponents.weekday for weekday-specific scheduling
