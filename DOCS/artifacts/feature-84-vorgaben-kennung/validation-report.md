# Validation Report: feature-84-vorgaben-kennung (A2c-1, #84)

Stand: 2026-11-20, geprüfter Code-Stand `e6e8f35`.

## Test Results

- Unit-Suite (`LeanHealthTimerTests`, iPhone 17 Pro / iOS 27.2, `-parallel-testing-enabled NO`):
  `Executed 263 tests, with 0 failures` (XCTest) plus `Test run with 1 test … passed` (Swift Testing) = 264/264.
  - AC-27 `ExerciseCatalogTests.test_defaultPrograms_referenceExistingCatalogIds`: passed
  - AC-30 `WorkoutPhaseMigrationTests.test_existingUserStore_unchangedAfterPresetMigration`: passed
- AC-28 `WorkoutHintUITests/test_infoButton_forPresetPlanke_showsContent` über `Scripts/run-uitests.sh`:
  `Test Case '-[LeanHealthTimerUITests.WorkoutHintUITests test_infoButton_forPresetPlanke_showsContent]' passed (168.712 seconds)`.
  Reiner Regressionsschutz (war vor A2c-1 schon grün über den Namens-Rückfall); den Kennungsnachweis liefert AC-27.

Umfeld: Die ersten beiden Läufe der Unit-Suite mit Standard-Parallelisierung brachen mit
„The test runner hung before establishing connection" ab, ohne einen Test auszuführen (Simulator-Klon startet den
Runner nicht, bekannt aus #23; `Scripts/run-uitests.sh` setzt deshalb schon `-parallel-testing-enabled NO`).
Ohne Parallelisierung lief die Suite sofort. Kein Produktbezug.

## Spec Compliance

- AC-27, AC-28, AC-30 erfüllt (Codeprüfung durch unabhängigen Prüfer plus Tests).
- AC-31 (A2c-1-Anteil): keine Änderung an Watch, Widget, `Info.plist`, Entitlements, `workoutProgramSets`, `speakExerciseNames`.
- Spec-Korrektur offen: Verweis auf `legacyDefaultWorkoutSets` ist veraltet (bereits durch #101 entfernt). Die freigegebene
  Spec bleibt in dieser Runde unverändert (Gate: Änderung nach Freigabe verlangt neue Freigabe); Nachzug samt Abhaken von
  AC-27/28/30 in Runde A2c-2 (#85), als Kommentar dort vermerkt.
- Hinweis ohne Handlungsbedarf: „leere Beschreibung" meint `nil`; eine gespeicherte `""` wird wie vorher nicht nachgefüllt.

## Regression Check

- Keine Regressionen: komplette Unit-Suite grün (vorher 5 erwartete Rotfälle späterer Schnitte, jetzt 0).

## Scope Check

- Swift-Dateien: 4 (2 Produkt, 2 Test), +62/−41 Zeilen. Limit 5 Dateien / 250 Zeilen eingehalten.
- Keine Änderungen außerhalb der Spec.

## App-Durchlauf (Simulator, iPhone 17 Pro / iOS 27.2)

Wegwerf-Kopie (`git archive HEAD`), nur um Bildschirmfotos ergänzter AC-28-Ablauf, App vorher deinstalliert:
Workout-Tab öffnen → „Core Circuit" starten → Training zeigt „Planke" mit Info-Knopf → Info-Knopf → Blatt „Planke" mit
Wirkung und Anleitung. Belege: `walk-1-programme.png`, `walk-2-training.png`, `walk-3-info-planke.png`.

## Result: PASS
