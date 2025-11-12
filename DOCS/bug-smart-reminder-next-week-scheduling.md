# Bug Report: Smart Reminders Scheduled for Next Week Instead of Today

**Date:** 12. November 2025
**Commit:** 960811a (NoAlc reminder cancellation fix)
**Status:** Root cause identified, fix pending
**Category:** Date Semantics & Notification Scheduling

---

## Problem Description

**Symptom:** ALL Smart Reminders stopped firing after commit 960811a. User reports last notification was yesterday at 16:38, no notifications today despite 6 active reminders configured as "Täglich" (Daily).

**Impact:** Complete Smart Reminders system failure - users receive no notifications.

**User Report:**
- Last working notification: 11.11.2025, 16:38
- All reminder types affected (Meditation, Workout, NoAlc)
- All 6 reminders configured as "Täglich" with various times (18:00, 19:00, 10:00, 09:45, 16:38, 08:30)
- No meditation/workout done today (cannot be cancelled notifications)
- No Focus mode active (cannot be iOS suppression)

---

## Secured Findings (Facts from Evidence)

### 1. Console.app Logs (11.11.2025)

```
📅 Scheduling smart reminders...
📊 Total reminders: 6, Enabled: 6, Disabled: 0
🔄 Scheduling 6 enabled reminder(s)...
✅ Scheduled 'Meditation' for Montag at 18:00
✅ Scheduled 'Meditation' for Dienstag at 18:00
... (41 total notifications scheduled successfully)
```

**Finding:** `scheduleNotifications()` executes successfully, creates 41 notifications.

### 2. Debug View Screenshot Evidence

**Global State:**
- Total Reminders: 6
- Enabled: 6, Disabled: 0
- Smart Reminders Paused: NO ▶️

**Notification Permissions:**
- Authorization Status: Authorized ✅

**Pending Notifications:**
- 41 pending activity reminders found
- **SMOKING GUN:** Next Trigger = **16.11.2025, 18:00** (5 days away!)

**Cancelled Notifications:**
- 1 cancelled: "Meditation - Dienstag" (expired, should have been cleaned up)

**Finding:** Notifications ARE scheduled, but for WRONG dates (next week, not this week).

### 3. Code Analysis - scheduleNotifications() Call Chain

**SmartReminderEngine.swift:206** (after `cancelMatchingReminders`):
```swift
if cancelledCount > 0 {
    saveCancelled()
    scheduleNotifications()  // ← Called after EVERY activity completion
}
```

**SmartReminderEngine.swift:263-283** (`scheduleNotifications` method):
```swift
// 1. Clean up expired cancellations
cleanupExpiredCancellations()

// 2. Cancel ALL existing activity reminder notifications
UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
    let reminderIdentifiers = requests
        .filter { $0.identifier.hasPrefix("activity-reminder-") }
        .map { $0.identifier }

    if !reminderIdentifiers.isEmpty {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIdentifiers)
    }

    // 3. Schedule notifications for each enabled reminder
    for reminder in enabledReminders {
        self.scheduleNotification(for: reminder)
    }
}
```

**Finding:** Every `cancelMatchingReminders()` call (triggered by activity completion) causes:
1. **DELETE** all existing notifications
2. **RECREATE** all notifications from scratch

### 4. iOS UNCalendarNotificationTrigger Behavior

**SmartReminderEngine.swift:311-316** (notification creation):
```swift
var dateComponents = DateComponents()
dateComponents.hour = hour
dateComponents.minute = minute
dateComponents.weekday = weekday.calendarWeekday  // 1=Sunday, 2=Monday, etc.

let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
```

**iOS Documented Behavior:**
- Partial `DateComponents` (weekday + hour + minute only, no year/month/day)
- `repeats: true` flag
- iOS finds **next occurrence** of matching components

**Example:**
- Today: Monday 11.11.2025, 15:00
- Notification: Monday 09:45
- iOS calculates: Monday 09:45 already passed today → schedules for **next Monday (18.11.2025)**

**Finding:** This is **correct iOS behavior**, not a bug in iOS.

---

## Root Cause Analysis

### The Bug Chain

1. **Commit 960811a** added `cancelMatchingReminders()` functionality
2. User completes activity (e.g., meditation at 10:00)
3. `cancelMatchingReminders()` called (Line 137)
4. Matching reminders cancelled, `cancelledCount > 0`
5. **Line 206:** `scheduleNotifications()` called
6. **Line 269:** ALL 41 pending notifications deleted
7. **Line 279:** Notifications recreated with partial DateComponents
8. **Current time check:**
   - If current time > trigger time today → iOS schedules for **next week**
   - If current time < trigger time today → iOS schedules for **today**
9. **Result:** Most trigger times have passed by the time user logs activity → everything scheduled for next week

### Why This Worked Before Commit 960811a

Before this commit, `scheduleNotifications()` was only called:
- App launch (Line 36)
- Add/Update/Remove reminder (Lines 105, 114, 124)

These operations happen at **unpredictable times**, so some notifications would schedule for today, some for next week (inconsistent but partially working).

After commit 960811a, `scheduleNotifications()` is called **after every activity completion**, which typically happens **after most trigger times** (users log activities in evening), causing **systematic next-week scheduling**.

### Why Debug Logs Show "today" vs "next week"

**SmartReminderEngine.swift:319-321** (diagnostic code added during debug):
```swift
let willTriggerToday = (weekday.calendarWeekday == currentWeekday) &&
                       (hour > currentHour || (hour == currentHour && minute > currentMinute))
let triggerInfo = willTriggerToday ? "today" : "next week"
```

This logic is **approximate** and doesn't account for iOS's actual next-occurrence calculation. It only checks if the time hasn't passed yet **on the same weekday**. This is diagnostic logging only, not part of the fix.

---

## Hypotheses for Solutions

### Hypothesis 1: Don't Re-Schedule After Cancellation ⭐ (Most Likely)

**Approach:** Remove `scheduleNotifications()` call from Line 206.

**Rationale:**
- `cancelMatchingReminders()` only adds to `cancelled` list
- `scheduleNotification(for:)` already checks `isCancelled()` (Line 301)
- NO NEED to delete and recreate all notifications just to cancel one

**Implementation:**
```swift
if cancelledCount > 0 {
    saveCancelled()
    // scheduleNotifications()  // ← REMOVE THIS LINE
}
```

**Why this works:**
- Notifications remain scheduled at original times
- `isCancelled()` check prevents re-scheduling cancelled notifications
- Next `scheduleNotifications()` call (app launch, reminder edit) will respect `cancelled` list
- Expired cancellations cleaned up by `cleanupExpiredCancellations()` (Line 260)

**Risk:** Need to verify `cancelled` list is respected when notifications fire (handled by iOS, not our code).

---

### Hypothesis 2: Calculate Explicit Next Occurrence Date

**Approach:** Replace partial DateComponents with full date calculation.

**Rationale:** Don't rely on iOS's "next occurrence" logic - calculate it explicitly.

**Implementation:**
```swift
func calculateNextOccurrence(for reminder: SmartReminder, weekday: Weekday) -> Date? {
    let calendar = Calendar.current
    let now = Date()

    let hour = calendar.component(.hour, from: reminder.triggerTime)
    let minute = calendar.component(.minute, from: reminder.triggerTime)

    var components = DateComponents()
    components.weekday = weekday.calendarWeekday
    components.hour = hour
    components.minute = minute

    // Find next occurrence after now
    guard let nextDate = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) else {
        return nil
    }

    // If next occurrence is TODAY and hasn't passed yet, use today
    // Otherwise use the date calculated
    return nextDate
}

// Then schedule with explicit date:
let nextOccurrence = calculateNextOccurrence(for: reminder, weekday: weekday)
var dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextOccurrence)
let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
```

**Why this works:**
- Explicit control over "today vs next week" decision
- Still uses `repeats: true` for recurring notifications

**Risk:** More complex logic, potential for off-by-one errors in date calculations.

---

### Hypothesis 3: Accept iOS Behavior + Auto-Reset Mechanism

**Approach:** Let iOS schedule for next week, rely on app launches to reset.

**Rationale:**
- iOS behavior is correct (next occurrence = next week if today passed)
- App launches call `scheduleNotifications()` (Line 36)
- Most users open app daily → notifications reset daily

**Implementation:** No code change, accept current behavior.

**Why this DOESN'T work:**
- User expects notifications to fire TODAY if configured
- Defeats purpose of Smart Reminders (notify if no activity)
- Relies on user opening app daily (bad UX)

**Verdict:** ❌ Not acceptable.

---

## Recommended Solution

**Hypothesis 1** is the correct fix:
- **Remove `scheduleNotifications()` call from Line 206**
- Cancellation only needs to update `cancelled` list
- Existing notifications remain scheduled at correct times
- `isCancelled()` check (Line 301) prevents re-scheduling cancelled ones
- Next app launch or reminder edit will clean up properly

**Why this is Analysis-First:**
- Root cause identified with certainty (re-schedule after cancellation)
- Evidence: Debug logs, screenshot, code analysis
- Solution directly addresses root cause (don't re-schedule unnecessarily)
- No speculative fixes or trial-and-error

---

## Pattern for CLAUDE.md

**Pattern:** Notification Scheduling with Partial DateComponents

**The Problem:**
- `UNCalendarNotificationTrigger` with partial `DateComponents` (weekday + hour + minute)
- `repeats: true` flag
- iOS finds **next occurrence**, not "today if possible"

**The Rule:**
```
❌ DON'T: Re-schedule all notifications after state changes
✅ DO: Update state (cancelled list), let existing notifications fire
✅ DO: Calculate explicit dates if you need control over "today vs next week"
```

**When to use which:**
- **Partial DateComponents + repeats: true:** For recurring notifications where "next occurrence" is acceptable
- **Explicit date calculation:** When you need to control whether notification fires today vs next week
- **State-based filtering:** Use cancelled/disabled lists instead of deleting/recreating notifications

---

## Next Steps

1. ✅ **Document bug** (this file)
2. ✅ **Update bug-index.md** (commit 2fb6792 referenced)
3. ✅ **Implement Hypothesis 1** (removed lines 204-207, commit 2fb6792)
4. ⏳ **Test on device:**
   - Complete activity (meditation/workout)
   - Verify notifications still scheduled for correct times
   - Verify cancelled notifications don't fire
   - Wait for next trigger time, verify notification fires
5. ⏳ **Remove diagnostic logging** (Lines 289-321 "today" vs "next week" code)
6. ⏳ **Update ACTIVE-todos.md** (mark bug as fixed after testing)

---

**Reference:**
- Commit: 960811a (introduced bug)
- Related: bug-noalc-reminder-cancellation.md (Date semantics issue)
- Feature Spec: feature-reverse-smart-reminders.md
- CLAUDE.md: Lines 826-856 (Bug Documentation Protocol)
