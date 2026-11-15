## Validation Report: feature-80-zusatzuebungen-1-12 (A2d-1a)

Stand: be98783, 2026-11-15

### Test Results
- Unit-Suite: 263 Fälle; rot sind genau die 14 erwarteten Fälle späterer Schnitte (5 ExerciseCatalogTests, 9 WorkoutPhaseMigrationTests). `SessionDurationTests`-Ausreißer bei 3 Wiederholungen grün (Zeit, nicht diese Runde).
- Server: 709/709 grün.

### Spec Compliance
- A2d-1a: alle Kriterien erfüllt (Katalog, JSON, Texte DE/EN, Namensschlüssel „Leg Swing“).

### App-Durchlauf (F001)
- Erster Lauf (16:39): „V-Ups“-Info-Blatt zeigte „nicht verfügbar“.
- Reproduziert (17:25, `WalkVUpsUITests-repro2.swift.txt`, Diagnosezeile im Blatt): Das Blatt bekommt beim ersten Tipp einen **leeren Namen** (`name=[] passedId=[own.uebung]`) – bei jeder Übung, auch Burpees (`repro2-erster-tipp-burpees-de.png`).
- Gegenprobe (17:31): Burpees zuerst, dann V-Ups → V-Ups zeigt Wirkung und Anleitung in DE und EN (`repro2-vups-de.png`, `repro2-vups-en.png`). `Executed 1 test, with 0 failures`.
- Ursache liegt in `.sheet(isPresented:)` + im selben Tipp gesetztem `@State` (seit f3398a3, 2025-11-06), nicht in dieser Runde → eigenes Ticket #90.

### Regression Check
- Keine Regressionen durch diese Runde.

### Scope Check
- Quellcode: `ExerciseDatabase.swift`, `Localizable.xcstrings` (+ Katalog-JSON aus RED); innerhalb der Spec.

### Result: PASS (Katalog-Inhalte im echten Blatt belegt); Info-Blatt-Fehler beim ersten Tipp → #90
