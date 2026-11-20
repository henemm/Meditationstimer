# RED-Stand Runde A2d-2b (#92, Nr. 16-18 und Namensschlüssel Seilspringen)

Stand: 2026-11-16, Simulator iPhone 17 Pro (iOS 27.2), vor jeder Produktänderung dieser Runde
(Ausgangsstand: A2d-2a abgeschlossen, Commit 8394dcc, Katalog mit 58 Einträgen).

## Tests dieser Runde

`LeanHealthTimerTests/ExerciseCatalogTests.swift` bleibt laut Spec unverändert (Tests aus dem gemeinsamen
RED-Commit von #48). `server/test/mcp-read.test.ts` liest die Anzahl aus der Katalogdatei und braucht keine Änderung.

## Unit-Lauf vorher

`test-red-output-a2d-2b.txt` (Konsole, 12 Testfälle: 7 bestanden, 5 fehlgeschlagen, `** TEST FAILED **`),
Fehlermeldungen aus dem Ergebnisbündel in `test-red-failures-a2d-2b.json`.

| Test | Fehler vorher | Erwartung nach A2d-2b |
|------|---------------|-----------------------|
| `test_newExercises_haveTextsInDeAndEn_andCategory` | Abbruch bei Nr. 16: „Kennung builtin.box-jumps fehlt" | Nr. 1-18 fehlerfrei, Abbruch bei Nr. 19 (`builtin.herabschauender-hund`) |
| `test_idForEnglishName_returnsBuiltinId` | 9 Fehler, u. a. „own.box-jumps", „own.skater-hops", „own.jump-rope" | 6 Fehler (Nr. 19-24) |
| `test_catalog_matchesBuiltinExercisesJson` | 58 statt 67 | rot nur an der Endanzahl 67, 61 Einträge stimmen überein |
| `test_catalog_has67EntriesAndVersion2` | 58 statt 67, Version 1 statt 2 | rot bis A2d-2d |
| `test_defaultPrograms_referenceExistingCatalogIds` | Vorgaben ohne `exerciseId` | rot bis A2c-1 |

Grün und grün zu halten: `test_catalogIds_matchRegexAndAreUnique`, `test_first43Entries_unchanged`,
`test_idForGermanName_returnsBuiltinId`, `test_idForNameWithLeftRightSuffix_resolvesBase`,
`test_idForUnknownSuffixName_isOwn`, `test_origin_derivedFromPrefix`, `test_infoForEnglishName_findsCatalogEntry`.

## App-Durchlauf (nach der Umsetzung)

Im Schritt-Editor „Jump Rope" aus der Vorschlagsliste wählen; das Info-Blatt zeigt Wirkung und Anleitung, einmal
mit `-AppleLanguages (de)`, einmal mit `(en)`. Der Name im Info-Blatt bleibt bis A2b englisch (Walk-Test-Lehre #88).
Der alte englische Schlüssel „Jump Rope" → „Seilspringen" bleibt unverändert, solange die Vorschlagsliste ihn nutzt.
Altfehler #90 (Info-Blatt beim ersten Tipp leer) wird hier nicht behoben und im Beleg vermerkt.
