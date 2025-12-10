# Smart Reminders

## Overview

Conditional reminder system that only notifies when no activity has been detected.

## Requirements

### Requirement: Activity Types
The system SHALL support multiple reminder types.

#### Scenario: Available Types
| Type | HealthKit Check | Default Time |
|------|-----------------|--------------|
| Mindfulness | mindfulSession | 20:00 |
| Workout | workoutType | 18:00 |
| NoAlc | numberOfAlcoholicBeverages | 09:00 |

### Requirement: Smart Condition
The system SHALL check activity before sending.

#### Scenario: Activity Check
- WHEN reminder time is reached
- THEN system checks HealthKit for activity today
- IF activity exists
- THEN notification is NOT sent
- IF no activity
- THEN notification IS sent

### Requirement: Configurable Schedule
The system SHALL allow schedule configuration.

#### Scenario: Time Selection
- WHEN user sets reminder time
- THEN notification schedules for that time
- AND persists across app restarts

#### Scenario: Weekday Selection
- WHEN user enables specific weekdays
- THEN reminders only fire on those days
- AND uses DateComponents.weekday for scheduling

### Requirement: Notification Categories
The system SHALL use notification categories for actions.

#### Scenario: NoAlc Actions
- WHEN NoAlc notification appears
- THEN three action buttons are available
- AND tapping action logs directly to HealthKit

### Requirement: Settings Integration
The system SHALL integrate with app Settings.

#### Scenario: Settings UI
- WHEN user opens Settings
- THEN Smart Reminder section is visible
- AND activity type picker is available
- AND time picker is available
- AND weekday toggles are available

## Technical Notes

- UNCalendarNotificationTrigger for reliable delivery
- One notification per weekday with unique identifiers
- Extract both .hour AND .minute from configured time
- BGTaskScheduler unreliable for conditional notifications
