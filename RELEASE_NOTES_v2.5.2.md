# Release Notes - Version 2.5.2

**Veröffentlichungsdatum:** 25. Oktober 2025
**Branch:** main
**Vorherige Version:** v2.5.1
**Typ:** Patch Release

## 🐛 Behobene Bugs

### 📊 Kalender- und Streaks-Filterung
- **HealthKit-Filterung repariert:** Kalender und Streaks zeigen jetzt nur noch app-spezifische Sessions an
- **Quelle-basierte Filterung:** Verwendet `HKSource.default()` um nur eigene App-Daten zu berücksichtigen
- **Streaks-Reset:** Alte gespeicherte Streaks werden beim App-Start zurückgesetzt und neu berechnet
- **UI-Updates:** Streak-Anzeige wird korrekt aktualisiert nach Neuberechnung

### 🔧 Technische Details
- Neue Methoden in `HealthKitManager`: `fetchActivityDaysDetailedFiltered()` und `fetchDailyMinutesFiltered()`
- `StreakManager` verwendet jetzt gefilterte Daten für alle Berechnungen
- `CalendarView` lädt Streaks beim Erscheinen neu
- `ContentView` triggert UI-Updates nach Streak-Neuberechnung

## 📝 Bekannte Probleme
- HealthKit-Integration muss noch auf echten iOS-Geräten getestet werden

## 🔄 Upgrade-Anweisungen
- Keine speziellen Schritte erforderlich - App aktualisiert Streaks automatisch beim nächsten Start