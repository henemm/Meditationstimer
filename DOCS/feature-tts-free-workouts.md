# Feature: TTS für freie Workouts

**Status:** Geplant
**Priorität:** Mittel
**Geschätzter Aufwand:** Klein (~30-50 LoC, 1-2 Dateien)

---

## Zusammenfassung

Die freien Workouts (Frei-Tab) sollen die gleiche iOS Sprachausgabe (TTS) nutzen wie der Workouts-Tab. Die Infrastruktur existiert bereits, wird aber nicht aktiviert.

---

## Ist-Zustand

### WorkoutsView.swift (Frei-Tab)
- `SoundPlayer` Klasse hat `speak()` Methoden (Zeilen 178-190)
- `AVSpeechSynthesizer` ist initialisiert
- **ABER:** Keine einzige Stelle ruft `sounds.speak()` auf
- Settings-Toggle `speakExerciseNames` nicht angeschlossen

### WorkoutProgramsView.swift (Workouts-Tab) - Referenz
- TTS aktiv genutzt (Zeilen 753, 1254-1259)
- Ankündigungen wie: "Als nächstes: Übung 2 von 5 - Plank"
- Gesteuert über `@AppStorage("speakExerciseNames")`

---

## Soll-Zustand

Der Frei-Tab soll:
1. Den gleichen Settings-Toggle `speakExerciseNames` respektieren
2. Bei Übungswechsel die nächste Übung ansagen
3. Gleiche Ankündigungs-Logik wie Workouts-Tab nutzen

---

## Anforderungen

- [ ] `@AppStorage("speakExerciseNames")` in WorkoutsView einbinden
- [ ] Bei REST-Phase Ende: Nächste Übung ansagen (wenn Toggle aktiv)
- [ ] **Sprachausgabe passend zur App-Oberfläche:** DE-Oberfläche → "de-DE" Stimme, EN-Oberfläche → "en-US" Stimme
- [ ] Konsistente Formulierung mit Workouts-Tab

**Hinweis zur Sprache:**
Die TTS-Stimme muss zur App-Sprache passen, NICHT zur System-Sprache. Grund: Die Texte sind lokalisiert ("Als nächstes" vs "Up next"). Eine deutsche Stimme für englischen Text klingt falsch.

---

## Technische Umsetzung

### Betroffene Dateien

| Datei | Änderung |
|-------|----------|
| `WorkoutsView.swift` | `@AppStorage` hinzufügen, `speak()` Aufrufe integrieren |

### Implementierungsschritte

1. **AppStorage hinzufügen:**
   ```swift
   @AppStorage("speakExerciseNames") private var speakExerciseNames: Bool = true
   ```

2. **TTS bei Übungswechsel aufrufen:**
   - Im Timer-Callback (bei Phasenwechsel REST → WORK)
   - Oder bei `currentExerciseIndex` Änderung

3. **Ankündigung formulieren:**
   ```swift
   if speakExerciseNames {
       let announcement = "Als nächstes: \(nextExerciseName)"
       sounds.speak(announcement, language: currentLocale)
   }
   ```

---

## Test-Plan

1. Settings: "Übungsnamen ansagen" aktivieren
2. Freies Workout starten mit mehreren Übungen
3. Bei Übungswechsel: TTS sollte nächste Übung ansagen
4. Settings: Toggle deaktivieren → Keine Ansagen mehr
5. Sprache testen: DE App = deutsche Stimme, EN App = englische Stimme

---

## Abgrenzung

- Keine Änderung am Workouts-Tab (funktioniert bereits)
- Keine neuen Settings (nutzt bestehenden Toggle)
- Keine neuen Audio-Dateien (nutzt iOS TTS)
