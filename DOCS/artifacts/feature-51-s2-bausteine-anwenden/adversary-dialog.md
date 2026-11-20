# Adversary-Protokoll #51 Runde 2a-1 (feature-51-s2-bausteine-anwenden)

## Runde 1: Checkliste und Code-Pfade

Eigener Lauf: Unit-Suite `LeanHealthTimerTests`, Protokoll unter
`/private/tmp/claude-501/-Users-hem-Developer-Meditationstimer-Meditationstimer--claude-worktrees-starry-nibbling-patterson/3d61ac91-0f58-4dee-949d-696282dc5e33/scratchpad/adversary_test_output.txt`
(das vorgegebene Ziel `/tmp/adversary_test_output.txt` blockiert der Hook secret_egress_guard). Ergebnis: `Executed 293 tests, with 0 failures`, `** TEST SUCCEEDED **`; 19 Tests in `ClaudeApplyTests` (293 = 274 + 19).
Eigene Builds: `Meditationstimer Watch App` (generic watchOS Simulator) BUILD SUCCEEDED, `MeditationstimerWidgetExtension` BUILD SUCCEEDED (ClaudeApply.swift wird dort mitkompiliert, 8 Treffer im Log).

- [x] AC-1a: ClaudeApplyTests.swift:90-146 prüft Name, emoji, repetitions, je Phase exerciseId/Dauern/hint/Katalogname, claude (itemId, revision, why, deliveredAt = createdAt), modifiedAt nil, Gedächtnis; Code ClaudeApply.swift applyProgram und applyBreath.
  Code reference: Meditationstimer iOS/Models/ClaudeApply.swift:92
- [x] AC-3: Test :151-160 (anderer lastSnapshotAt, späteres now, `second == first`); Code ClaudeApply.swift:42-44 gibt `state` unverändert zurück, Log wird nicht angefasst.
  Code reference: Meditationstimer iOS/Models/ClaudeApply.swift:42
- [x] AC-4: Test :165-188, 51 Lieferungen, Log 50, erste weg, Neubewertung der ersten (noEffect); Code `if final.log.count > 50 { removeFirst(count - 50) }`. Grenze 50/51 korrekt.
  Code reference: Meditationstimer iOS/Models/ClaudeApply.swift:60
- [x] AC-5: Tests :193-236; Code übernimmt Bausteine nur ohne Ablehnung (`if case .rejected = result {} else {...}`), hängt den Log-Eintrag auch bei rejected an. Ablehnung an zweiter Position nach angewendeter erster getestet (:212-225, anwendbare Atemübung nicht angelegt).
  Code reference: Meditationstimer iOS/Models/ClaudeApply.swift:58
- [x] AC-6a: Test :241-269 (UUID gleich, neuer Inhalt, revision/why/Paket/deliveredAt neu, modifiedAt nil, Anzahl 1); Code behält `id`, erzeugt neuen Baustein mit modifiedAt nil.
  Code reference: Meditationstimer iOS/Models/ClaudeApply.swift:89
- [x] AC-7: Test :272-296 (rev 2 und 1, mit modifiedAt und lastSnapshotAt nil: noEffect, Gedächtnis, zweite Anwendung gleich); Code: Revisionsprüfung steht vor `isBlockedByIphone`.
  Code reference: Meditationstimer iOS/Models/ClaudeApply.swift:89
- [x] AC-8a: Tests :301-337, Fälle (1000/500), (1000/nil), (1000/2000), (1000/1000), (nil/nil), (nil/10), beide Arten; Code `isBlockedByIphone` strikt `>`, nil-Abschrift blockiert nur bei gesetztem modifiedAt.
  Code reference: Meditationstimer iOS/Models/ClaudeApply.swift:70
- [x] AC-13a: Tests :342-367; Code `resolveStepName` nur Präfix `builtin.`, unbekanntes builtin liefert nil über `info(forId:)`; own/claude lehnen mit EXERCISE_UNKNOWN ab.
  Code reference: Meditationstimer iOS/Models/ClaudeApply.swift:80
- [x] AC-14: Tests :372-409, neue UUID, modifiedAt nil, revision 2 und 1 mit neuer deliveryId, gleiche deliveryId liefert gemerkt; Code: Baustein nicht im Zustand, index nil, Anlegen.
  Code reference: LeanHealthTimerTests/ClaudeApplyTests.swift:372
- [x] AC-15: Test :414-460 (Alt-JSON ohne Felder, Round-Trip); `WorkoutSet`/`Preset` nutzen synthetisiertes Codable (optionale Felder), nur `WorkoutPhase` hat eigenes `init(from:)` und ist nicht geändert.
  Code reference: LeanHealthTimerTests/ClaudeApplyTests.swift:414
- [x] AC-20: Tests :487-510; Code `default` liefert KIND_NOT_SUPPORTED mit nichtleerem Grund, Abbruch der Schleife, Bausteine unverändert.
  Code reference: Meditationstimer iOS/Models/ClaudeApply.swift:52
- [x] AC-22: Test :465-482 beide Reihenfolgen; Code: `break` nach erster Ablehnung.
  Code reference: Meditationstimer iOS/Models/ClaudeApply.swift:54
- [x] AC-21: Bericht `ac21/ac21-bericht.md`; `vorher-*.json` gegen `nachher-*.voll.json` selbst verglichen: workoutProgramSets 4/4, atemPresets 6/6, Namen gleich, Gleichheit auch ohne Filterung; die vier diff-Dateien haben 0 Byte; kein `workoutProgramSetsBackup.*`-Schlüssel; neuer Stand ohne Deinstallation darüber installiert. Bundle-ID: project.pbxproj:960 `henemm.Meditationstimer-iOS` ist die iOS-App, `henemm.Meditationstimer.dev2` (pbxproj:858) gehört zu einem anderen Ziel. Der Nachweis trägt, die Spec-Angabe ist falsch (F001).
  Code reference: Meditationstimer.xcodeproj/project.pbxproj:960
- [x] AC-19: 293/293 grün (eigener Lauf), Watch + Widget bauen (eigener Lauf). Produktiv-Diff: `git diff --numstat` 6+1 (AtemView) und 6+1 (WorkoutProgramsView) = 14 Zeilen, plus 122 Zeilen neue Datei = 136, höchstens 250. Längste Funktion `apply` rund 28 Zeilen, `applyProgram` rund 25, alle höchstens 50.
  Code reference: Meditationstimer iOS/Models/ClaudeApply.swift:39
- [x] AC-18-Durchsicht (Regel 13): ClaudeApply.swift importiert nur `import Foundation` (Zeile 9); grep nach `UserDefaults|NotificationCenter|Date()` ohne Treffer. `git status`: geändert nur AtemView.swift, WorkoutProgramsView.swift, neu ClaudeApply.swift (plus `.claude/`-Workflow-Dateien); WorkoutTab.swift, MeditationTab.swift, ExerciseDatabase.swift, project.pbxproj unberührt.
  Code reference: Meditationstimer iOS/Models/ClaudeApply.swift:9
- [x] UI-Test: `ClaudeFelderUITests/testProgrammeUndAtemuebungenUeberstehenNeustart` grün (uitest-green-output.txt Zeilen 1-5). Der rote `WorkoutHintUITests/test_pickedExercise_persistsAfterRelaunch` scheitert an `workout.training.hint` in der Trainingsansicht (WorkoutHintUITests.swift:319, nach allen Persistenz-Assertions), Ticket #105 offen mit Titel "rot auf unverändertem Stand"; 2a-1 berührt keine Trainingsansicht. Unabhängigkeit plausibel.
  Code reference: LeanHealthTimerUITests/ClaudeFelderUITests.swift:173

## Runde 2: Edge Cases (Code-Analyse)

- Revision vs. CHANGED_ON_IPHONE: Revisionsvergleich zuerst, erst dann Sperre. Gleiche/niedrigere revision bei geändertem Baustein bleibt noEffect, getestet (:288-295).
- `modifiedAt == lastSnapshotAt`: blockiert nicht (strikt `>`), getestet (:321).
- Ablehnung an späterer Position nach erfolgreicher erster: `final = state`, Arbeitskopie verworfen, Log ergänzt. Getestet.
- Kürzung bei 50/51: `> 50` mit `removeFirst(count - 50)`, bei genau 50 nichts, bei 51 genau eins. Getestet.
- Idempotenz ändert auch das Log nicht: früher Rücksprung vor jeder Mutation, Test vergleicht ganze Zustände mit `==`.
- Ersetzen: UUID des Bausteins bleibt, Phasen erhalten neue UUIDs (Spec nur für den Baustein; unkritisch).
- Unbekannte `builtin.*`: EXERCISE_UNKNOWN, getestet. Leere Positionsliste: Schleife läuft nicht, Ergebnis noEffect, harmlos.
- Zwei Positionen gleicher itemId in einer Lieferung: zweite sieht die erste in der Arbeitskopie; gleiche revision noEffect, höhere ersetzt erneut; kein Absturz, nicht spezifiziert, kein Mangel.
- Alt-JSON mit fehlenden Schlüsseln: getestet. Equatable/Hashable: synthetisiert, neue Felder in 2a-1 immer nil, bestehende Vergleiche ändern sich nicht.
- Paketfelder und `deliveredAt = createdAt`: getestet (:260-266, :116).

## Ergänzung: Prüfung der Typdateien (AC-15, AC-18)

Geprüft: `WorkoutSet` und `AtemView.Preset` bekommen genau zwei optionale Felder (`claude`, `modifiedAt`), im `init` als letzte Parameter mit Default `nil`; bestehende Aufrufe (Aufrufform ohne diese Parameter) bleiben gültig. Beide Typen haben kein eigenes `init(from:)`/`encode`, also synthetisiertes Codable mit `decodeIfPresent` für Optionals (Alt-JSON lesbar, `nil` wird nicht geschrieben, passend zu AC-21). Das Verdict ändert sich dadurch nicht.

- [x] AC-15 (Typdatei WorkoutProgramsView): Felder und init-Form.
  Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:173
  Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:177
- [x] AC-15 (Typdatei AtemView): Felder und init-Form.
  Code reference: Meditationstimer iOS/Tabs/AtemView.swift:53
  Code reference: Meditationstimer iOS/Tabs/AtemView.swift:57

## Findings

```json
[
  {"id":"F001","severity":"LOW","category":"spec_violation",
   "description":"Spec AC-21 nennt die Bundle-ID henemm.Meditationstimer.dev2; die iOS-App ist henemm.Meditationstimer-iOS. Der Nachweis trägt trotzdem, die Spec-Zeile ist falsch.",
   "evidence":"Meditationstimer.xcodeproj/project.pbxproj:858 (dev2, anderes Ziel) gegen :960 (henemm.Meditationstimer-iOS); docs/artifacts/feature-51-s2-bausteine-anwenden/ac21/ac21-bericht.md",
   "remediation":"Spec bei Gelegenheit berichtigen."},
  {"id":"F002","severity":"LOW","category":"spec_violation",
   "description":"Spec (Abhängigkeiten) behauptet, Watch und Widget kompilierten die neue Datei mit. Im eigenen Watch-Build taucht ClaudeApply.swift (und ClaudeDelivery.swift) nicht auf, im Widget-Build schon. Beide Builds sind grün; kein Defekt, aber die Spec-Aussage zum Watch stimmt nicht.",
   "evidence":"eigener Build Meditationstimer Watch App: 0 Treffer für ClaudeApply.swift; Widget: 8 Treffer",
   "remediation":"Spec-Satz korrigieren."},
  {"id":"F003","severity":"LOW","category":"spec_violation",
   "description":"UI-Test legt je ein neues Programm und eine neue Atemübung an, statt wie in der Spec vorhandene umzubenennen. Begründet im Testkopf; der Beweis (gespeicherte Liste überlebt Neustart) bleibt gleich stark.",
   "evidence":"LeanHealthTimerUITests/ClaudeFelderUITests.swift:9-12, :111-143",
   "remediation":"keine"},
  {"id":"F004","severity":"LOW","category":"anti_pattern",
   "description":"Der geforderte Ausgabepfad /tmp/adversary_test_output.txt ist durch den Hook secret_egress_guard gesperrt; das Protokoll liegt im Scratch-Ordner.",
   "evidence":"Hook-Meldung beim Aufruf",
   "remediation":"Pfad im Auftrag ändern"}
]
```

Kein Finding der Schwere CRITICAL, HIGH oder MEDIUM.

Finding-Referenzen:
Code reference: Meditationstimer.xcodeproj/project.pbxproj:858 (F001)
Code reference: Meditationstimer.xcodeproj/project.pbxproj:960 (F002)
Code reference: LeanHealthTimerUITests/ClaudeFelderUITests.swift:111 (F003)
Code reference: Meditationstimer iOS/Models/ClaudeApply.swift:9 (F004, Pfadhinweis ohne Codebezug)

VERDICT: VERIFIED. Alle 2a-1-ACs (1a, 3, 4, 5, 6a, 7, 8a, 13a, 14, 15, 20, 21, 22) und AC-19 sind durch Tests mit echten Assertions und eigene Läufe (293/293 grün, Watch und Widget bauen) belegt; Produktiv-Diff 136 Zeilen, keine Funktion über 50 Zeilen, Datei nur Foundation, keine Seiteneffekte, nur die Runden-Dateien geändert. Offen sind nur Spec-Korrekturen geringer Schwere.

## Geprüfte Dateien

- sha256:d0207fa24b3e74dcbc3f0ff29ae14aa5353dd99986444274b0a7da0a870f5c84  LeanHealthTimerTests/ClaudeApplyTests.swift
- sha256:ef8e375562ef0143db7c09e65c61f00d4792ff3654da5b78c7b33d169a9ad15c  LeanHealthTimerUITests/ClaudeFelderUITests.swift
- sha256:630b8712d9c70d41b56309cde4196f83dc3da5217dbdcb86219f37ac1be94726  Meditationstimer iOS/Models/ClaudeApply.swift
- sha256:11c62600d3cfb3ccc93ce7d468be10c1f7d601da9b72e9a83ba57ce3324eccd5  Meditationstimer.xcodeproj/project.pbxproj

## Prüfbasis

- base: dbdef2e590da61c8c1a34de18f0ef25e31aea723
- blob:e8140bd04d915d9cc28f224584971c442900d3b1  LeanHealthTimerTests/ClaudeApplyTests.swift
- blob:7af4d6a82247af70ce7810c0ca35889eabca4414  LeanHealthTimerUITests/ClaudeFelderUITests.swift
- blob:2238dcf7f18afa41acbdd5577edc2d13a38887c1  Meditationstimer iOS/Models/ClaudeApply.swift
- blob:7ad2216bed9f766ff9f7e832f2c776df00c840fd  Meditationstimer.xcodeproj/project.pbxproj

## Geprüfte Dateien

- sha256:d0207fa24b3e74dcbc3f0ff29ae14aa5353dd99986444274b0a7da0a870f5c84  LeanHealthTimerTests/ClaudeApplyTests.swift
- sha256:ef8e375562ef0143db7c09e65c61f00d4792ff3654da5b78c7b33d169a9ad15c  LeanHealthTimerUITests/ClaudeFelderUITests.swift
- sha256:630b8712d9c70d41b56309cde4196f83dc3da5217dbdcb86219f37ac1be94726  Meditationstimer iOS/Models/ClaudeApply.swift
- sha256:a848f804af0cd127c9830909e72e5450531e312d4523e3150965ef30bc86b8b6  Meditationstimer iOS/Tabs/AtemView.swift
- sha256:7817e1f24c54b7cf1b3694a9a33a49b5b3ac567fefb2d5ddaa42a1f66103f2f6  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- sha256:11c62600d3cfb3ccc93ce7d468be10c1f7d601da9b72e9a83ba57ce3324eccd5  Meditationstimer.xcodeproj/project.pbxproj

## Prüfbasis

- base: dbdef2e590da61c8c1a34de18f0ef25e31aea723
- blob:e8140bd04d915d9cc28f224584971c442900d3b1  LeanHealthTimerTests/ClaudeApplyTests.swift
- blob:7af4d6a82247af70ce7810c0ca35889eabca4414  LeanHealthTimerUITests/ClaudeFelderUITests.swift
- blob:2238dcf7f18afa41acbdd5577edc2d13a38887c1  Meditationstimer iOS/Models/ClaudeApply.swift
- blob:707399258a3eecc08d1e2f4d42633cd7e8970970  Meditationstimer iOS/Tabs/AtemView.swift
- blob:f9b04e87e3d5e08df69f3f8209f5a3308d0314f9  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- blob:7ad2216bed9f766ff9f7e832f2c776df00c840fd  Meditationstimer.xcodeproj/project.pbxproj
