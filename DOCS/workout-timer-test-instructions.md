# 🧪 Test Instructions: Reverse Smart Reminders

**Feature:** Reverse Smart Reminders
**Version:** v1.0 (Initial Implementation)
**Date:** 2025-11-01
**Tester:** Henning

---

## ✅ Unit Tests

**Status:** 15/15 unit tests passing (2025-11-01)

Automated tests have been written for the core Smart Reminder logic:

```bash
xcodebuild test -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -destination 'platform=iOS Simulator,id=2B6DDD00-A397-43EC-BA99-CFAB3C31176A'
```

**Test Coverage:**
- ✅ CancelledNotification codable/equality
- ✅ CRUD operations (add, update, remove, persistence)
- ✅ Window calculations (inside/outside, boundaries)
- ✅ Activity type matching (mindfulness, workout, noalc)
- ✅ Multiple reminders with selective cancellation
- ✅ 24h look-ahead window
- ✅ Disabled reminders ignored
- ✅ Duplicate cancellation prevention

**Test File:** `LeanHealthTimerTests/SmartReminderEngineTests.swift`

These unit tests verify the business logic works correctly. The manual tests below verify the full end-to-end integration on a physical device.

---

## ⚙️ Prerequisites

1. **Device:** Physical iPhone (iOS 18.5+) with notifications enabled
2. **Permissions:** Notifications allowed for Lean Health Timer
3. **Time:** ~30-60 minutes for full testing
4. **Important:** Use **today's date** for all tests (easier to verify in Settings → Notifications)

---

## 📋 Test Suite

### **Test 1: Basic Reminder Cancellation (Meditation)**

**Goal:** Verify that completing a meditation cancels matching reminders.

**Steps:**
1. Go to **Settings → Smart Reminders**
2. Tap **+** to create new reminder:
   - **Titel:** "Meditation Test"
   - **Nachricht:** "Zeit für eine kurze Meditation 🧘"
   - **Aktivitätstyp:** Meditation
   - **Uhrzeit:** 2 hours from now (e.g., if it's 10:00, set to 12:00)
   - **Rückblick-Zeitraum:** 12 Stunden
   - **Wochentage:** Only today's weekday (e.g., Friday)
   - **Aktiviert:** ON
3. Save reminder
4. **Verify:** Go to iPhone **Settings → Notifications → Lean Health Timer → Scheduled Notifications**
   - Should see "Meditation Test" scheduled for today at 12:00 ✅
5. **Perform meditation:** Go to Offen tab → Start 15 min meditation → Complete it
6. **Expected result:**
   - In app: Session logged to HealthKit
   - In Console logs: "🎯 Cancelled 1 reminder(s) based on activity completion"
7. **Verify:** Go to **Settings → Notifications → Lean Health Timer → Scheduled Notifications**
   - "Meditation Test" for today should be GONE ✅
   - Next week's same weekday should still be scheduled ✅

**Pass Criteria:**
- ✅ Reminder disappears from scheduled notifications after meditation
- ✅ No notification fires at the scheduled time
- ✅ Next week's reminder remains scheduled

---

### **Test 2: Look-back Window Logic**

**Goal:** Verify that activities outside the look-back window DON'T cancel reminders.

**Steps:**
1. Create reminder:
   - **Aktivitätstyp:** Meditation
   - **Uhrzeit:** 14:00 (2 PM)
   - **Rückblick-Zeitraum:** 1 Stunde (only 13:00-14:00 window)
   - **Wochentage:** Today
2. Current time: 12:00 (noon)
3. **Perform meditation** at 12:00 (BEFORE the 13:00-14:00 window)
4. **Expected result:**
   - Reminder should STILL be scheduled (activity outside window)
5. **Verify:** Check **Settings → Notifications → Scheduled Notifications**
   - "Meditation Test" for 14:00 today should STILL be there ✅
6. **Then:** Perform another meditation at 13:30 (INSIDE window)
7. **Expected result:** Now the reminder should be cancelled
8. **Verify:** Reminder should now be GONE ✅

**Pass Criteria:**
- ✅ Activity before window: Reminder stays
- ✅ Activity inside window: Reminder cancelled

---

### **Test 3: Multiple Reminders (Workout)**

**Goal:** Verify selective cancellation (only matching reminders cancelled).

**Steps:**
1. Create **Reminder 1:**
   - **Aktivitätstyp:** Workout
   - **Uhrzeit:** 12:00
   - **Rückblick-Zeitraum:** 1 Stunde (11:00-12:00)
   - **Wochentage:** Today
2. Create **Reminder 2:**
   - **Aktivitätstyp:** Workout
   - **Uhrzeit:** 18:00
   - **Rückblick-Zeitraum:** 12 Stunden (06:00-18:00)
   - **Wochentage:** Today
3. **Perform workout** at 10:30 (before first window, inside second window)
4. **Expected results:**
   - Reminder 1 (12:00): Should STAY (10:30 < 11:00 window start)
   - Reminder 2 (18:00): Should be CANCELLED (10:30 is in 06:00-18:00 window)
5. **Verify:** Check scheduled notifications
   - 12:00 Workout reminder: PRESENT ✅
   - 18:00 Workout reminder: GONE ✅

**Pass Criteria:**
- ✅ Only reminders with matching look-back window are cancelled
- ✅ Other reminders remain untouched

---

### **Test 4: NoAlc Integration**

**Goal:** Verify NoAlc reminders cancel after alcohol logging.

**Steps:**
1. Create reminder:
   - **Aktivitätstyp:** NoAlc
   - **Uhrzeit:** 20:00 (8 PM)
   - **Rückblick-Zeitraum:** 24 Stunden
   - **Wochentage:** Today
2. **Log alcohol:** (via notification action or manual entry)
   - Use notification action "0 Drinks" or "1+ Drinks"
   - OR manually log in Health app
3. **Expected result:**
   - Reminder should be cancelled (logging = activity completed)
4. **Verify:** Check scheduled notifications
   - 20:00 NoAlc reminder should be GONE ✅

**Pass Criteria:**
- ✅ Logging alcohol (any count) cancels NoAlc reminder

---

### **Test 5: Weekday Specificity**

**Goal:** Verify cancelled state is per-weekday.

**Steps:**
1. Create reminder with **multiple weekdays:** Monday + Wednesday + Friday, 18:00, 12h look-back
2. **Current:** Monday 10:00
3. **Perform meditation** at Monday 10:00
4. **Expected:**
   - Monday 18:00 reminder: CANCELLED ✅
   - Wednesday 18:00 reminder: STILL SCHEDULED ✅
   - Friday 18:00 reminder: STILL SCHEDULED ✅
5. **Verify:** Check scheduled notifications
   - Should see Wednesday + Friday, but NOT Monday

**Pass Criteria:**
- ✅ Only the specific weekday is cancelled
- ✅ Other weekdays remain active

---

### **Test 6: Automatic Reset**

**Goal:** Verify cancelled reminders automatically reset after expiry.

**Steps:**
1. Create reminder: Monday 18:00, 12h look-back
2. **Monday 10:00:** Complete meditation → Monday 18:00 cancelled
3. **Monday 18:01:** (After reminder time passed)
4. **Verify:** Check scheduled notifications
   - NEXT Monday 18:00 should be scheduled again ✅
5. **Alternative test:** Restart app on Tuesday morning
   - Verify next Monday's reminder is active

**Pass Criteria:**
- ✅ Cancelled reminder automatically resets for next week
- ✅ Works after app restart

---

### **Test 7: UI Configuration**

**Goal:** Verify all UI elements work correctly.

**Steps:**
1. Go to **Settings → Smart Reminders**
2. Verify:
   - ✅ Navigation title says "Smart Reminders" (not "Activity Reminders")
   - ✅ Settings sheet entry says "Smart Reminders"
3. Create/edit reminder:
   - ✅ "Rückblick-Zeitraum" picker is visible
   - ✅ Available options: 1, 3, 6, 12, 24, 48 hours
   - ✅ Default value: 12 hours
   - ✅ Explanatory text below picker shows current selection
4. Change look-back to 6 hours:
   - ✅ Text updates: "...in den letzten 6h..."

**Pass Criteria:**
- ✅ All UI elements present and functional
- ✅ Correct naming throughout

---

### **Test 8: App Restart Persistence**

**Goal:** Verify cancelled state survives app restarts.

**Steps:**
1. Create reminder for today 18:00
2. Complete matching activity → reminder cancelled
3. **Force-quit app** (swipe up in app switcher)
4. **Restart app**
5. **Verify:** Check scheduled notifications
   - Cancelled reminder should STILL be gone ✅

**Pass Criteria:**
- ✅ Cancelled state persists after app restart

---

## 🐛 Edge Cases to Test

### **Edge Case 1: Activity at Exact Reminder Time**

**Steps:**
1. Create reminder for 12:00, 1h look-back (11:00-12:00)
2. Complete activity at exactly 12:00
3. **Expected:** Should cancel (12:00 is within 11:00-12:00 window)

---

### **Edge Case 2: Multiple Activities Same Day**

**Steps:**
1. Create reminder for 18:00, 12h look-back
2. Complete meditation at 10:00 → cancelled
3. Complete another meditation at 14:00 (reminder already cancelled)
4. **Expected:** No crash, system handles gracefully

---

### **Edge Case 3: Disable/Re-enable Reminder**

**Steps:**
1. Create reminder, complete activity → cancelled
2. Toggle reminder OFF → ON
3. **Expected:** Reminder should re-schedule (cancelled state cleared on disable/enable)

---

## 📊 Testing Checklist Summary

Use this checklist to track progress:

- [ ] **Test 1:** Basic cancellation (Meditation)
- [ ] **Test 2:** Look-back window logic
- [ ] **Test 3:** Multiple reminders (Workout)
- [ ] **Test 4:** NoAlc integration
- [ ] **Test 5:** Weekday specificity
- [ ] **Test 6:** Automatic reset
- [ ] **Test 7:** UI configuration
- [ ] **Test 8:** App restart persistence
- [ ] **Edge Case 1:** Exact time activity
- [ ] **Edge Case 2:** Multiple activities
- [ ] **Edge Case 3:** Disable/re-enable

---

## 🔍 How to Debug Issues

### Check Console Logs:

In Xcode, filter console for "SmartReminderEngine":

```
🔍 Checking for reminders to cancel (activity: mindfulness, completed: ...)
✅ Cancelled reminder 'Meditation Test' for Monday at ...
🎯 Cancelled 1 reminder(s) based on activity completion
⏭️ Skipping 'Meditation Test' for Monday (cancelled)
🧹 Cleaned up 2 expired cancellation(s)
```

### Check Scheduled Notifications:

**iOS Settings → Notifications → Lean Health Timer → Scheduled Notifications**

- Shows all pending notifications
- Should update immediately after activity completion

---

## ✅ Success Criteria

**Feature is successful if:**

1. ✅ All 8 main tests pass
2. ✅ No crashes during testing
3. ✅ Cancelled reminders don't fire
4. ✅ Non-cancelled reminders DO fire on time
5. ✅ UI is clear and functional
6. ✅ State persists across app restarts

---

**Test Status:** Ready for device testing
**Expected Duration:** 30-60 minutes
**Next Step:** Test on physical iPhone with real notifications
