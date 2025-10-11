# Live Activity stop bug — spec and reproduction

Status: captured from user logs; experimental patches rolled back to keep `main` stable.

Summary
-------
The Live Activity (Dynamic Island / Lock Screen) sometimes does not stop after the user presses "Beenden". Instead, logs show that `end()` is called but immediately a `start()` or `requestStart()` follows, causing the Live Activity to persist and continue counting.

Goal
----
Find the root cause and implement a minimal, robust fix so that pressing "Beenden" stops the Live Activity and the timer does not immediately restart.

Observed logs (snippet)
------------------------
The following lines were captured from the simulator runtime logs. They show the sequence of events and some unrelated system noise (audio/hardware messages):

- [LiveActivity iOS] requestStart owner=AtemTab currentOwner=nil isActive=false
- [LiveActivity] start attempt=1 → title=Box 4-4-4-4, phase=1, ends=2025-10-11 09:48:38 +0000 enabled=true
- [LiveActivity] UIApplication.applicationState=0
- [LiveActivity] update → phase=1, ends=2025-10-11 09:48:38 +0000
- [LiveActivity iOS] requestStart owner=AtemTab currentOwner=AtemTab isActive=true
- [LiveActivity] start attempt=1 → title=Box 4-4-4-4, phase=1, ends=2025-10-11 09:48:39 +0000 enabled=true
- [LiveActivity] UIApplication.applicationState=0

There are also unrelated noises like LoudnessManager / HALC messages in the logs.

Immediate Hypothesis
--------------------
One or more components (engine, view, or service) call `start()` or `requestStart()` after `end()` is invoked. Possible causes:

1. The timer engine (`TwoPhaseTimerEngine`) has pending callbacks or onChange handlers that call `liveActivity.start()` or `liveActivity.update()` after `end()` is called.
2. Multiple `LiveActivityController` instances exist; `end()` on one instance is followed by `start()` on another instance.
3. A delayed Task/DispatchWorkItem scheduled earlier triggers `start()` after `end()`.

Constraints & Observations
--------------------------
- The codebase contains a central `TwoPhaseTimerEngine` used by `OffenView` and potentially other places.
- Some tabs (e.g., `AtemView`) use their own timers or call `liveActivity.requestStart()` directly.
- `LiveActivityController` is present both under `Meditationstimer iOS/` and `Services/` (duplicated copies for app vs. service code paths).
- The project previously had experimental patches (start guards, restart windows) which were reverted; they masked issues but didn't resolve root causes.

Reproduction steps
------------------
1. Open app in Simulator.
2. Start a session from the relevant tab (Atem or Offen).
3. Press "Beenden" while Live Activity is active.
4. Observe logs for `end()` followed by `start()`/`requestStart()` within <1s.

Instrumentation checklist (next minimal actions)
------------------------------------------------
- Add structured logs (OSLog) with correlation/sessionId to `requestStart`, `start`, `forceStart`, `update`, `end` in `LiveActivityController` (both copies). Include Thread.callStackSymbols.prefix(12) for the first N occurrences in a session to find caller.
- Add debug logs in `TwoPhaseTimerEngine` at state changes and in any spot that calls `liveActivity.start()` or `requestStart()` (e.g., in `OffenView.onChange` handlers).
- Ensure only one `LiveActivityController` instance is used by views (make a note to centralize as an `@EnvironmentObject` if multiple instances appear).

Recommended minimal fix(es)
---------------------------
1. If the root cause is pending engine callbacks: ensure engine `cancel()` is called before `liveActivity.end()` OR cancel all pending callbacks before ending — then end Activity. (This is minimal but must be done where engine triggers the start.)
2. If multiple controller instances: centralize the `LiveActivityController` and make views use a single shared instance.
3. If delayed Tasks schedule `start()`: introduce explicit cancellation handles for them and cancel prior to `end()`.

When to escalate
----------------
- If the first instrumentation run doesn't reveal the caller, implement a single authoritative `SessionManager` that coordinates engine + liveActivity, then migrate callers to it (this is larger work).

Notes
-----
- Keep changes minimal and reversible. Create a feature branch and tag safe commits before risky fixes.
- Prefer disabling any experimental timing window / heuristic (these hide issues).

Authored by: automated assistant — snapshot of analysis at 2025-10-11
