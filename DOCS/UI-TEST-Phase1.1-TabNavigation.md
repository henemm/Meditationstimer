# UI-Test-Anweisungen: Phase 1.1 Tab Navigation

**Datum:** 15. Dezember 2025
**Feature:** Tab-Struktur von 4 alten Tabs auf 4 neue Tabs umgestellt
**Tester:** Henning (echtes Device)

---

## Übersicht der Änderungen

| Alt | Neu | Inhalt |
|-----|-----|--------|
| Offen | **Meditation** | Zwei-Phasen-Timer (unverändert) |
| Frei | **Workout** | HIIT-Timer (unverändert) |
| - | **Tracker** | NoAlc-Button + Placeholder |
| - | **Erfolge** | Streaks + Kalender-Link |
| Atem | (entfernt) | Kommt in Phase 2 zurück |
| Workouts | (entfernt) | Kommt in Phase 2 zurück |

---

## Testschritte

### Test 1: Tab-Leiste sichtbar
**Schritte:**
1. App starten
2. Unten auf die Tab-Leiste schauen

**Erwartetes Ergebnis:**
- 4 Tabs sichtbar: Meditation, Workout, Tracker, Erfolge
- Icons: figure.mind.and.body, flame, chart.bar.fill, trophy.fill
- Meditation ist standardmäßig ausgewählt

**Status:** [ ] Pass / [ ] Fail

---

### Test 2: Meditation Tab
**Schritte:**
1. Auf "Meditation" Tab tippen (falls nicht schon aktiv)
2. Zwei-Phasen-Timer sichtbar?
3. Phase 1 auf 5 Min stellen, Phase 2 auf 1 Min
4. Start-Button tippen
5. Nach 5 Sekunden Stop tippen

**Erwartetes Ergebnis:**
- Timer zeigt Countdown
- Gong spielt bei Start
- Stop funktioniert
- Timer resettet

**Status:** [ ] Pass / [ ] Fail

---

### Test 3: Workout Tab
**Schritte:**
1. Auf "Workout" Tab tippen
2. HIIT-Timer sichtbar?
3. Intervall auf 10s, Pause auf 5s, 3 Wiederholungen einstellen
4. Start-Button tippen
5. Nach einem Intervall Stop tippen

**Erwartetes Ergebnis:**
- HIIT-Timer zeigt Countdown
- Intervall/Pause-Wechsel funktioniert
- Audio-Cues spielen
- Stop funktioniert

**Status:** [ ] Pass / [ ] Fail

---

### Test 4: Tracker Tab
**Schritte:**
1. Auf "Tracker" Tab tippen
2. UI prüfen

**Erwartetes Ergebnis:**
- "Log Today" Button sichtbar
- Tippen öffnet NoAlc-Sheet
- "More Trackers" Placeholder sichtbar
- "Custom trackers coming in Phase 2" Text

**Status:** [ ] Pass / [ ] Fail

---

### Test 5: Erfolge Tab
**Schritte:**
1. Auf "Erfolge" Tab tippen
2. UI prüfen
3. "View Calendar" tippen

**Erwartetes Ergebnis:**
- Streak-Badges sichtbar (Meditation, Workout)
- Rewards-Anzeige sichtbar
- Kalender öffnet sich bei Tap auf "View Calendar"
- Kalender schließt sich mit "Done"

**Status:** [ ] Pass / [ ] Fail

---

### Test 6: Tab-Wechsel während Timer läuft
**Schritte:**
1. Im Meditation Tab Timer starten
2. Zu Workout Tab wechseln
3. Zurück zu Meditation Tab

**Erwartetes Ergebnis:**
- Timer läuft weiter (oder stoppt - je nach gewünschtem Verhalten)
- Keine Crashes
- UI bleibt responsiv

**Status:** [ ] Pass / [ ] Fail
**Notizen:** ____________________

---

### Test 7: Deep Link (optional, falls Shortcuts eingerichtet)
**Schritte:**
1. Shortcut mit `henemm-lht://start?tab=offen&phase1=10` ausführen

**Erwartetes Ergebnis:**
- App öffnet sich
- Meditation Tab ist aktiv
- Timer startet mit 10 Min

**Status:** [ ] Pass / [ ] Fail / [ ] Übersprungen

---

## Zusammenfassung

| Test | Ergebnis |
|------|----------|
| Test 1: Tab-Leiste | |
| Test 2: Meditation | |
| Test 3: Workout | |
| Test 4: Tracker | |
| Test 5: Erfolge | |
| Test 6: Tab-Wechsel | |
| Test 7: Deep Link | |

**Gesamtergebnis:** ___/7 Tests bestanden

**Gefundene Bugs:**
-

**Anmerkungen:**
-

---

**Getestet von:** Henning
**Datum:** ____________________
