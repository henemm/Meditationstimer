# Validation Report: feature-117-stabile-kennungen (2026-11-25)

## Test Results
- Unit-Suite: Executed 459 tests, 0 failures (inkl. 10/10 StableDefaultIdsTests, AC-1 bis AC-8, AC-10)
- UI-Suite: 92 passed, 2 failed — beide Altfehler, identisch auf origin/main reproduziert:
  - BackgroundMeditationUITests/test_breathingExercise_backgroundForeground_sessionStillRunning („Kein Atem-Preset gefunden“, sucht nie existierende Namen; #30/#32)
  - BackgroundMeditationUITests/test_freeWorkout_backgroundForeground_sessionStillRunning („Freies Workout wurde beim Hintergrund-Wechsel beendet“; #30)

## Spec Compliance
- 10/10 Golden-Kennungen im Code identisch mit Spec-Tabelle; Vorgaben nur an je einer Stelle definiert
- AC-1 bis AC-10 erfüllt (AC-9: Unit-Suite grün)

## Regression Check
- Keine Regressionen (UI-Fehler auf altem App-Stand identisch)

## Scope Check
- App-Code: 3 Dateien, +22/-12 (MeditationTab, WorkoutTab, WorkoutProgramsView) — innerhalb Spec
- Außerhalb: nur Versionsmarker in 4 Befehlsvorlagen (Alias-Auffrischung), kein App-Code

## Durchlauf
- Simulator iPhone 17 Pro / iOS 27.2: App mit neuem Stand gebaut, installiert, gestartet; Atemübungen sichtbar (Box Breathing an erster Stelle)

## Result: PASS
