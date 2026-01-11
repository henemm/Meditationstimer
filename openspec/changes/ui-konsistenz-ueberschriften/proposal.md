# UI-Konsistenz: Überschriften und Textformatierung

## Problem

Die Überschriften "Offene Meditation" und "Freies Workout" sind inkonsistent formatiert im Vergleich zu "Atemübungen" und "Workout-Programme":

1. **Position:** Überschriften sind INNERHALB der grauen GlassCard statt darüber
2. **Schriftgröße:** `.font(.title3)` statt `.font(.headline)`
3. **Großbuchstaben:** `.textCase(.uppercase)` wird verwendet, aber nicht bei den anderen Sektionen

## Lösung

Überschriften vereinheitlichen:
- "Offene Meditation" und "Freies Workout" **über** die GlassCard verschieben
- Gleiche Formatierung wie "Atemübungen" / "Workout-Programme"
- `.textCase(.uppercase)` bei allen Labels in den Cards entfernen

## Visuelle Änderung

### Vorher (MeditationTab)
```
┌─────────────────────────────┐
│ OFFENE MEDITATION (i)       │  ← Innerhalb der Card, UPPERCASE
│                             │
│ 🧘  DURATION    [Picker]    │  ← Labels UPPERCASE
│ 🪷  CLOSING     [Picker]    │
│         [▶]                 │
└─────────────────────────────┘

Breathing Exercises            ← Außerhalb, normal
┌─────────────────────────────┐
│ Box Breathing               │
└─────────────────────────────┘
```

### Nachher (MeditationTab)
```
Open Meditation (i)            ← Außerhalb der Card, headline style
┌─────────────────────────────┐
│ 🧘  Duration    [Picker]    │  ← Labels normal (kein UPPERCASE)
│ 🪷  Closing     [Picker]    │
│         [▶]                 │
└─────────────────────────────┘

Breathing Exercises
┌─────────────────────────────┐
│ Box Breathing               │
└─────────────────────────────┘
```

## Betroffene Dateien

| Datei | Änderung |
|-------|----------|
| `MeditationTab.swift` | Überschrift herausziehen, `.textCase(.uppercase)` entfernen |
| `WorkoutTab.swift` | Überschrift herausziehen, `.textCase(.uppercase)` entfernen |

## Nicht betroffen

- Logik bleibt unverändert
- InfoButton-Funktionalität bleibt
- GlassCard-Inhalt (Picker, Button) bleibt
