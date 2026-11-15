# GREEN-Beleg Runde A2d-1a (Refs #80)

Unit-Lauf: 263 Testfälle, 14 rot (5 ExerciseCatalogTests = spätere Schnitte, 9 in WorkoutPhaseMigrationTests = A2b, unverändert rot). Rohausgabe: test-green-output-a2d-1a.txt.

| ExerciseCatalogTests | vorher | nachher | Fehler |
|---|---|---|---|
| test_first43Entries_unchanged | rot | grün | 0 |
| test_catalogIds_matchRegexAndAreUnique | grün | grün | 0 |
| test_idForGermanName_returnsBuiltinId | grün | grün | 0 |
| test_idForNameWithLeftRightSuffix_resolvesBase | grün | grün | 0 |
| test_idForUnknownSuffixName_isOwn | grün | grün | 0 |
| test_origin_derivedFromPrefix | grün | grün | 0 |
| test_infoForEnglishName_findsCatalogEntry | grün | grün | 0 |
| test_newExercises_haveTextsInDeAndEn_andCategory | rot | rot (spätere Runde) | 1 (Nr. 5 sit-ups fehlt; Nr. 1-4 bestanden) |
| test_idForEnglishName_returnsBuiltinId | rot | rot | 20 (Nr. 5-24) |
| test_catalog_matchesBuiltinExercisesJson | rot | rot | 2 (nur Endanzahl 47 statt 67) |
| test_catalog_has67EntriesAndVersion2 | rot | rot | 2 (47 statt 67, Version 1 statt 2) |
| test_defaultPrograms_referenceExistingCatalogIds | rot | rot | 24 (A2c-1) |

Server (npm --prefix server run test:local, Wegwerf-Postgres; npm test allein bricht ohne DATABASE_URL ab): 709 Tests, 709 bestanden, 0 Fehler. Beleg: server-test-green-a2d-1a.txt.

Umfang: 3 Quelldateien, 224 Zeilen hinzu, 2 entfernt (JSON 20, xcstrings 161, Swift 45).
