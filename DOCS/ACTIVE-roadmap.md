# Feature Roadmap - Meditationstimer

**Letzte Aktualisierung:** 23. November 2025
**Regel:** Geplante Features. Nach Implementation → löschen und feature-*.md erstellen

---

## ✅ Kürzlich abgeschlossen

### Countdown vor Start
**Status:** ✅ KOMPLETT (23.11.2025)
**Getestet:** EN-Version, Offen-Tab - Countdown + Gong funktioniert
**Dokumentation:** DOCS/feature-countdown-vor-start.md

### TTS für freie Workouts
**Status:** ✅ KOMPLETT (23.11.2025)
**Getestet:** EN-Version sagt "Round two" korrekt
**Bug behoben:** TTS-Stimme war hardcoded auf de-DE → jetzt Locale-basiert
**Dokumentation:** DOCS/feature-tts-free-workouts.md

---

## 🚀 Geplante Features

### Workout-Übungen Lokalisierung & Vollständigkeit
**Status:** Geplant
**Priorität:** Mittel
**Kategorie:** Support Feature
**Aufwand:** Klein-Mittel (~150-200 LoC, 2 Dateien)

**Kurzbeschreibung:**
Übungsnamen in HIIT-Workouts sind komplett englisch, obwohl deutsche Begriffe wo üblich sein sollten. Zusätzlich fehlt "Leg Swing Right" im Morning Stretch.

**Betroffene Systeme:**
- Services/WorkoutModels.swift (Übungsdefinitionen)
- Localizable.xcstrings (neue Strings)

**Dokumentation:** DOCS/feature-workout-exercises.md

---

## 📝 Regeln für diese Datei

1. **Nur geplante Features** - Keine "vielleicht mal"-Ideen
2. **Priorisierung** - Basierend auf User-Feedback und Impact
3. **Nach Start**: Feature bekommt eigene `feature-*.md` Spec
4. **Nach Implementation**: Feature-Eintrag hier löschen
5. **Max 10 Features** - Bei mehr: Neu bewerten und niedrige Priorität streichen

---

**Für aktuelle Aufgaben siehe:** ACTIVE-todos.md
