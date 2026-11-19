# Context: feature-84-vorgaben-kennung (A2c-1, Teil von Epic #48)

## Request Summary
Die vier mitgelieferten Workout-Programme sollen je Schritt eine feste Katalog-Kennung (`builtin.*`) tragen.
Sichtbar ändert sich nichts; vorhandene Programme der Nutzer bleiben unverändert (AC-27, AC-28, AC-30).

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Tabs/WorkoutTab.swift:812` | `let defaultWorkoutSets` (dateiweit, internal, im `#if os(iOS)`-Block). 4 Programme, 24 Schritte, heute alle ohne `exerciseId` |
| `Meditationstimer iOS/Tabs/WorkoutTab.swift:371-388` | `migrateSets`: ergänzt fehlende Vorgaben per Name, füllt `description` nach; Aufruf nur in `loadSets` (Z. 365) |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:338` | `WorkoutSet.migratingPresets(_:presets:)` ist ein Stub (gibt `stored` unverändert zurück) — AC-30-Test zielt darauf |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:213, 233-237` | `WorkoutPhase.init` mit `exerciseId: String? = nil`; Ableitung der Kennung nur beim Dekodieren |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:459` | `private let legacyDefaultWorkoutSets` (10er-Liste) — gehört zu A2c-2, nicht anfassen |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:1406-1430` | Info-Knopf im Training: `selectedExerciseId = phase.exerciseId`, Blatt `ExerciseDetailSheet(exerciseName:exerciseId:)` |
| `Meditationstimer iOS/Views/ExerciseDetailSheet.swift:17` | `exerciseId ?? ExerciseDatabase.exerciseId(forName:)` — Namens-Rückfall |
| `Meditationstimer iOS/Services/ExerciseDatabase.swift:697-723` | `lookupKey`, `exerciseId(forName:)` (DE-Name → EN-Tabelle → links/rechts → `own.*`) |
| `Contracts/catalog/builtin-exercises.json` | Referenzkatalog |
| `LeanHealthTimerTests/ExerciseCatalogTests.swift:301-312` | AC-27 `test_defaultPrograms_referenceExistingCatalogIds` — kompiliert, rot (24× nil) |
| `LeanHealthTimerTests/WorkoutPhaseMigrationTests.swift:380-396` | AC-30 `test_existingUserStore_unchangedAfterPresetMigration` — kompiliert, rot ab Z. 394 (Stub ergänzt nichts) |
| `LeanHealthTimerUITests/WorkoutHintUITests.swift:407-421` | AC-28 `test_infoButton_forPresetPlanke_showsContent` (Vorgabe „Core Circuit") — vermutlich heute schon grün |

## Kennungen der 12 Übungsnamen (alle exakte Katalogtreffer)
Burpees → `builtin.burpees`; Planke → `builtin.planke`; Seitliche Planke links/rechts → `builtin.seitliche-planke-links`/`-rechts`;
Fahrrad-Crunches → `builtin.fahrrad-crunches`; Beinheben → `builtin.beinheben`; Russian Twists → `builtin.russian-twists`;
Kniebeugen → `builtin.kniebeugen`; Ausfallschritte → `builtin.ausfallschritte`; Mountain Climbers → `builtin.mountain-climbers`;
Hampelmänner → `builtin.hampelmaenner`; Liegestütze → `builtin.liegestuetze`.

## Existing Patterns
- Vorgaben werden im Code gebaut (`WorkoutPhase(name:workDuration:restDuration:)`); neue Parameter `exerciseId:` am Ende mit Default.
- Gespeicherte Daten: `exerciseId` wird wörtlich übernommen, fehlt sie, abgeleitet (A2b-0).
- Reine statische Funktion beim Typ für Logik ohne UI (`WorkoutSet.loadStored`, `migratingPresets`).

## Dependencies
- Upstream: `ExerciseDatabase` (Katalog, Kennungen), `WorkoutPhase`/`WorkoutSet` (Modell).
- Downstream: `WorkoutTab.loadSets` → `migrateSets`; Training/Info-Knopf; Ansage (`WorkoutAnnouncement`, löst Namen per Kennung).

## Existing Specs
- `DOCS/specs/features/feature-48-uebungskatalog.md` — Schnitttabelle Z. 187, Ansatz Z. 226 ff., AC-27/28/30 Z. 302-305, Testplan Z. 325/362/370.

## Risks & Considerations
- **Spec-Abweichung:** AC-27 nennt `defaultWorkoutSets` „Z. 813, private → internal“; Stand: Z. 812, bereits internal. Änderungshistorie erwähnt `internal static`; der Test greift auf die dateiweite `let` zu → so lassen.
- **AC-30 braucht Produktcode:** `migratingPresets` ist ein Stub; die Logik aus `migrateSets` (Vorgaben per Name ergänzen, `description` nachfüllen) muss dorthin wandern und `migrateSets` sie nutzen. Eigene Programme und gespeicherte Schritte dürfen dabei nicht verändert werden.
- **AC-28 ist kein RED-Nachweis:** Der Info-Knopf findet die Planke heute über den Namens-Rückfall. Der Test sichert nur, dass nichts verloren geht. Echter Nachweis der Kennung kommt aus AC-27 (Unit). Im Prüfbericht so ausweisen.
- **Bestehende Nutzerdaten:** Gespeicherte Vorgaben ohne Kennung bekommen sie beim Laden ohnehin per Ableitung; `migrateSets` ergänzt fehlende Vorgaben per Name — eine schon gespeicherte, umbenannte Vorgabe wird damit ggf. doppelt ergänzt (heutiges Verhalten, unverändert lassen).
- Plattform: `defaultWorkoutSets` liegt im `#if os(iOS)`-Block; Unit-Tests laufen auf iOS-Simulator, ok.
- Umfang klein: Produkt ca. 40 Zeilen (24× `exerciseId:` + Migrationsfunktion), Tests liegen schon vor.

## Analysis

### Type
Feature (Schnitt A2c-1 von Epic #48), keine sichtbare Änderung.

### Ist-Stand (gemessen 2026-11-19, Simulator iPhone 17 Pro iOS 27.2)
- AC-27 `ExerciseCatalogTests/test_defaultPrograms_referenceExistingCatalogIds`: **rot**, 24× „ohne exerciseId" (alle 24 Schritte).
- AC-30 `WorkoutPhaseMigrationTests/test_existingUserStore_unchangedAfterPresetMigration`: **rot**, 2 Fehlschläge im zweiten Fall (Anzahl 4 statt 5, letzter Name „Eigenes" statt „Core Circuit") — Stub ergänzt nichts.
- AC-28 `WorkoutHintUITests/test_infoButton_forPresetPlanke_showsContent`: **grün** (`Executed 1 test, with 0 failures`), über den Namens-Rückfall (`ExerciseDetailSheet.swift:17`). Reiner Regressionsschutz, kein RED→GREEN; im Prüfbericht so ausweisen.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Tabs/WorkoutTab.swift` | MODIFY | 24× `exerciseId: "builtin.…"` in `defaultWorkoutSets` (Z. 812 ff.); `migrateSets` (Z. 371-388) ruft `WorkoutSet.migratingPresets` auf und speichert nur bei Änderung (`m != sets`) |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | MODIFY | Stub `migratingPresets` (Z. 338) durch reine Funktion ersetzen: fehlende Vorgaben per Name in Vorgabe-Reihenfolge anhängen, leere `description` gleichnamiger Programme nachfüllen, sonst nichts anfassen |
| `LeanHealthTimerTests/ExerciseCatalogTests.swift` | MODIFY (RED) | AC-27 zusätzlich: Kennung == `ExerciseDatabase.exerciseId(forName: phase.name)` (fängt vertauschte, aber existierende Kennungen) |
| `LeanHealthTimerTests/WorkoutPhaseMigrationTests.swift` | MODIFY (RED) | AC-30 um Fall „Vorgabe ohne `description` wird nachgefüllt, Phasen unverändert" ergänzen (sonst wandert die Nachfüll-Logik ungeprüft) |
| `LeanHealthTimerUITests/WorkoutHintUITests.swift` | — | AC-28 unverändert, bleibt grün |

### Scope Assessment
- Files: 4 (2 Produkt, 2 Test)
- Estimated LoC: Produkt ca. +40/-15, Test ca. +20
- Risk Level: LOW — betrifft nur die Vorgabeliste und die Ergänzung fehlender Vorgaben; gespeicherte Programme werden nicht umgeschrieben.

### Technical Approach
Kennungen **explizit** an alle 24 Schritte (Spec Z. 226 verlangt „explizit"; eine feste Kennung entkoppelt Vorgabe von Name/Lokalisierung). `migratingPresets` wird die einzige Migrationslogik (rein, testbar), `migrateSets` ruft sie auf. Equatable ist synthetisiert inkl. `id` (UUID); `defaultWorkoutSets` ist ein globales `let`, die UUIDs sind je Prozess stabil → AC-30-Gleichheit hält.

**Alternative (verworfen):** Kennung beim Bau aus dem Namen ableiten (Hilfsfunktion mit `ExerciseDatabase.exerciseId(forName:)`). Kürzer, aber koppelt die Kennung wieder an den Namen — widerspricht Ziel und Spec-Wortlaut. Würde die Spec-Entscheidung „explizit" (Z. 226) kippen.

### Dependencies
- Gespeicherte Vorgaben ohne Kennung: bekommen sie schon beim Dekodieren per Ableitung (`WorkoutProgramsView.swift:233-237`); beim nächsten Speichern wird sie mitgeschrieben. A2c-1 ändert daran nichts.
- Ansage und Info-Blatt lösen über die Kennung; explizite Kennungen = bisherige Ableitung → keine hörbare/sichtbare Änderung.
- Typen und `defaultWorkoutSets` liegen im `#if os(iOS)`-Block; Watch/Widget unberührt (AC-31).
- Nicht anfassen: `legacyDefaultWorkoutSets` (A2c-2).

### Umfeldbefund
- iOS-26.5-Laufzeit ist auf dem Rechner nicht mehr vorhanden; dieser Epic-Zweig hat `Scripts/run-uitests.sh` noch fest auf 26.5. Behoben auf dem Hauptstand (8a86e6a, #74), aber noch nicht in den Epic-Zweig übernommen (22 Commits Abstand, Übernahme hat Konflikte). Bis dahin Tests per `xcodebuild … OS=27.2` mit `Klasse/Methode`. Übernahme des Hauptstands vor/zu Beginn von Phase 4 erledigen (Git-Aufgabe von Claude).

### Open Questions
- keine (keine Produktentscheidung offen)
