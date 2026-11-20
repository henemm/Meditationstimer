# Adversary-Protokoll #85 (A2c-2), Workflow feature-85-aufraeumen

## Runde 1: Checkliste
- [x] AC-26 Spec-Nachzug: `openspec/specs/features/workouts.md` (Commit fade62a) enthält die Szenarien "Exercise Hint Line", "Exercise Hint TTS", "Exercise Catalog Identifiers", korrigiert "Program Selection" (4 Vorgaben) und "Exercise Name TTS". Gegenlesen: Katalog `Contracts/catalog/builtin-exercises.json` hat catalogVersion 2, 67 Einträge, 67 eindeutige Kennungen, alle `builtin.`; Hinweis nur in Arbeitsphase (`WorkoutProgramsView.swift:947` `if currentPhase.isWork, let hint`); `spokenText`/`textToSpeak` Z. 362/379 existieren.
- [x] AC-29 Tote Kopie entfernt: Codesuche `exerciseSuggestions|legacyDefault|Placeholder for Phase 1` über *.swift = 0 Treffer (Treffer nur in DOCS/*.md, historisch). MARK Z. 385 heißt "Namespace", `enum WorkoutProgramsView` Z. 387.
- [x] AC-31 Unberührt: `git diff fade62a~` (Stand vor Runde) enthält keine .xcstrings, .plist, .entitlements oder Watch-/Widget-Datei; kein Treffer auf `workoutProgramSets` im Diff. Build Watch App (generic/watchOS Simulator): BUILD SUCCEEDED. Build MeditationstimerWidgetExtension (generic/iOS Simulator): BUILD SUCCEEDED.
- [x] Scope: `git diff` Swift-Datei = 1 Einfügung, 87 Löschungen: nur der Block "Exercise Suggestions List" samt Doc-Kommentar und die MARK-Umbenennung; `getNextAnnouncementText` nicht im Diff.
- [x] Regression Unit-Suite: `Executed 263 tests, with 0 failures`, `** TEST SUCCEEDED **` (plus 1 Swift-Testing-Test; deckt sich mit 264 aus #84).

## Runde 2: Edge Cases
- [x] String-Verweise auf die Liste im Code: keine (Swift = 0 Treffer, auch Kommentare).
- [x] Spec-Zeilenangaben nach der Löschung (erledigt in Runde 3: Spec-Changelog Z. 431 vom 2026-11-20 kennzeichnet die Angaben als Analysestand vor der Löschung und nennt MARK Z. 385, Enum Z. 387; stimmt mit WorkoutProgramsView.swift:385/387 überein; frisches Testprotokoll adversary-test-output.txt: Executed 263 tests, 0 failures). Ursprünglicher Befund: Spec Abschnitt A2c-2 nennt den Enum bei "Z. 473" (1 Treffer); tatsächlich jetzt Z. 387. Die Angabe "Z. 385–469" für die Liste ist als Stand 2026-11-20 vor der Löschung gekennzeichnet und damit historisch korrekt. Die Z. 473 ist ein Stand-vor-Löschung-Wert (Z. 473 minus 86 = 387), also ebenfalls als Analysestand lesbar; Hinweis, kein Produktfehler.
- [x] Aufrufer: kein Verweis auf `exerciseSuggestions` in iOS, Watch, Widget, Tests (Codesuche s. o.), Builds grün.
- Nicht geprüft: UI-Suite und App-Durchlauf (nicht Teil dieses Auftrags).

VERDICT: VERIFIED
Begründung: Alle fünf Punkte bewiesen; reine Löschung plus MARK, Builds (iOS-Tests, Watch, Widget) grün, 263 XCTest 0 Fehler. Einziger Hinweis: veraltete Zeilenangabe "Z. 473" in der Spec (kosmetisch).

## Geprüfte Dateien

- sha256:1b5bd570abceacb6c2c91c56a74a49e3ffda0f93763770254d43a87e71820697  DOCS/specs/features/feature-48-uebungskatalog.md
- sha256:790317545b156e501257053231a9867cdac931b2ef8828675b17c8deba467c70  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- sha256:1118b690f40b0b2e772fc32d2d9053e59dc8127b96c80de0bd4d5a1440598d15  openspec/specs/features/workouts.md
