# Context: feature-57-s3-abschrift (#57 Schnitt 3)

## Request Summary
Die App erzeugt die Abschrift Fassung 1 (Übungen, Programme, Atemübungen mit Herkunft, letzte 50 Lieferergebnisse) als JSON
nach `Contracts/transcript/transcript-v1.schema.json`. Ein Unit-Test erzeugt sie aus festen Beständen und vergleicht mit
eingecheckten Goldendateien; die Contracts-CI prüft diese Goldendateien gegen das Schema. Noch kein Versand (Schnitt 4).

## Related Files
| Datei | Relevanz |
|---|---|
| `Contracts/transcript/transcript-v1.schema.json` | Format: required version(=1), generatedAt (UTC, Z), exercises ≤500, programs ≤200, breaths ≤200, deliveries ≤50; `$defs` anyId `^(builtin\|own\|claude)\.`, exercise (:151), step (:97), breath, program; builtin/own dürfen keine Claude-Felder tragen, claude braucht `state` |
| `Contracts/transcript/valid/{empty,full}.json`, `invalid/` (16) | Beispiele als Hülle `{description, transcript, expected}` |
| `Contracts/catalog/builtin-exercises.json` | Katalog fester `builtin.*`-Kennungen der mitgelieferten Übungen |
| `Contracts/validator/` (ajv ^8.20, Ajv2020; `npm test` = tsc + node --test) | Prüft heute nur Lieferungen (`helpers.ts:5-6,18-35`); **kein Test für Transcript-Dateien** |
| `.github/workflows/contracts.yml` | Läuft bei Änderungen unter `Contracts/**`; führt nur `npm test` im Validator aus → CI-Schritt fehlt |
| `server/src/transcripts.ts`, `server/src/app-routes.ts:10,119-127` | Server: Ajv strict, doppelte Kennungen, echte Kalenderdaten; Körper ≤256 KiB; 400 bei invalid |
| `server/test/transcripts.test.ts:11,16-25` | Liest `Contracts/transcript` (Hülle auspacken) |
| `Meditationstimer iOS/Models/ExerciseInfo.swift:8,46-57` | Übung mit `id`, Origin-Enum, Kategorie mit **deutschen** Rohwerten → Abbildung auf Schema-Enum nötig |
| `Meditationstimer iOS/Models/ClaudeApply.swift:11-49,76` | `ClaudeOrigin` (itemId, revision, why, packageId, packageName, deliveredAt), `ClaudeApplyLogEntry` (deliveryId, result, at), Log ≤50, `ClaudeApplyResult` applied/noEffect/rejected |
| `Meditationstimer iOS/Models/ClaudeStore.swift:18-20,41-43` | UserDefaults: `workoutProgramSets`, `atemPresets`, `claudeState` (`ClaudeStoredExercise`, Log) |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:166` | `WorkoutSet` (Codable, UUID-Kennung, kein `builtin.`-Präfix) |
| `Meditationstimer iOS/Tabs/AtemView.swift:43`, `Models/BreathPreset.swift:44` | `AtemView.Preset` (Codable) bzw. `BreathPreset` |
| `Meditationstimer iOS/Models/ClaudeDelivery.swift:11-59` | Eingabe-DTOs, nur von Hand gelesen; keine Encoder |
| `LeanHealthTimerTests/ClaudeDeliveryDecodingTests.swift:7,22-24` | Muster: Fixtures aus `Contracts/` über `#filePath` laden |
| `.github/workflows/ios-tests.yml` | Unit-Tests (`LeanHealthTimerTests`) auf macos-26 laufen in CI → Goldendatei-Vergleich läuft dort mit |
| `DOCS/context/analyse-51-57-claude-app.md:17-18,61,85,100-101,131,152` | Plan: `TranscriptBuilder.swift`, Goldendateien `Contracts/transcript/app-generated/*.json`; Vorbild Loose Ends `TranscriptCodecTests.swift:302` |

## Existing Patterns
- Fixtures aus `Contracts/` per `#filePath` im Unit-Test lesen (ClaudeDeliveryDecodingTests).
- Validator-Tests in TypeScript mit Ajv2020 über Verzeichnisse (helpers.ts) — neuer Test für `transcript/valid|invalid` und `app-generated` analog.
- Persistenz der Bausteine in UserDefaults über `ClaudeStore`; Herkunft über `ClaudeOrigin`.

## Dependencies
- Upstream: `ClaudeStore`/`ClaudeApply` (#51), `ExerciseInfo`, `WorkoutSet`, `AtemView.Preset`, Katalog builtin-Kennungen.
- Downstream: Schnitt 4 (`ServiceClient.putTranscript`, Abgleich) ruft den Builder auf; Fassung 2 (#59) erweitert ihn.

## Existing Specs
- `openspec/specs/features/claude-verbindung-app.md` (Verhalten 3.2, Tests, Schnitt 3)
- `DOCS/specs/features/feature-57-s1-bausteine.md`, `-s2-serviceclient.md`, `-s2b-accountstate.md`

## Risks & Considerations
- **Abbildungsfragen für die Analyse:** `noEffect` → accepted oder rejected? (Schema kennt nur accepted/rejected.) Deutsche Kategorie-Rohwerte → englisches Enum. Kennungen der Programme/Atemübungen: UUID → `own.<uuid>`, Claude-Bausteine → `claude.*` aus `ClaudeOrigin.itemId`; gibt es mitgelieferte Programme/Atemübungen (`builtin.*`)?
- `state` (active/adapted/withdrawn) für Claude-Bausteine: Quelle im App-Modell klären.
- Schema-Grenzen (Name 1–40, Hinweis ≤80, Schritte 1–40, Sekunden 1–600 …): App-Daten können darüber liegen → kürzen oder weglassen, sonst lehnt der Dienst die ganze Abschrift ab.
- Deterministische Ausgabe (sortierte Schlüssel, fester Zeitstempel, feste Reihenfolge), sonst flattern Goldendateien.
- Zeilengrenze 250 App-Code: Builder mit allen Abbildungen kann eng werden → ggf. Schnitt 3a/3b.
- Doppelte Kennungen und Kalenderdaten prüft nur der Server, nicht das Schema → im Swift-Test zusätzlich absichern.
- Loose-Ends-Vorbild (`LooseEnds/Claude`, `TranscriptCodecTests`) konnte nicht gelesen werden (Leserecht außerhalb des Arbeitsordners) — Analyse muss ohne oder mit Freigabe auskommen.

## Analysis

### Type
Feature (#57 Schnitt 3: Abschrift Fassung 1 + Goldendateien + CI-Schritt). Noch kein Versand (Schnitt 4).

### Befunde (24.11.2026, 3 Erkundungen + Plan-Bewertung)
- Claude-`itemId` hat laut Lieferschema schon das Format `^claude\.[a-z0-9][a-z0-9-]{1,62}$` (`Contracts/schema/delivery-v1.schema.json` `$defs.itemId`) → direkt als `id` verwendbar.
- Eigene Übungen haben keinen Speicher und **keine Kategorie**; sie existieren nur als Schritt (`WorkoutPhase.exerciseId = own.<slug>`, `WorkoutProgramsView.swift:208-258`). Schema verlangt `category` → nicht ohne erfundene Daten abbildbar.
- Server und Schema prüfen **nicht**, ob `steps[].exerciseId` in `exercises` steht (`server/src/transcripts.ts`: nur `duplicateId` :47-56, `calendarProblem` :88-105). Schritte mit `own.*` ohne Listeneintrag sind gültig.
- Zurückziehen **entfernt** den Baustein (`ClaudeApply.swift:171-186`) → `withdrawn` kommt in der Abschrift nie vor (Abweichung von `analyse-51-57-claude-app.md:90`, dort „nie löschen“; nicht Teil dieses Schnitts).
- Zustand: `adapted` = `claude != nil && modifiedAt != nil` (`ClaudeStore.swift:101-105`), sonst `active`. Claude-Übungen haben kein `modifiedAt` → immer `active`.
- Vorgaben (4 Programme `WorkoutTab.swift:800-858`, 6 Atemübungen `MeditationTab.swift:70-81`) nur per Name erkennbar, editierbar.
- `ClaudeStore.loadSets/loadPresets` (:61-76) liefern bei fehlendem Key Vorgaben und schreiben bei Unlesbarem ein Backup (`WorkoutProgramsView.swift:339-349`) → für die Abschrift ungeeignet. `loadState` privat; Log und Claude-Übungen nicht öffentlich lesbar.
- Neue Programme starten mit leeren Schritten (`WorkoutTab.swift:104-109`) → verletzen `steps minItems 1`.
- Eigene UUIDs sind großgeschrieben, Schema verlangt Kleinbuchstaben.
- Kein ISO8601-Ausgabeformatierer im Projekt; Persistenz-Daten sind `Date` (Sekunden seit 2001).
- Neue Dateien in `Meditationstimer iOS/` und `LeanHealthTimerTests/` sind synchronisierte Gruppen → keine `project.pbxproj`-Änderung. Watch/Widget nutzen keinen betroffenen Typ.
- CI: Transcript-Beispiele `valid/invalid` prüft heute nur `server/test/transcripts.test.ts` (server.yml). `Contracts/validator` prüft nur Lieferungen; `contracts.yml` läuft bei `Contracts/**`, `ios-tests.yml` bei jeder Änderung (Goldendatei-Vergleich läuft dort mit).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Models/TranscriptBuilder.swift` | CREATE | Reine Funktion `build(sets:presets:claudeExercises:log:now:) -> Data`, private Encodable-DTOs, Mapper je Art, ISO8601-UTC; dazu `readCurrent(defaults:)` ohne Seiteneffekt (für Schnitt 4, liefert zusätzlich `unreadable`) |
| `Meditationstimer iOS/Models/ClaudeStore.swift` | MODIFY | kleine interne Lesefunktion für `claudeState` (Claude-Übungen + Log) ohne Backup, ~5–10 Zeilen |
| `LeanHealthTimerTests/TranscriptBuilderTests.swift` | CREATE | fester Bestand → Vergleich mit Goldendateien; Grenzfälle; keine doppelten Kennungen; echte Kalenderdaten; Lesefunktion mit isolierter `UserDefaults(suiteName:)` |
| `Contracts/transcript/app-generated/{empty,full,limits}.json` | CREATE | Goldendateien (rohe Abschrift, keine Hülle) |
| `Contracts/validator/test/app-generated.test.ts` | CREATE | Ajv2020 gegen `transcript-v1.schema.json`, Mindestzahl Dateien erzwingen |

### Scope Assessment
- Files: 5 (+ Goldendateien)
- Estimated LoC: App-Code +180–210, Tests ~180 (zählen nicht)
- Risk Level: LOW–MEDIUM (neuer, noch unverdrahteter Baustein; einzige Änderung an Bestehendem ist eine Lesefunktion in ClaudeStore)

### Technical Approach (Entscheidungen, technisch, nicht PO)
- **Übungen (Variante B):** alle 67 `builtin.*` aus `ExerciseDatabase.catalog` (id, deutscher Rohname, Kategorie = englischer Case-Name, origin builtin) + alle Claude-Übungen (mit revision, state, effect, instructions, notes?, nameEn?, packageId?, packageName?, why, deliveredAt). Eigene Übungen **weggelassen** (keine Kategorie, nichts erfinden). Unbekannte Kategorie → Eintrag auslassen.
- **Programme/Atemübungen (Variante P1):** alles ohne Claude-Herkunft = `own.<uuid kleingeschrieben>`, Claude = `itemId`. Keine `builtin`-Tabelle für Vorgaben (Vorgaben sind editierbar und nur per Name erkennbar; `builtin` heißt unveränderlich).
- **Grenzen:** Zahlen klemmen (work 1–600, rest 0–600, Atem 1–60/0–60, Runden 1–99); Namen auf 40, Beschreibung auf 500, Hinweis auf 80 Unicode-Skalare kürzen; Steuerzeichen entfernen; Programm ohne Schritte, leerer Name oder ungültiges Symbol → Baustein auslassen; >40 Schritte abschneiden; Listen auf Höchstzahl kürzen; Kennungen je Liste deduplizieren (erste gewinnt).
- **Deliveries:** letzte ≤50 aus dem Log in gespeicherter Reihenfolge; `applied`/`noEffect` → `accepted` (wie `analyse-51-57-claude-app.md:88-90`), `rejected` → `rejected`; ungültige `deliveryId` auslassen.
- **Determinismus:** `JSONEncoder` `.sortedKeys, .prettyPrinted, .withoutEscapingSlashes`; `generatedAt` injiziert; feste Reihenfolge (Katalog, dann Claude nach deliveredAt/id; Programme/Atem in gespeicherter Reihenfolge).
- **Lesen:** direkt per `JSONDecoder` aus `workoutProgramSets`, `atemPresets`, `claudeState`; fehlend → leer, unlesbar → leer + `unreadable = true` (Senden-oder-nicht entscheidet Schnitt 4).

### Alternativen (verworfen)
- P2: Vorgaben als `builtin.<slug>` per Namenstabelle (+~30 Zeilen, bricht bei Umbenennen/Sprache; bearbeitete Vorgabe wäre „builtin“ mit fremden Werten) — kippt Vorschlag A2-5 der älteren Analyse.
- Variante C: eigene Übungen mit erfundener Kategorie — erfundene Daten.
- Variante D: nur verwendete builtin-Übungen — Goldendatei bestandsabhängig, Claude kennt den Katalog nicht.
- Alternative zum Kürzen: Baustein bei Überlänge auslassen (Claude sähe ihn gar nicht) — Kürzen zeigt mehr.

### Dependencies
- Liest: `ExerciseDatabase.catalog`, `ExerciseCategory`, `WorkoutSet`/`WorkoutPhase` (iOS-only), `AtemView.Preset`, `ClaudeStoredExercise`, `ClaudeOrigin`, `ClaudeApplyLogEntry`, `ClaudeApplyResult`.
- Downstream: Schnitt 4 ruft `readCurrent` + `build` und sendet per `ServiceClient`.

### Open Questions
- keine PO-Fragen; Abweichung „withdrawn wird gelöscht statt markiert“ nur festgehalten.
