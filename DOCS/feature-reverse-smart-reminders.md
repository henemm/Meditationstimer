# 📘 FEATURE SPEC — Reverse Smart Reminders

**Target Project:** `Lean Health Timer`
**Environment:** iOS 18 / Xcode 26 / SwiftUI
**Feature Scope:** Activity Reminders mit automatischer Stornierung nach Aktivität
**Goal:** Zuverlässige Smart Reminders durch "Reverse-Check" Ansatz statt BGTaskScheduler

---

## 🧩 1. Context Overview

### Aktueller Stand:

Die App hat **"Activity Reminders"** (früher "Smart Reminders"):
- UNCalendarNotificationTrigger (reliable!)
- Feuern zu konfigurierten Zeiten
- Konfigurierbar: ActivityType, Wochentage, Uhrzeit, Look-back Hours
- **PROBLEM:** Feuern IMMER - keine HealthKit-Prüfung (daher aktuell "dumm")

### Gescheiterter Ansatz (Oktober 2025):

**"Forward Smart Reminders"** mit BGTaskScheduler:
```
Reminder-Zeit erreicht (18:00)
→ BGTaskScheduler weckt App
→ Prüfe HealthKit (letzte 12h Aktivität?)
→ Wenn NEIN: Zeige Notification
```

**Problem:** BGTaskScheduler feuert unzuverlässig auf iOS → Feature unbrauchbar

---

## 🎯 2. Objective - "Reverse Smart Reminders"

### Die Idee (Henning's Ansatz):

**"Das Pferd von hinten aufzäumen"** - nicht bei Reminder-Zeit prüfen, sondern bei Aktivitäts-Ende:

```
User beendet Meditation um 10:00
→ App ist AKTIV (foreground!)
→ Prüfe: Welche Reminders kommen in den nächsten 24h?
→ Für jeden Match: Würde dieser Reminder auslösen?
→ Wenn JA: Lösche pending notification
→ User bekommt um 18:00 KEINE Notification ✓
```

### Warum das funktioniert:

1. **App ist aktiv** am Ende jeder Session → kein BGTaskScheduler nötig
2. **UNCalendarNotificationTrigger** feuert zuverlässig (wenn nicht gelöscht)
3. **Smart-Check im Foreground** → 100% reliable
4. **iOS-Standard Pattern** → keine OS-Limitierungen

---

## 📖 3. User Story

### Szenario 1: Erfüllte Aktivität

**Setup:**
- Reminder: "Meditation" um 18:00, Look-back: 12 Stunden
- Montag 10:00: User meditiert 15 Minuten

**Was passiert:**
```
10:15 Session endet
→ App prüft: Reminders in nächsten 24h?
→ Findet: "Meditation 18:00 Montag" (Look-back: 06:00-18:00)
→ User's Meditation (10:00) liegt im Look-back Window ✓
→ System löscht "Meditation 18:00 Montag" notification
→ 18:00: KEINE Notification (User hat ja schon meditiert!)
```

### Szenario 2: Nicht erfüllte Aktivität

**Setup:**
- Reminder: "Meditation" um 18:00, Look-back: 12 Stunden
- Montag: User meditiert NICHT

**Was passiert:**
```
18:00: Notification feuert normal ✓
→ "Nimm dir einen Moment zum Atmen 🌿"
```

### Szenario 3: Mehrere Reminders

**Setup:**
- Reminder 1: "Workout" um 12:00, Look-back: 1 Stunde
- Reminder 2: "Workout" um 18:00, Look-back: 12 Stunden
- Montag 10:00: User macht Workout

**Was passiert:**
```
10:30 Workout endet
→ Prüft Reminder 1 (12:00): Look-back 11:00-12:00
  → User's Workout (10:00) NICHT im Window → BLEIBT
→ Prüft Reminder 2 (18:00): Look-back 06:00-18:00
  → User's Workout (10:00) IM Window → GELÖSCHT

12:00: Notification feuert (User hat vor dem 11:00 Window trainiert)
18:00: KEINE Notification (Aktivität im Window)
```

---

## ⚙️ 4. Technical Design

### 4.1 Problem: Re-Scheduling

**Herausforderung:**
```swift
// SmartReminderEngine.scheduleNotifications() wird aufgerufen bei:
// - App-Start
// - Reminder hinzufügen/ändern/löschen
// - Toggle on/off

// Dabei:
// 1. Löscht ALLE pending notifications
// 2. Erstellt sie NEU aus reminders array

// Problem: Gelöschte (cancelled) Reminders werden wieder erstellt! ❌
```

**Lösung: Cancelled-Tracker mit Expiry**

### 4.2 Neue Datenstruktur

```swift
/// Represents a temporarily cancelled notification (until next natural trigger)
struct CancelledNotification: Codable, Equatable {
    let reminderID: UUID
    let weekday: Weekday
    let cancelledUntil: Date  // Next natural trigger time
}

// In SmartReminderEngine:
@AppStorage("cancelledNotifications") private var cancelledData: Data = Data()
private var cancelled: [CancelledNotification] = []
```

### 4.3 Core Logic Flow

#### A) Nach Session-Ende (OffenView, AtemView, WorkoutsView):

```swift
// In HealthKitManager.logMindfulness() / logWorkout():
SmartReminderEngine.shared.cancelMatchingReminders(
    for: .mindfulness,  // or .workout
    completedAt: startDate
)
```

#### B) Cancel Matching Reminders:

```swift
func cancelMatchingReminders(for activityType: ActivityType, completedAt: Date) {
    let reminders = getReminders()
    let now = Date()
    let lookAheadEnd = now.addingTimeInterval(24 * 3600)  // 24h window

    for reminder in reminders where reminder.isEnabled && reminder.activityType == activityType {
        for weekday in reminder.selectedDays {
            // Calculate next trigger for this reminder+weekday
            let nextTrigger = calculateNextTrigger(reminder: reminder, weekday: weekday, after: now)

            guard nextTrigger <= lookAheadEnd else { continue }  // Outside 24h window

            // Calculate look-back window for that trigger
            let lookBackStart = nextTrigger.addingTimeInterval(-Double(reminder.lookbackHours) * 3600)
            let lookBackEnd = nextTrigger

            // Does completedAt fall into look-back window?
            if completedAt >= lookBackStart && completedAt <= lookBackEnd {
                // YES → Cancel this notification
                cancelled.append(CancelledNotification(
                    reminderID: reminder.id,
                    weekday: weekday,
                    cancelledUntil: nextTrigger
                ))
            }
        }
    }

    saveCancelled()
    scheduleNotifications()  // Re-schedule (respecting cancelled list)
}
```

#### C) Modified scheduleNotifications():

```swift
func scheduleNotifications() {
    // 1. Clean up expired cancellations
    cleanupExpiredCancellations()

    // 2. Cancel ALL pending activity reminders
    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
        let reminderIdentifiers = requests
            .filter { $0.identifier.hasPrefix("activity-reminder-") }
            .map { $0.identifier }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIdentifiers)

        // 3. Schedule notifications (respecting cancelled list)
        for reminder in self.reminders where reminder.isEnabled {
            for weekday in reminder.selectedDays {
                // CHECK: Is this cancelled?
                if !self.isCancelled(reminder.id, weekday) {
                    self.scheduleNotification(for: reminder, weekday: weekday)
                }
            }
        }
    }
}

private func isCancelled(_ reminderID: UUID, _ weekday: Weekday) -> Bool {
    return cancelled.contains { $0.reminderID == reminderID && $0.weekday == weekday }
}

private func cleanupExpiredCancellations() {
    let now = Date()
    cancelled = cancelled.filter { $0.cancelledUntil > now }
    saveCancelled()
}
```

### 4.4 Automatic Reset

**Cancelled Notifications werden automatisch wieder aktiv:**
- Wenn `Date() > cancelledUntil` → wird aus cancelled-Liste entfernt
- Nächstes `scheduleNotifications()` erstellt sie wieder

**Beispiel:**
```
Montag 10:00 User meditiert
→ "Meditation Montag 18:00" cancelled until Monday 18:00

Dienstag 08:00 App startet
→ cleanupExpiredCancellations() prüft: Monday 18:00 < now?
→ JA (ist vorbei) → entfernt aus cancelled list
→ "Meditation Dienstag 18:00" wird normal gescheduled ✓
```

---

## 🔧 5. UI Änderungen

### 5.1 Reminder Editor: Look-back Hours hinzufügen

**Aktuell:** `hoursInactive` ist im Model, aber NICHT in der UI editierbar

**Neu:** Section "Zeitplan" erweitern:

```swift
Section(header: Text("Zeitplan")) {
    Picker("Aktivitätstyp", selection: $activityType) {
        Text("Meditation").tag(ActivityType.mindfulness)
        Text("Workout").tag(ActivityType.workout)
        Text("NoAlc").tag(ActivityType.noalc)
    }

    DatePicker("Uhrzeit", selection: $triggerTime, displayedComponents: .hourAndMinute)

    // NEU: Look-back Hours Picker
    Picker("Rückblick-Zeitraum", selection: $hoursInactive) {
        Text("1 Stunde").tag(1)
        Text("3 Stunden").tag(3)
        Text("6 Stunden").tag(6)
        Text("12 Stunden").tag(12)
        Text("24 Stunden").tag(24)
        Text("48 Stunden").tag(48)
    }

    Text("Reminder wird nicht gesendet, wenn Aktivität in den letzten \(hoursInactive)h vor der Reminder-Zeit stattfand.")
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

### 5.2 Umbenennung: "Activity Reminders" → "Smart Reminders"

**Dateien:**
- SmartRemindersView.swift: `.navigationTitle("Smart Reminders")`
- SettingsSheet.swift: `NavigationLink(destination: SmartRemindersView()) { Label("Smart Reminders", systemImage: "bell.badge") }`

---

## 📦 6. Implementation Plan

### Phase 1: Core Logic (~60 LoC)

**Files to modify:**
1. **SmartReminderEngine.swift**
   - Add `CancelledNotification` struct
   - Add `@AppStorage("cancelledNotifications")` + load/save
   - Add `cancelMatchingReminders(for:completedAt:)` method
   - Modify `scheduleNotifications()` to respect cancelled list
   - Add `isCancelled()`, `cleanupExpiredCancellations()` helpers

### Phase 2: Integration (~20 LoC)

**Files to modify:**
2. **HealthKitManager.swift**
   - Call `SmartReminderEngine.shared.cancelMatchingReminders()` at end of:
     - `logMindfulness()` (after saving to HealthKit)
     - `logWorkout()` (after saving to HealthKit)

### Phase 3: UI Restoration (~30 LoC)

**Files to modify:**
3. **SmartRemindersView.swift**
   - ReminderEditorView: Add `hoursInactive` Picker in "Zeitplan" section
   - Add explanatory text
   - Update `.navigationTitle()` to "Smart Reminders"

4. **SettingsSheet.swift**
   - Update Label text: "Activity Reminders" → "Smart Reminders"

### Total Scope: ~110 LoC, 3 Files

---

## 🧪 7. Testing Strategy

### Manual Testing Checklist:

**Test 1: Basic Cancel**
1. Create Reminder: "Meditation" 18:00, Look-back: 12h, Monday
2. Monday 10:00: Start + complete meditation (15 min)
3. Check: `getPendingNotificationRequests()` should NOT contain "meditation-18:00-monday"
4. Monday 18:00: NO notification should fire

**Test 2: Outside Look-back Window**
1. Create Reminder: "Workout" 12:00, Look-back: 1h, Monday
2. Monday 10:00: Start + complete workout
3. Check: Notification should STILL be pending (10:00 < 11:00 window start)
4. Monday 12:00: Notification SHOULD fire

**Test 3: Multiple Reminders**
1. Create Reminder 1: "Workout" 12:00, Look-back: 1h
2. Create Reminder 2: "Workout" 18:00, Look-back: 12h
3. Monday 10:00: Complete workout
4. Check:
   - Reminder 1 (12:00) PENDING (outside 11:00-12:00 window)
   - Reminder 2 (18:00) CANCELLED (inside 06:00-18:00 window)

**Test 4: Automatic Reset**
1. Monday 10:00: Complete meditation
2. Check: "Meditation Monday 18:00" cancelled
3. Tuesday 08:00: Restart app
4. Check: "Meditation Tuesday 18:00" PENDING (Monday cancellation expired)

**Test 5: App Restart**
1. Complete activity → cancel reminder
2. Force-quit app
3. Restart app
4. Check: Cancelled reminder STILL cancelled (persisted via AppStorage)

**Test 6: Weekday Specificity**
1. Create Reminder: Monday+Wednesday 18:00
2. Monday 10:00: Complete activity
3. Check:
   - Monday 18:00 CANCELLED
   - Wednesday 18:00 STILL PENDING

### Edge Cases:

- [ ] Complete activity AFTER reminder time (should NOT cancel, too late)
- [ ] Complete activity exactly at trigger time
- [ ] Multiple activities in one day
- [ ] Change reminder config while cancelled (should re-evaluate)
- [ ] Disable/Enable reminder while cancelled
- [ ] Delete reminder while cancelled (cleanup cancelled list)

---

## 🚧 8. Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Date calculations buggy** | Wrong reminders cancelled | Extensive unit tests for `calculateNextTrigger()`, edge cases |
| **Cancelled list grows indefinitely** | Memory leak | `cleanupExpiredCancellations()` on every `scheduleNotifications()` |
| **AppStorage corruption** | Lost cancelled state | Add error handling, fallback to empty array |
| **Timezone changes** | Wrong trigger calculations | Use `Calendar.current` consistently |
| **User changes reminder time** | Cancelled-until might be wrong | Acceptable: Next natural trigger will be correct |

---

## 🎯 9. Success Metrics

**MVP gilt als erfolgreich, wenn:**
1. Meditation/Workout → passende Reminders in 24h werden cancelled
2. Look-back Window logic korrekt (Edge Cases getestet)
3. Cancelled reminders reset automatisch nach Expiry
4. App-Restart: Cancelled state bleibt erhalten
5. UI: hoursInactive editierbar, erklärende Texte vorhanden
6. Keine Crashes, keine Memory Leaks

**Definition of Done:**
- Build compiliert ✓
- Manual Testing Checklist durchlaufen ✓
- Edge Cases getestet ✓
- Commit mit Conventional Commits ✓
- ACTIVE-roadmap.md updated ✓

---

## 🗂️ 10. Open Questions / Decisions Needed

### For Product Owner (Henning):

**Q1: NoAlc Integration?**
- NoAlc hat spezielle notification actions (direct logging)
- Soll NoAlc auch "smart" werden (cancelled nach logging)?
- Oder separate Logik behalten?

**Q2: Look-back Hours Default?**
- Welcher Default für neue Reminders? (aktuell: 24h)
- Empfehlung: 12h für Meditation/Workout, 24h für NoAlc?

**Q3: User Feedback?**
- Soll User sehen, dass Reminder cancelled wurde?
- Z.B. Badge in Settings: "2 Reminders heute cancelled"?
- Oder komplett transparent/unsichtbar?

**Q4: Manual Override?**
- Soll User cancelled Reminder manuell "wiederherstellen" können?
- Oder nur automatisches Reset?

---

**Status:** 🟡 Waiting for PO approval + Q&A
**Next Step:** PO reviews spec, answers Q1-Q4, approves implementation

**Estimated Effort:** 2-3 Stunden (Core + Integration + UI + Testing)
