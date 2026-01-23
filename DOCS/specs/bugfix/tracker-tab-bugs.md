---
entity_id: tracker-tab-bugs
type: bugfix
created: 2026-01-23
status: implemented
workflow: tracker-tab-bugs
---

# TrackerTab UI Bugs: Scroll-Wabbeln & Level-Tracker Layout

- [x] Approved for implementation
- [x] Implemented (2026-01-23)

## Purpose

Drei UI-Bugs im TrackerTab beheben:
1. **Scroll-Wabbeln:** Die Seite wabbelt horizontal beim vertikalen Scrollen
2. **Icons zu klein:** Level-Tracker haben kleine, gequetschte Icons
3. **Datum fehlt:** Keine Möglichkeit, für ein anderes Datum zu loggen

**Warum:** Das aktuelle TrackerRow-Layout ist dem NoAlc-Card unterlegen. Für eine konsistente UX sollten alle Level-Tracker das gleiche großzügige Layout haben.

## Scope

| File | Change Type | LoC | Description |
|------|-------------|-----|-------------|
| `Meditationstimer iOS/Tabs/TrackerTab.swift` | MODIFY | +3 | ScrollView axis fix |
| `Meditationstimer iOS/Tracker/TrackerRow.swift` | MODIFY | +35/-5 | Level-based layout |

**Total:** 2 Files, ~+33 LoC net
**Risk Level:** LOW

## Implementation Details

### Bug 1: ScrollView Wabbeln

**Problem:** `ScrollView` ohne explizite Achse (Zeile 76)

**Fix:**
```swift
// TrackerTab.swift:76
ScrollView(.vertical, showsIndicators: false) {
    // ...
}
.scrollBounceBehavior(.basedOnSize)
```

### Bug 2a + 2b: Level-Tracker Layout & Datums-Button

**Problem:** TrackerRow packt alles in eine HStack, Level-Buttons sind gequetscht.

**Fix:** Neues `levelBasedLayout` für Level-Tracker (VStack wie noAlcCard):

```swift
@ViewBuilder
private var levelBasedLayout: some View {
    VStack(spacing: 12) {
        // Zeile 1: Header (Icon, Name, Streak, Buttons)
        HStack {
            Text(tracker.icon)
                .font(.system(size: 28))
            Text(tracker.name)
                .font(.headline)
            streakBadge
            Spacer()

            // NEU: Kalender-Button für Datums-Auswahl
            Button(action: { showingLevelSheet = true }) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("trackerDateButton")

            // Edit-Button
            Button(action: onEdit) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
        }

        // Zeile 2: Level-Buttons (volle Breite, 32px Icons)
        HStack(spacing: 10) {
            ForEach(trackerLevels) { level in
                levelButtonLarge(level)
            }
        }

        // Zeile 3: Today's Status
        levelStatusView
    }
    .padding(.vertical, 4)
}

// Größere Level-Buttons (wie noAlcCard)
private func levelButtonLarge(_ level: TrackerLevel) -> some View {
    Button(action: { Task { await logLevel(level) } }) {
        Text(level.icon)
            .font(.system(size: 32))  // Statt 24-28
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(levelColor(for: level).opacity(0.2))
            .cornerRadius(10)
            .overlay { /* checkmark feedback */ }
    }
    .buttonStyle(.plain)
}
```

**body Änderung:**
```swift
var body: some View {
    GlassCard {
        if isLevelBased {
            levelBasedLayout
        } else {
            legacyLayout  // Bestehende HStack für Counter/YesNo/etc.
        }
    }
    // sheets...
}
```

## Test Plan

### Automated Tests (Unit Tests)

Da es sich um reine UI-Layout-Änderungen handelt, sind keine Unit Tests nötig. Die bestehenden TrackerModelTests bleiben unverändert.

### XCUITests

- [ ] **Test 1: Level-Tracker zeigt große Icons**
  - GIVEN: Ein Level-Tracker (z.B. NoAlc) existiert
  - WHEN: TrackerTab wird angezeigt
  - THEN: Level-Buttons sind sichtbar mit 32px Icons
  - THEN: `calendar.badge.plus` Button existiert

- [ ] **Test 2: Datums-Button öffnet LevelSelectionView**
  - GIVEN: Ein Level-Tracker wird angezeigt
  - WHEN: User tippt auf `calendar.badge.plus`
  - THEN: LevelSelectionView Sheet öffnet sich
  - THEN: "Advanced" Button für DatePicker ist sichtbar

### Manuelle Tests

- [ ] **Manual 1: Kein Wabbeln beim Scrollen**
  - Öffne TrackerTab
  - Scrolle vertikal durch die Tracker-Liste
  - Verifiziere: Kein horizontales Wabbeln/Wackeln

- [ ] **Manual 2: Level-Icons Größenvergleich**
  - Öffne TrackerTab
  - Vergleiche NoAlc-Card mit generischem Level-Tracker
  - Verifiziere: Icons haben gleiche Größe (32px)
  - Verifiziere: Buttons nehmen volle Breite ein

- [ ] **Manual 3: Datums-Auswahl funktioniert**
  - Tippe auf Kalender-Icon bei Level-Tracker
  - Tippe "Advanced" im Sheet
  - Wähle ein vergangenes Datum
  - Logge einen Level
  - Verifiziere: Eintrag wird für gewähltes Datum gespeichert

## Acceptance Criteria

### Funktional
- [ ] **AC1:** ScrollView wabbelt nicht mehr horizontal
- [ ] **AC2:** Level-Tracker Icons sind 32px (wie NoAlc-Card)
- [ ] **AC3:** Level-Buttons sind in eigener Zeile (volle Breite)
- [ ] **AC4:** Kalender-Button (`calendar.badge.plus`) existiert
- [ ] **AC5:** Kalender-Button öffnet LevelSelectionView
- [ ] **AC6:** Über LevelSelectionView kann für anderes Datum geloggt werden

### Nicht-Funktional
- [ ] **AC7:** Build erfolgreich (keine Warnings)
- [ ] **AC8:** Bestehende Tests grün
- [ ] **AC9:** Konsistentes Layout mit NoAlc-Card

## Risiken

1. **Layout für andere TrackingModes:** Das `legacyLayout` bleibt für Counter, YesNo, Awareness, Avoidance unverändert - kein Risiko.
2. **LevelSelectionView:** Existiert bereits mit DatePicker - wird nur aufgerufen, keine Änderung nötig.

## Abhängigkeiten

- [x] `LevelSelectionView` - existiert, hat Advanced-Modus mit DatePicker
- [x] `GlassCard` - unverändert
- [x] `TrackerLevel` - unverändert
