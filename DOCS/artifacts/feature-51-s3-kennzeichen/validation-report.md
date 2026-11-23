# Validation Report: feature-51-s3-kennzeichen (#51 Schnitt 3)

Stand: HEAD 4b668a9, 2026-11-23.

## Test Results
- Unit-Suite: `Executed 343 tests, with 0 failures` (`validate-unit.txt`).
- UI, je Klasse/Methode (`validate-ui.txt`): 26 Tests aus ClaudeKennzeichenUITests (7), ClaudeSpeichernUITests (10),
  ClaudeFelderUITests (1), WorkoutHintUITests (8); 25 grün im Serienlauf.
- `WorkoutHintUITests/test_pickedExercise_persistsAfterRelaunch` rot im Serienlauf, `test_exercisePicker_showsOnlyCatalogNames_german`
  erst im Wiederholungsversuch grün. Gegenprobe mit frisch installierter App (`gegenprobe-*.txt`): beide grün auf diesem Stand
  und auf origin/main. Ursache: Simulator-Reste früherer Läufe (Tests hängen vom Vorzustand ab), kein Regress.
- Watch und Widget: `build-watch.txt`, `build-widget.txt` BUILD SUCCEEDED (Adversary-Runde 2, unveränderter Stand).

## Spec Compliance
- AC-1 bis AC-14: 14/14 erfüllt (Unit- und UI-Tests oben, Adversary-Protokoll).
- F002/F003 (Adversary, LOW), hingenommen und hier festgehalten (freigegebene Spec bleibt unverändert): Ist `claudeState` unlesbar,
  legt das bestehende `loadState` eine Sicherung an (Bestandsverhalten). Das Lieferdatum 10:15 UTC zeigt nur in UTC+14 den Folgetag.
- F004 (Layout-Screenshots): erledigt durch den Nutzer-Durchlauf unten.

## Durchlauf als Nutzer (Simulator iPhone 17 Pro, iOS 27.2, hell und dunkel)
`durchlauf/` mit 9 Bildern je Modus und dem Wegwerf-Test `WalkKennzeichenUITests.swift.txt` (Scratch-Kopie, nicht im Repo):
Paket liefern → Kapsel in der Programmzeile → Workout-Info mit Abschnitt „Von Claude“ (Datum, Paket, Warum, keine
„Empfohlene Anwendung“) → Übungs-Info beim ersten Tippen mit Wirkung, Anleitung, Hinweisen und „Von Claude geliefert am
13.11.2026“ → Atem-Zeile und Atem-Info → Umbenennen → „von Claude · angepasst“ → große Schrift (Accessibility L), Kapsel
bricht um, nichts überdeckt. Beide Läufe `Executed 1 test, with 0 failures`.

## Regression Check
- Keine Regressionen (siehe Gegenprobe).

## Scope Check
- App-Dateien: 4 Swift-Dateien + String-Katalog (wie Spec). App-Diff 154 Zeilen (Grenze 250), Funktionen < 50 Zeilen.
- Keine Änderungen außerhalb der Spec.

## Result: PASS
