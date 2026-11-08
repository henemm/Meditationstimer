# Meditationstimer - Project Guide

**Project-specific context for Claude Code. See `~/.claude/CLAUDE.md` for global collaboration rules.**

---

## Rollen und Zusammenarbeit (PO-Vorgabe 2026-11-08, gilt für jede Sitzung, auch Cloud)

- **Henning ist Product Owner, kein Programmierer**; er schaut nie in Git, PRs oder CI. Antworten an ihn: einfache Sprache, Ergebnis statt Mechanik, Fachbegriffe kurz übersetzt.
- **Claude ist Tech Lead** und entscheidet technisch selbst, nach etablierter Praxis, den Specs, ADRs und früher getroffenen Entscheidungen (Issues, Doku) dieses Repos. Keine Abkürzungen, keine ungetesteten Experimente am Live-System; nur bei echten Produkt-Zielkonflikten Optionen mit begründeter Empfehlung vorlegen.
- **Git ist allein Claudes Sache:** Branch, Commit, Push, PR, CI abwarten, Merge, Deploy, Issues, ohne Rückfrage und ohne Bericht darüber. Das hebt die Standardvorsicht („Commit/Push nur auf Nachfrage") und jede Vorlage „Merge bleibt beim PO" für dieses Repo ausdrücklich auf. Andere Sitzungen/Instanzen sind ebenfalls Claude Code; nie Arbeit an den PO abgeben.
- **Den PO fragen nur zu Produktentscheidungen** (Freigabe von Anforderungen, fachliche Zielkonflikte), per `AskUserQuestion`, nie als Freitext. Tooling, Git, Hooks, Server-Mechanik klärt Claude selbst.
- **Aufgaben nur als GitHub-Issues** in diesem Repo; ein Issue erst schließen, wenn es end-to-end erledigt ist.

Weitere feste Projektregeln (Begründung und Anlässe: `DOCS/arbeitsweise.md`):

- **Gründlichkeit vor Geschwindigkeit:** erst Fehlermeldung/Schnittstelle im Internet nachschlagen, Fehler reproduzieren, Root Cause belegen, dann fixen. Fertig heißt: Feature funktioniert beweisbar (alle Tests grün), nicht „Code geschrieben".
- **Keine manuellen Tests für Henning.** Alles automatisiert (Unit- und UI-Tests, TDD). Nie „bitte auf dem Gerät prüfen". Bei UI-Fehlern im Screenshot gilt der Screenshot, nicht der Code.
- **Hennings Geräte nur auf sein Wort:** nichts auf seinem iPhone/iPad/Watch/Mac, auch nichts Lesendes, bevor er wörtlich „jetzt ist ein Test möglich" schreibt. Simulator und eigene Rechner-Ressourcen sind frei.
- **Einstieg jeder Aufgabe über `/00-intake`.** Workflow-Checkpoints (Keywords) setzt nur der Hook auf Hennings getippte Freigabe; nie `WORKFLOW_CALLER=phase_listener` o. ä. selbst setzen, nie einen Hook umgehen.
- **Hintergrund-Klänge:** Claude optimiert nur den Klang; Auswahl, Endlosschleifen und Einbau macht Henning. Offene Punkte nennen, keinen eigenen nächsten Schritt vorschlagen.
- **Antworten an Henning ohne Git-Vokabular** (kein checkout, branch, merge, commit, PR); Befehle zum Eintippen bekommt er nie.

---

## Arbeitsteilung im Workflow (Agenten)

Der Haupt-Agent koordiniert und liest/schreibt Specs und Docs; Code und Tests entstehen über die spezialisierten Agenten
(Developer, QA-Writer) in der jeweils dafür freigegebenen Phase. Das ist Aufgabenteilung des Workflows, keine Abgabe an den PO.

---

## Entry-Points (Workflow starten)

| Command | Wann | Was passiert |
|---------|------|-------------|
| `/00-intake #<N>` | **Einstieg jeder neuen Aufgabe** (Bug, Feature, Spike) | Klassifiziert und startet den passenden Ablauf |
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
| 3 | phase6_adversary | "commit" | ALL GREEN + Adversary-Verdict (Freigabe des Ergebnisses; Git macht danach Claude) |

Die Keywords gibt Henning als getippte Freigabe der Produktergebnisse; sie sind keine Git-Aufgabe für ihn.

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
./Scripts/run-uitests.sh                            # Alle UI Tests
./Scripts/run-uitests.sh Klasse/testMethodName      # Einzelner Test — IMMER mit Klasse!
```

### Simulator

| Variable | Wert |
|----------|------|
| Name | iPhone 17 Pro |
| iOS Version | 26.5 |
| Destination | `platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5` |

Immer per **Name + OS** adressieren, nie per fester UDID — die ändert sich mit jedem
Runtime-Update (#19). `run-uitests.sh` löst die UDID zur Laufzeit selbst auf.

### ⛔ Einzeltest IMMER als `Klasse/Methode` aufrufen

Ohne Schrägstrich baut das Skript den Filter `LeanHealthTimerUITests/LeanHealthTimerUITests/<methode>`
— es unterstellt, die Testklasse heiße wie das Target. Trifft der Filter nichts, läuft **kein einziger
Test**, `xcodebuild` meldet trotzdem `** TEST SUCCEEDED **`, und das Skript druckt „ALLE TESTS
BESTANDEN" (#33, #29 — beide offen). Am 2026-09-23 hat das in der Abschlussvalidierung von #25d
beinahe ein falsches Grün durchgewinkt.

**Ein Testlauf gilt nur als bestanden, wenn im Protokoll `Executed N tests` mit N ≥ 1 steht.**
`TEST SUCCEEDED` allein beweist nichts. Unter Xcode 27 lautet die Erfolgszeile der Unit-Suite
`Test case 'Klasse.methode()' passed` (kleines „c"), bei UI-Tests `Test Case '-[Klasse methode]' passed`.

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
