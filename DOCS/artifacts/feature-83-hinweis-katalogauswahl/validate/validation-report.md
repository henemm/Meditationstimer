# Validation Report: feature-83-hinweis-katalogauswahl (A2b)

Stand: 7f2ea36, 2026-11-17, Simulator iPhone 17 Pro iOS 27.2

## Test Results
- Unit-Suite voll (`-only-testing:LeanHealthTimerTests`, nichts übersprungen): 261 passed, 2 failed (`unit-suite-summary.txt`). Die 2 Rotfälle sind laut Spec A2c-1: `test_existingUserStore_unchangedAfterPresetMigration`, `test_defaultPrograms_referenceExistingCatalogIds`.
- Die ersten drei Unit-Läufe starteten auf dem Stamm-Simulator gar nicht („The test runner hung before establishing connection“, auch mit vorgestartetem Simulator und getrenntem Bauen). Laut Recherche ein Simulator-Zustandsproblem (Bitrise 9676554, CircleCI „exit code 65“, Apple-Forum 805060). Lauf auf frisch angelegtem Simulator „Val83“ grün bis auf die erwarteten zwei.
- UI-Suite voll (`-parallel-testing-enabled NO`): 99 ausgeführt, 20 übersprungen, 16 Fehlschläge (`ui-suite-summary.txt`). Alle 8 `WorkoutHintUITests` grün, `WorkoutSoundUITests` grün.

## Spec Compliance (AC-18 bis AC-25)
- Unabhängiger Abgleich (nur Lesen): 8/8 erfüllt, je AC mindestens ein Test. Adversary VERIFIED (8 Punkte, 2 Runden).
- Kosmetik ohne Handlungsbedarf: DE-Wert „Eigene Übung...“ (drei Punkte) ist laut Spec-Tabelle Altbestand, „keine Änderung“.

## App-Durchlauf (Wegwerf-Kopie per `git archive`, eigener Simulator „Walk83“, `WalkHintUITests.swift.txt`, passed)
1. DE: Core Circuit → Schritt 1: Auswahlmenü zeigt deutsche Katalognamen mit Haken bei „Planke“ (`03-auswahlmenue-de.png`). Hinweis „12 Wiederholungen, langsam“ eingegeben, gespeichert (`04`).
2. DE Training: Hinweis steht unter dem Ring mit „Planke“/„Übung“, über dem Zähler, Pause-Knopf frei darunter (`05-training-hinweis-de.png`).
3. EN nach Neustart: Schrittdialog „Edit Exercise“, Auswahl „Plank“, Hinweis erhalten (`06`); Training zeigt den Hinweis (`07`).

## Regression Check
- 15 der 16 UI-Fehlschläge sind Tracker-Tests aus der Bestandsaufnahme #25 (Cluster A/B/C, Trackerbereich unberührt).
- `testGuidedWorkoutPauseButtonIsBelowProgressRing`: in #25 schon rot (damals :2261, Play-Knopf). Jetzt rot an :2278, weil `app.buttons["info.circle"]` mehrere Elemente findet (Abfrage nicht eindeutig). Einzellauf auf Stand vor A2b und auf A2b: beide übersprungen („HealthKit may have blocked“), also kein Unterschied messbar. Was der Test fachlich prüft (Pause unter dem Ring, frei antippbar), zeigt `05-training-hinweis-de.png` erfüllt. Einordnung als Testschuld, vermerkt in #25.

## Scope Check
- Produkt: `WorkoutProgramsView.swift` +142/-69, `ExerciseDetailSheet.swift` +4/-1, `Localizable.xcstrings` +34 = 250 Zeilen, 3 Dateien, alle laut Spec-Schnitt A2b. Tests: `WorkoutHintUITests.swift`, `WorkoutPhaseMigrationTests.swift` (RED und dokumentierte RED-Nachbesserung).

## Dokumentation
- Spec im Schnitt nachgezogen (d29e879); keine Architekturänderung, CLAUDE.md unverändert.

## Nebenbefund Werkzeug
- `Scripts/run-uitests.sh` sucht iOS 26.5, vorhanden ist nur 27.2: Skript bricht ab; Läufe dieser Runde direkt mit `xcodebuild`.

## Result: PASS
