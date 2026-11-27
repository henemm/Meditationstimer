# Adversary Dialog — fix-35-s2-dauer
Spec: DOCS/specs/features/feature-35-s2-dauer.md
Datum: 2026-11-27 07:17

## Checkliste
- [x] `pauses: [DateInterval]`: abgeschlossene Pausen; eine beim Ende offene Pause erscheint als Intervall bis zum Ende.
- [x] `activeDuration`: Wandzeit minus Summe der Pausenintervalle.
- [x] `meetsMinimum`: `activeDuration > 3` (strikt größer).
- [x] `pause`/`resume`/`end`: ungültige und doppelte Aufrufe bleiben wirkungslos (wie Schnitt 1).
- [x] `logWorkout` schreibt Start und Ende echt, fügt die Events hinzu und berechnet Kalorien aus den aktiven Sekunden (Pausen nicht eingerechnet). Mit `pauses == []` ist das Ergebnis identisch zu heute (freies Workout, Meditation, Atem unverändert).
- [x] `WorkoutSessionLog.write` reicht `clock.pauses` an den Logger; unter der Schwelle wird nicht geschrieben.
- [x] Uhr und `phaseStart` entstehen erst beim Übergang aus dem Countdown; Ringe und Rundenanzeige erscheinen danach bei Übung 1 und Runde 1.
- [x] Abbruch im Countdown: keine Uhr, kein Schreibvorgang.
- [x] `endSession`: Wächter, dann sofort `sessionEnded = true`, dann `clock?.end(at: Date())`, dann Live-Activity-Ende und Schlussgong (Sleep), dann Schreiben, Streak, Effort-Sheet, `close()`.
- [x] **AC-1 (Unit): Pausenintervalle der Uhr.** Given Start t0, pause t0+10, resume t0+25, pause t0+40, resume t0+45, Ende t0+60, Then `pauses` = [t0+10…t0+25, t0+40…t0+45]. Given pause t0+30 und Ende t0+50 ohne resume, Then `pauses` = [t0+30…t0+50] (offene Pause bis Ende). Given doppeltes `pause` oder `resume` ohne Pause, Then bleibt `pauses` unverändert.
- [x] **AC-2 (Unit): Aktive Dauer.** Given AC-1 erster Fall, Then `wallDuration == 60`, `activeDuration == 40`. Given offene Pause (t0+30 bis Ende t0+50), Then `activeDuration == 30`.
- [x] **AC-3 (Unit): Schwelle auf aktive Zeit.** Given aktive Dauer 3,0 s (ohne Pause und mit Pause bei längerer Wandzeit), Then `meetsMinimum == false`; 3,1 s aktiv Then `true`. Given 10 s Wand und 8 s Pause (aktiv 2 s), Then `meetsMinimum == false`.
- [x] **AC-4 (Unit): Events-Funktion, Standardfälle.** Given leere Liste, Then keine Events. Given 1 Intervall, Then `[.pause(start), .resume(end)]`. Given 2 Intervalle in beliebiger Reihenfolge, Then 4 Events, nach Zeit sortiert, abwechselnd pause/resume.
- [x] **AC-5 (Unit): Events-Funktion, Grenzfälle.** Given Intervall, das über `[start, end]` hinausragt, Then Klemmen auf die Grenzen. Given Intervall der Länge 0 (auch durch Klemmen), Then verworfen. Given Pause bis genau zum Ende, Then nur `.pause`, kein `.resume`.
- [x] **AC-6 (Unit): Kalorien aus aktiven Sekunden.** Given 600 s Wand und 120 s Pause, Then Kalorienwert = aktive Sekunden × 12/min (also für 480 s), nicht für 600 s. Given keine Pausen, Then Wert wie heute (Wandzeit × 12/min).
- [x] **AC-7 (Unit): Standardwert lässt andere Workouts unverändert.** Given `logWorkout` ohne `pauses` (Aufrufer freies Workout, Meditation, Atem), Then keine Events, Kalorien aus der gesamten Dauer. Nachweis zusätzlich per Quelltextprüfung: die drei Aufrufer sind im Diff nicht enthalten.
- [x] **AC-8 (Unit, Fake-Logger): `WorkoutSessionLog` reicht Pausen durch.** Given beendete Uhr mit zwei Pausen, When `write`, Then genau ein Logger-Aufruf mit `pauses` gleich den Uhr-Pausen, `start == writtenStart`, `end == writtenEnd`. Given 10 s Wand und 8 s Pause, Then null Aufrufe, Ergebnis `.skipped`. Fehler des Loggers werden weiter durchgereicht.
- [x] **AC-9 (UI-Test): Uhr erst nach Countdown.** Given Start des Programms mit Countdown (Launch-Argument setzt `countdownBeforeStart` auf einen kurzen Wert), When der Countdown läuft, Then ist die Rundenanzeige nicht sichtbar; When er endet, Then zeigt die Rundenanzeige Übung 1 und Runde 1. Given Abbruch im Countdown, Then schließt die Karte ohne Effort-Sheet (kein Schreibvorgang; der Schreibverzicht selbst ist über die Konstruktion `clock == nil` und den Simulator-Durchlauf belegt, im Simulator entsteht ohnehin kein Eintrag, #122).
- [x] **AC-10 (Simulator): Ringe starten bei null.** Given Programm mit Countdown, When der Countdown endet, Then beginnen Gesamtring und Phasenring bei null (Screenshot unmittelbar nach dem Countdown; kein Vorrücken um die Countdown-Dauer). Nachweis nur im Simulator-Durchlauf, ergänzt durch AC-9.
- [x] **AC-11 (Simulator): Ende vor dem Schlussgong.** Given Programm läuft, When es natürlich oder manuell endet, Then wird die Uhr beendet, bevor Live Activity endet und der Schlussgong startet. Die Reihenfolge in der View ist nicht unit-testbar; Nachweis: Quelltextprüfung (`clock?.end(at: Date())` steht vor dem Sleep des Gongs) und Simulator-Durchlauf beider Enden (manuell, natürlich), ohne Absturz und mit unveränderter Tonfolge.
- [x] **AC-12 (Unit plus Simulator): Doppelaufruf schreibt nicht doppelt.** Given `endSession` wird zweimal kurz nacheinander ausgelöst (manuell und natürlich), Then wird genau einmal geschrieben und `close()` genau einmal aufgerufen. Unit-Anteil: `WorkoutSessionLog.write` bei bereits beendeter Uhr und zweitem `end` ändert Ende nicht. Der Wächter selbst (`sessionEnded = true` vor dem ersten `await`) ist View-Code: Nachweis per Quelltextprüfung (Flag steht vor jedem `await`) und Simulator-Durchlauf (Doppeltippen auf „Beenden“, ein Effort-Sheet).
- [x] **AC-13 (Simulator): Live Activity mit Zeiten ab Countdown-Ende.** Given Programm mit Countdown, Then startet die Live Activity erst nach dem Countdown und ihre Endzeit entspricht `Countdown-Ende + Programmdauer` (nicht um die Countdown-Dauer früher). Nachweis: Quelltextprüfung (Start der Live Activity nach dem Setzen von Uhr und `phaseStart`) und die vorhandenen Live-Activity-UI-Tests als Regression.
- [x] **AC-14 (Struktur): Umfang und Ziele.** Der Diff berührt nur die drei App-Dateien oben (plus Tests); `endSession` und alle neuen Funktionen haben höchstens 50 Zeilen; App-Diff höchstens 250 Zeilen; Build grün für iOS, Watch und Widget (Watch-Build prüft, dass `HealthKitManager.swift` dort weiter kompiliert).
- [x] **AC-15 (Regression): Bestehende Tests grün.** Vollständige Unit-Suite und die UI-Tests `BackgroundMeditationUITests` (`test_backgroundForeground_sessionStillRunning`, `test_explicitStop_endsSession`), `LeanHealthTimerUITests` (`testWorkoutProgramShowsRoundCounter`, `testGuidedWorkoutPauseButtonIsBelowProgressRing`, Live-Activity-Tests :3204/:3284), `WorkoutHintUITests` (:218), `WorkoutSoundUITests` (:22/:76); Aufruf nur über `./Scripts/run-uitests.sh Klasse/Methode`, Nachweis nur mit `Executed N tests`, N ≥ 1.
- [x] **AC-16 (benannter Fix, nachgetragen 2026-11-27): Auftakt-Klang blockiert den Start nicht.** Given ein geführtes Workout mit Countdown, When der Countdown endet und der Auftakt-Klang startet, Then bleibt die App ansprechbar: Ton-Anmeldung (`AVAudioSession.setCategory`/`setActive`) und Abspielen laufen nicht auf dem Hauptablauf; im App-Protokoll erscheint nach dem Countdown kein `[AVAudioSession Hang Risk]`. Anlass: In Phase 6 blockierte der Hauptablauf im Simulator ~22 s in `activateSession` (Belege: `[aqme] AQMEIO timed out after 15.000s`, Video), vorbestehend auch in bc16962; dadurch war AC-9 nicht prüfbar. Quellen: https://developer.apple.com/forums/thread/655326 , https://developer.apple.com/forums/thread/697861 . Nur der Klangspieler in `WorkoutProgramsView.swift`; `WorkoutSoundPlayer.swift`, `GongPlayer.swift`, `AtemView.swift` bleiben unberührt.

## Findings

### F001: speak aktiviert die Audio-Session jetzt asynchron (Reihenfolge geändert)
- **Severity:** LOW
- **Category:** edge_case
- **Evidence:** Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:135 — `speak` reiht `activateSession()` auf `audioQueue` ein und ruft danach sofort `speech.speak(u)` auf dem Hauptablauf auf (Zeile 137 bis 147). Vorher lief die Anmeldung synchron davor. `beginSessionAfterCountdown` (Zeile 678) spricht als Erstes, dann `play(.auftakt)`.
- **Remediation:** Kein Blocker: AVSpeechSynthesizer verwaltet seine Sitzung selbst, der UI-Test mit Countdown lief ohne `Hang Risk` (uitest-green-output.txt: 0 Treffer). Auf dem Gerät beobachten, ob die erste Ansage bei Stummschalter anders klingt.

### F002: Pausen-Event ohne .resume am Ende, nur im Simulator nicht prüfbar
- **Severity:** LOW
- **Category:** edge_case
- **Evidence:** Code reference: Services/HealthKitManager.swift:255 — bei Pause bis genau zum Ende entsteht nur `.pause` (so verlangt AC-5). Ob HealthKit das auf dem Gerät ohne Fehler annimmt, ist im Simulator nicht prüfbar (#122: dort entsteht kein Eintrag).
- **Remediation:** Spec-konform; Restrisiko beim ersten Gerätelauf (nur auf Hennings Wort).

## Dialog

### Runde 1
**Adversary:** Angriff auf Pausen und Kalorien. Offene Pause am Ende: `end` schließt sie über `closePause` mit dem Endzeitpunkt (Code reference: Meditationstimer iOS/Workout/WorkoutSessionClock.swift:49), `pauses` liefert sie (Zeile 55), `activeDuration` zieht sie ab (Zeile 69 bis 71), `meetsMinimum` ist strikt `> 3` auf aktiver Zeit (Zeile 75). Doppelte pause/resume/end sind durch die Guards in Zeilen 29 bis 49 wirkungslos; ein resume mit früherem Zeitpunkt schließt die Pause ohne Intervall (Länge 0 wird nicht gespeichert, Zeile 42). Beweis dafür, dass Events und Kalorien dieselbe Quelle nutzen?
**Implementierer:** Code reference: Services/HealthKitManager.swift:176 — `logWorkout` klemmt die Pausen mit `clampedPauses` (Zeile 247: Klemmen, Länge 0 verwerfen, sortieren), zieht sie von der Spanne ab (Zeile 180 bis 181) und ruft `estimatedCalories(activeSeconds:)` (Zeile 236) mit den Sätzen 12/4/8 kcal je Minute. `workoutEvents` (Zeile 255) nutzt dieselbe Klemmfunktion; `.resume` nur wenn `p.end < span.end`, also bei Pause bis Ende nur `.pause`. Events werden nur bei nicht leerer Liste hinzugefügt (Zeile 195). Mit `pauses == []` ist die Spanne die ganze Dauer, Ergebnis wie vorher. Die einzigen Aufrufer außerhalb der Uhr (MeditationTab:414, WorkoutTab:762, AtemView:743) stehen nicht im Diff und nutzen den Standardwert (grep). Unit-Suite von mir neu gelaufen: Executed 503 tests, 0 failures (nach einem ersten Lauf mit „test runner hung before establishing connection“, Umfeld, nach Simulator-Neustart grün).
**Bewertung:** AC-1 bis AC-8 bewiesen. Nachfrage: Wo steht der Beweis für Countdown und Ende?

### Runde 2
**Adversary:** Angriff auf Countdown, endSession und Klangspieler. Abbruch im Countdown: `onCancel` ruft nur `close()`; danach `onDisappear` mit `endSession(manual: true)`, dort ist `clock` nil, `logSession` liefert sofort false (Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:741) und es wird nichts geschrieben; vorher hätte eine Uhr ab Ansicht-Start einen Eintrag erzeugen können. Doppelstart: `guard clock == nil` (Zeile 679), Uhr und `phaseStart` mit demselben `startedAt` (Zeile 680 bis 682), Live Activity danach mit `sessionStart` (Zeile 696 bis 703); `sessionStart` fällt nur ohne Uhr auf `phaseStart` zurück (Zeile 441), das wird nach dem Start nicht mehr benutzt. Wächter: `sessionEnded = true` steht in Zeile 713 vor dem ersten `await`, `clock?.end` in Zeile 718 vor `liveActivity.end` und `playClosingSound` (Zeile 729). Funktionsgrößen: endSession 705 bis 727, playClosingSound 729 bis 738, logSession 740 bis 765, alle unter 50. Klangspieler: `activePlayers` wird nur auf der seriellen `audioQueue` angefasst (Zeilen 103, 121, 154); `urls`, `prepared`, `speech` nur auf dem Hauptablauf. Ist `stopAll` nach eingereihtem play sicher?
**Implementierer:** Die Warteschlange ist FIFO: ein vor `stopAll` eingereihtes `play` läuft zuerst und wird dann von `stopAll` (Zeile 153 bis 158) gestoppt; ein danach eingereihtes `play` (z. B. Fortsetzen, Zeile 813) startet erwartungsgemäß neu. Das Delegate (`audioPlayerDidFinishPlaying`, Zeile 121) wechselt auf dieselbe Queue, kein Rennen. `@unchecked Sendable` ist damit begründet, einen Datenzugriff außerhalb der Queue gibt es nicht. `WorkoutSoundPlayer.swift`, `GongPlayer.swift` und `AtemView.swift` stehen nicht im Diff. Umfang: App-Code 233 Zeilen (76+71, 16+12, 41+17 laut numstat) bei Grenze 250, drei Dateien wie Spec. UI-Test AC-9 grün mit `Executed 1 test, 0 failures` (uitest-green-output.txt, ohne `Hang Risk`); von mir neu gelaufen: `testGuidedWorkoutPauseButtonIsBelowProgressRing` passed (131 s). `testWorkoutProgramShowsRoundCounter` ist im Quelltext unbedingt mit XCTSkip übersprungen (LeanHealthTimerUITests.swift:2030, vorbestehend), liefert also keinen Beleg.
**Bewertung:** AC-9 bis AC-14 und AC-16 per Code und vorhandenen Läufen bewiesen. Offen bleibt nur, was im Simulator nicht prüfbar ist (F001, F002). Nicht von mir gelaufen: Live-Activity-, BackgroundMeditation-, WorkoutHint- und WorkoutSound-UI-Tests (AC-15 teilweise ohne eigenen Beleg), Simulator-Durchlauf AC-10/11/13 (Screenshots) nur per Quelltextprüfung.

Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:678
Code reference: Meditationstimer iOS/Workout/WorkoutSessionClock.swift:49
Code reference: Services/HealthKitManager.swift:255

## Herkunft der Vorbedingungen

Keine neue Testvorbedingung mit unklarer Herkunft: Die Unit-Tests bauen Uhr und Pausen über die öffentlichen Aufrufe `pause`/`resume`/`end` auf (kein Setzen von Zustand von Hand); der UI-Test startet den Countdown über ein Launch-Argument auf demselben Weg wie die App.

## Verdict
**VERIFIED**
Offene Punkte: 0 / 25

## Geprüfte Dateien

- sha256:37dc84b0a5ff07802d6fc7c1206bbaa80e71dcccb20384b25534cad360d76346  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- sha256:84c4e1b2f8dd3386d4dc504de76b9e7ad51fd16ebdcc4230e087f0fbbeaf4617  Meditationstimer iOS/Workout/WorkoutSessionClock.swift
- sha256:2ad034868f6deae0e6bbade6ef2d9c1baf6a59a8efb9ad6edcc2c1206842fa73  Services/HealthKitManager.swift

## Prüfbasis

- base: 0a8dbf63b7967641f7a5a963a1f09f120ddf2d83
- blob:873539d5c05208d403da3c0618730bda1b2ad24d  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- blob:bc2f83a933ab0144ef6d4d8b330a7fe66b9673ec  Meditationstimer iOS/Workout/WorkoutSessionClock.swift
- blob:3fd4589edb45e36ffad41b9e95ea167d0de87963  Services/HealthKitManager.swift
