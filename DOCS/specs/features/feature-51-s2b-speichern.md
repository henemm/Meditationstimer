---
entity_id: feature-51-s2b-speichern
type: feature
created: 2026-11-21
updated: 2026-11-21
status: draft
workflow: feature-51-s2b-speichern
issue: 51
epic: 44
parent: feature-51-s2-bausteine-anwenden
---

# Runde 2b-1: Claude-Bausteine speichern, laden, neu laden (#51, Schnitt 2b)

## Approval

- [ ] Approved

Freigabe dieser Rundenspec durch den PO.

## Purpose

Runde 2b-1 der freigegebenen Elternspec `DOCS/specs/features/feature-51-s2-bausteine-anwenden.md`: Das Ergebnis von `apply` (Schnitt 2a) wird dauerhaft gespeichert, beim Start geladen und in den offenen Tabs neu geladen. Die Elternspec gilt weiter (Regeln 1–14, `claudeState`, `revision`, Ablehnungen); diese Datei präzisiert nur, was sie für Schnitt 2b offenlässt.

Für Henning sichtbar ist in dieser Runde nur Neustartfestigkeit: Bis #57 ruft nichts im Betrieb `apply` auf, es gibt keine neue Oberfläche und kein Kennzeichen „von Claude“ (Schnitt 3). Der Nachweis läuft über Unit-Tests mit isolierten `UserDefaults` und einen DEBUG-Testeinstieg (Startargument), der nur in Debug-Builds existiert.

## Source

- Analyse: `DOCS/context/feature-51-s2b-speichern.md` (Befunde, Recherche, Zuschnitt, Alternativen, Risiken)
- Elternspec: `DOCS/specs/features/feature-51-s2-bausteine-anwenden.md`, Abschnitt „Nicht in Scope (gehört zu Schnitt 2b)“
- Vorgängerrunde (Formvorbild): `DOCS/specs/features/feature-51-s2a3-ruecknahme.md`
- Bestand: `claudeState` als eigener Speicher in `openspec/specs/features/claude-annahme.md:21`

## Dependencies

| Abhängigkeit | Art | Hinweis |
|---|---|---|
| `ClaudeDelivery` (Schnitt 1), `apply`, `ClaudeApplyState`, `ClaudeStoredExercise`, `ClaudeApplyLogEntry` (2a) | Upstream, nur lesen | `ClaudeApply.swift` bleibt unverändert (Quelltext-Wächter `ClaudeApplyTests.swift:951-966`) |
| `WorkoutSet`, `WorkoutSet.loadStored`, `WorkoutSet.migratingPresets`, `defaultWorkoutSets` | Bestand, wird erweitert | `WorkoutProgramsView.swift:322-358`, `WorkoutTab.swift:801` |
| `AtemView.Preset`, `MeditationTab.defaultPresets` (heute `private static`, :69) | Bestand; `Preset` wird per Erweiterung in `ClaudeStore.swift` ergänzt, `AtemView.swift` bleibt unverändert | Migration `migratePresets` (:472) ist Instanzcode |
| `UserDefaults.standard`, Keys `workoutProgramSets`, `atemPresets`, `claudeState` | Speicher | nur `WorkoutTab` und `MeditationTab` lesen/schreiben die ersten beiden (grep 2026-11-21) |
| Watch, Widget | keine Mitkompilierung (geprüft 2026-11-21 in `project.pbxproj`: nur das Ziel „Lean Health Timer“ synchronisiert den Ordner `Meditationstimer iOS`; Watch übernimmt daraus nur `auftakt.caf` und `Localizable.xcstrings`, Widget nur `Localizable.xcstrings` und `MeditationActivityAttributes.swift`) | `ClaudeStore.swift` darf deshalb `WorkoutSet`, `AtemView.Preset` und die Vorgaben referenzieren; importiert trotzdem nur `Foundation`; Build aller drei Ziele bleibt als Wächter in der DoD |

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine neue; gilt die ADR der Elternspec (reine Funktion `apply`, Persistenz in eigener Datei).

**Rationale:** Persistenz, Benachrichtigung und Uhr gehören nicht in `ClaudeApply.swift` (Wächtertest), deshalb eine neue Datei `ClaudeStore.swift` als dünne Hülle um `apply`. Sie benutzt für „gespeichert oder Vorgaben + Migration“ **denselben** Lader wie die Tabs. Würde das Anwenden bei fehlendem Key mit leerer Liste starten und diese schreiben, verschwänden die Code-Vorgaben aus der Anzeige.

**Alternativen (verworfen für 2b):**
1. Gemeinsamer Listen-Besitzer (`ObservableObject` für beide Listen statt `@State` + Benachrichtigung): beseitigt doppelte Kopien grundsätzlich, braucht aber Umbau beider Tabs und aller Editor-Aufrufe (> 250 Zeilen). Kandidat, falls AC-12 (Tabwechsel) oder AC-11 zeigt, dass `onReceive` in einem nicht sichtbaren Tab nicht greift. Kippt dann die Annahme „Benachrichtigung genügt“ der Analyse.
2. Alles in einer Datei statt `UserDefaults` (echte Atomarität): ändert den Speicherort bestehender Nutzerdaten und braucht Umzug; die Reihenfolge „Listen zuerst, `claudeState` zuletzt“ plus `revision`-Prüfung reicht (`UserDefaults` kennt keine Transaktion über mehrere Keys; `synchronize()` ist überflüssig).

## Scope

Fünf Dateien App-Code, geschätzt +170/−30 Zeilen, Grenze 250 (Tests zählen nicht):

- `Meditationstimer iOS/Models/ClaudeStore.swift` (CREATE, nur `Foundation`)
- `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` (MODIFY: `backUpUnreadable` generisch mit Präfix-Parameter; statischer Lader „gespeichert oder Vorgaben + Migration“)
- `Meditationstimer iOS/Tabs/WorkoutTab.swift` (MODIFY: `loadSets` über den gemeinsamen Lader; `.onReceive` → neu laden)
- `Meditationstimer iOS/Tabs/MeditationTab.swift` (MODIFY: Vorgaben + Migration statisch und rein; Laden mit Sicherung; `.onReceive` → neu laden)
- `Meditationstimer iOS/Meditationstimer_iOSApp.swift` (MODIFY, nur `#if DEBUG`: Testeinstieg)

**Nicht in Scope:** alles aus Runde 2b-2 (`modifiedAt` im Editor setzen, Schritt-Editor behält `claude.*`, Test `migratingPresets` + Claude-Programm, offener Editor + Anwenden); Aufrufer aus dem Dienst und `lastSnapshotAt` (#57); jede neue Oberfläche und das Kennzeichen „von Claude“ (Schnitt 3); jede Änderung an `ClaudeApply.swift`, `ClaudeDelivery.swift`, `AtemView.swift`, `ExerciseDatabase.swift`, `project.pbxproj`.

**Bewusste Abweichungen von der Elternspec:** (a) Deren Risiko-Abschnitt nimmt an, Watch und Widget kompilierten den Ordner `Meditationstimer iOS` mit; das trifft laut `project.pbxproj` nicht zu (siehe Dependencies), der Build-Wächter bleibt trotzdem. (b) Punkt 5 von „Nicht in Scope (gehört zu Schnitt 2b)“ (`claude.*` in `ExerciseDatabase.info(forId:)` auflösen) wird **nicht** in 2b umgesetzt, sondern nach Schnitt 3 verschoben. Begründung: `displayName` löst `claude.*` schon richtig auf (`ExerciseDatabase.swift:756`); einziger echter Verbraucher von `info(forId:)` ist das Info-Blatt (Schnitt 3), und der Schritt-Editor braucht es mit der Lösung aus 2b-2 nicht.

## Festlegungen (Tech-Lead, gelten zusätzlich zu den Regeln der Elternspec)

Bezeichner sind geprüft gegen den Code (2026-11-21); neue Namen sind als solche markiert. Verbindlich ist das beschriebene Verhalten; ein neuer Name darf bei der Umsetzung nur mit Begründung im RED-Bericht abweichen.

1. **Schnittstelle (neu):** `enum ClaudeStore` in `ClaudeStore.swift` mit `static func apply(_ delivery: ClaudeDelivery, in defaults: UserDefaults = .standard, lastSnapshotAt: Date?, now: Date = Date(), center: NotificationCenter? = .default) -> ClaudeApplyResult`. Die Uhr (`Date()`) und `UserDefaults`/`NotificationCenter` stehen nur hier, nie in `ClaudeApply.swift`.
2. **Keys und Sicherungspräfixe:** Listen unter `workoutProgramSets` und `atemPresets` (unverändert), Gedächtnis unter `claudeState` (neu). Sicherungspräfixe: `workoutProgramSetsBackup.` (Bestand), `atemPresetsBackup.` (neu), `claudeStateBackup.` (neu); Schlüssel `<Präfix><Unix-Sekunden>`, mit Zähler `-2`, `-3` bei Kollision, nie überschreiben, keine Doppelung gleicher Bytes (Verhalten des bestehenden `backUpUnreadable`, :333).
3. **Inhalt von `claudeState` (neu):** JSON eines Typs `ClaudeStoredState` mit genau `exercises: [ClaudeStoredExercise]` und `log: [ClaudeApplyLogEntry]`. Die Listen `sets` und `presets` von `ClaudeApplyState` stehen **nicht** darin (Analyse Befund 8); der Zustand für `apply` wird aus den drei Keys zusammengesetzt.
4. **Lader mit Vorgaben:** Fehlender Key ergibt Code-Vorgaben (`defaultWorkoutSets`, `MeditationTab.defaultPresets`), nie eine leere Liste; ein gelesener Key wird mit der bestehenden reinen Migration ergänzt (`WorkoutSet.migratingPresets`; für Atemübungen neu als `static`-Funktion in `MeditationTab.swift` mit demselben Ergebnis wie heutiges `migratePresets`). Der Lader meldet den Zustand `fehlend`, `gespeichert` oder `unlesbar` (neuer kleiner Aufzählungstyp in `ClaudeStore.swift`), damit `ClaudeStore` unlesbare Listen von fehlenden unterscheiden kann. Tabs zeigen bei `unlesbar` wie heute die Vorgaben und schreiben die Rohdaten erst nach erfolgter Sicherung (Festlegung 2) beim nächsten Speichern durch Henning über. `MeditationTab.defaultPresets` (heute `private static`, :69) wird dafür modulintern (`static`); `defaultWorkoutSets` ist bereits global (`WorkoutTab.swift:801`).
5. **Ablehnungscode (neu):** `LIST_UNREADABLE`, Text: „Die gespeicherten Programme oder Atemübungen sind nicht lesbar; bitte später neu lesen.“ Er steht in keinem Bezugsdokument (Lücke wie in der Elternspec vorgesehen) und wird hier festgelegt. Er kommt aus `ClaudeStore`, nie aus `apply`, und wird **nicht** ins Gedächtnis (`log`) geschrieben.
6. **Schreibregel:** Listen (Reihenfolge: `workoutProgramSets`, `atemPresets`) werden nur bei Ergebnis `applied` geschrieben, `claudeState` immer zuletzt und nur, wenn sich sein Inhalt gegenüber dem gespeicherten ändert. Bei `noEffect` und bei von `apply` abgelehnten Lieferungen (z. B. `CATEGORY_UNKNOWN`) bleiben die Listen unberührt; die Ablehnung steht im Gedächtnis.
7. **Prüfreihenfolge in `ClaudeStore.apply`:** erst beide Listen lesen (unlesbar → `LIST_UNREADABLE`, Sicherung wie in Festlegung 2, sonst nichts geschrieben), dann `claudeState` lesen (unlesbar → Sicherung unter `claudeStateBackup.`, mit leerem Gedächtnis und ohne Übungen weitermachen), dann `apply`. Eine bereits bekannte Lieferung bei unlesbarer Liste ergibt deshalb `LIST_UNREADABLE` statt des gemerkten Ergebnisses (konservativ, nichts wird verändert). Das ist eine bewusste Ausnahme von Regel 2 der Elternspec (Idempotenz): Solange eine Liste unlesbar ist, wird keine Lieferung beantwortet, auch keine bekannte.
8. **Benachrichtigung (neu):** `Notification.Name.claudeStoreDidChange` (Rohwert `"ClaudeStore.didChange"`), gesendet über das übergebene `center` **nach** dem letzten Schreibvorgang und nur, wenn in **diesem** Aufruf die Listen geschrieben wurden (neues Ergebnis `applied`). Ein aus dem Gedächtnis wiederholtes `applied` (Idempotenz, AC-5) schreibt nichts und sendet nichts. `WorkoutTab` und `MeditationTab` laden darauf per `.onReceive` neu; das Laden in `onAppear` bleibt.
9. **DEBUG-Testeinstieg (neu, nur `#if DEBUG` in `Meditationstimer_iOSApp.swift`, bis #57):** Startargument `uitest-claude-apply`; die Lieferung steht als JSON-Text in der Umgebungsvariablen `UITEST_CLAUDE_DELIVERY`, optional `UITEST_CLAUDE_DELAY` (Sekunden, Dezimalzahl, Standard 0). Verzögerung 0: wird beim Start vor dem ersten Bild angewendet; größer 0: nach Ablauf der Zeit auf dem Hauptakteur (die Tabs sind dann schon sichtbar). Gelesen wird mit `ClaudeDelivery.read`, angewendet mit `ClaudeStore.apply(…, lastSnapshotAt: nil, now: Date())`. Lässt sich die Lieferung nicht lesen, wird sie ignoriert (kein Absturz). Im Release-Build existiert dieser Code nicht.
10. **Sicherung `atemPresets` (neu):** `AtemView.Preset.loadStored(from:key:now:)` als Gegenstück zu `WorkoutSet.loadStored`, gleiche Regeln; `MeditationTab.loadPresets` benutzt es statt `try?`. Die Funktion steht als `extension AtemView.Preset` in `ClaudeStore.swift`; `AtemView.swift` bleibt unverändert (Scope: fünf Dateien).

## Acceptance Criteria

Alle als Given/When/Then; „Unit“ = isolierte `UserDefaults(suiteName:)` mit UUID, Aufräumen im `tearDown` (Muster `LeanHealthTimerTests/WorkoutPhaseMigrationTests.swift`); „UI“ = `LeanHealthTimerUITests/` (Muster `ClaudeFelderUITests.swift`).

- **AC-1 (Unit): Fehlende Listen ergeben Vorgaben, nicht leer.** Given leere `UserDefaults` (keiner der drei Keys), When `ClaudeStore.apply` mit einer Lieferung aus einem Programm und einer Atemübung, Then ist das Ergebnis `applied`, und die geschriebene Programmliste besteht aus `defaultWorkoutSets` (Vorgaben, ihre Reihenfolge) plus dem gelieferten Programm, die geschriebene Atemliste aus `MeditationTab.defaultPresets` plus der gelieferten Atemübung.
- **AC-2 (Unit): Gültige gespeicherte Listen bleiben erhalten.** Given gespeicherte Listen mit eigenen Einträgen (Reihenfolge und Werte bekannt), When `apply` einer Lieferung, Then sind die eigenen Einträge unverändert und in derselben Reihenfolge geschrieben, das Gelieferte folgt den Regeln der Elternspec.
- **AC-3 (Unit): Schreibreihenfolge und Inhalt von `claudeState`.** Given eine `UserDefaults`-Unterklasse, die jeden `set(_:forKey:)`-Aufruf mit Key aufzeichnet, When `apply` mit `applied` (Programm, Atemübung, Übung), Then ist die Reihenfolge der Schreibvorgänge `workoutProgramSets`, `atemPresets`, `claudeState`, und das JSON unter `claudeState` enthält als Schlüssel nur `exercises` und `log` (kein `sets`, kein `presets`) und lässt sich als `ClaudeStoredState` mit der gelieferten Übung und dem Log-Eintrag dekodieren.
- **AC-4 (Unit): Schreiben nur bei Bedarf.** Given je eine Lieferung mit Ergebnis `noEffect` (Revision nicht neuer) und mit von `apply` abgelehntem Ergebnis (z. B. `CATEGORY_UNKNOWN`), When `ClaudeStore.apply`, Then sind die Bytes unter `workoutProgramSets` und `atemPresets` unverändert (bzw. nicht angelegt), die Ablehnung steht im Log unter `claudeState`, und es wird keine Benachrichtigung gesendet.
- **AC-5 (Unit): Idempotenz über Neustart.** Given eine angewendete Lieferung und ein „Neustart“ (neue `UserDefaults(suiteName:)`-Instanz mit gleichem Namen, neuer `NotificationCenter`), When dieselbe Lieferung (gleiche `deliveryId`) noch einmal angewendet wird, Then liefert `ClaudeStore.apply` das gemerkte Ergebnis (`applied`), alle drei Keys sind byte-gleich zu vorher, und es wird keine Benachrichtigung gesendet.
- **AC-6 (Unit): Unlesbare Liste lehnt ab.** Given unlesbare Rohdaten unter `workoutProgramSets` (und getrennt: unter `atemPresets`), When `ClaudeStore.apply` mit einer gültigen Lieferung, Then ist das Ergebnis `rejected(code: "LIST_UNREADABLE", reason: …)` mit dem Text aus Festlegung 5, die Rohdaten sind unter `workoutProgramSetsBackup.` bzw. `atemPresetsBackup.` gesichert, es wurde kein Key der Liste und kein `claudeState` geschrieben, das Gedächtnis enthält die Lieferung nicht (derselbe Aufruf nach Reparatur der Liste wendet sie normal an), und es wird keine Benachrichtigung gesendet.
- **AC-7 (Unit): Unlesbarer `claudeState` wird gesichert.** Given gültige Listen und unlesbare Rohdaten unter `claudeState`, When `apply` einer gültigen Lieferung, Then liegen die Rohdaten unter `claudeStateBackup.<Sekunden>`, die Lieferung wird mit leerem Gedächtnis und ohne Übungen angewendet (Ergebnis `applied`), und `claudeState` ist danach lesbar und enthält die neue Lieferung.
- **AC-8 (Unit): Sicherung unlesbarer `atemPresets` beim Laden.** Given unlesbare Rohdaten unter `atemPresets`, When `AtemView.Preset.loadStored` (zweimal mit gleichen Rohdaten, einmal mit geänderten Rohdaten und gleicher Sekunde), Then ist das Ergebnis `nil`, der Lader der Tabs meldet `unlesbar` und liefert `MeditationTab.defaultPresets` (Tab zeigt Vorgaben), die Rohdaten liegen genau einmal unter `atemPresetsBackup.`, die geänderten Rohdaten unter einem zweiten Schlüssel mit Zähler (`-2`), nichts wird überschrieben.
- **AC-9 (Unit): Bestehende Sicherung der Programme bleibt gleich.** Given die Tests zu `workoutProgramSetsBackup.` in `WorkoutPhaseMigrationTests`, When die Funktion `backUpUnreadable` auf einen Präfix-Parameter umgestellt ist, Then laufen sie unverändert grün (gleiche Schlüsselnamen, gleiche Kollisionsregeln).
- **AC-10 (Unit): Benachrichtigung nach dem Schreiben, nur bei `applied`.** Given ein eigenes `NotificationCenter` mit Beobachter, der beim Eintreffen `claudeState` und die Listen aus den `UserDefaults` liest, When `apply` mit `applied`, Then wird genau eine Benachrichtigung `.claudeStoreDidChange` gesendet, und im Beobachter ist der neue Stand in allen drei Keys schon lesbar; bei `noEffect`, bei von `apply` Abgelehntem und bei `LIST_UNREADABLE` wird keine gesendet.
- **AC-11 (UI): Lieferung erscheint in sichtbarem Tab.** Given ein Start mit `enable-testing`, `uitest-claude-apply`, `UITEST_CLAUDE_DELIVERY` (Lieferung mit einem Programm; Aufbau nach den Beispielen unter `Contracts/deliveries/valid/`, mit einem eindeutigen Testnamen) und `UITEST_CLAUDE_DELAY` = 3, When der Workout-Tab schon sichtbar ist und die Verzögerung abgelaufen ist, Then erscheint das gelieferte Programm in der Liste, und mindestens ein Vorgabe-Programm (`defaultWorkoutSets`) ist weiterhin sichtbar. Dasselbe für eine gelieferte Atemübung im Meditation-Tab.
- **AC-12 (UI): Lieferung erscheint nach Tabwechsel.** Given derselbe Aufbau wie AC-11, When die Lieferung eintrifft, während ein anderer Tab sichtbar ist, und danach zum Workout- bzw. Meditation-Tab gewechselt wird, Then ist der gelieferte Baustein dort sichtbar, und ein anschließendes Bearbeiten und Speichern eines **anderen** Eintrags in diesem Tab (z. B. Bestätigen des Editors für einen eigenen Eintrag) lässt den gelieferten Baustein in der Liste stehen (kein Überschreiben durch eine veraltete Kopie).
- **AC-13 (UI): Lieferung übersteht Neustart.** Given AC-11 erfüllt, When die App beendet und ohne `uitest-claude-apply` neu gestartet wird, Then sind das gelieferte Programm und die gelieferte Atemübung weiterhin in den Listen, und die Vorgaben stehen unverändert da.
- **AC-14 (UI): Rücknahme per Paket räumt auf.** Given AC-13 erfüllt und die Lieferung trug eine `packageId`, When die App mit einer zweiten Lieferung (Rücknahme per dieser `packageId`, neue `deliveryId`) gestartet wird, Then sind die gelieferten Bausteine aus den Listen verschwunden, die Vorgaben und eigene Einträge bleiben; ein Neustart ohne Startargument zeigt dasselbe. Der Teardown der UI-Tests wendet diese Rücknahme an, damit der Simulator sauber bleibt.
- **AC-15 (UI): Testeinstieg bricht nichts.** Given `uitest-claude-apply` mit unlesbarem Inhalt in `UITEST_CLAUDE_DELIVERY`, When die App startet, Then erscheinen die Tabs wie ohne Lieferung, und die Listen zeigen die Vorgaben bzw. den bisherigen Stand. Der Code des Einstiegs steht vollständig in `#if DEBUG`; der Release-Build der App übersetzt ihn nicht.
- **AC-16 (bestehende Tests): Altdaten erscheinen wie heute.** Given der umgebaute Lader in beiden Tabs, When die vollständige Unit-Suite `LeanHealthTimerTests` und `ClaudeFelderUITests/testProgrammeUndAtemuebungenUeberstehenNeustart` laufen, Then sind sie grün; gespeicherte Altlisten ohne Claude-Felder werden wie zuvor gelesen und nicht durch Vorgaben ersetzt.
- **AC-17 (jede Runde): Reinheit, Build, Budget.** Given der Diff der Runde, Then ist `ClaudeApply.swift` unverändert und `testApplyDateiIstFoundationOnlyUndOhneSeiteneffekte` grün; `ClaudeStore.swift` importiert nur `Foundation`; iOS, Watch und Widget bauen; der Produktiv-Diff (App-Code ohne Tests, Löschzeilen mitgezählt) liegt bei höchstens 250 Zeilen, keine Funktion über 50 Zeilen; Protokoll `Executed N tests` mit N ≥ 1. Nachweis in der Adversary-Prüfung: Diff-Durchsicht, nur die fünf Dateien der Runde plus Specs und Tests.

## Test Plan

- [ ] Unit (neue Testdatei `LeanHealthTimerTests/ClaudeStoreTests.swift`): AC-1 bis AC-8 und AC-10, isolierte `UserDefaults(suiteName:)`, aufzeichnende `UserDefaults`-Unterklasse für AC-3, eigenes `NotificationCenter` für AC-4, AC-5, AC-10
- [ ] Unit (Bestand): AC-9 (`WorkoutPhaseMigrationTests` unverändert grün), AC-16 (vollständige Unit-Suite), `ClaudeApplyTests`-Quelltextwächter
- [ ] UI (neue Datei `LeanHealthTimerUITests/ClaudeSpeichernUITests.swift`): AC-11 bis AC-15, Aufruf `./Scripts/run-uitests.sh ClaudeSpeichernUITests/<Methode>` (immer mit Klasse), Nachweis nur mit `Executed N tests`, N ≥ 1
- [ ] Bestand UI: `ClaudeFelderUITests/testProgrammeUndAtemuebungenUeberstehenNeustart` als Wächter für AC-16
- [ ] RED-Beleg: Die neuen Tests scheitern zuerst, weil `ClaudeStore`, `Preset.loadStored` und der Testeinstieg fehlen; kein Gerüst im Produktivcode
- [ ] Durchlauf als Nutzer im Simulator vor Übergabe: Lieferung per Startargument, Liste sehen, Neustart, Rücknahme (Pflicht der Arbeitsweise, kein Gerät von Henning)

## Definition of Done

- [ ] Build grün für iOS, Watch und Widget
- [ ] ACs AC-1 bis AC-17 nachgewiesen, im Protokoll `Executed N tests` mit N ≥ 1
- [ ] Vollständige Unit-Suite und die genannten UI-Tests grün
- [ ] Produktiv-Diff ≤ 250 Zeilen, Funktionen ≤ 50 Zeilen
- [ ] Adversary-Prüfung: Verdict VERIFIED
- [ ] `openspec/specs/features/claude-annahme.md` nachgezogen: Schnitt 2b-1 erledigt, 2b-2 offen, Verschiebung von `info(forId:)` nach Schnitt 3
- [ ] Änderungen am Gerät von Henning: keine, kein Start auf seinen Geräten

## Changelog

- 2026-11-21: RED-Bericht, Namen zu Festlegung 4 festgelegt durch die Tests: `enum ClaudeListState { case missing, stored, unreadable }`, `ClaudeStore.loadSets(from:now:) -> (list: [WorkoutSet], state: ClaudeListState)`, `ClaudeStore.loadPresets(from:now:) -> (list: [AtemView.Preset], state: ClaudeListState)`; `ClaudeStoredState` mit Standard-`JSONDecoder`. UI-Test AC-11 nutzt `UITEST_CLAUDE_DELAY` = 8 statt 3 (Tab sicher sichtbar vor der Lieferung). AC-15 und der Import-Wächter aus AC-17 zusätzlich als Quelltext-Wächter in `ClaudeStoreTests`.

- 2026-11-21: Nach Validierung: `Preset.loadStored` als Erweiterung in `ClaudeStore.swift` (AtemView unverändert), Benachrichtigung nur bei echtem Schreiben, Ausnahme von Regel 2 benannt, Mitkompilierung Watch/Widget geklärt.
- 2026-11-21: Angelegt als Rundenspec 2b-1 (Elternspec eingefroren); Festlegungen zu Benachrichtigung, Testeinstieg, `LIST_UNREADABLE` und Verschiebung von `info(forId:)` nach Schnitt 3.
