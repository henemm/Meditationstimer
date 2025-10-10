# Atem — Live Activity / Dynamic Island Spec

Kurz: this is the agreed specification for adding Live Activity support to the Atem tab. Implement only after this file is accepted.

## Zweck
Sicherstellen, dass beim Start einer Atem‑Session eine Live Activity gestartet/aktualisiert/beendet wird, ohne mehrere parallele Timer laufen zu lassen. UI soll klar über Konflikte informieren.

## Gültigkeitsbereich
- Target: iOS app (`Meditationstimer iOS`)
- Datei(s) primär betroffen: `Meditationstimer iOS/Tabs/AtemView.swift` (SessionCard) und bestehender `LiveActivityController` (shared)
- Keine Änderungen an `project.pbxproj` oder Targets.

## High level Ablauf
1. Nutzer tippt Play auf einem Preset → compute sessionEnd = now + preset.totalSeconds
2. Call `liveActivity.requestStart(title: preset.name, phase: 1, endDate: sessionEnd, ownerId: "AtemTab")`
   - `.started` → start local engine & UI overlay
   - `.conflict(existingOwner, existingTitle)` → show Alert with existingTitle and two actions:
     - `Beenden & Starten` → call `liveActivity.forceStart(...)`, then start engine
     - `Abbrechen` → do nothing (no local engine start)
   - `.failed` → start local engine anyway (Activity unavailable), but show brief Alert/Toast explaining Activity konnte nicht gestartet werden (optional minimal message)
3. Während einer laufenden Session: bei inneren Phasewechseln (inhale → hold → exhale) update only the activity's emoji/icon; do NOT change countdown time.
4. Beim Ende (natürlich oder manuell): call `await liveActivity.end()` and cleanup engine/UI.

## Visual mapping / DynamicIsland content
- Compact / collapsed: show phase symbol only (SF Symbol: `arrow.up` / `arrow.down` / `arrow.right`) and remaining time (mm:ss) optionally.
- Expanded Dynamic Island / LivePreview: show large phase symbol (same arrow) and remaining time. No extra title text required (title may be empty); keep UI minimal and consistent with Offen.
- Emoji/icon for Activity must reflect the current inner phase arrow (use same mapping as SessionCard center icon).

## Owner / IDs
- ownerId for Atem: `"AtemTab"` (consistent with Offen's `"OffenTab"`).

## Acceptance Criteria (quick checks)
- Play → `requestStart` called with correct title & endDate.
- If `.started`: engine runs, overlay visible, Activity exists (DBG prints show started).
- If `.conflict`: Alert shows `existingTitle` and `Beenden & Starten` ends other Activity and starts new one.
- If `.failed`: local session still starts; user sees optional brief message that Live Activity unavailable.
- On inner phase changes: Activity is updated only for the emoji/icon (no change to countdown value).
- On finish/manual end: `liveActivity.end()` is called and Activity is removed.

## Edge cases & decisions
- Race conditions: Start is gated by `requestStart`; local engine starts only after `.started` or after forceStart confirmation, except `.failed` where local start is allowed.
- If user wants to allow overwriting without prompt, we can add a setting; default is to prompt on conflict.
- Permissions / iOS versions: `.failed` can occur; handle it gracefully (local start allowed).

## Minimal implementation notes
- Implement changes in `AtemView.SessionCard` only. Use existing `LiveActivityController` API (`requestStart`, `forceStart`, `update`, `end`).
- Use the session's computed `sessionEnd` for the Activity endDate.
- When updating phase symbol, call `liveActivity.update(phase: <phaseId>, endDate: sessionEnd)` or a dedicated API that changes only the displayed symbol.

## Tests (manual)
- Manual run on device/simulator (if simulator supports Activities): start, conflict flow, phase symbol updates, finish.

## Branching / commits
- Implement in branch `live-activity-debug` (already created). Make small, focused commits and push to remote. No changes to project settings.

---
If this matches your intent, say `OK` and I will implement the changes. If anything should change in this spec, reply with the exact short modification (one-line change is fine).