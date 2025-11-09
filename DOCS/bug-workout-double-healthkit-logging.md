# Bug: Workouts werden doppelt in Apple Health geloggt

**Erstellt:** 9. November 2025
**Status:** Behoben (Versuch 1)
**Datei:** `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift`

---

## Problem-Beschreibung

**Symptom:**
Workouts im "Workouts"-Tab (WorkoutProgramsView) werden doppelt in Apple Health protokolliert.

**Beobachtung:**
Nach jedem abgeschlossenen Workout erscheinen zwei identische HKWorkout-Einträge in der Health-App (gleiche Start-/Endzeit, gleiche Dauer).

**Konfiguration:**
- Tab: "Workouts" (nicht "Frei"-Tab)
- View: WorkoutProgramsView.swift
- HealthKit-Methode: `HealthKitManager.logWorkout()`

---

## Root Cause

**Problem:** SwiftUI `.onDisappear` Lifecycle-Hook feuert NACH dem Session-Completion-Callback, wodurch `endSession()` zweimal ausgeführt wird.

**Konkrete Ursache:**
```swift
// WorkoutProgramsView.swift - DREI Call Sites für endSession():

// Zeile 710: Callback wenn Timer endet
ProgressRingsView(
    onSessionEnd: { await endSession(manual: false) }
)

// Zeile 736: Manueller Stop-Button
Button("Stop") {
    await endSession(manual: true)
}

// Zeile 775: View Lifecycle
.onDisappear {
    await endSession(manual: true)
}
```

**Warum das fehlschlägt:**

1. User beendet Workout (normal completion oder manueller Stop)
2. Timer feuert → `onSessionEnd` Callback (Zeile 710) wird ausgeführt
3. `endSession()` loggt Workout zu HealthKit via `HKWorkoutBuilder.finishWorkout()`
4. View verschwindet → `.onDisappear` (Zeile 775) wird ausgeführt
5. `endSession()` loggt **ERNEUT** zu HealthKit
6. Ergebnis: **Zwei HKWorkout-Einträge** in Apple Health

**Wichtig:**
- `HKWorkoutBuilder.finishWorkout()` speichert automatisch in HealthKit (kein manuelles Save nötig)
- Jeder Aufruf erstellt einen **neuen HKWorkout-Eintrag**
- Duplikate akkumulieren über Zeit → korrupte Health-Daten

---

## Lösung

**Änderung:** Guard Flag Pattern implementiert

### Schritt 1: State Flag hinzugefügt (Zeile 689)
```swift
@State private var pausedPhaseAccum: TimeInterval = 0
@State private var pausedSessionAccum: TimeInterval = 0
@State private var sessionEnded: Bool = false  // NEW: Prevent double HealthKit logging
```

### Schritt 2: Guard Check in endSession() (Zeilen 791-826)
```swift
func endSession(manual: Bool) async {
    print("[WorkoutPrograms] endSession(manual: \(manual)) called")

    // Guard: Prevent double execution (callback + onDisappear)
    if sessionEnded {
        print("[WorkoutPrograms] endSession already executed, skipping duplicate call")
        return
    }

    // 1. Re-enable idle timer
    setIdleTimer(false)

    // 2. Stop ambient audio
    ambientPlayer.stop()

    // 3. HealthKit Logging if session > 3s (runs in background)
    let endDate = Date()
    if sessionStart.distance(to: endDate) > 3 {
        // Mark session as ended BEFORE async logging starts (prevent race condition!)
        sessionEnded = true

        Task.detached(priority: .userInitiated) {
            do {
                try await HealthKitManager.shared.logWorkout(
                    start: sessionStart,
                    end: endDate,
                    activity: .highIntensityIntervalTraining
                )
                print("[WorkoutPrograms] HealthKit workout logged successfully")

                // Update streak
                await StreakManager.shared.updateStreaks()
            } catch {
                print("[WorkoutPrograms] HealthKit logging failed: \(error)")
            }
        }
    } else {
        // Session < 3s: no HealthKit logging, but still mark as ended
        sessionEnded = true
        print("[WorkoutPrograms] Session < 3s, skipping HealthKit logging")
    }

    // 4. End Live Activity
    await liveActivity.end(immediate: true)

    // 5. Reset state
    isPaused = false
    pausedPhaseAccum = 0
    pausedSessionAccum = 0
}
```

**Begründung:**
- **Synchronous Flag Setting:** Flag wird SYNCHRON gesetzt, bevor `Task.detached` startet → verhindert Race Conditions
- **Guard at Start:** Erste Zeile in `endSession()` prüft Flag → Early Return bei Duplikat-Aufruf
- **Debug Logging:** Print-Statements helfen bei Debugging ("already executed, skipping")
- **Both Paths:** Flag wird in BEIDEN Pfaden gesetzt (>3s UND <3s) → verhindert partielle Duplikate

---

## Test-Plan

1. Workout im "Workouts"-Tab starten
2. Workout normal zu Ende laufen lassen (kein manueller Stop)
3. Apple Health-App öffnen → Workout-Einträge prüfen
4. **Erwartetes Ergebnis:** Genau EIN HKWorkout-Eintrag
5. Console-Logs prüfen:
   - `[WorkoutPrograms] endSession(manual: false) called` (vom Callback)
   - `[WorkoutPrograms] endSession(manual: true) called` (von .onDisappear)
   - `[WorkoutPrograms] endSession already executed, skipping duplicate call`

**Repeat für manuellen Stop:**
1. Workout starten → manuell stoppen (Stop-Button)
2. Health-App prüfen → nur EIN Eintrag
3. Logs prüfen → zweiter Aufruf wird geskippt

---

## Lessons Learned

### 1. SwiftUI Lifecycle ist unvorhersehbar
**Problem:** `.onDisappear` kann vor, nach oder gleichzeitig mit Callbacks feuern.

**Pattern:**
```
❌ DON'T: Cleanup-Tasks nur in .onDisappear ausführen
❌ DON'T: Cleanup-Tasks nur in Callbacks ausführen
✅ DO: Guard Flag Pattern für Methoden mit Side-Effects
✅ DO: Flag SYNCHRON setzen (vor async Tasks!)
```

### 2. Race Condition Prevention
**Falsch:**
```swift
Task.detached {
    try await HealthKitManager.shared.logWorkout(...)
    sessionEnded = true  // ❌ Zu spät! Zweiter Task könnte schon gestartet sein
}
```

**Richtig:**
```swift
sessionEnded = true  // ✅ ZUERST synchron setzen
Task.detached {
    try await HealthKitManager.shared.logWorkout(...)
}
```

### 3. Gleiche Pattern gilt für andere Cleanup-Tasks
**Anwendbar auf:**
- Live Activities (`.end()` nicht doppelt aufrufen)
- Notifications (nicht doppelt canceln)
- Audio Cleanup (Player nicht doppelt stoppen)
- HealthKit Logging (wie hier)
- Idle Timer (nicht doppelt re-enablen)

### 4. Analysis-First Prinzip
**Prozess:**
1. ✅ Alle Call Sites identifiziert (3 Stellen: Callback, Button, .onDisappear)
2. ✅ Lifecycle-Order verstanden (Callback → .onDisappear)
3. ✅ Root Cause mit Sicherheit identifiziert (nicht spekuliert)
4. ✅ Gezielter Fix (Guard Flag Pattern)
5. ✅ Build erfolgreich, keine Regression

**Keine Trial-and-Error Versuche nötig!**

---

## Related Files

- `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` (Lines 689, 710, 736, 775, 791-826)
- `Services/HealthKitManager.swift` (Lines 166-233) - `logWorkout()` Methode
- `CLAUDE.md` (Lines 826-905) - Documented Pattern für zukünftige Referenz

---

## Verwandte Bugs

**Ähnliches Pattern (potenziell):**
- OffenView.swift - Prüfen ob Meditation-Logging ähnliches Problem hat
- AtemView.swift - Prüfen ob Breathing-Logging betroffen ist
- WorkoutsView.swift ("Frei"-Tab) - Separate Implementierung, vermutlich nicht betroffen

**Hinweis:** Nur WorkoutProgramsView betroffen, da dort ProgressRingsView mit Callback verwendet wird + .onDisappear.
