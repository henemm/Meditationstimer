# Context: NoAlc Reminder Cancel Bug

## Request Summary

Nach dem Logging eines NoAlc-Eintrags mit dem neuen Generic Tracker System wird der SmartReminder nicht gecancelt. Der Reminder fragt weiterhin nach, obwohl bereits geloggt wurde.

## Root Cause (bereits identifiziert)

Zwei unverbundene Systeme:
1. **Alter NoAlc-Reminder:** Nutzt `activityType = .noalc` (HealthKit-basiert)
2. **Neuer NoAlc-Tracker:** Nutzt `trackerID` (SwiftData Generic Tracker System)

`cancelMatchingTrackerReminders()` filtert nur nach `trackerID`, findet den alten Reminder nicht.

## Related Files

| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/SmartReminderEngine.swift:137-195` | `cancelMatchingTrackerReminders()` - nur trackerID-Filter |
| `Meditationstimer iOS/SmartReminderEngine.swift:203-250` | `cancelMatchingReminders(for activityType:)` - für alte Typen |
| `Meditationstimer iOS/Tabs/TrackerTab.swift:121-125` | NoAlc-Button ruft nur `cancelMatchingTrackerReminders` |
| `Meditationstimer iOS/Tracker/TrackerRow.swift:390-394` | Generische Tracker rufen `cancelMatchingTrackerReminders` |
| `Meditationstimer iOS/SmartRemindersView.swift:178-186` | Migration erstellt NoAlc-Reminder mit `activityType = .noalc` |
| `Meditationstimer iOS/Models/SmartReminder.swift:167` | Sample NoAlc-Reminder Definition |

## Existing Patterns

### Pattern 1: Dual Cancel (HealthKitManager)
```swift
// HealthKitManager ruft beide Methoden auf:
SmartReminderEngine.shared.cancelMatchingReminders(for: .noalc, completedAt: date)
```

### Pattern 2: Tracker Cancel (TrackerRow)
```swift
// Generische Tracker rufen nur trackerID-Methode:
SmartReminderEngine.shared.cancelMatchingTrackerReminders(for: tracker.id, completedAt: Date())
```

## Dependencies

- **Upstream:** `SmartReminderEngine.cancelMatchingReminders()`, `SmartReminderEngine.cancelMatchingTrackerReminders()`
- **Downstream:** Notification-System, User-Experience

## Fix Strategy

In `TrackerTab.swift` beim NoAlc-Card-Logging zusätzlich `cancelMatchingReminders(for: .noalc)` aufrufen:

```swift
// Bestehend:
SmartReminderEngine.shared.cancelMatchingTrackerReminders(for: tracker.id, completedAt: Date())

// NEU für NoAlc-Abwärtskompatibilität:
SmartReminderEngine.shared.cancelMatchingReminders(for: .noalc, completedAt: Date())
```

## Risks & Considerations

1. **Risiko:** Doppelte Cancel-Aufrufe (minimales Performance-Impact)
2. **Alternative:** Migration aller alten NoAlc-Reminder zu `trackerID` (komplexer, würde User-Daten ändern)
3. **Langfristig:** Nach vollständiger Migration zu Generic Tracker System kann `.noalc` deprecated werden

## Estimated Effort

**Small** - 3-5 LoC in einer Datei (`TrackerTab.swift`)
