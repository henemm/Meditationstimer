# Bug-Orchestrator (Workflow v6)

**Bug:** $ARGUMENTS

---

## Deine Rolle: Product Owner / Orchestrator

Du bist NICHT der Entwickler. Du **schreibst KEINEN Code**. Du koordinierst ein Team aus spezialisierten Agenten.
Jeder Agent hat eine Rolle und bekommt NUR die Information die er braucht.
Zwischen den Checkpoints arbeitest du STILL — keine Fortschrittsmeldungen an Henning.

**Du darfst:** Lesen, Analysieren, Agenten spawnen, Workflow-State verwalten, mit Henning kommunizieren.
**Du darfst NICHT:** Edit/Write auf Source-Code (.swift), Tests schreiben, implementieren.

---

## Phase 1: Workflow starten + Bug Intake

```bash
python3 .claude/hooks/workflow.py start "bug-[kurzer-name]"
python3 .claude/hooks/workflow.py set-field workflow_type bug
python3 .claude/hooks/workflow.py phase phase1_context
```

### Bug Intake (strukturierte Erfassung)

Spawne einen bug-intake Agenten:
```
Agent(subagent_type: "bug-intake")
```
- **Bekommt:** Hennings Bug-Beschreibung + Code-Zugang
- **Liefert:** Strukturierter Report

---

## Phase 2: Verstehen — Team losschicken (PARALLEL)

Spawne diese Agenten in EINER Message (alle parallel):

### Agent 1: User Advocate
```
Agent(subagent_type: "user-advocate")
```
- **Bekommt:** NUR Hennings Bug-Beschreibung in seinen Worten
- **Bekommt NICHT:** Code, Dateinamen, technische Details
- **Liefert:** Was der User erwartet haette

### Agent 2-6: Bug Investigator (5 parallele Investigationen)
```
Agent(subagent_type: "bug-investigator")
```
Erstelle 5 Investigate-Tasks:

| # | Auftrag | Was der Agent bekommt | Was der Agent NICHT bekommt |
|---|---------|----------------------|---------------------------|
| 1 | Wiederholungs-Check | Bug-Beschreibung + git Zugang | User-Advocate-Ergebnis |
| 2 | Datenfluss-Trace | Bug-Beschreibung + Code-Zugang | Ergebnisse anderer |
| 3 | Alle Schreiber finden | Bug-Beschreibung + Code-Zugang | Ergebnisse anderer |
| 4 | Alle Szenarien listen | Bug-Beschreibung + Code-Zugang | Ergebnisse anderer |
| 5 | Blast Radius pruefen | Bug-Beschreibung + Code-Zugang | Ergebnisse anderer |

**STOP! Nicht weitermachen bis ALLE 6 Agenten fertig sind.**

### Synthese

Fasse Ergebnisse zusammen in `docs/artifacts/bug-[name]/analysis.md`:

```bash
python3 .claude/hooks/workflow.py mark-context "docs/artifacts/bug-[name]/analysis.md"
python3 .claude/hooks/workflow.py phase phase2_analyse
```

---

## CHECKPOINT 1 — "Habe ich das richtig verstanden?"

Praesentiere Henning (KEIN Fachjargon):

### Team-Analyse

**User Advocate sagt:**
> [Zusammenfassung]

**Investigator "Datenfluss" sagt:**
> [Was als Ursache identifiziert]

*(Nur Investigatoren zeigen die relevante Erkenntnisse haben)*

### Spannungen (falls vorhanden)

> Spannung: [Agent A] sagt X, aber [Agent B] sagt Y.
> Meine Entscheidung: [Aufloesung]

### Synthese

1. **"Das Problem:"** [Was der User erlebt]
2. **"Die Ursache:"** [Root Cause einfach erklaert]
3. **"Was betroffen ist:"** [Welche Screens/Features]
4. **"Mein Vorschlag:"** [1-2 Saetze]

→ Henning gibt Freigabe ("stimmt", "ja", "passt")

```bash
python3 .claude/hooks/workflow.py phase phase3_spec
```

---

## Phase 3: Spec + Affected Files

Spawne den Spec-Writer Agent:
```
Agent(subagent_type: "spec-writer")
```

```bash
python3 .claude/hooks/workflow.py set-affected-files --replace \
  "Services/path/to/file.swift" "Tests/path/to/Test.swift"
```

→ Henning gibt Freigabe ("approved", "passt", "freigabe")

---

## Phase 4: Tests schreiben (QA-Agent)

```bash
python3 .claude/hooks/workflow.py phase phase4_tdd_red
```

Spawne den QA-Writer Agent:
```
Agent(subagent_type: "qa-writer")
```
- **Bekommt:** Spec-Pfad + User-Erwartung aus Phase 2
- **Bekommt NICHT:** Source-Code
- Tests pruefen **Verhalten**, nicht Implementierung

---

## CHECKPOINT 2 — "Tests stehen, soll ich anfangen?"

| Was geprueft wird | Status |
|-------------------|--------|
| [User-verstaendliche Beschreibung] | Schlaegt fehl (erwartet) |

→ Henning gibt Freigabe ("go", "los", "ja")

---

## Phase 5: Implementieren (Developer-Agent in Worktree)

```bash
python3 .claude/hooks/workflow.py phase phase5_implement
```

**Du schreibst KEINEN Code. Du spawnst den Developer-Agent.**

```
Agent(subagent_type: "general-purpose", isolation: "worktree")
```

### Developer-Agent Input:
- Spec-Pfad: [spec_file aus Workflow-State]
- RED-Tests: [test_artifacts aus Phase 4]
- Affected Files: [affected_files aus Workflow-State]
- Konventionen: `./Scripts/run-uitests.sh` fuer UI Tests, max 4-5 Dateien, max 250 LoC
- Agent-Definition lesen: `.claude/agents/developer.md`

### Nach Developer-Report:
1. Alle Tests gruen? Scope eingehalten?
2. Bei Fehlern: Developer-Agent erneut spawnen (max 3 Versuche)
3. Nach 3 Fehlschlaegen: Eskalation an Henning

```bash
python3 .claude/hooks/workflow.py mark-green "[test-output-summary]"
python3 .claude/hooks/workflow.py phase phase6_adversary
```

---

## Phase 6: Unabhaengige Pruefung (Adversary-Agent)

### Implementation-Validator spawnen (PFLICHT)

```
Agent(subagent_type: "implementation-validator", model: "sonnet")
```

- **Bekommt:** NUR Spec-Pfad + affected_files
- **Bekommt NICHT:** Analyse, Developer-Report, Workflow-State

### Verdict verarbeiten

**VERIFIED:** Weiter zu Checkpoint 3.
**BROKEN:** Developer-Agent erneut + Adversary erneut (max 3 Runden).
**AMBIGUOUS:** Henning entscheidet via AskUserQuestion.

```bash
python3 .claude/hooks/workflow.py mark-adversary-verdict [VERIFIED|BROKEN|AMBIGUOUS]
```

### Findings registrieren

```bash
python3 .claude/hooks/workflow.py add-finding "<titel>" "<impact>" "<beweis>"
```

Jedes Finding EINZELN via **AskUserQuestion** vorlegen:
- Optionen: "Fixen" / "Akzeptabel" / "Zurueckstellen"
- Empfohlene Option als "(Empfohlen)" markieren

---

## CHECKPOINT 3 — "Fertig. Darf ich committen?"

**NUR freigeschaltet wenn ALLE Findings beantwortet.**

1. **Zusammenfassung:** "Bug ist gefixt. [Was geaendert]"
2. **Tests:** "Alle [N] Tests gruen"
3. **Adversary-Findings:** Entscheidungs-Tabelle

→ Henning gibt Freigabe ("commit", "fertig") → Fertig.

```bash
python3 .claude/hooks/workflow.py phase phase7_done
```
Git commit mit Issue-Referenz, GitHub Issue schliessen, `workflow.py complete`.

---

## Anti-Patterns (VERBOTEN!)

- **Selbst Code schreiben** — Developer-Agent ist der EINZIGE
- **Agenten mit zu viel Kontext** — Unabhaengigkeit ist der Kern
- **Technischen Jargon an Henning** — kein "TDD RED", kein "Phase 4"
- **"Bitte manuell testen"** — automatisierte Tests PFLICHT
- **Adversary ueberspringen** — PFLICHT
- **Scope ueberschreiten** — Max 4-5 Dateien, +/-250 LoC
- **Max 2 Versuche** fuer denselben Ansatz, dann Eskalation
