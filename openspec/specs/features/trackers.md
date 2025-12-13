# Trackers (Custom Trackers)

## Overview

Custom Trackers allow users to track count-based habits beyond the built-in features (Meditation, Workouts, NoAlc).

**Terminology / Begriffe:**
| English | Deutsch | Description |
|---------|---------|-------------|
| Tracker | Tracker | Count-based logging tool |
| Good Tracker | Positiv-Tracker | Positive habits to build (Hydration, Stretching) |
| Saboteur Tracker | Saboteur-Tracker | Negative autopilots to notice (Doomscrolling) |

### Core Principle: Awareness Before Avoidance

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
- THEN suggestions are displayed:
  - Good: Hydration, Stretching, Reading, Journaling, Walking
  - Saboteur: Doomscrolling, Procrastination, Snacking, Nail biting
- AND user can choose suggestion or create custom

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

### [OPEN] Scaling with Many Trackers
- Current: 3 concentric rings (Mindfulness, Workout, NoAlc)
- With many custom trackers: How to visualize?
- **Options:**
  - A: More rings (max 5-6, then cluttered)
  - B: Aggregated "Tracker Score" + detail on tap
  - C: User selects 2-3 "Focus Trackers" for rings, rest in list
- **Decision:** TBD after UI prototyping

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

### [OPEN] Scaling with Many Reminders
- With 10+ trackers: Avoid notification spam
- **Options:**
  - A: Max X tracker reminders per day (user-configured)
  - B: Grouped "Tracker Check-In" notification
  - C: Smart prioritization (only for missed trackers)
- **Decision:** TBD

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

### Storage
- Custom Trackers: SwiftData (not HealthKit - no standard types)
- Exception: Hydration could use HKQuantityTypeIdentifier.dietaryWater
- Tracker definitions: Local storage (no iCloud sync for MVP)

### Data Model (conceptual) / Datenmodell (konzeptuell)
```
Tracker
├── id: UUID
├── name: String
├── icon: String (SF Symbol or Emoji)
├── type: .good | .saboteur
├── trackingMode: .counter | .yesNo | .awareness | .avoidance
├── createdAt: Date
└── isActive: Bool

TrackerLog
├── id: UUID
├── trackerId: UUID
├── timestamp: Date
├── value: Int? (for Counter)
├── note: String?
├── trigger: String? (for Saboteur Trackers)
└── location: String? (optional)
```

### Integration with Existing System / Integration mit bestehendem System
- Smart Reminders: Extension of existing system / Erweiterung des bestehenden Systems
- Calendar: New ring types or aggregated display / Neue Ring-Typen oder aggregierte Darstellung
- Streaks: Extension of StreakManager or dedicated TrackerStreakManager

---

## Open Questions / Offene Fragen

1. **Calendar Visualization**: How to display with 5+ trackers? (see above)
   - Kalender-Visualisierung: Wie bei 5+ Trackers? (siehe oben)
2. **Reminder Scaling**: How to handle many trackers? (see above)
   - Reminder-Skalierung: Wie bei vielen Trackers? (siehe oben)
3. **HealthKit Integration**: Which Good Trackers should use HealthKit?
   - HealthKit-Integration: Welche Good Trackers sollen HealthKit nutzen?
4. ~~**iCloud Sync**: Should custom trackers sync across devices?~~ → **Decided: No, local only for MVP**
5. ~~**Widget**: Should there be a tracker widget?~~ → **Decided: Not for MVP**
6. ~~**Watch**: Should trackers be trackable on Watch?~~ → **Decided: iPhone only for MVP**

---

## References / Referenzen

- `.agent-os/standards/healthkit/date-semantics.md` (Forward Iteration for Streaks)
- `openspec/specs/features/noalc-tracker.md` (Pattern for Streak with Rewards)
- `openspec/specs/features/smart-reminders.md` (Reminder System)
