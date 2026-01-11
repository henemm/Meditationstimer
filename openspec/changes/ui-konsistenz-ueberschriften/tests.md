# Tests: UI-Konsistenz Überschriften

## XCUITests

### Test 1: MeditationTab Überschrift Position

```swift
func testOpenMeditationHeaderOutsideCard() {
    // GIVEN: App gestartet, MeditationTab sichtbar
    let app = XCUIApplication()
    app.launch()
    app.tabBars.buttons["Meditation"].tap()

    // WHEN: Überschrift "Open Meditation" gesucht
    let header = app.staticTexts["Open Meditation"]

    // THEN: Überschrift existiert und ist sichtbar
    XCTAssertTrue(header.exists)
    XCTAssertTrue(header.isHittable)

    // AND: Text ist NICHT in Großbuchstaben
    // (implizit durch Matching auf "Open Meditation" statt "OPEN MEDITATION")
}
```

### Test 2: WorkoutTab Überschrift Position

```swift
func testFreeWorkoutHeaderOutsideCard() {
    // GIVEN: App gestartet, WorkoutTab sichtbar
    let app = XCUIApplication()
    app.launch()
    app.tabBars.buttons["Workout"].tap()

    // WHEN: Überschrift "Free Workout" gesucht
    let header = app.staticTexts["Free Workout"]

    // THEN: Überschrift existiert
    XCTAssertTrue(header.exists)
}
```

### Test 3: Labels nicht mehr UPPERCASE

```swift
func testLabelsNotUppercase() {
    // GIVEN: MeditationTab sichtbar
    let app = XCUIApplication()
    app.launch()
    app.tabBars.buttons["Meditation"].tap()

    // THEN: Labels sind in normaler Schreibweise
    XCTAssertTrue(app.staticTexts["Duration"].exists)
    XCTAssertTrue(app.staticTexts["Closing"].exists)

    // AND: Alte UPPERCASE-Versionen existieren NICHT
    XCTAssertFalse(app.staticTexts["DURATION"].exists)
    XCTAssertFalse(app.staticTexts["CLOSING"].exists)
}
```

## Manuelle Tests (Device)

### MT-1: Visuelle Konsistenz MeditationTab

| Schritt | Aktion | Erwartung |
|---------|--------|-----------|
| 1 | App öffnen, Meditation Tab | Tab lädt |
| 2 | Scroll nach oben | "Open Meditation (i)" Überschrift ÜBER der grauen Card sichtbar |
| 3 | Prüfe Labels | "Duration", "Closing" in normaler Schreibweise (nicht DURATION, CLOSING) |
| 4 | Scroll zu "Breathing Exercises" | Formatierung identisch zu "Open Meditation" |

### MT-2: Visuelle Konsistenz WorkoutTab

| Schritt | Aktion | Erwartung |
|---------|--------|-----------|
| 1 | Workout Tab öffnen | Tab lädt |
| 2 | Scroll nach oben | "Free Workout (i)" Überschrift ÜBER der grauen Card sichtbar |
| 3 | Prüfe Labels | "Work", "Rest", "Repetitions" in normaler Schreibweise |
| 4 | Scroll zu "Workout Programs" | Formatierung identisch zu "Free Workout" |

### MT-3: InfoButton funktioniert weiterhin

| Schritt | Aktion | Erwartung |
|---------|--------|-----------|
| 1 | Meditation Tab → (i) Button tippen | Info Sheet öffnet sich |
| 2 | Sheet schließen | Sheet schließt |
| 3 | Workout Tab → (i) Button tippen | Info Sheet öffnet sich |
| 4 | Sheet schließen | Sheet schließt |
