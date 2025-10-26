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

- **Bug 1: Gong wird am Ende der Session abgeschnitten (Offen-Tab)**
  - **Wo:** OffenView, finaler End-Gong ("gong-ende")
  - **Problem:** Der End-Gong wird vorzeitig abgebrochen, klingt nicht vollständig aus
  - **Ursache:** `BackgroundAudioKeeper.stop()` deaktiviert die Audio-Session (`AVAudioSession.setActive(false)`) nur 0.5s nach Gong-Start, während der Gong noch spielt
  - **Location:** `OffenView.swift:431-438`, `BackgroundAudioKeeper.swift:41-44`
  - **Lösung:** Warte bis Gong-Duration vollständig abgelaufen ist, bevor Audio-Session deaktiviert wird
  - *Priorität: Mittel*
  - *Status: Offen*

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
  - *Priorität: Hoch*
  - *Status: Code implementiert, Build erfolgreich, wartet auf Device-Test* (26.10.2025)

- **Bug 4: Display schaltet sich bei Workouts aus**
  - **Wo:** Workouts-Tab (und Atem-Tab)
  - **Problem:** Das Display schaltet sich während eines Workouts aus (Idle Timer ist aktiv)
  - **Ursache:** WorkoutsView und AtemView setzen `UIApplication.shared.isIdleTimerDisabled` nicht, nur OffenView macht das
  - **Location:** `WorkoutsView.swift` (fehlt), `AtemView.swift` (fehlt), `OffenView.swift:407-410` (funktioniert)
  - **Lösung:** Idle Timer in WorkoutsView und AtemView deaktivieren während Session läuft
  - *Priorität: Hoch*
  - *Status: Code implementiert, wartet auf User-Test* (26.10.2025)

- **Bug 5: Countdown-Sounds am Ende der Belastung fehlen (Workouts)**
  - **Wo:** Workouts-Tab, Ende der Belastungsphase
  - **Problem:** Soll 3x "kurz" Sound im Sekundentakt (bei -3s, -2s, -1s), aber nur 1x hörbar
  - **Ursache:** `SoundPlayer` verwendet nur **einen** `AVAudioPlayer` pro Cue-Typ. Beim zweiten `play(.kurz)` Aufruf wird `currentTime = 0` gesetzt und der laufende Sound zurückgesetzt/abgebrochen
  - **Location:** `WorkoutsView.swift:107-116` (SoundPlayer.play Methode)
  - **Lösung:** Für parallele Wiedergabe: Erstelle neue AVAudioPlayer-Instanzen statt gleichen Player wiederzuverwenden, oder halte Pool von Playern vor
  - *Priorität: Mittel*
  - *Status: Offen*

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

## 🔧 Sonstige Todos

- **Test-Target in Xcode einrichten**
  - Neues iOS Unit Testing Bundle erstellen (MeditationstimerTests)
  - Test-Dateien aus Tests/ zum Target hinzufügen
  - Tests ausführen und verifizieren
  - *Status: Offen*

- **HealthKit re-testing on device**
  - *Status: Offen*

## 📝 Notizen

- Letzte Aktualisierung: 25. Oktober 2025
- Test-Suite mit 58+ Tests erstellt am 25. Oktober 2025
- Test-Dateien: TwoPhaseTimerEngineTests.swift, StreakManagerTests.swift, HealthKitManagerTests.swift
- Siehe CLAUDE.md für Details zur Test-Einrichtung und Ausführung
- 5 Bugs analysiert und dokumentiert am 25. Oktober 2025