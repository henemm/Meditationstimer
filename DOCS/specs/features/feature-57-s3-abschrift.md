---
entity_id: feature-57-s3-abschrift
type: feature
created: 2026-11-24
updated: 2026-11-24
status: draft
workflow: feature-57-s3-abschrift
issue: 57
epic: 44
parent: claude-verbindung-app
---

# Schnitt 3: Abschrift Fassung 1 mit Goldendateien (#57)

## Approval

- [ ] Approved

Freigabe dieser Schnittspec durch den PO.

## Purpose

Schnitt 3 liefert den Baustein, der aus dem, was auf dem iPhone liegt, die Abschrift Fassung 1 für Claude erzeugt: alle mitgelieferten Übungen, die von Claude gelieferten Übungen, die Programme und Atemübungen mit ihrer Herkunft und die Ergebnisse der letzten 50 Lieferungen, als Datei nach `Contracts/transcript/transcript-v1.schema.json`. Dazu kommen eingecheckte Beispieldateien („Goldendateien“), die ein App-Test Byte für Byte nachbaut und die die Contracts-CI gegen das Schema prüft. So ist durch Tests festgelegt, dass die App nur Dateien erzeugt, die der Dienst annimmt, bevor Schnitt 4 sie wirklich verschickt.

Sichtbar für Henning: nichts. Kein Bildschirm ändert sich, nichts wird versendet, keine Datei der App ruft den Baustein auf.

## Source

- Kontext und Analyse: `DOCS/context/feature-57-s3-abschrift.md` (Abschnitt „Analysis“, verbindlich: Befunde, Technical Approach, Alternativen)
- Elternspec: `openspec/specs/features/claude-verbindung-app.md`, Abschnitt „Verhalten“, Punkt 3.2 (Abgleich: Abschrift senden, Fassung 1), Abschnitt „Tests“ und Schnitt 3
- Format: `Contracts/transcript/transcript-v1.schema.json` (einzige Quelle der Feldnamen und Grenzen); Beispiele `Contracts/transcript/valid/`, `invalid/`
- Server-Gegenstück: `server/src/transcripts.ts` (Ajv strict, doppelte Kennungen, echte Kalenderdaten, Körper höchstens 256 KiB)

## Abgrenzung

- **Kein Versand.** `ServiceClient.putTranscript`, Abgleich, Auslöser und `withSession` sind Schnitt 4. Der Baustein erzeugt nur Daten (`Data`).
- **`withdrawn` kommt nicht vor.** Zurückziehen entfernt den Baustein aus dem Speicher (`ClaudeApply.swift`, Zurückziehen), also gibt es nichts zu melden. Das Schema kennt den Wert; die App schreibt ihn in Fassung 1 nie. Abweichung von `DOCS/context/analyse-51-57-claude-app.md` („nie löschen“): hier nur festgehalten, nicht Teil dieses Schnitts.
- **Keine eigenen Übungen.** Sie haben weder Speicher noch Kategorie (sie existieren nur als Schritt eines Programms); das Schema verlangt eine Kategorie, erfunden wird nichts.
- **Keine Vorgabe-Tabelle `builtin` für Programme und Atemübungen.** Vorgaben sind editierbar und nur per Name erkennbar; „builtin“ hieße unveränderlich.
- **Fassung 2 (Verlauf, Tracker, Erinnerungen) ist #59.**

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine neue; die Entscheidungen stehen in der Analyse und sind hier festgeschrieben.

- **Übungen, Variante B:** alle `builtin.*` des Katalogs (`ExerciseDatabase.catalog`) plus alle Claude-Übungen; eigene Übungen entfallen.
- **Programme und Atemübungen, Variante P1:** alles ohne Claude-Herkunft ist `own.<uuid in Kleinbuchstaben>`, alles mit Claude-Herkunft trägt die `itemId` als Kennung.
- **Klemmen und Kürzen statt Auslassen**, wo ein Wert nur zu groß ist; **Auslassen**, wo etwas Pflichtiges fehlt oder ungültig ist (sonst lehnt der Dienst die ganze Abschrift ab).
- **`noEffect` wird `accepted`:** das Schema kennt nur `accepted` und `rejected`; „keine Wirkung“ ist keine Ablehnung.
- **Determinismus:** gleiche Eingabe und gleiche Zeit ergeben gleiche Bytes.
- **`readCurrent` zeigt, was das iPhone zeigt, ohne Seiteneffekt:** Leitlinie der Elternspec „Das iPhone ist die Wahrheit“. Hat der Nutzer seine Programme oder Atemübungen nie verändert (Schlüssel fehlt), zeigt die App die Vorgaben (4 Programme, 6 Atemübungen); die Abschrift enthält sie dann ebenso (als `own.<uuid>`). Ausnahme: Bei unlesbaren Werten zeigt die App Vorgaben, die Abschrift liefert leere Listen und `unreadable = true` (R14), damit Schnitt 4 nicht auf beschädigter Grundlage sendet. Gespeicherte Listen werden wie in der App um fehlende Vorgaben ergänzt (`WorkoutSet.migratingPresets`, `MeditationTab.migratingPresets`, beide reine Funktionen). Die bestehenden Ladefunktionen `ClaudeStore.loadSets/loadPresets` werden trotzdem nicht aufgerufen, weil sie bei Unlesbarem eine Sicherung schreiben.

Alternativen, verworfen:
- **P2, Vorgaben als `builtin.<slug>` per Namenstabelle:** rund 30 Zeilen mehr, bricht bei Umbenennung und Sprache, eine bearbeitete Vorgabe stünde als „builtin“ mit fremden Werten da. Kippt Vorschlag A2-5 der älteren Analyse.
- **Variante C, eigene Übungen mit erfundener Kategorie:** erfundene Daten.
- **Variante D, nur verwendete `builtin`-Übungen:** Goldendatei hängt vom Bestand ab; Claude kennt den Katalog nicht.
- **Überlange Bausteine auslassen statt kürzen:** Claude sähe sie gar nicht; Kürzen zeigt mehr.
- **Vorhandene Ladefunktionen wiederverwenden:** schreiben bei Unlesbarem eine Sicherung, also eine Nebenwirkung einer Leseoperation (siehe oben).
- **Fehlender Schlüssel = leere Liste (Stand der Analyse):** verworfen bei der Spec-Prüfung, weil Claude dann bei einem Nutzer, der nie etwas geändert hat, keine Programme sähe, obwohl das iPhone vier zeigt.

## Scope

App-Code (Grenze 250 Zeilen gilt nur für App-Code; Tests, Goldendateien und TypeScript-Test zählen nicht):

| Datei | Änderung | Inhalt | ca. Zeilen |
|---|---|---|---|
| `Meditationstimer iOS/Models/TranscriptBuilder.swift` | neu | `TranscriptBuilder` (`build(sets:presets:claudeExercises:log:now:) -> Data`, `readCurrent(defaults:) -> TranscriptInput`), private Encodable-Typen, Abbildung je Art, Bereinigung, ISO8601-UTC | 170 bis 200 |
| `Meditationstimer iOS/Models/ClaudeStore.swift` | ändern | interne Lesefunktion für `claudeState` ohne Sicherung (`readState(from:) -> (state: ClaudeStoredState, unreadable: Bool)`) | 5 bis 10 |

Summe App-Code 175 bis 210 Zeilen, Funktionen je höchstens 50 Zeilen.

Nicht zum Budget:

| Datei | Änderung |
|---|---|
| `LeanHealthTimerTests/TranscriptBuilderTests.swift` | neu, XCTest, `@testable import Lean_Health_Timer`, deutsche `testXyz`-Namen |
| `Contracts/transcript/app-generated/empty.json`, `full.json`, `limits.json` | neu, rohe Abschrift (keine Hülle `{description, transcript, expected}`) |
| `Contracts/validator/test/app-generated.test.ts` | neu |

Dazu eine Zeile in der Elternspec `openspec/specs/features/claude-verbindung-app.md` (Stand Schnitt 3, kein Code). Betroffen sind damit 5 Dateien (2 App-Code, 1 Unit-Test, 1 Validator-Test, 1 Elternspec) plus 3 Goldendateien; das liegt an der Grenze von 4 bis 5 Dateien, ist aber vertretbar, weil die Goldendateien erzeugte Prüfdaten ohne Logik sind und nur 2 Dateien App-Code enthalten. `Meditationstimer iOS/` und `LeanHealthTimerTests/` sind synchronisierte Gruppen; kein Eingriff in `project.pbxproj`. Watch und Widget nutzen keinen betroffenen Typ. `.github/workflows/contracts.yml` bleibt unverändert: sie läuft bei jeder Änderung unter `Contracts/**` und führt `npm test` aus, das alle `test/*.test.ts` einschließt, also auch den neuen Test. Die Unit-Tests laufen mit dem Goldendatei-Vergleich in `ios-tests.yml`.

## Nicht in Scope

- Versand, `ServiceClient`-Routen, Abgleich, Auslöser, Entitlement (Schnitt 4); jede Oberfläche (Schnitt 5).
- Verdrahtung in der App; außerhalb der Tests ruft nichts den Baustein auf.
- Änderungen am Schema, am Server, an `ClaudeApply.swift`, an Katalog oder Datenmodellen (`WorkoutSet`, `AtemView.Preset`).
- Behandlung einer Abschrift über 256 KiB (Server-Grenze): praktisch erreichbar nur mit mehreren hundert langen Claude-Übungen; ob gesendet wird, entscheidet Schnitt 4 mit dem Ergebnis von `readCurrent`/`build`.

## Dependencies

| Abhängigkeit | Art | Hinweis |
|---|---|---|
| `ExerciseDatabase.catalog`, `ExerciseInfo`, `ExerciseCategory` (deutsche Rohwerte), `mapCategory(_:)` | Upstream | Katalog: 67 `builtin.*`; `mapCategory` bildet den englischen Case-Namen auf die Kategorie ab |
| `WorkoutSet`, `WorkoutPhase` (`id: UUID`, `name`, `emoji`, `phases`, `repetitions`, `description`, `claude`, `modifiedAt`; `workDuration`, `restDuration`, `exerciseId`, `hint`) | Upstream | iOS-only |
| `AtemView.Preset` (`id: UUID`, `name`, `emoji`, `inhale`, `holdIn`, `exhale`, `holdOut`, `repetitions`, `description`, `claude`, `modifiedAt`) | Upstream | |
| `ClaudeStoredExercise`, `ClaudeOrigin`, `ClaudeApplyLogEntry`, `ClaudeApplyResult`, `ClaudeStoredState` | Upstream (#51) | |
| `ClaudeStore.setsKey`, `presetsKey`, `stateKey` | Upstream | `workoutProgramSets`, `atemPresets`, `claudeState` |
| Foundation | Framework | `JSONEncoder` |
| Schnitt 4 (ruft `readCurrent` und `build`), #59 (Fassung 2 erweitert) | Downstream | |

## Expected Behavior

- Input: `build(sets: [WorkoutSet], presets: [AtemView.Preset], claudeExercises: [ClaudeStoredExercise], log: [ClaudeApplyLogEntry], now: Date) -> Data`. Dazu `readCurrent(defaults: UserDefaults) -> TranscriptInput`, wobei `TranscriptInput` die vier Listen und `unreadable: Bool` trägt.
- Output: UTF-8-JSON nach Fassung 1, endet mit genau einem Zeilenumbruch. Ausgabeoptionen `sortedKeys`, `prettyPrinted`, `withoutEscapingSlashes`.
- Side effects: keine. Kein Schreiben in `UserDefaults`, keine Sicherung, keine Benachrichtigung, keine Uhr (Zeit nur über `now`).

### Regeln

**R1. Hülle.** Schlüssel genau `version` (Zahl 1), `generatedAt`, `exercises`, `programs`, `breaths`, `deliveries`; alle Listen immer vorhanden (leer als `[]`). Optionale Felder ohne Wert werden nicht ausgegeben (kein `null`).

**R2. Datumsformat.** `generatedAt` und `deliveredAt`: ISO 8601, UTC, ganze Sekunden (abgerundet), Endung `Z`, zum Beispiel `2026-11-24T08:30:00Z`. Gregorianischer Kalender, `en_US_POSIX`, unabhängig von Zeitzone und Systemsprache. Jedes ausgegebene Datum ist ein echtes Kalenderdatum (kein 30. Februar, 29. Februar nur im Schaltjahr); das ergibt sich aus `Date`, wird aber im Test geprüft, weil nur der Server es prüft, nicht das Schema.

**R3. Übungen.** In dieser Reihenfolge:
1. Alle Einträge des Katalogs in Katalogreihenfolge: `id` (`builtin.*`), `name` (deutscher Rohname), `category` (R7), `origin = "builtin"`. Keine weiteren Felder (das Schema verbietet sie für `builtin`).
2. Alle Claude-Übungen (`ClaudeStoredExercise`), sortiert nach `claude.deliveredAt` aufsteigend, bei Gleichheit nach `claude.itemId`: `id = claude.itemId`, `name`, `nameEn` (falls vorhanden), `category` (R7), `origin = "claude"`, `effect`, `instructions`, `notes` (falls vorhanden), `revision`, `state = "active"` (Claude-Übungen haben kein `modifiedAt`), `packageId`/`packageName` (falls vorhanden; eine `packageId`, die nicht auf `^claude\.[a-z0-9][a-z0-9-]{1,62}$` passt, entfällt als Feld, die Übung bleibt, wie in R6), `why` (falls vorhanden, R9), `deliveredAt`. Ist die `itemId` ungültig, entfällt die Übung (R10).

Eigene Übungen entfallen.

**R4. Programme.** In gespeicherter Reihenfolge, je `WorkoutSet`: `name`, `symbol = emoji`, `description` (falls vorhanden), `rounds = repetitions`, `steps` aus den Phasen in Reihenfolge (`exerciseId`, `workSeconds = workDuration`, `restSeconds = restDuration`, `hint` falls vorhanden). Phasen ohne `exerciseId` oder mit einer `exerciseId`, die nach Kleinschreibung nicht zum Muster `^(builtin|own|claude)\.[a-z0-9][a-z0-9-]{1,62}$` passt, entfallen als Schritt (nichts wird erfunden). `exerciseId` wird in Kleinbuchstaben ausgegeben. Es wird nicht geprüft, ob die Übung in `exercises` steht (Schema und Server prüfen es nicht).

**R5. Atemübungen.** In gespeicherter Reihenfolge, je `Preset`: `name`, `symbol = emoji`, `description` (falls vorhanden), `inhaleSeconds = inhale`, `holdInSeconds = holdIn`, `exhaleSeconds = exhale`, `holdOutSeconds = holdOut`, `rounds = repetitions`.

**R6. Herkunft und Zustand (Programme und Atemübungen).** Ohne `claude`: `origin = "own"`, `id = "own." + uuidString.lowercased()`, keine Claude-Felder. Mit `claude`: `origin = "claude"`, `id = claude.itemId`, `revision`, `state` (`"adapted"`, wenn `modifiedAt != nil`, sonst `"active"`), `packageId`/`packageName` (falls vorhanden), `why` (falls vorhanden; das Schema verlangt `why` bei keiner Art, ein leeres `why` lässt nur das Feld entfallen, nie den Baustein, R9), `deliveredAt`. Ist die `itemId` oder die `packageId` kein gültiger `claude.*`-Wert (Muster `^claude\.[a-z0-9][a-z0-9-]{1,62}$`), wird bei der `itemId` der Baustein ausgelassen, bei der `packageId` nur dieses Feld.

**R7. Kategorie.** Katalogübungen: deutscher Rohwert auf englischen Schema-Wert: Kraft → `strength`, Dehnung → `stretching`, Core → `core`, Cardio → `cardio`, Beine → `legs`, Oberkörper → `upperBody`, Ganzkörper → `fullBody`, Aufwärmen → `warmup`, Cool-Down → `cooldown` (identisch mit dem Case-Namen von `ExerciseCategory`). Claude-Übungen: der gespeicherte englische Text über `mapCategory`. Ist die Kategorie unbekannt, wird die Übung ausgelassen.

**R8. Klemmen (Zahlen).** `workSeconds` auf 1 bis 600, `restSeconds` auf 0 bis 600, `inhaleSeconds` und `exhaleSeconds` auf 1 bis 60, `holdInSeconds` und `holdOutSeconds` auf 0 bis 60, `rounds` (Programm und Atem) auf 1 bis 99, `revision` auf 1 bis 1000000.

**R9. Kürzen und Bereinigen (Texte).** Erst bereinigen, dann auf die Höchstlänge in Unicode-Skalaren kürzen: Zeichen entfernen, die das Schema verbietet (Steuerzeichen U+0000 bis U+001F und U+007F bis U+009F, die dort aufgeführten Zeilen-/Absatztrenner und Richtungssteuerzeichen); bei den Feldern, die Zeilenumbrüche erlauben (`description`, `effect`, `instructions`, `notes`), bleibt U+000A erhalten. Höchstlängen: `name`, `nameEn`, `packageName` 40; `hint` 80; `description` (Programm, Atem) 500; `effect` 600; `instructions` 1500; `notes` 600; `why` 300. `symbol` wird von R9 nicht bereinigt und nicht gekürzt (ein gekürztes oder bereinigtes Emoji wäre ein anderes Zeichen); für das Symbol gilt allein R10. Besteht ein Text danach nur aus Leerzeichen, geschützten Leerzeichen (U+00A0) und Zeilenumbrüchen (das Schema verlangt ein anderes Zeichen), gilt er als leer: Pflichtfelder (`name`, bei Claude-Übungen `effect`, `instructions`) lassen dann den Baustein aus, optionale Felder (`nameEn`, `notes`, `description`, `hint`, `packageName`, `why`) entfallen.

**R10. Auslassen (Bausteine).** Ein Baustein entfällt ganz, wenn: sein `name` leer ist (R9); sein `symbol` (unverändert, ohne Bereinigung) leer ist, mehr als 16 Unicode-Skalare hat oder ein Zeichen enthält, das das Schema im Symbol verbietet (Steuerzeichen, Leerzeichen, geschütztes Leerzeichen, Richtungszeichen, ASCII-Buchstaben und -Ziffern); ein Programm keinen gültigen Schritt behält; die Kennung ungültig ist (R6); die Kategorie unbekannt ist (R7); bei einer Claude-Übung `effect` oder `instructions` nach R9 leer ist. Mehr als 40 Schritte: die ersten 40 bleiben.

**R11. Deduplizieren.** Kennungen sind je Liste (`exercises`, `programs`, `breaths`) eindeutig; bei doppelter Kennung gewinnt der erste Eintrag in der Ausgabereihenfolge (bei Übungen: Katalog vor Claude). Der Server lehnt Doppelte ab, das Schema nicht.

**R12. Höchstzahlen.** Nach Auslassen und Deduplizieren werden die Listen gekürzt auf: Übungen 500 (die ersten 500 in Ausgabereihenfolge; die Katalogübungen bleiben vollständig, es fallen die zuletzt gelieferten Claude-Übungen weg), Programme 200 und Atemübungen 200 (jeweils die ersten in gespeicherter Reihenfolge), Lieferergebnisse 50 (die **letzten** 50, R13).

**R13. Lieferergebnisse.** Aus dem Log (`log`, neueste zuletzt) werden Einträge mit gültiger `deliveryId` (`^[A-Za-z0-9][A-Za-z0-9-]{7,63}$`) übernommen, nach `deliveryId` dedupliziert (erster gewinnt), dann die letzten 50 in gespeicherter Reihenfolge (neueste zuletzt). `outcome` (Ausgabeschlüssel; Quelle ist das Feld `result: ClaudeApplyResult` von `ClaudeApplyLogEntry`): `applied` und `noEffect` ergeben `accepted`, `rejected` ergibt `rejected`. Weitere Felder (Code, Grund, Zeit) werden nicht ausgegeben.

**R14. Lesen (`readCurrent`).** Quellen: `workoutProgramSets` und `atemPresets` liest `readCurrent` selbst mit `JSONDecoder`; `claudeState` liest die neue Funktion `ClaudeStore.readState(from defaults: UserDefaults) -> (state: ClaudeStoredState, unreadable: Bool)` (fehlender Schlüssel: `(ClaudeStoredState(), false)`, unlesbar: `(ClaudeStoredState(), true)`), die ebenfalls nur mit `JSONDecoder` dekodiert und keine Sicherung anlegt, und liefert daraus die Claude-Übungen und das Log. Fehlender Schlüssel: bei `workoutProgramSets` die Vorgaben `defaultWorkoutSets`, bei `atemPresets` die Vorgaben `MeditationTab.defaultPresets`, bei `claudeState` leere Listen; `unreadable` bleibt `false`. Gelesener Wert: Programme über `WorkoutSet.migratingPresets(stored, presets: defaultWorkoutSets)`, Atemübungen über `MeditationTab.migratingPresets(stored)` (dieselbe Liste wie in der App). Vorhandener, nicht dekodierbarer Wert: zugehörige Listen leer (keine Vorgaben) und `unreadable = true`. Zuordnung: `workoutProgramSets` → `sets`; `atemPresets` → `presets`; `claudeState` → **beide** Listen `claudeExercises` und `log`. Es wird nichts geschrieben und keine Sicherung angelegt. Bekannte Folge: Nie gespeicherte Vorgaben erhalten bei jedem App-Start eine neue UUID (`init(id: UUID = UUID())`), ihre `own.`-Kennung ist also nur innerhalb eines Laufs stabil; ob vor dem Senden gespeichert wird, entscheidet Schnitt 4.

## Acceptance Criteria

„Unit“ = `LeanHealthTimerTests/TranscriptBuilderTests.swift`. Hilfsmittel: ein fester Bestand aus Fixtures (Programme, Atemübungen, Claude-Übungen, Log) und ein fester Zeitpunkt `now = 2026-11-24T08:30:00Z`; Goldendateien werden über `#filePath` aus `Contracts/transcript/app-generated/` gelesen (Muster `ClaudeDeliveryDecodingTests`). Jeder Test, der Bytes vergleicht, liest die Datei als `Data` und vergleicht mit `build(...)` ohne Umformatierung.

- **AC-1 (Unit): Leere Abschrift gleich Goldendatei.** Given leere Listen und `now`, When `build`, Then sind die Bytes gleich `app-generated/empty.json`; die Datei enthält version 1, `generatedAt` `2026-11-24T08:30:00Z`, 67 Katalogübungen (alle `origin: builtin`), und `programs`, `breaths`, `deliveries` als leere Listen. Test: `testLeereAbschriftGleichGoldendatei`.
- **AC-2 (Unit): Vollständige Abschrift gleich Goldendatei.** Given der feste Bestand (mindestens: ein eigenes Programm, ein bearbeitetes und ein unbearbeitetes Claude-Programm, eine eigene Atemübung, eine bearbeitete und eine unbearbeitete Claude-Atemübung, zwei Claude-Übungen mit und ohne `nameEn`/`notes`/`packageId`, ein Log mit `applied`, `noEffect` und `rejected`), When `build`, Then Bytes gleich `app-generated/full.json`. Test: `testVollstaendigeAbschriftGleichGoldendatei`.
- **AC-3 (Unit): Grenzfälle gleich Goldendatei.** Given ein Bestand an den Schemagrenzen (Name genau 40 und 41 Unicode-Skalare, Beschreibung 500 und 501, Hinweis 80 und 81, Symbol 16 und 17 Skalare, ein Programm mit 40 und eines mit 41 Schritten, Zahlen an und außerhalb der Grenzen, Log mit 51 Einträgen, Texte mit Steuerzeichen und Umbrüchen, Emojis mit mehreren Skalaren), When `build`, Then Bytes gleich `app-generated/limits.json`, und die Datei bleibt unter 256 KiB. Test: `testGrenzfaelleGleichGoldendatei`.
- **AC-4 (Unit): Determinismus.** Given derselbe Bestand und dasselbe `now`, When `build` zweimal aufgerufen wird, Then sind beide Ausgaben byte-gleich, die Schlüssel stehen in jedem Objekt alphabetisch sortiert, und die Ausgabe endet mit genau einem Zeilenumbruch. Test: `testAbschriftIstDeterministisch`.
- **AC-5 (Unit): Hülle.** Given beliebiger Bestand, When die Ausgabe als JSON gelesen wird, Then hat die oberste Ebene genau die Schlüssel `version`, `generatedAt`, `exercises`, `programs`, `breaths`, `deliveries`; `version` ist die Zahl 1; kein Wert ist `null`; `generatedAt` passt auf das Schema-Muster. Test: `testHuelleHatGenauDieSchemafelder`.
- **AC-6 (Unit): Kennungen und Herkunft.** Given ein eigenes Programm mit UUID in Großbuchstaben, ein Claude-Programm mit `itemId` „claude.kern-runde“, Then ist die Kennung des ersten `own.` plus die UUID in Kleinbuchstaben, die des zweiten `claude.kern-runde`; `own`-Bausteine tragen keines der Felder `revision`, `state`, `packageId`, `packageName`, `why`, `deliveredAt`; Katalogübungen tragen keines der Felder `revision`, `state`, `packageId`, `packageName`, `why`, `deliveredAt`, `effect`, `instructions`, `notes`; jede `id` passt auf das Muster ihrer Herkunft (`builtin.`, `own.`, `claude.`). Test: `testKennungenUndHerkunftsfelder`.
- **AC-7 (Unit): Zustand active und adapted.** Given Claude-Programme und Claude-Atemübungen je mit und ohne `modifiedAt`, Then ist `state` `adapted` genau bei gesetztem `modifiedAt`, sonst `active`; Claude-Übungen sind immer `active`; der Wert `withdrawn` kommt in keiner Ausgabe vor; `revision`, `packageId`, `packageName`, `why`, `deliveredAt` stimmen mit der gespeicherten Herkunft überein. Test: `testZustandActiveUndAdapted`.
- **AC-8 (Unit): Kategorie-Abbildung.** Given alle neun deutschen Rohwerte (je eine Katalogübung) und alle neun englischen Texte (je eine Claude-Übung), Then ist `category` jeweils der erwartete Schema-Wert aus R7 (Tabelle im Test, unabhängig vom Quelltext geschrieben). Given eine Claude-Übung mit Kategorie „Unsinn“, Then fehlt sie in der Ausgabe und die übrigen bleiben. Tests: `testKategorienAbbildung`, `testUnbekannteKategorieLaesstUebungAus`.
- **AC-9 (Unit): Zahlen klemmen.** Given Werte 0 und 601 für `workDuration`, -5 und 601 für `restDuration`, 0 und 61 für `inhale`/`exhale`, -1 und 61 für `holdIn`/`holdOut`, 0 und 100 für `repetitions` (Programm und Atem) und `revision` 0 und 1000001, Then stehen in der Ausgabe 1/600, 0/600, 1/60, 0/60, 1/99 und 1/1000000; Werte innerhalb der Grenzen bleiben unverändert. Test: `testZahlenWerdenGeklemmt`.
- **AC-10 (Unit): Texte kürzen und bereinigen.** Given für jedes Textfeld ein Wert mit Höchstlänge plus 1 Skalar (`name` 40, `nameEn` 40, `hint` 80, `description` 500, `effect` 600, `instructions` 1500, `notes` 600, `why` 300, `packageName` 40), Then hat die Ausgabe genau die Höchstlänge in Unicode-Skalaren. Given Texte mit U+0007, U+0085, U+202E und einem Zeilenumbruch, Then sind die verbotenen Zeichen entfernt; der Zeilenumbruch bleibt nur bei `description`, `effect`, `instructions`, `notes` und wird sonst ebenfalls entfernt. Tests: `testTexteWerdenGekuerzt`, `testVerboteneZeichenWerdenEntfernt`.
- **AC-11 (Unit): Auslassen statt Ungültiges.** Given (a) ein Programm ohne Schritte, (b) ein Programm, dessen Phasen alle keine oder eine ungültige `exerciseId` haben, (c) ein Programm mit Name „   “, (d) eine Atemübung mit Symbol „AB“ (nur ASCII), (e) ein Programm mit Symbol „“, (e2) eine Atemübung mit Symbol „🌬\u{202E}“ (Emoji plus Richtungszeichen), (e3) ein Programm mit Symbol aus 17 Skalaren, (f) eine Claude-Übung mit leerem `effect`, (g) ein Claude-Baustein mit `itemId` „claude.“, Then fehlen alle neun in der Ausgabe und gültige Nachbarn bleiben. Given eine Claude-Übung und ein Claude-Programm je mit `packageId` „paket-ohne-praefix“, Then bleiben beide in der Ausgabe, jeweils ohne das Feld `packageId`; ein Programm, bei dem nur einzelne Phasen ungültig sind, bleibt mit den gültigen Schritten in Reihenfolge. Given ein Programm mit 45 gültigen Schritten, Then hat es 40, die ersten 40 in Reihenfolge. Given eine Phase mit `exerciseId` „OWN.Planke-ABC“ (Großschreibung), Then steht sie als `own.planke-abc` in der Ausgabe. Tests: `testUngueltigeBausteineWerdenAusgelassen`, `testUngueltigePackageIdEntfaelltNurAlsFeld`, `testSchritteWerdenAuf40GekuerztUndKleingeschrieben`.
- **AC-12 (Unit): Leere optionale Felder entfallen.** Given `nameEn`, `notes`, `description`, `hint`, `packageName`, `why` jeweils nur aus Leerzeichen oder nicht gesetzt, Then fehlt das Feld in der Ausgabe (nicht `""`, nicht `null`), der Baustein bleibt. Test: `testLeereOptionaleFelderEntfallen`.
- **AC-13 (Unit): Keine doppelten Kennungen.** Given zwei Claude-Programme mit derselben `itemId`, zwei Claude-Übungen mit derselben `itemId`, eine Claude-Übung mit der Kennung einer Katalogübung (prüft nicht die Dedup-Regel, sondern R6/R10: Präfix `builtin.` ist als Claude-Kennung ungültig, die Übung entfällt, die Katalogübung bleibt einmal) und zwei Atemübungen mit derselben UUID, Then enthält jede Liste jede `id` höchstens einmal, und bei Doppelten steht der erste Eintrag in der Ausgabereihenfolge. Test: `testKeineDoppeltenKennungen`.
- **AC-14 (Unit): Reihenfolge.** Given Programme [B, A, C] und Atemübungen [Y, X] in dieser gespeicherten Reihenfolge, Then bleibt sie; Übungen: erst alle 67 Katalogübungen in Katalogreihenfolge, dann Claude-Übungen nach `deliveredAt` aufsteigend, bei gleichem Zeitpunkt nach `itemId`. Test: `testReihenfolgeIstFest`.
- **AC-15 (Unit): Höchstzahlen.** Given 250 Programme, 250 Atemübungen, 600 Claude-Übungen und 60 Log-Einträge (alle gültig, verschiedene Kennungen), Then hat die Ausgabe 200 Programme (die ersten 200), 200 Atemübungen, 500 Übungen (67 Katalog plus die ersten 433 Claude-Übungen in Ausgabereihenfolge) und 50 Lieferergebnisse (die letzten 50). Test: `testHoechstzahlenWerdenEingehalten`.
- **AC-16 (Unit): Lieferergebnisse.** Given ein Log mit `applied`, `noEffect`, `rejected(code:reason:)` und einer ungültigen `deliveryId` („abc“), Then stehen `accepted`, `accepted`, `rejected` in gespeicherter Reihenfolge, die ungültige fehlt, jedes Objekt hat genau die Schlüssel `deliveryId` und `outcome`, und `code`/`reason`/Zeit kommen nirgends in der Ausgabe vor. Given ein Log mit 51 gültigen Einträgen, Then sind es die letzten 50. Given ein Log mit zwei Einträgen gleicher `deliveryId` (erst `rejected`, später `applied`), Then steht diese `deliveryId` genau einmal in der Ausgabe, mit `outcome` des ersten Eintrags (`rejected`). Test: `testLieferergebnisseAbbildung`.
- **AC-17 (Unit): Datumsformat und echte Kalenderdaten.** Given `now` und `deliveredAt` bei `2028-02-29T23:59:59Z`, `2026-12-31T23:59:59Z`, `2026-01-01T00:00:00Z` und ein `deliveredAt` mit Sekundenbruchteil (`…:59.9Z`), Then haben alle Datumsfelder die Form `yyyy-MM-ddTHH:mm:ssZ` (Sekunden abgerundet, keine Zone außer `Z`), und jedes ausgegebene Datum lässt sich mit einem strengen Kalender (UTC, gregorianisch) in genau dieses Datum zurückrechnen. Der Test setzt dazu `NSTimeZone.default = TimeZone(identifier: "Asia/Tokyo")!` vor dem Bauen und stellt die alte Zone in `defer` wieder her; die Ausgabe ist byte-gleich zu der mit `TimeZone(identifier: "UTC")!`. Test: `testDatumsformatUtcUndEchteKalenderdaten`.
- **AC-18 (Unit): `readCurrent` bei fehlenden Schlüsseln.** Given eine frische `UserDefaults(suiteName: <UUID>)` ohne die drei Schlüssel, When `readCurrent(defaults:)`, Then enthalten `sets` genau die Namen von `defaultWorkoutSets` und `presets` genau die Namen von `MeditationTab.defaultPresets` in deren Reihenfolge, `claudeExercises` und `log` sind leer, `unreadable == false`. Test: `testReadCurrentFehlendZeigtVorgaben`.
- **AC-19 (Unit): `readCurrent` bei lesbaren Werten.** Given die drei Schlüssel mit gültig kodierten Werten (Programme und Atemübungen als `JSONEncoder`-Ausgabe, `claudeState` als `ClaudeStoredState` mit Übung und Log), Then liefert `readCurrent` genau diese Werte in Reihenfolge, Programme und Atemübungen ergänzt um die fehlenden Vorgaben wie `migratingPresets` (Gegenprobe: ein gespeichertes Programm „Tabata Classic“ erscheint nur einmal), `unreadable == false`. Test: `testReadCurrentLiestGespeicherteWerte`.
- **AC-20 (Unit): `readCurrent` bei unlesbaren Werten.** Given `workoutProgramSets` mit Müllbytes, die anderen gültig, Then ist die Programmliste leer, die übrigen Listen sind gelesen, `unreadable == true`. Given dasselbe für `atemPresets` (einzeln), Then die Atemliste leer, die übrigen gelesen, `unreadable == true`. Given dasselbe für `claudeState` (einzeln), Then sind `claudeExercises` **und** `log` leer, Programme und Atemübungen gelesen, `unreadable == true`. Test: `testReadCurrentUnlesbarIstLeerUndMarkiert`.
- **AC-21 (Unit): Keine Seiteneffekte.** Given eine isolierte Suite vor und nach `readCurrent` und `build` (in den Fällen fehlend, lesbar, unlesbar), Then ist `dictionaryRepresentation()` vor und nach dem Aufruf identisch; insbesondere entstehen keine Schlüssel mit den Präfixen `atemPresetsBackup.`, `claudeStateBackup.` oder `workoutProgramSetsBackup.`, und `workoutProgramSets`/`atemPresets` werden nicht angelegt. Test: `testLesenUndBauenSchreibenNichts`.
- **AC-22 (Validator): Alle Goldendateien sind schemagültig.** Given `Contracts/transcript/app-generated/*.json`, When `npm test` in `Contracts/validator` läuft (neuer Test `app-generated.test.ts`, Ajv2020 mit den Optionen des Servers `{ allErrors: false, strict: true, strictRequired: false }`, Schema `transcript-v1.schema.json`), Then ist jede Datei gültig; der Test zählt die Dateien und verlangt mindestens 3 und dass `empty.json`, `full.json` und `limits.json` darunter sind (Schutz gegen einen Nulllauf, falls der Ordner leer oder falsch adressiert ist); je Datei ein eigener Testfall mit dem Dateinamen im Titel. Test: `app-generated.test.ts` („Goldendateien sind schemagültig“, „Mindestzahl Goldendateien“).
- **AC-23 (Validator): Der Prüfer erkennt Ungültiges.** Given eine Kopie von `full.json` im Speicher mit je einer Änderung (zusätzliches Feld `calories` an oberster Ebene; `workSeconds` 601; Claude-Programm ohne `state`; `generatedAt` mit `+01:00`), Then lehnt derselbe Prüfer jede Kopie ab. Beweist, dass AC-22 nicht nur „immer grün“ ist. Test: `app-generated.test.ts` („Prüfer lehnt veränderte Goldendatei ab“).
- **AC-24 (Validator): Eindeutige Kennungen und echte Kalenderdaten in den Goldendateien.** Given jede Goldendatei, Then sind die Kennungen je Liste (`exercises`, `programs`, `breaths`) eindeutig, und jedes `generatedAt`/`deliveredAt` ist ein echtes Kalenderdatum (Gegenprobe zu den beiden Regeln, die nur der Server prüft). Test: `app-generated.test.ts` („Kennungen eindeutig, Daten echt“).
- **AC-25 (Unit): Goldendatei deckt die Felder des Beispiels ab.** Given `Contracts/transcript/valid/full.json` (Hülle, Feld `transcript`) und `app-generated/full.json`, Then kommt jeder Feldname, der in einem Baustein von `valid/full.json` vorkommt, mindestens einmal in `app-generated/full.json` vor (Abdeckung unter anderem von `nameEn`, `notes`, `packageId`, `packageName`, `hint`, `description`, `state` mit `adapted`, `deliveredAt`), ausgenommen Felder, die die App nie schreibt (`state` mit `withdrawn`). Test: `testGoldendateiDecktFelderVonValidFullAb`.
- **AC-26 (jede Runde): Nichts verdrahtet, Umfang, Build.** Given der Diff des Schnitts, Then enthält er genau: `TranscriptBuilder.swift` (neu), die Lesefunktion in `ClaudeStore.swift`, `TranscriptBuilderTests.swift`, die drei Goldendateien, `app-generated.test.ts`, die Zeile in der Elternspec sowie die Workflow-Dokumente dieses Schnitts (diese Spec, `DOCS/context/feature-57-s3-abschrift.md`, `DOCS/briefings/feature-57-s3-abschrift.md`, Validierungsbericht); keine weitere bestehende App-Datei ist geändert (insbesondere nicht `ClaudeApply.swift`, `WorkoutProgramsView.swift`, `AtemView.swift`, `ExerciseInfo.swift`, Schema, Server, Workflows); außerhalb der Tests ruft nichts `TranscriptBuilder` auf (Quelltextsuche); iOS, Watch und Widget bauen; Produktiv-Diff höchstens 250 Zeilen (Zielwert 175 bis 210), keine Funktion über 50 Zeilen; die bestehende Unit-Suite und `npm test` im Validator bleiben grün; im Protokoll steht `Executed N tests` mit N ≥ 1 (Unit) beziehungsweise eine Zahl bestandener Tests ≥ 1 je neuer Validator-Testdatei. Nachweis, je als Befehl mit Ausgabe im Validierungsbericht: (1) Dateiliste `git diff --name-only origin/main...HEAD` gleich der genannten Liste; (2) Quelltextsuche `grep -rln TranscriptBuilder "Meditationstimer iOS" "Meditationstimer Watch"` liefert nur `TranscriptBuilder.swift`; (3) Zeilenzählung `git diff --numstat origin/main...HEAD -- "Meditationstimer iOS"` ≤ 250; (4) Build iOS, Watch, Widget; (5) Unit-Suite; (6) `npm test` in `Contracts/validator`.

## Tests

Neue Datei `LeanHealthTimerTests/TranscriptBuilderTests.swift` (Klasse `TranscriptBuilderTests`, AC-1 bis AC-21 und AC-25); neue Datei `Contracts/validator/test/app-generated.test.ts` (AC-22 bis AC-24). Testnamen stehen bei den Kriterien. Die Fixtures stehen in der Testdatei; die Goldendateien entstehen einmalig aus dem fertigen Builder (erste Fassung vom Developer erzeugt und von Hand im Diff geprüft, nicht vom Test selbst geschrieben): Ein Test, der seine Erwartung selbst erzeugt, prüft nichts.

Die Goldendateien ändern sich bewusst bei jeder Änderung des Katalogs oder des Formats; ein Unterschied wird im Diff sichtbar und von Hand bestätigt.

**Kein UI-Test in diesem Schnitt, und das ist Absicht:** Es wird nichts sichtbar. Kein Bildschirm, keine Kennung, kein Ablauf ändert sich, und kein Code der App ruft den Baustein auf; die Wirkung ist ausschließlich eine Datei aus Bytes, die vollständig durch Unit-Tests und den Schema-Test geprüft wird. Der erste UI-Test der Verbindung entsteht in Schnitt 5 mit der Einstellungsseite.

Durchlauf-Nachweis („App benutzen“): Da nichts verdrahtet ist, besteht er aus dem Start der App im Simulator `iPhone 17 Pro` (iOS 27.2) ohne Veränderung (Regression): bauen, installieren, starten, Meditation-, Workout- und Tracker-Tab öffnen, Einstellungen öffnen. Erwartet: derselbe Stand wie vor dem Schnitt, kein Absturz, kein Systemdialog, Programme und Atemübungen unverändert (insbesondere kein neuer oder verschwundener Eintrag). Screenshot der Einstellungen als Beleg. Kein Gerät von Henning.

## Test Plan

- [ ] Unit (`TranscriptBuilderTests.swift`): AC-1 bis AC-21 und AC-25. GIVEN fester Bestand und festes `now` WHEN `build` bzw. `readCurrent` THEN Bytes gleich Goldendatei beziehungsweise Werte wie beschrieben
- [ ] Validator (`app-generated.test.ts`): AC-22 bis AC-24. GIVEN die Goldendateien WHEN `npm test` in `Contracts/validator` THEN alle schemagültig, Mindestzahl erfüllt, veränderte Kopien abgelehnt
- [ ] RED-Beleg: Unit-Tests scheitern zuerst am Übersetzungsfehler „cannot find `TranscriptBuilder`“; der Validator-Test scheitert, weil der Ordner `app-generated` fehlt (Mindestzahl-Prüfung schlägt an); danach legt der Developer die Implementierung an und erzeugt die Goldendateien
- [ ] Bestand: vollständige Unit-Suite grün (Aufruf wie in `CLAUDE.md`, Nachweis nur mit `Executed N tests`, N ≥ 1); `npm test` im Validator grün
- [ ] Build grün für iOS, Watch und Widget
- [ ] Diff-Prüfung und Quelltextsuche AC-26
- [ ] Zeilenzählung des Produktiv-Diffs (ohne Tests und Goldendateien): höchstens 250, Zielwert 175 bis 210
- [ ] Durchlauf im Simulator: App starten, Tabs und Einstellungen öffnen, unverändert; Screenshot
- [ ] Kein UI-Test (begründet oben)

## Risiken

- **Zeilenbudget.** Zielwert 175 bis 210, Grenze 250. Wird es eng, ist der Schnitt in 3a (Übungen, Hülle, Lieferergebnisse) und 3b (Programme, Atemübungen, `readCurrent`) teilbar. Bei Überschreitung: STOP, Grenze nicht anheben, Rückfrage mit Schätzung.
- **Goldendateien hängen am Katalog.** 67 Katalogübungen stehen in jeder Datei; jede Katalogänderung erzwingt eine bewusste Aktualisierung (gewollt, siehe Tests).
- **Zeichenzählung.** Das Schema zählt `maxLength` in Unicode-Skalaren (JSON-Schema), Swift in Zeichen (`Character`). Gekürzt wird deshalb über `unicodeScalars`; ein Schnitt mitten in ein zusammengesetztes Emoji kann entstehen, ist aber schemagültig. AC-3 enthält einen solchen Fall.
- **Ajv-Strenge.** Der Server prüft mit `Ajv2020({ allErrors: false, strict: true, strictRequired: false })`, `schema.test.ts` mit `strict: false`. `app-generated.test.ts` nutzt deshalb die Optionen des Servers, damit die Goldendateien so geprüft werden wie eine echte Abschrift.
- **Wechselnde Kennungen der Vorgaben.** Nie gespeicherte Vorgaben bekommen je App-Start neue UUIDs (R14). Schnitt 4 muss das vor dem ersten Senden lösen (zum Beispiel die angezeigte Liste einmal speichern), sonst sieht Claude bei jedem Abgleich scheinbar neue Programme.
- **Abschrift über 256 KiB.** Siehe „Nicht in Scope“; Schnitt 4 entscheidet über das Senden.
- **Stiller Auslass.** Ausgelassene Bausteine sind für Claude unsichtbar; das ist die gewählte Abwägung gegen die Ablehnung der ganzen Abschrift. Die Zahl ausgelassener Bausteine wird in diesem Schnitt nicht gemeldet.
- **Watch und Widget.** Kompilieren `Meditationstimer iOS` nicht; der Build-Wächter bleibt in der Abschlussprüfung.

## Definition of Done

- [ ] ACs AC-1 bis AC-26 nachgewiesen, im Protokoll `Executed N tests` mit N ≥ 1
- [ ] Vollständige Unit-Suite grün; `npm test` im Validator grün (inklusive neuer Datei)
- [ ] Build grün für iOS (Simulator `iPhone 17 Pro`, iOS 27.2), Watch und Widget
- [ ] Zeilenzählung: Produktiv-Diff ≤ 250 Zeilen, Funktionen ≤ 50 Zeilen, keine weitere bestehende App-Datei geändert
- [ ] Goldendateien von Hand im Diff geprüft, nicht vom Test erzeugt
- [ ] Durchlauf im Simulator (Regression) mit Screenshot
- [ ] Adversary-Prüfung: Verdict VERIFIED
- [ ] Elternspec `openspec/specs/features/claude-verbindung-app.md`: Schnitt-3-Zeile „Erledigt“
- [ ] Änderungen am Gerät von Henning: keine, kein Start auf seinen Geräten

## Changelog

- 2026-11-24: Angelegt als Schnittspec für #57 Schnitt 3 (Abschrift Fassung 1, Goldendateien `empty`, `full`, `limits`, Validator-Test). Entscheidungen aus der Analyse übernommen: Variante B (Übungen), P1 (Programme und Atemübungen), Klemmen und Kürzen, `noEffect` wird `accepted`, Determinismus, `readCurrent` ohne Seiteneffekt.
