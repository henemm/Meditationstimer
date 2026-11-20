# Context: feature-82-datenmodell-kennung-hinweis (#82, Runde A2b-0 von Epic #48)

## Request Summary
Jeder Programmschritt (`WorkoutPhase`) trägt eine Übungskennung `exerciseId` und einen optionalen Hinweis `hint`.
Gespeicherte Programme im alten Format laden verlustfrei, fehlende Kennungen werden beim Laden aus dem Namen
abgeleitet (Entscheidung 4), Hinweise werden normiert (Entscheidung 9). Nicht dekodierbare Daten unter
`workoutProgramSets` werden byte-gleich unter `workoutProgramSetsBackup.<Unix-Sekunden>` gesichert, bevor die Vorgaben
greifen. Doku-Nachzug in `claude-annahme.md`. Nichts Sichtbares für Henning.
Spec: `DOCS/specs/features/feature-48-uebungskatalog.md` (freigegeben), Datenmodell-Abschnitt Z. 211-215,
Rundenzeile A2b-0 Z. 185, Widersprüche 1/2 Z. 163-164, AC-10 bis AC-17 Z. 267-276, Test-Plan Z. 333-339.

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` Z. 203-254 | `WorkoutPhase` (Felder `exerciseId`/`hint` schon da, Codable synthetisiert, Init mit Defaults `nil`); Stubs aus dem gemeinsamen RED-Commit: `normalizedHint` (gibt `raw` zurück), `WorkoutSet.backupKeyPrefix`, `WorkoutSet.loadStored(from:key:now:)` (gibt `nil`). Spätere Stubs (`apply`, `newDefault`, `migratingPresets`, `ExerciseSelection`, `WorkoutAnnouncement*`) gehören zu A2b/A2c-1 — nicht anfassen |
| `Meditationstimer iOS/Tabs/WorkoutTab.swift` Z. 44, 362-395 | aktiver Bildschirm: `setsKey`, `loadSets()` mit `try? JSONDecoder()` (Z. 364) und stillem Rückfall auf `defaultWorkoutSets` (Z. 368) → auf `WorkoutSet.loadStored` umstellen; `migrateSets()`/`saveSets()` unverändert |
| `Meditationstimer iOS/Services/ExerciseDatabase.swift` Z. 709-753 | vorhanden aus A2a: `exerciseId(forName:)` (Entscheidung 4), `ownExerciseId(forName:)`, `slug` (Umlaute, 63 Zeichen) → wiederverwenden, nicht duplizieren |
| `LeanHealthTimerTests/WorkoutPhaseMigrationTests.swift` | 12 Tests, davon 8 für A2b-0 (AC-10 bis AC-16), 4 für A2b/A2c-1 (bleiben rot). Vertrag: `normalizedHint(_:)`, `loadStored(from:key:now:)`, `backupKeyPrefix`, `ownExerciseId(forName:)`, Decoder auf `WorkoutPhase`/`[WorkoutSet]` |
| `openspec/specs/features/claude-annahme.md` Z. 18, 35-38 | AC-17: `own.<slug>` in „Voraussetzung aus A2" ergänzen, Vermerk `claudeId` → Schema-Namen in #51 |

## Existing Patterns
- Eigener Decoder: nur `StreakManager.swift:30-35` (`init(from:)` mit `decodeIfPresent ... ?? 0`).
- Stille Rückfälle ohne Sicherung gibt es mehrfach (SmartReminderEngine, MeditationTab, AtemView) — A2b-0 ist die erste Sicherung im Produkt.

## Dependencies
- Upstream: `ExerciseDatabase.exerciseId(forName:)` (A2a), `JSONDecoder`, `UserDefaults`.
- Downstream: Editor, Training und Info-Knopf lesen `WorkoutPhase`; A2b nutzt `exerciseId`/`hint` sichtbar; A2c-1 setzt Kennungen in den Vorgaben.
- Watch und Widget benutzen weder den Schlüssel noch `WorkoutPhase` (Codesuche).

## Existing Specs
- `DOCS/specs/features/feature-48-uebungskatalog.md` — maßgeblich.
- `openspec/specs/features/claude-annahme.md` — Doku-Nachzug.

## Risks & Considerations
- **Ableitung beim Dekodieren:** synthetisiertes Codable liest fehlende Felder als `nil`, leitet aber nicht ab (AC-11). Eigenes `init(from:)` nötig; gespeicherte Kennung nie neu berechnen (AC-13); `encode` schreibt Felder nur, wenn gesetzt.
- **Datenverlust:** ein unlesbares Feld kippt das ganze Array → Sicherung vor Rückfall, vorhandenen Schlüssel derselben Sekunde nicht überschreiben (AC-15); Erststart und gültige Daten erzeugen keine Sicherung (AC-16).
- **Tote Kopie in `WorkoutProgramsView`:** eigenes `loadSets/saveSets` (Z. 648-692) umgeht die Sicherung, wird aber nie instanziiert; Entfernen ist A2c-2 — hier nicht anfassen.
- **Hinweis-Normalisierung:** Steuer-/Zeilentrenner (U+2028/2029, Tab, Zeilenumbruch) → Leerzeichen, U+00A0 als Leerraum, Kürzen auf 80 UTF-16-Einheiten ohne Graphem zu zerreißen.
- Scope: 3 Code-Dateien + 1 Doku, Spec schätzt Produkt 110 / Test 110 Zeilen; Tests liegen schon vor (gemeinsamer RED-Commit), daher RED-Phase = Nachweis der 8 roten Tests.
- Keine Änderung an `Info.plist`, Entitlements, Watch/Widget oder den Schlüsseln `workoutProgramSets`/`speakExerciseNames` (AC-31).

## Analysis

### Type
Feature (Runde A2b-0 von Epic #48) — nichts Sichtbares, Datenstand.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | MODIFY | `WorkoutPhase`: private `CodingKeys`, eigenes `init(from:)`/`encode(to:)` in der Struct-Deklaration; Stubs `normalizedHint` und `loadStored` mit Logik füllen. Übrige Stubs (`apply`, `newDefault`, `migratingPresets`, `WorkoutAnnouncement*`) und die tote `loadSets/saveSets`-Kopie (Z. 648-692, A2c-2) unverändert |
| `Meditationstimer iOS/Tabs/WorkoutTab.swift` | MODIFY | `loadSets()` (Z. 362-370) nutzt `WorkoutSet.loadStored(from: .standard, key: setsKey)`; `migrateSets`/`saveSets` unverändert |
| `openspec/specs/features/claude-annahme.md` | MODIFY | AC-17: `own.<slug>` in „Voraussetzung aus A2", Vermerk `claudeId` → Schema-Namen in #51 |
| `LeanHealthTimerTests/WorkoutPhaseMigrationTests.swift` | — | Tests liegen aus gemeinsamem RED-Commit vor, werden nicht geändert |

Nicht betroffen (geprüft): Watch und Widget kompilieren die beiden Dateien nicht (Exceptions im pbxproj sind dort Include-Listen: nur `auftakt.caf`, `Localizable.xcstrings`, `MeditationActivityAttributes.swift`). `ExerciseDatabase` ist `struct` ohne Actor-Isolation, kein `SWIFT_DEFAULT_ACTOR_ISOLATION` → aus `init(from:)` aufrufbar.

### Scope Assessment
- Files: 2 Code + 1 Doku
- Estimated LoC: Produkt +100..+130 / -5, Doku +4
- Risk Level: MEDIUM — berührt das Laden aller gespeicherten Trainingsprogramme; abgesichert durch Altbestands-Tests (AC-10) und Sicherung (AC-15)

### Technical Approach (Empfehlung Plan/Sonnet, von mir übernommen)
1. **Decoder:** `id`, `name`, `workDuration`, `restDuration` mit `decode` (Fehlverhalten wie bisher); `exerciseId`, `hint` mit `decodeIfPresent`. Gespeicherte Kennung wörtlich übernehmen (auch leere, AC-13), nur bei fehlend/`null` `ExerciseDatabase.exerciseId(forName: name)`. `hint = normalizedHint(...)`. **Encoder:** `encode` für die vier Pflichtfelder, `encodeIfPresent` für die beiden neuen, ohne Normalisierung.
2. **`normalizedHint`:** über `unicodeScalars` U+0000-001F, U+007F-009F, U+00A0, U+2028/2029, Bidi-Steuerzeichen (U+061C, U+200E/200F, U+202A-202E, U+2066-2069) → Leerzeichen; Läufe von Leerzeichen zu einem zusammenfassen; trimmen; leer → `nil`; Grapheme anhängen, solange `utf16.count` ≤ 80; danach erneut trimmen.
3. **`loadStored`:** kein `Data` unter dem Schlüssel → `nil` ohne Sicherung (AC-16). Dekodieren gelingt → Ergebnis (auch `[]`). Fehler → Sicherung, dann `nil`. Sicherungsschlüssel `workoutProgramSetsBackup.<Int(now.timeIntervalSince1970)>`, belegt → `…-2`, `-3` … (Obergrenze), nie überschreiben (AC-15). Originalschlüssel bleibt stehen.
4. **Doppelte Sicherung vermeiden (eigener Befund):** Im Rückfallzweig von `loadSets` wird nicht gespeichert (`saveSets` nur aus `migrateSets` bei gelesenem Bestand und bei Nutzeraktionen, Z. 152/158). Kaputte Daten bleiben also stehen, und jeder App-Start legte eine weitere, byte-gleiche Sicherung an. Regel: liegt unter dem Präfix schon eine Sicherung mit identischen Bytes, wird keine neue angelegt. Verträgt sich mit AC-15 Fall 2 (vorhandene Sicherung hat andere Bytes). In der Spec als Zusatz festhalten.
5. **Reihenfolge:** `normalizedHint` → Codable → `loadStored` → `WorkoutTab.loadSets` → Doku. Erwartet grün: AC-10..AC-16 (AC-12 ggf. schon aus A2a grün); rot bleiben AC-20/21/23/30 (spätere Runden).

### Alternative (verworfen)
Ableitung nicht im Decoder, sondern als Nachbearbeitung in `loadStored` (Decoder bleibt synthetisiert, weniger Code). Verworfen: Die Tests AC-10/11/13/14 dekodieren `WorkoutPhase` direkt, und jeder andere Dekodierweg bliebe ohne Kennung. Kippen würde das die Spec-Festlegung „eigenes `init(from:)`" (Z. 213).

### Dependencies
- Upstream: `ExerciseDatabase.exerciseId(forName:)`/`ownExerciseId(forName:)` (A2a), `JSONDecoder`, `UserDefaults`.
- Downstream: Editor, Training, Info-Knopf lesen `WorkoutPhase`; A2b zeigt `hint`, A2c-1 setzt Kennungen in den Vorgaben.

### Open Questions (technisch, von mir entschieden — kein PO-Thema)
- [x] Mehrfach-Leerzeichen zusammenfassen: ja („a\n\nb" → „a b"), idempotent; Spec-Zusatz.
- [x] Kollisionsschema Sicherung: Suffix `-2`, `-3` …; Spec-Zusatz.
- [x] Keine erneute Sicherung byte-gleicher Daten; Spec-Zusatz.
