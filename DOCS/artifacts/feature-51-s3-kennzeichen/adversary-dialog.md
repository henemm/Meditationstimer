# Adversary-Protokoll feature-51-s3-kennzeichen (#51 Schnitt 3)

Rohausgaben im selben Ordner: `adversary-unit.txt`, `adversary-unit-rerun.txt`, `adversary-ui-*.txt`, `adversary-ui-builtin-clean.txt`, `adversary-f001-rerun.txt`, `adversary-r2-builtin.txt`, `build-watch.txt`, `build-widget.txt`.

## Runde 1

Eigene Läufe: Unit-Suite TEST SUCCEEDED, 344 `Test case ... passed`, 0 failed. UI je Klasse/Methode: 6 von 7 neuen Tests passed; `testBuiltinProgramHasNoClaudeBadge` rot (3 von 3 Versuchen) auf verschmutztem Simulator, grün nach Deinstallation der App. Bestandstest `WorkoutHintUITests/test_infoButton_forPresetPlanke_showsContent` passed (Katalogübung, kein Regress durch #90).

Checkliste:

- [x] AC-1 Lesefunktion löst gelieferte Übung auf — Unit `testStoredExerciseResolvesClaudeIdFromState` passed
- [x] AC-2 Unbekannt/Katalog liefert nil — Unit `testStoredExerciseReturnsNilForUnknownOrBuiltinId` passed, Präfix-Guard
- [x] AC-3 Abbildung mit Hinweisen und Kategorie-Rückfall `.fullBody` — Unit `testExerciseInfoMapsCategoryEffectInstructions` passed
- [x] AC-4 Kapseltext ohne Bearbeitung — Unit `testBadgeTextPlainWhenNotModified` passed
- [x] AC-5 Kapseltext mit Bearbeitung — Unit `testBadgeTextShowsAngepasstWhenModified` passed
- [x] AC-6 Programm-Zeile trägt Kapsel, eingebaute nicht — UI `testWorkoutRowShowsClaudeBadgeAndInfoShowsPackageAndWhy` passed; `testBuiltinProgramHasNoClaudeBadge` in Runde 1 rot wegen Testschuld F001, in Runde 2 grün
- [x] AC-7 Info des Programms zeigt Herkunft, kein "Empfohlene Anwendung" — gleicher UI-Test passed
- [x] AC-8 Atemübung mit Kapsel und Info — UI `testBreathRowShowsClaudeBadgeAndInfo` passed
- [x] AC-9 Info-Knopf auch ohne Beschreibung — UI `testBreathMinimalDeliveryStillHasInfoButton` passed
- [x] AC-10 Gelieferte Übung zeigt Texte beim ersten Tippen (#90) — UI `testClaudeExerciseInfoShowsTextsOnFirstTap` passed
- [x] AC-11 "angepasst" nach Bearbeitung — UI `testEditedClaudeProgramShowsAngepasst` passed
- [x] AC-12 Katalog und eigene Bausteine unverändert — Unit AC-2-Test passed, `test_infoButton_forPresetPlanke_showsContent` passed
- [x] AC-13 Englische Texte — UI `testClaudeBadgeIsLocalizedInEnglish` passed; 7 Schlüssel DE/EN, manual/translated, `%@` stimmt
- [x] AC-14 Reinheit, Build, Budget — Runde 2 (unten) erledigt

Befunde Runde 1:

```json
[
 {"id":"F001","severity":"MEDIUM","category":"anti_pattern","description":"testBuiltinProgramHasNoClaudeBadge zählte alle Kapseln und erwartete genau 1; Reste früherer Läufe ergaben 3. Testschuld, kein Produktfehler.","evidence":"ClaudeKennzeichenUITests.swift:238-240 (alt); adversary-ui-testBuiltinProgramHasNoClaudeBadge.txt","remediation":"Zählung durch Einzelprüfung der eingebauten Programme ersetzen"},
 {"id":"F002","severity":"LOW","category":"spec_violation","description":"loadState schreibt bei nicht lesbarem claudeState eine Sicherung in UserDefaults; Spec sagt rein lesend. Nur im Korruptionsfall, Bestandsverhalten.","evidence":"Meditationstimer iOS/Models/ClaudeStore.swift:78-89","remediation":"Akzeptieren, in Spec vermerken"},
 {"id":"F003","severity":"LOW","category":"edge_case","description":"Bei UTC+14 zeigt 10:15Z den Folgetag (14.11.); Spec-Aussage 'in allen realen Zeitzonen' stimmt nicht.","evidence":"Meditationstimer iOS/Views/ExerciseDetailSheet.swift:236","remediation":"Spec-Formulierung abschwächen"},
 {"id":"F004","severity":"LOW","category":"spec_violation","description":"Kein Screenshot einer Zeile mit Kapsel und eines Info-Blatts erzeugt; Simulator ohne Fenster, kein Scroll-/Tipp-Werkzeug, erfolgreiche UI-Tests liefern keine Anhänge. Layout mit Kapsel nicht visuell geprüft.","evidence":"docs/artifacts/feature-51-s3-kennzeichen/adversary-screenshot.png (nur Startbild)","remediation":"Screenshots Dunkel/Hell im Nutzer-Durchlauf in /60-validate"}
]
```

## Runde 2

Eingang vom Orchestrator (nur Eingang, kein Urteil): F001 sei durch Umbau des Tests behoben; Watch/Widget-Build und frische Unit-Suite lägen vor.

Eigene Prüfung:

- F001: Der Test prüft jetzt je eingebautem Programm (Tabata Classic, Core Circuit, Full Body Burn, Quick Burn) `workout.programRow.<Name>.claudeBadge` auf Nicht-Existenz, nachdem die Zeile per `.edit` ins Bild gescrollt und hittable ist (damit keine Falsch-Grün durch nicht gerenderte Zeile). Die vier Namen sind alle `name:`-Einträge der eingebauten Sets in `WorkoutTab.swift` (Z. 802, 818, 832, 846; weitere gibt es nicht). Der Test hängt nicht mehr vom Simulator-Vorzustand ab. Eigener Nachlauf ohne Deinstallation: `Test Case '-[LeanHealthTimerUITests.ClaudeKennzeichenUITests testBuiltinProgramHasNoClaudeBadge]' passed (98.451 seconds)` (`adversary-r2-builtin.txt`). Der Test deckt AC-6 (eingebaute ohne Kapsel) und AC-12 (UI-Teil) korrekt und robust ab. F001 behoben.
- AC-14: `build-watch.txt` und `build-widget.txt` enthalten je `** BUILD SUCCEEDED **` (gelesen, nicht selbst gebaut). Frische Unit-Suite `adversary-unit-rerun.txt`: TEST SUCCEEDED, 344 passed, 0 failed. ClaudeStore.swift importiert nur Foundation, ClaudeApply.swift und ExerciseDatabase.swift unverändert, App-Diff 154 Zeilen, neue Funktionen unter 50 Zeilen.
- F004: bleibt offen, LOW. Keine Spec-AC verlangt Screenshots; sie stehen im Test Plan (Durchlauf als Nutzer). Beobachtbares Verhalten ist durch die UI-Tests bewiesen (Existenz, Hittable, Texte), nur das Layout (minHeight 140 mit Kapsel, großer Schrift) ist ungeprüft. Ich kann hier keinen Screenshot erzeugen; das gehört in `/60-validate`.

Checkliste Runde 2:

- [x] AC-6 Eingebaute Programme ohne Kapsel (alle vier Namen einzeln) — `adversary-r2-builtin.txt` passed
- [x] AC-12 Katalog/eigene Bausteine unverändert, UI-Teil robust — gleicher Lauf passed
- [x] AC-14 Watch und Widget bauen — `build-watch.txt`, `build-widget.txt` je BUILD SUCCEEDED
Offen, bewusst keine Checklistenzeile (kein AC): F004, Screenshot-Nachweis des Layouts aus dem Test Plan, für /60-validate.

Code reference: Meditationstimer iOS/Models/ClaudeStore.swift:85
Code reference: Meditationstimer iOS/Views/ExerciseDetailSheet.swift:236
Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:1444
Code reference: Meditationstimer iOS/Tabs/AtemView.swift:216
Code reference: Meditationstimer iOS/Tabs/WorkoutTab.swift:802
Code reference: LeanHealthTimerUITests/ClaudeKennzeichenUITests.swift:230

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

VERDICT: AMBIGUOUS

## Geprüfte Dateien

- sha256:22040f6702f1900298fd4cfaf2bd0af9871c7632c25e5f18771a5291eca2ba8c  LeanHealthTimerUITests/ClaudeKennzeichenUITests.swift
- sha256:1696765f51ee9cdc2d56e0a8e17a4dd5c7ae0ff8f0fe5f834d6e17b145afc519  Meditationstimer iOS/Models/ClaudeStore.swift
- sha256:f3c231bc24a4780895199402a238881f23a3ae0ab3f73b16516e8b50cf621f79  Meditationstimer iOS/Tabs/AtemView.swift
- sha256:0d33f20bb17cf309c12ce5bb125a66f34eb839a77978a2ac518b4f1dca5275b8  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- sha256:49814abf612ed3a0f0ab6f33214967f073bddc58d56e4e418867461e97ec41f0  Meditationstimer iOS/Tabs/WorkoutTab.swift
- sha256:543d6fdc89cf375156ab0d8bda1c4bfa8b93cbb449147231531897527f0b0986  Meditationstimer iOS/Views/ExerciseDetailSheet.swift

## Prüfbasis

- base: 810e47e201f0c25667cfce153081b900156ecf71
- blob:6a99394d29a472de877a710524e42431e10aa012  LeanHealthTimerUITests/ClaudeKennzeichenUITests.swift
- blob:d8b3112601953398151a6986c4bd51a872f0712a  Meditationstimer iOS/Models/ClaudeStore.swift
- blob:8e71ae26ec1a8153ce7ed86d027b9fff5538f324  Meditationstimer iOS/Tabs/AtemView.swift
- blob:ba2942ebf72435a8e8a4db717e73bb96f51e9090  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- blob:f0d26a282f29f4aca3c9db82d9cc776113810b27  Meditationstimer iOS/Tabs/WorkoutTab.swift
- blob:a79a95efe4b9a5283aacaf1e8468359011561cbe  Meditationstimer iOS/Views/ExerciseDetailSheet.swift
