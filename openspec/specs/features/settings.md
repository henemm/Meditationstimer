# Settings

## Overview

Global configuration sheet for the app, providing controls for daily goals, audio settings, HealthKit logging options, workout audio cues, and tab order configuration. Accessible via gear icon (⚙️) in the navigation bar on all tabs.

## Requirements

### Requirement: Daily Goals Configuration
The system SHALL allow users to set daily activity goals.

#### Scenario: Meditation Goal Selection
- GIVEN user opens Settings sheet
- WHEN viewing Daily Goals section
- THEN meditation goal picker is available
- AND range is 1-120 minutes
- AND wheel picker allows selection
- AND value persists to AppStorage "meditationGoalMinutes"

#### Scenario: Workout Goal Selection
- GIVEN user opens Settings sheet
- WHEN viewing Daily Goals section
- THEN workout goal picker is available
- AND range is 1-120 minutes
- AND wheel picker allows selection
- AND value persists to AppStorage "workoutGoalMinutes"

#### Scenario: Goal Explanation Text
- GIVEN user views Daily Goals section
- WHEN section renders
- THEN explanatory text displays below header
- AND explains that progress shows as filled circles in calendar
- AND text uses .font(.caption) and .foregroundStyle(.secondary)

### Requirement: Background Sound Configuration
The system SHALL allow users to configure ambient sounds.

#### Scenario: Ambient Sound Selection
- GIVEN user is in Background Sounds section
- WHEN user taps sound picker
- THEN options display: None, Waves, Spring, Fire
- AND selection persists to AppStorage "ambientSound"

#### Scenario: Enable for Free Meditation
- GIVEN ambient sound is selected (not None)
- WHEN user toggles "Enable for Free Meditation"
- THEN setting persists to AppStorage "ambientSoundOffenEnabled"
- AND ambient sound plays during free meditation sessions (top section of Meditation Tab)

#### Scenario: Enable for Breathing Exercises
- GIVEN ambient sound is selected (not None)
- WHEN user toggles "Enable for Breathing"
- THEN setting persists to AppStorage "ambientSoundAtemEnabled"
- AND ambient sound plays during breathing preset sessions (bottom section of Meditation Tab)

#### Scenario: Sound Toggles Disabled When None
- GIVEN ambient sound is set to "None"
- WHEN viewing enable toggles
- THEN both toggles are disabled (grayed out)
- AND user cannot enable until sound is selected

#### Scenario: Preview Sound Button
- GIVEN ambient sound is selected (not None)
- WHEN user taps "Play Background Sound"
- THEN selected sound begins playing
- AND button changes to "Stop Background Sound"
- AND sound plays at configured volume

### Requirement: Volume Configuration
The system SHALL allow users to adjust ambient sound volume.

#### Scenario: Volume Slider
- GIVEN user is in Background Sound Settings section
- WHEN viewing volume control
- THEN slider displays with 0-100% range
- AND current value shows as "relative volume: X%"
- AND step size is 5%

#### Scenario: Volume Change
- GIVEN user adjusts volume slider
- WHEN slider value changes
- THEN value persists to AppStorage "ambientSoundVolume"
- AND if preview is playing, volume updates immediately

#### Scenario: Test Gong Button
- GIVEN user is in Background Sound Settings section
- WHEN user taps "Test Gong"
- THEN gong-Ende sound plays
- AND allows user to set system volume appropriately
- AND explanatory text explains this workflow

### Requirement: Breathing Sound Theme
The system SHALL allow users to select breathing exercise sound theme.

#### Scenario: Theme Selection
- GIVEN user is in Breathe Sounds section
- WHEN user taps theme picker
- THEN options display: Distinctive, Marimba, Harp, Guitar
- AND each shows emoji and name
- AND selection persists to AppStorage "atemSoundTheme"

#### Scenario: Theme Description
- GIVEN user selects a sound theme
- WHEN theme is selected
- THEN description text updates below picker
- AND describes the selected theme's character

### Requirement: Audio Cues Configuration
The system SHALL allow users to configure workout audio cues.

#### Scenario: Speak Exercise Names Toggle
- GIVEN user is in Audio Cues section
- WHEN user toggles "Speak Exercise Names"
- THEN setting persists to AppStorage "speakExerciseNames"
- AND if enabled, TTS announces exercise names during workouts

#### Scenario: Countdown Before Start Selection
- GIVEN user is in Audio Cues section
- WHEN viewing countdown picker
- THEN options range from 0-10 seconds
- AND value persists to AppStorage "countdownBeforeStart"
- AND affects countdown overlay before sessions

### Requirement: HealthKit Logging Options
The system SHALL allow users to customize HealthKit logging behavior.

#### Scenario: Log Meditation as Yoga Workout
- GIVEN user is in HealthKit section
- WHEN user toggles "Log meditations as yoga workouts"
- THEN setting persists to AppStorage "logMeditationAsYogaWorkout"
- AND if enabled, meditations also create HKWorkout (yoga type)

#### Scenario: Log Workouts as Mindfulness
- GIVEN user is in HealthKit section
- WHEN user toggles "Log workouts as mindfulness"
- THEN setting persists to AppStorage "logWorkoutsAsMindfulness"
- AND if enabled, workouts also create mindfulness sample

### Requirement: Tab Order Configuration
The system SHALL allow users to customize the order of tabs in the tab bar.

#### Scenario: Tab Order Section
- GIVEN user is in Settings sheet
- WHEN viewing Tab Order section
- THEN list of 4 tabs displays in current order:
  - 🧘 Meditation
  - 💪 Workout
  - 📊 Tracker
  - 🏆 Erfolge
- AND drag handles are visible on each row

#### Scenario: Reorder Tabs via Drag & Drop
- GIVEN user is in Tab Order section
- WHEN user drags a tab row to a new position
- THEN tabs reorder in real-time
- AND new order persists to AppStorage "tabOrder"
- AND tab bar updates immediately

#### Scenario: Tab Order Persistence
- GIVEN user has customized tab order
- WHEN app relaunches
- THEN custom order is restored
- AND tab bar shows tabs in saved order

#### Scenario: Default Tab Order
- GIVEN fresh app installation
- WHEN Settings opens
- THEN default order is: Meditation, Workout, Tracker, Erfolge
- AND order is stored in AppStorage on first launch

### Requirement: Settings Persistence
The system SHALL persist all settings across app restarts.

#### Scenario: AppStorage Persistence
- GIVEN user changes any setting
- WHEN app is closed and reopened
- THEN all settings retain their configured values
- AND UI reflects stored values

#### Scenario: Default Values
- GIVEN app is freshly installed
- WHEN user opens Settings
- THEN default values are used:
  - meditationGoalMinutes: 10
  - workoutGoalMinutes: 10
  - ambientSound: none
  - ambientSoundVolume: 45
  - atemSoundTheme: distinctive
  - speakExerciseNames: false
  - countdownBeforeStart: 0

### Requirement: Settings Sheet Presentation
The system SHALL present Settings as a modal sheet.

#### Scenario: Open Settings
- GIVEN user is on any tab
- WHEN user taps Settings button (gear icon)
- THEN SettingsSheet presents as modal
- AND navigation title shows "Settings"
- AND close button is available

#### Scenario: Close Settings
- GIVEN Settings sheet is open
- WHEN user taps close button or swipes down
- THEN sheet dismisses
- AND changes are already persisted (no "Save" needed)

## Settings Sections Overview

| Section | Contents |
|---------|----------|
| **Daily Goals** | Meditation goal, Workout goal (minutes) |
| **Background Sounds** | Ambient sound selection, volume, enable per activity type |
| **Breathe Sounds** | Sound theme for breathing exercises |
| **Audio Cues** | TTS exercise names, countdown duration |
| **HealthKit** | Cross-logging options (meditation↔workout) |
| **Tab Order** | Drag & drop tab reordering |

---

## Technical Notes

- **Persistence:** All settings use `@AppStorage` for automatic UserDefaults sync
- **Tab Order Storage:** Array of tab identifiers in AppStorage "tabOrder"
- **Ambient Player:** `AmbientSoundPlayer()` instance for preview playback
- **Gong Player:** `GongPlayer()` instance for test gong
- **Localization:** All labels use `NSLocalizedString` for DE/EN support
- **Form Layout:** Uses SwiftUI `Form` with `Section` for grouped appearance

Reference Standards:
- `.agent-os/standards/swiftui/localization.md`

---

## References

- `openspec/specs/features/app-navigation.md` - 4-tab structure definition
- `openspec/specs/features/meditation-timer.md` - Free meditation settings
- `openspec/specs/features/breathing.md` - Breathing preset settings
- `openspec/specs/features/workouts.md` - Workout audio cues
