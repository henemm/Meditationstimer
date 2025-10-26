# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

# Meditationstimer: High-Level Architecture Documentation

## Overview

**Meditationstimer** is a comprehensive meditation and wellness app built with SwiftUI for iOS, watchOS, and featuring a Live Activity widget. The app enables users to practice guided meditation with customizable timers, breathing exercises (Atem), high-intensity interval training (HIIT workouts), activity tracking, and streak management.

**Target Platforms:**
- iOS 16.1+ (primary experience with Live Activities / Dynamic Island)
- watchOS 9.0+ (companion app with extended runtime support)
- iOS Widget Extension (Live Activities and static widgets)

**Current Version:** 2.5.3+

---

## Architecture Overview

The codebase follows a **multi-target, horizontally-layered architecture** with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────────────┐
│                        iOS / watchOS / Widget Apps                  │
│  (UI Layer: ContentView, Tabs, Views)                               │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    Shared Service Layer (Services/)                  │
│  • TwoPhaseTimerEngine    • HealthKitManager     • GongPlayer        │
│  • HeartRateStream        • StreakManager        • NotificationHelper│
│  • BackgroundNotifier     • RuntimeSessionHelper • AppTerminationDet │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    Data & Model Layer                                │
│  • MeditationAttributes   • SmartReminder        • Preset (Atem)     │
│  • StreakData            • Activity Types       • Shared Constants   │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│              Platform Frameworks                                     │
│  • HealthKit  • ActivityKit  • WatchConnectivity  • WatchKit         │
│  • AVFoundation  • UserNotifications  • BackgroundTasks              │
└─────────────────────────────────────────────────────────────────────┘
```

### Key Design Principles

1. **Foreground-First Timer Design:** All meditation timers run only in foreground to avoid iOS background execution limits. Background notifications serve as backup only.

2. **Shared Services, Separate UI:** Core business logic (timers, health logging, notifications) lives in `/Services/` and is reused across all targets. Each target (iOS app, Watch app, Widget) has independent UI.

3. **Reactive State Management:** Uses SwiftUI's `@Published` (ObservableObject) with Combine for reactive updates across the app. The timer engine publishes state changes that drive UI updates in real-time.

4. **Live Activity as Cross-Tab Coordination:** The `LiveActivityController` runs on iOS and is shared across all tabs (Offen, Atem, Workouts) to ensure only one meditation/workout is active at a time on the lock screen/Dynamic Island.

5. **HealthKit as Single Source of Truth for History:** All historical activity data (streaks, calendar, daily minutes) comes from HealthKit, ensuring consistency with Apple Health and avoiding duplicate storage.

---

## Build Commands and Development Workflow

### Available Schemes

The project has two main schemes:
- **Lean Health Timer**: The iOS app with Watch app companion and Widget extension (Release builds use this name)
- **Meditationstimer Watch App**: watchOS companion app

### Building the Project

**Build iOS app with all targets (iOS + Watch + Widget):**
```bash
xcodebuild -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build
```

**Build for device (requires proper signing):**
```bash
xcodebuild -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  build
```

**Build Watch app only:**
```bash
xcodebuild -project Meditationstimer.xcodeproj \
  -scheme "Meditationstimer Watch App" \
  -configuration Debug \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' \
  build
```

**Archive for App Store distribution:**
```bash
xcodebuild -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -configuration Release \
  -archivePath "./build/Meditationstimer.xcarchive" \
  archive
```

### Running Tests

**Important:** Test files are located in `Tests/` directory but need to be added to a test target in Xcode first. See "Testing & Debugging" section below for setup instructions.

**Run all tests (once test target is configured):**
```bash
xcodebuild test \
  -project Meditationstimer.xcodeproj \
  -scheme "MeditationstimerTests" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

**Run specific test:**
```bash
xcodebuild test \
  -project Meditationstimer.xcodeproj \
  -scheme "MeditationstimerTests" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:MeditationstimerTests/StreakManagerTests/testStreakCalculation
```

**Run in Xcode:**
- Quick test shortcut: `Cmd+U`
- Test a single file: Click the diamond icon next to the test class
- Test a single method: Click the diamond icon next to the test method

### Development in Xcode

**Open the project:**
```bash
open Meditationstimer.xcodeproj
```

**Quick build shortcut:** `Cmd+B`
**Run on simulator:** `Cmd+R`
**Run tests:** `Cmd+U`
**Clean build folder:** `Cmd+Shift+K`

### Important Notes

- The project uses **HealthKit**, so you need a physical device or configured simulator with HealthKit support for full functionality
- **Live Activities** (Dynamic Island) require iOS 16.1+ and only work on physical devices with Dynamic Island hardware or iOS 17.2+ simulators
- The **Widget extension** is automatically included when building the "Lean Health Timer" scheme
- Build artifacts are typically stored in `build/` directory (gitignored)

---

## Project Structure

```
Meditationstimer/
├── Services/                          # Shared services used across all targets
│   ├── TwoPhaseTimerEngine.swift      # Core timer state machine (Offen tab)
│   ├── HealthKitManager.swift         # HealthKit read/write operations
│   ├── StreakManager.swift            # Streak calculation & reward logic
│   ├── GongPlayer.swift               # Audio playback service
│   ├── HeartRateStream.swift          # Heart rate monitoring (watchOS)
│   ├── RuntimeSessionHelper.swift     # Extended runtime for watchOS
│   ├── NotificationHelper.swift       # Local notifications (watchOS)
│   ├── BackgroundNotifier.swift       # Background notification handling (iOS)
│   ├── SessionManager.swift           # Live Activity management (legacy)
│   ├── AppTerminationDetector.swift   # App termination detection
│   ├── MeditationEngine.swift         # Type alias for TwoPhaseTimerEngine
│   └── ...
│
├── Meditationstimer iOS/              # Main iOS app target
│   ├── Meditationstimer_iOSApp.swift  # App entry point, environment setup
│   ├── ContentView.swift              # Tab container & cross-tab logic
│   │
│   ├── Tabs/
│   │   ├── OffenView.swift            # "Offen" - Free meditation (2-phase timer)
│   │   ├── AtemView.swift             # "Atem" - Guided breathing with presets
│   │   └── WorkoutsView.swift         # "Workouts" - HIIT timer with cues
│   │
│   ├── UI/
│   │   ├── CircularRing.swift         # Reusable progress ring component
│   │   ├── GlassCard.swift            # Styled card component
│   │   └── WheelPicker.swift          # Custom wheel picker
│   │
│   ├── Models/
│   │   ├── SmartReminder.swift        # Reminder scheduling model
│   │   └── BreathPreset.swift         # Breathing preset data
│   │
│   ├── MeditationActivityAttributes.swift # Live Activity data structure
│   ├── LiveActivityController.swift    # Live Activity orchestration (iOS only)
│   ├── BackgroundAudioKeeper.swift     # Keep audio session alive during meditation
│   ├── PhoneMindfulnessReceiver.swift  # WatchConnectivity handler
│   ├── SettingsSheet.swift            # Shared settings UI
│   ├── SmartReminderEngine.swift      # Smart reminder scheduling
│   ├── CalendarView.swift             # Activity calendar UI
│   ├── Colors.swift                   # Color constants
│   └── StreakManager.swift            # iOS-specific streak UI wrapper
│
├── Meditationstimer Watch App/        # watchOS companion app
│   ├── MeditationstimerApp.swift      # Watch app entry point
│   └── ContentView.swift              # Watch UI (picker + timer display)
│
├── MeditationstimerWidget/            # Live Activity Widget Extension
│   ├── MeditationstimerWidgetBundle.swift    # Widget bundle entry
│   ├── MeditationstimerWidget.swift          # Static widgets
│   ├── MeditationstimerWidgetLiveActivity.swift # Live Activity UI
│   ├── MeditationActivityAttributes.swift    # Widget data structure
│   ├── LiveActivityTimerLogic.swift          # Widget timer helper
│   ├── MeditationstimerWidgetControl.swift   # Control widget
│   └── AppIntent.swift                       # Widget actions
│
└── Models/                            # Shared models (deprecated, mostly empty)
    └── ...
```

---

## Core Components

### 1. **TwoPhaseTimerEngine** (Services/TwoPhaseTimerEngine.swift)

**Purpose:** The state machine for the "Offen" (free) meditation timer with two sequential phases.

**Key Features:**
- State machine with three states: `.idle`, `.phase1(remaining)`, `.phase2(remaining)`, `.finished`
- Uses `Timer.publish(every: 0.05)` for UI-driven updates (foreground only)
- Date-based calculations for precision: `startDate`, `phase1EndDate`, `endDate`
- Automatic termination detection via `UIApplication.willTerminateNotification`
- No background timers; relies on notifications if app backgrounds

**Usage Flow:**
```swift
engine.start(phase1Minutes: 15, phase2Minutes: 3)
// UI observes engine.state changes and updates display
engine.cancel()  // Manual stop or app termination
```

**Integration Points:**
- OffenView reads state for UI updates
- Watch app (ContentView) uses the same engine for consistency
- LiveActivityController reads `endDate` properties for Live Activity updates

### 2. **HealthKitManager** (Services/HealthKitManager.swift)

**Purpose:** Centralized, robust HealthKit integration for logging and reading health data.

**Key Operations:**
- **Write:** `logMindfulness(start:end:)` – logs meditation as HKCategoryType.mindfulSession
- **Write:** `logWorkout(start:end:activity:)` – logs HIIT workouts as HKWorkout
- **Read:** `fetchActivityDaysDetailedFiltered(forMonth:)` – gets meditation/workout days with type tracking
- **Read:** `fetchDailyMinutesFiltered(from:to:)` – sums daily activity minutes by type
- **Read:** `hasActivity(ofType:inRange:)` – checks for activity in a date range
- **Authorization:** `requestAuthorization()` – prompts user with proper timing guards

**Design Decisions:**
- Only logs Phase 1 duration for "Offen" meditations (Phase 2 is reflection, not tracked)
- Filters by app source (`appSource`) to exclude external data
- Minimum 2-minute threshold for streak eligibility
- Graceful error handling; logging failures don't block user experience

**Used By:**
- OffenView, AtemView, WorkoutsView (logging sessions)
- StreakManager (calculating current streaks & rewards)
- CalendarView (displaying activity history)

### 3. **StreakManager** (Services/StreakManager.swift)

**Purpose:** Calculates meditation and workout streaks with reward progression.

**State:**
```swift
@Published var meditationStreak: StreakData  // currentStreakDays, rewardsEarned, lastActivityDate
@Published var workoutStreak: StreakData
```

**Streak Logic:**
- Consecutive days with ≥2 minutes of activity = streak day
- Rewards: 1 per 7 consecutive days (max 3 rewards)
- No activity today: streak day ends, rewards decay by 1 (unless already 0, then reset)
- Data source: HealthKit (filters by app source)

**Used By:**
- ContentView (shared environment injection)
- All tabs display current streaks and reward badges

### 4. **LiveActivityController** (Meditationstimer iOS/LiveActivityController.swift)

**Purpose:** Centralized Live Activity (Dynamic Island) management for all iOS tabs.

**Architecture:**
- Singleton pattern (created in Meditationstimer_iOSApp as `@StateObject`)
- Injected via `@EnvironmentObject` into ContentView and all tabs
- Ownership model: tracks which tab owns the current activity (`ownerId`)
- Conflict resolution: if tab B tries to start while tab A is active, ends tab A's activity first

**API:**
```swift
func start(title:, phase:, endDate:, ownerId:)       // Simple start
func requestStart(...) -> StartResult                  // Detects conflicts
func forceStart(...)                                   // End existing + start new
func update(phase:, endDate:, isPaused:) async        // Update running activity
func end(immediate:) async                             // End current activity
```

**State in MeditationAttributes:**
```swift
struct ContentState: Codable {
    var endDate: Date        // Phase end time (for live countdown)
    var phase: Int           // 1=meditation, 2=besinnung/reflection, etc.
    var ownerId: String?     // "OffenTab", "AtemTab", "WorkoutsTab"
    var isPaused: Bool       // For visual feedback
}
```

**Integration:**
- OffenView: starts activity on session begin, updates on phase transition, ends on finish
- AtemView: starts/updates/ends per breathing session
- WorkoutsView: starts/updates/ends per workout session

### 5. **GongPlayer** (Services/GongPlayer.swift)

**Purpose:** Audio playback service for meditation cues and transitions.

**Features:**
- Searches for audio files in priority order: .caf → .wav → .mp3
- Maintains array of active players to prevent early garbage collection
- Supports completion handlers for sequenced audio playback
- Graceful fallback: no audio files = silent skip

**Usage:**
```swift
let gong = GongPlayer()
gong.play(named: "gong-dreimal") { print("Done") }
gong.play()  // Default: "gong"
```

**Audio Files Expected:**
- `gong` – default gong sound
- `gong-Ende` – end of session
- `gong-dreimal` – phase transition (3 short gongs)
- `einatmen`, `ausatmen`, `halten-ein`, `halten-aus` – breathing cues

**Used By:**
- OffenView: start, phase transition, end gongs
- AtemView: breathing phase cues (local GongPlayer instance to avoid conflicts)
- WorkoutsView: uses separate SoundPlayer (different requirements)

### 6. **HeartRateStream** (Services/HeartRateStream.swift)

**Purpose:** Real-time heart rate monitoring during meditation on watchOS.

**Features:**
- Uses HKAnchoredObjectQuery for streaming heart rate samples
- Auto-updates via updateHandler as new HR data arrives
- Generates summary (min/avg/max) for session report

**Used By:**
- Watch app ContentView: starts HR stream during meditation, displays HR list after session

### 7. **RuntimeSessionHelper** (Services/RuntimeSessionHelper.swift)

**Purpose:** WKExtendedRuntimeSession management for watchOS.

**Features:**
- Extends watch app runtime to ~30 minutes for long meditation sessions
- Manages session lifecycle with start/stop
- Invokes callbacks on expiration or invalidation

**Used By:**
- Watch app ContentView: activated on session start, stopped on finish/cancel

### 8. **NotificationHelper** (Services/NotificationHelper.swift)

**Purpose:** Local notification scheduling on watchOS.

**Features:**
- Requests user notification permissions
- Schedules phase-end notifications
- Cancels all pending notifications on session end

**Used By:**
- Watch app: schedules notifications for phase end times

### 9. **BackgroundAudioKeeper** (Meditationstimer iOS/BackgroundAudioKeeper.swift)

**Purpose:** Keeps audio session alive to prevent iOS from killing meditation timer sounds.

**Technical Approach:**
- Plays silent audio loop (silence.caf or generated 1-second WAV)
- Volume set to 0.0 (inaudible)
- Prevents iOS from suspending audio session during meditation

**Used By:**
- OffenView: starts on session begin, stops on session end

### 10. **PhoneMindfulnessReceiver** (Meditationstimer iOS/PhoneMindfulnessReceiver.swift)

**Purpose:** WatchConnectivity handler for Watch→iPhone communication.

**Data Flow:**
1. Watch app logs meditation session and sends start/end timestamps to iPhone
2. PhoneMindfulnessReceiver receives message via WatchConnectivity
3. Logs the session to HealthKit (avoiding duplication with Watch's direct logging)

**Used By:**
- Created in Meditationstimer_iOSApp; runs throughout app lifecycle

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

---

## State Management & Data Flow

### Timer Session Flow (Offen Tab)

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

### Watch App Flow

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

### Data Persistence

```
App Settings (UserDefaults):
  • phase1Minutes, phase2Minutes      → @AppStorage in views
  • atemPresets                       → Codable JSON in UserDefaults
  • logMeditationAsYogaWorkout        → Feature flag
  • logWorkoutsAsMindfulness          → Feature flag

Historical Data (HealthKit):
  • Mindfulness sessions              → HKCategoryType.mindfulSession
  • Workout sessions                  → HKWorkout
  • Heart rate samples                → HKQuantityType.heartRate (watchOS)

Computed Streaks (from HealthKit):
  • meditationStreak, workoutStreak   → Recalculated on demand
  • Cached in StreakManager @Published vars
  • Updated via updateStreaks() task
```

---

## Meditation Session Flow (Complete Example: Offen Tab)

**User Experience:**
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

**Behind the Scenes:**
- TwoPhaseTimerEngine drives all timing via Timer.publish updates
- BackgroundAudioKeeper prevents iOS from killing audio if user switches apps
- GongPlayer handles all sound playback
- LiveActivityController keeps lock screen activity in sync
- HealthKitManager logs the session asynchronously
- StreakManager recalculates streaks from HealthKit data

---

## Key Architectural Decisions & Rationale

### 1. **Foreground-Only Timers**
**Decision:** All meditation timers run only in foreground (app must stay active).
**Rationale:** iOS severely restricts background execution. Attempting to keep a timer running in the background leads to frequent termination. Better UX to require app to stay active for the meditation session. Users with screens locked still get notifications as backup.

### 2. **Live Activity as Cross-Tab Arbiter**
**Decision:** Only one Live Activity can exist at a time across all tabs (Offen, Atem, Workouts).
**Rationale:** iOS lock screen/Dynamic Island is a limited real estate. Prevents confusing overlapping activities. LiveActivityController's ownership model ensures deterministic conflict resolution.

### 3. **HealthKit as Source of Truth**
**Decision:** All historical activity data (streaks, calendar) comes from HealthKit, not app-local database.
**Rationale:** Integrates with Apple Health (app users expect their data to appear in Health.app). Single source of truth prevents sync bugs. HealthKit queries are expensive, so streaks are cached in StreakManager and updated on-demand.

### 4. **Service Layer Sharing**
**Decision:** All business logic (timers, HealthKit, notifications) lives in `/Services/` and is target-agnostic.
**Rationale:** Enables code reuse across iOS app, Watch app, and Widget. Services are pure Swift (no UI). Tests can mock services easily.

### 5. **Phase 1 Only for HealthKit Logging**
**Decision:** Only Phase 1 (meditation) is logged to HealthKit; Phase 2 (reflection) is not counted.
**Rationale:** Phase 2 is not meditation—it's a wind-down period. Logging only Phase 1 gives accurate "Mindfulness" minutes. Streak calculations use Phase 1 duration only.

### 6. **Date-Based Timer Calculations**
**Decision:** Timer calculates remaining time using `endDate.timeIntervalSince(now)` rather than decrementing a counter.
**Rationale:** If app is backgrounded/suspended and then returns to foreground, date-based math still gives correct remaining time. Counter-based approach would lose accuracy.

### 7. **Combine + @Published for Reactive Updates**
**Decision:** Engine state published via Combine; views observe with `@ObservedObject`.
**Rationale:** SwiftUI's reactive model. Efficient: only affected views redraw when state changes. Testable: can drive engine state and verify UI updates.

### 8. **No Background Task for Meditation Timer**
**Decision:** Meditation timer does NOT use BackgroundTasks (BGAppRefreshTask, BGProcessingTask).
**Rationale:** These tasks are for periodic, non-urgent work (e.g., data sync). They're not reliable for real-time apps. Instead, notifications serve as backup if user leaves the app.

### 9. **Watch App Uses Extended Runtime + Notifications**
**Decision:** Watch app extends runtime to ~30 min; uses notifications as fallback if session exceeds 30 min.
**Rationale:** WKExtendedRuntimeSession allows watch app to stay active for long meditations. If meditation is >30 min, watch display might lock, but notifications will still fire.

---

## Audio System

### iOS (OffenView)

**Components:**
- `GongPlayer` service instance (created in OffenView @State)
- `BackgroundAudioKeeper` to prevent iOS from killing audio session
- `AVAudioSession` configured with `.playback` category + `.mixWithOthers`

**Flow:**
```
User taps Start
  → bgAudio.start()              // silent audio keeps session alive
  → gong.play("gong")             // start sound
  → ... meditation runs ...
  → On phase transition:
    gong.play("gong-dreimal", completion: { /* update UI */ })
  → On end:
    gong.play("gong-ende")
    bgAudio.stop()                // release audio session
```

### iOS (AtemView)

**Components:**
- Local GongPlayer instance (nested inside AtemView to avoid conflicts with OffenView's GongPlayer)
- Similar audio session setup

**Breathing Cues:**
- `einatmen` – inhale phase
- `ausatmen` – exhale phase
- `halten-ein` – hold after inhale
- `halten-aus` – hold after exhale

### iOS (WorkoutsView)

**Components:**
- `SoundPlayer` class (local, distinct from GongPlayer to support round announcements and speech)
- `AVSpeechSynthesizer` for German voice announcements
- Support for round-specific audio (`round-1.caf`, `round-2.caf`, ... `round-20.caf`)

**Cues:**
- `auftakt` – pre-workout warm-up cue
- `kurz` – 3, 2, 1 second countdown
- `lang` – work/rest phase transition
- `ausklang` – final completion tone
- `last-round` – penultimate round announcement
- German voice: "Round 5 of 10", "30 seconds left", etc.

### watchOS

**Simplicity:**
- No audio (watch speaker too quiet)
- Uses haptic feedback instead (WKInterfaceDevice haptics)
- Notifications deliver any critical alerts

---

## Testing & Debugging

### Test Suite Overview

The project includes comprehensive unit tests for critical business logic components:

**Unit Test Files:**
- `Tests/TwoPhaseTimerEngineTests.swift` – Timer state machine, phase transitions, time calculations (18 test cases)
- `Tests/StreakManagerTests.swift` – Streak calculation, rewards, persistence (15 test cases)
- `Tests/HealthKitManagerTests.swift` – Date calculations, activity filtering, mocks (25+ test cases)
- `Tests/AtemViewTests.swift` – Breathing exercise logic
- `Tests/LiveActivityControllerTests.swift` – Live Activity conflict scenarios

**Total Test Coverage:** 58+ test cases covering core business logic

### Setting Up Test Target

**⚠️ Important:** Test files exist in `Tests/` but need to be added to an Xcode test target:

1. Open `Meditationstimer.xcodeproj` in Xcode
2. Go to **File → New → Target**
3. Select **iOS Unit Testing Bundle**
4. Name it `MeditationstimerTests`
5. Add test files from `Tests/` directory to the new target
6. Set the main app target as a test dependency
7. Ensure `@testable import Meditationstimer` is enabled in build settings

### Running Tests

**In Xcode:**
```
Cmd+U (run all tests)
```

**From command line:**
```bash
xcodebuild test \
  -project Meditationstimer.xcodeproj \
  -scheme "MeditationstimerTests" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

**Run specific test class:**
```bash
xcodebuild test ... -only-testing:MeditationstimerTests/StreakManagerTests
```

**Run specific test method:**
```bash
xcodebuild test ... -only-testing:MeditationstimerTests/StreakManagerTests/testStreakCalculation
```

### Test Coverage Areas

| Component | Tests | What's Tested |
|-----------|-------|---------------|
| **TwoPhaseTimerEngine** | 18 | State transitions, timer accuracy, date calculations, edge cases |
| **StreakManager** | 15 | Consecutive days, rewards (7-day intervals), persistence, gaps |
| **HealthKitManager** | 25+ | Month boundaries, leap years, activity filtering, duration calculations |
| **AtemView** | 4 | Phase mapping, duration calculations, preset validation |
| **LiveActivityController** | 1 | Ownership conflicts, force start |

### Writing New Tests

**Template for new test:**
```swift
import XCTest
@testable import Meditationstimer

final class MyComponentTests: XCTestCase {
    var component: MyComponent!

    override func setUp() {
        super.setUp()
        component = MyComponent()
    }

    override func tearDown() {
        component = nil
        super.tearDown()
    }

    func testSomething() {
        // Arrange
        let input = "test"

        // Act
        let result = component.process(input)

        // Assert
        XCTAssertEqual(result, "expected")
    }
}
```

### Debug Logging

Core services include detailed logging:
- `TwoPhaseTimerEngine` – App termination detection, timer state changes
- `LiveActivityController` – Activity lifecycle (start, update, end)
- `HealthKitManager` – HealthKit operations
- `GongPlayer` / `SoundPlayer` – Audio playback status
- `WorkoutsView.SoundPlayer` – Round announcements, speech synthesis

### Preview Support

All views include SwiftUI previews. LiveActivityController detects preview mode and skips actual ActivityKit calls.

---

## Important Files by Responsibility

### Timer Logic
- `Services/TwoPhaseTimerEngine.swift` – Two-phase meditation timer (state machine)
- `Services/MeditationEngine.swift` – Type alias wrapper

### Health Data & Tracking
- `Services/HealthKitManager.swift` – HealthKit read/write
- `Services/StreakManager.swift` – Streak calculation & reward logic
- `Meditationstimer iOS/StreakManager.swift` – iOS UI wrapper (deprecated, see Services version)

### Audio & Haptics
- `Services/GongPlayer.swift` – Meditation gong sounds
- `Meditationstimer iOS/BackgroundAudioKeeper.swift` – Prevent audio session termination
- `Meditationstimer iOS/Tabs/AtemView.swift` (local GongPlayer) – Breathing cues
- `Meditationstimer iOS/Tabs/WorkoutsView.swift` (local SoundPlayer) – Workout cues & announcements

### Live Activity & Lock Screen
- `Meditationstimer iOS/LiveActivityController.swift` – Activity orchestration
- `Meditationstimer iOS/MeditationActivityAttributes.swift` – Activity data model
- `MeditationstimerWidget/MeditationstimerWidgetLiveActivity.swift` – Lock screen/Dynamic Island UI
- `MeditationstimerWidget/MeditationActivityAttributes.swift` – Widget copy of data model

### Notifications
- `Services/NotificationHelper.swift` – Local notifications (watchOS)
- `Services/BackgroundNotifier.swift` – Background notification handling (iOS)

### Cross-Device Communication
- `Services/RuntimeSessionHelper.swift` – watchOS extended runtime
- `Meditationstimer iOS/PhoneMindfulnessReceiver.swift` – WatchConnectivity handler

### Tab Views
- `Meditationstimer iOS/Tabs/OffenView.swift` – Free meditation with two phases
- `Meditationstimer iOS/Tabs/AtemView.swift` – Guided breathing exercises
- `Meditationstimer iOS/Tabs/WorkoutsView.swift` – HIIT timer
- `Meditationstimer iOS/ContentView.swift` – Tab container & global state

### UI Components
- `Meditationstimer iOS/UI/CircularRing.swift` – Progress ring (reusable)
- `Meditationstimer iOS/UI/GlassCard.swift` – Styled card
- `Meditationstimer iOS/UI/WheelPicker.swift` – Custom wheel picker
- `Meditationstimer iOS/CalendarView.swift` – Activity calendar
- `Meditationstimer iOS/SettingsSheet.swift` – App settings

### Smart Reminders (iOS Only)
- `Meditationstimer iOS/SmartReminderEngine.swift` – Background task for reminders
- `Meditationstimer iOS/SmartRemindersView.swift` – Reminder settings UI
- `Meditationstimer iOS/Models/SmartReminder.swift` – Reminder data model

### Watch App
- `Meditationstimer Watch App/MeditationstimerApp.swift` – Watch app entry
- `Meditationstimer Watch App/ContentView.swift` – Watch UI (picker + timer)

---

## Zusammenarbeit mit Claude Code - Projektregeln

### Rollen & Verantwortung

**Henning (Product Owner):**
- Definiert WAS und WARUM
- Setzt Scope, Ziele, Prioritäten, Acceptance Criteria
- Kein Engineer, versteht keinen Code
- Testet auf echtem Device (iPhone/Apple Watch)

**Claude (Tech Lead + Developer):**
- Verantwortlich für WIE und WOMIT
- Übersetzt Anforderungen in konkrete Schritte/Code
- Keine kreativen Neuinterpretationen
- Nur das Gewünschte umsetzen

### Workflow - Vor jeder Änderung

1. **Viel abfragen** - Problem vollständig verstehen (wo, was, warum)
2. **Understanding Checklist** präsentieren (Stichpunkte: Was verstanden wurde)
3. **Eine klare Empfehlung** geben (nicht mehrere Optionen zur Wahl)
4. **Nur kritische Fragen** stellen (wo PO-Input wirklich nötig)
5. **Erst nach Bestätigung** starten

### Analysis-First Prinzip

**Keine Quick Fixes ohne Analyse!**

- Immer **vollständige Problem-Analyse** vor Lösung
- **Root Cause** mit konkreten Daten identifizieren
- **Keine spekulativen Fixes** oder Trial-and-Error
- Code lesen, verstehen, dann gezielt ändern

**Prozess:**
1. Problem-Scope vollständig erfassen
2. Alle möglichen Ursachen listen
3. Root Cause mit Sicherheit identifizieren (Code-Stellen finden)
4. Erst dann Fix implementieren
5. Sofort testen & validieren

**Motto:** "Analyse thoroughly, solve correctly, verify immediately"

### Scoping Limits

**Pro Änderung (Bug oder Feature):**
- Max **4-5 Dateien** ändern
- **±250 LoC** insgesamt (Additions + Modifications + Deletions)
- **Keine Seiteneffekte** außerhalb des Tickets
  - Kein "Ich ändere mal schnell dies oder das nebenbei"
  - Kein Drive-by Refactoring
- Funktionen: **≤50 LoC**

**Bei Überschreitung:**
- STOP und nachfragen mit konkreter Schätzung
- Ticket in kleinere Teile splitten vorschlagen

### Testing-Strategie

**Business Logic (Timer, Streak, HealthKit, Sound):**
- Unit Tests schreiben (Test-First wo sinnvoll)
- Tests müssen vor Commit grün sein
- Test-Files in `Tests/` Verzeichnis

**UI (SwiftUI Views):**
- UI Tests wo möglich/sinnvoll
- Sonst: **Klare Test-Anweisungen** für Henning erstellen:
  - Was genau testen? (Schritte)
  - Wo könnten ungewünschte Effekte auftreten?
  - Welche Edge Cases prüfen?

### Definition of Done

✅ **Fertig = ALLE Punkte erfüllt:**

- **Build erfolgreich** (`xcodebuild` compiliert ohne Errors)
- **Tests grün** (falls Unit Tests vorhanden)
- **Code formatiert** (konsistent mit Projekt-Style)
- **Jeder Commit compiliert** (funktionsfähiger Zwischenstand)
- **Test-Anweisungen** für Henning (bei UI-Changes)
- **Dokumentation aktualisiert:**
  - `CLAUDE.md` (bei Architektur-Änderungen)
  - `DOCS/current-todos.md` (Bug-Status, neue Todos)

### Git Commits

**Conventional Commits verwenden:**
- `feat:` - Neue Features
- `fix:` - Bugfixes
- `refactor:` - Code-Umstrukturierung ohne Funktionsänderung
- `test:` - Tests hinzufügen/ändern
- `docs:` - Dokumentation
- `chore:` - Maintenance (Dependencies, Config)

**Commit-Frequenz:**
- **Sinnvolle Zwischenschritte** committen (nicht zu selten)
- **Grund:** Verlust-Risiko minimieren bei AI-Fehlern
- **Jeder Commit muss compilieren** (keine broken builds)

**Beispiele:**
```
fix: End-Gong wird nicht mehr abgeschnitten (Bug 1)
feat: Settings als Toolbar-Navigation statt Modal Sheet
refactor: Idle Timer Logik für Workouts/Atem hinzugefügt
test: Unit Tests für StreakManager Reward-Berechnung
```

### Safety Mode

**Keine versteckten Überraschungen:**

- **Syntax validieren** vor Code-Output
- **Alle Side-Effects explizit auflisten:**
  - Welche Files werden geändert?
  - Werden neue Permissions benötigt (Info.plist)?
  - Ändern sich AppStorage-Keys?
  - Werden Audio-Files hinzugefügt/umbenannt?
- **Strikte Requirement Fidelity:**
  - Keine kreativen Abweichungen vom Gewünschten
  - Keine "Ich mache das mal besser"-Mentalität
  - Nur das umsetzen, was explizit gewünscht ist

### Best Practices & Design Language

**iOS 18+ "Liquid Glass" Design Language:**
- Ultra-thin materials & Glassmorphismus (`.ultraThinMaterial`)
- Smooth spring animations (`.spring()`, `.smooth`)
- Vibrancy & depth (Shadows, Blur-Effekte)
- Spatial design principles
- Große, runde Buttons mit visuellem Feedback

**Modern SwiftUI (iOS 17+):**
- `NavigationStack` (NICHT `NavigationView` - deprecated!)
- Neue Animationen (`.spring`, `.smooth`, nicht `.easeInOut`)
- SF Symbols 6 (neueste Icons)
- `.sensoryFeedback()` für Haptik

**Code-Qualität:**
- **Code so einfach wie möglich** (Wartbarkeit > Cleverness)
- **Konsistente Architektur** (bestehende Patterns fortführen)
- **Keine neuen Dependencies** ohne explizite Freigabe
- **SwiftLint-konform** (falls konfiguriert)

### Kommunikation mit Henning

**Was zeigen:**
- **WAS** du machst (high-level, verständlich)
- **WARUM** du es so machst (Begründung)
- **Test-Anweisungen** für UI (klar und konkret)

**Was verstecken:**
- Code-Details (außer bei Debugging/Klärungsbedarf)
- Technische Tiefe (außer explizit gefragt)
- Implementierungs-Interna

**Entscheidungen:**
- **So wenig wie möglich** von Henning abfragen
- Klare **Handlungsvorschläge** statt offene Fragen
- Nur bei **echten PO-Themen** nachfragen (Features, UX, Priorität)
- Bei technischen Details: **Empfehlung geben** + kurz begründen

---

## Common Development Tasks

### Adding a New Meditation Timer

1. Create a new "engine" service class in `/Services/` that implements the timer logic (use TwoPhaseTimerEngine as template).
2. Create a new tab view in `Meditationstimer iOS/Tabs/` that uses the engine.
3. Integrate the engine into ContentView.swift tab list.
4. Add HealthKit logging in the tab's session completion handler.

### Adding a New Audio Cue

1. Create/add the audio file (e.g., `new-cue.caf`) to the app bundle in Xcode.
2. Call `gong.play(named: "new-cue")` at the appropriate time.
3. For completion handlers: `gong.play(named: "new-cue", completion: { /* next step */ })`

### Accessing HealthKit Data

```swift
// Read mindfulness days for a month
let days = try await healthKitManager.fetchActivityDaysDetailedFiltered(forMonth: Date())

// Read daily minutes
let minutes = try await healthKitManager.fetchDailyMinutesFiltered(from: start, to: end)

// Log a session
try await healthKitManager.logMindfulness(start: startDate, end: endDate)
```

### Updating the Live Activity

```swift
// Start a new activity
liveActivity.start(title: "Meditation", phase: 1, endDate: phaseEndDate, ownerId: "OffenTab")

// Update running activity
await liveActivity.update(phase: 2, endDate: phaseEndDate, isPaused: false)

// End activity
await liveActivity.end(immediate: true)
```

### Detecting Ownership Conflicts

```swift
// Request start with conflict detection
let result = liveActivity.requestStart(title: "...", phase: 1, endDate: Date(), ownerId: "AtemTab")
switch result {
case .started:
    print("No conflict, activity started")
case .conflict(let ownerID, let title):
    print("\(ownerID) owns the activity: \(title)")
    // Show user a prompt; if approved, call forceStart()
case .failed(let error):
    print("Failed: \(error)")
}
```

---

## Platform-Specific Notes

### iOS

- Live Activities require iOS 16.1+
- `BackgroundAudioKeeper` uses UIKit (requires CanImportUIKit conditional)
- Smart reminders use BackgroundTasks (BGAppRefreshTask)
- Three tabs: Offen, Atem, Workouts

### watchOS

- No Live Activities
- Uses WKExtendedRuntimeSession for long meditations
- Simpler UI: single picker + timer display
- Heart rate monitoring via HealthKit
- Notifications for phase transitions
- Haptic feedback instead of audio

### Widget (iOS Only)

- Lock screen / Dynamic Island Live Activity
- Static widget for quick launch
- Control widget for media-style controls
- Limited data: only what's in MeditationAttributes

---

## Version & Release Notes

Current version: **2.5.3**

Key features by version:
- **v2.5.3**: Release notes documentation, optimized Live Activity updates
- **v2.5.2**: Corrected version numbering
- **v2.5.0+**: Dynamic Island support, multi-tab Live Activity conflicts, streaming heart rate
- **v2.0.0**: Complete rebuild with three meditation tabs + workouts
- **v1.1**: Initial release

See `RELEASE_NOTES_v*.md` for detailed changelog.

---

## Future Considerations

1. **Background Timer Improvements**: Explore combining foreground timer with passive background notifications for sessions >30 min
2. **Watch UI Enhancements**: Add more visual feedback (progress rings on watch face)
3. **Smart Reminders Expansion**: More sophisticated reminder scheduling based on user patterns
4. **Health Integration Depth**: Display additional HealthKit data (HRV, sleep, etc.) in insights view
5. **Cloud Sync**: Optional iCloud backup of settings and preferences
6. **Multi-Language Support**: Currently German-focused; expand to English, Spanish, etc.

---

## References & External Resources

- [Apple HealthKit Framework](https://developer.apple.com/healthkit/)
- [ActivityKit / Live Activities](https://developer.apple.com/documentation/activitykit)
- [WatchKit & watchOS Development](https://developer.apple.com/watchkit/)
- [AVFoundation Audio](https://developer.apple.com/avfoundation/)
- [SwiftUI & Combine](https://developer.apple.com/swiftui/)
- [WatchConnectivity for iPhone-Watch Communication](https://developer.apple.com/documentation/watchconnectivity)

