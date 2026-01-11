# StreakManager Joker-System

## Zusammenfassung

Der StreakManager für Meditation und Workout soll das **Universal Joker System** erhalten, wie es bereits für NoAlc implementiert ist. Rewards werden von dekorativen Indikatoren zu funktionalen Jokern, die Fehltage heilen können.

## Motivation

**Problem:** Aktuell sind Meditation/Workout Rewards nur dekorativ (`streak / 7`). Bei einem Fehltag bricht der Streak sofort - es gibt keine Vergabung.

**Lösung:** Joker-System implementieren, das:
- Alle 7 gute Tage einen Joker verdient
- Fehltage mit verfügbarem Joker heilen kann
- Forward Iteration verwendet (Earn before Consume)

## IST vs. SOLL

| Aspekt | IST (aktuell) | SOLL (nach Änderung) |
|--------|---------------|----------------------|
| Reward-Berechnung | `streak / 7` (dekorativ) | `earned - consumed` (funktional) |
| Fehltag-Verhalten | Streak bricht sofort | Joker kann heilen |
| Iteration | Backward (heute → Vergangenheit) | Forward (Vergangenheit → heute) |
| Gap-Erkennung | Keine | Gap = Fehltag |

## Betroffene Dateien

| Datei | Änderung |
|-------|----------|
| `Services/StreakManager.swift` | `updateStreak()` komplett refactoren, neue `calculateStreakAndRewards()` Methode |
| `LeanHealthTimerTests/StreakManagerTests.swift` | Neue Unit Tests für Joker-Logik |

## Scope

- **Dateien:** 2
- **Geschätzte LoC:** +150 (80 Code + 70 Tests)
- **Risiko:** Mittel (bestehende Streak-Anzeige könnte sich ändern)

## Nicht im Scope

- UI-Änderungen (Rewards werden bereits angezeigt)
- Tracker-Streaks (haben eigene Logik)
- NoAlc (bereits implementiert)

## Referenzen

- `openspec/specs/features/streaks-rewards.md` - Universal Joker System Spec
- `Services/NoAlcManager.swift` - Referenz-Implementierung
- `LeanHealthTimerTests/NoAlcStreakTests.swift` - Referenz-Tests
