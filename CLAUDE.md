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

**Current Version:** 2.7.1

**Development Target:**
- **Xcode 26.0.1 / Swift 6.2** (iOS 26.0 SDK)
- **Minimum Deployment:** iOS 18.5, watchOS 9.0
- **Testing:** 66 Unit Tests (StreakManager + HealthKit + SmartReminder) in LeanHealthTimerTests/

---

## Bug-Fixing Pflicht

**Bei JEDEM Bug-Fix MUSS der `bug-investigator` Agent verwendet werden:**

- Direktes Fixen ohne Agent ist **VERBOTEN**
- Der Agent analysiert erst vollständig, dann wird (nach Freigabe) gefixt
- Aufruf: `/bug [Beschreibung]` oder explizit "Nutze bug-investigator für..."
- **Ausnahme:** Triviale Typos (1 Zeile, offensichtlich)

**Warum:** Verhindert Trial-and-Error und erzwingt Analysis-First Prinzip.

---

## UI-Testing Regeln

**Bei manuellen UI-Tests mit Henning:**

1. **ALLE ausstehenden Tests durchgehen** - Nicht fragen "möchtest du noch mehr testen?"
2. **Immer nur EINEN Test zur Zeit** - Nicht alle Tests auf einmal präsentieren
3. **Auf Ergebnis warten** - Erst nach Hennings Feedback zum nächsten Test
4. **Sofort protokollieren** - Pass/Fail direkt in ACTIVE-todos.md dokumentieren
5. **Bei Fehler: STOP** - Nicht weiter testen, sondern Bug analysieren
6. **Erst wenn ALLES getestet:** Session beenden oder fragen was als nächstes

**Workflow:**
1. ACTIVE-todos.md lesen → alle "Test ausstehend" Items sammeln
2. Jeden Test einzeln präsentieren → Ergebnis abwarten → dokumentieren → nächster
3. Erst wenn Liste leer: "Alle Tests abgeschlossen"

**Warum:** Henning testet auf echtem Device. Alle offenen Tests müssen am Stück erledigt werden.

---

## Dokumentations-Pflicht

**SOFORT aktualisieren wenn Arbeit erledigt ist:**

1. **Nach jedem Fix:** ACTIVE-todos.md → Status auf "GEFIXT" setzen
2. **Nach jedem Test:** ACTIVE-todos.md → "Getestet" + Datum hinzufügen
3. **Wenn Feature komplett:** ACTIVE-roadmap.md → Status auf "KOMPLETT" setzen
4. **Nicht warten** bis Henning danach fragt!

**Prüfen bei Session-Ende:**
- Sind alle erledigten Items in ACTIVE-todos.md als GEFIXT markiert?
- Sind alle getesteten Items dokumentiert?
- Sind abgeschlossene Features in ACTIVE-roadmap.md aktualisiert?

**Warum:** Henning soll nicht nachfragen müssen. Dokumentation ist Teil der Arbeit.

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
- `StreakManagerTests.swift` – 14 tests
- `HealthKitManagerTests.swift` – 24 tests
- `NoAlcManagerTests.swift` – 10 tests
- `SmartReminderEngineTests.swift` – 15 tests (Reverse Smart Reminders)
- `MockHealthKitManagerTests.swift` – 2 tests
- `LeanHealthTimerTests.swift` – 1 test
- Total: 66 test cases

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

### Forward vs. Backward Iteration for Chronological Data (November 2025)

**Problem:** NoAlc Streak calculation showing 0 despite visible data.

**Root Cause:** Used backwards iteration (today → past) to calculate streaks with reward-based forgiveness system. When iterating backwards, code tried to USE rewards before they were EARNED chronologically.

**Example Bug:**
```swift
// WRONG: Backwards iteration
var checkDate = today
while true {
    if level == .easy && earnedRewards > 0 { // Try to use reward
        consumedRewards += 1
    }
    checkDate = previousDate  // But rewards earned in chronologically earlier dates!
}
```

**Why backwards iteration fails for reward tracking:**
1. Start at Nov 8 (Easy day needing reward)
2. At this point: `earnedRewards = 0` (haven't iterated through past yet)
3. Cannot heal Easy day → streak ends
4. Rewards from Nov 1-7 are encountered AFTER in iteration, but chronologically BEFORE
5. Result: Trying to use future rewards to heal past days

**Solution:** Forward chronological iteration (past → today)
```swift
// CORRECT: Forward iteration
let sortedDates = data.keys.sorted()  // Earliest → Latest
for date in sortedDates {
    if level == .steady {
        consecutiveDays += 1
        if consecutiveDays % 7 == 0 { earnedRewards += 1 }  // Earn chronologically
    } else if level == .easy {
        if earnedRewards - consumedRewards > 0 {  // Rewards already earned!
            consumedRewards += 1
            consecutiveDays += 1
        }
    }
}
```

**User Insight:** *"Denke doch einmal nach: Wie ist die ganz einfache Regel? Du machst es aktuell immer komplizierter."*

**The Simple Rule:**
```
✅ DO: Process chronological data in chronological order (past → present)
✅ DO: Earn/consume resources in the order they naturally occur in time
❌ DON'T: Use backwards iteration when tracking cumulative earned resources
❌ DON'T: Overcomplicate with "clever" iteration directions
```

**When to use which:**
- **Forward iteration:** Tracking earned/consumed resources, cumulative statistics, chronological state changes
- **Backwards iteration:** Finding most recent value, checking "current streak from now", simple recency queries

Reference: `DOCS/bug-noalc-streak-logic.md` Lösungsversuch 3

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
- Duplicate systems = double maintenance burden
- User expects integration with existing UI/Settings
- Wasted time building wrong architecture that must be deleted

**Checklist before building ANY new system:**
1. ✅ Grep for keywords related to the feature
2. ✅ Read existing architecture documentation
3. ✅ Check if Models/ or Services/ already have related code
4. ✅ Ask user: "I see [existing system X], should I extend that or build new?"
5. ✅ ONLY proceed after confirming approach

---

### CRITICAL: Never Use ✅ Checkmarks Without User Verification (October 2025)

**Problem:** Repeatedly marked features as "✅ Complete" when they were incomplete or architecturally wrong.

**Examples:**
1. Claimed "Smart Notifications ✅ Complete" → No SmartReminder integration
2. Claimed "SmartReminder Integration ✅ Complete" → UI Picker missing
3. Multiple green checkmarks without full end-to-end verification

**User Feedback:** *"ich kann diese Grünen Häkchen nicht mehr sehen! Die sind zu 80% phantasie!"*

**The Rule:**
```
❌ NEVER: Use ✅ or "Complete" for implementation status
✅ ALWAYS: Describe what was DONE, not what is "finished"
✅ ALWAYS: Only USER can declare something "complete" after device testing
```

**What I CAN say:**
- "Implemented X in file Y"
- "Added X functionality"
- "Built successfully"
- "Unit tests passing"

**What I CANNOT say:**
- "✅ Complete"
- "✅ Feature X done"
- "✅ Working"
- Any green checkmarks implying completeness

**Why this matters:**
- False "Complete" status wastes user's time (they assume it works)
- Breaks trust (user sees feature "done" → tests → doesn't work)
- I can only verify: builds, compiles, unit tests pass
- I CANNOT verify: full integration, UI correctness, device behavior
- Only USER can verify end-to-end functionality on real device

**Checklist before building ANY new system:**
1. ✅ Grep for keywords related to the feature (e.g., "Reminder", "Notification", "Activity")
2. ✅ Read existing architecture documentation (DOCS/ folder)
3. ✅ Check if Models/ or Services/ already have related code
4. ✅ Ask user: "I see [existing system X], should I extend that or build new?"
5. ✅ ONLY proceed after confirming approach

---

### CRITICAL: Never Simplify Away the Feature Intent (October 2025)

**Problem:** When facing implementation challenges, I suggested "simplifying" the feature by removing its core value proposition.

**Example - Smart Reminder Bug:**
1. Feature: **SMART** Reminders (only notify if no activity detected via HealthKit)
2. Implementation: BGTaskScheduler not firing reliably
3. **MY ERROR:** "Let's use UNCalendarNotificationTrigger instead, user can dismiss if not relevant"
4. **WHAT I DID WRONG:** Removed the "SMART" (conditional) aspect, making it a dumb timer
5. **USER FEEDBACK:** "Was ist denn dann noch smart?"

**The Rule:**
```
❌ DON'T: Change feature goal to simplify implementation
❌ DON'T: Remove core value to avoid technical challenges
✅ DO: Research how successful apps solve the SAME problem
✅ DO: Ask user if feature goal can be adjusted (don't decide alone)
```

**Why this is CRITICAL:**
- Implementation complexity is MY problem, not the user's
- User wants the FEATURE, not "whatever is easiest to build"
- "Simple notifications" already exist - user asked for SMART for a reason
- Removing smartness = deleting the feature entirely

**The Right Approach:**
1. **Verify Feature Intent:** What is the core value? (here: conditional notifications)
2. **Research Best Practices:** How do successful apps (Strava, MyFitnessPal) solve this?
3. **Propose Solutions:** "Option A: X, Option B: Y" - let USER choose tradeoffs
4. **NEVER decide alone** to remove core functionality

**What I SHOULD have said:**
"BGTaskScheduler is unreliable. Let me research how fitness apps handle conditional notifications. I'll come back with 2-3 options that preserve the 'smart' aspect."

**NOT:**
"Let's just send notifications always, user can dismiss."

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

### Notification Debugging Protocol (November 2025)

**Problem:** UNCalendarNotificationTrigger notifications not firing after 5+ attempts.

**Solution:** Build minimal reproducible test FIRST:
1. Create debug view with simplest possible notification (10-second timer)
2. Test system works isolated from complex code
3. If debug works → problem is in app code, not system
4. Rewrite complex code based on working minimal example

**Key Technical Fixes:**
- `DateComponents.weekday` = proper way to schedule weekday-specific notifications (not manual logic!)
- One notification PER weekday with unique identifiers
- `UNNotificationCategory` + actions for interactive notifications (NoAlc: 3 buttons)
- Extract both `.hour` AND `.minute` from Date (not just hour with :00 hardcoded)

**CRITICAL Mistake:** In panic, removed core features (weekday filtering, NoAlc direct logging) instead of fixing ONLY the scheduling bug.

**The Rule:**
```
❌ DON'T: Delete features when stuck - fix the actual problem
✅ DO: Create minimal test, identify root cause, fix systematically
✅ DO: Preserve existing features while fixing bugs
```

**User feedback (verbatim):** "Aber warum sind Weekdays jetzt weg? Und außerdem: Was ist aus dem Feature geworden, dass ich über den Reminder direkt meinen NoAlc Report machen kann???"

**Lesson:** Stick to Analysis-First principle. Never remove features without user approval, even under time pressure.

Reference: `NotificationDebugView.swift` (minimal test), `SmartReminderEngine.swift` (lines 124-156: weekday loop)

### Audio Completion Handler Pattern (November 2025)

**Problem:** End-gong sound in Atem meditation was being cut off because ambient audio stopped before the gong finished playing.

**Root Cause:** Using `Task.sleep()` which doesn't wait for audio playback to complete:
```swift
gong.play(named: "gong-ende")
try? await Task.sleep(nanoseconds: 2_000_000_000) // This doesn't wait for gong!
ambientPlayer.stop()  // Stops too early, cutting off gong
```

**Solution:** Completion handler pattern in AVAudioPlayerDelegate + DispatchWorkItem for delayed cleanup:
```swift
// In GongPlayer class:
private var completions: [AVAudioPlayer: () -> Void] = [:]

func play(named name: String, completion: (() -> Void)? = nil) {
    // ... setup player ...
    if let completion = completion {
        completions[player] = completion
    }
}

func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    if let completion = completions[player] {
        completions.removeValue(forKey: player)
        completion()  // Called when audio finishes
    }
}

// In endSession:
gong.play(named: "gong-ende") {
    self.pendingEndStop?.cancel()
    let work = DispatchWorkItem { [ambientPlayer = self.ambientPlayer] in
        ambientPlayer.stop()
    }
    self.pendingEndStop = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work) // Extra 0.5s safety delay
}
```

**The Pattern:**
```
❌ DON'T: Use Task.sleep() or arbitrary delays hoping audio finishes
✅ DO: Use AVAudioPlayerDelegate + completion callback + DispatchWorkItem
✅ DO: Stop dependent resources AFTER audio finishes, not based on guessed timing
```

**Why this matters:**
- Race conditions between audio playback and resource cleanup
- Audio files have variable length - hardcoded delays break when audio changes
- Completion handlers guarantee correct sequencing regardless of audio duration
- DispatchWorkItem allows cancellation if user interrupts

**User feedback:** "Implementiere ihn exakt genauso wie beim Offen-Tab. Du hast schon einmal sehr viel rumprobiert."

Reference: `AtemView.swift` lines 134-175 (GongPlayer class), 582 (@State pendingEndStop), 927-943 (endSession with completion)

### Workout REST Phase UI State Management (November 2025)

**Problem:** During workout REST phase pause, UI showed both completed exercise AND next exercise (redundant). "Als nächstes" text was not consistently displayed in small font.

**Root Cause:** Pause state didn't differentiate between WORK phase pause and REST phase pause:
```swift
// WRONG: Same display for both WORK and REST pause
if isPaused {
    exerciseNameWithInfoButton(phase.name)  // Current exercise
    Text(nextExerciseInfo)                   // Next exercise → redundant in REST!
}
```

**Solution:** Split pause behavior based on phase type + separate text styling:
```swift
// CORRECT: Different display for WORK vs REST pause
if isPaused {
    if currentPhase.isWork {
        // WORK phase paused: show current exercise
        exerciseNameWithInfoButton(phase.name)
        Text(nextExerciseInfo).font(.caption)
    } else {
        // REST phase paused: show ONLY next exercise (same as REST running)
        Image(systemName: "pause")
        nextExerciseNameWithInfoButton()
    }
}

// Split "Als nächstes" text for consistent font sizes:
VStack(spacing: 4) {
    Text(nextInfo.prefix)  // "Als nächstes" in .font(.caption)
        .font(.caption)
        .foregroundStyle(.secondary)

    HStack(spacing: 6) {
        Text(nextInfo.name)  // Exercise name in .font(.headline)
            .font(.headline)
        // ... info button
    }
}
```

**The Pattern:**
```
❌ DON'T: Use same UI state for semantically different phases
❌ DON'T: Combine text with different styles in single Text view
✅ DO: Differentiate UI based on phase type (WORK vs REST)
✅ DO: Match pause display to running display for same phase
✅ DO: Split text into separate views for independent styling
```

**Why this matters:**
- Reduces cognitive load: user sees only relevant information
- Prevents redundancy: showing completed exercise during REST is noise
- Consistent styling: separate views allow granular font control
- UX principle: "What you see matches what's happening"

**User feedback:** "Wir haben ja grundsätzlich die zwei Phasen: 1. Belastungsphase und 2. Rest-Phase. [...] Ich drücke auf Pause. 'Als nächstes' (kleine Schrift) 'Kniebeugen' (große schrift) wird angezeigt (also exakt das gleiche wie ohne drücken der Pause-Taste)."

Reference: `WorkoutProgramsView.swift` lines 970-1124 (pause behavior split, text styling split, 3-tuple data structure)

### Bug Documentation Protocol (November 2025)

**CRITICAL:** Every bug fix MUST be documented following this protocol.

**When to create separate bug-*.md file:**
1. ✅ Bug required multiple solution attempts (track failed approaches)
2. ✅ Bug represents a recurring pattern (SwiftUI Lifecycle, Date Semantics)
3. ✅ Bug solution is non-obvious and took significant analysis

**When CLAUDE.md + commit is sufficient:**
1. ✅ Bug has generalizable pattern already documented in CLAUDE.md
2. ✅ Bug is trivial fix with no recurring pattern
3. ✅ Commit message + CLAUDE.md lesson cover the learning

**Mandatory artifacts for EVERY bug:**
1. ✅ **Entry in DOCS/bug-index.md** (even if no separate file)
2. ✅ **CLAUDE.md Lesson** (if generalizable pattern)
3. ✅ **Detailed commit message** (Problem, Root Cause, Fix, Files)

**The Rule:**
```
❌ DON'T: Document everything exhaustively (creates noise)
❌ DON'T: Document nothing (lose institutional memory)
✅ DO: Document bugs that help prevent future mistakes
✅ DO: Update bug-index.md for ALL bugs (tracks everything)
✅ DO: Ask yourself: "Will this doc help me avoid repeating this mistake?"
```

**User expectation:** *"Du brauchst nichts zu protokollieren, was dir nichts hilft."*

Reference: DOCS/bug-index.md for categorization criteria

### SwiftUI Lifecycle Duplicate Execution - Callbacks + .onDisappear (November 2025)

**Problem:** Workouts were being logged twice to Apple Health in the Workouts tab.

**Root Cause:** SwiftUI `.onDisappear` lifecycle hook fires AFTER session completion callbacks, causing `endSession()` to execute twice:
```swift
// WorkoutProgramsView.swift - THREE call sites:
// Line 710: Callback when timer completes
ProgressRingsView(onSessionEnd: { await endSession(manual: false) })

// Line 736: Manual stop button
await endSession(manual: true)

// Line 775: View lifecycle
.onDisappear { await endSession(manual: true) }

// When workout completes normally:
// 1. Timer fires → onSessionEnd callback (line 710) executes endSession()
// 2. View disappears → .onDisappear (line 775) executes endSession() AGAIN
// Result: HKWorkoutBuilder.finishWorkout() called twice → duplicate entries
```

**Solution:** Guard Flag Pattern to prevent duplicate execution:
```swift
// Line 689: Add state flag
@State private var sessionEnded: Bool = false

// Lines 791-826: Guard check in endSession()
func endSession(manual: Bool) async {
    print("[WorkoutPrograms] endSession(manual: \(manual)) called")

    // Guard: Prevent double execution (callback + onDisappear)
    if sessionEnded {
        print("[WorkoutPrograms] endSession already executed, skipping duplicate call")
        return
    }

    // ... cleanup code ...

    // Mark session as ended BEFORE async HealthKit logging
    if sessionStart.distance(to: endDate) > 3 {
        sessionEnded = true  // Set synchronously to prevent race condition

        Task.detached(priority: .userInitiated) {
            try await HealthKitManager.shared.logWorkout(
                start: sessionStart,
                end: endDate,
                activity: .highIntensityIntervalTraining
            )
        }
    } else {
        sessionEnded = true  // Also set for sessions < 3s
    }
}
```

**The Pattern:**
```
❌ DON'T: Rely on SwiftUI lifecycle hooks alone for cleanup tasks
❌ DON'T: Call side-effect methods from both callbacks AND .onDisappear without guards
❌ DON'T: Set guard flags AFTER async tasks (race conditions!)
✅ DO: Use Guard Flag Pattern for methods called from multiple lifecycle points
✅ DO: Set flags synchronously BEFORE async operations
✅ DO: Log guard hits for debugging ("already executed, skipping")
```

**Why this matters:**
- SwiftUI lifecycle is unpredictable: callbacks and hooks can overlap
- HealthKit duplicate entries corrupt user's health data
- Race conditions: async tasks can interleave without synchronous guards
- Same pattern applies to: notifications, Live Activities, audio cleanup

**Technical Detail:**
- `HKWorkoutBuilder.finishWorkout()` automatically saves to HealthKit (no manual save needed)
- Each call creates a new HKWorkout entry → duplicates accumulate over time
- Flag must be set synchronously before Task.detached to prevent both branches executing

**User observation:** "Workouts werden doppelt in Apple Health gelogt" (Workouts are being logged twice in Apple Health)

Reference: `WorkoutProgramsView.swift` lines 689 (flag), 791-794 (guard), 807+826 (flag setting)

---

## Established Design Patterns (November 2025)

### InfoButton + InfoSheet Pattern

**Purpose:** Provide contextual help for tabs and features without cluttering the UI.

**Components:**
1. **InfoButton.swift** - Reusable button component
2. **InfoSheet.swift** - Reusable modal sheet with title, description, usage tips

**Usage Pattern:**
```swift
// In parent view
@State private var showInfo = false

// In body
HStack(spacing: 8) {
    Text("Feature Title")
    InfoButton { showInfo = true }
}

// Sheet presentation
.sheet(isPresented: $showInfo) {
    InfoSheet(
        title: "Feature Name",
        description: "What this feature does and why it's useful",
        usageTips: [
            "Step 1: How to use",
            "Step 2: What to expect",
            "Tip: Additional context"
        ]
    )
}
```

**When to Use:**
- ✅ Tab-specific features (Offen-Tab, Frei-Tab, Atem-Tab)
- ✅ Complex UI elements needing explanation (NoAlc-Sheet)
- ✅ Non-obvious functionality requiring user education

**When NOT to Use:**
- ❌ Settings screens (already modal → use inline text instead)
- ❌ Simple, self-explanatory UI elements
- ❌ Features with extensive documentation needs (use separate help screens)

**Key Design Decisions:**
- No decorative icons in InfoSheet (information, not decoration)
- Minimal whitespace (8pt top padding instead of 20pt)
- Consistent styling: `.font(.caption)` for secondary text
- Close button: xmark.circle.fill in toolbar (not dismiss button in content)

**Successfully Applied:**
- Offen-Tab (Offene Meditation)
- Frei-Tab (Freies Workout)
- NoAlc-Tagebuch Sheet
- Phase 2 Mini Improvements: All implemented first-try without errors

Reference: `InfoButton.swift`, `InfoSheet.swift`

---

### Modal Context Awareness

**Rule:** Avoid nested modals. Use inline text for already-modal contexts.

**Example - Settings Screen:**
```swift
// WRONG: Info button in Settings (Settings is already .sheet presentation)
Section(header: Text("Daily Goals")) {
    InfoButton { showGoalsInfo = true }  // ❌ Sheet in Sheet!
}

// CORRECT: Inline explanatory text
Section(header: Text("Daily Goals")) {
    Text("Set your daily goals. Progress shown as filled circles in calendar.")
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

**Why This Matters:**
- iOS Guidelines discourage nested modals (poor UX)
- User has to dismiss multiple layers to return to main content
- Inline text provides immediate context without additional interaction

**Pattern:**
```
✅ DO: Inline text for modal contexts (Settings, Sheets)
❌ DON'T: Info buttons in already-modal UI
```

**Successfully Applied:**
- SettingsSheet.swift: 3 sections with inline explanatory text
- Consistent styling: `.font(.caption)` + `.foregroundStyle(.secondary)`

---

### Tab Content vs Toolbar Placement

**Rule:** Info buttons belong in tab content, not toolbar.

**Why:**
- **Toolbar** = global navigation, shared across tabs (Settings, Calendar navigation)
- **Tab Content** = tab-specific features and context

**Example:**
```swift
// WRONG: Info button in toolbar
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        InfoButton { showInfo = true }  // ❌ Which tab does this explain?
    }
}

// CORRECT: Info button in tab content
VStack {
    HStack(spacing: 8) {
        Text("Feature Title")
        InfoButton { showInfo = true }  // ✅ Clearly belongs to this feature
        Spacer()
    }
    // ... rest of tab content
}
```

**Pattern:**
```
✅ DO: Place info buttons in tab content (next to feature titles)
❌ DON'T: Place info buttons in toolbar (unless explaining global feature)
```

**Successfully Applied:**
- Frei-Tab: Info button next to "Freies Workout" header
- NoAlc-Sheet: Info button next to "NoAlc-Tagebuch" title

---

**For global collaboration rules and workflow, see `~/.claude/CLAUDE.md`**
- immer an lokalisierung denken, bei neuen Features genauso wie bei der Behebung von Bugs. Nutze den Agenten