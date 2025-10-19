# AI Notes (consolidated)

This file is a central place for AI-facing hints, annotations and quick context that other chat sessions or automation can read.

Suggested contents:
- Projektname/Scheme für Build und Tests: **Lean Health Timer**
- Regel: Vor jedem Hinweis zum Testen wird ein Compiler-Test (Build) per Kommandozeile durchgeführt und das Ergebnis dokumentiert.
- Where to look first for Live Activity issues: `Meditationstimer iOS/Tabs/OffenView.swift`, `Services/LiveActivityController.swift`, `Services/TwoPhaseTimerEngine.swift`.
- Owner convention for LiveActivity: callers should pass `ownerId` (e.g. `"OffenTab"`).
- Files with AI orientation comments: `OffenView.swift`, `AtemView.swift`, `WorkoutsView.swift` (each contains a short AI ORIENTATION block).
- Local notes:
  - Tag `v1.1` and branch `stable/v1.1` were created on 2025-10-10 as a safe rollback point.
  - Release: https://github.com/henemm/Meditationstimer/releases/tag/v1.1

If you want, I can scan the repository for all `AI ORIENTATION` sections and append them here.

## Lessons Learned from Timer Bug

Based on failed attempts documented in Fehlversuche-Timer-Bug.md and Fehlversuche-Timer-Bug-Entry-2025-10-11.md:

### Core Timer Issues
- **Timer not reliably stopped after "Beenden"**: The timer continues running in background even after user presses stop button
- **Race conditions**: Between UI state changes and background tasks, causing inconsistent behavior
- **Multiple timer instances**: Possible to have multiple timer engines running simultaneously
- **State synchronization**: UI shows stopped but timer still active, or vice versa

### Root Causes Identified
- **Engine/Activity duplication**: Multiple instances of MeditationEngine and LiveActivityController can exist
- **Improper cleanup**: Timer tasks not properly cancelled when view changes or app terminates
- **State management**: Lack of centralized state tracking across UI and background processes

### Proposed Solutions
- **Central reset function**: Implement a single `resetAll()` method that properly cleans up all timer-related components
- **Owner-based management**: Use ownerId pattern to prevent duplicate instances (already partially implemented)
- **State synchronization**: Ensure UI state and background state are always in sync
- **Proper task cancellation**: Use structured concurrency with proper cancellation handling

### Debugging Approaches That Failed
- Debug instrumentation: Adding extensive logging didn't reveal the core issue
- UI state monitoring: Watching state changes didn't catch the background timer continuation
- Multiple reset attempts: Various cleanup approaches didn't fully resolve the race conditions

### Key Files Involved
- `Services/TwoPhaseTimerEngine.swift`: Core timer logic
- `Services/LiveActivityController.swift`: Activity management
- `Services/MeditationEngine.swift`: Engine coordination
- `Meditationstimer iOS/Tabs/OffenView.swift`: Main UI interaction point

## Project Status

Based on backlog.md (as of 07.10.2025):

### Current Focus Areas
1. HealthKit-Race-Conditions: Ensure sessions only close after successful save
2. Live Activity/Dynamic Island: Streamlined visual design (centered timer, compact width, meaningful labels)
3. UI/UX Polish: Icons, Settings, bug fixes (e.g., missing scenePhase declaration in Atem preview)

### Completed Tasks
- HealthKit race conditions eliminated in Offen/Atem/Workout views
- Live Activity/Dynamic Island redesigned (centered lock screen timer, compact dynamic island)
- Settings expanded (option to log meditation as Yoga workout)
- UI refinements in Workouts (neutral repeat icon)
- Atem preview bug fixed (added missing @Environment(.scenePhase))
- Removed incorrect auto-end on app switch

### Open Tasks
- Live Preview (Canvas) stability final check
- Dynamic Island final variant decision
- Optional debug switch for ending all Live Activities
- HealthKit re-testing on device
- Minor UX polish for lock screen and expanded views

## Technical Solutions

### Live Activity Watchdog (from LIVE_ACTIVITY_WATCHDOG.md)

**Problem:** Timer continues running after app force-quit, Live Activity shows countdown even when app is terminated.

**Solution:** Automatic watchdog timer in LiveActivityController.swift

**How it works:**
1. On Live Activity start, watchdog timer begins
2. Each update() resets lastUpdateTime to current time
3. Every 5 seconds, watchdog checks time since last update
4. After 30 seconds without update, Live Activity auto-terminates

**Technical details:**
```swift
private let watchdogInterval: TimeInterval = 30.0 // 30 second timeout
private var watchdogTimer: Timer? // checks every 5 seconds
private var lastUpdateTime: Date // timestamp of last update
```

**Benefits:**
- Automatic cleanup on app termination
- No user intervention required
- Robust system - works even with crashes
- No more false timer displays

**Status:** ✅ Implemented and tested

## Debugging History

From Timer_LivePreview_Problem.md (as of 18.10.2025):

### AtemView Timer Issue - Fixed 18.10.2025
**Problem:** Live Activity not automatically ended at natural session end due to missing .onChange(of: finished)

**Root Cause:** AtemView uses direct state variables (@State private var finished = false) instead of SessionEngine. When finished = true was set, only UI switched to "Fertig", but no automatic session termination was triggered. Other views have .onChange(of: engine.state) that automatically calls endSession().

**Solution:**
- Added .onChange(of: finished) modifier that calls endSession(manual: false) when finished becomes true
- Reactivated Live Activity termination in endSession(): await liveActivity.end(immediate: true)

**Key Insight:** AtemView needed the same automatic cleanup mechanism as other views, but with state variables instead of engine state.

### Live Activity Specifications
**Purpose:** Ensure Atem sessions start/update/end Live Activities without multiple parallel timers.

**Flow:**
1. User taps Play → compute sessionEnd = now + preset.totalSeconds
2. Call liveActivity.requestStart(title: preset.name, phase: 1, endDate: sessionEnd, ownerId: "AtemTab")
   - .started → start local engine & UI overlay
   - .conflict → show Alert with "End & Start" or "Cancel" options
   - .failed → start local engine anyway
3. Phase changes: update only emoji/icon, not countdown time
4. End: call await liveActivity.end() and cleanup

**Visual:** Phase arrows (SF symbols: arrow.up/down/left/right) and timer in Dynamic Island.

### Live Activity Bug
**Problem:** Live Activity doesn't stop after "Beenden" - end() called but immediately followed by start()/requestStart().

**Hypotheses:**
1. Timer engine has pending callbacks after end()
2. Multiple LiveActivityController instances
3. Delayed Task/DispatchWorkItem triggers start() after end()

**Reproduction:** Start session → Press "Beenden" → check logs for end() followed by start() within <1s.

### Timer Architecture Rules
- Maximum one active timer/Live Activity at a time
- Each tab can use its own timer engine
- Tab responsible for clean termination
- Runtime guard: ownership check in LiveActivityController with ownerId (e.g. "AtemTab")

### Countdown Sync Issue
**Problem:** Ring display and Live Activity show different remaining times
**Cause:** End time calculated twice - once for Live Activity, once for engine
**Solution:** End time must come from same source (ring logic)

### Previous Attempts
- Ported EndSession logic from WorkoutsView to AtemView
- Build validation after each step
- Modified/removed GongPlayer.stopAll(), engine.cancel(), session start logic
- Adjusted dual-ring UI and CircularRing parameters
- Reset to last stable commits

**Result:** None of these approaches solved the core issue - timer/Live Activity not stopped after "Beenden"
