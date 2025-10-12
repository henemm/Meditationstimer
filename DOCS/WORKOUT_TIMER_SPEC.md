# Workout Timer — Konzept und Implementationsplan

> STATUS: DRAFT — Erstellt 2025-10-12 zur Diskussion

Ziel
----
Dieses Dokument beschreibt das Konzept für den Workout‑Timer (Workouts‑Tab). Es wurde aktualisiert, um das tatsächliche Verhalten im Code widerzuspiegeln (siehe Implementation in `Meditationstimer iOS/Tabs/WorkoutsView.swift`).

Kernaussage: Der aktuelle Workout‑Timer zählt die Gesamt‑Session‑Zeit und zeigt ein einziges SF‑Icon (phasenabhängig). Es gibt keine separaten Warmup/Cooldown‑Phasen im State‑Modell — Auftakt/Ausklang sind nur Sounds.

Kurzvertrag (Contract)
---------------------
- Inputs: WorkoutPreset (Name, rounds, workDuration, restDuration, warmup, cooldown, sound settings, optional heartRateTarget), Benutzeraktion (Start/Pause/Stop), System Events (App background/terminate).
- Outputs: Lokal laufender Timer (UI updates jede Sekunde), LiveActivity updates (phase + endDate), HealthKit Workout (on finish if enabled), Logs/Telemetry (TIMER‑BUG category).
- Fehlerzustände: ActivityKit nicht verfügbar, HealthKit not authorized, App‑Termination, Race bei schnellen Start/Stop → muss deterministisch behandelt werden.

Designprinzipien (aktuell)
-------------------------
1. Aktuell zeigt der UI‑Overlay ausschließlich den Gesamt‑Session‑Timer (sessionTotal) und ein SF‑Icon, das die aktuelle Phase repräsentiert.
2. Phase‑Icons sind nur zwei: `flame` für Work, `pause` für Rest (siehe Code). Kein Pausen‑Icon für paused state.
3. LiveActivity‑Integration für Workouts ist im vorliegenden Code entfernt. Wenn wieder aktiviert, muss sie sich an das vorhandene Ownership‑/requestStart‑Pattern halten.
4. HealthKit logging bleibt im `endSession` implementiert (auf Device getestet), Verhalten bei denied permissions ist tolerant.

User Flows
----------
1. Erstellen/Auswählen Preset
   - Nutzer wählt ein WorkoutPreset oder erstellt ein neues (UI: WorkoutsView Presets list).
2. Start
   - Compute sessionEnd = now + totalDuration
   - Call `liveActivity.requestStart(title: preset.name, phase: 1, endDate: sessionEnd, ownerId: "WorkoutsTab")`
     - .started → local engine.start(preset)
     - .conflict → show Alert (End & Start / Cancel)
     - .failed → retry locally as fallback (log warning)
3. Running
   - Engine publishes state: .idle, .running(phase, remaining, round, totalRounds), .finished
   - UI shows RunCard with dual/stacked rings or linear progress, big timer, and pause/stop buttons
   - On inner phase change (work→rest) call `liveActivity.update(phase:, endDate:)` (only icon/phase, not endDate unless changed)
4. Pause/Resume
   - Pause: engine.pause() (cancel Task timers), LiveActivity should show paused state (optional) or remain with same endDate but change phase icon
   - Resume: engine.resume(), LiveActivity.update(...)
5. Stop / Finish
   - Manual Stop: stop engine, await `liveActivity.end()`, then reset UI
   - Natural Finish: engine reaches .finished → log HealthKit (if enabled) → await `liveActivity.end()`

Data Model (minimal)
--------------------
struct WorkoutPreset {
   var id: UUID
   var name: String
   var rounds: Int
   var workSeconds: Int
   var restSeconds: Int
   var playSoundOnPhase: Bool
   var logToHealthKit: Bool
}

Engine contract (swift-like)
---------------------------
protocol WorkoutEngine: ObservableObject {
    var state: WorkoutState { get }
    func start(preset: WorkoutPreset)
    func pause()
    func resume()
    func cancel()
}

LiveActivity / HealthKit mapping (current state)
------------------------------------------------
- LiveActivity: currently **not active** for Workouts in code (calls removed). If re-enabled, use ownerId: "WorkoutsTab" and update only phase/icon on phase changes.
- Activity phases: the code only distinguishes work vs rest; any Activity phase mapping should reflect that (1 = work, 2 = rest, 3 = finished).
- HealthKit: implemented in `endSession` — logs either Mindfulness or HKWorkout (highIntensityIntervalTraining) depending on user setting.

Edge Cases & Race Conditions
---------------------------
- Simultaneous Start Attempts (race): rely on `requestStart` conflict response; optionally implement a short client-side mutex in `LiveActivityController`.
- App background/terminate during workout: engine must persist minimal state (startDate + elapsed) so on resume UI can reconstruct. Live Activity should remain authoritative for user-visible timer while app is backgrounded.
- HealthKit denied: gracefully skip logging, but still finish UI cycle.

Acceptance Criteria
-------------------
1. Start → RunCard shows, LiveActivity started, no second concurrent timer possible.
2. Phase transitions update LiveActivity icon/phase only.
3. Manual Stop → LiveActivity ended and RunCard closed within <1s (modulo ActivityKit delay).
4. Finished natural → HealthKit entry created if authorized and configured.
5. Pause/Resume works without creating duplicate activities.

Testing Plan
------------
- Unit tests for WorkoutEngine: start/pause/resume/cancel semantics, boundary durations, repeated start prevention.
- Integration tests: simulate requestStart conflict and forceStart flows.
- Manual simulator test: verify LiveActivity start/update/end, UI overlay timing, and that starting another tab stops Workouts if needed.
- HealthKit: run on device with Health permissions to verify Workout creation.

Incremental Implementation Plan (5 steps)
---------------------------------------
1. Spec + data models (this doc) — discuss and finalize.
2. Implement `WorkoutPreset` model and small editor UI in `WorkoutsView` (non‑breaking).
3. Implement `WorkoutEngine` (adapter over existing TwoPhaseTimerEngine or new implementation), with `@Published state` and DebugLog entries.
4. Wire `WorkoutsView` UI overlay (RunCard) to `WorkoutEngine` and `LiveActivityController` using same `requestStart` pattern as Offen/Atem. Add unit tests.
5. HealthKit integration and device tests. Add acceptance tests and finalize docs.

Backwards compatibility & feature flagging
----------------------------------------
- Implement behind feature flag `USE_WORKOUT_SERVICE=false` → default disabled if you want to gate rollout.
- Keep TwoPhaseTimerEngine for Offen compatibility; WorkoutEngine can be an adapter to the TwoPhaseTimerEngine if reuse is desired.

Offene Punkte (konkret)
----------------------
1. LiveActivity-Reaktivierung: entscheiden, ob Workouts wieder `requestStart`/`update`/`end` verwenden sollen. (Empfehlung: JA, um konsistente UX across tabs.)
2. Paused‑State in Activity/Island: aktuell nicht abgebildet — optional hinzufügen.
3. UI for Expanded Dynamic Island / LivePreview: designen, ob wir Dual‑Ring oder Single icon+timer zeigen (siehe unten Vorschlag).

Aktuell implementiert: Gesamt‑Timer + SF‑Icon(=phase). Keine Warmup/Cooldown phases.

Nächste Schritte (wenn du zustimmst)
----------------------------------
1. Ich aktualisiere diese Spec mit der exakten Icon‑Mapping‑Tabelle und der Regel: "Timer zeigt immer Gesamt‑Session‑Timer; Icon wechselt bei `setPhase(...)` zwischen `flame` und `pause`."
2. Optional: Ich reaktiviere LiveActivity für Workouts (kleiner Patch) und sorge dafür, dass `requestStart` + `update(phase:)` + `end()` genau diese Anzeige auf Dynamic Island/Widget widerspiegelt.

Autor: automatisierter Assistent — Entwurf 2025-10-12
