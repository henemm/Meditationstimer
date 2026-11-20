## Validation Report: feature-88-zusatzuebungen-9-12 (A2d-1c)

Stand: cf18c18, 2026-11-15, Simulator iPhone 17 Pro iOS 27.2

### Test Results
- Unit-Suite komplett (ohne Ausschlussliste): 262 Fälle ausgeführt; rot sind genau die 14 erwarteten Fälle späterer Schnitte (5 ExerciseCatalogTests, 9 WorkoutPhaseMigrationTests), `unit-suite-summary.txt`. Einzelfehler 91 statt 95 in A2d-1b (vier englische Namen weniger rot).
- Zwischenstände laut Spec-Test-Plan getroffen: `test_newExercises_haveTextsInDeAndEn_andCategory` bricht bei Nr. 13 (`builtin.umgekehrtes-rudern`) ab, `test_idForEnglishName_returnsBuiltinId` rot für genau 12 Namen, Gleichlauf aller 55 Einträge grün bis auf die Endanzahl 67 („55 is not equal to 67“).
- Server: in dieser Runde nicht berührt, laut Spec-Zeile A2d-1c ohne Server-Test.

### Spec Compliance
- A2d-1c: Nr. 9-12 (Dips, Klimmzüge, Chin-ups, Australische Klimmzüge) im Katalog, JSON gleichlaufend, Texte DE/EN, Namensschlüssel Klimmzüge/Australische Klimmzüge. Adversary VERIFIED (9 Punkte, 2 Runden), keine Befunde.

### App-Durchlauf
- Wegwerf-Kopie (`git archive`), frisch zurückgesetzter Simulator, Test `WalkPullupsUITests.swift.txt`: im Schritt-Editor „Pull-ups“ aus der heutigen Vorschlagsliste gewählt (`editor-pullups-de.png`; die Liste zeigt bis A2b englische Namen), gesichert, Programm-Info geöffnet.
- Namenswechsel: Programm-Info zeigt Deutsch „Klimmzüge“ (`proginfo-de.png`), Englisch „Pull-ups“ (`proginfo-en.png`).
- Wegen Altfehler #90 zuerst Burpees, dann Klimmzüge geöffnet: Wirkung und Anleitung auf Deutsch (`pullups-de.png`) und Englisch (`pullups-en.png`). `Executed 1 test, with 0 failures`.
- Bestehendes Verhalten außerhalb dieser Runde: Titel des Info-Blatts bleibt „Pull-ups“ auch auf Deutsch (lokalisierter Titel laut Spec erst A2b); Kategorie zeigt auf Englisch „Oberkörper“ (deutscher Rohwert der Kategorie, alle Oberkörper-Übungen) → #91.

### Regression Check
- Keine Regressionen: keine weiteren roten Fälle außer den 14 erwarteten.

### Scope Check
- Produktdateien: `ExerciseDatabase.swift` +38, `Localizable.xcstrings` +178, `builtin-exercises.json` +20 = 236 Zeilen, rein additiv (`.xcstrings` zählt laut PO-Entscheidung nicht zur Grenze); Watch/Widget unberührt.

### Result: PASS
