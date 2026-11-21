# Context: feature-51-s2a2-uebungen (#51 Schnitt 2a, Runde 2a-2)

## Request Summary
Runde 2a-2 der freigegebenen Spec `DOCS/specs/features/feature-51-s2-bausteine-anwenden.md` umsetzen:
Übungen aus einer Claude-Lieferung anwenden (`ClaudeStoredExercise`, `state.exercises`), englische Kategorie auf
`ExerciseCategory` abbilden (`CATEGORY_UNKNOWN`), Namensauflösung für `own.*` und `claude.*` in Programmschritten.
Die Spec-Freigabe gilt für alle drei Runden (Spec, Abschnitt Approval); 2a-1 ist gemergt (PR #106).

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Models/ClaudeApply.swift` (122 Zeilen) | MODIFY: `ClaudeStoredExercise`, `exercises` im Zustand, `applyExercise`, `mapCategory`, Erweiterung `resolveStepName`, `.exercise`-Fall im `apply`-Switch statt `KIND_NOT_SUPPORTED` |
| `LeanHealthTimerTests/ClaudeApplyTests.swift` (511 Zeilen) | MODIFY: 9 neue Tests, 2 befristete löschen, Hilfsfunktion `empty()` um `exercises: []` erweitern |
| `Meditationstimer iOS/Models/ClaudeDelivery.swift` | nur lesen: `ClaudeExercise` (itemId, revision, name, nameEn?, category, effect, instructions, notes?) — `read` prüft die Kategorie NICHT, ein unbekannter Wert kommt also bis `apply` |
| `Meditationstimer iOS/Models/ExerciseInfo.swift:57` | nur lesen: `enum ExerciseCategory: String, CaseIterable` mit Fallnamen strength … cooldown und deutschen Rohwerten |
| `Contracts/deliveries/valid/exercise-and-program.json`, `own-exercise-reference.json`, `exercise-minimal.json`, `exercise-update-same-name.json` | Beispielsätze für die Tests |

## Existing Patterns
- `applyProgram`/`applyBreath`: Index über `claude?.itemId`, `revision <=` → `.noEffect`, sonst ersetzen mit gleicher UUID bzw. anhängen; `origin(...)` baut `ClaudeOrigin`. `applyExercise` folgt demselben Muster, ohne `modifiedAt`-Prüfung (Regel 8: Übungen nie `CHANGED_ON_IPHONE`).
- Arbeitskopie `work`; am Ende werden nur bei Nicht-Ablehnung die Listen übernommen — `final.exercises = work.exercises` muss ergänzt werden.
- Kategorie-Abbildung über Fallnamen: `ExerciseCategory.allCases.first { "\($0)" == text }` (CaseIterable vorhanden, kein Eingriff in `ExerciseInfo.swift`).

## Dependencies
- Upstream: `ClaudeDelivery`, `ExerciseDatabase.info(forId:)`, `ExerciseCategory`, `WorkoutSet`/`WorkoutPhase`, `AtemView.Preset`.
- Downstream: keine App-Aufrufer (nur Tests); Watch und Widget kompilieren die Datei mit (synchronisierter Ordner) → nur `Foundation`.

## Existing Specs
- `DOCS/specs/features/feature-51-s2-bausteine-anwenden.md` — Regeln 1, 6, 7, 10, 12; AC-1b, 6b, 12, 13b, 16, 19
- `DOCS/specs/features/feature-51-lieferung-annehmen.md` — Schnitt 1 (Lesen)

## Risks & Considerations
- `resolveStepName` braucht für `claude.*` die Lieferung und für `claude.*`/`own.*` den Arbeitszustand → Signatur bekommt Lieferung und Zustand, nicht nur die Kennung.
- **Geklärt:** „Übung derselben Lieferung" (Regel 10) heißt jede `exercise`-Position der Lieferung, auch eine spätere. Beleg: `Contracts/deliveries/valid/program-before-exercise.json` („Der Bezug gilt auch, wenn die Übung erst nach dem Programm in der Liste steht"), und 2a-3 verlangt, dass alle lesbaren Beispiele anwendbar sind. Also zuerst in `delivery.items` suchen, dann in `state.exercises` — nicht nur in den bereits angewendeten Positionen (`work.exercises`). Den Fall im RED-Schritt mit abdecken (in `testClaudeVerweisNutztLieferungOderZustand`).
- Neues Feld `exercises` ändert die Aufrufform von `ClaudeApplyState(...)` — nur Tests betroffen.
- Budget: App kalibriert ~98 von 250 Zeilen.
- Keine gespeicherten Typen ändern sich (kein Aktualisierungsnachweis nötig, kein UI-Test laut Spec).

## Analysis

### Type
Feature (Runde 2a-2 der freigegebenen Spec `DOCS/specs/features/feature-51-s2-bausteine-anwenden.md`; die Freigabe gilt für alle drei Runden, keine neue Spec nötig — `/30-write-spec` bestätigt nur den Rundenzuschnitt).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Models/ClaudeApply.swift` | MODIFY | `ClaudeStoredExercise`; `exercises` in `ClaudeApplyState`; `applyExercise`; `mapCategory`; `resolveStepName(_:in:state:)` für `builtin.*`/`claude.*`/`own.*`; `.exercise`-Fall im `apply`-Switch; `final.exercises = work.exercises` |
| `LeanHealthTimerTests/ClaudeApplyTests.swift` | MODIFY | 9 neue Tests (AC-1b, 6b, 12, 13b, 16); löschen: `testUebungslieferungNochNichtUnterstuetzt`, `testProgrammMitOwnOderClaudeVerweisLehntMitExerciseUnknownAb`; `empty()` um `exercises: []` |

`ClaudeApplyState` wird außerhalb dieser zwei Dateien nirgends benutzt (geprüft per `grep -rl`, 2026-11-21).

### Scope Assessment
- Files: 2 (1 App, 1 Test)
- Estimated LoC: App ~+65/-5 (kalibriert ~98 von 250), Test ~+160/-40 (zählt nicht)
- Risk Level: LOW — keine Aufrufer in der App, keine gespeicherten Typen, nichts Sichtbares

### Technical Approach
Wie in der Kontext-Datei, mit drei Festlegungen aus der strategischen Prüfung (Plan/Sonnet, 2026-11-21):
1. **Kategorie vor Revision prüfen** in `applyExercise`: Eine unbekannte Kategorie lehnt die Lieferung mit `CATEGORY_UNKNOWN` ab, auch wenn die `revision` sonst `noEffect` ergäbe — so geht eine ungültige Kategorie nie still durch (Spec Regel 12 sagt „lehnt die Lieferung ab“ ohne Ausnahme).
2. **Namensauflösung immer gegen die Arbeitskopie `work`** (Regel 1: spätere Positionen sehen frühere): `own.*` aus Phasen in `work.sets`, `claude.*` zuerst aus jeder `exercise`-Position der Lieferung (auch spätere, Beleg `program-before-exercise.json`), dann aus `work.exercises`.
3. **Regel 8 gilt für Übungen nicht** (Spec Z. 177: „Übungen haben kein `modifiedAt` und werden nie so abgelehnt“) → kein `isBlockedByIphone` in `applyExercise`.
- Kategorie-Abbildung über Fallnamen `ExerciseCategory.allCases.first { "\($0)" == text }`, gespeichert wird der englische Text; `ExerciseInfo.swift` bleibt unverändert.

**Dokumentierter Randfall:** Liefert Claude eine Übung mit gleicher/niedrigerer `revision` (`noEffect`) und anderem Namen, nimmt eine Programmphase derselben Lieferung den Namen aus der Lieferung (Spec Regel 10 wörtlich: „Name der Übung derselben Lieferung, sonst aus `state.exercises`“). Wird im Test als Kommentar festgehalten, keine PO-Frage.

**Alternative (verworfen):** `claude.*` nur aus bereits angewendeten Positionen (`work.exercises`) auflösen. Einfacher, scheitert aber an `program-before-exercise.json` und damit an AC-2 in 2a-3.

### Dependencies
`ClaudeDelivery` (`ClaudeExercise`, `ClaudeItem`), `ExerciseDatabase.info(forId:)`, `ExerciseCategory`, `WorkoutSet`/`WorkoutPhase`. Nur `Foundation` (Watch/Widget kompilieren die Datei mit; Builds aller drei Ziele in der DoD).

### Reihenfolge
RED (Tests + 2 Löschungen; RED-Beleg = Übersetzungsfehler, `ClaudeStoredExercise`/`exercises` fehlen) → Typen → `mapCategory` → `resolveStepName` neue Signatur (auch `applyProgram` ruft mit `work`) → `applyExercise` + Switch-Fall → `final.exercises`.

### Open Questions
- keine
