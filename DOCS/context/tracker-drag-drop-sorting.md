# Context: Tracker Drag & Drop Sorting

## Request Summary

Tracker im TrackerTab sollen per Drag & Drop sortierbar sein, damit der User die Reihenfolge selbst bestimmen kann.

## Related Files

| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Tabs/TrackerTab.swift:21` | `@Query(sort: \Tracker.createdAt)` - aktuelle Sortierung |
| `Meditationstimer iOS/Tabs/TrackerTab.swift:203-207` | `ForEach(customTrackers)` - zeigt Tracker an |
| `Services/TrackerModels.swift:199-280` | `Tracker` Model - braucht `displayOrder` Property |
| `Meditationstimer iOS/Tracker/TrackerRow.swift` | Row-Komponente die verschoben werden soll |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:1774` | Bestehendes Pattern mit `.onMove` |

## Current State

1. **Sortierung:** Tracker werden nach `createdAt` sortiert (Erstellungsdatum)
2. **UI-Struktur:** `ScrollView` mit `ForEach`, nicht `List`
3. **Model:** `Tracker` hat `widgetOrder: Int` für Widget, aber kein `displayOrder`

## Existing Patterns

### Pattern 1: List mit .onMove (WorkoutProgramsView)
```swift
List {
    ForEach(items) { item in ... }
        .onMove { from, to in
            items.move(fromOffsets: from, toOffset: to)
        }
}
```

### Pattern 2: ScrollView mit ForEach (aktuelle TrackerTab)
```swift
ScrollView(.vertical) {
    VStack(spacing: 20) {
        ForEach(customTrackers) { tracker in
            TrackerRow(tracker: tracker) { ... }
        }
    }
}
```

## Dependencies

- **Upstream:** SwiftData `@Query`, SwiftUI List/ForEach
- **Downstream:** TrackerRow (keine Änderung nötig), Widget (hat eigene `widgetOrder`)

## Implementation Options

### Option A: List mit .onMove (Empfohlen)
- TrackerTab auf `List` umstellen
- `.onMove` Modifier hinzufügen
- Einfachste Lösung, native iOS-Behavior

### Option B: Custom Drag & Drop in ScrollView
- `draggable()` und `dropDestination()` Modifier
- Mehr Code, aber behält aktuelles Layout exakt bei

### Option C: Edit-Modus mit Reorder-Buttons
- Kein echtes Drag & Drop
- Stattdessen ↑/↓ Buttons im Edit-Modus

## Required Changes

1. **Model:** `displayOrder: Int` Property zu `Tracker` hinzufügen
2. **Query:** Sort ändern zu `\Tracker.displayOrder`
3. **UI:** Entweder `List` mit `.onMove` oder custom drag-and-drop
4. **Persistenz:** Order in SwiftData speichern nach Move

## Risks & Considerations

1. **NoAlc-Sonderfall:** NoAlc-Card ist oben fixiert, soll sie sortierbar sein?
2. **Migration:** Bestehende Tracker brauchen Default-Order (z.B. basierend auf `createdAt`)
3. **List vs ScrollView:** List hat andere Styling-Defaults als aktueller Look
4. **Performance:** Bei vielen Trackern könnte Reordering langsam werden

## Estimated Effort

**Small-Medium** - ~100-150 LoC
- Model ändern: 10 LoC
- Query ändern: 5 LoC
- UI implementieren: 50-100 LoC
- Migration: 20 LoC

---

## Analysis (Phase 2)

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `Services/TrackerModels.swift` | MODIFY | Add `displayOrder: Int` property to Tracker |
| `Meditationstimer iOS/Tabs/TrackerTab.swift` | MODIFY | Add drag-drop UI, change Query sort |
| `LeanHealthTimerTests/TrackerModelTests.swift` | MODIFY | Add displayOrder tests |
| `LeanHealthTimerUITests/LeanHealthTimerUITests.swift` | MODIFY | Add drag-drop UI test |

### Scope Assessment
- Files: 4
- Estimated LoC: +80/-10
- Risk Level: LOW (keine Breaking Changes)

### Technical Approach

**Empfehlung: List mit .onMove + EditButton**

1. **Model-Änderung:**
   ```swift
   var displayOrder: Int = 0  // Default 0, wird bei Add Tracker inkrementiert
   ```

2. **Query-Änderung:**
   ```swift
   @Query(filter: #Predicate<Tracker> { $0.isActive }, sort: \Tracker.displayOrder)
   ```

3. **UI-Änderung:**
   - `ScrollView` → `List` Umstellung
   - `.onMove` Modifier hinzufügen
   - `EditButton()` in Toolbar für Edit-Modus
   - Styling anpassen (`.listRowBackground`, `.listStyle(.plain)`)

4. **Move-Handler:**
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

### Design-Entscheidung

**NoAlc bleibt oben fixiert** (nicht sortierbar):
- NoAlc ist ein "Built-in" Tracker mit eigener Card
- User-erstellte Tracker sind darunter sortierbar
- Konsistent mit aktueller UI-Logik

### Open Questions
- [x] Soll NoAlc sortierbar sein? → Nein, bleibt oben fixiert
- [ ] Soll der Edit-Button nur bei >1 Tracker erscheinen?
