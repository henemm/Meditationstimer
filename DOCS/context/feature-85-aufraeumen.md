# Context: feature-85-aufraeumen (#85, Schnitt A2c-2 von #48)

## Request Summary
Letzter Schnitt des Übungskatalogs (#48): die ungenutzte alte Übungs-Vorschlagsliste aus `WorkoutProgramsView.swift`
entfernen und `openspec/specs/features/workouts.md` um Szenarien für Hinweiszeile, Hinweisansage und Katalog mit
Kennungen ergänzen (AC-26, AC-29). Für den Nutzer ändert sich nichts.

## Ist-Stand (gemessen 2026-11-20, Branch nach A2c-1)
- **Großteil schon erledigt durch #101 (Commit faebfef, „tote äußere Ansichten … entfernt"):** `WorkoutProgramsView`
  ist bereits `enum WorkoutProgramsView` (Z. 473) als reiner Namensraum; der tote Bildschirm, `loadSets`/`saveSets`,
  `@State`-Felder, `legacyDefaultWorkoutSets` (10er-Vorgabeliste) und der Nicht-iOS-Rückfall sind weg
  (`grep legacyDefault` = 0 Treffer). Die Spec-Beschreibung A2c-2 (Struct → Enum, rund 400 Zeilen weg) ist damit
  überholt.
- **Rest im Code:** `private let exerciseSuggestions: [String]` (Z. 385–469, 69 Namen, `.sorted()`), einziger Treffer
  im ganzen Repo ist die Deklaration selbst — keine Aufrufer (Swift warnt dazu nicht, weil `private let` auf
  Dateiebene).
- `getNextAnnouncementText(afterIndex:)` (Z. 1209) hat ebenfalls keine Aufrufer; laut Spec nur entfernen, wenn beim
  Aufräumen berührt — wird nicht berührt, bleibt.

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | `exerciseSuggestions` Z. 385–469 entfernen (~85 Zeilen) |
| `openspec/specs/features/workouts.md` | Szenarien ergänzen: Hinweiszeile (Req. „Workout Programs"), Hinweisansage (Req. „Audio Cues", „Exercise Hint TTS"), Katalog mit Kennungen und 67 Übungen (Req. „Exercise Database") |
| `DOCS/specs/features/feature-48-uebungskatalog.md` | Quelle der Regeln (Entscheidungen 1, 10, 11; AC-26, AC-29); Abschnitt A2c-2 an Ist-Stand anpassen |
| `Meditationstimer iOS/Localizable.xcstrings` | **bleibt unverändert**: 54 der 69 Listennamen sind Schlüssel, aber weiter zur Laufzeit gebraucht (`Text(LocalizedStringKey(phase.name))` zeigt gespeicherte englische Namen übersetzt; `ExerciseDatabase` mappt sie in `englishNameIds`) |

## Existing Patterns
- Vorherige Aufräum-Runden #99/#101: reine Löschung, Beleg per Codesuche + Build + Unit-Suite.
- Spec-Szenarien in `workouts.md`: GIVEN/WHEN/THEN/AND-Format, englisch.

## Dependencies
- Upstream: keine (Liste ist Blatt).
- Downstream: keine Verweise (Codesuche über alle Swift-Ordner und Tests).

## Risks & Considerations
- Kein Laufzeitrisiko, da unreferenziert; Build ist der Beweis.
- Die xcstrings-Schlüssel dürfen nicht mitgelöscht werden (s. o.), sonst zeigen alte Programme englische Namen.
- AC-29-Endprüfung (komplette UI-Suite am Ende von A2c-2, Watch-/Widget-Scheme bauen) gehört zu diesem Schnitt.

## Analysis

### Type
Feature (Aufräumen + Doku-Nachzug, Schnitt A2c-2 von #48), für den Nutzer unsichtbar.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | MODIFY | Z. 385–469 löschen (MARK „Exercise Suggestions List", Doc-Kommentar, `private let exerciseSuggestions … .sorted()`); MARK Z. 471 „Main View (Placeholder for Phase 1)" → „Namespace" |
| `openspec/specs/features/workouts.md` | MODIFY | 3 neue Szenarien + 2 Korrekturen (siehe Ansatz) |
| `DOCS/specs/features/feature-48-uebungskatalog.md` | MODIFY | A2c-2-Beschreibung an Ist-Stand (Z. 171, 188, 208, 229) + Protokollzeile |

Nicht geändert: `Localizable.xcstrings` (englische Schlüssel weiter gebraucht über `Text(LocalizedStringKey(phase.name))`, Z. 529/1111/1326/1448/1524/1623), `getNextAnnouncementText` (Z. 1209, nicht berührt), Watch/Widget.

### Scope Assessment
- Files: 3 (davon 2 Doku)
- Estimated LoC: Code −85; Doku ca. +35 (`workouts.md`) und ca. ±15 (Katalog-Spec)
- Risk Level: LOW — gelöscht wird nur eine unreferenzierte Konstante (Codesuche: einziger Treffer ist die Deklaration Z. 388; Tests, Watch, Widget ohne Treffer; `WorkoutProgramsView()` nirgends instanziiert).

### Technical Approach
1. Katalog-Spec an Ist-Stand anpassen: Struct→Enum-Umbau, Instanz-Member, 10er-Vorgabeliste und `loadSets`/`saveSets` sind schon durch #101 (faebfef) entfernt; A2c-2 schrumpft auf „`exerciseSuggestions` entfernen + Doku". Z. 208 („englische Schlüssel entfernen, falls nichts mehr verweist"): Bedingung nicht erfüllt, Schlüssel bleiben — so vermerken. Nicht-iOS-Rückfall (Z. 229): existiert nicht mehr (Datei hat nur `#if os(iOS)` … `#endif`, kein `#else`), entfällt.
2. `exerciseSuggestions` samt MARK und Doc-Kommentar löschen; MARK „Placeholder" berichtigen.
3. `workouts.md` (englisch, GIVEN/WHEN/THEN/AND):
   - Requirement „Workout Programs": neues Szenario „Exercise Hint Line" — Hinweis unter dem Ring nur in der Arbeitsphase (auch pausiert), nicht in der Vorschau „Als nächstes"; eine Zeile, höchstens 80 UTF-16-Einheiten, leer → keine Zeile (Entscheidungen 1, 9, 10).
   - Requirement „Audio Cues": neues Szenario „Exercise Hint TTS" (Entscheidung 11) — „. Hinweis" angehängt an die vier bestehenden Sätze; ohne Hinweis wörtlich unverändert; beide Sprechstellen (erste Übung nach Countdown, Pausenbeginn mit nächster Übung); nur mit `speakExerciseNames`.
   - Requirement „Exercise Database": neues Szenario „Exercise Catalog Identifiers" — 67 Übungen, Kennungen `builtin.*`/`own.*`/`claude.*`, Ableitung aus dem Namen bei fehlender Kennung, Info-Knopf sucht per Kennung; Katalog in `Contracts/catalog/builtin-exercises.json`.
   - Korrektur „Program Selection": „10+ default programs" → „4 default programs" (live `defaultWorkoutSets`), Schritte mit Kennung.
   - Korrektur „Exercise Name TTS (Workout Programs)": gesprochen werden „Übung %d von %d: Name", „letzte Übung: Name" (kleines l), „Runde %d von %d: Name", „Letzte Runde: Name" — nicht „Als nächstes: …" (das ist nur der sichtbare Pausentext).
4. Prüfung: Codesuche (AC-29), Build iOS + Watch- und Widget-Scheme, komplette Unit-Suite, komplette UI-Suite (AC-29/AC-31, Altlast #25 belegen), App-Durchlauf im Simulator (Programm bearbeiten, Hinweis eingeben, Training starten).

Alternative (verworfen): nur die Code-Löschung jetzt, Doku-Nachzug als eigenes Issue — verletzt AC-26 und Spec-Widerspruch 3, der den Nachzug ausdrücklich in A2c-2 legt.

### Dependencies
Upstream keine (Liste ist Blatt), downstream keine Verweise. Folgt auf A2c-1 (#84, validiert PASS). Letzter Schnitt von #48; danach Epic-Abschluss.

### Open Questions
- keine (reines Aufräumen, keine Produktentscheidung)
