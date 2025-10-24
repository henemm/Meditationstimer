# Release Notes - Version 2.6

**Veröffentlichungsdatum:** 24. Oktober 2025  
**Branch:** main  
**Vorherige Version:** v2.5.1  

## 🎉 Neue Features

### 🔔 Smart Reminders
- **Intelligente Erinnerungen:** Automatische Benachrichtigungen bei Inaktivität für Meditation oder Workouts
- **Anpassbare Einstellungen:** Wähle Aktivitätstyp (Meditation oder Workout), Inaktivitätsdauer (1-24 Stunden) und Wochentage
- **HealthKit-Integration:** Nutzt HealthKit-Daten zur Erkennung von Aktivitäten
- **Hintergrundverarbeitung:** Läuft im Hintergrund mit iOS Background Tasks
- **Rate Limiting:** Vermeidet übermäßige Benachrichtigungen (max. 1 pro Tag pro Erinnerung)

### 🎯 Fokusmode
- **Fokus-Unterstützung:** Integration mit iOS Fokusmodi für störungsfreie Meditation
- **Automatische Aktivierung:** Fokusmodus startet automatisch bei Timer-Start
- **Berechtigungen:** Anfrage um Fokus-Berechtigung bei erster Nutzung
- **UI-Integration:** Fokus-Einstellungen in den App-Einstellungen

## 🔧 Technische Verbesserungen
- **HealthKit-Kompatibilität:** Verbesserte watchOS-Kompatibilität für HealthKit-Abfragen
- **Code-Architektur:** Neue Services für Smart Reminders und Fokus-Management
- **UI-Polish:** Verbesserte Einstellungen-Navigation und Picker-Komponenten

## 🐛 Behobene Bugs
- FokusManager Scope-Issues behoben durch bedingte Kompilierung
- HealthKit-Conditional-Compilation für watchOS-Kompatibilität

## 📱 Kompatibilität
- **iOS:** 15.0+
- **watchOS:** 8.0+
- **HealthKit:** Erforderlich für Smart Reminders und Statistiken
- **Background Tasks:** Erforderlich für Smart Reminders

## 📝 Bekannte Einschränkungen
- Smart Reminders basieren auf HealthKit-Daten
- Fokusmode erfordert iOS 15+ und Fokus-Berechtigung

## 🔄 Migration
Keine speziellen Migrationsschritte erforderlich. Bestehende User-Daten bleiben erhalten.

---