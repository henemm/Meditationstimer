# Adversary Dialog — feature-48-uebungskatalog, Runde Schnitt A2a (inkl. API-Gerüst)
Spec: docs/specs/features/feature-48-uebungskatalog.md
Datum: 2026-11-15
Testausgabe: docs/artifacts/feature-48-uebungskatalog/adversary-test-output.txt
Lauf: `Executed 262 tests, with 105 failures` (iPhone 17 Pro, OS 27.2, nicht parallel). Kein Test außerhalb von ExerciseCatalogTests / WorkoutPhaseMigrationTests scheitert.

## Checkliste (Stand A2a)
- [x] AC-1 BEWIESEN (Stand A2a): `test_catalog_matchesBuiltinExercisesJson` scheitert ausschließlich an den zwei Anzahl-Zeilen ExerciseCatalogTests.swift:159/160 (43 vs 67, "Endstand"). Keine Meldung zu Kennung/Name/Kategorie/Reihenfolge. Erwartetes Rot A2d.
- [x] AC-2 BEWIESEN: `test_catalogIds_matchRegexAndAreUnique` passed.
- [x] AC-3 BEWIESEN: `test_idForGermanName_returnsBuiltinId` passed; ExerciseDatabase.swift:479 (Schritt 1 deutscher Name; lookupKey :467 trim + lowercase).
- [x] AC-4 BEWIESEN für die 37: `test_idForEnglishName_returnsBuiltinId` hat genau 24 Fehlermeldungen (Zeile 203), alle für neue Namen (Hollow Hold, Dead Bug, Flutter Kicks, V-Ups, Sit-ups, Crunches, Archer Push-ups, Decline Push-ups, Dips, Pull-ups, Chin-ups, Australian Pull-ups, Inverted Rows, Step-ups, Wall-Sit, Box Jumps, Skater Hops, Jump Rope, Downward Dog, Cobra Stretch, Cat-Cow, Seated Forward Bend, Shoulder Stretch Left/Right). Die 37-Schleife und "  plank " (Zeile 205) ohne Fehler. Tabelle ExerciseDatabase.swift:426-465 gegen Spec-Tabelle Zeile für Zeile verglichen: gleich.
- [x] AC-5 BEWIESEN: `test_idForNameWithLeftRightSuffix_resolvesBase`, `test_idForUnknownSuffixName_isOwn` passed. "Seitliche Planke links" trifft zuerst den deutschen Katalognamen (:485) und behält die eigene Kennung, bevor die Endung gestrippt wird (:488).
- [x] AC-6 BEWIESEN: `test_origin_derivedFromPrefix` passed; ExerciseInfo.swift:31, :50.
- [x] AC-7 BEWIESEN: `test_infoForEnglishName_findsCatalogEntry` passed; ExerciseDetailSheet.swift:17-19; Aufrufer WorkoutProgramsView.swift:1280, :1732.
- [x] AC-9 (Teil) BEWIESEN: `test_first43Entries_unchanged` scheitert nur an Zeilen 284/285 (43 nicht > 43). Diff: je Eintrag nur eine hinzugefügte `id:`-Zeile.
- [x] AC-31 (Teil) BEWIESEN: Diff berührt nur 5 iOS-Quelldateien; keine Watch/Widget/plist/entitlements-Datei; Schlüssel nur als Default-Parameter des Gerüsts (WorkoutProgramsView.swift:235), Wert unverändert. `exerciseId`/`hint` sind `String?` mit synthetisiertem Codable (decodeIfPresent/encodeIfPresent; nil wird nicht geschrieben; `test_roundTrip_keepsExerciseIdAndHint`, `test_storedExerciseId_notRecomputed` passed). Gerüst-Funktionen: per Grep keine Aufrufer im App-Code. Umbenennung `legacyDefaultWorkoutSets` (WorkoutProgramsView.swift:344) rein lexikalisch, alle Verwendungen mitgezogen; `private`→internal in WorkoutTab.swift:813 ohne Namenskonflikt.
- [x] Regression: 262 Tests, Fehler nur in den zwei Klassen.

Nicht Teil dieser Runde: AC-8 (A2d), AC-10 bis AC-30 außer den Teilen oben.

## Erwartetes Rot späterer Schnitte (einzeln)
ExerciseCatalogTests:
- `test_catalog_has67EntriesAndVersion2` (43≠67, Version 1≠2): A2d.
- `test_newExercises_haveTextsInDeAndEn_andCategory`: A2d (AC-8).
- `test_defaultPrograms_referenceExistingCatalogIds`: A2c-1 (Vorgabe-Schritte ohne exerciseId, AC-27).
- Teilrot nur im A2d-Teil: `test_catalog_matchesBuiltinExercisesJson`, `test_first43Entries_unchanged`, `test_idForEnglishName_returnsBuiltinId`.
WorkoutPhaseMigrationTests (Gerüst-Stubs, A2b-0/A2b): `test_announcement_respectsSpeakSetting`, `test_corruptJson_isBackedUpBeforeFallback`, `test_existingUserStore_unchangedAfterPresetMigration`, `test_hint_normalization`, `test_missingExerciseId_derivedFromName`, `test_noBackup_whenKeyMissingOrValid`, `test_oldJson_loadsLossless`, `test_selectingCatalogOrOwnExercise_setsExerciseId`, `test_spokenText_withAndWithoutHint`.
Grün aus dieser Klasse: `test_ownSlug_rules`, `test_roundTrip_keepsExerciseIdAndHint`, `test_storedExerciseId_notRecomputed`.

## Dialog

### Runde 1
**Adversary:** Namensableitung: Groß-/Kleinschreibung und Ränder via lookupKey und "  plank "-Test belegt. Endung bei Namen, die selbst "links" tragen: deutscher Treffer hat Vorrang (:485), korrekt. Doppelendung "Seitliche Planke links rechts" fiele auf `builtin.seitliche-planke-links` (F001). Unbekannte `claude.*`-Kennung: `info(forId:)` liefert nil, Sheet hat else-Zweig, kein Absturz. Alte `info(for:)` strippte zusätzlich " Left/ Right"; neue nicht (F002). Funktionslängen: größte `slug` ca. 27 Zeilen; alle ≤ 50. Vertauschte Info-Inhalte: Diff zeigt je Eintrag nur eine `id:`-Zeile; id/name/Kategorie gegen JSON durch Test belegt.
**Implementierer:** nicht vorgelegt (Isolation).

### Runde 2
**Adversary:** Früh-Übereinstimmungs-Skepsis: Rot der 15 Tests einzeln anhand der Fehlermeldungszeilen zugeordnet, nicht nur nach Teststatus; Executed 262. Kein Befund über LOW hinaus.
**Implementierer:** nicht vorgelegt.

## Findings
Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: Meditationstimer iOS/Services/ExerciseDatabase.swift:484
  Description: Die Endungsregel schlägt den Grundnamen in allen deutschen Katalognamen nach, auch in solchen mit Endung. "Seitliche Planke links rechts" ergibt `builtin.seitliche-planke-links`.
  Spec requirement: Entscheidung 4 (3), Endung auf eine Katalogübung ohne Endung
  Conflict: Doppelendungen werden einer Katalogübung statt `own.*` zugeordnet; nur durch manuell eingegebene Namen erreichbar, kein Datenverlust.
  Remediation: Grundname nur akzeptieren, wenn er selbst nicht auf " links"/" rechts" endet (optional).

Finding:
  ID: F002
  Severity: LOW
  Category: regression
  Code reference: Meditationstimer iOS/Services/ExerciseDatabase.swift:14
  Description: Die bisherige `info(for:)` strippte auch " Left/ Right/ left/ right" auf deutsche Namen; die neue Ableitung kennt nur " links/ rechts" und normalisiert Unicode nicht (NFD-ü). `info(for:)` hat jetzt keine Aufrufer.
  Spec requirement: AC-7, Entscheidung 4
  Conflict: Spec-konform, aber Verhaltensunterschied; kein Name der früheren Vorschlagsliste betroffen.
  Remediation: Keine nötig; toten Code in A2c-2 entfernen.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:226
  Description: Gerüst mit leeren Rümpfen (normalizedHint gibt Rohwert, spokenText ""); 255 hinzugefügte Zeilen im Produktcode (Schätzung 140, Limit ±250). Stubs sind nicht aufgerufen.
  Spec requirement: Scoping-Limits, Schnitt-Tabelle A2a
  Conflict: Überschreitung der Schätzung; Stubs würden bei Aufruf still falsche Werte liefern.
  Remediation: Keine; in A2b-0/A2b mit echten Rümpfen füllen, vorher nicht anbinden.

## Confirmations
Confirmation:
  AC: AC-1
  Code reference: Meditationstimer iOS/Services/ExerciseDatabase.swift:61
  Evidence: 43 Einträge mit `id:` in JSON-Reihenfolge; Test scheitert nur an Anzahl 67.
  Status: CONFIRMED (Stand A2a)

Confirmation:
  AC: AC-2
  Code reference: Meditationstimer iOS/Models/ExerciseInfo.swift:12
  Evidence: `test_catalogIds_matchRegexAndAreUnique` passed.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Meditationstimer iOS/Services/ExerciseDatabase.swift:479
  Evidence: `test_idForGermanName_returnsBuiltinId` passed.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: Meditationstimer iOS/Services/ExerciseDatabase.swift:426
  Evidence: 37-Zeilen-Tabelle identisch zur Spec; Test scheitert nur an den 24 neuen Namen.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Meditationstimer iOS/Services/ExerciseDatabase.swift:484
  Evidence: beide Suffix-Tests passed; eigener Katalogname hat Vorrang.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: Meditationstimer iOS/Models/ExerciseInfo.swift:50
  Evidence: `test_origin_derivedFromPrefix` passed.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: Meditationstimer iOS/Views/ExerciseDetailSheet.swift:19
  Evidence: `test_infoForEnglishName_findsCatalogEntry` passed; Aufrufer WorkoutProgramsView.swift:1280/1732.
  Status: CONFIRMED

Confirmation:
  AC: AC-31
  Code reference: Meditationstimer iOS/Tabs/WorkoutTab.swift:813
  Evidence: nur private zu internal; Watch/Widget/plist/entitlements unberührt; Rename WorkoutProgramsView.swift:344 lexikalisch.
  Status: CONFIRMED (Teil)

## Herkunft der Vorbedingungen

Kein Sprachprofil konfiguriert (`precondition_origins.default_lang`); keine Tabelle angehängt. Fachlich: `exerciseId` wird in A2a nur lesend aus dem Namen abgeleitet (Bedingung davor: Info-Blatt geöffnet, ExerciseDetailSheet.swift:17); Test für diesen Weg: `test_infoForEnglishName_findsCatalogEntry`.

## Verdict
Alle Punkte dieser Runde bewiesen; erwartetes Rot späterer Schnitte einzeln ausgewiesen. Nur LOW-Befunde.

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:7dc57473c77fa8ceec4ed189d5c366ee0d92a3e52d154a72e720deeec7175fbd  Meditationstimer iOS/Models/ExerciseInfo.swift
- sha256:1c433b75c0aa24e1f829471916b88b62832689c418f8d3823630cd3e8d8f7c92  Meditationstimer iOS/Services/ExerciseDatabase.swift
- sha256:0cefb51062cd1a190a64b3ea72445dd2fdc56de7e1dc76c399d71c1316df534a  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- sha256:d999efc527e89d54dfd2afa3a014ff5bc2d9244950e7dda0cd4b9db0366fcd84  Meditationstimer iOS/Tabs/WorkoutTab.swift
- sha256:c6ea985e32eb37f3b3f5106d86abc375b4ac54f50919b65db296445229a854c5  Meditationstimer iOS/Views/ExerciseDetailSheet.swift

## Prüfbasis

- base: 96c73e26669ee7c740e300cc60076771c5d82db6
- blob:207480164b29b550374f7d6811aa1fb502c39d13  Meditationstimer iOS/Models/ExerciseInfo.swift
- blob:cfcc46c4fb0cdfc6479fee4e702679b86b3bbfdc  Meditationstimer iOS/Services/ExerciseDatabase.swift
- blob:5a6840c9f670b1ef2bc23f70a593e1b63f12513f  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- blob:c92dc4cedd3dd60154219675442944d9ced41547  Meditationstimer iOS/Tabs/WorkoutTab.swift
- blob:5dc11d003e1251b94e455633c20ffe6bd6351fd4  Meditationstimer iOS/Views/ExerciseDetailSheet.swift
