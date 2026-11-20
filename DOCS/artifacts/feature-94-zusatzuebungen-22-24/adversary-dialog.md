# Adversary-Protokoll Runde A2d-2d (Issue #94)

Eigener Lauf: `xcodebuild test ... -only-testing:LeanHealthTimerTests/ExerciseCatalogTests` (iPhone 17 Pro, OS 27.2), Ergebnisbündel im Scratchpad (`adv94.xcresult`), Rohprotokoll `adversary-test-output.txt`. 12 Testfälle ausgeführt, 11 grün, 1 rot, der Rotfall ist laut Spec erwartet (A2c-1).

## Prüfpunkte dieser Runde (A2d-2d)

- [x] AC-1 Gleichlauf JSON/Swift für alle 67 Einträge, catalogVersion 2
- [x] AC-2 Kennungen gültig und eindeutig
- [x] AC-3 deutscher Name → Kennung (inkl. „Vorbeuge im Sitzen")
- [x] AC-4 englischer Name → Kennung für Seated Forward Bend, Shoulder Stretch Left/Right; Aliase wortgleich zur Vorschlagsliste
- [x] AC-8 Nr. 22-24 mit Kategorie stretching, Wirkung und Anleitung DE/EN (DE ≠ EN), Namensschlüssel für die drei deutschen Namen
- [x] AC-9 vorhandene 64 Einträge unverändert, Diff append-only (außer Versionszeile)
- [x] AC-31 nur die 3 erlaubten Dateien geändert, Testdateien unberührt
- [x] Altschlüssel „Seated Forward Bend", „Shoulder Stretch Left", „Shoulder Stretch Right" unverändert
- [x] Fachliche Abgrenzung, Seitenrichtigkeit der Schulter-Texte DE und EN
- [x] Edge Cases: Doppelschlüssel, gültiges JSON, Kollisionen, state/extractionState

AC-5/6/7 unberührt grün. AC-10 bis AC-30 gehören zu späteren Schnitten.

### Runde 1 — eigener Testlauf

Fragestellung: Entspricht das Testbild der Erwartung (11 grün, nur A2c-1 rot)?

| Test | Ergebnis | Erwartet? |
|---|---|---|
| test_catalog_has67EntriesAndVersion2 | grün | ja |
| test_catalog_matchesBuiltinExercisesJson | grün | ja |
| test_catalogIds_matchRegexAndAreUnique | grün | ja |
| test_first43Entries_unchanged | grün | ja |
| test_idForEnglishName_returnsBuiltinId | grün | ja |
| test_idForGermanName_returnsBuiltinId | grün | ja (Tupel Z. 146 „Vorbeuge im Sitzen") |
| test_idForNameWithLeftRightSuffix_resolvesBase | grün | ja |
| test_idForUnknownSuffixName_isOwn | grün | ja |
| test_infoForEnglishName_findsCatalogEntry | grün | ja |
| test_newExercises_haveTextsInDeAndEn_andCategory | grün | ja |
| test_origin_derivedFromPrefix | grün | ja |
| test_defaultPrograms_referenceExistingCatalogIds | rot | ja, A2c-1, laut Spec erwartet |

Kein zusätzlicher Rotfall.

### Runde 2 — Datenprüfung per Skript, Edge Cases, Fachtexte

Fragestellung: Halten Daten, Schlüssel und Texte jenseits der Tests?

Skript (Python, Scratchpad `chk94.py`) gleicht HEAD gegen Arbeitsstand, JSON gegen Swift und xcstrings ab.

| Nr. / AC | Status | Beweis |
|---|---|---|
| AC-1 | BEWIESEN | Skript: JSON 67, Swift 67, (id, name, category, Reihenfolge) identisch; `catalogVersion` 2; `note` unverändert |
| AC-2 | BEWIESEN | 67 eindeutige Kennungen, alle `builtin.[a-z0-9-]+`; keine doppelten Namen (case-insensitiv) |
| AC-3 | BEWIESEN | test_idForGermanName grün; Name „Vorbeuge im Sitzen" in JSON und Swift, Kennung `builtin.sitzende-vorbeuge` |
| AC-4 | BEWIESEN | `englishNameIds` enthält je einen Alias für die drei Namen (Zähler 1), Schreibweise wortgleich zu `WorkoutProgramsView.swift` Z. 323/333/334; alle Alias-Ziele existieren im Katalog, keine doppelten Alias-Schlüssel |
| AC-8 | BEWIESEN | Kategorie stretching x3; 6 Textschlüssel `exercise.<slug>.effect/.instructions` und 3 Namensschlüssel mit de+en `translated`, `extractionState manual`, DE ≠ EN; EN-Namen „Seated Forward Bend", „Shoulder Stretch Left", „Shoulder Stretch Right" |
| AC-9 | BEWIESEN | `exercises[:64]` identisch zu HEAD; `git diff -U0` zeigt nur eine `-`-Zeile in JSON/Swift (Versionszeile) |
| AC-31 | BEWIESEN | `git diff --stat`: genau 3 Dateien; `LeanHealthTimerTests/` ohne Diff |
| Altschlüssel | BEWIESEN | 757 Schlüssel HEAD, 766 neu; 0 geänderte bestehende, 9 neue |

## Datenprüfung

- JSON und xcstrings gültig; beim Laden mit `object_pairs_hook` keine doppelten Schlüssel.
- Der neue Namensschlüssel „Vorbeuge im Sitzen" kollidiert mit keinem vorhandenen Schlüssel; die Altschlüssel „Seated Forward Bend" (de „Vorbeuge im Sitzen") usw. sind unverändert.
- Beobachtung (nicht blockierend): xcstrings endet jetzt mit Zeilenumbruch, HEAD endete ohne; inhaltlich ohne Wirkung.

## Fachliche Gegenlesung

- Vorbeuge im Sitzen: Langsitz mit beiden Beinen, Beugung aus der Hüfte mit langem Rücken, Knie dürfen leicht gebeugt sein. Wirkungstext grenzt ausdrücklich gegen die Hamstring-Dehnung im Stehen ab. DE und EN sinngleich.
- Schulter-Dehnung links: DE „linken Arm quer vor die Brust, mit der rechten Hand am Oberarm, linke Schulter tief, dann zur rechten Seite"; EN „left arm … right hand … left shoulder … " spiegelbildlich korrekt.
- Schulter-Dehnung rechts: DE „rechten Arm … linken Hand … rechte Schulter … linken Seite"; EN „right arm … left hand … right shoulder …" korrekt. Keine vertauschten Seiten. Wirkungstexte nennen links bzw. rechts richtig (DE und EN).
- Keine Tippfehler gefunden.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Findings

Keine Defekte.

Code reference: Meditationstimer iOS/Services/ExerciseDatabase.swift:581
Code reference: Meditationstimer iOS/Localizable.xcstrings:1
Code reference: Contracts/catalog/builtin-exercises.json:1

VERDICT: VERIFIED

Begründung: Testbild entspricht exakt der Erwartung (11 grün; 1 rot, ausschließlich A2c-1). Daten konsistent über JSON, Swift und xcstrings, append-only, nur die 3 erlaubten Dateien geändert, Testdatei unberührt, Schulter-Seiten in DE und EN richtig.

## Geprüfte Dateien

- sha256:bda1d28e24dda08a8e48b1d6330e860d6f10282e3d5de999d14d82c1b84c5835  Contracts/catalog/builtin-exercises.json
- sha256:941ec02ea180f0612575a72631889f5f0c58dc43da4e28b1678b6a8fb8dc62c1  Meditationstimer iOS/Localizable.xcstrings
- sha256:eedf3f289deb24f89068df8275c9c0a2f01f1b2c27f3b352df9140999bc3e841  Meditationstimer iOS/Services/ExerciseDatabase.swift

## Prüfbasis

- base: 94bc499eaaf34cf24ee072b3c7fd9bdd7714b770
- blob:e2b15f99e6f47619e27587810e88fc3e742d2e9f  Contracts/catalog/builtin-exercises.json
- blob:acbf9f930a16336742b70c21246f52ddf611d9e5  Meditationstimer iOS/Localizable.xcstrings
- blob:db7fdcd6828a4c216c0d92663194b4826d16029d  Meditationstimer iOS/Services/ExerciseDatabase.swift
