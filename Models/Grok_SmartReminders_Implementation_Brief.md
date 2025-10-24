# 🧑‍💻 GROK IMPLEMENTATION BRIEF — Smart Reminders (Lean Health Timer)

**Goal:**  
Implement a modular reminder subsystem that checks HealthKit data (Workouts + Mindfulness) and triggers a local notification only if *no activity* occurred within a user-defined look-back period.  
Must work in background via `BGTaskScheduler`.

---

## 🚀 TASK 1 — Data Model  
**File:** `Models/SmartReminder.swift`

**Implement**
```swift
struct SmartReminder: Identifiable, Codable, Equatable {
    enum CheckType: String, Codable { case meditation, workout }

    let id: UUID
    var title: String
    var checkType: CheckType
    var triggerHour: Int
    var windowMinutes: Int
    var lookbackHours: Int
    var message: String
    var repeats: Bool = true
}
```

**Persist** reminders as JSON array via `@AppStorage("smartReminders")`.  
Add helper `static func sampleData()` for previews.

---

## ⚙️ TASK 2 — SmartReminderEngine  
**File:** `Services/SmartReminderEngine.swift`

**Responsibilities**
1. Load / save reminders  
2. Query HealthKit via existing `HealthKitManager.shared`  
   - MindfulSession + Workout  
   - check last `lookbackHours` before trigger  
3. Trigger local notifications (using `NotificationHelper`)  
4. Register and run BGTask `com.henemm.smartreminders.check`  
5. Add rate-limiting (max 1 notification per run)  
6. Use `os.Logger` for debug output  

**Important**
- Implement `handleReminderCheck(task: BGAppRefreshTask)`  
- Set `task.expirationHandler = { self.cleanup() }`  
- Schedule next run after each check  

---

## 🪄 TASK 3 — Background Setup  
**Update**
- `App` initialization → register BGTaskScheduler  
- `Info.plist` → add
```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
  <string>com.henemm.smartreminders.check</string>
</array>
```
- Enable Background Fetch + Processing capabilities  

If BGTaskScheduler disabled → fallback to local Timer while foregrounded.

---

## 🖥️ TASK 4 — SmartRemindersView  
**File:** `Views/SmartRemindersView.swift`

**UI Features**
- List of existing reminders (using GlassCard style)  
- “+” button → Editor Sheet  
- Swipe to delete / tap to edit  
- Fields: Name · Activity type · Time · Look-back · Message  
- Optional “Test now” button to trigger immediate check  
- Animations on add/remove (`withAnimation`)  

**Validation**
- Trigger time ≥ current time  
- Look-back ≥ 15 min  
- Prevent duplicates  

---

## ⚙️ TASK 5 — SettingsSheet Integration  
**Update**
- Add section **“Smart Reminders”**  
- Show background refresh status:
  ```swift
  UIApplication.shared.backgroundRefreshStatus
  ```
  - If `.denied` → orange warning  
- Add link to system settings  
- Toggle “Pause all Reminders” flag (`@AppStorage("smartRemindersPaused")`)  

---

## 🧠 TASK 6 — Permissions & Edge Cases  
- Check `UNUserNotificationCenter.getNotificationSettings()` and update UI live  
- Handle missing HealthKit access → disable related reminders  
- Store `lastHealthKitSync: Date?` for diagnostics  
- Provide friendly error logging  

---

## 🧪 TASK 7 — Testing Scenarios  
1. Workout within look-back → no notification  
2. No activity → notification sent  
3. App killed → BGTask still fires  
4. Background refresh disabled → UI warning  
5. Multiple reminders → rate-limited notifications  

---

## 🧰 TASK 8 — Optional Enhancements  
| Feature | Purpose |
| --- | --- |
| Weekday filter (Mon–Fri vs weekend) | Scheduling control |
| Adaptive reminders | Delay if late workout detected |
| iCloud sync | Cross-device sync |
| Analytics summary | Show skipped vs triggered rates |

---

## 🗂️ FILE STRUCTURE
```
/LeanHealthTimer
├── Models/
│   └── SmartReminder.swift
├── Services/
│   ├── SmartReminderEngine.swift
│   ├── HealthKitManager.swift
│   ├── NotificationHelper.swift
│   └── BackgroundAudioKeeper.swift
├── Views/
│   ├── SmartRemindersView.swift
│   ├── OffenView.swift
│   ├── AtemView.swift
│   └── WorkoutsView.swift
└── Supporting/
    └── Info.plist
```

---

## ✅ Deliverables Checklist
- [ ] SmartReminder.swift (Model)  
- [ ] SmartReminderEngine.swift (Logic)  
- [ ] SmartRemindersView.swift (UI)  
- [ ] Info.plist update  
- [ ] App entry registration + Settings integration  
- [ ] End-to-end test cases  
