# Core Components - Detailed Documentation

Complete reference for all major components in Meditationstimer.

---

## 1. TwoPhaseTimerEngine (Services/TwoPhaseTimerEngine.swift)

**Purpose:** The state machine for the "Offen" (free) meditation timer with two sequential phases.

### Key Features
- State machine with three states: `.idle`, `.phase1(remaining)`, `.phase2(remaining)`, `.finished`
- Uses `Timer.publish(every: 0.05)` for UI-driven updates (foreground only)
- Date-based calculations for precision: `startDate`, `phase1EndDate`, `endDate`
- Automatic termination detection via `UIApplication.willTerminateNotification`
- No background timers; relies on notifications if app backgrounds

### Usage Flow
```swift
engine.start(phase1Minutes: 15, phase2Minutes: 3)
// UI observes engine.state changes and updates display
engine.cancel()  // Manual stop or app termination
```

### Integration Points
- OffenView reads state for UI updates
- Watch app (ContentView) uses the same engine for consistency
- LiveActivityController reads `endDate` properties for Live Activity updates

---

## 2. HealthKitManager (Services/HealthKitManager.swift)

**Purpose:** Centralized, robust HealthKit integration for logging and reading health data.

### Key Operations
- **Write:** `logMindfulness(start:end:)` – logs meditation as HKCategoryType.mindfulSession
- **Write:** `logWorkout(start:end:activity:)` – logs HIIT workouts as HKWorkout
- **Read:** `fetchActivityDaysDetailedFiltered(forMonth:)` – gets meditation/workout days with type tracking
- **Read:** `fetchDailyMinutesFiltered(from:to:)` – sums daily activity minutes by type
- **Read:** `hasActivity(ofType:inRange:)` – checks for activity in a date range
- **Authorization:** `requestAuthorization()` – prompts user with proper timing guards

### Design Decisions
- Only logs Phase 1 duration for "Offen" meditations (Phase 2 is reflection, not tracked)
- Filters by app source (`appSource`) to exclude external data
- Minimum 2-minute threshold for streak eligibility
- Graceful error handling; logging failures don't block user experience

### Used By
- OffenView, AtemView, WorkoutsView (logging sessions)
- StreakManager (calculating current streaks & rewards)
- CalendarView (displaying activity history)

---

## 3. StreakManager (Services/StreakManager.swift)

**Purpose:** Calculates meditation and workout streaks with reward progression.

### State
```swift
@Published var meditationStreak: StreakData  // currentStreakDays, rewardsEarned, lastActivityDate
@Published var workoutStreak: StreakData
```

### Streak Logic
- Consecutive days with ≥2 minutes of activity = streak day
- Rewards: 1 per 7 consecutive days (max 3 rewards)
- No activity today: streak day ends, rewards decay by 1 (unless already 0, then reset)
- Data source: HealthKit (filters by app source)

### Used By
- ContentView (shared environment injection)
- All tabs display current streaks and reward badges

---

## 4. LiveActivityController (Meditationstimer iOS/LiveActivityController.swift)

**Purpose:** Centralized Live Activity (Dynamic Island) management for all iOS tabs.

### Architecture
- Singleton pattern (created in Meditationstimer_iOSApp as `@StateObject`)
- Injected via `@EnvironmentObject` into ContentView and all tabs
- Ownership model: tracks which tab owns the current activity (`ownerId`)
- Conflict resolution: if tab B tries to start while tab A is active, ends tab A's activity first

### API
```swift
func start(title:, phase:, endDate:, ownerId:)       // Simple start
func requestStart(...) -> StartResult                  // Detects conflicts
func forceStart(...)                                   // End existing + start new
func update(phase:, endDate:, isPaused:) async        // Update running activity
func end(immediate:) async                             // End current activity
```

### State in MeditationAttributes
```swift
struct ContentState: Codable {
    var endDate: Date        // Phase end time (for live countdown)
    var phase: Int           // 1=meditation, 2=besinnung/reflection, etc.
    var ownerId: String?     // "OffenTab", "AtemTab", "WorkoutsTab"
    var isPaused: Bool       // For visual feedback
}
```

### Integration
- OffenView: starts activity on session begin, updates on phase transition, ends on finish
- AtemView: starts/updates/ends per breathing session
- WorkoutsView: starts/updates/ends per workout session

---

## 5. GongPlayer (Services/GongPlayer.swift)

**Purpose:** Audio playback service for meditation cues and transitions.

### Features
- Searches for audio files in priority order: .caf → .wav → .mp3
- Maintains array of active players to prevent early garbage collection
- Supports completion handlers for sequenced audio playback
- Graceful fallback: no audio files = silent skip

### Usage
```swift
let gong = GongPlayer()
gong.play(named: "gong-dreimal") { print("Done") }
gong.play()  // Default: "gong"
```

### Audio Files Expected
- `gong` – default gong sound
- `gong-Ende` – end of session
- `gong-dreimal` – phase transition (3 short gongs)
- `einatmen`, `ausatmen`, `halten-ein`, `halten-aus` – breathing cues

### Used By
- OffenView: start, phase transition, end gongs
- AtemView: breathing phase cues (local GongPlayer instance to avoid conflicts)
- WorkoutsView: uses separate SoundPlayer (different requirements)

---

## 6. HeartRateStream (Services/HeartRateStream.swift)

**Purpose:** Real-time heart rate monitoring during meditation on watchOS.

### Features
- Uses HKAnchoredObjectQuery for streaming heart rate samples
- Auto-updates via updateHandler as new HR data arrives
- Generates summary (min/avg/max) for session report

### Used By
- Watch app ContentView: starts HR stream during meditation, displays HR list after session

---

## 7. RuntimeSessionHelper (Services/RuntimeSessionHelper.swift)

**Purpose:** WKExtendedRuntimeSession management for watchOS.

### Features
- Extends watch app runtime to ~30 minutes for long meditation sessions
- Manages session lifecycle with start/stop
- Invokes callbacks on expiration or invalidation

### Used By
- Watch app ContentView: activated on session start, stopped on finish/cancel

---

## 8. NotificationHelper (Services/NotificationHelper.swift)

**Purpose:** Local notification scheduling on watchOS.

### Features
- Requests user notification permissions
- Schedules phase-end notifications
- Cancels all pending notifications on session end

### Used By
- Watch app: schedules notifications for phase end times

---

## 9. BackgroundAudioKeeper (Meditationstimer iOS/BackgroundAudioKeeper.swift)

**Purpose:** Keeps audio session alive to prevent iOS from killing meditation timer sounds.

### Technical Approach
- Plays silent audio loop (silence.caf or generated 1-second WAV)
- Volume set to 0.0 (inaudible)
- Prevents iOS from suspending audio session during meditation

### Used By
- OffenView: starts on session begin, stops on session end

---

## 10. PhoneMindfulnessReceiver (Meditationstimer iOS/PhoneMindfulnessReceiver.swift)

**Purpose:** WatchConnectivity handler for Watch→iPhone communication.

### Data Flow
1. Watch app logs meditation session and sends start/end timestamps to iPhone
2. PhoneMindfulnessReceiver receives message via WatchConnectivity
3. Logs the session to HealthKit (avoiding duplication with Watch's direct logging)

### Used By
- Created in Meditationstimer_iOSApp; runs throughout app lifecycle
