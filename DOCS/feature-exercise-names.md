# Feature: Übungsnamen Konsistenz

## Bug-Referenz
**Bug 25:** Übungsnamen inkonsistent lokalisiert

## Status: Teilweise behoben durch Bug 18

### Was wurde bereits gefixt (Bug 18, Commit 9942d46)

Die **WorkoutPhase Namen** in `WorkoutProgramsView.swift` wurden auf die deutschen **ExerciseDatabase Namen** geändert:

| Vorher (EN) | Nachher (DE) |
|-------------|--------------|
| Plank | Planke |
| Squats | Kniebeugen |
| Push-Ups | Liegestütze |
| Jumping Jacks | Hampelmänner |
| Mountain Climbers | Bergsteiger |
| ... | ... (31 Übungen total) |

**Ergebnis:** ExerciseDatabase Lookup funktioniert jetzt → Info-Sheets zeigen Übungsdetails.

## Verbleibende Fragen

### 1. Englische App-Version

In der **EN-Version** werden jetzt deutsche Übungsnamen angezeigt (z.B. "Kniebeugen" statt "Squats").

**Optionen:**
- **A) So lassen:** Deutsche Namen sind auch im Fitness-Bereich verbreitet
- **B) Lokalisieren:** Übungsnamen auch per NSLocalizedString → EN zeigt "Squats"

### 2. Namens-Konvention

Die ExerciseDatabase verwendet eine **sinnvolle Mischung**:

| Deutsch (üblich) | Englisch (Fachbegriff) |
|------------------|------------------------|
| Kniebeugen | Burpees |
| Liegestütze | Mountain Climbers |
| Planke | High Knees |
| Ausfallschritte | Russian Twists |
| Hampelmänner | Glute Bridges |

Diese Mischung ist **beabsichtigt** - deutsche Begriffe wo im Deutschen üblich, englische Fachbegriffe wo sie auch im Deutschen verwendet werden.

### 3. Fehlende "Rechts"-Übungen?

Die ursprüngliche Bug-Beschreibung erwähnte: *"Leg Swing Left" ohne "Leg Swing Right"*

**Aktuelle Situation in ExerciseDatabase:**
- ✅ `Seitliche Planke links` + `Seitliche Planke rechts`
- ✅ `Quadrizeps-Dehnung links` + `Quadrizeps-Dehnung rechts`
- ✅ `Hamstring-Dehnung links` + `Hamstring-Dehnung rechts`
- ✅ `Hüftbeuger-Dehnung links` + `Hüftbeuger-Dehnung rechts`
- ✅ `Waden-Dehnung links` + `Waden-Dehnung rechts`
- ✅ `Einbeiniges Kreuzheben links` + `Einbeiniges Kreuzheben rechts`
- ✅ `Bulgarische Split-Kniebeugen links` + `Bulgarische Split-Kniebeugen rechts`

**→ Alle links/rechts Paare sind vollständig!**

Das "Leg Swing Left/Right" Problem bezog sich wahrscheinlich auf die **WorkoutPhase Definitionen**, nicht die ExerciseDatabase.

## Empfehlung

### Bug 25 als "Kein Handlungsbedarf" schließen

**Begründung:**
1. ✅ Namen-Konsistenz wurde mit Bug 18 hergestellt
2. ✅ Links/Rechts Paare sind in ExerciseDatabase vollständig
3. ✅ Mischung DE/EN ist beabsichtigt und sinnvoll

### Für EN-Version: Zusammenführen mit Bug 19

Die Lokalisierung der **Übungsnamen** sollte gemeinsam mit der Lokalisierung der **effect/instructions Texte** (Bug 19) erfolgen.

→ Siehe: `DOCS/feature-exercise-localization.md`

## Offene Fragen an Henning

1. **Bug 25 schließen?** Die ursprünglichen Probleme scheinen behoben zu sein.

2. **EN-Version Übungsnamen:** Sollen "Kniebeugen" etc. in EN auch zu "Squats" werden? (Dann zusammen mit Bug 19 implementieren)

3. **Workout-Programme prüfen:** Fehlen in den konkreten Workout-Programmen (Warmup, HIIT, Cooldown) noch Übungen wie "Leg Swing Right"?
