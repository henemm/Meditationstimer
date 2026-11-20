# A2b GREEN, Zwischenstand 2026-11-17 (Orchestrator)

Developer-Agent: 3 Produktdateien, +176/-70 = 246 LoC (inkl. 34 xcstrings), Grenze 250 fast erreicht.

## Grün
- Unit: alle außer zwei A2c-1-Fällen (`test_existingUserStore_unchangedAfterPresetMigration`, `ExerciseCatalogTests.test_defaultPrograms_referenceExistingCatalogIds`).
- UI: `test_exercisePickerOption_isTappableById`, `test_hintField_localized_german/english`, `test_infoButton_forPresetPlanke_showsContent` (A2c-1-Test, unerwartet grün).

## Rot (je 3 Versuche)
1. `test_exercisePicker_showsOnlyCatalogNames_german` (Z. 328): `workout.exercisePicker.own` im offenen `.menu` nicht auffindbar, `planke` schon.
   Hypothese (NICHT bewiesen): UIMenu mit 68 Einträgen öffnet bei der aktuellen Auswahl (Planke) und lädt nur Einträge
   in Sichtweite in den Zugänglichkeitsbaum (Apple-Forum https://developer.apple.com/forums/thread/719444: SwiftUI lädt bei
   langen Listen verzögert). Dann ist auch die Prüfung `options.count == 67` (Z. 330) mit `.menu` nie erfüllbar.
   Der Test `isTappableById` war nur grün, weil Liegestütze alphabetisch nah an Planke liegt.
   Folge laut Spec (Rückfallregel): `.navigationLink` = sichtbare Änderung → Entwurf Heute/Entwurf an PO vor Umsetzung.
2. `test_pickedExercise_persistsAfterRelaunch` (Z. 154): `option.builtin.planke` fehlt, Menü steht bei „Seitliche Planke rechts“ → gleiche Ursache.
3. `test_hintField_limitsLengthAndLines` (Z. 294): direkt nach Eingabe 81 statt ≤ 80. Setter-Kappung schreibt bei gleichem State
   nicht ins Feld zurück; `onChange`-Rückschreiben ist einen Tick zu spät. Bekanntes SwiftUI-Verhalten (Hacking-with-Swift-Forum
   „source of truth bug“, codecrew „limit number of characters“). Spec-Abweichung: Normalisierung per `onChange` statt Setter.
4. `test_hintEnteredInEditor_visibleUnderRingInTraining` (Z. 203/204): `app.buttons["Start"]` mehrdeutig (Zeilen-Startknöpfe
   heißen ebenfalls „Start“) → Testschuld, Korrektur nur in einer RED-Phase durch QA-Writer.

## Nachstellung 2026-11-17 (Wegwerf-Kopie, Diagnosetest, `Executed 1 test`, Protokolle scratchpad/diag/out3.txt, out5.txt)
- `.menu`: öffnet bei der gewählten Übung, im Baum stehen nur 14–21 Einträge rund um die Auswahl. `own` erscheint nach EINEM Wischen nach oben (Button, „Eigene Übung...“). Einträge A–J nur per Wischen nach unten erreichbar.
- `.navigationLink`: ebenfalls faul (15–16 je Blick), beginnt oben; durch Scrollen kommen alle 67 + `own` zusammen.
- Urteil: Produkt mit `.menu` ist bedienbar und testbar, sofern der Test scrollt. Fehlerhaft sind die Testannahmen
  (Option ohne Scrollen sichtbar; Zählung 67 auf einen Blick). Kein Wechsel auf `.navigationLink` nötig → keine sichtbare Änderung, kein PO-Entwurf.
- Entscheidung Tech Lead: `.menu` bleibt (Spec). Zurück in RED: QA-Writer bessert Tests nach
  (a) `pickExercise` wischt in beide Richtungen, bis die Option im Baum steht; (b) Zählung sammelt Kennungen beim Scrollen
  in beide Richtungen, Ziel 67 + `own`; (c) Z. 203 eindeutiger Fortsetzen-Knopf statt `app.buttons["Start"]`.
  Danach GREEN: Hinweis-Kappung (81 statt 80) im Produkt.

## RED-Nachbesserung erledigt (Phase zurück auf phase5_tdd_red, nur WorkoutHintUITests.swift geändert, nicht committet)
- Helfer `revealOption`/`dragMenu` (Menü per Koordinaten-Zug scrollen; swipeDown schließt das Menü), Zählung sammelt 67 + own, Fortsetzen-Knopf heißt „Weiter“, `openPresetEditor()` vor erneutem `openPhaseEditor(row: 0)`.
- Grün (je `Executed 1 test`): isTappableById, showsOnlyCatalogNames_german, pickedExercise_persistsAfterRelaunch, hintEnteredInEditor_visibleUnderRingInTraining.
- Rot, 3 von 3 Läufen: test_hintField_limitsLengthAndLines Z. 338 „Hinweis ueber 80 Zeichen“ (84, 84, 81) → Produktfehler, Kappung per onChange greift nicht verlässlich.
- Nächster Schritt nach PO-„go“: GREEN, Developer behebt Kappung im Produkt (z. B. verzögertes Rückschreiben oder Kappung im Binding mit erzwungener Aktualisierung), LoC-Stand 246/250 beachten.

## Nächste Schritte (offen, Stand vor Nachstellung)
- Hypothese zu 1/2 reproduzieren: Diagnosetest in Wegwerf-Kopie (Scratchpad), listet Kennungen im offenen Menü vor/nach Wischen.
  Erster Versuch scheiterte am App-Start der Kopie im Simulator („Simulator device failed to launch“, vermutlich Signatur/Installation
  der Kopie neben dem Original), nicht am Test.
- Bestätigt sich 1/2: PO-Entwurf `.menu` (heute) vs. `.navigationLink` (eigene Liste) als Artefakt; danach Tests 1, 2, 4 in RED-Runde nachbessern.
- Zu 3: Kappung mit verzögertem Rückschreiben oder UIKit-Feld; LoC-Budget beachten (246/250), ggf. Schnitt teilen.
- Skript `Scripts/run-uitests.sh` ist auf iOS 26.5 fest, Simulator hat nur 27.2 (Developer nutzte Kopie im Scratchpad) → eigenes Issue.

## GREEN erreicht (2026-11-17)
- Kappung über `hintBinding` (Setter: Rohwert setzen, bei Abweichung gekappten Wert per `DispatchQueue.main.async` nachschreiben; `onChange` entfernt). Quelle: forums.swift.org/t/75861.
- `test_hintField_limitsLengthAndLines` 3/3 grün; alle 8 WorkoutHintUITests grün; Unit 261 passed, 2 erwartete A2c-1-Rotfälle.
- LoC Produkt 250/250 (genau an der Grenze).
- Bekannt: Anzeige kann beim Tippen kurz > 80 Zeichen zeigen, gespeichert wird immer gekappt.
- Nächster Schritt: PO-Freigabe „go“ der GREEN-Ergebnisse, dann Adversary (Step 7/8 in /50-implement).
