---
entity_id: noalc-healthkit-value-bug
type: bugfix
created: 2026-01-27
status: completed
workflow: noalc-healthkit-value-bug
verified: 2026-02-01
---

# Bugfix: Generic NoAlc Tracker schreibt falschen HealthKit-Wert

- [x] Approved for implementation
- [x] Implemented
- [x] Tests passing

**Status:** ✅ COMPLETED & VERIFIED
**Aufwand:** Klein (~10 LoC)
**Dateien:** 1

---

## Purpose

Der Generic NoAlc Tracker schreibt beim Loggen über die TrackerRow die Level-ID (0/1/2) statt des korrekten HealthKit drink count (0/4/6) nach HealthKit. Beim Zurucklesen wird dadurch "Party" als "Ueberschaubar" interpretiert.

## Problem

**Reproduktion:**
1. Tracker Tab → Generic NoAlc Tracker (TrackerRow)
2. "Party" (💥) antippen
3. HealthKit-Wert pruefen → zeigt 2 statt 6
4. CalendarView/TrackerTab liest zurueck → "Ueberschaubar" statt "Party"

**Erwartetes Verhalten:**
- "Kaum" (steady) → HealthKit-Wert 0
- "Ueberschaubar" (easy) → HealthKit-Wert 4
- "Party" (wild) → HealthKit-Wert 6

**Tatsaechliches Verhalten:**
- "Kaum" → HealthKit-Wert 0 (zufaellig korrekt)
- "Ueberschaubar" → HealthKit-Wert 1 (FALSCH)
- "Party" → HealthKit-Wert 2 (FALSCH)

---

## Root Cause

`TrackerManager.swift:74-77` — `saveToHealthKit()` wird in einem `Task {}` aufgerufen. Der uebergebene `tracker` ist ein SwiftData `@Model`-Objekt, das an den MainActor gebunden ist. Im async Task kann `tracker.levels` (via `tracker.levelsData`) `nil` zurueckgeben, weil der ModelContext nicht mehr verfuegbar ist.

In `saveToHealthKit()` (Zeile 113-120) greift dann der Fallback `hkValue = value`, der die Level-ID (0/1/2) statt des drink count (0/4/6) verwendet.

---

## Scope

| File | Change Type | Description |
|------|-------------|-------------|
| `Services/TrackerManager.swift` | MODIFY | HealthKit-Wert-Konvertierung vor Task-Grenze verschieben |

- **Files:** 1
- **Estimated LoC:** +8/-5
- **Risk Level:** LOW

---

## Fix

Die HealthKit-Wert-Konvertierung MUSS vor dem `Task {}` auf dem MainActor stattfinden, wo `tracker.levels` garantiert verfuegbar ist. Dann nur noch primitive Werte (Int, String, Date) an den async Task uebergeben.

### Implementierte Lösung in `TrackerManager.logEntry()`:

```swift
if tracker.saveToHealthKit, let logValue = value {
    // Resolve HealthKit value on MainActor (where tracker.levels is accessible)
    let hkValue = resolveHealthKitValue(for: tracker, levelId: logValue)
    let hkTypeId = tracker.healthKitType
    let trackerName = tracker.name
    let dayAssignment = tracker.effectiveDayAssignment

    Task {
        await saveToHealthKitDirect(hkTypeId: hkTypeId, hkValue: hkValue, date: log.timestamp, dayAssignment: dayAssignment, trackerName: trackerName)
    }
}
```

### Neue Methode `resolveHealthKitValue()`:

```swift
func resolveHealthKitValue(for tracker: Tracker, levelId: Int) -> Int {
    if let levels = tracker.levels,
       let level = levels.first(where: { $0.id == levelId }) {
        return level.healthKitValue
    }
    return levelId
}
```

---

## Test Plan

### Automated Tests (TDD RED → GREEN)

- [x] Test 1: GIVEN NoAlc tracker with levels WHEN `logEntry(value: 2)` (wild) THEN HealthKit receives value 6 (not 2)
- [x] Test 2: GIVEN NoAlc tracker with levels WHEN `logEntry(value: 1)` (easy) THEN HealthKit receives value 4 (not 1)
- [x] Test 3: GIVEN NoAlc tracker with levels WHEN `logEntry(value: 0)` (steady) THEN HealthKit receives value 0
- [x] Test 4: GIVEN tracker without levels WHEN `logEntry(value: 5)` THEN HealthKit receives value 5 (fallback)

**Test-Ergebnisse (2026-02-01):**
```
testResolveHealthKitValueWild    → passed ✅
testResolveHealthKitValueEasy    → passed ✅
testResolveHealthKitValueSteady  → passed ✅
testResolveHealthKitValueFallbackNoLevels → passed ✅
```

---

## Acceptance Criteria

- [x] "Party" (wild) schreibt HealthKit-Wert 6
- [x] "Ueberschaubar" (easy) schreibt HealthKit-Wert 4
- [x] "Kaum" (steady) schreibt HealthKit-Wert 0
- [x] Kein SwiftData `@Model`-Objekt wird ueber Task-Grenze uebergeben
- [x] Alle bestehenden Unit Tests gruen
- [x] Build erfolgreich
