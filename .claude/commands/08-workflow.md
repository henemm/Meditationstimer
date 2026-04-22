# Workflow Management

Verwalte aktive Workflows.

## Verfügbare Befehle

```bash
# Alle Workflows anzeigen
python3 .claude/hooks/workflow.py list

# Status des aktiven Workflows
python3 .claude/hooks/workflow.py status

# Neuen Workflow starten
python3 .claude/hooks/workflow.py start "name"

# Zu anderem Workflow wechseln
python3 .claude/hooks/workflow.py switch "name"

# Phase setzen
python3 .claude/hooks/workflow.py phase phase3_spec

# Workflow abschließen und archivieren
python3 .claude/hooks/workflow.py complete
```

## 8 Phasen (Workflow v6)

| Phase | Name | Gate to enter | Gate to leave |
|-------|------|---------------|---------------|
| phase0_idle | Idle | — | /10-bug oder /11-feature |
| phase1_context | Context | — | context_file exists |
| phase2_analyse | Analysis | context_file | **Checkpoint 1** ("stimmt") |
| phase3_spec | Spec & Approval | checkpoint1 | spec_file + "approved" |
| phase4_tdd_red | TDD RED | spec_approved | RED artifacts + **Checkpoint 2** ("go") |
| phase5_implement | Implementation | checkpoint2 | Tests GREEN |
| phase6_adversary | Adversary | green_test | All findings resolved + **Checkpoint 3** ("commit") |
| phase7_done | Done | checkpoint3 | git commit |

## 3 Human Checkpoints

| # | Keyword | Wann | Was Henning sieht |
|---|---------|------|-------------------|
| 1 | "stimmt" | phase2_analyse | Root Cause + betroffene Stellen + Ansatz |
| 2 | "go" | phase4_tdd_red | Test-Namen + was geprüft + FAILED Output |
| 3 | "commit" | phase6_adversary | ALL GREEN + Adversary-Verdict + Screenshot |

## Code Modification Rules

- **phase4_tdd_red:** Nur Test-Dateien editierbar
- **phase5_implement:** Nur Source-Dateien editierbar (Tests gesperrt!)
- **Alle anderen Phasen:** Keine Code-Edits

## Nächste Schritte

- `/10-bug [Beschreibung]` — Bug-Workflow starten
- `/11-feature [Beschreibung]` — Feature-Workflow starten
- `/00-reset` — Workflow zurücksetzen
