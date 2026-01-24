# Context: Generic Tracker Completion (NoAlc Focus)

## Request Summary
Vollständiger funktioneller Vergleich zwischen Legacy NoAlc Tracker und Generic Tracker System, mit Plan für fehlende Features und Edit-Mode-Vollständigkeit.

## Related Files

### Legacy NoAlc System
| File | Relevance |
|------|-----------|
| `Services/NoAlcManager.swift` | DEPRECATED - Day assignment (18:00 cutoff), HealthKit I/O, Streak+Joker calculation |
| `Meditationstimer iOS/NoAlcLogSheet.swift` | Legacy Log-UI (compact + advanced mode mit DatePicker) |
| `Meditationstimer iOS/Models/AlcoholEntry.swift` | Legacy Datenmodell (wird nicht mehr aktiv genutzt) |

### Generic Tracker System
| File | Relevance |
|------|-----------|
| `Services/TrackerModels.swift` | Core Models: Tracker, TrackerLog, TrackerLevel, RewardConfig, StreakCalculator |
| `Services/TrackerManager.swift` | CRUD, Logging, HealthKit writes, Streak queries |
| `Meditationstimer iOS/Tabs/TrackerTab.swift` | Main UI: NoAlc Card + Custom Tracker Liste |
| `Meditationstimer iOS/Tracker/TrackerRow.swift` | Generic Row mit FEAT-38 Inline Level Buttons |
| `Meditationstimer iOS/Tracker/CustomTrackerSheet.swift` | Tracker-Erstellung mit Level-Editor |
| `Meditationstimer iOS/Tracker/TrackerEditorSheet.swift` | Tracker-Bearbeitung (begrenzt) |
| `Meditationstimer iOS/Tracker/LevelSelectionView.swift` | Generic Level Picker |

### Reminder System
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/SmartReminderEngine.swift` | Notification scheduling, Reverse Smart Reminders |
| `Meditationstimer iOS/Models/SmartReminder.swift` | Reminder Model mit trackerID Support (ungenutzt) |
| `Meditationstimer iOS/SmartRemindersView.swift` | Reminder UI (nur ActivityType, kein Tracker-Picker) |

### Tests
| File | Relevance |
|------|-----------|
| `LeanHealthTimerTests/NoAlcManagerTests.swift` | Day assignment, value encoding |
| `LeanHealthTimerTests/NoAlcStreakTests.swift` | Streak + Joker calculation |
| `LeanHealthTimerTests/TrackerModelTests.swift` | Generic system models (2 Tests failing) |

---

## Feature Comparison: Legacy vs Generic NoAlc

### ✅ VOLLSTÄNDIG IM GENERIC SYSTEM

| Feature | Legacy Location | Generic Location | Status |
|---------|-----------------|------------------|--------|
| **3 Consumption Levels** | `NoAlcManager.ConsumptionLevel` | `TrackerLevel.noAlcLevels` | ✅ Identisch |
| **HealthKit Storage** | `NoAlcManager.logConsumption()` | `TrackerManager.saveToHealthKit()` | ✅ Funktioniert |
| **Streak Calculation** | `NoAlcManager.calculateStreakAndRewards()` | `StreakCalculator.calculate()` | ✅ Identisch |
| **Joker/Reward System** | `NoAlcManager` lines 171-238 | `RewardConfig` + `StreakCalculator` | ✅ Konfigurierbar |
| **Day Assignment (18:00)** | `NoAlcManager.targetDay()` | `DayAssignment.cutoffHour(18)` | ✅ Konfigurierbar |
| **Quick-Log Buttons** | `NoAlcLogSheet` compact | `TrackerRow` FEAT-38 | ✅ Inline Buttons |
| **Advanced Date Picker** | `NoAlcLogSheet` extended | `LevelSelectionView` extended | ✅ Vorhanden |
| **Streak Badge Display** | `CalendarView` | `TrackerRow` header | ✅ Vorhanden |
| **Joker Display** | `CalendarView` footer | `TrackerRow` (Joker icons) | ✅ Vorhanden |

### ⚠️ TEILWEISE IMPLEMENTIERT

| Feature | Legacy | Generic | Gap |
|---------|--------|---------|-----|
| **Level-Konfiguration** | Hard-coded | `CustomTrackerSheet` Level-Editor | ⚠️ Nur bei Erstellung, nicht im Edit-Mode |
| **Joker-Konfiguration** | Hard-coded (7 days, max 3) | `CustomTrackerSheet` Joker-Config | ⚠️ Nur bei Erstellung |
| **Day Boundary Config** | Hard-coded 18:00 | `CustomTrackerSheet` Cutoff-Picker | ⚠️ UI vorhanden, Persistierung unklar |
| **Calendar Integration** | `CalendarView` zeigt NoAlc | Generic Tracker Support | ⚠️ CalendarView nutzt noch Legacy |

### ❌ FEHLT IM GENERIC SYSTEM

| Feature | Legacy | Generic | Impact |
|---------|--------|---------|--------|
| **Smart Reminders für Tracker** | `ActivityType.noalc` | `SmartReminder.trackerID` (ungenutzt) | ❌ Keine Reminder für Generic Tracker |
| **Reminder Quick-Actions** | `NOALC_LOG_CATEGORY` mit 3 Buttons | Nicht für Generic | ❌ Kein Direktlogging aus Notification |
| **Edit-Mode für Levels** | - | Fehlt | ❌ Levels nur bei Erstellung änderbar |
| **Edit-Mode für Joker-Config** | - | Fehlt | ❌ Joker-System nur bei Erstellung konfigurierbar |
| **Edit-Mode für Day Boundary** | - | Fehlt | ❌ Cutoff-Hour nur bei Erstellung |
| **HealthKit Historical Read** | `NoAlcManager.fetchConsumption()` | TODO in TrackerModels:878 | ❌ Keine Migration alter Daten |

---

## Edit-Mode Analyse: Was fehlt?

### TrackerEditorSheet.swift - Aktueller Stand

**Editierbar:**
- ✅ Icon (24 Emoji-Auswahl)
- ✅ Name (TextField)
- ✅ Daily Goal (nur Counter-Mode)
- ✅ Delete mit Bestätigung

**Nicht editierbar (read-only oder fehlend):**
- ❌ Tracker Type (good/saboteur)
- ❌ Tracking Mode
- ❌ **Levels** (Icon, Name, StreakEffect)
- ❌ **Joker System** (enable, earnEveryDays, maxOnHand)
- ❌ **Day Boundary** (timestamp vs cutoffHour)
- ❌ Success Condition
- ❌ Storage Strategy
- ❌ HealthKit Type
- ❌ **Smart Reminder Link**

### CustomTrackerSheet.swift - Bei Erstellung

**Konfigurierbar (nur bei Erstellung):**
- ✅ Icon, Name, Type, Mode
- ✅ Daily Goal (Counter)
- ✅ Level Editor (2-5 Levels mit Icon, Name, StreakEffect)
- ✅ Joker System Toggle + Config
- ✅ Day Boundary (Midnight vs Cutoff Hour)

---

## Risks & Considerations

1. **Dual-System Komplexität:** Legacy NoAlcManager und Generic System laufen parallel → mögliche Inkonsistenzen
2. **HealthKit Sync:** Generic System schreibt zu HealthKit, liest aber nicht → keine historische Datenmigration
3. **Calendar View Abhängigkeit:** CalendarView nutzt noch Legacy NoAlc Streak-Berechnung
4. **Reminder-System Lücke:** SmartReminder.trackerID existiert, aber UI fehlt komplett
5. **Test Failures:** 2 Tests failing (Mood preset fehlt, Labels nicht lokalisiert)

---

## Existing Specs

- `DOCS/specs/features/generic-tracker-system-implementation.md` - Existierende Spec (ggf. veraltet)
- `DOCS/specs/features/FEAT-37d-healthkit-integration.md` - HealthKit Integration für Generic Tracker

---

## Scope Clarification Questions

1. **NoAlc-spezifisch vs. Alle Generic Tracker:** Soll der Edit-Mode nur für NoAlc oder für ALLE Level-basierten Tracker erweitert werden?

2. **Reminder-Integration:** Sollen Smart Reminders für alle Generic Tracker ermöglicht werden, oder nur für NoAlc?

3. **Calendar View Migration:** Soll CalendarView auf das Generic System migriert werden?

4. **Legacy Deprecation:** Soll NoAlcManager.swift vollständig depreciert und entfernt werden, oder parallel weiterlaufen?

5. **HealthKit Read:** Brauchen wir Migration historischer HealthKit-Daten ins Generic System?
