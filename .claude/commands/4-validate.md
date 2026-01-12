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

## ⚠️ ALLE TESTS SIND PFLICHT!

**Validierung ist NICHT abgeschlossen ohne:**
1. ✅ Unit Tests GRÜN
2. ✅ XCUITests GRÜN (im Simulator!)
3. ✅ Release Build erfolgreich
4. ✅ Device-Test NUR für Audio/Haptics (was Simulator nicht kann)

**XCUITests ersetzen manuelle Test-Checklisten!**

---

## Validierungs-Schritte

### 1. Unit Tests ausführen (PFLICHT)

```bash
xcodebuild test \
  -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:LeanHealthTimerTests \
  2>&1 | grep -E "(Test Case|passed|failed|error:)"
```

### 2. XCUITests ausführen (PFLICHT!)

```bash
xcodebuild test \
  -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:LeanHealthTimerUITests \
  2>&1 | grep -E "(Test Case|passed|failed|error:)"
```

**⛔ KEIN Überspringen! XCUITests MÜSSEN laufen und GRÜN sein!**

### 3. Release Build

```bash
xcodebuild -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

---

## Ergebnis-Handling

### ✅ Alle Tests grün (Unit + XCUITests)

```bash
python3 .claude/hooks/update_state.py validating --tests-passing --validated
```

Dann:
1. **ACTIVE-todos.md aktualisieren**
2. **Commit erstellen**
3. **Device-Test NUR für:** Audio-Ausgabe, Haptics, Watch-Sync

### ❌ Tests fehlgeschlagen

Zurück zu Phase 3:
```bash
python3 .claude/hooks/update_state.py implementing
```

→ `/3-implement` erneut aufrufen und fixen!

---

## Was gehört in XCUITests vs. Device-Test?

| Test-Typ | XCUITest (Simulator) | Device-Test (Henning) |
|----------|---------------------|----------------------|
| UI Layout | ✅ PFLICHT | ❌ |
| Navigation | ✅ PFLICHT | ❌ |
| Button-Taps | ✅ PFLICHT | ❌ |
| Timer-Start/Stop | ✅ PFLICHT | ❌ |
| Workout-Ablauf | ✅ PFLICHT | ❌ |
| Voice/TTS Output | ❌ | ✅ PFLICHT |
| Haptic Feedback | ❌ | ✅ PFLICHT |
| HealthKit Sync | ❌ | ✅ PFLICHT |
| Watch Connectivity | ❌ | ✅ PFLICHT |

---

## Nächster Schritt

Nach ALLEN Tests grün → `/0-reset`
