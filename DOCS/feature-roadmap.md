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
- Smart Reminders: Intelligente Erinnerungen basierend auf HealthKit-Inaktivität für Meditation und Workouts
- Fokusmode: Automatische Aktivierung von iOS Focus Modes während Sessions

## 🚀 Geplante Features

### 1. Erweiterte Statistiken (Priorität: Mittel)
**Beschreibung:** Detailliertere Analysen und Visualisierungen der Meditation- und Workout-Daten.

**Details:**
- **Trends:** Langzeit-Trends über Wochen/Monate
- **Vergleiche:** Vergleich mit Vorperioden
- **Export:** Datenexport für externe Analyse

**Aufwand:** Mittel  
**Risiken:** HealthKit-Datenverfügbarkeit

### 2. Benutzerdefinierte Atem-Pattern (Priorität: Niedrig)
**Beschreibung:** Erweiterte Atem-Übungen mit benutzerdefinierten Mustern.

**Details:**
- **Editor:** UI zum Erstellen eigener Atem-Sequenzen
- **Presets:** Mehr vordefinierte Muster
- **Integration:** Mit Live Activity und Fokusmode

**Aufwand:** Hoch  
**Risiken:** Komplexe UI, Timer-Logik

### 3. Beschreibungstexte für Atem-Meditationen (Priorität: Niedrig)
**Beschreibung:** Kurze, inspirierende Beschreibungstexte zu den Atem-Meditationen hinzufügen, um die Nutzererfahrung zu verbessern.

**Details:**
- **Texte:** Lokalisierte Beschreibungen für jede Atem-Übung
- **UI:** Anzeige in der Atem-View oder Preset-Auswahl
- **Inhalt:** Kurze Anleitungen oder Benefits der Übung

**Aufwand:** Niedrig (wenige Tage)  
**Risiken:** Lokalisierung, UI-Anpassungen

### 4. Lokalisierung (Priorität: Mittel)
**Beschreibung:** Vollständige Lokalisierung der App für mehrere Sprachen hinzufügen.

**Details:**
- **Sprachen:** Englisch als primäre zusätzliche Sprache
- **Umfang:** Alle UI-Texte, Beschreibungen, Notifications
- **Tools:** SwiftUI LocalizedStringKey verwenden

**Aufwand:** Mittel  
**Risiken:** Konsistente Übersetzungen, Testing

## 💡 Offene Fragen
- Grafische Umsetzung der Kreise: Ein oder zwei pro Tag?
- Streak-Definition: Mindestdauer pro Session?
- Fokusmode: Welche iOS-Modes sind programmatisch steuerbar?

## 🔄 Nächste Schritte
- User-Feedback zu Roadmap einholen
- Prototyp für Statistiken starten
- Technische Machbarkeitsstudie für Fokusmode