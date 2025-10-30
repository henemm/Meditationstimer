# Feature Roadmap - Meditationstimer

**Letzte Aktualisierung:** 30. Oktober 2025
**Regel:** Geplante Features. Nach Implementation → löschen und feature-*.md erstellen

---

## 🚀 Geplante Features

### 1. Erweiterte Statistiken
**Priorität:** Mittel
**Aufwand:** Mittel
**Status:** Planungsphase

**Beschreibung:**
Detailliertere Analysen und Visualisierungen der Meditation- und Workout-Daten.

**Details:**
- Langzeit-Trends über Wochen/Monate
- Vergleich mit Vorperioden
- Datenexport für externe Analyse

**Risiken:** HealthKit-Datenverfügbarkeit

---

### 2. Lokalisierung (Englisch)
**Priorität:** Mittel
**Aufwand:** Mittel
**Status:** Planungsphase

**Beschreibung:**
Vollständige Lokalisierung der App für Englisch.

**Details:**
- Alle UI-Texte, Beschreibungen, Notifications
- SwiftUI LocalizedStringKey verwenden
- String-Katalog erstellen

**Risiken:** Konsistente Übersetzungen, Testing

---

### 3. Beschreibungstexte für Atem-Meditationen
**Priorität:** Niedrig
**Aufwand:** Niedrig (wenige Tage)
**Status:** Planungsphase

**Beschreibung:**
Kurze, inspirierende Beschreibungstexte zu den Atem-Meditationen hinzufügen.

**Details:**
- Lokalisierte Beschreibungen für jede Atem-Übung
- Anzeige in der Atem-View oder Preset-Auswahl
- Kurze Anleitungen oder Benefits der Übung

**Risiken:** Lokalisierung, UI-Anpassungen

---

### 4. Benutzerdefinierte Atem-Pattern
**Priorität:** Niedrig
**Aufwand:** Hoch
**Status:** Planungsphase

**Beschreibung:**
Erweiterte Atem-Übungen mit benutzerdefinierten Mustern.

**Details:**
- Editor: UI zum Erstellen eigener Atem-Sequenzen
- Mehr vordefinierte Presets
- Integration: Mit Live Activity und Fokusmode

**Risiken:** Komplexe UI, Timer-Logik

---

## 📝 Regeln für diese Datei

1. **Nur geplante Features** - Keine "vielleicht mal"-Ideen
2. **Priorisierung** - Basierend auf User-Feedback und Impact
3. **Nach Start**: Feature bekommt eigene `feature-*.md` Spec
4. **Nach Implementation**: Feature-Eintrag hier löschen
5. **Max 10 Features** - Bei mehr: Neu bewerten und niedrige Priorität streichen

---

**Für aktuelle Aufgaben siehe:** ACTIVE-todos.md
