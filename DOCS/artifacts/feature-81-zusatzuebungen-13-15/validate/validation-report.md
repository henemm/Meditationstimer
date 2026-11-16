## Validation Report: feature-81-zusatzuebungen-13-15 (A2d-2a)

Stand: c9e09c9, 2026-11-16, Simulator iPhone 17 Pro iOS 27.2

### Test Results
- Unit-Suite komplett (ohne Ausschlussliste): 263 Fälle ausgeführt, 249 grün, 14 rot; rot sind genau die 14 erwarteten Fälle späterer Schnitte (5 ExerciseCatalogTests, 9 WorkoutPhaseMigrationTests), `unit-suite-summary.txt`.
- Zwischenstände laut Spec-Test-Plan getroffen: `test_newExercises_haveTextsInDeAndEn_andCategory` bricht bei Nr. 16 (`builtin.box-jumps`) ab, `test_idForEnglishName_returnsBuiltinId` rot für genau 9 Namen (Nr. 16-24), Gleichlauf aller 58 Einträge grün bis auf die Endanzahl 67 („58 is not equal to 67“), Version 1 statt 2 erst in A2d-2d.
- Server: in dieser Runde nicht berührt, laut Spec-Zeile A2d-2a ohne Server-Test.

### Spec Compliance
- A2d-2a: Nr. 13-15 (Umgekehrtes Rudern, Step-ups, Wandsitzen) im Katalog, JSON gleichlaufend, Texte DE/EN, Namensschlüssel Umgekehrtes Rudern (Inverted Rows) und Wandsitzen (Wall-Sit), englische Namen in `englishNameIds`. Adversary VERIFIED (9 Punkte, 2 Runden).
- Fachliche Abgrenzung erfüllt: Umgekehrtes Rudern am Tisch, an Ringen oder Band, Fokus mittlerer Rücken und Schulterblätter, Ellbogen nah am Körper (anders als Australische Klimmzüge Nr. 12); Wandsitzen nennt eine Haltedauer von 30 bis 60 Sekunden statt Wiederholungen.

### App-Durchlauf
- Wegwerf-Kopie (`git archive`), frisch zurückgesetzter Simulator, Test `WalkInvertedRowsUITests.swift.txt`: im Schritt-Editor „Inverted Rows“ aus der heutigen Vorschlagsliste gewählt (`editor-invertedrows-de.png`), gesichert, Programm-Info geöffnet (`proginfo-de.png`, `proginfo-en.png`).
- Wegen Altfehler #90 zuerst Burpees, dann Inverted Rows geöffnet: Wirkung und Anleitung auf Deutsch (`invertedrows-de.png`) und Englisch (`invertedrows-en.png`). `test_walk() passed` (`walk-summary.txt`).
- Name im Programm-Info und Info-Blatt bleibt laut Spec bis A2b der gespeicherte englische Name „Inverted Rows“. Kategorie zeigt auf Englisch „Oberkörper“ (bekannt, #91).

### Regression Check
- Keine Regressionen: keine weiteren roten Fälle außer den 14 erwarteten.

### Scope Check
- Produktdateien: `ExerciseDatabase.swift` +29, `Localizable.xcstrings` +142, `builtin-exercises.json` +15 = 186 Zeilen (Spec-Schätzung ca. 190), rein additiv; Watch/Widget unberührt.

### Result: PASS
