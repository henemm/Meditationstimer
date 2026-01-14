# TDD (Test-Driven Development) Standard

## Grundprinzip: Red-Green-Refactor

TDD ist **PFLICHT** bei allen Features und Änderungen. Keine Ausnahmen.

```
┌─────────────────────────────────────────────────────────────┐
│                    RED-GREEN-REFACTOR                        │
│                                                              │
│   ┌───────┐      ┌───────┐      ┌──────────┐                │
│   │  RED  │ ──► │ GREEN │ ──► │ REFACTOR │ ──► (repeat)    │
│   └───────┘      └───────┘      └──────────┘                │
│                                                              │
│   1. RED:      Test schreiben, der FEHLSCHLÄGT              │
│   2. GREEN:    Minimalen Code schreiben, Test BESTEHT       │
│   3. REFACTOR: Code verbessern, Tests bleiben GRÜN          │
└─────────────────────────────────────────────────────────────┘
```

## Warum Test-FIRST?

| Ohne TDD | Mit TDD |
|----------|---------|
| "Hoffnungs-Tests" die immer grün sind | Tests prüfen echtes Verhalten |
| Tests passen sich dem Code an | Code passt sich den Tests an |
| Bugs werden später entdeckt | Bugs werden sofort entdeckt |
| Unklare Anforderungen | Anforderungen als Tests definiert |

## Workflow für Features

### Phase 1: RED (Test schreiben)

**BEVOR du Code implementierst:**

1. **Unit Tests** (für Business-Logik):
   ```swift
   func testPickerShowsDauerLabelInGerman() throws {
       // GIVEN
       let locale = Locale(identifier: "de")

       // WHEN
       let label = NSLocalizedString("Duration", comment: "")

       // THEN
       XCTAssertEqual(label, "Dauer")
   }
   ```

2. **XCUITests** (für UI):
   ```swift
   func testOffenViewShowsCorrectPickerLabels() throws {
       // GIVEN
       let app = XCUIApplication()
       app.launchArguments = ["-AppleLanguages", "(de)"]
       app.launch()

       // WHEN
       app.tabBars.buttons["Offen"].tap()

       // THEN
       XCTAssertTrue(app.staticTexts["DAUER"].exists)
       XCTAssertTrue(app.staticTexts["AUSKLANG"].exists)
   }
   ```

3. **Test ausführen → MUSS FEHLSCHLAGEN**
   ```bash
   xcodebuild test -scheme "Lean Health Timer" \
     -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
     -only-testing:LeanHealthTimerUITests
   ```

⛔ **BLOCKER:** Wenn der Test NICHT fehlschlägt, ist er wertlos!

### Phase 2: GREEN (Implementieren)

1. **Minimalen Code schreiben** um Test zu bestehen
2. **Keine Extra-Features** - nur was der Test verlangt
3. **Test erneut ausführen → MUSS BESTEHEN**

```bash
xcodebuild test ... # Jetzt sollte es grün sein
```

⛔ **BLOCKER:** Erst wenn alle Tests grün sind, zum nächsten Schritt

### Phase 3: REFACTOR (Optional)

1. Code aufräumen ohne Funktionsänderung
2. Tests bleiben grün
3. Bei Rot → Änderungen rückgängig machen

## Test-Kategorien

### 1. Unit Tests (LeanHealthTimerTests)

- Für: Business-Logik, Manager, Services
- Schnell, isoliert, ohne UI
- Beispiele:
  - StreakManager-Berechnungen
  - Timer-Logik
  - HealthKit-Datenverarbeitung

### 2. UI Tests (LeanHealthTimerUITests)

- Für: SwiftUI Views, User Flows, Localization
- Brauchen Simulator
- Beispiele:
  - Picker-Labels sind korrekt
  - Navigation funktioniert
  - Buttons sind interaktiv

### 3. Manuelle Tests (Henning)

- Für: Real-Device-spezifisches
- HealthKit-Integration
- Watch Connectivity
- Audio-Ausgabe (Gongs)

## Wann welcher Test?

```
┌─────────────────────────────────────────────────────┐
│ Änderung betrifft...              │ Test-Typ        │
├───────────────────────────────────┼─────────────────┤
│ Reine Logik (kein UI)             │ Unit Test       │
│ UI-Darstellung                    │ XCUITest        │
│ Lokalisierung (Texte)             │ XCUITest + Unit │
│ HealthKit/Watch/Audio             │ Manuell         │
│ Komplexer User-Flow               │ XCUITest        │
└─────────────────────────────────────────────────────┘
```

## Anti-Patterns

❌ **Test NACH Implementation** → Test prüft nur was da ist
❌ **Grüner Test ohne Rot** → Test beweist nichts
❌ **Tests überspringen** → Bugs werden vom User gefunden
❌ **Nur "Happy Path"** → Edge Cases fehlen
❌ **Flaky Tests ignorieren** → False Confidence

## Checklist vor Implementation

- [ ] Acceptance Criteria als Tests formuliert
- [ ] Tests geschrieben (Unit + UI wo nötig)
- [ ] Tests ausgeführt und ROT bestätigt
- [ ] Erst DANN mit Implementation beginnen

## Commit-Strategie bei TDD

```
1. feat(test): Add failing tests for label rename
   → Tests sind ROT

2. feat: Rename picker labels Dauer/Ausklang
   → Tests sind GRÜN

3. refactor: Improve label readability (optional)
   → Tests bleiben GRÜN
```
