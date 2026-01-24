# Context: FEAT-37d HealthKit-Integration für Generic Tracker System

## Request Summary

Statt NoAlcManager zu löschen, soll das Generic Tracker System HealthKit-Integration unterstützen. Tracker mit `saveToHealthKit: true` sollen ihre Daten sowohl in SwiftData als auch in HealthKit speichern.

## Related Files

| File | Relevance |
|------|-----------|
| `Services/TrackerManager.swift` | ❌ Hat KEINE HealthKit-Integration - muss erweitert werden |
| `Services/TrackerModels.swift` | ✅ Hat bereits `healthKitType`, `saveToHealthKit`, `StorageStrategy` |
| `Services/NoAlcManager.swift` | 🔄 Hat HealthKit-Logik die übernommen werden soll |
| `Services/HealthKitManager.swift` | ✅ Existiert, hat aber keine Alcohol-Methoden |
| `Meditationstimer iOS/Tabs/TrackerTab.swift` | 🔄 Hat Dual-Write (SwiftData + NoAlcManager) |

## Kernproblem

```
TrackerModels.swift:
  Tracker {
    healthKitType: String?    // ✅ Definiert
    saveToHealthKit: Bool     // ✅ Definiert
  }

TrackerManager.swift:
  logEntry() {
    context.insert(log)       // ✅ SwiftData
    // ❌ FEHLT: HealthKit-Write wenn saveToHealthKit == true
  }
```

## Existing Patterns

### NoAlcManager HealthKit-Logik (zu übernehmen):
```swift
// 1. HealthKit-Typ
HKQuantityType(.numberOfAlcoholicBeverages)

// 2. Speichern
let quantity = HKQuantity(unit: .count(), doubleValue: Double(level.healthKitValue))
let sample = HKQuantitySample(type: alcoholType, quantity: quantity, start: date, end: date)
healthStore.save(sample)

// 3. Lesen
HKSampleQuery mit Predicate für Datum
```

### TrackerPreset NoAlc:
```swift
TrackerPreset(
    id: "noalc",
    healthKitType: "HKQuantityTypeIdentifierNumberOfAlcoholicBeverages",
    levels: TrackerLevel.noAlcLevels,  // id: 0, 1, 2
    ...
)
```

### Mapping NoAlcManager.ConsumptionLevel → TrackerLevel:
| ConsumptionLevel | rawValue | TrackerLevel.id |
|------------------|----------|-----------------|
| .steady | 0 | 0 |
| .easy | 4 | 1 |
| .wild | 6 | 2 |

**Achtung:** HealthKit-Werte (0, 4, 6) ≠ TrackerLevel.id (0, 1, 2)!

## Dependencies

**Upstream (was TrackerManager nutzt):**
- SwiftData (ModelContext)
- TrackerModels (Tracker, TrackerLog)

**Downstream (was TrackerManager nutzt):**
- TrackerTab.swift
- LevelSelectionView.swift
- TrackerHistorySheet.swift

## Existing Specs

- `DOCS/specs/features/generic-tracker-system.md` - Main spec
- `DOCS/specs/features/generic-tracker-system-implementation.md` - Implementation details

## Risks & Considerations

1. **Value Mapping:** HealthKit-Werte (0, 4, 6) müssen zu TrackerLevel.id (0, 1, 2) gemappt werden
2. **Day Assignment:** 18-Uhr Cutoff muss auch für HealthKit-Writes gelten
3. **Dual-Write entfernen:** TrackerTab macht aktuell beides - nur noch einmal loggen
4. **CalendarView Datenquelle:** Liest noch von NoAlcManager.fetchConsumption()
5. **Migration:** Bestehende HealthKit-Daten müssen weiter lesbar sein

## Lösungsansatz

### Option A: TrackerManager erweitern
```swift
func logEntry(for tracker:, value:, ...) {
    // 1. SwiftData wie bisher
    context.insert(log)

    // 2. NEU: HealthKit wenn konfiguriert
    if tracker.saveToHealthKit, let hkType = tracker.healthKitType {
        await saveToHealthKit(value, type: hkType, date: log.timestamp)
    }
}
```

### Option B: NoAlcManager als HealthKit-Adapter behalten
- NoAlcManager bleibt für HealthKit I/O
- TrackerManager ruft NoAlcManager für HK-Operationen auf
- Weniger Refactoring, aber mehr Indirektion

**Empfehlung:** Option A (sauberere Architektur)

## Scope-Schätzung

| Änderung | LoC |
|----------|-----|
| TrackerManager: HealthKit-Write hinzufügen | ~40 |
| TrackerManager: HealthKit-Read hinzufügen | ~30 |
| TrackerTab: Dual-Write entfernen | -15 |
| Meditationstimer_iOSApp: Shortcuts anpassen | ~10 |
| **Gesamt** | ~65 LoC |

NoAlcManager wird **nicht gelöscht** - bleibt als Fallback für:
- CalendarView Datenquelle (bis FEAT-37b komplett)
- Historische HealthKit-Daten lesen

---

## Analysis (Phase 2)

### Betroffene Dateien (mit Änderungen)

| File | Change Type | Description |
|------|-------------|-------------|
| `Services/TrackerManager.swift` | MODIFY | HealthKit-Write in logEntry() hinzufügen |
| `Meditationstimer iOS/Tabs/TrackerTab.swift` | MODIFY | Dual-Write entfernen (Zeile 94-104) |
| `Services/TrackerModels.swift` | MODIFY | HealthKit-Value Mapping für TrackerLevel |

### Dual-Write Problem (TrackerTab.swift:94-104)

```swift
// AKTUELL: Zwei separate Writes
tracker.logLevel(level, in: modelContext)  // → SwiftData
NoAlcManager.shared.logConsumption(...)    // → HealthKit

// ZIEL: Ein Write, TrackerManager macht beides
tracker.logLevel(level, in: modelContext)  // → SwiftData + HealthKit
```

### HealthKit Value Mapping

TrackerLevel.id ≠ HealthKit-Wert für NoAlc:

| TrackerLevel | id | HealthKit-Wert | Bedeutung |
|--------------|-----|----------------|-----------|
| steady | 0 | 0 | 0-1 Drinks |
| easy | 1 | 4 | 2-5 Drinks |
| wild | 2 | 6 | 6+ Drinks |

**Lösung:** TrackerLevel braucht `healthKitValue: Int?` Property

### Scope Assessment

- **Files:** 3
- **Estimated LoC:** +50 / -15
- **Risk Level:** MEDIUM (HealthKit-Integration kann fehlschlagen)

### Technischer Ansatz

1. **TrackerLevel erweitern:**
   ```swift
   var healthKitValue: Int? { ... }  // Mapping für NoAlc
   ```

2. **TrackerManager.logEntry() erweitern:**
   ```swift
   // Nach SwiftData-Insert:
   if tracker.saveToHealthKit {
       Task { await saveToHealthKit(tracker, value, date) }
   }
   ```

3. **TrackerTab Dual-Write entfernen:**
   - Zeilen 94-104 löschen
   - Nur noch `tracker.logLevel()` aufrufen

### Open Questions

- [x] Wo wird HealthKit-Value Mapping definiert? → In TrackerLevel
- [x] Wie wird Day Assignment für HealthKit gehandhabt? → Via `tracker.effectiveDayAssignment`
- [ ] Soll HealthKit-Write synchron oder async sein? → Empfehlung: async (Fire-and-forget)
