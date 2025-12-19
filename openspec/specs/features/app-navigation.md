# App Navigation

## Overview

Tab-based navigation structure for "Healthy Habits Haven". Four main tabs: Meditation, Workout, Tracker, and Achievements.

Tab-basierte Navigation für "Healthy Habits Haven". Vier Haupttabs: Meditation, Workout, Tracker und Erfolge.

---

## Tab Structure

### Tab Bar (Bottom)

```
┌───────────────────────────────────────────────────────┐
│  🧘 Meditation   💪 Workout   📊 Tracker   🏆 Erfolge │
└───────────────────────────────────────────────────────┘
```

| Tab | Icon | German | English | Purpose |
|-----|------|--------|---------|---------|
| 1 | 🧘 | Meditation | Meditation | Timer + Breathing Presets |
| 2 | 💪 | Workout | Workout | Free Timer + Programs |
| 3 | 📊 | Tracker | Tracker | Good/Saboteur/NoAlc Tracking |
| 4 | 🏆 | Erfolge | Achievements | Streaks + Rewards + Calendar |

---

## Requirements

### Requirement: Tab Bar Configuration
The system SHALL provide configurable tab order.

#### Scenario: Default Tab Order
- GIVEN user opens app for first time
- WHEN tab bar renders
- THEN tabs appear in order: Meditation, Workout, Tracker, Erfolge
- AND order is stored in AppStorage

#### Scenario: Drag & Drop Reorder
- GIVEN user is in Settings
- WHEN user accesses "Tab Order" setting
- THEN tabs can be reordered via drag & drop
- AND new order persists across app restarts

#### Scenario: Tab Order Persistence
- GIVEN user has customized tab order
- WHEN app relaunches
- THEN custom order is restored
- AND uses AppStorage for persistence

---

### Requirement: Meditation Tab
The system SHALL combine free meditation and breathing presets in one tab.

#### Scenario: Meditation Tab Layout
- GIVEN user is on Meditation tab
- WHEN tab renders
- THEN free timer configuration appears at top
- AND breathing presets appear below (scrollable)
- AND scrolling reveals presets

#### Scenario: Free Meditation Section (Top)
- GIVEN user views Meditation tab
- WHEN viewing top section
- THEN two-phase timer configuration is visible
- AND Phase 1 (Dauer) picker is available
- AND Phase 2 (Ausklang) picker is available
- AND large Start button is prominent

#### Scenario: Breathing Presets Section (Below)
- GIVEN user scrolls down on Meditation tab
- WHEN presets section is visible
- THEN list of breathing presets appears
- AND each preset shows: name, emoji, duration info
- AND tap on preset shows detail/starts session
- AND "Create Preset" option is available

#### Scenario: Start Free Meditation
- GIVEN user is in free meditation section
- WHEN user taps Start
- THEN two-phase meditation starts
- AND same behavior as current Offen-Tab

#### Scenario: Start Breathing Preset
- GIVEN user taps a breathing preset
- WHEN preset is selected
- THEN breathing session starts with preset configuration
- AND same behavior as current Atem-Tab

---

### Requirement: Workout Tab
The system SHALL combine free workout and programs in one tab.

#### Scenario: Workout Tab Layout
- GIVEN user is on Workout tab
- WHEN tab renders
- THEN free workout timer appears at top
- AND workout programs appear below (scrollable)
- AND scrolling reveals programs

#### Scenario: Free Workout Section (Top)
- GIVEN user views Workout tab
- WHEN viewing top section
- THEN count-up timer is visible
- AND Start button is prominent
- AND elapsed time display (when running)

#### Scenario: Workout Programs Section (Below)
- GIVEN user scrolls down on Workout tab
- WHEN programs section is visible
- THEN list of workout programs appears
- AND each program shows: name, duration, exercise count
- AND tap on program shows detail/starts session
- AND "Create Program" option is available

#### Scenario: Start Free Workout
- GIVEN user is in free workout section
- WHEN user taps Start
- THEN count-up timer starts
- AND same behavior as current Frei-Tab

#### Scenario: Start Workout Program
- GIVEN user taps a workout program
- WHEN program is selected
- THEN structured workout starts
- AND same behavior as current Workout-Tab programs

---

### Requirement: Tracker Tab
The system SHALL provide quick access to all trackers including NoAlc.

#### Scenario: Tracker Tab Layout
- GIVEN user is on Tracker tab
- WHEN tab renders
- THEN NoAlc section appears prominently at top
- AND Good Trackers section follows
- AND Saboteur Trackers section follows
- AND "Add Tracker" button is available

#### Scenario: NoAlc Section (Top)
- GIVEN user views Tracker tab
- WHEN viewing NoAlc section
- THEN current streak is visible
- AND quick-log buttons (Steady/Easy/Wild) are available
- AND today's status is shown
- AND reward count is visible

#### Scenario: Good Trackers Section
- GIVEN user views Good Trackers section
- WHEN section renders
- THEN list of Good Trackers appears
- AND each shows: icon, name, today's status, quick-log button
- AND counter trackers show current/goal (e.g., "5/8")
- AND Yes/No trackers show checkmark if done

#### Scenario: Saboteur Trackers Section
- GIVEN user views Saboteur Trackers section
- WHEN section renders
- THEN list of Saboteur Trackers appears
- AND each shows: icon, name, today's count
- AND "Notice" button for quick awareness logging

#### Scenario: Quick-Log from Tracker Tab
- GIVEN user is on Tracker tab
- WHEN user taps quick-log button on any tracker
- THEN log is created immediately
- AND visual feedback confirms action
- AND streak/status updates

#### Scenario: Add New Tracker
- GIVEN user taps "Add Tracker"
- WHEN creation sheet appears
- THEN user can choose: Good Tracker or Saboteur Tracker
- AND predefined suggestions are offered
- AND custom creation is possible

#### Scenario: Edit Tracker
- GIVEN user long-presses or taps edit on a tracker
- WHEN edit mode activates
- THEN tracker settings are editable
- AND includes: name, icon, goal, widget visibility, calendar visibility

---

### Requirement: Achievements Tab (Erfolge)
The system SHALL display streaks, rewards, and calendar for motivation and progress visualization.

#### Scenario: Achievements Tab Layout
- GIVEN user is on Achievements tab (Erfolge)
- WHEN tab renders
- THEN Streaks/Rewards header appears at top
- AND Calendar grid appears below
- AND month navigation is available

#### Scenario: Streaks Header
- GIVEN user views Achievements tab
- WHEN header renders
- THEN meditation streak shows (🧘 X days)
- AND workout streak shows (💪 X days)
- AND NoAlc streak shows (🍀 X days)
- AND available rewards show (⭐ X)
- AND tap on streak shows detail/info

#### Scenario: Calendar Grid
- GIVEN user views calendar section
- WHEN calendar renders
- THEN monthly grid displays
- AND activity rings appear on days with data
- AND Focus Trackers appear as additional rings (if configured)
- AND current day is highlighted

#### Scenario: Day Detail
- GIVEN user taps a day in calendar
- WHEN day detail opens
- THEN all activities for that day are listed
- AND includes: meditation, workout, NoAlc, custom trackers
- AND allows historical logging (e.g., forgot to log NoAlc)

---

### Requirement: Settings Access
The system SHALL provide consistent settings access.

#### Scenario: Settings Button
- GIVEN user is on any tab
- WHEN looking for settings
- THEN gear icon is in navigation bar (top right)
- AND tap opens Settings sheet

#### Scenario: Settings Sheet Contents
- GIVEN Settings sheet is open
- WHEN viewing settings
- THEN includes: Daily Goals, Audio, HealthKit, Tab Order, Smart Reminders
- AND Tab Order section allows drag & drop reordering

---

## Visual Mockups

### Meditation Tab
```
┌─────────────────────────────────┐
│ Meditation              ⚙️      │ ← Nav bar with Settings
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │      Freie Meditation       │ │
│ │                             │ │
│ │   Dauer      Ausklang       │ │
│ │   [15 min]   [3 min]        │ │
│ │                             │ │
│ │        [ ▶ Start ]          │ │
│ └─────────────────────────────┘ │
│                                 │
│ Atemübungen                     │
│ ┌─────────────────────────────┐ │
│ │ 🌙 4-7-8 Entspannung    >   │ │
│ ├─────────────────────────────┤ │
│ │ 📦 Box Breathing        >   │ │
│ ├─────────────────────────────┤ │
│ │ 😌 Relaxing             >   │ │
│ ├─────────────────────────────┤ │
│ │ ➕ Preset erstellen         │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

### Tracker Tab
```
┌─────────────────────────────────┐
│ Tracker                 ⚙️      │
├─────────────────────────────────┤
│ NoAlc                   🍀 21   │
│ ┌─────────────────────────────┐ │
│ │ [Steady] [Easy] [Wild]      │ │
│ │ Heute: ✓ Steady  ⭐ 2       │ │
│ └─────────────────────────────┘ │
│                                 │
│ Positiv-Tracker                 │
│ ┌─────────────────────────────┐ │
│ │ 💧 Wasser         5/8   [+] │ │
│ │ 😊 Stimmung       —     [+] │ │
│ │ 🦷 Zähneputzen    ✓         │ │
│ └─────────────────────────────┘ │
│                                 │
│ Saboteur-Tracker                │
│ ┌─────────────────────────────┐ │
│ │ 📱 Doomscrolling  2x    [!] │ │
│ │ 🍫 Snacking       0x    [!] │ │
│ └─────────────────────────────┘ │
│                                 │
│ [+ Tracker hinzufügen]          │
└─────────────────────────────────┘
```

### Achievements Tab (Erfolge)
```
┌─────────────────────────────────┐
│ 🏆 Erfolge              ⚙️      │
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ 🧘 14 Tage   💪 7 Tage      │ │
│ │ 🍀 21 Tage   ⭐ 2 Rewards   │ │
│ └─────────────────────────────┘ │
│                                 │
│ ◀  November 2025  ▶            │
│ ┌─────────────────────────────┐ │
│ │ Mo Di Mi Do Fr Sa So        │ │
│ │                    1  2     │ │
│ │  3  4  5  6  7  8  9        │ │
│ │ ○○ ○○ ○○ ○○ ○○    ○○        │ │
│ │ 10 11 12 13 14 15 16        │ │
│ │ ○○ ○○ ○○ ○○ ●● ○○           │ │
│ │ 17 18 19 20 21 22 23        │ │
│ │    ...                       │ │
│ └─────────────────────────────┘ │
│                                 │
│ ○○ = Activity Rings (Meditation,│
│      Workout, NoAlc, Focus)     │
└─────────────────────────────────┘
```

---

## Design Decisions

| Decision | Choice |
|----------|--------|
| **Tab Count** | 4 tabs (down from 5) |
| **Tab Order** | Configurable via drag & drop in Settings |
| **Intra-Tab Navigation** | Scrolling (free timer top, presets/programs below) |
| **NoAlc Location** | Tracker Tab (prominent, top section) |
| **Settings Access** | Gear icon in nav bar (consistent across all tabs) |
| **Meditation + Breathing** | Combined in one tab (both are "meditation") |
| **Workout + Programs** | Combined in one tab (both are "workout") |

---

## Technical Notes

- **Tab Order Storage:** AppStorage with array of tab identifiers
- **Scroll Position:** Remember scroll position per tab (optional)
- **Deep Links:** Support opening specific tab via URL scheme or App Intent
- **Live Activity:** Each tab can own a Live Activity (same as today)

---

## Migration from Current Structure

| Current | New |
|---------|-----|
| Offen-Tab | → Meditation Tab (top section) |
| Atem-Tab | → Meditation Tab (presets section) |
| Frei-Tab | → Workout Tab (top section) |
| Workout-Tab | → Workout Tab (programs section) |
| Kalender-Tab | → Achievements Tab (Erfolge) |
| (new) | → Tracker Tab |

---

## References

- `openspec/specs/app-vision.md` - Healthy Habits Haven Vision
- `openspec/specs/features/trackers.md` - Tracker functionality
- `openspec/specs/features/meditation-timer.md` - Two-phase timer
- `openspec/specs/features/breathing.md` - Breathing presets
- `openspec/specs/features/workouts.md` - Workout programs
- `openspec/specs/features/calendar-view.md` - Calendar display
