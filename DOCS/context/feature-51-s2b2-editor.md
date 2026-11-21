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

## Analysis

### Type
Feature (Restpunkte Schnitt 2b, Runde 2b-2)

### Befunde am Code (2026-11-21, gelesen)
- `onSave` in `WorkoutTab.swift:146-153` / `MeditationTab.swift:173-180` ersetzt per id oder hängt an; `modifiedAt` bleibt
  unberührt. `isBlockedByIphone` (`ClaudeApply.swift:86-89`) greift deshalb heute nie.
- Wichtig: Solange #57 fehlt, ist `lastSnapshotAt == nil` → ein gesetztes `modifiedAt` sperrt **jede** weitere Lieferung und
  Rücknahme dieses Bausteins (`CHANGED_ON_IPHONE`), bis Claude neu liest. Das ist Regel 8, gewollt.
- Neuer Befund zu Fall 3: Speichert Henning im veralteten Editor **ohne Änderung**, überschreibt `onSave` heute eine
  inzwischen gelieferte höhere Revision mit der alten Kopie — ohne `modifiedAt`, also unbemerkt für Claude. Lösung:
  unverändertes Speichern schreibt gar nicht.
- Das Original, mit dem der Editor geöffnet wurde, liegt im Tab bereits vor (Closure-Parameter `set`/`preset` von
  `.sheet(item:)`). Der Editor ändert `modifiedAt` nie → `edited == original` ist ein exakter „unverändert“-Test.
- `PhaseEditorView.init` (`WorkoutProgramsView.swift:1669-1671`) wertet `claude.*` als eigene Übung; Speichern ruft
  `apply(.own(name:))` (:1770-1772) → `own.<slug>`, auch ohne Namensänderung.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Models/ClaudeStore.swift` | MODIFY | reine Hilfsfunktion `savingEdit(edited, original, in:, modifiedAt: keyPath, now:) -> [T]?` (nil = unverändert, nichts schreiben; sonst ersetzt/angehängt mit `modifiedAt = now`) |
| `Meditationstimer iOS/Tabs/WorkoutTab.swift` | MODIFY | `onSave` nutzt die Hilfsfunktion |
| `Meditationstimer iOS/Tabs/MeditationTab.swift` | MODIFY | `onSave` nutzt die Hilfsfunktion |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | MODIFY | Schritt-Editor: `claude.*` behalten, wenn der Name der eigenen Übung unverändert ist (kleine `mutating func` an `WorkoutPhase`, testbar) |
| `LeanHealthTimerTests/…` | CREATE/MODIFY | Unit: Hilfsfunktion (unverändert/geändert/zurückgenommen/neu), `claude.*` behalten/wechseln, `migratingPresets` + Claude-Programm setzt kein `modifiedAt` |
| `LeanHealthTimerUITests/…` | MODIFY | Durchlauf: Claude-Programm liefern → bearbeiten → neue Revision liefern (Neustart, Disk-Store) → Hennings Fassung bleibt |

### Scope Assessment
- Files: 4 App-Dateien + Tests
- Estimated LoC (App): +40/-10
- Risk Level: LOW — nur Speicherpfad der beiden Editoren und eine Zeile im Schritt-Editor; `ClaudeApply.swift` unverändert

### Technical Approach
Empfehlung: „Hennings Speichern gewinnt“ (Vorfestlegung 2b-1) konsequent über eine reine Hilfsfunktion im Tab umsetzen.
1. Unverändert gespeichert (`edited == original`) → nichts schreiben, kein `modifiedAt`. Das schließt die stille Überschreibung.
2. Geändert → per id ersetzen bzw. anhängen, `modifiedAt = jetzt`. Fehlt der Baustein inzwischen (zurückgenommen), hängt das
   Speichern ihn als Hennings Fassung wieder an (bisheriges Verhalten, jetzt mit `modifiedAt`), Claude-Rücknahmen werden
   danach bis zur nächsten Abschrift abgelehnt.
3. Schritt-Editor: Bei `claude.*` und unverändertem Übungsnamen bleibt die Kennung; nur ein anderer Name/Katalogwechsel setzt
   `own.*`/`builtin.*`. Schritt-Änderungen erreichen das Programm über den Programm-Editor → Punkt 2 setzt `modifiedAt`.

Alternativen:
- (B) Offenen Editor bei eintreffender Lieferung schließen oder warnen: zusätzliche Oberfläche, mehr Code, kippt nichts
  Festgelegtes, aber widerspricht „einfach statt kompliziert“. Verworfen.
- (C) Speichern eines zurückgenommenen Bausteins legt einen eigenen Baustein ohne Claude-Herkunft an (`claude = nil`,
  neue id): saubere Trennung, Claude kann ihn nie wieder anfassen; kippt die Vorfestlegung „Hennings Speichern gewinnt“
  nicht, ändert aber die Herkunft. Mehr Code, kein Nutzen für Henning sichtbar. Nicht empfohlen.
- (D) `modifiedAt` nur bei Claude-Bausteinen setzen: spart nichts, Feld heißt „letzte Änderung durch den Nutzer“; verworfen.

### Dependencies
`ClaudeApply.isBlockedByIphone` (liest `modifiedAt`), `ClaudeStore.load*`, `ExerciseDatabase.ownExerciseId`. Downstream #57
(Abschrift liest `modifiedAt`/`exerciseId`), Schnitt 3 (Info-Blatt).

### Open Questions
- keine PO-Frage: Fall 3 ist durch die Vorfestlegung „Hennings Speichern gewinnt“ entschieden; der Fall „zurückgenommen“
  folgt daraus (Wiederanlegen als Hennings Fassung).
