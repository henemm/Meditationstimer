# RED-Stand Runde A2d-2d (#94, Nr. 22-24, Namensschlüssel Vorbeuge im Sitzen, Schulter-Dehnung links/rechts, catalogVersion 2)

Stand: 2026-11-16, Simulator iPhone 17 Pro (iOS 27.2), vor jeder Produktänderung dieser Runde
(Ausgangsstand: A2d-2c abgeschlossen, Commit 2a6c43f, Katalog mit 64 Einträgen, Version 1).

## Tests dieser Runde

`LeanHealthTimerTests/ExerciseCatalogTests.swift`: laut Spec (Test Plan, Runde A2d-2d, PO-Entscheidung 2026-11-16)
nur der deutsche Name des Tupels Nr. 22 in `newExercises` geändert: „Sitzende Vorbeuge" → „Vorbeuge im Sitzen".
Kennung `builtin.sitzende-vorbeuge`, englischer Name und Kategorie unverändert. Geprüft wird der Name in
`test_newExercises_haveTextsInDeAndEn_andCategory` (`XCTAssertEqual(info.name, row.de, row.id)`). In der Umsetzung
wird kein Test geändert. `server/test/mcp-read.test.ts` liest die Anzahl aus der Katalogdatei, keine Änderung.

## Unit-Lauf vorher

`test-red-output-a2d-2d.txt` (Konsole, 12 Testfälle: 7 bestanden, 5 fehlgeschlagen, `** TEST FAILED **`),
Fehlermeldungen aus dem Ergebnisbündel in `test-red-failures-a2d-2d.json`.

| Test | Fehler vorher | Erwartung nach A2d-2d |
|------|---------------|-----------------------|
| `test_newExercises_haveTextsInDeAndEn_andCategory` | Abbruch bei Nr. 22: „Kennung builtin.sitzende-vorbeuge fehlt" | grün (Nr. 1-24, Name Nr. 22 „Vorbeuge im Sitzen") |
| `test_idForEnglishName_returnsBuiltinId` | 3 Fehler: „own.seated-forward-bend", „own.shoulder-stretch-left", „own.shoulder-stretch-right" | grün |
| `test_catalog_matchesBuiltinExercisesJson` | 64 statt 67 (JSON und Katalog) | grün |
| `test_catalog_has67EntriesAndVersion2` | 64 statt 67, Version 1 statt 2 | grün |
| `test_defaultPrograms_referenceExistingCatalogIds` | Vorgaben ohne `exerciseId` | rot bis A2c-1 (nicht Teil dieser Runde) |

Grün und grün zu halten: `test_catalogIds_matchRegexAndAreUnique`, `test_first43Entries_unchanged`,
`test_idForGermanName_returnsBuiltinId`, `test_idForNameWithLeftRightSuffix_resolvesBase`,
`test_idForUnknownSuffixName_isOwn`, `test_origin_derivedFromPrefix`, `test_infoForEnglishName_findsCatalogEntry`.

## App-Durchlauf (nach der Umsetzung)

Im Schritt-Editor „Seated Forward Bend" aus der Vorschlagsliste wählen; das Info-Blatt zeigt Wirkung und Anleitung,
einmal mit `-AppleLanguages (de)`, einmal mit `(en)`. Der Name im Info-Blatt bleibt bis A2b englisch.
Die alten englischen Schlüssel „Seated Forward Bend", „Shoulder Stretch Left/Right" bleiben unverändert, solange die
Vorschlagsliste sie nutzt. Altfehler #90 (Info-Blatt beim ersten Tipp leer) wird hier nicht behoben und im Beleg vermerkt.
