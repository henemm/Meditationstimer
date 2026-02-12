# Phase 2: Analyse

You are in **Phase 2 - Analysis** of the workflow.

## Prerequisites

- Context gathered (`/context` completed, or combined with analysis)
- Active workflow exists

Check current workflow:
```bash
python3 .claude/hooks/workflow_state_multi.py status
```

## Your Tasks

### Step 1: Bug vs. Feature Routing

Bestimme aus dem Kontext:
- **Bug:** User meldet ein Problem, etwas funktioniert nicht wie erwartet
- **Feature:** User wuenscht neue Funktionalitaet oder Aenderung

### Step 2a: Feature-Analyse (3x Explore/Haiku parallel)

Bei Features dispatche **3 parallele Subagenten** fuer schnelle Kontextsammlung:

```
Task 1 (Explore/haiku): "Finde alle Dateien die von [Feature-Bereich] betroffen
  sind im Meditationstimer-Projekt. Suche in Services/, 'Meditationstimer iOS/',
  Tests/. Liste: Dateipfad, Typ (MODIFY/CREATE/DELETE), Begruendung."

Task 2 (Explore/haiku): "Suche nach bestehenden Specs in openspec/specs/ die
  [Feature-Bereich] betreffen. Liste gefundene Specs mit Status."

Task 3 (Explore/haiku): "Identifiziere Dependencies und Imports fuer
  [Feature-Bereich]. Welche Services (HealthKitManager, StreakManager,
  GongPlayer, TwoPhaseTimerEngine) haengen davon ab?"
```

### Step 2b: Bug-Analyse (bug-intake/Haiku)

Bei Bugs dispatche den **bug-intake Agent**:

```
Task (general-purpose/haiku): Verwende die bug-intake Instruktionen aus
  .agent-os/agents/core/bug-intake.md.
  Input: symptom=[Fehlerbeschreibung], context=[Wo/Wann]
  Fuehre parallele Investigation durch und erstelle Bug Report.
```

### Step 3: Strategische Bewertung (Plan/Sonnet)

Dispatche einen **Plan/Sonnet Subagenten** fuer die strategische Bewertung:

```
Task (Plan/sonnet): "Basierend auf folgenden Investigation-Ergebnissen:
  [Ergebnisse aus Step 2]

  Bewerte fuer das Meditationstimer iOS-Projekt:
  1. Technischer Ansatz (wie implementieren?)
  2. Risiko-Bewertung (was koennte brechen? HealthKit, LiveActivity, Watch?)
  3. Scope-Schaetzung (Dateien, LoC - Max 4-5 Dateien, +/-250 LoC)
  4. Abhaengigkeiten und Reihenfolge
  5. Empfehlung (eine klare Empfehlung)"
```

### Step 4: Synthese praesentieren

Fasse die Ergebnisse zusammen und aktualisiere `docs/context/[workflow-name].md`:

```markdown
## Analysis

### Type
[Bug / Feature]

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| Services/StreakManager.swift | MODIFY | Add reward logic |
| Tests/StreakManagerTests.swift | MODIFY | Add test cases |

### Scope Assessment
- Files: [N] (Max 5)
- Estimated LoC: +[N]/-[N] (Max 250)
- Risk Level: LOW/MEDIUM/HIGH

### Technical Approach
[Empfehlung aus Plan/Sonnet Bewertung]

### Dependencies
[Aus Explore-Ergebnis]

### Open Questions
- [ ] Question 1?
```

### Step 5: Update Workflow State

```bash
python3 .claude/hooks/workflow_state_multi.py phase phase3_spec
```

## Next Step

When analysis is complete:
> "Analysis complete. Type: [Bug/Feature]. Scope: [N] files, ~[N] LoC. Next: `/write-spec` to create the specification."

If you have open questions, ask the user before proceeding.

**IMPORTANT:** Do NOT start implementation. Analysis -> Spec -> Approve -> TDD RED -> Implement.
