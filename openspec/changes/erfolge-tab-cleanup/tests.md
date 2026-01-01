# Test-Definitionen

## XCUITests

### Test: Erfolge Tab zeigt keine redundanten Elemente

**Datei:** `LeanHealthTimerUITests.swift`
**Test:** `testErfolgeTabShowsCleanLayout`

```
GIVEN: App startet
WHEN: User navigiert zum Erfolge Tab
THEN: Kein "Fertig" Button sichtbar
AND: Kein "Kalender" Title in Navigation Bar
AND: Streak-Info-Sektion unten sichtbar (Meditation, Workout, NoAlc)
AND: Kalender-Grid sichtbar
```

### Test: Sheet-Aufrufe funktionieren weiterhin

**Test:** `testCalendarSheetShowsNavigation` (optional, da bestehende Tests abdecken)

```
GIVEN: App startet
WHEN: User öffnet Kalender als Sheet (z.B. aus OffenView)
THEN: "Fertig" Button sichtbar
AND: Navigation Title sichtbar
AND: Dismiss funktioniert
```

## Unit Tests

Keine neuen Unit Tests nötig - rein UI-Refactoring ohne Logik-Änderung.

## Manuelle Tests

### Test 1: Erfolge Tab Layout

1. App starten
2. Zu "Erfolge" Tab navigieren
3. **Erwartung:**
   - Kalender direkt sichtbar (kein Header mit 🧘 💪 ⭐ oben)
   - Kein "Fertig" Button
   - Kein "Kalender" Title
   - Streak-Infos unten sichtbar

### Test 2: Kalender Sheet (Regression)

1. App starten
2. Zu "Meditation" Tab gehen
3. Kalender-Button in Toolbar tippen (falls vorhanden)
4. **Erwartung:**
   - Sheet öffnet sich
   - "Fertig" Button sichtbar
   - Tap auf "Fertig" schließt Sheet

### Test 3: Tab-Wechsel

1. Zwischen allen 4 Tabs wechseln
2. Zurück zu "Erfolge"
3. **Erwartung:**
   - Kein Crash
   - Layout korrekt
   - Keine Navigation-Anomalien
