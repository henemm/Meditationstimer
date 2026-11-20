# RED-Stand Runde A2d-1a (#80, Nr. 1-4 und Namensschlüssel „Beinpendel")

Stand: 2026-11-15 15:38, Simulator iPhone 17 Pro, iOS 27.2, vor jeder Produktänderung dieser Runde.
Seit dem ersten RED-Commit (cf155e9) haben sich nur Spec und Briefing geändert, kein Code und kein Test.

## Tests dieser Runde

`LeanHealthTimerTests/ExerciseCatalogTests.swift` bleibt laut Spec unverändert (Tests aus dem gemeinsamen
RED-Commit von #48). `server/test/mcp-read.test.ts` liest die Anzahl seit cf155e9 aus der Katalogdatei;
Server-Beleg weiter `server-test-red.txt` (709/709 grün, gilt für 43 wie für 47 Einträge).

Für „Beinpendel" → „Leg Swing" gibt es keinen eigenen Unit-Test (Spec: Testdatei unverändert); Nachweis im
App-Durchlauf von A2d-1a.

## Unit-Lauf vorher

`test-red-output-a2d-1a.txt` (Konsole, 12 Testfälle: 6 bestanden, 6 fehlgeschlagen, `** TEST FAILED **`),
Fehlermeldungen aus dem Ergebnisbündel in `test-red-failures-a2d-1a.json`.

| Test | Fehler vorher | Erwartung nach A2d-1a |
|------|---------------|-----------------------|
| `test_newExercises_haveTextsInDeAndEn_andCategory` | Abbruch bei Nr. 1: „Kennung builtin.hollow-hold fehlt" | Nr. 1-4 fehlerfrei, Abbruch bei Nr. 5 (`builtin.sit-ups`) |
| `test_idForEnglishName_returnsBuiltinId` | 24 Fehler, u. a. „own.hollow-hold" statt „builtin.hollow-hold" | 20 Fehler (Nr. 5-24) |
| `test_first43Entries_unchanged` | „43 is not greater than 43 – Erweiterung um die 24 neuen fehlt" | grün (47 > 43, erste 43 unverändert) |
| `test_catalog_matchesBuiltinExercisesJson` | 43 statt 67 | rot nur an der Endanzahl 67, 47 Einträge stimmen überein |
| `test_catalog_has67EntriesAndVersion2` | 43 statt 67, Version 1 statt 2 | rot bis A2d-2 |
| `test_defaultPrograms_referenceExistingCatalogIds` | Vorgaben ohne `exerciseId` | rot bis A2c-1 |

Grün und grün zu halten: `test_catalogIds_matchRegexAndAreUnique`, `test_idForGermanName_returnsBuiltinId`,
`test_idForNameWithLeftRightSuffix_resolvesBase`, `test_idForUnknownSuffixName_isOwn`,
`test_origin_derivedFromPrefix`, `test_infoForEnglishName_findsCatalogEntry`.
