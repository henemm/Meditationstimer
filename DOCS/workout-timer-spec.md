# Workout Timer - Feature Spezifikation

**Datum:** 2025-10-29
**Status:** Spezifikation für alternative Implementierung
**Typ:** HIIT (High Intensity Interval Training) Timer

---

## 1. Überblick

Der Workout-Timer ist ein konfigurierbarer HIIT-Timer mit zwei Phasen (Belastung/Erholung), visuellen Fortschrittsringen und akustischen Signalen. Er integriert sich in das bestehende System (HealthKit, Live Activity, Streak-System).

---

## 2. Timer-Struktur

### Phasen
- **Belastung (Work):** Konfigurierbare Dauer (in Sekunden)
- **Erholung (Rest):** Konfigurierbare Dauer (in Sekunden)
- **Wiederholungen:** Konfigurierbare Anzahl Runden (1-200)

### Konfiguration
- **Belastung:** Picker 0-600 Sekunden (wie in Offen/Atem)
- **Erholung:** Picker 0-600 Sekunden
- **Wiederholungen:** Picker 1-200 Runden
- **Gesamtdauer:** Automatisch berechnet und angezeigt
  - Formel: `(Belastung × Wiederholungen) + (Erholung × (Wiederholungen - 1))`

### Ablauf
```
1. User konfiguriert: Belastung/Erholung/Wiederholungen
2. User startet Workout
3. Auftakt-Sound spielt ab
4. Nach Auftakt: Erste Belastungsphase beginnt (Runde 1)
5. Countdown 3 Sekunden vor Ende der Belastung
6. Belastung endet → Erholungsphase beginnt
7. Während Erholung: Rundenansage für NÄCHSTE Runde
8. Gegen Ende Erholung: Auftakt-Sound
9. Erholung endet → Nächste Belastungsphase beginnt
10. Schritte 5-9 wiederholen für alle Runden
11. Nach letzter Belastungsphase: Ausklang-Sound
12. HealthKit-Logging, Streak-Update
13. Workout beendet
```

---

## 3. Visuelle Darstellung

### UI-Layout
- **Zwei konzentrische Ringe** (wie AtemView)
  - **Äußerer Ring:** Gesamtfortschritt (gesamtes Workout)
  - **Innerer Ring:** Phasenfortschritt (aktuelle Belastung/Erholung, resettet bei jedem Phasenwechsel)

### Farben
- **Primärfarbe:** `Color.workoutViolet` (definiert in `Colors.swift`)
  - RGB: (0.58, green: 0.31, blue: 0.73)
  - Verwendung: Ringe, Buttons, Icons
- **Äußerer Ring:** `workoutViolet` mit opacity 0.8-1.0 Gradient
- **Innerer Ring:** `workoutViolet` mit opacity 0.5-0.7 Gradient

### Icons
- **Belastungsphase:** `flame` (Flamme)
- **Erholungsphase:** `pause` (Pause-Symbol)

### Anzeigen
- **Oben:** Konfiguration-Zusammenfassung (z.B. "10 x 30s/10s")
- **Zentrum:** Doppelter Ring mit Phase-Icon
- **Unten:** Fortschrittsanzeige
  - "Satz X / Y — Belastung" oder
  - "Satz X / Y — Erholung"

### Animationen
- **Phasenwechsel:** Smooth transitions zwischen Icons
- **Ring-Animation:** `.spring()` oder `.smooth` (iOS 17+)
- **Farb-Transitions:** Sanfte Übergänge (keine harten Cuts)

---

## 4. Akustische Signale

### Sound-Dateien
Alle Sounds unterstützen folgende Formate: `.caff`, `.caf`, `.wav`, `.mp3`, `.aiff`

#### 4.1 Haupt-Sounds
- **`auftakt`**
  - Verwendet bei: Workout-Start, Beginn jeder Belastungsphase
  - Timing: Spielt so ab, dass er genau beim Start der Belastungsphase endet

- **`countdown-transition`**
  - 3 Beeps + langer Ton (kombiniert in einer Datei)
  - Verwendet bei: 3 Sekunden vor Ende jeder Belastungsphase
  - Ersetzt separate "3-2-1" Countdown-Ansagen

- **`ausklang`**
  - Finaler Gong am Ende des gesamten Workouts
  - Spielt nach der letzten Belastungsphase

#### 4.2 Rundenansagen
- **`round-2.caff` bis `round-20.caff`**
  - Rundennummern-Ansagen (Deutsch)
  - **Wichtig:** Runde 1 wird NICHT angesagt (keine `round-1` Datei nötig)
  - Timing: Während der Erholungsphase, VOR dem nächsten Auftakt

- **`last-round`** (.caff/.caf/.wav/.mp3/.aiff)
  - Spezielle Ansage für die letzte Runde
  - Timing: Während der Erholungsphase vor der letzten Belastungsphase

### Timing-Übersicht

#### Workout-Start
```
User drückt Start
  → auftakt spielt ab (Dauer: X Sekunden)
  → Nach Ende von auftakt: Runde 1 Belastung beginnt
```

#### Belastungsphase (z.B. 30s)
```
0:00  | Belastung beginnt
      | ...
0:27  | countdown-transition beginnt (3 Beeps + langer Ton)
0:30  | Belastung endet → Erholung beginnt
```

#### Erholungsphase (z.B. 10s) - Runde 2-N
```
0:00  | Erholung beginnt
0:XX  | Rundenansage ("Runde 3" oder "last round")
      | Dann: auftakt beginnt (endet genau bei 0:10)
0:10  | Erholung endet → Nächste Belastung beginnt
```

#### Letzte Belastungsphase
```
0:00  | Letzte Belastung beginnt
      | ...
0:27  | countdown-transition (3 Beeps + langer Ton)
0:30  | Belastung endet
      | ausklang spielt ab
      | Workout beendet
```

### Audio-Logik Besonderheiten

1. **Erste Runde:** Keine Rundenansage (beginnt direkt nach Workout-Start-Auftakt)
2. **Runde 2 bis (N-1):** Normale Rundenansage (`round-X.caff`)
3. **Letzte Runde:** Spezielle Ansage (`last-round`)
4. **Auftakt-Timing:**
   - Pre-Roll während Erholung
   - Berechnung: `Erholung-Dauer - auftakt-Dauer = Start-Zeitpunkt`
   - Ziel: auftakt endet exakt beim Start der nächsten Belastung

---

## 5. Verhalten & Steuerung

### Pause/Resume
- **Pause-Button:** Unterbricht Timer und Audio
- **Resume-Button:** Setzt Timer und Audio fort (kein erneuter Auftakt)
- **State Management:**
  - Akkumulierte Pause-Zeit für Session und Phase getrennt tracken
  - Geplante Sounds müssen bei Pause gecancelt werden
  - Bei Resume: Sounds neu schedulen basierend auf verbleibender Zeit

### Abbruch
- **X-Button (oben rechts):** Beendet Workout vorzeitig
- **Verhalten:**
  - Timer stoppt
  - Alle Sounds stoppen
  - HealthKit-Logging (falls gewünscht)
  - Live Activity beenden
  - Zurück zur Haupt-Ansicht

### Background-Verhalten
- **Timer läuft im Foreground weiter** (wie Offen-Tab)
- **Live Activity mit Restzeit** wird angezeigt
  - Zeigt: Phasen-Icon (Flame/Pause), verbleibende Zeit, aktueller Satz
- **Notifications als Backup** (falls implementiert)

### Idle Timer
- **Display bleibt während Workout aktiv** (UIApplication.isIdleTimerDisabled = true)
- **Nach Workout-Ende:** Idle Timer wieder aktivieren

---

## 6. Integration

### HealthKit
- **Workout-Typ:** `.highIntensityIntervalTraining`
- **Logging:**
  - Start-Zeit: Beginn der ersten Belastungsphase (nach initialem Auftakt)
  - End-Zeit: Ende der letzten Belastungsphase
  - **Gesamtdauer:** Alle Belastungs- UND Erholungsphasen
- **Fehlerbehandlung:** Graceful (keine UI-Unterbrechung bei Fehlern)

### Live Activity / Dynamic Island
- **Start:** Bei Workout-Start
- **Update:** Bei jedem Phasenwechsel
  - Phase 1 = Belastung (Flame-Icon)
  - Phase 2 = Erholung (Pause-Icon)
- **Anzeige:**
  - Titel: "Workout"
  - Phase-Icon (Flame/Pause)
  - Verbleibende Zeit (Countdown zum Workout-Ende)
  - Aktueller Satz (z.B. "3/10")
- **Pause-Status:** Live Activity zeigt "Pausiert"
- **Ende:** Nach Workout-Ende oder Abbruch

### Streak-System
- **Workout-Streak:** Separate Streak (bereits vorhanden in `StreakManager`)
- **Eligibility:** Mindestens 2 Minuten Gesamtdauer (wie bei Meditation)
- **Update:** Nach erfolgreichem HealthKit-Logging

---

## 7. Technische Details

### Services/Dependencies
- **Timer-Engine:** Eigene Implementierung (NICHT `TwoPhaseTimerEngine`)
  - Grund: HIIT hat mehrere Phasen mit Wiederholungen (nicht nur 2 Phasen)
- **Audio:** Eigener `SoundPlayer` (bereits in WorkoutsView vorhanden)
  - AVAudioPlayer für Sounds
  - AVSpeechSynthesizer (optional, aktuell nicht genutzt)
- **HealthKitManager:** `logWorkout(start:end:activity:)`
- **LiveActivityController:** Shared service (Ownership-Model)
- **StreakManager:** Shared service

### State Management
- **Phase-State:** Enum `.work` / `.rest`
- **Timer-State:** Date-basierte Berechnungen (wie TwoPhaseTimerEngine)
  - Grund: Überleben von kurzen Background-Events
- **Pause-State:** Akkumulierte Pause-Zeit
- **Scheduling:** DispatchWorkItem für geplante Sounds (cancellable)

### Edge Cases
1. **User ändert Wiederholungen während Workout:**
   - Aktuelle Implementierung: `repeats` ist `@Binding` (kann sich ändern)
   - **Empfehlung:** Wert beim Start einfrieren (`cfgRepeats`)

2. **Sehr kurze Phasen (<3s):**
   - Countdown-Transition könnte mit Phase-Ende überlappen
   - **Lösung:** Countdown nur schedulen wenn `phaseDuration > 3.5s`

3. **Pause während Countdown:**
   - **Lösung:** Alle geplanten Sounds canceln, bei Resume neu schedulen

4. **Auftakt länger als Erholungsphase:**
   - **Lösung:** Check `if aDur < restDuration` → nur dann schedulen

5. **App-Termination:**
   - **Verhalten:** Timer stoppt (wie Offen-Tab)
   - Optional: Notification als Backup (nicht Teil dieser Spec)

---

## 8. UI-Komponenten Wiederverwendung

### Bestehende Komponenten
- **`CircularRing.swift`** – Doppelter Ring für Fortschritt
- **`GlassCard.swift`** – Card-Container für Picker-Sektion
- **`Colors.swift`** – `workoutViolet` für Farbkonsistenz
- **`SettingsSheet.swift`** – Shared settings
- **`CalendarView.swift`** – Activity calendar (zeigt Workout-Tage)

### Layout-Vorbild
- **Picker-Sektion:** 1:1 wie `OffenView` (3 Wheels statt 2)
- **Runner-View:** 1:1 wie `OffenView` (Overlay mit Doppel-Ring)
- **Buttons:** Konsistente Größen/Styles mit restlicher App

---

## 9. Testing-Anforderungen

### Unit Tests (falls gewünscht)
- Timer-State-Machine (Phase-Transitions)
- Pause/Resume-Akkumulation
- Sound-Scheduling-Logik
- Gesamtdauer-Berechnung

### Device Testing (von Henning)
**Muss getestet werden:**
1. **Normale Durchläufe:**
   - 3 Runden, 10s Belastung, 5s Erholung
   - Verify: Sounds zur richtigen Zeit
   - Verify: Ringe aktualisieren sich korrekt

2. **Pause/Resume:**
   - Pause während Belastung → Resume
   - Pause während Erholung → Resume
   - Verify: Sounds schedulen sich neu

3. **Abbruch:**
   - X-Button während Belastung
   - X-Button während Erholung
   - Verify: HealthKit logged partial workout

4. **Edge Cases:**
   - Sehr kurze Phasen (5s Belastung, 3s Erholung)
   - Lange Phasen (120s Belastung, 60s Erholung)
   - Keine Erholung (0s Rest)

5. **Background:**
   - App in Background während Workout
   - Zurück zum Foreground
   - Verify: Timer korrekt, Live Activity aktuell

6. **Live Activity:**
   - Verify: Dynamic Island zeigt Phase-Icon
   - Verify: Countdown korrekt
   - Verify: Pause-Status sichtbar

---

## 10. Offene Fragen / Zukünftige Erweiterungen

### Nicht Teil dieser Spec
- [ ] Presets (z.B. "Tabata", "EMOM") – könnte später wie AtemView hinzugefügt werden
- [ ] Anpassbare Warmup/Cooldown-Phasen
- [ ] Sprachauswahl für Ansagen (aktuell nur Deutsch)
- [ ] Vibration/Haptics bei Phasenwechseln
- [ ] Background-Notifications (aktuell nicht geplant)

### Bestätigt: Nicht gewünscht
- ❌ Text-to-Speech für "3-2-1" (countdown-transition übernimmt das)
- ❌ Mehrere Sounds pro Phasenwechsel (ein Sound reicht)

---

## 11. Implementierungs-Hinweise

### Branch-Strategie
- **Neuer Branch** für alternative Implementierung
- Grund: Bestehende Implementierung hat Probleme, Clean-Slate-Ansatz

### UI-Constraint: Keine visuellen Änderungen

**⚠️ WICHTIG: UI darf sich NICHT verändern!**

Das Problem liegt im **Timing-System**, nicht im UI. Daher:

- ✅ **Haupt-UI (WorkoutsView):** Layout, Farben, Icons, Buttons bleiben identisch
- ✅ **Runner-View:** Doppelter Ring, Icons, Fortschrittsanzeigen bleiben identisch
- ✅ **Dynamic Island (expanded):** Aktuelles Design beibehalten
- ✅ **Lock Screen / Live Activity:** Aktuelles Layout beibehalten
- ✅ **Animationen:** Bestehende Transitions beibehalten

**Was sich ändern darf:**
- ⚙️ **Timing-Logik:** Komplett neu (Continuous Monitoring statt Drift-Offset)
- ⚙️ **Audio-Scheduling:** Separater Timer statt UI-gebunden
- ⚙️ **Phase-State-Management:** Verbessert, aber kein UI-Impact

**Ziel:**
- User sieht **keinen visuellen Unterschied**
- User erlebt **präziseres Timing** (Sound-Cues zur richtigen Zeit)

---

### Scoping
- **Ziel:** Max 4-5 Dateien ändern
- **Dateien:**
  1. `WorkoutsView.swift` (Timing-Logik neu, UI-Layout identisch)
  2. ggf. neue Engine-Datei (z.B. `WorkoutTimerEngine.swift` in `/Services/`)
  3. ggf. neue Audio-Klasse (oder in WorkoutsView behalten)
  4. `Colors.swift` (nur lesen, nicht ändern)
  5. `CLAUDE.md` / `DOCS/` (Dokumentation updaten)

### Qualitäts-Kriterien (DoD)
- ✅ Build erfolgreich (xcodebuild)
- ✅ Tests grün (falls Unit Tests geschrieben)
- ✅ Code formatiert (konsistent mit Projekt)
- ✅ Jeder Commit compiliert
- ✅ Test-Anweisungen für Henning
- ✅ Dokumentation aktualisiert

---

## 12. Timing-System: Learnings & Best Practices

### Problem: countdown-transition Timing

**Herausforderung:**
Der `countdown-transition` Sound muss **exakt 3 Sekunden vor Ende der Belastungsphase** starten. Bisherige Implementierungen hatten massive Timing-Probleme.

### ❌ Fehlgeschlagene Ansätze (NICHT verwenden!)

#### 1. Prozentualer Drift-Offset (AKTUELL IM CODE)
```swift
// ❌ NICHT SO MACHEN
let estimatedDrift = Double(dur) * 0.015  // 1.5% per second
let targetFromStart = Double(dur) - 3.0 - estimatedDrift
let delay = targetFromStart - elapsed
scheduleCountdown(delay) { sounds.play(.countdownTransition) }
```

**Warum das nicht funktioniert:**
- **Falsche Annahme:** Drift ist NICHT proportional zur Phase-Dauer
- **Unpräzise:** Heuristik basiert auf Beobachtung, nicht auf System-Verhalten
- **Nicht deterministisch:** Variiert je nach System-Last, Frame-Rate, Gerät
- **Schwer zu debuggen:** Magic Numbers, keine klare Logik
- **Fragil:** Funktioniert nur unter bestimmten Bedingungen

#### 2. One-Time Scheduling beim Phase-Start
```swift
// ❌ NICHT SO MACHEN
func setPhase(_ p: WorkoutPhase) {
    phaseStart = Date()
    let delay = phaseDuration - 3.0
    schedule(delay) { sounds.play(.countdownTransition) }
}
```

**Warum das nicht funktioniert:**
- **Keine Korrektur möglich:** Wenn Scheduling falsch ist, kein Fallback
- **Ignoriert Pause/Resume:** Bei Pause werden Sounds gecancelt, aber nicht neu berechnet
- **UI-gekoppelt:** `onChange(of: fractionPhase)` hat intrinsische Verzögerung
- **Hardcoded "3.0":** Sound-Dauer sollte dynamisch gemessen werden

#### 3. UI-gebundener Timer für Sounds
```swift
// ❌ NICHT SO MACHEN
TimelineView(.animation) { ctx in
    let progress = /* ... berechnung ... */
    // Versuche Sound basierend auf progress zu triggern
}
.onChange(of: progress) { newVal in
    if newVal >= threshold { sounds.play() }
}
```

**Warum das nicht funktioniert:**
- **onChange-Latenz:** SwiftUI's `onChange` feuert NICHT sofort
- **Frame-abhängig:** Abhängig von Rendering-Zyklen (nicht präzise genug)
- **Doppeltes Abspielen:** Ohne Flag-System wird Sound mehrfach getriggert

---

### ✅ Best Practice: Continuous Monitoring mit separatem Timer

**Empfohlener Ansatz:**

```swift
// ✅ SO MACHEN

// 1. Separater Timer (unabhängig von UI-Rendering)
private var soundCheckTimer: Timer?

func startPhase(_ phase: WorkoutPhase, duration: TimeInterval) {
    phaseStart = Date()
    phaseDuration = duration
    soundTriggered = false  // Reset flag

    // Messe Sound-Dauer dynamisch
    let soundDuration = sounds.duration(of: .countdownTransition)
    let triggerThreshold = soundDuration + 0.05  // 50ms buffer

    // Starte Monitoring-Timer (alle 0.1s)
    soundCheckTimer?.invalidate()
    soundCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
        guard let self = self else { return }

        let now = Date()
        let elapsed = now.timeIntervalSince(self.phaseStart) - pausedPhaseAccum
        let remaining = self.phaseDuration - elapsed

        // Trigger Sound wenn verbleibende Zeit <= Sound-Dauer + Buffer
        if !self.soundTriggered && remaining <= triggerThreshold && remaining > 0 {
            self.soundTriggered = true
            self.sounds.play(.countdownTransition)
            print("[Workout] countdown-transition triggered (remaining: \(remaining)s)")
        }
    }
}

func stopPhase() {
    soundCheckTimer?.invalidate()
    soundCheckTimer = nil
}
```

**Warum das funktioniert:**
- ✅ **Kontinuierliches Monitoring:** Prüft alle 0.1s → hohe Präzision
- ✅ **Selbstkorrigierend:** Wenn eine Iteration verpasst wird, nächste greift
- ✅ **Unabhängig von UI:** Nicht an SwiftUI-Rendering gekoppelt
- ✅ **Flag-basiert:** Verhindert doppeltes Abspielen
- ✅ **Dynamisch:** Verwendet echte Sound-Dauer (nicht hardcoded)
- ✅ **Einfach:** Klare Logik, leicht zu verstehen und zu debuggen
- ✅ **Robust:** Funktioniert bei verschiedenen Phase-Dauern

---

### Alternative: DispatchSourceTimer (noch präziser)

Für maximale Präzision:

```swift
// ✅ AUCH GUT: DispatchSourceTimer für sub-100ms Präzision

private var soundCheckTimer: DispatchSourceTimer?

func startPhase(_ phase: WorkoutPhase, duration: TimeInterval) {
    phaseStart = Date()
    phaseDuration = duration
    soundTriggered = false

    let queue = DispatchQueue(label: "workout.soundcheck", qos: .userInteractive)
    soundCheckTimer?.cancel()
    soundCheckTimer = DispatchSource.makeTimerSource(queue: queue)

    soundCheckTimer?.schedule(deadline: .now(), repeating: .milliseconds(100))
    soundCheckTimer?.setEventHandler { [weak self] in
        guard let self = self else { return }

        let now = Date()
        let elapsed = now.timeIntervalSince(self.phaseStart) - self.pausedPhaseAccum
        let remaining = self.phaseDuration - elapsed
        let threshold = self.sounds.duration(of: .countdownTransition) + 0.05

        if !self.soundTriggered && remaining <= threshold && remaining > 0 {
            DispatchQueue.main.async {
                self.soundTriggered = true
                self.sounds.play(.countdownTransition)
            }
        }
    }
    soundCheckTimer?.resume()
}
```

---

### Implementierungs-Checklist

**Must-Have:**
- [ ] Separater Timer für Sound-Monitoring (NICHT UI-gebunden)
- [ ] Sound-Dauer dynamisch messen (`sounds.duration(of: .countdownTransition)`)
- [ ] Flag-basiertes System (`soundTriggered`) gegen doppeltes Abspielen
- [ ] Kleiner Buffer (50-100ms) für Scheduling-Sicherheit
- [ ] Timer bei Pause invalidieren, bei Resume neu starten

**Must-NOT:**
- [ ] ❌ KEINE prozentualen Drift-Offsets
- [ ] ❌ KEINE One-Time Scheduling beim Phase-Start
- [ ] ❌ KEINE UI-gebundenen Trigger (`onChange` für Sounds)
- [ ] ❌ KEINE hardcoded "3.0" Sound-Dauer

---

### Testing: Timing-Präzision prüfen

**Zu testen (von Henning auf Device):**

1. **Verschiedene Belastungs-Dauern:**
   - 10s, 20s, 30s, 60s, 120s
   - Verify: countdown-transition startet konsistent ~3s vor Ende

2. **Mit Stoppuhr messen:**
   - Countdown-Sound startet → Stoppuhr starten
   - Phase endet → Stoppuhr stoppen
   - Erwartung: 3.0s ± 0.2s

3. **Pause während Countdown:**
   - Belastung läuft
   - 2s vor Ende → Pause drücken
   - Verify: Sound stoppt
   - Resume → Sound sollte sofort abspielen (wenn <3s verbleibend)

4. **Mehrere Runden hintereinander:**
   - 10 Runden durchlaufen
   - Verify: Jeder Countdown ist präzise (kein Drift über Zeit)

---

## 13. Sound-Dateien Checkliste

**Benötigte Dateien (müssen im Bundle vorhanden sein):**
- [x] `auftakt` (.caff/.caf/.wav/.mp3/.aiff)
- [x] `countdown-transition` (.caff/.caf/.wav/.mp3/.aiff)
- [x] `ausklang` (.caff/.caf/.wav/.mp3/.aiff)
- [x] `round-2.caff` bis `round-20.caff` (19 Dateien)
- [x] `last-round` (.caff/.caf/.wav/.mp3/.aiff)

**Nicht benötigt:**
- ❌ `round-1` (erste Runde wird nicht angesagt)
- ❌ Separate "3", "2", "1" Dateien (countdown-transition ist kombiniert)

---

**Ende der Spezifikation**
