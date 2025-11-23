# Übungsnamen Lokalisierung (Bug 25)

**Erstellt:** 23. November 2025
**Status:** Implementiert in Localizable.xcstrings

---

## Übungsnamen (46 Einträge)

| Deutsch | English |
|---------|---------|
| Ausfallschritte | Lunges |
| Ausfallschritte gehend | Walking Lunges |
| Beinheben | Leg Raises |
| Beinpendel links | Leg Swings Left |
| Beinpendel rechts | Leg Swings Right |
| Breite Liegestütze | Wide Push-Ups |
| Bulgarische Split-Kniebeugen links | Bulgarian Split Squats Left |
| Bulgarische Split-Kniebeugen rechts | Bulgarian Split Squats Right |
| Burpees | Burpees |
| Butt Kicks | Butt Kicks |
| Diamond-Liegestütze | Diamond Push-Ups |
| Einbeiniges Kreuzheben links | Single-Leg Deadlift Left |
| Einbeiniges Kreuzheben rechts | Single-Leg Deadlift Right |
| Fahrrad-Crunches | Bicycle Crunches |
| Glute Bridges | Glute Bridges |
| Hampelmänner | Jumping Jacks |
| Hamstring-Dehnung links | Hamstring Stretch Left |
| Hamstring-Dehnung rechts | Hamstring Stretch Right |
| High Knees | High Knees |
| Hüftbeuger-Dehnung links | Hip Flexor Stretch Left |
| Hüftbeuger-Dehnung rechts | Hip Flexor Stretch Right |
| Hüftkreisen | Hip Circles |
| Jump-Kniebeugen | Jump Squats |
| Kindspose | Child's Pose |
| Kniebeugen | Squats |
| Knieheben stehend | Standing Knee Raises |
| Liegestütze | Push-Ups |
| Marschieren auf der Stelle | Marching in Place |
| Mountain Climbers | Mountain Climbers |
| Pike-Liegestütze | Pike Push-Ups |
| Planke | Plank |
| Planke (Knie) | Knee Plank |
| Planke zu Herabschauender Hund | Plank to Downward Dog |
| Quadrizeps-Dehnung links | Quad Stretch Left |
| Quadrizeps-Dehnung rechts | Quad Stretch Right |
| Reverse-Ausfallschritte | Reverse Lunges |
| Russian Twists | Russian Twists |
| Schmetterlings-Dehnung | Butterfly Stretch |
| Seitliche Planke links | Side Plank Left |
| Seitliche Planke rechts | Side Plank Right |
| Waden-Dehnung links | Calf Stretch Left |
| Waden-Dehnung rechts | Calf Stretch Right |
| Wadenheben | Calf Raises |
| Wandliegestütze | Wall Push-Ups |
| Hintere Kette | Posterior Chain |
| Neues Workout | New Workout |

---

## Workout-Namen (bleiben international)

Diese Namen sind bereits englisch oder international gebräuchlich:

| Name | Anmerkung |
|------|-----------|
| Beginner Flow | International |
| Core Circuit | International |
| Full Body Burn | International |
| Jogging Warm-up | International |
| Post-Run Stretching | International |
| Power Intervals | International |
| Quick Burn | International |
| Tabata Classic | International |
| Upper Body Push | International |

---

## Test-Anweisungen

### Im Simulator (ohne Device):
1. Scheme "Lean Health Timer (EN)" auswählen
2. Build & Run im Simulator
3. Workouts-Tab öffnen
4. Workout aufklappen → Übungsnamen prüfen
5. **Erwartung:** "Squats" statt "Kniebeugen"

### Auf Device:
1. iPhone-Sprache auf Englisch stellen
2. App starten
3. Workouts prüfen

---

## Technische Umsetzung

**Dateien geändert:**
- `Localizable.xcstrings` - 46 neue Einträge
- `WorkoutProgramsView.swift` - 6 Stellen: `Text(name)` → `Text(LocalizedStringKey(name))`

**Code-Pattern:**
```swift
// Vorher (nicht lokalisiert):
Text(phase.name)

// Nachher (lokalisiert):
Text(LocalizedStringKey(phase.name))
```
