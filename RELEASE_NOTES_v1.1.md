v1.1 — Minor release

> STATUS: REVIEWED — validated 2025-10-12

Highlights
- OffenView: LivePreview integrated and working with updated UI and controls.
- Dynamic Island: Expanded Dynamic Island shows phase emoji and a live timer; updated layout for Dynamic Island.
- LiveActivityController: consolidated implementations; more robust start/update/end flows and instrumentation.
- Bugfixes: removed temporary watchdog; fixed several race conditions around activity lifecycle.

Commits included (short):
- 000e0fe DynamicIsland: place phase emoji on leading side, remove SF icon in expanded region; keep timer on trailing side
- 9af23e4 Restore MeditationstimerWidgetLiveActivity.swift from 341fdc6
- 94a3c08 Widget: use Color.accentColor for SF icon; prevent timer wrap and slightly reduce emoji size
- 341fdc6 Widget: keep SF app icon filled with AccentColor; move phase emoji to right of timer
- c8e51b4 2 Phasen laufen.

Notes
- The remote `main` branch was force-updated to match local main when tagging. If other collaborators exist, they should rebase or re-clone to avoid conflicts.

How to publish on GitHub Web UI
1. Open https://github.com/henemm/Meditationstimer/releases
2. Click "Draft a new release"
3. Tag version: `v1.1` (select created tag)
4. Release title: `v1.1 — Minor release`
5. Paste these release notes into the description.
6. Publish release.

Alternatively, to create via API, provide a GitHub personal access token with `repo` scope and I can create the release with a `curl` command.