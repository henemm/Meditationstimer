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

- Neues iOS Unit Testing Bundle erstellen (MeditationstimerTests)
- Test-Dateien aus Tests/ zum Target hinzufügen (58+ Tests vorhanden)
- Tests ausführen und verifizieren

### HealthKit Re-Testing auf Device
**Status:** Offen
**Priorität:** Niedrig

- End-to-End Tests auf echtem iPhone/Apple Watch durchführen
- Verifizieren: Meditation, Workouts, Streaks, Smart Reminders

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
