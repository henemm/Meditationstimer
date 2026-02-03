# Implementierungs-Tasks

## Vorbereitung

- [x] Duplikat `Meditationstimer iOS/StreakManager.swift` löschen
- [ ] Bestehende Tests ausführen (Baseline)

## Implementation

### Task 1: StreakManager erweitern

**Datei:** `Services/StreakManager.swift`

1. Neue Methode `calculateExpandingStreak()` erstellen:
   - Parameter: `endDate`, `fetchMinutes` closure
   - Batch-Size: 30 Tage
   - Max-Batches: 40 (Safety-Limit)
   - Return: Int (Streak-Tage)

2. `updateStreaks()` anpassen:
   - Alte `updateStreak()` Methode entfernen
   - Neue `calculateExpandingStreak()` für Meditation aufrufen
   - Neue `calculateExpandingStreak()` für Workout aufrufen

### Task 2: CalendarView anpassen

**Datei:** `Meditationstimer iOS/CalendarView.swift`

**Empfohlene Lösung:** CalendarView soll StreakManager nutzen statt lokal zu berechnen.

1. `@EnvironmentObject var streakManager: StreakManager` hinzufügen
2. Lokale `meditationStreak` computed property ersetzen durch `streakManager.meditationStreak.currentStreakDays`
3. Lokale `workoutStreak` computed property ersetzen durch `streakManager.workoutStreak.currentStreakDays`
4. `streakManager.updateStreaks()` in `onAppear` aufrufen

**Vorteil:** Eine zentrale Streak-Berechnung, keine Duplikation der Logik.

### Task 3: Spec aktualisieren

**Datei:** `openspec/specs/features/streaks-rewards.md`

1. Zeile 229 ändern: "fetches last 30 days" → "fetches data in 30-day batches until streak breaks"
2. Neues Szenario für Expand-on-Demand hinzufügen

## Validierung

- [ ] Unit Tests für `calculateExpandingStreak()` schreiben
- [ ] Bestehende StreakManager-Tests anpassen
- [ ] Build erfolgreich
- [ ] Manuelle Verifikation mit echten Daten
