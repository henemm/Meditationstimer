# RED-Stand Runde A2d-1 (#80, Zusatzübungen Nr. 1-12)

Stand: 2026-11-15, Simulator iPhone 17 Pro, iOS 27.2, vor jeder Produktänderung dieser Runde.

## Tests dieser Runde

`LeanHealthTimerTests/ExerciseCatalogTests.swift` bleibt laut Spec unverändert; die Tests liegen aus dem
gemeinsamen RED-Commit von #48 vor. Neu in dieser Runde ist nur die Anpassung von
`server/test/mcp-read.test.ts`: die beiden festen Anzahlen 43 (Test „overview" und Test „catalog ohne
Abschrift") sind durch die Anzahl aus `Contracts/catalog/builtin-exercises.json` ersetzt. Ohne diese
Anpassung würde die Server-CI rot, sobald der Katalog 55 Einträge hat.

## Unit-Lauf vorher (`test-red-output.txt`)

`Executed 12 tests, with 55 failures`. Rot und für A2d-1 maßgeblich:

| Test | Fehler vorher | Erwartung nach A2d-1 |
|------|---------------|----------------------|
| `test_newExercises_haveTextsInDeAndEn_andCategory` | bricht bei Nr. 1 ab: „Kennung builtin.hollow-hold fehlt" | Nr. 1-12 fehlerfrei, Abbruch erst bei Nr. 13 (`builtin.umgekehrtes-rudern`) |
| `test_idForEnglishName_returnsBuiltinId` | alle 24 englischen Namen liefern `own.*` | nur noch die 12 Namen aus Nr. 13-24 rot |
| `test_first43Entries_unchanged` | „Erweiterung um die 24 neuen fehlt" (43 nicht > 43), JSON ebenso | grün |
| `test_catalog_matchesBuiltinExercisesJson` | 43 statt 67 | rot nur an der Endanzahl 67 (55 Einträge stimmen überein) |
| `test_catalog_has67EntriesAndVersion2` | 43 statt 67, Version 1 statt 2 | rot bis A2d-2 |
| `test_defaultPrograms_referenceExistingCatalogIds` | Vorgaben ohne `exerciseId` | rot bis A2c-1 |

Grün und grün zu halten: `test_catalogIds_matchRegexAndAreUnique`, `test_idForGermanName_returnsBuiltinId`,
`test_idForNameWithLeftRightSuffix_resolvesBase`, `test_idForUnknownSuffixName_isOwn`,
`test_origin_derivedFromPrefix`, `test_infoForEnglishName_findsCatalogEntry`.

## Server-Lauf (`server-test-red.txt`)

`npm test` gegen ein lokales Wegwerf-Postgres 18 (wie in der CI): 709 Tests, 709 bestanden. Die angepasste
Prüfung gilt vorher (43 = 43 aus der Datei) und nachher (55 = 55 aus der Datei); vorher hätte die feste 43
nach A2d-1 den Lauf rot gemacht.

## Hinweis Testlauf

`xcodebuild test` brach dreimal mit „The test runner hung before establishing connection" ab. Ursache laut
Recherche (Apple-Forum Thread 805060, CircleCI-Blog zu Exit-Code 65): Simulator nicht vorgewärmt. Mit
vorab gebootetem Simulator (`simctl boot` + `bootstatus`) und `test-without-building` auf dem schon gebauten
Stand lief der Test sofort. Zur selben Zeit war ein zweiter Simulator (iPhone 17, nicht aus dieser Sitzung)
gebootet.
