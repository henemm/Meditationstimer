# HealthKit Integration

## Overview

Central integration with Apple HealthKit for activity tracking, data storage, and streak calculation.

## Requirements

### Requirement: Data Types
The system SHALL use standard HealthKit data types.

#### Scenario: Supported Types
| Feature | HealthKit Type | Unit |
|---------|---------------|------|
| Meditation | mindfulSession | minutes |
| Workout | workoutType | minutes |
| NoAlc | numberOfAlcoholicBeverages | count |
| Calories | activeEnergyBurned | kcal |

### Requirement: Permissions
The system SHALL request appropriate permissions.

#### Scenario: Permission Request
- WHEN app launches first time
- THEN HealthKit permission sheet appears
- AND includes read/write for all types

### Requirement: Data Filtering
The system SHALL filter data by source.

#### Scenario: App Source Filter
- WHEN fetching historical data
- THEN only data from this app is included
- AND external sources are excluded

### Requirement: Date Range Handling
The system SHALL handle date ranges correctly.

#### Scenario: strictStartDate Exclusive End
- GIVEN query uses .strictStartDate
- WHEN specifying date range
- THEN endDate is EXCLUSIVE
- AND use "start of NEXT period" not "end of CURRENT period"

### Requirement: Data Consistency
The system SHALL maintain data consistency.

#### Scenario: Same Source Principle
- GIVEN visualization needs data
- AND calculation needs same data
- THEN both use identical data source
- AND "What you see = What gets counted"

## Technical Notes

Reference: `.agent-os/standards/healthkit/date-semantics.md`
Reference: `.agent-os/standards/healthkit/data-consistency.md`
