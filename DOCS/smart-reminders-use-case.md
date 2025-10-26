# Smart Reminders - Use Case & Implementation Guide

## 🎯 Was möchte der User erreichen?

### Hauptziel
Der User möchte **intelligente Erinnerungen**, die ihn zur Meditation oder zu Workouts motivieren, wenn er länger als eine bestimmte Zeit inaktiv war.

### Konkrete User Stories

1. **Als User möchte ich:**
   - Einen Reminder erstellen (z.B. "Morgens Meditation")
   - Eine **Uhrzeit** festlegen (z.B. 9:00 Uhr)
   - **Wochentage** auswählen (z.B. Mo-Fr)
   - Eine **Inaktivitätsdauer** einstellen (z.B. 8 Stunden ohne Meditation)
   - Den Reminder **aktivieren/deaktivieren** können

2. **Als User erwarte ich:**
   - Um **9:00 Uhr** prüft die App: "Hatte ich in den letzten 8 Stunden eine Meditation?"
   - **NEIN** → Notification wird gesendet
   - **JA** → Keine Notification
   - Das funktioniert **auch wenn die App geschlossen ist** (Background)
   - Ich kann mit einem **Test-Button** (Debug) sofort eine Notification auslösen

3. **Als User möchte ich:**
   - **Sofort-Tests** machen können (Reminder für "JETZT + 5 Minuten")
   - **Klare Fehlermeldungen** wenn Berechtigungen fehlen (Notifications, Background Refresh)
   - **Direkte Links** zu iOS-Einstellungen bei Problemen

## 📱 Was möchte der User sehen?

### UI-Erwartungen

1. **Settings → Smart Reminders**
   - Toggle: "Smart Reminders aktivieren"
   - Liste der konfigurierten Reminders
   - Status: "Aktiv" / "Inaktiv" (grün/grau Badge)
   - Info-Banner bei fehlenden Berechtigungen (orange, mit Link zu Settings)

2. **Reminder bearbeiten**
   - Titel + Nachricht
   - Uhrzeit-Picker (HH:mm)
   - Wochentage-Toggles
   - Stunden-Picker (1-24h ohne Aktivität)
   - Aktivitätstyp: "Meditation" oder "Workout"
   - Debug: Orange "Test Notification" Button unter jedem Reminder

3. **Notification**
   - Banner (auch wenn App im Vordergrund)
   - Titel: z.B. "Zeit für deine Meditation!"
   - Body: z.B. "Du hattest heute noch keine Meditation. Nimm dir jetzt 10 Minuten Zeit."
   - Sound + Haptic Feedback

## 🔧 Wie erreicht man das am besten?

### Technische Anforderungen

#### 1. Background Tasks (BGAppRefreshTask)
**Standard iOS-Mechanismus für periodische Checks**

**Herausforderungen:**
- ❌ **Funktioniert NICHT im Simulator** (error code 1)
- ⚠️ **Timing ist nicht garantiert** - iOS entscheidet, wann Task ausgeführt wird
- ⚠️ **Unpräzise für kurze Zeiträume** - nicht für "in 5 Minuten" geeignet
- ✅ **Funktioniert im Hintergrund** - auch wenn App geschlossen
- ✅ **System-freundlich** - iOS optimiert Batterie

**Best Practice:**
- Schedule BGTask **5 Minuten VOR** Trigger-Zeit (Puffer für Ungenauigkeit)
- Bei Reminders <5min: Schedule **sofort** (60 Sekunden)
- Nach jedem Check: **Nächsten BGTask schedulen**

#### 2. Local Notifications (UNUserNotificationCenter)
**Standard iOS-Mechanismus für Benachrichtigungen**

**Anforderungen:**
- ✅ User muss **Berechtigung** erteilen (einmalig)
- ✅ **Foreground Display**: `UNUserNotificationCenterDelegate` erforderlich
- ✅ Sofortige Notifications: `timeInterval: 1` Sekunde

**Best Practice:**
- Delegate in `requestAuthorization()` setzen
- `willPresent` → `[.banner, .sound, .badge]` für Foreground-Display

#### 3. HealthKit Activity Check
**Standard iOS-Mechanismus für Aktivitätsdaten**

**Anforderungen:**
- ✅ User muss **HealthKit-Berechtigung** erteilen
- ✅ Daten müssen in Health App vorhanden sein (echte Meditationen/Workouts)

**Implementation:**
```swift
func hasActivity(ofType: String, inRange: Date, end: Date) async throws -> Bool
```

**Look-back Berechnung:**
- Von: `now - hoursInactive`
- Bis: `now`
- **NICHT** von `triggerStart` (Bug)

#### 4. Trigger-Logik

**Checkliste für `shouldTriggerReminder()`:**

1. ✅ **isEnabled** → false? Return false
2. ✅ **Weekday Check** → Heute nicht in selectedDays? Return false
3. ✅ **Time Window** → Jetzt nicht zwischen triggerStart und triggerEnd? Return false
4. ✅ **HealthKit Check** → Aktivität in letzten X Stunden? Return false
5. ✅ **Alle Checks bestanden** → Return true, Notification senden

**Wichtige Edge Cases:**
- Look-back von `now`, nicht von `triggerStart`
- Window-Dauer: 60 Minuten (Reminder kann 1h nach Trigger-Zeit noch feuern)
- Rate Limiting: Max. 1 Notification pro Stunde (verhindert Spam)

## 🐛 Bekannte Bugs & Lösungen

### Bug: Short-term Reminders (< 5min)
**Problem:** Reminder für "JETZT + 3 Minuten" wird nicht ausgelöst
**Ursache:** Code versucht 5min vorher zu schedulen → in der Vergangenheit → überspringt zum nächsten Reminder (morgen)

**Lösung:**
```swift
if idealCheckTime <= now {
    logger.info("Next reminder too soon (<5min), scheduling immediate check in 1 minute")
    return Date(timeIntervalSinceNow: 60)
} else {
    return idealCheckTime
}
```

### Bug: Notifications im Foreground nicht sichtbar
**Problem:** Console zeigt "Triggered notification", aber keine visuelle Notification
**Ursache:** Ohne Delegate zeigt iOS Notifications nicht im Foreground

**Lösung:**
```swift
// In requestAuthorization()
await MainActor.run {
    if center.delegate == nil {
        center.delegate = NotificationDelegate.shared
    }
}
```

### Bug: Wochentage nicht geprüft
**Problem:** Reminder feuert an Wochentagen, die nicht ausgewählt wurden
**Lösung:** Weekday-Check in `shouldTriggerReminder()` hinzugefügt

## ✅ Testing-Strategie

### 1. Debug Test Button (Simulator + Device)
- Orange Button unter jedem Reminder
- Ruft `testReminder()` sofort auf
- **Ignoriert** Uhrzeit und Wochentage
- Prüft nur HealthKit-Aktivität
- **Ergebnis:** Sofortige Notification oder Log-Meldung

### 2. Short-term Test (Device only)
- Reminder für "JETZT + 8-10 Minuten" erstellen
- Xcode Console beobachten:
  - "Scheduled next reminder check at [HH:mm]" (sollte ~5min vor Trigger sein)
  - ODER "Next reminder too soon, scheduling immediate check in 1 minute"
- App im **Vordergrund** lassen (einfacher zu debuggen)
- Nach 1-2 Minuten: Notification sollte erscheinen

### 3. Background Test (Device only)
- Reminder für nächsten Morgen (z.B. 9:00 Uhr)
- App schließen
- Am nächsten Morgen: Notification sollte kommen
- **Achtung:** BGTask-Timing nicht garantiert (±15 Minuten)

### 4. HealthKit Test (Device only)
- Echte Meditation in Health App loggen
- Reminder mit kurzer Inaktivität (1h) erstellen
- Erwartung: **Keine** Notification (Aktivität vorhanden)

## 📋 Offene Punkte für nächsten Chat

### Kritisch (Muss getestet werden)
- [ ] **Short-term Reminder Fix testen** (Code geschrieben, nicht deployed)
  - Rebuild mit Cmd+R
  - Test mit Reminder in 8-10 Minuten
  - Console-Logs prüfen

- [ ] **BGTask Firing bestätigen** (Background)
  - Reminder für morgen früh
  - App schließen
  - Am nächsten Tag: Notification kam?

- [ ] **HealthKit Integration verifizieren**
  - Echte Meditation loggen
  - Reminder sollte NICHT feuern
  - Debug Button zum Testen nutzen

### Nice-to-have (Kann warten)
- [ ] **Bug 5: Workout Countdown-Sounds** (3x "kurz" aber nur 1x hörbar)
  - AVAudioPlayer-Pool für parallele Wiedergabe

- [ ] **Bug 1: Gong wird abgeschnitten** (OffenView)
  - BackgroundAudioKeeper.stop() zu früh aufgerufen

- [ ] **Settings Modernisierung** (Toolbar Navigation)
  - iOS 18+ "Liquid Glass" Design

## 📝 Wichtige Dateien

- `SmartReminderEngine.swift` - Core-Logik (Trigger, BGTask)
- `SmartRemindersView.swift` - UI + Debug Button
- `NotificationHelper.swift` - Notifications + Delegate
- `SmartReminder.swift` - Datenmodell
- `HealthKitManager.shared.hasActivity()` - Aktivitätsprüfung

## 🚨 Wichtige Hinweise

1. **Simulator-Limitationen:**
   - BGTasks funktionieren NICHT (error code 1)
   - HealthKit hat keine echten Daten
   - Background Refresh Status immer `.available`

2. **Debug-Mode auf Device:**
   - iPhone per Kabel verbinden
   - Als Target auswählen
   - Cmd+R drücken → automatisch Debug Mode
   - Xcode Console zeigt Logs

3. **iOS Settings:**
   - Notifications: Erlauben
   - Background App Refresh: Einschalten (per App oder global)
   - HealthKit: Mindfulness/Workout Berechtigung

4. **Rate Limiting:**
   - Max. 1 Notification pro Stunde
   - Verhindert, dass User zugespammt wird
   - Check in Code: `if Date().timeIntervalSince(lastTrigger) < 3600`

## 🎯 Success Criteria

**Feature ist "done" wenn:**
1. ✅ User kann Reminder erstellen/bearbeiten/löschen
2. ✅ Debug Test Button feuert Notification sofort
3. ✅ Short-term Reminder (10min) feuert zuverlässig
4. ✅ Background Reminder (nächster Tag) feuert zuverlässig
5. ✅ HealthKit Check verhindert Notifications korrekt
6. ✅ Fehlende Permissions zeigen Info-Banner mit Settings-Link
7. ✅ Notifications sichtbar im Foreground + Background

**Aktueller Status:**
- 1-2: ✅ Fertig
- 3: ⚠️ Code geschrieben, nicht getestet
- 4-5: ❓ Offen (Device-Testing erforderlich)
- 6-7: ✅ Fertig
