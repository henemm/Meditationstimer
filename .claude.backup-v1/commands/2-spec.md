# 2-spec: Spezifikation schreiben

## ⚡ WORKFLOW STATE UPDATE (PFLICHT!)

**ZUERST** den Workflow-State setzen:
```bash
python3 .claude/hooks/update_state.py spec_written
```

---

## Phase 2: SPEC_WRITTEN

**Nur für Feature-Workflow!** (Bug-Workflow überspringt diese Phase)

---

## Feature-Workflow Übersicht

```
/1-analyse-feature  ←── Erledigt (Phase 1)
        ↓
/2-spec             ←── DU BIST HIER (Phase 2)
        ↓
   User: "Freigegeben"
        ↓
/3-implement        ←── Nächster Schritt (Phase 3)
        ↓
/4-validate         ←── Danach (Phase 4)
        ↓
/0-reset            ←── Abschluss
```

---

## Anweisung

1. **Tests definieren** in `openspec/changes/[feature-name]/tests.md`:
   - Unit Tests (GIVEN/WHEN/THEN)
   - XCUITests für UI
   - Manuelle Tests für Device

2. **Spec erstellen** in `openspec/changes/[feature-name]/`:
   - `proposal.md` - Was und Warum
   - `tasks.md` - Implementierungs-Checkliste
   - `tests.md` - Test-Definitionen

3. **Spec dem User präsentieren** und auf Approval warten

---

## State nach Approval

Wenn User "Freigegeben" / "Approved" sagt:
```bash
python3 .claude/hooks/update_state.py spec_approved --approved
```

**⛔ KEIN Code-Edit in dieser Phase!**

---

## Nächster Schritt

Nach User-Approval → `/3-implement`
