# Adversary-Protokoll #84 (A2c-1, Epic #48)

Geprüft: uncommittete Änderungen in `Meditationstimer iOS/Tabs/WorkoutTab.swift` und `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift`. Testausgabe: `/tmp/adversary_test_output.txt`.

## Checkliste

- [x] AC-27 24 Schritte mit expliziter `exerciseId` — Beweis: Diff WorkoutTab.swift Z. 803-856, 8+6+6+4 Aufrufe `exerciseId: "builtin.…"`
- [x] AC-27 Test grün — Beweis: unit.txt `Test case 'ExerciseCatalogTests.test_defaultPrograms_referenceExistingCatalogIds()' passed`
- [x] AC-27 Kennung == Namensableitung — Beweis: ExerciseCatalogTests.swift:310 `XCTAssertEqual(id, ExerciseDatabase.exerciseId(forName:))`, im selben Test grün
- [x] AC-30 Migration rein (nur anhängen und Beschreibung nachfüllen) — Beweis: WorkoutProgramsView.swift:341-352; swiftc-Skript 7 Fälle gleich dem alten migrateSets
- [x] AC-30 Test grün — Beweis: unit.txt `Test case 'WorkoutPhaseMigrationTests.test_existingUserStore_unchangedAfterPresetMigration()' passed`
- [x] AC-30 migrateSets speichert nur bei Änderung — Beweis: WorkoutTab.swift:371-377 `if migrated != sets { sets = migrated; saveSets() }`
- [x] AC-28 UI-Test — Beweis: ui.txt `Test Case '-[LeanHealthTimerUITests.WorkoutHintUITests test_infoButton_forPresetPlanke_showsContent]' passed (78.585 seconds)`
- [x] AC-31 Diff ohne Watch/Widget/Plist — Beweis: `git status --short` zeigt nur WorkoutTab.swift und WorkoutProgramsView.swift
- [x] AC-31 Watch- und Widget-Build — Beweis: watch.txt und widget.txt `** BUILD SUCCEEDED **`
- [x] Scope (≤ 5 Dateien, ±250 LoC, Funktionen ≤ 50) — Beweis: `git diff --stat` 2 Dateien, +43/-40; Funktionen 11 und 7 Zeilen
- [x] Sammelzweig-Basis ExerciseDatabase.swift unberührt von #84 und alle 12 builtin-Kennungen vorhanden — Beweis: Verlauf 2c9fe78..HEAD nennt nur #48/#80-#94-Commits, Diff HEAD~1 HEAD leer; sha256 eedf3f28… == feature-94-Protokoll; 12 Kennungen vorhanden, info(forId:) :627
- [x] Sammelzweig-Basis ExerciseDetailSheet.swift unberührt, Namens-Rückfall funktioniert — Beweis: Diff HEAD~1 HEAD leer; sha256 090fe61b… == feature-83-Protokoll; Z. 15 `exerciseId ?? ExerciseDatabase.exerciseId(forName: exerciseName)`
- [x] Sammelzweig-Basis ExerciseInfo.swift unberührt — Beweis: Diff HEAD~1 HEAD leer; sha256 7dc57473… == feature-48- und feature-80-Protokoll
- [x] Sammelzweig-Basis WalkVUpsUITests.swift unberührt (nur Doku-Artefakt aus #80) — Beweis: letzter Commit abfd058 (#80), Diff HEAD~1 HEAD leer; kein früherer Hash in einem Protokoll (Abweichung, nicht blockierend); von #84 nicht referenziert

Code reference: Meditationstimer iOS/Services/ExerciseDatabase.swift:627
Code reference: Meditationstimer iOS/Views/ExerciseDetailSheet.swift:15
Code reference: Meditationstimer iOS/Models/ExerciseInfo.swift:11
Code reference: DOCS/artifacts/feature-80-zusatzuebungen-1-12/validate/WalkVUpsUITests.swift:5
Code reference: Meditationstimer iOS/Tabs/WorkoutTab.swift:803
Code reference: Meditationstimer iOS/Tabs/WorkoutTab.swift:371
Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:341
Code reference: LeanHealthTimerTests/ExerciseCatalogTests.swift:301

## Runde 1: Behauptungen und Beweise

| Punkt | Status | Beweis |
|---|---|---|
| AC-27: 24 Schritte mit expliziter `exerciseId` | BEWIESEN (statisch) | Diff `WorkoutTab.swift` Z. 803-856: 8 (Tabata) + 6 (Core) + 6 (Full Body) + 4 (Quick Burn) = 24 Aufrufe `WorkoutPhase(..., exerciseId: "builtin.…")`, keine Ableitung per Funktion. Alle 12 Kennungen wörtlich wie Spec Z. 228. |
| AC-27: Test grün | UNGEPRÜFT | 4 Läufe von `test_defaultPrograms_referenceExistingCatalogIds` + `test_existingUserStore_unchangedAfterPresetMigration`: jeweils „test runner hung before establishing connection" bzw. „Simulator device failed to launch henemm.Meditationstimer-iOS", Exit 65, **0 Testfälle ausgeführt**, kein `Executed N tests`. Nach Neustart des Simulators und im Leerlauf wiederholt. Gilt nicht als bestanden. |
| AC-27: Kennung == `ExerciseDatabase.exerciseId(forName:)` | UNGEPRÜFT (nur Test würde es beweisen) | Test `ExerciseCatalogTests.swift:301-314` prüft es, lief aber nicht. Lesend: Kennungen entsprechen den Spec-Zuordnungen (Spec Z. 228). Katalogvorhandensein nicht selbst ausgeführt. |
| AC-30: Migration rein, nur (a) anhängen (b) Beschreibung füllen | BEWIESEN (Logik) | `WorkoutProgramsView.swift:341-352`: nur `append` fehlender Namen und Zuweisung `result[i].description`; Schritte/Kennungen/Reihenfolge unberührt. Eigenständiges swiftc-Skript (Scratchpad `mig.swift`, identischer Algorithmus) gegen alten `migrateSets` aus HEAD: 7 Fälle `equal-to-old=true`, `saveFlagMatches=true`, idempotent, `ALL EQUIVALENT`. |
| AC-30: Test grün | UNGEPRÜFT | siehe AC-27, Host-App startet nicht. |
| `migrateSets` speichert nur bei Änderung | BEWIESEN | `WorkoutTab.swift:371-377`: `if migrated != sets { sets = migrated; saveSets() }`; `WorkoutSet` ist `Hashable` mit synthetisiertem `==` (`WorkoutProgramsView.swift:166`), also Gleichheit über alle Felder. Skript: `saveFlagMatches` in allen Fällen, `changed=false` bei vollständigem Bestand. |
| AC-28 UI-Test | UNGEPRÜFT | nicht ausgeführt, derselbe Host-App-Hänger; Spec nennt ihn ohnehin reinen Regressionsschutz (war schon grün). Im Prüfbericht so ausweisen. |
| AC-31: keine Watch-/Widget-/Plist-Dateien | BEWIESEN | `git status --short`: nur die zwei genannten Dateien geändert (plus untracked `.claude/*`). Schlüssel `workoutProgramSets` unverändert (`WorkoutTab.swift:44`, nicht im Diff); `speakExerciseNames` nicht im Diff. |
| AC-31: Watch-/Widget-Scheme bauen | UNGEPRÜFT | Schemen existieren (`Meditationstimer Watch App`, `MeditationstimerWidgetExtension`), Build nicht ausgeführt (Umfeld instabil). Watch/Widget kompilieren die geänderten iOS-Dateien laut Verzeichnisname nicht mit; nicht verifiziert. |
| Scope ≤ 5 Dateien, ±250 LoC, Funktionen ≤ 50 | BEWIESEN | `git diff --stat`: 2 Dateien, 43 + / 40 -; `migratingPresets` 11 Zeilen, `migrateSets` 7 Zeilen. |
| `legacyDefaultWorkoutSets` unberührt | BEWIESEN (mit Hinweis) | Symbol existiert weder im Arbeitsbaum noch in HEAD (`grep` leer; #101 hat die Kopie entfernt); der Diff berührt es nicht. Spec Z. 228 ist veraltet. |

## Runde 2: Nachbohren bei Randfällen

| Randfall | Befund |
|---|---|
| Leerer Bestand | Ergebnis = alle Vorgaben in Vorgabe-Reihenfolge; wie alt (Skript Fall 0). Im Betrieb greift vorher ohnehin `sets = defaultWorkoutSets` (`WorkoutTab.swift:367`). |
| Doppelte Namen im Bestand | Beide bleiben, nichts angehängt, beide Beschreibungen nachgefüllt; wie alt (Fall 3). |
| Umbenannte Vorgabe | wird per Name erneut angehängt; bekanntes, gewolltes Altverhalten, identisch zum alten Code. |
| `description = ""` | wird NICHT nachgefüllt (nur `nil`), identisch zum alten Code (Fall 4). Spec-Wortlaut „leere Beschreibung" ist weiter gefasst als der Code, die Tests nutzen `nil`. Kein Fehler, nur Wortlaut. |
| Vorgabe ohne Beschreibung in Presets | `preset.description != nil` verhindert Überschreiben mit nil; wie alt. |
| Schritte/Kennungen/eigene Programme | werden nie angefasst (Code-Pfad nur `append` und `description`); Skript Fall 6: Schritte bleiben. |
| UUID-Stabilität | `defaultWorkoutSets` ist globales `let`, ids stabil; angehängte Vorgabe hat dieselbe id bei jedem Aufruf, Idempotenz im Skript bestätigt. |
| Regression Aufrufer | `migrateSets` hat einen Aufrufer (`WorkoutTab.swift:365`), `migratingPresets` nur diesen; kein Watch-Code nutzt sie. |

## Findings

- F001, MEDIUM, edge_case/Nachweis: Die Zieltests (AC-27, AC-30) und der UI-Test (AC-28) konnten nicht gültig ausgeführt werden. Beleg: `/tmp/adversary_test_output.txt`, 4 Läufe, 0 Testfälle, „The test runner hung before establishing connection". Ursache nicht belegt (Umgebung, Rechnerlast war zuvor sehr hoch). Mit Code selbst nicht in Verbindung gebracht, aber auch nicht ausgeschlossen, da kein Vorher-Lauf möglich war.
- F002, LOW, spec drift: Spec Z. 228 nennt `legacyDefaultWorkoutSets` (Z. 459), existiert nicht mehr. `WorkoutProgramsView.swift`/Spec.
- F003, LOW, spec wording: „leere Beschreibung" (Spec AC-30) vs. Code `== nil`; `""` wird nicht gefüllt (Altverhalten).

Kein Befund, der die Umsetzung als falsch beweist.

(Zwischenstand nach Runde 2: AMBIGUOUS, da kein gültiger Testlauf. Überholt durch Runde 3.)

## Runde 3: Beweise zu F001 (Läufe des Orchestrators bei niedriger Last, selbst gelesen)

Dateien im Scratchpad, gefiltert gelesen:

| Punkt | Beweiszeile |
|---|---|
| AC-27 | `unit.txt`: `Test case 'ExerciseCatalogTests.test_defaultPrograms_referenceExistingCatalogIds()' passed … (0.289 seconds)` |
| AC-30 | `unit.txt`: `Test case 'WorkoutPhaseMigrationTests.test_existingUserStore_unchangedAfterPresetMigration()' passed … (0.129 seconds)`; `** TEST SUCCEEDED **` (2 Testfälle liefen, N ≥ 1) |
| AC-28 | `ui.txt`: `Test Case '-[LeanHealthTimerUITests.WorkoutHintUITests test_infoButton_forPresetPlanke_showsContent]' passed (78.585 seconds).` `** TEST SUCCEEDED **`, `ALLE TESTS BESTANDEN` (reiner Regressionsschutz, war schon vorher grün) |
| AC-31 Watch | `watch.txt`: `** BUILD SUCCEEDED **` |
| AC-31 Widget | `widget.txt`: `** BUILD SUCCEEDED **` |

Bewertung F001: erledigt. Die Hänger in meinen vier Läufen waren Umfeldfehler (Host-App-Start), keine Eigenschaft des Codes; dieselben Tests laufen jetzt grün. Dateistempel 07:43-07:47, also nach meinen Läufen.
Bewertung F002: LOW, veraltete Spec-Zeile (Symbol existiert in HEAD nicht mehr), berührt die Umsetzung nicht; kein Mangel.
Bewertung F003: LOW, bewusst übernommenes Altverhalten (nur `nil` wird gefüllt, vom Skript als gleich zum alten `migrateSets` belegt); kein Mangel, nur Spec-Wortlaut „leer" ggf. nachschärfen.

Verbleibende Findings: nur F002 und F003 (beide LOW, nicht blockierend).

## Runde 4: Sammelzweig-Basis

Das Gate misst gegen merge-base(origin/main, HEAD) = 2c9fe78; `required-files` nennt zusätzlich vier früher committete Dateien. #84 ist inzwischen als 6e40369 committet.

(1) Berührung durch #84:
- Diff HEAD~1 → HEAD über die vier Dateien: leer. #84 ändert keine davon.
- Verlauf 2c9fe78..HEAD über die vier Dateien: nur Commits aus #48/#80-#94/#83 (45b4262, be98783, abfd058, 007b4fc, cf18c18, c9e09c9, 560b215, 15641ff, c4e6cf3, 7f2ea36), kein #84-Commit.
- Hashes gegen frühere Protokolle: ExerciseInfo.swift 7dc57473… == feature-48 und feature-80 (Übereinstimmung); ExerciseDatabase.swift eedf3f28… == feature-94 (Übereinstimmung, jüngster Stand); ExerciseDetailSheet.swift 090fe61b… == feature-83 (Übereinstimmung). WalkVUpsUITests.swift edec22a1…: in keinem früheren Protokoll gehasht (Abweichung, nicht vergleichbar; Walk-Test-Artefakt aus #80, letzter Commit abfd058, unverändert, von #84 nicht benutzt).

(2) Verlässt sich #84 auf Fehlendes?
- Alle 12 Kennungen sind in ExerciseDatabase.swift vorhanden: burpees :49, mountain-climbers :57, planke :107, russian-twists :155; die übrigen acht per Treffer-Zählung zweifach (Eintrag plus Alias). Zusätzlich beweist der grüne Test `test_defaultPrograms_referenceExistingCatalogIds` (Runde 3), dass `ExerciseDatabase.info(forId:)` für alle 24 Schritte einen Eintrag liefert.
- Namens-Rückfall: `ExerciseDetailSheet.swift:15` `let id = exerciseId ?? ExerciseDatabase.exerciseId(forName: exerciseName)`, danach `info(forId: id)`; der UI-Test AC-28 war grün (Runde 3). Der Rückfall greift auch ohne Kennung.

Befund Runde 4: keine Abweichung, die #84 betrifft; ein Hinweis (kein früherer Hash für WalkVUpsUITests.swift), nicht blockierend.

VERDICT: VERIFIED — alle Checklistenpunkte AC-27, AC-28, AC-30, AC-31 und Scope sind durch gültige Läufe bzw. Codebeweis belegt, kein widerlegender Befund.

## Geprüfte Dateien

- sha256:fd6f17c497b3ed947a9e327b6d6f7f967c52e343810d334781f53a9fb60e1ef5  LeanHealthTimerTests/ExerciseCatalogTests.swift
- sha256:62336404311ae06f4eae8dbab69e2945bbf59e86fed322c353d0888c9891afa6  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- sha256:b909240d11ac604dd41c4dc613a8aa559ada608363f711b890a23af37f6e7c6e  Meditationstimer iOS/Tabs/WorkoutTab.swift

## Prüfbasis

- base: 2c9fe78d3763a4db250b12883b43eacdcd76f3e2
- blob:bead8d280331b6e9fe2140be98f722d78755eab3  LeanHealthTimerTests/ExerciseCatalogTests.swift
- blob:64e7b5d12d4111faab9fa7409639eabdd635833b  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- blob:81d4ae78062fd7bba75e54152698f52759935075  Meditationstimer iOS/Tabs/WorkoutTab.swift

## Geprüfte Dateien

- sha256:edec22a1f7284112678b7ab582d534a25270c30f6d555e02cc40c422319b0e3a  DOCS/artifacts/feature-80-zusatzuebungen-1-12/validate/WalkVUpsUITests.swift
- sha256:fd6f17c497b3ed947a9e327b6d6f7f967c52e343810d334781f53a9fb60e1ef5  LeanHealthTimerTests/ExerciseCatalogTests.swift
- sha256:7dc57473c77fa8ceec4ed189d5c366ee0d92a3e52d154a72e720deeec7175fbd  Meditationstimer iOS/Models/ExerciseInfo.swift
- sha256:eedf3f289deb24f89068df8275c9c0a2f01f1b2c27f3b352df9140999bc3e841  Meditationstimer iOS/Services/ExerciseDatabase.swift
- sha256:62336404311ae06f4eae8dbab69e2945bbf59e86fed322c353d0888c9891afa6  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- sha256:b909240d11ac604dd41c4dc613a8aa559ada608363f711b890a23af37f6e7c6e  Meditationstimer iOS/Tabs/WorkoutTab.swift
- sha256:090fe61b2ea630d1c2fb9ad68324aca27655174c601bad9e9dea495f4ad16a5a  Meditationstimer iOS/Views/ExerciseDetailSheet.swift

## Prüfbasis

- base: 2c9fe78d3763a4db250b12883b43eacdcd76f3e2
- blob:2285023898ae703dad2aa15de0049856e76ad7bc  DOCS/artifacts/feature-80-zusatzuebungen-1-12/validate/WalkVUpsUITests.swift
- blob:bead8d280331b6e9fe2140be98f722d78755eab3  LeanHealthTimerTests/ExerciseCatalogTests.swift
- blob:207480164b29b550374f7d6811aa1fb502c39d13  Meditationstimer iOS/Models/ExerciseInfo.swift
- blob:8486c90a57858951ae98be27f63bf74c188d9b3e  Meditationstimer iOS/Services/ExerciseDatabase.swift
- blob:64e7b5d12d4111faab9fa7409639eabdd635833b  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- blob:81d4ae78062fd7bba75e54152698f52759935075  Meditationstimer iOS/Tabs/WorkoutTab.swift
- blob:c421dbf9975814ce3d374b27f7a69442caced777  Meditationstimer iOS/Views/ExerciseDetailSheet.swift
