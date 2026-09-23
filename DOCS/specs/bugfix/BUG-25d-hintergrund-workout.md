---
entity_id: BUG-25d-hintergrund-workout
type: bugfix
created: 2026-09-22
updated: 2026-09-22
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
Sitzung prüfen (Sitzungs-Karte mit Pause-Knopf vorhanden oder nicht), statt sich auf den
irreführenden Start-Knopf zu verlassen. Zusätzlich enthält er eine Aufräumarbeit: Eine
Absicherung im Sitzungskarten-Code, die auf einer von Apple nicht zugesicherten Reihenfolge zweier
Systemereignisse beruhte, bleibt entfernt — nicht als Fehlerbehebung, sondern weil sie ohnehin nie
wirksam war und im Projekt an zwei anderen Stellen bereits ersatzlos gestrichen ist.

## Source

| Feld | Wert |
|------|------|
| Entity | `BUG-25d-hintergrund-workout` |
| Spec-Datei | `docs/specs/bugfix/BUG-25d-hintergrund-workout.md` |
| Kontext & Analyse | `docs/context/bug-25d-hintergrund-meditation.md` |
| Messbeleg | `docs/artifacts/bug-25d-hintergrund-meditation/diagnose-endSession-aufrufe.txt` |
| Workflow | `bug-25d-hintergrund-meditation` |
| Ursprung | Issue #25, Cluster D (Bestandsaufnahme rote UI-Tests) |
| Tatsächliche Ursache des roten Tests | `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift`, `struct OverlayBackgroundEffect` (Zeilen 596-605) |
| Betroffene Tests | `LeanHealthTimerUITests/BackgroundMeditationUITests.swift`: `test_backgroundForeground_sessionStillRunning` (Zeile 183), `test_explicitStop_endsSession` (Zeile 297) |
| Widerlegte Ursachenannahme | `struct WorkoutProgramSessionCard` — betroffener Code bereits entfernt, siehe unten |

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
läuft weiter. Beleg: `docs/artifacts/bug-25d-hintergrund-meditation/diagnose-endSession-aufrufe.txt`
(3 Durchgänge, alle identisch).

**Der tatsächliche Grund für den roten Test:** Die Sitzungs-Karte (`WorkoutProgramSessionCard`)
liegt als Überlagerung über der Programmliste. `OverlayBackgroundEffect`
(`WorkoutProgramsView.swift`, Zeilen 596-605) blendet die Liste darunter nur per
`.blur(radius: 6)` weich aus und sperrt sie über `.allowsHitTesting(false)` gegen Antippen — beides
entfernt sie **nicht** aus dem Bedienhilfen-Baum, den XCUITest abfragt. `app.buttons["Start"]`
existiert deshalb während der **gesamten** Sitzung: vor Sitzungsbeginn, während sie läuft, und
danach — der Hintergrund-Wechsel ändert daran nichts. Der Test prüfte
`XCTAssertFalse(startButtonAfterReturn.exists)` und schloss daraus fälschlich auf ein
Sitzungsende. Diese Prüfung konnte unabhängig vom tatsächlichen Sitzungszustand nie bestehen.

**Zusatzbefund:** Der Workout-Tab, den Nutzer tatsächlich sehen, ist `WorkoutTab.swift` mit einer
eigenen Liste und einem eigenen `runningSet` (Zeile 38). Aus `WorkoutProgramsView.swift` wird
produktiv nur die Sitzungs-Karte (`WorkoutProgramSessionCard`) und der Überlagerungs-Effekt
(`OverlayBackgroundEffect`) wiederverwendet — die Liste und der Überlagerungs-Zustand in
`WorkoutProgramsView` selbst laufen im Produkt nie.

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

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | UNVERÄNDERT | Entfernung zurückgenommen (2026-09-23); nur der irreführende Kommentar über die Callback-Reihenfolge wurde durch den gemessenen Befund ersetzt |
| SwiftUI `scenePhase` / `onDisappear` (`WorkoutProgramSessionCard`) | System-Lebenszyklus | Gegenstand der widerlegten Ursachenannahme; die zugehörige Absicherung ist bereits entfernt und bleibt es (Aufräumen) |
| HealthKit | System-Framework | Ziel der Dauer-Prüfung in AC-3 (voller Eintrag bei regulärem Abschluss) |
| `Meditationstimer iOS/Tabs/WorkoutTab.swift` (Zeile 38) | Projekt-Kontext | Tatsächlich genutzter Workout-Tab mit eigenem `runningSet`; erklärt, warum Liste und Überlagerungs-Zustand in `WorkoutProgramsView` selbst nie produktiv laufen |
| `Meditationstimer iOS/Tabs/WorkoutsView.swift`, `AtemView.swift` | Projekt-Präzedenzfall | Gleiches Guard-Muster dort bereits ersatzlos entfernt — Vorbild für das Aufräumen in `WorkoutProgramsView` |

## Scope

### Affected Files

| Datei | Change Type | Beschreibung |
|-------|-------------|--------------|
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | MODIFY (bereits umgesetzt) | Aufräumen, kein Fehlerbehebung: `@State isInBackground`, `.onChange(of: scenePhase)` und der `.onDisappear`-Block mit `endSession(manual: true)` in `WorkoutProgramSessionCard` bleiben entfernt (ca. −14 LoC). Begründung: Die Konstruktion beruhte auf einer nicht zugesicherten Callback-Reihenfolge, der Pfad wird im Produkt nachweislich nie durchlaufen (siehe Root Cause), und dieselbe Streichung ist in `AtemView` und `WorkoutsView` bereits gelebte Praxis. |
| `openspec/specs/bug-7-background-meditation.md` | MODIFY (bereits erfolgt) | Die dortige Entscheidung (Guard einführen) ist als zurückgenommen vermerkt, mit Verweis auf diese Spec und auf die Gegenstandslosigkeit von Issue #13. |
| `LeanHealthTimerUITests/BackgroundMeditationUITests.swift` | MODIFY | Testkorrektur: `test_backgroundForeground_sessionStillRunning` und `test_explicitStop_endsSession` werden umgeschrieben, sodass sie den tatsächlichen Zustand der Sitzungs-Karte (Pause-Knopf) prüfen statt sich auf `app.buttons["Start"]` zu verlassen (siehe Test Plan). |

### Estimated Changes

- Dateien: 3 (eine Quelldatei, eine bestehende Spec, eine UI-Testdatei)
- LoC Produktänderung (`WorkoutProgramsView.swift`): bereits umgesetzt, ca. −14 LoC, kein weiterer
  Aufwand offen.
- LoC Testkorrektur (`BackgroundMeditationUITests.swift`): ca. +10/−15 — Ersetzen der beiden
  Start-Knopf-Prüfungen durch Pause-Knopf-Prüfungen, Kommentare aktualisiert (der Verweis auf
  „Bug: onDisappear ruft endSession auf" wird durch den tatsächlichen Befund ersetzt).
- Risiko: NIEDRIG. Es wird kein neues Produktverhalten eingeführt, nur eine bestehende, bereits
  vollzogene Aufräumarbeit dokumentiert und zwei fehlerhafte Testprüfungen korrigiert.

## Implementation Details

Die Produktänderung ist bereits vollzogen: `WorkoutProgramSessionCard` enthält keinen
`@State isInBackground`, kein `.onChange(of: scenePhase)` und keinen `.onDisappear`-Block mit
`endSession` mehr. Die beiden regulären Wege, eine Sitzung zu beenden, bleiben unverändert
bestehen und rufen `endSession` weiterhin direkt auf: der Abbruch-Knopf (xmark) und der natürliche
Abschluss über `onSessionEnd`.

Die verbleibende Arbeit betrifft ausschließlich die Testdatei:

- `test_backgroundForeground_sessionStillRunning`: Die Prüfung
  `XCTAssertFalse(startButtonAfterReturn.exists)` entfällt ersatzlos. Die bereits vorhandene,
  bislang nur als „Cleanup"-Kommentar geführte Prüfung `XCTAssertTrue(pauseButton.exists)` nach dem
  Hintergrund-Zyklus wird zur eigentlichen, alleinigen Prüfung des Tests. Kommentare, die den
  scenePhase-Guard als Ursache benennen, werden durch den tatsächlichen Befund ersetzt.
- `test_explicitStop_endsSession`: Die Prüfung `XCTAssertTrue(startButton.waitForExistence(...))`
  entfällt, weil sie nichts beweist — der Start-Knopf existierte technisch schon vor dem Tap auf
  den Abbruch-Knopf. Ersetzt wird sie durch eine Prüfung, dass der Pause-Knopf (Sitzungs-Karte)
  nach dem Abbruch nicht mehr existiert.
- `test_backgroundDuringSession_thenNaturalCompletion_writesFullDurationEntry` wird **gelöscht**,
  samt der nur von ihm genutzten Hilfsmethoden — sein Nachweis ist im Simulator nicht führbar
  (siehe Test Plan). AC-3 belegt stattdessen der neue Unit-Test
  `LeanHealthTimerTests/SessionDurationTests.swift`, mit der dort ausgewiesenen Einschränkung.

### Geprüfte Alternativen

| # | Ansatz | Bewertung |
|---|--------|-----------|
| A | Aufräumarbeit rückgängig machen: Guard in `WorkoutProgramSessionCard` wiederherstellen, nur die Tests anpassen | **Abgelehnt.** Der Guard beruhte auf einer nicht zugesicherten Reihenfolge und ist im Produkt nachweislich nie wirksam (siehe Root Cause). Eine Wiedereinführung wäre ein Rückschritt ohne Nutzen. |
| **B (gewählt)** | Aufräumarbeit behalten, beide betroffenen Tests auf den tatsächlichen Sitzungszustand (Pause-Knopf) statt auf den irreführenden Start-Knopf umstellen | Behebt die eigentliche Ursache des roten Tests, folgt dem Befund der Messung, ändert kein Produktverhalten. |
| C | Bedienhilfen-Baum reparieren: Liste bei laufender Sitzung vollständig aus dem Baum entfernen (z. B. `.accessibilityHidden(true)` statt nur `.blur` + `.allowsHitTesting`) | **Zurückgestellt.** Würde `app.buttons["Start"]` wieder brauchbar als Kriterium machen, ist aber eine Produktänderung außerhalb des Scopes dieses Testschuld-Fixes und behebt keinen bekannten Nutzer-Fehler. Kandidat für ein eigenes, kleines Aufräum-Ticket, falls künftig weitere Tests denselben Fallstrick treffen. |

## Test Plan

### Automated Tests (Korrektur bestehender Tests)

- [ ] Test 1 (korrigiert): GIVEN ein geführtes Workout wurde gestartet und die Sitzungs-Karte mit
      Pause-Knopf ist sichtbar WHEN der Nutzer den Home-Knopf drückt und die App danach wieder
      aktiviert THEN ist die Sitzungs-Karte mit Pause-Knopf weiterhin sichtbar
      (`BackgroundMeditationUITests.test_backgroundForeground_sessionStillRunning`). Die bisherige
      Prüfung `XCTAssertFalse(app.buttons["Start"].exists)` entfällt ersatzlos.
- [ ] Test 2 (korrigiert): GIVEN ein geführtes Workout läuft WHEN der Nutzer den Abbruch-Knopf
      (xmark) antippt THEN ist die Sitzungs-Karte mit Pause-Knopf nicht mehr sichtbar
      (`BackgroundMeditationUITests.test_explicitStop_endsSession`). Die bisherige Prüfung
      `XCTAssertTrue(app.buttons["Start"].waitForExistence(...))` entfällt, weil sie nichts
      beweist — der Start-Knopf existierte technisch schon vor dem Tap.

### Warum `app.buttons["Start"]` als Kriterium untauglich ist

`OverlayBackgroundEffect` blendet die Programmliste hinter
der Sitzungs-Karte nur per `.blur(radius: 6)` weich aus und sperrt sie über
`.allowsHitTesting(false)` gegen Antippen. Beides entfernt den Start-Knopf **nicht** aus dem
Bedienhilfen-Baum. `app.buttons["Start"].exists` ist deshalb während der gesamten Sitzung wahr —
vor Sitzungsbeginn, während sie läuft, und danach. Eine Prüfung, die auf diesem Zustand aufbaut
(gleich ob als „darf nicht existieren" oder „muss existieren"), unterscheidet nicht zwischen
laufender und beendeter Sitzung und ist als Kriterium wertlos. Die Sitzungs-Karte selbst
(Pause-Knopf) dagegen existiert ausschließlich, während die Sitzung tatsächlich läuft — sie ist das
einzige verlässliche Signal und wird deshalb künftig als alleiniges Kriterium verwendet.

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
- Das Ende steht beim Start fest und verrutscht auch nach realer Laufzeit nicht — **das ist der
  eigentliche Regressionsschutz für den Hintergrund-Fall:** Vergangene Zeit zählt voll, auch
  während die App nicht sichtbar war. Eine spätere Umstellung auf einen mitlaufenden Countdown
  würde diesen Test sofort kippen.
- Gegenfall: Ein vorzeitiger Abbruch ergibt einen entsprechend kürzeren Zeitraum.

Alle drei grün. Kein HealthKit, kein Testdoppel, keine Produktivcode-Änderung.

**⚠️ Der Ersatz belegt AC-3 NICHT — auch nicht mittelbar.** Die unabhängige Prüfung vom
2026-09-23 hat das nachgewiesen, und die frühere Formulierung „mittelbar belegt" war falsch:

`SessionDurationTests` prüft `TwoPhaseTimerEngine`. Dort steht der Endzeitpunkt **beim Start fest**.
Das geführte Workout-Programm macht das Gegenteil: `WorkoutProgramsView.swift:958` setzt
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

## Acceptance Criteria

- **AC-1:** Läuft ein geführtes Workout und der Nutzer drückt den Home-Knopf, ist die
  Sitzungs-Karte mit Pause-Knopf nach der Rückkehr in die App weiterhin sichtbar — die Sitzung hat
  den App-Wechsel überstanden.
- **AC-2:** Der Abbruch-Knopf (xmark) beendet eine laufende Sitzung weiterhin zuverlässig — nach
  dem Antippen ist die Sitzungs-Karte mit Pause-Knopf nicht mehr sichtbar.
- **AC-3:** *(nicht belegt — als offener Punkt ausgewiesen, siehe unten)* Ein geführtes Workout,
  das regulär bis zum Ende läuft, schreibt einen Eintrag mit der vollständigen Dauer. Für diese
  Aussage existiert **kein** automatisierter Nachweis. Der ursprünglich dafür vorgesehene UI-Test
  ist im Simulator nicht führbar, und der Unit-Test `SessionDurationTests` prüft einen **anderen**
  Entwurf als den, der im geführten Workout läuft (Details im Test Plan). Der Nachweis ist als
  **Issue #35** ausgelagert.

- **AC-4:** `test_backgroundForeground_sessionStillRunning` und `test_explicitStop_endsSession`
  prüfen künftig den tatsächlichen Zustand der Sitzungs-Karte statt des irreführenden
  Start-Knopfs, und beide laufen grün.

## Definition of Done

- [ ] `test_backgroundForeground_sessionStillRunning` prüft die Sitzungs-Karte (Pause-Knopf) statt
      `app.buttons["Start"]` und läuft grün.
- [ ] `test_explicitStop_endsSession` prüft, dass die Sitzungs-Karte (Pause-Knopf) nach dem
      Abbruch verschwindet, statt nur den Start-Knopf zu prüfen, und läuft grün.
- [ ] `test_backgroundDuringSession_thenNaturalCompletion_writesFullDurationEntry` ist entfernt,
      samt der nur von ihm genutzten Hilfsmethoden.
- [ ] `LeanHealthTimerTests/SessionDurationTests.swift` existiert und läuft grün; die vollständige
      Unit-Suite bleibt fehlerfrei.
- [ ] `WorkoutProgramSessionCard` enthält weiterhin keinen `@State isInBackground`, kein
      `.onChange(of: scenePhase)` und keinen `.onDisappear`-Block mit `endSession`.
- [ ] `openspec/specs/bug-7-background-meditation.md` bleibt mit dem Revisions-Abschnitt vom
      2026-09-22 versehen (Guard als zurückgenommen vermerkt).
- [ ] Alle Acceptance Criteria sind abgehakt.
- [ ] `git diff --name-only` gegen den Ausgangsstand nennt ausschließlich die unter „Affected
      Files" gelisteten Pfade — keinen weiteren.
- [ ] Die App übersetzt ohne Fehler (`xcodebuild` für Schema „Lean Health Timer").

## Abgrenzung — was dieser Fix NICHT behandelt

- **Testbarkeit des geführten Workout-Pfades** — dass dessen geschriebene Dauer direkt geprüft
  werden kann, verlangt einen Umbau: Sitzungslogik aus der Bildschirmansicht herauslösen oder
  `HealthKitManager` eine einspeisbare Schreib-Schnittstelle geben. Eigenes Ticket; hier bewusst
  nicht angefasst, weil es den Umfang (4-5 Dateien / ±250 LoC) sprengt.
- **Warum im Simulator kein HealthKit-Eintrag entsteht** — gemessen, aber nicht erklärt. Ob die
  Schreibfreigabe fehlt, verweigert ist oder der Schreibpfad aus anderem Grund nicht greift, ist
  offen. Eigenes Ticket.

- **#15 „Meditation stirbt im Hintergrund"** — betrifft eine andere Ansicht (freie Meditation) mit
  einem anderen Mechanismus. Bleibt offen, wird durch diesen Fix weder gelöst noch berührt.
- **#14 „Zombie-Sitzung bei Deep-Link während Hintergrund"** — bleibt offen, wird durch diesen Fix
  weder gelöst noch verschärft.
- **Freies Workout und Atemübung** — dort existierte der ursprünglich vermutete Fehler ohnehin
  nicht, weil die automatische Beendigung dort bereits fehlt (Präzedenzfall für die Aufräumarbeit).
- **#32 (Atemübungs-Test, falsche Preset-Namen)** — eigenes Ticket, kein Bezug zum geführten
  Workout.
- **#33 (`Scripts/run-uitests.sh` meldet Grün bei null ausgeführten Tests)** — eigenes Ticket,
  betrifft die Test-Infrastruktur, nicht das Produktverhalten dieses Fixes.
- **#34 (Edit-Gate lehnt die Häkchen-Schreibweise bei Acceptance Criteria ab)** — eigenes Ticket;
  diese Spec verwendet deshalb durchgehend das Format `- **AC-N:** …`.
- **Bedienhilfen-Baum-Reparatur von `OverlayBackgroundEffect`** (Alternative C oben) — eigenes,
  mögliches Aufräum-Ticket, nicht Teil dieses Fixes.
- **Fehlende Hintergrund-Audio-Absicherung des geführten Workouts** (im Unterschied zur freien
  Meditation, die `BackgroundAudioKeeper` nutzt) — eigenes Ticket.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Es handelt sich um eine Testkorrektur (falsches Prüfkriterium) plus eine bereits
  vollzogene, lokal begrenzte Aufräumarbeit an entferntem Code — kein neuer Mechanismus, keine
  Architektur-Weichenstellung. Die Aufräumarbeit folgt einem im Projekt bereits zweifach gelebten
  Muster (`WorkoutsView.swift`, `AtemView.swift`). Keine neue, projektweite Entscheidung, daher
  keine ADR nötig.

## Changelog

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
  nicht gelöscht. Tatsächliche Ursache des roten Tests: `OverlayBackgroundEffect` entfernt die
  Programmliste nicht aus dem Bedienhilfen-Baum, wodurch `app.buttons["Start"]` während der
  gesamten Sitzung existiert und als Prüfkriterium untauglich ist. Titel, Purpose, Root Cause,
  Dependencies, Affected Files, Test Plan, Acceptance Criteria, Definition of Done und Abgrenzung
  entsprechend umgestellt: von Produktfehler-Behebung auf Testschuld-Korrektur plus dokumentiertes
  Aufräumen. Die bereits entfernten zwölf Zeilen in `WorkoutProgramSessionCard` bleiben entfernt
  (PO-Entscheidung: „Tests korrigieren, Aufräumen behalten").
