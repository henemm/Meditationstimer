# Context: feature-83-hinweis-katalogauswahl

## Request Summary
Schnitt A2b von Epic #48 (Spec `DOCS/specs/features/feature-48-uebungskatalog.md`, AC-18 bis AC-25): optionales
Hinweisfeld im Schrittdialog, Hinweiszeile im Training unter dem Ring, Ansage „Name. Hinweis" (nur wenn Ansagen an),
Übungsauswahl nur aus den 67 Katalogübungen (lokalisiert) plus „Eigene Übung…". Erste für Henning sichtbare Stufe.

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` (2180 Z.) | Alles Sichtbare: `PhaseEditorView` (Z. 2021 ff., Picker Z. 2053/2064 über `exerciseSuggestions`, Prüfung `isCustom` Z. 2039), `SetEditorView` (Z. 1847 ff., neuer Schritt mit `exerciseSuggestions.first` Z. 1939, Speichern Z. 1972, Schrittzeilen Z. 1910), `WorkoutSetRow` (Z. 1608 ff., Start Z. 1625, Info Z. 1650), Training/Ring (ab Z. 1199, Name + Info-Knopf Z. 1358/1367, Pause „Als nächstes" Z. 1380 ff.), Ansagen (Z. 1041 erste Übung in `beginSessionAfterCountdown`, Z. 1518–1529 Satzformen, Z. 1550 Pause-Ankündigung). Stubs aus dem RED-Gerüst: `apply(_:)`, `newDefault(bundle:)` Z. 282–285, `WorkoutAnnouncement.spokenText` Z. 318 (liefert ""), `textToSpeak` Z. 321 (fertig). |
| `Meditationstimer iOS/Views/ExerciseDetailSheet.swift` | Titel `.navigationTitle(exerciseName)` Z. 114 → lokalisierter Katalogname; UI-Test erwartet Kennungen `exerciseDetail.effect`, `exerciseDetail.instructions`. |
| `Meditationstimer iOS/Localizable.xcstrings` | Neue Texte „Hinweis (optional)"/„Hint (optional)", Platzhalter, „Eigene Übung…"; vorhandene Schlüssel `Exercise %d of %d: %@`, `Last exercise: %@`, `Round %d of %d: %@`, `Last round: %@`. Zählt laut Projektregel nicht zur Zeilengrenze (`loc_exclude_patterns`), solange #89 offen ist, wirkt die Regel im Hook aber evtl. nicht. |
| `LeanHealthTimerTests/WorkoutPhaseMigrationTests.swift` | RED-Tests vorhanden: `test_spokenText_withAndWithoutHint` (AC-20), `test_announcement_respectsSpeakSetting` (AC-21), `test_selectingCatalogOrOwnExercise_setsExerciseId` (AC-23, inkl. `newDefault` → `builtin.archer-liegestuetze`). |
| `LeanHealthTimerUITests/WorkoutHintUITests.swift` | RED-UI-Tests vorhanden (7 Tests, Vorgabe „Core Circuit"). |
| `Meditationstimer iOS/Services/ExerciseDatabase.swift` | Katalog (67 Einträge, `exerciseId(forName:)`, lokalisierte Namen) — Quelle für Auswahl und Ansage-Namen. Nur lesen. |

## Existing Patterns
- Ansage: `NSLocalizedString`-Format + `String(format:)`; neue reine Funktion `WorkoutAnnouncement.spokenText` mit `bundle`-Parameter (für Test DE/EN). Beide Aufrufstellen müssen über `textToSpeak` laufen (AC-21, Adversary prüft per Codesuche).
- Schrittdaten: `WorkoutPhase` mit `exerciseId`/`hint` seit A2b-0; `normalizedHint` existiert (AC-14) und ist für die Editor-Eingabe wiederzuverwenden (AC-24).
- Info-Blatt: `ExerciseDetailSheet(exerciseName:exerciseId:)`; heute noch `ExerciseDatabase.exerciseId(forName:)` an Z. 1351/1803 statt gespeicherter Kennung.
- UI-Test-Zugriff über `accessibilityIdentifier`; Tabs nur positionsbasiert (Memory).

## Erwartete Kennungen (aus den UI-Tests, heute alle NICHT im App-Code)
`workout.programRow.<Name>.edit`, `workout.programRow.<Name>.start`, `workout.setEditor.save`, `workout.setEditor.phaseRow.<n>`,
`workout.phaseEditor.exercisePicker`, `workout.phaseEditor.hintField`, `workout.phaseEditor.ownNameField`, `workout.phaseEditor.save`,
`workout.exercisePicker.option.<exerciseId>`, `workout.exercisePicker.own`, `workout.training.hint`, `workout.training.infoButton`,
`exerciseDetail.effect`, `exerciseDetail.instructions`. Alle Bedienelemente dafür liegen in den zwei Produktdateien oben.

## Dependencies
- Upstream: `ExerciseDatabase` (Katalog, Namensableitung), `WorkoutPhase.normalizedHint`, `AVSpeechSynthesizer`-Pfad im Training, `@AppStorage("speakExerciseNames")`.
- Downstream: `WorkoutTab.swift` nutzt verschachtelte Typen (`SetEditorView`, `WorkoutProgramSessionCard`); Watch-App nicht betroffen (iOS-only Zweig). `exerciseSuggestions` bleibt als Liste bis A2c-2 stehen, wird aber aus Auswahl, `isCustom` und Standardname entfernt.

## Existing Specs
- `DOCS/specs/features/feature-48-uebungskatalog.md` — Abschnitt „Editor, Training, Ansage — A2b", AC-18…AC-25, Test-Plan Z. 340 ff.
- `openspec/specs/features/workouts.md` — Szenarien-Nachzug erst in A2c-2.

## Risks & Considerations
- **Zeilengrenze:** Spec schätzt Produkt 150 + Test 130 (Tests liegen schon im RED-Commit, zählen also nur als Änderung, falls nachgebessert). 14 Kennungen + Hinweisfeld + Hinweiszeile + Auswahl + Ansagefunktion könnten knapp werden; xcstrings-Ausnahme wirkt wegen #89 evtl. nicht → bei Überschreitung STOP, nicht Grenze anheben.
- **Ansage an zwei Stellen** (Countdown-Ende und Pause) plus Rundenformen: keine zweite `speakExerciseNames`-Auswertung übrig lassen.
- **Katalogwahl schreibt deutschen Namen in `name`** (Entscheidung 6), Anzeige aber lokalisiert aus dem Katalog; `own.*` zeigt `name` wörtlich.
- **Picker-Bindung**: Auswahlwert sollte die Kennung sein, nicht der Name, sonst kollidieren eigene Namen mit Katalognamen.
- **Hinweisfeld einzeilig + 80 UTF-16**: TextField mit Zeilenumbruch-Eingabe (Einfügen) → Normalisierung beim Ändern.
- **UI-Tests lang**: Komplett-Suite >10 min, Einzeltests nur `Klasse/Methode`, nur `Executed N tests` mit N ≥ 1 zählt.
- **Walk-Test** Pflicht: Hinweis eingeben → Training → Zeile unter dem Ring; Auswahl Deutsch/Englisch.

## Analysis

### Type
Feature (Schnitt A2b von Epic #48, erste für den PO sichtbare Stufe)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | MODIFY | Stubs füllen: `apply(_:)` Z. 281 (Katalog: `exerciseId` + **deutscher** Katalogname in `name`, Entscheidung 6; eigene: `own.<slug>` + Name wörtlich), `newDefault(bundle:)` Z. 282 (alphabetisch erste Katalogübung nach lokalisiertem Namen), `spokenText` Z. 318 (Name bei `builtin.*` lokalisiert über Kennung, bei `own.*` `phase.name`; Hinweis wörtlich mit „. " angehängt; vier Satzformen). Ansage: `getNextExerciseNameForTTS` Z. 1508–1534 und beide Sprechstellen (`beginSessionAfterCountdown` Z. 1037–1042, Pause Z. 1550–1553) laufen nur noch über `WorkoutAnnouncement.textToSpeak`. PhaseEditorView ab Z. 2021: Auswahlwert = Kennung bzw. Marker „eigene", Optionen aus `ExerciseDatabase.catalog` (67) plus „Eigene Übung…", `isCustom` über Kennung statt `exerciseSuggestions`, einzeiliges Hinweisfeld mit `normalizedHint`-Begrenzung (80 UTF-16) im Binding-Setter, Speichern über `apply`. SetEditorView Z. 1939 Standardname über `newDefault`. Hinweiszeile `workout.training.hint` zwischen Ring und Zähler, nur Arbeitsphase (auch pausiert), nie in „Als nächstes". Kennungen: programRow.<Name>.edit/.start (Z. 1624/1658), setEditor.save/phaseRow.<n>, phaseEditor.exercisePicker/hintField/ownNameField/save, exercisePicker.option.<id>/own, training.infoButton (Z. 1366/1393). |
| `Meditationstimer iOS/Views/ExerciseDetailSheet.swift` | MODIFY | Titel lokalisiert aus Katalog (Z. 114), Kennungen `exerciseDetail.effect` (Z. 50) und `exerciseDetail.instructions` (Z. 65). |
| `Meditationstimer iOS/Localizable.xcstrings` | MODIFY | Neu DE/EN: „Hinweis (optional)"/„Hint (optional)", „z. B. 12 Wiederholungen, langsam"/„e.g. 12 reps, slow", „Eigene Übung…"/„Custom exercise…" (manual + translated, sonst Großbuchstaben im Debug, Memory Bug 38). Ansage-Schlüssel vorhanden. |
| `LeanHealthTimerUITests/WorkoutHintUITests.swift` | MODIFY (RED-Nachbesserung) | Siehe Testlücken. |
| `LeanHealthTimerTests/WorkoutPhaseMigrationTests.swift` | MODIFY (RED-Nachbesserung, klein) | Katalogumfang 67 und Auswahloptionen 67 + 1 als Unit-Prüfung (AC-22 Anzahl). |

Nicht betroffen: Watch-App, Widget (Datei gehört nur zum iOS-Target), `WorkoutTab.swift` (nutzt nur die Typen, Signaturen bleiben), `openspec/specs/features/workouts.md` (Nachzug erst A2c-2). `exerciseSuggestions` bleibt als unbenutzte Liste bis A2c-2 stehen (Spec); `getNextAnnouncementText` Z. 1488 nicht anfassen.

### Scope Assessment
- Files: 5 (xcstrings laut `.claude/openspec.yaml` von der Zeilengrenze ausgenommen, Wirkung wegen #89 unsicher)
- Estimated LoC: Produkt ~170 (WorkoutProgramsView ~165, ExerciseDetailSheet ~6), Test ~35, zusammen ~205 von 250
- Risk Level: MEDIUM — zentrale Trainings- und Editoransicht; Datenmodell steht seit A2b-0; Hauptrisiko ist die Test-Erreichbarkeit der Auswahloptionen.
- Funktionsgrenze 50 Zeilen: Übungsauswahl als eigene Unteransicht auslagern.

### Technical Approach
1. Reine Funktionen zuerst (`apply`, `newDefault`, `spokenText`), drei Unit-Tests werden grün.
2. Ansage zentral: Textbau in `getNextExerciseNameForTTS` über `WorkoutAnnouncementForm` + `textToSpeak`; keine zweite Auswertung von `speakExerciseNames` für Übungsansagen (Adversary-Codesuche, AC-21).
3. Übungsauswahl: Picker bleibt im heutigen Stil `.menu` (Spec „wie bisher", keine sichtbare Formänderung), flach alphabetisch nach lokalisiertem Namen (passt zur Regel für den Standardnamen), Auswahlwert ist die Kennung, damit eigene Namen nicht mit Katalognamen kollidieren. Kennungen an den Optionszeilen.
4. Hinweisfeld einzeilig (`TextField` ohne vertikale Achse), Normalisierung im Binding-Setter statt `onChange`-Rückschreiben (keine Cursor-Sprünge oder Schleifen); leer ergibt `nil`.
5. Hinweiszeile im Training, Info-Knopf-Kennungen, Detailblatt.

**Recherche zur Auswahl (2026-11-17):** Kennungen an einzelnen Einträgen von SwiftUI-Menüs findet XCUITest nicht verlässlich (Apple-Forum https://developer.apple.com/forums/thread/713900 und https://developer.apple.com/forums/thread/690882; kein bestätigter Fix für `.menu`). Deshalb im RED-Schritt als Erstes ein Erreichbarkeitsnachweis: eine Option per Kennung antippen. Trägt `.menu` die Kennungen nicht, Rückfall auf `.pickerStyle(.navigationLink)` (eigene Liste, Abschnitte nach Kategorie). Das ist eine sichtbare Änderung der Bedienung, dann vorher Entwurf „Heute/Entwurf" für den PO (Regel „Entwurf vor Spec").

**Alternative:** eigene Auswahlliste (NavigationLink je Kategorie auf `List` mit `Button`-Zeilen). Kennungen sicher, Zustand voll kontrollierbar; Nachteil +30–40 Zeilen, Häkchen und Zurück selbst bauen, sichtbare Formänderung. Nur, falls weder `.menu` noch `.navigationLink` die Kennungen tragen.

### Testlücken (im RED-Schritt nachbessern)
- `test_pickedExercise_persistsAfterRelaunch`: OR-Bedingung (`isSelected || value=="1" || label.contains("Planke")`) praktisch immer wahr, eindeutig prüfen; laut Testplan den **zweiten** Schritt als „Eigene Übung" statt Zeile 0; Info-Knopf-Prüfung nach Neustart ergänzen (AC-23 Oberfläche); `addTeardownBlock` fehlt (verseucht Folgetests).
- AC-19 Arbeitsphase ohne Hinweis: ausdrücklich prüfen, dass `workout.training.hint` bei einem Schritt ohne Hinweis fehlt.
- AC-22 Anzahl 67 plus „Eigene Übung…": als Unit-Prüfung.
- `test_infoButton_forPresetPlanke_showsContent` gehört zu A2c-1, bleibt bewusst rot, im Prüfbericht einzeln ausweisen.
- Spec-Kennungsliste (Spec Z. 228–235) nennt nur fünf Kennungen; die übrigen aus den Tests in der Spec nachtragen.

### Dependencies
- Upstream: `ExerciseDatabase.catalog`, `info(forId:)`, `localizedTexts(forId:bundle:)`, `displayName(exerciseId:storedName:bundle:)`, `ownExerciseId(forName:)`; `WorkoutPhase.normalizedHint`; Ansage-Schlüssel in xcstrings.
- Downstream: `WorkoutTab.swift` (verschachtelte Typen, Signaturen unverändert); Tests.

### Nebenbefunde (nicht in diesem Schnitt)
- `speakExerciseNames` Startwert `false` im Programm-Training (Z. 796), `true` im freien Workout (`WorkoutsView.swift:80`): Inkonsistenz, eigenes Issue.
- Freigegebener Entwurf `DOCS/artifacts/feature-48-uebungskatalog/entwurf.html` und `heute-*.jpg` liegen nicht im Repo (nie eingecheckt, in keiner Arbeitskopie), nur veröffentlicht unter https://claude.ai/artifact/XrPS81A34yJzGMDacNYQiU; im Spec-Schritt aus dem Artefakt ins Repo holen.
- Verweis `docs/artifacts/feature-48-uebungskatalog/test-api-vertrag.md` (WorkoutPhaseMigrationTests Z. 6) ist tot; die Datei liegt als `DOCS/context/feature-48-test-api-vertrag.md`.

### Open Questions
- [x] Picker-Stil: technisch entschieden (`.menu` beibehalten, Nachweis im RED-Schritt, Rückfall mit PO-Entwurf).
- keine offenen PO-Fragen
