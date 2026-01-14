# 1-analyse-feature: Feature-Analyse starten

## ⚡ WORKFLOW STATE UPDATE (PFLICHT!)

**ZUERST** den Workflow-State setzen:
```bash
python3 .claude/hooks/update_state.py analysing --type feature --feature "$ARGUMENTS"
```

---

## Phase 1: ANALYSING (Feature)

Starte den `feature-planner` Agenten aus `.agent-os/agents/feature-planner.md`.

**Anfrage:** $ARGUMENTS

---

## Feature-Workflow Übersicht

```
/1-analyse-feature  ←── DU BIST HIER (Phase 1)
        ↓
   Anforderungen verstehen
        ↓
/2-spec             ←── Nächster Schritt (Phase 2)
        ↓
   User: "Freigegeben"
        ↓
/3-implement        ←── Danach (Phase 3)
        ↓
/4-validate         ←── Danach (Phase 4)
        ↓
/0-reset            ←── Abschluss
```

---

## Modus erkennen

| Formulierung | Modus |
|--------------|-------|
| "Neues Feature...", "Füge hinzu...", "Implementiere..." | **NEU** |
| "Änderung an...", "Passe an...", "Erweitere...", "Modifiziere..." | **ÄNDERUNG** |

**Befolge den Workflow aus `.agent-os/workflows/feature-workflow.md`**

**Injizierte Standards:**
- `.agent-os/standards/global/analysis-first.md`
- `.agent-os/standards/global/scoping-limits.md`
- `.agent-os/standards/global/documentation-rules.md`
- `.agent-os/standards/swiftui/state-management.md`

---

## Anweisung

1. **Modus bestimmen:** NEU oder ÄNDERUNG?
2. Feature-Intent verstehen (WAS, WARUM, Kategorie)
3. **Bei ÄNDERUNG:** Aktuellen Zustand dokumentieren, Delta identifizieren
4. Bestehende Systeme prüfen (KRITISCH!)
5. Scoping (Max 4-5 Dateien, +/-250 LoC)

**⛔ KEIN Code-Edit in dieser Phase!**

---

## Nächster Schritt

Nach Analyse abgeschlossen → `/2-spec`
