# Workflow Reset

Setzt den aktuellen Workflow zurück oder schließt ihn ab.

## Workflow abschließen (normal)

```bash
python3 .claude/hooks/workflow.py complete
```

## Wenn kein Workflow aktiv

```bash
python3 .claude/hooks/workflow.py list
```

## Neuen Workflow starten

```bash
python3 .claude/hooks/workflow.py start "neuer-workflow-name"
```

## Nächste Schritte

- `/10-bug [Beschreibung]` — Bug analysieren
- `/11-feature [Beschreibung]` — Feature planen
