# Adversary Dialog — feature-51-s2b-speichern
Spec: DOCS/specs/features/feature-51-s2b-speichern.md
Datum: 2026-11-21 15:30

## Checkliste
- [x] **AC-1 (Unit): Fehlende Listen ergeben Vorgaben, nicht leer.** Given leere `UserDefaults` (keiner der drei Keys), When `ClaudeStore.apply` mit einer Lieferung aus einem Programm und einer Atemübung, Then ist das Ergebnis `applied`, und die geschriebene Programmliste besteht aus `defaultWorkoutSets` (Vorgaben, ihre Reihenfolge) plus dem gelieferten Programm, die geschriebene Atemliste aus `MeditationTab.defaultPresets` plus der gelieferten Atemübung.
  Beweis: ClaudeStore.swift:52,60 (fehlender Key liefert Vorgaben); testAC1 grün
- [x] **AC-2 (Unit): Gültige gespeicherte Listen bleiben erhalten.** Given gespeicherte Listen mit eigenen Einträgen (Reihenfolge und Werte bekannt), When `apply` einer Lieferung, Then sind die eigenen Einträge unverändert und in derselben Reihenfolge geschrieben, das Gelieferte folgt den Regeln der Elternspec.
  Beweis: testAC2 grün; Korrektur (Vergleich nach Encode/Decode) schwächt nicht ab: WorkoutSet-Decoder leitet exerciseId aus dem Namen ab (WorkoutProgramsView.swift:231-242), Namen/Emoji/Reihenfolge werden weiter einzeln geprüft
- [x] **AC-3 (Unit): Schreibreihenfolge und Inhalt von `claudeState`.** Given eine `UserDefaults`-Unterklasse, die jeden `set(_:forKey:)`-Aufruf mit Key aufzeichnet, When `apply` mit `applied` (Programm, Atemübung, Übung), Then ist die Reihenfolge der Schreibvorgänge `workoutProgramSets`, `atemPresets`, `claudeState`, und das JSON unter `claudeState` enthält als Schlüssel nur `exercises` und `log` (kein `sets`, kein `presets`) und lässt sich als `ClaudeStoredState` mit der gelieferten Übung und dem Log-Eintrag dekodieren.
  Beweis: ClaudeStore.swift:86-90 Reihenfolge sets, presets, state; ClaudeStoredState nur exercises/log (:18-21); testAC3 grün
- [x] **AC-4 (Unit): Schreiben nur bei Bedarf.** Given je eine Lieferung mit Ergebnis `noEffect` (Revision nicht neuer) und mit von `apply` abgelehntem Ergebnis (z. B. `CATEGORY_UNKNOWN`), When `ClaudeStore.apply`, Then sind die Bytes unter `workoutProgramSets` und `atemPresets` unverändert (bzw. nicht angelegt), die Ablehnung steht im Log unter `claudeState`, und es wird keine Benachrichtigung gesendet.
  Beweis: :84 wroteLists nur bei isNew und applied; Probe B (noEffect, Listen-Bytes gleich, Log geschrieben, keine Meldung) grün
- [x] **AC-5 (Unit): Idempotenz über Neustart.** Given eine angewendete Lieferung und ein „Neustart“ (neue `UserDefaults(suiteName:)`-Instanz mit gleichem Namen, neuer `NotificationCenter`), When dieselbe Lieferung (gleiche `deliveryId`) noch einmal angewendet wird, Then liefert `ClaudeStore.apply` das gemerkte Ergebnis (`applied`), alle drei Keys sind byte-gleich zu vorher, und es wird keine Benachrichtigung gesendet.
  Beweis: :80,84; testAC5 grün
- [x] **AC-6 (Unit): Unlesbare Liste lehnt ab.** Given unlesbare Rohdaten unter `workoutProgramSets` (und getrennt: unter `atemPresets`), When `ClaudeStore.apply` mit einer gültigen Lieferung, Then ist das Ergebnis `rejected(code: "LIST_UNREADABLE", reason: …)` mit dem Text aus Festlegung 5, die Rohdaten sind unter `workoutProgramSetsBackup.` bzw. `atemPresetsBackup.` gesichert, es wurde kein Key der Liste und kein `claudeState` geschrieben, das Gedächtnis enthält die Lieferung nicht (derselbe Aufruf nach Reparatur der Liste wendet sie normal an), und es wird keine Benachrichtigung gesendet.
  Beweis: :77-78; Probe A (bekannte Lieferung bei unlesbarer Liste: LIST_UNREADABLE, claudeState unverändert, Rohdaten erhalten, genau eine Sicherung); Probe C (beide unlesbar: kein claudeStateBackup, Reihenfolge Festlegung 7) grün
- [x] **AC-7 (Unit): Unlesbarer `claudeState` wird gesichert.** Given gültige Listen und unlesbare Rohdaten unter `claudeState`, When `apply` einer gültigen Lieferung, Then liegen die Rohdaten unter `claudeStateBackup.<Sekunden>`, die Lieferung wird mit leerem Gedächtnis und ohne Übungen angewendet (Ergebnis `applied`), und `claudeState` ist danach lesbar und enthält die neue Lieferung.
  Beweis: :67-72; testAC7 grün
- [x] **AC-8 (Unit): Sicherung unlesbarer `atemPresets` beim Laden.** Given unlesbare Rohdaten unter `atemPresets`, When `AtemView.Preset.loadStored` (zweimal mit gleichen Rohdaten, einmal mit geänderten Rohdaten und gleicher Sekunde), Then ist das Ergebnis `nil`, der Lader der Tabs meldet `unlesbar` und liefert `MeditationTab.defaultPresets` (Tab zeigt Vorgaben), die Rohdaten liegen genau einmal unter `atemPresetsBackup.`, die geänderten Rohdaten unter einem zweiten Schlüssel mit Zähler (`-2`), nichts wird überschrieben.
  Beweis: ClaudeStore.swift:23-31 und WorkoutProgramsView backUpUnreadable mit Präfix; testAC8, Probe E und G grün
- [x] **AC-9 (Unit): Bestehende Sicherung der Programme bleibt gleich.** Given die Tests zu `workoutProgramSetsBackup.` in `WorkoutPhaseMigrationTests`, When die Funktion `backUpUnreadable` auf einen Präfix-Parameter umgestellt ist, Then laufen sie unverändert grün (gleiche Schlüsselnamen, gleiche Kollisionsregeln).
  Beweis: Diff WorkoutProgramsView.swift: nur Präfix-Parameter; Suite grün
- [x] **AC-10 (Unit): Benachrichtigung nach dem Schreiben, nur bei `applied`.** Given ein eigenes `NotificationCenter` mit Beobachter, der beim Eintreffen `claudeState` und die Listen aus den `UserDefaults` liest, When `apply` mit `applied`, Then wird genau eine Benachrichtigung `.claudeStoreDidChange` gesendet, und im Beobachter ist der neue Stand in allen drei Keys schon lesbar; bei `noEffect`, bei von `apply` Abgelehntem und bei `LIST_UNREADABLE` wird keine gesendet.
  Beweis: :91 post nach :90; testAC10 (beide) grün
- [x] **AC-11 (UI): Lieferung erscheint in sichtbarem Tab.** Given ein Start mit `enable-testing`, `uitest-claude-apply`, `UITEST_CLAUDE_DELIVERY` (Lieferung mit einem Programm; Aufbau nach den Beispielen unter `Contracts/deliveries/valid/`, mit einem eindeutigen Testnamen) und `UITEST_CLAUDE_DELAY` = 3, When der Workout-Tab schon sichtbar ist und die Verzögerung abgelaufen ist, Then erscheint das gelieferte Programm in der Liste, und mindestens ein Vorgabe-Programm (`defaultWorkoutSets`) ist weiterhin sichtbar. Dasselbe für eine gelieferte Atemübung im Meditation-Tab.
  Beweis: Entwicklerlauf (test-green-ui.txt) passed; .onReceive in WorkoutTab/MeditationTab; nicht selbst wiederholt
- [x] **AC-12 (UI): Lieferung erscheint nach Tabwechsel.** Given derselbe Aufbau wie AC-11, When die Lieferung eintrifft, während ein anderer Tab sichtbar ist, und danach zum Workout- bzw. Meditation-Tab gewechselt wird, Then ist der gelieferte Baustein dort sichtbar, und ein anschließendes Bearbeiten und Speichern eines **anderen** Eintrags in diesem Tab (z. B. Bestätigen des Editors für einen eigenen Eintrag) lässt den gelieferten Baustein in der Liste stehen (kein Überschreiben durch eine veraltete Kopie).
  Beweis: eigener Lauf passed; Tabs laden bei Benachrichtigung neu (WorkoutTab.swift Diff, MeditationTab.swift Diff)
- [x] **AC-13 (UI): Lieferung übersteht Neustart.** Given AC-11 erfüllt, When die App beendet und ohne `uitest-claude-apply` neu gestartet wird, Then sind das gelieferte Programm und die gelieferte Atemübung weiterhin in den Listen, und die Vorgaben stehen unverändert da.
  Beweis: Entwicklerlauf passed. Korrektur openTab(0) ist nötig und schwächt nicht ab: die Atem-Prüfung braucht den Meditation-Tab, die Liste wird weiter nach Neustart geprüft
- [x] **AC-14 (UI): Rücknahme per Paket räumt auf.** Given AC-13 erfüllt und die Lieferung trug eine `packageId`, When die App mit einer zweiten Lieferung (Rücknahme per dieser `packageId`, neue `deliveryId`) gestartet wird, Then sind die gelieferten Bausteine aus den Listen verschwunden, die Vorgaben und eigene Einträge bleiben; ein Neustart ohne Startargument zeigt dasselbe. Der Teardown der UI-Tests wendet diese Rücknahme an, damit der Simulator sauber bleibt.
  Beweis: Entwicklerlauf passed (nicht selbst wiederholt)
- [x] **AC-15 (UI): Testeinstieg bricht nichts.** Given `uitest-claude-apply` mit unlesbarem Inhalt in `UITEST_CLAUDE_DELIVERY`, When die App startet, Then erscheinen die Tabs wie ohne Lieferung, und die Listen zeigen die Vorgaben bzw. den bisherigen Stand. Der Code des Einstiegs steht vollständig in `#if DEBUG`; der Release-Build der App übersetzt ihn nicht.
  Beweis: Meditationstimer_iOSApp.swift: alles in #if DEBUG, ClaudeDelivery.read mit try? (kein Absturz), Verzögerung 0 im init; Release-Build erfolgreich; Wächtertest grün
- [x] **AC-16 (bestehende Tests): Altdaten erscheinen wie heute.** Given der umgebaute Lader in beiden Tabs, When die vollständige Unit-Suite `LeanHealthTimerTests` und `ClaudeFelderUITests/testProgrammeUndAtemuebungenUeberstehenNeustart` laufen, Then sind sie grün; gespeicherte Altlisten ohne Claude-Felder werden wie zuvor gelesen und nicht durch Vorgaben ersetzt.
  Beweis: Unit-Suite 324 grün; Probe F (Altpresets ohne Beschreibung werden ergänzt, Vorgaben angehängt, leeres Array ergibt Vorgaben wie früher); Altmigration inhaltsgleich zu `git show HEAD`-Code
- [x] **AC-17 (jede Runde): Reinheit, Build, Budget.** Given der Diff der Runde, Then ist `ClaudeApply.swift` unverändert und `testApplyDateiIstFoundationOnlyUndOhneSeiteneffekte` grün; `ClaudeStore.swift` importiert nur `Foundation`; iOS, Watch und Widget bauen; der Produktiv-Diff (App-Code ohne Tests, Löschzeilen mitgezählt) liegt bei höchstens 250 Zeilen, keine Funktion über 50 Zeilen; Protokoll `Executed N tests` mit N ≥ 1. Nachweis in der Adversary-Prüfung: Diff-Durchsicht, nur die fünf Dateien der Runde plus Specs und Tests.
  Beweis: ClaudeApply.swift nicht im Diff; ClaudeStore.swift importiert nur Foundation; numstat App-Code 151 Zeilen neu, 38 gelöscht = 189 (<= 250); längste Funktion apply etwa 19 Zeilen; Watch, Widget, Release bauen

## Dialog

Code reference: Meditationstimer iOS/Models/ClaudeStore.swift:75
Code reference: Meditationstimer iOS/Models/ClaudeStore.swift:51
Code reference: Meditationstimer iOS/Models/ClaudeStore.swift:91
Code reference: Meditationstimer iOS/Tabs/WorkoutTab.swift:365
Code reference: Meditationstimer iOS/Tabs/MeditationTab.swift:465
Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:333
Code reference: Meditationstimer iOS/Meditationstimer_iOSApp.swift:35


### Runde 1
**Adversary:** Alle 17 ACs gegen Spec geprüft, Unit-Suite (324 passed, 0 failed), AC-12-UI selbst gefahren, 7 Proben zu Festlegung 4/6/7/8. Befund F-1 (LOW): Tabs schreiben bei jedem Laden zurück, Byte-Vergleich unwirksam (JSONEncoder nicht deterministisch). F-2 (LOW): AC-12-Test belegt veraltete Kopie nur schwach.
**Implementierer:** F-1 behoben: semantischer Vergleich (gespeicherte Liste dekodiert != geladene Liste) in WorkoutTab.loadSets und MeditationTab.loadPresets. Unit-Suite 324 passed, 0 failed; UI AC-12 und ClaudeFelder-Wächter passed. F-2 bleibt als LOW-Hinweis (Code-Pfad .onReceive vom Adversary als korrekt bestätigt).

### Runde 2
**Adversary:** F-1 nachgeprüft mit 3 Proben: unveränderte Liste wird nicht mehr geschrieben (5 Ladevorgänge), echte Migration wird weiter gespeichert, exerciseId-Ableitung führt weder zu Dauer-Schreiben noch zu verpasstem Speichern. Unit-Suite 327 passed (inkl. 3 Proben), 0 failed. Keine neuen Befunde.
**Implementierer:** Keine weitere Änderung nötig.

## Herkunft der Vorbedingungen

<!-- vom Prüfer auszufüllen, siehe `precondition_origins.py` -->

## Prüfer-Protokoll (Original)


Grundlage: Spec feature-51-s2b-speichern.md, Elternspec. Kein Developer-Bericht gelesen.

## Läufe

- Unit-Suite LeanHealthTimerTests: 324 `Test case ... passed`, 0 failed, TEST SUCCEEDED (Ausgabe: /tmp/adversary_test_output.txt).
- Eigene Probe-Tests (temporäre Datei, danach entfernt): 7 Proben, 6 grün, 1 rot (F-1).
- UI: `ClaudeSpeichernUITests/testAC12_GeliefertesProgrammNachTabwechselUndSpeichernEinesAnderenEintrags` selbst gefahren: passed. Weitere UI-Tests nur aus dem Entwicklerlauf (test-green-ui.txt: 7 von 7) gesehen, nicht selbst wiederholt.
- Builds: Watch App, Widget Extension (Debug) und iOS App Release: BUILD SUCCEEDED.
- Screenshot /tmp/adversary_screenshot.png zeigt nur den Home-Bildschirm des Simulators (App nach dem Test beendet), kein Nachweis des Features.

#### Prüfer-Runde 1: Checkliste

| AC | Status | Beweis |
|---|---|---|
| AC-1 | BEWIESEN | ClaudeStore.swift:52,60 (fehlender Key liefert Vorgaben); testAC1 grün |
| AC-2 | BEWIESEN | testAC2 grün; Korrektur (Vergleich nach Encode/Decode) schwächt nicht ab: WorkoutSet-Decoder leitet exerciseId aus dem Namen ab (WorkoutProgramsView.swift:231-242), Namen/Emoji/Reihenfolge werden weiter einzeln geprüft |
| AC-3 | BEWIESEN | ClaudeStore.swift:86-90 Reihenfolge sets, presets, state; ClaudeStoredState nur exercises/log (:18-21); testAC3 grün |
| AC-4 | BEWIESEN | :84 wroteLists nur bei isNew und applied; Probe B (noEffect, Listen-Bytes gleich, Log geschrieben, keine Meldung) grün |
| AC-5 | BEWIESEN | :80,84; testAC5 grün |
| AC-6 | BEWIESEN | :77-78; Probe A (bekannte Lieferung bei unlesbarer Liste: LIST_UNREADABLE, claudeState unverändert, Rohdaten erhalten, genau eine Sicherung); Probe C (beide unlesbar: kein claudeStateBackup, Reihenfolge Festlegung 7) grün |
| AC-7 | BEWIESEN | :67-72; testAC7 grün |
| AC-8 | BEWIESEN | ClaudeStore.swift:23-31 und WorkoutProgramsView backUpUnreadable mit Präfix; testAC8, Probe E und G grün |
| AC-9 | BEWIESEN | Diff WorkoutProgramsView.swift: nur Präfix-Parameter; Suite grün |
| AC-10 | BEWIESEN | :91 post nach :90; testAC10 (beide) grün |
| AC-11 | BEWIESEN | Entwicklerlauf (test-green-ui.txt) passed; .onReceive in WorkoutTab/MeditationTab; nicht selbst wiederholt |
| AC-12 | BEWIESEN | eigener Lauf passed; Tabs laden bei Benachrichtigung neu (WorkoutTab.swift Diff, MeditationTab.swift Diff) |
| AC-13 | BEWIESEN | Entwicklerlauf passed. Korrektur openTab(0) ist nötig und schwächt nicht ab: die Atem-Prüfung braucht den Meditation-Tab, die Liste wird weiter nach Neustart geprüft |
| AC-14 | BEWIESEN | Entwicklerlauf passed (nicht selbst wiederholt) |
| AC-15 | BEWIESEN | Meditationstimer_iOSApp.swift: alles in #if DEBUG, ClaudeDelivery.read mit try? (kein Absturz), Verzögerung 0 im init; Release-Build erfolgreich; Wächtertest grün |
| AC-16 | BEWIESEN | Unit-Suite 324 grün; Probe F (Altpresets ohne Beschreibung werden ergänzt, Vorgaben angehängt, leeres Array ergibt Vorgaben wie früher); Altmigration inhaltsgleich zu `git show HEAD`-Code |
| AC-17 | BEWIESEN | ClaudeApply.swift nicht im Diff; ClaudeStore.swift importiert nur Foundation; numstat App-Code 151 Zeilen neu, 38 gelöscht = 189 (<= 250); längste Funktion apply etwa 19 Zeilen; Watch, Widget, Release bauen |

#### Prüfer-Runde 2: Nachprüfung offener Punkte

- Offen aus Runde 1: Tab speichert in loadSets/loadPresets, wenn `JSONEncoder`-Bytes vom gespeicherten Wert abweichen. Probe D zeigt: gleiche Größe, aber andere Bytes bei jedem Encode (Schlüsselreihenfolge nicht stabil). Folge: Siehe F-1.
- Offen: Schleife durch onReceive und Speichern? savePresets/saveSets senden keine Benachrichtigung, also keine Schleife. Ausgeräumt.
- Offen: AC-12 beweist "veraltete Kopie" nur, wenn der Workout-Tab beim Eintreffen schon instanziiert ist. Der Test lässt den Workout-Tab vorher nicht explizit sichtbar; AC-11 deckt onReceive im sichtbaren Tab ab. Kein Defekt, schwacher Beweis (F-2).

## Findings

```json
[
  {
    "id": "F-1",
    "severity": "LOW",
    "category": "regression",
    "description": "Beim Laden schreiben beide Tabs bei jedem onAppear und jedem onReceive die Liste zurück, obwohl nichts migriert wurde. Früher wurde nur gespeichert, wenn die Migration etwas änderte.",
    "evidence": "MeditationTab.swift loadPresets / WorkoutTab.swift loadSets vergleichen `JSONEncoder().encode(list)` mit den gespeicherten Bytes. Probe D: bei gleicher Liste sind die Bytes (4374 bzw. 1763) gleich lang, aber ungleich, daher true bei jedem Laden. Keine Datenverlust-Folge, keine Schleife, nur überflüssige Schreibvorgänge; sie machen den Byte-Vergleich unwirksam.",
    "remediation": "Statt Byte-Vergleich den dekodierten gespeicherten Wert mit der migrierten Liste vergleichen (Equatable) oder die Migration ein Änderungs-Flag zurückgeben lassen."
  },
  {
    "id": "F-2",
    "severity": "LOW",
    "category": "anti_pattern",
    "description": "AC-12 prüft nicht belegbar, dass eine bereits geladene veraltete Kopie nicht überschreibt; je nach Instanziierung des Tabs könnte der Test auch ohne onReceive grün sein.",
    "evidence": "ClaudeSpeichernUITests.swift:237-259 öffnet Tab 2, wartet, wechselt zu Tab 1; der Workout-Tab ist vor der Lieferung nicht ausdrücklich geladen. Der Code-Pfad (.onReceive laden, kein Speichern veralteter Daten) ist im Diff aber korrekt.",
    "remediation": "Vor dem Warten einmal Tab 1 öffnen, dann Tab 2, Lieferung abwarten, Tab 1, anderen Eintrag speichern."
  }
]
```

Keine CRITICAL/HIGH/MEDIUM-Findings. Festlegungen 4, 6, 7, 8, 9 durch Code und Proben bestätigt; keine verloren gegangene Migration gegenüber dem Altcode.



#### Prüfer-Runde 2 (F-1)

Änderung: WorkoutTab.loadSets / MeditationTab.loadPresets speichern nur noch, wenn `state == .stored` und die mit JSONDecoder dekodierten gespeicherten Daten != geladene (migrierte) Liste.

Beweis (temporäre Proben mit derselben Bedingung, danach gelöscht; Suite 327 passed = 324 + 3 Proben, 0 failed, TEST SUCCEEDED, /tmp/adversary_test_output.txt):
1. Unveränderte, bereits migrierte Liste (nach apply, 5 Ladevorgänge): kein Speichern, weder Programme noch Atemübungen. BEWIESEN.
2. Echte Migration wird weiter gespeichert: Atemübung ohne Beschreibung plus fehlende Vorgaben, nur fehlende Beschreibung, nur fehlende Vorgabe, fehlende Vorgabe-Programme (Liste wird ergänzt). BEWIESEN.
3. WorkoutPhase-exerciseId: Rohdaten ohne exerciseId bei allen Vorgaben ergeben kein Dauer-Schreiben (beide Seiten des Vergleichs gehen durch denselben Decoder); Altprogramm ohne exerciseId: einmal Speichern (Vorgaben fehlen), nach dem Speichern nicht mehr. Kein verpasstes Speichern gefunden. BEWIESEN.
4. Keine neue Regression: Unit-Suite grün. UI-Pfad (Tab-Wechsel/Neustart) nicht neu gefahren.

F-1: BEHOBEN. F-2 (LOW, schwacher AC-12-Beweis) unverändert.




## Verdict: VERIFIED

## Geprüfte Dateien

- sha256:558e67578907b71adbd9f93cda288b34c4df84ce17067143842f25dc0b59da74  Meditationstimer iOS/Meditationstimer_iOSApp.swift
- sha256:a1888de6bf8f88bf64415c3af9ff77ff0604d2d3f40bb50b6ee7e08c30868bee  Meditationstimer iOS/Models/ClaudeStore.swift
- sha256:813a5ab0c435187a742252a0bd13aae31558b643d0f4921fcd6e4b659de6703a  Meditationstimer iOS/Tabs/MeditationTab.swift
- sha256:59d8d190b070a6bbc43795155d9d9d3c4447c49d1c6eb19b17129c06904be2de  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- sha256:3a6cad71f49ac11eaf17938096cba7dad356f81bccc12c11ca6b3d739b3276b0  Meditationstimer iOS/Tabs/WorkoutTab.swift

## Prüfbasis

- base: 1616fae5d89464a0cb18e4f432cc28e9a9858714
- blob:a8fd2036741d76f65749a9bcf9d56b955ead9212  Meditationstimer iOS/Meditationstimer_iOSApp.swift
- blob:1137ae90f739f21f22e631a6d07952656a4d641a  Meditationstimer iOS/Models/ClaudeStore.swift
- blob:bf0dd043b537b9dad3c3c2c0bf1d5d854442008a  Meditationstimer iOS/Tabs/MeditationTab.swift
- blob:aa8df97cb62227777622aaa2fdde56d5325c73c8  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- blob:04c1343e11afba3bbe0f1c9220fdf0f71197060b  Meditationstimer iOS/Tabs/WorkoutTab.swift
