# Context: feature-51-s3-kennzeichen (#51 Schnitt 3)

## Request Summary
Gelieferte Programme und Atemübungen tragen in ihrer Liste ein kleines Zeichen „von Claude“; die bestehende Info-Ansicht zeigt
zusätzlich Datum, Paket und Warum. Gelieferte Übungen (`claude.*`) bekommen im Info-Blatt ihre Texte (heute „nicht verfügbar“).
Vor der Spec: Entwurf zum Ansehen (Heute / Entwurf / Alternative, Dunkel und Hell).

## Grundlage
- Elternspec `openspec/specs/features/claude-annahme.md` Verhalten 7, Tests „UI-Test: Zeichen ‚von Claude‘ und Warum in der Info-Ansicht“,
  Schnitt 3 (inkl. aus 2b verschobenem `claude.*` in `ExerciseDatabase.info(forId:)`).
- Konzept `DOCS/konzept-claude-verbindung.md` Z. 204 (Zeichen + Detail Datum/Paket/Warum), Z. 307 (gelieferte Trainings tragen den
  Hinweis „von Claude zusammengestellt, kein medizinischer Rat“), Z. 20 (direkt am Platz, gekennzeichnet).
- Issue-Text #51: „angepasst“, wenn Henning Geliefertes bearbeitet hat.

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | `WorkoutSetRow` (Z. 1238) Listenzeile; `PresetInfoSheet` (Z. 1330) Info-Ansicht Programm; `phaseRow` (Z. 1444) öffnet Übungs-Info über `exerciseId(forName:)` statt `phase.exerciseId` (Z. 1435) |
| `Meditationstimer iOS/Tabs/AtemView.swift` | `Row` Listenzeile; `PresetInfoSheet` (Z. 260) Info-Ansicht Atemübung |
| `Meditationstimer iOS/Services/ExerciseDatabase.swift` | `info(forId:)` (Z. 627) kennt nur den eingebauten Katalog; `displayName` (Z. 756) löst `claude.*` schon über den gespeicherten Namen |
| `Meditationstimer iOS/Models/ClaudeStore.swift` | `loadState` (privat) liest `claudeState` mit `exercises: [ClaudeStoredExercise]` |
| `Meditationstimer iOS/Models/ClaudeApply.swift` | `ClaudeOrigin` (itemId, revision, why, packageId, packageName, deliveredAt = createdAt); `mapCategory` englisch → `ExerciseCategory` |
| `Meditationstimer iOS/Views/ExerciseDetailSheet.swift` | Übungs-Info; Fallback „Übungsinformationen nicht verfügbar“ |
| `Meditationstimer iOS/Localizable.xcstrings` | DE/EN-Texte |
| `Meditationstimer iOS/Meditationstimer_iOSApp.swift` | DEBUG-Einstieg `uitest-claude-apply` + `UITEST_CLAUDE_DELIVERY` (Lieferung beim Start anwenden) – UI-Test-Hebel existiert |
| `LeanHealthTimerUITests/ClaudeSpeichernUITests.swift`, `ClaudeFelderUITests.swift` | bestehende Claude-UI-Tests, Muster `openTab(1)` nach Neustart |
| `Contracts/deliveries/valid/exercise-and-program.json`, `breath.json`, `breath-minimal.json`, `package-mixed.json` | Beispiel-Lieferungen für Tests |

## Existing Patterns
- Listenzeilen Workout und Atem sind baugleich (Glaskarte, Emoji + Name oben, Kennzahlen + Info + „…“ unten).
- Info-Knopf erscheint nur, wenn `description != nil`. Gelieferte Bausteine dürfen ohne `description` kommen (`breath-minimal.json`)
  → ohne Änderung gäbe es dort keinen Weg zu Datum/Paket/Warum.
- Info-Ansichten: `NavigationStack` + Abschnitte mit `.headline`/`.secondary`-Überschrift; „Empfohlene Anwendung“ fällt für unbekannte
  Namen auf den Standardtext „Regular execution for best results.“ zurück (bei Claude-Bausteinen inhaltsleer).
- UI-Kennungen: `workout.programRow.<Name>.start/.edit`; Atem-Zeilen haben keine Kennungen.

## Dependencies
- Upstream: `ClaudeOrigin` auf `WorkoutSet.claude` / `AtemView.Preset.claude`, `modifiedAt`; `claudeState.exercises`.
- Downstream: #57 (Abschrift), spätere Kennzeichnung weiterer Arten (Erinnerung, Challenge, Tracker; B4b–B6b).

## Existing Specs
- `openspec/specs/features/claude-annahme.md` (Elternspec), Rundenspecs `DOCS/specs/features/feature-51-*.md`.

## Risks & Considerations
- **#90 (offen):** Übungs-Info im Programm-Info-Blatt ist beim ersten Antippen leer (`.sheet(isPresented:)` + getrennter Name-State).
  Betrifft denselben Code (`phaseRow`). Nicht in Scope, aber ein UI-Test auf die Claude-Übungs-Info würde darüber stolpern →
  entweder #90 mitlösen (gleiche Zeilen, kleiner Eingriff: `.sheet(item:)`) oder Test so bauen, dass er nicht davon abhängt. Entscheidung in der Analyse.
- **#91 (offen):** Kategorie im Übungs-Info deutsch statt englisch – nicht in Scope.
- „Angepasst“: Bearbeitete Claude-Bausteine (`modifiedAt != nil`) – soll das Zeichen das zeigen? Produktfrage, im Entwurf zeigen.
- Gesundheits-Hinweis aus Konzept Z. 307 nur für Programme oder auch Atem? Produktfrage, im Entwurf zeigen.
- Watch/Widget kompilieren `Meditationstimer iOS` nicht mit (2b-1 belegt); Build-Wächter bleibt.
- Budget: voraussichtlich 4–5 Dateien (2 Views, ExerciseDatabase/ClaudeStore, ExerciseDetailSheet?, xcstrings), < 150 App-Zeilen.

## Analysis

### Type
Feature (#51 Schnitt 3, Elternspec `openspec/specs/features/claude-annahme.md` Verhalten 7)

### Entwurf (PO-Freigabe ausstehend)
Artefakt https://claude.ai/artifact/WuKWhnEjMVANcCUvHDwZis, Quellen `DOCS/artifacts/feature-51-s3-kennzeichen/project/` (Generator-Ausgabe), Heute-Screenshots `heute-zeile-dark.png`/`-light.png`.
- Empfohlen: Kapsel „von Claude“ unter dem Namen (Workout- und Atem-Zeile); bei `modifiedAt != nil` „von Claude · angepasst“. Info-Knopf bei `claude != nil` immer (auch ohne `description`).
- Info-Ansicht (beide): Abschnitt „Von Claude“ unten: „Geliefert am <Datum> · Paket „<packageName>““ (Paketteil nur, wenn vorhanden), Warum (kein Gesundheitshinweis, PO 2026-11-22). „Empfohlene Anwendung“ entfällt bei `claude != nil`.
- Übungs-Info `claude.*`: Name, Kategorie, Wirkung, Ausführung (+ Hinweise falls `notes`), darunter „Von Claude geliefert am <Datum>“.
- Alternative: nur Funkel-Symbol hinter dem Namen (kein Text, „angepasst“ nicht darstellbar), Herkunft als Karte oben in der Info.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Models/ClaudeStore.swift` | MODIFY | öffentliche Lesefunktion `storedExercise(id:defaults:)` über das private `loadState`; Abbildung auf `ExerciseInfo` (Kategorie über `mapCategory`, Fallback falls nil); kleine gemeinsame Views `ClaudeOriginBadge` und `ClaudeOriginSection` + reine Funktion Kapseltext |
| `Meditationstimer iOS/Views/ExerciseDetailSheet.swift` | MODIFY | Zweig: `claude.*` → ClaudeStore, sonst `ExerciseDatabase.info(forId:)`; Herkunftszeile |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | MODIFY | `WorkoutSetRow` Kapsel + Info-Knopf-Bedingung; `PresetInfoSheet` Abschnitt + „Empfohlene Anwendung“ ausblenden; `phaseRow` → `.sheet(item:)` mit `phase.exerciseId` (löst #90 mit) |
| `Meditationstimer iOS/Tabs/AtemView.swift` | MODIFY | `Row` Kapsel + Info-Knopf-Bedingung + Kennungen; `PresetInfoSheet` Abschnitt |
| `Meditationstimer iOS/Localizable.xcstrings` | MODIFY | DE/EN: „von Claude“, „angepasst“, „Von Claude“, „Geliefert am %@“, „Paket „%@““ |
| `LeanHealthTimerTests/ClaudeKennzeichenTests.swift` | CREATE | Unit-Tests (zählen nicht zum Budget) |
| `LeanHealthTimerUITests/ClaudeKennzeichenUITests.swift` | CREATE | UI-Tests mit `uitest-claude-apply` + `package-mixed.json`, `breath-minimal.json` |

### Scope Assessment
- Files: 5 App-Dateien + 2 Testdateien
- Estimated LoC: +150 bis +200 / -10 (App-Code)
- Risk Level: LOW–MEDIUM (nur Anzeige; zentrale Stelle ist die Programm-Info-Übungsauflösung)

### Technical Approach
- `claude.*` NICHT in `ExerciseDatabase.info(forId:)` auflösen: Funktion ist rein/statisch; Aufrufer (WorkoutProgramsView:292, :1675, ClaudeApply:104 `resolveStepName`) setzen „nur Katalog“ voraus → Auflösung in ClaudeStore + Zweig im Sheet. Elternspec-Satz „in `ExerciseDatabase.info(forId:)` auflösen“ wird in der Rundenspec entsprechend präzisiert (Ziel: einziger Verbraucher Info-Blatt bekommt die Texte).
- #90 mitlösen: Ursache dieselben Zeilen (`.sheet(isPresented:)` + getrennter Name-State + Namensauflösung `exerciseId(forName:)`, die für `claude.*` nie trifft). `.sheet(item:)` mit Identifiable (Name + `phase.exerciseId`). Gehört zum Feature, nicht Drive-by.
- Kapsel und Abschnitt als zwei kleine Structs in einer vorhandenen Datei (Budget 5 Dateien), von beiden Tabs genutzt.
- Datum über `Date.FormatStyle` (sprachabhängig). Ausblenden „Empfohlene Anwendung“ an `claude != nil`, nicht am Text.
- Neue Kennungen: `atem.row.<Name>.info`, `…claudeBadge`, `workout.programRow.<Name>.info/.claudeBadge`.
- `mapCategory`: gespeicherte Übungen sind bei Annahme geprüft (Regel 12), Fallback trotzdem (z. B. `.core`/erste Kategorie), damit nie „nicht verfügbar“ wegen Kategorie.

### Tests (Vorschlag)
- Unit: `testStoredExerciseResolvesClaudeIdFromState`, `testStoredExerciseReturnsNilForUnknownOrBuiltinId`, `testExerciseInfoMapsCategoryEffectInstructions`, `testBadgeTextShowsAngepasstWhenModified`, `testBadgeTextPlainWhenNotModified`.
- UI: `testWorkoutRowShowsClaudeBadgeAndInfoShowsPackageAndWhy`, `testBreathRowShowsClaudeBadgeAndInfo`, `testClaudeExerciseInfoShowsTextsOnFirstTap` (deckt #90), `testBuiltinProgramHasNoClaudeBadge`, `testBreathMinimalDeliveryStillHasInfoButton`, `testEditedClaudeProgramShowsAngepasst`.

### Dependencies
Upstream `ClaudeOrigin`, `modifiedAt`, `claudeState` (Schnitte 2a/2b). Downstream #57, B4b–B6b. Watch/Widget kompilieren `Meditationstimer iOS` nicht (pbxproj geprüft) → keine Wirkung dort; Build-Wächter bleibt.

### Alternativen
- Auflösung direkt in `ExerciseDatabase.info(forId:)` (wie Elternspec wörtlich): verworfen, verändert drei Katalog-Aufrufer.
- Kennzeichen als Symbol ohne Text: im Entwurf als Alternative.
- #90 getrennt lassen: dann müsste der UI-Test um den Erst-Tipp-Fehler herumgebaut werden; verworfen.

### Open Questions
- [x] PO 2026-11-22: Kapsel mit Text „von Claude“ (Empfehlung angenommen)
- [x] PO 2026-11-22: „von Claude · angepasst“ zeigen (Empfehlung angenommen)
- [x] PO 2026-11-22: **KEIN Gesundheitshinweis** („Das hat ja der User mit Claude für sich generiert. Ich finde den Hinweis übertrieben.“) — weder Programme noch Atem; Konzept Z. 307 damit für die App-Anzeige aufgehoben
