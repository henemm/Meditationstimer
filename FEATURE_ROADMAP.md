# Meditationstimer Feature Roadmap

## Übersicht
Dieses Dokument fasst die geplanten Features für die Meditationstimer-App zusammen. Basierend auf User-Feedback wurden die Ideen detailliert ausgearbeitet und priorisiert.

**Erstellt am:** 20. Oktober 2025  
**Status:** Planungsphase

## ✅ Abgeschlossene Features (für Kontext)
- Persistente Einstellungen für Workouts Tab
- Persistente Presets für Atem Tab
- Vereinheitlichte Ring-Animationen (0.05s Updates)

## 🚀 Geplante Features

### 1. Statistiken (Priorität: Hoch)
**Beschreibung:** Monatskalender mit visueller Darstellung des täglichen Fortschritts. Kreise um Tageszahlen zeigen Zielerfüllung an.

**Details:**
- **Ziel-Setting:** User legt tägliches Ziel fest (z.B. 30 Minuten Meditation).
- **Kategorien:** 
  - Meditation: Kombiniert Offen + Atem (Gesamtdauer pro Tag)
  - Workout: Separat (HIIT-Sessions)
- **Visualisierung:** Kreise um Zahlen (z.B. 15/30 Min = halber Kreis). Ein oder zwei Kreise pro Tag (Meditation + Workout).
- **UI:** Scrollbarer Monatskalender für mehrere Monate/Jahre.
- **Datenbasis:** HealthKit-Logs oder lokale Session-Daten.

**User Stories:**
- Als User möchte ich meinen Fortschritt sehen, um motiviert zu bleiben.
- Als User möchte ich ein tägliches Ziel setzen, um meine Routine zu tracken.

**Technik:**
- SwiftUI CalendarView
- HealthKit-Datenaggregation
- @AppStorage für Ziele

**Aufwand:** Mittel (2-3 Wochen)  
**Risiken:** HealthKit-Berechtigungen, Performance bei vielen Daten.

### 2. Streaks (Priorität: Hoch)
**Beschreibung:** Verfolgung von aufeinanderfolgenden Tagen mit Meditation oder Workout. Belohnungssystem mit Herzen und Meilensteinen.

**Details:**
- **Definition:** Mindestens eine Session pro Tag (User wählt: Meditation oder Workout).
- **Belohnungen:** Kudos für 7 Tage, 1 Monat, 10 Monate etc. (Badges, Animationen).
- **Herz-System:** Ab 7 Tagen sammelt man Herzen; bei Unterbrechung verliert man ein Herz, aber Streak bleibt (z.B. Flamme-Icon).
- **UI:** Streak-Counter in der App, Herzen-Icon, Badge-Popups.

**User Stories:**
- Als User möchte ich meine Streaks sehen, um dranzubleiben.
- Als User möchte ich Belohnungen für Meilensteine, um Spaß zu haben.

**Technik:**
- Streak-Logik basierend auf Statistik-Daten
- @AppStorage für Herzen/Streaks
- SwiftUI-Animationen

**Aufwand:** Mittel (1-2 Wochen)  
**Risiken:** Kreative UI-Ideen brauchen Iterationen.

### 3. Erinnerungen (Priorität: Mittel)
**Beschreibung:** Tägliche Push-Notifications für Meditation und Atemübungen, konfigurierbar vom User.

**Details:**
- **Art:** Push-Notifications für Meditation (Offen + Atem) und Atemübungen separat.
- **Konfiguration:** User wählt Uhrzeit und Häufigkeit (z.B. täglich 8:00 Uhr).
- **Intelligenz:** Keine Erinnerung, wenn bereits am Tag trainiert wurde.
- **UI:** Settings-Tab mit Time-Picker und Toggles.

**User Stories:**
- Als User möchte ich tägliche Erinnerungen, um meine Routine nicht zu vergessen.
- Als User möchte ich konfigurierbare Zeiten, um flexibel zu sein.

**Technik:**
- UNUserNotificationCenter
- HealthKit-Prüfung vor Senden
- Background-Tasks für Scheduling

**Aufwand:** Mittel (2 Wochen)  
**Risiken:** iOS Notification-Berechtigungen, Batterie-Impact.

### 4. Fokusmode (Priorität: Niedrig)
**Beschreibung:** Automatische Aktivierung eines konfigurierten iOS Focus Modes während Sessions.

**Details:**
- **Konfiguration:** User wählt iOS Focus Mode (z.B. Do Not Disturb) für Meditation/Workout.
- **Aktivierung:** Automatisch bei Session-Start; zurück zum vorherigen Modus am Ende.
- **Technik:** iOS Focus Modes API (FocusStatus).

**User Stories:**
- Als User möchte ich Fokus während Sessions, um ungestört zu bleiben.
- Als User möchte ich automatische Aktivierung/Deaktivierung.

**Technik:**
- FocusStatus API (iOS 15+)
- Fallback: Do-Not-Disturb

**Aufwand:** Hoch (3-4 Wochen)  
**Risiken:** iOS-API-Beschränkungen, Berechtigungen.

## 📋 Roadmap-Zeitplan
1. **Q4 2025:** Statistiken implementieren (Basis für Streaks)
2. **Q1 2026:** Streaks hinzufügen (Motivation boost)
3. **Q1 2026:** Erinnerungen integrieren (Routine-Unterstützung)
4. **Q2 2026:** Fokusmode testen und freigeben (nice-to-have)

## 💡 Offene Fragen
- Grafische Umsetzung der Kreise: Ein oder zwei pro Tag?
- Streak-Definition: Mindestdauer pro Session?
- Fokusmode: Welche iOS-Modes sind programmatisch steuerbar?

## 🔄 Nächste Schritte
- User-Feedback zu Roadmap einholen
- Prototyp für Statistiken starten
- Technische Machbarkeitsstudie für Fokusmode