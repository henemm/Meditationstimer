# Smart Reminders

## Overview

Conditional reminder system that checks HealthKit before sending notifications. Only notifies users when no activity has been detected for the configured activity type, reducing notification fatigue.

## Requirements

### Requirement: Activity Types
The system SHALL support reminders for multiple activity types.

#### Scenario: Mindfulness Reminder Type
- GIVEN user is configuring a smart reminder
- WHEN user selects "Mindfulness" type
- THEN reminder will check for HKCategoryTypeIdentifier.mindfulSession
- AND default time is set to 20:00
- AND notification prompts user to meditate

#### Scenario: Workout Reminder Type
- GIVEN user is configuring a smart reminder
- WHEN user selects "Workout" type
- THEN reminder will check for HKWorkoutType entries
- AND default time is set to 18:00
- AND notification prompts user to exercise

#### Scenario: NoAlc Reminder Type
- GIVEN user is configuring a smart reminder
- WHEN user selects "NoAlc" type
- THEN reminder will check for numberOfAlcoholicBeverages
- AND default time is set to 09:00
- AND notification includes quick-log action buttons

### Requirement: Smart Condition
The system SHALL check HealthKit activity before sending notifications.

#### Scenario: Activity Found - No Notification
- GIVEN reminder time is reached
- AND HealthKit contains activity for today (matching type)
- WHEN smart check executes
- THEN notification is NOT sent
- AND next scheduled occurrence remains active

#### Scenario: No Activity Found - Send Notification
- GIVEN reminder time is reached
- AND HealthKit contains NO activity for today (matching type)
- WHEN smart check executes
- THEN notification IS sent
- AND notification content matches activity type

#### Scenario: Activity Completed Just Before Reminder
- GIVEN user completes activity
- AND reminder is scheduled within next 60 seconds
- WHEN activity is logged to HealthKit
- THEN pending notification for that type is cancelled
- AND uses `cancelMatchingReminders(for:completedAt:)` method

#### Scenario: HealthKit Query Failure
- GIVEN reminder time is reached
- AND HealthKit query fails (permissions, timeout)
- WHEN smart check cannot complete
- THEN notification is sent (fail-safe)
- AND error is logged for debugging

### Requirement: Configurable Schedule
The system SHALL allow flexible schedule configuration.

#### Scenario: Time Selection
- GIVEN user is editing a reminder
- WHEN user adjusts time picker
- THEN reminder reschedules for new time
- AND both hour AND minute are extracted
- AND setting persists to AppStorage

#### Scenario: Weekday Selection
- GIVEN user is editing a reminder
- WHEN user toggles weekday buttons
- THEN reminders only fire on selected days
- AND uses DateComponents.weekday (1=Sunday, 7=Saturday)
- AND one UNNotificationRequest per enabled weekday

#### Scenario: All Weekdays Disabled
- GIVEN user is editing a reminder
- WHEN user disables all weekday toggles
- THEN reminder becomes effectively disabled
- AND no notifications are scheduled
- AND UI shows warning or auto-disables reminder

#### Scenario: Reminder Enable/Disable Toggle
- GIVEN reminder exists
- WHEN user toggles enable switch
- THEN notifications are scheduled/cancelled accordingly
- AND visual state updates immediately

### Requirement: Notification Categories
The system SHALL use notification categories for actionable notifications.

#### Scenario: NoAlc Quick Actions
- GIVEN NoAlc notification is delivered
- WHEN notification appears on device
- THEN three action buttons are available: "Steady", "Easy", "Wild"
- AND tapping action logs consumption directly to HealthKit
- AND notification dismisses after action

#### Scenario: Mindfulness Actions
- GIVEN Mindfulness notification is delivered
- WHEN notification appears
- THEN "Start Meditation" action is available
- AND tapping opens app to Offen-Tab

#### Scenario: Workout Actions
- GIVEN Workout notification is delivered
- WHEN notification appears
- THEN "Start Workout" action is available
- AND tapping opens app to Workout-Tab

#### Scenario: Notification Tap (No Action)
- GIVEN any smart reminder notification is delivered
- WHEN user taps notification body (not action button)
- THEN app opens to relevant tab
- AND no automatic logging occurs

### Requirement: Notification Scheduling
The system SHALL use reliable scheduling mechanism.

#### Scenario: Calendar-Based Trigger
- GIVEN reminder is configured
- WHEN scheduling notifications
- THEN UNCalendarNotificationTrigger is used (not BGTaskScheduler)
- AND trigger uses DateComponents with weekday, hour, minute
- AND repeats: true for recurring notifications

#### Scenario: Unique Notification Identifiers
- GIVEN reminder with multiple weekdays enabled
- WHEN scheduling notifications
- THEN each weekday gets unique identifier
- AND format: "[reminderID]-weekday-[1-7]"
- AND allows individual weekday cancellation

#### Scenario: Notification Persistence
- GIVEN reminders are configured
- WHEN app is terminated and relaunched
- THEN scheduled notifications remain active
- AND no re-scheduling needed on app launch

### Requirement: Settings Integration
The system SHALL provide UI for reminder management in Settings.

#### Scenario: Smart Reminders Section
- GIVEN user opens Settings
- WHEN scrolling to Smart Reminders section
- THEN list of configured reminders displays
- AND "Add Reminder" button is available
- AND each reminder shows type, time, enabled state

#### Scenario: Add New Reminder
- GIVEN user is in Settings > Smart Reminders
- WHEN user taps "Add Reminder"
- THEN reminder editor appears
- AND activity type picker shows all three types
- AND time picker defaults to type's default time
- AND weekday buttons default to all enabled

#### Scenario: Edit Existing Reminder
- GIVEN reminder list contains reminders
- WHEN user taps on a reminder
- THEN editor opens with current values
- AND all parameters are editable

#### Scenario: Delete Reminder
- GIVEN reminder exists
- WHEN user swipes to delete or taps delete button
- THEN reminder is removed from list
- AND all associated notifications are cancelled
- AND reminder ID added to deleted-reminders blacklist

#### Scenario: Permission Warning
- GIVEN notification permissions not granted
- WHEN user views Smart Reminders section
- THEN warning banner displays
- AND link to Settings app is provided
- AND reminders can still be configured (but won't fire)

### Requirement: Reverse Smart Reminders
The system SHALL cancel reminders when activity is completed.

#### Scenario: Activity Triggers Cancellation
- GIVEN smart reminder is scheduled for today
- AND reminder time is within lookAhead window (24h)
- WHEN user completes matching activity type
- THEN `HealthKitManager.logX()` calls `cancelMatchingReminders()`
- AND matching notification is removed from pending

#### Scenario: Cancellation Tracking
- GIVEN notification was cancelled due to activity
- WHEN cancellation occurs
- THEN `CancelledNotification` record is created
- AND stored in AppStorage for debugging
- AND prevents re-scheduling until next day

## Technical Notes

- **Scheduling:** `UNCalendarNotificationTrigger` is reliable; `BGTaskScheduler` is NOT (iOS throttles)
- **Weekday Loop:** One notification per weekday with unique identifiers (lines 124-156 in SmartReminderEngine)
- **Date Components:** Extract `.hour` AND `.minute` (not just hour with :00)
- **Categories:** `UNNotificationCategory` with `UNNotificationAction` for quick actions
- **Reverse Reminders:** `cancelMatchingReminders(for:completedAt:)` called from HealthKitManager

Reference Standards:
- `.agent-os/standards/healthkit/date-semantics.md`
- `.agent-os/standards/global/analysis-first.md` (Notification Debugging Protocol)
