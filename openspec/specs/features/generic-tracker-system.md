# Generic Tracker System

## Overview

This specification defines the **abstracted, configurable Tracker architecture** that unifies all tracker types (including NoAlc) into a single, flexible system. The Generic Tracker System enables any tracker behavior through configuration rather than code.

**Status:** Spec Phase (not yet implemented)
**Predecessor:** `trackers.md` (current implementation), `noalc-tracker.md` (to be migrated)

---

## Design Goals

| Goal | Description |
|------|-------------|
| **HealthKit First** | ⚠️ **PFLICHT:** Wenn HealthKit-Typ existiert, MUSS er verwendet werden |
| **Unification** | NoAlc migrates into the generic system |
| **Configuration over Code** | Tracker behavior defined by properties, not subclasses |
| **Extensibility** | New tracker types without code changes |
| **SmartReminder Integration** | Every tracker can have reminders |
| **Backward Compatibility** | Mindfulness & Workout remain separate (timer-based) |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Tracker                                 │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │ ValueType   │  │ SuccessCond  │  │ RewardConfig?     │  │
│  │ - boolean   │  │ - logExists  │  │ - earnEveryDays   │  │
│  │ - integer   │  │ - logNotExist│  │ - maxOnHand       │  │
│  │ - levels    │  │ - meetsGoal  │  │ - canHealGrace    │  │
│  └─────────────┘  │ - levelMatch │  └───────────────────┘  │
│                   └──────────────┘                          │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │DayAssignment│  │StorageStrategy│ │ TrackerLevel[]    │  │
│  │ - timestamp │  │ - local      │  │ (for level-based) │  │
│  │ - cutoffHour│  │ - healthKit  │  │ - id, key, icon   │  │
│  └─────────────┘  │ - both       │  │ - streakEffect    │  │
│                   └──────────────┘  └───────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ StreakCalculator │
                    │ (universal)      │
                    └─────────────────┘
```

---

## Core Components

### TrackerLevel

Defines a single level for level-based trackers (2-5 levels per tracker).

```swift
struct TrackerLevel: Identifiable, Codable, Hashable {
    let id: Int                    // Sort order + HealthKit value
    let key: String                // Internal identifier ("steady", "easy")
    let icon: String               // Emoji or SF Symbol
    let labelKey: String           // Localization key
    let streakEffect: StreakEffect
}

enum StreakEffect: String, Codable {
    case success       // Day counts as successful
    case needsGrace    // Requires reward/joker to save streak
    case breaksStreak  // Immediately breaks streak
}
```

**Constraints:**
- Minimum: 2 levels
- Maximum: 5 levels (UI constraint)
- Each level MUST have unique `id` and `key`

---

### TrackerValueType

Defines what value is stored per log entry.

```swift
enum TrackerValueType: Codable, Hashable {
    case boolean                    // Yes/No (yesNo, awareness modes)
    case integer(goal: Int?)        // Number with optional daily goal
    case levels([TrackerLevel])     // 2-5 predefined levels
}
```

| Type | Use Case | Example |
|------|----------|---------|
| `boolean` | Simple logging | Meditation done, Saboteur noticed |
| `integer(goal: 8)` | Counter with target | 8 glasses of water |
| `integer(goal: nil)` | Counter without target | Cups of coffee |
| `levels([...])` | Categorical choice | NoAlc (steady/easy/wild), Mood |

---

### SuccessCondition

Defines when a day counts as "successful" for streak calculation.

```swift
enum SuccessCondition: Codable, Hashable {
    case logExists              // At least 1 log present
    case logNotExists           // No log present (avoidance)
    case meetsGoal              // integer value >= dailyGoal
    case levelMatches([String]) // Logged level.key is in this list
}
```

| Condition | Tracker Type | Success means... |
|-----------|--------------|------------------|
| `logExists` | yesNo, awareness | User logged something |
| `logNotExists` | avoidance | User did NOT log (avoided behavior) |
| `meetsGoal` | counter | Sum of logs >= goal |
| `levelMatches(["steady"])` | NoAlc | User logged "steady" level |

---

### RewardConfig (Optional)

Enables joker/reward system for streak forgiveness.

```swift
struct RewardConfig: Codable, Hashable {
    let earnEveryDays: Int      // Earn 1 reward every X successful days
    let maxOnHand: Int          // Maximum rewards at once
    let canHealGrace: Bool      // Can heal needsGrace days
}
```

**If `nil`:** No reward system, streaks break on first failed day.

**NoAlc Example:**
```swift
RewardConfig(earnEveryDays: 7, maxOnHand: 3, canHealGrace: true)
```

---

### DayAssignment

Determines which calendar day a log belongs to.

```swift
enum DayAssignment: Codable, Hashable {
    case timestamp                 // Log.timestamp determines day
    case cutoffHour(Int)           // Before hour X = previous day
}
```

| Assignment | Behavior | Use Case |
|------------|----------|----------|
| `timestamp` | 23:59 log = today | Most trackers |
| `cutoffHour(18)` | 17:00 log = yesterday, 18:00 log = today | NoAlc evening logging |

---

### StorageStrategy

Defines where tracker data is stored.

```swift
enum StorageStrategy: Codable, Hashable {
    case local                     // SwiftData only (NUR wenn kein HK-Typ existiert!)
    case healthKit(String)         // HealthKit only (identifier)
    case both(String)              // SwiftData + HealthKit sync
}
```

#### ⚠️ REQUIREMENT: HealthKit First

**PFLICHT:** Wenn ein passender HealthKit-Typ existiert, MUSS er verwendet werden!

| HealthKit Typ | Tracker |
|---------------|---------|
| `numberOfAlcoholicBeverages` | NoAlc |
| `dietaryWater` | Wasser |
| `dietaryCaffeine` | Kaffee |
| `stateOfMind` | Stimmung/Mood |
| `sleepAnalysis` | Schlaf |
| `mindfulSession` | Achtsamkeit (bereits via Timer) |

**`local` ist NUR erlaubt wenn:**
- Kein passender HealthKit-Typ existiert (z.B. Doomscrolling, Saboteurs, Gratitude)
- Der Tracker rein app-intern ist und keine Gesundheitsdaten trackt

| Strategy | Primary Store | HealthKit | Use Case |
|----------|---------------|-----------|----------|
| `local` | SwiftData | No | **NUR** wenn kein HK-Typ existiert (Saboteurs, custom habits) |
| `healthKit("...")` | HealthKit | Yes (only) | NoAlc, Standard-Tracker |
| `both("...")` | SwiftData | Yes (sync) | Wenn lokaler Cache nötig ist |

---

## Complete Tracker Model

```swift
@Model
final class Tracker {
    // MARK: - Identity
    var id: UUID
    var name: String
    var icon: String
    var type: TrackerType           // .good / .saboteur
    var createdAt: Date
    var isActive: Bool

    // MARK: - Behavior Configuration
    var valueType: TrackerValueType
    var successCondition: SuccessCondition
    var dayAssignment: DayAssignment
    var storageStrategy: StorageStrategy
    var rewardConfig: RewardConfig?

    // MARK: - SmartReminder Integration
    var supportsReminders: Bool
    var smartReminderID: UUID?
    var defaultLookbackHours: Int

    // MARK: - UI Options
    var showInWidget: Bool
    var widgetOrder: Int
    var showInCalendar: Bool

    // MARK: - Logs
    @Relationship(deleteRule: .cascade, inverse: \TrackerLog.tracker)
    var logs: [TrackerLog] = []
}
```

---

## TrackerLog Model

```swift
@Model
final class TrackerLog {
    var id: UUID
    var timestamp: Date
    var assignedDay: Date          // Calculated based on DayAssignment

    // Flexible value storage
    var intValue: Int?             // For integer + levels (level.id)
    var boolValue: Bool?           // For boolean
    var note: String?              // Optional note/trigger

    // Metadata
    var syncedToHealthKit: Bool
    var tracker: Tracker?
}
```

**`assignedDay` Calculation:**
```swift
var assignedDay: Date {
    switch tracker.dayAssignment {
    case .timestamp:
        return Calendar.current.startOfDay(for: timestamp)
    case .cutoffHour(let hour):
        let logHour = Calendar.current.component(.hour, from: timestamp)
        let startOfDay = Calendar.current.startOfDay(for: timestamp)
        if logHour < hour {
            return Calendar.current.date(byAdding: .day, value: -1, to: startOfDay)!
        }
        return startOfDay
    }
}
```

---

## Streak Calculation

### DayOutcome

```swift
enum DayOutcome {
    case success           // Day meets SuccessCondition
    case needsGrace        // Needs reward to save streak
    case breaksStreak      // Immediately breaks streak
    case noData            // No logs for this day
}
```

### Algorithm (Forward Iteration)

```
FOR each day FROM firstLog TO today:
    outcome = evaluate(day, logs, successCondition)

    SWITCH outcome:
        success:
            streak += 1
            IF streak % earnEveryDays == 0 AND rewards < maxOnHand:
                rewards += 1

        needsGrace:
            IF rewards > 0 AND canHealGrace:
                rewards -= 1
                streak += 1
            ELSE:
                streak = 0
                rewards = 0

        breaksStreak:
            streak = 0
            rewards = 0

        noData:
            // Depends on successCondition
            IF successCondition == .logNotExists:
                streak += 1  // No log = success for avoidance
            ELSE IF rewardConfig != nil:
                // Treat like needsGrace
            ELSE:
                // No reward system = graceful (don't break)
```

**Critical:** Forward iteration is REQUIRED for correct reward earning/consumption order.

---

## SmartReminder Integration

### Extended ActivityType

```swift
public enum ActivityType: Codable, Hashable {
    // Session-based (remain separate)
    case mindfulness
    case workout

    // Log-based (generic)
    case tracker(UUID)   // Links to Tracker.id
}
```

### Cancel Logic on Log

```swift
// TrackerManager.swift
func logEntry(for tracker: Tracker, ...) -> TrackerLog {
    let log = TrackerLog(...)
    // ... save log ...

    // Cancel matching SmartReminders
    if tracker.supportsReminders {
        SmartReminderEngine.shared.cancelMatchingReminders(
            for: .tracker(tracker.id),
            completedAt: log.timestamp
        )
    }

    return log
}
```

---

## Configuration Examples

### NoAlc (Migration Target)

```swift
Tracker(
    name: "NoAlc",
    icon: "🍷",
    type: .saboteur,

    valueType: .levels([
        TrackerLevel(id: 0, key: "steady", icon: "💧", labelKey: "Steady", streakEffect: .success),
        TrackerLevel(id: 1, key: "easy", icon: "✨", labelKey: "Easy", streakEffect: .needsGrace),
        TrackerLevel(id: 2, key: "wild", icon: "💥", labelKey: "Wild", streakEffect: .needsGrace)
    ]),

    successCondition: .levelMatches(["steady"]),
    dayAssignment: .cutoffHour(18),
    storageStrategy: .healthKit("HKQuantityTypeIdentifierNumberOfAlcoholicBeverages"),

    rewardConfig: RewardConfig(earnEveryDays: 7, maxOnHand: 3, canHealGrace: true),

    supportsReminders: true,
    defaultLookbackHours: 24
)
```

### Water Tracker

```swift
Tracker(
    name: "Wasser trinken",
    icon: "💧",
    type: .good,

    valueType: .integer(goal: 8),
    successCondition: .meetsGoal,
    dayAssignment: .timestamp,
    storageStrategy: .both("HKQuantityTypeIdentifierDietaryWater"),

    rewardConfig: nil,  // No joker system

    supportsReminders: true,
    defaultLookbackHours: 12
)
```

### Doomscrolling (Awareness)

```swift
Tracker(
    name: "Doomscrolling",
    icon: "📱",
    type: .saboteur,

    valueType: .boolean,
    successCondition: .logExists,  // Logging = awareness exercise
    dayAssignment: .timestamp,
    storageStrategy: .local,

    rewardConfig: nil,

    supportsReminders: true,
    defaultLookbackHours: 24
)
```

### Mood Tracker

```swift
Tracker(
    name: "Stimmung",
    icon: "😊",
    type: .good,

    valueType: .levels([
        TrackerLevel(id: 1, key: "awful", icon: "😢", labelKey: "Awful", streakEffect: .success),
        TrackerLevel(id: 2, key: "bad", icon: "😕", labelKey: "Bad", streakEffect: .success),
        TrackerLevel(id: 3, key: "okay", icon: "😐", labelKey: "Okay", streakEffect: .success),
        TrackerLevel(id: 4, key: "good", icon: "🙂", labelKey: "Good", streakEffect: .success),
        TrackerLevel(id: 5, key: "great", icon: "😊", labelKey: "Great", streakEffect: .success)
    ]),

    successCondition: .logExists,  // Any mood logged = success
    dayAssignment: .timestamp,
    storageStrategy: .both("HKStateOfMind"),

    rewardConfig: nil,

    supportsReminders: true,
    defaultLookbackHours: 20
)
```

---

## Migration Plan: NoAlc

### Phase 1: Preparation
- [ ] Implement Generic Tracker System components
- [ ] Add migration flag to detect first launch after update
- [ ] Create NoAlc tracker preset with full configuration

### Phase 2: Data Migration
- [ ] Read existing HealthKit NoAlc data
- [ ] Create Tracker instance with NoAlc configuration
- [ ] Link existing SmartReminders (ActivityType.noalc → .tracker(id))
- [ ] Preserve streak and rewards state

### Phase 3: UI Migration
- [ ] NoAlc card uses generic TrackerCardView
- [ ] NoAlc sheet uses generic LevelSelectionView
- [ ] Remove NoAlcManager.swift (logic now in StreakCalculator)

### Phase 4: Cleanup
- [ ] Remove legacy ActivityType.noalc (deprecated)
- [ ] Remove NoAlcManager.swift
- [ ] Update documentation

---

## What Stays Separate

| Feature | Reason |
|---------|--------|
| **Mindfulness Timer** | Timer-based, creates HealthKit sessions |
| **Workout Timer** | Timer-based, creates HKWorkout |
| **Breathing Timer** | Timer-based, creates HealthKit sessions |

These are **session-based** features that run timers and write HealthKit session data. They are fundamentally different from **log-based** trackers.

---

## References

- `trackers.md` - Current tracker implementation (to be superseded)
- `noalc-tracker.md` - NoAlc-specific details (migration source)
- `smart-reminders.md` - SmartReminder system
- `streaks-rewards.md` - Reward calculation details
- `.agent-os/standards/healthkit/date-semantics.md` - Forward iteration requirement
