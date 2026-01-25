# Context: Generic Tracker Date Edit Bug

## Request Summary
Generic NoAlc Tracker ignoriert das vom User gewählte Datum im "Erweitert"-Modus. Änderungen werden immer für HEUTE gespeichert, nicht für das ausgewählte Datum.

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Tracker/LevelSelectionView.swift` | **ROOT CAUSE** - dateToLog wird berechnet aber nicht verwendet |
| `Services/TrackerManager.swift` | logEntry() fehlt timestamp-Parameter |
| `Services/TrackerModels.swift` | TrackerLog.init() hat timestamp mit Default Date() |

## Root Cause Analysis

### Problem-Stelle: LevelSelectionView.swift:201-215

```swift
@MainActor
private func logLevel(_ level: TrackerLevel, dismissImmediately: Bool) async {
    // ...

    // Zeile 207: dateToLog wird berechnet...
    let dateToLog = isExpanded ? selectedDate : Date()

    // Zeile 210-215: ...aber NICHT übergeben!
    _ = manager.logEntry(
        for: tracker,
        value: level.id,
        note: "\(level.icon) \(level.localizedLabel)",
        in: modelContext
    )  // ← FEHLER: kein timestamp!
    // ...
}
```

### Warum der Bug auftritt

1. **LevelSelectionView** berechnet `dateToLog` korrekt basierend auf `isExpanded` und `selectedDate`
2. **TrackerManager.logEntry()** hat KEINEN `timestamp`-Parameter
3. **TrackerLog.init()** verwendet `timestamp: Date = Date()` als Default
4. Ergebnis: Log wird IMMER mit aktuellem Zeitstempel erstellt

### Warum Legacy NoAlc funktioniert

Der Legacy NoAlc Tracker (`NoAlcLogSheet.swift`) schreibt direkt in HealthKit mit dem gewählten Datum via `NoAlcManager.logConsumption(date:level:)`. Der Generic Tracker nutzt SwiftData, wo der timestamp-Parameter fehlt.

## Dependencies
- **Upstream:** TrackerManager.logEntry() → TrackerLog.init()
- **Downstream:** TrackerRow Quick-Log Buttons (nutzen auch logEntry, aber immer mit Date())

## Fix Strategy

1. **TrackerManager.logEntry()** - timestamp-Parameter hinzufügen mit Default `Date()`
2. **LevelSelectionView.logLevel()** - dateToLog an logEntry übergeben
3. **Rückwärtskompatibel:** Alle anderen Aufrufe von logEntry() nutzen weiterhin Default

## Risks & Considerations
- **Risiko gering:** Neuer optionaler Parameter mit Default-Wert
- **Keine Breaking Changes:** Bestehende Aufrufe ohne timestamp funktionieren weiterhin
- **HealthKit:** Muss AUCH das custom-Datum erhalten (aktuell: log.timestamp wird verwendet - OK)
