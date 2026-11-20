# RED-Stand Runde A2d-1b (#87, Nr. 5-8 und Namensschlüssel Archer-/Decline-Liegestütze)

Stand: 2026-11-15, Simulator iPhone 17 Pro, iOS 27.2, vor jeder Produktänderung dieser Runde
(Ausgangsstand: A2d-1a abgeschlossen, Katalog mit 47 Einträgen).

## Tests dieser Runde

`LeanHealthTimerTests/ExerciseCatalogTests.swift` bleibt laut Spec unverändert (Tests aus dem gemeinsamen
RED-Commit von #48). `server/test/mcp-read.test.ts` liest die Anzahl seit #80 aus der Katalogdatei und
braucht in dieser Runde keine Änderung.

## Unit-Lauf vorher

`test-red-output-a2d-1b.txt` (Konsole, 12 Testfälle: 7 bestanden, 5 fehlgeschlagen, `** TEST FAILED **`),
Fehlermeldungen aus dem Ergebnisbündel in `test-red-failures-a2d-1b.json`.

| Test | Fehler vorher | Erwartung nach A2d-1b |
|------|---------------|-----------------------|
| `test_newExercises_haveTextsInDeAndEn_andCategory` | Abbruch bei Nr. 5: „Kennung builtin.sit-ups fehlt" | Nr. 1-8 fehlerfrei, Abbruch bei Nr. 9 (`builtin.dips`) |
| `test_idForEnglishName_returnsBuiltinId` | 20 Fehler, u. a. „own.sit-ups", „own.crunches", „own.archer-push-ups", „own.decline-push-ups" | 16 Fehler (Nr. 9-24) |
| `test_catalog_matchesBuiltinExercisesJson` | 47 statt 67 | rot nur an der Endanzahl 67, 51 Einträge stimmen überein |
| `test_catalog_has67EntriesAndVersion2` | 47 statt 67, Version 1 statt 2 | rot bis A2d-2 |
| `test_defaultPrograms_referenceExistingCatalogIds` | Vorgaben ohne `exerciseId` (24 Fehler) | rot bis A2c-1 |

Grün und grün zu halten: `test_catalogIds_matchRegexAndAreUnique`, `test_first43Entries_unchanged`,
`test_idForGermanName_returnsBuiltinId`, `test_idForNameWithLeftRightSuffix_resolvesBase`,
`test_idForUnknownSuffixName_isOwn`, `test_origin_derivedFromPrefix`, `test_infoForEnglishName_findsCatalogEntry`.

## App-Durchlauf (nach der Umsetzung)

Im Schritt-Editor „Crunches" aus der Vorschlagsliste wählen; das Info-Blatt zeigt Wirkung und Anleitung, einmal mit
`-AppleLanguages (de)`, einmal mit `(en)`. Altfehler #90 (Info-Blatt beim ersten Tipp leer) wird hier nicht behoben
und im Beleg vermerkt.
