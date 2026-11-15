# Adversary-Protokoll A2d-1a (Issue #80, Workflow feature-80-zusatzuebungen-1-12)

Grundlage: Spec `DOCS/specs/features/feature-48-uebungskatalog.md`, Zeile A2d-1a. Nur lesend geprüft, nichts geändert.
Testausgabe: `docs/artifacts/feature-80-zusatzuebungen-1-12/adversary-test-output-a2d-1a.txt`

## Runde 1 - Prüfung gegen die Checkliste

| Punkt | Bewertung | Beweis |
|---|---|---|
| AC-1 Gleichlauf JSON/Swift | BEWIESEN, rot nur an Endanzahl | JSON 47 Einträge (python), Katalog 47; test_catalog_matchesBuiltinExercisesJson scheitert nur an `("47") is not equal to ("67")` (2x), keine Fehler pro Position |
| AC-2 Kennungen Regex, eindeutig | BEWIESEN | test_catalogIds_matchRegexAndAreUnique grün; zusätzlich Skript: 47 verschieden, alle passen `^(builtin\|own)\.[a-z0-9]+(-[a-z0-9]+)*$` |
| AC-3/5/6/7 | BEWIESEN grün | idForGermanName, idForNameWithLeftRightSuffix, idForUnknownSuffixName in der Liste der 249 bestandenen, nicht in den 14 roten |
| AC-4 Nr. 1-4 | BEWIESEN | Swift `ExerciseDatabase.swift:498-501`; die 20 Fehler von test_idForEnglishName nennen nur Sit-ups bis Shoulder Stretch Right (Nr. 5-24), kein Fehler für Hollow Hold, Dead Bug, Flutter Kicks, V-Ups. Groß-/Kleinschreibung und Ränder über `lookupKey` (Z. 505ff.), "  plank " bleibt grün |
| AC-8 Nr. 1-4 | BEWIESEN | Kennung/Name/Kategorie `.core` in Swift Z. 402-435 und JSON wie Spec-Tabelle 80-83; 8 xcstrings-Einträge de+en vorhanden, verschieden, nicht leer; test_newExercises bricht erst bei `builtin.sit-ups` ab (Nr. 5), also Nr. 1-4 bestehen alle Prüfungen inkl. `tEn.effect != tDe.effect`. Fachlich gelesen: Hollow Hold (Rückenpresse, Rücken hohl -> Beine höher), Dead Bug (gegengleich, 90 Grad), Flutter Kicks (Hände unter Gesäß, kleine Wechselschläge), V-Ups (V, Hände an Füße) korrekt, EN keine deutsche Kopie |
| AC-9 erste 43 unverändert, Version 1 | BEWIESEN | git diff: JSON nur angehängt (+20), Swift nur Einfügung nach Hüftkreisen, xcstrings 161 Einfügungen, 0 Löschungen; `catalogVersion` 1; test_first43Entries_unchanged grün |
| xcstrings-Metadaten | BEWIESEN | alle 9 Einträge `extractionState: manual`, `state: translated` in de und en; Schlüssel `exercise.<slug>.effect/.instructions`; "Beinpendel" en "Leg Swing" (`Localizable.xcstrings:11972`); keine Namensschlüssel für die 4 neuen; JSON gültig, keine doppelten Schlüssel (Prüfung mit object_pairs_hook) |
| Kompilierte Fassung | BEWIESEN | App-Bundle `en.lproj/Localizable.strings`: `exercise.v-ups.effect` englisch, `Beinpendel => Leg Swing`; `de.lproj`: deutsch |
| localizedTexts über Bundle | BEWIESEN | `ExerciseDatabase.swift:573-580` löst Name, Wirkung, Anleitung über das übergebene Bundle auf, Rückfall `info.effect/instructions`; die 43 alten Einträge haben keine Schlüssel `exercise.<slug>.*`, fallen also auf den bisherigen Text zurück (unverändert wie vorher) |
| Umfang | BEWIESEN | `git diff --stat`: 224 Einfügungen, 2 Löschungen (inkl. 161 xcstrings), Swift 45, JSON 20; nur die drei Dateien geändert; `ExerciseCatalogTests.swift` und `server/test/mcp-read.test.ts` unverändert (nicht in `git diff --name-only`). Funktionen: localizedTexts 8 Zeilen |

## Testbild (selbst ausgeführt, Simulator iPhone 17 Pro, iOS 27.2)

`** TEST FAILED **`, 249 bestanden, genau 14 rot, jeder einzeln:
1. test_newExercises_haveTextsInDeAndEn_andCategory: `XCTUnwrap ... Kennung builtin.sit-ups fehlt` (erwartet, Nr. 5)
2. test_idForEnglishName_returnsBuiltinId: 20 Fehler, Sit-ups ... Shoulder Stretch Right (erwartet, genau 20)
3. test_catalog_matchesBuiltinExercisesJson: nur `47 != 67` (2x) (erwartet)
4. test_catalog_has67EntriesAndVersion2: `47 != 67`, `1 != 2` (erwartet, A2d-2)
5. test_defaultPrograms_referenceExistingCatalogIds: Schritte ohne exerciseId (A2c-1, erwartet)
6-14. WorkoutPhaseMigrationTests, 9 Gerüst-Tests (announcement, corruptJson, existingUserStore, hint_normalization, missingExerciseId, noBackup, oldJson, selectingCatalogOrOwnExercise, spokenText) (A2b-0/A2b, erwartet)
Kein weiterer roter Test.

## Runde 2 - Eigene Befunde hinterfragt, Randfälle

- "V-Ups" gegen "V-ups"/" v-ups ": `lookupKey` trimmt und macht klein, Tabellenschlüssel werden ebenso normalisiert; beides löst auf `builtin.v-ups`. Kein Befund.
- Doppelte Kennungen/Schlüssel: keine (Skript, Regex, Dictionary `uniquingKeysWith` würde sie ohnehin verschlucken, daher zusätzlich die Mengenprüfung 47=47).
- Komma/JSON-Fehler in xcstrings: Datei parst, Build kompiliert sie, beide Sprachen im Bundle.
- "Leg Swing" abgeleitet: `Beinpendel` EN "Leg Swing"; `englishNameIds` kennt "Leg Swing Left/Right", nicht den Grundnamen "Leg Swing" (Spec fordert das nicht, AC-4 nennt ihn nicht). Kein Verstoß.
- Endungen links/rechts: unverändert, test_idForNameWithLeftRightSuffix grün. Hinweis ohne Spec-Bezug: `displayName` für `builtin.beinpendel` liefert nun "Leg Swing" ohne Seite (vorher in DE ebenfalls "Beinpendel" ohne Seite, Verhalten des Entwurfs A2a, nicht neu).
- Der Info-Dialog (`ExerciseDetailSheet.swift`, Zeile 17-19, 36) liest `info.effect`, also die per `NSLocalizedString` im Hauptbundle aufgelöste Fassung, nicht `localizedTexts`; das Hauptbundle enthält die en-Texte (siehe oben), der Weg funktioniert. Kein Befund.

## App-Durchlauf (Test Plan) - NICHT vollständig durchführbar

Gebaut, im Simulator installiert und gestartet (de und en), Start gelingt: `adversary-launch-de.png`, `adversary-launch-en.png` (Englisch zeigt "Open Meditation", "Breathing Exercises"). Der geforderte Schritt "im Schritt-Editor V-Ups wählen, Info-Blatt öffnen" scheitert technisch: In dieser Umgebung gibt es keine Werkzeuge zum Antippen im Simulator (kein idb/axe, kein Computer-Use-Werkzeug), `simctl` kann nur starten und Bilder aufnehmen. Ein eigener UI-Test hätte Testdateien verändert, das war ausgeschlossen. Deshalb gibt es `adversary-vups-de.png` und `adversary-vups-en.png` NICHT. Ersatznachweise: Bundle-Inhalt (en/de.lproj) und die grünen/erwarteten Unit-Tests. Das ist kein Grün für den Durchlauf.

## Befunde

[
  {
    "id": "F001",
    "severity": "LOW",
    "category": "anti_pattern",
    "description": "App-Durchlauf (Info-Blatt V-Ups in de/en) nicht ausgeführt, weil im Simulator nichts angetippt werden kann; es fehlen adversary-vups-de.png und adversary-vups-en.png",
    "evidence": "docs/artifacts/feature-80-zusatzuebungen-1-12/adversary-launch-en.png, kompilierte en.lproj/de.lproj enthalten exercise.v-ups.* in der jeweiligen Sprache",
    "remediation": "Durchlauf mit einem UI-Test oder Tap-Werkzeug nachholen (z. B. in A2d-1c, wenn der Pflichtdurchlauf ansteht)"
  }
]

Kein Befund zu Spec-Verstoß, Regression oder Umfang.


## Nachtrag Orchestrator (Angabe des Orchestrators, nicht von mir erzeugt; Zählung von mir geprüft)

Der Orchestrator ließ die Unit-Suite mit `-skip-testing` für genau die 14 ausgewiesenen Tests späterer Schnitte laufen
(`docs/artifacts/feature-80-zusatzuebungen-1-12/test-scope-a2d-1a.txt`, `** TEST SUCCEEDED **`). Der erste Versuch scheiterte
laut Orchestrator vor dem ersten Test an der Installation im Simulator (Infrastruktur), die Wiederholung lief grün.

Meine Prüfung dieser Datei: Die 14 `-skip-testing`-Argumente (5 ExerciseCatalogTests, 9 WorkoutPhaseMigrationTests) sind namensgleich
mit den 14 roten Tests meines eigenen Laufs. 0 fehlgeschlagen. Bestanden sind 249 Tests (`grep -c "' passed on"` = 249 in dieser Datei und in meiner
`adversary-test-output-a2d-1a.txt`; meine frühere Zählung 248 war falsch, weil eine Erfolgszeile durch verschränkte Ausgabe nicht mit "Test case" beginnt,
z. B. `EngineTests.testCancelledNotificationEquality`). 249 + 14 übersprungene bzw. rote = 263 Tests insgesamt in beiden Läufen.
F001 (App-Durchlauf Info-Blatt V-Ups DE/EN) bleibt offen und wird laut Orchestrator in /60-validate nachgeholt.

## Checkliste A2d-1a (meine Fassung, jeder Punkt von mir belegt)

- [x] AC-1 Gleichlauf JSON/Swift, 47 Einträge, rot nur an Endanzahl 67 (Positionsvergleich ohne Fehler)
- [x] AC-2 Kennungen gültig (Regex) und eindeutig
- [x] AC-3/AC-5/AC-6/AC-7 bleiben grün
- [x] AC-4 Nr. 1-4 englischer Name auf Kennung, ohne Groß-/Kleinschreibung und mit Randleerzeichen
- [x] AC-8 Nr. 1-4 Kennung, Name, Kategorie core, Wirkung/Anleitung DE und EN verschieden und fachlich korrekt
- [x] AC-9 erste 43 unverändert, catalogVersion 1
- [x] xcstrings manual/translated in de und en, Schlüsselmuster, Beinpendel auf Leg Swing, keine Namensschlüssel für die 4 neuen
- [x] localizedTexts löst über das Bundle auf, Rückfall bisheriger Text
- [x] Umfang höchstens 250 Zeilen, nur drei Dateien, ExerciseCatalogTests.swift und mcp-read.test.ts unverändert
- [x] Testbild: genau die 14 Tests späterer Schnitte rot (mein Lauf), Lauf ohne sie 249 bestanden, 0 fehlgeschlagen

Code reference: Meditationstimer iOS/Services/ExerciseDatabase.swift:402
Code reference: Meditationstimer iOS/Services/ExerciseDatabase.swift:498
Code reference: Meditationstimer iOS/Services/ExerciseDatabase.swift:505
Code reference: Meditationstimer iOS/Services/ExerciseDatabase.swift:517
Code reference: Meditationstimer iOS/Services/ExerciseDatabase.swift:573
Code reference: Contracts/catalog/builtin-exercises.json:2
Code reference: Contracts/catalog/builtin-exercises.json:221
Code reference: Meditationstimer iOS/Localizable.xcstrings:11972
Code reference: Meditationstimer iOS/Localizable.xcstrings:11989
Code reference: Meditationstimer iOS/Localizable.xcstrings:12025
Code reference: Meditationstimer iOS/Localizable.xcstrings:12061
Code reference: Meditationstimer iOS/Localizable.xcstrings:12097
Code reference: Meditationstimer iOS/Views/ExerciseDetailSheet.swift:50
Code reference: LeanHealthTimerTests/ExerciseCatalogTests.swift:196
Code reference: LeanHealthTimerTests/ExerciseCatalogTests.swift:251

## Nachprüfung Runde A2a-Dateien (Diff 2f56d2e..HEAD, jeweils selbst gelesen)

- `Models/ExerciseInfo.swift`: A2a fügt `let id` und `ExerciseOrigin` hinzu. Alle neuen Einträge in ExerciseDatabase.swift übergeben `id:` als ersten Parameter, kein Aufrufer verwendet den alten Initialisierer. Bestätigt, passt zu A2d-1a.
- `Tabs/WorkoutTab.swift`: A2a macht nur `defaultWorkoutSets` nicht mehr `private` (Test-Zugriff). Keine Berührung mit A2d-1a. Bestätigt.
- `Tabs/WorkoutProgramsView.swift`: A2a ergänzt optionale `exerciseId`/`hint`, Gerüst-Stubs (Ursache der 9 erwarteten roten Gerüst-Tests) und übergibt an `ExerciseDetailSheet` `exerciseId: ExerciseDatabase.exerciseId(forName:)`. Mit A2d-1a löst "V-Ups" auf `builtin.v-ups` auf und das Blatt findet den neuen Eintrag. Die Vorschlagsliste enthält die vier Namen (Zeilen 264-271). Kein Rückschritt, bestätigt.

Code reference: Meditationstimer iOS/Models/ExerciseInfo.swift:13
Code reference: Meditationstimer iOS/Models/ExerciseInfo.swift:50
Code reference: Meditationstimer iOS/Tabs/WorkoutTab.swift:813
Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:209
Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:1280
Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:1732

Offen (kein AC dieser Runde, Test-Plan-Durchlauf): F001 App-Durchlauf Info-Blatt V-Ups DE/EN, nachzuholen in /60-validate.

## Verdict
**VERIFIED**

## Geprüfte Dateien

- sha256:647e34948ad7eb48392b39319d27dc472ddc0ab53112778f6d2aef61ad96a88b  Contracts/catalog/builtin-exercises.json
- sha256:60fd8c2b449f0c81a907c27614a02a6121d7ab62d19c3be7b8f03f0d4070e4f8  LeanHealthTimerTests/ExerciseCatalogTests.swift
- sha256:3385d09b4f20c613e6c88a5eb8ef83925068fa3125d884bb0aa2cf56888475bd  Meditationstimer iOS/Localizable.xcstrings
- sha256:7dc57473c77fa8ceec4ed189d5c366ee0d92a3e52d154a72e720deeec7175fbd  Meditationstimer iOS/Models/ExerciseInfo.swift
- sha256:25437475e185b6533cd5eac86f55ace193cc4e8085d388fb5207e6b82447e390  Meditationstimer iOS/Services/ExerciseDatabase.swift
- sha256:0cefb51062cd1a190a64b3ea72445dd2fdc56de7e1dc76c399d71c1316df534a  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- sha256:d999efc527e89d54dfd2afa3a014ff5bc2d9244950e7dda0cd4b9db0366fcd84  Meditationstimer iOS/Tabs/WorkoutTab.swift
- sha256:c6ea985e32eb37f3b3f5106d86abc375b4ac54f50919b65db296445229a854c5  Meditationstimer iOS/Views/ExerciseDetailSheet.swift

## Prüfbasis

- base: 2f56d2efd05e7ab583fc5ce989a12fd0969ad725
- blob:b0ef08fe9bcf2d2a209f62fb91ca8843864e7446  Contracts/catalog/builtin-exercises.json
- blob:7834ef35a598d7e8d1c7d31c38e1e87d9463b04f  LeanHealthTimerTests/ExerciseCatalogTests.swift
- blob:f5156cc97f75ad853bc0466b11a7868a566260d2  Meditationstimer iOS/Localizable.xcstrings
- blob:207480164b29b550374f7d6811aa1fb502c39d13  Meditationstimer iOS/Models/ExerciseInfo.swift
- blob:c74b3fea701d7290a69242e98c02be8da1b30f98  Meditationstimer iOS/Services/ExerciseDatabase.swift
- blob:5a6840c9f670b1ef2bc23f70a593e1b63f12513f  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- blob:c92dc4cedd3dd60154219675442944d9ced41547  Meditationstimer iOS/Tabs/WorkoutTab.swift
- blob:5dc11d003e1251b94e455633c20ffe6bd6351fd4  Meditationstimer iOS/Views/ExerciseDetailSheet.swift

## Geprüfte Dateien

- sha256:647e34948ad7eb48392b39319d27dc472ddc0ab53112778f6d2aef61ad96a88b  Contracts/catalog/builtin-exercises.json
- sha256:60fd8c2b449f0c81a907c27614a02a6121d7ab62d19c3be7b8f03f0d4070e4f8  LeanHealthTimerTests/ExerciseCatalogTests.swift
- sha256:3385d09b4f20c613e6c88a5eb8ef83925068fa3125d884bb0aa2cf56888475bd  Meditationstimer iOS/Localizable.xcstrings
- sha256:7dc57473c77fa8ceec4ed189d5c366ee0d92a3e52d154a72e720deeec7175fbd  Meditationstimer iOS/Models/ExerciseInfo.swift
- sha256:25437475e185b6533cd5eac86f55ace193cc4e8085d388fb5207e6b82447e390  Meditationstimer iOS/Services/ExerciseDatabase.swift
- sha256:0cefb51062cd1a190a64b3ea72445dd2fdc56de7e1dc76c399d71c1316df534a  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- sha256:d999efc527e89d54dfd2afa3a014ff5bc2d9244950e7dda0cd4b9db0366fcd84  Meditationstimer iOS/Tabs/WorkoutTab.swift
- sha256:c6ea985e32eb37f3b3f5106d86abc375b4ac54f50919b65db296445229a854c5  Meditationstimer iOS/Views/ExerciseDetailSheet.swift

## Prüfbasis

- base: 2f56d2efd05e7ab583fc5ce989a12fd0969ad725
- blob:b0ef08fe9bcf2d2a209f62fb91ca8843864e7446  Contracts/catalog/builtin-exercises.json
- blob:7834ef35a598d7e8d1c7d31c38e1e87d9463b04f  LeanHealthTimerTests/ExerciseCatalogTests.swift
- blob:f5156cc97f75ad853bc0466b11a7868a566260d2  Meditationstimer iOS/Localizable.xcstrings
- blob:207480164b29b550374f7d6811aa1fb502c39d13  Meditationstimer iOS/Models/ExerciseInfo.swift
- blob:c74b3fea701d7290a69242e98c02be8da1b30f98  Meditationstimer iOS/Services/ExerciseDatabase.swift
- blob:5a6840c9f670b1ef2bc23f70a593e1b63f12513f  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- blob:c92dc4cedd3dd60154219675442944d9ced41547  Meditationstimer iOS/Tabs/WorkoutTab.swift
- blob:5dc11d003e1251b94e455633c20ffe6bd6351fd4  Meditationstimer iOS/Views/ExerciseDetailSheet.swift

## Geprüfte Dateien

- sha256:647e34948ad7eb48392b39319d27dc472ddc0ab53112778f6d2aef61ad96a88b  Contracts/catalog/builtin-exercises.json
- sha256:60fd8c2b449f0c81a907c27614a02a6121d7ab62d19c3be7b8f03f0d4070e4f8  LeanHealthTimerTests/ExerciseCatalogTests.swift
- sha256:3385d09b4f20c613e6c88a5eb8ef83925068fa3125d884bb0aa2cf56888475bd  Meditationstimer iOS/Localizable.xcstrings
- sha256:7dc57473c77fa8ceec4ed189d5c366ee0d92a3e52d154a72e720deeec7175fbd  Meditationstimer iOS/Models/ExerciseInfo.swift
- sha256:25437475e185b6533cd5eac86f55ace193cc4e8085d388fb5207e6b82447e390  Meditationstimer iOS/Services/ExerciseDatabase.swift
- sha256:0cefb51062cd1a190a64b3ea72445dd2fdc56de7e1dc76c399d71c1316df534a  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- sha256:d999efc527e89d54dfd2afa3a014ff5bc2d9244950e7dda0cd4b9db0366fcd84  Meditationstimer iOS/Tabs/WorkoutTab.swift
- sha256:c6ea985e32eb37f3b3f5106d86abc375b4ac54f50919b65db296445229a854c5  Meditationstimer iOS/Views/ExerciseDetailSheet.swift

## Prüfbasis

- base: 2f56d2efd05e7ab583fc5ce989a12fd0969ad725
- blob:b0ef08fe9bcf2d2a209f62fb91ca8843864e7446  Contracts/catalog/builtin-exercises.json
- blob:7834ef35a598d7e8d1c7d31c38e1e87d9463b04f  LeanHealthTimerTests/ExerciseCatalogTests.swift
- blob:f5156cc97f75ad853bc0466b11a7868a566260d2  Meditationstimer iOS/Localizable.xcstrings
- blob:207480164b29b550374f7d6811aa1fb502c39d13  Meditationstimer iOS/Models/ExerciseInfo.swift
- blob:c74b3fea701d7290a69242e98c02be8da1b30f98  Meditationstimer iOS/Services/ExerciseDatabase.swift
- blob:5a6840c9f670b1ef2bc23f70a593e1b63f12513f  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- blob:c92dc4cedd3dd60154219675442944d9ced41547  Meditationstimer iOS/Tabs/WorkoutTab.swift
- blob:5dc11d003e1251b94e455633c20ffe6bd6351fd4  Meditationstimer iOS/Views/ExerciseDetailSheet.swift
