# Aktuelle Todo-Liste - Meditationstimer

## ✅ Abgeschlossene Todos

- **Timer Stopp nach Beenden testen**
  - Teste, dass Timer und Live Activity nach 'Beenden' garantiert gestoppt werden
  - *Status: Abgeschlossen*

- **Persistente Einstellungen Workouts Tab**
  - Füge @AppStorage für Belastung, Erholung, Wiederholungen hinzu
  - *Status: Abgeschlossen*

- **Persistente Presets Atem Tab**
  - Erweitere Preset um Codable, speichere als JSON in UserDefaults
  - *Status: Abgeschlossen*

- **Ring-Animationen vereinheitlichen**
  - Alle Ringe auf 0.05s Updates für sanfte Animationen
  - *Status: Abgeschlossen*

- **Live Activity Atem-Phasen synchronisieren**
  - Implementiere Live Activity Synchronisation mit Atem-Phasen (Einatmen/Halten/Ausatmen Icons)
  - *Status: Abgeschlossen*

- **Statistiken**
  - Übersicht über Sitzungen, Dauer, Häufigkeit
  - *Status: Abgeschlossen*

- **Live Activity Ownership prüfen**
  - Validiere, dass nur eine Live Activity gleichzeitig im Widget erscheint
  - *Status: Abgeschlossen*

- **End-to-End Test Atem-Session**
  - Teste komplette Atem-Session mit Live Activity im Simulator
  - *Status: Abgeschlossen*

- **Streaks**
  - Verfolgung von aufeinanderfolgenden Tagen mit Meditation und Workouts mit Belohnungssystem
  - *Status: Abgeschlossen*

- **Live Preview (Canvas) stability final check**
  - *Status: Erledigt*

- **Dynamic Island final variant decision**
  - *Status: Erledigt*

- **Optional debug switch for ending all Live Activities**
  - *Status: Erledigt*

- **Minor UX polish for lock screen and expanded views**
  - *Status: Erledigt*

- **Konsolidierung von Duplikaten (Technische Schulden)**
  - LiveActivityController und CalendarView Duplikate entfernt, Single Source of Truth etabliert
  - API-Deprecations behoben (Activity.endAll() → Activity.activities Loop)
  - Build-Stabilität wiederhergestellt
  - *Status: Abgeschlossen*

- **Unit-Tests hinzufügen**
  - Unit-Tests für kritische Komponenten wie Timer-Logik, HealthKit-Integration und Datenmodelle implementieren
  - 58+ Test-Fälle erstellt für TwoPhaseTimerEngine, StreakManager, HealthKitManager
  - Test-Dateien in `Tests/` Verzeichnis, müssen noch zum Xcode Test-Target hinzugefügt werden
  - *Status: Abgeschlossen* ✅


## 🐛 Bugs (gefunden am 25. Oktober 2025)

- **Bug 1: Gong wird am Ende der Session abgeschnitten (Offen-Tab)** ✅
  - **Wo:** OffenView, finaler End-Gong ("gong-ende")
  - **Problem:** Der End-Gong wird vorzeitig abgebrochen, klingt nicht vollständig aus
  - **Ursache:** `resetSession()` wurde sofort nach Gong-Start aufgerufen und hat `bgAudio.stop()` sofort ausgeführt, obwohl der Gong noch spielte
  - **Root Cause:** In `endSession()` wurde `resetSession()` am Ende aufgerufen, während der Gong-Completion-Handler bereits eine verzögerte Audio-Stop-Aufgabe schedulte. Die sofortige resetSession()-Ausführung hat die verzögerte Aufgabe überschrieben und Audio gestoppt.
  - **Location:** `OffenView.swift:endSession()`
  - **Lösung:** `resetSession(stopAudio: false)` aufrufen, damit Audio vom Gong-Completion-Handler gestoppt wird
  - **Änderungen:**
    - `resetSession()` erhält Parameter `stopAudio: Bool = true`
    - `endSession()` ruft `resetSession(stopAudio: false)` auf
    - Gong-Completion-Handler stoppt Audio nach Gong-Duration + 0.5s Safety-Delay
  - *Priorität: Mittel*
  - *Status: Behoben durch User-Test* (26.10.2025)

- **Bug 2: Smart Reminder Zeit lässt sich nicht ändern** ✅
  - **Wo:** Smart Reminders Settings
  - **Problem:** Wenn man die Uhrzeit eines Beispiel-Reminders ändert, springt sie sofort zurück
  - **Ursache:** Beispiel-Reminders werden nur in der UI geladen (`SmartRemindersView.swift:87`), aber **nicht** in die Engine gespeichert. `updateReminder()` versucht, einen nicht-existenten Reminder in der Engine zu updaten
  - **Location:** `SmartRemindersView.swift:83-94`
  - **Lösung:** Beim ersten App-Start Beispieldaten in die Engine speichern (for-loop in loadReminders)
  - *Priorität: Hoch*
  - *Status: Behoben* (25.10.2025)

- **Bug 3: Smart Reminders komplett neu implementiert** ✅
  - **Was wurde gemacht:**
    - Komplettes Redesign von SmartReminderEngine mit korrekter Scheduling-Logik
    - Wochentage-Prüfung hinzugefügt
    - Look-back Berechnung von NOW (nicht triggerStart) korrigiert
    - Permission-Handling (Notifications, Background Refresh, HealthKit)
    - Toggle disabled wenn Permissions fehlen
    - Test-Button entfernt (wie gewünscht)
    - Beispieldaten werden jetzt persistent in Engine gespeichert
  - **Änderungen:**
    - `SmartReminderEngine.swift` - Komplett neu geschrieben (350 Zeilen)
    - `SmartRemindersView.swift` - Permission-Handling UI hinzugefügt
  - **User-Test-Ergebnis (26.10.2025):**
    - ❌ App erscheint NICHT in iOS Settings → Hintergrundaktualisierung
    - ❌ Permission-Check zeigt fälschlicherweise grünes Häkchen
    - **Root Cause:** Background Modes NICHT in Xcode Capabilities konfiguriert
  - **Lösung:**
    - Background Modes in Xcode Target → Signing & Capabilities aktiviert
    - UIBackgroundModes und BGTaskSchedulerPermittedIdentifiers waren bereits in Info.plist vorhanden
    - App erscheint jetzt korrekt in iOS Settings → Hintergrundaktualisierung
  - *Priorität: Hoch*
  - *Status: Behoben* (27.10.2025)

- **Bug 4: Display schaltet sich bei Workouts aus** ✅
  - **Wo:** Workouts-Tab (und Atem-Tab)
  - **Problem:** Das Display schaltet sich während eines Workouts aus (Idle Timer ist aktiv)
  - **Ursache:** WorkoutsView und AtemView setzen `UIApplication.shared.isIdleTimerDisabled` nicht, nur OffenView macht das
  - **Location:** `WorkoutsView.swift` (fehlt), `AtemView.swift` (fehlt), `OffenView.swift:407-410` (funktioniert)
  - **Lösung:** Idle Timer in WorkoutsView und AtemView deaktivieren während Session läuft
  - *Priorität: Hoch*
  - *Status: Behoben durch User-Test* (26.10.2025)

- **Bug 5: Countdown-Sounds am Ende der Belastung fehlen (Workouts)** ✅
  - **Wo:** Workouts-Tab, Ende der Belastungsphase
  - **Problem:** Soll 3x "kurz" Sound im Sekundentakt (bei -3s, -2s, -1s), aber nur 1-2x hörbar (je länger die Phase, desto weniger Beeps)
  - **Root Cause (GEFUNDEN):** `onChange(fractionPhase >= 1.0)` akkumuliert TimelineView-Drift proportional zur Phase-Dauer
    - 10s Phase: ~200 Updates × 1-5ms = ~0.2s Drift → Trigger bei T+10.2s → Beep 3 (T+9s) fertig ✅
    - 30s Phase: ~600 Updates × 1-5ms = ~0.6s Drift → Trigger bei T+29.4s → Beep 3 (T+29s) noch nicht gefeuert ❌
    - **Console-Logs beweisen:** Dritter Beep wird NACH `.lang` gescheduled (Race Condition)
  - **Location:** `WorkoutsView.swift:313-322` (onChange Trigger), `WorkoutsView.swift:545-558` (Countdown-Scheduling)
  - **Fix-Versuch 1 (FEHLGESCHLAGEN):**
    - SoundPlayer mit URL-Caching und activePlayers Array
    - **User-Test:** Nur 1 Beep hörbar
  - **Fix-Versuch 2 (FEHLGESCHLAGEN):**
    - Separate `countdownSounds` Array (nicht mit scheduled gekoppelt)
    - **User-Test:** Bei 20s/30s nur 1-2 Beeps statt 3
    - **Console Logs:** Dritter Beep spielt NACH `.lang` (falsches Timing)
  - **Fix-Versuch 3 (verworfen):**
    - Countdown-Beeps 1 Sekunde früher schedulen
    - Problem: Als "gebastelt" verworfen, aber richtige Idee
  - **Fix-Versuch 4 (FEHLGESCHLAGEN):**
    - **Ansatz:** UI-Trigger von Business-Logik getrennt (Best Practice)
    - `onChange(fractionPhase)` entfernt, Phase-Ende via `DispatchQueue.asyncAfter`
    - **Console Logs:** Alle 3 Sounds feuern korrekt
    - **User-Test (30s):** KEINE VERBESSERUNG - Audio-Problem lag woanders
    - **Revert:** onChange wieder eingefügt, DispatchQueue-Scheduling entfernt
  - **Fix-Versuch 5 (ERFOLGREICH - Drift-Kompensation):**
    - **Ansatz:** Beeps 1 Sekunde früher schedulen (T-4, T-3, T-2 statt T-3, T-2, T-1)
    - **Rationale:** Kompensiert onChange-Drift, dritter Beep feuert VOR frühem advance() Trigger
    - **Constraints:** Nur bei dur>=5s (sonst nicht genug Zeit für 3 Beeps)
    - **Changes:** `WorkoutsView.swift:545-558` - Countdown-Logik angepasst
  - *Priorität: Mittel*
  - *Status: Behoben durch User-Test* (27.10.2025)

## 🎨 Design & UX

- **Liquid Glass Design-Audit durchführen**
  - App analysieren auf iOS 18+ "Liquid Glass" Design Language
  - Bereiche identifizieren, die modernisiert werden können:
    - Ultra-thin materials & Glassmorphismus
    - Smooth spring animations
    - Vibrancy & Depth-Effekte
    - Spatial Design
  - Konkrete Verbesserungsvorschläge ausarbeiten
  - *Priorität: Niedrig*
  - *Status: Backlog*

## 🎨 UI/UX Modernisierung - Liquid Glass Design

- **Einheitliche View-Transitions implementieren** (iOS 18 Liquid Glass)
  - **Analyse abgeschlossen:** Siehe `DOCS/view-transitions-analysis.md`
  - **Hauptproblem:** Drei verschiedene Präsentations-Patterns für Session-Runner
  - **Ziel:** Einheitliches Verhalten nach Liquid Glass Guidelines

  **Kategorien definiert:**
  1. **Play-Views** (Session-Runner): Offen, Atem, Workouts
  2. **Modal Sheets**: Settings, Calendar
  3. **Sub-Sheets**: Editors (Presets, Reminders)

  **Kritische Inkonsistenzen:**
  - ❌ WorkoutsView: Verwendet `.fullScreenCover` statt Overlay-Pattern
  - ❌ OffenView: Overlay ohne Transition-Animation
  - ✅ AtemView: **Best Practice** - Custom overlay mit `.scale+.opacity`

  **High Priority Fixes:**
  1. WorkoutsView → Replace `.fullScreenCover` mit Overlay-Pattern (~80 LOC)
  2. OffenView → Add `.scale+.opacity` transition animation (~30 LOC)
  3. Alle `NavigationView` → `NavigationStack` (3 Stellen, ~20 LOC)
  4. AtemView Animation → `.easeInOut` zu `.smooth` (~2 LOC)

  **Medium Priority:**
  5. OffenView Background → Blur + Saturation wie AtemView
  6. Presentation Backgrounds → `.ultraThinMaterial` für Sheets

  **Standard-Pattern (AtemView-Basis):**
  ```swift
  // Overlay transition
  .scale.combined(with: .opacity)
  .animation(.smooth(duration: 0.3))

  // Background effect
  .blur(radius: 6)
  .saturation(0.95)
  .brightness(-0.02)
  ```

  - *Priorität: Hoch*
  - *Status: Analysiert, bereit zur Implementation*
  - *Geschätzte Änderungen: ~137 LOC über 7 Dateien*

## 🔧 Sonstige Todos

- **Test-Target in Xcode einrichten**
  - Neues iOS Unit Testing Bundle erstellen (MeditationstimerTests)
  - Test-Dateien aus Tests/ zum Target hinzufügen
  - Tests ausführen und verifizieren
  - *Status: Offen*

- **HealthKit re-testing on device**
  - *Status: Offen*

## 🎨 UI-Verbesserungen (27. Oktober 2025)

- **Settings Navigation Modernisierung** ✅
  - Settings von `.navigationDestination` zu `.fullScreenCover` geändert (alle 3 Tabs)
  - "Fertig"-Button oben rechts hinzugefügt
  - Settings liegen jetzt vollflächig über TabBar
  - *Status: Abgeschlossen* (27.10.2025)

- **X-Button Position WorkoutsView** ✅
  - Overlay von VStack auf ZStack verschoben (konsistent mit AtemView)
  - Button jetzt ganz oben rechts positioniert
  - *Status: Abgeschlossen* (27.10.2025)

- **WorkoutRunnerView Safe Area** ✅
  - `.ignoresSafeArea()` entfernt von WorkoutRunnerView
  - X-Button jetzt klickbar (nicht mehr unter Dynamic Island)
  - Nur Background ignoriert Safe Area (konsistent mit AtemView)
  - *Status: Abgeschlossen* (27.10.2025)

- **Toolbar/TabBar Hiding während Sessions** ✅
  - TabBar versteckt während Sessions (alle 3 Tabs)
  - Kalender/Settings Buttons konditionell angezeigt (nicht mehr .toolbar(.hidden))
  - Verhindert Tab-Wechsel während aktiver Session
  - *Status: Abgeschlossen* (27.10.2025)

- **WorkoutsView Ringe Farbe** ✅
  - CircularRing: Neuer optionaler `gradient` Parameter hinzugefügt
  - WorkoutsView: Ringe jetzt korrekt in workoutViolet
  - OffenView/AtemView: Unverändert (blue/cyan default)
  - *Status: Abgeschlossen* (27.10.2025)

## 📝 Notizen

- Letzte Aktualisierung: 27. Oktober 2025
- Test-Suite mit 58+ Tests erstellt am 25. Oktober 2025
- Test-Dateien: TwoPhaseTimerEngineTests.swift, StreakManagerTests.swift, HealthKitManagerTests.swift
- Siehe CLAUDE.md für Details zur Test-Einrichtung und Ausführung
- 5 Bugs analysiert und dokumentiert am 25. Oktober 2025
- UI-Verbesserungen und Konsistenz-Fixes am 27. Oktober 2025