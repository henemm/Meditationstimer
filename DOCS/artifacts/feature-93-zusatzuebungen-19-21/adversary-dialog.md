# Adversary-Protokoll Runde A2d-2c (Issue #93)

Eigener Lauf: `xcodebuild test ... -only-testing:LeanHealthTimerTests/ExerciseCatalogTests` (iPhone 17 Pro, OS 27.2), Ergebnisbündel im Scratchpad (`adv93.xcresult`), Rohprotokoll `adversary-test-output.txt`. 12 Testfälle ausgeführt, 7 grün, 5 rot, alle 5 Rotfälle laut Spec erwartet.

## Prüfpunkte dieser Runde (A2d-2c)

- [x] AC-1 Gleichlauf JSON/Swift für Nr. 1-64 (Endanzahl 67 erwartet offen bis A2d-2d), catalogVersion bleibt 1
- [x] AC-2 Kennungen gültig und eindeutig
- [x] AC-3 deutscher Name → Kennung
- [x] AC-4 englischer Name → Kennung für Downward Dog, Cobra Stretch, Cat-Cow (Nr. 22-24 erwartet offen); Aliase wortgleich zur Vorschlagsliste
- [x] AC-5/6/7 unberührt grün
- [x] AC-8 Nr. 19-21 mit Kategorie, Wirkung und Anleitung DE/EN, Namensschlüssel für die drei deutschen Namen
- [x] AC-9 vorhandene Einträge unverändert, Diff append-only
- [x] AC-31 nur die 3 erlaubten Dateien geändert, Testdatei unberührt
- [x] Altschlüssel „Downward Dog", „Cobra Stretch", „Cat-Cow" unverändert
- [x] Fachliche Abgrenzung der Texte

AC-10 bis AC-30 gehören zu späteren Schnitten und sind nicht Gegenstand dieser Runde.

### Runde 1 — eigener Testlauf

Fragestellung: Entspricht das Testbild exakt der Erwartung, oder gibt es zusätzliche Rotfälle?

## Testlauf gegen erwartetes Bild

| Test | Ergebnis | Erwartet? |
|---|---|---|
| test_newExercises_haveTextsInDeAndEn_andCategory | rot: `Kennung builtin.sitzende-vorbeuge fehlt` | ja, Nr. 19-21 bestehen, Abbruch erst bei Nr. 22 |
| test_idForEnglishName_returnsBuiltinId | rot für genau 3 Namen: Seated Forward Bend, Shoulder Stretch Left/Right (Nr. 22-24) | ja; Downward Dog, Cobra Stretch, Cat-Cow nicht unter den Fehlern |
| test_catalog_matchesBuiltinExercisesJson | rot nur `64 != 67` | ja |
| test_catalog_has67EntriesAndVersion2 | rot `64 != 67` (x2), `1 != 2` | ja (A2d-2d) |
| test_defaultPrograms_referenceExistingCatalogIds | rot: "Schritt ... ohne exerciseId" | ja (A2c-1) |
| test_catalogIds_matchRegexAndAreUnique, test_first43Entries_unchanged, test_idForGermanName, test_idForNameWithLeftRightSuffix, test_idForUnknownSuffixName, test_infoForEnglishName, test_origin_derivedFromPrefix | grün | ja |

Kein zusätzlicher Rotfall.

### Runde 2 — Datenprüfung per Skript, Edge Cases, Fachtexte

Fragestellung: Halten Daten, Schlüssel und Texte jenseits der Tests (Doppelungen, Kollision, Übersetzungsgleichheit, Altschlüssel)?

## Checkliste

| Nr. / AC | Status | Beweis |
|---|---|---|
| AC-1 | BEWIESEN für Nr. 1-64; Endanzahl 67 ERWARTET OFFEN | Skript: JSON 64, Swift 64, (id, name, category, Reihenfolge) identisch; `catalogVersion` 1 |
| AC-2 | BEWIESEN | Test grün; keine doppelte Kennung; builtin.herabschauender-hund, builtin.cobra-dehnung, builtin.cat-cow |
| AC-3 | BEWIESEN | test_idForGermanName grün; Namen „Herabschauender Hund" / „Kobra-Dehnung" / „Katze-Kuh" |
| AC-4 | BEWIESEN für Nr. 19-21, ERWARTET OFFEN für Nr. 22-24 | genau 3 Fehler (Nr. 22-24); Aliase in ExerciseDatabase.swift (englishNameIds) wortgleich zu WorkoutProgramsView.swift Z. 319/321/322 |
| AC-5/6/7 | BEWIESEN (unberührt) | LeftRight, UnknownSuffix, origin, infoForEnglishName grün |
| AC-8 Nr. 19-21 | BEWIESEN | Kategorien stretching/stretching/warmup; 6 Schlüssel `exercise.<slug>.effect/.instructions` de+en `translated`, `extractionState manual`, EN nicht leer; DE-`value:` in Swift == de in xcstrings 6/6; 3 Namensschlüssel (de Name, en Downward Dog / Cobra Stretch / Cat-Cow, manual) |
| Altschlüssel | BEWIESEN unverändert | Vergleich HEAD vs. Arbeitsstand: 0 geänderte bestehende Schlüssel, 9 neue Schlüssel |
| AC-9 | BEWIESEN | test_first43Entries_unchanged grün; `git diff -U0` zeigt keine `-`-Zeile |
| AC-10 bis AC-30 | ERWARTET OFFEN | nicht Gegenstand |
| AC-31 | BEWIESEN | nur 3 erlaubte Dateien geändert (203 Einfügungen, 0 Löschungen); `LeanHealthTimerTests/` ohne Diff |

## Datenprüfung

- JSON gültig (`json.tool`), xcstrings gültiges JSON ohne Doppelschlüssel (Hook auf Duplikate geprüft).
- Neue Namensschlüssel kollidieren nicht mit bestehenden (nur neue Schlüssel, keine geänderten).
- `englishNameIds`: Aliase einmalig, keine Dopplung.

## Fachliche Gegenlesung

- Herabschauender Hund: gehaltene Dehnung (20-30 s), ausdrücklich abgegrenzt gegen „Planke zu Herabschauender Hund" (DE und EN „Plank to Downward Dog"), Knie dürfen gebeugt bleiben. Sinngleich.
- Kobra-Dehnung: Hüfte bleibt am Boden, Schultern weg von den Ohren, Rückenhinweis (nur so weit, wie der untere Rücken schmerzfrei bleibt). Sinngleich. Leichte Abweichung: DE „Brustwirbelsäule", EN „upper back" (sinngleich, Alltagssprache).
- Katze-Kuh: Mobilisierung im Atemrhythmus (Ausatmen Katze, Einatmen Kuh), ausdrücklich keine Haltedehnung, 8-10 Wiederholungen. Sinngleich. Keine Tippfehler gefunden.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Findings

Keine Defekte.

Code reference: Meditationstimer iOS/Services/ExerciseDatabase.swift:555
Code reference: Meditationstimer iOS/Localizable.xcstrings:1
Code reference: Contracts/catalog/builtin-exercises.json:1

VERDICT: VERIFIED

Begründung: Testbild entspricht exakt der Erwartung (7 grün; 5 rot, ausschließlich Nr. 22-24, Endanzahl 67/Version 2 und A2c-1). Daten konsistent, append-only, nur die 3 erlaubten Dateien geändert, Testdatei unberührt, Altschlüssel unverändert.

## Geprüfte Dateien

- sha256:a850c020f43673be17cdac633de45ee7f213d0e7060291bb4f32e9c72e915cda  Contracts/catalog/builtin-exercises.json
- sha256:785f24dcad0e31c7c88cefd0e85d4762a05abc2c20a256e692bcbf4bb65dbc28  Meditationstimer iOS/Localizable.xcstrings
- sha256:49d669cdd1ca42db8c4fbe9a1c213375a4765c66c6bc0f410c285ed293d287e2  Meditationstimer iOS/Services/ExerciseDatabase.swift

## Prüfbasis

- base: 2f56d2efd05e7ab583fc5ce989a12fd0969ad725
- blob:e2b15f99e6f47619e27587810e88fc3e742d2e9f  Contracts/catalog/builtin-exercises.json
- blob:acbf9f930a16336742b70c21246f52ddf611d9e5  Meditationstimer iOS/Localizable.xcstrings
- blob:db7fdcd6828a4c216c0d92663194b4826d16029d  Meditationstimer iOS/Services/ExerciseDatabase.swift
