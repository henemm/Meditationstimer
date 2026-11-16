# Adversary-Protokoll Runde A2d-2a (Issue #81)

Eigener Lauf: `xcodebuild test ... -only-testing:LeanHealthTimerTests/ExerciseCatalogTests` (iPhone 17 Pro, OS 27.2), Ergebnisbündel im Scratchpad. 12 Testfälle ausgeführt (Zeilen `Test case ... passed/failed`), 7 grün, 5 rot, alle 5 Rotfälle laut Spec erwartet.

## Testlauf gegen erwartetes Bild

| Test | Ergebnis | Erwartet? |
|---|---|---|
| test_newExercises_haveTextsInDeAndEn_andCategory | rot: `XCTUnwrap failed ... Kennung builtin.box-jumps fehlt` (ExerciseCatalogTests.swift:255) | ja, bricht erst bei Nr. 16 ab, Nr. 13-15 bestehen |
| test_idForEnglishName_returnsBuiltinId | rot für genau 9 Namen: Box Jumps, Skater Hops, Jump Rope, Downward Dog, Cobra Stretch, Cat-Cow, Seated Forward Bend, Shoulder Stretch Left/Right (Nr. 16-24) | ja; Inverted Rows, Step-ups, Wall-Sit nicht unter den Fehlern |
| test_catalog_matchesBuiltinExercisesJson | rot nur `58 != 67` (Katalog und JSON je einmal) | ja, nur Endanzahl |
| test_catalog_has67EntriesAndVersion2 | rot `58 != 67`, `1 != 2` | ja (A2d-2d) |
| test_defaultPrograms_referenceExistingCatalogIds | rot: "Schritt ... ohne exerciseId" | ja (A2c-1) |
| test_first43Entries_unchanged, test_catalogIds_matchRegexAndAreUnique, test_idForGermanName, test_idForNameWithLeftRightSuffix, test_idForUnknownSuffixName, test_infoForEnglishName, test_origin_derivedFromPrefix | grün | ja |

## Checkliste

| Nr. / AC | Status | Beweis |
|---|---|---|
| 1-3 (Input/Output/Side effects, Kontext) | ERWARTET OFFEN (späterer Schnitt A2b/A2c) | berührt A2d-2a nicht; `git status` zeigt nur 3 geänderte Dateien |
| 4 / AC-1 Gleichlauf JSON/Swift | BEWIESEN für Nr. 1-58, Endanzahl 67 ERWARTET OFFEN | Skript: JSON 58 Einträge, Swift 58 Einträge, Listen (id, name, category) identisch inkl. Reihenfolge; Test rot nur an Endanzahl 67 |
| 5 / AC-2 Kennung gültig, eindeutig | BEWIESEN | test_catalogIds_matchRegexAndAreUnique grün; neue ids `builtin.umgekehrtes-rudern`, `builtin.step-ups`, `builtin.wandsitzen` |
| 6 / AC-3 DE-Name → Kennung | BEWIESEN | test_idForGermanName grün; `idByGermanName` aus allExercises (ExerciseDatabase.swift ~Z. 612) |
| 7 / AC-4 EN-Name → Kennung | BEWIESEN für Nr. 13-15, ERWARTET OFFEN für Nr. 16-24 | `englishNameIds` Z. 604-606; im roten Test fehlen genau 9 Namen Nr. 16-24 |
| 8 / AC-5 links/rechts | BEWIESEN (unberührt) | test_idForNameWithLeftRightSuffix, test_idForUnknownSuffixName grün |
| 9 / AC-6 Herkunft | BEWIESEN (unberührt) | test_origin_derivedFromPrefix grün |
| 10 / AC-7 Info bei EN-Namen | BEWIESEN | test_infoForEnglishName_findsCatalogEntry grün |
| 11 / AC-8 Nr. 13-15 | BEWIESEN; Nr. 16-24 und catalogVersion 2 ERWARTET OFFEN | ExerciseDatabase.swift:507-528 (id, name, Kategorie wie Spec Z. 92-94: upperBody/legs/legs); xcstrings: 6 Schlüssel `exercise.<slug>.effect/.instructions` mit de und en je `translated`, `extractionState manual`; Namensschlüssel „Umgekehrtes Rudern"=Inverted Rows, „Wandsitzen"=Wall-Sit, kein Schlüssel „Step-ups" (Spec Z. 199); DE-Swift-Wert (value:) == de-Eintrag, 6/6 per Skript; Test bis Nr. 15 durchlaufen (bricht erst bei 16) |
| 12 / AC-9 erste 43 unverändert | BEWIESEN | test_first43Entries_unchanged grün; `git diff -U0` JSON: nur Hinzufügungen ab Z. 279 (kein `-`-Eintrag außer Kommaänderung der Vorzeile), xcstrings-Diff nur `+`-Zeilen, Swift-Diff nur ergänzte Einträge und 3 Alias-Zeilen |
| 13-33 (AC-10 bis AC-30) | ERWARTET OFFEN (späterer Schnitt A2b/A2c) | nicht Gegenstand von A2d-2a |
| 34 / AC-31 unberührt | BEWIESEN | `git status`: nur Contracts/catalog/builtin-exercises.json, Localizable.xcstrings, ExerciseDatabase.swift geändert (plus untracked Workflow-Artefakte); keine Watch/Widget/Info.plist-Änderung |

### Regression (Orchestrator, nach dem Adversary-Lauf)

Gesamte Unit-Suite mit derselben Ausschlussliste wie A2d-1c (Tests späterer Schnitte, siehe Spec-Regel „Tests späterer Schnitte dürfen rot sein"): `test-scope-a2d-2a.txt`, 249 bestanden, 0 fehlgeschlagen, `** TEST SUCCEEDED **`.

### Checkliste (abgehakt)
- [x] AC-1: JSON 58 == Swift 58 (id, name, category, Reihenfolge); Endanzahl 67 erst A2d-2d.
- [x] AC-2: Regex/Eindeutigkeit, test_catalogIds_matchRegexAndAreUnique grün.
- [x] AC-3, AC-5, AC-6: A2a-Tests grün, unberührt.
- [x] AC-4: Inverted Rows, Step-ups, Wall-Sit → richtige Kennung, wortgleich zur Vorschlagsliste; Nr. 16-24 rot (genau 9).
- [x] AC-7: test_infoForEnglishName_findsCatalogEntry grün.
- [x] AC-8 (Nr. 13-15): Kennung, Name, Kategorie, Wirkung und Anleitung DE+EN translated, DE-Werte identisch; Nr. 16-24 und Version 2 außerhalb A2d-2a.
- [x] AC-9: erste 43 (und 55 vorhandene) unverändert, nur Hinzufügungen, catalogVersion 1.
- [x] AC-10 bis AC-30: außerhalb A2d-2a, bestehende Tests grün (249/0).
- [x] AC-31: nur 3 Produktdateien, Watch/Widget unberührt.

## Datenprüfung

- Localizable.xcstrings: gültiges JSON, keine Doppelschlüssel (Skript mit object_pairs_hook, Ergebnis `dups []`).
- JSON `catalogVersion` 1, 58 Einträge, Reihenfolge und Inhalt gleich ExerciseDatabase.
- Aliasprüfung: „Inverted Rows", „Step-ups", „Wall-Sit" stehen wortgleich in WorkoutProgramsView.swift Z. 290, 304, 305; Ableitung vergleicht per `lookupKey` (trim, lowercased), trifft also exakt. Keine Kollision mit vorhandenen Namen/Aliasen (grep: „Wall Push-ups" ist ein anderer Schlüssel). Bewusst nicht abgedeckt: „Wall Sit" ohne Bindestrich ergäbe `own.wall-sit`, steht aber nirgends in der Vorschlagsliste (kein Defekt).
- „Step-ups": deutscher Name wird über `idByGermanName` getroffen, englisch identisch, Alias redundant aber unschädlich.

## Fachliche Gegenlesung

- Umgekehrtes Rudern: klar abgegrenzt (Tisch/Ringe/Band statt Stange, mittlerer Rücken, Schulterblätter zusammenziehen, Ellbogen nah am Körper). Fachlich korrekt. EN "Inverted Rows" idiomatisch, deckungsgleich.
- Step-ups: korrekt (volle Fußfläche auf Stufe, Druck aus vorderem Bein, kontrolliert absetzen, Seitenwechsel). EN deckungsgleich.
- Wandsitzen: isometrisch, Haltedauer 30 bis 60 Sekunden statt Wiederholungen, 90°-Knie, Knie über den Füßen. EN deckungsgleich, "Wall-Sit" gebräuchlich (häufiger "Wall Sit", dennoch korrekt, entspricht Spec-Tabelle).
- Stil: nummerierte Schritte „1) … 2) …" wie bestehende Einträge.

## Findings

Keine Defekte. Hinweis niedrig (kein Mangel): Alias „Step-ups" ist redundant; Bindestrich-Variante „Wall Sit" würde nicht erkannt (nicht in der Vorschlagsliste).

## Runde 1 - Prüfung gegen die Checkliste

Zusammenfassung: Eigener Lauf von ExerciseCatalogTests (12 Fälle, 7 grün, 5 rot, alle 5 laut Spec erwartet, Abschnitt „Testlauf gegen erwartetes Bild"). Alle Checklistenpunkte für Nr. 13-15, AC-1 bis AC-9 und AC-31 BEWIESEN, spätere Schnitte als ERWARTET OFFEN (Abschnitt „Checkliste"). Quelldaten (JSON, Swift, xcstrings) konsistent, nur Hinzufügungen (Abschnitt „Datenprüfung"). Fachtexte DE/EN ohne Fehler (Abschnitt „Fachliche Gegenlesung"). Keine Defekte (Abschnitt „Findings").

## Runde 2 - Kompilat, Regression, Anzeige

(a) Kompilat: BEWIESEN. Im frisch gebauten Bundle (DerivedData/Meditationstimer-eigojyav.../Debug-iphonesimulator/Lean Health Timer.app, gebaut 16.11. 06:52 durch den Runde-1-Lauf) liegen `en.lproj/Localizable.strings` und `de.lproj/Localizable.strings`. Per Plist-Dekodierung (plistlib, gleiche Daten wie `plutil -p`) gelesen:
- EN: „Umgekehrtes Rudern" -> „Inverted Rows", „Wandsitzen" -> „Wall-Sit"; alle 6 `exercise.<slug>.effect/.instructions` tragen den englischen Text (z. B. `exercise.wandsitzen.effect` -> „Strengthens the thighs and glutes through a static hold ...").
- DE: „Umgekehrtes Rudern" -> „Umgekehrtes Rudern", „Wandsitzen" -> „Wandsitzen"; alle 6 Schlüssel tragen den deutschen Text (z. B. `exercise.step-ups.effect` -> „Kräftigt Oberschenkel, Gesäß und Hüfte ...").
- „Step-ups" erscheint in keinem Bundle (kein Schlüssel, wie die Spec Z. 199 verlangt).

(b) Regression: BEWIESEN. Zeile 2 (Kommandozeile) von test-scope-a2d-2a.txt und test-scope-a2d-1c.txt hat identische MD5 (47c411f17f1823602f5c0602c01ed309), ist also byte-gleich. Die Ausschlussliste enthält genau 14 `-skip-testing`: die 5 erwarteten ExerciseCatalogTests (test_newExercises_haveTextsInDeAndEn_andCategory, test_idForEnglishName_returnsBuiltinId, test_catalog_matchesBuiltinExercisesJson, test_catalog_has67EntriesAndVersion2, test_defaultPrograms_referenceExistingCatalogIds) und 9 WorkoutPhaseMigrationTests (A2b-Rotfälle); nichts Zusätzliches. Zählung A2d-2a: 249 `Test case ... passed`, 0 `failed`, `** TEST SUCCEEDED **` (Xcode 27 druckt keine `Executed N tests`-Zeile; N = 249 >= 1 aus der passed-Zählung). Dieselbe Zählung in A2d-1c: 249 passed, 0 failed. Hinweis: Die 5 geskippten Tests wurden in Runde 1 separat gelaufen und verhalten sich wie erwartet rot.

(c) Anzeige der Vorschlagsliste: KEINE Regression. WorkoutProgramsView.swift:1993-1994 rendert `ForEach(exerciseSuggestions ...) { Text(exercise) }` mit einer String-Variablen (verbatim, keine LocalizedStringKey-Auflösung). Die englischen Einträge „Inverted Rows"/„Wall-Sit" (Z. 290, 305) erscheinen daher in DE und EN unverändert. Zusätzlich gibt es in der xcstrings keinen Schlüssel „Inverted Rows" oder „Wall-Sit" (nur als Werte, Z. 12501/12518), und im Bundle liefern beide Sprachen für diese Strings `<kein Key>`. Die neuen Schlüssel „Umgekehrtes Rudern"/„Wandsitzen" sind andere Zeichenketten und beeinflussen die Liste nicht. Sie greifen erst über `displayName`/`localizedTexts` (bundle.localizedString mit dem deutschen Katalognamen), also nicht in dieser Liste.

Findings Runde 2: keine Defekte. Checklistenpunkte bleiben unverändert (keiner widerlegt).

## Geprüfte Dateien

- sha256:e09b01058146994d8f956f171e7f3bee0f7469d672a9f6cc30f63ffe75c2d4a2  Contracts/catalog/builtin-exercises.json
- sha256:e82f81cef82a092ae32734ce89bb25b162ac58fa3ec78466ad503e68bde20da8  Meditationstimer iOS/Localizable.xcstrings
- sha256:8cef297005c3f2e810e671fbffbe9933e696c979432bcc78d393ecb319005754  Meditationstimer iOS/Services/ExerciseDatabase.swift

## Prüfbasis

- base: 2248476674c1cf5975277c8560ca72e62e700bc1

VERDICT: VERIFIED — Runde 1 und Runde 2: Kompilat enthält alle 8 Schlüssel je Sprache korrekt, Ausschlussliste byte-gleich zu A2d-1c mit 249 passed/0 failed, die Anzeige der heutigen Vorschlagsliste bleibt unverändert; keine Defekte.
