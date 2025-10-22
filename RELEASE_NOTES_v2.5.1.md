# Release Notes - Version 2.5.1

**Veröffentlichungsdatum:** 22. Oktober 2025  
**Branch:** feature/calendar-stats  
**Vorherige Version:** v2.5  

## 🎉 Neue Features

### 📊 Statistiken & Kalender
- **Monatskalender:** Vollständiger, scrollbarer Kalender mit visueller Darstellung des täglichen Fortschritts
- **Aktivitäts-Ringe:** Konzentrische Kreise um Tageszahlen zeigen Zielerfüllung an
  - Innerer blauer Ring: Meditation-Fortschritt
  - Äußerer violetter Ring: Workout-Fortschritt
- **Filter:** Nur Aktivitäten >= 2 Minuten werden angezeigt (konsistent mit Streak-Logik)
- **Popover-Details:** Tippen auf einen Tag zeigt genaue Minuten und Ziele
- **Ziel-Setting:** Konfigurierbare tägliche Ziele für Meditation und Workouts in den Einstellungen

### 🔥 Streaks & Belohnungen
- **Streak-Verfolgung:** Aufeinanderfolgende Tage mit mindestens 2 Minuten Aktivität
- **Separate Streaks:** Unabhängige Zählung für Meditation und Workouts
- **Belohnungssystem:** 
  - Meditation: Lotus-Blüten (max. 3) nach je 7 Tagen
  - Workouts: Flammen (max. 3) nach je 7 Tagen
- **Freischuss-Mechanik:** Bei verpassten Tagen wird eine Belohnung entfernt, aber Streak bleibt erhalten
- **UI-Integration:** Streak-Anzeige im Kalender-Footer mit Info-Popover

## 🔧 Technische Verbesserungen
- **Thread-Safety:** Streak-Updates laufen jetzt auf MainActor zur Vermeidung von UI-Problemen
- **Code-Organisation:** Bereinigung von Duplicate-Dateien und Target-Management
- **Performance:** Optimierte HealthKit-Abfragen für bessere Darstellung

## 🐛 Behobene Bugs
- Kalender-Ringe wurden für alle Aktivitäten angezeigt (jetzt nur >= 2 Minuten)
- Threading-Issues bei Streak-Berechnung behoben
- Duplicate StreakManager-Datei entfernt

## 📱 Kompatibilität
- **iOS:** 15.0+
- **watchOS:** 8.0+
- **HealthKit:** Erforderlich für vollständige Funktionalität

## 📝 Bekannte Einschränkungen
- Streak-Berechnung basiert auf HealthKit-Daten (lokale Sessions werden nicht gezählt)
- Kalender zeigt nur Daten ab dem Zeitpunkt der ersten Nutzung

## 🔄 Migration
Keine speziellen Migrationsschritte erforderlich. Bestehende User-Daten bleiben erhalten.

---

*Diese Version markiert den Abschluss der Statistiken- und Streaks-Features. Vielen Dank für Ihr Feedback und Ihre Geduld während der Entwicklung!* 🚀</content>
<parameter name="filePath">/Users/hem/Documents/opt/Meditationstimer/Meditationstimer/RELEASE_NOTES_v2.5.1.md