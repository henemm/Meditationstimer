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
**Beschreibung:** Automatische Aktivierung eines konfigurierten iOS Focus Modes während Sessions, um ungestörte Meditation oder Workouts zu ermöglichen.

**Details:**
- **Konfiguration:** User wählt im Settings-Tab einen iOS Focus Mode (z.B. Do Not Disturb, Work, Sleep) für Meditation- und Workout-Sessions separat. Optionale Toggle für automatische Aktivierung.
- **Aktivierung:** Automatisch bei Session-Start (z.B. über TimerEngine); zurück zum vorherigen Modus am Ende der Session oder bei Abbruch. Fallback auf Do-Not-Disturb, wenn der gewählte Modus nicht verfügbar ist.
- **Verfügbare Modi:** Abhängig von iOS-Version – typischerweise Do Not Disturb, Driving, Work, Sleep, Personal. Nicht alle Modi sind programmatisch steuerbar (z.B. Custom Modi mit Filtern).
- **UI-Integration:** Neue Sektion im Settings-Tab mit Picker für Modi und Toggles pro Session-Typ.

**User Stories:**
- Als User möchte ich Fokus während Sessions, um ungestört zu bleiben.
- Als User möchte ich automatische Aktivierung/Deaktivierung, ohne manuell den Modus zu wechseln.
- Als User möchte ich den Modus pro Session-Typ konfigurieren, um Flexibilität zu haben.
- Als User möchte ich einen Fallback, falls mein gewählter Modus nicht funktioniert.

**Technik:**
- FocusStatus API (iOS 15+): Verwende ActivityManager für Aktivierung/Deaktivierung von Focus Modi.
- Berechtigungen: Erfordert Focus-Status-Berechtigung (Info.plist: NSFocusStatusUsageDescription).
- Fallback: Do-Not-Disturb via UIApplication.shared (ältere API).
- Integration: Hook in MeditationEngine/TwoPhaseTimerEngine für Start/Ende-Events.
- Background-Handling: Stelle sicher, dass Modus bei App-Terminierung zurückgesetzt wird.

**Implementierungsschritte:**
1. Berechtigungen in Info.plist hinzufügen.
2. Settings-UI erweitern (neue View mit Picker und Toggles).
3. FocusManager-Klasse erstellen für API-Interaktion.
4. Integration in Timer-Engines (onStart: activate Modus; onEnd: deactivate).
5. Fallback-Logik implementieren.
6. Tests: Simulator-Unterstützung prüfen, Berechtigungen testen.

**Aufwand:** Niedrig (1 Woche)  
**Risiken:** iOS-API-Beschränkungen (nicht alle Modi steuerbar, abhängig von iOS-Version), Berechtigungen (User muss zustimmen), Kompatibilität mit älteren iOS-Versionen (Fallback erforderlich).

(nice-to-have)

## 💡 Offene Fragen
- Grafische Umsetzung der Kreise: Ein oder zwei pro Tag?
- Streak-Definition: Mindestdauer pro Session?
- Fokusmode: Welche iOS-Modes sind programmatisch steuerbar?

## 🔄 Nächste Schritte
- User-Feedback zu Roadmap einholen
- Prototyp für Statistiken starten
- Technische Machbarkeitsstudie für Fokusmode