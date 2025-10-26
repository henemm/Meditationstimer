# State Management & Data Flows

Detailed workflows and state management patterns in Meditationstimer.

---

## Timer Session Flow (Offen Tab)

### Complete User Flow

```
User sets phase1=15min, phase2=3min
         ↓
User taps "Start"
         ↓
OffenView.start() calls:
  • engine.start(phase1Minutes, phase2Minutes) → timer begins
  • bgAudio.start()                             → audio session alive
  • liveActivity.start(...)                     → lock screen activity
  • gong.play(named: "gong")                    → start sound
         ↓
TwoPhaseTimerEngine updates state:
  • state = .phase1(remaining: 900) → UI updates every 50ms
  • Countdown displays "15:00", "14:59", etc.
         ↓
After 15 minutes:
  • state transitions to .phase2(remaining: 180)
  • OffenView observes state change:
    - Stop phase1 audio keeper? No, keep alive for phase2
    - Play triple gong (gong-dreimal)
    - Update Live Activity to phase 2
         ↓
After 3 more minutes:
  • state = .finished
  • TwoPhaseTimerEngine stops ticker
  • OffenView observes .finished:
    - Play end gong (gong-ende)
    - Log session to HealthKit (Phase 1 duration only)
    - End Live Activity
    - Stop audio keeper
    - Update streak
         ↓
Session complete, UI returns to idle state
```

---

## Watch App Flow

### watchOS Meditation Session

```
Watch User sets phase1=15min, phase2=3min
         ↓
Taps "Start"
         ↓
WatchOS ContentView calls:
  • runtime.start()                     → extended runtime session
  • engine.start(phase1Minutes, ...)    → timer begins
  • notifier.schedulePhaseEndNotification() → schedules notifications
  • hrStream.start(from: startDate)     → begins HR monitoring
         ↓
During Session:
  • engine.state publishes updates
  • UI displays countdown
  • hrStream collects HR samples
  • haptic feedback on phase transitions
         ↓
Session Ends:
  • hrStream.stop()
  • Log to HealthKit
  • Send start/end to iPhone via WatchConnectivity (optional)
  • runtime.stop()
  • notifier.cancelAll()
```

---

## Data Persistence

### App Settings (UserDefaults)

```
• phase1Minutes, phase2Minutes      → @AppStorage in views
• atemPresets                       → Codable JSON in UserDefaults
• logMeditationAsYogaWorkout        → Feature flag
• logWorkoutsAsMindfulness          → Feature flag
```

### Historical Data (HealthKit)

```
• Mindfulness sessions              → HKCategoryType.mindfulSession
• Workout sessions                  → HKWorkout
• Heart rate samples                → HKQuantityType.heartRate (watchOS)
```

### Computed Streaks (from HealthKit)

```
• meditationStreak, workoutStreak   → Recalculated on demand
• Cached in StreakManager @Published vars
• Updated via updateStreaks() task
```

---

## Meditation Session Flow (Complete Example: Offen Tab)

### User Experience

1. User opens app → ContentView shows three tabs
2. User selects "Offen" (free meditation) tab → OffenView displays
3. User adjusts phase durations with wheel pickers (e.g., 15 min + 3 min)
4. User taps "Start" button
5. Gong sound plays (meditation begins)
6. Lock screen/Dynamic Island shows countdown timer
7. User sees circular progress ring on screen, with time remaining
8. 15 minutes pass...
9. Triple gong sounds (phase transition)
10. UI updates to show "Besinnung" (reflection) phase, 3 minutes remaining
11. 3 more minutes pass...
12. Final gong sounds
13. UI shows "Session complete"
14. Session is logged to Apple Health as "Mindfulness" activity (15 minutes)
15. Streak is updated if applicable
16. Lock screen activity disappears

### Behind the Scenes

- TwoPhaseTimerEngine drives all timing via Timer.publish updates
- BackgroundAudioKeeper prevents iOS from killing audio if user switches apps
- GongPlayer handles all sound playback
- LiveActivityController keeps lock screen activity in sync
- HealthKitManager logs the session asynchronously
- StreakManager recalculates streaks from HealthKit data

---

## Multi-Target Code Sharing Strategy

### Shared Code (Available to All Targets)

The `/Services/` directory is accessible to all targets (iOS app, Watch app, Widget):

```
iOS App Target:
  ✓ Services/TwoPhaseTimerEngine.swift
  ✓ Services/HealthKitManager.swift
  ✓ Services/GongPlayer.swift
  ✓ Services/StreakManager.swift
  ... all Services

Watch App Target:
  ✓ Services/TwoPhaseTimerEngine.swift
  ✓ Services/HealthKitManager.swift
  ✓ Services/HeartRateStream.swift
  ✓ Services/RuntimeSessionHelper.swift
  ✓ Services/NotificationHelper.swift
  (subset of services, no background audio, no live activity)

Widget Target:
  ✓ Services/ (read-only for ActivityKit data)
  ✓ MeditationActivityAttributes.swift
  (minimal dependencies: ActivityKit, SwiftUI)
```

### Platform-Specific Code

**iOS Only:**
- `BackgroundAudioKeeper` – requires UIKit, audio session management
- `LiveActivityController` – requires ActivityKit (iOS 16.1+)
- `PhoneMindfulnessReceiver` – WatchConnectivity (iPhone side)
- All tab views (OffenView, AtemView, WorkoutsView)
- SmartReminderEngine, SmartRemindersView

**watchOS Only:**
- HeartRateStream (Watch HR API)
- RuntimeSessionHelper (WKExtendedRuntimeSession)
- Watch app UI (simplified ContentView)

**Widget Only:**
- MeditationstimerWidget (static widgets)
- MeditationstimerWidgetLiveActivity (Live Activity dynamic island)

### Data Synchronization

**No Explicit Sync Protocol:**
The app relies on **HealthKit as the source of truth** for all historical data. Both iOS and Watch apps independently log sessions to HealthKit, then read back to calculate streaks and display history.

**WatchConnectivity:**
- Used for **optional real-time feedback** only (Watch tells iPhone about completed sessions)
- Not required for correctness; HealthKit integration is sufficient
