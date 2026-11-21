# Context: feature-51-s2b-speichern (#51, Schnitt 2b)

## Request Summary
Gelieferte Bausteine von Claude (Programme, Atemübungen, Übungen) dauerhaft speichern, beim Start laden und in den
bestehenden Listen der App zeigen. Grundlage ist die reine Funktion `apply` aus Schnitt 2a (Runden 2a-1 bis 2a-3, gemergt).
Elternspec: `DOCS/specs/features/feature-51-s2-bausteine-anwenden.md`, Abschnitt „Nicht in Scope (gehört zu Schnitt 2b)“;
Analyse: `DOCS/context/feature-51-s2-bausteine-anwenden.md` (Entscheidung 8, „Befunde für spätere Runden“).

## Umfang laut Elternspec (2b)
1. Laden/Schreiben der Keys `workoutProgramSets`, `atemPresets`, `claudeState`; Reihenfolge Listen zuerst, `claudeState` zuletzt.
2. Sicherung unlesbarer `atemPresets` (parametrisiertes `backUpUnreadable`); Ablehnung „Liste unlesbar“, nicht ins Gedächtnis.
3. Neu-Laden offener Tabs per Benachrichtigung.
4. `modifiedAt` beim Speichern im Editor setzen (nur bei echter Inhaltsänderung).
5. `claude.*` in `ExerciseDatabase.info(forId:)` und `displayName` auflösen (Laufzeit-Katalog aus `claudeState`).
6. Befunde: Schritt-Editor macht aus `claude.x` ein `own.*`; `migratingPresets` und Claude-Programme (Test); offener Editor +
   Anwenden: iPhone gewinnt (festhalten).
Nicht in 2b: Aufrufer von `apply` aus dem Dienst und `lastSnapshotAt` (#57); jede neue Oberfläche, Kennzeichen „von Claude“ (Schnitt 3).

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Models/ClaudeApply.swift` (187) | `ClaudeApplyState` :44 (Codable: sets, presets, exercises, log), `apply` :52, `resolveStepName` :102. Darf laut Test kein `UserDefaults`/`NotificationCenter`/`Date()` enthalten (`ClaudeApplyTests.swift:951-966`) → Persistenz in neuer Datei |
| `Meditationstimer iOS/Tabs/WorkoutTab.swift` (868) | Liste `sets` @State :35, `setsKey` :44, `onAppear` :165, `loadSets` :362, `migrateSets` :371, `saveSets` :379, Editor-Aufruf onSave/onDelete :142-161 |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` (1826) | `WorkoutSet` :166-186 (`claude`, `modifiedAt`), `loadStored` :324-330, `backUpUnreadable` :333-342 (private, Präfix `workoutProgramSetsBackup.`), `migratingPresets` :346-357, SetEditor :1473 (Save :1595), PhaseEditor :1644 (Custom→`own.*` :1770-1772, `apply(.own)` :288-296) |
| `Meditationstimer iOS/Tabs/MeditationTab.swift` (568) | Liste `presets` @State :26, `presetsKey` :65, `onAppear` :193, `loadPresets` :462 (`try?`, keine Sicherung, Fehler → Defaults, Rohdaten werden beim nächsten Speichern überschrieben), `migratePresets` :472, `savePresets` :491, Editor :170-189 |
| `Meditationstimer iOS/Tabs/AtemView.swift` (938) | `Preset` :43-80 (`claude`, `modifiedAt`), EditorView :796 (Save :880) |
| `Meditationstimer iOS/Services/ExerciseDatabase.swift` (773) | `info(forId:)` :627 (statisch, nur `builtin.*`), `displayName` :756, `exerciseId(forName:)` :709, `ownExerciseId` :723 |
| `Meditationstimer iOS/Models/ExerciseInfo.swift` (81) | `ExerciseOrigin` :46 |
| `LeanHealthTimerTests/WorkoutPhaseMigrationTests.swift` (~420) | Muster für isolierte `UserDefaults(suiteName:)` + Sicherungstests (:224, :268, :381) |
| `LeanHealthTimerTests/ClaudeApplyTests.swift` (967) | Reine Tests + Quelltext-Wächter |
| `LeanHealthTimerUITests/ClaudeFelderUITests.swift` | Neustart-Test Programme/Atemübungen |
| `openspec/specs/features/claude-annahme.md:21` | `claudeState` als eigener Speicher |

## Existing Patterns
- Listen als JSON-`Data` in `UserDefaults.standard`, kein `@AppStorage`; Laden in `onAppear` des Tabs in ein `@State`.
- Sicherung unlesbarer Programme: `loadStored` → `backUpUnreadable` unter Präfix + Unix-Sekunden, überschreibt nie.
- Tests isolieren `UserDefaults` per `suiteName` mit UUID und räumen in `tearDown` auf.
- NotificationCenter nur für Kurzbefehle (`ShortcutNotifications.swift:11-14`); kein Muster zum Neu-Laden von Listen.

## Dependencies
- Upstream: `ClaudeDelivery` (Schnitt 1), `apply` (2a), `ExerciseDatabase`.
- Downstream: #57 (Dienst, ruft das Anwenden mit `lastSnapshotAt` auf), Schnitt 3 (Oberfläche). Watch/Widget lesen die Keys nicht,
  kompilieren aber den Ordner `Meditationstimer iOS` mit (nur Foundation in neuen Dateien, Watch- und Widget-Build in DoD).

## Risks & Considerations
- **Größe:** Sechs Teilaufgaben in mindestens 6 Dateien (neue Persistenzdatei, WorkoutTab, MeditationTab, WorkoutProgramsView,
  AtemView, ExerciseDatabase). Das übersteigt 4–5 Dateien / 250 Zeilen App-Code sehr wahrscheinlich → in Runden teilen
  (Analyse legt Zuschnitt fest).
- **Datenverlust `atemPresets`:** heute keine Sicherung; Laden mit `try?` und späteres Speichern überschreibt unlesbare Rohdaten.
- **Ohne Aufrufer:** Bis #57 ruft nichts `apply` auf; was 2b liefert, ist für Henning noch unsichtbar, außer Neustartfestigkeit.
  Nachweis daher über Unit-Tests mit isolierten `UserDefaults` und einen Testeinstieg (Startargument) statt Dienst.
- **`modifiedAt`** wird heute nirgends gesetzt → Regel 8 (`CHANGED_ON_IPHONE`) greift im echten Betrieb erst mit 2b.
- **Schritt-Editor** zerstört `claude.*`-Kennungen beim Speichern (wird `own.*`).
- **Zwei Tabs halten eigene Kopien** der Listen (`@State`); Anwenden im Hintergrund braucht Neu-Laden, sonst überschreibt das nächste
  `saveSets()` die gelieferte Fassung.
