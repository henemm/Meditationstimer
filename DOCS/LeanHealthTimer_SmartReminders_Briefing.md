# 📘 PROJECT BRIEF — “Smart Reminders” Integration

**Target Project:** `Lean Health Timer`  
**Environment:** iOS 18 / Xcode 26 / SwiftUI  
**Editor:** Visual Studio Code + Grok (AI Assistant)  
**Goal:** Implement a modular, HealthKit-aware reminder system that triggers conditional local notifications depending on user activity (meditation or workouts) within a configurable timeframe.

---

## 🧩 1. Context Overview

The app already includes:
- HealthKit integration (workout + mindfulness sessions)
- Notification scheduling logic (`NotificationHelper` or similar)
- Background refresh setup (`BGTaskScheduler` permitted identifiers)
- SwiftUI Settings sheet and multi-tab layout (OffenView, AtemView, WorkoutsView)
- App-wide persistence via `@AppStorage` and possibly lightweight CoreData

---

## 🎯 2. Objective

Allow users to define **multiple smart reminders** that are **only triggered if**  
no corresponding activity (Workout or Meditation) was logged in HealthKit during a defined “look-back period”.

Each reminder defines:

| Field | Description |
|--------|--------------|
| **Activity type** | Meditation 🧘 or Workout 🏋️ |
| **Trigger time window** | e.g. 08:00–08:30 |
| **Look-back duration** | e.g. 2 hours |
| **Custom message** | “Take a moment to breathe 🌿” |
| **Repeat** | Daily (default) |

---

## ⚙️ 3. Technical Requirements

### 3.1 Data Model

`SmartReminder.swift`
```swift
struct SmartReminder: Identifiable, Codable {
    enum CheckType: String, Codable { case meditation, workout }

    let id: UUID
    var title: String
    var checkType: CheckType
    var triggerHour: Int          // e.g. 8 = 08:00
    var windowMinutes: Int        // e.g. 30 min window
    var lookbackHours: Int        // e.g. 2 hours before
    var message: String
}
```

---

### 3.2 Reminder Engine

`SmartReminderEngine.swift` in `/Services/`

Responsibilities:
1. Load all stored reminders.  
2. On app launch or background wake (`BGTaskScheduler`), iterate over each reminder.  
3. Query HealthKit for activities in the `lookbackHours` range before the trigger time.  
4. If **no activity found**, trigger a local notification via existing notification helper.  
5. Reschedule BGTask for the next appropriate reminder window.

Identifier: `com.henemm.smartreminders.check`

---

### 3.3 Background Registration

```swift
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.henemm.smartreminders.check",
    using: nil
) { task in
    SmartReminderEngine.shared.handleReminderCheck(task: task as! BGAppRefreshTask)
}
```

`Info.plist`
```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.henemm.smartreminders.check</string>
</array>
```

Enable in Xcode Capabilities: **Background fetch + Background processing**

---

### 3.4 SwiftUI Frontend Integration

New View: `SmartRemindersView.swift`  
- List of reminders  
- “+ Reminder” button opens editor sheet  
- Editor allows:
  - Name/title
  - Meditation / Workout toggle
  - Time picker for trigger hour
  - Stepper/picker for look-back duration
  - Message text field

Styling: match `GlassCard` visual design.

---

### 3.5 SettingsSheet Integration

Add a status indicator for background permission:

```swift
UIApplication.shared.backgroundRefreshStatus
```

If denied, show orange warning and link to system settings.

---

## 🧠 4. Logic Flow Example

**Example:**  
User adds “Morning Meditation” reminder:  
- Type: Meditation  
- Time: 08:00–08:30  
- Look-back: 2 hours  

**At 08:10**, background check runs:  
→ HealthKit query for mindfulness sessions 06:10–08:10.  
→ If none found → send notification.  
→ If at least one found → skip.

---

## 🔒 5. Permissions

- HealthKit read permissions for:
  - `HKCategoryTypeIdentifier.mindfulSession`
  - `HKWorkoutType.workoutType()`  
- Notification authorization via `UNUserNotificationCenter`
- Background modes enabled in capabilities

---

## 🧰 6. Optional Enhancements

- Weekday selection (Mon–Fri vs weekend)  
- Adaptive reminders (delay if late activity detected)  
- iCloud sync  
- In-app summary (skipped vs triggered)

---

## 🧩 7. File Structure

```
/LeanHealthTimer
├── Views/
│   ├── OffenView.swift
│   ├── AtemView.swift
│   ├── WorkoutsView.swift
│   └── SmartRemindersView.swift
├── Services/
│   ├── SmartReminderEngine.swift
│   ├── HealthKitManager.swift
│   ├── NotificationHelper.swift
│   └── BackgroundAudioKeeper.swift
├── Models/
│   └── SmartReminder.swift
└── Supporting Files/
    ├── Info.plist
    └── Assets.xcassets
```

---

## ✅ 8. Deliverables

1. `SmartReminder.swift` (model)  
2. `SmartReminderEngine.swift` (background logic)  
3. `SmartRemindersView.swift` (UI)  
4. Updated:
   - `Info.plist`
   - `App` initialization (BGTaskScheduler registration)
   - `SettingsSheet` (status check + link)

---

**Author:** Henning Emmrich  
**Date:** 2025-09-29  
**Document Type:** Technical Briefing for AI Integration (Grok / VS Code)
