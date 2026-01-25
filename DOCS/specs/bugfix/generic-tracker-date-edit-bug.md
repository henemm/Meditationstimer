# Bugfix: Generic Tracker Date Edit Bug

**Status:** Awaiting Approval
**Aufwand:** Klein (~15 LoC)
**Dateien:** 2

---

## Problem

Generic NoAlc Tracker ignoriert das vom User gewählte Datum im "Erweitert"-Modus.

**Reproduktion:**
1. Tracker Tab → Generic NoAlc Tracker
2. "Erweitert" antippen
3. Anderes Datum wählen (z.B. gestern)
4. Level auswählen → Speichern
5. **Erwartet:** Eintrag bei gewähltem Datum
6. **Tatsächlich:** Eintrag bei HEUTE

---

## Root Cause

`LevelSelectionView.swift:207-215` - Die Variable `dateToLog` wird berechnet aber nie an `logEntry()` übergeben.

---

## Fix

### 1. TrackerManager.swift - timestamp-Parameter hinzufügen

```swift
// Zeile 45-52: Neuer Parameter mit Default
func logEntry(
    for tracker: Tracker,
    value: Int? = nil,
    note: String? = nil,
    trigger: String? = nil,
    location: String? = nil,
    timestamp: Date = Date(),  // ← NEU
    in context: ModelContext
) -> TrackerLog {
    let log = TrackerLog(
        timestamp: timestamp,  // ← verwenden statt Default
        value: value,
        note: note,
        trigger: trigger,
        location: location,
        tracker: tracker
    )
    // ...
}
```

### 2. LevelSelectionView.swift - dateToLog übergeben

```swift
// Zeile 210-216: timestamp hinzufügen
_ = manager.logEntry(
    for: tracker,
    value: level.id,
    note: "\(level.icon) \(level.localizedLabel)",
    timestamp: dateToLog,  // ← NEU
    in: modelContext
)
```

---

## Rückwärtskompatibilität

- **Alle bestehenden Aufrufe** von `logEntry()` nutzen weiterhin `Date()` als Default
- **Keine Breaking Changes**
- **HealthKit:** Verwendet bereits `log.timestamp` - funktioniert automatisch

---

## Test-Plan

### Unit Test (TDD RED)
```swift
func testLogEntryWithCustomTimestamp() {
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    let log = manager.logEntry(
        for: tracker,
        value: 1,
        timestamp: yesterday,
        in: context
    )
    XCTAssertTrue(Calendar.current.isDate(log.timestamp, inSameDayAs: yesterday))
}
```

### Manueller Test
1. Generic NoAlc → "Erweitert" → Gestern wählen → Level loggen
2. Zurück zum Tracker Tab → Eintrag prüfen
3. Erwartet: Log erscheint bei GESTERN

---

## Betroffene Dateien

| Datei | Änderung |
|-------|----------|
| `Services/TrackerManager.swift` | +1 Parameter, 1 Zeile ändern |
| `Meditationstimer iOS/Tracker/LevelSelectionView.swift` | +1 Zeile |

**Total:** ~5 LoC
