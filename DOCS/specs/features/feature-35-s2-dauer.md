---
entity_id: feature-35-s2-dauer
type: feature
created: 2026-11-26
updated: 2026-11-26
status: draft
workflow: fix-35-s2-dauer
issue: 35
---

# Schnitt 2: Dauer des Workout-Programms nach PO-Entscheidung (#35)

## Approval

- [ ] Approved

Freigabe dieser Rundenspec durch den PO.

## Purpose

Die in Health gespeicherte Dauer eines geführten Workout-Programms stimmt heute nicht mit dem Training überein: Pausen und der Countdown zählen mit, und das Ende liegt hinter dem Schlussgong. Schnitt 2 setzt die PO-Entscheidung vom 2026-11-26 um: Pausen werden in Health als Pause markiert, der Countdown zählt nicht, das Ende liegt vor dem Schlussgong. Dazu kommen zwei Tech-Lead-Folgen (Mindestdauer auf aktive Zeit, Doppelaufruf-Wächter).

Sichtbar für Henning: Ringe und Rundenanzeige starten nach dem Countdown bei null; die Live-Activity-Endzeit stimmt; in Health stehen kürzere aktive Dauer und weniger Kalorien, wenn pausiert wurde.

## Source

- Kontext und Analyse: `DOCS/context/fix-35-s2-dauer.md` (verbindlich: „Analysis“)
- Vorgänger: `DOCS/specs/features/feature-35-workout-session-clock.md` (Schnitt 1, PR #125, Uhr und Protokoll)
- Vorbild freies Workout: `Meditationstimer iOS/Tabs/WorkoutTab.swift` (Start nach Auftakt, Ende vor Gong)

### Ursprungsanfrage (PO-Entscheidung 2026-11-26, Issue-Kommentar #35)

1. **Pausen als Pause markieren:** `HKWorkoutEvent` `.pause`/`.resume` über den Builder; Start und Ende bleiben echt, Health rechnet aktive Dauer und Kalorien ohne Pausen.
2. **Countdown zählt nicht:** Das Training beginnt nach dem Countdown.
3. **Ende vor dem Schlussgong**, wie beim freien Workout.

Tech-Lead-Folgen: Die 3-Sekunden-Schwelle gilt auf aktive Zeit. Der Doppelaufruf-Wächter in `endSession` wird als benannter Fix korrigiert. `endSession` (heute 66 Zeilen) wird in Funktionen von höchstens 50 Zeilen aufgeteilt. Die Charakterisierungstests aus Schnitt 1 werden sichtbar umgestellt.

## Gewählter Ansatz und Alternativen

**Gewählt:**
- **Countdown, Variante A:** Die Uhr in der Karte wird optional (`@State clock: WorkoutSessionClock?`, `nil` bis Countdown-Ende). `beginSessionAfterCountdown` legt Uhr und `phaseStart` an; die Ringe werden erst gerendert, wenn die Uhr existiert, ihr Timer startet damit bei null. Die Ring-Datei bleibt unberührt.
- **Pausen: Events über den Builder.** Die Uhr speichert Pausen-Intervalle; `HealthKitManager.logWorkout` bekommt `pauses: [DateInterval] = []` und schreibt per `addWorkoutEvents` `.pause`/`.resume`. Der Schreibweg ist bereits Builder-basiert, ein API-Wechsel entfällt.
- **Regel vor Modell:** Die Eventliste entsteht in einer reinen, statischen, unit-getesteten Funktion; sie ist zugleich die einzige Quelle für aktive Sekunden und Kalorien.

**Verworfen:**
- **Countdown B** (`start` als `var` plus `begin(at:)` in der Uhr, ca. +20 Zeilen): Die Uhr bekäme einen Zustand „nicht gestartet“; mehr Code, kein Gewinn, weil „keine Uhr“ dasselbe ausdrückt.
- **Countdown C** (Uhr später anlegen, Ringe laufen weiter, ca. +5 Zeilen): Die Ringe rückten während des Countdowns vor und kurze Phasen könnten übersprungen werden; verletzt Punkt 2 der PO-Entscheidung sichtbar.
- **Pausen durch Dauer kürzen** (ca. +5 Zeilen): verfälscht Start und Ende, die der PO „echt“ haben will, und Health kennt dann keine Pause.
- **Wandzeit-Schwelle beibehalten:** Eine Sitzung mit 10 s Wand und 8 s Pause hätte nur 2 s Training und würde trotzdem geschrieben.

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — es wird keine bestehende ADR gekippt und keine neue Architekturentscheidung getroffen (Erweiterung des in Schnitt 1 eingeführten Bausteins).

## Affected Files

App-Code (3 Dateien, ca. 90 bis 110 Zeilen, Grenze 250, Funktionen höchstens 50 Zeilen):

| Datei | Änderung | Inhalt | ca. Zeilen |
|---|---|---|---|
| `Meditationstimer iOS/Workout/WorkoutSessionClock.swift` | geändert | `pausedTotal` wird zu `closed: [DateInterval]` plus offene Pause; `pauses`; `activeDuration` aus Intervallen; `meetsMinimum` = `activeDuration > 3`; Protokoll `logWorkout(start:end:activity:pauses:)`; `WorkoutSessionLog.write` reicht `clock.pauses` durch | +25 |
| `Services/HealthKitManager.swift` | geändert | `logWorkout(…, pauses: [DateInterval] = [])`; reine statische Funktion `workoutEvents(pauses:in:)`; `addWorkoutEvents` nach `beginCollection`, nur bei nicht leerer Liste; Kalorien aus aktiven Sekunden; Helfer im `#if os(iOS)`-Block | +30 |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | geändert | Uhr optional; `beginSessionAfterCountdown` mit Wächter `clock == nil`; Ringe nur bei Uhr; `endSession` geteilt in Hauptteil, `playClosingSound(manual:)`, `logSession()`; `sessionEnded = true` sofort nach dem Wächter; `clock?.end(at: Date())` vor Live-Activity-Ende und Gong | +35 netto |

Tests (zählen nicht zum Budget):

| Datei | Änderung |
|---|---|
| `LeanHealthTimerTests/WorkoutSessionClockTests.swift` | geändert: Fake-Logger mit `pauses`, vier Charakterisierungstests umgestellt |
| `LeanHealthTimerTests/HealthKitWorkoutEventsTests.swift` | neu |
| `LeanHealthTimerTests/SessionDurationTests.swift` | Kopfkommentar |
| UI-Test mit Countdown | neu, in der vorhandenen UI-Test-Datei zum Workout-Programm (Launch-Argument) |

Kein Eingriff in `WorkoutTab.swift`, `MeditationTab.swift`, `AtemView.swift`, Watch-Logik, Widget, Info.plist, Entitlements, AppStorage-Schlüssel, `project.pbxproj`.

## Dependencies

| Abhängigkeit | Art | Hinweis |
|---|---|---|
| `logWorkout`-Aufrufer `WorkoutTab` (:762), `MeditationTab` (:414), `AtemView` (:743) | unverändert | Neuer Parameter hat Standardwert `[]` |
| `HealthKitManager.swift` | wird auch vom Watch-Ziel kompiliert | Neuer Code im `#if os(iOS)`-Block; Watch-Build Pflicht |
| Live Activity (`sessionStart`, Zeilen :494, :681/683, :772, :815) | gleiche Quelle | Start künftig ab Countdown-Ende |
| `countdownBeforeStart` | geteilt mit MeditationTab und SettingsSheet | nicht anfassen |
| #49 (Tagebuch) | nachgelagert | nutzt die Uhr ab Schnitt 3 |
| #122 (Health-Freigabe Programm-Weg) | getrennt | Simulator schreibt nichts |

## Expected Behavior

### Uhr (`WorkoutSessionClock`)

- `pauses: [DateInterval]`: abgeschlossene Pausen; eine beim Ende offene Pause erscheint als Intervall bis zum Ende.
- `activeDuration`: Wandzeit minus Summe der Pausenintervalle.
- `meetsMinimum`: `activeDuration > 3` (strikt größer).
- `pause`/`resume`/`end`: ungültige und doppelte Aufrufe bleiben wirkungslos (wie Schnitt 1).

### Events-Funktion (rein)

`static func workoutEvents(pauses: [DateInterval], in span: DateInterval) -> [HKWorkoutEvent]`: sortiert, klemmt jedes Intervall auf `[start, end]`, verwirft Intervalle der Länge 0 (auch nach dem Klemmen), liefert je Intervall `.pause` und `.resume`; reicht ein Intervall bis zum Ende, nur `.pause` (kein `.resume` exakt auf dem Ende).

### Schreibweg

- `logWorkout` schreibt Start und Ende echt, fügt die Events hinzu und berechnet Kalorien aus den aktiven Sekunden (Pausen nicht eingerechnet). Mit `pauses == []` ist das Ergebnis identisch zu heute (freies Workout, Meditation, Atem unverändert).
- `WorkoutSessionLog.write` reicht `clock.pauses` an den Logger; unter der Schwelle wird nicht geschrieben.

### Karte

- Uhr und `phaseStart` entstehen erst beim Übergang aus dem Countdown; Ringe und Rundenanzeige erscheinen danach bei Übung 1 und Runde 1.
- Abbruch im Countdown: keine Uhr, kein Schreibvorgang.
- `endSession`: Wächter, dann sofort `sessionEnded = true`, dann `clock?.end(at: Date())`, dann Live-Activity-Ende und Schlussgong (Sleep), dann Schreiben, Streak, Effort-Sheet, `close()`.

## Acceptance Criteria

„Unit“ = XCTest im Testziel `LeanHealthTimerTests`, feste Basiszeit `Date(timeIntervalSinceReferenceDate: 0)` plus Sekunden, deutsche `testXyz`-Namen. „Simulator“ = Nachweis nur über den Durchlauf im Simulator `iPhone 17 Pro` (iOS 26.5, siehe Projekt-CLAUDE.md), weil die View nicht unit-testbar ist.

- **AC-1 (Unit): Pausenintervalle der Uhr.** Given Start t0, pause t0+10, resume t0+25, pause t0+40, resume t0+45, Ende t0+60, Then `pauses` = [t0+10…t0+25, t0+40…t0+45]. Given pause t0+30 und Ende t0+50 ohne resume, Then `pauses` = [t0+30…t0+50] (offene Pause bis Ende). Given doppeltes `pause` oder `resume` ohne Pause, Then bleibt `pauses` unverändert.
- **AC-2 (Unit): Aktive Dauer.** Given AC-1 erster Fall, Then `wallDuration == 60`, `activeDuration == 40`. Given offene Pause (t0+30 bis Ende t0+50), Then `activeDuration == 30`.
- **AC-3 (Unit): Schwelle auf aktive Zeit.** Given aktive Dauer 3,0 s (ohne Pause und mit Pause bei längerer Wandzeit), Then `meetsMinimum == false`; 3,1 s aktiv Then `true`. Given 10 s Wand und 8 s Pause (aktiv 2 s), Then `meetsMinimum == false`.
- **AC-4 (Unit): Events-Funktion, Standardfälle.** Given leere Liste, Then keine Events. Given 1 Intervall, Then `[.pause(start), .resume(end)]`. Given 2 Intervalle in beliebiger Reihenfolge, Then 4 Events, nach Zeit sortiert, abwechselnd pause/resume.
- **AC-5 (Unit): Events-Funktion, Grenzfälle.** Given Intervall, das über `[start, end]` hinausragt, Then Klemmen auf die Grenzen. Given Intervall der Länge 0 (auch durch Klemmen), Then verworfen. Given Pause bis genau zum Ende, Then nur `.pause`, kein `.resume`.
- **AC-6 (Unit): Kalorien aus aktiven Sekunden.** Given 600 s Wand und 120 s Pause, Then Kalorienwert = aktive Sekunden × 12/min (also für 480 s), nicht für 600 s. Given keine Pausen, Then Wert wie heute (Wandzeit × 12/min).
- **AC-7 (Unit): Standardwert lässt andere Workouts unverändert.** Given `logWorkout` ohne `pauses` (Aufrufer freies Workout, Meditation, Atem), Then keine Events, Kalorien aus der gesamten Dauer. Nachweis zusätzlich per Quelltextprüfung: die drei Aufrufer sind im Diff nicht enthalten.
- **AC-8 (Unit, Fake-Logger): `WorkoutSessionLog` reicht Pausen durch.** Given beendete Uhr mit zwei Pausen, When `write`, Then genau ein Logger-Aufruf mit `pauses` gleich den Uhr-Pausen, `start == writtenStart`, `end == writtenEnd`. Given 10 s Wand und 8 s Pause, Then null Aufrufe, Ergebnis `.skipped`. Fehler des Loggers werden weiter durchgereicht.
- **AC-9 (UI-Test): Uhr erst nach Countdown.** Given Start des Programms mit Countdown (Launch-Argument setzt `countdownBeforeStart` auf einen kurzen Wert), When der Countdown läuft, Then ist die Rundenanzeige nicht sichtbar; When er endet, Then zeigt die Rundenanzeige Übung 1 und Runde 1. Given Abbruch im Countdown, Then schließt die Karte ohne Effort-Sheet (kein Schreibvorgang; der Schreibverzicht selbst ist über die Konstruktion `clock == nil` und den Simulator-Durchlauf belegt, im Simulator entsteht ohnehin kein Eintrag, #122).
- **AC-10 (Simulator): Ringe starten bei null.** Given Programm mit Countdown, When der Countdown endet, Then beginnen Gesamtring und Phasenring bei null (Screenshot unmittelbar nach dem Countdown; kein Vorrücken um die Countdown-Dauer). Nachweis nur im Simulator-Durchlauf, ergänzt durch AC-9.
- **AC-11 (Simulator): Ende vor dem Schlussgong.** Given Programm läuft, When es natürlich oder manuell endet, Then wird die Uhr beendet, bevor Live Activity endet und der Schlussgong startet. Die Reihenfolge in der View ist nicht unit-testbar; Nachweis: Quelltextprüfung (`clock?.end(at: Date())` steht vor dem Sleep des Gongs) und Simulator-Durchlauf beider Enden (manuell, natürlich), ohne Absturz und mit unveränderter Tonfolge.
- **AC-12 (Unit plus Simulator): Doppelaufruf schreibt nicht doppelt.** Given `endSession` wird zweimal kurz nacheinander ausgelöst (manuell und natürlich), Then wird genau einmal geschrieben und `close()` genau einmal aufgerufen. Unit-Anteil: `WorkoutSessionLog.write` bei bereits beendeter Uhr und zweitem `end` ändert Ende nicht. Der Wächter selbst (`sessionEnded = true` vor dem ersten `await`) ist View-Code: Nachweis per Quelltextprüfung (Flag steht vor jedem `await`) und Simulator-Durchlauf (Doppeltippen auf „Beenden“, ein Effort-Sheet).
- **AC-13 (Simulator): Live Activity mit Zeiten ab Countdown-Ende.** Given Programm mit Countdown, Then startet die Live Activity erst nach dem Countdown und ihre Endzeit entspricht `Countdown-Ende + Programmdauer` (nicht um die Countdown-Dauer früher). Nachweis: Quelltextprüfung (Start der Live Activity nach dem Setzen von Uhr und `phaseStart`) und die vorhandenen Live-Activity-UI-Tests als Regression.
- **AC-14 (Struktur): Umfang und Ziele.** Der Diff berührt nur die drei App-Dateien oben (plus Tests); `endSession` und alle neuen Funktionen haben höchstens 50 Zeilen; App-Diff höchstens 250 Zeilen; Build grün für iOS, Watch und Widget (Watch-Build prüft, dass `HealthKitManager.swift` dort weiter kompiliert).
- **AC-15 (Regression): Bestehende Tests grün.** Vollständige Unit-Suite und die UI-Tests `BackgroundMeditationUITests` (`test_backgroundForeground_sessionStillRunning`, `test_explicitStop_endsSession`), `LeanHealthTimerUITests` (`testWorkoutProgramShowsRoundCounter`, `testGuidedWorkoutPauseButtonIsBelowProgressRing`, Live-Activity-Tests :3204/:3284), `WorkoutHintUITests` (:218), `WorkoutSoundUITests` (:22/:76); Aufruf nur über `./Scripts/run-uitests.sh Klasse/Methode`, Nachweis nur mit `Executed N tests`, N ≥ 1.

## Test Plan

Geplante Tests je AC:

| AC | Test | Art |
|---|---|---|
| AC-1 | `testPausenIntervalleDerUhr`, `testOffenePauseWirdBisZumEndeIntervall`, `testDoppelteUndUnpassendeAufrufeAendernKeinePause` | Unit, `WorkoutSessionClockTests` |
| AC-2 | `testAktiveDauerAusIntervallen`, `testOffenePauseZaehltBisZumEnde` | Unit |
| AC-3 | `testSchwelleGrenzwerteAufAktiverZeit` (3,0 und 3,1 s), `testZehnSekundenWandAchtPauseWirdVerworfen` | Unit |
| AC-4, AC-5 | `testEventsLeer`, `testEventsEinIntervall`, `testEventsZweiIntervalleSortiert`, `testEventsWerdenAufSpanneGeklemmt`, `testEventsLaengeNullVerworfen`, `testPauseBisEndeLiefertNurPause` | Unit, neu `HealthKitWorkoutEventsTests` |
| AC-6 | `testKalorienAusAktivenSekunden`, `testKalorienOhnePausenWieBisher` | Unit, `HealthKitWorkoutEventsTests` |
| AC-7 | `testLogWorkoutStandardwertOhnePausenOhneEvents` | Unit, `HealthKitWorkoutEventsTests` |
| AC-8 | `testSchreibwegReichtPausenDurch`, `testSchreibwegUeberspringtZehnWandAchtPause`, bestehend `testSchreibwegReichtFehlerDurch` | Unit, `WorkoutSessionClockTests` |
| AC-9 | UI-Test `testWorkoutProgramStartetErstNachCountdown` (Launch-Argument für kurzen Countdown); vor dem ersten Lauf Aussagekraft prüfen (RED muss an fehlender Verzögerung scheitern, nicht am Fehlen eines Elements) | UI |
| AC-10, AC-11, AC-13 | Simulator-Durchlauf, Screenshots | nur Simulator |
| AC-12 | Unit-Anteil in `WorkoutSessionClockTests`, Rest Simulator | Unit plus Simulator |
| AC-14 | Diff- und Zeilenzählung, Builds iOS, Watch, Widget | Struktur |
| AC-15 | Regression UI und vollständige Unit-Suite | Regression |

Umstellung der vier Charakterisierungstests aus Schnitt 1 in `WorkoutSessionClockTests.swift` (Kommentar „dokumentiert heutiges Verhalten, Änderung in #35 Schnitt 2“ entfällt, stattdessen neue Aussage):

- [ ] :133 `testHeuteWerdenPausenInDieGeschriebeneDauerGezaehlt` wird umbenannt in `testPausenWerdenAlsPauseUebergebenUndNichtAbgezogen`: Sitzung 120 s mit 30 s Pause; der Fake bekommt Start/Ende über die volle Spanne **und** die Pause als Intervall; `activeDuration == 90`.
- [ ] :214 (Mindestdauer-Wandzeit, `testHeuteHatDieMindestdauerWandzeitBasis`) wird umbenannt in `testMindestdauerZaehltAktiveZeit`: 10 s Wand, 8 s Pause, Then `meetsMinimum == false` und `write` ruft den Logger nicht auf (Umkehr der heutigen Aussage).
- [ ] :232 (`testHeuteLiegtDasEndeNachDemSchlussgong`) wird umbenannt in `testEndeIstDerUebergebeneZeitpunktOhneGong`: Aussage nur auf Uhr-Ebene (Ende = übergebener Zeitpunkt, Logger bekommt exakt diesen). Dass die View das Ende vor dem Gong übergibt, steht in AC-11 (nur Simulator und Quelltextprüfung).
- [ ] :248 (`testHeuteStartetDieSitzungBeiErzeugungUndCountdownZaehltMit`) wird umbenannt in `testStartIstDerUebergabezeitpunktNachDemCountdown`: Uhr wird mit dem Zeitpunkt des Countdown-Endes angelegt, `writtenStart` entspricht ihm; Zeit vor der Anlage kommt nicht vor.
- [ ] Unit-Suite vollständig grün (`Executed N tests`, N ≥ 1)
- [ ] RED-Beleg: neue und umgestellte Tests scheitern zuerst (Übersetzungsfehler für fehlende `pauses`/`workoutEvents`, danach Assertion-Fehler)
- [ ] Kopfkommentar `SessionDurationTests.swift` auf Schnitt 2 nachgeführt
- [ ] Builds iOS, Watch, Widget grün
- [ ] Simulator-Durchlauf (kein Gerät von Henning): Countdown, Start, Pause und Fortsetzen, manuelles Ende, zweiter Lauf bis zum natürlichen Ende, Doppeltippen auf „Beenden“; Screenshots nach Countdown, in Pause und beim Ende

## Nicht in Scope

- Die Parallelrechnung `pausedSessionAccum` / `pausedPhaseAccum` in der Karte (Ringe, Live Activity): bleibt bestehen, Zusammenführung mit der Uhr gehört zu Schnitt 4.
- Freies Workout (`WorkoutTab`), Meditation, Atem: eigener Pfad, unverändert.
- Einstellung `countdownBeforeStart` (geteilt mit MeditationTab und SettingsSheet).
- Watch-Logik: unverändert; der Watch-Build muss grün bleiben.
- Felder für #49 (Programm-Kennung, beendet/abgebrochen, Ablage): Schnitt 3.
- Health-Berechtigung auf dem Programm-Weg: #122.
- Herauslösen der Phasen-Engine und der dreifach duplizierten Live-Activity-Rechnung: Schnitt 4.
- Hintergrund-Verhalten (BUG-25d): unverändert.

## Risiken

- **Countdown ist mehr als „Uhr später anlegen“:** Ringe und Phasen-Timer laufen heute während des Countdowns mit. Variante A (Ringe erst bei Uhr) ist der größte Zeilentreiber und die sichtbarste Änderung; Simulator-Durchlauf Pflicht.
- **`.task` kann den Start zweimal auslösen:** Wächter `clock == nil` in `beginSessionAfterCountdown`.
- **Zeilenbudget:** Zielwert 90 bis 110, Grenze 250; bei Überschreitung STOP und Rückfrage, Grenze nie selbst anheben. Funktionen höchstens 50 Zeilen.
- **Health-Schreibweg:** Alle Workout-Arten nutzen dieselbe Funktion; der Standardwert hält die anderen unverändert (AC-7). Watch-Ziel kompiliert `HealthKitManager.swift` (AC-14).
- **Karte nicht direkt testbar:** Reihenfolge Ende vor Gong und Doppelaufruf-Wächter sind View-Code; abgesichert durch Quelltextprüfung, UI-Test, Simulator-Durchlauf, nicht durch Unit-Test (AC-11, AC-12).

## Annahmen, ungeprüft

- `finishWorkout` rechnet `duration` aus `addWorkoutEvents` wie in der Apple-Dokumentation für `HKWorkout` beschrieben (aktive Zeit nach `.pause`/`.resume`). Dass der Builder dieselbe Rechnung beim Abschluss anwendet, steht nicht wörtlich in der Doku.
- Eine Pause ohne `.resume` bis zum Ende wird von HealthKit akzeptiert (Pause gilt bis Ende, zählt nicht). Deshalb wird bei Pause bis Ende kein `.resume` exakt auf der Endzeit geschrieben.
- Der Simulator schreibt ohne Health-Freigabe nichts (#35, #122). Belegbar sind die Annahmen daher nur auf dem Gerät, und das nur mit ausdrücklicher PO-Freigabe („jetzt ist ein Test möglich“); ohne Freigabe bleibt der Beleg die Unit-Prüfung der Events-Funktion plus Doku.

## Quellen der Recherche (2026-11-26)

- Apple, `HKWorkoutEvent`: https://developer.apple.com/documentation/healthkit/hkworkoutevent (Pause schaltet inaktiv, Resume aktiv; Datum zwischen Start und Ende; redundante Events ohne Wirkung)
- Apple, `HKWorkout.duration`: https://developer.apple.com/documentation/healthkit/hkworkout/duration (Dauer = Zeit im aktiven Zustand)
- Apple Developer Forums: https://developer.apple.com/forums/thread/649276 (Fallbericht zu Pausen und Dauer)

## Definition of Done

- [ ] AC-1 bis AC-15 nachgewiesen, im Protokoll `Executed N tests` mit N ≥ 1
- [ ] Vollständige Unit-Suite und die Regression-UI-Tests grün
- [ ] Neuer UI-Test für den Countdown grün und vor Implementation RED belegt
- [ ] Build grün für iOS, Watch und Widget
- [ ] Zeilenzählung: App-Diff ≤ 250, Funktionen ≤ 50, nur die genannten Dateien
- [ ] Simulator-Durchlauf mit Screenshots vor der Übergabe (AC-10, AC-11, AC-12, AC-13)
- [ ] Adversary-Prüfung: Verdict VERIFIED
- [ ] Kein Start auf Geräten von Henning ohne wörtliche Freigabe

## Changelog

- 2026-11-26: Angelegt als Rundenspec für #35 Schnitt 2 (Pausen als HealthKit-Events, Countdown zählt nicht, Ende vor Schlussgong, Schwelle auf aktive Zeit, Doppelaufruf-Wächter).
