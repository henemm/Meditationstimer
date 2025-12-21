# Feature: Workout Effort Score

## Was
Nach HIIT-Workout-Ende erscheint ein Sheet zur Eingabe der Anstrengung (1-10 Skala).
Der Wert wird in HealthKit als `workoutEffortScore` gespeichert und fließt in Apple Training Load ein.

## Warum
- Apple berechnet `estimatedWorkoutEffortScore` nur für Walking, Running, Hiking, Cycling
- HIIT-Workouts haben keinen automatischen Effort Score
- Mit manuellem Score fließen HIIT-Workouts in Training Load ein

## UX-Flow

```
Workout endet
    ↓
Sheet erscheint: "Wie anstrengend war das?"
Slider 1-10, Default: 7 (Schwer)
    ↓
User tippt "OK" oder passt an
    ↓
Effort Score wird mit Workout verknüpft
    ↓
Erscheint in Fitness App → Training Load
```

## Technische Details

- API: `healthStore.relateWorkoutEffortSample(_:with:activity:)` (iOS 18+)
- Einheit: `HKUnit.appleEffortScore()`
- Typ: `HKQuantityTypeIdentifier.workoutEffortScore`

## Scope

| Datei | Änderung |
|-------|----------|
| `HealthKitManager.swift` | Neue Methode `relateEffortScore(score:workout:)`, Permission ergänzen |
| `WorkoutTab.swift` | Sheet nach Workout-Ende mit Slider |

**Geschätzt:** ~80 LoC, 2 Dateien
