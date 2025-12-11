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

### Workout-Übungen Lokalisierung & Vollständigkeit
**Status:** ✅ KOMPLETT (23.11.2025)
**Umgesetzt durch:**
- Bug 18: ExerciseDatabase-Lookup gefixt (31 Namen)
- Bug 19: 86 Exercise-Info-Strings übersetzt
- Bug 25: 46 Übungsnamen lokalisiert
**Dokumentation:** DOCS/feature-workout-exercises.md

---

## 🔄 In Planung

### Label-Umbenennung Offene Meditation
**Status:** ✅ Implementiert - UI-Test ausstehend
**Priorität:** Mittel
**Kategorie:** UI-Änderung
**Aufwand:** Klein (~15 Änderungen, 4 Dateien)

**Kurzbeschreibung:**
Die Phasen-Labels der Offenen Meditation wurden umbenannt:
- Phase 1: "Meditation" → "Dauer" (DE) / "Duration" (EN)
- Phase 2: "Besinnung" → "Ausklang" (DE) / "Closing" (EN)

**Geänderte Dateien:**
- iOS: OffenView.swift (Picker + RunCard)
- Widget: MeditationstimerWidgetLiveActivity.swift (Live Activity)
- Watch: ContentView.swift (Picker + Phase + Notifications)
- Localization: Localizable.xcstrings + iOS/Localizable.xcstrings (neue Keys)

**UI-Test-Anweisungen:**
1. **iOS App - Offen-Tab (DE)**
   - [ ] Picker zeigt "DAUER" und "AUSKLANG" als Labels
   - [ ] Session starten → Overlay zeigt "DAUER" mit 🧘 Emoji
   - [ ] Nach Phase 1 → Overlay zeigt "AUSKLANG" mit 🪷 Emoji

2. **iOS App - Offen-Tab (EN)**
   - [ ] Picker zeigt "DURATION" und "CLOSING" als Labels
   - [ ] Session starten → Overlay zeigt "DURATION"
   - [ ] Nach Phase 1 → Overlay zeigt "CLOSING"

3. **Live Activity / Dynamic Island**
   - [ ] Während Phase 1: Label zeigt "Duration" / "Dauer"
   - [ ] Während Phase 2: Label zeigt "Closing" / "Ausklang"

4. **Watch App (falls verfügbar)**
   - [ ] Picker zeigt neue Labels
   - [ ] Notifications zeigen "Dauer beendet" / "Sitzung abgeschlossen"

---

## 📝 Regeln für diese Datei

1. **Nur geplante Features** - Keine "vielleicht mal"-Ideen
2. **Priorisierung** - Basierend auf User-Feedback und Impact
3. **Nach Start**: Feature bekommt eigene `feature-*.md` Spec
4. **Nach Implementation**: Feature-Eintrag hier löschen
5. **Max 10 Features** - Bei mehr: Neu bewerten und niedrige Priorität streichen

---

**Für aktuelle Aufgaben siehe:** ACTIVE-todos.md
