---
entity_id: noalc-parallel-availability
type: bugfix
created: 2026-01-18
status: implemented
workflow: generic-tracker-system
---

# NoAlc Parallel Availability in Add Tracker

- [x] Approved for implementation (nachträglich dokumentiert)

## Purpose

NoAlc soll **parallel** an zwei Stellen verfügbar sein:
1. **Automatisch** im Tracker-Tab (durch Migration erstellt)
2. **Manuell** in Add Tracker als Preset

Dies ermöglicht eine Übergangsphase während der Migration zum Generic Tracker System.

## Scope

- **Files:** 2
  - `Meditationstimer iOS/Tracker/AddTrackerSheet.swift` (Filter entfernt)
  - `LeanHealthTimerUITests/LeanHealthTimerUITests.swift` (Test angepasst)
- **Actual:** -25 LoC (Filter und alter Test entfernt)

## Implementation Details

### Änderung in AddTrackerSheet.swift

```swift
// VORHER (Filter aktiv):
ForEach(TrackerManager.presets(for: .levelBased).filter { $0.name != "NoAlc" })

// NACHHER (kein Filter):
ForEach(TrackerManager.presets(for: .levelBased))
```

### Begründung

User Request: "Ich möchte dass es für eine Zeitlang parallel existiert."

Während der Übergangsphase sollen Nutzer:
- Das automatisch erstellte NoAlc im Tracker-Tab sehen
- NoAlc auch manuell hinzufügen können (für Tests, Duplikate, etc.)

## Test Plan

### Automated Tests

```swift
func testAddTrackerShowsNoAlcPreset() {
    // GIVEN: App launched, Tracker tab
    // WHEN: User opens Add Tracker sheet
    // THEN: NoAlc appears in Level-Based section alongside Mood
}
```

### Manual Tests

- [x] Add Tracker öffnen → NoAlc in "Level-Based" sichtbar
- [x] Mood ebenfalls sichtbar (nicht durch Änderung beeinträchtigt)
- [x] NoAlc-Card im Tracker-Tab weiterhin funktional

## Acceptance Criteria

- [x] NoAlc erscheint in Add Tracker → Level-Based
- [x] NoAlc-Card im Tracker-Tab unverändert (💧✨💥 Buttons)
- [x] Build erfolgreich
- [x] Committed

## Notes

**Workflow-Verstoß:** Diese Änderung wurde ohne vorherigen Workflow implementiert.
Nachträglich dokumentiert zur Vollständigkeit.

**Zukünftige Entfernung:** Wenn die Migration abgeschlossen ist, kann der NoAlc-Preset
aus Add Tracker wieder entfernt werden (Filter reaktivieren).
