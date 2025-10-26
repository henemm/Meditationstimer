# Platform-Specific Notes

Platform differences and requirements for iOS, watchOS, and Widget Extension.

---

## iOS Platform (iOS 16.1+)

### Requirements

- **iOS 16.1+** for Live Activities / Dynamic Island
- **iOS 17.2+** simulator for testing Dynamic Island (or physical device)
- HealthKit capabilities configured

### Platform-Specific Components

**Live Activities:**
- `LiveActivityController.swift` – Activity orchestration
- `MeditationActivityAttributes.swift` – Activity data model
- Requires ActivityKit framework
- Only one activity active at a time (cross-tab coordination)

**Background Audio:**
- `BackgroundAudioKeeper.swift` – Prevents audio session termination
- Uses silent audio loop (volume 0.0)
- Required for meditation sessions

**Smart Reminders:**
- `SmartReminderEngine.swift` – Background task scheduling
- `SmartRemindersView.swift` – Settings UI
- Uses BGAppRefreshTask (iOS 13+)

**WatchConnectivity:**
- `PhoneMindfulnessReceiver.swift` – Receives Watch session data
- Optional: HealthKit is primary sync mechanism

### Three Tabs

1. **Offen** – Free meditation (2-phase timer)
2. **Atem** – Guided breathing exercises
3. **Workouts** – HIIT timer with cues

### Audio System

- GongPlayer for meditation cues
- SoundPlayer (WorkoutsView) for workout cues
- AVSpeechSynthesizer for German voice announcements

### Testing Notes

- **Live Activities:** Require physical device with Dynamic Island or iOS 17.2+ simulator
- **HealthKit:** Requires device or configured simulator
- **Background Tasks:** Only run on physical device (not simulator)

---

## watchOS Platform (watchOS 9.0+)

### Requirements

- **watchOS 9.0+** minimum
- Paired with iPhone running iOS 16.1+
- HealthKit capabilities configured

### Platform-Specific Components

**Extended Runtime:**
- `RuntimeSessionHelper.swift` – WKExtendedRuntimeSession
- Extends app runtime to ~30 minutes
- Automatic expiration handling

**Heart Rate Monitoring:**
- `HeartRateStream.swift` – Real-time HR tracking
- Uses HKAnchoredObjectQuery
- Displays min/avg/max after session

**Notifications:**
- `NotificationHelper.swift` – Local notifications
- Schedules phase-end alerts
- Fallback if session exceeds 30 min

### Simplified UI

- Single picker for phase durations
- Timer display during session
- Heart rate list after completion
- No tabs (single-purpose app)

### No Audio

- Watch speaker too quiet
- Uses **haptic feedback** instead
- Notifications for critical alerts

### Haptic Patterns

```swift
WKInterfaceDevice.current().play(.notification)  // Phase transition
WKInterfaceDevice.current().play(.success)       // Session complete
WKInterfaceDevice.current().play(.start)         // Session start
```

### Data Sync

- Logs directly to HealthKit (independent of iPhone)
- Sends session data to iPhone via WatchConnectivity (optional)
- No explicit sync required (HealthKit is source of truth)

### Testing Notes

- **Extended Runtime:** Only works on physical Apple Watch
- **Heart Rate:** Requires wearing watch during test
- **Notifications:** Test with session >30 min

---

## Widget Extension (iOS 16.1+)

### Components

**Live Activity Widget:**
- `MeditationstimerWidgetLiveActivity.swift` – Dynamic Island UI
- `MeditationActivityAttributes.swift` – Data structure (copy of iOS version)
- `LiveActivityTimerLogic.swift` – Timer helper for widget

**Static Widgets:**
- `MeditationstimerWidget.swift` – Home screen widgets
- `MeditationstimerWidgetControl.swift` – Control center widget
- `AppIntent.swift` – Widget actions

### Live Activity UI

**Dynamic Island (Compact):**
- Timer countdown
- Activity phase indicator

**Dynamic Island (Expanded):**
- Larger countdown
- Progress ring
- Phase title

**Lock Screen:**
- Full timer display
- Progress bar
- Pause/resume controls (if enabled)

### Limitations

- **Read-only data:** Widget cannot modify app state directly
- **Limited dependencies:** Only ActivityKit, SwiftUI, minimal services
- **No HealthKit:** Cannot log directly from widget
- **No audio:** Widgets cannot play sounds

### Testing Notes

- **Dynamic Island:** Physical device or iOS 17.2+ simulator
- **Lock Screen:** Test with device locked
- **Activity Updates:** Verify countdown accuracy

---

## Cross-Platform Shared Code

### Services Directory

All targets can access `/Services/`:

**iOS + watchOS + Widget:**
- `TwoPhaseTimerEngine.swift` – Timer state machine
- `HealthKitManager.swift` – HealthKit operations
- `StreakManager.swift` – Streak calculation

**iOS + watchOS Only:**
- `GongPlayer.swift` – Audio (iOS only uses)
- `NotificationHelper.swift` – Notifications (watchOS only uses)

**iOS Only:**
- `BackgroundAudioKeeper.swift` – Requires UIKit
- `LiveActivityController.swift` – Requires ActivityKit

**watchOS Only:**
- `HeartRateStream.swift` – Watch HR API
- `RuntimeSessionHelper.swift` – WKExtendedRuntimeSession

### Data Models

Shared across targets:
- `MeditationActivityAttributes.swift` – Live Activity data (iOS + Widget)
- `StreakData.swift` – Streak information (iOS + watchOS)

---

## Platform Capabilities Required

### iOS App (Info.plist)

```xml
<key>NSHealthShareUsageDescription</key>
<string>Read meditation and workout history for streak tracking</string>

<key>NSHealthUpdateUsageDescription</key>
<string>Log meditation and workout sessions to Apple Health</string>

<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>processing</string>
</array>

<key>NSSupportsLiveActivities</key>
<true/>
```

### watchOS App (Info.plist)

```xml
<key>NSHealthShareUsageDescription</key>
<string>Track meditation heart rate</string>

<key>NSHealthUpdateUsageDescription</key>
<string>Log meditation sessions</string>

<key>WKExtensionDelegateClassName</key>
<string>$(PRODUCT_MODULE_NAME).ExtensionDelegate</string>
```

### Widget Extension (Info.plist)

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.widgetkit-extension</string>
</dict>
```

---

## Platform-Specific Build Settings

### iOS Target

- **Deployment Target:** iOS 16.1
- **Frameworks:** UIKit, SwiftUI, ActivityKit, HealthKit, WatchConnectivity
- **Capabilities:** HealthKit, Background Modes (Audio, Processing), Live Activities

### watchOS Target

- **Deployment Target:** watchOS 9.0
- **Frameworks:** SwiftUI, WatchKit, HealthKit, WatchConnectivity
- **Capabilities:** HealthKit, Extended Runtime

### Widget Target

- **Deployment Target:** iOS 16.1
- **Frameworks:** SwiftUI, ActivityKit, WidgetKit
- **Capabilities:** Live Activities

---

## Future Platform Considerations

1. **visionOS Support:** Adapt UI for spatial computing
2. **macOS Catalyst:** Enable Mac app with HealthKit limitations
3. **iPadOS Optimization:** Larger screen layouts
4. **watchOS Complications:** Quick-launch from watch face
5. **iOS 18 Features:** New Live Activity capabilities
