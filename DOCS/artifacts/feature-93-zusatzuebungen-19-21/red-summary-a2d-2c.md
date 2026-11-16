# RED-Stand Runde A2d-2c (#93, Nr. 19-21 und Namensschlüssel Herabschauender Hund, Kobra-Dehnung, Katze-Kuh)

Stand: 2026-11-16, Simulator iPhone 17 Pro (iOS 27.2), vor jeder Produktänderung dieser Runde
(Ausgangsstand: A2d-2b abgeschlossen, Commit 2ccb606, Katalog mit 61 Einträgen).

## Tests dieser Runde

`LeanHealthTimerTests/ExerciseCatalogTests.swift`: laut Spec (Test Plan, Runde A2d-2c, PO-Entscheidung 2026-11-16)
nur die deutschen Namen der Tupel Nr. 20/21 in `newExercises` geändert: „Cobra-Dehnung" → „Kobra-Dehnung",
„Cat-Cow" → „Katze-Kuh". Kennung, englischer Name und Kategorie unverändert. Geprüft werden die Namen in
`test_newExercises_haveTextsInDeAndEn_andCategory` (`XCTAssertEqual(info.name, row.de, row.id)`); sichtbar wird das
erst, wenn der Test nicht mehr bei Nr. 19 abbricht. In der Umsetzung wird kein Test geändert.
`server/test/mcp-read.test.ts` liest die Anzahl aus der Katalogdatei und braucht keine Änderung.

## Unit-Lauf vorher

`test-red-output-a2d-2c.txt` (Konsole, 12 Testfälle: 7 bestanden, 5 fehlgeschlagen, `** TEST FAILED **`),
Fehlermeldungen aus dem Ergebnisbündel in `test-red-failures-a2d-2c.json`.

| Test | Fehler vorher | Erwartung nach A2d-2c |
|------|---------------|-----------------------|
| `test_newExercises_haveTextsInDeAndEn_andCategory` | Abbruch bei Nr. 19: „Kennung builtin.herabschauender-hund fehlt" | Nr. 1-21 fehlerfrei (Namen „Kobra-Dehnung", „Katze-Kuh"), Abbruch bei Nr. 22 (`builtin.sitzende-vorbeuge`) |
| `test_idForEnglishName_returnsBuiltinId` | 6 Fehler, u. a. „own.downward-dog", „own.cobra-stretch", „own.cat-cow" | 3 Fehler (Nr. 22-24) |
| `test_catalog_matchesBuiltinExercisesJson` | 61 statt 67 | rot nur an der Endanzahl 67, 64 Einträge stimmen überein |
| `test_catalog_has67EntriesAndVersion2` | 61 statt 67, Version 1 statt 2 | rot bis A2d-2d |
| `test_defaultPrograms_referenceExistingCatalogIds` | Vorgaben ohne `exerciseId` | rot bis A2c-1 |

Grün und grün zu halten: `test_catalogIds_matchRegexAndAreUnique`, `test_first43Entries_unchanged`,
`test_idForGermanName_returnsBuiltinId`, `test_idForNameWithLeftRightSuffix_resolvesBase`,
`test_idForUnknownSuffixName_isOwn`, `test_origin_derivedFromPrefix`, `test_infoForEnglishName_findsCatalogEntry`.

## App-Durchlauf (nach der Umsetzung)

Im Schritt-Editor „Downward Dog" aus der Vorschlagsliste wählen; das Info-Blatt zeigt Wirkung und Anleitung, einmal
mit `-AppleLanguages (de)`, einmal mit `(en)`. Der Name im Info-Blatt bleibt bis A2b englisch (Walk-Test-Lehre #88).
Die alten englischen Schlüssel „Downward Dog", „Cobra Stretch", „Cat-Cow" bleiben unverändert, solange die
Vorschlagsliste sie nutzt. Altfehler #90 (Info-Blatt beim ersten Tipp leer) wird hier nicht behoben und im Beleg vermerkt.
