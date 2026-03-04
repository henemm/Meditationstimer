# Workout Phase Timer in Live Activity

## Overview

Die Workout Live Activity (Dynamic Island + Lock Screen) zeigt zusätzlich zum Gesamt-Session-Countdown einen zweiten Countdown für das aktuelle Work/Rest-Intervall an. Kein Icon, kein Label — zwei Countdowns nebeneinander, selbsterklärend.

## Requirements

### Requirement: Dual Timer Display (Workout Only)
Die Live Activity SOLL bei Workouts zwei Countdown-Timer anzeigen.

#### Scenario: Workout Running - Work Phase
- GIVEN Live Activity ist aktiv mit ownerId "WorkoutsTab"
- AND `phaseEndDate` ist gesetzt (nicht nil)
- WHEN Work-Phase läuft (phase == 1)
- THEN zeigt Timer 1 den Intervall-Countdown (z.B. "0:28")
- AND zeigt Timer 2 den Gesamt-Countdown (z.B. "12:34")
- AND Timer 1 ist größer/prominenter als Timer 2

#### Scenario: Workout Running - Rest Phase
- GIVEN Live Activity ist aktiv mit ownerId "WorkoutsTab"
- AND `phaseEndDate` ist gesetzt
- WHEN Rest-Phase läuft (phase == 2)
- THEN zeigt Timer 1 den Intervall-Countdown (z.B. "0:14")
- AND zeigt Timer 2 den Gesamt-Countdown (z.B. "12:06")

#### Scenario: Workout Paused
- GIVEN Workout ist pausiert (isPaused == true)
- WHEN Live Activity anzeigt
- THEN beide Timer zeigen statische Restzeit (eingefroren)
- AND kein Timer zählt weiter

#### Scenario: Non-Workout Activity (Meditation/Atem)
- GIVEN Live Activity ist aktiv mit ownerId != "WorkoutsTab"
- AND `phaseEndDate` ist nil
- WHEN Live Activity anzeigt
- THEN zeigt nur EINEN Timer (bestehendes Verhalten, keine Änderung)

### Requirement: Layout per Presentation
Die Anzeige SOLL sich an die verfügbare Fläche anpassen.

#### Scenario: Lock Screen (160pt Höhe)
- GIVEN Lock Screen Live Activity
- WHEN Workout läuft mit zwei Timern
- THEN Intervall-Countdown links (größere Schrift)
- AND Gesamt-Countdown rechts (kleinere Schrift)
- AND keine Icons, keine Labels

#### Scenario: Dynamic Island Expanded (144pt Höhe)
- GIVEN Dynamic Island Expanded View
- WHEN Workout läuft mit zwei Timern
- THEN Layout analog Lock Screen: Intervall links, Gesamt rechts

#### Scenario: Dynamic Island Compact (36pt Höhe)
- GIVEN Dynamic Island Compact View
- WHEN Workout läuft
- THEN zeigt NUR den Intervall-Countdown (Phase-Timer)
- AND Gesamt-Countdown wird NICHT angezeigt (kein Platz)

#### Scenario: Dynamic Island Minimal
- GIVEN Dynamic Island Minimal View
- WHEN Workout läuft
- THEN zeigt Phase-Icon wie bisher (keine Änderung)

### Requirement: ContentState Erweiterung
Das Datenmodell SOLL ein optionales Feld für den Phase-Endzeitpunkt erhalten.

#### Scenario: ContentState mit phaseEndDate
- GIVEN neues Feld `phaseEndDate: Date?` in ContentState
- WHEN Workout-Caller start/update aufruft
- THEN setzt `phaseEndDate` auf den Endzeitpunkt des aktuellen Intervalls
- AND setzt `endDate` weiterhin auf den Session-Endzeitpunkt

#### Scenario: ContentState ohne phaseEndDate (bestehend)
- GIVEN Meditation/Atem-Caller start/update aufruft
- WHEN `phaseEndDate` nicht gesetzt wird
- THEN bleibt `phaseEndDate` nil
- AND bestehende Single-Timer-Anzeige unverändert

## Technical Notes

### ContentState Änderung (BEIDE Targets!)

```swift
struct ContentState: Codable, Hashable {
    var endDate: Date           // Session-Gesamtende (bestehend)
    var phase: Int              // 1=Work, 2=Rest (bestehend)
    var ownerId: String?        // (bestehend)
    var isPaused: Bool          // (bestehend)
    var phaseEndDate: Date?     // NEU: Ende des aktuellen Intervalls (optional)
}
```

ACHTUNG: `MeditationActivityAttributes.swift` existiert in ZWEI Targets:
1. `Meditationstimer iOS/MeditationActivityAttributes.swift`
2. `MeditationstimerWidget/MeditationActivityAttributes.swift`
Beide MÜSSEN identisch geändert werden!

### Timer-Rendering (Apple Best Practice)

```swift
// Intervall-Countdown (OS-gesteuert, batterieschonend)
Text(phaseEndDate, style: .timer)

// Gesamt-Countdown (bestehend)
Text(endDate, style: .timer)
```

Kein `Timer.publish` oder `activity.update()` pro Sekunde nötig — Apple's `Text(_, style: .timer)` aktualisiert sich automatisch.

### Verfügbare Daten in Workout-Callern

| View | phaseStart | phaseDuration | phaseEndDate berechenbar? |
|------|-----------|---------------|--------------------------|
| WorkoutTab.swift | `phaseStart: Date` | `phaseDuration: Double` | ✅ `phaseStart + phaseDuration` |
| WorkoutsView.swift | `phaseStart: Date` | `phaseDuration: Double` | ✅ `phaseStart + phaseDuration` |
| WorkoutProgramsView.swift | `phaseStart: Date` | via `set.phases[index]` | ✅ berechenbar |

### LiveActivityController API-Erweiterung

```swift
// Neue optionale Parameter (backward compatible)
func start(title:, phase:, endDate:, phaseEndDate: Date? = nil, ownerId:)
func update(phase:, endDate:, phaseEndDate: Date? = nil, isPaused:)
```

### Betroffene Dateien

| Datei | Änderung | ~LoC |
|-------|----------|------|
| `iOS/MeditationActivityAttributes.swift` | +1 Feld | +1 |
| `Widget/MeditationActivityAttributes.swift` | Mirror | +1 |
| `iOS/LiveActivityController.swift` | Neue Parameter | +4 |
| `Widget/MeditationstimerWidgetLiveActivity.swift` | Dual-Timer UI | +25 |
| `iOS/Tabs/WorkoutTab.swift` | phaseEndDate übergeben | +3 |
| `iOS/Tabs/WorkoutsView.swift` | phaseEndDate übergeben | +5 |
| `iOS/Tabs/WorkoutProgramsView.swift` | phaseEndDate übergeben | +5 |
| **Total** | | **~44 LoC** |

Reference Standards:
- `.agent-os/standards/global/implementation-gate.md`
- `.agent-os/standards/testing/ui-testing.md`
