# Meditationstimer Feature Roadmap

## Übersicht
Dieses Dokument fasst die geplanten Features für die Meditationstimer-App zusammen. Basierend auf User-Feedback wurden die Ideen detailliert ausgearbeitet und priorisiert.

**Erstellt am:** 20. Oktober 2025  
**Status:** Planungsphase

## ✅ Abgeschlossene Features (für Kontext)
- Persistente Einstellungen für Workouts Tab
- Persistente Presets für Atem Tab
- Vereinheitlichte Ring-Animationen (0.05s Updates)
- Statistiken: Monatskalender mit visueller Darstellung des täglichen Fortschritts
- Streaks: Verfolgung von aufeinanderfolgenden Tagen mit Meditation und Workouts mit Belohnungssystem

## 🚀 Geplante Features

### 1. Erinnerungen (Priorität: Mittel)
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
1. **Q1 2026:** Erinnerungen integrieren (Routine-Unterstützung)
2. **Q2 2026:** Fokusmode testen und freigeben (nice-to-have)

## 💡 Offene Fragen
- Grafische Umsetzung der Kreise: Ein oder zwei pro Tag?
- Streak-Definition: Mindestdauer pro Session?
- Fokusmode: Welche iOS-Modes sind programmatisch steuerbar?

## 🔄 Nächste Schritte
- User-Feedback zu Roadmap einholen
- Prototyp für Statistiken starten
- Technische Machbarkeitsstudie für Fokusmode