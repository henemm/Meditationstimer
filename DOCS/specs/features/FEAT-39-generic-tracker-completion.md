# FEAT-39: Generic Tracker System - Feature-Parität

**Status:** In Arbeit
**Erstellt:** 19. Januar 2026
**Letzte Aktualisierung:** 19. Januar 2026

---

## Ziel

Das Generic Tracker System soll **vollständige Feature-Parität** mit dem Legacy NoAlcManager erreichen, sodass der Legacy-Code am Ende entfernt werden kann.

---

## Implementierungs-Plan

### Phase A: UI-Anzeige im TrackerTab (Kritisch)

#### A1: Streak/Joker/Rewards im NoAlc-Card Header
- **Datei:** `Meditationstimer iOS/Tabs/TrackerTab.swift`
- **Was:** Im `noAlcCard` Header neben "NoAlc" Text:
  - 🔥 Streak-Zahl anzeigen
  - 🃏 Joker-Anzahl anzeigen (0/3 Format)
  - ⭐ Optional: Earned Rewards
- **Wie:**
  1. `StreakCalculator` aufrufen mit `noAlcTracker.logs`
  2. Ergebnis in der View anzeigen
- **Aufwand:** Klein (~30 Min)
- **Test:** XCUITest `testNoAlcCardShowsStreakAndJoker`

#### A2: Streak/Joker für andere Level-Tracker
- **Datei:** `Meditationstimer iOS/Tracker/TrackerRow.swift`
- **Was:** Für alle `.levels` Tracker mit `rewardConfig` die gleiche Anzeige
- **Aufwand:** Klein (~20 Min)
- **Test:** XCUITest `testLevelTrackerShowsStreakInfo`

---

### Phase B: Reverse Cancel für Reminders (Kritisch)

#### B1: cancelMatchingTrackerReminders aufrufen
- **Datei:** `Meditationstimer iOS/Tabs/TrackerTab.swift`
- **Was:** Nach `tracker.logLevel()` auch `SmartReminderEngine.shared.cancelMatchingTrackerReminders()` aufrufen
- **Wo:** In `noAlcButton()` Funktion nach Zeile 91
- **Aufwand:** Klein (~10 Min)
- **Test:** Unit Test `testLoggingCancelsTrackerReminders`

---

### Phase C: History-Sheet verlinken (Wichtig)

#### C1: History-Button im NoAlc-Card
- **Datei:** `Meditationstimer iOS/Tabs/TrackerTab.swift`
- **Was:** Info-Button (i) öffnet TrackerHistorySheet statt NoAlcLogSheet
- **Oder:** Zweiten Button für History hinzufügen
- **Aufwand:** Klein (~15 Min)
- **Test:** XCUITest `testNoAlcCardOpensHistorySheet`

#### C2: History-Link im TrackerEditorSheet
- **Datei:** `Meditationstimer iOS/Tracker/TrackerEditorSheet.swift`
- **Was:** NavigationLink zu TrackerHistorySheet in Info-Section
- **Aufwand:** Klein (~10 Min)
- **Test:** XCUITest `testEditorShowsHistoryLink`

---

### Phase D: Editor-Erweiterungen (Wichtig)

#### D1: HealthKit Toggle hinzufügen
- **Datei:** `Meditationstimer iOS/Tracker/TrackerEditorSheet.swift`
- **Was:** Toggle für `tracker.saveToHealthKit` in basicSettingsSection
- **Nur anzeigen wenn:** `tracker.healthKitType != nil`
- **Aufwand:** Klein (~10 Min)

#### D2: Widget/Kalender Toggles hinzufügen
- **Datei:** `Meditationstimer iOS/Tracker/TrackerEditorSheet.swift`
- **Was:** Toggles für `showInWidget` und `showInCalendar`
- **Aufwand:** Klein (~15 Min)

---

### Phase E: CalendarView Migration (Mittel)

#### E1: CalendarView Daten-Quelle umstellen
- **Datei:** `Meditationstimer iOS/CalendarView.swift`
- **Was:**
  1. `@Query` für NoAlc Tracker Logs hinzufügen
  2. `alcoholDays` aus SwiftData statt HealthKit laden
  3. `NoAlcManager.calculateStreakAndRewards()` → `StreakCalculator.calculate()`
- **Aufwand:** Mittel (~1h)
- **Test:** XCUITest `testCalendarShowsTrackerData`

#### E2: Farb-Mapping anpassen
- **Datei:** `Meditationstimer iOS/CalendarView.swift`
- **Was:** `alcoholColor()` nutzt `TrackerLevel` statt `ConsumptionLevel`
- **Aufwand:** Klein (~15 Min)

---

### Phase F: Cleanup (Am Ende)

#### F1: NoAlcManager als deprecated markieren
- **Bereits erledigt:** `@available(*, deprecated)` ist gesetzt

#### F2: Dual-Write entfernen
- **Datei:** `Meditationstimer iOS/Tabs/TrackerTab.swift`
- **Was:** HealthKit-Aufruf in `noAlcButton()` entfernen (Zeilen 96-108)
- **Wann:** Erst wenn CalendarView migriert ist

#### F3: NoAlcManager.swift löschen
- **Wann:** Erst wenn alle Referenzen entfernt sind
- **Prüfen:** `grep -rn "NoAlcManager" --include="*.swift"`

---

## Reihenfolge (Empfohlen)

```
A1 → A2 → B1 → C1 → C2 → D1 → D2 → E1 → E2 → F1 → F2 → F3
```

**Checkpoints:**
- Nach A2: TrackerTab zeigt alle Streak-Infos ✓
- Nach C2: History ist überall erreichbar ✓
- Nach D2: Editor ist vollständig ✓
- Nach E2: CalendarView nutzt Generic System ✓
- Nach F3: Legacy-Code entfernt ✓

---

## Fortschritt

| Phase | Task | Status | Datum |
|-------|------|--------|-------|
| A1 | Streak/Joker im NoAlc-Card | ✅ Erledigt | 2026-01-20 |
| A2 | Streak für Level-Tracker | ⏳ Offen | |
| B1 | Reverse Cancel | ⏳ Offen | |
| C1 | History-Button NoAlc-Card | ⏳ Offen | |
| C2 | History-Link Editor | ⏳ Offen | |
| D1 | HealthKit Toggle | ⏳ Offen | |
| D2 | Widget/Kalender Toggles | ⏳ Offen | |
| E1 | CalendarView Daten | ⏳ Offen | |
| E2 | CalendarView Farben | ⏳ Offen | |
| F1 | Deprecated Marker | ✅ Erledigt | |
| F2 | Dual-Write entfernen | ⏳ Offen | |
| F3 | NoAlcManager löschen | ⏳ Offen | |

---

## Abhängigkeiten

- A1, A2 können parallel
- B1 kann parallel zu A
- C1, C2 können parallel zu A, B
- D1, D2 können parallel zu A, B, C
- E1, E2 müssen NACH A, B (sonst Streak-Anzeige inkonsistent)
- F2, F3 müssen NACH E (sonst Datenverlust)

---

## Test-Strategie

Jede Phase hat XCUITests:
1. TDD RED: Test schreiben der fehlschlägt
2. Implementieren
3. TDD GREEN: Test muss bestehen
4. Commit

**XCUITest-Datei:** `LeanHealthTimerUITests/TrackerSystemTests.swift`
