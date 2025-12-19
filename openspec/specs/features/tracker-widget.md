# Tracker Widget

## Overview

Interactive widgets for quick-logging of Awareness Trackers and Activity Trackers. The widget enables **spontaneous awareness capture** - when a moment of mindfulness occurs, the user can log it immediately without opening the app.

Interaktive Widgets zum schnellen Loggen von Awareness- und Aktivitäts-Trackern. Das Widget ermöglicht **spontanes Erfassen von Achtsamkeitsmomenten** - wenn ein Moment der Bewusstheit eintritt, kann der User ihn sofort loggen ohne die App zu öffnen.

**Core Insight / Kernerkenntnis:**
The widget is NOT just for "checking off habits" - it's a tool for capturing awareness moments as they happen. Each tap is a mindful pause.

Das Widget ist NICHT nur zum "Abhaken von Gewohnheiten" - es ist ein Werkzeug zum Erfassen von Achtsamkeitsmomenten, wenn sie passieren. Jeder Tap ist eine bewusste Pause.

## User Stories

### US-W1: Achtsamkeitsmoment erfassen
Als Henning möchte ich **einen Moment der Bewusstheit sofort festhalten**, ohne die App zu öffnen - damit der Achtsamkeitsmoment nicht vergeht.

### US-W2: Überblick auf einen Blick
Als Henning möchte ich auf dem Home Screen **sehen, ob ich heute schon reflektiert habe** - als sanfte Erinnerung zur Achtsamkeit.

### US-W3: Spontanes Wahrnehmen vom Sperrbildschirm
Als Henning möchte ich **vom Sperrbildschirm aus loggen**, wenn ich kurz mein Handy checke - damit ich spontane Achtsamkeitsmomente erfassen kann.

### US-W4: Saboteur bewusst wahrnehmen
Als Henning möchte ich **schnell notieren wenn ich einen Autopiloten bemerke** - damit der Moment der Erkenntnis festgehalten wird (ohne Bewertung).

### US-W5: Selbst bestimmen was ich sehe
Als Henning möchte ich **selbst entscheiden welche Tracker im Widget erscheinen** - damit nur die wichtigsten Achtsamkeitsübungen sichtbar sind.

---

## Requirements

### Requirement: Awareness Capture from Home Screen
The system SHALL enable one-tap awareness logging directly from Home Screen widgets.

#### Scenario: Log Awareness Tracker (Mood/Feelings)
- GIVEN Home Screen widget displays Awareness Tracker "Stimmung"
- AND tracker captures current state (selection type)
- WHEN user taps the tracker button
- THEN quick selection appears (emoji options)
- AND user selects current mood/feeling
- AND widget shows brief "Wahrgenommen" feedback
- AND app does NOT open

#### Scenario: Log Awareness Tracker (Gratitude)
- GIVEN Home Screen widget displays Awareness Tracker "Dankbarkeit"
- AND tracker is reflection type (Log + Note)
- WHEN user taps the tracker button
- THEN "Dankbarkeitsmoment erfasst" feedback shows
- AND gratitude log is created with timestamp
- AND opens app for optional note entry (if desired)

#### Scenario: Log Activity Tracker (Counter Type)
- GIVEN Home Screen widget displays Activity Tracker "Wasser"
- AND tracker is counter-based (e.g., glasses of water)
- WHEN user taps the tracker button
- THEN count increases by 1
- AND widget shows brief success feedback
- AND display updates (e.g., "5/8" → "6/8")
- AND app does NOT open

#### Scenario: Log Saboteur Tracker (Awareness Mode)
- GIVEN Home Screen widget displays Saboteur Tracker "Doomscrolling"
- AND tracker is in Awareness mode
- WHEN user taps the tracker button
- THEN awareness moment is logged with timestamp
- AND widget shows "Bemerkt!" / "Noticed!" feedback (non-judgmental)
- AND counter increases (e.g., "2x heute" → "3x heute")
- AND NO negative connotation in feedback

#### Scenario: Visual Feedback After Log
- GIVEN user taps any tracker in widget
- WHEN log is successful
- THEN brief animation plays (checkmark, pulse, or similar)
- AND feedback disappears after ~1 second
- AND widget returns to normal state with updated data

---

### Requirement: Awareness Status Display
The system SHALL show current awareness/tracker status in the widget.

#### Scenario: Awareness Tracker Status (Selection Type)
- GIVEN widget displays Awareness Tracker "Stimmung" or "Gefühle"
- WHEN tracker has NOT been logged today
- THEN shows: Icon + Name + tap-target with "?"
- AND example: "😊 Stimmung ?"
- AND invites reflection: "Wie fühlst du dich?"

- GIVEN widget displays Awareness Tracker
- WHEN tracker HAS been logged today
- THEN shows: Icon + Name + selected emoji
- AND example: "😊 Stimmung: 😌" (selected mood)
- AND can be tapped again for additional reflection

#### Scenario: Awareness Tracker Status (Gratitude)
- GIVEN widget displays "Dankbarkeit" tracker
- WHEN NOT yet reflected today
- THEN shows: Icon + Name + tap-target
- AND example: "🙏 Dankbarkeit" with circle button

- GIVEN widget displays "Dankbarkeit" tracker
- WHEN already reflected today
- THEN shows: Icon + Name + count
- AND example: "🙏 Dankbarkeit: 2x"
- AND button remains active (multiple reflections welcome)

#### Scenario: Activity Tracker Status (Counter)
- GIVEN widget displays Activity Tracker "Wasser"
- WHEN widget renders
- THEN shows: Icon + Name + "X/Y" (current/goal)
- AND example: "💧 Wasser: 5/8"

#### Scenario: Saboteur Tracker Status (Awareness Mode)
- GIVEN widget displays Saboteur Tracker in Awareness mode
- WHEN widget renders
- THEN shows: Icon + Name + "Xx" (times noticed today)
- AND example: "📱 Doomscrolling: 2x"
- AND neutral display (no judgment indicators)

#### Scenario: Saboteur Tracker Status (Avoidance Mode)
- GIVEN widget displays Saboteur Tracker in Avoidance mode
- WHEN widget renders
- THEN shows: Icon + Name + streak days
- AND example: "📱 Doomscrolling: 5 Tage"

---

### Requirement: Lock Screen Widget
The system SHALL provide Lock Screen widgets for quick access.

#### Scenario: Lock Screen Widget Display
- GIVEN user has added Lock Screen widget
- WHEN Lock Screen is visible
- THEN widget shows single tracker with compact display
- AND shows: Icon + abbreviated name + status

#### Scenario: Lock Screen Quick-Log
- GIVEN Lock Screen widget is visible
- WHEN user taps widget
- THEN log is created (same as Home Screen)
- AND brief haptic feedback confirms action
- AND device does NOT need to be unlocked

#### Scenario: Lock Screen Widget Size
- GIVEN Lock Screen has limited space
- WHEN displaying tracker
- THEN only essential info shows (icon + mini-status)
- AND fits in circular or rectangular Lock Screen slot

---

### Requirement: Control Center Widget (iOS 18+)
The system SHALL provide Control Center access for quick logging.

#### Scenario: Control Center Toggle
- GIVEN user has added Control Center widget
- WHEN user opens Control Center
- THEN tracker button is available
- AND shows current status
- AND tap logs immediately

---

### Requirement: Widget Configuration
The system SHALL allow users to configure which trackers appear in widgets.

#### Scenario: Enable Widget Visibility per Tracker
- GIVEN user is editing a Tracker in app
- WHEN viewing tracker settings
- THEN "Show in Widget" toggle is available
- AND default is OFF for new trackers
- AND setting persists

#### Scenario: Configure Widget Order
- GIVEN user has multiple trackers with "Show in Widget" enabled
- WHEN viewing widget settings or tracker list
- THEN user can set display order (drag & drop or number)
- AND order determines position in widget

#### Scenario: Widget Respects Order
- GIVEN widget displays multiple trackers
- WHEN rendering trackers
- THEN trackers appear in user-defined order
- AND most important trackers appear first

#### Scenario: Maximum Trackers per Widget Size
- GIVEN widget has size constraint
- WHEN more trackers enabled than fit
- THEN widget shows trackers up to maximum:
  - Small: 2 trackers
  - Medium: 4 trackers
  - Large: 6 trackers
  - Lock Screen: 1 tracker
- AND remaining trackers are not shown (order determines priority)

---

### Requirement: Multiple Widget Instances
The system SHALL support multiple widget instances with different configurations.

#### Scenario: Add Multiple Widgets
- GIVEN user wants different widgets for different contexts
- WHEN adding widgets to Home Screen
- THEN each widget instance can show different trackers
- AND example: "Morning Routine" widget + "Evening Check" widget

#### Scenario: Widget Instance Configuration
- GIVEN user long-presses widget
- WHEN selecting "Edit Widget"
- THEN can select which trackers to show in THIS instance
- AND independent of global "Show in Widget" setting

---

### Requirement: Data Synchronization
The system SHALL keep widget data synchronized with app data.

#### Scenario: Widget Updates After App Log
- GIVEN user logs tracker in main app
- WHEN returning to Home Screen
- THEN widget shows updated status
- AND uses WidgetKit timeline refresh

#### Scenario: App Updates After Widget Log
- GIVEN user logs via widget
- WHEN opening main app
- THEN app shows the log created via widget
- AND streak calculations include widget logs

#### Scenario: Offline Widget Logging
- GIVEN device has no network connection
- WHEN user logs via widget
- THEN log is stored locally (SwiftData)
- AND syncs when connection restored (if iCloud enabled later)

#### Scenario: Smart Reminder Cancellation
- GIVEN Smart Reminder is scheduled for tracker
- AND reminder time is within next 24 hours
- WHEN user logs via widget
- THEN matching Smart Reminder is cancelled
- AND uses same `cancelMatchingReminders(for:completedAt:)` as in-app logging
- AND no duplicate reminder appears

---

## Widget Sizes

### Small Widget (2 Trackers)
```
┌─────────────────┐
│ 😊 Stimmung [?] │
│                 │
├─────────────────┤
│ 🙏 Dankbar  [○] │
│                 │
└─────────────────┘
```

### Medium Widget (4 Trackers)
```
┌─────────────────────────────────┐
│ 😊 Stimmung: 😌         [○]    │ ← Bereits reflektiert
│ 💭 Gefühle              [?]    │ ← Noch nicht
│ 🙏 Dankbarkeit: 1x      [○]    │
│ 📱 Doomscrolling: 2x    [!]    │ ← Bemerkt (neutral)
└─────────────────────────────────┘
```

### Large Widget (6 Trackers + Header)
```
┌─────────────────────────────────┐
│  Achtsamkeit             heute │
├─────────────────────────────────┤
│ 😊 Stimmung: 😌          [○]   │
│ 💭 Gefühle               [?]   │
│ 🙏 Dankbarkeit: 2x       [○]   │
│ 💧 Wasser: 5/8           [+]   │
│ 📱 Doomscrolling: 2x     [!]   │
│ 🍫 Snacking: 0x          [!]   │
└─────────────────────────────────┘
```

### Lock Screen Widget
```
┌─────┐
│ 😊  │  ← Stimmung: Nicht reflektiert
│  ?  │
└─────┘

┌─────┐
│ 😊  │  ← Stimmung: Reflektiert
│ 😌  │
└─────┘
```

---

## Design Decisions

1. **No Streak in Widget** - Widget focuses on awareness capture, not motivation display. Streaks are visible in main app Achievements tab (Erfolge).
2. **Goal NOT Editable in Widget** - Goals are configured in main app only. Widget shows progress toward existing goal.
3. **Smart Reminder Cancellation: YES** - Widget log triggers `cancelMatchingReminders()` same as in-app logging. This is the CORE of the smart system.
4. **No Timer Start in Widget** - This widget is for Tracker awareness only. Timer features remain in existing Live Activity widget.
5. **Multiple Reflections Welcome** - For Awareness Trackers (Mood, Feelings, Gratitude), users CAN log multiple times per day. Each is a separate awareness moment.
6. **Non-Judgmental Feedback** - All feedback text is neutral/positive. "Bemerkt!" not "Erwischt!". "Wahrgenommen" not "Geschafft".

---

## Widget + Smart Reminder Synergy

The Widget and Smart Reminders work together as a **two-part awareness system**:

```
┌─────────────────────────────────────────────────────────┐
│                    WIDGET                               │
│         Captures SPONTANEOUS awareness moments          │
│  "I just noticed I'm feeling anxious" → tap → logged    │
└─────────────────────────────────────────────────────────┘
                           +
┌─────────────────────────────────────────────────────────┐
│               SMART REMINDER                            │
│         Prompts reflection if NOT yet done today        │
│    "Have you reflected on your mood today?" (20:00)     │
│           → Only fires if NOT already logged            │
└─────────────────────────────────────────────────────────┘
                           =
┌─────────────────────────────────────────────────────────┐
│              DAILY AWARENESS GUARANTEED                 │
│   Either spontaneous (Widget) OR prompted (Reminder)    │
│      But NEVER annoying (no duplicate reminders)        │
└─────────────────────────────────────────────────────────┘
```

**Key Insight:** The Smart Reminder is NOT a "nag" - it's a gentle invitation for those days when awareness didn't happen spontaneously.

---

## Technical Notes

- **Framework:** WidgetKit with App Intents (iOS 17+ for interactivity)
- **Data Storage:** SwiftData shared via App Group
- **Timeline:** Update on each log + periodic refresh
- **Interactivity:** `Button` with `AppIntent` for direct logging
- **Lock Screen:** `WidgetFamily.accessoryCircular` / `.accessoryRectangular`
- **Control Center:** `ControlWidget` (iOS 18+)

Reference Standards:
- `.agent-os/standards/swiftui/lifecycle-patterns.md`
- `openspec/specs/features/trackers.md` (Tracker data model)

---

## References

- `openspec/specs/app-vision.md` - "Quick-Log First" + "Logging IS the Exercise" principles
- `openspec/specs/features/trackers.md` - Awareness-First tracker philosophy
- `openspec/specs/features/smart-reminders.md` - Smart Reminder logic (only if not logged)
- `openspec/specs/platforms/widget.md` - Existing widget infrastructure
