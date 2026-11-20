## Validation Report: feature-94-zusatzuebungen-22-24 (A2d-2d)

Stand: c4e6cf3, 2026-11-16, Simulator iPhone 17 Pro iOS 27.2

### Test Results
- Unit-Suite komplett: 263 Testfälle ausgeführt, 253 grün, 10 rot (`unit-suite-summary.txt`). Gegenüber A2d-2c (14 rot) sind genau die vier Katalogfälle grün geworden, die laut Spec-Test-Plan erst nach A2d-2d grün werden: `test_catalog_has67EntriesAndVersion2`, `test_catalog_matchesBuiltinExercisesJson`, `test_newExercises_haveTextsInDeAndEn_andCategory`, `test_idForEnglishName_returnsBuiltinId`.
- Die 10 verbleibenden Rotfälle sind dieselben wie nach A2d-2c und gehören zu späteren Schnitten (u. a. `test_defaultPrograms_referenceExistingCatalogIds` → A2c-1, WorkoutPhaseMigrationTests).

### Spec Compliance
- A2d-2d: Nr. 22-24 (Vorbeuge im Sitzen, Schulter-Dehnung links/rechts) im Katalog, `catalogVersion` 2, 67 Einträge, JSON gleichlaufend, Texte DE/EN, Namensschlüssel Seated Forward Bend, Shoulder Stretch Left/Right. Fachliche Abgrenzung gegen die Hamstring-Dehnung im Stehen im Wirkungstext sichtbar; Schulter-Seiten spiegelbildlich (Adversary). Testdatei nur in der RED-Phase (deutscher Name Z. 146). Adversary VERIFIED (2 Runden, 10 Punkte bewiesen).

### App-Durchlauf
- Wegwerf-Kopie (`git archive`), eigener frisch angelegter Simulator, Test `WalkSeatedForwardBendUITests.swift.txt`: im Schritt-Editor „Seated Forward Bend“ aus der Vorschlagsliste gewählt (`editor-seatedforwardbend-de.png`), gesichert, Programm-Info geöffnet (`proginfo-de.png`, `proginfo-en.png`), Info-Blatt mit Kategorie, Wirkung und Anleitung auf Deutsch (`seatedforwardbend-de.png`) und Englisch (`seatedforwardbend-en.png`). `test_walk() passed` (`walk-summary.txt`).
- Erster Versuch abgebrochen: Absturz des Test-Runners (nicht der App) an einem erzwungenen Entpacken im Wegwerf-Skript, als sich das Menü beim langen Blättern bis „S“ schloss. Skript ohne erzwungenes Entpacken, Simulator gelöscht, zweiter Versuch grün.
- Name im Info-Blatt bleibt laut Spec bis A2b der gespeicherte englische Name. Altfehler #90 umgangen (zuerst Burpees geöffnet). Kategorie „Dehnung“ im englischen Blatt: bekannter Altfehler #91.

### Regression Check
- Keine Regressionen: keine roten Fälle außer den 10 erwarteten späterer Schnitte.

### Scope Check
- Produktdateien: `ExerciseDatabase.swift` +29, `Localizable.xcstrings` +160/-1 (Dateiende-Umbruch), `builtin-exercises.json` +16/-1 (`catalogVersion`) = 207 Zeilen; Testdatei 1/1 Zeile (RED); Watch/Widget unberührt. Innerhalb der Rundenschätzung ca. 210.

### Result: PASS
