# Device Test-Checklist

**Datum:** 26. Oktober 2025
**Device:** iPhone
**Build:** Debug

---

## Vorbereitung

- [ ] App per Xcode auf iPhone installieren (Cmd+R)
- [ ] Xcode Console offen lassen für Logs

---

## Test 1: End-Gong komplett hörbar (Bug 1)

**Wo:** Offen-Tab
**Was testen:** End-Gong spielt vollständig aus, wird nicht abgeschnitten

### Schritte:

1. [ ] Öffne "Offen"-Tab
2. [ ] Setze Phase 1: **1 Minute**, Phase 2: **1 Minute**
3. [ ] Tippe "Start"
4. [ ] Warte 2 Minuten bis Session endet
5. [ ] **LAUSCHE:** Hörst du den kompletten End-Gong?

### Erwartung:

- ✅ End-Gong ("gong-ende") spielt **vollständig** aus
- ✅ Gong klingt **nicht** abrupt ab
- ✅ Gong endet sauber/natürlich

### Bei Fehler:

- ❌ Gong wird abgeschnitten → Bug 1 NICHT behoben, melde mir das
- ❌ Gong spielt gar nicht → Neues Problem, melde mir das

---

## Test 2: Countdown-Sounds (3-2-1) hörbar (Bug 5)

**Wo:** Workouts-Tab
**Was testen:** 3 kurze Beeps bei -3s, -2s, -1s vor Ende der Belastung

### Schritte:

1. [ ] Öffne "Workouts"-Tab
2. [ ] Setze Belastung: **10 Sekunden**, Erholung: **5 Sekunden**, Wiederholungen: **2**
3. [ ] Tippe "Start"
4. [ ] Warte bis Belastung fast vorbei ist (letzte 3 Sekunden)
5. [ ] **LAUSCHE:** Hörst du 3 separate "kurz" Sounds im Sekundentakt?

### Erwartung:

- ✅ Bei -3s: **BEEP** (1. Sound)
- ✅ Bei -2s: **BEEP** (2. Sound)
- ✅ Bei -1s: **BEEP** (3. Sound)
- ✅ Alle 3 Sounds klar hörbar
- ✅ Keine Überlappung oder Unterbrechung

### Bei Fehler:

- ❌ Nur 1 Sound hörbar → Bug 5 NICHT behoben, melde mir das
- ❌ 2 Sounds hörbar → Teilweise behoben, melde mir das
- ❌ Sounds überlappen komisch → Melde mir das

---

## Test 3: Smart Reminders - Permission Handling (Bug 3, Teil 1)

**Wo:** Einstellungen → Smart Reminders
**Was testen:** UI disabled wenn Permissions fehlen

### Schritte:

1. [ ] **Deaktiviere alle Permissions:**
   - iOS Settings → Lean Health Timer → Benachrichtigungen: **AUS**
   - iOS Settings → Lean Health Timer → Hintergrundaktualisierung: **AUS**
   - iOS Settings → Health → Achtsamkeit → Lean Health Timer: **LESEN VERWEIGERN**

2. [ ] Öffne App → Einstellungen → Smart Reminders

3. [ ] **PRÜFE UI:**
   - [ ] Toggle "Smart Reminders aktivieren" ist **GRAU/DISABLED**?
   - [ ] Orange Warning-Banner sichtbar?
   - [ ] Alle 3 Permissions zeigen **❌ (rot)**?

4. [ ] Tippe "Einstellungen öffnen" Button
   - [ ] Öffnet iOS Settings?

5. [ ] **Aktiviere alle Permissions:**
   - Benachrichtigungen: **ERLAUBEN**
   - Hintergrundaktualisierung: **AN**
   - Health → Achtsamkeit: **LESEN ERLAUBEN**

6. [ ] Gehe zurück zur App (App Switcher)

7. [ ] **PRÜFE UI:**
   - [ ] Toggle ist jetzt **ENABLED (blau)**?
   - [ ] Warning-Banner ist **WEG**?
   - [ ] 2 Beispiel-Reminders sichtbar?

### Erwartung:

- ✅ Toggle disabled bei fehlenden Permissions
- ✅ Warning-Banner korrekt
- ✅ Live-Prüfung funktioniert (Banner verschwindet automatisch)

### Bei Fehler:

- ❌ Toggle bleibt disabled trotz Permissions → Melde mir das
- ❌ Banner bleibt trotz Permissions → Melde mir das
- ❌ App muss neu gestartet werden → Melde mir das

---

## Test 4: Smart Reminders - Scheduling Logs (Bug 3, Teil 2)

**Wo:** Xcode Console
**Was testen:** Nächster Check wird korrekt berechnet

### Schritte:

1. [ ] Smart Reminders aktivieren (falls noch nicht)
2. [ ] **Erstelle neuen Reminder:**
   - Titel: "Test Morgen"
   - Nachricht: "Test"
   - **Uhrzeit: Morgen um 9:00 Uhr**
   - Wochentage: **Nur morgigen Tag** auswählen
   - Stunden ohne Aktivität: 24
   - Aktivitätstyp: Meditation
   - **Speichern**

3. [ ] **SOFORT in Xcode Console schauen:**
   - Suche nach: "📅 Next check scheduled at"

### Erwartung in Console:

```
📅 Next check scheduled at 2025-10-27 08:55:00
✅ Scheduled next reminder check at 2025-10-27 08:55:00
```

### Prüfe:

- [ ] Datum ist **morgen** (nicht heute)?
- [ ] Uhrzeit ist **08:55** (5 Minuten VOR 09:00)?

### Bei Fehler:

- ❌ Keine Logs erscheinen → Melde mir das
- ❌ Zeit ist falsch (nicht 08:55) → Melde mir das + Screenshot
- ❌ Datum ist falsch → Melde mir das

---

## Test 5: Smart Reminders - Short-term Scheduling (Bug 3, Teil 3)

**Wo:** Xcode Console
**Was testen:** Reminders <5min werden sofort scheduled

### Schritte:

1. [ ] **Erstelle neuen Reminder:**
   - Titel: "Short-term Test"
   - **Uhrzeit: JETZT + 8 Minuten**
     (Beispiel: Wenn es 15:42 ist → 15:50 setzen)
   - Wochentage: **Heute**
   - Stunden ohne Aktivität: 1
   - **Speichern**

2. [ ] **SOFORT in Xcode Console schauen:**
   - Suche nach: "⚡ Next reminder <5min away"

### Erwartung in Console:

```
⚡ Next reminder <5min away, scheduling immediate check at 2025-10-26 15:43:00
✅ Scheduled next reminder check at 2025-10-26 15:43:00
```

### Prüfe:

- [ ] "⚡ Next reminder <5min away" Log erscheint?
- [ ] Check-Zeit ist in **~60 Sekunden** (nicht 5min vorher)?

### Bei Fehler:

- ❌ Kein ⚡ Log → Melde mir das
- ❌ Check-Zeit ist in 5 Minuten → Melde mir das

---

## Test 6: Smart Reminders - Background Task (OPTIONAL - Overnight)

**Wo:** Device über Nacht
**Was testen:** BGTask feuert morgens (unzuverlässig in iOS)

### Schritte:

1. [ ] **Erstelle Reminder für morgen früh:**
   - Titel: "Background Test"
   - **Uhrzeit: Morgen 7:00 Uhr**
   - Wochentage: **Morgigen Tag**
   - Stunden ohne Aktivität: 24
   - **Speichern**

2. [ ] **WICHTIG:**
   - [ ] iPhone per Kabel ans Ladegerät
   - [ ] Background App Refresh: **AN**
   - [ ] App **vollständig schließen** (Swipe up im App Switcher)

3. [ ] iPhone über Nacht liegen lassen

4. [ ] Morgen um 7:00 Uhr ± 15min:
   - [ ] Notification erschienen?

### Erwartung:

- 📬 Push-Notification auf Lock Screen
- Titel: "Background Test"

### WICHTIG:

⚠️ **BGTasks sind unzuverlässig!** iOS kann Tasks verzögern oder überspringen.
Wenn Notification NICHT erscheint → **KEIN Bug**, sondern iOS-Heuristik.

### Bei Erfolg:

- ✅ Notification erscheint → Sehr gut! Melde mir das

### Bei Fehler:

- ❌ Keine Notification → **Normal** bei BGTasks, kein Problem

---

## Zusammenfassung - Was muss funktionieren

| Test | Kritisch? | Muss funktionieren? |
|------|-----------|---------------------|
| Test 1: End-Gong komplett | ✅ Ja | End-Gong spielt vollständig |
| Test 2: 3x Countdown-Sounds | ✅ Ja | Alle 3 Sounds hörbar |
| Test 3: Permission UI | ✅ Ja | Toggle disabled ohne Permissions |
| Test 4: Scheduling Logs (morgen) | ✅ Ja | Check 5min vor Trigger |
| Test 5: Scheduling Logs (<5min) | ✅ Ja | Immediate scheduling |
| Test 6: BGTask Overnight | ⚠️ Nice-to-have | Optional, oft unzuverlässig |

---

## Fehler melden

Wenn ein Test fehlschlägt, gib mir bitte:

1. **Welcher Test:** (z.B. "Test 2: Countdown-Sounds")
2. **Was passiert ist:** (z.B. "Nur 1 Sound hörbar")
3. **Xcode Console Logs:** (falls vorhanden, kopiere relevante Zeilen)
4. **Screenshot:** (falls UI-Problem)

---

**Viel Erfolg beim Testen! 🧪**
