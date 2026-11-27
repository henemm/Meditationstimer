# Context: fix-122-programm-freigabe (#122)

## Request Summary
Ein geführtes Workout-Programm schreibt ohne vorherige HealthKit-Schreibfreigabe still nichts in Health (kein Eintrag, keine Serie). Ziel: vor dem Programmstart dieselbe Freigabe-Prüfung und derselbe Hinweis wie beim freien Workout; Schreibfehler nicht mehr still verschlucken.

Reproduziert am 2026-11-26 im Simulator (#35-Sitzung): frischer Simulator, nur Achtsamkeit freigegeben → Tabata Classic → 0 Workouts, healthd `HKWorkoutBuilder … Active -> Discarded`. Gegenprobe mit voller Freigabe → 1 Workout.

## Related Files (Stand Worktree, Kontext-Agent 2026-11-27)
- `Meditationstimer iOS/Tabs/WorkoutTab.swift`
  - :95 `play: { runningSet = set }` in `WorkoutSetRow` (ForEach ab :92) — **kein** Freigabe-Check
  - :233-249 `if let set = runningSet { … WorkoutProgramSessionCard(set:) { runningSet = nil } }`
  - :351-362 `startFreeWorkout()`: `if await HealthKitManager.shared.isAuthorized() { … } else { showHealthAlert = true }` — **Vorbild**
  - :174-191 `.alert("Health Access", isPresented: $showHealthAlert)` mit „Cancel“/„Allow“; Allow → `requestAuthorization()` → Start; catch nur `print`
  - :530 Runner des freien Workouts fragt in `.task` zusätzlich still an
  - :756 / :775-777 Schreibfehler freies Workout: `try?` bzw. `print`
- `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift`
  - :427 `var logger: any WorkoutLogging = HealthKitManager.shared`
  - :530 `.task` der Session-Karte — kein `requestAuthorization`/`isAuthorized` in der Datei
  - :738-762 `logSession()` → `WorkoutSessionLog.write(...)` (:741); catch :744-745 nur `print`, `return false`
- `Meditationstimer iOS/Workout/WorkoutSessionClock.swift:79-101` — Protokoll `WorkoutLogging`, `WorkoutSessionLog.write` (`.skipped`/`.written`)
- `Services/HealthKitManager.swift`
  - :72 `requestAuthorization() async throws` (Share: mindful, workout, alcohol, activeEnergy, iOS18 effortScore); `.unnecessary` → return (:120); 5-s-Warten auf aktive App, sonst `authorizationDenied` (:123-125)
  - :176 `logWorkout(start:end:activity:pauses:) async throws -> HKWorkout?` — prüft selbst nicht
  - :290-335 `isAuthorized()` = `getRequestStatusForAuthorization == .unnecessary` (heißt nur „schon gefragt“, nicht „Schreiben erlaubt“; ohne effortScore)
- `Meditationstimer iOS/PhoneMindfulnessReceiver.swift:39-47` — beim App-Start nur Achtsamkeit angefragt
- `Localizable.xcstrings` — `"Health Access"` (:2026), Workout-Hinweistext als Key (:4573), beide vorhanden DE/EN

## Existing Patterns
- Freigabe vor Start: freies Workout (WorkoutTab :351-362, Alert :174-191), Meditation (MeditationTab :334-339, :211-222, mit `NSLocalizedString`), CalendarView :318-321.
- Schreibfehler: überall still/`print` (WorkoutTab :775, MeditationTab :419, AtemView :748, TrackerManager :136/158). Kein bestehender Fehler-Hinweis für den Nutzer.

## Dependencies / Dependents
- Programmstart nur über WorkoutTab :95; `WorkoutProgramSessionCard` nirgends sonst erzeugt.
- Siri/Shortcut/Deep Link (`StartWorkoutIntent`, `ShortcutHandler` :205-210, `ContentView` :143-147) betreffen nur das freie Workout.
- Watch/Widgets: kein Programm-Bezug.

## Existing Specs
- `openspec/specs/integrations/healthkit.md:40-63` Requirement Permissions: „Permission Denied → UI shows appropriate message“, „Changed Mid-Session → user is informed“ — heute nirgends erfüllt.
- `openspec/specs/features/workouts.md:35-53` Workout Programs — keine Aussage zur Freigabe.
- `docs/specs/**/FEAT-37d-healthkit-integration.md`, `feature-35-workout-session-clock.md`, `BUG-25d-hintergrund-workout.md` (noch ungelesen).

## Tests
- Unit: `LeanHealthTimerTests/WorkoutSessionClockTests.swift` (Mock-Logger :30-41 mit `wirft`; `testSchreibwegReichtFehlerDurch` :266), `HealthKitManagerTests.swift`, `SessionDurationTests.swift`.
- UI: `WorkoutCountdownUITests.swift:109` `testWorkoutProgramStartetErstNachCountdown`; `LeanHealthTimerUITests.swift:2029` `testWorkoutProgramShowsRoundCounter`, :1463; App-Alert per `app.buttons["Allow"]` an mehreren Stellen; `HealthSheetHelper.dismissHealthSheetIfAny()` lehnt System-Blatt ab.
- Kein Launch-Argument, das HealthKit-Zustand simuliert. Frischer Simulator / `simctl privacy reset health` erzeugt den „nicht gefragt“-Zustand.

## Risks
- Bestehende Programm-UI-Tests starten bisher ohne Alert → neuer Alert kann sie brechen (müssen „Allow“ bedienen, wie das freie Workout).
- `isAuthorized()` erkennt verweigerte Freigabe nicht (nur „gefragt“). Wer verweigert hat, bekommt mit dem Muster keinen Hinweis; Schreibfehler-Hinweis ist dafür der einzige Weg.
- Schreibfehler-Hinweis ist neu (kein Vorbild) → Lokalisierung DE/EN nötig, UI-Entwurf nötig (Entwurf-vor-Spec-Regel).
- Nebenbefund: CLAUDE.md nennt Simulator iOS 26.5, Laufzeit ist 27.2 — nicht Teil dieses Tickets.

## Recherche (2026-11-27, Apple-Doku + iOS-27.2-SDK)
- `HKHealthStore.authorizationStatus(for:)` meldet für **Schreib**typen verlässlich `.notDetermined` / `.sharingDenied` / `.sharingAuthorized` („checks the authorization status for saving data“). Lesestatus bleibt verborgen. https://developer.apple.com/documentation/healthkit/hkhealthstore/authorizationstatus(for:)
- `getRequestStatusForAuthorization` `.unnecessary` = „already requested“, **nicht** „erlaubt“ → heutiges `isAuthorized()` erkennt Verweigerung nicht. https://developer.apple.com/documentation/healthkit/hkauthorizationrequeststatus/unnecessary
- Erneutes `requestAuthorization` für bereits entschiedene Typen zeigt **kein** Blatt. Ändern nur in Einstellungen/Health-App. Offizieller Link: `UIApplication.openSettingsURLString` (App-Einstellungsseite); `x-apple-health://` undokumentiert, `App-Prefs:` privat (Ablehnungsrisiko). https://developer.apple.com/documentation/healthkit/hkhealthstore/requestauthorization(toshare:read:completion:)
- Speichern ohne Recht → `HKError.errorAuthorizationDenied` (Rohwert 4); 5 = `errorAuthorizationNotDetermined`. In iOS 27 unverändert; neu in iOS 27 nur Lese-Zeitraumbegrenzung (`earliestAuthorizedSampleDate(for:)`), für #122 irrelevant. https://developer.apple.com/documentation/healthkit/hkerror/code/errorauthorizationdenied
- HIG: Erlaubnis im Kontext kurz vor Bedarf erfragen; Funktion bei Verweigerung nicht sperren; auf Einstellungen verweisen; keine eigene Rechteverwaltung. https://developer.apple.com/design/human-interface-guidelines/healthkit

## Bug-Intake (2026-11-27, nur Code gelesen; Reproduktion vom 2026-11-26 passt)
- Root Cause bestätigt: Programmstart WorkoutTab.swift:95 ohne Prüfung; WorkoutProgramsView.swift ohne `requestAuthorization`/`isAuthorized`; Schreibfehler :760 nur `print`, `logSession()` → `false` (:762), Karte schließt (:723-726).
- **Korrektur am Vorbild:** `isAuthorized()` = `.unnecessary` = „schon gefragt“. Auch das freie Workout (WorkoutTab.swift:353) und Meditation (MeditationTab.swift:336) starten bei Verweigerung still ohne Hinweis. Typenmenge von `isAuthorized()` weicht von `requestAuthorization()` ab (effortScore fehlt, HealthKitManager.swift:95 vs. :290-319).
- Fälle: (a) nie gefragt → Programm still; frei: Dialog. (b) verweigert → beide still. (c) entzogen → wie (b); Entzug mitten in der Sitzung fällt erst beim Speichern auf.
- `authorizationStatus(for:)` für Workout nirgends genutzt (nur TrackerManager.swift:134, SmartRemindersView.swift:259 für andere Typen).
- `logSession()` `true` nur bei Workout≠nil und iOS 18+ (Effort-Sheet); `false` bei Mindestdauer-Skip (WorkoutSessionClock.swift:75), nil, Fehler → Karte schließt, keine Anzeige. Streak liest Health neu (StreakManager.swift:149; WorkoutProgramsView.swift:752).
- UI-Tests mit Programmstart (würden durch Alert vor Start brechen, wenn Simulator „nicht gefragt“): WorkoutHintUITests `startPreset()` :113 (4 Tests), WorkoutCountdownUITests :109, BackgroundMeditationUITests `startFirstWorkoutSession()` :33 (2 Tests), LeanHealthTimerUITests :2029.
- Nebenbefunde: Programm ignoriert `logWorkoutsAsMindfulness` (frei wertet es aus, WorkoutTab.swift:753); Meditation hat dieselbe (b)/(c)-Lücke.

## Analysis

**Type:** Bug (Fehlende Freigabe-Prüfung + verschluckter Schreibfehler)

### Varianten (Plan-Agent, 2026-11-27)
| | Dateien | LoC App | deckt ab | Bemerkung |
|---|---|---|---|---|
| V1 `isAuthorized()` + bestehender Alert, nur Programm | 3 | 60-80 | nur (a) | wörtliches Ticket-Ziel; (b)/(c) bleiben still |
| **V2** `authorizationStatus(for: .workoutType())`, nur Programm | 4-5 | 125-155 | (a)(b)(c) | **Empfehlung** |
| V3 = V2 + freies Workout | 4-5 | 150-190 | (a)(b)(c) beide Wege | verlässt Ticketrahmen → Folge-Ticket |
| V4 nur Schreibfehler-Hinweis | 2 | 30-45 | nichts verhindert, nur nachträglich | |

### Affected Files (V2)
- `Services/HealthKitManager.swift` — MODIFY: `workoutShareStatus()` dünner Wrapper um `authorizationStatus(for: .workoutType())` (~10). `isAuthorized()` bleibt **unverändert** (Meditation, CalendarView hängen daran).
- Reine Entscheidungsfunktion Status→Aktion (`.notDetermined→.askPermission`, `.sharingDenied→.showSettingsHint`, `.sharingAuthorized→.start`) — CREATE oder in HealthKitManager.swift (~15), unit-testbar ohne HealthKit.
- `Meditationstimer iOS/Tabs/WorkoutTab.swift` — MODIFY: Prüfung im `play`-Closure (:95), Alert (a) = bestehender „Health Access“-Alert, Hinweis (b)/(c) mit Einstellungs-Link (`UIApplication.openSettingsURLString`) (~50-60).
- `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` — MODIFY: Schreibfehler-Alert; catch in `logSession()` (:744) setzt Zustand, Karte schließt erst nach „OK“ (~30-40).
- `Localizable.xcstrings` — MODIFY: neue Texte DE+EN (~20-30).
- Tests (zählen nicht): Unit-Test Entscheidungsfunktion; 8 UI-Tests mit Programmstart müssen optionalen Alert per `waitForExistence` + „Allow“ bedienen; neuer UI-Test (a) und (b) über `HealthSheetHelper.dismissHealthSheetIfAny()` („Nicht erlauben“).

### Scope / Risk
~125-155 LoC App-Code in 4-5 Dateien — innerhalb der Limits. Risiko mittel: bestehende Programm-UI-Tests; Simulator-Zustand nicht reproduzierbar (run-uitests.sh hat kein `privacy reset`) → Tests müssen Alert optional behandeln; für (a)/(b) gezielter Reset nötig.

### Technical Approach
1. Rote Unit-Tests für Entscheidungsfunktion. 2. Wrapper in HealthKitManager. 3. Prüfung beim Programmstart. 4. Schreibfehler-Alert. 5. Lokalisierung. 6. UI-Tests anpassen/neu. 7. Simulator-Durchlauf (a), (b), Schreibfehler.
Fallstrick: bei (b)/(c) **nicht** `requestAuthorization()` aufrufen (kein Blatt, keine Wirkung). Programm wird nie gesperrt (Apple HIG).
Offen zu prüfen: ob `logWorkout` bei Verweigerung wirft oder `nil` liefert — beide Zweige müssen den Hinweis auslösen.

### Dependencies
`WorkoutSessionLog.write` reicht Fehler durch (WorkoutSessionClock.swift:79-101); Streak liest Health neu (StreakManager.swift:149).

### Open Questions (PO)
1. Hinweis bei verweigerter Freigabe (b)/(c): Rückfrage mit „Trotzdem starten“ (Empfehlung) oder direkt starten mit Hinweiszeile im laufenden Training. → Entwurf `docs/artifacts/fix-122-programm-freigabe/entwurf.html`
2. Scope V2 (nur Programm) — freies Workout + Meditation als Folge-Ticket.

### Folge-Tickets (außerhalb #122)
- Freies Workout und Meditation erkennen verweigerte Freigabe nicht (gleiche (b)/(c)-Lücke; `isAuthorized()` = „schon gefragt“; effortScore fehlt in `isAuthorized()`).
- Programm ignoriert Einstellung `logWorkoutsAsMindfulness` (WorkoutTab.swift:753).

### Entwurf
https://claude.ai/artifact/5CZDPSr4PBxpimjc3EzpTe (Quelle: docs/artifacts/fix-122-programm-freigabe/project/). Wartet auf PO-Entscheidung zu Open Question 1.
- Folge-Ticket: #129 (freies Workout/Meditation, Achtsamkeits-Einstellung)

### PO-Entscheidung (2026-11-27)
- Open Question 1: **Rückfrage vor dem Start** („Training wird nicht gespeichert“, Buttons „Einstellungen“ / „Trotzdem starten“). Alternative „Zeile im Training“ verworfen.
- Scope V2 (nur Programm); freies Workout/Meditation in #129.
