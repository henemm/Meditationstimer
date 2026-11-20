# Validation Report: feature-85-aufraeumen (A2c-2, #85)

Stand: 2026-11-20, Commit 49d5f5e, Simulator iPhone 17 Pro / iOS 27.2.

## Test Results
- Build: iOS-Scheme „Lean Health Timer“ (im Testlauf), „Meditationstimer Watch App“ und „MeditationstimerWidgetExtension“: `** BUILD SUCCEEDED **`.
- Unit-Suite (`-only-testing:LeanHealthTimerTests -parallel-testing-enabled NO`): `Executed 263 tests, with 0 failures` (XCTest) plus 10 Swift-Testing-Tests ohne Fehler. Gleicher Umfang wie #84 (263 XCTest + 10).
- UI-Suite komplett (`./Scripts/run-uitests.sh`, 56 min): 72 bestanden, 20 übersprungen, 3 rot (`ui-suite-summary.txt`).

## Regression Check (UI, 3 rote Tests)
- `BackgroundMeditationUITests/test_explicitStop_endsSession`: im Komplettlauf rot mit „VORBEDINGUNG FEHLGESCHLAGEN … Sitzung ließ sich nicht starten“, im Einzellauf auf demselben Stand grün (`ui-explicitstop-einzellauf.txt`). In #83 grün. Meditationsbereich, von #85 nicht berührt: instabile Vorbedingung, kein Regressionsbefund (bekannt: #30).
- `BackgroundMeditationUITests/test_breathingExercise_backgroundForeground_sessionStillRunning`: auch in #83 rot; Test sucht Preset-Namen, die es nie gab (#32, Altlast vor #48).
- `LeanHealthTimerUITests/testGuidedWorkoutPauseButtonIsBelowProgressRing`: schon in der Bestandsaufnahme #25 (vor #48) rot; Einordnung als Testschuld in #83 belegt. Fachlich zeigt `walk-3-training.png` die Pause unter dem Ring.
- Keine Test-Regression gegenüber #83; die 15 Tracker-Fehlschläge aus #83 sind inzwischen grün.

## Spec Compliance
- AC-29: Codesuche `exerciseSuggestions` = 0, `legacyDefault` = 0, MARK „Placeholder for Phase 1“ = 0 (`codesuche-green.txt`, erneut bestätigt). Erfüllt.
- AC-26: `openspec/specs/features/workouts.md` enthält „Exercise Hint Line“, „Exercise Hint TTS“, „Exercise Catalog Identifiers“ sowie die Korrekturen „Program Selection“ (4 Vorgaben, Kennungen) und „Exercise Name TTS (Workout Programs)“ (vier Sätze, Pausenbeginn). Erfüllt.
- Test Plan A2c-2 Punkte (1)–(6): erfüllt, (4) mit den oben einzeln ausgewiesenen Ausnahmen.

## App-Durchlauf (Simulator, Wegwerf-Kopie des Stands 49d5f5e)
Core Circuit bearbeiten → Schritt 1 → Auswahl „Planke“ aus dem Katalog → Hinweis „12 Wiederholungen, langsam“ → speichern → Training starten: Hinweis steht unter dem Ring. Belege `walk-1-auswahl.png`, `walk-2-hinweis.png`, `walk-3-training.png`, Testcode `WalkHintUITests.swift.txt`, Ergebnis `walk-summary.txt` (passed).

## Scope Check
- Produkt: 1 Datei, `WorkoutProgramsView.swift` +1/−87 (reine Löschung). Doku: `workouts.md` +41, Spec +13/−12, Briefing und Kontext des Workflows.
- Keine Änderungen außerhalb der Spec; Watch, Widget, `Localizable.xcstrings` unberührt.

## Adversary
VERIFIED, Dialog valid (8 Punkte, 2 Runden).

### Result: PASS
