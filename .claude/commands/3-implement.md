# 3-implement: Code schreiben

## ⚡ WORKFLOW STATE UPDATE (PFLICHT!)

**ZUERST** den Workflow-State setzen:
```bash
python3 .claude/hooks/update_state.py implementing --approved
```

---

## Phase 3: IMPLEMENTING

**✅ Ab jetzt sind Code-Änderungen (Edit/Write auf .swift) ERLAUBT!**

---

## Workflow-Übersicht

```
Bug-Workflow:
/1-analyse-bug      ←── Erledigt
        ↓
/3-implement        ←── DU BIST HIER (Phase 3)
        ↓
/4-validate         ←── Nächster Schritt (Phase 4)

Feature-Workflow:
/1-analyse-feature  ←── Erledigt
        ↓
/2-spec             ←── Erledigt
        ↓
/3-implement        ←── DU BIST HIER (Phase 3)
        ↓
/4-validate         ←── Nächster Schritt (Phase 4)
```

---

## Voraussetzungen prüfen

| Check | Status |
|-------|--------|
| ⛔ Analyse abgeschlossen? | Muss erfüllt sein |
| ⛔ Root Cause / Spec klar? | Muss erfüllt sein |
| ⛔ User hat freigegeben? | Muss erfüllt sein |
| ⛔ Tests definiert? | Muss erfüllt sein (TDD!) |

---

## Implementierungs-Regeln

**Constraints (aus Scoping-Limits):**
- Max **4-5 Dateien** ändern
- Max **±250 LoC** insgesamt
- Funktionen **≤50 LoC**
- **Keine Side-Effects** außerhalb des Tickets

**Vorgehen:**
1. Lies die Spec / Root Cause Analyse nochmal
2. Implementiere **exakt** das Geplante (keine Extras!)
3. Bei jedem sinnvollen Zwischenstand: **Commit**
4. Jeder Commit muss **compilieren**

---

## Nach Implementierung

1. **Build prüfen:**
   ```bash
   xcodebuild -project Meditationstimer.xcodeproj \
     -scheme "Lean Health Timer" \
     -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
     build
   ```

2. **State aktualisieren:**
   ```bash
   python3 .claude/hooks/update_state.py implementing --implemented
   ```

---

## Nächster Schritt

Nach erfolgreichem Build → `/4-validate`
