# Feature: Round Announcement "X of Y"

## Status: SPEC_WRITTEN

## Was
Voice-Ansage bei Workout-Runden von "Round X" auf "Round X of Y" ändern.

## Warum
- Benutzer weiß aktuell nicht, wie viele Runden insgesamt geplant sind
- Bessere Orientierung während des Workouts
- Konsistenz mit AtemView UI (zeigt bereits "Round X / Y")

## Aktuell
```
"Round 3"        (EN)
"Runde 3"        (DE)
```

## Neu
```
"Round 3 of 10"  (EN)
"Runde 3 von 10" (DE)
```

## Scope

| Datei | Änderung |
|-------|----------|
| `WorkoutSoundPlayer.swift` | `playRound(_ number: Int, of total: Int)` Signatur |
| `WorkoutsView.swift` | Format + Aufruf anpassen |
| `WorkoutTab.swift` | Format anpassen (2 Stellen) |
| `WorkoutProgramsView.swift` | Format anpassen |
| `Localizable.xcstrings` | Neue Übersetzung hinzufügen |

## Nicht betroffen
- "Last round" Ansage bleibt unverändert
- AtemView (hat bereits korrektes UI-Format)

## Risiko
Gering - nur String-Format-Änderung, keine Logik-Änderung.
