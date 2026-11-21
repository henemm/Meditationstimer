---
entity_id: feature-51-s2b2-editor
type: feature
created: 2026-11-21
updated: 2026-11-21
status: draft
workflow: feature-51-s2b2-editor
issue: 51
epic: 44
parent: feature-51-s2-bausteine-anwenden
---

# Runde 2b-2: Editoren setzen `modifiedAt`, Schritt-Editor behält `claude.*` (#51, Schnitt 2b)

## Approval

- [ ] Approved

Freigabe dieser Rundenspec durch den PO.

## Purpose

Runde 2b-2 der freigegebenen Elternspec `DOCS/specs/features/feature-51-s2-bausteine-anwenden.md`: Bearbeitet Henning einen von Claude gelieferten Baustein (Programm oder Atemübung) im Editor, wird das als seine Änderung festgehalten (`modifiedAt`), damit Regel 8 („das iPhone gewinnt“, `CHANGED_ON_IPHONE`) greift. Dazu behält der Schritt-Editor die `claude.*`-Übungskennung, solange die Übung nicht gewechselt wird, und ein Speichern aus einem veralteten Editor überschreibt weder eine neuere Lieferung unbemerkt noch holt es eine Rücknahme zurück.

Die Elternspec und Runde 2b-1 (`DOCS/specs/features/feature-51-s2b-speichern.md`) gelten weiter. Bis #57 ruft im Betrieb nichts `apply` auf; sichtbar ist für Henning nur, dass seine Änderung an einem gelieferten Baustein später nicht von einer Lieferung überschrieben wird.

## Source

- Kontext und Analyse: `DOCS/context/feature-51-s2b2-editor.md`
- Elternspec: Regel 8 (`modifiedAt` gegen `lastSnapshotAt`), AC-12 (`own.*`-Verweis), Abschnitt „Nicht in Scope (gehört zu Schnitt 2b)“
- Vorgängerrunde: `DOCS/specs/features/feature-51-s2b-speichern.md` (Nicht in Scope: Runde 2b-2; Vorfestlegungen in `DOCS/context/feature-51-s2b-speichern.md:109-116`)

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine neue; gilt die ADR der Elternspec (reine Funktion `apply`, Persistenz in `ClaudeStore.swift`).

**Rationale:** Die Regel „unverändert schreibt nicht, geändert setzt `modifiedAt`“ steckt in einer reinen Hilfsfunktion neben dem Lader in `ClaudeStore.swift`, damit beide Tabs dieselbe Logik nutzen und sie ohne Oberfläche testbar ist. `ClaudeApply.swift` bleibt unberührt, weil es `modifiedAt` nur liest.

## Scope

App-Code (4 Dateien, geschätzt +40/−10 Zeilen, Grenze 250 nur für App-Code):

- `Meditationstimer iOS/Models/ClaudeStore.swift` (MODIFY: reine Hilfsfunktion `savingEdit`)
- `Meditationstimer iOS/Tabs/WorkoutTab.swift` (MODIFY: `onSave` des Programm-Editors, Zeilen 146-153)
- `Meditationstimer iOS/Tabs/MeditationTab.swift` (MODIFY: `onSave` des Atem-Editors, Zeilen 174-180)
- `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` (MODIFY: neue `mutating func` an `WorkoutPhase`, Aufruf im Speichern-Knopf von `PhaseEditorView`, Zeilen 1770-1772)

Tests (zählen nicht zum Budget): `LeanHealthTimerTests/ClaudeEditorSpeichernTests.swift` (neu), `LeanHealthTimerUITests/ClaudeSpeichernUITests.swift` (erweitern).

Unverändert: `ClaudeApply.swift` (Quelltext-Wächter `testApplyDateiIstFoundationOnlyUndOhneSeiteneffekte`), `AtemView.swift`, `ExerciseDatabase.swift`, `project.pbxproj`.

## Dependencies

| Abhängigkeit | Art | Hinweis |
|---|---|---|
| `isBlockedByIphone(modifiedAt:lastSnapshotAt:)` (`ClaudeApply.swift:86`) | Upstream, nur lesen | liest `modifiedAt`; solange #57 fehlt (`lastSnapshotAt == nil`), sperrt ein gesetztes `modifiedAt` jede weitere Lieferung und Rücknahme dieses Bausteins (`CHANGED_ON_IPHONE`), bis Claude neu liest. Das ist Regel 8, gewollt |
| `WorkoutSet.modifiedAt`, `AtemView.Preset.modifiedAt` | Bestand (2b-1/2a) | Felder existieren (`WorkoutProgramsView.swift:174`, `AtemView.swift:54`) |
| `ClaudeStore.loadSets/loadPresets`, `claudeStoreDidChange` | Bestand (2b-1) | Tabs laden nach Lieferung neu |
| `ExerciseDatabase.ownExerciseId(forName:)` | Bestand | erzeugt `own.<slug>` |
| #57 (Abschrift liest `modifiedAt`/`exerciseId`), Schnitt 3 (Info-Blatt) | Downstream | |

## Befund (Ist-Stand, am Code gelesen 2026-11-21)

1. `modifiedAt` wird in der Produktion nirgends gesetzt; `onSave` ersetzt per `id` oder hängt an, `modifiedAt` bleibt unberührt. „iPhone gewinnt“ greift heute nie.
2. `PhaseEditorView.init` wertet `claude.*` als eigene Übung (`useCustomExercise = true`); der Speichern-Knopf ruft dann `draft.apply(.own(name:))` und macht daraus `own.<slug>`, auch ohne Namensänderung.
3. Offener Editor: `draft` bleibt veraltet. Speichern ersetzt per `id` eine inzwischen höhere Revision durch die alte Kopie, auch ohne jede Änderung und ohne `modifiedAt` (stille Überschreibung); wurde der Baustein zurückgenommen, hängt `onSave` ihn wieder an.

## Festlegungen (Tech-Lead)

Verbindlich ist das beschriebene Verhalten; ein neuer Name darf bei der Umsetzung nur mit Begründung im RED-Bericht abweichen.

1. **Hilfsfunktion (neu, rein):** in `ClaudeStore.swift`
   `static func savingEdit<T: Identifiable & Equatable>(_ edited: T, original: T, in list: [T], modifiedAt: WritableKeyPath<T, Date?>, now: Date) -> [T]?`
   (Bezeichner und Argumentbeschriftung ändern sich nicht, `ID`-Typ ist der des Elements.) Keine Uhr, kein `UserDefaults`, keine Benachrichtigung darin; `now` wird vom Aufrufer übergeben.
   - `edited == original` → `nil`: der Aufrufer schreibt nichts, `modifiedAt` bleibt unberührt.
   - sonst: Kopie von `edited` mit `modifiedAt = now`; steht ein Element mit gleicher `id` in `list`, wird es an seiner Stelle ersetzt, sonst (neuer oder inzwischen zurückgenommener Baustein) hinten angehängt. Rückgabe ist die neue Liste.
2. **„Hennings Speichern gewinnt“:** Die Liste im Tab (`sets`/`presets`) wird nicht gegen den Editorstand abgeglichen; nur der Vergleich `edited == original` entscheidet. `original` ist die Kopie, mit der der Editor geöffnet wurde (Closure-Parameter `set` bzw. `preset` von `.sheet(item:)`). Der Editor verändert `modifiedAt` nie, daher ist `==` ein exakter „unverändert“-Test.
3. **Aufrufer:** `onSave` in `WorkoutTab` und `MeditationTab` ruft `savingEdit(edited, original: set, in: sets, modifiedAt: \.modifiedAt, now: Date())` (bzw. mit `preset`/`presets`); bei `nil` kein Schreiben und kein `saveSets()`/`savePresets()`, sonst Liste ersetzen und speichern. `onDelete` bleibt unverändert.
4. **Schritt-Editor:** neue `mutating func applyKeepingClaudeId(ownName: String)` an `WorkoutPhase` (`WorkoutProgramsView.swift`, neben `apply(_:)`, Zeile 288): trägt die Phase eine `claude.*`-Kennung und ist `ownName == name`, passiert nichts (Kennung bleibt); in allen anderen Fällen wie `apply(.own(name: ownName))`. Der Speichern-Knopf von `PhaseEditorView` ruft diese Funktion statt `apply(.own(name:))`. Namenswechsel oder Wechsel auf eine Katalogübung (Picker) setzen weiter `own.*` bzw. `builtin.*`. `init` bleibt unverändert (`claude.*` zeigt weiter „Eigene Übung…“ mit vorbelegtem Namen).
5. **Schritt-Änderung ist Programm-Änderung:** Der Schritt-Editor gibt die Phase an den Programm-Editor zurück; dessen `draft` unterscheidet sich dadurch vom Original, und `onSave` setzt `modifiedAt` des Programms (Festlegung 3). Keine eigene Behandlung im Schritt-Editor.
6. **`migratingPresets`:** Ein Programm mit Claude-Herkunft und `claude.*`-Phase durchläuft `WorkoutSet.migratingPresets` ohne `modifiedAt` zu setzen und ohne Kennungsverlust (Absicherung, Test).

## Alternativen (verworfen)

- **B – Offenen Editor bei eintreffender Lieferung schließen oder warnen:** zusätzliche Oberfläche und mehr Code; widerspricht „einfach statt kompliziert“. Verworfen. Das Anwenden läuft ohnehin nur über #57 und den DEBUG-Einstieg.
- **C – Speichern eines zurückgenommenen Bausteins legt einen eigenen Baustein ohne Claude-Herkunft an (`claude = nil`, neue `id`):** saubere Trennung, aber mehr Code und für Henning nichts sichtbar; ändert die Herkunft. Nicht empfohlen. Gewählt: Wiederanlegen als Hennings Fassung mit `modifiedAt`.
- **D – `modifiedAt` nur bei Claude-Bausteinen setzen:** spart nichts, das Feld heißt „letzte Änderung durch den Nutzer“. Verworfen.

## Nicht in Scope

- Warnung oder Schließen offener Editoren bei eintreffender Lieferung (Alternative B)
- Abschrift an Claude und `lastSnapshotAt` (#57)
- Info-Blatt und Kennzeichen „von Claude“ (Schnitt 3), `ExerciseDatabase.info(forId:)` für `claude.*`
- Jede Änderung an `ClaudeApply.swift`, `AtemView.swift`, `ExerciseDatabase.swift`
- Löschen im Editor (`onDelete`) setzt kein `modifiedAt` (Baustein ist weg)

## Expected Behavior

- Input: Henning speichert im Programm-Editor oder Atem-Editor (Bestätigen), oder im Schritt-Editor.
- Output: Unverändert gespeichert → es wird nichts geschrieben. Geändert gespeichert → der Baustein steht mit `modifiedAt = jetzt` in der Liste (ersetzt oder angehängt). Schritt mit `claude.*`-Kennung und unverändertem Namen behält die Kennung.
- Side effects: Eine spätere Lieferung oder Rücknahme dieses Bausteins wird mit `CHANGED_ON_IPHONE` abgelehnt, solange `modifiedAt > lastSnapshotAt` (Regel 8; bis #57 immer). Keine neue Oberfläche, keine Benachrichtigung.

## Acceptance Criteria

Alle als Given/When/Then; „Unit“ = `LeanHealthTimerTests`, „UI“ = `LeanHealthTimerUITests/ClaudeSpeichernUITests.swift`.

- **AC-1 (Unit): Unverändert speichert nichts.** Given ein Programm `original` und `edited == original` (auch bei vorhandenem `claude`-Feld und `modifiedAt == nil`), When `savingEdit` mit beliebiger Liste, Then ist das Ergebnis `nil`. Test: `testSavingEditUnveraendertLiefertNil` (je Programm und Atemübung).
- **AC-2 (Unit): Geändert ersetzt per `id` und setzt `modifiedAt`.** Given eine Liste mit dem Baustein (Revision aus Lieferung, `modifiedAt == nil`) und `edited` mit geändertem Namen, When `savingEdit(..., now: T)`, Then enthält die Rückgabe an gleicher Stelle `edited` mit `modifiedAt == T`, alle anderen Elemente sind unverändert und in gleicher Reihenfolge, die `claude`-Herkunft bleibt erhalten. Test: `testSavingEditGeaendertErsetztUndSetztModifiedAt` (je Programm und Atemübung).
- **AC-3 (Unit): Neuer Baustein wird angehängt.** Given `edited` mit `id`, die nicht in der Liste steht, die vom `original` abweicht (neu angelegt), When `savingEdit`, Then steht `edited` mit `modifiedAt == now` hinten in der Liste, die übrigen Einträge unverändert. Test: `testSavingEditNeuerBausteinWirdAngehaengt`.
- **AC-4 (Unit): Zurückgenommener Baustein wird als Hennings Fassung wieder angelegt.** Given `original` (mit Claude-Herkunft), geänderter `edited`, und eine Liste, aus der der Baustein inzwischen entfernt wurde, When `savingEdit`, Then steht `edited` mit `modifiedAt == now` und weiterhin gesetzter `claude`-Herkunft hinten in der Liste. Test: `testSavingEditZurueckgenommenerBausteinWirdWiederAngelegt`.
- **AC-5 (Unit): Veralteter Editor ohne Änderung überschreibt keine neuere Revision.** Given eine Liste, in der der Baustein inzwischen eine höhere `revision` trägt als `original`, und `edited == original`, When `savingEdit`, Then ist das Ergebnis `nil` (die höhere Revision bleibt). Test: `testSavingEditUnveraendertLaesstNeuereRevisionStehen`.
- **AC-6 (Unit): Hennings Fassung sperrt nachfolgende Lieferung.** Given ein per `savingEdit` geänderter Claude-Baustein (`modifiedAt = now`) im `ClaudeApplyState` mit `lastSnapshotAt` vor `now` (und getrennt: `lastSnapshotAt == nil`), When `apply` einer Lieferung mit höherer `revision` desselben Bausteins, Then ist das Ergebnis `rejected(code: "CHANGED_ON_IPHONE", …)` und die Liste unverändert. Test: `testGeaenderterClaudeBausteinLehntLieferungAb` (je Programm und Atemübung).
- **AC-7 (Unit): Schritt behält `claude.*` bei unverändertem Namen.** Given eine `WorkoutPhase` mit `exerciseId == "claude.x"` und `name == "Bergsteiger Plus"`, When `applyKeepingClaudeId(ownName: "Bergsteiger Plus")`, Then bleiben `exerciseId == "claude.x"` und `name` unverändert. Test: `testPhaseBehaeltClaudeIdBeiUnveraendertemNamen`.
- **AC-8 (Unit): Namenswechsel setzt `own.*`.** Given dieselbe Phase, When `applyKeepingClaudeId(ownName: "Mein Name")`, Then ist `exerciseId == ExerciseDatabase.ownExerciseId(forName: "Mein Name")` und `name == "Mein Name"`; für eine Phase mit `own.*`- oder `builtin.*`-Kennung verhält sich die Funktion wie `apply(.own(name:))`. Test: `testPhaseWechseltAufOwnBeiNamensaenderung`.
- **AC-9 (Unit): Katalogwechsel ersetzt `claude.*`.** Given dieselbe Phase, When `apply(.catalog(id: "builtin.…"))` (Picker-Weg, unverändertes Verhalten), Then ist `exerciseId` die Katalogkennung. Test: `testPhaseKatalogwechselErsetztClaudeId`.
- **AC-10 (Unit): Migration setzt kein `modifiedAt`.** Given ein Programm mit Claude-Herkunft und einer `claude.*`-Phase (ohne `modifiedAt`), When `WorkoutSet.migratingPresets`, Then bleibt `modifiedAt == nil` und die `claude.*`-Kennung unverändert. Test: `testMigratingPresetsLaesstClaudeProgrammUnberuehrt`.
- **AC-11 (UI): Durchlauf „Hennings Fassung bleibt“.** Given ein Start mit `enable-testing`, `uitest-disk-store`, `uitest-reset-store` und `uitest-claude-apply` mit einer Lieferung (Programm mit eindeutigem Testnamen, Revision 1), When das gelieferte Programm im Workout-Tab geöffnet, im Editor der Programmname geändert und bestätigt wird, die App danach beendet und mit `uitest-claude-apply` und einer Lieferung desselben Programms in Revision 2 neu gestartet wird, Then zeigt der Workout-Tab weiterhin Hennings geänderten Namen, der Name aus Revision 2 erscheint nicht, und eine zweite Lieferung (Rücknahme per `itemId`) lässt das Programm ebenfalls stehen. Zusätzlich: Wird das Programm geöffnet und ohne Änderung bestätigt und danach Revision 2 geliefert, wird Revision 2 angewendet (Name aus Revision 2 sichtbar), weil kein `modifiedAt` gesetzt wurde. Test: `ClaudeSpeichernUITests/testBearbeitetesClaudeProgrammBleibtBeiNeuerRevision` und `…/testUnveraendertBestaetigtesClaudeProgrammWirdAktualisiert`. Der Teardown räumt per Rücknahme-Lieferung bzw. `uitest-reset-store` auf.
- **AC-12 (UI): Schritt-Editor behält die Kennung im Durchlauf.** Given das gelieferte Programm mit einem Schritt `claude.*` aus AC-11, When der Schritt im Schritt-Editor geöffnet und ohne Namensänderung bestätigt (Dauer geändert) und das Programm gespeichert wird, Then trägt der Schritt danach weiter die Übung mit dem gelieferten Namen in der Programmliste, und das Programm gilt als von Henning geändert (neue Revision wird abgelehnt wie in AC-11). Die Kennung selbst wird in AC-7 bis AC-9 bewiesen; der UI-Test prüft die sichtbare Folge (Name unverändert, Lieferung abgelehnt). Test: `ClaudeSpeichernUITests/testSchrittEditorBehaeltClaudeUebung`.
- **AC-13 (jede Runde): Reinheit, Build, Budget.** Given der Diff der Runde, Then ist `ClaudeApply.swift` unverändert und `testApplyDateiIstFoundationOnlyUndOhneSeiteneffekte` grün; `ClaudeStore.swift` importiert nur `Foundation`; iOS, Watch und Widget bauen; der Produktiv-Diff (App-Code ohne Tests, Löschzeilen mitgezählt) liegt bei höchstens 250 Zeilen, keine Funktion über 50 Zeilen; Protokoll `Executed N tests` mit N ≥ 1; die bestehenden Tests (`ClaudeStoreTests`, `WorkoutPhaseMigrationTests`, `ClaudeFelderUITests`, `ClaudeSpeichernUITests` aus 2b-1) bleiben grün. Nachweis in der Adversary-Prüfung: Diff-Durchsicht, nur die vier App-Dateien der Runde plus Specs und Tests.

## Test Plan

- [ ] Unit (neue Datei `LeanHealthTimerTests/ClaudeEditorSpeichernTests.swift`): AC-1 bis AC-10, reine Funktionen, keine `UserDefaults` nötig außer AC-10 (Migration)
- [ ] UI (`LeanHealthTimerUITests/ClaudeSpeichernUITests.swift`, erweitert): AC-11, AC-12; Aufruf `./Scripts/run-uitests.sh ClaudeSpeichernUITests/<Methode>` (immer mit Klasse), Nachweis nur mit `Executed N tests`, N ≥ 1
- [ ] Bestand: vollständige Unit-Suite, `ClaudeApplyTests`-Quelltextwächter, `ClaudeFelderUITests/testProgrammeUndAtemuebungenUeberstehenNeustart`
- [ ] RED-Beleg: Die neuen Tests scheitern zuerst, weil `savingEdit` und `applyKeepingClaudeId` fehlen und `modifiedAt` nie gesetzt wird
- [ ] Durchlauf als Nutzer im Simulator vor Übergabe: Programm liefern, bearbeiten, neue Revision liefern, Ablehnung sehen (kein Gerät von Henning)

## Definition of Done

- [ ] Build grün für iOS, Watch und Widget
- [ ] ACs AC-1 bis AC-13 nachgewiesen, im Protokoll `Executed N tests` mit N ≥ 1
- [ ] Vollständige Unit-Suite und die genannten UI-Tests grün
- [ ] Produktiv-Diff ≤ 250 Zeilen, Funktionen ≤ 50 Zeilen
- [ ] Adversary-Prüfung: Verdict VERIFIED
- [ ] `openspec/specs/features/claude-annahme.md` nachgezogen: Schnitt 2b vollständig erledigt, Schnitt 3 und #57 offen
- [ ] Änderungen am Gerät von Henning: keine, kein Start auf seinen Geräten

## Changelog

- 2026-11-21 (RED): Tests angelegt. Abweichungen mit Begründung: AC-12 ändert den Schritt über das Hinweisfeld (`workout.phaseEditor.hintField`) statt über die Dauer, weil das Dauer-Rad keine Kennung hat (gleichwertig: Schritt geändert → Programm geändert). AC-11/12 starten mit dem vorhandenen Helfer (`enable-testing` + `uitest-claude-apply`) ohne `uitest-disk-store`, weil Programme in `UserDefaults` liegen, nicht in SwiftData. Der Teardown löscht von Henning geänderte Programme über den Editor, weil die Rücknahme sie mit `CHANGED_ON_IPHONE` ablehnt. „Revision 2 erscheint nicht“ wird nach 5 s Wartezeit geprüft (invertierte Erwartung). `testUnveraendertBestaetigtesClaudeProgrammWirdAktualisiert` ist schon vor der Umsetzung grün (Bestandsverhalten, muss grün bleiben).
- 2026-11-21: Angelegt als Rundenspec 2b-2 (Elternspec und 2b-1 eingefroren); Alternativen B, C, D verworfen; Fall „veralteter Editor ohne Änderung“ durch „unverändert → nichts schreiben“ gelöst.
