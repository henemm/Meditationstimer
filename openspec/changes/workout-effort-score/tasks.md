# Tasks: Workout Effort Score

## 1. HealthKitManager erweitern

- [ ] Permission für `workoutEffortScore` in `requestAuthorization()` hinzufügen
- [ ] Neue Methode `relateEffortScore(score: Int, workout: HKWorkout)`
- [ ] iOS 18+ Availability Check (`@available(iOS 18, *)`)

## 2. WorkoutTab UI

- [ ] State: `@State private var showEffortSheet = false`
- [ ] State: `@State private var effortScore: Double = 7`
- [ ] State: `@State private var lastWorkout: HKWorkout?`
- [ ] Sheet mit Slider (1-10) und OK-Button
- [ ] Sheet nach `endSession()` anzeigen
- [ ] Bei OK: `HealthKitManager.shared.relateEffortScore()` aufrufen

## 3. Tests

- [ ] Unit Test: `relateEffortScore()` mit Mock
- [ ] UI Test: Sheet erscheint nach Workout
