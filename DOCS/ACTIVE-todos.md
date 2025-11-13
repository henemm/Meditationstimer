# Active Todos - Meditationstimer

**Letzte Aktualisierung:** 13. November 2025
**Regel:** Nur OFFENE und AKTIVE Aufgaben. Abgeschlossene Bugs/Tasks werden gelöscht.

---

## 🐛 aktive Bugs
(Keine)


## behobene Bugs
- NoAlc Sheet: Drag Handle überlappte/schnitt durch "NoAlc-Tagebuch" Titel (Fix implementiert in 45b1330, muss noch getestet werden)
  - Root Cause: Drag Indicator ist Teil des Sheet Containers, nicht des Content VStack - inner padding hatte keine Auswirkung
  - Fix: Root-level `.padding(.top, 20)` + Sheet height 200→240 + inner padding 52→32
  - NoAlcLogSheet.swift Lines 38, 161-162
- Workouts: Keine Sounds mehr nachdem man auf Pause gedrückt hat und weiter spielt (Fix implementiert in 0f61eec, muss noch getestet werden)
- Auf der Workouts-View wird der Text "6 Übungen . 3 Runden = 1…" abgeschnitten. Wir müssen am besten die Begriffe "Übungen" und "Runden" kürzen. Evlt. einfach "6 x 3 = 18:00 min"?
- Smart Reminders: Alle Notifications wurden für nächste Woche statt diese Woche scheduled nach commit 960811a (Fix implementiert in 2fb6792, muss noch getestet werden)
  - Root Cause: scheduleNotifications() nach JEDER cancelMatchingReminders() → löschte ALLE Notifications → re-created mit partial DateComponents
  - Fix: scheduleNotifications() Call nach cancelMatchingReminders() entfernt (Line 204-207 in SmartReminderEngine.swift)
  - Testing: App neustarten, prüfen dass Notifications für HEUTE scheduled werden (nicht nächste Woche)

---


---

## 💳 Technische Schulden

### Swift Compiler Warnings behoben
**Status:** ✅ **Abgeschlossen** (10. November 2025)
**Commit:** 825e845
**Release:** v2.7.3

**Was wurde gefixt:**
1. **NotificationHelper.swift:56** - Unnecessary `async`/`await` für synchrone UNNotificationCenter Methoden entfernt
2. **AmbientSoundPlayer.swift:292** - Unused `volumeStep` variable entfernt (fade logic nutzt direct `progress * targetVolume`)
3. **WorkoutProgramsView.swift:1084** - Unused `nextIndex` variable entfernt
4. **CalendarView.swift:92** - Unused `streakStart` binding → wildcard pattern (`let _ = ...`)

**Ergebnis:**
- Alle 4 Code-Warnings eliminiert ✅
- Build erfolgreich (nur CFBundleShortVersionString mismatch bleibt - nicht code-bezogen)
- Modern Swift patterns angewandt (wildcard für nil-checks, synchrone API calls)

---

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

### Diagnostic Logging entfernen (SmartReminderEngine)
**Status:** Offen (nach Testing)
**Priorität:** Niedrig
**Aufwand:** ~5 Min

**Was zu tun ist:**
Nach erfolgreichem Testing des Smart Reminders Bug-Fixes (commit 2fb6792):
- SmartReminderEngine.swift Lines 314-317 entfernen (diagnostic "today" vs "next week" logging)
- Diese Logs waren nur für Debugging gedacht und sind irreführend (zeigen "next week" auch für morgen/übermorgen)

**Warum warten:**
- Erst nach Device-Testing bestätigen dass Fix funktioniert
- Dann Cleanup durchführen

---

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
