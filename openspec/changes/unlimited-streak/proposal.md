# Unbegrenzte Streak-Berechnung

## Zusammenfassung

Die Streak-Berechnung für Meditation und Workout soll nicht mehr auf 30 Tage begrenzt sein, sondern unbegrenzt zurückgehen.

## Problem

Die Streak-Berechnung für Meditation und Workout stoppt bei ca. 90 Tagen, obwohl User längere Streaks haben. Die Limitierung entsteht durch:

1. **StreakManager** (`Services/StreakManager.swift:40`): Lädt nur 30 Tage
2. **CalendarView** (`CalendarView.swift:368`): Lädt nur -6 Monate, Streak-Berechnung nutzt nur geladene Daten

**Beobachtung:** User sieht im Frontend (ErfolgeTab/CalendarView) maximal ~90 Tage Streak für Meditation und Workout.

## Lösung: Expand-on-Demand

Statt alle Daten auf einmal zu laden, erweitern wir das Zeitfenster nur wenn nötig:

```
1. Lade erste 30 Tage
2. Berechne Streak rückwärts
3. WENN Streak bis zum ältesten geladenen Tag reicht:
   → Lade weitere 30 Tage
   → Wiederhole Schritt 2-3
4. SONST: Streak ist gefunden (bricht vor dem Rand ab)
5. Safety-Limit: Max 40 Batches (~3.3 Jahre)
```

## Warum dieser Ansatz?

| Aspekt | Vorteil |
|--------|---------|
| **Performance** | 90% der User haben kurze Streaks (<30 Tage) → nur 1 Query |
| **Skalierbarkeit** | Lange Streaks laden nur so viele Batches wie nötig |
| **HealthKit** | Queries sind nach Datum indexiert = schnell |
| **Speicher** | Keine riesigen Datenmengen im RAM |

## Betroffene Komponenten

| Datei | Änderung |
|-------|----------|
| `Services/StreakManager.swift` | Neuer `calculateExpandingStreak()` Algorithmus |
| `Meditationstimer iOS/CalendarView.swift` | Lokale Streak-Berechnung anpassen |
| `openspec/specs/features/streaks-rewards.md` | Spec aktualisieren (30 → unlimited) |

## Nicht betroffen

- NoAlc-Streak (hat eigene Logik in NoAlcManager)
- Tracker-Streaks (SwiftData-basiert, nicht HealthKit)
- UI/Design (keine visuellen Änderungen)

## Risiko

**Niedrig** - Isolierte Änderung der Berechnungslogik, keine UI-Änderungen.
