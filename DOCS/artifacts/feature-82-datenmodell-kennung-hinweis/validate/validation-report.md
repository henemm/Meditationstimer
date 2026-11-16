# Validation Report: feature-82-datenmodell-kennung-hinweis (A2b-0)

Stand: 8526800, 2026-11-16, Simulator iPhone 17 Pro iOS 27.2

## Test Results
- Unit-Suite voll (`-only-testing:LeanHealthTimerTests`, nichts übersprungen): 262 ausgeführt, 257 passed, 5 failed (`unit-suite-voll.txt`).
- Die 5 Rotfälle sind genau die Tests späterer Schnitte aus dem gemeinsamen RED-Commit (A2b/A2c): `test_defaultPrograms_referenceExistingCatalogIds`, `test_announcement_respectsSpeakSetting`, `test_existingUserStore_unchangedAfterPresetMigration`, `test_selectingCatalogOrOwnExercise_setsExerciseId`, `test_spokenText_withAndWithoutHint`. Dieselbe Liste ist in `test-scope-a2b-0.txt` als Ausschluss geführt.
- Alle 8 A2b-0-Tests in `WorkoutPhaseMigrationTests` grün.

## Spec Compliance (AC-10 bis AC-17)
- AC-10/11 Altbestand und Ableitung: Unit-Tests grün; App-Durchlauf (unten) zeigt dasselbe am echten Speicher.
- AC-12 Slug-Regel, AC-13 Rundreise, AC-14 Hinweis-Normalisierung: Unit-Tests grün; Code: `WorkoutPhase.init(from:)`, `encode(to:)`, `normalizedHint`.
- AC-15 Sicherung kaputter Daten, AC-16 keine Sicherung ohne Fehler: Unit-Tests grün; App-Durchlauf bestätigt.
- AC-17 Spec-Nachzug: `openspec/specs/features/claude-annahme.md` nennt `own.<slug>` und den Vermerk zu `claudeId`/#51.
- Ergebnis: 8/8 erfüllt.

## App-Durchlauf (Wegwerf-Kopie per `git archive`, eigener Simulator „Walk82“, Test `Walk82UITests.swift.txt`)
1. Altbestand im alten Format (Programm „Altprogramm Test“, 2 Runden, Schritte „Planke“ 30/10 und „Mein Lauf!“ 45/15, ohne `exerciseId`/`hint`) eingespielt, App gestartet, Workout-Tab: Programm erscheint mit „2 x 2 = 3:20 min“ (`altbestand-de.png`). Gespeicherter Stand danach: Schritt-`id`s, Namen und Zeiten unverändert, Kennungen `builtin.planke` und `own.mein-lauf`, `hint` leer, kein Sicherungsschlüssel.
2. Kaputte Daten (16 Bytes, kein gültiges JSON) direkt in den App-Speicher geschrieben, App gestartet: Vorgabeprogramme erscheinen (`kaputt-start1-de.png`); danach liegt `workoutProgramSetsBackup.1794862767` mit byte-gleichem Inhalt (gleiche SHA-1), `workoutProgramSets` hält unverändert die Rohdaten.
3. Zweiter Start mit denselben kaputten Daten (spätere Sekunde): Vorgaben erscheinen (`kaputt-start2-de.png`), weiterhin genau eine Sicherung, keine Doppelsicherung.
- Hilfsskripte: `seedfile.py.txt` (schreibt in die App-Einstellungsdatei bei gestopptem Simulator), `readstate.py.txt` (liest sie aus).
- Lehre: `simctl spawn … defaults write` landet nicht verlässlich bei der App, wenn sie schon eine eigene Einstellungsdatei hat; Testläufe mit Parallel-Klonen arbeiten auf einer Kopie, deshalb `-parallel-testing-enabled NO`.

## Regression Check
- Keine Regressionen: alle Tests außerhalb der 5 erwarteten Rotfälle grün.

## Scope Check
- Umsetzung (8526800): 3 Dateien, +75/-5 (Produktcode `WorkoutProgramsView.swift`, `WorkoutTab.swift`; Doku `claude-annahme.md`), alle laut Spec-Schnitttabelle A2b-0 vorgesehen. Test-Datei `WorkoutPhaseMigrationTests.swift` im RED-Commit.
- Keine Änderungen außerhalb des Schnitts.

## Adversary
- `adversary-dialog.md`: valid, 10 Punkte bewiesen, 2 Runden, Verdict VERIFIED.

## Result: PASS
