# Validation Report: feature-51-s2-bausteine-anwenden (Runde 2a-1)

Datum: 2026-11-20 · Stand: 5c4dbcd · Spec: `DOCS/specs/features/feature-51-s2-bausteine-anwenden.md`

## Test Results
- Unit-Suite `LeanHealthTimerTests`: **Executed 293 tests, 0 failures** (`validate-unit.txt`), davon `ClaudeApplyTests` 19/19
- UI `ClaudeFelderUITests/testProgrammeUndAtemuebungenUeberstehenNeustart`: passed, Iteration 1 von 3 (`validate-uitests.txt`)
- UI `WorkoutHintUITests/test_pickedExercise_persistsAfterRelaunch`: passed, Iteration 1 von 3 (`validate-uitests.txt`)
- Build Watch App und WidgetExtension: je `BUILD SUCCEEDED`, je Ziel einzeln benannt (`validate-build.txt`)

## Spec Compliance
- ACs der Runde 2a-1 (1a, 3, 4, 5, 6a, 7, 8a, 13a, 14, 15, 20, 22): alle erfüllt, jeweils mit Test und echter Assertion belegt.
- AC-19: erfüllt (Unit-Suite grün, Builds aller Ziele grün, App-Diff 136 Zeilen, längste Funktion `apply` 24 Zeilen).
- AC-21 (Start-Nachweis): erfüllt laut `ac21/ac21-bericht.md`; Vergleich vorher/nachher unabhängig nachgerechnet (Listen nach Entfernen von `claude`/`modifiedAt` identisch, kein Sicherungsschlüssel). Kleine Abweichungen vom Spec-Wortlaut, nicht inhaltlich: Bundle-ID des Simulatorlaufs `henemm.Meditationstimer-iOS` statt `…dev2` (im Bericht begründet); Screenshots zeigen nur den ersten Eintrag, die übrigen Namen belegen die Text-Abzüge.

## Regression Check
- Keine Regressionen. Der Workout-Neustart-Test war in den Läufen um 19:19 und 20:03 rot (Zeile 319, Hinweiszeile im Training), ebenso auf `main` ohne 2a-1 (#105). Im Validierungslauf 21:47 grün beim ersten Versuch, ohne Codeänderung dazwischen: zustandsabhängig, nicht durch 2a-1 verursacht. #105 bleibt offen und ist kommentiert.

## Scope Check
- App-Code-Dateien: 3 (Limit 5): `ClaudeApply.swift` (+122, neu), `AtemView.swift` (+6/−1), `WorkoutProgramsView.swift` (+6/−1)
- App-LoC: 136 (Limit 250); Testcode zählt nicht
- Out-of-scope: keine

## Dokumentation
- Keine Doku-Änderung in dieser Runde nötig: neuer Code wird noch nirgends aufgerufen; `claude-annahme.md` wird laut DoD erst in 2a-3 angepasst.

### Result: PASS
