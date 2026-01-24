---
entity_id: FEAT-tracker-drag-drop
type: feature
created: 2026-01-24
status: draft
workflow: tracker-drag-drop-sorting
---

# Tracker Drag & Drop Sorting

- [ ] Approved for implementation

## Purpose

Tracker im TrackerTab sollen per Drag & Drop sortierbar sein, damit der User die Reihenfolge seiner Custom Tracker selbst bestimmen kann. NoAlc bleibt als Built-in Tracker oben fixiert.

## Scope

- Files: 4
- Estimated: +80/-10 LoC

### Affected Files

| File | Change |
|------|--------|
| `Services/TrackerModels.swift` | Add `displayOrder: Int` property |
| `Meditationstimer iOS/Tabs/TrackerTab.swift` | List + onMove + EditButton |
| `LeanHealthTimerTests/TrackerModelTests.swift` | displayOrder tests |
| `LeanHealthTimerUITests/LeanHealthTimerUITests.swift` | Drag-drop UI test |

## Implementation Details

### 1. Model: Add displayOrder Property

```swift
// In Tracker class
var displayOrder: Int = 0
```

Initializer updaten mit `displayOrder: Int = 0` Parameter.

### 2. Query: Sort by displayOrder

```swift
@Query(filter: #Predicate<Tracker> { $0.isActive }, sort: \Tracker.displayOrder)
private var allTrackers: [Tracker]
```

### 3. UI: List mit onMove

```swift
// trackersSection ändern:
List {
    // NoAlc bleibt oben (nicht in ForEach, nicht sortierbar)
    noAlcCard
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)

    // Custom Trackers sind sortierbar
    ForEach(customTrackers) { tracker in
        TrackerRow(tracker: tracker) { trackerToEdit = tracker }
    }
    .onMove(perform: moveTrackers)
    .listRowSeparator(.hidden)
    .listRowBackground(Color.clear)
}
.listStyle(.plain)
.environment(\.editMode, editMode)
```

### 4. Move Handler

```swift
private func moveTrackers(from source: IndexSet, to destination: Int) {
    var trackers = customTrackers
    trackers.move(fromOffsets: source, toOffset: destination)
    for (index, tracker) in trackers.enumerated() {
        tracker.displayOrder = index
    }
    try? modelContext.save()
}
```

### 5. EditButton in Toolbar

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        if customTrackers.count > 1 {
            EditButton()
        }
    }
}
```

### 6. Migration für bestehende Tracker

Beim App-Start: Falls `displayOrder == 0` für alle Tracker, Order nach `createdAt` setzen:

```swift
// In TrackerMigration oder App-Init
let trackers = allTrackers.sorted { $0.createdAt < $1.createdAt }
for (index, tracker) in trackers.enumerated() {
    if tracker.displayOrder == 0 {
        tracker.displayOrder = index + 1
    }
}
```

## Test Plan

### Automated Tests (TDD RED)

- [ ] `testTrackerHasDisplayOrderProperty`: GIVEN Tracker WHEN created THEN displayOrder defaults to 0
- [ ] `testTrackerListShowsEditButton`: GIVEN >1 custom trackers WHEN TrackerTab loads THEN EditButton visible
- [ ] `testTrackerReorderUpdatesDisplayOrder`: GIVEN 3 trackers WHEN moved THEN displayOrder updated

### UI Tests

- [ ] `testTrackerTabShowsEditButtonWithMultipleTrackers`: Verify EditButton erscheint
- [ ] `testTrackerReorderingWorks`: Enter edit mode, verify reorder handles visible

## Acceptance Criteria

- [ ] Custom Tracker können per Drag & Drop sortiert werden
- [ ] NoAlc-Card bleibt immer oben (nicht sortierbar)
- [ ] Sortierung wird persistent gespeichert
- [ ] EditButton erscheint nur bei >1 Custom Tracker
- [ ] Bestehende Tracker erhalten automatisch eine Order (nach Erstellungsdatum)
