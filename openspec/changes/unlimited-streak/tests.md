# Test-Definitionen

## Unit Tests

### Test 1: Kurzer Streak (< 30 Tage)

```
GIVEN User hat 15 konsekutive Tage mit ≥2 Min Meditation
WHEN calculateExpandingStreak() aufgerufen wird
THEN Streak = 15
AND nur 1 Batch wurde geladen (30 Tage)
```

### Test 2: Streak genau am Batch-Rand

```
GIVEN User hat genau 30 konsekutive Tage Aktivität
AND Tag 31 hat keine Aktivität
WHEN calculateExpandingStreak() aufgerufen wird
THEN Streak = 30
AND 2 Batches wurden geladen (um Tag 31 zu prüfen)
```

### Test 3: Langer Streak über mehrere Batches

```
GIVEN User hat 45 konsekutive Tage Aktivität
WHEN calculateExpandingStreak() aufgerufen wird
THEN Streak = 45
AND 2 Batches wurden geladen
```

### Test 4: Sehr langer Streak

```
GIVEN User hat 100 konsekutive Tage Aktivität
WHEN calculateExpandingStreak() aufgerufen wird
THEN Streak = 100
AND 4 Batches wurden geladen
```

### Test 5: Streak mit Lücke in der Mitte

```
GIVEN User hat Aktivität an Tag 1-10
AND keine Aktivität an Tag 11
AND Aktivität an Tag 12-20
WHEN calculateExpandingStreak() aufgerufen wird
THEN Streak = 9 (nur die neuesten 9 Tage)
```

### Test 6: Kein Streak (keine Daten)

```
GIVEN User hat keine Aktivitätsdaten
WHEN calculateExpandingStreak() aufgerufen wird
THEN Streak = 0
AND nur 1 Batch wurde versucht
```

### Test 7: Safety-Limit erreicht

```
GIVEN User hat theoretisch 1500 Tage Aktivität
WHEN calculateExpandingStreak() aufgerufen wird
THEN Streak = 1200 (40 Batches × 30 Tage)
AND Berechnung stoppt beim Safety-Limit
```

### Test 8: Today-Grace (heute noch keine Aktivität)

```
GIVEN User hat Aktivität an Tag -1 bis -10 (gestern bis vor 10 Tagen)
AND heute noch keine Aktivität
WHEN calculateExpandingStreak() aufgerufen wird
THEN Streak = 10 (zählt ab gestern)
```

## Bestehende Tests anpassen

**Datei:** `LeanHealthTimerTests/StreakManagerTests.swift`

Die bestehenden Tests sollten weiterhin funktionieren, da sich nur die interne Implementierung ändert, nicht das externe Verhalten.

Zu prüfende Tests:
- `testStreakCalculation()`
- `testStreakWithGap()`
- `testEmptyStreak()`

## Manuelle Tests

### Device-Test 1: Echter langer Streak

```
GIVEN Testgerät mit HealthKit-Daten über 30+ Tage
WHEN ErfolgeTab öffnen
THEN Streak zeigt korrekte Anzahl (nicht bei 30 abgeschnitten)
```

### Device-Test 2: Performance

```
GIVEN Testgerät mit vielen HealthKit-Daten
WHEN ErfolgeTab öffnen
THEN Streak-Anzeige lädt schnell (<1 Sekunde)
AND keine UI-Blockierung
```
