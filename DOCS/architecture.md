# Architecture - Complete Details

Deep dive into Meditationstimer's architecture and design decisions.

---

## System Architecture

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

---

## Key Design Principles

### 1. Foreground-First Timer Design

All meditation timers run only in foreground to avoid iOS background execution limits. Background notifications serve as backup only.

### 2. Shared Services, Separate UI

Core business logic (timers, health logging, notifications) lives in `/Services/` and is reused across all targets. Each target (iOS app, Watch app, Widget) has independent UI.

### 3. Reactive State Management

Uses SwiftUI's `@Published` (ObservableObject) with Combine for reactive updates across the app. The timer engine publishes state changes that drive UI updates in real-time.

### 4. Live Activity as Cross-Tab Coordination

The `LiveActivityController` runs on iOS and is shared across all tabs (Offen, Atem, Workouts) to ensure only one meditation/workout is active at a time on the lock screen/Dynamic Island.

### 5. HealthKit as Single Source of Truth for History

All historical activity data (streaks, calendar, daily minutes) comes from HealthKit, ensuring consistency with Apple Health and avoiding duplicate storage.

---

## Key Architectural Decisions & Rationale

### 1. Foreground-Only Timers

**Decision:** All meditation timers run only in foreground (app must stay active).

**Rationale:** iOS severely restricts background execution. Attempting to keep a timer running in the background leads to frequent termination. Better UX to require app to stay active for the meditation session. Users with screens locked still get notifications as backup.

### 2. Live Activity as Cross-Tab Arbiter

**Decision:** Only one Live Activity can exist at a time across all tabs (Offen, Atem, Workouts).

**Rationale:** iOS lock screen/Dynamic Island is a limited real estate. Prevents confusing overlapping activities. LiveActivityController's ownership model ensures deterministic conflict resolution.

### 3. HealthKit as Source of Truth

**Decision:** All historical activity data (streaks, calendar) comes from HealthKit, not app-local database.

**Rationale:** Integrates with Apple Health (app users expect their data to appear in Health.app). Single source of truth prevents sync bugs. HealthKit queries are expensive, so streaks are cached in StreakManager and updated on-demand.

### 4. Service Layer Sharing

**Decision:** All business logic (timers, HealthKit, notifications) lives in `/Services/` and is target-agnostic.

**Rationale:** Enables code reuse across iOS app, Watch app, and Widget. Services are pure Swift (no UI). Tests can mock services easily.

### 5. Phase 1 Only for HealthKit Logging

**Decision:** Only Phase 1 (meditation) is logged to HealthKit; Phase 2 (reflection) is not counted.

**Rationale:** Phase 2 is not meditation—it's a wind-down period. Logging only Phase 1 gives accurate "Mindfulness" minutes. Streak calculations use Phase 1 duration only.

### 6. Date-Based Timer Calculations

**Decision:** Timer calculates remaining time using `endDate.timeIntervalSince(now)` rather than decrementing a counter.

**Rationale:** If app is backgrounded/suspended and then returns to foreground, date-based math still gives correct remaining time. Counter-based approach would lose accuracy.

### 7. Combine + @Published for Reactive Updates

**Decision:** Engine state published via Combine; views observe with `@ObservedObject`.

**Rationale:** SwiftUI's reactive model. Efficient: only affected views redraw when state changes. Testable: can drive engine state and verify UI updates.

### 8. No Background Task for Meditation Timer

**Decision:** Meditation timer does NOT use BackgroundTasks (BGAppRefreshTask, BGProcessingTask).

**Rationale:** These tasks are for periodic, non-urgent work (e.g., data sync). They're not reliable for real-time apps. Instead, notifications serve as backup if user leaves the app.

### 9. Watch App Uses Extended Runtime + Notifications

**Decision:** Watch app extends runtime to ~30 min; uses notifications as fallback if session exceeds 30 min.

**Rationale:** WKExtendedRuntimeSession allows watch app to stay active for long meditations. If meditation is >30 min, watch display might lock, but notifications will still fire.

---

## Project Structure (Complete)

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
├── DOCS/                              # Detailed documentation
│   ├── architecture.md
│   ├── components.md
│   ├── workflows.md
│   ├── testing-guide.md
│   ├── development-guide.md
│   ├── audio-system.md
│   └── platform-notes.md
│
└── Models/                            # Shared models (deprecated, mostly empty)
    └── ...
```

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
