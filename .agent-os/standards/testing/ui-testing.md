# UI Testing Standards

## XCUITest Standards (Automated)

### Simulator-Konfiguration

**IMMER verwenden:**
```bash
xcodebuild test ... -parallel-testing-enabled NO
```

Ohne `-parallel-testing-enabled NO` erstellt xcodebuild Simulator-Klone die oft fehlschlagen mit "Simulator device failed to launch".

### Scrolling in UI Tests

**NICHT verwenden:**
```swift
sheetList.swipeUp()  // Unzuverlässig
```

**STATTDESSEN verwenden:**
```swift
app.swipeUp()  // Zuverlässiger - scrollt den gesamten Bildschirm
```

Bei langen Listen mehrfach scrollen:
```swift
for _ in 0..<5 {
    app.swipeUp()
    sleep(1)
}
```

### Sprach-Einstellungen

Die App läuft standardmäßig auf **Deutsch**. Tests müssen passende Locale setzen:
```swift
app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
```

Dann nach deutschen Texten suchen:
```swift
app.staticTexts["Stimmung"]  // NICHT "Mood"
```

### Debugging fehlschlagender Tests

**Schritt 1:** Debug-Output hinzufügen
```swift
let allTexts = app.staticTexts.allElementsBoundByIndex
print("DEBUG: Found \(allTexts.count) staticTexts:")
for (index, text) in allTexts.prefix(30).enumerated() {
    print("  [\(index)] '\(text.label)'")
}
```

**Schritt 2:** Test-Logs lesen
```bash
RESULT_PATH=$(ls -dt ~/Library/Developer/Xcode/DerivedData/*/Logs/Test/*.xcresult | head -1)
xcrun xcresulttool get --legacy --path "$RESULT_PATH" --format json | grep -i "XCTAssert"
```

---

## Manual UI Test Protocol

Henning tests on real device (iPhone/Apple Watch). Follow these rules:

## Rules for Test Sessions

1. **Go through ALL pending tests** - Don't ask "want to test more?"
2. **ONE test at a time** - Don't present all tests at once
3. **Wait for result** - Only proceed after Henning's feedback
4. **Document immediately** - Record Pass/Fail in ACTIVE-todos.md
5. **STOP on failure** - Don't continue, analyze the bug first
6. **Complete the list** - Only end when ALL tests are done

## Test Workflow

```
1. Read ACTIVE-todos.md -> collect all "Test pending" items
2. Present first test -> wait for result -> document -> next test
3. Only when list empty: "All tests completed"
```

## Test Documentation Format

In ACTIVE-todos.md:
```markdown
### Bug #XX: [Description]
- **Status:** GEFIXT (Test ausstehend)
- **Getestet:** 2025-11-25 - PASS
```

## Test Both Languages

**CRITICAL:** Every UI change must be tested in:
- German (DE) - Primary language
- English (EN) - Secondary language

## What to Test

For each UI change, verify:
1. Visual appearance matches spec
2. Interaction works as expected
3. Edge cases handled gracefully
4. No regressions in related features
5. Both portrait and landscape (if applicable)

## Preparing Test Instructions

When creating test instructions for Henning:
1. **Clear steps** - Exact sequence of actions
2. **Expected result** - What should happen
3. **Potential side effects** - Where to check for regressions
4. **Edge cases** - What unusual scenarios to try

## Example Test Instruction

```markdown
## Test: Workout REST Phase Pause Display

**Steps:**
1. Start any workout program
2. Wait for REST phase to begin
3. Tap pause button
4. Observe display

**Expected:**
- Shows "Als naechstes" (small font)
- Shows next exercise name (large font)
- NO current exercise shown (redundant)

**Edge Cases:**
- Try pausing at very start of REST
- Try pausing near end of REST

**Both Languages:** Test with DE and EN settings
```
