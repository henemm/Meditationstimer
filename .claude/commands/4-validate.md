# 4-validate: Tests & Verifizierung

## ⚡ WORKFLOW STATE UPDATE (PFLICHT!)

**ZUERST** den Workflow-State setzen:
```bash
python3 .claude/hooks/update_state.py validating
```

---

## Phase 4: VALIDATING

**Tests ausführen und Implementierung verifizieren.**

---

## Workflow-Übersicht

```
/1-analyse-*        ←── Erledigt (Phase 1)
        ↓
/2-spec             ←── Erledigt (nur Feature)
        ↓
/3-implement        ←── Erledigt (Phase 3)
        ↓
/4-validate         ←── DU BIST HIER (Phase 4)
        ↓
/0-reset            ←── Nächster Schritt (Abschluss)
```

---

## Validierungs-Schritte

### 1. Unit Tests ausführen

```bash
xcodebuild test \
  -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:LeanHealthTimerTests \
  2>&1 | grep -E "(Test Case|passed|failed|error:)"
```

### 2. UI Tests ausführen (falls vorhanden)

```bash
xcodebuild test \
  -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:LeanHealthTimerUITests \
  2>&1 | grep -E "(Test Case|passed|failed|error:)"
```

### 3. Release Build

```bash
xcodebuild -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build
```

---

## Ergebnis-Handling

### ✅ Alle Tests grün

```bash
python3 .claude/hooks/update_state.py validating --tests-passing --validated
```

Dann:
1. **ACTIVE-todos.md aktualisieren**
2. **Commit erstellen**
3. **Test-Anweisungen für Henning** (Device-Test)

### ❌ Tests fehlgeschlagen

Zurück zu Phase 3:
```bash
python3 .claude/hooks/update_state.py implementing
```

→ `/3-implement` erneut aufrufen und fixen!

---

## Nächster Schritt

Nach erfolgreichem Device-Test → `/0-reset`
