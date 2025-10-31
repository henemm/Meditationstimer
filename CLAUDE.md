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

**Development Target:**
- **Xcode 26.0.1 / Swift 6.2** (iOS 26.0 SDK)
- **Minimum Deployment:** iOS 18.5, watchOS 9.0
- **Testing:** 44 Unit Tests (StreakManager + HealthKit) in LeanHealthTimerTests/

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

## Critical Lessons Learned (October 2025)

### Git Merge Safety Protocol

**Problem:** Feature specifications and documentation can be lost during git merges, especially when files exist only in feature branches.

**Mandatory Post-Merge Checklist:**
1. **Immediately after any merge**: Run `git status` and verify no important files are missing
2. **Check for deleted files**: `git log -1 --stat` to see what was added/removed
3. **Verify DOCS/ directory**: Ensure all spec files, todo lists, and feature documentation are present
4. **If files are missing**: Check `git log --diff-filter=D` to find deleted files and restore them

**Example from alcohol-tracking feature:**
- Created feature spec, todo list, and implementation
- Merged main branch (v2.5.5 bug fixes) into feature branch
- Merge silently dropped DOCS files that only existed in feature branch
- Continued implementation without spec → built wrong feature

**Prevention:**
- Always check `git diff --name-status HEAD@{1} HEAD` after merge
- Keep critical specs in DOCS/ committed on main branch, not just feature branches
- Use `git merge --no-commit` to review changes before finalizing merge

### Spec-First Implementation Rule

**CRITICAL:** Never implement features without complete written specification.

**If spec is missing:**
1. ❌ **DO NOT** speculate or build "what seems right"
2. ❌ **DO NOT** infer requirements from existing code alone
3. ✅ **STOP immediately** and ask user for complete spec
4. ✅ **Document spec** in DOCS/ before writing any code

**Why this matters:**
- User has specific vision that may not match "obvious" implementation
- Breaking changes to existing UX (e.g., Calendar tap behavior) have serious consequences
- Wasted time building wrong feature that must be reverted

**Example failure (alcohol-tracking):**
- Found AlcoholEntry model with color levels → assumed manual color-coded UI
- Saw Calendar tap → repurposed it for alcohol logging
- Built "Walking Skeleton" without understanding user wanted "passive, notification-driven feature"
- Result: Broke existing Calendar tooltip, built aufdringliches UI instead of unterschwelliges feature

### Understanding Existing UI Behavior

**Before modifying ANY user interaction:**
1. Read the CURRENT code to understand what it does
2. Test the CURRENT behavior yourself (or ask user)
3. Document WHY the change is needed
4. Get explicit approval for breaking changes

**Calendar Tap Example:**
- **Original behavior:** Tap → show tooltip with meditation/workout minutes
- **My change:** Tap → open AlcoholLogSheet (breaking change!)
- **Correct approach:** Should have asked: "Calendar tap shows tooltip - should I change this or add different interaction?"

### Feature Philosophy Alignment

**This app has different feature categories:**
1. **Primary Features:** Meditation, Breathing, Workouts (prominent UI, explicit interaction)
2. **Support Features:** Streaks, Calendar, Statistics (visible but secondary)
3. **Passive Features:** Smart Notifications, background tracking (unterschwellig, notification-driven)

**Critical:** Ask which category before designing UI. "Passive" features should NOT have prominent manual-entry UI.

### Clean Rollback Strategy

**When implementation is wrong:**
1. Don't try to "fix forward" - this compounds errors
2. Use `git reset --hard <commit>` to clean rollback point
3. Start fresh with correct specification
4. Document what went wrong (this section!)

**Example:** `git reset --hard 9a0e459` removed all incorrect alcohol-tracking work cleanly.

### Automated Testing Protocol

**MANDATORY:** Run tests before every commit that touches business logic (Services/, Models/).

**When to run tests:**
1. ✅ **Always** before committing changes to Services/ (HealthKitManager, StreakManager, TwoPhaseTimerEngine)
2. ✅ **Always** after fixing deprecated APIs or refactoring
3. ✅ **Optional** for pure UI changes (but recommended)

**How to run:**
```bash
xcodebuild test -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

**What to expect:**
- **44 passing tests** (StreakManager + HealthKit)
- Tests in LeanHealthTimerTests/: StreakManagerTests.swift, HealthKitManagerTests.swift
- Build + Test time: ~30-60 seconds
- **Zero tolerance:** All tests MUST pass before commit

**If tests fail:**
- ❌ **DO NOT** commit broken code
- Fix the regression immediately
- Re-run tests until green

### Trace Complete Data Flow - Don't Analyze Fragments (October 2025)

**CRITICAL:** Always trace the COMPLETE "Entstehungsgeschichte" (origin story), not just isolated code fragments.

**5-Step Analysis Framework:**
1. WHERE is data created/loaded?
2. HOW is data transformed?
3. WHERE is data displayed?
4. WHERE is data used for calculations?
5. **Are steps 3 and 4 using THE SAME data?** (If NO → inconsistency!)

**Lesson:**
```
❌ DON'T: Look at isolated code fragments
✅ DO: Trace complete data flow from source to consumption
✅ DO: Map ALL usages before making changes
```

User insight: *"Du darfst nicht nur Fragmente anschauen, sondern die komplette Entstehungsgeschichte rückverfolgen"*

### Data Source Consistency (October 2025)

**CRITICAL:** Visualization and calculation MUST use the SAME data source.

**Problem:** CalendarView rings used `dailyMinutes` dictionary, StreakManager used separate HealthKit query → inconsistent results.

**Solution:** Added computed properties in CalendarView that use SAME `dailyMinutes` dictionary.

User insight: *"What you see = What gets counted"*

```
✅ DO: Use same data for visualization AND calculation
❌ DON'T: Query separately for display vs. calculation
```

### HealthKit .strictStartDate Date Range Bug (October 2025)

**Problem:** Today's data not showing despite being saved.

**Root Cause:** Used `endOfMonth` (Oct 31 00:00:00) but `.strictStartDate` endDate is EXCLUSIVE → samples after 00:00:00 excluded!

**Fix:** Use `startOfNextMonth` (Nov 1 00:00:00) to include entire current month.

```
.strictStartDate endDate is EXCLUSIVE
→ Use "start of NEXT period" not "end of CURRENT period"
```

### Analysis-First Principle Violation (October 2025)

**Problem:** Multiple trial-and-error attempts instead of root cause analysis.

User: *"Das sind schon wieder viel zu viele Versuche!"*

**Lesson:** Identify root cause with CERTAINTY before implementing fix. No speculative fixes!

Reference: Global CLAUDE.md "Analysis-First Prinzip"

### Workout Calorie Tracking (October 2025)

**Implementation:** MET-based estimation (HIIT: 12 kcal/min, Yoga: 4 kcal/min) written as `HKQuantitySample` with `.activeEnergyBurned` type.

**HealthKit:** Added `.activeEnergyBurned` permission for MOVE ring integration.

Reference: `HealthKitManager.logWorkout()` lines 158-218

### CRITICAL: Always Check for Existing Systems Before Building New Ones (October 2025)

**Problem:** Built a completely separate `NoAlcNotificationManager` system without checking if notification infrastructure already existed.

**What happened:**
1. Task: Add Smart Notifications for NoAlc tracking
2. **MY ERROR:** Immediately started building `NoAlcNotificationManager.swift` as standalone system
3. **WHAT I MISSED:** App already has `SmartReminderEngine` with `ActivityType` enum, BGTaskScheduler, and UI
4. **RESULT:** Built parallel system that duplicates functionality and doesn't integrate with Settings UI
5. **CLAIMED:** "✅ Complete" when it was actually wrong architecture

**What I SHOULD have done:**
```
1. Search for existing notification/reminder systems (Grep for "Reminder", "Notification", "ActivityType")
2. Read existing SmartReminder.swift, SmartReminderEngine.swift
3. Understand the pattern: ActivityType enum → SmartReminderEngine → Settings UI
4. Extend existing system, don't build parallel one
5. ONLY claim "complete" after proper integration
```

**The Rule:**
```
❌ DON'T: See feature request → immediately start coding new system
✅ DO: Search for existing systems → understand pattern → extend/integrate → test
```

**Why this is CRITICAL:**
- Wastes time building wrong solution
- Creates technical debt (parallel systems doing same thing)
- Breaks user expectations (no Settings UI integration)
- Violates "Analysis-First Principle"

**Checklist before building ANY new system:**
1. ✅ Grep for keywords related to the feature (e.g., "Reminder", "Notification", "Activity")
2. ✅ Read existing architecture documentation (DOCS/ folder)
3. ✅ Check if Models/ or Services/ already have related code
4. ✅ Ask user: "I see [existing system X], should I extend that or build new?"
5. ✅ ONLY proceed after confirming approach

**Example - Correct Approach:**
```
User: "Add NoAlc smart notifications"
Me: *Searches for "Notification", "Reminder", "ActivityType"*
Me: *Finds SmartReminderEngine.swift*
Me: "I see you have SmartReminderEngine with ActivityType enum (mindfulness, workout).
     Should I add 'noalc' to this existing system, or build a separate notification manager?"
User: "Use the existing system!"
Me: *Extends ActivityType enum, adds NoAlc HealthKit check to engine, done correctly*
```

**User's feedback (verbatim):**
> "Du hast ja gerade sehr viele grüne Häkchen für das Feature 'NoAlc' vergeben.
> Aber ich sehe überhaupt nichts was auf die SmartReminder Integration hindeutet.
> Weder gibt es die Kategorie 'NoAlc' noch hast du einen Beispieleintrag (9:00 Uhr) hinterlegt.
> Was hast du denn überhaupt gemacht?????"

**Lesson internalized:** ALWAYS check for existing systems FIRST. No exceptions.

---

**For global collaboration rules and workflow, see `~/.claude/CLAUDE.md`**
