# Phase 7: Validation

You are in **Phase 7 - Validation**.

## Prerequisites

- Implementation complete (`phase6_implement`)
- All tests passing (GREEN artifacts registered)

Check status:
```bash
python3 .claude/hooks/workflow_state_multi.py status
```

## Your Tasks

### Step 1: Parallele Validierung (4x Haiku)

Dispatche **4 parallele Haiku-Agenten** fuer umfassende Validierung:

```
Task 1 (general-purpose/haiku) - TEST CHECK:
  "Fuehre ALLE Unit Tests aus:
  xcodebuild test \
    -project Meditationstimer.xcodeproj \
    -scheme 'MeditationstimerTests' \
    -destination 'platform=iOS Simulator,id=6653EEF7-8DAB-42A5-ABBA-73C0B8DCA919'
  Report: Anzahl passed/failed, Laufzeit, Fehlerdetails."

Task 2 (general-purpose/haiku) - SPEC COMPLIANCE:
  "Lies die Spec: [spec_file_path]
  Pruefe jeden Acceptance Criterion gegen die Implementation.
  Report: Welche Kriterien sind erfuellt, welche nicht?"

Task 3 (general-purpose/haiku) - REGRESSION CHECK:
  "Fuehre einen vollstaendigen Build aus:
  xcodebuild -project Meditationstimer.xcodeproj \
    -scheme 'Lean Health Timer' \
    -configuration Debug \
    -destination 'platform=iOS Simulator,id=6653EEF7-8DAB-42A5-ABBA-73C0B8DCA919' \
    build
  Report: Compiliert das Projekt fehlerfrei? Gibt es Warnings?"

Task 4 (general-purpose/haiku) - SCOPE CHECK:
  "Vergleiche die geaenderten Dateien mit der Spec.
  Fuehre aus: git diff --stat
  Wurden Dateien ausserhalb des Specs geaendert?
  Wurden mehr als 5 Dateien / 250 LoC geaendert?"
```

### Step 2: Ergebnis-Auswertung

Werte die 4 Reports aus:

**Step 2a: Alle Checks bestanden**
-> Weiter zu Step 3

**Step 2b: Fehler gefunden -> Auto-Fix (general-purpose/Sonnet)**

Bei Fehlern dispatche einen **general-purpose/Sonnet Subagenten**:

```
Task (general-purpose/sonnet): "Folgende Validierungsfehler wurden gefunden:
  [Fehler-Liste aus den 4 Haiku-Reports]

  Behebe die Fehler im Meditationstimer iOS-Projekt. Beachte:
  - Nur die gemeldeten Fehler fixen, keine anderen Aenderungen
  - Scoping Limits einhalten (Max 4-5 Dateien, +/-250 LoC)
  - Tests nach dem Fix erneut ausfuehren
  - iOS 18.5+ / SwiftUI Patterns beachten"
```

Nach dem Fix: Dispatche die relevanten Haiku-Checks erneut zur Verifikation.

### Step 3: Dokumentation aktualisieren (docs-updater/Sonnet)

Bei erfolgreicher Validierung dispatche den **docs-updater**:

```
Task (general-purpose/sonnet): "Du bist der docs-updater Agent.
  Lies die Instruktionen aus .agent-os/agents/core/docs-updater.md.

  Input:
  - changed_files: [Liste der geaenderten Dateien]
  - feature_summary: [Kurzbeschreibung]
  - spec_file_path: [Pfad zur Spec]

  Aktualisiere:
  - DOCS/ACTIVE-todos.md (Bug-Status aktualisieren)
  - DOCS/ACTIVE-roadmap.md (Feature-Status aktualisieren)
  - CLAUDE.md (nur bei Architektur-Aenderungen)"
```

### Step 4: Workflow State aktualisieren

```bash
python3 .claude/hooks/workflow_state_multi.py phase phase8_complete
```

## Validation Report

Erstelle eine Zusammenfassung:

```markdown
## Validation Report: [Workflow Name]

### Test Results
- Unit Tests: [N] passed, [N] failed
- XCUITests: [N] passed, [N] failed
- Full Build: SUCCESS / FAILURE

### Spec Compliance
- Acceptance Criteria: [N]/[N] erfuellt
- [Details zu nicht-erfuellten Kriterien]

### Regression Check
- Build Status: [Compiliert fehlerfrei / Fehler]
- Warnings: [Keine / Liste]

### Scope Check
- Files changed: [N] (Limit: 5)
- LoC changed: +[N]/-[N] (Limit: 250)
- Out-of-scope changes: [Keine / Liste]

### Result: PASS / FAIL
```

## Next Step

After successful validation:
> "Validation successful. All checks passed. Ready for commit."

## On Failure

If validation fails after auto-fix attempt:
1. Do NOT update state to complete
2. Report the remaining issues to the user
3. User decides: fix manually or re-implement
