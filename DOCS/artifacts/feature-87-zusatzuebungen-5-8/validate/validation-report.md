## Validation Report: feature-87-zusatzuebungen-5-8 (A2d-1b)

Stand: 007b4fc, 2026-11-15, Simulator iPhone 17 Pro iOS 27.2

### Test Results
- Unit-Suite komplett (ohne Ausschlussliste): 262 Fälle ausgeführt; rot sind genau die 14 erwarteten Fälle späterer Schnitte (5 ExerciseCatalogTests, 9 WorkoutPhaseMigrationTests), `unit-suite-summary.txt`.
- Zwischenstände laut Spec-Test-Plan getroffen: `test_newExercises_haveTextsInDeAndEn_andCategory` bricht bei Nr. 9 (`builtin.dips`) ab, `test_idForEnglishName_returnsBuiltinId` rot für 16 Namen, Gleichlauf aller 51 Einträge grün bis auf die Endanzahl 67.
- Server: in dieser Runde nicht berührt und laut Spec-Zeile A2d-1b ohne Server-Test; lokal ohnehin nicht lauffähig (`DATABASE_URL` fehlt, Tests brauchen echtes Postgres).

### Spec Compliance
- A2d-1b: Nr. 5-8 (Sit-ups, Crunches, Archer-, Decline-Liegestütze) im Katalog, JSON gleichlaufend, Texte DE/EN, Namensschlüssel Archer/Decline. Adversary VERIFIED, keine Befunde.

### App-Durchlauf
- Wegwerf-Kopie (`git archive`), Test `WalkCrunchesUITests.swift.txt`: im Schritt-Editor „Crunches“ aus der Vorschlagsliste gewählt (`editor-crunches-de.png`), gesichert, Programm-Info geöffnet (`proginfo-de.png`).
- Wegen Altfehler #90 zuerst Burpees, dann Crunches geöffnet: Wirkung und Anleitung auf Deutsch (`crunches-de.png`) und Englisch (`crunches-en.png`). `Executed 1 test, with 0 failures`.

### Regression Check
- Keine Regressionen: keine weiteren roten Fälle außer den 14 erwarteten.

### Scope Check
- Produktdateien: `ExerciseDatabase.swift` +38, `Localizable.xcstrings` +178, `builtin-exercises.json` +20 = 236 Zeilen, rein additiv; Watch/Widget unberührt.

### Result: PASS
