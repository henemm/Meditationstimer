# AI Notes (consolidated)

This file is a central place for AI-facing hints, annotations and quick context that other chat sessions or automation can read.

Suggested contents:
- Where to look first for Live Activity issues: `Meditationstimer iOS/Tabs/OffenView.swift`, `Services/LiveActivityController.swift`, `Services/TwoPhaseTimerEngine.swift`.
- Owner convention for LiveActivity: callers should pass `ownerId` (e.g. `"OffenTab"`).
- Files with AI orientation comments: `OffenView.swift`, `AtemView.swift`, `WorkoutsView.swift` (each contains a short AI ORIENTATION block).
- Local notes:
  - Tag `v1.1` and branch `stable/v1.1` were created on 2025-10-10 as a safe rollback point.
  - Release: https://github.com/henemm/Meditationstimer/releases/tag/v1.1

If you want, I can scan the repository for all `AI ORIENTATION` sections and append them here.
