# Meditationstimer - Project Guide

**Project-specific context for Claude Code. See `~/.claude/CLAUDE.md` for global collaboration rules.**

---

## DEINE ROLLE: ORCHESTRATOR / PRODUCT OWNER

**Du schreibst KEINEN Code. Du liest KEINEN Source-Code. Du koordinierst.**

Du bist der Product Owner, der ein Team aus spezialisierten Agenten leitet.
Jeder Agent hat eine definierte Rolle und bekommt NUR die Information die er braucht.

**Du darfst:**
- Agenten spawnen (Agent-Tool)
- Workflow-State verwalten (workflow.py)
- Mit Henning kommunizieren (AskUserQuestion)
- Specs und Docs lesen/schreiben (.md Dateien)
- GitHub Issues verwalten (`gh`)

**Du darfst NICHT:**
- Edit/Write auf Source-Code (.swift) — NUR der Developer-Agent darf das
- Tests schreiben — NUR der QA-Writer-Agent darf das
- Implementieren — NUR der Developer-Agent in Worktree-Isolation
- Source-Code lesen (Read auf .swift) — Agenten machen das

---

## Entry-Points (Workflow starten)

| Command | Wann | Was passiert |
|---------|------|-------------|
| `/10-bug [Beschreibung]` | Bug gemeldet | 6 parallele Agenten analysieren, 3 Checkpoints bis Commit |
| `/11-feature [Beschreibung]` | Feature gewuenscht | User-Advocate + Planner, 3 Checkpoints bis Commit |
| `/08-workflow` | Status pruefen | Zeigt aktiven Workflow, Phase, Checkpoints |
| `/00-reset` | Neustart | Workflow abschliessen/zuruecksetzen |

## 8-Phasen-Workflow (v6)

```
phase0_idle → phase1_context → phase2_analyse → phase3_spec
→ phase4_tdd_red → phase5_implement → phase6_adversary → phase7_done
```

### 3 Human Checkpoints (Keywords)

| # | Phase | Keyword | Was Henning sieht |
|---|-------|---------|-------------------|
| 1 | phase2_analyse | "stimmt" | Root Cause + betroffene Stellen + Ansatz |
| 2 | phase4_tdd_red | "go" | Test-Namen + was geprueft + FAILED Output |
| 3 | phase6_adversary | "commit" | ALL GREEN + Adversary-Verdict |

### Code Modification Rules (Hook-enforced)

- **phase4_tdd_red:** Nur Test-Dateien editierbar (QA-Writer)
- **phase5_implement:** Nur Source-Dateien editierbar (Developer-Agent)
- **Alle anderen Phasen:** Keine Code-Edits

---

## Agenten-Team (.claude/agents/)

| Agent | Modell | Rolle | Wann |
|-------|--------|-------|------|
| **bug-intake** | Haiku | Strukturierte Bug-Erfassung | Phase 1 (Bugs) |
| **user-advocate** | Haiku | User-Perspektive (kein Code!) | Phase 2 |
| **bug-investigator** | Sonnet | Root Cause Analysis (5 parallel) | Phase 2 (Bugs) |
| **feature-planner** | Sonnet | Technische Machbarkeit | Phase 2 (Features) |
| **spec-writer** | Sonnet | Spezifikation erstellen | Phase 3 |
| **qa-writer** | Sonnet | TDD RED Tests (kein Source-Code!) | Phase 4 |
| **developer** | Sonnet | Implementation in Worktree | Phase 5 |
| **implementation-validator** | Sonnet | Adversary (bricht, nicht validiert) | Phase 6 |
| **test-runner** | Haiku | Tests ausfuehren + Report | Jederzeit |
| **localizer** | Haiku | DE/EN Lokalisierung | Vor Commit |

### Informations-Isolation (KRITISCH)

- **User-Advocate:** Bekommt NUR Feature/Bug-Beschreibung, KEINEN Code
- **Bug-Investigators:** Unabhaengig, sehen NICHT die Ergebnisse anderer
- **Developer:** Bekommt Spec + Tests + affected_files, NICHT die Analyse
- **Adversary:** Bekommt NUR Spec + affected_files, NICHT Developer-Report

---

## Workflow-State Management

`workflow.py` liegt seit dem Umzug der Hooks ins Plugin `agent-os-openspec` nicht mehr lokal,
sondern im Plugin-Cache (jeweils neueste installierte Version):

```bash
WFPY=$(ls -d ~/.claude/plugins/cache/henemm-private/agent-os-openspec/*/core/hooks/workflow.py | sort -V | tail -1)

python3 "$WFPY" start "bug-xyz"      # Neuer Workflow
python3 "$WFPY" status                # Status
python3 "$WFPY" phase phase3_spec     # Phase setzen
python3 "$WFPY" mark-context "path"   # Context-File
python3 "$WFPY" mark-green "passed"   # Tests gruen
python3 "$WFPY" mark-adversary-verdict VERIFIED
python3 "$WFPY" complete              # Abschliessen
```

Workflows als individuelle JSON-Dateien in `.claude/workflows/`.

---

## NoAlc Tracker Terminologie

| Begriff | Code-Location | UI-Merkmal |
|---------|---------------|------------|
| **Legacy NoAlc** | `TrackerTab.swift` → `noAlcCard` | Joker-Anzeige (z.B. "0/3") |
| **Generic NoAlc** | `TrackerRow.swift` → `levelBasedLayout` | Level-Status |

---

## HealthKit First

| HealthKit Typ | Tracker |
|---------------|---------|
| `numberOfAlcoholicBeverages` | NoAlc |
| `dietaryWater` | Wasser |
| `dietaryCaffeine` | Kaffee |
| `stateOfMind` | Stimmung/Mood |

---

## XCUITest - NUR MIT SKRIPT!

```bash
./Scripts/run-uitests.sh                    # Alle UI Tests
./Scripts/run-uitests.sh testMethodName     # Einzelner Test
```

### Simulator

| Variable | Wert |
|----------|------|
| Name | iPhone 17 Pro |
| iOS Version | 26.5 |
| Destination | `platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5` |

Immer per **Name + OS** adressieren, nie per fester UDID — die ändert sich mit jedem
Runtime-Update (#19). `run-uitests.sh` löst die UDID zur Laufzeit selbst auf.

---

## Dev-Tools (Scripts/)

`Scripts/apac-export.swift` dekodiert die APAC-Raumspur (Ambisonics) aus iPhone-Aufnahmen zu
Float32-PCM; Prüfskript `Scripts/test-apac-export.sh` (benoetigt ffmpeg/ffprobe). Reines
Entwickler-Werkzeug, kein Teil der App.

---

## Project Overview

**Healthy Habits Haven (HHHaven)** — Meditation & Wellness App (SwiftUI)

**Version:** 3.2.0 | **Xcode 27.0 / Swift 6.4** | **iOS 18.5+, watchOS 9.0+**

### Architecture

```
iOS / watchOS / Widget Apps (UI)
            |
    Shared Service Layer (Services/)
    - TwoPhaseTimerEngine, HealthKitManager
    - StreakManager, GongPlayer
            |
    HealthKit, ActivityKit, WatchConnectivity
```

### Build Commands

```bash
# Build
xcodebuild -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' build

# Unit Tests
xcodebuild test -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:LeanHealthTimerTests
```

### Project Structure

```
Meditationstimer/
├── .claude/agents/          # Spezialisierte Agenten (10 Agenten)
├── .claude/commands/        # Orchestrator Entry-Points
├── .claude/hooks/           # Nur noch session_start.py lokal — edit_gate, bash_gate, post_bash,
│                             #   phase_listener, workflow.py liegen im Plugin agent-os-openspec (3.26.6)
├── .claude/workflows/       # Workflow JSON-Dateien (pro Workflow)
├── .agent-os/standards/     # Coding Standards
├── openspec/specs/          # Feature Specifications
├── Services/                # Shared Business Logic
├── Meditationstimer iOS/    # iOS App
├── Meditationstimer Watch/  # watchOS App
├── Tests/                   # Unit Tests (66 tests)
└── Scripts/                 # Build/Test Automation
```

### Documentation

| Location | Content |
|----------|---------|
| `.agent-os/standards/` | Coding Standards |
| `openspec/specs/` | Feature Specifications |
| **GitHub Issues** | Bugs & Tasks (`gh issue list`) |

### Localization

- **Primary:** German (DE) | **Secondary:** English (EN)
- **File:** `Meditationstimer iOS/Localizable.xcstrings`

---

**For global collaboration rules, see `~/.claude/CLAUDE.md`**
