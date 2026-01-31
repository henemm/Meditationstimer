---
entity_id: feat-37d-healthkit-integration
type: feature
created: 2026-01-18
status: complete
workflow: feat-37d-healthkit-integration
---

# FEAT-37d: HealthKit-Integration für Generic Tracker System

- [x] Approved for implementation (31. Januar 2026)

## Purpose

TrackerManager soll HealthKit-Integration unterstützen, sodass Tracker mit `saveToHealthKit: true` ihre Daten automatisch sowohl in SwiftData als auch in HealthKit speichern. Dies ersetzt den aktuellen Dual-Write in TrackerTab.

## Scope

**Dateien:**
| File | Change |
|------|--------|
| `Services/TrackerModels.swift` | +10 LoC (healthKitValue Property) |
| `Services/TrackerManager.swift` | +40 LoC (HealthKit-Write Methode) |
| `Meditationstimer iOS/Tabs/TrackerTab.swift` | -15 LoC (Dual-Write entfernen) |

**Geschätzt:** +50 / -15 LoC = **+35 LoC netto**

## Implementation Details

### 1. TrackerLevel: healthKitValue Property

```swift
// TrackerModels.swift - TrackerLevel extension
extension TrackerLevel {
    /// HealthKit-Wert für dieses Level (nur für NoAlc relevant)
    /// NoAlc: steady=0, easy=4, wild=6
    var healthKitValue: Int {
        switch key {
        case "steady": return 0
        case "easy": return 4
        case "wild": return 6
        default: return id  // Fallback: id als Wert
        }
    }
}
```

### 2. TrackerManager: HealthKit-Write

```swift
// TrackerManager.swift
import HealthKit

// Neue Property
private let healthStore = HKHealthStore()

// Neue Methode
private func saveToHealthKit(
    tracker: Tracker,
    value: Int,
    date: Date
) async {
    guard tracker.saveToHealthKit,
          let hkTypeId = tracker.healthKitType,
          let hkType = HKQuantityType.quantityType(
              forIdentifier: HKQuantityTypeIdentifier(rawValue: hkTypeId)
          ) else { return }

    // Für Level-Tracker: HealthKit-Wert aus Level holen
    let hkValue: Int
    if let levels = tracker.levels,
       let level = levels.first(where: { $0.id == value }) {
        hkValue = level.healthKitValue
    } else {
        hkValue = value
    }

    let quantity = HKQuantity(unit: .count(), doubleValue: Double(hkValue))
    let assignedDay = tracker.effectiveDayAssignment.assignedDay(for: date, calendar: calendar)
    let sample = HKQuantitySample(type: hkType, quantity: quantity, start: assignedDay, end: assignedDay)

    do {
        try await healthStore.save(sample)
    } catch {
        print("[TrackerManager] HealthKit save failed: \(error)")
    }
}

// logEntry() erweitern (am Ende der Methode):
func logEntry(...) -> TrackerLog {
    // ... existing SwiftData code ...

    // HealthKit-Write (async, fire-and-forget)
    if tracker.saveToHealthKit, let value = value {
        Task {
            await saveToHealthKit(tracker: tracker, value: value, date: log.timestamp)
        }
    }

    return log
}
```

### 3. TrackerTab: Dual-Write entfernen

```swift
// ENTFERNEN (Zeilen 94-104):
// do {
//     let legacyLevel: NoAlcManager.ConsumptionLevel
//     switch level.key {
//     case "steady": legacyLevel = .steady
//     ...
//     }
//     try await NoAlcManager.shared.logConsumption(legacyLevel, for: Date())
// } catch { ... }
```

## Test Plan

### Automated Tests (TDD RED)

1. **Test HealthKit Value Mapping:**
   - GIVEN TrackerLevel mit key "steady"
   - WHEN healthKitValue aufgerufen wird
   - THEN return 0

2. **Test HealthKit Value für Easy:**
   - GIVEN TrackerLevel mit key "easy"
   - WHEN healthKitValue aufgerufen wird
   - THEN return 4

3. **Test HealthKit Value für Wild:**
   - GIVEN TrackerLevel mit key "wild"
   - WHEN healthKitValue aufgerufen wird
   - THEN return 6

### Manual Tests

- [ ] NoAlc loggen → Prüfen ob Eintrag in Apple Health erscheint
- [ ] Streak-Berechnung funktioniert weiterhin
- [ ] Kalender zeigt NoAlc-Daten korrekt an

## Acceptance Criteria

- [x] **AC1:** TrackerLevel hat `healthKitValue` Property mit korrektem Mapping ✅ (bereits implementiert)
- [x] **AC2:** TrackerManager.logEntry() schreibt in HealthKit wenn `saveToHealthKit: true` ✅ (bereits implementiert)
- [x] **AC3:** HealthKit-Write verwendet `effectiveDayAssignment` für korrektes Datum ✅ (bereits implementiert)
- [x] **AC4:** Dual-Write in TrackerTab ist entfernt ✅ (31.01.2026)
- [x] **AC5:** Build erfolgreich (keine Compile-Errors) ✅
- [x] **AC6:** Alle bestehenden Unit Tests grün ✅

## Nicht im Scope

- NoAlcManager wird **nicht gelöscht** (bleibt für CalendarView)
- Keine neuen UI-Änderungen
- Keine Migration von historischen Daten
