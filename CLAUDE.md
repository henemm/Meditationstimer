# Meditationstimer - Project Guide

**Project-specific context for Claude Code. See `~/.claude/CLAUDE.md` for global collaboration rules.**

---

## Overview

**Meditationstimer** is a meditation and wellness app built with SwiftUI for iOS 16.1+, watchOS 9.0+, and Widget Extension.

**Features:**
- Free meditation timer with two phases (meditation + reflection)
- Guided breathing exercises (Atem) with customizable presets
- HIIT workout timer with audio cues
- HealthKit integration for activity tracking
- Streak management with reward system
- Live Activities / Dynamic Island support
- Apple Watch companion app with heart rate monitoring

**Current Version:** 2.5.4

---

## Architecture Overview

Multi-target, horizontally-layered architecture:

```
┌──────────────────────────────────────────────────┐
│        iOS / watchOS / Widget Apps (UI)          │
└──────────────────────────────────────────────────┘
                     ↓
┌──────────────────────────────────────────────────┐
│    Shared Service Layer (Services/)              │
│  • TwoPhaseTimerEngine  • HealthKitManager       │
│  • StreakManager        • GongPlayer             │
│  • LiveActivityController (iOS only)             │
└──────────────────────────────────────────────────┘
                     ↓
┌──────────────────────────────────────────────────┐
│              Platform Frameworks                 │
│  HealthKit • ActivityKit • WatchConnectivity     │
└──────────────────────────────────────────────────┘
```

### Key Design Principles

1. **Foreground-First Timers:** All meditation timers run in foreground only (iOS background limits)
2. **Shared Services:** Business logic in `/Services/` reused across all targets
3. **Reactive State:** SwiftUI `@Published` + Combine for real-time updates
4. **Live Activity Coordination:** Only one activity at a time across all tabs
5. **HealthKit as Source of Truth:** All historical data from HealthKit (no duplicate storage)

---

## Build Commands

**Build iOS app (all targets):**
```bash
xcodebuild -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build
```

**Run tests:**
```bash
xcodebuild test \
  -project Meditationstimer.xcodeproj \
  -scheme "MeditationstimerTests" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

**Xcode shortcuts:**
- Build: `Cmd+B`
- Run: `Cmd+R`
- Test: `Cmd+U`
- Clean: `Cmd+Shift+K`

**Important Notes:**
- HealthKit requires device or configured simulator
- Live Activities require iOS 16.1+ (Dynamic Island on physical devices or iOS 17.2+ simulator)
- Widget extension auto-included in "Lean Health Timer" scheme

---

## Project Structure

```
Meditationstimer/
├── Services/                    # Shared across all targets
│   ├── TwoPhaseTimerEngine.swift
│   ├── HealthKitManager.swift
│   ├── StreakManager.swift
│   ├── GongPlayer.swift
│   └── ...
│
├── Meditationstimer iOS/        # iOS app
│   ├── Tabs/
│   │   ├── OffenView.swift      # Free meditation (2-phase)
│   │   ├── AtemView.swift       # Guided breathing
│   │   └── WorkoutsView.swift   # HIIT timer
│   ├── LiveActivityController.swift
│   ├── ContentView.swift        # Tab container
│   └── ...
│
├── Meditationstimer Watch App/  # watchOS app
│   └── ContentView.swift
│
└── MeditationstimerWidget/      # Live Activity + Widgets
    └── MeditationstimerWidgetLiveActivity.swift
```

---

## Core Components (Top 5)

### 1. TwoPhaseTimerEngine (Services/TwoPhaseTimerEngine.swift)

**Purpose:** State machine for meditation timer with two sequential phases.

**Key Features:**
- States: `.idle`, `.phase1(remaining)`, `.phase2(remaining)`, `.finished`
- Date-based calculations (survives backgrounding)
- Foreground-only (Timer.publish every 0.05s)
- Auto-terminates on app quit

**Usage:**
```swift
engine.start(phase1Minutes: 15, phase2Minutes: 3)
// Observe engine.state for UI updates
engine.cancel()
```

### 2. HealthKitManager (Services/HealthKitManager.swift)

**Purpose:** Centralized HealthKit integration.

**Key Operations:**
- `logMindfulness(start:end:)` – Log meditation session
- `logWorkout(start:end:activity:)` – Log HIIT workout
- `fetchActivityDaysDetailedFiltered(forMonth:)` – Get activity calendar
- `fetchDailyMinutesFiltered(from:to:)` – Sum daily minutes

**Design Notes:**
- Only Phase 1 duration logged (Phase 2 = reflection, not meditation)
- Filters by app source (excludes external data)
- Min 2 minutes for streak eligibility

### 3. LiveActivityController (Meditationstimer iOS/LiveActivityController.swift)

**Purpose:** Dynamic Island / Lock Screen activity management.

**Key Features:**
- Singleton, injected via `@EnvironmentObject`
- Ownership model: tracks which tab owns current activity
- Conflict resolution: auto-ends conflicting activities

**API:**
```swift
liveActivity.start(title:, phase:, endDate:, ownerId:)
await liveActivity.update(phase:, endDate:, isPaused:)
await liveActivity.end(immediate:)
```

### 4. StreakManager (Services/StreakManager.swift)

**Purpose:** Streak calculation with reward progression.

**Streak Logic:**
- Consecutive days with ≥2 min activity = streak
- Rewards: 1 per 7 days (max 3)
- No activity today → streak ends, rewards decay by 1

**State:**
```swift
@Published var meditationStreak: StreakData
@Published var workoutStreak: StreakData
```

### 5. GongPlayer (Services/GongPlayer.swift)

**Purpose:** Audio playback for meditation cues.

**Audio Files:**
- `gong` – Start sound
- `gong-dreimal` – Phase transition
- `gong-Ende` – Session end
- `einatmen`, `ausatmen`, `halten-ein`, `halten-aus` – Breathing cues

**Usage:**
```swift
gong.play(named: "gong-dreimal") { print("Done") }
```

---

## Important Patterns

### Timer Session Flow

```
User taps Start
  → engine.start() – timer begins
  → bgAudio.start() – keep audio alive
  → liveActivity.start() – lock screen activity
  → gong.play("gong") – start sound

Phase 1 (15 min)
  → UI updates every 50ms

Phase transition
  → gong.play("gong-dreimal")
  → liveActivity.update(phase: 2)

Phase 2 (3 min)
  → Reflection phase

Session ends
  → gong.play("gong-ende")
  → Log to HealthKit (Phase 1 only!)
  → liveActivity.end()
  → bgAudio.stop()
  → Update streaks
```

### Multi-Target Code Sharing

**All targets can access:**
- `/Services/` directory (shared business logic)

**iOS only:**
- `LiveActivityController`
- `BackgroundAudioKeeper`
- Tab views (OffenView, AtemView, WorkoutsView)

**watchOS only:**
- `HeartRateStream`
- `RuntimeSessionHelper`

**No explicit sync protocol:**
- HealthKit = single source of truth
- WatchConnectivity = optional real-time feedback only

---

## Testing

**Test Files:** Located in `Tests/` directory

**Test Coverage:**
- `TwoPhaseTimerEngineTests.swift` – 18 tests
- `StreakManagerTests.swift` – 15 tests
- `HealthKitManagerTests.swift` – 25+ tests
- Total: 58+ test cases

**Setup:** Test files need to be added to Xcode test target first (see DOCS/testing-guide.md)

---

## Detailed Documentation

For in-depth information, see `/DOCS/`:

- `architecture.md` – Complete architecture details
- `components.md` – Detailed component documentation
- `workflows.md` – Session flows, state management
- `testing-guide.md` – Testing setup & strategies
- `development-guide.md` – Common tasks & recipes
- `audio-system.md` – Audio playback details
- `platform-notes.md` – iOS/watchOS/Widget specifics

---

## Quick Reference

**Version:** 2.5.4

**Main Schemes:**
- "Lean Health Timer" – iOS + Watch + Widget
- "Meditationstimer Watch App" – watchOS only

**Key Files to Know:**
- `Services/TwoPhaseTimerEngine.swift` – Timer logic
- `Services/HealthKitManager.swift` – HealthKit integration
- `Meditationstimer iOS/Tabs/OffenView.swift` – Main meditation UI
- `Meditationstimer iOS/LiveActivityController.swift` – Dynamic Island
- `Meditationstimer iOS/ContentView.swift` – Tab container

**Dependencies:**
- HealthKit (all historical data)
- ActivityKit (Live Activities, iOS 16.1+)
- WatchConnectivity (optional Watch↔iPhone sync)
- AVFoundation (audio playback)

---

**For global collaboration rules and workflow, see `~/.claude/CLAUDE.md`**
