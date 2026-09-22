---
entity_id: BUG-25d-hintergrund-workout
type: bugfix
created: 2026-09-22
updated: 2026-09-22
status: draft
workflow: bug-25d-hintergrund-meditation
---

# BUG-25d: Hintergrund-Wechsel beendet geführtes Workout

## Approval

- [ ] Approved

## Purpose

Drückt der Nutzer während eines laufenden geführten Workouts den Home-Knopf, beendet die App die
Sitzung sofort und schreibt einen verfrühten HealthKit-Eintrag — obwohl der Nutzer nichts gestoppt
hat, sondern nur kurz zu einer anderen App gewechselt ist. Der Fix entfernt die fehlerhafte
Sicherung, die das auslöst, und stellt damit das Verhalten wieder her, das für freies Workout und
Atemübung bereits gilt: Eine Sitzung läuft im Hintergrund weiter, bis der Nutzer sie aktiv beendet
oder sie regulär abgeschlossen ist.

## Source

| Feld | Wert |
|------|------|
| Entity | `BUG-25d-hintergrund-workout` |
| Spec-Datei | `docs/specs/bugfix/BUG-25d-hintergrund-workout.md` |
| Kontext & Analyse | `docs/context/bug-25d-hintergrund-meditation.md` |
| Workflow | `bug-25d-hintergrund-meditation` |
| Ursprung | Issue #25, Cluster D (Bestandsaufnahme rote UI-Tests) |
| Datei | `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` |
| Identifier | `struct WorkoutProgramSessionCard`, Zeilen 681-682 und 807-817 |

## Root Cause

`WorkoutProgramSessionCard` koppelt die Sitzungsdauer an den View-Lebenszyklus statt an eine
explizite Nutzerhandlung. Ein `@State isInBackground`, gesetzt über `.onChange(of: scenePhase)`,
soll in `.onDisappear` verhindern, dass die Sitzung beim Hintergrund-Wechsel beendet wird. Der
Kommentar im Code geht davon aus, dass `onChange(of: scenePhase)` immer vor `onDisappear` feuert —
eine Reihenfolge, die Apple nirgends zusichert.

Unter Xcode 27.0 / iOS 26.5 feuert `onDisappear` deterministisch vor dem scenePhase-Update
(3 von 3 Reproduktionen in dieser Sitzung, zusätzlich 2 von 2 in einem früheren Lauf). Der Guard
greift dadurch nie: `endSession(manual: true)` läuft durch, die Live Activity endet, ein
HealthKit-Eintrag mit der bis dahin verstrichenen (falschen) Dauer wird geschrieben, und die
Übersicht mit dem Start-Knopf erscheint wieder — obwohl der Nutzer die Sitzung nicht beendet hat.

Der `onDisappear`-Aufruf von `endSession` ist zudem nachweislich redundant: Es gibt in dieser
Ansicht keinen anderen Weg aus der Sitzungs-Karte heraus, den er auffangen müsste. Sie ist ein
Overlay ohne Navigation, die Tab-Leiste ist während der Sitzung ausgeblendet, und beide regulären
Enden (Abbruch-Knopf, natürlicher Abschluss) rufen `endSession` bereits direkt auf.

**Ergänzender Code-Befund (Hintergrundwissen, keine Testgrundlage):** `endSession()`
(Zeilen 941-1004) bündelt in einem einzigen, durch ein `sessionEnded`-Flag vor Doppelausführung
geschütztem Aufruf drei Effekte: das Beenden der Live Activity, das Schreiben des
HealthKit-Eintrags und das Wiedereinblenden der Übersicht mit dem Start-Knopf. Das erklärt, warum
im Bug-Fall überhaupt nur EIN (zu kurzer) Eintrag entsteht, statt zweier. Dieser Zusammenhang wird
im Test Plan bewusst NICHT als Beweisgrundlage verwendet — er gilt nur für den heutigen Code und
bricht bei einem künftigen Umbau von `endSession()`, ohne dass ein Test das anzeigen würde. Der
Test Plan misst stattdessen direkt auf HealthKit-Ebene (siehe unten), was auch nach einem Umbau
noch aussagekräftig bleibt.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| SwiftUI `scenePhase` / `onDisappear` | System-Lebenszyklus | Ursache des Fehlers; wird durch den Fix aus dem Sitzungs-Ende entkoppelt |
| ActivityKit (Live Activity) | System-Framework | Wird fälschlich beendet, solange der Guard nicht greift |
| HealthKit | System-Framework | Erhält den verfrühten, falschen Eintrag |
| `Meditationstimer iOS/Tabs/WorkoutsView.swift` (Zeile 66) | Projekt-Präzedenzfall | Gleiches Problem bereits durch ersatzlose Streichung gelöst |
| `Meditationstimer iOS/Tabs/AtemView.swift` (Zeile 567) | Projekt-Präzedenzfall | Gleiches Problem bereits durch ersatzlose Streichung gelöst |

## Scope

### Affected Files

| Datei | Change Type | Beschreibung |
|-------|-------------|--------------|
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | MODIFY | Zeilen 681-682 und 807-817: `@State isInBackground`, `.onChange(of: scenePhase)` und der `.onDisappear`-Block mit `endSession(manual: true)` werden ersatzlos entfernt. Kein neuer Code. |
| `openspec/specs/bug-7-background-meditation.md` | MODIFY | Die dort getroffene Entscheidung (Guard einführen) wird als überholt vermerkt; Abgrenzung zu Issue #13 (wird gegenstandslos), #14 und #15 ergänzt. |
| `LeanHealthTimerUITests/BackgroundMeditationUITests.swift` | MODIFY | Ein neuer Test ergänzt, der AC-2 und AC-4 gemeinsam über die tatsächlich geschriebene HealthKit-Dauer belegt (siehe Test Plan). Die beiden bestehenden Tests (`test_backgroundForeground_sessionStillRunning`, `test_explicitStop_endsSession`) bleiben unverändert und dienen weiterhin als Abnahmenachweis. |

### Estimated Changes

- Dateien: 3 (eine Quelldatei, eine bestehende Spec, eine UI-Testdatei)
- LoC Produktänderung: +0 / −12 (unverändert — es wird ausschließlich Code entfernt)
- LoC Testdatei: +~90 / −0 (ein neuer, kombinierter Test mit Hintergrund-Zyklus, Wartezeit bis zum
  natürlichen Abschluss und HealthKit-Dauerprüfung; bestehende Tests unverändert)
- Risiko: NIEDRIG für die Produktänderung (nur Entfernung, kein neuer Code). Für den neuen Test:
  bewusst in Kauf genommene Laufzeit von ca. 4-5 Minuten (siehe Test Plan) — kein funktionales
  Risiko, aber ein Laufzeit-Kostenpunkt für die Test-Suite.

## Implementation Details

Entfernt werden in `WorkoutProgramSessionCard`:

- die Zustandsvariable `isInBackground` (Zeilen 681-682)
- der `.onChange(of: scenePhase)`-Block, der sie setzt
- der `.onDisappear`-Block, der bei `!isInBackground` `endSession(manual: true)` auslöst
  (Zeilen 807-817)

Die beiden regulären Wege, eine Sitzung zu beenden, bleiben unverändert bestehen und rufen
`endSession` weiterhin direkt auf: der Abbruch-Knopf (xmark, Zeilen 766-771) und der natürliche
Abschluss über `onSessionEnd` (Zeile 729). Kein Ersatzmechanismus wird eingeführt — genau das ist
der Kern des Fixes.

### Geprüfte Alternativen

| # | Ansatz | Bewertung |
|---|--------|-----------|
| A | Guard härten: `scenePhase` direkt im `onDisappear` lesen statt über `onChange` zwischenzuspeichern | **Abgelehnt.** Verlässt sich weiterhin auf eine von Apple nicht zugesicherte Reihenfolge zweier Callbacks — dieselbe Wette, nur neu verpackt. Ist zwischen iOS 18.5 und 26.5 bereits einmal still gebrochen. |
| **B (gewählt)** | Kopplung auflösen: Guard-Konstrukt ersatzlos entfernen | Behebt die Ursache, führt keinen neuen Code ein, folgt dem im Projekt an zwei anderen Stellen bereits etablierten Muster (`WorkoutsView`, `AtemView`). |
| C | Sitzung in ein vom View unabhängiges Modell/Service auslagern | **Abgelehnt für diesen Fix.** Architektonisch der Idealzustand, sprengt aber die Umfangsgrenze (2-3 Dateien, 300-500+ LoC statt 4-5 Dateien / ±250 LoC). Kein erprobtes Vorbild im Projekt — gehört als eigenes Architektur-Vorhaben in ein separates Ticket. |
| D | Nur die Testerwartung im RED-Test ändern | **Abgelehnt.** Die Reproduktion ist deterministisch und bildet alltägliches Nutzerverhalten ab (Home-Knopf während eines Workouts). Das würde nur das Test-Signal verfälschen, ohne das Produktverhalten zu ändern. |

**Gekippte frühere Entscheidung:** Bug #7 (`openspec/specs/bug-7-background-meditation.md`,
2026-04-22) hat genau diesen Guard eingeführt, mit Adversary-Urteil `AMBIGUOUS`. Der damalige
Zweifel ist mit der heutigen Reproduktion bestätigt. Issue #13 („scenePhase-Guard ist
timing-abhängig") wird durch die Entfernung gegenstandslos, nicht nur vermutlich behoben: Ohne
Guard gibt es kein Reihenfolge-Problem mehr, das timing-abhängig sein könnte.

## Test Plan

### Automated Tests — bestehend (unverändert, dienen weiterhin als Abnahme)

- [ ] Test 1 (bestehend, RED): GIVEN ein geführtes Workout wurde gestartet und die Sitzungs-Karte
      mit Pause-Knopf ist sichtbar WHEN der Nutzer den Home-Knopf drückt und die App danach wieder
      aktiviert THEN ist der Start-Knopf NICHT sichtbar und der Pause-Knopf ist weiterhin da
      (`BackgroundMeditationUITests.test_backgroundForeground_sessionStillRunning`).
- [ ] Test 2 (bestehend, Regression): GIVEN ein geführtes Workout läuft WHEN der Nutzer den
      Abbruch-Knopf (xmark) antippt THEN wird die Sitzung sofort beendet und der Start-Knopf
      erscheint wieder (`BackgroundMeditationUITests.test_explicitStop_endsSession`).

Beide Tests bleiben unverändert. Nach Entfernung des Guard-Konstrukts muss Test 1 von FAILED auf
PASSED wechseln, Test 2 muss PASSED bleiben.

### Machbarkeitsprüfung zur Testlücke (AC-2 / AC-4)

Die einzige App-Stelle, die geschriebene HealthKit-Workout-Einträge mit Datum und Dauer sichtbar
macht, ist `DayDetailSheet` (erreichbar über Erfolge-Tab → Tag im Kalender antippen). Dabei gilt:

- Diese Ansicht ist **während einer laufenden Sitzung nicht erreichbar** — die Tab-Leiste ist
  während der Sitzung ausgeblendet (siehe Root-Cause-Abschnitt oben). Ein Test kann den Verlauf
  deshalb nur nach dem Ende der Sitzung einsehen, nie während sie noch läuft.
- Diese Ansicht **blendet jeden Eintrag unter 2 Minuten Dauer komplett aus**
  (`DayDetailSheet.fetchSessions()`: `if duration < 2.0 { continue }`).
- Es gibt **keinen Reset-Mechanismus für HealthKit** im Simulator — nur die Tracker-Datenbank wird
  über das Launch-Argument `enable-testing` in-memory geschaltet, nicht HealthKit.

**Wichtige Korrektur gegenüber einer früheren Fassung dieser Spec:** Die 2-Minuten-Schwelle ist
hier **kein Hindernis, sondern Teil des Messverfahrens** und wird bewusst genutzt: Lässt man das
kürzeste verfügbare Workout-Programm „Tabata Classic" (8 Runden à 30s, keine Wiederholung,
≈ 3:50 Min Gesamtdauer) real bis zum natürlichen Ende laufen und baut in der Mitte einen
Hintergrund-Wechsel ein, unterscheidet sich das Ergebnis auf HealthKit-Ebene unmittelbar und ohne
Umweg über einen Bildschirm-Proxy:

- **Bug aktiv:** Die Sitzung endet beim Hintergrund-Wechsel nach wenigen Sekunden Laufzeit. Der
  geschriebene Eintrag trägt nur diese kurze Dauer (≈ 30s) — und wird von der 2-Minuten-Schwelle
  in `DayDetailSheet` ausgefiltert. Der erwartete Eintrag mit voller Programmdauer taucht in der
  Ansicht gar nicht auf.
- **Fix wirksam:** Die Sitzung läuft trotz Hintergrund-Wechsel weiter bis zum natürlichen
  Abschluss. Der geschriebene Eintrag trägt die volle Programmdauer (≈ 3:50) und ist in
  `DayDetailSheet` sichtbar, weil er deutlich über der 2-Minuten-Schwelle liegt.

Damit misst ein einziger Testlauf die tatsächlich geschriebene Dauer auf HealthKit-Ebene — ein
direkter Beweis, kein Bildschirm-Proxy, und unabhängig davon, wie `endSession()` intern
strukturiert ist oder künftig umgebaut wird. Ein separater, nur auf dem sichtbaren Start-/
Pause-Knopf basierender Test (wie in einer früheren Fassung dieser Spec) entfällt, weil er
gegenüber dem bereits bestehenden Test 1 keinen zusätzlichen, unabhängigen Beleg liefert.

**Warnung für künftige Änderungen:** Die 2-Minuten-Schwelle in `DayDetailSheet.fetchSessions()`
ist Teil des Messverfahrens dieses Tests. Wird sie künftig geändert oder entfernt (z. B. im Rahmen
einer „Aufräum"-Änderung an `DayDetailSheet`), muss dieser Test erneut geprüft werden — er würde
sonst stillschweigend seine Trennschärfe zwischen Bug- und Fix-Fall verlieren, ohne rot zu werden.

### Automated Tests — NEU (in Phase 4 zu schreiben)

- [ ] Test 3 (NEU): GIVEN das kürzeste verfügbare Workout-Programm „Tabata Classic" wurde gestartet
      WHEN nach ca. 30 Sekunden Laufzeit ein Hintergrund/Vordergrund-Zyklus erfolgt (Home-Knopf,
      App reaktivieren) AND die Sitzung danach ohne weiteren Eingriff bis zum natürlichen
      Abschluss durchläuft (Checkmark „Fertig" erscheint) THEN zeigt der Erfolge-Tab für heute
      genau einen neuen Workout-Eintrag, dessen Dauer mindestens 3:30 Min beträgt (nicht ≈ 30s) —
      das beweist in einem Lauf sowohl AC-2 (kein vorzeitiger, durch den Hintergrund-Wechsel
      ausgelöster Eintrag — ein solcher Eintrag hätte nur ≈ 30s und würde von der 2-Minuten-
      Schwelle ausgefiltert, der erwartete lange Eintrag bliebe aus) als auch AC-4 (natürlicher
      Abschluss schreibt die vollständige Dauer)
      (`BackgroundMeditationUITests.test_backgroundDuringSession_thenNaturalCompletion_writesFullDurationEntry`,
      neu).
      **Hinweis:** Dieser Test lässt das Programm real bis zum Ende laufen; seine Laufzeit beträgt
      rund 4-5 Minuten und ist damit der mit Abstand langsamste Test in dieser Datei. Das ist
      bewusst in Kauf genommen — es ist der einzige Weg, sowohl das Ausbleiben eines vorzeitigen
      Eintrags als auch die volle Dauer tatsächlich über HealthKit statt über einen
      Bildschirm-Proxy nachzuweisen. Ein zweiter, separater Testlauf ohne Hintergrund-Wechsel
      (nur zur AC-4-Absicherung) würde die Laufzeit-Kosten verdoppeln, ohne zusätzliche
      Beweiskraft zu bringen, da ein Eintrag mit voller Dauer in diesem einen Lauf bereits beide
      Kriterien gleichzeitig belegt.

**Nicht automatisiert prüfbar:** Dass die Live Activity beim Hintergrund-Wechsel tatsächlich
*sichtbar* bestehen bleibt (Sperrbildschirm/Dynamic Island), lässt sich mit XCUITest nicht direkt
prüfen — Live Activities laufen außerhalb des App-eigenen Bedienelemente-Baums, den XCUITest
ansprechen kann.

## Acceptance Criteria

- [ ] AC-1: Läuft ein geführtes Workout und der Nutzer drückt den Home-Knopf, läuft die Sitzung
      nach dem Zurückkehren zur App weiter — kein Start-Knopf erscheint, die Sitzungs-Karte mit
      Pause-Knopf bleibt sichtbar.
- [ ] AC-2: Beim Hintergrund-Wechsel während eines geführten Workouts wird kein HealthKit-Eintrag
      geschrieben — automatisiert bewiesen über Test 3 anhand der geschriebenen Dauer (kein
      Kurz-Eintrag durch verfrühtes Ende, sondern ein Eintrag mit voller Programmdauer). Dass die
      Live Activity dabei bestehen bleibt statt zu enden, ist nicht automatisiert nachprüfbar
      (Live Activities liegen außerhalb der von XCUITest ansprechbaren Bedienelemente — siehe Test
      Plan).
- [ ] AC-3: Der Abbruch-Knopf (xmark) beendet eine laufende Sitzung weiterhin sofort und
      zuverlässig (Regression zu Test 2).
- [ ] AC-4: Der natürliche Abschluss eines geführten Workouts (Ablauf aller Sätze) schreibt
      weiterhin den erwarteten HealthKit-Eintrag mit der vollständigen Dauer — automatisiert
      bewiesen über Test 3, zusätzlich zur unveränderten Code-Grundlage in `onSessionEnd`.
- [ ] AC-5: `test_backgroundForeground_sessionStillRunning` läuft grün (PASSED statt FAILED),
      `test_explicitStop_endsSession` bleibt grün.

## Definition of Done

- [ ] `WorkoutProgramSessionCard` enthält keinen `@State isInBackground`, kein
      `.onChange(of: scenePhase)` und keinen `.onDisappear`-Block mit `endSession` mehr.
- [ ] Es wurde ausschließlich Code entfernt — kein neuer Code, kein Ersatz-Guard, kein Debounce.
- [ ] `test_backgroundForeground_sessionStillRunning` läuft grün (war vorher deterministisch rot).
- [ ] `test_explicitStop_endsSession` bleibt grün (keine Regression beim expliziten Abbruch).
- [ ] `test_backgroundDuringSession_thenNaturalCompletion_writesFullDurationEntry` (neu) läuft grün
      — der geschriebene HealthKit-Eintrag hat eine Dauer von mindestens 3:30 Min (Laufzeit des
      Tests selbst ca. 4-5 Minuten — bewusst akzeptiert, siehe Test Plan).
- [ ] Alle Acceptance Criteria sind abgehakt.
- [ ] `git diff --name-only` gegen den Ausgangsstand nennt ausschließlich die drei unter
      „Affected Files" gelisteten Pfade — keinen weiteren.
- [ ] `openspec/specs/bug-7-background-meditation.md` ist revidiert: Der Guard ist dort als
      zurückgenommen vermerkt, mit Verweis auf diese Spec und auf Issue #13.
- [ ] Die App übersetzt ohne Fehler (`xcodebuild` für Schema „Lean Health Timer").

## Abgrenzung — was dieser Fix NICHT behandelt

- **#15 „Meditation stirbt im Hintergrund"** — betrifft eine andere Ansicht mit einem anderen
  Mechanismus. Bleibt offen, wird durch diesen Fix weder gelöst noch berührt.
- **#14 „Zombie-Sitzung bei Deep-Link während Hintergrund"** — bleibt offen, wird durch die
  Entfernung des Guards weder gelöst noch verschärft.
- **Freies Workout und Atemübung** — dort existiert der Fehler nicht, weil die fehlerhafte
  automatische Beendigung dort bereits fehlt (Präzedenzfall für diesen Fix).
- **Testschulden in `BackgroundMeditationUITests.swift`** — falsche Atem-Preset-Namen im Test
  (`"4-7-8"`, `"Box"`, `"Wim Hof"` statt der sechs echten Namen), fehlendes Handling des
  HealthKit-Systemdialogs (#24) in den übrigen Cluster-Tests. Eigenes Ticket.
- **Fehlende Hintergrund-Audio-Absicherung des geführten Workouts** (im Unterschied zur freien
  Meditation, die `BackgroundAudioKeeper` nutzt). Eigenes Ticket.
- **`Scripts/run-uitests.sh` meldet Grün bei null ausgeführten Tests** (Zeilen 120-126, greift bei
  Klassennamen ohne `/`-Zeichen). Eigenes Ticket, betrifft die Test-Infrastruktur, nicht das
  Produktverhalten dieses Fixes.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Es wird ausschließlich Code entfernt, kein neuer Mechanismus eingeführt. Die
  Entfernung folgt einem im Projekt bereits zweifach gelebten Muster (`WorkoutsView.swift`,
  `AtemView.swift`) und kippt keine Architektur, sondern eine einzelne, lokal begrenzte
  Fehlentscheidung aus Bug #7 (dort ebenfalls ohne eigene ADR getroffen). Der ergänzte Test ändert
  kein Architektur-Verhalten, sondern schließt ausschließlich eine Prüf-Lücke auf HealthKit-Ebene.
  Keine neue, projektweite Weichenstellung, daher keine ADR nötig.

## Changelog

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
