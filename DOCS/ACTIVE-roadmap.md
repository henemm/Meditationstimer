# Feature Roadmap - Meditationstimer

**Letzte Aktualisierung:** 1. November 2025
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

### 2. Mehrsprachigkeit (Deutsch/Englisch)
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

## 📝 Regeln für diese Datei

1. **Nur geplante Features** - Keine "vielleicht mal"-Ideen
2. **Priorisierung** - Basierend auf User-Feedback und Impact
3. **Nach Start**: Feature bekommt eigene `feature-*.md` Spec
4. **Nach Implementation**: Feature-Eintrag hier löschen
5. **Max 10 Features** - Bei mehr: Neu bewerten und niedrige Priorität streichen

---

**Für aktuelle Aufgaben siehe:** ACTIVE-todos.md
