# Was Du testen musst

## 🔴 KRITISCH - Muss funktionieren:

### 1. End-Gong (Bug 1)
- **Offen-Tab:** Phase 1 = 1min, Phase 2 = 1min
- **Starte** die Session
- **Warte** 2 Minuten bis Ende
- **Hörst du den kompletten End-Gong?** (nicht abgeschnitten)

---

### 2. Countdown-Sounds (Bug 5)
- **Workouts-Tab:** Belastung = 10s, Erholung = 5s, Wiederholungen = 2
- **Starte** das Workout
- **Letzte 3 Sekunden der Belastung:** Hörst du **3 separate Beeps** (3-2-1)?

---

### 3. Smart Reminders - Permissions (Bug 3)
1. **Deaktiviere in iOS Settings:**
   - Benachrichtigungen: AUS
   - Hintergrundaktualisierung: AUS
   - Health → Achtsamkeit → Lesen: VERWEIGERN

2. **App öffnen → Smart Reminders:**
   - Ist Toggle **grau/disabled**?
   - Siehst du **Orange Warning-Banner**?

3. **Aktiviere alle Permissions wieder**

4. **Zurück zur App:**
   - Ist Toggle jetzt **enabled**?
   - Banner **weg**?

---

### 4. Smart Reminders - Scheduling Logs (Bug 3)
- **Erstelle Reminder:** Morgen 9:00 Uhr, nur morgigen Tag
- **Speichern**
- **Xcode Console:** Steht da "📅 Next check scheduled at [MORGEN] 08:55:00"?
  - Datum = morgen?
  - Uhrzeit = 08:55 (5min vor 9:00)?

---

## ⚪ OPTIONAL:

### 5. Smart Reminders - Overnight Test
- Reminder für morgen 7:00 Uhr erstellen
- App schließen, iPhone laden lassen
- Morgen: Kommt Notification?
  - **Wenn JA:** Super!
  - **Wenn NEIN:** Normal, kein Problem (iOS ist unzuverlässig)

---

## ✅ Erfolgskriterien:

| Test | Muss funktionieren |
|------|-------------------|
| 1. End-Gong komplett | ✅ JA |
| 2. 3x Countdown-Sounds | ✅ JA |
| 3. Permission UI | ✅ JA |
| 4. Scheduling Logs | ✅ JA |
| 5. Overnight (optional) | ⚪ Nice-to-have |

---

**Bei Fehler sag mir:**
- Welcher Test
- Was ist passiert
- (Optional: Console Logs / Screenshot)
