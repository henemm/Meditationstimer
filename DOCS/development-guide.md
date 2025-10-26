# Development Guide - Common Tasks & Recipes

Quick reference for common development tasks in Meditationstimer.

---

## Adding a New Meditation Timer

1. Create a new "engine" service class in `/Services/` that implements the timer logic (use TwoPhaseTimerEngine as template).
2. Create a new tab view in `Meditationstimer iOS/Tabs/` that uses the engine.
3. Integrate the engine into ContentView.swift tab list.
4. Add HealthKit logging in the tab's session completion handler.

---

## Adding a New Audio Cue

1. Create/add the audio file (e.g., `new-cue.caf`) to the app bundle in Xcode.
2. Call `gong.play(named: "new-cue")` at the appropriate time.
3. For completion handlers: `gong.play(named: "new-cue", completion: { /* next step */ })`

**Supported formats:** .caf (preferred), .wav, .mp3

---

## Accessing HealthKit Data

### Read Meditation Days for a Month

```swift
let days = try await healthKitManager.fetchActivityDaysDetailedFiltered(forMonth: Date())
```

### Read Daily Minutes

```swift
let minutes = try await healthKitManager.fetchDailyMinutesFiltered(from: start, to: end)
```

### Log a Meditation Session

```swift
try await healthKitManager.logMindfulness(start: startDate, end: endDate)
```

### Log a Workout Session

```swift
try await healthKitManager.logWorkout(
    start: startDate,
    end: endDate,
    activity: .highIntensityIntervalTraining
)
```

---

## Updating the Live Activity

### Start a New Activity

```swift
liveActivity.start(
    title: "Meditation",
    phase: 1,
    endDate: phaseEndDate,
    ownerId: "OffenTab"
)
```

### Update Running Activity

```swift
await liveActivity.update(
    phase: 2,
    endDate: phaseEndDate,
    isPaused: false
)
```

### End Activity

```swift
await liveActivity.end(immediate: true)
```

---

## Detecting Ownership Conflicts

```swift
// Request start with conflict detection
let result = liveActivity.requestStart(
    title: "...",
    phase: 1,
    endDate: Date(),
    ownerId: "AtemTab"
)

switch result {
case .started:
    print("No conflict, activity started")
case .conflict(let ownerID, let title):
    print("\(ownerID) owns the activity: \(title)")
    // Show user a prompt; if approved, call forceStart()
case .failed(let error):
    print("Failed: \(error)")
}
```

---

## Adding a New Breathing Preset

### Create Preset Data

```swift
struct BreathPreset: Codable, Identifiable {
    let id = UUID()
    let name: String
    let inhale: Int      // seconds
    let holdIn: Int      // seconds
    let exhale: Int      // seconds
    let holdOut: Int     // seconds
    let rounds: Int
}
```

### Save to UserDefaults

```swift
let preset = BreathPreset(
    name: "Box Breathing",
    inhale: 4,
    holdIn: 4,
    exhale: 4,
    holdOut: 4,
    rounds: 5
)

var presets = loadPresets()  // Load existing
presets.append(preset)
savePresets(presets)         // Save updated list
```

---

## Working with Streaks

### Update Streaks Manually

```swift
streakManager.updateStreaks()
```

### Access Streak Data

```swift
let meditationStreak = streakManager.meditationStreak
print("Current streak: \(meditationStreak.currentStreakDays) days")
print("Rewards earned: \(meditationStreak.rewardsEarned)")
```

### Streak Calculation Logic

- Consecutive days with ≥2 min activity = streak
- Rewards: 1 per 7 days (max 3)
- Data source: HealthKit (app source only)

---

## Audio Playback Patterns

### Simple Playback

```swift
let gong = GongPlayer()
gong.play(named: "gong")
```

### With Completion Handler

```swift
gong.play(named: "gong-dreimal") {
    print("Triple gong finished")
    // Continue with next action
}
```

### Sequenced Playback

```swift
gong.play(named: "gong") {
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        gong.play(named: "gong-Ende")
    }
}
```

---

## Watch App Development

### Start Extended Runtime Session

```swift
let runtime = RuntimeSessionHelper()
runtime.start { reason in
    print("Runtime ended: \(reason)")
}
```

### Start Heart Rate Monitoring

```swift
let hrStream = HeartRateStream()
hrStream.start(from: Date()) { heartRate in
    print("HR: \(heartRate) bpm")
}
```

### Schedule Phase Notifications

```swift
let notifier = NotificationHelper()
notifier.schedulePhaseEndNotification(
    title: "Meditation Phase 1 Complete",
    date: phase1EndDate
)
```

---

## Debugging Common Issues

### Timer Stops When App Backgrounds

**Expected behavior.** Timers are foreground-only. Use BackgroundAudioKeeper to prevent audio session termination.

### Live Activity Not Appearing

**Check:**
- iOS 16.1+ required
- Physical device with Dynamic Island or iOS 17.2+ simulator
- `ActivityAuthorizationInfo().areActivitiesEnabled`

### HealthKit Authorization Prompts Repeatedly

**Fix:** Add proper timing guards in `requestAuthorization()` to prevent repeated prompts.

### Audio Files Not Found

**Check:**
- Files are in app bundle (Xcode project navigator)
- File extensions correct (.caf, .wav, .mp3)
- File names match exactly (case-sensitive)

---

## Build & Release Commands

### Build iOS App (Debug)

```bash
xcodebuild -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build
```

### Build for Device (Release)

```bash
xcodebuild -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  build
```

### Archive for App Store

```bash
xcodebuild -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -configuration Release \
  -archivePath "./build/Meditationstimer.xcarchive" \
  archive
```

### Build Watch App Only

```bash
xcodebuild -project Meditationstimer.xcodeproj \
  -scheme "Meditationstimer Watch App" \
  -configuration Debug \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' \
  build
```

---

## Code Snippets

### Create a New Tab View

```swift
import SwiftUI

struct MyNewTabView: View {
    @EnvironmentObject var liveActivity: LiveActivityController
    @StateObject private var engine = TwoPhaseTimerEngine()

    var body: some View {
        VStack {
            // Your UI here
        }
        .onAppear {
            // Setup
        }
    }
}
```

### Add SwiftUI Preview

```swift
#Preview {
    MyNewTabView()
        .environmentObject(LiveActivityController())
}
```

### Add Unit Test

```swift
import XCTest
@testable import Meditationstimer

final class MyNewFeatureTests: XCTestCase {
    func testFeature() {
        // Arrange
        let input = "test"

        // Act
        let result = process(input)

        // Assert
        XCTAssertEqual(result, "expected")
    }
}
```
