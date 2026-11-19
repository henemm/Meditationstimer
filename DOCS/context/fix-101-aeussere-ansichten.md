# Context: fix-101-aeussere-ansichten

## Request Summary
Zweiter Schnitt aus #99 (Teil von #25, Runde 25g): In `AtemView.swift` und `WorkoutProgramsView.swift` die tote äußere
Bildschirmansicht entfernen. Alle verschachtelten Bausteine, gespeicherten Schlüssel und das Verhalten der Reiter bleiben.

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Tabs/AtemView.swift` (1153 Z.) | Tot: Watch-Stub Z. 37–51 (`#if !os(iOS)`), `defaultPresets` Z. 177–191, Zustand/Laden/Migrieren/Sichern Z. 193–253, `init`/`body` Z. 255–366 (inkl. `.onReceive(.startBreathingSession)`), dateiprivates `OverlayBackgroundEffect` Z. 369–380 (nur vom toten `body` genutzt). Lebend: `Preset`, `Phase`, `AtemSoundTheme`, `GongPlayer`, `Row`, `AddPresetCard`, `PresetInfoSheet`, `SessionCard`, `EditorView`, `AtemWheelPicker`, `AtemGlassCard` |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` (2066 Z.) | Tot: `defaultWorkoutSets` Z. 304–468 (dateiprivat, nur äußere Ansicht), äußere Ansicht Z. 470–652 (Zustand, `body`, verschachteltes `OverlayBackgroundEffect`, `loadSets`/`migrateSets`/`saveSets`, `emojiChoices`), Watch-Stub Z. 2058–2065. Lebend: `Cue`, `SoundPlayer`, `WorkoutSet`, `WorkoutPhase`, `exerciseSuggestions`, `SessionPhase`, `WorkoutProgramSessionCard`, `ProgressRingsView`, `WorkoutSetRow`, `AddSetCard`, `PresetInfoSheet`, `ExerciseSheetWrapper`, `SetEditorView`, `PhaseEditorView`, `WorkoutWheelPicker`, `WorkoutGlassCard` |
| `Meditationstimer iOS/Tabs/MeditationTab.swift` | Konsument: `AtemView.Preset/Row/AddPresetCard/EditorView/PresetInfoSheet/SessionCard`; eigene `defaultPresets`, eigenes Laden von `atemPresets` |
| `Meditationstimer iOS/Tabs/WorkoutTab.swift` | Konsument: `WorkoutProgramsView.WorkoutSetRow/AddSetCard/SetEditorView/PresetInfoSheet/WorkoutProgramSessionCard`; eigene `defaultWorkoutSets` (kürzere Beschreibungen), eigenes Laden von `workoutProgramSets` |
| `Meditationstimer iOS/SettingsSheet.swift` | Konsument: `AtemView.AtemSoundTheme` (`@AppStorage("atemSoundTheme")`) |
| `Meditationstimer iOS/ContentView.swift` | Lebender Empfänger von `.startBreathingSession`/`.startWorkoutSession` (Reiterwechsel); der Empfänger in `AtemView.body` ist tot |
| `Meditationstimer iOS/Localizable.xcstrings` | 11 Schlüssel nur im toten Teil (10 lange Programmbeschreibungen aus `defaultWorkoutSets`, „Workout programs are only available on iOS.“, „Breathe is only available on iOS.“) |

## Existing Patterns
- Runde #99: tote Dateien gelöscht, nur dort genutzte Übersetzungsschlüssel entfernt, Nachweis per Prüfskript + Build + Suiten + App-Durchlauf (kein RED-Test möglich bei „nichts ändert sich“).
- Typen werden von außen qualifiziert angesprochen (`AtemView.Preset`, `WorkoutProgramsView.SetEditorView`): Die Hülle bleibt als Namensraum nötig.

## Dependencies
- Upstream: `SettingsSheet`, `CalendarView`, `StreakManager` (nur im toten `body` benutzt), `UserDefaults`-Schlüssel `atemPresets`/`workoutProgramSets` (lebend in den Tabs gelesen/geschrieben).
- Downstream: `MeditationTab`, `WorkoutTab`, `SettingsSheet` über die verschachtelten Typen.

## Offene Entwurfsfrage für /20-analyse
- Ohne `body` kann die Hülle kein `View` mehr sein. Kandidaten: (a) `public struct AtemView: View` → `enum AtemView` (caseloser Namensraum, qualifizierte Namen bleiben gleich), (b) Struct behalten mit Platzhalter-`body` (lässt Tote stehen), (c) Typen auf oberste Ebene ziehen (großer Umbau, gegen Issue-Ziel „Bausteine behalten“).
- Watch-Stubs: Dateien gehören laut #99-Analyse nicht zum Watch-Target; `#if`-Zweige prüfen (Build watchOS).

## Existing Specs
- `DOCS/specs/bugfix/fix-99-toter-code.md` (Vorgängerrunde, Muster für Nachweis)

## Risks & Considerations
- Gespeicherte Daten: Benutzer-Vorlagen speichern Beschreibungstext aufgelöst, nicht als Schlüssel; Entfernen der Schlüssel ändert gespeicherte Daten nicht.
- Kurzbefehl „Atem starten“ läuft lebend über `ContentView` (Reiterwechsel); entfällt nur der tote Empfänger.
- Testdateien nennen `AddPresetCard`/`AddSetCard` nur in Kommentaren.
- Umfang: reines Löschen ca. −560 Zeilen plus Hüllen-Umstellung (wenige Zeilen) und ca. −11 xcstrings-Einträge; nach PO-Entscheidung zählt Löschen nicht gegen 250.

## Analysis

### Type
Bug-Ticket-Schiene, inhaltlich Aufräumen (toter Code, kein sichtbares Verhalten ändert sich).

### Nachgeprüfte Befunde (2026-11-19)
- `AtemView(` und `WorkoutProgramsView(` werden nirgends erzeugt (Quellen, Tests, Previews): die äußeren Ansichten sind unerreichbar.
- Von außen benutzt werden nur verschachtelte Typen: `AtemView.Preset/Row/AddPresetCard/EditorView/PresetInfoSheet/SessionCard/AtemSoundTheme`, `WorkoutProgramsView.WorkoutSetRow/AddSetCard/SetEditorView/PresetInfoSheet/WorkoutProgramSessionCard`.
- `AtemView.defaultPresets`, `randomEmoji`/`emojiChoices`, `presetsKey`/`setsKey`, `showSettings`, `showingCalendar`, äußeres `streakManager` werden nur im toten Teil benutzt. Das `streakManager` in `WorkoutProgramSessionCard` (Z. 680) ist ein eigenes und bleibt.
- `OverlayBackgroundEffect` in `AtemView.swift` (Z. 369–380) steht trotz Einrückung **innerhalb** der Hülle (der `}` in Z. 367 schließt nur `body`); privat, nur vom toten `body` genutzt. `MeditationTab`/`WorkoutTab` haben eigene Kopien.
- Watch-Target bezieht aus `Meditationstimer iOS/` nur `auftakt.caf` und `Localizable.xcstrings` (Ausnahmeliste im Projekt): die `#if !os(iOS)`-Platzhalter werden nie übersetzt.
- Übersetzungsschlüssel: **12** nur im toten Teil (Korrektur der Zählung oben): 10 lange Programmbeschreibungen aus `defaultWorkoutSets` + „Breathe is only available on iOS.“ + „Workout programs are only available on iOS.“. Die sechs Atem-Beschreibungen aus `AtemView.defaultPresets` bleiben, weil `MeditationTab` dieselben Schlüssel nutzt. `WorkoutTab` nutzt kürzere Varianten (eigene Schlüssel, bleiben).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Tabs/AtemView.swift` | MODIFY | Watch-Platzhalter, `defaultPresets`, Zustand/Laden/Migrieren/Sichern, `init`/`body`, `OverlayBackgroundEffect` entfernen; `#if !os(iOS)…#else` → `#if os(iOS)`; Hülle `public struct AtemView: View` → `enum AtemView` |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | MODIFY | `defaultWorkoutSets`, äußere Ansicht Z. 470–652, Watch-Platzhalter entfernen; `#else`-Zweig weg; Hülle → `enum WorkoutProgramsView` |
| `Meditationstimer iOS/Localizable.xcstrings` | MODIFY | 12 tote Schlüssel entfernen |
| `DOCS/specs/bugfix/fix-101-aeussere-ansichten.md` | CREATE | Spec (Phase 3) |
| Prüfskript (Muster #99) | CREATE | Nachweis „äußere Ansicht weg, Bausteine da, Schlüssel weg“ als RED-Beleg |

### Scope Assessment
- Dateien: 3 Quell-/Katalogdateien + Spec + Prüfskript
- LoC: ca. −560 Swift, ca. −12 Katalogeinträge (≈ −250 JSON-Zeilen), neu/geändert < 20 Zeilen (Hülle, `#if`, Kopfkommentar). Löschen zählt laut PO nicht gegen 250.
- Risiko: NIEDRIG — kein erreichbarer Code betroffen; Compiler fängt jeden übersehenen Bezug.

### Technical Approach (Empfehlung)
**Hülle als caseloser `enum`** (`enum AtemView { … }`, `enum WorkoutProgramsView { … }`). Das ist die übliche Swift-Form eines reinen Namensraums: nicht instanziierbar, alle qualifizierten Namen (`AtemView.Preset` …) bleiben wörtlich gleich, keine Änderung in `MeditationTab`, `WorkoutTab`, `SettingsSheet` und Tests. `public` entfällt (App-Target, nichts außerhalb des Moduls).

Alternativen:
- (b) Struct mit Platzhalter-`body` behalten — lässt ein totes, aufrufbares `View` stehen; widerspricht dem Ticketziel.
- (c) Bausteine auf oberste Ebene ziehen (`AtemPreset`, `AtemSessionCard` …) — sauberer langfristig, aber Umbenennung in allen Konsumenten und Tests, Namenskonflikte (`PresetInfoSheet` gibt es in beiden Dateien), sprengt „Bausteine behalten“ und die Grenze für Neues. Falls gewünscht, eigenes Ticket.

Nachweis wie #99: Prüfskript RED vorher / GREEN nachher, Build iOS + watchOS, Unit- und UI-Suite ohne neue Rotmeldung, App-Durchlauf Meditation- und Workout-Reiter im Simulator (Vorlage starten, bearbeiten, Info öffnen), Kurzbefehl „Atem starten“ wechselt weiter den Reiter.

### Dependencies
Nach #99 (gemergt). Keine Produktfrage offen.

### Open Questions
- keine
