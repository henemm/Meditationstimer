# Trackers (Custom Trackers)

## Overview

Custom Trackers enable conscious awareness of habits, feelings, and behaviors. The act of logging itself is the mindfulness exercise - not just documentation.

Custom Trackers ermöglichen bewusstes Wahrnehmen von Gewohnheiten, Gefühlen und Verhaltensweisen. Das Loggen selbst ist die Achtsamkeitsübung - nicht nur Dokumentation.

**Terminology / Begriffe:**
| English | Deutsch | Description |
|---------|---------|-------------|
| Tracker | Tracker | Awareness and logging tool |
| Good Tracker | Positiv-Tracker | Positive habits and awareness exercises |
| Saboteur Tracker | Saboteur-Tracker | Negative autopilots to notice consciously |

---

## Core Philosophy: Awareness-First

### The Logging IS the Exercise

| Traditional Approach | Awareness-First Approach |
|---------------------|--------------------------|
| "Did I do the good thing?" | "Did I pause and notice?" |
| "Did I avoid the bad thing?" | "Did I become aware?" |
| Logging = Documentation | **Logging = Mindfulness Exercise** |

### Why This Matters

**Gratitude Example:**
- ❌ Old: "Was I grateful today? Yes ✓" (meaningless checkbox)
- ✅ New: The act of logging "I'm grateful for [...]" IS the gratitude practice

**Mood Example:**
- ❌ Old: "Rate your mood 1-5" (judgment)
- ✅ New: "What am I feeling right now?" (awareness without judgment)

**Saboteur Example:**
- ❌ Old: "I failed and scrolled again" (shame)
- ✅ New: "I notice I'm scrolling" (awareness = first step to change)

### The Awareness Progression

```
1. AWARENESS     →    2. PATTERNS    →    3. CHOICE
"I notice..."        "I see that..."      "I choose to..."

Logging captures      Over time,           Awareness enables
the moment of        patterns emerge       conscious choice
awareness            from data             (optional)
```

### Smart Reminder + Widget = Awareness Tools

| Tool | Purpose |
|------|---------|
| **Widget** | Capture spontaneous awareness moments quickly |
| **Smart Reminder** | Prompt daily reflection if not yet done |
| **Reminder fires only if NOT logged** | Already reflected = no nagging |

---

## Tracker Categories

### Awareness Trackers (Logging = The Exercise)

| Tracker | What You Log | The Awareness Exercise |
|---------|--------------|------------------------|
| Stimmung | What mood am I in? | Pausing to notice internal state |
| Gefühle | What emotions am I feeling? | Identifying and naming feelings |
| Dankbarkeit | What am I grateful for? | Conscious appreciation |
| Saboteure | I notice I'm doing [behavior] | Non-judgmental observation |

### Activity Trackers (Logging = Documentation)

| Tracker | What You Log | Purpose |
|---------|--------------|---------|
| Wasser | How much I drank | Track progress toward goal |
| NoAlc | Consumption level | Track abstinence with rewards |

### Core Principle for Saboteur Trackers

Saboteur Trackers use a two-stage model:
1. **Awareness Mode**: First become aware of when the behavior occurs
2. **Avoidance Mode**: Later actively avoid (optional, when ready)

This progression is based on psychological research (Stages of Change) - you cannot change a behavior you don't notice.

### Distinction from Built-in Features

| Feature | Type | Custom Tracker? |
|---------|------|-----------------|
| Meditation | Built-in (Timer) | ❌ No |
| Breathing | Built-in (Timer) | ❌ No |
| Workouts | Built-in (Timer) | ❌ No |
| NoAlc | Built-in (Tracker) | ❌ No |
| **Hydration** | Custom Tracker | ✅ Good Tracker |
| **Doomscrolling** | Custom Tracker | ✅ Saboteur Tracker |

---

## Requirements

### Requirement: Tracker Creation
The system SHALL allow users to create custom trackers.

#### Scenario: Create Good Tracker
- GIVEN user is in Trackers section
- WHEN user selects "Add Good Tracker" / "Positiv-Tracker hinzufügen"
- THEN user can enter name (e.g. "Drink water" / "Wasser trinken")
- AND can choose Icon/Emoji
- AND can choose tracking type (Counter or Yes/No)
- AND tracker appears in Good Trackers list

#### Scenario: Create Saboteur Tracker
- GIVEN user is in Trackers section
- WHEN user selects "Add Saboteur Tracker" / "Saboteur-Tracker hinzufügen"
- THEN user can enter name (e.g. "Doomscrolling")
- AND can choose Icon/Emoji
- AND mode is initially "Awareness" (not Avoidance)
- AND tracker appears in Saboteur Trackers list

#### Scenario: Predefined Suggestions
- GIVEN user wants to add tracker
- WHEN selection sheet opens
- THEN predefined presets are displayed (see Presets section below)
- AND user can choose preset or create custom tracker

---

## Presets

### Awareness Tracker Presets (Logging = The Exercise)

| Preset | Icon | Type | HealthKit | DE | EN | Awareness Exercise |
|--------|------|------|-----------|----|----|-------------------|
| Stimmung | 😊 | Selection | `HKStateOfMind` | Stimmung | Mood | "What mood am I in right now?" |
| Gefühle | 💭 | Selection | `HKStateOfMind` | Gefühle | Feelings | "What emotions am I feeling?" |
| Dankbarkeit | 🙏 | Log + Note | - | Dankbarkeit | Gratitude | "What am I grateful for right now?" |

**Selection Options for Stimmung/Mood:**
```
Wie fühlst du dich gerade? / How are you feeling?

😊 Freudig / Joyful       😌 Entspannt / Relaxed    🤔 Nachdenklich / Thoughtful
😟 Ängstlich / Anxious    😤 Ärgerlich / Irritated  😢 Traurig / Sad
😐 Neutral / Neutral      🥱 Müde / Tired          ⚡ Energiegeladen / Energized
```

**Selection Options for Gefühle/Feelings:**
```
Welche Gefühle bemerkst du? / What feelings do you notice?
(Multi-select possible)

❤️ Liebe / Love           😊 Freude / Joy          🙏 Dankbarkeit / Gratitude
😰 Angst / Fear           😤 Ärger / Anger         😢 Trauer / Sadness
😔 Enttäuschung / Disappointment  🤗 Verbundenheit / Connection
```

**Dankbarkeit/Gratitude Log:**
```
Wofür bist du gerade dankbar? / What are you grateful for?

[Free text input or quick-select common items]
Optional: Add note with details
```

### Activity Tracker Presets (Logging = Documentation)

| Preset | Icon | Type | HealthKit | DE | EN | Purpose |
|--------|------|------|-----------|----|----|---------|
| Wasser | 💧 | Counter | `dietaryWater` | Wasser trinken | Drink Water | Track hydration goal |

### Saboteur Tracker Presets (Awareness Mode)

| Preset | Icon | Mode | DE | EN | Awareness Prompt |
|--------|------|------|----|----|------------------|
| Doomscrolling | 📱 | Awareness | Doomscrolling | Doomscrolling | "I notice I'm scrolling..." |
| Snacking | 🍫 | Awareness | Snacking | Snacking | "I notice I'm eating without hunger..." |
| Prokrastination | 🛋️ | Awareness | Prokrastination | Procrastination | "I notice I'm avoiding..." |
| Grübeln | 💭 | Awareness | Grübeln | Rumination | "I notice I'm stuck in thoughts..." |
| Handy im Gespräch | 📵 | Awareness | Handy während Gesprächen | Phone During Conversations | "I notice I reached for my phone..." |

### Preset Behavior

#### Scenario: Select Awareness Preset
- GIVEN user selects an awareness preset (Stimmung, Gefühle, Dankbarkeit)
- WHEN preset is chosen
- THEN tracker is created with selection options or note field
- AND logging UI prompts reflection ("What are you feeling?")
- AND the logging moment itself is the mindfulness exercise

#### Scenario: Select Activity Preset
- GIVEN user selects an activity preset (Wasser)
- WHEN preset is chosen
- THEN tracker is created with counter and optional goal
- AND logging tracks quantity toward goal

#### Scenario: Select Saboteur Preset
- GIVEN user selects a saboteur preset
- WHEN preset is chosen
- THEN tracker is created in Awareness Mode (not Avoidance)
- AND logging prompts non-judgmental observation
- AND optional trigger/note field is available

#### Scenario: Custom Tracker
- GIVEN user wants a tracker not in presets
- WHEN user selects "Custom" / "Eigener Tracker"
- THEN creation form asks: Awareness Tracker or Activity Tracker?
- AND appropriate fields are shown based on type
- AND HealthKit mapping is suggested if applicable

---

### Requirement: Good Tracker Logging
The system SHALL support logging of positive habits via Good Trackers.

#### Scenario: Counter-based Tracking
- GIVEN user has Good Tracker with counter type (e.g. "Glasses of water")
- WHEN user logs entry
- THEN user can enter amount (e.g. 1, 2, 3...)
- AND total for today is updated
- AND entry is saved with timestamp

#### Scenario: Yes/No Tracking
- GIVEN user has Good Tracker with Yes/No type (e.g. "Read today")
- WHEN user logs entry
- THEN day is marked as "done"
- AND multiple logs on same day have no effect

#### Scenario: Quick-Log from Notification
- GIVEN Smart Reminder for Good Tracker fires
- WHEN user sees notification
- THEN Quick-Actions are available
- AND tap on action logs directly (without opening app)

---

### Requirement: Saboteur Tracker (Awareness Mode)
The system SHALL enable conscious awareness of negative habits.

#### Scenario: Create Awareness Log
- GIVEN user has Saboteur Tracker in Awareness mode
- WHEN user notices the behavior
- THEN user can log "I notice [Saboteur]" / "Ich bemerke [Saboteur]"
- AND optionally add note (trigger, context)
- AND timestamp is saved
- AND counter for today increases

#### Scenario: Awareness Streak
- GIVEN Saboteur Tracker is in Awareness mode
- AND user has logged at least 1x for X consecutive days
- WHEN streak is displayed
- THEN shows "X days aware" / "X Tage bewusst" (Awareness Streak)
- AND streak rewards self-observation, not avoidance

#### Scenario: Trigger Documentation
- GIVEN user logs awareness moment
- WHEN user adds optional details
- THEN user can select/enter trigger:
  - When? (timestamp automatic)
  - Where? (Home, Work, On the go / Zuhause, Arbeit, Unterwegs)
  - Why? (Boredom, Stress, Habit / Langeweile, Stress, Gewohnheit)
- AND data is saved for pattern analysis

---

### Requirement: Saboteur Tracker (Avoidance Mode)
The system SHALL support active avoidance of negative habits.

#### Scenario: Switch Mode
- GIVEN user has Saboteur Tracker in Awareness mode
- WHEN user wants to switch to Avoidance
- THEN warning is displayed: "Streak type will change" / "Streak-Typ ändert sich"
- AND after confirmation, mode switches
- AND old Awareness Streak is archived

#### Scenario: Avoidance Streak
- GIVEN Saboteur Tracker is in Avoidance mode
- AND user has X days WITHOUT log (no behavior)
- WHEN streak is displayed
- THEN shows "X days without [Saboteur]" / "X Tage ohne [Saboteur]"
- AND each log breaks streak (like NoAlc Wild)

#### Scenario: Document Relapse
- GIVEN Saboteur Tracker is in Avoidance mode
- WHEN user shows the behavior anyway
- THEN user logs the relapse
- AND streak breaks
- AND optionally: note about trigger

---

### Requirement: Calendar Visualization
The system SHALL visualize trackers in the calendar.

#### Scenario: Good Tracker in Calendar
- GIVEN calendar day has Good Tracker log
- WHEN day is displayed
- THEN indicator appears for this tracker
- AND color shows completion status (green = done)

#### Scenario: Saboteur Tracker in Calendar (Awareness)
- GIVEN calendar day has Awareness logs
- WHEN day is displayed
- THEN indicator appears
- AND shows number of conscious moments

#### Scenario: Saboteur Tracker in Calendar (Avoidance)
- GIVEN calendar day WITHOUT Saboteur Tracker log
- WHEN day is displayed
- THEN green indicator appears (successful avoidance)

#### Scenario: Focus Tracker Selection
- GIVEN user has multiple custom trackers
- WHEN user wants tracker to appear in calendar rings
- THEN user enables "Show in Calendar" for that tracker
- AND maximum 2 Focus Trackers can be enabled (beyond built-in Mindfulness/Workout/NoAlc)
- AND Focus Trackers appear as additional rings (4th and 5th ring)

#### Scenario: Focus Tracker Ring Display
- GIVEN calendar day has Focus Tracker activity
- WHEN day is displayed
- THEN Focus Tracker ring appears in configured color
- AND ring shows completion status (filled = goal met or logged)
- AND position is consistent (same tracker = same ring position)

#### Scenario: Non-Focus Tracker Visibility
- GIVEN user has trackers NOT set as Focus Trackers
- WHEN tapping on calendar day
- THEN DayDetailSheet shows ALL tracker logs for that day
- AND non-focus trackers are visible in detail view (not in rings)

---

### Requirement: Smart Reminders Integration
The system SHALL support reminders for custom trackers.

#### Scenario: Reminder for Good Tracker
- GIVEN user has created Good Tracker
- WHEN user activates reminder
- THEN time can be selected
- AND notification appears as reminder
- AND Quick-Actions enable direct logging

#### Scenario: Reminder for Saboteur Tracker (Awareness)
- GIVEN user has Saboteur Tracker in Awareness mode
- WHEN user activates "Reflection Reminder"
- THEN notification appears e.g. at 20:00
- AND asks: "Did you notice [Saboteur] today?" / "Hast du heute [Saboteur] bemerkt?"
- AND enables logging if forgotten

#### Scenario: Smart Reminder for Custom Tracker
- GIVEN user has custom tracker with reminder enabled
- WHEN reminder time is reached
- THEN Smart Reminder checks if tracker was logged today
- AND notification only fires if NOT logged (same as existing Smart Reminders)
- AND no additional scaling logic needed (Smart Reminders handle this by design)

---

### Requirement: Streak System
The system SHALL calculate streaks for custom trackers.

#### Scenario: Good Tracker Streak
- GIVEN user logs Good Tracker daily
- WHEN X consecutive days logged
- THEN shows streak "X days" / "X Tage"
- AND streak display motivates continuity

#### Scenario: Streak with Forgiveness (Good Trackers)
- GIVEN user has reward-based system (like NoAlc)
- WHEN user misses a day
- THEN reward can be consumed to save streak
- AND rewards are earned through consistent tracking

#### Scenario: Awareness Streak (Saboteur Trackers)
- GIVEN Saboteur Tracker in Awareness mode
- WHEN user has logged at least 1x for X consecutive days
- THEN shows "X days aware" / "X Tage bewusst"
- AND streak rewards active self-observation

#### Scenario: Avoidance Streak (Saboteur Trackers)
- GIVEN Saboteur Tracker in Avoidance mode
- WHEN user has X days WITHOUT log
- THEN shows "X days without [Saboteur]" / "X Tage ohne [Saboteur]"
- AND each log (relapse) breaks streak

---

### Requirement: Insights and Patterns
The system SHALL recognize patterns in Saboteur Tracker data.

#### Scenario: Time-of-Day Analysis
- GIVEN user has multiple Saboteur logs over time
- WHEN insights are displayed
- THEN shows distribution by time of day
- AND identifies "risk times" (e.g. "60% in afternoon")

#### Scenario: Trigger Analysis
- GIVEN user has documented triggers in logs
- WHEN insights are displayed
- THEN shows most frequent triggers
- AND enables targeted countermeasures

#### Scenario: Trend Display
- GIVEN user has tracked Saboteur for weeks
- WHEN insights are displayed
- THEN shows trend (more/less over time)
- AND shows progress toward reduction

---

## User Stories

### Good Trackers / Positiv-Tracker
1. As a user, I want to track my own positive habits (e.g., drinking water)
   - Als User möchte ich eigene positive Gewohnheiten tracken (z.B. Wasser trinken)
2. As a user, I want to see how many days I've maintained a habit
   - Als User möchte ich sehen wie viele Tage ich eine Gewohnheit durchgehalten habe
3. As a user, I want to be reminded when I forget a habit
   - Als User möchte ich erinnert werden, wenn ich eine Gewohnheit vergesse
4. As a user, I want to see my progress in the calendar
   - Als User möchte ich meinen Fortschritt im Kalender sehen

### Saboteur Trackers / Saboteur-Tracker
1. As a user, I want to consciously notice when I fall into autopilot behaviors
   - Als User möchte ich bewusst wahrnehmen, wann ich in Autopiloten verfalle
2. As a user, I want to understand what triggers my saboteur behaviors
   - Als User möchte ich verstehen, was meine Saboteure triggert
3. As a user, I want to see if my awareness is increasing
   - Als User möchte ich sehen, ob meine Awareness zunimmt
4. As a user, I want to switch from Awareness to Avoidance mode when ready
   - Als User möchte ich später von Awareness zu Avoidance wechseln können
5. As a user, I want to see my progress over time
   - Als User möchte ich meine Fortschritte über Zeit sehen

---

## Technical Notes

### Storage: Hybrid Approach (SwiftData + HealthKit)

Custom Trackers use **SwiftData** for definitions and **HealthKit** for logging where a matching type exists.

#### HealthKit-Mapped Trackers (Good Trackers)

| Tracker | HealthKit Type | Unit | Notes |
|---------|----------------|------|-------|
| 💧 Wasser trinken | `dietaryWater` | ml/L | Counter-based |
| ☕ Koffein-Limit | `dietaryCaffeine` | mg | Counter-based |
| 🦷 Zähneputzen | `toothbrushingEvent` | Event | Yes/No (2x daily) |
| 😊 Stimmung | `HKStateOfMind` | Scale 1-5 | iOS 17+ Mood tracking |
| 🤲 Händewaschen | `handwashingEvent` | Event | Yes/No |

#### SwiftData-Only Trackers (No HealthKit Match)

| Tracker | Reason |
|---------|--------|
| 📱 Doomscrolling | No matching HealthKit type |
| 🍫 Snacking | `dietaryEnergyConsumed` too complex |
| 💅 Nägelkauen | No matching HealthKit type |
| 🛋️ Prokrastination | No matching HealthKit type |

#### Design Decisions

1. **No Sleep Tracking** - Apple's native sleep tracking is superior. Don't reinvent.
2. **Mood/Feelings: YES** - `HKStateOfMind` (iOS 17+) integrates with Apple Health.
3. **Auto-detect HealthKit** - When creating tracker, app suggests HealthKit mapping if available.
4. **User Toggle** - "Save to Apple Health" toggle when HealthKit type exists (default: ON).

#### Storage Architecture

```
Tracker Definition (SwiftData)
├── id, name, icon, type, trackingMode
├── healthKitType: String?        ← nil if no mapping
├── showInWidget: Bool
├── widgetOrder: Int
└── dailyGoal: Int?

TrackerLog (SwiftData + HealthKit)
├── Always: SwiftData for app queries
└── If healthKitType != nil: Also write to HealthKit
```

### Tracker Definitions
- Local storage via SwiftData (no iCloud sync for MVP)

### Data Model (conceptual) / Datenmodell (konzeptuell)
```
Tracker
├── id: UUID
├── name: String
├── icon: String (SF Symbol or Emoji)
├── type: .good | .saboteur
├── trackingMode: .counter | .yesNo | .awareness | .avoidance
├── createdAt: Date
├── isActive: Bool
├── healthKitType: String?         ← NEW: HealthKit identifier (nil if no mapping)
├── saveToHealthKit: Bool          ← NEW: User toggle (default: true if healthKitType exists)
├── showInWidget: Bool             ← NEW: Show in Tracker Widget
├── widgetOrder: Int               ← NEW: Position in Widget (lower = higher priority)
├── dailyGoal: Int?                ← NEW: Target for counter-based trackers
└── showInCalendar: Bool           ← NEW: Show as Focus Tracker ring in calendar

TrackerLog
├── id: UUID
├── trackerId: UUID
├── timestamp: Date
├── value: Int? (for Counter)
├── note: String?
├── trigger: String? (for Saboteur Trackers)
├── location: String? (optional)
└── syncedToHealthKit: Bool        ← NEW: Track if successfully synced
```

### Integration with Existing System / Integration mit bestehendem System
- Smart Reminders: Extension of existing system / Erweiterung des bestehenden Systems
- Calendar: New ring types or aggregated display / Neue Ring-Typen oder aggregierte Darstellung
- Streaks: Extension of StreakManager or dedicated TrackerStreakManager

---

## Design Decisions / Entscheidungen

| Question | Decision |
|----------|----------|
| **Calendar Visualization** | Focus Tracker: User selects 1-2 trackers to show as rings. Rest visible on day tap. |
| **Reminder Scaling** | Smart Reminders already handle this: Only fire if not logged. No additional logic needed. |
| **HealthKit Integration** | Hybrid approach: Use HealthKit where type exists (see Technical Notes). User toggle per tracker. |
| **Sleep Tracking** | NO - Apple's native solution is superior. Don't reinvent. |
| **Mood/State of Mind** | YES - Use `HKStateOfMind` (iOS 17+) for mood tracking in Apple Health ecosystem. |
| **iCloud Sync** | No, local only for MVP |
| **Widget** | YES - See `tracker-widget.md` for full specification |
| **Watch** | No, iPhone only for MVP |

---

## References / Referenzen

- `.agent-os/standards/healthkit/date-semantics.md` (Forward Iteration for Streaks)
- `openspec/specs/features/noalc-tracker.md` (Pattern for Streak with Rewards)
- `openspec/specs/features/smart-reminders.md` (Reminder System)
- `openspec/specs/features/tracker-widget.md` (Widget for Quick-Logging)
- `openspec/specs/app-vision.md` (Healthy Habits Haven Vision)
