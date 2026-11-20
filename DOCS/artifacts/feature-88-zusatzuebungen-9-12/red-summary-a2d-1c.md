# RED-Stand Runde A2d-1c (#88, Nr. 9-12 und Namensschlüssel Klimmzüge / Australische Klimmzüge)

Stand: 2026-11-15, Simulator iPhone 17 Pro, vor jeder Produktänderung dieser Runde
(Ausgangsstand: A2d-1b abgeschlossen, Katalog mit 51 Einträgen).

## Tests dieser Runde

`LeanHealthTimerTests/ExerciseCatalogTests.swift` bleibt laut Spec unverändert (Tests aus dem gemeinsamen
RED-Commit von #48). `server/test/mcp-read.test.ts` liest die Anzahl aus der Katalogdatei und braucht keine Änderung.

## Unit-Lauf vorher

`test-red-output-a2d-1c.txt` (Konsole, 12 Testfälle: 7 bestanden, 5 fehlgeschlagen, `** TEST FAILED **`),
Fehlermeldungen aus dem Ergebnisbündel in `test-red-failures-a2d-1c.json`.

| Test | Fehler vorher | Erwartung nach A2d-1c |
|------|---------------|-----------------------|
| `test_newExercises_haveTextsInDeAndEn_andCategory` | Abbruch bei Nr. 9: „Kennung builtin.dips fehlt" | Nr. 1-12 fehlerfrei, Abbruch bei Nr. 13 (`builtin.umgekehrtes-rudern`) |
| `test_idForEnglishName_returnsBuiltinId` | 16 Fehler, u. a. „own.dips", „own.pull-ups", „own.chin-ups", „own.australian-pull-ups" | 12 Fehler (Nr. 13-24) |
| `test_catalog_matchesBuiltinExercisesJson` | 51 statt 67 | rot nur an der Endanzahl 67, 55 Einträge stimmen überein |
| `test_catalog_has67EntriesAndVersion2` | 51 statt 67, Version 1 statt 2 | rot bis A2d-2 |
| `test_defaultPrograms_referenceExistingCatalogIds` | Vorgaben ohne `exerciseId` (24 Fehler) | rot bis A2c-1 |

Grün und grün zu halten: `test_catalogIds_matchRegexAndAreUnique`, `test_first43Entries_unchanged`,
`test_idForGermanName_returnsBuiltinId`, `test_idForNameWithLeftRightSuffix_resolvesBase`,
`test_idForUnknownSuffixName_isOwn`, `test_origin_derivedFromPrefix`, `test_infoForEnglishName_findsCatalogEntry`.

## App-Durchlauf (nach der Umsetzung)

Im Schritt-Editor „Pull-ups" aus der Vorschlagsliste wählen; das Info-Blatt zeigt Wirkung und Anleitung, einmal mit
`-AppleLanguages (de)`, einmal mit `(en)`. Erstmals wechselt auch der Name: Deutsch „Klimmzüge", Englisch „Pull-ups".
Altfehler #90 (Info-Blatt beim ersten Tipp leer) wird hier nicht behoben und im Beleg vermerkt.
