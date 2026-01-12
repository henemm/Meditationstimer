# Tests: Round Announcement "X of Y"

## Unit Tests

### Test 1: WorkoutSoundPlayer.playRound Format

```
GIVEN: WorkoutSoundPlayer instance
WHEN: playRound(3, of: 10) is called
THEN: speak() receives "Round 3 of 10" (EN) or "Runde 3 von 10" (DE)
```

**Datei:** `LeanHealthTimerTests/WorkoutSoundPlayerTests.swift`

### Test 2: Format String Localization EN

```
GIVEN: Locale is EN
WHEN: String(format: NSLocalizedString("Round %d of %d", ...), 3, 10)
THEN: Result is "Round 3 of 10"
```

### Test 3: Format String Localization DE

```
GIVEN: Locale is DE
WHEN: String(format: NSLocalizedString("Round %d of %d", ...), 3, 10)
THEN: Result is "Runde 3 von 10"
```

## XCUITests

### Test 4: Voice Announcement während Workout

```
GIVEN: Free Workout mit 5 Runden konfiguriert
WHEN: Workout läuft und Rest-Phase beginnt
THEN: (Manuell verifizieren) Voice sagt "Round 2 of 5" statt "Round 2"
```

**Hinweis:** TTS-Output kann nicht automatisch geprüft werden.
Manueller Test auf Device erforderlich.

## Manuelle Tests (Device)

### Test 5: Free Workout Voice Check

1. Workout Tab öffnen
2. Free Workout: 3 Runden, 10s Work, 5s Rest
3. Start drücken
4. **Erwartung:** Nach erster Work-Phase hören: "Round 2 of 3"
5. **Erwartung:** Vor letzter Runde hören: "Last round"

### Test 6: Workout Program Voice Check

1. Workout Tab öffnen
2. Ein Workout-Programm mit 4 Runden starten
3. **Erwartung:** Ansagen enthalten "of 4" bzw. "von 4"

### Test 7: Deutsche Lokalisierung

1. iPhone auf Deutsch stellen
2. Free Workout mit 5 Runden starten
3. **Erwartung:** "Runde 2 von 5" hören
