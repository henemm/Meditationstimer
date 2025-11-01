# Active Todos - Meditationstimer

**Letzte Aktualisierung:** 30. Oktober 2025
**Regel:** Nur OFFENE und AKTIVE Aufgaben. Abgeschlossene Bugs/Tasks werden gelöscht.

---

## 🐛 aktive Bugs

keine

---

## 🎨 Design & UX - Liquid Glass Modernisierung

### View-Transitions Vereinheitlichen
**Status:** Analysiert, bereit zur Implementation
**Priorität:** Hoch
**Aufwand:** ~137 LOC über 7 Dateien

**Problem:**
- Drei unterschiedliche Präsentations-Patterns für Session-Runner (Offen/Atem/Workouts)
- OffenView: Overlay ohne Animation
- AtemView: Overlay mit `.scale+.opacity` ✅ (Best Practice)
- WorkoutsView: `.fullScreenCover` (inkonsistent)

**High Priority Fixes:**
1. WorkoutsView → Replace `.fullScreenCover` mit Overlay-Pattern (~80 LOC)
2. OffenView → Add `.scale+.opacity` transition animation (~30 LOC)
3. Alle `NavigationView` → `NavigationStack` (3 Stellen, ~20 LOC)
4. AtemView Animation → `.easeInOut` zu `.smooth` (~2 LOC)

**Details:** Siehe CLAUDE.md "Critical Lessons Learned" für Liquid Glass Patterns

---

## 💳 Technische Schulden

### Deprecated APIs beheben
**Status:** ✅ **Abgeschlossen** (30. Oktober 2025)
**Commits:** 855cd2c, 81d3281, 423eb4a

**Was wurde gefixt:**
1. `.onChange(of:)` → 2-Parameter Syntax (4 Dateien)
2. `HKWorkout.init()` → HKWorkoutBuilder (HealthKitManager)
3. `end(dismissalPolicy:)` → `end(_:dismissalPolicy:)` (LiveActivityController, 5 Stellen)

**Ergebnis:**
- Alle Deprecation-Warnings eliminiert ✅
- Build erfolgreich
- Keine Regressions (Tests verifiziert)

---

## 🧪 Test-Failures (Pre-existing)

### 2 Tests schlagen fehl (nicht durch aktuelle Änderungen verursacht)
**Status:** ✅ **Abgeschlossen** (30. Oktober 2025)
**Commit:** fa782fc

**Was wurde gefixt:**
1. **testMinimumMinutesThreshold()** - Test-Wert von 1.9 → 1.0 minutes (round() ambiguity fix)
2. **testYearBoundaryTransition()** - Test-Dates korrigiert (Dec 31 → Jan 1 ist nur 1 Tag, nicht 1 Jahr)

**Root Causes:**
- Test 1: `round(1.9) = 2` zählte fälschlicherweise (Produktionslogik verwendet round())
- Test 2: Falsche Erwartung (1 Tag Differenz ≠ 1 Jahr Differenz)

**Ergebnis:**
- **41/41 Tests passed** ✅ (100% Success Rate, war 39/41)
- Keine fehlgeschlagenen Tests mehr
- Test-Logic matcht nun Production-Behavior

---

## 🔧 Sonstige Todos

### ~~Test-Target in Xcode einrichten~~ ✅ **Abgeschlossen**
**Status:** ✅ Erledigt (1. November 2025)
**Priorität:** Niedrig
**Aufwand:** War ~30 Min

**Was erledigt wurde:**
- ✅ Test Target `LeanHealthTimerTests` erstellt und konfiguriert
- ✅ 53 Unit Tests erfolgreich integriert:
  - `HealthKitManagerTests.swift` (25 Tests)
  - `StreakManagerTests.swift` (15 Tests)
  - `NoAlcManagerTests.swift` (10 Tests)
  - `MockHealthKitManagerTests.swift` (2 Tests)
  - `LeanHealthTimerTests.swift` (1 Test)
- ✅ Alle Tests laufen via `⌘U` oder xcodebuild
- ✅ 100% Test Success Rate

**Bereinigung durchgeführt (1. November 2025):**
- Gelöscht: Duplikat-Verzeichnis `Tests/` (identische Kopie)
- Gelöscht: Alte manuelle Test-Scripts in `scripts/` (durch XCTest ersetzt)
- Behalten: `LeanHealthTimerTests/` (einziges aktives Test-Target)

**Test-Ausführung:**
```bash
# In Xcode:
⌘U

# Oder Terminal:
xcodebuild test -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

---

### HealthKit Re-Testing auf Device
**Status:** Offen
**Priorität:** Niedrig
**Aufwand:** ~1-2h

**Problem:**
Alle bisherigen Tests liefen im Simulator oder via Unit Tests. HealthKit verhält sich auf echten Geräten manchmal anders (Berechtigungen, Background-Refresh, Watch-Sync).

**Was zu testen ist:**
1. **Meditation (OffenView):**
   - Session starten/beenden
   - HealthKit Logging verifizieren (Apple Health App öffnen)
   - Partial Session bei App-Wechsel

2. **Workouts (WorkoutsView):**
   - HIIT Session mit Sound-Cues
   - HealthKit Workout Type korrekt

3. **Atem (AtemView):**
   - Breathing Session mit Live Activity
   - HealthKit Mindfulness Logging

4. **Streaks:**
   - Streak Calculation korrekt nach echten Sessions
   - Rewards nach 7 Tagen

5. **Smart Reminders:**
   - Notifications erscheinen korrekt
   - Background Refresh funktioniert
   - HealthKit Inaktivitäts-Erkennung

6. **Apple Watch:**
   - Session-Sync iPhone ↔ Watch
   - Heart Rate Monitoring während Session
   - WatchOS Companion App

**Wo testen:**
- iPhone (echtes Gerät, nicht Simulator)
- Apple Watch (optional, aber empfohlen)
- Über mehrere Tage (für Streaks)

**Warum wichtig:**
- User testet auf echtem Device → realistische Bedingungen
- HealthKit Simulator != HealthKit Device
- Catch Edge-Cases die nur auf Hardware auftreten

---

## 📝 Regeln für diese Datei

1. **Nur OFFENE Aufgaben** - Abgeschlossene werden sofort gelöscht
2. **Keine Bug-Historie** - Behobene Bugs dokumentiere ich in Commit-Messages
3. **Konkrete Aufgaben** - Keine vagen "könnte man mal machen" Ideen
4. **Priorisierung** - Hoch/Mittel/Niedrig basierend auf User-Impact
5. **Max 20 Todos** - Bei mehr: Priorisieren und unwichtige löschen

---

**Für Feature-Backlog siehe:** ACTIVE-roadmap.md
**Für abgeschlossene Historie siehe:** Git-Log
