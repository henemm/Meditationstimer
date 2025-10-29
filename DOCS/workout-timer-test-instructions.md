# Workout Timer - Test-Anweisungen (Timing-Fix)

**Branch:** `feature/workout-timer-timing-fix`
**Datum:** 2025-10-29
**Änderungen:** Neues Timing-System für präzise Audio-Cues

---

## Was wurde geändert?

### Technische Änderungen (unsichtbar für User):
- ✅ **Timing-System:** Continuous Monitoring statt Drift-Offset
- ✅ **Audio-Scheduling:** Separater Timer (alle 0.1s) statt UI-gebunden
- ✅ **Last-Round Support:** "last-round" Sound wird jetzt korrekt abgespielt

### UI (unverändert):
- ✅ **Identisches Layout:** Alle Screens sehen exakt gleich aus
- ✅ **Identische Animationen:** Keine visuellen Änderungen
- ✅ **Identische Live Activity:** Dynamic Island/Lock Screen unverändert

**Erwartung:** Du solltest **keinen visuellen Unterschied** sehen, aber **präziseres Timing** erleben.

---

## Was testen?

### 1. Basis-Test: countdown-transition Timing

**Setup:**
- Belastung: **30 Sekunden**
- Erholung: **10 Sekunden**
- Wiederholungen: **3 Runden**

**Ablauf:**
1. Starte Workout
2. Höre auf den `countdown-transition` Sound (3 Beeps + langer Ton)
3. **Starte Stoppuhr** sobald der Countdown-Sound beginnt
4. **Stoppe Stoppuhr** sobald die Belastungsphase endet (Wechsel zu Erholung)

**Erwartung:**
- ⏱️ **Soll: 3.0 Sekunden** (±0.2s Toleranz)
- 🎯 **Ziel: Countdown endet exakt beim Phasenwechsel**

**Zu prüfen:**
- [ ] Countdown startet ~3s vor Ende der Belastung
- [ ] Countdown-Ende = Phasenwechsel (synchron)
- [ ] Alle 3 Runden haben gleiches Timing (kein Drift)

---

### 2. Verschiedene Belastungs-Dauern

**Test-Konfigurationen:**

| Belastung | Erholung | Runden | Prüfpunkt |
|-----------|----------|--------|-----------|
| 10s       | 5s       | 3      | Countdown ~3s vor Ende? |
| 20s       | 10s      | 3      | Countdown ~3s vor Ende? |
| 60s       | 15s      | 3      | Countdown ~3s vor Ende? |
| 120s      | 30s      | 2      | Countdown ~3s vor Ende? |

**Zu prüfen:**
- [ ] Countdown-Timing ist konsistent (unabhängig von Belastungs-Dauer)
- [ ] Kein "Drift" bei längeren Phasen (120s genauso präzise wie 10s)

---

### 3. Rundenansagen

**Setup:**
- Belastung: **30 Sekunden**
- Erholung: **10 Sekunden**
- Wiederholungen: **5 Runden**

**Zu prüfen:**
- [ ] **Runde 1:** KEINE Ansage (normal)
- [ ] **Runde 2:** "Runde 2" während Erholung von Runde 1
- [ ] **Runde 3:** "Runde 3" während Erholung von Runde 2
- [ ] **Runde 4:** "Runde 4" während Erholung von Runde 3
- [ ] **Runde 5 (letzte):** "last-round" während Erholung von Runde 4

**Wichtig:**
- Rundenansagen sollen **früh in der Erholungsphase** kommen (~20% der Erholungszeit)
- `auftakt` Sound soll **kurz vor Ende der Erholung** kommen (Pre-Roll)

---

### 4. Pause/Resume

**Setup:**
- Belastung: **30 Sekunden**
- Erholung: **10 Sekunden**
- Wiederholungen: **3 Runden**

**Test A: Pause während Belastung (vor Countdown)**
1. Starte Workout
2. Nach 10s → **Pause drücken**
3. Warte 5 Sekunden
4. **Resume drücken**
5. Warte bis Countdown-Sound

**Zu prüfen:**
- [ ] Countdown kommt zur richtigen Zeit (3s vor Ende der verbleibenden Zeit)
- [ ] Keine doppelten Sounds
- [ ] Phase-Timer läuft korrekt weiter

**Test B: Pause während Belastung (nach Countdown gestartet)**
1. Starte Workout
2. Warte bis Countdown-Sound beginnt (bei ~27s)
3. Sofort **Pause drücken** (während Countdown läuft)
4. **Resume drücken**

**Zu prüfen:**
- [ ] Countdown wird gestoppt (kein Weiterlaufen im Hintergrund)
- [ ] Nach Resume: Kein erneuter Countdown (Phase endet normal)

**Test C: Pause während Erholung**
1. Starte Workout, warte bis Erholung beginnt
2. **Pause drücken** während Erholung
3. **Resume drücken**

**Zu prüfen:**
- [ ] Auftakt-Sound spielt zur richtigen Zeit
- [ ] Rundenansage (falls vorhanden) spielt korrekt

---

### 5. Abbruch

**Setup:**
- Belastung: **30 Sekunden**
- Erholung: **10 Sekunden**
- Wiederholungen: **3 Runden**

**Test A: X-Button während Belastung**
1. Starte Workout
2. Nach 15s → **X-Button drücken**

**Zu prüfen:**
- [ ] Alle Sounds stoppen sofort
- [ ] Workout schließt sich (zurück zur Haupt-Ansicht)
- [ ] HealthKit-Logging erfolgt (falls gewünscht)
- [ ] Live Activity endet

**Test B: X-Button während Erholung**
1. Starte Workout, warte bis Erholung
2. **X-Button drücken**

**Zu prüfen:**
- [ ] Alle Sounds stoppen sofort
- [ ] Workout schließt sich
- [ ] Keine Crashes

---

### 6. Edge Cases

**Test A: Sehr kurze Belastung (5s)**
- Belastung: **5 Sekunden**
- Erholung: **3 Sekunden**
- Wiederholungen: **3 Runden**

**Zu prüfen:**
- [ ] Countdown startet ~3s vor Ende (also fast sofort nach Start)
- [ ] Kein Overlap mit anderen Sounds
- [ ] Phase-Wechsel funktioniert

**Test B: Keine Erholung (0s)**
- Belastung: **20 Sekunden**
- Erholung: **0 Sekunden**
- Wiederholungen: **3 Runden**

**Zu prüfen:**
- [ ] Countdown am Ende jeder Belastung
- [ ] Direkt zur nächsten Belastung (keine Erholung)
- [ ] Keine Rundenansagen (weil keine Erholungsphase)
- [ ] Auftakt-Sound fehlt (normal, weil keine Erholung)

**Test C: Lange Phasen (120s)**
- Belastung: **120 Sekunden**
- Erholung: **30 Sekunden**
- Wiederholungen: **2 Runden**

**Zu prüfen:**
- [ ] Countdown nach ~117s (präzise, kein Drift)
- [ ] Timer läuft stabil (keine UI-Freezes)

---

### 7. Background-Verhalten

**Setup:**
- Belastung: **60 Sekunden**
- Erholung: **15 Sekunden**
- Wiederholungen: **2 Runden**

**Ablauf:**
1. Starte Workout
2. Nach 20s → **Wechsle zu anderer App** (z.B. Home-Screen)
3. Warte 10 Sekunden
4. **Zurück zur App**

**Zu prüfen:**
- [ ] Timer läuft korrekt weiter (Zeit stimmt)
- [ ] Live Activity zeigt korrekte Restzeit
- [ ] Countdown kommt zur richtigen Zeit
- [ ] Keine Crashes beim Zurückkehren

---

### 8. Live Activity / Dynamic Island

**Setup:**
- Belastung: **30 Sekunden**
- Erholung: **10 Sekunden**
- Wiederholungen: **3 Runden**

**Zu prüfen (während Workout läuft):**
- [ ] **Dynamic Island:** Zeigt Flame-Icon während Belastung
- [ ] **Dynamic Island:** Zeigt Pause-Icon während Erholung
- [ ] **Dynamic Island:** Countdown-Timer läuft korrekt
- [ ] **Lock Screen:** Activity zeigt korrekte Restzeit
- [ ] **Lock Screen:** Satz-Anzeige (z.B. "2/3") korrekt
- [ ] **Pause:** Live Activity zeigt "Pausiert"-Status

---

## Bekannte Unterschiede (aktuell vs. neu)

### Was sollte BESSER sein:
- ✅ **Countdown-Transition:** Präzises Timing (kein Drift mehr)
- ✅ **Alle Belastungs-Dauern:** Gleiche Präzision (10s genauso gut wie 120s)
- ✅ **Pause/Resume:** Sounds schedulen sich korrekt neu

### Was sollte GLEICH sein:
- ✅ **UI:** Identisches Aussehen
- ✅ **Animationen:** Keine Änderungen
- ✅ **Live Activity UI:** Unverändert
- ✅ **Rundenansagen:** Wie vorher (nur last-round neu unterstützt)

---

## Fehler-Meldung

Falls du Probleme findest, notiere bitte:

1. **Konfiguration:** Belastung/Erholung/Runden
2. **Szenario:** Was hast du getan?
3. **Erwartung:** Was sollte passieren?
4. **Tatsächlich:** Was ist passiert?
5. **Timing:** Mit Stoppuhr gemessen (falls relevant)
6. **Screenshots:** Von Live Activity (falls relevant)

---

## Erfolgs-Kriterien

**Bestanden, wenn:**
- ✅ Countdown-Transition startet bei **3.0s ± 0.2s** vor Ende (alle Belastungs-Dauern)
- ✅ Keine Drift über mehrere Runden
- ✅ Pause/Resume funktioniert korrekt (Sounds schedulen sich neu)
- ✅ Rundenansagen zur richtigen Zeit (während Erholung)
- ✅ Last-round Sound bei letzter Runde
- ✅ Keine Crashes, keine UI-Probleme

**Falls Timing immer noch ungenau:**
- Notiere genaue Abweichungen (mit Stoppuhr)
- Dann können wir das Monitoring-Intervall anpassen (aktuell 0.1s)

---

**Viel Erfolg beim Testen!** 🎯
