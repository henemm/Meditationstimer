# HealthKit Integration

## Overview

Central integration with Apple HealthKit for activity tracking, data storage, and streak calculation. Serves as the single source of truth for all historical data.

## Requirements

### Requirement: Data Types
The system SHALL use standard HealthKit data types for all tracked activities.

#### Scenario: Mindfulness Session Storage
- GIVEN user completes meditation session
- WHEN logging to HealthKit
- THEN HKCategoryTypeIdentifier.mindfulSession is used
- AND duration is stored in minutes
- AND sample is tagged with app source

#### Scenario: Workout Storage
- GIVEN user completes workout
- WHEN logging to HealthKit
- THEN HKWorkout is created
- AND activity type is .highIntensityIntervalTraining
- AND duration is stored in minutes

#### Scenario: Active Energy Storage
- GIVEN workout completes with calorie estimation
- WHEN logging to HealthKit
- THEN HKQuantitySample is created
- AND type is .activeEnergyBurned
- AND unit is kilocalories

#### Scenario: Alcohol Consumption Storage
- GIVEN user logs NoAlc entry
- WHEN storing to HealthKit
- THEN HKQuantitySample is created
- AND type is .numberOfAlcoholicBeverages
- AND unit is count

### Requirement: Permissions
The system SHALL request and handle HealthKit permissions appropriately.

#### Scenario: Initial Permission Request
- GIVEN app launches for first time
- AND HealthKit is available on device
- WHEN app needs HealthKit access
- THEN permission request sheet appears
- AND includes read/write for all required types
- AND user can selectively enable/disable types

#### Scenario: Permission Denied
- GIVEN user denies HealthKit permission
- WHEN app tries to read/write data
- THEN operation fails gracefully
- AND UI shows appropriate message
- AND app remains functional (degraded mode)

#### Scenario: Permission Changed Mid-Session
- GIVEN session is active
- AND user changes HealthKit permissions in Settings
- WHEN session tries to log
- THEN error is handled gracefully
- AND user is informed of permission issue

#### Scenario: HealthKit Unavailable
- GIVEN device doesn't support HealthKit (e.g., iPad)
- WHEN app launches
- THEN HealthKit features are disabled
- AND app functions without HealthKit integration

### Requirement: Data Filtering
The system SHALL filter data by source to ensure consistency.

#### Scenario: App Source Filter
- GIVEN app queries historical data
- WHEN fetching mindfulness/workout minutes
- THEN only samples from THIS app are included
- AND external sources (Apple Watch default, other apps) are excluded

#### Scenario: Source Filter Includes Extensions
- GIVEN app has Widget and Watch extensions
- WHEN filtering by app source
- THEN samples from main app ARE included
- AND samples from Widget extension ARE included
- AND samples from Watch extension ARE included
- AND external apps are excluded

#### Scenario: Unfiltered External Query
- GIVEN app needs to show ALL user health data
- WHEN query is explicitly unfiltered
- THEN all sources are included
- AND UI clearly indicates mixed sources

### Requirement: Date Range Handling
The system SHALL handle date ranges correctly for queries.

#### Scenario: strictStartDate Exclusive End
- GIVEN query uses HKQueryOptions.strictStartDate
- WHEN specifying date range [startDate, endDate)
- THEN endDate is EXCLUSIVE
- AND samples AT endDate are NOT included
- AND use "start of NEXT period" not "end of CURRENT period"

#### Scenario: Monthly Query Range
- GIVEN fetching data for October 2025
- WHEN constructing date range
- THEN startDate = October 1, 00:00:00
- AND endDate = November 1, 00:00:00 (NOT October 31, 23:59:59)
- AND all October samples are included

#### Scenario: Today's Data Query
- GIVEN fetching today's activity
- WHEN constructing date range
- THEN startDate = today at 00:00:00
- AND endDate = tomorrow at 00:00:00
- AND samples logged today are included

### Requirement: Data Consistency
The system SHALL maintain data consistency between display and calculation.

#### Scenario: Same Source Principle
- GIVEN calendar shows activity rings for a day
- AND streak calculation needs same day's data
- WHEN both access HealthKit
- THEN BOTH use identical query parameters
- AND BOTH get same results
- AND "What you see = What gets counted"

#### Scenario: Cached Data Refresh
- GIVEN cached data exists from previous query
- WHEN user logs new activity
- THEN cache is invalidated
- AND fresh query is executed
- AND UI updates with new data

#### Scenario: Query Failure Handling
- GIVEN HealthKit query fails (network, permissions, timeout)
- WHEN failure occurs
- THEN cached data is used if available
- AND UI indicates stale data (optional)
- AND retry is attempted on next interaction

### Requirement: Logging Methods
The system SHALL provide dedicated logging methods for each activity type.

#### Scenario: Log Mindfulness Session
- GIVEN meditation session completes
- WHEN calling `logMindfulness(start:end:)`
- THEN HKCategorySample is created
- AND start/end times are preserved
- AND sample appears in Apple Health app

#### Scenario: Log Workout with Calories
- GIVEN workout session completes
- WHEN calling `logWorkout(start:end:activity:)`
- THEN HKWorkout is created via HKWorkoutBuilder
- AND HKQuantitySample for activeEnergyBurned is associated
- AND calorie estimation uses MET values

#### Scenario: Log Alcohol Consumption
- GIVEN user logs NoAlc entry
- WHEN calling `logAlcohol(drinks:date:)`
- THEN HKQuantitySample is created
- AND value represents consumption level (0, 4, or 6)
- AND date is midnight-aligned for that day

### Requirement: Reverse Smart Reminders Integration
The system SHALL trigger reminder cancellation when activities are logged.

#### Scenario: Activity Triggers Cancellation
- GIVEN smart reminder is scheduled for today
- WHEN activity is logged via HealthKitManager
- THEN `cancelMatchingReminders(for:completedAt:)` is called
- AND matching pending notifications are cancelled

## Technical Notes

- **Single Source of Truth:** All historical data from HealthKit, no duplicate storage
- **Date Semantics:** `.strictStartDate` endDate is EXCLUSIVE - critical bug pattern
- **Source Filtering:** `HKSourceQuery` to get app's source, then filter samples
- **Async/Await:** All HealthKit methods use modern async patterns
- **MainActor Safety:** Authorization requests on MainActor

Reference Standards:
- `.agent-os/standards/healthkit/date-semantics.md`
- `.agent-os/standards/healthkit/data-consistency.md`
