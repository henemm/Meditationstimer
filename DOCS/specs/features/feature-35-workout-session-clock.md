---
entity_id: feature-35-workout-session-clock
type: feature
created: 2026-11-26
updated: 2026-11-26
status: draft
workflow: fix-35-workout-sitzung
issue: 35
---

# Schnitt 1: Sitzungsuhr und Schreib-Schnittstelle für Workout-Programme (#35)

## Approval

- [ ] Approved

Freigabe dieser Rundenspec durch den PO.

## Purpose

Heute lässt sich nicht beweisen, welche Start- und Endzeit ein geführtes Workout-Programm nach HealthKit schreibt: Die Zeitrechnung steckt inline in `WorkoutProgramSessionCard`, und der Schreibaufruf geht fest an `HealthKitManager.shared`. Schnitt 1 löst beides heraus: ein reiner Werttyp `WorkoutSessionClock` (Zeiten von außen gegeben, keine `Date()`-Aufrufe darin) und ein Protokoll `WorkoutLogging`, das die Karte einspeisen lässt. Das Verhalten der App bleibt **exakt wie heute**; neu ist nur, dass es per Unit-Test festgehalten ist. Voraussetzung für die Verhaltensänderungen (Schnitt 2) und für #49.

Sichtbar für Henning: nichts.

## Source

- Kontext und Analyse: `DOCS/context/fix-35-workout-sitzung.md` (verbindlich: „Analysis“, „Festlegung für die Spec (Schnitt 1)“)
- Bezug: `DOCS/specs/bugfix/BUG-25d-hintergrund-workout.md` (Hintergrund-Einschränkung bleibt unverändert)
- Vorbild für herausgelösten, getesteten Zeittyp: `Services/TwoPhaseTimerEngine.swift`

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine (lokale Entscheidung; kippt keine bestehende ADR). Verworfene Alternativen: B (nur Schreib-Protokoll — beweist keine Dauer), A voll in einer Runde (sprengt 250 Zeilen, zieht Live Activity mit).

Gewählt ist **A'**: Uhr als Werttyp plus Schreib-Protokoll, in Schnitten (Schnitt 1 Umbau, 2 Semantik, 3 #49-Felder, 4 Phasen-Engine).

Alternativen, verworfen für diese Runde:
- **A voller Sitzungstyp** (State, Pause, Live-Activity-Rechnung, Ende in einem `@MainActor`-Typ): beweist mehr, kostet aber 200 bis 300 Zeilen und sprengt die Grenze; Live-Activity-Rechnung ist dreifach dupliziert und gehört in eine eigene Runde.
- **B nur Protokoll**: beweist nur „`logWorkout` wurde gerufen“, die Zeiten blieben inline und unprüfbar. Ziel verfehlt.

**Platzierung: `Meditationstimer iOS/Workout/WorkoutSessionClock.swift`** (synchronisierte Gruppe), nicht `Services/`.
- Grund 1: `Services/` ist keine synchronisierte Gruppe; eine neue Datei bräuchte händische Einträge in `project.pbxproj` (Dateireferenz, Gruppe, Sources-Phase), die der Edit-Gate und das Zeilenbudget unnötig belasten.
- Grund 2: Einziger Nutzer ist die iOS-Karte. Das Protokoll wird per `extension HealthKitManager: WorkoutLogging {}` in der neuen Datei angehängt; `Services/HealthKitManager.swift` (auch vom Watch-Ziel kompiliert) bleibt unberührt.
- Grund 3: Präzedenz: Die Dateien von #57 liegen in `Meditationstimer iOS/Claude/` ohne pbxproj-Eingriff.
- Risiko: Die Ausnahmemengen der Gruppe nennen nur Watch (`auftakt.caf`, `Localizable.xcstrings`) und Widget (`Localizable.xcstrings`, `MeditationActivityAttributes.swift`). Ob eine neue Datei im iOS-Ordner auch ins Watch-Ziel gelangt, ist deshalb im Abschluss per Build des Watch-Ziels zu belegen (AC-8). Gelangt die Datei ins Watch-Ziel, ist das unerwünscht (toter Code dort, ggf. Build-Fehler bei iOS-only-APIs): dann wird sie per Ausnahme im pbxproj aus dem Watch-Ziel genommen; das wäre die einzige pbxproj-Änderung und im Bericht zu nennen. Rückfall: `Services/` mit pbxproj-Einträgen nur im iOS-Ziel.

## Affected Files

App-Code (2 Dateien, Zielwert 90 bis 130 Zeilen, Grenze 250, Funktionen höchstens 50 Zeilen):

| Datei | Änderung | Inhalt | ca. Zeilen |
|---|---|---|---|
| `Meditationstimer iOS/Workout/WorkoutSessionClock.swift` | neu | `WorkoutSessionClock`, `EndReason`, Protokoll `WorkoutLogging`, Konformität `HealthKitManager`, Schreibhelfer `WorkoutSessionLog` | 70 bis 90 |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | geändert | Karte: Uhr und Logger statt Inline-Rechnung; Live-Activity-Rechnung, Sounds, Sleeps, Phasen-Engine unverändert | 20 bis 40 |

Tests (zählen nicht zum Budget):

| Datei | Änderung |
|---|---|
| `LeanHealthTimerTests/WorkoutSessionClockTests.swift` | neu |
| `LeanHealthTimerTests/SessionDurationTests.swift` | Kopfkommentar Zeilen 20 bis 36 aktualisieren |

`WorkoutTab.swift` bleibt unverändert (einziger Aufrufer, `WorkoutProgramSessionCard(set:close:)` muss weiter ohne Logger-Argument übersetzen). Kein Eingriff in Watch, Widget, Info.plist, Entitlements, AppStorage-Schlüssel.

## Dependencies

| Abhängigkeit | Art | Hinweis |
|---|---|---|
| `Services/HealthKitManager.swift` (`logWorkout`) | genutzt, unverändert | Konformität zu `WorkoutLogging` per Extension in der neuen Datei |
| `WorkoutTab.swift` (Aufrufer der Karte) | unverändert | Logger-Parameter mit Standardwert `HealthKitManager.shared` |
| `LiveActivityController`, `StreakManager`, `SoundPlayer` | unverändert | bleiben in der View |
| #49 (Tagebuch) | nachgelagert | nutzt die Uhr ab Schnitt 3 |
| #122 (Health-Freigabe Programm-Weg) | getrennt | erklärt fehlende Einträge im Simulator |

## Expected Behavior

### `WorkoutSessionClock` (Sendable struct, Foundation only)

- `init(start: Date)`: Sitzungsbeginn.
- `mutating pause(at: Date)`: nur wirksam, wenn nicht pausiert; sonst ignoriert.
- `mutating resume(at: Date)`: nur wirksam, wenn pausiert; sonst ignoriert.
- `mutating end(at: Date, reason: EndReason)`: nur der **erste** Aufruf wirkt; weitere ändern nichts. `EndReason` ist `.natural` oder `.manual`.
- `writtenStart: Date`: immer `start` (heutige Semantik, Countdown eingeschlossen).
- `writtenEnd: Date?`: das übergebene Ende, `nil` solange nicht beendet. Pausen werden **nicht** abgezogen.
- `wallDuration: TimeInterval`: `writtenEnd − start`, ohne Ende `0`.
- `activeDuration: TimeInterval`: `wallDuration` minus alle Pausenzeiten; eine beim Ende noch offene Pause zählt bis zum Ende. Wird berechnet, in Schnitt 1 **nicht** verwendet.
- `meetsMinimum: Bool`: `wallDuration > 3` (strikt größer, wie heute `distance(to:) > 3`).
- `reason: EndReason?`.
- Keine Methode ruft `Date()` auf.

### `WorkoutLogging` und Schreibhelfer

- `protocol WorkoutLogging { func logWorkout(start: Date, end: Date, activity: HKWorkoutActivityType) async throws -> HKWorkout? }`; `HealthKitManager` erfüllt es über eine leere Erweiterung (Signatur identisch zu heute, der Standardwert `activity` bleibt am konkreten Typ).
- `WorkoutSessionLog.write(clock:activity:logger:) async throws -> Result` mit `Result = .skipped` (Mindestdauer nicht erreicht oder nicht beendet) oder `.written(HKWorkout?)`. Bei erfüllter Mindestdauer ruft es `logger.logWorkout(start: clock.writtenStart, end: clock.writtenEnd, activity:)` genau einmal; sonst gar nicht. Fehler des Loggers werden durchgereicht (die Karte fängt sie wie heute und gibt sie per `print` aus).

### Karte `WorkoutProgramSessionCard`

- Neue injizierbare Abhängigkeit `var logger: any WorkoutLogging = HealthKitManager.shared` (Standard-Initialisierer, Aufrufer unverändert).
- `@State private var clock = WorkoutSessionClock(start: .now)`; `sessionStart` bleibt als berechnete Eigenschaft `clock.start`, damit Ringe, Phasen und Live-Activity-Rechnung (Zeilen 463, 492, 679, 681, 766, 807 bis 876) unverändert bleiben.
- `togglePause`: ruft zusätzlich `clock.pause(at:)` und `clock.resume(at:)` mit demselben `Date()` wie die bestehende Rechnung; `pausedSessionAccum` und `pausedPhaseAccum` bleiben bestehen.
- `endSession(manual:)`: Reihenfolge unverändert (Idle-Timer, Live Activity beenden, Schlussgong und Wartezeit bzw. 0,3 s, **danach** `Date()` als Ende). Dieses `Date()` geht in `clock.end(at:reason:)` (`manual ? .manual : .natural`); das Schreiben läuft über `WorkoutSessionLog.write(clock:activity: .highIntensityIntervalTraining, logger:)`. Streak-Update, Effort-Sheet, `close()`, `sessionEnded`-Flag und der Wächter an derselben Stelle wie heute.

### Heutiges Verhalten, das erhalten bleibt (Charakterisierung)

1. Start = Erzeugungszeit der Karte, Countdown zählt mit.
2. Pausen werden nicht abgezogen: HealthKit bekommt `start … Ende` über die volle Spanne.
3. Ende = `Date()` nach Live-Activity-Ende und Schlussgong (bzw. 0,3 s bei Abbruch).
4. Mindestdauer 3 s auf Wandzeit, strikt größer.
5. Der Doppelaufruf-Wächter `sessionEnded` wird erst nach den beiden `await` gesetzt (bekanntes Fenster, Fix in Schnitt 2).

## Acceptance Criteria

„Unit“ = `LeanHealthTimerTests/WorkoutSessionClockTests.swift` (XCTest, `@testable import Lean_Health_Timer`, deutsche `testXyz`-Namen). Alle Zeiten werden injiziert (feste Basis `Date(timeIntervalSinceReferenceDate: 0)` plus Sekunden).

- **AC-1 (Unit): Grundzeiten.** Given Start t0, Ende t0+60 `.natural`, Then `writtenStart == t0`, `writtenEnd == t0+60`, `wallDuration == 60`, `activeDuration == 60`, `reason == .natural`. Given noch nicht beendet, Then `writtenEnd == nil`, `wallDuration == 0`, `meetsMinimum == false`. Test: `testGrundzeitenEinfacheSitzung`.
- **AC-2 (Unit): Aktive Dauer zieht Pausen ab.** Given Start t0, pause t0+10, resume t0+25, pause t0+40, resume t0+45, Ende t0+60, Then `wallDuration == 60`, `activeDuration == 40`. Given Ende während offener Pause (pause t0+30, Ende t0+50), Then `activeDuration == 30`. Tests: `testAktiveDauerZiehtPausenAb`, `testOffenePauseZaehltBisZumEnde`.
- **AC-3 (Unit): Ungültige Aufrufe sind wirkungslos.** Doppeltes `pause`, `resume` ohne Pause, und ein zweites `end` ändern nichts (Ende und Grund des ersten Aufrufs bleiben). Test: `testDoppelteUndUnpassendeAufrufeAendernNichts`.
- **AC-4 (Unit): Mindestdauer 3 Sekunden auf Wandzeit.** Dauer 2,9 und 3,0 Sekunden: `meetsMinimum == false`; 3,1 Sekunden: `true`. Eine Sitzung mit 10 s Wandzeit, davon 8 s Pause (aktiv 2 s), erfüllt die Mindestdauer. Tests: `testMindestdauerGrenzwerte`, `testMindestdauerZaehltWandzeitNichtAktiveZeit`.
- **AC-5 (Unit): Endgrund.** `.manual` und `.natural` werden unverändert gehalten. Test: `testEndgrundWirdGehalten`.
- **AC-6 (Unit, Fake-Logger): Der Schreibweg reicht Start und Ende der Uhr durch.** Given `FakeWorkoutLogger` (zeichnet Aufrufe auf, gibt `nil` zurück) und eine beendete Uhr (Start t0, Ende t0+120), When `WorkoutSessionLog.write(clock:activity:.highIntensityIntervalTraining, logger:)`, Then genau ein Aufruf mit `start == t0`, `end == t0+120`, `activity == .highIntensityIntervalTraining`, Ergebnis `.written`. Given Dauer 3 s oder eine nicht beendete Uhr, Then null Aufrufe, Ergebnis `.skipped`. Given ein Logger, der wirft, Then wirft `write` denselben Fehler durch. Tests: `testSchreibwegReichtStartUndEndeDurch`, `testSchreibwegUeberspringtKurzeSitzung`, `testSchreibwegReichtFehlerDurch`.
- **AC-7 (Unit): Charakterisierung, dokumentiert heutiges Verhalten, Änderung in #35 Schnitt 2.** Jeder dieser Tests trägt im Kommentar wörtlich „dokumentiert heutiges Verhalten, Änderung in #35 Schnitt 2“:
  - `testHeuteWerdenPausenInDieGeschriebeneDauerGezaehlt`: Sitzung 120 s mit 30 s Pause, Fake-Logger bekommt Spanne 120 s (nicht 90 s), `activeDuration == 90`.
  - `testHeuteLiegtDasEndeNachDemSchlussgong`: Ende = übergebener Zeitpunkt nach dem Gong (t0+60 Sitzung, Ende t0+62,3), Logger bekommt t0+62,3, nicht t0+60.
  - `testHeuteStartetDieSitzungBeiErzeugungUndCountdownZaehltMit`: `writtenStart` bleibt der bei `init` gegebene Zeitpunkt, auch wenn die erste Pause erst später liegt.
  - `testHeuteHatDieMindestdauerWandzeitBasis` (siehe AC-4, zweiter Fall) trägt dieselbe Markierung.
- **AC-8 (Struktur): Karte nutzt Uhr und Protokoll, nichts anderes ändert sich.** Prüfung per Quelltext und Build:
  - `WorkoutProgramsView.swift` enthält `WorkoutSessionClock` und `WorkoutLogging`; `HealthKitManager.shared.logWorkout` kommt in der Karte nicht mehr vor (nur als Standardwert des Loggers).
  - `WorkoutSessionClock.swift` enthält kein `Date()` und kein `Date.now`.
  - Der Diff berührt nur die zwei App-Dateien oben (plus Tests); insbesondere nicht `WorkoutTab.swift`, `HealthKitManager.swift`, `LiveActivityController.swift`, `ProgressRingsView`-Phasenlogik, `project.pbxproj` (Ausnahme: nur falls Watch-Build es erzwingt, dann im Bericht begründet).
  - Reihenfolge in `endSession` unverändert (Live Activity beenden, Gong und Sleep, dann `Date()` für das Ende).
  - Build grün für iOS (Simulator `iPhone 17 Pro`, iOS 27.2), Watch und Widget; die neue Datei erscheint nicht fehlerhaft im Watch-Ziel.
  - Produktiv-Diff höchstens 250 Zeilen, keine Funktion über 50 Zeilen.
- **AC-9 (Doku): Kopfkommentar `SessionDurationTests.swift`.** Zeilen 20 bis 36 sagen nicht mehr, der Programm-Weg sei nicht prüfbar. Stattdessen: Verweis auf `WorkoutSessionClockTests` und `WorkoutSessionLog`, mit dem Hinweis, dass Verbindungsstück View und Live-Activity weiter nicht unit-geprüft sind und die Semantik in Schnitt 2 folgt. Nachweis: Diff-Sicht, Suche nach „bewusst NICHT getan“ ergibt keinen Treffer.
- **AC-10 (Regression): Bestehende Tests grün.** Vollständige Unit-Suite grün; die bestehenden UI-Tests zum Workout-Programm (Start, Pause, Ende; u. a. in `BackgroundMeditationUITests` die Fälle mit `startFirstWorkoutSession`) bleiben grün, Aufruf nur über `./Scripts/run-uitests.sh Klasse/Methode`. Nachweis nur mit `Executed N tests`, N ≥ 1.

## Test Plan

- [ ] Unit (`WorkoutSessionClockTests.swift`): AC-1 bis AC-7. GIVEN feste Zeitpunkte und `FakeWorkoutLogger` WHEN Pausen, Ende, Schreiben THEN Zeiten, Dauer, Mindestdauer und aufgezeichnete Logger-Aufrufe wie beschrieben
- [ ] RED-Beleg: Tests scheitern zuerst am Übersetzungsfehler „cannot find `WorkoutSessionClock`/`WorkoutLogging`/`WorkoutSessionLog`“ im Testziel
- [ ] Kopfkommentar `SessionDurationTests.swift` aktualisiert (AC-9)
- [ ] Bestand: vollständige Unit-Suite grün (Aufruf wie in `CLAUDE.md`, `Executed N tests`, N ≥ 1)
- [ ] Regression UI: bestehende Workout-Programm-UI-Tests grün (AC-10)
- [ ] Build grün für iOS, Watch, Widget (AC-8)
- [ ] Diff-Prüfung und Zeilenzählung (AC-8)
- [ ] Durchlauf im Simulator `iPhone 17 Pro` (iOS 27.2): App starten, Workout-Tab, Programm starten, pausieren, fortsetzen, vorzeitig beenden; zweiter Lauf bis zum natürlichen Ende (kurzes Programm). Erwartet: Ringe, Zeitanzeige, Live Activity, Töne, Schließen wie vor der Runde, kein Absturz; Screenshot. Kein Gerät von Henning. Ausnahme von der UI-Test-Pflicht, begründet: reiner Umbau ohne sichtbare Änderung; die bestehenden Workout-Programm-UI-Tests (AC-10) sichern die Oberfläche, ein neuer UI-Test könnte die Dauer ohnehin nicht prüfen (kein Health-Eintrag im Simulator ohne Freigabe, #122); dass im Simulator ohne Health-Freigabe kein Eintrag entsteht, ist bekannt (#122) und kein Fehler dieser Runde.

## Nicht in Scope

- Verhaltensänderungen (PO-Fragen 1 bis 4: Pausen, Countdown, Endzeit vor/nach Gong, Mindestdauer auf aktive Zeit): Schnitt 2.
- Doppelaufruf-Wächter `sessionEnded` korrigieren: Schnitt 2, als benannter Fix.
- Health-Berechtigung auf dem Programm-Weg: #122.
- Felder für #49 (Programm-Kennung, beendet/abgebrochen, Ablage): Schnitt 3.
- Herauslösen der Phasen-Engine aus `ProgressRingsView` und der dreifach duplizierten Live-Activity-Rechnung: Schnitt 4.
- Freies Workout (`WorkoutTab`), Atem, Meditation: eigener Pfad, unverändert.
- Verwendung von `activeDuration` für HealthKit oder Kalorien (nur berechnet).
- Hintergrund-Verhalten (BUG-25d): unverändert.

## Risiken

- **Verhaltensabweichung beim Umbau.** `togglePause` und `endSession` sind die Stellen; die Charakterisierungstests und der Simulator-Durchlauf sichern sie. Reihenfolge der `await` darf sich nicht ändern.
- **Standardwert mit `@MainActor`-Zugriff.** `HealthKitManager.shared` als Standardwert in der View-Struktur kann unter Swift 6.4 im Swift-5-Modus eine Isolationswarnung geben; Lösung nur durch Anpassung des Standardwerts (z. B. Optional mit Auflösung zur Laufzeit), ohne Umfang zu ändern; im RED-/GREEN-Bericht begründen.
- **Zielmitgliedschaft.** Siehe Architektur-Entscheidung; durch den Watch-Build belegt.
- **Zeilenbudget.** Zielwert 90 bis 130, Grenze 250; bei Überschreitung STOP und Rückfrage, Grenze nie selbst anheben.
- **Karte nicht direkt testbar.** Das View-Klebstoffstück (Aufruf der Helfer in `endSession`) wird nur durch Quelltextprüfung, UI-Regression und Simulator-Durchlauf gesichert, nicht per Unit-Test; das ist für Schnitt 1 akzeptiert und im Kopfkommentar der Tests benannt.

## Definition of Done

- [ ] AC-1 bis AC-10 nachgewiesen, im Protokoll `Executed N tests` mit N ≥ 1
- [ ] Vollständige Unit-Suite und bestehende Workout-Programm-UI-Tests grün
- [ ] Build grün für iOS (`iPhone 17 Pro`, iOS 27.2), Watch und Widget
- [ ] Zeilenzählung: Produktiv-Diff ≤ 250, Funktionen ≤ 50, nur die genannten Dateien
- [ ] Durchlauf im Simulator (Start, Pause, Ende, natürliches Ende) mit Screenshot vor der Übergabe
- [ ] Adversary-Prüfung: Verdict VERIFIED
- [ ] Änderungen am Gerät von Henning: keine, kein Start auf seinen Geräten

## Changelog

- 2026-11-26: Angelegt als Rundenspec für #35 Schnitt 1 (Uhr-Werttyp `WorkoutSessionClock` und Protokoll `WorkoutLogging`, Verhalten unverändert, Charakterisierungstests).
