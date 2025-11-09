# Bug Documentation Index

**Zweck:** Schnelles Nachschlagen aller dokumentierten Bugs, kategorisiert nach Pattern/Thema.

**Nutzung für zukünftige Sessions:**
- Vor Bug-Fix: Index nach Symptomen durchsuchen
- Ähnliche Bugs finden: Kategorie-basierte Suche
- Patterns wiedererkennen: z.B. "SwiftUI Lifecycle" → Guard Flag Pattern

---

## Kategorien

### 1. SwiftUI Lifecycle & State Management

#### 🔴 **Duplicate Execution (Callbacks + .onDisappear)**
- **Datei:** [bug-workout-double-healthkit-logging.md](bug-workout-double-healthkit-logging.md)
- **Symptom:** Workouts werden doppelt in Apple Health geloggt
- **Root Cause:** `.onDisappear` feuert NACH completion callback → `endSession()` wird 2x aufgerufen
- **Pattern:** Guard Flag Pattern (synchrone Flag-Setzung vor async Tasks)
- **Commit:** `2821247`
- **CLAUDE.md Lesson:** Lines 826-905

#### 🔴 **REST Phase UI Redundancy**
- **Datei:** [bug-workout-rest-phase-ui.md](bug-workout-rest-phase-ui.md) *(TO BE CREATED)*
- **Symptom:** Während Pause in REST-Phase werden sowohl completed exercise ALS AUCH next exercise angezeigt (redundant)
- **Root Cause:** Pause-State unterschied nicht zwischen WORK-Phase-Pause und REST-Phase-Pause
- **Pattern:** Split UI state based on phase type (WORK vs REST)
- **Commit:** `611f385`
- **CLAUDE.md Lesson:** Lines 765-824

---

### 2. Audio / Completion Handler Patterns

#### 🔴 **End-Gong Cutoff (Atem Tab)**
- **Datei:** [bug-atem-end-gong-cutoff.md](bug-atem-end-gong-cutoff.md) *(TO BE CREATED)*
- **Symptom:** End-Gong wird abgeschnitten bei Atem-Meditation
- **Root Cause:** Ambient audio wurde via `Task.sleep()` gestoppt, BEVOR Gong-Playback fertig war
- **Pattern:** AVAudioPlayerDelegate + Completion Handler + DispatchWorkItem (KEIN Task.sleep!)
- **Commit:** `b1a16f0`
- **CLAUDE.md Lesson:** Lines 728-763

---

### 3. Date Semantics & Iteration Logic

#### 🔴 **NoAlc Streak - Forward vs Backward Iteration**
- **Datei:** [bug-noalc-streak-logic.md](bug-noalc-streak-logic.md)
- **Symptom:** Streak zeigte "0 Days" trotz sichtbarer Daten (1.-8. November)
- **Root Cause:** Backwards iteration (heute → Vergangenheit) versuchte Rewards zu NUTZEN bevor sie chronologisch VERDIENT wurden
- **Pattern:** Forward Chronological Iteration (Vergangenheit → heute) für earned/consumed Resources
- **Lösungsversuche:** 3 (Versuch 1+2 gescheitert, Versuch 3 = Forward Iteration funktionierte)
- **Commit:** `960811a`
- **CLAUDE.md Lesson:** Lines 659-726

#### 🔴 **Smart Reminder Cancellation - Date vs targetDay**
- **Datei:** [bug-noalc-reminder-cancellation.md](bug-noalc-reminder-cancellation.md)
- **Symptom:** NoAlc Reminder erschien trotz Logging um 22:00 Uhr
- **Root Cause:** `NoAlcManager.logConsumption()` übergab `targetDay` (Mitternacht 00:00) statt tatsächlicher Logging-Zeit `Date()` an `cancelMatchingReminders()`
- **Pattern:** Date-Semantik wichtig - `startOfDay(for:)` vs `Date()` haben unterschiedliche Bedeutungen
- **Commit:** `960811a` (combined fix)
- **CLAUDE.md Lesson:** Siehe "Forward vs Backward Iteration" Section

---

### 4. Workout Logic & Timing

#### 🔴 **Workout Rounds - Missing Pause Between Rounds**
- **Datei:** [bug-workout-rounds-missing-pause.md](bug-workout-rounds-missing-pause.md) *(TO BE CREATED)*
- **Symptom:** Keine Pause zwischen Runde 1→2, 2→3 bei mehreren Runden
- **Root Cause:** `needsRest` Logic prüfte nur `restDuration > 0`, aber letzte Übung jeder Runde hatte `restDuration = 0` by design
- **Pattern:** Rest überspringen NUR wenn `isLastPhaseInSet && isFinalRound` (nicht nur `isLastPhaseInSet`)
- **Commit:** `34d3670`
- **CLAUDE.md Lesson:** *(Not documented in CLAUDE.md)*

---

### 5. Data Persistence & State Management

#### 🔴 **NoAlc Streak Points - Dynamic vs Persistent**
- **Datei:** [bug-noalc-streak-points-persistence.md](bug-noalc-streak-points-persistence.md) *(TO BE CREATED)*
- **Symptom:** Streak Points wurden bei jedem App-Start neu berechnet statt persistent gespeichert
- **Root Cause:** Points als `var` statt persistent in `UserDefaults`
- **Pattern:** Persistent state für UI-kritische Werte (nicht re-calculate on every launch)
- **Commit:** `64233c6`
- **CLAUDE.md Lesson:** *(Not documented in CLAUDE.md)*

---

## Quick Search Patterns

### Symptom → Bug Report

| **Symptom** | **Bug Report** | **Pattern** |
|-------------|----------------|-------------|
| Doppelte HealthKit Einträge | bug-workout-double-healthkit-logging.md | Guard Flag Pattern |
| Audio wird abgeschnitten | bug-atem-end-gong-cutoff.md | Completion Handler Pattern |
| Streak zeigt 0 trotz Daten | bug-noalc-streak-logic.md | Forward Iteration |
| Reminder trotz Logging | bug-noalc-reminder-cancellation.md | Date vs startOfDay |
| Redundante UI in Pause | bug-workout-rest-phase-ui.md | Split State by Phase Type |
| Keine Pause zwischen Runden | bug-workout-rounds-missing-pause.md | Conditional Rest Skip |
| Points falsch nach Restart | bug-noalc-streak-points-persistence.md | Persistent State |

### Pattern → Alle Bugs mit diesem Pattern

| **Pattern** | **Bug Reports** |
|-------------|-----------------|
| SwiftUI Lifecycle Hooks | bug-workout-double-healthkit-logging.md |
| Completion Handler (Audio) | bug-atem-end-gong-cutoff.md |
| Date Semantics | bug-noalc-reminder-cancellation.md |
| Iteration Direction | bug-noalc-streak-logic.md |
| UI State Differentiation | bug-workout-rest-phase-ui.md |
| Logic Conditional Edge Cases | bug-workout-rounds-missing-pause.md |
| Persistent vs Computed State | bug-noalc-streak-points-persistence.md |

### Kategorie → Bug Count

| **Kategorie** | **Anzahl Bugs** |
|---------------|-----------------|
| SwiftUI Lifecycle & State | 2 |
| Audio / Completion Handlers | 1 |
| Date Semantics & Iteration | 2 |
| Workout Logic & Timing | 1 |
| Data Persistence | 1 |
| **TOTAL** | **7** |

---

## Workflow für neue Bugs

**VOR dem Fix:**
1. ✅ **Index durchsuchen**: Symptom in Quick Search Table nachschlagen
2. ✅ **Ähnliche Bugs lesen**: Related Pattern-Kategorie prüfen
3. ✅ **CLAUDE.md Lessons lesen**: Generalisiertes Pattern verstehen
4. ✅ **Nur bei neuem Pattern**: Neuen Fix entwickeln

**NACH dem Fix:**
1. ✅ **Bug-Dokument erstellen**: `bug-<name>.md` in DOCS/
2. ✅ **Index aktualisieren**: Dieses Dokument updaten (neue Zeile in Tabellen)
3. ✅ **CLAUDE.md Lesson**: Falls generalisierbares Pattern → in CLAUDE.md dokumentieren
4. ✅ **Git Commit**: Mit Link zu bug-*.md Datei

---

## Status: COMPLETE

**Vollständig dokumentiert (als separate bug-*.md Dateien):**
- ✅ bug-workout-double-healthkit-logging.md - Guard Flag Pattern (wiederkehrend)
- ✅ bug-noalc-streak-logic.md - 3 Lösungsversuche (verhindert Wiederholung)
- ✅ bug-noalc-reminder-cancellation.md - Date-Semantik (wichtige Unterscheidung)

**Nur in CLAUDE.md + Commit dokumentiert (ausreichend):**
- ✅ Atem end-gong cutoff → CLAUDE.md:728-763 + commit `b1a16f0`
- ✅ REST phase UI → CLAUDE.md:765-824 + commit `611f385`
- ✅ Workout rounds pause → Commit `34d3670` (einfacher Logic-Fix)
- ✅ NoAlc streak persistence → Commit `64233c6` (trivial: var → UserDefaults)

**Begründung für Aufspaltung:**
- **Separate Dokumente:** Bugs mit Lösungsversuchen (>1) oder wiederkehrenden Patterns
- **CLAUDE.md only:** Bugs mit generalisierbarem Pattern (einmal dokumentiert = ausreichend)
- **Commit only:** Triviale Fixes ohne wiederkehrendes Pattern

---

**Letzte Aktualisierung:** 9. November 2025
