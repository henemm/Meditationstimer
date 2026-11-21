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

## Analysis

### Type
Feature (Schnitt 2b von #51, ohne sichtbare Oberfläche; Grundlage für #57 und Schnitt 3)

### Befunde aus dem Code (2026-11-21)
1. **Fehlende Liste = Vorgaben, nicht leer.** `WorkoutTab.loadSets` (:362) und `MeditationTab.loadPresets` (:462) zeigen bei
   fehlendem Key die Code-Vorgaben (`defaultWorkoutSets` :801, `MeditationTab.defaultPresets` :69, privat) plus Migration.
   Würde das Anwenden bei fehlendem Key mit leerer Liste starten und sie schreiben, verschwänden alle Vorgaben aus der Anzeige
   bis zur nächsten Migration (und deren Reihenfolge). → Anwenden und Tab müssen **denselben** Lader benutzen.
2. **Migration der Atemübungen ist Instanzcode** (`migratePresets` :472, mutiert `@State`); `migratingPresets` für Programme ist
   schon rein (`WorkoutProgramsView.swift:346`). → Atem-Migration als reine statische Funktion herausziehen (gleiches Muster).
3. **`atemPresets` ohne Sicherung:** `try?` → Vorgaben → nächstes `savePresets` überschreibt die Rohdaten. `backUpUnreadable`
   (:333) ist `private` und an das Präfix `workoutProgramSetsBackup.` gebunden → Präfix als Parameter, eigene Präfix
   `atemPresetsBackup.`.
4. **Zwei Besitzer der Listen:** nur `WorkoutTab` (`setsKey` :44) und `MeditationTab` (`presetsKey` :65) lesen/schreiben die Keys;
   sonst niemand (grep 2026-11-21). Beide halten `@State`-Kopien, laden nur in `onAppear`, schreiben die ganze Liste.
5. **`displayName` löst `claude.*` bereits richtig auf** (gibt den gespeicherten Namen zurück, `ExerciseDatabase.swift:756`).
   `info(forId:)` für `claude.*` braucht nur das Info-Blatt, dessen Fehler (:1424 leitet Kennung aus dem Namen ab) laut
   Elternanalyse Schnitt 3 ist. Zweiter Nutzer: `PhaseEditorView.init` (:1660) entscheidet „eigene Übung“ über `info(forId:)`.
6. **Schritt-Editor zerstört `claude.*`:** `isCustom` = alles außer gültigem `builtin.*` (:1669); Speichern ruft dann
   `apply(.own(name:))` (:1771) → `own.<slug>`. Passiert schon, wenn Henning nur die Dauer ändert.
7. **`modifiedAt` wird nirgends gesetzt.** Beide Editoren geben über `onSave` den Entwurf an den Tab zurück
   (`WorkoutTab.swift:145`, `MeditationTab.swift:173`); dort ist alter und neuer Stand bekannt → Vergleich ohne `modifiedAt`.
8. **`claudeState` ≠ `ClaudeApplyState`:** Der Typ enthält die vollen Listen. Gespeichert unter `claudeState` werden nur
   `exercises` + `log`; der Zustand fürs Anwenden wird aus drei Keys zusammengesetzt.
9. **UI-Tests nutzen die echten `UserDefaults` der App im Simulator** (`ClaudeFelderUITests`, Aufräumen über die Oberfläche).
   Es gibt bis #57 keinen Aufrufer; Startargumente liegen in `Meditationstimer_iOSApp.swift:38-50` (nur DEBUG).

### Recherche (2026-11-21)
- `UserDefaults` kennt keine Transaktion über mehrere Keys; einzelne `set`-Aufrufe sind der vorgesehene Weg, `synchronize()` ist
  überflüssig (Apple-Doku `synchronize()`, Foundation Release Notes). → Reihenfolge „Listen zuerst, `claudeState` zuletzt“ plus
  `revision`-Prüfung ist die richtige Absicherung; kein `synchronize`.
- Benachrichtigungen in nicht sichtbaren Tabs: Forenberichte, dass Tabs außerhalb des Bildschirms nicht neu zeichnen
  (developer.apple.com/forums/thread/705110, /782755). `@State` wird trotzdem gesetzt; zusätzlich bleibt `onAppear`-Laden. Der
  Nachweis gehört in einen UI-Test (Anwenden, während der Tab sichtbar ist, und Tabwechsel).

### Zuschnitt (Tech-Lead-Entscheidung)
Alles zusammen ≈ 260–300 Zeilen App-Code in 6–7 Dateien → zwei Runden.

**Runde 2b-1 „Speichern, Laden, Neu-Laden“** (≈ 170 Zeilen, 5 Dateien)
| File | Change | Beschreibung |
|------|--------|--------------|
| `Meditationstimer iOS/Models/ClaudeStore.swift` | CREATE | Zustand aus drei Keys laden (gleicher Lader wie Tabs), `apply` aufrufen, Listen zuerst, `claudeState` (`exercises`+`log`) zuletzt schreiben, Benachrichtigung senden; unlesbare Liste → `rejected(LIST_UNREADABLE)`, nichts schreiben, nicht ins Gedächtnis; unlesbarer `claudeState` → sichern, leer weiter; generische `backUpUnreadable(prefix:)`, `Preset.loadStored`. Nur Foundation |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | MODIFY | `backUpUnreadable` auf generische Funktion umstellen; Lader „gespeichert oder Vorgaben + Migration“ als statische Funktion |
| `Meditationstimer iOS/Tabs/WorkoutTab.swift` | MODIFY | `loadSets` nutzt den gemeinsamen Lader; `.onReceive` der Benachrichtigung → neu laden |
| `Meditationstimer iOS/Tabs/MeditationTab.swift` | MODIFY | Vorgaben + Migration rein/statisch; Laden über `Preset.loadStored` (mit Sicherung); `.onReceive` → neu laden |
| `Meditationstimer iOS/Meditationstimer_iOSApp.swift` | MODIFY | nur DEBUG: Startargument wendet eine per Umgebung übergebene Lieferung über `ClaudeStore` an (Testeinstieg bis #57) |
Tests: Unit (isolierte `UserDefaults(suiteName:)`: Laden fehlend/gültig/unlesbar, Schreibreihenfolge, Idempotenz über Neustart,
unlesbare Liste nicht gemerkt, Sicherung `atemPresets`), UI (Lieferung per Startargument erscheint in der Liste, übersteht
Neustart; Rücknahme per Paket räumt auf). Quelltext-Wächter `ClaudeApply.swift` bleibt unverändert grün.

**Runde 2b-2 „Bearbeiten erkennt Claude-Bausteine“** (≈ 60–70 Zeilen, 3–4 Dateien)
- `modifiedAt` = jetzt in beiden `onSave`, nur wenn sich der Inhalt (ohne `modifiedAt`) wirklich geändert hat.
- Schritt-Editor behält `claude.*`, solange Henning die Übung nicht wechselt.
- Test `migratingPresets` + Claude-Programm (ergänzt nur Beschreibung, setzt kein `modifiedAt`).
- Festgehalten (Test): offener Editor + Anwenden → Hennings Speichern gewinnt, `modifiedAt` gesetzt.

**Verschoben nach Schnitt 3:** `ExerciseDatabase.info(forId:)` für `claude.*` (Laufzeit-Katalog). Einziger echter Verbraucher ist
das Info-Blatt (Schnitt 3); `displayName` funktioniert schon; der Schritt-Editor braucht es mit der Lösung in 2b-2 nicht.
Kippt die Zuordnung aus der Elternspec („Nicht in Scope (2b)“, Punkt 5).

### Alternativen
- **Gemeinsamer Listen-Besitzer** (ein `ObservableObject` für beide Listen statt `@State` + Benachrichtigung): beseitigt doppelte
  Kopien grundsätzlich, aber Umbau beider Tabs und aller Editor-Aufrufe (> 250 Zeilen). Verworfen für 2b (Elternanalyse
  „zu groß für diese Runden“), Kandidat, falls der UI-Test zeigt, dass `onReceive` im Hintergrund-Tab nicht greift.
- **Alles in einer Datei statt `UserDefaults`** (ein Schreibvorgang, echte Atomarität): ändert den Speicherort bestehender
  Nutzerdaten, braucht Umzug → widerspricht „Einfach statt kompliziert“; die `revision`-Absicherung reicht.
- **`info(forId:)` doch in 2b:** möglich in 2b-2 (+30 Zeilen, 1 Datei), ohne Verbraucher aber unbelegt.

### Scope Assessment
- Runde 2b-1: 5 Dateien, ≈ +170/−30 App-Code; Risiko MITTEL (berührt Laden der Listen beim Start, Datenverlust-Pfad).
- Runde 2b-2: 3–4 Dateien, ≈ +60/−5; Risiko NIEDRIG.

### Risiken
- Laden umgebaut: Altdaten müssen genau wie heute erscheinen (bestehende Migrationstests + `ClaudeFelderUITests` als Wächter).
- Stale Tab überschreibt Lieferung, wenn `onReceive` nicht greift → UI-Test mit sichtbarem Tab und Tabwechsel.
- Neuer Code `LIST_UNREADABLE` steht in keinem Bezugsdokument (wie Lücke 2 der Elternspec vorgesehen); Wortlaut legt Spec fest.
- Watch/Widget kompilieren den Ordner mit: `ClaudeStore.swift` nur Foundation; Watch- und Widget-Build in DoD.

### Open Questions
- keine PO-Frage (technischer Zuschnitt; keine sichtbare Änderung in 2b).
