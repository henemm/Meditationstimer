# Test-API-Vertrag #48 (festgelegt in der RED-Phase, 2026-11-15)

Die Spec (`docs/specs/features/feature-48-uebungskatalog.md`, Abschnitt „Technischer Ansatz") überlässt Namen und
Signaturen der testbaren Funktionen der RED-Phase. Die Tests in `LeanHealthTimerTests/ExerciseCatalogTests.swift`,
`LeanHealthTimerTests/WorkoutPhaseMigrationTests.swift` und `LeanHealthTimerUITests/WorkoutHintUITests.swift`
verwenden genau diese Oberfläche. Modul: `@testable import Lean_Health_Timer`.

## Katalog (A2a, A2d)

```swift
enum ExerciseOrigin: String { case builtin, own, claude
    init?(exerciseId: String)            // Präfix vor dem ersten Punkt; sonst nil
}

struct ExerciseInfo {
    let id: String                        // NEU, z. B. "builtin.planke"
    let name: String                      // deutscher Katalogname (wie bisher)
    let category: ExerciseCategory        // String(describing:) == Kategorie im JSON, z. B. "fullBody"
    let effect: String
    let instructions: String
    var origin: ExerciseOrigin { get }    // aus dem Präfix von id
}

struct ExerciseTexts: Equatable { let name: String; let effect: String; let instructions: String }

extension ExerciseDatabase {
    static var catalog: [ExerciseInfo] { get }                      // Reihenfolge wie builtin-exercises.json
    static func info(forId id: String) -> ExerciseInfo?
    static func exerciseId(forName name: String) -> String          // Entscheidung 4, nie leer: builtin.* oder own.*
    static func ownExerciseId(forName name: String) -> String       // Entscheidung 5: "own.<slug>"
    static func displayName(exerciseId: String?, storedName: String, bundle: Bundle = .main) -> String
        // builtin.* → lokalisierter Katalogname aus `bundle`; own.*/claude.*/unbekannt/nil → storedName
    static func localizedTexts(forId id: String, bundle: Bundle) -> ExerciseTexts?
        // Name, Wirkung, Anleitung in der Sprache von `bundle` (z. B. de.lproj / en.lproj)
}
```

`ExerciseDatabase.info(for: String)` (Namenssuche) bleibt bestehen.

## Schritt-Modell, Laden, Sicherung (A2b-0)

```swift
struct WorkoutPhase {
    var exerciseId: String?               // NEU, decodeIfPresent; nach dem Dekodieren abgeleitet, wenn nil
    var hint: String?                     // NEU, decodeIfPresent; nach dem Dekodieren normalisiert
    init(id: UUID = UUID(), name: String, workDuration: Int, restDuration: Int,
         exerciseId: String? = nil, hint: String? = nil)
    static func normalizedHint(_ raw: String?) -> String?   // Entscheidung 9
}

extension WorkoutSet {
    static let backupKeyPrefix = "workoutProgramSetsBackup."
    /// nil bei fehlendem Schlüssel (ohne Sicherung) oder nicht dekodierbaren Daten (mit Sicherung der Rohdaten
    /// unter backupKeyPrefix + Unix-Sekunden von `now`; ein vorhandener Schlüssel wird nie überschrieben).
    static func loadStored(from defaults: UserDefaults, key: String = "workoutProgramSets", now: Date = Date()) -> [WorkoutSet]?
    /// Bisheriges migrateSets als reine Funktion: fehlende Vorgaben per Name anhängen, fehlende Beschreibung nachfüllen.
    static func migratingPresets(_ stored: [WorkoutSet], presets: [WorkoutSet]) -> [WorkoutSet]
}
```

## Auswahl, Ansage (A2b)

```swift
enum ExerciseSelection { case catalog(id: String); case own(name: String) }

extension WorkoutPhase {
    mutating func apply(_ selection: ExerciseSelection)
        // .catalog: exerciseId = id, name = deutscher Katalogname; .own: exerciseId = own.<slug>, name = eingegebener Name
    static func newDefault(bundle: Bundle = .main) -> WorkoutPhase
        // alphabetisch erster Katalogeintrag nach lokalisiertem Namen, mit Kennung, 30 s / 15 s
}

enum WorkoutAnnouncementForm: Equatable {
    case exercise(number: Int, total: Int)   // "Exercise %d of %d: %@"
    case lastExercise                         // "Last exercise: %@"
    case round(number: Int, total: Int)      // "Round %d of %d: %@"
    case lastRound                            // "Last round: %@"
}

enum WorkoutAnnouncement {
    static func spokenText(_ form: WorkoutAnnouncementForm, phase: WorkoutPhase, bundle: Bundle = .main) -> String
        // Satz mit lokalisiertem Namen; mit Hinweis ". <Hinweis>" angehängt (Entscheidung 11)
    static func textToSpeak(_ form: WorkoutAnnouncementForm, phase: WorkoutPhase, speakExerciseNames: Bool,
                            bundle: Bundle = .main) -> String?
        // einzige Entscheidungsstelle; false → nil
}
```

## Vorgaben (A2c-1)

`defaultWorkoutSets` in `WorkoutTab.swift` wird dateiweit `let` (internal).

## Bedienkennungen (UI-Tests)

Aus der Spec: `workout.phaseEditor.exercisePicker`, `workout.exercisePicker.option.<exerciseId>`,
`workout.exercisePicker.own`, `workout.phaseEditor.hintField`, `workout.training.hint`, `workout.training.infoButton`.

In der RED-Phase ergänzt:

- `workout.programRow.<Programmname>.edit` — Bearbeiten-Knopf der Programmzeile (z. B. `workout.programRow.Core Circuit.edit`)
- `workout.programRow.<Programmname>.start` — Start-Knopf der Programmzeile
- `workout.setEditor.addExercise` — „Übung hinzufügen" im Programm-Editor
- `workout.setEditor.phaseRow.<Index>` — Schrittzeile im Programm-Editor (0-basiert)
- `workout.setEditor.save` / `workout.phaseEditor.save` — Sichern-Knöpfe
- `workout.phaseEditor.ownNameField` — Textfeld „Übungsname" bei „Eigene Übung…"
- `exerciseDetail.effect` und `exerciseDetail.instructions` — Texte im Info-Blatt

## Schnitte und Testlauf

Die Tests decken alle Schnitte ab. Das Testziel kompiliert erst, wenn die Oberfläche oben vollständig existiert.
Empfehlung für `/50-implement`: im ersten Schnitt die Signaturen vollständig anlegen (Rumpf darf in späteren
Schnitten folgen), danach je Schnitt dessen Tests per `-only-testing:<Klasse>/<Methode>` grün nachweisen; die Tests
späterer Schnitte dürfen bis zu ihrem Schnitt rot sein. Am Ende sind alle grün.
