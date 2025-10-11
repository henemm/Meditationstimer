# LiveActivity Concept for Meditationstimer

This document captures the agreed concept for per‑tab Live Activity rendering.

Tabs and phases

- Offen-Tab
  - Phases: "Meditation" (phase 1) and "Besinnung" (phase 2)
  - Live Activity appearance: single dynamic SF icon on the LEFT (Dynamic Island leading and compact/minimal)
  - Icon mapping: Meditation/Besinnung → app specific or emoji (legacy)

- Atem-Tab
  - Phases: Einatmen (phase 1), Halten (phase 2), Ausatmen (phase 3), Halten (phase 4)
  - Live Activity appearance: phase arrows (SF symbols) and timer; arrows mapping:
    - phase 1 → `arrow.up`
    - phase 2 → `arrow.left`
    - phase 3 → `arrow.down`
    - phase 4 → `arrow.right`
  - OwnerId: `AtemTab` must be set on activity start so widget can render arrows

- Workout-Tab
  - Phases: Belastung and Erholung
  - Live Activity appearance: TBD (suggest SF symbols or icons matching workout UI)

Notes

- ActivityAttributes.ContentState contains `endDate`, `phase: Int`, and optional `ownerId: String?` so widget can render per-tab icons safely.
- The Dynamic Island leading region should be kept stable for the app icon unless a tab explicitly requests to show a per-tab icon.
- Phase updates should never reset the countdown endDate; update only the icon when changing inner phases.

Approved: by user on 11.10.2025

## UI Placement Rules (explicit)

- The phase icon MUST replace the small app SF icon in the leading region of the Expanded Dynamic Island.
- The trailing region MUST be reserved for the timer text. There must be sufficient room for the timer to display without truncation; use `.minimumScaleFactor(0.6)` on the timer text to avoid ellipses where possible.
- For Atem-Tab the phase icon mapping is: phase 1→arrow.up, phase 2→arrow.left, phase 3→arrow.down, phase 4→arrow.right.
- For Offen-Tab the phase icon may be an emoji (🧘‍♂️ / 🍃) if preferred; it should appear in the same leading position.
- The widget should not show a separate small phase bubble in the trailing region; remove duplicate phase indicators to free space for the timer.

These rules ensure the phase symbol is prominent and the timer remains legible in the Dynamic Island Expanded layout.

Document approved and updated: 11.10.2025
