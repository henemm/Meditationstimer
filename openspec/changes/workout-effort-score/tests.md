# Tests: Workout Effort Score

## Unit Tests

### Test 1: Effort Score Permission angefordert
```
GIVEN: App startet
WHEN: requestAuthorization() aufgerufen
THEN: workoutEffortScore ist in toShare enthalten (iOS 18+)
```

### Test 2: Effort Score im gültigen Bereich
```
GIVEN: Workout beendet
WHEN: relateEffortScore(score: 7, workout: workout)
THEN: Score wird ohne Fehler gespeichert
```

### Test 3: Effort Score außerhalb Bereich abgelehnt
```
GIVEN: Workout beendet
WHEN: relateEffortScore(score: 15, workout: workout)
THEN: Fehler oder Clamp auf 10
```

## UI Tests

### Test 4: Sheet erscheint nach Workout
```
GIVEN: Free Workout läuft
WHEN: User beendet Workout (X-Button oder natürliches Ende)
THEN: Effort Sheet erscheint mit Slider (Default: 7)
```

### Test 5: Sheet kann übersprungen werden
```
GIVEN: Effort Sheet ist sichtbar
WHEN: User tippt außerhalb oder "Überspringen"
THEN: Sheet schließt, kein Effort Score gespeichert
```

## Manueller Device-Test

1. HIIT Workout mit Apple Watch starten
2. Workout beenden
3. Effort Score eingeben (z.B. 8)
4. In Fitness App prüfen:
   - Workout zeigt "Effort: 8 Hard"
   - Training Load wird aktualisiert
