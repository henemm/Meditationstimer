# Refactor: Central SessionService (Specification)

Ziel: Einen zentralen SessionService einführen, der Timer, LiveActivity, HealthKit Logging und Audio (AVAudioSession/Gong) verwaltet. UI‑Views (`Atem`, `Offen`, `Workouts`) werden zu thin clients, die nur Session‑Requests an den Service senden und Observable SessionHandles abonnieren.

Kurznutzen
- Eliminiert Race/Ownership‑Probleme (zentrale Serialisierung der ActivityKit Aufrufe). 
- Reuse für `Workouts` und weitere Session‑Typen.
- Bessere Testbarkeit, klarere Trennlinie zwischen UI und Lifecycle.
- Vollständig reversibel (Branch/Tag/Bundle + Feature‑Flagging).

----------------------------------------

## 1. Non‑Functional Requirements
- Reversibilität: Jeder Commit muss revertierbar sein. Vor Beginn: Branch `refactor/session-service` + tag `start/session-service-<date>` + git bundle backup. 
- Backwards compatibility: Alte UI‑Flows müssen unverändert funktionieren, bis sie schrittweise migriert werden.
- Observability: Alle Session‑Aufrufe loggen `sessionUUID` mit os.Logger subsystem `henemm.Meditationstimer` category `SESSION-SVC`.
- Failure tolerance: Service führt ActivityKit Aufrufe seriell mit bounded retries and backoff (max 3 retries, initial delay 100ms, multiplier 2x).

----------------------------------------

## 2. High Level Design

- Component: `SessionService` (singleton / @MainActor class) — verwaltet aktive Sessions in einer internen DispatchQueue.
- Components it coordinates: `LiveActivityController` (existing wrapper), `HealthKitManager`, `AudioManager` (Gong/AVAudioSession), `SessionStore` (in‑memory, optional persistence), `SessionStatePublisher` (ObservableObject for UI).
- UI contract: UI calls `SessionService.shared.start(spec:)` and receives a `SessionHandle` (ObservableObject / AsyncSequence) to monitor progress, request end, or force end.

----------------------------------------

## 3. Data Contracts / API (Swift pseudocode)

```swift
// Describes the session request
struct SessionSpec: Equatable {
    enum Kind { case atem, offen, workout }
    let kind: Kind
    let presetId: UUID?
    let presetName: String
    let ownerId: String // e.g. "AtemTab" or "OffenTab" or "WorkoutsTab"
    let startDate: Date
    let endDate: Date
    let sessionUUID: UUID
}

@MainActor
final class SessionHandle: ObservableObject {
    @Published var state: SessionState
    let sessionUUID: UUID
    func end(immediate: Bool)
    func forceStart() async -> Bool
}

enum SessionState {
    case idle, running(phase:Int, remaining:Int), finished, failed(Error)
}

@MainActor
final class SessionService {
    static let shared = SessionService()

    // start returns a handle immediately; the service will serialize calls and update the handle
    func start(spec: SessionSpec) -> SessionHandle
    func update(sessionUUID: UUID, phase:Int, endDate: Date)
    func end(sessionUUID: UUID, immediate: Bool)
}
```

Behavorial notes:
- `start` must serially call `LiveActivityController.requestStart` (or `forceStart` when requested) and only after a `started` response (or a deterministic `failed` fallback) set the `SessionHandle.state = .running(...)` and start local timers.
- `end` always calls `LiveActivityController.end()` for the correlated `sessionUUID` and then sets state finished.

----------------------------------------

## 4. Internal Implementation Details
- Single serial `actor` or `DispatchQueue` inside `SessionService` to sequence all ActivityKit calls.
- Each session entry keeps: spec, current State, Task token for local timer, correlation `sessionUUID`, and an `ownerId` string.
- Retry/backoff: when requestStart returns a transient error or ActivityKit not immediately active, the service will retry up to 3 times with 100ms, 200ms, 400ms delays. If still fails, fallback to local engine with a log entry indicating Activity unavailable.
- ForceStart: if user explicitly forces, attempt `forceStart` and do not show conflict alert at service level; return result to UI.
- HealthKit: at `end` the service decides whether to call `HealthKitManager.logMindfulness` or `logWorkout` based on `spec.kind` and user setting `logMeditationAsYogaWorkout`.
- AudioManager: the service owns starting/stopping audio sessions for the session lifecycle. For `Atem` we expose per‑phase gong triggers to UI or provide a callback API.

----------------------------------------

## 5. Migration Plan (iterative, reversible)

### Step 0 — Prep (5–15 minutes)
- Create branch: `git checkout -b refactor/session-service`.
- Create remoteless backup bundle: `git bundle create backups/repo-refactor-session-service.bundle --all`.
- Tag baseline: `git tag start/session-service-YYYY-MM-DD`.

### Step 1 — Skeleton service + tests (1–2 hours)
- Add `SessionService.swift` file with skeleton API and in‑memory store; add unit tests for serialization and retry/backoff logic (mock LiveActivityController).
- Add `SessionHandle` type.
- Add logging scaffolding.
- No changes to `AtemView` or `OffenView` yet; feature flag `USE_SESSION_SERVICE=false` by default.

Acceptance criteria step1
- `SessionService` compiles and tests for serialization logic pass locally.
- Branch/commit created and bundle created.

### Step 2 — Integrate with Offen (POC) (2–4 hours)
- Route `OffenView` to use `SessionService.start` instead of direct TwoPhaseTimerEngine for a single preset (controlled by feature flag). Keep TwoPhaseTimerEngine adapter to the service so existing tests still valid.
- Verify LiveActivity behavior and HealthKit logging for Offen.

Acceptance criteria step2
- Offen session works end‑to‑end in simulator (start, updates, end). Logs show single requestStart per session, HealthKit entry created, LiveActivity lifecycle correct.

### Step 3 — Migrate Atem (4–8 hours)
- Implement `SessionEngineAdapter` inside service that supports Atem's fine‑grained phases and gong triggers. Ensure UI Timeline and phase progress still driven by `SessionHandle` state updates.
- Move Audio management into service (or provide API for UI to request gongs via the service).
- Validate LiveActivity phase updates frequency is compatible (throttle updates if necessary).

Acceptance criteria step3
- Atem overlay functions visually identical; LiveActivity no longer shows Start/Cancel loops; logs show serialized starts and expected update frequency.

### Step 4 — Add Workouts (2–4 hours)
- Add a `Kind.workout` mapping in `SessionSpec` and implement HealthKit workout mapping in `SessionService` (HKWorkoutBuilder or logWorkout API used as in current code).
- Add UI hooks in Workouts tab to call `SessionService`.

Acceptance criteria step4
- Workouts start/end properly logged in HealthKit; LiveActivity and UI sync correctly.

### Step 5 — Polish, tests, roll‑out (1–2 days)
- Add unit tests for HealthKit mapping, add integration test harness (simulator), run smoke tests across iPhone/Watch if applicable, document API for future tabs.
- Remove feature flag, merge to main once validated.

----------------------------------------

## 6. Rollback & Reversibility Plan
- Pre‑work: `git checkout -b refactor/session-service && git tag start/session-service-YYYYMMDD && git bundle create backups/repo-refactor-session-service.bundle --all`.
- During migration, every milestone must be committed and tagged: `tag step1-ready`, `tag step2-ready`, ...
- If a milestone causes regression, revert to previous tag: `git reset --hard <tag>` or `git checkout main` and `git merge --abort` depending on workflow.
- Because changes are behind a feature flag, quick disable: set `USE_SESSION_SERVICE=false` in a dev config, which instantly routes UI back to old code paths.

Rollback example commands
```
# restore from bundle (if local repo corrupted)
git clone repo-refactor-session-service.bundle repo-restore
# or reset branch to tag
git checkout refactor/session-service
git reset --hard start/session-service-YYYYMMDD
```

----------------------------------------

## 7. Tests & Smoke Checks (how to verify)
- Unit tests: serialization, retry/backoff, correlation id propagation.
- Manual smoke (Simulator):
  1. Boot simulator, start app.
  2. Start Offen session (via UI or direct call). Inspect logs: only one requestStart line per sessionUUID.
  3. Start Atem session, step through phases; ensure no immediate cancel loop.
  4. End sessions; check HealthKit entries (or stubbed test logger).
- Log inspection predicate example:
```
xcrun simctl spawn <UDID> log stream --predicate 'subsystem == "henemm.Meditationstimer" AND category == "SESSION-SVC"' --style compact
```
Look for: `SESSION-SVC requestStart session=<uuid> owner=AtemTab`, then `SESSION-SVC startConfirmed session=<uuid>` etc.

----------------------------------------

## 8. Milestones & Estimates (conservative)
- M0: Prep & backup — 0.25h
- M1: Service skeleton + unit tests — 1.5h
- M2: Offen migration POC — 3h
- M3: Atem migration — 6h
- M4: Workouts integration — 3h
- M5: Tests + polish + merge — 6–12h

Total conservative estimate: 1.5–2.5 work days (M1–M4 core + M5 polish). Adjust after step2 POC.

----------------------------------------

## 9. Acceptance Criteria (project level)
- No Start→Cancel loops reproducible in simulator for Atem and Offen (verified by log sequence and manual test).
- LiveActivity lifecycle: single `requestStart` per sessionUUID, regular `update` calls matching phases, and an `end` at session finish.
- HealthKit logs present for sessions when enabled.
- UI behavior unchanged (visual parity) for Atem and Offen after migration; any minor differences documented and accepted.
- Rollback path validated: setting `USE_SESSION_SERVICE=false` returns to prior behavior without code revert.

----------------------------------------

## 10. Deliverables
- `refactor/session-service` branch with incremental commits and tags.
- `SessionService.swift`, `SessionHandle.swift`, `SessionStore.swift`, `AudioManager.swift` (if created) and unit tests.
- Migration PRs for `OffenView` and `AtemView` (feature flagged).
- Smoke test run logs and brief verification note.

----------------------------------------

## 11. Next actions (immediate)
If you approve I will:
1. Create branch `refactor/session-service` and backup bundle (5 min).
2. Implement skeleton `SessionService` + unit tests and open a PR draft for review (1–2h).

Antwort: `Start` (ich beginne Branch + Step1) oder `Patch` (liefern nur Guard‑Patch).