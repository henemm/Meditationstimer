---
entity_id: BUG-25d-hintergrund-workout
type: bugfix
created: 2026-09-22
updated: 2026-09-23
status: draft
workflow: bug-25d-hintergrund-meditation
---

# BUG-25d: Rote Hintergrund-Tests beim geführten Workout waren Testschuld, kein Produktfehler

> **⚠️ Stand 2026-09-23: Die Aufräumarbeit wurde zurückgenommen.**
> Das Entfernen des `scenePhase`-Guards erzeugte eine in 4 von 4 Durchgängen gemessene Regression
> (Beleg: `DOCS/artifacts/bug-25d-hintergrund-meditation/regressionspruefung-reiterwechsel.txt`).
> Der `onDisappear`-Pfad wird beim Hintergrund-Wechsel zwar nie durchlaufen, ist im **Vordergrund**
> aber die einzige Aufräumstelle — beim programmatischen Reiterwechsel per Kurzbefehl und beim
> abgebrochenen Startvorlauf. Ohne ihn blieben Bildschirmsperre deaktiviert und Live Activity
> offen, und es wurde kein Eintrag in die Gesundheits-App geschrieben. Der Product Owner hat die
> Rücknahme entschieden. **Ergebnis dieses Vorhabens ist damit ausschließlich die Testkorrektur;
> am Produktcode ändert sich nichts.** Die strukturelle Zerbrechlichkeit ist als Issue #36
> ausgelagert.


## Approval

- [ ] Approved

## Purpose

Zwei UI-Tests in `BackgroundMeditationUITests.swift` behaupten, ein geführtes Workout werde
beendet, sobald der Nutzer kurz zu einer anderen App wechselt. **Eine Messung in der laufenden App
widerlegt das:** Die Sitzung läuft unverändert weiter, `endSession` wird beim Hintergrund-Wechsel
nicht aufgerufen. Rot wurde der Test aus einem anderen Grund: Die Programmliste hinter der
Sitzungs-Karte wird nur weich ausgeblendet (Unschärfe + Antipp-Sperre), bleibt dabei aber im
Bedienhilfen-Baum bestehen — der Start-Knopf ist deshalb während der gesamten Sitzung technisch
vorhanden, unabhängig davon, ob sie läuft oder beendet ist. Der Test prüfte also etwas, das sich
nie ändert.

Dieser Fix korrigiert die beiden betroffenen Tests, sodass sie tatsächlich den Zustand der
Sitzung prüfen — **am Abbruch-Knopf und am Fortschrittszähler der Sitzungs-Karte** — statt sich auf
den irreführenden Start-Knopf zu verlassen. Test 1 belegt zusätzlich, dass die Sitzung nach dem
App-Wechsel nicht nur dasteht, sondern **weiterläuft**: Der Fortschrittszähler muss sich messbar
weiterbewegen.

**Am Produktcode ändert sich nichts.** Eine zwischenzeitlich vollzogene Aufräumarbeit — das
Entfernen einer Absicherung in der Sitzungs-Karte — wurde am 2026-09-23 zurückgenommen, weil sie
eine gemessene Regression erzeugte (siehe Warnkasten oben). Im Quellcode bleibt als einzige
Änderung ein **berichtigter Kommentar**, der die frühere, widerlegte Begründung durch den
gemessenen Befund ersetzt.

## Source

| Feld | Wert |
|------|------|
| Entity | `BUG-25d-hintergrund-workout` |
| Spec-Datei | `DOCS/specs/bugfix/BUG-25d-hintergrund-workout.md` |
| Kontext & Analyse | `DOCS/context/bug-25d-hintergrund-meditation.md` |
| Messbeleg (Sitzung überlebt) | `DOCS/artifacts/bug-25d-hintergrund-meditation/diagnose-endSession-aufrufe.txt` |
| Messbeleg (Zustandstabelle der Karte) | `DOCS/artifacts/bug-25d-hintergrund-meditation/baum-laufende-sitzung.txt` |
| Messbeleg (Regression nach Entfernen des Guards) | `DOCS/artifacts/bug-25d-hintergrund-meditation/regressionspruefung-reiterwechsel.txt` |
| Messbeleg (Gegenprobe nach der Rücknahme) | `DOCS/artifacts/bug-25d-hintergrund-meditation/gegenprobe-ruecknahme-guard.txt` |
| Prüfprotokoll | `DOCS/artifacts/bug-25d-hintergrund-meditation/adversary-dialog.md` |
| Workflow | `bug-25d-hintergrund-meditation` |
| Ursprung | Issue #25, Cluster D (Bestandsaufnahme rote UI-Tests) |
| Tatsächliche Ursache des roten Tests | `Meditationstimer iOS/Tabs/WorkoutTab.swift`, `struct OverlayBackgroundEffect` (Zeilen 800-810), angewandt in Zeile 201 |
| Betroffene Tests | `LeanHealthTimerUITests/BackgroundMeditationUITests.swift`: `test_backgroundForeground_sessionStillRunning`, `test_explicitStop_endsSession` |
| Widerlegte Ursachenannahme | `struct WorkoutProgramSessionCard` — der vermutete Fehler existiert nicht; der zugehörige Guard **bleibt im Code**, siehe unten |

## Root Cause (gemessen)

Eine gezielte Messung in der laufenden App widerlegt die ursprüngliche Ursachen-Annahme aus
Phase 2 dieses Workflows (siehe „Widerlegte Ursachenannahme" unten). Eine temporäre Protokollierung
an allen Stellen, die eine Sitzung beenden könnten (`endSession`, `close()`, `runningSet`-Zugriffe,
`card.onAppear`/`onDisappear`, Szenenphasen-Wechsel) zeigt über drei Durchgänge identisch:

```
[BUG25D] card.task gestartet (sessionEnded=false)
[BUG25D] card.onAppear
[BUG25D] scene: willResignActive
[BUG25D] scene: didEnterBackground
[BUG25D] scene: willEnterForeground
[BUG25D] scene: didBecomeActive
```

Danach passiert nichts mehr — kein `endSession`-Eintrag, kein `close()`, kein
`card.onDisappear`. Die Sitzungs-Karte überlebt den Hintergrund-Wechsel unversehrt, die Sitzung
läuft weiter. Beleg: `DOCS/artifacts/bug-25d-hintergrund-meditation/diagnose-endSession-aufrufe.txt`
(3 Durchgänge, alle identisch). Die temporäre Protokollierung ist restlos entfernt.

**Der tatsächliche Grund für den roten Test:** Die Sitzungs-Karte (`WorkoutProgramSessionCard`)
liegt als Überlagerung über der Programmliste. Der Überlagerungs-Effekt `OverlayBackgroundEffect`
blendet die Liste darunter nur per `.blur(radius: 6)` weich aus und sperrt sie über
`.allowsHitTesting(false)` gegen Antippen — beides entfernt sie **nicht** aus dem
Bedienhilfen-Baum, den XCUITest abfragt. `app.buttons["Start"]` existiert deshalb während der
**gesamten** Sitzung: vor Sitzungsbeginn, während sie läuft, und danach — der Hintergrund-Wechsel
ändert daran nichts. Der Test prüfte `XCTAssertFalse(startButtonAfterReturn.exists)` und schloss
daraus fälschlich auf ein Sitzungsende. Diese Prüfung konnte unabhängig vom tatsächlichen
Sitzungszustand nie bestehen.

**Zusatzbefund (2026-09-23 durch die unabhängige Prüfung berichtigt):** Der Workout-Tab, den Nutzer
tatsächlich sehen, ist `WorkoutTab.swift` mit einer eigenen Liste und einem eigenen `runningSet`
(Zeile 38). Der produktiv wirksame Überlagerungs-Effekt ist die **eigene, gleich aufgebaute Kopie**
in `WorkoutTab.swift` (Zeilen 800-810, angewandt in Zeile 201); der gleichnamige Typ in
`WorkoutProgramsView.swift` ist `private` und läuft im Produkt nie — ebenso wenig wie die dortige
Liste. Aus `WorkoutProgramsView.swift` werden produktiv die Sitzungs-Karte
(`WorkoutProgramSessionCard`) sowie `WorkoutSetRow`, `AddSetCard`, `SetEditorView` und
`PresetInfoSheet` wiederverwendet (`WorkoutTab.swift:92, 102, 143, 163`). Der „Start"-Knopf stammt
aus `WorkoutSetRow`. Da beide Überlagerungs-Effekte identisch aufgebaut sind, bleibt die
Schlussfolgerung über den Bedienhilfen-Baum unverändert gültig; berichtigt ist nur die
Quellenangabe.

### Widerlegte Ursachenannahme (zur Nachvollziehbarkeit erhalten, NICHT die tatsächliche Ursache)

> **Status: WIDERLEGT durch Messung am 2026-09-22.** Der folgende Abschnitt beschreibt die
> ursprüngliche Analyse aus Phase 2 dieses Workflows. Er wird nicht gelöscht, sondern bewusst als
> Irrweg stehen gelassen, damit spätere Leser nachvollziehen können, wie plausibel die Annahme
> wirkte und woran sie tatsächlich scheiterte.

Die ursprüngliche Analyse ging davon aus, `WorkoutProgramSessionCard` koppele die Sitzungsdauer
fälschlich an den View-Lebenszyklus: Ein `@State isInBackground`, gesetzt über
`.onChange(of: scenePhase)`, sollte in `.onDisappear` verhindern, dass die Sitzung beim
Hintergrund-Wechsel beendet wird. Der Kommentar im Code ging davon aus, dass
`onChange(of: scenePhase)` immer vor `onDisappear` feuert — eine Reihenfolge, die Apple nirgends
zusichert. Die Annahme lautete: Unter Xcode 27.0 / iOS 26.5 feuere `onDisappear` deterministisch
vor dem scenePhase-Update, der Guard greife dadurch nie, `endSession(manual: true)` laufe durch und
beende die Sitzung vorzeitig.

**Warum die Annahme plausibel wirkte:**

- Der Code enthielt einen verdächtigen Kommentar, der eine nicht zugesicherte
  Callback-Reihenfolge als gegeben voraussetzte — ein klassisches Zeichen für eine Wette auf
  undokumentiertes Verhalten.
- Es gab eine passende Vorgeschichte: Bug #7 (2026-04-22) hatte genau diesen Guard eingeführt, mit
  Adversary-Urteil `AMBIGUOUS` — der Zweifel war also bereits protokolliert, bevor der Test je
  scharf gestellt wurde.
- Der Test war deterministisch rot (3 von 3 Durchgängen, identische Fehlermeldung „Session wurde
  beim Hintergrund-Wechsel beendet"), was eher für eine echte, reproduzierbare Produktregression
  sprach als für einen Test-Defekt.
- Zwei andere Ansichten (`AtemView`, `WorkoutsView`) trugen denselben Kommentar über eine bereits
  entfernte „scenePhase-Automatik, die zu unerwünschten Beendigungen führte" — ein scheinbar
  bestätigendes Muster im eigenen Code.

**Was die Annahme übersah:** Ein deterministisch roter Test entsteht genauso zuverlässig durch
einen deterministisch fehlerhaften Test wie durch einen deterministisch fehlerhaften Produktcode.
Die naheliegende Erklärung — der Code passt exakt zum Symptom — wurde nie gegen eine direkte
Messung der tatsächlichen Methodenaufrufe geprüft, bevor der Fix geschrieben wurde. Genau diese
Messung (siehe oben) hat den Irrtum aufgedeckt.

**Nachtrag 2026-09-23:** Aus der Widerlegung wurde zunächst geschlossen, der Guard sei nutzlos und
könne entfallen. Auch dieser Schluss war falsch — er betrachtete nur den Hintergrund-Fall. Im
Vordergrund ist derselbe Pfad die einzige Aufräumstelle. Die Entfernung wurde deshalb
zurückgenommen; der Guard ist im Code vorhanden und bleibt es.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | MODIFY (nur Kommentar) | Der `scenePhase`-Guard in `WorkoutProgramSessionCard` ist **vorhanden und bleibt es** (`:682`, `:807-808`, `:824-826`). Die Entfernung wurde am 2026-09-23 zurückgenommen. Geändert ist ausschließlich der Kommentar: Die widerlegte Begründung über die Callback-Reihenfolge ist durch den gemessenen Befund ersetzt. |
| SwiftUI `scenePhase` / `onDisappear` (`WorkoutProgramSessionCard`) | System-Lebenszyklus | Gegenstand der widerlegten Ursachenannahme. Beim Hintergrund-Wechsel feuert `onDisappear` nicht; im Vordergrund (Reiterwechsel per Kurzbefehl, abgebrochener Startvorlauf) ist der Pfad die einzige Aufräumstelle und wird gebraucht — gemessen, siehe `gegenprobe-ruecknahme-guard.txt`. |
| HealthKit | System-Framework | Ziel der Dauer-Prüfung in AC-3 (voller Eintrag bei regulärem Abschluss) — für diesen Pfad besteht **kein** automatisierter Nachweis, ausgelagert als Issue #35. |
| `Meditationstimer iOS/Tabs/WorkoutTab.swift` | Projekt-Kontext | Tatsächlich genutzter Workout-Tab mit eigenem `runningSet` (Zeile 38) und eigener Kopie des Überlagerungs-Effekts (Zeilen 800-810, angewandt in Zeile 201); erklärt, warum der Start-Knopf während der gesamten Sitzung im Bedienhilfen-Baum steht. |
| `Meditationstimer iOS/Tabs/WorkoutsView.swift`, `AtemView.swift` | Projekt-Präzedenzfall | Dort ist dasselbe Guard-Muster ersatzlos entfernt. Das galt als Vorbild für das Aufräumen in `WorkoutProgramsView` — dieses Aufräumen wurde nach der gemessenen Regression zurückgenommen. Ob die beiden anderen Ansichten dieselbe Lücke tragen, ist hier nicht geprüft (Issue #36). |
| `LeanHealthTimerUITests/BackgroundMeditationUITests.swift` | Testdatei | Trägt die Korrektur der beiden Tests inklusive der Lebendigkeitsprüfung. |
| `LeanHealthTimerTests/SessionDurationTests.swift` | Testdatei (NEU) | Ersatz für den gelöschten langen UI-Test; prüft die Zeitquelle der *freien* Sitzungen. Belegt AC-3 ausdrücklich **nicht** (Begründung im Test Plan). |

## Scope

### Affected Files

| Datei | Change Type | Beschreibung |
|-------|-------------|--------------|
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | MODIFY (nur Kommentar) | Kein Codezeichen geändert. Der `scenePhase`-Guard (`@State isInBackground`, `.onChange(of: scenePhase)`, `.onDisappear`-Block mit `endSession(manual: true)`) ist unverändert vorhanden; die zwischenzeitliche Entfernung wurde zurückgenommen. Ersetzt wurden zwei Kommentarzeilen durch elf: statt der widerlegten Annahme über die Callback-Reihenfolge steht dort jetzt der gemessene Befund — Hintergrund-Wechsel löst `onDisappear` nicht aus, im Vordergrund ist der Block die einzige Aufräumstelle. |
| `LeanHealthTimerUITests/BackgroundMeditationUITests.swift` | MODIFY | Testkorrektur: `test_backgroundForeground_sessionStillRunning` und `test_explicitStop_endsSession` prüfen den Zustand der Sitzungs-Karte über **Abbruch-Knopf (`xmark`) und Fortschrittszähler** statt über `app.buttons["Start"]`. Test 1 erhält zusätzlich eine Lebendigkeitsprüfung. Der lange UI-Test `test_backgroundDuringSession_thenNaturalCompletion_writesFullDurationEntry` entfällt samt seiner Hilfsmethoden. Die Begründungen stehen als „BITTE NICHT ZURÜCKREPARIEREN"-Blöcke in der Datei. |
| `LeanHealthTimerTests/SessionDurationTests.swift` | CREATE | Neuer Unit-Test (drei Prüfungen) als Ersatz für den gelöschten langen UI-Test. Prüft die Zeitquelle der freien Sitzungen (`TwoPhaseTimerEngine`) ohne HealthKit und ohne Systemberechtigung. Belegt AC-3 **nicht** — siehe Test Plan. |
| `openspec/specs/bug-7-background-meditation.md` | MODIFY (bereits erfolgt) | Die dortige Falschbehauptung („`onDisappear` feuert deterministisch vor dem scenePhase-Update") ist ausdrücklich zurückgezogen. Issue #13 bleibt **offen**, weil der Guard weiterhin existiert; die frühere Einstufung „gegenstandslos" ist als hinfällig vermerkt. |

### Estimated Changes

- Dateien: 4 (eine Quelldatei — nur Kommentar, eine UI-Testdatei, eine neue Unit-Testdatei, eine
  bestehende Spec).
- LoC Produktänderung (`WorkoutProgramsView.swift`): ca. +11/−2, ausschließlich Kommentar. Kein
  Codezeichen verändert (zeilengenau nachgewiesen durch die unabhängige Prüfung, Runde 2,
  Befund 1).
- LoC Testkorrektur (`BackgroundMeditationUITests.swift`): ca. +200/−60 — Umstellung beider Tests
  auf `xmark` + Fortschrittszähler, Lebendigkeitsprüfung, Löschung des langen Tests samt
  Hilfsmethoden, ausführliche Begründungsblöcke gegen ein Zurückreparieren.
- LoC neue Unit-Testdatei (`SessionDurationTests.swift`): drei Prüfungen.
- Risiko: NIEDRIG. Es wird kein Produktverhalten geändert — der Quellcode trägt ausschließlich
  einen berichtigten Kommentar.

## Implementation Details

**Produktcode: unverändert.** `WorkoutProgramSessionCard` enthält weiterhin `@State isInBackground`
(`:682`), `.onChange(of: scenePhase)` (`:807-808`) und den `.onDisappear`-Block mit
`guard !isInBackground` + `endSession(manual: true)` (`:824-826`). Die Wege, eine Sitzung zu
beenden, bleiben damit wie bisher: der Abbruch-Knopf (`xmark`), der natürliche Abschluss über
`onSessionEnd` und — im Vordergrund — das Aufräumen über `onDisappear`. Am Quellcode ändert dieses
Vorhaben nur den Kommentar an dieser Stelle.

Die eigentliche Arbeit betrifft die Testdateien:

- `test_backgroundForeground_sessionStillRunning` prüft in drei Stufen:
  1. Direkt nach der Rückkehr aus dem Hintergrund steht die Sitzungs-Karte — erkannt an
     `app.buttons["xmark"]` **und** am Fortschrittszähler („Übung n / m", „Runde n / m").
  2. Fünf Sekunden später steht sie immer noch; das fängt ein verzögertes Abräumen ab.
  3. **Lebendigkeitsprüfung:** Der Zählerstand direkt nach der Rückkehr dient als Grundlinie; der
     Test wartet, bis er sich ändert (Schranke 60 s). Damit ist nicht nur belegt, dass die Karte
     dasteht, sondern dass die Sitzung **weiterläuft** statt eingefroren zu sein.
  Die bisherige Prüfung `XCTAssertFalse(app.buttons["Start"].exists)` entfällt ersatzlos.
- `test_explicitStop_endsSession` greift den Abbruch-Knopf gezielt über seine stabile Kennung
  `xmark` zu — nicht über die lokalisierte Beschriftung („Schließen") und nicht über die Position
  im Baum. Fehlt der Knopf, ist das ein **Vorbedingungs-Fehlschlag**; der frühere Rateblock samt
  Ersatztippen („nimm halt den letzten Knopf") ist entfernt. Nach dem Antippen wird gefordert, dass
  **weder `xmark` noch ein Fortschrittszähler** übrig bleibt — die Karte muss vollständig
  abgeräumt sein, es darf kein Abschluss-Bildschirm stehen bleiben.
- `test_backgroundDuringSession_thenNaturalCompletion_writesFullDurationEntry` wird **gelöscht**,
  samt der nur von ihm genutzten Hilfsmethoden — sein Nachweis ist im Simulator nicht führbar
  (siehe Test Plan). An seine Stelle tritt `LeanHealthTimerTests/SessionDurationTests.swift`, der
  jedoch einen anderen Pfad absichert und AC-3 ausdrücklich nicht belegt.

### Geprüfte Alternativen

| # | Ansatz | Bewertung |
|---|--------|-----------|
| **A (gewählt, Stand 2026-09-23)** | `scenePhase`-Guard in `WorkoutProgramSessionCard` unangetastet lassen, nur die Tests korrigieren und den irreführenden Kommentar berichtigen | **Gewählt.** Der Guard greift beim Hintergrund-Wechsel zwar nie, ist im Vordergrund aber die einzige Aufräumstelle — gemessen in `gegenprobe-ruecknahme-guard.txt` (Reiterwechsel per Kurzbefehl, abgebrochener Startvorlauf). Kein Produktverhalten wird verändert. |
| B | Guard als tote Absicherung entfernen und zusätzlich die Tests korrigieren | **Ursprünglich gewählt, am 2026-09-23 zurückgenommen.** Die Entfernung erzeugte in 4 von 4 Durchgängen eine Regression: Bildschirmsperre blieb deaktiviert, Live Activity blieb offen, kein Eintrag in die Gesundheits-App (`regressionspruefung-reiterwechsel.txt`). Die strukturelle Zerbrechlichkeit des Pfades bleibt als Issue #36 offen. |
| C | Bedienhilfen-Baum reparieren: Liste bei laufender Sitzung vollständig aus dem Baum entfernen (z. B. `.accessibilityHidden(true)` statt nur `.blur` + `.allowsHitTesting`) | **Zurückgestellt.** Würde `app.buttons["Start"]` wieder brauchbar als Kriterium machen, ist aber eine Produktänderung außerhalb des Scopes dieses Testschuld-Fixes und behebt keinen bekannten Nutzer-Fehler. Kandidat für ein eigenes, kleines Aufräum-Ticket, falls künftig weitere Tests denselben Fallstrick treffen. |

## Test Plan

### Automated Tests (Korrektur bestehender Tests)

- [ ] Test 1 (korrigiert): GIVEN ein geführtes Workout wurde gestartet und die Sitzungs-Karte ist
      sichtbar (Abbruch-Knopf `xmark` **und** Fortschrittszähler vorhanden) WHEN der Nutzer den
      Home-Knopf drückt und die App danach wieder aktiviert THEN sind Abbruch-Knopf und
      Fortschrittszähler weiterhin vorhanden — direkt nach der Rückkehr und fünf Sekunden später —
      AND der Fortschrittszähler wandert innerhalb von 60 s von seinem Grundwert weiter, die
      Sitzung läuft also nachweislich weiter
      (`BackgroundMeditationUITests.test_backgroundForeground_sessionStillRunning`). Die bisherige
      Prüfung `XCTAssertFalse(app.buttons["Start"].exists)` entfällt ersatzlos.
- [ ] Test 2 (korrigiert): GIVEN ein geführtes Workout läuft WHEN der Nutzer den Abbruch-Knopf
      antippt, gezielt angesprochen über seine stabile Kennung `xmark` THEN sind weder der
      Abbruch-Knopf noch ein Fortschrittszähler noch vorhanden — die Sitzungs-Karte ist vollständig
      abgeräumt, es bleibt kein Abschluss-Bildschirm stehen
      (`BackgroundMeditationUITests.test_explicitStop_endsSession`). Ist `xmark` nicht bedienbar,
      gilt das als Vorbedingungs-Fehlschlag, nicht als bestandener Test. Die bisherige Prüfung
      `XCTAssertTrue(app.buttons["Start"].waitForExistence(...))` entfällt, weil sie nichts
      beweist — der Start-Knopf existierte technisch schon vor dem Tap.

### Warum das Prüfkriterium `xmark` + Fortschrittszähler heißt

**`app.buttons["Start"]` ist untauglich.** Der Überlagerungs-Effekt blendet die Programmliste hinter
der Sitzungs-Karte nur per `.blur(radius: 6)` weich aus und sperrt sie über
`.allowsHitTesting(false)` gegen Antippen. Beides entfernt den Start-Knopf **nicht** aus dem
Bedienhilfen-Baum. `app.buttons["Start"].exists` ist deshalb während der gesamten Sitzung wahr —
vor Sitzungsbeginn, während sie läuft, und danach. Eine Prüfung, die auf diesem Zustand aufbaut
(gleich ob als „darf nicht existieren" oder „muss existieren"), unterscheidet nicht zwischen
laufender und beendeter Sitzung und ist als Kriterium wertlos. Beleg: `baum-laufende-sitzung.txt`
— im Abzug der laufenden Sitzung stehen vier Knöpfe `play.fill` / „Start" gleichzeitig mit dem
Abbruch-Knopf `xmark` im selben Baum.

**Der Pause-Knopf ist ebenfalls untauglich.** Er wechselt beim Pausieren seine Beschriftung auf
„Weiter" und fehlt im Abschluss-Zustand ganz — er verschwindet also auch dann, wenn die Sitzung
sehr wohl besteht. Gemessen, nicht vermutet (`baum-laufende-sitzung.txt`):

| Zustand | `xmark` | „Pause" | „Weiter" | Fortschrittszähler |
|---|---|---|---|---|
| keine Sitzung | – | – | – | – |
| laufend | ✓ | ✓ | – | ✓ |
| pausiert | ✓ | – | ✓ | ✓ |
| nach Abbruch | – | – | – | – |

> **Der Satz „die Sitzungs-Karte (Pause-Knopf) existiert ausschließlich, während die Sitzung läuft"
> stand bis zum 2026-09-23 in dieser Spec und ist durch die Tabelle oben widerlegt.** Er ist
> ersatzlos gestrichen. Die Testdatei verbietet die Verwendung des Pause-Knopfs als Kriterium
> ausdrücklich mit einem „BITTE NICHT ZURÜCKREPARIEREN"-Block
> (`BackgroundMeditationUITests.swift`, bei beiden Tests). Diese Spec darf dem nicht widersprechen:
> **Wer den Pause-Knopf wieder als Kriterium einbaut, baut einen bereits widerlegten Fehler zurück.**

**Warum die Kombination trägt:** `xmark` ist ein zustandsunabhängiges Merkmal der Sitzungs-Karte —
er existiert laufend wie pausiert und fehlt, solange keine Sitzung läuft. Allein wäre er dennoch
unscharf, weil auch die Abschluss-Karte ihn trägt. Der Fortschrittszähler fängt genau das ab: Er
steht in `ProgressRingsView`, und `ProgressRingsView` wird ausschließlich im `!finished`-Zweig der
Karte gebaut. **Zähler vorhanden ⟺ Karte da UND noch nicht abgeschlossen** — das ist am Code
geschlossen, nicht bloß gemessen. Die unabhängige Prüfung hat zusätzlich bestätigt, dass die Suche
nach dem Zähler nichts außerhalb der Karte trifft (im vollen Baumabzug exakt zwei Treffer, nach dem
Antippen von `xmark` keiner).

**Abhängigkeit der Lebendigkeitsprüfung (bekannt und hingenommen):** Sie hängt am Zuschnitt des
Testprogramms „Tabata Classic" (8 Phasen, 230 s, Phasendauer ≈ 28,75 s; Schranke 60 s ≈ zwei
Phasenlängen Reserve). Der konstante „Runde 1 / 1" trägt nichts bei — die Lebendigkeit ruht auf
„Übung n / m". Wird die erste Programmkarte je durch ein sehr kurzes Programm ersetzt, kann der
Test ohne Produktfehler rot werden.

### Der lange UI-Test wurde gelöscht — Ersatz durch einen Unit-Test

`test_backgroundDuringSession_thenNaturalCompletion_writesFullDurationEntry` wurde in einer
früheren Runde dieses Workflows ergänzt und am 2026-09-23 **ersatzlos entfernt**.

**Grund:** Er sollte die geschriebene Dauer über die Erfolge-Ansicht belegen. Das ist im Simulator
nicht führbar. Gemessen (`DOCS/artifacts/bug-25d-hintergrund-meditation/`):

| Befund | Beleg |
|---|---|
| Kein HealthKit-Eintrag entsteht | `healthdb_secure.sqlite`: 0 Workouts, 0 Objekte, 0 Samples — obwohl ein Durchgang den natürlichen Abschluss nachweislich erreichte (339 s Laufzeit) |
| Kein Berechtigungsblatt erscheint | kein Treffer auf „Health Access"/„Erlauben"/„Allow" in beiden vollständigen Bedienhilfen-Mitschnitten |
| Die Berechtigung ist nicht vorab setzbar | `xcrun simctl privacy` kennt `calendar, contacts, location, photos, media-library, microphone, motion, reminders, siri` — **kein `health`** |

Damit sind „Eintrag geschrieben, Kalender nicht aktualisiert" und „2-Minuten-Anzeigeschwelle
filtert" als Ursachen ausgeschlossen: Die Kette reißt vor der Oberfläche. Der Test konnte in dieser
Umgebung nie grün werden, kostete aber rund 17 Minuten je Suite-Durchlauf (drei Wiederholungen à
5,5 Minuten) — auf einer Maschine, auf der lange Läufe regelmäßig wegen Speichermangels abgebrochen
wurden.

**Ersatz:** `LeanHealthTimerTests/SessionDurationTests.swift` prüft die Zeitquelle direkt, ohne
Systemberechtigung, in Sekunden statt Minuten:

- Volle Dauer: 3 + 4 Minuten ergeben einen Zeitraum von 420 s.
- Das Ende steht beim Start fest und verrutscht auch nach realer Laufzeit nicht.
- Gegenfall: Ein vorzeitiger Abbruch ergibt einen entsprechend kürzeren Zeitraum.

Alle drei grün. Kein HealthKit, kein Testdoppel, keine Produktivcode-Änderung.

**⚠️ Der Ersatz belegt AC-3 NICHT — auch nicht mittelbar.** Die unabhängige Prüfung vom
2026-09-23 hat das nachgewiesen, und die frühere Formulierung „mittelbar belegt" war falsch:

`SessionDurationTests` prüft `TwoPhaseTimerEngine`. Dort steht der Endzeitpunkt **beim Start fest**.
Das geführte Workout-Programm macht das Gegenteil: `WorkoutProgramsView.swift:983` setzt
`let endDate = Date()` erst **beim Beenden**. Das sind zwei verschiedene Entwürfe, keine gemeinsame
Zeitquelle — ein Test des einen sagt nichts über den anderen.

Hinzu kommt: Der Gegenfall-Test („vorzeitiger Abbruch ergibt kürzere Dauer") ist gegenstandslos.
Die geprüfte Dauer entsteht aus zwei `Date`-Werten, die der Test selbst erzeugt; entfernt man den
Abbruch, bleibt er grün.

**Was `SessionDurationTests` tatsächlich wert ist:** Er sichert für die *freien* Sitzungen
(Meditation, freies Workout) ab, dass die Dauer aus festen Zeitpunkten stammt und vergangene Zeit
voll zählt — eine spätere Umstellung auf einen mitlaufenden Countdown würde ihn kippen. Das ist
echter Regressionsschutz, nur eben für einen anderen Pfad als den, um den es in AC-3 geht.

**Der fehlende Nachweis ist als Issue #35 ausgelagert.** Er verlangt eine Produktivcode-Änderung:
die Sitzungslogik aus der Bildschirmansicht herauslösen oder `HealthKitManager` eine einspeisbare
Schreib-Schnittstelle geben. Beides sprengt den Umfang dieses Vorhabens.

**Nicht automatisiert prüfbar:** Dass die Live Activity beim Hintergrund-Wechsel tatsächlich
*sichtbar* bestehen bleibt (Sperrbildschirm/Dynamic Island), lässt sich mit XCUITest nicht direkt
prüfen — Live Activities laufen außerhalb des App-eigenen Bedienelemente-Baums, den XCUITest
ansprechen kann.

### Messstand (2026-09-23, unabhängig nachgemessen)

| Lauf | Ergebnis |
|---|---|
| `test_backgroundForeground_sessionStillRunning` | grün, 75,9 s |
| `test_explicitStop_endsSession` | grün, 25,5 s |
| Unit-Suite `LeanHealthTimerTests` | 214 Prüfungen, 0 Fehler |

## Acceptance Criteria

- **AC-1:** Läuft ein geführtes Workout und der Nutzer drückt den Home-Knopf, ist die
  Sitzungs-Karte nach der Rückkehr in die App weiterhin da — erkennbar am Abbruch-Knopf und am
  Fortschrittszähler — **und die Sitzung läuft weiter**: Der Fortschrittszähler wandert messbar
  weiter. Die Sitzung hat den App-Wechsel also nicht nur als Standbild überstanden.
- **AC-2:** Der Abbruch-Knopf beendet eine laufende Sitzung weiterhin zuverlässig — nach dem
  Antippen sind weder Abbruch-Knopf noch Fortschrittszähler vorhanden, die Sitzungs-Karte ist
  vollständig abgeräumt und es bleibt kein Abschluss-Bildschirm stehen.
- **AC-3:** *(nicht belegt — als offener Punkt ausgewiesen, siehe unten)* Ein geführtes Workout,
  das regulär bis zum Ende läuft, schreibt einen Eintrag mit der vollständigen Dauer. Für diese
  Aussage existiert **kein** automatisierter Nachweis. Der ursprünglich dafür vorgesehene UI-Test
  ist im Simulator nicht führbar, und der Unit-Test `SessionDurationTests` prüft einen **anderen**
  Entwurf als den, der im geführten Workout läuft (Details im Test Plan). Der Nachweis ist als
  **Issue #35** ausgelagert.
- **AC-4:** `test_backgroundForeground_sessionStillRunning` und `test_explicitStop_endsSession`
  prüfen den tatsächlichen Zustand der Sitzungs-Karte über Abbruch-Knopf und Fortschrittszähler —
  weder über den irreführenden Start-Knopf noch über den zustandsabhängigen Pause-Knopf — und beide
  laufen grün.
- **AC-5:** Das Produktverhalten bleibt unverändert: Der `scenePhase`-Guard in der Sitzungs-Karte
  ist vorhanden, am Quellcode ist ausschließlich ein Kommentar berichtigt.

## Definition of Done

- [ ] `test_backgroundForeground_sessionStillRunning` prüft die Sitzungs-Karte über Abbruch-Knopf
      (`xmark`) und Fortschrittszähler statt über `app.buttons["Start"]` und läuft grün.
- [ ] Die Lebendigkeitsprüfung in Test 1 ist vorhanden: Nach der Rückkehr aus dem Hintergrund wird
      der Zählerstand als Grundlinie genommen und muss sich innerhalb von 60 s ändern. Ein
      Stillstand färbt den Test rot.
- [ ] `test_explicitStop_endsSession` spricht den Abbruch-Knopf gezielt über die Kennung `xmark` an
      (kein Durchsuchen nach Beschriftungen, kein Ersatztippen nach Position) und prüft, dass danach
      weder `xmark` noch ein Fortschrittszähler übrig bleibt. Der Test läuft grün.
- [ ] In keinem der beiden Tests dient der Pause-Knopf als Kriterium; die
      „BITTE NICHT ZURÜCKREPARIEREN"-Blöcke stehen bei beiden Tests in der Datei.
- [ ] `test_backgroundDuringSession_thenNaturalCompletion_writesFullDurationEntry` ist entfernt,
      samt der nur von ihm genutzten Hilfsmethoden.
- [ ] `LeanHealthTimerTests/SessionDurationTests.swift` existiert und läuft grün; die vollständige
      Unit-Suite bleibt fehlerfrei.
- [ ] `WorkoutProgramSessionCard` enthält unverändert `@State isInBackground`,
      `.onChange(of: scenePhase)` und den `.onDisappear`-Block mit `endSession(manual: true)`; die
      zwischenzeitliche Entfernung ist zurückgenommen. Am Quellcode ist ausschließlich der Kommentar
      geändert — `git diff` gegen den Ausgangsstand zeigt für diese Datei keine Codezeile.
- [ ] Keine Reste der temporären Protokollierung: `grep -rn "BUG25D"` trifft keine `.swift`-Datei.
- [ ] `openspec/specs/bug-7-background-meditation.md` ist berichtigt: Die Behauptung
      „`onDisappear` feuert deterministisch vor dem scenePhase-Update" ist zurückgezogen, Issue #13
      ist als weiterhin offen vermerkt (der Guard existiert).
- [ ] AC-1, AC-2, AC-4 und AC-5 sind erfüllt. AC-3 ist ausdrücklich als **nicht belegt** ausgewiesen
      und als Issue #35 ausgelagert — es wird nicht abgehakt.
- [ ] `git diff --name-only` gegen den Ausgangsstand nennt neben den Dokumenten dieses Workflows
      (`DOCS/**`, `openspec/**`) ausschließlich die drei unter „Affected Files" gelisteten
      Code-/Testpfade — keinen weiteren.
- [ ] Die App übersetzt ohne Fehler (`xcodebuild` für Schema „Lean Health Timer").

## Abgrenzung — was dieser Fix NICHT behandelt

- **Testbarkeit des geführten Workout-Pfades** — dass dessen geschriebene Dauer direkt geprüft
  werden kann, verlangt einen Umbau: Sitzungslogik aus der Bildschirmansicht herauslösen oder
  `HealthKitManager` eine einspeisbare Schreib-Schnittstelle geben. Eigenes Ticket (#35); hier
  bewusst nicht angefasst, weil es den Umfang (4-5 Dateien / ±250 LoC) sprengt.
- **Warum im Simulator kein HealthKit-Eintrag entsteht** — gemessen, aber nicht erklärt. Ob die
  Schreibfreigabe fehlt, verweigert ist oder der Schreibpfad aus anderem Grund nicht greift, ist
  offen. Eigenes Ticket.
- **Strukturelle Zerbrechlichkeit des Aufräum-Pfades** — dass das Aufräumen einer laufenden Sitzung
  allein an `onDisappear` hängt, bleibt unbefriedigend. Die Rücknahme stellt nur den vorherigen
  Stand wieder her. Eigenes Ticket (#36).
- **#15 „Meditation stirbt im Hintergrund"** — betrifft eine andere Ansicht (freie Meditation) mit
  einem anderen Mechanismus. Bleibt offen, wird durch diesen Fix weder gelöst noch berührt.
- **#14 „Zombie-Sitzung bei Deep-Link während Hintergrund"** — bleibt offen. Der Zustand, der sie
  hätte ausweiten können, gehörte zur inzwischen zurückgenommenen Entfernung und besteht nicht
  mehr.
- **#13** — bleibt offen, weil der Guard weiterhin im Code steht. Die frühere Einstufung
  „gegenstandslos" ist zurückgezogen.
- **Freies Workout und Atemübung** — dort fehlt die automatische Beendigung bereits. Ob dort
  dieselbe Aufräum-Lücke besteht, die die Rücknahme in `WorkoutProgramsView` ausgelöst hat, ist in
  diesem Vorhaben nicht geprüft (#36).
- **#32 (Atemübungs-Test, falsche Preset-Namen)** — eigenes Ticket, kein Bezug zum geführten
  Workout.
- **#33 (`Scripts/run-uitests.sh` meldet Grün bei null ausgeführten Tests)** — eigenes Ticket,
  betrifft die Test-Infrastruktur, nicht das Produktverhalten dieses Fixes.
- **#34 (Edit-Gate lehnt die Häkchen-Schreibweise bei Acceptance Criteria ab)** — eigenes Ticket;
  diese Spec verwendet deshalb durchgehend das Format `- **AC-N:** …`.
- **Bedienhilfen-Baum-Reparatur des Überlagerungs-Effekts** (Alternative C oben) — eigenes,
  mögliches Aufräum-Ticket, nicht Teil dieses Fixes.
- **Fehlende Hintergrund-Audio-Absicherung des geführten Workouts** (im Unterschied zur freien
  Meditation, die `BackgroundAudioKeeper` nutzt) — eigenes Ticket.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Es handelt sich um eine reine Testkorrektur (falsches Prüfkriterium) plus einen
  berichtigten Kommentar im Quellcode — kein neuer Mechanismus, kein geändertes Produktverhalten,
  keine Architektur-Weichenstellung. Die zwischenzeitlich erwogene Entfernung des `scenePhase`-
  Guards wäre eine Weichenstellung gewesen; sie wurde zurückgenommen, der bestehende Stand bleibt
  unangetastet. Keine neue, projektweite Entscheidung, daher keine ADR nötig.

## Changelog

- **2026-09-23 (3):** Spec nach Runde 2 der unabhängigen Prüfung durchgängig auf den tatsächlichen
  Stand gezogen (Commit `53da218`). Alle Stellen berichtigt, die den `scenePhase`-Guard als entfernt
  beschrieben — er ist vorhanden, die Entfernung wurde zurückgenommen, am Quellcode bleibt nur ein
  berichtigter Kommentar. Das Prüfkriterium ist in allen verbindlichen Abschnitten (Purpose,
  Implementation Details, Test Plan, Acceptance Criteria, Definition of Done) von „Pause-Knopf" auf
  **Abbruch-Knopf (`xmark`) + Fortschrittszähler** umgestellt; der widerlegte Satz, die
  Sitzungs-Karte existiere ausschließlich während laufender Sitzung, ist gestrichen und durch die
  gemessene Zustandstabelle ersetzt. Lebendigkeitsprüfung als Abnahmepunkt ergänzt, der unerfüllbare
  DoD-Punkt zur Abwesenheit des Guards umformuliert, `LeanHealthTimerTests/SessionDurationTests.swift`
  in „Affected Files" aufgenommen, AC-5 (unverändertes Produktverhalten) ergänzt. Quellenangabe zum
  Überlagerungs-Effekt auf `WorkoutTab.swift` berichtigt (Runde-1-Befund).

- **2026-09-23 (2):** Unabhängige Prüfung urteilte BROKEN. Vier Befunde behoben: Entfernung der
  zwölf Zeilen **zurückgenommen** (gemessene Regression, #36); AC-3 als *nicht belegt* ausgewiesen
  statt „mittelbar belegt"; Test 2 tippte den Abbruch-Knopf blind — jetzt gezielter Zugriff;
  Prüfkriterium vom zustandsabhängigen Pause-Knopf auf Abbruch-Knopf und Fortschrittszähler
  umgestellt, ergänzt um eine Lebendigkeitsprüfung. Falschaussage in der Spec zu #7 berichtigt.

- **2026-09-23:** Langer UI-Test gelöscht (im Simulator nicht führbar: HealthKit-Speicher
  bleibt leer, Berechtigung nicht setzbar). Ersatz: Unit-Test `SessionDurationTests`. AC-3 auf das
  tatsächlich Belegbare zugeschnitten, Einschränkung ausgewiesen. Test 2 ebenfalls korrigiert —
  seine Prüfung auf den Start-Knopf war aus demselben Grund wertlos wie die in Test 1.

- 2026-09-22: Initial spec created
- 2026-09-22: Testlücke zu AC-2/AC-4 nach PO-Rückmeldung geschlossen. Ein neuer, kombinierter Test
  ergänzt (`test_backgroundDuringSession_thenNaturalCompletion_writesFullDurationEntry`), der
  einen Hintergrund-Wechsel in einen bis zum natürlichen Abschluss durchlaufenden Workout-Testlauf
  einbaut und die geschriebene HealthKit-Dauer prüft. AC-2 auf den beweisbaren Teil (kein
  HealthKit-Eintrag) präzisiert, Live-Activity-Bestand als nicht automatisiert prüfbar
  ausgewiesen. `LeanHealthTimerUITests/BackgroundMeditationUITests.swift` in Scope von UNCHANGED
  auf MODIFY geändert, Estimated Changes entsprechend aktualisiert.
- 2026-09-22: Nachbesserung — ursprünglich vorgeschlagener „Test 3" (Bildschirmzustand nach
  Hintergrund-Wechsel + Abbruch) gestrichen, da er denselben Beleg wie Test 1 nur anders verpackt
  hätte, keinen unabhängigen Beweis. Ersetzt durch einen einzigen Test, der den Hintergrund-Wechsel
  in den bis zum natürlichen Ende laufenden Testlauf integriert und AC-2 sowie AC-4 direkt über
  die geschriebene HealthKit-Dauer belegt (kein Bildschirm-Proxy mehr). Die 2-Minuten-Schwelle in
  `DayDetailSheet` als Teil des Messverfahrens dokumentiert, inkl. Warnung vor stillschweigendem
  Wirkungsverlust bei künftiger Änderung dieser Schwelle.
- 2026-09-22: **Root Cause widerlegt durch Messung; Spec auf Testschuld umgestellt.** Eine gezielte
  Protokollierung aller sitzungsbeendenden Aufrufe zeigt: `endSession` wird beim
  Hintergrund-Wechsel nicht ausgelöst, die Sitzung läuft unverändert weiter. Die ursprüngliche
  Ursachenannahme (scenePhase-Guard greift nicht) ist damit widerlegt und wird als Irrweg markiert,
  nicht gelöscht. Tatsächliche Ursache des roten Tests: Der Überlagerungs-Effekt entfernt die
  Programmliste nicht aus dem Bedienhilfen-Baum, wodurch `app.buttons["Start"]` während der
  gesamten Sitzung existiert und als Prüfkriterium untauglich ist. Titel, Purpose, Root Cause,
  Dependencies, Affected Files, Test Plan, Acceptance Criteria, Definition of Done und Abgrenzung
  entsprechend umgestellt: von Produktfehler-Behebung auf Testschuld-Korrektur.
