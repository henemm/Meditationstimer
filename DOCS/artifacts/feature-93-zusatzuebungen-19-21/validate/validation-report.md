## Validation Report: feature-93-zusatzuebungen-19-21 (A2d-2c)

Stand: 15641ff, 2026-11-16, Simulator iPhone 17 Pro iOS 27.2

### Test Results
- Unit-Suite komplett: 263 Testfälle ausgeführt, 249 grün, 14 rot; rot sind genau die 14 erwarteten Fälle späterer Schnitte (5 ExerciseCatalogTests, 9 WorkoutPhaseMigrationTests), dieselben 14 wie nach A2d-2b (`unit-suite-summary.txt`).
- Zwischenstände laut Spec-Test-Plan: `test_newExercises_haveTextsInDeAndEn_andCategory` bricht erst bei Nr. 22 (`builtin.sitzende-vorbeuge`) ab, `test_idForEnglishName_returnsBuiltinId` rot nur noch für die drei Namen aus A2d-2d (Seated Forward Bend, Shoulder Stretch Left/Right), Gleichlauf rot nur an der Endanzahl („64 is not equal to 67“).

### Spec Compliance
- A2d-2c: Nr. 19-21 (Herabschauender Hund, Kobra-Dehnung, Katze-Kuh) im Katalog mit Kategorien Dehnung/Dehnung/Aufwärmen, JSON gleichlaufend, Texte DE/EN, Namensschlüssel Downward Dog, Cobra Stretch, Cat-Cow. Fachliche Abgrenzung laut Spec in den Texten sichtbar (gehaltene Dehnung, nicht „Planke zu Herabschauender Hund“). Testdatei nur in der RED-Phase an den zwei deutschen Namen angepasst. Adversary VERIFIED (2 Runden, 10 Punkte bewiesen).

### App-Durchlauf
- Wegwerf-Kopie (`git archive`), eigener frisch angelegter Simulator, Test `WalkDownwardDogUITests.swift.txt`: im Schritt-Editor „Downward Dog“ aus der Vorschlagsliste gewählt (`editor-downwarddog-de.png`), gesichert, Programm-Info geöffnet (`proginfo-de.png`, `proginfo-en.png`), Info-Blatt mit Kategorie, Wirkung und Anleitung auf Deutsch (`downwarddog-de.png`) und Englisch (`downwarddog-en.png`). `test_walk passed`, 1 Test ausgeführt (`walk-summary.txt`), beim ersten Versuch.
- Name im Info-Blatt bleibt laut Spec bis A2b der gespeicherte englische Name „Downward Dog“. Altfehler #90 umgangen (zuerst Burpees geöffnet, dessen Blatt wie bekannt leer blieb).
- Im englischen Blatt steht die Kategorie „Dehnung“ auf Deutsch: bekannter Altfehler #91 (Kategorie ist der deutsche Rohwert des Enums), nicht Teil dieser Runde.

### Regression Check
- Keine Regressionen: keine weiteren roten Fälle außer den 14 erwarteten.

### Scope Check
- Produktdateien: `ExerciseDatabase.swift` +29, `Localizable.xcstrings` +159, `builtin-exercises.json` +15 = 203 Zeilen, rein additiv; Testdatei 2/2 Zeilen; Watch/Widget unberührt. Innerhalb der Rundenschätzung ca. 210.

### Result: PASS
