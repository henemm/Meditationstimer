---
entity_id: noalc-card-ui-fix
type: bugfix
created: 2026-01-18
status: draft
workflow: generic-tracker-system
---

# NoAlc Card UI Fix: Emoji-Buttons mit Feedback

- [ ] Approved for implementation

## Purpose

Die NoAlc-Card zeigt aktuell Text-Buttons ("Steady", "Easy", "Wild") statt der besprochenen **anklickbaren Emojis** (💧, ✨, 💥). Außerdem fehlt visuelles Feedback nach dem Klick, und NoAlc erscheint fälschlich in der "Add Tracker" Liste obwohl es automatisch erstellt wird.

## Scope

- **Files:** 2
  - `Meditationstimer iOS/Tabs/TrackerTab.swift` (UI-Änderung)
  - `Meditationstimer iOS/Tracker/AddTrackerSheet.swift` (NoAlc entfernen)
- **Estimated:** +25/-15 LoC (~40 LoC Änderungen)

## Problem Details

### 1. Text statt Emojis (TrackerTab.swift:90)
```swift
// AKTUELL (falsch):
Text(NSLocalizedString(level.labelKey, comment: "NoAlc level"))  // → "Steady"

// SOLL:
Text(level.icon)  // → "💧"
```

### 2. Kein visuelles Feedback
- User klickt Button → nichts passiert sichtbar
- Im Hintergrund wird korrekt geloggt, aber keine Bestätigung

### 3. NoAlc in Add Tracker (AddTrackerSheet.swift)
- NoAlc wird durch Migration automatisch erstellt
- Erscheint trotzdem als Preset in "Level-Based" Kategorie
- Führt zu Verwirrung/Duplikaten

## Implementation Details

### Fix 1: Emoji-Buttons (TrackerTab.swift)

```swift
private func noAlcButton(_ level: TrackerLevel, color: Color) -> some View {
    Button(action: {
        // ... logging action ...
    }) {
        Text(level.icon)  // ← ÄNDERUNG: icon statt labelKey
            .font(.system(size: 32))  // ← Größer für Touch
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.2))
            .cornerRadius(10)
    }
    .buttonStyle(.plain)
}
```

### Fix 2: Visuelles Feedback (TrackerTab.swift)

Option A: **Kurze Animation + Checkmark**
```swift
@State private var loggedLevel: TrackerLevel? = nil

// Im Button:
.overlay {
    if loggedLevel?.id == level.id {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
            .transition(.scale.combined(with: .opacity))
    }
}
.sensoryFeedback(.success, trigger: loggedLevel)

// Nach Log:
withAnimation(.spring(duration: 0.3)) {
    loggedLevel = level
}
// Reset nach 1.5 Sekunden
DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
    withAnimation { loggedLevel = nil }
}
```

Option B: **Today's Log anzeigen** (bereits vorhanden via `noAlcTracker?.todayLog`)
```swift
// Unter den Buttons anzeigen was heute geloggt wurde
if let todayLog = noAlcTracker?.todayLog,
   let levelId = todayLog.value,
   let level = TrackerLevel.noAlcLevels.first(where: { $0.id == levelId }) {
    HStack {
        Text("Heute: \(level.icon)")
        Text(level.localizedLabel)
    }
    .font(.caption)
    .foregroundStyle(.secondary)
}
```

**Empfehlung:** Option A + B kombinieren

### Fix 3: NoAlc aus Add Tracker entfernen (AddTrackerSheet.swift)

```swift
// In levelBased Section:
Section {
    ForEach(TrackerManager.presets(for: .levelBased)
        .filter { $0.name != "NoAlc" }) { preset in  // ← Filter hinzufügen
        PresetRow(preset: preset) {
            createTracker(from: preset)
        }
    }
}
```

## Test Plan

### Automated Tests (TDD RED)

```swift
// LeanHealthTimerUITests/TrackerTabUITests.swift

func testNoAlcButtonsShowEmojis() {
    // GIVEN: App is launched, Tracker tab selected
    // WHEN: NoAlc card is visible
    // THEN: Buttons show "💧", "✨", "💥" (not "Steady", "Easy", "Wild")

    let steadyButton = app.buttons["💧"]
    let easyButton = app.buttons["✨"]
    let wildButton = app.buttons["💥"]

    XCTAssertTrue(steadyButton.exists, "Steady button should show 💧 emoji")
    XCTAssertTrue(easyButton.exists, "Easy button should show ✨ emoji")
    XCTAssertTrue(wildButton.exists, "Wild button should show 💥 emoji")
}

func testNoAlcButtonShowsFeedbackAfterTap() {
    // GIVEN: Tracker tab with NoAlc card
    // WHEN: User taps 💧 button
    // THEN: Checkmark appears briefly

    let steadyButton = app.buttons["💧"]
    steadyButton.tap()

    let checkmark = app.images["checkmark.circle.fill"]
    XCTAssertTrue(checkmark.waitForExistence(timeout: 1), "Checkmark should appear after logging")
}

func testAddTrackerDoesNotShowNoAlc() {
    // GIVEN: Tracker tab
    // WHEN: User taps "Add Tracker"
    // THEN: NoAlc preset is NOT in the list

    app.buttons["addTrackerButton"].tap()

    let noAlcPreset = app.staticTexts["NoAlc"]
    XCTAssertFalse(noAlcPreset.exists, "NoAlc should not appear in Add Tracker list")
}
```

### Manual Tests

- [ ] **Emoji-Buttons:** NoAlc zeigt 💧 ✨ 💥 statt Text
- [ ] **Feedback:** Nach Klick erscheint kurz ✓ und Haptik
- [ ] **Today's Log:** Unter Buttons steht "Heute: 💧 Steady" nach Logging
- [ ] **Add Tracker:** NoAlc erscheint NICHT in der Preset-Liste
- [ ] **Mood erscheint:** Mood (😊) ist weiterhin in Add Tracker verfügbar

## Acceptance Criteria

- [ ] NoAlc-Buttons zeigen Emojis (💧, ✨, 💥) statt Text
- [ ] Nach Klick: Visuelles Feedback (Checkmark + Haptik)
- [ ] Nach Klick: "Heute: [Emoji] [Label]" wird angezeigt
- [ ] NoAlc ist NICHT in "Add Tracker" Presets sichtbar
- [ ] Mood und andere Presets funktionieren weiterhin
- [ ] Alle bestehenden Unit Tests grün

## Design Mockup (ASCII)

```
┌─────────────────────────────────────────┐
│ 🍷 NoAlc                           ⓘ   │
│                                         │
│   ┌─────────┐ ┌─────────┐ ┌─────────┐  │
│   │   💧    │ │   ✨    │ │   💥    │  │
│   │         │ │         │ │         │  │
│   └─────────┘ └─────────┘ └─────────┘  │
│                                         │
│   Heute: 💧 Steady                      │
└─────────────────────────────────────────┘
```

Nach Klick auf 💧:
```
┌─────────┐
│   💧    │
│   ✓     │  ← Checkmark Overlay (kurz)
└─────────┘
```
