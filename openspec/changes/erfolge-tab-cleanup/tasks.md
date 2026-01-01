# Implementierungs-Tasks

## Task 1: CalendarView - isEmbedded Parameter

**Datei:** `Meditationstimer iOS/CalendarView.swift`

- [ ] Property `var isEmbedded: Bool = false` hinzufügen
- [ ] Body refaktorieren: `calendarContent` als computed property extrahieren
- [ ] Bedingte Navigation: `NavigationView` nur wenn `!isEmbedded`
- [ ] Bedingte Toolbar: `.toolbar` nur wenn `!isEmbedded`

## Task 2: ErfolgeTab - Cleanup

**Datei:** `Meditationstimer iOS/Tabs/ErfolgeTab.swift`

- [ ] `StreakHeaderSection` View komplett entfernen
- [ ] `CompactStreakBadge` View komplett entfernen
- [ ] `totalRewards` computed property entfernen
- [ ] `CalendarView()` → `CalendarView(isEmbedded: true)` ändern
- [ ] Unnötige Imports/Kommentare aufräumen

## Task 3: Build & Test

- [ ] Build erfolgreich
- [ ] XCUITest `testErfolgeTabShowsEmbeddedCalendar` anpassen
- [ ] Manueller Test: Erfolge Tab zeigt Kalender ohne doppelten Header
- [ ] Manueller Test: Sheet-Aufrufe (OffenView, AtemView, WorkoutProgramsView) funktionieren weiterhin mit "Fertig" Button

## Definition of Done

- [ ] Kein "Kalender" Title im Erfolge Tab
- [ ] Kein "Fertig" Button im Erfolge Tab
- [ ] Keine doppelte Streak-Anzeige
- [ ] Sheet-Aufrufe unverändert funktional
- [ ] Build grün
- [ ] XCUITests grün
