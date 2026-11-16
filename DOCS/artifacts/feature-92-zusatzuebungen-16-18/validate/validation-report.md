## Validation Report: feature-92-zusatzuebungen-16-18 (A2d-2b)

Stand: 560b215, 2026-11-16, Simulator iPhone 17 Pro iOS 27.2

### Test Results
- Unit-Suite komplett: 263 Testfälle ausgeführt, 249 grün, 14 rot; rot sind genau die 14 erwarteten Fälle späterer Schnitte (5 ExerciseCatalogTests, 9 WorkoutPhaseMigrationTests), dieselben 14 wie nach A2d-2a. Ein zusätzlicher Eintrag im Ergebnisbündel ist kein Testfall, sondern ein Startfehler eines parallelen Simulator-Klons (`unit-suite-summary.txt`).
- Zwischenstände laut Spec-Test-Plan: `test_newExercises_haveTextsInDeAndEn_andCategory` bricht erst bei Nr. 19 (`builtin.herabschauender-hund`) ab, `test_idForEnglishName_returnsBuiltinId` rot nur noch für Nr. 19-24, Gleichlauf rot nur an der Endanzahl („61 is not equal to 67“).

### Spec Compliance
- A2d-2b: Nr. 16-18 (Box Jumps, Skater Hops, Seilspringen) im Katalog, JSON gleichlaufend, Texte DE/EN, Namensschlüssel „Seilspringen“, englische Namen in `englishNameIds`, vorhandener Schlüssel „Jump Rope“ unverändert. Adversary VERIFIED (2 Runden).

### App-Durchlauf
- Wegwerf-Kopie (`git archive`), eigener frisch angelegter Simulator, Test `WalkJumpRopeUITests.swift.txt`: im Schritt-Editor „Jump Rope“ aus der Vorschlagsliste gewählt (`editor-jumprope-de.png`), gesichert, Programm-Info geöffnet (`proginfo-de.png`, `proginfo-en.png`), Info-Blatt mit Kategorie Cardio, Wirkung und Anleitung auf Deutsch (`jumprope-de.png`) und Englisch (`jumprope-en.png`). `test_walk passed` (`walk-summary.txt`).
- Name im Info-Blatt bleibt laut Spec bis A2b der gespeicherte englische Name „Jump Rope“. Altfehler #90 umgangen (zuerst Burpees geöffnet).
- Drei Fehlläufe vorher ohne Produktbezug: langsames Wischen im Menü wählte versehentlich einen Eintrag; ein gemeinsam genutzter Simulator wurde mitten im Lauf heruntergefahren; Ziehen mit Halten schloss das Menü. Lösung im Wegwerf-Test: normales Wischen, Menü bei Bedarf neu öffnen, eigener Simulator.

### Regression Check
- Keine Regressionen: keine weiteren roten Fälle außer den 14 erwarteten.

### Scope Check
- Produktdateien: `ExerciseDatabase.swift` +29, `Localizable.xcstrings` +125, `builtin-exercises.json` +15 = 169 Zeilen, rein additiv; Watch/Widget unberührt.

### Result: PASS
