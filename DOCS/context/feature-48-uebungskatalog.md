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

## Analysis

### Type
Feature (mit Bestandsfehler, im Simulator nachgestellt: Schritt „Planke" im Vorgabeprogramm „Core Circuit" öffnet als
„Eigene Übung…", die Auswahl ist eine überwiegend englische Liste; Screenshots `docs/artifacts/feature-48-uebungskatalog/heute-*.jpg`).

### Befunde der Analyse (2026-11-14)
- DB 43 Namen ↔ `Contracts/catalog/builtin-exercises.json` 43 Kennungen: 1:1 deckungsgleich. JSON liegt in keinem App-Target.
- Vorschlagsliste 69 Namen: 6 exakt in der DB, 2 über Endung links/rechts (Beinpendel), 37 englische Übersetzungen von DB-Namen,
  **24 ohne DB-Eintrag** (Hollow Hold, Dead Bug, Flutter Kicks, V-Ups, Sit-ups, Crunches, Archer/Decline Push-ups, Dips, Pull-ups,
  Chin-ups, Australian Pull-ups, Inverted Rows, Step-ups, Wall-Sit, Box Jumps, Skater Hops, Jump Rope, Downward Dog, Cobra Stretch,
  Cat-Cow, Seated Forward Bend, Shoulder Stretch L/R).
- `PhaseEditorView.init` (`WorkoutProgramsView.swift:1930`) prüft „eigen" gegen die Vorschlagsliste → alle deutschen Vorgabenamen gelten als eigen.
- `WorkoutSet`/`WorkoutPhase` synthetisiertes Codable ohne Version; Felder id, name, workDuration, restDuration. Keine Unit-Tests auf diesen Typen.
- Zwei Ansage-Wege: privater `SoundPlayer` (`WorkoutProgramsView.swift:56,128-142`) und `WorkoutSoundPlayer.swift:38,128-144`; Programme nutzen den privaten.
  Toter Code: `getNextAnnouncementText` (1379) ohne Aufrufer.
- Keine accessibilityIdentifier in Editor und Training.
- Spec-Widersprüche (für /30 klären): `claudeId` (claude-annahme.md:18) vs `itemId` (Lieferformat/Schema); claude-annahme.md:37 nennt `own.*` nicht;
  workouts.md TTS 158-172 ohne Hinweis; Herkunft-Enum nur in transcript-v2 (Lieferformat leitet Herkunft aus dem Präfix ab);
  Hinweislänge: Schema zählt UTF-16, Spec Codepunkte (Lieferformat:120).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Models/ExerciseInfo.swift` | MODIFY | `id` (`builtin.*`), `origin` (builtin/own/claude) |
| `Meditationstimer iOS/Services/ExerciseDatabase.swift` | MODIFY | Kennung je Eintrag, `info(forId:)`, `id(forName:)` inkl. Endung und englischer Namen |
| `Meditationstimer iOS/Views/ExerciseDetailSheet.swift` | MODIFY | Suche per Kennung |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | MODIFY | `WorkoutPhase.exerciseId`/`hint` mit tolerantem `init(from:)`; Auswahl aus Katalog; Hinweisfeld; Anzeige; Ansage |
| `Meditationstimer iOS/Tabs/WorkoutTab.swift` | MODIFY | Ladepfad absichern (Sicherung vor Rückfall auf Vorgaben), Vorgaben mit Kennung (A2c) |
| `Meditationstimer iOS/Localizable.xcstrings` | MODIFY | Hinweis-Texte DE/EN |
| `LeanHealthTimerTests/ExerciseCatalogTests.swift` | CREATE | Gleichlauf mit JSON, Namen→Kennung, Endungsregel, Slug-Regel `own.*` |
| `LeanHealthTimerTests/WorkoutPhaseMigrationTests.swift` | CREATE | Altbestand-JSON → verlustfrei, Rundreise |
| `LeanHealthTimerUITests/WorkoutHintUITests.swift` | CREATE | Hinweis eingeben → im Training sichtbar; Auswahl zeigt Katalognamen |

### Scope Assessment
- Files: 9 gesamt → Schnitt nötig (Scoping-Limit 4-5 Dateien/±250 Z.)
- Estimated LoC: +600/-150 gesamt
- Risk Level: MEDIUM (Datenverlust beim Laden eigener Programme ist der Hauptpunkt; Gegenmittel: nur optionale Felder, Sicherung des Rohbestands, Altbestandstests)

### Technical Approach
Variante (a): `WorkoutPhase` erhält `exerciseId: String?` und `hint: String?`, beide per `decodeIfPresent`; fehlt die Kennung,
wird sie beim Laden aus dem Namen abgeleitet (DB-Name, englischer Name, Endung links/rechts → `builtin.*`; sonst `own.<slug>`
nach Regex `^(builtin|own|claude)\.[a-z0-9][a-z0-9-]{1,62}$`). `name` bleibt Anzeigename für `own.*`; für `builtin.*` kommt der
Name aus dem Katalog (lokalisiert über xcstrings). Swift-Katalog bleibt in `ExerciseDatabase`, ein Test prüft ihn gegen das JSON.
Hinweis: 1-80 Codepunkte, eine Zeile, leer → nil; Anzeige unter dem Namen; Ansage „Name. Hinweis" nur bei eingeschalteter Ansage.
Herkunft: aus dem Präfix der Kennung abgeleitet (kein gespeichertes Feld), passend zum Lieferformat.

Alternative (b), verworfen: Kennung zur Laufzeit aus dem Namen berechnen, ohne Datenänderung — für `claude.*`/`own.*` aus #51/#53
fehlt dann der Anker, jede Umbenennung bricht die Zuordnung.

Schnitte: **A2a** Katalog + Kennung (3 Dateien, ≈150 Z.) → **A2b-0** Datenmodell + Migration + Sicherung (3 Dateien, ≈120 Z.)
→ **A2b** Hinweis sichtbar und hörbar, Auswahl aus Katalog (4-5 Dateien, ≈200 Z., erste PO-sichtbare Stufe)
→ **A2c** Vorgabeprogramme mit Kennung, tote 10er-Kopie entfernen (≈150 Z.).

### Dependencies
Nur iOS-App-Target. Watch/Widget/Intents/HealthKit nutzen die Typen nicht. #51 braucht A2a + A2b-0 (Kennung, Feld `hint`), #53 `own.*`.

### Open Questions (PO)
- [ ] Entwurf Training/Editor freigeben (Variante Hinweis im Ring vs. unter dem Ring)
- [ ] 24 Zusatzübungen ohne Beschreibung: als Namensvorschläge (eigene Übung, Info-Knopf leer) oder in den Katalog mit Texten?

### Entwurf (PO-Vorschau)
https://claude.ai/artifact/XrPS81A34yJzGMDacNYQiU — Quelle `docs/artifacts/feature-48-uebungskatalog/entwurf.html`; Empfehlung: Hinweis im Ring statt „Übung“, 24 Zusatzübungen als „Weitere“ (eigene Übung).

### PO-Entscheidungen (2026-11-14)
- **Hinweis im Training: unter dem Ring** (eigene Zeile zwischen Ring und Zähler, Alternative der Vorschau). Im Ring bleibt „Übung“.
- **Die 24 Zusatzübungen bekommen eine Beschreibung** und werden Teil des Katalogs: je Übung Wirkung + Anleitung (DE/EN),
  Kategorie, neue `builtin.*`-Kennung, im JSON-Katalog **angehängt** (append-only, catalogVersion 2). Eigener Schnitt **A2d**
  (ExerciseDatabase, xcstrings, builtin-exercises.json, Katalogtest; ≈250 Z., ggf. zwei Hälften à 12 Übungen).
  Danach enthält die Auswahl nur Katalogübungen + „Eigene Übung…“, keine Rubrik „Weitere“.
