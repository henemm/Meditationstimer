# Bugfix Spec: NoAlc Reminder Cancel

## Problem

Nach dem Logging eines NoAlc-Eintrags mit dem Generic Tracker System wird der SmartReminder nicht gecancelt. Der Reminder fragt weiterhin nach, obwohl bereits geloggt wurde.

## Root Cause

Zwei unverbundene Systeme:

| System | Identifier | Cancel-Methode |
|--------|------------|----------------|
| Alter NoAlc-Reminder | `activityType = .noalc` | `cancelMatchingReminders(for: .noalc)` |
| Neuer Tracker | `trackerID` | `cancelMatchingTrackerReminders(for: trackerID)` |

`TrackerTab.swift:122-125` ruft nur `cancelMatchingTrackerReminders()` auf, die nach `trackerID` filtert und den alten Reminder mit `activityType = .noalc` nie findet.

## Fix

In `TrackerTab.swift` nach Zeile 125 zusätzlich aufrufen:

```swift
// Also cancel old-style NoAlc reminders (backwards compatibility)
SmartReminderEngine.shared.cancelMatchingReminders(for: .noalc, completedAt: Date())
```

## Betroffene Dateien

| Datei | Änderung |
|-------|----------|
| `Meditationstimer iOS/Tabs/TrackerTab.swift` | +3 LoC nach Zeile 125 |

## Test Strategy

Unit Test in `SmartReminderEngineTests.swift`:
- Test dass `cancelMatchingReminders(for: .noalc)` aufgerufen wird

## Risks

1. **Doppelte Cancel-Aufrufe** - Minimaler Performance-Impact, kein funktionales Problem
2. **Langfristig:** Nach vollständiger Migration zu Generic Tracker System kann `.noalc` deprecated werden

## Estimated Effort

**Small** - 3 LoC in einer Datei
