# v2.0.0 — Major Release

## Highlights
- **Live Activity Background Updates Fixed**: Live Activities now update correctly even when the device is locked. Previously, timer updates would only appear after unlocking the screen.
- **Consistent Phase Transitions**: All tabs (Offen, Atem, Workouts) now handle Live Activity phase transitions consistently using `update()` with `staleDate`.
- **Improved Reliability**: Added `staleDate` to all Live Activity updates to ensure they are processed reliably in background/locked states.

## Technical Details
- **LiveActivityController**: Added `staleDate` parameter to `update()` method (30 seconds in future) to ensure background updates are prioritized
- **OffenView**: Fixed phase transition from `end()`+`start()` back to `update()` for continuous Live Activity display
- **Background Processing**: Live Activity updates now work reliably when app is in background or device is locked

## Bug Fixes
- Live Activity timer no longer shows incorrect times in locked state
- Phase 2 now appears correctly in Live Activity after transition
- Consistent behavior across all meditation tabs

## Commits included
- cf7e8e5 Fix Live Activity background updates with staleDate
- 52893d6 Fix OffenView Live Activity: Use phase-specific end times instead of session total
- 33eaa27 Add WorkoutsTab Live Activity icons

## Breaking Changes
None - this is a bug fix release that improves existing functionality.

## How to publish on GitHub Web UI
1. Open https://github.com/henemm/Meditationstimer/releases
2. Click "Draft a new release"
3. Tag version: `v2.0.0` (select created tag)
4. Release title: `v2.0.0 — Major Release`
5. Paste these release notes into the description.
6. Publish release.