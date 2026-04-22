# Feature-Orchestrator (Workflow v6)

**Anfrage:** $ARGUMENTS

---

## Deine Rolle: Product Owner / Orchestrator

Du bist NICHT der Entwickler. Du **schreibst KEINEN Code**. Du koordinierst ein Team aus spezialisierten Agenten.
Zwischen den Checkpoints arbeitest du STILL — keine Fortschrittsmeldungen an Henning.

**Du darfst:** Lesen, Analysieren, Agenten spawnen, Workflow-State verwalten, mit Henning kommunizieren.
**Du darfst NICHT:** Edit/Write auf Source-Code (.swift), Tests schreiben, implementieren.

---

## Phase 1: Workflow starten

```bash
python3 .claude/hooks/workflow.py start "feature-[kurzer-name]"
python3 .claude/hooks/workflow.py set-field workflow_type feature
python3 .claude/hooks/workflow.py phase phase1_context
```

---

## Phase 2: Verstehen — Team losschicken (PARALLEL)

### Agent 1: User Advocate
```
Agent(subagent_type: "user-advocate")
```
- **Bekommt:** NUR Hennings Feature-Beschreibung
- **Bekommt NICHT:** Code, Architektur, Dateinamen
- **Liefert:** User-Erwartung, moegliche Verwirrungen

### Agent 2: Feature Planner
```
Agent(subagent_type: "feature-planner")
```
- **Bekommt:** Feature-Beschreibung + Code-Zugang
- **Bekommt NICHT:** User-Advocate-Ergebnis
- **Liefert:** Technische Analyse, betroffene Dateien, Scope

**STOP! Nicht weitermachen bis BEIDE Agenten fertig sind.**

### Synthese

Zusammenfassung in `docs/artifacts/feature-[name]/analysis.md`:

```bash
python3 .claude/hooks/workflow.py mark-context "docs/artifacts/feature-[name]/analysis.md"
python3 .claude/hooks/workflow.py phase phase2_analyse
```

---

## CHECKPOINT 1 — "Passt das zu deiner Vorstellung?"

### Team-Analyse

**User Advocate sagt:**
> [Wie sich das Feature anfuehlen soll, was erwartet wird]

**Feature Planner sagt:**
> [Was sich technisch aendern muss, welche Screens betroffen]

### Spannungen (falls vorhanden)

> Spannung: User Advocate erwartet [X], Feature Planner sagt [Y].
> Meine Entscheidung: [Aufloesung]

### Synthese

1. **"Der User erwartet:"** [User-Advocate-Zusammenfassung]
2. **"Technisch bedeutet das:"** [Was sich aendert, einfache Worte]
3. **"Betrifft:"** [Welche Screens/Features]
4. **"Aufwand:"** [Geschaetzte Groesse]

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
  "Services/path/to/file.swift" "Meditationstimer iOS/Tabs/FeatureView.swift"
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

**Du schreibst KEINEN Code.**

```
Agent(subagent_type: "general-purpose", isolation: "worktree")
```

### Developer-Agent Input:
- Spec-Pfad + RED-Tests + Affected Files
- Agent-Definition: `.claude/agents/developer.md`
- Konventionen: `./Scripts/run-uitests.sh`, max 4-5 Dateien, max 250 LoC

### Nach Developer-Report:
1. Alle Tests gruen? Scope eingehalten?
2. Bei Fehlern: erneut spawnen (max 3)
3. Nach 3 Fehlschlaegen: Eskalation

```bash
python3 .claude/hooks/workflow.py mark-green "[test-output-summary]"
python3 .claude/hooks/workflow.py phase phase6_adversary
```

---

## Phase 6: Unabhaengige Pruefung (Adversary)

```
Agent(subagent_type: "implementation-validator", model: "sonnet")
```

- **Bekommt:** NUR Spec-Pfad + affected_files
- **Bekommt NICHT:** Analyse, Developer-Report

```bash
python3 .claude/hooks/workflow.py mark-adversary-verdict [VERDICT]
python3 .claude/hooks/workflow.py add-finding "<titel>" "<impact>" "<beweis>"
```

Jedes Finding via **AskUserQuestion** vorlegen.

---

## CHECKPOINT 3 — "Fertig. Darf ich committen?"

1. **Zusammenfassung:** "Feature ist fertig. [Was gebaut]"
2. **Tests:** "Alle [N] Tests gruen"
3. **Adversary-Verdict + Findings**

→ Henning gibt Freigabe ("commit", "fertig") → Fertig.

```bash
python3 .claude/hooks/workflow.py phase phase7_done
```
Git commit, GitHub Issue schliessen/kommentieren, `workflow.py complete`.

---

## Anti-Patterns (VERBOTEN!)

- **Selbst Code schreiben**
- **Agenten mit zu viel Kontext**
- **Technischen Jargon an Henning**
- **"Bitte manuell testen"**
- **Adversary ueberspringen**
- **Scope ueberschreiten** — Max 4-5 Dateien, +/-250 LoC
