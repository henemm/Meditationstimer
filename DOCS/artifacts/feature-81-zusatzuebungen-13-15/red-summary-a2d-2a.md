# RED-Stand Runde A2d-2a (#81, Nr. 13-15 und Namensschlüssel Umgekehrtes Rudern / Wandsitzen)

Stand: 2026-11-16, Simulator iPhone 17 Pro (iOS 27.2), vor jeder Produktänderung dieser Runde
(Ausgangsstand: A2d-1c abgeschlossen, Commit a3f3e94, Katalog mit 55 Einträgen).

## Tests dieser Runde

`LeanHealthTimerTests/ExerciseCatalogTests.swift` bleibt laut Spec unverändert (Tests aus dem gemeinsamen
RED-Commit von #48). `server/test/mcp-read.test.ts` liest die Anzahl aus der Katalogdatei und braucht keine Änderung.

## Unit-Lauf vorher

`test-red-output-a2d-2a.txt` (Konsole, 12 Testfälle: 7 bestanden, 5 fehlgeschlagen, `** TEST FAILED **`),
Fehlermeldungen aus dem Ergebnisbündel in `test-red-failures-a2d-2a.json`.

| Test | Fehler vorher | Erwartung nach A2d-2a |
|------|---------------|-----------------------|
| `test_newExercises_haveTextsInDeAndEn_andCategory` | Abbruch bei Nr. 13: „Kennung builtin.umgekehrtes-rudern fehlt" | Nr. 1-15 fehlerfrei, Abbruch bei Nr. 16 (`builtin.box-jumps`) |
| `test_idForEnglishName_returnsBuiltinId` | 12 Fehler, u. a. „own.inverted-rows", „own.step-ups", „own.wall-sit" | 9 Fehler (Nr. 16-24) |
| `test_catalog_matchesBuiltinExercisesJson` | 55 statt 67 | rot nur an der Endanzahl 67, 58 Einträge stimmen überein |
| `test_catalog_has67EntriesAndVersion2` | 55 statt 67, Version 1 statt 2 | rot bis A2d-2d |
| `test_defaultPrograms_referenceExistingCatalogIds` | Vorgaben ohne `exerciseId` | rot bis A2c-1 |

Grün und grün zu halten: `test_catalogIds_matchRegexAndAreUnique`, `test_first43Entries_unchanged`,
`test_idForGermanName_returnsBuiltinId`, `test_idForNameWithLeftRightSuffix_resolvesBase`,
`test_idForUnknownSuffixName_isOwn`, `test_origin_derivedFromPrefix`, `test_infoForEnglishName_findsCatalogEntry`.

## App-Durchlauf (nach der Umsetzung)

Im Schritt-Editor „Inverted Rows" aus der Vorschlagsliste wählen; das Info-Blatt zeigt Wirkung und Anleitung, einmal
mit `-AppleLanguages (de)`, einmal mit `(en)`. Der Name im Info-Blatt bleibt bis A2b englisch (Walk-Test-Lehre #88).
Altfehler #90 (Info-Blatt beim ersten Tipp leer) wird hier nicht behoben und im Beleg vermerkt.
