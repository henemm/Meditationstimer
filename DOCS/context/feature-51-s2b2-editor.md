# Context: feature-51-s2b2-editor (#51, Runde 2b-2)

## Request Summary
Drei Restpunkte aus Schnitt 2b: (1) Bearbeitet Henning einen gelieferten Baustein im Editor, wird `modifiedAt` gesetzt
(Grundlage für „das iPhone gewinnt“). (2) Der Schritt-Editor behält eine `claude.*`-Übungskennung, solange die Übung nicht
gewechselt wird. (3) Kommt eine Lieferung an, während ein Editor offen ist, überschreibt das spätere Speichern sie nicht
unbemerkt bzw. holt eine Rücknahme nicht wieder zurück.

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Tabs/WorkoutTab.swift:142-161` | `onSave` des Programm-Editors: ersetzt per id oder hängt an, dann `saveSets()` (:376-380) |
| `Meditationstimer iOS/Tabs/WorkoutTab.swift:169-171` | `.onReceive(.claudeStoreDidChange)` → `loadSets()` (:365-374) |
| `Meditationstimer iOS/Tabs/MeditationTab.swift:170-189` | `onSave` des Atem-Editors, dann `savePresets()` (:488-492) |
| `Meditationstimer iOS/Tabs/MeditationTab.swift:200-202` | `.onReceive(.claudeStoreDidChange)` → `loadPresets()` (:465-474) |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:1473-1626` | `SetEditorView`: `@State draft` (Kopie), `onSave(draft)` (:1595), Schritt-Sheet (:1602-1626) |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:1657-1775` | `PhaseEditorView`: `init` setzt für `claude.*` `useCustomExercise = true` (:1669-1671); Speichern ruft `apply(.own(name:))` (:1770-1775) → Kennung wird `own.<slug>` |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:288-297` | `WorkoutPhase.apply(...)` setzt `exerciseId` |
| `Meditationstimer iOS/Tabs/AtemView.swift:796-880` | `AtemView.EditorView`: `@State draft`, `onSave(draft); dismiss()` |
| `Meditationstimer iOS/Models/ClaudeApply.swift:86-181` | liest `modifiedAt` für `CHANGED_ON_IPHONE` |
| `Meditationstimer iOS/Models/ClaudeStore.swift` | `ClaudeStore.apply`, Benachrichtigung `claudeStoreDidChange` |
| `Meditationstimer iOS/Meditationstimer_iOSApp.swift:91-103` | DEBUG-Einstieg `uitest-claude-apply` |

## Existing Patterns
- Editoren arbeiten auf einer Kopie (`@State draft`) und geben sie per `onSave` zurück; der Tab besitzt die Liste und schreibt
  sie ganz nach `UserDefaults`. Optionale Claude-Felder bleiben dabei erhalten (Kopie wird verändert, nicht neu gebaut).
- Tabs laden nach `claudeStoreDidChange` ihre Liste komplett neu (2b-1).
- Übungskennungen: `builtin.*`, `own.<slug>` (`ExerciseDatabase.ownExerciseId(forName:)`, `ExerciseDatabase.swift:723`), `claude.*`.

## Dependencies
- Upstream: `ClaudeApply.apply` (Regel „iPhone gewinnt“ über `modifiedAt`), `ExerciseDatabase`.
- Downstream: Abschrift an Claude (#57) liest `modifiedAt`/`exerciseId`; Info-Blatt (Schnitt 3, `info(forId:)`).

## Existing Specs
- `DOCS/specs/features/feature-51-s2-bausteine-anwenden.md` (Nicht-in-Scope 2b, :126-134; Regel 8 :177; AC-12 :98)
- `DOCS/specs/features/feature-51-s2b-speichern.md` (2b-1, Nicht-in-Scope 2b-2)
- `DOCS/context/feature-51-s2b-speichern.md:109-116` — Vorfestlegungen für 2b-2: `modifiedAt = jetzt` in beiden `onSave`,
  nur bei echter Inhaltsänderung (Vergleich ohne `modifiedAt`); Schritt-Editor behält `claude.*`, solange die Übung nicht
  gewechselt wird; Test `migratingPresets` + Claude-Programm (setzt kein `modifiedAt`); offener Editor + Anwenden: Hennings
  Speichern gewinnt, `modifiedAt` gesetzt. Schätzung 3–4 Dateien, ~+60 Zeilen.

## Befunde (Ist-Stand, ohne Reproduktion)
1. `modifiedAt` wird in der Produktion nirgends gesetzt → „iPhone gewinnt“ greift heute nie.
2. Schritt-Editor: `claude.*` → beim Öffnen „Eigene Übung…“, beim Speichern `own.<slug>`, auch ohne Änderung.
3. Offener Editor: `draft` bleibt veraltet. Speichern ersetzt per id eine inzwischen höhere Revision durch die alte Kopie;
   wurde der Baustein zurückgenommen, hängt `onSave` ihn wieder an (`sets.append` / `presets.append`).
   Offen: ob `.onReceive` im nicht sichtbaren Tab feuert (für 2b-1 per UI-Test Tabwechsel abgedeckt).

## Risks & Considerations
- Fall 3 ist eine Produktentscheidung: Hennings Speichern gewinnt (Vorfestlegung) — gilt das auch bei zurückgenommenem
  Baustein (Wiederanlegen als eigener Baustein?) Mit gesetztem `modifiedAt` lehnt Claude danach folgerichtig ab.
- „Echte Änderung“ erfordert Vergleich ohne `modifiedAt`; Abbrechen/unverändert Speichern darf `modifiedAt` nicht setzen.
- Schritt-Änderung muss `modifiedAt` des Programms setzen (Programm ist der Baustein).
- Testlücke: kein Test für `claude.*` im Schritt-Editor oder `modifiedAt` im Editor.
