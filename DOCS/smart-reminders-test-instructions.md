# Smart Reminders - Test-Anweisungen für Device

**Status:** Code implementiert, Build erfolgreich, wartet auf Device-Test
**Datum:** 26. Oktober 2025

---

## 🎯 Was wurde implementiert?

Smart Reminders wurden **komplett neu geschrieben** mit folgenden Verbesserungen:

### Kern-Logik (SmartReminderEngine.swift)
✅ **Korrekte Scheduling-Logik** - Findet nächsten Reminder basierend auf Wochentagen
✅ **Wochentage-Prüfung** - Reminder feuert nur an ausgewählten Tagen
✅ **Look-back von NOW korrigiert** - Prüft Aktivität bis jetzt (nicht nur bis triggerStart)
✅ **Test-Button entfernt** - Wie gewünscht
✅ **Beispieldaten persistent** - Werden jetzt in Engine gespeichert

### Permission-Handling (SmartRemindersView.swift)
✅ **Toggle disabled** wenn Permissions fehlen
✅ **Warning-Banner** zeigt fehlende Permissions mit Checklist
✅ **"Einstellungen öffnen" Button** mit Anleitung
✅ **Live-Überwachung** - Permissions werden neu geprüft wenn App aus Settings zurückkommt

---

## 📱 Test-Plan (auf Physical Device)

### Pre-Test: App neu builden

**In Xcode:**
1. iPhone per Kabel verbinden
2. Als Target auswählen (oben links)
3. **Cmd+R** drücken → App startet im Debug-Modus
4. Xcode Console offen lassen für Logs

**Oder via Terminal:**
```bash
cd /Users/hem/Documents/opt/Meditationstimer/Meditationstimer
xcodebuild -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -configuration Debug \
  -destination 'name=Hennings iPhone 16 Pro' \
  build
```

---

## Test 1: Permission-Handling (KRITISCH)

**Ziel:** Prüfen ob Permission-Checks funktionieren und UI korrekt disabled wird.

### 1.1 Alle Permissions deaktivieren

**iOS Settings:**
1. **Einstellungen → Lean Health Timer**
   - Benachrichtigungen: **Deaktivieren**
   - Hintergrundaktualisierung: **Deaktivieren**
2. **Einstellungen → Health → Achtsamkeit**
   - Lean Health Timer: Lesen **Verweigern**

### 1.2 App öffnen → Smart Reminders

**Erwartung:**
```
[ Toggle: Smart Reminders aktivieren ] ← GRAU + DISABLED

┌─────────────────────────────────────────┐
│ ⚠️ Fehlende Berechtigungen               │
│                                         │
│ Smart Reminders benötigen:              │
│ ❌ Benachrichtigungen                   │
│ ❌ Hintergrundaktualisierung            │
│ ❌ HealthKit (Achtsamkeit lesen)        │
│                                         │
│ [ Einstellungen öffnen → ]              │
└─────────────────────────────────────────┘

(Anleitung: Gehe zu Einstellungen → ...)
```

**Verifizieren:**
- ✅ Toggle ist disabled (grau)?
- ✅ Alle 3 Permissions zeigen ❌ (rot)?
- ✅ Orange Warning-Banner sichtbar?

### 1.3 Permissions aktivieren

1. **"Einstellungen öffnen" Button** antippen
2. Öffnet iOS Settings?
3. **Benachrichtigungen: Erlauben**
4. **Hintergrundaktualisierung: Aktivieren**
5. **Health → Achtsamkeit → Lesen erlauben**

### 1.4 Zurück zur App

**Erwartung:**
```
[ Toggle: Smart Reminders aktivieren ] ← ENABLED (blau)

[ Liste der Reminders ]
- Morgendliche Meditation (8:00 Uhr, Mo-So)
- Abendliches Workout (18:00 Uhr, Mo-Fr)
```

**Verifizieren:**
- ✅ Toggle ist enabled?
- ✅ Warning-Banner ist WEG?
- ✅ 2 Beispiel-Reminders sichtbar?

---

## Test 2: Reminder-Scheduling (Device-Logs)

**Ziel:** Prüfen ob nächster Check korrekt berechnet wird.

### 2.1 Reminder für morgen früh erstellen

1. **"+ Neue Erinnerung hinzufügen"**
2. Titel: "Test Morgen"
3. Nachricht: "Test für morgigen Tag"
4. **Uhrzeit: Morgen 9:00 Uhr** (heute + 1 Tag, 9:00)
5. Wochentage: **Nur morgigen Tag** auswählen
6. Stunden ohne Aktivität: 24
7. Aktivitätstyp: Meditation
8. **Speichern**

### 2.2 Xcode Console prüfen

**Erwartung (erscheint sofort nach Speichern):**
```
📅 Next check scheduled at 2025-10-27 08:55:00
✅ Scheduled next reminder check at 2025-10-27 08:55:00
```

**Verifizieren:**
- ✅ Check-Zeit ist **5 Minuten VOR** Trigger-Zeit (08:55 statt 09:00)?
- ✅ Datum ist **morgen**?

---

## Test 3: Short-term Reminder (Device-Logs)

**Ziel:** Prüfen ob Reminders <5min korrekt "sofort" scheduled werden.

### 3.1 Reminder für JETZT + 8 Minuten

1. **Neue Erinnerung**
2. Titel: "Short-term Test"
3. **Uhrzeit: JETZT + 8 Minuten** (z.B. wenn es 15:42 ist → 15:50 setzen)
4. Wochentage: **Heute** auswählen
5. Stunden ohne Aktivität: 1
6. **Speichern**

### 3.2 Xcode Console prüfen

**Erwartung:**
```
⚡ Next reminder <5min away, scheduling immediate check at 2025-10-26 15:43:00
✅ Scheduled next reminder check at 2025-10-26 15:43:00
```

**Verifizieren:**
- ✅ "⚡ Next reminder <5min away" Log erscheint?
- ✅ Check-Zeit ist in **~60 Sekunden** (nicht 5min vorher)?

---

## Test 4: HealthKit Integration (Device)

**Ziel:** Prüfen ob Reminder NICHT feuert wenn Aktivität vorhanden war.

### 4.1 Echte Meditation loggen

**In der App:**
1. **Offen-Tab** öffnen
2. Phase 1: **5 Minuten**
3. Phase 2: **1 Minute**
4. **Start** → Meditation durchführen
5. Warten bis Session fertig
6. **HealthKit Log prüfen:** Health App → Achtsamkeit → Sollte 5min-Session zeigen

### 4.2 Reminder mit kurzer Inaktivität erstellen

1. **Neue Erinnerung**
2. Titel: "HealthKit Test"
3. **Uhrzeit: JETZT + 10 Minuten**
4. Wochentage: **Heute**
5. **Stunden ohne Aktivität: 1** (du hattest gerade Meditation vor 1min!)
6. Aktivitätstyp: **Meditation**
7. **Speichern**

### 4.3 10 Minuten warten

**App im Vordergrund lassen** (einfacher zu debuggen)

### 4.4 Erwartung (nach 10min in Console)

```
🔔 Starting smart reminder check
✅ Reminder 'HealthKit Test' skipped: activity found in last 1h
✅ Completed check: no notifications triggered
```

**Verifizieren:**
- ✅ KEINE Notification erscheint?
- ✅ Console zeigt "activity found in last 1h"?

---

## Test 5: Background Task (Overnight Test)

**Ziel:** Prüfen ob BGTask morgen früh ausgeführt wird.

### 5.1 Reminder für morgen früh (ohne vorherige Aktivität)

1. **Neue Erinnerung**
2. Titel: "Background Test"
3. **Uhrzeit: Morgen 9:00 Uhr**
4. Wochentage: **Morgigen Tag**
5. **Stunden ohne Aktivität: 24** (du hattest morgen um 9:00 noch keine Aktivität)
6. **Speichern**

### 5.2 App schließen & iPhone über Nacht liegen lassen

**WICHTIG:**
- ✅ iPhone per Kabel am Strom
- ✅ Background App Refresh: **AN**
- ✅ App **vollständig schließen** (nicht nur im Hintergrund)

### 5.3 Morgen um 9:00 Uhr ± 15min

**Erwartung:**
- 📬 **Notification erscheint** (Push-Banner auf Lock Screen)
- Titel: "Background Test"
- Body: [Deine Nachricht]

**⚠️ WICHTIG:** iOS BGTasks sind **unzuverlässig**! Timing ist **nicht garantiert** (±15min normal). Wenn Notification NICHT erscheint → kann iOS-Heuristik sein (Battery, system busy, etc.). Das ist ein bekanntes iOS-Problem, KEIN App-Bug.

---

## Test 6: Wochentage-Prüfung

**Ziel:** Prüfen ob Reminder nur an ausgewählten Tagen feuert.

### 6.1 Reminder nur für Montag

1. **Neue Erinnerung**
2. Titel: "Nur Montag"
3. Uhrzeit: Heute + 5 Minuten
4. Wochentage: **Nur Montag** auswählen
5. **Speichern**

### 6.2 Wenn heute NICHT Montag ist

**Erwartung (in Console nach 5min):**
```
❌ Reminder 'Nur Montag' not active on [heutiger Tag]
✅ Completed check: no notifications triggered
```

**Verifizieren:**
- ✅ KEINE Notification?
- ✅ Console zeigt "not active on [Tag]"?

---

## 🐛 Bekannte Probleme & Workarounds

### Problem 1: BGTask feuert nicht morgens

**Symptom:** Keine Notification erscheint
**Ursache:** iOS-Heuristik (Battery, System busy, Developer-Build)
**Workaround:** Release-Build testen oder mehrere Tage testen

### Problem 2: Permissions nicht erkannt nach Aktivierung

**Symptom:** Toggle bleibt disabled trotz aktivierter Permissions
**Workaround:** App **killen** und neu starten (Force-Close)

### Problem 3: Console Logs nicht sichtbar

**Symptom:** Keine Emoji-Logs in Xcode Console
**Workaround:** Filter in Console löschen, App neu starten

---

## ✅ Success Criteria

**Feature ist DONE wenn:**

1. ✅ **Permission-Handling funktioniert**
   - Toggle disabled bei fehlenden Permissions
   - Warning-Banner korrekt
   - Permissions live-geprüft

2. ✅ **Scheduling korrekt**
   - Nächster Check 5min VOR Trigger
   - Short-term (<5min) scheduled in 60s
   - Wochentage korrekt beachtet

3. ✅ **HealthKit-Integration funktioniert**
   - Keine Notification wenn Aktivität vorhanden
   - Notification wenn keine Aktivität

4. ⏳ **Background Task feuert** (kann mehrere Tage dauern wegen iOS-Heuristik)

---

## 📊 Test-Report Template

Bitte nach Tests ausfüllen:

```
## Test-Ergebnisse (Datum: ___)

### Test 1: Permission-Handling
- Toggle disabled bei fehlenden Permissions? [ ]
- Warning-Banner sichtbar? [ ]
- Permissions nach Aktivierung erkannt? [ ]

### Test 2: Reminder-Scheduling
- Check 5min VOR Trigger? [ ]
- Console-Logs korrekt? [ ]

### Test 3: Short-term Reminder
- Immediate scheduling (<5min)? [ ]

### Test 4: HealthKit Integration
- Notification NICHT gesendet bei Aktivität? [ ]
- Console zeigt "activity found"? [ ]

### Test 5: Background Task
- Notification morgens erschienen? [ ]
- Timing ungefähr korrekt (±15min)? [ ]

### Test 6: Wochentage
- Reminder nur an ausgewählten Tagen? [ ]

### Bugs gefunden:
- [Liste hier]

### Notizen:
- [Weitere Beobachtungen]
```

---

**Bei Fragen oder Bugs:** Xcode Console-Logs kopieren und bereitstellen!
