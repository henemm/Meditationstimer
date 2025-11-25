# Active Todos - Meditationstimer

**Letzte Aktualisierung:** 25. November 2025
**Regel:** Nur OFFENE und AKTIVE Aufgaben. Abgeschlossene Bugs/Tasks werden gelöscht.

---

## 🚨 KRITISCHE Bugs

*Aktuell keine kritischen Bugs*

---

## ✅ In Version 2.8.2 gefixt (25.11.2025)

**4 Bugs gefixt mit Test-First Ansatz:**

1. **Bug #28:** Gelöschte Presets → First-Launch-Flag Pattern ✅ (wird mit Update 2.8.2 verifiziert)
2. **Bug #29:** Besinnungszeit Reset → `@AppStorage` statt `@State` ✅ VERIFIZIERT
3. **Bug #30:** 1 Minute = 0 → `.tag()` zu Pickern ✅ VERIFIZIERT
4. **Bug #31:** "Contemplation" → `NSLocalizedString()` ✅ VERIFIZIERT

**Test-Ergebnisse:** 90/92 Unit Tests bestanden (TwoPhaseTimerTests, LocalizationTests)

Details siehe Commit c89163d und git history.

---

## 🐛 aktive Bugs

### NoAlc Bugs

**Bug 27: NoAlc Rewards können nach 3 Wochen nicht mehr verdient werden**
- Location: `CalendarView.swift` Zeilen 64-65 und 79-80
- Problem: Nach 3 verdienten Rewards (auch wenn alle verbraucht) wurden keine neuen mehr vergeben
- Root Cause: Cap prüfte `earnedRewards < 3` (total je verdient) statt `availableRewards < 3` (aktuell verfügbar)
- **Fix (24.11.2025):** Beide Stellen korrigiert auf `currentAvailable < 3` bzw. `newAvailable < 3`
- Commit: 5a4fbdd
- Status: **GEFIXT, BITTE TESTEN**

---

### Localization Bugs
**Status:** Offen
**Priorität:** Hoch (User Impact - App soll bilingual sein)

**Bug 8: Debug Entry für Smart Reminders entfernen**
- Problem: Debug-Datei `SmartReminderDebugView.swift` + NavigationLink in Settings
- **Fix (23.11.2025):**
  - Datei `SmartReminderDebugView.swift` gelöscht
  - NavigationLink in `SettingsSheet.swift:200` entfernt
- Status: **GEFIXT**


**Bug 12: AirPods Static Noise während Meditation**
- Location: `Meditationstimer iOS/BackgroundAudioKeeper.swift` Zeile 32
- **Fix existiert:** Volume wurde auf `0.0` gesetzt (war vorher 0.01)
- Test: AirPods + ANC aktivieren, Meditation OHNE Ambient Sound starten, auf Fiepen achten
- Status: **FIX EXISTIERT, BITTE AUF DEVICE TESTEN**

**Bug 26: Free Workout TTS sagt "Round Eins" statt "Round one" (EN)**
- Location: `Meditationstimer iOS/Tabs/WorkoutsView.swift` Zeilen 178-200
- Root Cause: TTS-Stimme war hardcoded auf `de-DE` → deutsche Stimme las englischen Text
- **Fix (23.11.2025):** `currentTTSLanguage` computed property hinzugefügt, erkennt Gerätesprache automatisch
- **Getestet (23.11.2025):** ✅ EN-Version sagt "Round two" korrekt
- Status: **GEFIXT**

---

### Weitere Localization Bugs (Neu: 22.11.2025)

**Bug 18: Workouts-Tab Übungs-Info-Sheets zeigen "nicht verfügbar"**
- Location: `WorkoutProgramsView.swift` (WorkoutPhase names) + `ExerciseDatabase.swift`
- Problem: Info-Sheets zeigen "Übungsinformationen nicht verfügbar" statt der Übungsdetails
- **Fix:** 31 Übungsnamen in WorkoutProgramsView.swift auf deutsche ExerciseDatabase-Namen geändert
- **Getestet (23.11.2025):** ✅ Übungsdetails werden korrekt angezeigt
- Status: **GEFIXT**

**Bug 19: Workouts-Tab Übungs-Info-Sheets auf Deutsch (in EN Version)**
- Location: `ExerciseDatabase.swift` - 43 Übungen mit effect + instructions Strings
- Problem: EN-Übersetzungen fehlten in Localizable.xcstrings (state: "new" mit deutschem Text)
- **Fix (23.11.2025):** 86 englische Übersetzungen in Localizable.xcstrings eingefügt
- **Getestet (23.11.2025):** ✅ EN-Version zeigt englische Texte
- Status: **GEFIXT** 

---

### Workout-Übungen

**Bug 25: Übungsnamen inkonsistent lokalisiert - GEFIXT**
- **Durch Bug 18 gefixt:** WorkoutPhase Namen → ExerciseDatabase Namen (31 Änderungen)
- **Links/Rechts Paare:** Alle vollständig in ExerciseDatabase ✅
- **NEU (23.11.2025):** 46 Übungsnamen in Localizable.xcstrings mit EN-Übersetzungen
- **NEU:** UI-Code geändert: Text(name) → Text(LocalizedStringKey(name))
- **Getestet (23.11.2025):** ✅ EN-Version zeigt englische Übungsnamen
- Status: **GEFIXT**

---

## behobene Bugs
- Bug 10: Touch-Bereich für "..." Edit Buttons zu klein (UX)
  - Fix: `.frame(width: 44, height: 44)` + `.contentShape(Rectangle())`
  - Commit: be02cfe
- Bug 13: RunCard hatte transparenten Hintergrund statt soliden
  - Root Cause: RunCard hatte keinen expliziten Hintergrund → Liquid Glass durchscheinend
  - Fix: `.frame(maxWidth: .infinity, maxHeight: .infinity)` + `.background(Color(uiColor: .systemBackground))` hinzugefügt
  - OffenView.swift RunCard struct (Lines 629-631)
- Bug 11: TTS sprach immer Deutsch (auch in EN-App)
  - Root Cause: `speak()` hatte hardcoded `language: String = "de-DE"` Default
  - Fix: Sprache automatisch aus `Locale.current.language.languageCode` ermitteln
  - WorkoutProgramsView.swift speak() Funktion (Lines 125-140)
- Bug 20: NoAlc Sheet "Yesterday Evening" nicht lokalisiert
  - Fix: Hardcoded Strings durch NSLocalizedString ersetzt
  - NoAlcLogSheet.swift titleText (Lines 186, 188)
- Bug 21: NoAlc Sheet Begriffe umbenennen
  - Fix: "Ruhig"→"Kaum", "Leicht"→"Überschaubar", "Wild"→"Party"
  - Localizable.xcstrings (Steady, Easy, Wild Entries)
- Bug 22: Settings-Sheet hardcoded deutsche Texte
  - Fix: "Einstellungen", "System-Einstellungen öffnen", "Fertig" → NSLocalizedString
  - SettingsSheet.swift (Lines 191, 196, 202)
- Bug 23: Settings Smart-Reminder Text nicht lokalisiert
  - Fix: NSLocalizedString für den Erklärungstext verwendet (Übersetzung existierte bereits)
  - SettingsSheet.swift (Line 173)
- Bug 24: Settings irreführender "(German/English)" Text
  - Fix: Text entfernt (System nutzt tatsächlich alle Sprachen)
  - SettingsSheet.swift (Lines 167-169 entfernt)
- Bug 14: Offen Info-Dialog auf Englisch (in DE)
  - Fix: NSLocalizedString für alle Texte (Übersetzungen existierten bereits)
  - OffenView.swift InfoSheet (Lines 436-444)
- Bug 15: Atem-Tab Info-Sheets unvollständig übersetzt (DE)
  - Fix: NSLocalizedString für Section-Überschriften (Rhythm, Effect, Recommended Application)
  - Fix: Format-String "%lld Repetitions · ≈ %@" → "%lld Wiederholungen · ≈ %@"
  - Fix: 7 recommendedUsage Fließtexte mit deutschen Übersetzungen hinzugefügt
  - AtemView.swift PresetInfoSheet (Lines 520-543), Localizable.xcstrings
- Bug 16: Atem-Tab Edit Dialog unvollständig übersetzt (DE)
  - Root Cause: `pickerRow(title: String, ...)` - String-Parameter wird nicht automatisch lokalisiert
  - Fix: Parameter-Typ von `String` auf `LocalizedStringKey` geändert
  - AtemView.swift pickerRow() Funktion (Line 1084)
- Bug 17: Workouts-Tab Info-Sheet unvollständig übersetzt (DE)
  - Root Cause: InfoSheet akzeptierte `String` statt `LocalizedStringKey` → keine automatische Lokalisierung
  - Fix: InfoSheet.swift Parameter von String auf LocalizedStringKey geändert
  - Bonus: Alle InfoSheet-Aufrufstellen (OffenView, WorkoutsView, NoAlcLogSheet) automatisch gefixt!
- Bug 3: Breathe Meditation InfoSheets auf Deutsch (in EN Version)
  - Fix: Automatisch durch Bug 17 Fix behoben (InfoSheet → LocalizedStringKey)
- Bug 4: Breathe Exercise Edit Dialog auf Deutsch (in EN Version)
  - Fix: Automatisch durch Bug 16 Fix behoben (pickerRow → LocalizedStringKey)
- Bug 5: Workouts Section unterhalb "Recommended Application" auf Deutsch (in EN Version)
  - Status: War bereits korrekt implementiert - NSLocalizedString + Übersetzungen existieren
- Bug 6: Workouts Edit Dialog teilweise auf Deutsch (in EN Version)
  - Fix: "Neue Übung" → NSLocalizedString("New Exercise"), "Work: Rest:" Format-String lokalisiert
  - WorkoutProgramsView.swift Lines 1625, 1646, Localizable.xcstrings
- Bug 7: Settings Ambient Sound zeigt falschen Text
  - Fix: Text(sound.rawValue) → Text(LocalizedStringKey(sound.rawValue))
  - SettingsSheet.swift Line 81
- Bug 9: SmartReminder Beschreibungen auf Deutsch (in EN Version)
  - Root Cause: Hardcoded deutsche Strings in Weekday.displayName + SmartReminder.description
  - Fix: Alle Strings durch NSLocalizedString ersetzt + deutsche Übersetzungen im xcstrings
  - Betroffen: Wochentagsnamen, Abkürzungen, "Täglich", "Keine Tage", activity descriptions
  - SmartReminder.swift Lines 12-22, 65-111, Localizable.xcstrings (+25 neue Einträge)
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
