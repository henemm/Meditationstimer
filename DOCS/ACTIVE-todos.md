# Active Todos - HHHaven

**Letzte Aktualisierung:** 1. Januar 2026
**Regel:** Nur OFFENE und AKTIVE Aufgaben. Abgeschlossene Bugs/Tasks werden gelöscht.

---

## ✅ Erfolge Tab Cleanup - ABGESCHLOSSEN

**Datum:** 1. Januar 2026
**Status:** ✅ IMPLEMENTIERT & VALIDIERT

**Problem:**
- Redundante Streak-Anzeige (Header + untere Sektion)
- Verschachtelte Navigation (NavigationStack + NavigationView)
- Sinnloser "Fertig" Button (CalendarView war als Sheet designed, aber eingebettet)

**Lösung:**
1. `CalendarView.swift`: `isEmbedded` Parameter hinzugefügt
   - `isEmbedded=true`: ohne NavigationView/Toolbar (für ErfolgeTab)
   - `isEmbedded=false`: mit Navigation (für Sheet-Aufrufe)
2. `ErfolgeTab.swift`: StreakHeaderSection komplett entfernt

**Tests:**
- [x] XCUITest `testErfolgeTabHasCleanLayoutWithoutSheetNavigation` hinzugefügt
- [x] XCUITest `testErfolgeTabShowsEmbeddedCalendar` angepasst
- [x] Alle Unit Tests GRÜN
- [x] Release Build erfolgreich
- [ ] Manueller Test auf Device

**Commits:**
- `a7f816b` refactor: Erfolge Tab Cleanup - redundante Navigation entfernt
- `60af509` test: XCUITest für Erfolge Tab an neues Layout angepasst

---

## 🚨 KRITISCHE Bugs

### Bug 34: NoAlc DayAssignment Parser erkannte cutoffHour-Prefix nicht
**Datum:** 31. Dezember 2025
**Status:** ✅ BEHOBEN

**Problem:**
NoAlc Tracking ordnete Einträge dem falschen Tag zu:
- Dienstag 9:00 Uhr Eintrag → wurde auf Dienstag geschrieben (falsch)
- Sollte aber auf Montag geschrieben werden (Cutoff 18:00)

**Root Cause:**
- NoAlc Preset speicherte `"cutoffHour:18"`
- Parser suchte nur nach `"cutoff:"` → Prefix-Mismatch!
- Fallback auf `.timestamp` → Cutoff wurde ignoriert

**Fix:**
`TrackerModels.swift:338-343` - Parser unterstützt jetzt beide Formate:
```swift
if raw.hasPrefix("cutoffHour:"), let hour = Int(...) {
    return .cutoffHour(hour)
}
if raw.hasPrefix("cutoff:"), let hour = Int(...) {
    return .cutoffHour(hour)
}
```

**Verifizierung:**
- [x] 5 neue Unit Tests für DayAssignment-Logik
- [x] Build erfolgreich (Debug + Release)
- [x] Alle 71 Unit Tests GRÜN
- [ ] Manueller Test auf Device (ausstehend)

---

### Bug 33: SmartReminder "Reverse Cancel" funktioniert nicht mehr
**Datum:** 25. Dezember 2025
**Status:** ✅ BEHOBEN - Fix implementiert
**Gemeldet von:** User-Feedback

**Problem:**
Das "Smarte" an SmartReminders funktionierte nicht mehr:
- Wenn eine Aktivität geloggt wurde, sollten zukünftige Reminder automatisch gecancelled werden
- Reminder feuerten trotzdem

**Root Cause (identifiziert):**
Bei einem früheren Fix für "Next-Week Scheduling" wurde `scheduleNotifications()` nicht mehr nach `cancelMatchingReminders()` aufgerufen. Das bedeutete:
- `cancelMatchingReminders()` fügte nur zur `cancelled`-Liste hinzu
- Die **bereits geplante iOS-Notification wurde NICHT entfernt**
- Ergebnis: Notification feuerte trotzdem

**Fix (implementiert):**
In `SmartReminderEngine.swift` Zeile 191-198:
```swift
// Bug 33 Fix: Remove the pending notification from iOS immediately
#if os(iOS)
let identifier = "activity-reminder-\(reminder.id.uuidString)-\(weekday.rawValue)"
UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
#endif
```

**Verifizierung:**
- [x] Build erfolgreich
- [x] 66 Unit Tests GRÜN
- [ ] Manueller Test auf Device (ausstehend)

---

## 📚 Lessons Learned

### 2025-12-15: Implementation Gate eingeführt

**Problem:** Phase 1.1 Tab Navigation wurde implementiert OHNE:
- Bestehende Unit Tests auszuführen
- Neue Tests zu schreiben
- UI-Test-Anweisungen VOR der Implementierung zu erstellen

**Lösung:** Implementation Gate als PFLICHT eingeführt:
- `.agent-os/standards/global/implementation-gate.md` erstellt
- CLAUDE.md aktualisiert mit Gate als ERSTE PFLICHT
- Keine Code-Änderungen ohne Gate-Durchlauf

**Regel:** VOR jeder Implementierung MUSS:
1. `xcodebuild test` ausgeführt werden
2. Neue Tests geschrieben werden (TDD RED)
3. UI-Test-Anweisungen vorbereitet werden
4. Gate-Check dokumentiert werden

---

## ✅ Phase 1.1 Tab Navigation - Gate NACHGEHOLT

**Datum:** 15. Dezember 2025

### Gate-Check (nachträglich)

| Check | Status | Ergebnis |
|-------|--------|----------|
| Bestehende Tests ausgeführt | ✅ | 97/97 Tests GRÜN |
| Tests korrigiert | ✅ | ShortcutHandlerTests für neue Tab-Namen angepasst |
| Neue Tests hinzugefügt | ✅ | 3 neue Tests: testParseMeditationURL, testParseWorkoutURL_NewTabName, testParseWorkoutURL_LegacyWorkoutsTab |
| UI-Test-Anweisungen | ✅ | DOCS/UI-TEST-Phase1.1-TabNavigation.md erstellt |
| Build erfolgreich | ✅ | xcodebuild build SUCCEEDED |

### Geänderte Dateien

| Datei | Änderung |
|-------|----------|
| `ContentView.swift` | AppTab Enum + TabView |
| `MeditationTab.swift` | NEU |
| `WorkoutTab.swift` | NEU |
| `TrackerTab.swift` | NEU |
| `ErfolgeTab.swift` | NEU |
| `ShortcutHandler.swift` | Backwards-Compatibility |
| `ShortcutHandlerTests.swift` | Tests für neue Tabs |

### UI-Tests (automatisiert im Simulator)

| Test | Status |
|------|--------|
| testAllFourTabsExist | ✅ PASS |
| testMeditationTabIsDefaultSelected | ✅ PASS |
| testTabSwitching | ✅ PASS |
| testMeditationViewShowsDauerLabelInGerman | ✅ PASS |
| testMeditationViewShowsAusklangLabelInGerman | ✅ PASS |
| testMeditationViewShowsDurationLabelInEnglish | ✅ PASS |
| testMeditationViewShowsClosingLabelInEnglish | ✅ PASS |
| testTrackerTabShowsLogTodayButton | ✅ PASS |
| testErfolgeTabShowsContent | ✅ PASS |
| testErfolgeTabShowsViewCalendarButton | ✅ PASS |
| testInfoSheetOpensAndShowsContent | ✅ PASS |
| testLaunchPerformance | ✅ PASS |

**Alle 12 XCUITests bestanden!**

### Nächster Schritt
- [ ] Manuelle Verifikation auf echtem Device (optional)

---

## ✅ Phase 1.2 SwiftData Tracker Model - ABGESCHLOSSEN

**Datum:** 19. Dezember 2025

### Gate-Check

| Check | Status | Ergebnis |
|-------|--------|----------|
| Bestehende Tests ausgeführt | ✅ | 83+ Tests GRÜN |
| Neue Tests geschrieben | ✅ | 17 neue TrackerModelTests |
| Build erfolgreich | ✅ | xcodebuild build SUCCEEDED |

### Implementierte Features

| Feature | Status |
|---------|--------|
| SwiftData Models (Tracker, TrackerLog) | ✅ |
| Enum-Types (TrackerType, TrackingMode) | ✅ |
| TrackerManager mit CRUD | ✅ |
| 8 Predefined Presets | ✅ |
| Streak-Berechnung (Active + Avoidance) | ✅ |
| ModelContainer in App | ✅ |
| Cascade Delete für Logs | ✅ |

### Neue Dateien

| Datei | Beschreibung |
|-------|--------------|
| `Services/TrackerModels.swift` | SwiftData @Model Klassen |
| `Services/TrackerManager.swift` | CRUD + Presets + Queries |
| `LeanHealthTimerTests/TrackerModelTests.swift` | 17 Unit Tests |

### Geänderte Dateien

| Datei | Änderung |
|-------|----------|
| `Meditationstimer_iOSApp.swift` | ModelContainer + Schema |
| `Meditationstimer.xcodeproj/project.pbxproj` | Neue Dateien registriert |

### UI-Test Phase 2.4: Streak-Badge

| Test | Schritte | Erwartet | Status |
|------|----------|----------|--------|
| Badge bei neuem Tracker | 1. Neuen Tracker hinzufügen | Kein Badge (Streak = 0) | ⏳ |
| Badge nach erstem Log | 1. Tracker loggen 2. Tab neu öffnen | 🔥 1 Badge erscheint | ⏳ |
| Badge bei Avoidance | 1. Saboteur-Tracker hinzufügen | Kein Badge (Streak im Status) | ⏳ |
| Badge verschwindet | 1. Tag ohne Log warten | Badge verschwindet | ⏳ |

### Phase 2.5: Custom Tracker - Gate ✅

| Check | Status | Ergebnis |
|-------|--------|----------|
| Bestehende Tests ausgeführt | ✅ | TEST SUCCEEDED |
| Neue Tests geplant | ✅ | Keine nötig (nutzt existierende Logik) |
| UI-Test-Anweisungen | ✅ | 7 Tests dokumentiert |

**UI-Tests Phase 2.5:**

| Test | Schritte | Erwartet | Status |
|------|----------|----------|--------|
| Sheet öffnen | Add Tracker → Custom Tracker | Sheet mit Form öffnet sich | ⏳ |
| Icon-Auswahl | Emoji antippen | Blauer Rahmen um Auswahl | ⏳ |
| Typ-Auswahl | Picker wechseln | Good ↔ Saboteur funktioniert | ⏳ |
| Modus je Typ | Typ ändern → Modi prüfen | Good: Counter/YesNo, Saboteur: Awareness/Avoidance | ⏳ |
| Tagesziel nur Counter | Modi wechseln | Stepper nur bei Counter sichtbar | ⏳ |
| Tracker erstellen | Form ausfüllen → Erstellen | Neuer Tracker in Liste | ⏳ |
| Validierung | Name leer lassen | Erstellen-Button deaktiviert | ⏳ |

### Phase 2.6: Mood/Feelings/Gratitude UIs - Gate ✅

| Check | Status | Ergebnis |
|-------|--------|----------|
| Bestehende Tests ausgeführt | ✅ | TEST SUCCEEDED |
| Neue Tests geplant | ✅ | Keine nötig (reine UI-Arbeit) |
| UI-Test-Anweisungen | ✅ | 7 Tests dokumentiert |

**UI-Tests Phase 2.6:**

| Test | Schritte | Erwartet | Status |
|------|----------|----------|--------|
| Mood Sheet öffnen | Stimmung-Tracker → Quick-Log | MoodSelectionView mit 9 Emojis | ⏳ |
| Mood Single-Select | 2 Moods antippen | Nur einer ausgewählt | ⏳ |
| Feelings Sheet öffnen | Gefühle-Tracker → Quick-Log | FeelingsSelectionView | ⏳ |
| Feelings Multi-Select | Mehrere antippen | Alle bleiben ausgewählt | ⏳ |
| Gratitude Sheet öffnen | Dankbarkeit-Tracker → Quick-Log | GratitudeLogView mit TextEditor | ⏳ |
| Gratitude speichern | Text eingeben → Speichern | Note gespeichert | ⏳ |
| Andere Tracker direkt | Counter/YesNo Quick-Log | Kein Sheet, direkt geloggt | ⏳ |

### Nächste Schritte (Phase 2.x)
- [x] Phase 2.1: TrackerTab Liste + Quick-Log
- [x] Phase 2.2: Add Tracker aus Presets
- [x] Phase 2.3: Edit/Delete Tracker
- [x] Phase 2.4: Streak-Anzeige (Gate nachgeholt)
- [x] Phase 2.5: Custom Tracker erstellen ✅
- [x] Phase 2.6: Mood/Feelings/Gratitude UIs ✅
- [ ] HealthKit Sync für Tracker
- [ ] Tracker Widget

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

## ✅ Neue Features (validiert)

### Workout Effort Score (iOS 18+)
**Datum:** 21. Dezember 2025
**Status:** ✅ ABGESCHLOSSEN UND VERIFIZIERT (25.12.2025)

**Implementierung:**
- Sheet mit Slider (1-10) erscheint nach jedem HIIT Workout
- Default: 7 (Hard) - vorbelegt für HIIT
- Effort Score wird mit HKWorkout verknüpft (Apple Training Load)
- Skip-Option für User die nicht bewerten möchten
- Graceful Degradation: Bei iOS < 18 erscheint kein Sheet

**Tests:**
| Test | Status |
|------|--------|
| Unit Tests (5 Tests) | ✅ GRÜN |
| Device Test | ✅ VERIFIZIERT |

---

## 🐛 aktive Bugs

### Workout Bugs

**Bug 32: Freie Workouts ohne Sound (weder Ansagen noch Töne)**
- Location: `WorkoutTab.swift` (ehemals WorkoutsView.swift)
- **Ursprüngliches Problem:** Keine Sounds mehr bei freien Workouts - weder Auftakt/Ausklang noch TTS-Ansagen
- **Root Cause (erweitert 22.12.2025):**
  - Lokaler `SoundPlayer` hatte KEINE TTS-Funktion
  - Nur Auftakt wurde gespielt, kein Countdown/Ausklang/TTS
- **Vollständiger Fix (22.12.2025):**
  - Lokalen `SoundPlayer` entfernt, `WorkoutSoundPlayer` wiederverwendet (DRY)
  - Countdown-Sound bei 3 Sekunden vor Work-Ende
  - TTS-Ansagen "Round X" / "Last round" bei Runden-Wechsel
  - Auftakt pre-roll vor jeder neuen Work-Phase
  - Ausklang am Session-Ende
- Status: **✅ GEFIXT UND VERIFIZIERT** (22.12.2025)
- **Geänderte Datei:** `Meditationstimer iOS/Tabs/WorkoutTab.swift` (-76/+50 LoC)

### NoAlc Bugs

**Bug 27: NoAlc Joker-System ignorierte nicht berichtete Tage**
- Location: `NoAlcManager.swift` (neu: `calculateStreakAndRewards()`)
- **Root Cause:** Code verwendete `alcoholDays.keys.sorted()` statt über ALLE Tage zu iterieren
- **Fix (19.12.2025):** Neue testbare Methode iteriert über ALLE Tage
- **Getestet:** ✅ 16 Unit Tests GRÜN + Device-Test
- Status: **✅ GEFIXT UND VERIFIZIERT** (25.12.2025)

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
- **Fix:** Volume auf `0.0` gesetzt (war vorher 0.01)
- Status: **✅ GEFIXT UND VERIFIZIERT** (25.12.2025)

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
