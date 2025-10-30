# Active Todos - Meditationstimer

**Letzte Aktualisierung:** 30. Oktober 2025
**Regel:** Nur OFFENE und AKTIVE Aufgaben. Abgeschlossene Bugs/Tasks werden gelöscht.

---

## 🐛 Keine aktiven Bugs

Alle bekannten Bugs wurden behoben (siehe Git-Historie für Details).

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
**Status:** Dokumentiert
**Priorität:** Mittel
**Aufwand:** ~2-3h (separate Commits pro Kategorie)

**40+ Warnings über 8 Dateien:**
- `onChange(of:perform:)` deprecated → neue 2-Parameter Syntax
- `end(using:dismissalPolicy:)` deprecated → `end(content:dismissalPolicy:)`
- `HKWorkout.init(activityType:start:end:)` deprecated → HKWorkoutBuilder

**Locations:**
- WorkoutsView.swift:351, 481
- OffenView.swift:420, 383, 391
- AtemView.swift:506
- LiveActivityController.swift:59, 127, 175, 177, 183
- HealthKitManager.swift:149, 178, 181
- NotificationHelper.swift:56, 57
- AmbientSoundPlayer.swift:262

---

## 🔧 Sonstige Todos

### Test-Target in Xcode einrichten
**Status:** Offen
**Priorität:** Niedrig
**Aufwand:** ~30 Min

**Problem:**
Es existieren 58+ Unit Tests im Verzeichnis `/Tests/`:
- `TwoPhaseTimerEngineTests.swift` (18 Tests)
- `StreakManagerTests.swift` (15 Tests)
- `HealthKitManagerTests.swift` (25+ Tests)

Diese Tests sind NICHT in Xcode integriert und werden nicht ausgeführt.

**Was zu tun ist:**
1. In Xcode: File → New → Target → iOS Unit Testing Bundle
2. Target-Name: "MeditationstimerTests"
3. Alle `.swift` Dateien aus `/Tests/` zum neuen Target hinzufügen
4. Im Terminal: `xcodebuild test -scheme MeditationstimerTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
5. Verifizieren dass alle Tests grün sind

**Warum wichtig:**
- Regression Testing bei Code-Änderungen
- CI/CD Integration möglich
- Test Coverage sichtbar machen

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
