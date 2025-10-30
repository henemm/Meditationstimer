# Feature Roadmap - Meditationstimer

**Letzte Aktualisierung:** 30. Oktober 2025
**Regel:** Geplante Features. Nach Implementation → löschen und feature-*.md erstellen

---

## 🚀 Geplante Features

### 1. NoAlk Streak (Alcohol Tracking)
**Priorität:** Hoch
**Aufwand:** Mittel
**Status:** Spec fehlt - muss neu erstellt werden

**Beschreibung:**
Passives Alcohol-Tracking mit NoAlk-Streak-System analog zu Meditation/Workout Streaks.

**Details:**
- Unterschwelliges Feature (nicht aufdringlich)
- Smart Notifications als Haupt-Interaktion
- NoAlk Streak: Belohnung für alkoholfreie Tage
- HealthKit Integration (numberOfAlcoholicBeverages)
- Minimale UI (kein Manual-Entry im Vordergrund)

**Risiken:** Feature-Spec verloren gegangen, muss neu definiert werden

**Hinweis:** Erste Implementation wurde revertiert (falsche Annahmen ohne Spec)

---

### 2. Klangpakete/-Presets
**Priorität:** Mittel
**Aufwand:** Mittel
**Status:** Planungsphase

**Beschreibung:**
Auswahl verschiedener Klangpakete/Soundpresets für Offen, Atem und Workouts.

**Details:**
- Mehrere Gong-Varianten (klassisch, Klangschale, modern)
- Unterschiedliche Atem-Cue Sounds
- Workout-Countdown Varianten
- Settings-Integration: Sound-Theme Auswahl
- Beibehaltung aktueller Sounds als "Standard"-Preset

**Risiken:** Audio-Assets Größe, Lokalisierung der Sound-Namen

---

### 3. Mehrsprachigkeit (Deutsch/Englisch)
**Priorität:** Mittel
**Aufwand:** Mittel
**Status:** Planungsphase

**Beschreibung:**
Vollständige Lokalisierung der App für Deutsch und Englisch.

**Details:**
- Alle UI-Texte, Beschreibungen, Notifications
- SwiftUI LocalizedStringKey verwenden
- String-Katalog erstellen (Localizable.xcstrings)
- Automatische Spracherkennung (System-Sprache)

**Risiken:** Konsistente Übersetzungen, Testing auf beiden Sprachen

---

### 4. Erweiterte Statistiken
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

### 5. Beschreibungstexte für Atem-Meditationen
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

### 6. Benutzerdefinierte Atem-Pattern
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
