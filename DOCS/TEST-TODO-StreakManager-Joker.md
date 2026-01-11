# TEST-TODO: StreakManager Joker-System

**Erstellt:** 2026-01-11
**Status:** Ausstehend - User muss lokal testen

---

## Kritik an existierenden Tests

Die Tests in `StreakManagerJokerTests.swift` sind **Fake-TDD**:
- Rufen `calculateStreakAndRewards()` auf (NEUE Methode)
- Echter TDD hätte ALTE `updateStreak()` testen müssen
- Tests kompilieren nur weil Methode bereits existiert

---

## Manuelle Test-Checkliste

### 1. Unit Tests ausführen
```bash
xcodebuild test \
  -project Meditationstimer.xcodeproj \
  -scheme "MeditationstimerTests" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:LeanHealthTimerTests/StreakManagerJokerTests \
  2>&1 | tee test_output.log
```

**Erwartetes Ergebnis:** Alle 14 Tests GRÜN

---

### 2. Integration testen (App starten)

| Test | Schritte | Erwartung |
|------|----------|-----------|
| **7 Tage Streak** | 7 Tage meditieren (je 2+ min) | Streak = 7, Joker = 1 |
| **Gap heilen** | Nach 7 Tagen, 1 Tag überspringen, dann wieder | Streak = 9, Joker = 0 |
| **Streak bricht** | Nur 5 Tage, dann 2 Tage überspringen | Streak = 1 (nur heute) |

---

### 3. Persistence testen

1. App öffnen → Streak notieren
2. App beenden (aus Multitasking entfernen)
3. App neu starten
4. **Prüfen:** Streak, rewardsEarned, rewardsConsumed identisch?

---

### 4. Migration testen (alte Daten)

Falls alte UserDefaults existieren ohne `rewardsConsumed`:
1. App updaten
2. **Prüfen:** Kein Crash, `rewardsConsumed` = 0

---

## Nach Tests

Wenn alle Tests bestanden:
```bash
python3 .claude/hooks/update_state.py tests_written --user-verified
```

---

## Offene Fragen

1. Soll UI angepasst werden um `availableRewards` vs `rewardsEarned` zu unterscheiden?
2. Wie soll "Joker verbraucht" dem User kommuniziert werden?
