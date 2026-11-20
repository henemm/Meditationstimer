# RED-Bericht #51 Runde 2a-1 (2026-11-20)

## Unit-Tests `LeanHealthTimerTests/ClaudeApplyTests.swift` (19 Tests, Namen wie Spec)

**RED-Beleg im Repo (`test-red-output.txt`):** Übersetzungsfehler, Exit 65. Ursache sind ausschließlich fehlende
Symbole der neuen API: `ClaudeApplyState`, `ClaudeApplyResult`, `apply(_:to:lastSnapshotAt:now:)`. Alle übrigen
Meldungen (`T?` statt `T`, `Equatable has no member 'applied'`, Key-Path-Inferenz) sind Folgefehler, weil diese Typen fehlen.

**Zusatzprüfung, dass Tests und Assertions zur Spec-API passen (Wegwerfkopie außerhalb des Repos):**
Projekt in den Scratchpad kopiert und dort nur eine Platzhalter-API ergänzt. Sie folgt der Spec-Signatur: `ClaudeOrigin`, `ClaudeApplyState(sets:presets:log:)`,
`ClaudeApplyLogEntry`, `ClaudeApplyResult`, die Felder `claude`/`modifiedAt` an `WorkoutSet` und `Preset`, `apply` liefert `(state, .noEffect)`.
- `build-for-testing`: **TEST BUILD SUCCEEDED**. Die Testdatei übersetzt also gegen die spezifizierte API, es gibt keine Tippfehler gegen bestehende Typen.
- Lauf: **18 failed, 1 passed, 0 Abstürze.**
  - In einer ersten Fassung brachen 9 Tests mit `Index out of range` ab. Sie wurden gehärtet: Hilfsfunktion `first(_:_:)` mit `XCTUnwrap`, siehe unten.
  - Bestanden hat `testAltJsonWorkoutSetUndPresetLiestSichOhneNeueFelderUndRoundTrip` (AC-15). Er ist eine Absicherung ohne Laufzeit-RED: Er prüft das Codable-Verhalten optionaler Felder. Die Platzhalter-Felder erfüllen es bereits. Im Repo ist er wie alle anderen über den Übersetzungsfehler rot.
- Kein Platzhalter gelangt ins Repo. Das Edit-Gate (nur Testdateien in dieser Phase) bleibt unberührt.

## UI-Tests (Absicherungen ohne RED, Spec Test Plan)

Protokoll: `uitest-absicherung.txt`.
- `ClaudeFelderUITests/testProgrammeUndAtemuebungenUeberstehenNeustart`: **passed** (230 s).
  - Abweichung im Aufbau, Tech-Lead-Entscheidung: Der Test legt je ein neues Programm („Workout Neustart“) und eine neue Atemübung („Atem Neustart“) an, statt Vorgaben umzubenennen.
  - Grund: `migrateSets`/`migratePresets` ergänzen fehlende Vorgaben beim Laden nach Namen. Eine umbenannte Vorgabe käme also zurück, und die Anzahl wäre verschieden.
  - Die Aussage bleibt gleich: Die gespeicherte Liste wird nach dem Neustart durch die Typen gelesen. Ein Teardown löscht beide Einträge.
- `WorkoutHintUITests/test_pickedExercise_persistsAfterRelaunch`: **failed** auf unverändertem App-Code.
  - Fehler in allen drei Wiederholungen: Zeile 319 „Schritt ohne Hinweis darf keine Hinweiszeile zeigen“.
  - Altfehler vor 2a-1, als #105 angelegt.
  - Regressionsmaßstab für diese Runde: nach GREEN dieselbe Stelle, dieselbe Meldung, und alle Prüfungen davor (Neustart, Auswahl Planke, eigene Übung) weiter grün.
