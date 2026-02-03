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

1. Lokale `meditationStreak` computed property anpassen:
   - Aktuell: Iteriert nur über geladene `dailyMinutes`
   - Neu: Nutzt StreakManager oder eigene expanding Logik

2. Lokale `workoutStreak` computed property anpassen:
   - Gleiche Änderung wie meditationStreak

**Alternative:** CalendarView könnte direkt StreakManager.meditationStreak nutzen statt lokal zu berechnen.

### Task 3: Spec aktualisieren

**Datei:** `openspec/specs/features/streaks-rewards.md`

1. Zeile 229 ändern: "fetches last 30 days" → "fetches data in 30-day batches until streak breaks"
2. Neues Szenario für Expand-on-Demand hinzufügen

## Validierung

- [ ] Unit Tests für `calculateExpandingStreak()` schreiben
- [ ] Bestehende StreakManager-Tests anpassen
- [ ] Build erfolgreich
- [ ] Manuelle Verifikation mit echten Daten
