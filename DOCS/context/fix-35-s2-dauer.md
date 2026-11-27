# Context: #35 Schnitt 2 — Dauer nach PO-Entscheidung (fix-35-s2-dauer)

## Request Summary

PO-Entscheidung 2026-11-26 (Issue-Kommentar) für das geführte Workout-Programm:
1. **Pausen als Pause markieren:** HKWorkoutEvent `.pause`/`.resume` über den Builder; Start/Ende bleiben echt, Health rechnet aktive Dauer und Kalorien ohne Pausen.
2. **Countdown zählt nicht:** Training beginnt nach dem Countdown.
3. **Ende vor dem Schlussgong**, wie beim freien Workout.

Tech-Lead-Folgerungen: 3-s-Mindestschwelle auf aktive Zeit; Doppelaufruf-Wächter in `endSession` als benannter Fix; `endSession` (66 Zeilen) aufteilen (≤50 LoC). Charakterisierungstests aus Schnitt 1 werden sichtbar umgestellt.

Vorarbeit: `DOCS/context/fix-35-workout-sitzung.md`, `DOCS/specs/features/feature-35-workout-session-clock.md` (Schnitt 1, PR #125).

## Recherche (2026-11-26)

- Ein `HKWorkout` beginnt aktiv; `.pause` schaltet inaktiv, `.resume` wieder aktiv; `duration` = Zeit im aktiven Zustand. Event-Datum muss zwischen Start und Ende liegen; redundante Events (pause auf pausiert) wirken nicht.
  Quellen: https://developer.apple.com/documentation/healthkit/hkworkoutevent , https://developer.apple.com/documentation/healthkit/hkworkout/duration , https://developer.apple.com/forums/thread/649276
- Offen: Dass `HKWorkoutBuilder.addWorkoutEvents` beim `finishWorkout` dieselbe Rechnung anwendet, steht nicht wörtlich in der Doku → in der Analyse belegen (Simulator schreibt laut #35/#122 nichts; Beleg ggf. über Fake + Doku, Gerätenachweis nur mit PO-Freigabe).

## Related Files

| Datei | Rolle |
|---|---|
| `Meditationstimer iOS/Workout/WorkoutSessionClock.swift` | Uhr (`start` let :19, `pause` :30, `resume` :36, `end` :43, `activeDuration` :65, `meetsMinimum` :71 = Wandzeit > 3), `WorkoutLogging` :75, `WorkoutSessionLog.write` :82–96. Nur iOS-Ziel. Speichert nur `pausedTotal`, **keine Intervalle** |
| `Services/HealthKitManager.swift:175–240` | `logWorkout(start:end:activity:)` über `HKWorkoutBuilder` (:200); kcal = Wandzeit × 12/min; keine Events. Datei auch im Watch-Ziel, Teil in `#if os(iOS)` |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | `WorkoutProgramSessionCard` :417: Uhr bei View-Erzeugung :432, `phaseStart` :436, `.task` :522–535, Countdown-Cover :536–548, `beginSessionAfterCountdown` :670–691, `endSession(manual:)` :693–758 (Wächter :697, Flag erst :726/:752, Gong-Sleep :714–718, `clock.end(Date())` :724), `togglePause` :760–827; ProgressRingsView-Timer startet `onAppear` :986 → läuft während Countdown |
| `Meditationstimer iOS/Tabs/WorkoutTab.swift` | Vorbild freies Workout: Start nach Auftakt :548, `endDate = Date()` vor Gong :740, schreibt :762 |
| `LeanHealthTimerTests/WorkoutSessionClockTests.swift` | 14 Tests; 4 Charakterisierungstests umzustellen (:133, :214, :232, :248); `FakeWorkoutLogger` :26–35 |
| `LeanHealthTimerTests/SessionDurationTests.swift:30–36` | Kopfkommentar verweist auf Schnitt 2 |

## Existing Patterns

- Schreibweg ist bereits Builder-basiert → Events per `addWorkoutEvents` passen ohne Wechsel der API.
- `WorkoutSessionLog.write(clock:activity:logger:)` ist der prüfbare Nahtpunkt; Fake-Logger im Test.
- Freies Workout setzt den Start erst nach dem Vorlauf und nimmt das Ende vor dem Gong.

## Dependencies / Dependents

- `logWorkout`-Aufrufer: Programm (über Protokoll), WorkoutTab :762, MeditationTab :414, AtemView :743. Neuer Parameter mit Standardwert (`pauses: [DateInterval] = []`) lässt die drei direkten Aufrufer unverändert.
- `sessionStart` steuert ProgressRingsView (Gesamtring :884), Live Activity (:494, :681/683, :772, :815).
- `countdownBeforeStart` geteilt mit MeditationTab und SettingsSheet — nicht anfassen.

## UI-Tests (Regression)

`BackgroundMeditationUITests` (`test_backgroundForeground_sessionStillRunning`, `test_explicitStop_endsSession`), `LeanHealthTimerUITests` (`testWorkoutProgramShowsRoundCounter`, `testGuidedWorkoutPauseButtonIsBelowProgressRing`, LiveActivity :3204/:3284), `WorkoutHintUITests` :218, `WorkoutSoundUITests` :22/:76. Kein Test prüft den Programm-Countdown.

## Risks

1. **Countdown ist mehr als „Uhr später anlegen“:** Ringe/Phasen-Timer laufen heute während des Countdowns mit. Uhr muss änderbar/optional werden, `phaseStart` beim Start neu setzen, ProgressRingsView erst ab Start rendern/timen → sichtbare Verhaltensänderung (Ring beginnt nach Countdown). Größter LoC-Treiber.
2. **Kalorien:** PO: „Kalorien ohne Pausen“ → kcal aus aktiver Dauer, nicht Wandzeit.
3. **Pausen-Intervalle:** Uhr muss Intervalle speichern; offene Pause beim Ende → Pause-Event ohne Resume (gilt bis Ende, zählt nicht).
4. **Doppelaufruf:** Flag wird erst nach `await` gesetzt → zwei Schreibvorgänge möglich (manuell + natürlich).
5. **Umfang:** Schätzung ~120–160 LoC App-Code in 3–4 Dateien (Uhr, HealthKitManager, View, ggf. ProgressRingsView in derselben Datei) — innerhalb der Grenze, Countdown-Teil knapp beobachten.
6. **Watch-Ziel:** HealthKitManager wird auch dort kompiliert → Watch-Build prüfen.

## Analysis

**Type:** Feature/Verhaltensänderung (PO-Entscheidung) + benannter Fix (Doppelaufruf).

### Affected Files (Change Type)

| Datei | Change | App-LoC |
|---|---|---|
| `Meditationstimer iOS/Workout/WorkoutSessionClock.swift` | MODIFY: `pausedTotal` → `closed: [DateInterval]` (+`pausedAt`); `pauses`; `activeDuration` aus Intervallen; `meetsMinimum` = `activeDuration > 3`; Protokoll `logWorkout(start:end:activity:pauses:)`; `write` reicht `clock.pauses` durch | ~+25 |
| `Services/HealthKitManager.swift` | MODIFY: `logWorkout(…, pauses: [DateInterval] = [])`; reine statische Funktion `workoutEvents(pauses:in:)` (klemmen, Länge 0 verwerfen, sortieren, Pause bis Ende → nur `.pause`); `addWorkoutEvents` nach `beginCollection`, nur wenn nicht leer; kcal aus aktiven Sekunden; Helfer im `#if os(iOS)`-Block | ~+30 |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | MODIFY: `@State clock: WorkoutSessionClock?` (nil bis Countdown-Ende); `beginSessionAfterCountdown` setzt `clock` + `phaseStart` zuerst (Wächter `clock == nil`), dann Live Activity; Ringe nur bei `clock != nil` rendern (Timer startet erst dann); `endSession` geteilt in Hauptteil / `playClosingSound(manual:)` / `logSession()`; `sessionEnded = true` sofort nach Wächter; `clock?.end(at: Date())` vor Live-Activity-Ende und Gong | ~+35 netto |
| `LeanHealthTimerTests/WorkoutSessionClockTests.swift` | MODIFY: Fake mit `pauses`; 4 Charakterisierungstests umstellen (:133, :214, :232, :248) | Test |
| `LeanHealthTimerTests/HealthKitWorkoutEventsTests.swift` | CREATE: Events-Funktion + kcal-Aktivsekunden | Test |
| `LeanHealthTimerTests/SessionDurationTests.swift` | MODIFY: Kopfkommentar | Test |

**Scope:** 3 App-Dateien, ~90–110 LoC App-Code — innerhalb der Grenzen.
**Risk:** Mittel — Health-Schreibweg wird geändert (alle Workout-Arten rufen dieselbe Funktion, Standardwert hält die anderen unverändert); Watch-Ziel kompiliert HealthKitManager → Watch-Build Pflicht.

### Technical Approach (Varianten)

| Thema | Variante | LoC | Bewertung |
|---|---|---|---|
| Countdown | **A: Uhr optional, Ringe erst bei Start** | +12 | **gewählt** — Ring startet bei 0, Ring-Datei unberührt |
| Countdown | B: `start` var + `begin(at:)` in der Uhr | +20 | Uhr bekommt „nicht gestartet“-Zustand, mehr Code |
| Countdown | C: nur Uhr neu anlegen, Ringe laufen weiter | +5 | verletzt PO-Punkt 2 sichtbar (Phase rückt hinter Countdown vor) |
| Pausen | **HKWorkoutEvent über Builder** | +30 | **gewählt** — PO-Entscheidung, echte Zeiten |
| Pausen | Dauer kürzen | +5 | verfälscht Zeiten, widerspricht PO — verworfen |

Reihenfolge: Uhr + Tests → Events/kcal-Funktion + Tests → `logWorkout`/Protokoll/Fake/`write` → View Countdown → `endSession`-Schnitt (Wächter, Ende vor Gong, Schwelle) → Watch-Build, Simulator-Durchlauf.

Sichtbare Folgen für den Nutzer: Ringe starten nach dem Countdown bei 0 (heute ggf. schon vorgerückt, kurze Phasen evtl. übersprungen); Live-Activity-Endzeit stimmt (heute um Countdown zu früh); in Health kürzere aktive Dauer und weniger kcal bei Pausen; Start/Ende verschieben sich um Countdown bzw. Gong.

### Befunde gegen den Plan

1. `.task` kann Start zweimal auslösen → Wächter `clock == nil`.
2. Pause bis zum Ende: Resume exakt auf Endzeit ungeprüft → nur `.pause` schreiben.
3. kcal-Rechnung entsteht in Uhr und HealthKitManager → reine Funktion ist Quelle.
4. Abbruch im Countdown: `clock == nil` → nichts schreiben, kein Sonderfall.

### Tests

- Unit: Uhr (Intervalle, offene Pause, doppelte Aufrufe, Schwelle 3,0/3,1 s aktiv); Events-Funktion (leer, 1, 2 Intervalle, Klemmen, Länge 0, offene Pause → nur `.pause`); kcal-Aktivsekunden; `WorkoutSessionLog` mit Fake (Pausen kommen an; 10 s Wand + 8 s Pause → nicht geschrieben).
- Charakterisierung: :133 umkehren; :214 Pausen am Fake; :232 Uhr-Aussage, Reihenfolge Ende-vor-Gong nur im Simulator-Durchlauf; :248 Start = Übergabezeitpunkt nach Countdown.
- UI: ein Test mit Countdown (Launch-Argument), Rundenanzeige nach Cover bei Übung 1 / Runde 1 — Aussagekraft vor erstem Lauf prüfen. Regression: BackgroundMeditation, WorkoutHint, WorkoutSound, LiveActivity.

### Open Questions

- Keine PO-Frage offen.
- **Annahmen, ungeprüft (nur auf Gerät mit PO-Freigabe belegbar):** `finishWorkout` rechnet `duration` aus `addWorkoutEvents` wie dokumentiert; Pause ohne Resume bis Ende wird akzeptiert. Simulator schreibt nichts (#35, #122).

## Vorgaben aus TDD RED (für /50-implement)

- Signaturen, die die Tests erwarten: `WorkoutSessionClock.pauses: [DateInterval]`; `WorkoutLogging.logWorkout(start:end:activity:pauses:)`; `static HealthKitManager.workoutEvents(pauses:in:)`; `static HealthKitManager.estimatedCalories(activity: HKWorkoutActivityType, activeSeconds: TimeInterval) -> Double` (HIIT 12 kcal/min — von QA angenommen, Spec nennt keine Signatur).
- UI-Test `WorkoutCountdownUITests/testWorkoutProgramStartetErstNachCountdown`: „Tabata Classic“, Launch-Argument `-countdownBeforeStart` als Plist-Integer `<integer>20</integer>`; lastempfindlich (3-s-Timeout nach Countdown).
- Simulator: iPhone 17 Pro, iOS 27.2.

## Befund Phase 6 (2026-11-27, 00:10 MEZ)

- Umsetzung im Worktree (nicht committet, Commit-Sperre bis Adversary): 3 App-Dateien +104/−78; Unit-Suite 503/0, Watch-Build grün.
- UI `WorkoutCountdownUITests/testWorkoutProgramStartetErstNachCountdown` scheitert an :132 auch bei ruhigem Host und auch mit Stand bc16962. Ursache (Video + App-Log): Countdown läuft korrekt ab, danach blockiert der Main-Thread ~22 s in `sounds.play(.auftakt)` → `AVAudioSession.setActive` (`[AVAudioSession Hang Risk]`, `HALC … overload`, `[aqme] AQMEIO timed out after 15.000s`). Vorbestehend, nicht durch den Diff. Bekanntes Simulator-Muster: https://developer.apple.com/forums/thread/655326 ; Main-Thread-Risiko: https://developer.apple.com/forums/thread/697861
- Belege: scratchpad att1/ (Video), diag1/ (App-Log) der Sitzung 8be699a7.
