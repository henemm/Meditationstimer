# Adversary-Protokoll Runde A2d-2b (Issue #92)

Eigener Lauf: `xcodebuild test ... -only-testing:LeanHealthTimerTests/ExerciseCatalogTests` (iPhone 17 Pro, OS 27.2), Ergebnisbündel im Scratchpad (`adv92.xcresult`), Rohprotokoll `adversary-test-output.txt`. 12 Testfälle ausgeführt, 7 grün, 5 rot, alle 5 Rotfälle laut Spec erwartet.

## Prüfpunkte dieser Runde (A2d-2b)

- [x] AC-1 Gleichlauf JSON/Swift für Nr. 1-61 (Endanzahl 67 erwartet offen bis A2d-2d)
- [x] AC-2 Kennungen gültig und eindeutig
- [x] AC-3 deutscher Name → Kennung
- [x] AC-4 englischer Name → Kennung für Box Jumps, Skater Hops, Jump Rope (Nr. 19-24 erwartet offen)
- [x] AC-5/6/7 unberührt grün
- [x] AC-8 Nr. 16-18 mit Kategorie, Wirkung und Anleitung DE/EN, Namensschlüssel „Seilspringen"
- [x] AC-9 vorhandene Einträge unverändert, Diff append-only
- [x] AC-31 nur die 3 erlaubten Dateien geändert, Testdatei unberührt
- [x] Vorhandener Schlüssel „Jump Rope" unverändert

AC-10 bis AC-30 gehören zu späteren Schnitten (A2b/A2c) und sind nicht Gegenstand dieser Runde.

### Runde 1 — eigener Testlauf

Fragestellung: Entspricht das Testbild exakt der Erwartung, oder gibt es zusätzliche Rotfälle?

## Testlauf gegen erwartetes Bild

| Test | Ergebnis | Erwartet? |
|---|---|---|
| test_newExercises_haveTextsInDeAndEn_andCategory | rot: `Kennung builtin.herabschauender-hund fehlt` (erste Kennung nach Nr. 18) | ja, Nr. 16-18 bestehen, Abbruch erst bei Nr. 19 |
| test_idForEnglishName_returnsBuiltinId | rot für genau 6 Namen: Downward Dog, Cobra Stretch, Cat-Cow, Seated Forward Bend, Shoulder Stretch Left/Right (Nr. 19-24) | ja; Box Jumps, Skater Hops, Jump Rope nicht unter den Fehlern |
| test_catalog_matchesBuiltinExercisesJson | rot nur `61 != 67` (JSON und Katalog je einmal) | ja |
| test_catalog_has67EntriesAndVersion2 | rot `61 != 67`, `1 != 2` | ja (A2d-2d) |
| test_defaultPrograms_referenceExistingCatalogIds | rot: "Schritt ... ohne exerciseId" (24 Meldungen) | ja (A2c-1) |
| test_catalogIds_matchRegexAndAreUnique, test_first43Entries_unchanged, test_idForGermanName, test_idForNameWithLeftRightSuffix, test_idForUnknownSuffixName, test_infoForEnglishName, test_origin_derivedFromPrefix | grün | ja |

### Runde 2 — Datenprüfung per Skript, Edge Cases, Fachtexte

Fragestellung: Halten Daten, Schlüssel und Texte auch jenseits der Tests (Doppelungen, Alias-Kollision, Sortierung, Übersetzungsgleichheit, Altschlüssel „Jump Rope")?

## Checkliste

| Nr. / AC | Status | Beweis |
|---|---|---|
| AC-1 Gleichlauf JSON/Swift | BEWIESEN für Nr. 1-61; Endanzahl 67 ERWARTET OFFEN | Skript: JSON 61, Swift 61, Listen (id, name, category, Reihenfolge) identisch; Test rot nur 61 != 67; `catalogVersion` 1 |
| AC-2 Kennung gültig, eindeutig | BEWIESEN | Test grün; Skript: keine doppelte Kennung; neue: builtin.box-jumps, builtin.skater-hops, builtin.seilspringen |
| AC-3 DE-Name -> Kennung | BEWIESEN | test_idForGermanName grün |
| AC-4 EN-Name -> Kennung | BEWIESEN für Nr. 16-18, ERWARTET OFFEN für Nr. 19-24 | genau 6 Fehler (Nr. 19-24); Aliase ExerciseDatabase.swift Z. 633-635 |
| AC-5/6/7 | BEWIESEN (unberührt) | LeftRight, UnknownSuffix, origin, infoForEnglishName grün |
| AC-8 Nr. 16-18 | BEWIESEN; Nr. 19-24 und Version 2 ERWARTET OFFEN | Kategorien legs/cardio/cardio wie Spec Z. 95-97; 6 Schlüssel `exercise.<slug>.effect/.instructions` mit de+en `translated`, `extractionState manual`, en nicht leer; DE-`value:` in Swift == de im xcstrings 6/6 (Skript); Namensschlüssel „Seilspringen" de „Seilspringen" / en „Jump Rope"; kein Schlüssel für Box Jumps/Skater Hops |
| Vorhandener Schlüssel „Jump Rope" | BEWIESEN unverändert | Inhalt in HEAD identisch (de Seilspringen, en Jump Rope, manual); `git diff -U0` zeigt in keiner Datei eine `-`-Zeile |
| AC-9 erste 43 / alle 58 unverändert | BEWIESEN | test_first43Entries_unchanged grün; Diff append-only (keine `-`-Zeile) |
| AC-10 bis AC-30 | ERWARTET OFFEN (A2b/A2c) | nicht Gegenstand |
| AC-31 unberührt | BEWIESEN | `git status`: nur die 3 erlaubten Dateien geändert (plus untracked Workflow-Artefakte); `LeanHealthTimerTests/` ohne Diff |

## Datenprüfung

- JSON gültig (`python3 -m json.tool`), xcstrings gültiges JSON ohne Doppelschlüssel.
- `englishNameIds`: 55 Schlüssel, keine Duplikate; „Jump Rope" einmal (Z. 635). Der Name steht wortgleich in WorkoutProgramsView.swift Z. 315 (Vorschlagsliste) und wird korrekt aufgelöst.
- Sortierung xcstrings: „Seilspringen" nach `%llds`, `exercise.*` danach alphabetisch (box-jumps, seilspringen, skater-hops), vor `•`; konsistent mit der bestehenden Reihenfolge.

## Fachliche Gegenlesung

- Box Jumps: klar gegen Jump-Kniebeugen abgegrenzt (Sprung auf Erhöhung, Landung oben), Abstieg gehend (Achillessehne), stabile rutschfeste Box, Höhe wählbar. DE/EN inhaltsgleich.
- Skater Hops: seitlich, Landung auf einem Bein, Hinterbein diagonal, Knie nicht nach innen. DE/EN inhaltsgleich.
- Seilspringen: Springseil nötig, Handgelenke statt Schultern, Fußballen, 30-60 s, ruhig atmen. DE/EN inhaltsgleich. Keine Tippfehler gefunden.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Findings

Keine Defekte.

Code reference: Meditationstimer iOS/Services/ExerciseDatabase.swift:633
Code reference: Meditationstimer iOS/Localizable.xcstrings:1
Code reference: Contracts/catalog/builtin-exercises.json:1

VERDICT: VERIFIED

Begründung: Testbild entspricht exakt der Erwartung (7 grün; 5 rot, ausschließlich Nr. 19-24, Endanzahl 67/Version 2 und A2c-1). Daten konsistent, append-only, nur die 3 erlaubten Dateien geändert, Testdatei unberührt, vorhandener „Jump Rope"-Schlüssel unverändert.

## Geprüfte Dateien

- sha256:6a5436d46765708dd4644176a4e141a83e1424d22cf58994731def7042fc6c20  Contracts/catalog/builtin-exercises.json
- sha256:78684711f3ef2d8f03196a449a7f8d9797b5489531c7cf2212c501e723143ce3  Meditationstimer iOS/Localizable.xcstrings
- sha256:355cba588944d2204969dce60106be2f2eaff90e96a4139a728a615153a30a46  Meditationstimer iOS/Services/ExerciseDatabase.swift

## Prüfbasis

- base: 2f56d2efd05e7ab583fc5ce989a12fd0969ad725
- blob:3a3c5a36c8a4f2ce1fde5ff209dc1940fdb4f72e  Contracts/catalog/builtin-exercises.json
- blob:d55b728d0fe681ddb57120f23498a13828c48237  Meditationstimer iOS/Localizable.xcstrings
- blob:b5c92366cb2f7a17497ee7f3ee1ac85c0845ee61  Meditationstimer iOS/Services/ExerciseDatabase.swift
