# Context: feature-48-uebungskatalog

## Request Summary
Issue #48 (Epic #44, Scheibe A2): Die 43 eingebauten Übungen werden ein Katalog mit festen Kennungen, die zweite
Vorschlagsliste geht darin auf, Programme verweisen per Kennung, bestehende eigene Programme werden verlustfrei
umgestellt. Neu je Programmschritt: ein kurzer **Hinweis**, sichtbar unter dem Übungsnamen im Training und nach dem
Namen angesagt (wenn Ansagen an). Herkunftsfeld (mitgeliefert / eigen / von Claude) vorbereiten.
Konzept: `DOCS/konzept-claude-verbindung.md` §6.1 (Z. 89-101), §6.2 (Z. 103-111), §13 Stufe 0.

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Models/ExerciseInfo.swift:11-61` | `ExerciseInfo` (name, category, effect, instructions, notes) — **keine Kennung**; `ExerciseCategory` mit deutschen Rohwerten |
| `Meditationstimer iOS/Services/ExerciseDatabase.swift:14-358` | 43 Übungen (geprüft); `info(for:)` sucht per Name, dann Endungsregel links/rechts (Z. 21-41) |
| `Contracts/catalog/builtin-exercises.json` | 43 feste Kennungen `builtin.*` (catalogVersion 1), Name+Kategorie deckungsgleich; vom Server genutzt, von Swift noch nicht |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` (2071 Z.) | `WorkoutSet` 166-200, `WorkoutPhase` 203-216 (id, name, workDuration, restDuration); Vorschlagsliste `exerciseSuggestions` 221-302 (69, fast alles englisch); 10 Vorgabeprogramme 306-468 (tote Kopie); `SetEditorView` 1738-1909, `PhaseEditorView` 1912-2024; Trainingsansicht `ProgressRingsView` 1084-1496 (Name 1173/1196/1247-1264, nächste Übung 1267-1298); Ansagen `SoundPlayer` 52-161, `getNextExerciseNameForTTS` 1399-1425, erste Übung 930-934 |
| `Meditationstimer iOS/Tabs/WorkoutTab.swift` (880 Z.) | **Live-Ansicht** (`ContentView.swift:73`): Speichern/Laden UserDefaults `workoutProgramSets` 44, 362-395, `migrateSets` 372-389; nur 4 Vorgabeprogramme 813-866; ruft Editor 142-160 |
| `Meditationstimer iOS/Views/ExerciseDetailSheet.swift` | Info-Knopf; sucht per Name (Z. 12, 17); Titel roh (112) |
| `Meditationstimer iOS/SettingsSheet.swift:25,165` | `@AppStorage("speakExerciseNames")` (Standard false) |
| `Meditationstimer iOS/Localizable.xcstrings` | Übungsnamen als Schlüssel (deutsche DB-Namen → en, englische Vorschlagsnamen → de) |
| `openspec/specs/features/workouts.md` | Requirement Workout Programs 35-104, Exercise Database 106-122, TTS 151-180 |
| `openspec/specs/features/claude-annahme.md:17-20,37-38` | erwartet aus A2: Kennungen `builtin.*`/`claude.*`, optionales `hint` |
| `Contracts/schema/delivery-v1.schema.json:95-107,360-386` | `exerciseId` `^(builtin\|own\|claude)\.…`, `hint` ≤ 80 Zeichen |
| `DOCS/context/analyse-51-57-claude-app.md` §4, Z. 108-114 | Vorab-Analyse A2: Lücken A2-1…A2-7, Schnitt A2a/A2b/A2c |

## Existing Patterns
- Persistenz eigener Programme: ganzes Array als JSON in UserDefaults, `try? JSONDecoder()`, keine Versionsnummer.
- „Migration" heute: fehlende Vorgaben per Name ergänzen, fehlende Beschreibungen nachfüllen (`WorkoutTab.swift:372-389`).
- Migrationstest-Muster: `LeanHealthTimerTests/TrackerMigrationTests.swift`.
- Lokalisierung von Übungsnamen per `LocalizedStringKey(name)` — nur an manchen Stellen.
- UI-Tests: Startoption `enable-testing`, `-AppleLanguages (de)/(en)`; UserDefaults bleiben zwischen Läufen erhalten.

## Dependencies
- Upstream: `ExerciseDatabase` ← `ExerciseInfo`; Training/Editor ← `WorkoutPhase.name`; Ansage ← `speakExerciseNames`.
- Downstream: #51 (B1a) braucht Kennungen und das Feld `hint`; #53 (B1c) und Abschrift (`own.*`-Kennungen).
- Watch/Widget nutzen keine Programm- oder Übungsdaten (nur geteilte xcstrings).

## Existing Specs
- `openspec/specs/features/workouts.md` — muss um Kennung, Hinweis, Herkunft ergänzt werden.
- `openspec/specs/features/claude-annahme.md`, `openspec/specs/integrations/claude-lieferformat.md`.

## Befunde (Bestandsfehler, nicht Teil des Auftrags, aber relevant)
- Wahl aus der Vorschlagsliste speichert englische Namen („Plank") → `ExerciseDatabase.info(for:)` findet nichts → Info-Knopf leer.
- Übungsname im Training (`Text(name)` Z. 1249), Picker (1956), Sheet-Titel und Sprachansage sind unübersetzt.
- Zwei Vorgabelisten (10 tote / 4 live) und doppelte Lade-/Speicherlogik.
- Bei Pause 0 s wird die nächste Übung nicht angesagt.
- Freier HIIT-Timer nutzt `speakExerciseNames` mit Standard true, Programme mit false.

## Risks & Considerations
- **Datenverlust:** Schlägt das Dekodieren fehl, fällt das Laden still auf Vorgaben zurück und der nächste Speichervorgang
  überschreibt eigene Programme. Neue Felder nur optional oder mit eigenem `init(from:)`; Altbestand-JSON-Tests Pflicht.
- **Zuordnung Name → Kennung** muss deutsch, englisch (über Tabelle/xcstrings), Endung links/rechts und Freitext (`own.*`) abdecken.
  Vorab-Analyse schlägt berechnete Zuordnung ohne Datenumbau vor (`own.` + Hash) — Alternative: gespeichertes `exerciseId`.
- **Scoping:** gesamt ≈ 8-10 Dateien, 600-800 Z. → Schnitt nötig (A2a Katalog/Kennung, A2b Hinweis, A2c Vorgaben vereinheitlichen).
- **Produktfragen:** 26 Zusatzübungen aus der Vorschlagsliste ohne Wirkung/Anleitung — in den Katalog (Texte nötig) oder als
  eigene Übungen? Vorgabelisten 4 vs. 10 vereinheitlichen? Hinweis-Länge (≤ 80 Zeichen laut Lieferformat).
- **UI sichtbar** → Entwurf (Heute/Entwurf/Alternative) vor der Spec (globale Regel 2026-09-22).
- Keine Accessibility-Identifier im Editor/Training → UI-Tests brauchen neue Kennungen.
