# Workout-Programme Feature - Vollständige Spezifikation

**Version:** 1.0
**Datum:** 2025-01-04
**Autor:** Claude Code (mit Henning)
**Status:** Ready for Implementation

---

## 1. Executive Summary

### Feature-Typ
**Primary Feature** – Prominent in der Tab-Bar, Hauptfunktion der App

### Kategorie
Fitness / Training (HIIT, Calisthenics, Stretching)

### Problem Statement
**Aktuell:** Der "Workouts"-Tab bietet nur homogene Intervalle (X Sekunden Belastung, Y Sekunden Pause, Z Wiederholungen). Für strukturierte Trainingsprogramme mit unterschiedlichen Übungen muss der User:
- Den Ablauf im Kopf behalten
- Jedes Mal die Zeiten neu einstellen
- Keine wissenschaftlich fundierten Vorlagen nutzen

**Lösung:** Preset-basierte Workout-Sets mit:
- Benannten Phasen (z.B. "Planke", "Diamond-Liegestütze")
- Flexiblen Dauern pro Phase (Phase 1: 45s/15s, Phase 2: 30s/10s, ...)
- Set-Wiederholungen (z.B. 3 Runden durch das ganze Programm)
- 10 wissenschaftlich fundierten Default-Presets
- Custom-Sets mit Editor

---

## 2. Naming & Navigation

### Tab-Umbenennung
- **Aktueller "Workouts"-Tab** → **"Frei"** (freie Workouts mit 3 Wheels: Belastung/Erholung/Wiederholungen)
- **Neuer Tab** → **"Workouts"** (Preset-basierte Programme)

### Tab-Reihenfolge
```
Offen | Atem | Frei | Workouts
```

### Begründung
- **"Frei"** = analoger Name zu "Offen" (Meditation) → konsistente Nomenklatur
- **"Workouts"** = etablierter Begriff für strukturierte Trainingsprogramme
- Zwei Tabs mit "Offen" würde Verwirrung stiften

---

## 3. Datenmodell

### 3.1 WorkoutSet (analog zu Atem `Preset`)

```swift
struct WorkoutSet: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String                 // "Core Circuit"
    var emoji: String                // "💪"
    var phases: [WorkoutPhase]       // Array von Übungsphasen
    var repetitions: Int             // Wie oft das ganze Set durchlaufen wird (1-99)
    var description: String?         // Wissenschaftliche Begründung (optional)

    // Computed Properties
    var totalSeconds: Int {
        let singleRound = phases.reduce(0) { $0 + $1.workDuration + $1.restDuration }
        return singleRound * max(1, repetitions)
    }

    var totalDurationString: String {
        let s = totalSeconds
        let m = s / 60, r = s % 60
        return String(format: "%d:%02d min", m, r)
    }

    var phaseCount: Int {
        phases.count
    }
}
```

### 3.2 WorkoutPhase (neue Struktur)

```swift
struct WorkoutPhase: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String            // "Diamond-Liegestütze", "Planke", etc.
    var workDuration: Int       // Sekunden Belastung (1-600)
    var restDuration: Int       // Sekunden Pause (0-600)
                                // WICHTIG: Letzte Phase im Set hat immer restDuration = 0
}
```

### 3.3 Beispiel-Datenstruktur

```swift
WorkoutSet(
    id: UUID(),
    name: "Core Circuit",
    emoji: "💪",
    phases: [
        WorkoutPhase(id: UUID(), name: "Planke", workDuration: 45, restDuration: 15),
        WorkoutPhase(id: UUID(), name: "Seitliche Planke links", workDuration: 30, restDuration: 15),
        WorkoutPhase(id: UUID(), name: "Seitliche Planke rechts", workDuration: 30, restDuration: 15),
        WorkoutPhase(id: UUID(), name: "Fahrrad-Crunches", workDuration: 40, restDuration: 15),
        WorkoutPhase(id: UUID(), name: "Beinheben", workDuration: 30, restDuration: 15),
        WorkoutPhase(id: UUID(), name: "Russian Twists", workDuration: 40, restDuration: 0) // Letzte Phase!
    ],
    repetitions: 3,
    description: "Fokussiert auf Core-Stabilität und Rotationskraft. Kombiniert isometrische und dynamische Übungen für ganzheitliche Rumpfstärkung."
)
```

**Gesamtdauer:** (45+15 + 30+15 + 30+15 + 40+15 + 30+15 + 40+0) × 3 = 280s × 3 = 840s = 14:00 min

---

## 4. UI-Design & Flows

### 4.1 Hauptansicht (Liste der Sets)

**Layout:** 1:1 wie AtemView (GlassCards mit Emoji, Name, Details, Play-Button)

```
┌─────────────────────────────────────┐
│ 💪  Core Circuit           [▶️]     │
│                                      │
│ 6 Übungen · 3 Runden · ≈ 14:00 min  │
│                             [ℹ️] [⋯] │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│ 🔥  Tabata Classic         [▶️]     │
│ 8 Übungen · 1 Runde · ≈ 4:00 min    │
│                             [ℹ️] [⋯] │
└─────────────────────────────────────┘
...
┌─────────────────────────────────────┐
│         [➕ Set hinzufügen]          │
└─────────────────────────────────────┘
```

**Details-Zeile:**
- **Anzahl Phasen:** `6 Übungen`
- **Repetitions:** `3 Runden` (bei 1 Runde: nur "8 Übungen")
- **Gesamtdauer:** `≈ 14:00 min`

**Buttons:**
- **ℹ️ Info:** Sheet mit Beschreibung + empfohlener Anwendung (wie Atem PresetInfoSheet)
- **⋯ Edit:** Öffnet Set-Editor
- **▶️ Play:** Startet Workout (öffnet Session-Runner Overlay)

**Interaktionen:**
- **Swipe-to-delete:** Löscht custom Sets (Default-Presets können nur "zurückgesetzt" werden via Migration)
- **Drag-to-reorder:** Optional (V2)

---

### 4.2 Set-Editor (Erstellen/Bearbeiten)

**Layout:** Liste mit Drag & Drop (iOS 26 Liquid Glass Style)

```
┌────────────── SET DETAILS ────────────────┐
│ Icon:                                      │
│ [🧘][🪷][🌬️][💪][🔥][⚡][🏃][🦵][🌱]...    │
│ (horizontal scroll)                        │
│                                            │
│ Name:                                      │
│ [Core Circuit__________________]           │
│                                            │
│ Runden:                                    │
│ [Picker: 1-99] → aktuell: 3                │
│                                            │
│ Gesamtdauer: ≈ 14:00 min                   │
└───────────────────────────────────────────┘

┌────────────── PHASEN ─────────────────────┐
│ ┌──── Phase 1 ────┐                       │
│ │ [≡] Planke                  [⋯]         │
│ │     45s Belastung · 15s Pause           │
│ └─────────────────┘                       │
│ ┌──── Phase 2 ────┐                       │
│ │ [≡] Seitliche Planke links  [⋯]         │
│ │     30s Belastung · 15s Pause           │
│ └─────────────────┘                       │
│ ┌──── Phase 3 ────┐                       │
│ │ [≡] Seitliche Planke rechts [⋯]         │
│ │     30s Belastung · 15s Pause           │
│ └─────────────────┘                       │
│ ...                                        │
│                                            │
│ [+ Phase hinzufügen]                       │
└───────────────────────────────────────────┘

[Löschen] (nur bei existierendem Set, nicht bei "Neu")
```

**Interaktionen:**
- **[≡] Drag Handle:** Phasen per Drag & Drop umordnen (iOS List + `.onMove`)
- **[⋯] Button:** Öffnet Phasen-Detail-Editor (Sheet)
- **[+ Phase hinzufügen]:**
  - Fügt neue Phase ans Ende
  - Übernimmt `workDuration` und `restDuration` der letzten Phase als Vorschlag
  - Öffnet sofort Phasen-Editor

**Validation:**
- Name darf nicht leer sein
- Mindestens 1 Phase erforderlich
- Letzte Phase bekommt automatisch `restDuration = 0` (logisch, da Set endet)

---

### 4.3 Phasen-Editor (Detail-Sheet für eine Phase)

```
┌────────────────────────────────────────┐
│         PHASE BEARBEITEN                │
├────────────────────────────────────────┤
│ Name:                                   │
│ [Planke                    ▼] (Dropdown)│
│  ↳ Vorschläge (60+ Übungen):            │
│    - Planke                             │
│    - Seitliche Planke links             │
│    - Diamond-Liegestütze                │
│    - Burpees                            │
│    - ...                                │
│    - [Eigener Name...]                  │
│                                         │
│ Belastung: [45] Sekunden (Wheel Picker) │
│ Pause:     [15] Sekunden (Wheel Picker) │
│                                         │
│ [Speichern]                             │
└────────────────────────────────────────┘
```

**Vorschlagsliste (Dropdown/Picker):**
- Kategorisiert nach Typ (optional: Sections in Picker)
- 60+ Übungen (siehe Anhang A)
- Option "Eigener Name..." → öffnet TextField

**Wheel Picker:**
- **Belastung:** 1-600 Sekunden (wie aktueller Workout-Tab)
- **Pause:** 0-600 Sekunden (0 = keine Pause)

---

### 4.4 Workout-Runner (Session Overlay)

**Ähnlich wie aktueller WorkoutRunnerView, aber mit Erweiterungen:**

#### Display während Session

```
┌────────────────────────────────────┐
│         Core Circuit               │
│                                    │
│   ┌──────────────────┐             │
│   │                  │             │
│   │   Dual Rings     │  ← Outer: Gesamt-Progress (14 min)
│   │                  │     Inner: Phase-Progress (45s)
│   │   [🔥 Planke]    │  ← Icon + Phase-Name
│   │                  │             │
│   └──────────────────┘             │
│                                    │
│ Runde 1/3 · Phase 1/6 · Belastung │
│                                    │
│         [Pause]                    │
│                                    │
│         [×]  (oben rechts)         │
└────────────────────────────────────┘
```

**Anzeige-Elemente:**
- **Set-Name:** "Core Circuit" (oben)
- **Dual-Ring:**
  - **Outer Ring:** Gesamt-Fortschritt (continuous, 0→1 über gesamte Session)
  - **Inner Ring:** Phase-Fortschritt (resets bei jedem Phasenwechsel)
- **Icon + Phase-Name:** Aktuell: "🔥 Planke" (während Belastung), "⏸️ Pause" (während Rest)
- **Status-Zeile:** "Runde 1/3 · Phase 1/6 · Belastung"
- **Buttons:**
  - **[Pause]** / **[Weiter]** (Toggle, wie aktuell)
  - **[×]** (oben rechts, beendet Session mit Abfrage)

#### Phase-Wechsel-Logik

**Belastungsphase → Pause:**
1. **3s vor Ende:** Countdown-Sound `countdown-transition` (3-2-1 Beeps + Ton)
2. **Bei 0s:** Wechsel zu Pause-Phase
3. **Icon wechselt:** 🔥 → ⏸️
4. **LiveActivity Update:** Phase-Name = "Pause"

**Pause → Nächste Belastungsphase:**
1. **3s vor Ende der Pause:** `auftakt` Sound (Pre-Roll, damit Sound genau bei Phase-Start endet)
2. **Bei 0s:** Wechsel zur nächsten Belastungsphase
3. **Icon wechselt:** ⏸️ → 🔥
4. **Phase-Name aktualisieren:** "Seitliche Planke links"
5. **LiveActivity Update**

**Rundenübergang:**
- Nach letzter Phase (Rest = 0s) → Prüfen: `currentRound < repetitions`?
- **Ja:** Runde erhöhen, zurück zu Phase 1, `auftakt` Sound
- **Nein:** Session beendet, `ausklang` Sound

#### Completion-Flow

```
┌────────────────────────────────────┐
│         Core Circuit               │
│                                    │
│   ┌──────────────────┐             │
│   │                  │             │
│   │  ✅ Fertig!      │             │
│   │                  │             │
│   └──────────────────┘             │
│                                    │
│ 3 Runden abgeschlossen             │
│ 14:00 min · 168 kcal               │
│                                    │
│         [Fertig]                   │
└────────────────────────────────────┘
```

**Nach letzter Phase:**
1. `ausklang` Sound abspielen
2. HealthKit Logging (HIIT Workout + Kalorien)
3. LiveActivity beenden
4. Fertig-Screen anzeigen (0.5s delay)
5. Button "Fertig" → schließt Overlay

---

## 5. Audio-System

### 5.1 Sounds (wiederverwenden von aktuellem SoundPlayer in WorkoutsView)

**Verfügbare Sounds:**
- **`auftakt.caf`** – Pre-start Cue (vor erster Phase, vor Pausen-Ende als Pre-Roll)
- **`countdown-transition.caf`** – 3-2-1 Beeps + langer Ton (3s vor Ende jeder Belastungsphase)
- **`ausklang.caf`** – Final Chime (nach letzter Phase)
- **`last-round.caf`** – "Letzte Runde" Ansage

**Zusätzlich:**
- **`round-1.caf` bis `round-20.caf`** – Runden-Ansagen (bereits vorhanden!)

### 5.2 TTS (AVSpeechSynthesizer)

**Nur für Runden-Ansagen:**
- "Runde 2" (vor Start von Runde 2)
- "Runde 3" (vor Start von Runde 3)
- "Letzte Runde" (vor letzter Runde)

**NICHT für Phase-Namen:**
- Phase-Namen werden NICHT gesprochen
- Nur visuell im Display + LiveActivity angezeigt

**Begründung:** TTS ist in iOS verfügbar (bereits verwendet in WorkoutsView für Runden-Ansagen)

### 5.3 Timing (wie aktueller WorkoutRunnerView)

**Belastungsphase (Work):**
```
Start → ... → (3s vor Ende) countdown-transition → Ende → Pause
```

**Pause-Phase (Rest):**
```
Start → ... → (3s vor Ende) auftakt (Pre-Roll) → Ende → Nächste Phase
```

**Rundenübergang:**
```
Letzte Phase endet → (Pause) → TTS: "Runde X" → auftakt → Phase 1
```

**Session-Ende:**
```
Letzte Phase der letzten Runde → ausklang → Fertig-Screen
```

---

## 6. LiveActivity Integration

### 6.1 Display in Dynamic Island / Lock Screen

**Compact View:**
```
┌──────────────────────────────────────┐
│ 💪 Core Circuit                      │
│ ──────●─────────────── 45% (6:18)    │
│ 🔥 Planke · Runde 1/3                │
└──────────────────────────────────────┘
```

**Expanded View:**
```
┌──────────────────────────────────────┐
│ 💪 Core Circuit                      │
│                                      │
│ 🔥 Planke                            │
│ Phase 1/6 · Runde 1/3                │
│                                      │
│ ──────────●──────────── 45% (6:18)   │
│                                      │
│ [Pause]              [Beenden]       │
└──────────────────────────────────────┘
```

### 6.2 Update-Trigger

**LiveActivity.requestStart() bei Session-Start:**
```swift
let endDate = sessionStart.addingTimeInterval(TimeInterval(totalSeconds))
liveActivity.requestStart(
    title: "\(set.emoji) \(set.name)",  // "💪 Core Circuit"
    phase: 1,                            // Work = 1, Rest = 2
    endDate: endDate,
    ownerId: "WorkoutsTab"
)
```

**LiveActivity.update() bei jedem Phasenwechsel:**
```swift
await liveActivity.update(
    phase: currentPhase == .work ? 1 : 2,
    endDate: updatedEndDate,  // Angepasst durch Pausen-Akkumulation
    isPaused: isPaused
)
```

**Custom Attribute für Phase-Name (optional, V2):**
- LiveActivity könnte `contentState` erweitern um `phaseName: String`
- Dann in Widget: `"🔥 Planke"` anzeigen

### 6.3 Apple Watch Sichtbarkeit

✅ LiveActivities werden automatisch auf Apple Watch angezeigt (iOS 16.1+)
✅ Keine separate Watch App nötig (Out of Scope V1)

---

## 7. HealthKit Integration

### 7.1 Workout Logging

**Activity Type:**
```swift
HKWorkoutActivityType.highIntensityIntervalTraining
```

**Logging-Funktion (bereits in HealthKitManager implementiert!):**
```swift
try await HealthKitManager.shared.logWorkout(
    start: workoutStart,
    end: Date(),
    activity: .highIntensityIntervalTraining
)
```

### 7.2 Kalorien-Berechnung

**MET-basiert (bereits implementiert in HealthKitManager.swift:158-218):**
- **HIIT:** 12 kcal/min (MET = 8.0)
- **Formula:** `(MET × 3.5 × Gewicht in kg) / 200 × Minuten`

**Beispiel:** 14 min HIIT bei 75 kg → ~168 kcal

### 7.3 Health App Integration

**Was erscheint in Health App:**
- **Workout-Typ:** "High Intensity Interval Training"
- **Dauer:** 14:00 min
- **Kalorien:** ~168 kcal (Active Energy)
- **Quelle:** "Lean Health Timer"

**MOVE Ring:**
- Workout zählt zu "Exercise Minutes"
- Kalorien zählen zu "Active Calories"

### 7.4 Keine zusätzlichen Permissions nötig

✅ `HKQuantityType.workoutType()` bereits in Info.plist
✅ `HKQuantityType.activeEnergyBurned` bereits authorized
✅ Keine Code-Änderungen an HealthKitManager erforderlich

---

## 8. Default-Presets (10 wissenschaftlich fundierte Sets)

### Preset 1: Tabata Classic 🔥

```swift
WorkoutSet(
    name: "Tabata Classic",
    emoji: "🔥",
    phases: [
        WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
        WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
        WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
        WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
        WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
        WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
        WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
        WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 0),
    ],
    repetitions: 1,
    description: "Original Tabata-Protokoll (Izumi Tabata, 1996): 8 Runden à 20s maximale Intensität / 10s Pause. Nachweislich VO2max-Steigerung um bis zu 14% in 6 Wochen. Erfordert 170% VO2max Intensität."
)
```
**Gesamtdauer:** 4:00 min
**Wissenschaftliche Basis:** Tabata et al. (1996), Med Sci Sports Exerc

---

### Preset 2: Core Circuit 💪

```swift
WorkoutSet(
    name: "Core Circuit",
    emoji: "💪",
    phases: [
        WorkoutPhase(name: "Planke", workDuration: 45, restDuration: 15),
        WorkoutPhase(name: "Seitliche Planke links", workDuration: 30, restDuration: 15),
        WorkoutPhase(name: "Seitliche Planke rechts", workDuration: 30, restDuration: 15),
        WorkoutPhase(name: "Fahrrad-Crunches", workDuration: 40, restDuration: 15),
        WorkoutPhase(name: "Beinheben", workDuration: 30, restDuration: 15),
        WorkoutPhase(name: "Russian Twists", workDuration: 40, restDuration: 0),
    ],
    repetitions: 3,
    description: "Fokussiert auf Core-Stabilität und Rotationskraft. Kombiniert isometrische (Planken) und dynamische Übungen für ganzheitliche Rumpfstärkung. Verbessert Haltung und reduziert Rückenschmerzen."
)
```
**Gesamtdauer:** 14:00 min
**Wissenschaftliche Basis:** McGill et al. (2010), J Strength Cond Res

---

### Preset 3: Full Body Burn 🏃

```swift
WorkoutSet(
    name: "Full Body Burn",
    emoji: "🏃",
    phases: [
        WorkoutPhase(name: "Burpees", workDuration: 30, restDuration: 20),
        WorkoutPhase(name: "Kniebeugen", workDuration: 40, restDuration: 20),
        WorkoutPhase(name: "Liegestütze", workDuration: 30, restDuration: 20),
        WorkoutPhase(name: "Mountain Climbers", workDuration: 30, restDuration: 20),
        WorkoutPhase(name: "Ausfallschritte", workDuration: 40, restDuration: 20),
        WorkoutPhase(name: "Planke", workDuration: 45, restDuration: 0),
    ],
    repetitions: 3,
    description: "Ganzkörper-HIIT mit Fokus auf funktionelle Bewegungsmuster. Kombiniert Kraft, Cardio und Core-Stabilität. Maximale Kalorienverbrennung durch Einbindung großer Muskelgruppen."
)
```
**Gesamtdauer:** 15:45 min
**Kalorien:** ~190 kcal (75 kg)

---

### Preset 4: Power Intervals ⚡

```swift
WorkoutSet(
    name: "Power Intervals",
    emoji: "⚡",
    phases: [
        WorkoutPhase(name: "Jump-Kniebeugen", workDuration: 40, restDuration: 20),
        WorkoutPhase(name: "Burpees", workDuration: 40, restDuration: 20),
        WorkoutPhase(name: "High Knees", workDuration: 40, restDuration: 20),
        WorkoutPhase(name: "Mountain Climbers", workDuration: 40, restDuration: 20),
        WorkoutPhase(name: "Hampelmänner", workDuration: 40, restDuration: 0),
    ],
    repetitions: 4,
    description: "Explosive plyometrische Übungen zur Steigerung von Schnellkraft und anaerober Kapazität. Optimal für Fettverbrennung und kardiovaskuläre Fitness. EPOC-Effekt (Nachbrenneffekt) bis 24h."
)
```
**Gesamtdauer:** 16:00 min
**Wissenschaftliche Basis:** Laursen & Jenkins (2002), Sports Med

---

### Preset 5: Hintere Kette 🦵

```swift
WorkoutSet(
    name: "Hintere Kette",
    emoji: "🦵",
    phases: [
        WorkoutPhase(name: "Glute Bridges", workDuration: 45, restDuration: 15),
        WorkoutPhase(name: "Einbeiniges Kreuzheben", workDuration: 40, restDuration: 15),
        WorkoutPhase(name: "Bulgarische Split-Kniebeugen", workDuration: 40, restDuration: 15),
        WorkoutPhase(name: "Reverse-Ausfallschritte", workDuration: 40, restDuration: 15),
        WorkoutPhase(name: "Wadenheben", workDuration: 30, restDuration: 0),
    ],
    repetitions: 3,
    description: "Gezieltes Training der posterior chain (Gesäß, Hamstrings, unterer Rücken, Waden). Essentiell für Laufökonomie, Sprintgeschwindigkeit und Verletzungsprävention. Korrigiert Dysbalancen durch Sitzposition."
)
```
**Gesamtdauer:** 13:30 min
**Wissenschaftliche Basis:** Contreras et al. (2015), J Appl Biomech

---

### Preset 6: Jogging Warm-up 🏃‍♀️

```swift
WorkoutSet(
    name: "Jogging Warm-up",
    emoji: "🏃‍♀️",
    phases: [
        WorkoutPhase(name: "High Knees", workDuration: 30, restDuration: 10),
        WorkoutPhase(name: "Butt Kicks", workDuration: 30, restDuration: 10),
        WorkoutPhase(name: "Beinpendel", workDuration: 30, restDuration: 10),
        WorkoutPhase(name: "Ausfallschritte gehend", workDuration: 40, restDuration: 10),
        WorkoutPhase(name: "Hüftkreisen", workDuration: 30, restDuration: 0),
    ],
    repetitions: 2,
    description: "Dynamisches Aufwärmen für Läufer. Aktiviert Hüftmuskulatur, erhöht Bewegungsumfang und bereitet den Körper auf Laufbelastung vor. Reduziert Verletzungsrisiko um bis zu 35%."
)
```
**Gesamtdauer:** 6:40 min
**Wissenschaftliche Basis:** Woods et al. (2007), Br J Sports Med

---

### Preset 7: Post-Run Stretching 🧘‍♂️

```swift
WorkoutSet(
    name: "Post-Run Stretching",
    emoji: "🧘‍♂️",
    phases: [
        WorkoutPhase(name: "Quadrizeps-Dehnung", workDuration: 45, restDuration: 10),
        WorkoutPhase(name: "Hamstring-Dehnung", workDuration: 45, restDuration: 10),
        WorkoutPhase(name: "Hüftbeuger-Dehnung", workDuration: 45, restDuration: 10),
        WorkoutPhase(name: "Waden-Dehnung", workDuration: 45, restDuration: 10),
        WorkoutPhase(name: "Schmetterlings-Dehnung", workDuration: 60, restDuration: 10),
        WorkoutPhase(name: "Kindspose", workDuration: 60, restDuration: 0),
    ],
    repetitions: 1,
    description: "Statisches Stretching zur Regeneration nach dem Laufen. Fokus auf Hüft- und Beinmuskulatur. Reduziert Muskelkater (DOMS), verbessert Beweglichkeit und fördert Durchblutung. Mindestens 30s pro Stretch halten."
)
```
**Gesamtdauer:** 7:30 min
**Wissenschaftliche Basis:** Herbert et al. (2011), Cochrane Database Syst Rev

---

### Preset 8: Beginner Flow 🌱

```swift
WorkoutSet(
    name: "Beginner Flow",
    emoji: "🌱",
    phases: [
        WorkoutPhase(name: "Marschieren auf der Stelle", workDuration: 40, restDuration: 20),
        WorkoutPhase(name: "Wandliegestütze", workDuration: 30, restDuration: 20),
        WorkoutPhase(name: "Kniebeugen", workDuration: 30, restDuration: 20),
        WorkoutPhase(name: "Planke (Knie)", workDuration: 30, restDuration: 20),
        WorkoutPhase(name: "Knieheben stehend", workDuration: 30, restDuration: 0),
    ],
    repetitions: 2,
    description: "Sanfter Einstieg ins HIIT-Training. Gelenkschonende Varianten mit längeren Pausen (1:1 Ratio). Ideal zum Aufbau von Grundfitness und Technik. Progressiv steigerbar durch mehr Runden oder kürzere Pausen."
)
```
**Gesamtdauer:** 6:40 min
**Zielgruppe:** Einsteiger, Reha, Ältere

---

### Preset 9: Quick Burn 🔥

```swift
WorkoutSet(
    name: "Quick Burn",
    emoji: "🔥",
    phases: [
        WorkoutPhase(name: "Burpees", workDuration: 30, restDuration: 15),
        WorkoutPhase(name: "Mountain Climbers", workDuration: 30, restDuration: 15),
        WorkoutPhase(name: "Hampelmänner", workDuration: 30, restDuration: 15),
        WorkoutPhase(name: "Planke", workDuration: 30, restDuration: 0),
    ],
    repetitions: 3,
    description: "Kompaktes 6-Minuten-Workout für maximale Effizienz. Kombiniert Cardio und Core für schnelle Kalorienverbrennung. Perfekt für zeitknappe Tage oder als Finisher nach Krafttraining."
)
```
**Gesamtdauer:** 6:00 min
**Kalorien:** ~72 kcal (75 kg)

---

### Preset 10: Upper Body Push 💪

```swift
WorkoutSet(
    name: "Upper Body Push",
    emoji: "💪",
    phases: [
        WorkoutPhase(name: "Liegestütze", workDuration: 40, restDuration: 20),
        WorkoutPhase(name: "Diamond-Liegestütze", workDuration: 30, restDuration: 20),
        WorkoutPhase(name: "Breite Liegestütze", workDuration: 30, restDuration: 20),
        WorkoutPhase(name: "Pike-Liegestütze", workDuration: 30, restDuration: 20),
        WorkoutPhase(name: "Planke zu Herabschauender Hund", workDuration: 30, restDuration: 0),
    ],
    repetitions: 3,
    description: "Fokussiertes Training der Druckmuskulatur (Brust, Trizeps, Schultern). Progression durch Push-up-Varianten mit unterschiedlichen Schwerpunkten. Ergänzt Pull-Training für ausgewogene Oberkörperentwicklung."
)
```
**Gesamtdauer:** 12:00 min
**Muskelgruppen:** Pectoralis, Trizeps, Deltoideus (anterior)

---

## 9. Übungs-Vorschlagsliste (60+ Übungen, deutsch/englisch)

**Verwendung:** Dropdown/Picker im Phasen-Editor

```swift
private static let exerciseSuggestions: [String] = [
    // Core
    "Planke",
    "Seitliche Planke links",
    "Seitliche Planke rechts",
    "Hollow Hold",
    "Dead Bug",
    "Fahrrad-Crunches",
    "Russian Twists",
    "Beinheben",
    "Flutter Kicks",
    "Mountain Climbers",
    "V-Ups",
    "Sit-ups",
    "Crunches",
    "Planke zu Herabschauender Hund",

    // Push (Oberkörper drückend)
    "Liegestütze",
    "Diamond-Liegestütze",
    "Breite Liegestütze",
    "Pike-Liegestütze",
    "Archer-Liegestütze",
    "Decline-Liegestütze",
    "Wandliegestütze",
    "Dips",

    // Pull (Oberkörper ziehend)
    "Klimmzüge",
    "Chin-ups",
    "Australian Pull-ups",
    "Inverted Rows",

    // Legs (Beine)
    "Kniebeugen",
    "Jump-Kniebeugen",
    "Ausfallschritte",
    "Reverse-Ausfallschritte",
    "Ausfallschritte gehend",
    "Bulgarische Split-Kniebeugen",
    "Einbeiniges Kreuzheben",
    "Wadenheben",
    "Glute Bridges",
    "Step-ups",
    "Wall-Sit",
    "Knieheben stehend",

    // Cardio / Full Body
    "Burpees",
    "Hampelmänner",
    "High Knees",
    "Butt Kicks",
    "Box Jumps",
    "Skater Hops",
    "Jumping Jacks",
    "Bergsteiger",
    "Seilspringen",
    "Marschieren auf der Stelle",

    // Stretching
    "Herabschauender Hund",
    "Kindspose",
    "Kobra-Dehnung",
    "Katze-Kuh",
    "Vorbeuge im Sitzen",
    "Schmetterlings-Dehnung",
    "Hüftbeuger-Dehnung",
    "Quadrizeps-Dehnung",
    "Hamstring-Dehnung",
    "Waden-Dehnung",
    "Schulter-Dehnung",
    "Beinpendel",
    "Hüftkreisen",

    // Eigener Name (Option im Picker)
    "[Eigener Name...]"
].sorted()
```

**Sprachliche Regel:**
- Deutsch wo etabliert: "Kniebeugen", "Liegestütze", "Planke", "Ausfallschritte"
- Englisch wo kein deutscher Standard: "Burpees", "Mountain Climbers", "High Knees", "Dead Bug"
- Hybrid OK: "Jump-Kniebeugen", "Diamond-Liegestütze"

---

## 10. Technische Architektur

### 10.1 Neue Dateien

**Haupt-Datei:**
```
Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
```

**Struktur (analog zu AtemView.swift):**
```swift
// MARK: - Models
struct WorkoutSet: Identifiable, Hashable, Codable { ... }
struct WorkoutPhase: Identifiable, Hashable, Codable { ... }

// MARK: - Main View
public struct WorkoutProgramsView: View { ... }

// MARK: - Row View (Liste)
struct WorkoutSetRow: View { ... }

// MARK: - Set Editor
struct SetEditorView: View { ... }

// MARK: - Phase Editor
struct PhaseEditorView: View { ... }

// MARK: - Session Runner
struct WorkoutSessionRunner: View { ... }

// MARK: - Sound Player (reuse from WorkoutsView)
// Wird importiert/geteilt

// MARK: - Helper Views
struct WorkoutGlassCard<Content: View>: View { ... }
struct OverlayBackgroundEffect: ViewModifier { ... }
```

**LoC-Schätzung:** ~1200 LoC (analog zu AtemView: 1107 LoC)

---

### 10.2 Geänderte Dateien

**ContentView.swift:**
```swift
// Tab-Reihenfolge anpassen
TabView {
    OffenView()
        .tabItem { Label("Offen", systemImage: "lotus") }

    AtemView()
        .tabItem { Label("Atem", systemImage: "wind") }

    WorkoutsView()  // ← UMBENENNEN
        .tabItem { Label("Frei", systemImage: "flame.fill") }  // ← NEU

    WorkoutProgramsView()  // ← NEU
        .tabItem { Label("Workouts", systemImage: "figure.strengthtraining.traditional") }  // ← NEU
}
```

**Änderungen:** ~5 LoC

---

### 10.3 Shared Services (bereits vorhanden, keine Änderung!)

**HealthKitManager.swift:**
```swift
try await HealthKitManager.shared.logWorkout(
    start: workoutStart,
    end: Date(),
    activity: .highIntensityIntervalTraining
)
```
✅ Bereits implementiert (Lines 158-218)

**LiveActivityController.swift:**
```swift
liveActivity.requestStart(title: ..., phase: 1, endDate: ..., ownerId: "WorkoutProgramsTab")
await liveActivity.update(phase: ..., endDate: ..., isPaused: ...)
await liveActivity.end(immediate: true)
```
✅ Bereits vorhanden

**SoundPlayer (aus WorkoutsView):**
- Wird in WorkoutProgramsView wiederverwendet (nested class, wie bei AtemView)
- Alternativ: Auslagern in Services/ (aber nicht kritisch)

---

### 10.4 Persistence

**UserDefaults:**
```swift
private let setsKey = "workoutProgramSets"

private func loadSets() {
    if let data = UserDefaults.standard.data(forKey: setsKey),
       let decoded = try? JSONDecoder().decode([WorkoutSet].self, from: data) {
        sets = decoded
        migrateSets()  // Fügt fehlende Default-Presets hinzu
    } else {
        sets = Self.defaultSets  // Initial load
    }
}

private func saveSets() {
    if let data = try? JSONEncoder().encode(sets) {
        UserDefaults.standard.set(data, forKey: setsKey)
    }
}
```

**Migration (analog zu AtemView):**
- Prüft, ob Default-Presets fehlen (z.B. nach Update)
- Fügt fehlende hinzu, ohne custom Sets zu überschreiben
- Aktualisiert Beschreibungen bei bestehenden Defaults

---

## 11. Acceptance Criteria

### ✅ Feature ist fertig, wenn:

#### 11.1 Liste & Navigation
- [ ] 10 Default-Presets werden angezeigt (emoji, Name, Details)
- [ ] Details-Zeile zeigt: "X Übungen · Y Runden · ≈ Z:ZZ min"
- [ ] Play-Button startet Workout (öffnet Session-Runner)
- [ ] Info-Button (ℹ️) zeigt Sheet mit wissenschaftlicher Beschreibung
- [ ] Edit-Button (⋯) öffnet Set-Editor
- [ ] Swipe-to-delete funktioniert (nur custom Sets)
- [ ] "Set hinzufügen" Button öffnet Editor für neues Set

#### 11.2 Set-Editor
- [ ] Emoji-Auswahl (Horizontal Scroll, mind. 10 Optionen)
- [ ] Name-Textfeld (Validation: nicht leer)
- [ ] Runden-Picker (1-99)
- [ ] Gesamtdauer wird live berechnet und angezeigt
- [ ] Phasen-Liste mit Drag & Drop zum Umordnen
- [ ] "Phase hinzufügen" übernimmt Dauern der letzten Phase
- [ ] Phase-Detail-Button (⋯) öffnet Phasen-Editor
- [ ] "Löschen"-Button (nur bei existierenden Sets, nicht bei Neu)
- [ ] Speichern/Abbrechen funktioniert

#### 11.3 Phasen-Editor
- [ ] Name-Dropdown mit 60+ Vorschlägen (alphabetisch sortiert)
- [ ] Option "Eigener Name..." → TextField
- [ ] Belastung Wheel Picker (1-600s)
- [ ] Pause Wheel Picker (0-600s)
- [ ] Speichern übernimmt Änderungen
- [ ] Letzte Phase bekommt automatisch restDuration = 0 (nur beim Speichern des Sets)

#### 11.4 Session-Runner
- [ ] Display zeigt: Set-Name, Phase-Name, Runde X/Y, Phase X/Y, Belastung/Pause
- [ ] Dual-Ring Progress (Outer: Gesamt 0→1, Inner: Phase reset bei jedem Wechsel)
- [ ] Icon wechselt: 🔥 (Belastung) ↔ ⏸️ (Pause)
- [ ] Audio: countdown-transition (3s vor Ende Belastung)
- [ ] Audio: auftakt (3s vor Ende Pause, Pre-Roll)
- [ ] Audio: ausklang (nach letzter Phase)
- [ ] TTS: "Runde X" / "Letzte Runde" (nur Runden, NICHT Phase-Namen)
- [ ] Pause/Resume funktioniert (Button-Toggle, akkumuliert Zeit korrekt)
- [ ] X-Button bricht ab (mit HealthKit Logging, wenn >3s)
- [ ] Fertig-Button nach letzter Phase (mit HealthKit Logging)
- [ ] Idle Timer disabled während Session (Display bleibt an)

#### 11.5 LiveActivity
- [ ] Zeigt Set-Name + Emoji ("💪 Core Circuit")
- [ ] Zeigt aktuelle Phase-Name ("🔥 Planke" / "⏸️ Pause")
- [ ] Zeigt Runde X/Y
- [ ] Progress-Ring oder Linear-Bar (continuous)
- [ ] Update bei jedem Phase-Wechsel (nicht nur Runden-Wechsel!)
- [ ] Pause-Status wird angezeigt (isPaused: true)
- [ ] Beendet sich bei Session-Ende

#### 11.6 HealthKit
- [ ] Logged als "High Intensity Interval Training"
- [ ] Kalorien werden berechnet und geschrieben (MET-basiert)
- [ ] Funktioniert bei: Natural End, Manual Finish, X-Button Cancel
- [ ] Mindestens 3s Session-Dauer erforderlich (wie aktuell)
- [ ] Keine Fehler-Alerts (nur Console-Logging)

#### 11.7 Tab-Umbenennung
- [ ] Aktueller "Workouts"-Tab heißt jetzt "Frei"
- [ ] Tab-Icon bleibt "flame.fill"
- [ ] Neuer Tab heißt "Workouts"
- [ ] Neuer Tab-Icon: "figure.strengthtraining.traditional"
- [ ] Tab-Reihenfolge: Offen | Atem | Frei | Workouts

#### 11.8 Migration & Persistence
- [ ] Alte Nutzer bekommen 10 Default-Presets beim ersten Load
- [ ] Neue Nutzer sehen sofort die Defaults
- [ ] Custom Sets bleiben erhalten (nicht überschrieben)
- [ ] Migration fügt fehlende Defaults hinzu (wie bei Atem)

#### 11.9 Build & Tests
- [ ] App kompiliert ohne Errors
- [ ] Keine Crashes beim Navigieren zwischen Tabs
- [ ] Keine Warnings (außer deprecation-warnings von Dependencies)
- [ ] (Optional) Unit Tests für WorkoutSet.totalSeconds Berechnung

---

## 12. Out of Scope (V1)

### ❌ Nicht enthalten:

1. **Watch App Integration**
   - Kein separater Tab auf Apple Watch
   - LiveActivities werden automatisch auf Watch angezeigt (ausreichend)

2. **Session History / Analytics**
   - Kein "Welches Set wurde wann gelaufen"
   - Nur HealthKit als Datenquelle (wie aktuell)

3. **Set-Sharing / Cloud-Sync**
   - Keine Export/Import-Funktion
   - Keine iCloud-Sync zwischen Geräten

4. **Kategorien in der Set-Liste**
   - Erst ab 12+ Sets relevant
   - V1: Einfache Liste (wie Atem)

5. **Custom Audio-Sounds pro Phase**
   - Nur Standard-Sounds (auftakt, countdown, ausklang)
   - Keine "Gong für Planke, Bell für Burpees"

6. **Video-Tutorials für Übungen**
   - Keine eingebetteten Anleitungen
   - User kennt Übungen oder nutzt externe Quellen

7. **Workout-Templates aus Cloud**
   - Keine Online-Bibliothek mit Community-Sets
   - Nur lokale Presets

---

## 13. Offene Fragen / Risiken

### 13.1 Tabata-Struktur: 8x identische Phase oder generisch?

**Problem:** Tabata = 8 Runden à 20s/10s mit **derselben Übung** (z.B. Burpees).

**Aktuelle Lösung:** 8 identische `WorkoutPhase`-Einträge
```swift
phases: [
    WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
    WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10),
    // ... 8x
]
```

**Alternative:** Single Phase + Meta-Repetitions?
```swift
phases: [
    WorkoutPhase(name: "Burpees", workDuration: 20, restDuration: 10, repetitions: 8)
]
```

**Entscheidung:** ❓ Hennings Feedback erforderlich
**Empfehlung:** Option 1 (explizite Phasen), da flexibler und konsistent mit Editor-UX

---

### 13.2 LiveActivity Phase-Namen: Truncation bei langen Übungen

**Problem:** "Bulgarische Split-Kniebeugen links" = 38 Zeichen → zu lang für LiveActivity Compact View

**Lösung:**
- Max 25 Zeichen in LiveActivity
- Truncate mit "..." (SwiftUI `.lineLimit(1)`)
- Beispiel: "Bulgarische Split-Knie..."

**Alternativ:** Kurzformen definieren (V2)
- "Bulgarische Split-Kniebeugen links" → "Bulg. Split links"

---

### 13.3 SoundPlayer: Shared oder Nested?

**Aktuell (AtemView):** Nested class `GongPlayer` (Lines 135-166)
**Aktuell (WorkoutsView):** Nested class `SoundPlayer` (Lines 69-207)

**Problem:** Code-Duplikation zwischen Tabs

**Optionen:**
1. **Keep nested** (wie jetzt) → keine Konflikte, isolierte Namespaces
2. **Extract to Services/** → Shared, aber aufwändiger Refactor

**Entscheidung:** ❓ Hennings Feedback
**Empfehlung:** Keep nested für V1 (konsistent mit bestehender Architektur)

---

### 13.4 Scope-Limit: 1200 LoC = OK?

**Geschätzt:** 1 neue Datei, ~1200 LoC
**Limit laut CLAUDE.md:** Max 250 LoC Änderungen, Max 4-5 Dateien

**Analyse:**
- **1 neue Datei** ✅ (unter Limit)
- **1200 LoC gesamt** ⚠️ (über Limit)
- **Aber:** Analog zu AtemView (1107 LoC), die auch in einem Zug erstellt wurde

**Frage an Henning:** Feature in Phasen splitten?
1. **Phase 1:** Models + Liste + Editor (~600 LoC)
2. **Phase 2:** Session-Runner + LiveActivity (~600 LoC)

**Alternative:** Als "ausnahmsweise OK" behandeln, da analog zu AtemView?

---

## 14. Implementierungs-Plan (wenn approved)

### Schritt 1: Feature-Branch erstellen
```bash
git checkout -b feature/workout-programs
```

### Schritt 2: WorkoutProgramsView.swift erstellen
- Models (WorkoutSet, WorkoutPhase)
- Liste mit Default-Presets
- Set-Editor (Name, Emoji, Runden, Phasen-Liste)
- Phasen-Editor (Name-Dropdown, Dauern)
- Session-Runner (analog zu WorkoutRunnerView in WorkoutsView)

### Schritt 3: ContentView.swift anpassen
- Tab "Workouts" → "Frei" umbenennen
- Neuen Tab "Workouts" hinzufügen
- Tab-Icons anpassen

### Schritt 4: Testen
- Build & Run
- Alle Acceptance Criteria durchgehen
- LiveActivity auf Device testen (Simulator: iOS 17.2+)

### Schritt 5: Commit & Merge
```bash
git add .
git commit -m "feat: Workout-Programme mit 10 Presets, Editor, LiveActivity"
git checkout main
git merge feature/workout-programs
```

---

## 15. Anhang: Design-Referenzen

### Liquid Glass Design Language (iOS 18+)

**Verwendet in diesem Feature:**
- `.ultraThinMaterial` für GlassCards
- `.smooth()` Animationen bei Overlays
- Dual-Ring Progress mit `LinearGradient`
- Vibrancy & depth (Shadows, Blur)
- SF Symbols 6 Icons

**Beispiel (GlassCard):**
```swift
struct WorkoutGlassCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.32), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}
```

---

## 16. Zusammenfassung

**Was wird gebaut:**
- Neuer "Workouts"-Tab mit Preset-basierten HIIT-Programmen
- 10 wissenschaftlich fundierte Default-Sets (Tabata, Core, HIIT, Stretching, etc.)
- Editor für custom Sets (Name, Emoji, Phasen mit individuellen Dauern)
- 60+ Übungs-Vorschlagsliste (deutsch/englisch)
- Session-Runner mit Dual-Ring Progress, Phase-Namen, Audio-Cues, TTS
- LiveActivity Integration (Dynamic Island + Lock Screen + Apple Watch)
- HealthKit Logging (HIIT Workout + Kalorien)

**Umfang:**
- 1 neue Datei: `WorkoutProgramsView.swift` (~1200 LoC)
- 1 geänderte Datei: `ContentView.swift` (5 LoC)
- Keine Änderungen an Services (HealthKitManager, LiveActivityController bereits kompatibel)

**Fertig wenn:**
- Alle 9 Acceptance Criteria-Kategorien erfüllt (insgesamt 50+ Checkboxen)
- Build ohne Errors
- Device-Test zeigt LiveActivity korrekt

---

**Status:** Ready for Implementation
**Next Step:** Hennings Approval → Feature-Branch erstellen → Implementieren
