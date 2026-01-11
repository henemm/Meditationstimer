# Tests: StreakManager Joker-System

## Unit Tests

### Test 1: Streak mit allen guten Tagen
```
GIVEN: 7 aufeinanderfolgende Tage mit ≥2 min Aktivität
WHEN: calculateStreakAndRewards() aufgerufen
THEN: streak = 7, rewardsEarned = 1, rewardsConsumed = 0
```

### Test 2: Streak bricht ohne Joker
```
GIVEN: 6 Tage mit Aktivität, 1 Gap (Tag 4)
WHEN: calculateStreakAndRewards() aufgerufen
THEN: streak = 0 (kein Joker verfügbar zum Heilen)
```

### Test 3: Joker heilt Gap
```
GIVEN: 7 Tage mit Aktivität (verdient 1 Joker), dann 1 Gap
WHEN: calculateStreakAndRewards() aufgerufen
THEN: streak = 8, rewardsEarned = 1, rewardsConsumed = 1
```

### Test 4: Mehrere Gaps mit mehreren Jokern
```
GIVEN: 14 Tage mit Aktivität (verdient 2 Joker), dann 2 Gaps
WHEN: calculateStreakAndRewards() aufgerufen
THEN: streak = 16, rewardsEarned = 2, rewardsConsumed = 2
```

### Test 5: Zu viele Gaps brechen Streak
```
GIVEN: 7 Tage mit Aktivität (verdient 1 Joker), dann 2 Gaps
WHEN: calculateStreakAndRewards() aufgerufen
THEN: streak = 1 (nur letzter Tag), erster Gap geheilt, zweiter bricht Streak
```

### Test 6: Heute nicht geloggt wird toleriert
```
GIVEN: Gestern hatte Aktivität, heute keine
WHEN: calculateStreakAndRewards() aufgerufen
THEN: streak = 1 (gestern zählt), kein Penalty für heute
```

### Test 7: Earn before Consume (Tag 7 Edge Case)
```
GIVEN: 6 Tage mit Aktivität, Tag 7 ist Gap
WHEN: calculateStreakAndRewards() aufgerufen
THEN: streak = 7 (Joker wird erst verdient, dann sofort verbraucht)
```

### Test 8: Maximum 3 Joker Cap
```
GIVEN: 28 Tage mit Aktivität (würde 4 Joker verdienen)
WHEN: calculateStreakAndRewards() aufgerufen
THEN: streak = 28, availableRewards = 3 (gedeckelt)
```

### Test 9: Leere Daten
```
GIVEN: Keine Aktivitätsdaten
WHEN: calculateStreakAndRewards() aufgerufen
THEN: streak = 0, rewards = 0
```

### Test 10: Nur heute geloggt
```
GIVEN: Nur heute hat Aktivität
WHEN: calculateStreakAndRewards() aufgerufen
THEN: streak = 1, rewards = 0
```

### Test 11: Minimum-Threshold (< 2 min = Fehltag)
```
GIVEN: 7 Tage, davon Tag 4 mit nur 1.5 min
WHEN: calculateStreakAndRewards() aufgerufen
THEN: Tag 4 gilt als Fehltag, braucht Joker
```

### Test 12: Runden auf 2 min
```
GIVEN: Tag hat 1.8 min (rundet auf 2)
WHEN: calculateStreakAndRewards() aufgerufen
THEN: Tag zählt als guter Tag (round(1.8) = 2)
```

---

## XCUITests

Keine XCUITests erforderlich - reine Backend-Logik ohne UI-Änderungen.

---

## Manuelle Tests

### Test M1: Streak-Anzeige nach Joker-Heilung
```
GIVEN: User hat 7+ Tage Meditation-Streak
AND: User überspringt einen Tag
WHEN: User öffnet Erfolge-Tab am nächsten Tag
THEN: Streak zeigt 8+ Tage (nicht 0)
AND: Joker-Anzeige zeigt 0 (verbraucht)
```

### Test M2: Streak bricht nach Joker-Erschöpfung
```
GIVEN: User hat 7 Tage Streak (1 Joker)
AND: User überspringt 2 Tage
WHEN: User öffnet Erfolge-Tab
THEN: Streak zeigt 1 Tag (nur heute)
AND: Joker-Anzeige zeigt 0
```
