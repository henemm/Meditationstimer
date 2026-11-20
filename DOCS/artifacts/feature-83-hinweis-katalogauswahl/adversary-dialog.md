# Adversary-Dialog feature-83-hinweis-katalogauswahl (Schnitt A2b)

Datum: 2026-11-17 · Prüfer: implementation-validator (nur Spec + betroffene Dateien, kein Developer-Bericht)
Basis: iPhone 17 Pro Simulator, iOS 27.2. Testausgabe: /tmp/adversary_test_output.txt

## Checkliste

- [x] AC-18 Hinweis unter dem Ring, Ring zeigt weiter „Übung“ (UI-Test grün, Code Z. 1370-1379)
- [x] AC-19 Ohne Hinweis keine Zeile, in der Pause nie (UI-Test grün)
- [x] AC-20 Ansagetext DE/EN mit Hinweis (test_spokenText_withAndWithoutHint grün)
- [x] AC-21 Ansage nur bei speakExerciseNames, beide Sprechstellen über textToSpeak (test_announcement_respectsSpeakSetting grün, Codesuche)
- [x] AC-22 Auswahl genau 67 Katalogübungen plus „Eigene“ (Unit- und UI-Test grün)
- [x] AC-23 Wahl setzt Kennung, Name bleibt, nach Neustart erhalten (Unit- und UI-Test grün)
- [x] AC-24 Höchstens 80 UTF-16, eine Zeile, leer wird nil, kein Graphem-Riss (UI-Test grün, normalizedHint)
- [x] AC-25 Feldbeschriftung und Platzhalter DE/EN ohne Großschreibung (beide UI-Tests grün)

## Runde 1: Beweise

**Tests**
- Unit-Suite: 261 `Test case … passed`, 2 failed. Das sind genau die zwei erwarteten A2c-1-Rotfälle (`test_existingUserStore_unchangedAfterPresetMigration`, `ExerciseCatalogTests.test_defaultPrograms_referenceExistingCatalogIds`).
- UI `WorkoutHintUITests`: 8 von 8 passed (showsOnlyCatalogNames_german, isTappableById, hintEnteredInEditor_visibleUnderRingInTraining, hintField_limitsLengthAndLines, hintField_localized_english, hintField_localized_german, infoButton_forPresetPlanke_showsContent, pickedExercise_persistsAfterRelaunch).
- Screenshot: keiner. Die Tests liefern keine Bildanhänge. AC-18 ist über den UI-Test (Position und Text) belegt.

| AC | Status | Beweis |
|---|---|---|
| AC-18 Hinweis unter dem Ring, Ring zeigt weiter „Übung“ | BEWIESEN | WorkoutProgramsView.swift:1370-1379. `Text(hint)` mit `workout.training.hint` steht zwischen Ring und Zähler, nur bei `currentPhase.isWork && phase.hint != nil`. Der UI-Test prüft Position und Text. |
| AC-19 Ohne Hinweis keine Zeile, in der Pause nie | BEWIESEN | Einzige Hinweis-Stelle (Z. 1371). Die „Als nächstes“-Vorschau zeigt keinen Hinweis. Der UI-Test prüft die Pause und Schritt 2 ohne Hinweis. |
| AC-20 Ansagetext DE/EN | BEWIESEN | `spokenText` (Z. 348-364) hängt `". " + hint` an. Der Name kommt lokalisiert über `ExerciseDatabase.displayName`. `test_spokenText_withAndWithoutHint` ist grün. |
| AC-21 Ansage nur bei `speakExerciseNames` | BEWIESEN | `textToSpeak` (Z. 365-367) ist die einzige Auswertung. Es gibt genau zwei Sprechstellen (Z. 1085 nach dem Countdown, Z. 1597 in der Pause), beide gehen über `textToSpeak`. `test_announcement_respectsSpeakSetting` ist grün. |
| AC-22 67 Katalogübungen und „Eigene“ | BEWIESEN | `exercisePicker` (Z. 2098-2120) nutzt `pickerCatalog()` und `own`. Die Unit- und UI-Tests sind grün. |
| AC-23 Wahl setzt Kennung, Name bleibt, nach Neuladen erhalten | BEWIESEN | `apply(_:)` (Z. 283-292). Unit-Test und Relaunch-UI-Test sind grün. |
| AC-24 Höchstens 80 UTF-16, eine Zeile, leer wird nil | BEWIESEN | `normalizedHint` (Z. 265-282) kürzt per `Character`. Ein Surrogatpaar an der Grenze wird nie zerschnitten, ein Feld mit nur Leerzeichen ergibt nil. Der UI-Test ist grün. |
| AC-25 Lokalisierung | BEWIESEN | xcstrings mit manual/translated, DE und EN laut Spec. Beide Lokalisierungs-UI-Tests sind grün. |

## Runde 2: Edge Cases und Umfang

- Emoji an der Grenze, Zeilenumbruch beim Einfügen, Feld mit nur Leerzeichen, Bearbeiten eines bestehenden Hinweises: Der Setter setzt `draft.hint` immer normalisiert. Ein Defekt wurde nicht gefunden.
- Umfang: WorkoutProgramsView +142/-69, ExerciseDetailSheet +4/-1, xcstrings +34. Zusammen sind das 250, genau auf der Grenze. Keine Funktion hat mehr als 50 Zeilen.

## Findings

1. NIEDRIG: Das Feld zeigt beim schnellen Tippen oder Einfügen kurz mehr als 80 Zeichen (Z. 2126-2132, asynchrones Nachschreiben). Gespeichert wird immer gekappt. Der Punkt ist bekannt und an den PO gemeldet.
2. NIEDRIG: Der Info-Knopf in der „Als nächstes“-Vorschau setzt `selectedExerciseId = nil` (Z. 1456). Das ist Altverhalten aus A2a und liegt nicht im Umfang von A2b.
3. INFO: Das Layout der Hinweiszeile (`lineLimit(2)`) ist auf kleinen Geräten nicht visuell belegt. Ein Fehler ist nicht belegt.
4. INFO: `exerciseSuggestions` (Z. 374) ist tot. Laut Spec wird es in A2c entfernt.

Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:265
Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:283
Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:348
Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:365
Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:1085
Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:1370
Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:1597
Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:2098
Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:2126
Code reference: Meditationstimer iOS/Views/ExerciseDetailSheet.swift:1
Code reference: Meditationstimer iOS/Localizable.xcstrings:1
Code reference: LeanHealthTimerUITests/WorkoutHintUITests.swift:1

VERDICT: VERIFIED

## Rundenumfangs-Lauf für das QA-Gate (Orchestrator)

Vorgehen wie in Runde A2b-0: Die gesamte Unit-Suite lief ohne die zwei laut Spec späteren Rotfälle aus A2c-1. Ergebnis in test-scope-a2b.txt: 261 passed, 0 failed, TEST SUCCEEDED. Die UI-Klasse WorkoutHintUITests hatte 8 von 8 passed (siehe Testausgabe des Adversary).

## Geprüfte Dateien

- sha256:86577c3e90a0f764c8ce6c9603997c9a16e39552dbb6a6915be6c045f8245fb5  LeanHealthTimerUITests/WorkoutHintUITests.swift
- sha256:be75879658d16acaf6f873181052740bd267f94062ff855333de9ebdb2adca2f  Meditationstimer iOS/Localizable.xcstrings
- sha256:5435213dbfc2061b3476e493c8b17a74cf7ae4ae04ee9c8595181aded9edd588  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- sha256:090fe61b2ea630d1c2fb9ad68324aca27655174c601bad9e9dea495f4ad16a5a  Meditationstimer iOS/Views/ExerciseDetailSheet.swift

## Prüfbasis

- base: 2f56d2efd05e7ab583fc5ce989a12fd0969ad725
- blob:9247ab28032e60d420220898a47c866526dfdc21  LeanHealthTimerUITests/WorkoutHintUITests.swift
- blob:973eec157108c613708f523238b760e5b9a74623  Meditationstimer iOS/Localizable.xcstrings
- blob:eb400159ba75a364084304180e9d30663aac67be  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- blob:c421dbf9975814ce3d374b27f7a69442caced777  Meditationstimer iOS/Views/ExerciseDetailSheet.swift
