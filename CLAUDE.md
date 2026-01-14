# Meditationstimer - Project Guide

**Project-specific context for Claude Code. See `~/.claude/CLAUDE.md` for global collaboration rules.**

---

## ⛔ IMPLEMENTATION GATE - ERSTE PFLICHT

**VOR JEDER CODE-ÄNDERUNG MUSS dieses Gate durchlaufen werden!**

Siehe: `.agent-os/standards/global/implementation-gate.md`

```
PFLICHT vor jeder Implementierung:
1. [ ] Bestehende Tests ausführen (xcodebuild test)
2. [ ] Neue Unit Tests schreiben (TDD RED)
3. [ ] Neue XCUITests schreiben (NICHT manuelle Anweisungen!)
4. [ ] Gate-Check dokumentieren

ERST DANN: Code schreiben
```

**⚠️ XCUITests sind PFLICHT - manuelle Test-Checklisten sind KEIN Ersatz!**

**Bei Verstoß:** Henning stoppt die Arbeit, Gate wird nachgeholt.

---

## ⚠️ VERIFY ACTIVE CODE - ZWEITE PFLICHT

**VOR JEDER CODE-ÄNDERUNG prüfen: Bearbeite ich die RICHTIGE Datei?**

Siehe: `.agent-os/standards/global/verify-active-code.md`

```
PFLICHT-CHECK:
1. [ ] Welche View verwendet ContentView.swift? (grep "Tab\|View" ContentView.swift)
2. [ ] Gibt es Duplikate? (grep -rn "struct MyView" .)
3. [ ] Wird meine Datei überhaupt verwendet?

WARNUNG: Es gibt oft parallele Implementierungen (z.B. WorkoutsView vs WorkoutTab)!
```

**Bug 32 Lesson:** Stundenlang falsche Datei bearbeitet weil Duplikat existierte.

---

## Overview

**Healthy Habits Haven (HHHaven)** is a meditation and wellness app built with SwiftUI for iOS 18.5+, watchOS 9.0+, and Widget Extension.

**Features:**
- Free meditation timer with two phases (meditation + reflection)
- Guided breathing exercises (Atem) with customizable presets
- HIIT workout timer with audio cues
- HealthKit integration for activity tracking
- Streak management with reward system
- Live Activities / Dynamic Island support
- Apple Watch companion app with heart rate monitoring

**Current Version:** 2.8.2

**Development Target:**
- **Xcode 26.0.1 / Swift 6.2** (iOS 26.0 SDK)
- **Minimum Deployment:** iOS 18.5, watchOS 9.0
- **Testing:** 66 Unit Tests in Tests/

---

## Agent OS + OpenSpec Integration

This project uses **Agent OS** for standards and **OpenSpec** for spec-driven development.

### Standards (`.agent-os/standards/`)

All coding standards and lessons learned are in:
- `global/` - **Implementation Gate**, Analysis-First, Scoping Limits, Documentation Rules
- `swiftui/` - Lifecycle Patterns, Localization, State Management
- `healthkit/` - Date Semantics, Data Consistency
- `audio/` - Completion Handlers
- `testing/` - Unit Tests, UI Testing

### Agents (`.agent-os/agents/`)

Specialized agents with injected standards:
- `bug-investigator.md` - Bug analysis (Analysis-First)
- `feature-planner.md` - Feature planning (Spec-First)
- `localizer.md` - DE/EN localization
- `test-runner.md` - Unit test execution
- `ui-test-guide.md` - Manual UI test checklists

### Workflows (`.agent-os/workflows/`)

- `bug-fix-workflow.md` - Full bug fix process
- `feature-workflow.md` - Feature development with OpenSpec
- `release-workflow.md` - Version bump and deploy

### Feature Specs (`openspec/specs/`)

- `features/meditation-timer.md` - Two-phase timer
- `features/workouts.md` - HIIT timer
- `features/breathing.md` - Guided breathing
- `features/noalc-tracker.md` - Alcohol tracking
- `features/smart-reminders.md` - Conditional notifications
- `integrations/healthkit.md` - HealthKit patterns
- `integrations/live-activities.md` - Dynamic Island

---

## Slash Commands (Agent OS v2.0)

### Core Commands (plattform-unabhängig)

| Command | Phase | Purpose |
|---------|-------|---------|
| `/context` | 1 | Kontext sammeln für Feature/Bug |
| `/analyse` | 2 | Analyse durchführen |
| `/write-spec` | 3 | Spezifikation erstellen |
| `/tdd-red` | 5 | Failing Tests schreiben (TDD RED) |
| `/implement` | 6 | Code implementieren (Tests grün machen) |
| `/validate` | 7 | Manuelle Validierung |
| `/workflow` | - | Workflow-Status & Multi-Workflow-Manager |
| `/add-artifact` | - | Test-Artefakt hinzufügen |
| `/bug` | - | Bug aufnehmen & analysieren |
| `/0-reset` | - | Workflow zurücksetzen |

### iOS-Spezifische Commands

| Command | Agent | Purpose |
|---------|-------|---------|
| `/test` | test-runner | Unit Tests ausführen |
| `/sim-test` | simulator-tester | Simulator UI Tests |
| `/localize` | localizer | Lokalisierung prüfen (DE/EN) |
| `/ui-test` | ui-test-guide | UI-Test-Checkliste erstellen |

### 8-Phasen-Workflow (v2.0)

```
phase0_idle → phase1_context → phase2_analyse → phase3_spec →
phase4_approved → phase5_tdd_red → phase6_implement → phase7_validate → phase8_complete
```

**Kritische Phasen:**
- **Phase 4 (Approved):** User muss Spec freigeben (sag "approved")
- **Phase 5 (TDD RED):** Tests schreiben die fehlschlagen - ECHTE Artefakte erforderlich
- **Phase 6 (Implement):** Code schreiben um Tests grün zu machen

### Multi-Workflow Support (v2.0)

Agent OS v2.0 unterstützt **mehrere parallele Workflows**:

```bash
/workflow status        # Alle aktiven Workflows anzeigen
/workflow switch <id>   # Zu anderem Workflow wechseln
/workflow complete      # Aktuellen Workflow abschließen
```

---

## Bug-Fixing Pflicht

**Bei JEDEM Bug-Fix MUSS der `bug-investigator` Agent verwendet werden:**

- Aufruf: `/bug [Beschreibung]`
- Der Agent analysiert erst vollstaendig, dann wird (nach Freigabe) gefixt
- **Ausnahme:** Triviale Typos (1 Zeile, offensichtlich)
- **Standards:** Siehe `.agent-os/standards/global/analysis-first.md`

---

## UI-Testing Regeln

**⚠️ XCUITests sind PFLICHT bei jeder UI-Änderung!**

1. **XCUITests MÜSSEN geschrieben werden** - in `LeanHealthTimerUITests/`
2. **Manuelle Test-Checklisten sind KEIN Ersatz** für automatisierte Tests
3. **Ausnahme NUR bei technischer Unmöglichkeit** - mit schriftlicher Begründung

**XCUITest Command:**
```bash
xcodebuild test \
  -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:LeanHealthTimerUITests
```

**Standards:** Siehe `.agent-os/standards/testing/ui-testing.md`

---

## Dokumentations-Pflicht

**SOFORT aktualisieren wenn Arbeit erledigt ist:**

1. Nach jedem Fix: ACTIVE-todos.md aktualisieren
2. Nach jedem Test: Ergebnis dokumentieren
3. Nach Feature: ACTIVE-roadmap.md aktualisieren

**Standards:** Siehe `.agent-os/standards/global/documentation-rules.md`

---

## Architecture Overview

```
iOS / watchOS / Widget Apps (UI)
            |
            v
    Shared Service Layer (Services/)
    - TwoPhaseTimerEngine
    - HealthKitManager
    - StreakManager
    - GongPlayer
            |
            v
    Platform Frameworks
    - HealthKit
    - ActivityKit
    - WatchConnectivity
```

### Key Design Principles

1. **Foreground-First Timers:** All timers run in foreground only
2. **Shared Services:** Business logic in `/Services/`
3. **HealthKit as Source of Truth:** All historical data from HealthKit
4. **Live Activity Coordination:** Only one activity at a time

---

## Build Commands

**Build iOS app:**
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

---

## Project Structure

```
Meditationstimer/
├── .agent-os/               # Standards, Agents, Workflows
├── openspec/                # Feature Specifications
├── DOCS/                    # Active todos, roadmap, bug-index
├── Services/                # Shared business logic
├── Meditationstimer iOS/    # iOS app
├── Meditationstimer Watch/  # watchOS app
└── Tests/                   # Unit tests (66 tests)
```

---

## Core Components

| Component | File | Purpose |
|-----------|------|---------|
| TwoPhaseTimerEngine | Services/ | Two-phase meditation timer |
| HealthKitManager | Services/ | HealthKit integration |
| LiveActivityController | iOS/ | Dynamic Island |
| StreakManager | Services/ | Streak calculation |
| GongPlayer | Services/ | Audio playback |

---

## Quick Reference

**Version:** 2.8.2

**Main Schemes:**
- "Lean Health Timer" - iOS + Watch + Widget
- "Meditationstimer Watch App" - watchOS only
- "MeditationstimerTests" - Unit tests

**Key Files:**
- `Services/TwoPhaseTimerEngine.swift` - Timer logic
- `Services/HealthKitManager.swift` - HealthKit
- `Meditationstimer iOS/Tabs/OffenView.swift` - Main UI
- `Meditationstimer iOS/LiveActivityController.swift` - Dynamic Island

**Dependencies:**
- HealthKit, ActivityKit, WatchConnectivity, AVFoundation

---

## Documentation Structure

| Location | Content |
|----------|---------|
| `.agent-os/standards/` | Coding standards (from Lessons Learned) |
| `.agent-os/agents/` | Specialized agents with standards |
| `.agent-os/workflows/` | Bug fix, feature, release workflows |
| `openspec/specs/` | Feature specifications |
| `DOCS/ACTIVE-todos.md` | Current bugs and tasks |
| `DOCS/ACTIVE-roadmap.md` | Planned features |
| `DOCS/bug-index.md` | Bug pattern reference |

---

## Localization

- **Primary:** German (DE)
- **Secondary:** English (EN)
- **Files:** `Localizable.xcstrings`
- **Standards:** `.agent-os/standards/swiftui/localization.md`

---

**For global collaboration rules, see `~/.claude/CLAUDE.md`**
