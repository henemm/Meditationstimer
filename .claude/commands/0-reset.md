# 0-reset: Workflow zurücksetzen

## ⚡ WORKFLOW STATE UPDATE

**Workflow komplett zurücksetzen:**
```bash
python3 .claude/hooks/update_state.py idle --reset
```

---

## Wann verwenden?

| Situation | Aktion |
|-----------|--------|
| ✅ Workflow erfolgreich abgeschlossen | `/0-reset` |
| ❌ Workflow abbrechen | `/0-reset` |
| 🔄 Neuen Workflow starten | `/0-reset` dann `/context` oder `/bug` |

---

## Was passiert?

1. **Phase** → `idle`
2. **Alle Flags** → zurückgesetzt
3. **History** → gelöscht

---

## Nächste Schritte

Nach Reset kannst du einen neuen Workflow starten:

```
/bug [beschreibung]     → Bug-Workflow
/context [feature-name] → Feature-Workflow
```

---

## State nach Reset

```json
{
  "current_phase": "idle",
  "workflow_type": null,
  "feature_name": null,
  "spec_file": null,
  "spec_approved": false,
  "tests_written": false,
  "tests_passing": false,
  "implementation_done": false,
  "validated": false
}
```
