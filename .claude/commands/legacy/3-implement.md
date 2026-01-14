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

## ⚠️ XCUITESTS SIND PFLICHT!

**Bei JEDER UI-Änderung MÜSSEN XCUITests geschrieben werden!**

| Änderungstyp | Test-Pflicht |
|--------------|--------------|
| UI-Änderung (Views, Layout) | XCUITest PFLICHT |
| Business Logic | Unit Test PFLICHT |
| Voice/Audio | XCUITest für Workflow + manueller Device-Test |

**KEIN Feature ist fertig ohne:**
1. Unit Tests für Logic (TDD RED → GREEN)
2. XCUITests für UI-Verhalten (im Simulator ausführen!)
3. Device-Test NUR für Dinge die Simulator nicht kann (Audio, Haptics)

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
3. **XCUITests schreiben die das Feature testen!**
4. Bei jedem sinnvollen Zwischenstand: **Commit**
5. Jeder Commit muss **compilieren**

---

## Nach Implementierung

1. **Build prüfen:**
   ```bash
   xcodebuild -project Meditationstimer.xcodeproj \
     -scheme "Lean Health Timer" \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
     build
   ```

2. **XCUITests ausführen (PFLICHT!):**
   ```bash
   xcodebuild test \
     -project Meditationstimer.xcodeproj \
     -scheme "Lean Health Timer" \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
     -only-testing:LeanHealthTimerUITests
   ```

3. **State aktualisieren:**
   ```bash
   python3 .claude/hooks/update_state.py implementing --implemented
   ```

---

## Nächster Schritt

Nach erfolgreichem Build UND XCUITests → `/4-validate`
