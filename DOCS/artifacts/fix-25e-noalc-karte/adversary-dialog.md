# Adversary-Protokoll: fix-25e-noalc-karte (#25, Runde 25e)

- Workflow: fix-25e-noalc-karte
- Datum: 2026-11-19
- Stand: HEAD 8080fbc plus uncommittete Änderungen (LeanHealthTimerUITests.swift, DayDetailHabitsUITests.swift, neu HealthSheetHelper.swift)
- Methode: rein statisch plus vorhandene Protokolle. Keine UI-Tests, kein xcodebuild (Simulator belegt durch AC-13-Gesamtlauf).
- Umfang gemessen: `git diff HEAD --stat` = 69 Einfügungen / 305 Löschungen in zwei Dateien, plus neue Datei 57 Zeilen (ca. +126 / -305). `git diff origin/main --stat` ohne DOCS/.claude: nur die zwei Testdateien (plus neue Datei, ungetrackt). App-Code unverändert. Testfunktionen: 82 vorher, 77 nachher (genau fünf gestrichen).

## Runde 1: Befunde und Nachfragen

- F1 (AC-5): `testLevelTrackerShowsLargeIconsInSeparateRow` prüft nur `sadButton.exists || happyButton.exists` und die Existenz von `trackerDateButton`. Keine Frame-Prüfung, also kein Beweis für "eigene Zeile über der trackerDateButton-Zeile". Nachfrage: Stimmt die AC überhaupt mit dem Code?
- F2 (AC-11): Beweislauf-Protokoll enthält keine Zeile `Executed N tests`. Nachfrage: reicht das?
- F3 (AC-10): Nur iPhone 17 Pro erase statt `shutdown all`; Tests liefen auf Klonen. Nachfrage: wurde der Helfer überhaupt belastet?
- F4: Helfer scheitert still (keine XCTFail, Schleife endet nach 8 Durchgängen oder erstem Leerlauf). Kann er falsch tippen?
- F5 (AC-6): Wird das Verlauf-Blatt am Inhalt erkannt?
- F6 (AC-4): Zählung je Zeile?

## Runde 2: Selbstprüfung der Nachfragen

- F1: TrackerRow.swift:82-125 (`levelBasedLayout`): Row 1 = Header mit `trackerDateButton` (Zeile 103), Row 2 = Stufen-Knöpfe (Zeile 118-121), also die Stufen-Icons liegen UNTER der Datumsknopf-Zeile. Die AC-5-Formulierung "über der trackerDateButton-Zeile" ist fachlich falsch. Der Test behauptet das nicht, würde bei einer Frame-Prüfung gemäß Spec sogar rot. Gleichzeitig prüft er die Position gar nicht; die `||`-Bedingung lässt einen fehlenden Knopf zu, solange der andere da ist. Ergebnis: Befund bleibt (MEDIUM), Ursache ist Spec-Fehler plus abgeschwächte Prüfung. Der Test ist so nicht falsch-grün bezüglich des heutigen Verhaltens (Knöpfe existieren), beweist aber die Zeilenposition nicht.
- F2: Protokoll `test-green-output.txt` enthält 11 Zeilen `Test case '...' passed` für 11 Filter, je genau ein Test, plus `** TEST SUCCEEDED **`; das Protokoll nennt die Klonläufe (Clone 1 und Clone 3). Zahl der bestandenen Fälle = Zahl der Filter = 11 (N = 11 ≥ 1). Nulllauf ausgeschlossen, der Zweck von AC-11 (kein falsches Grün, #33) ist erfüllt. Der Wortlaut `Executed N tests` fehlt, das ist eine dokumentierte Abweichung. Ergebnis: akzeptabel, LOW; Spec sollte den Klonmodus nennen.
- F3: RED-Protokoll (Kopfzeilen): Erase davor, trotzdem lief Test 10 (ohne Helfer) grün, das Blatt lag dort nicht über dem Tracker-Tab. Heißt: Auch auf frisch gelöschtem Gerät erscheint das Blatt nicht in jedem Test, und im Beweislauf ist nicht belegt, dass der Helfer je ein Blatt weggetippt hat (im Log kein Hinweis). Der Beweislauf zeigt nur "grün trotz frischem Gerät", nicht "Helfer wirkt". Der Rotbeleg der Blattwirkung stützt sich auf das Bild `red-healthblatt-test9.png` und Aussagen im RED-Protokoll (Tests mit Blatt gelistet). Zusätzlich: Die ersten beiden Tests auf Clone 1 (DatePicker, EditorSheetHistoryLink) nutzen den Helfer nicht. Abweichung vom `simctl shutdown all`: ein zweiter Simulator einer Nachbarsitzung lief; Erase nur des Test-Geräts stellt denselben Zielzustand her und schont die fremde Sitzung. Bewertung: vertretbar, aber Wirksamkeit des Helfers nicht direkt bewiesen. LOW/MEDIUM-Grenze: MEDIUM nicht, da Spec das Blatt im RED nachweist; LOW.
- F4: HealthSheetHelper.swift:25-54. Ein Durchgang ohne Treffer kostet ca. 2+1+1+1 s ("OK") plus 3+1+1+1 s (Deny), dann `break`: ca. 11 s je Test, kein Fehlschlag, kein XCTFail. Der Helfer kann still scheitern; der Test scheitert dann später am Blatt (so entsteht eine unscharfe Fehlermeldung, aber kein Falsch-Grün). Falsch-Tippen: `host.buttons["OK"]` im App-Prozess (`self`) wäre ein App-eigener "OK"-Knopf; in diesen Tests erscheinen keine App-Alerts, Risiko niedrig (LOW). Koordinaten-Tipp über `coordinate(withNormalizedOffset: .zero).withOffset(frame.mid)` ist relativ zum App-Fenster; für Hostframes in Bildschirmkoordinaten korrekt.
- F5: Test `testNoAlcHistoryButtonOpensHistorySheet`: tippt `trackerHistoryLink` (TrackerEditorSheet.swift:392, NavigationLink) und wartet auf `app.navigationBars.staticTexts["History"]`; der Titel stammt aus TrackerHistorySheet.swift:55. Das ist ein inhaltliches Merkmal des Zielblatts, nicht die Existenz des Knopfs. `waitForExistence(5)`; kein `||`, kein XCTSkip. Beweist den Nutzen. Restrisiko: Editor wird über das erste `trackerEditButton` geöffnet; Tracker unspezifisch, Beweis trotzdem gültig. Aufgelöst: BEWIESEN.
- F6: `testLevelTrackerShowsInlineButtons` zählt `app.buttons.matching(identifier: "generic_💧").count >= 2` nach Anlegen des zweiten NoAlc-Trackers. Jeder Tracker hat genau einen 💧-Knopf (TrackerRow.swift:131-154), also entspricht Zählung = Zeilenzahl. `>= 2` statt `== 2` toleriert mehr, kein Falsch-Grün gegen das Verhalten. Beweist AC-4 hinreichend. Keine Frame-Prüfung "inline" (LOW, nicht gefordert).

## Checkliste

Pflichtpunkte:

1. `HealthSheetHelper.swift` mit `extension XCUIApplication { func dismissHealthSheetIfAny() }`: AKZEPTIERT (HealthSheetHelper.swift:4-5, genau eine Definition per grep).
2. Code aus DayDetailHabitsUITests verschoben, nur Aufruf dort: AKZEPTIERT (Diff: 62 Zeilen entfernt, vier Aufrufe `app.dismissHealthSheetIfAny()` bei Zeilen 50, 85, 101, 154; kein privater Helfer mehr).
3. Aufruf in jedem der fünf verbleibenden Tests nach `app.launch()`: AKZEPTIERT (LeanHealthTimerUITests.swift:1835, 2190, 2307, 2712, 2890, je direkt nach `app.launch()`).

Acceptance Criteria:

- AC-1: AKZEPTIERT. Test `testNoAlcLevelButtonsHaveIdentifiers` (Z. 1831-1853) prüft `generic_💧/✨/💥`; im Beweislauf passed.
- AC-2: AKZEPTIERT. Test nicht mehr in Datei (grep), `testDatePickerButtonOpensLevelSelectionViewWithDatePicker` passed im Beweislauf.
- AC-3: AKZEPTIERT. `testNoAlcLogSheetShowsCorrectTitle` entfernt; Teil-Ticket #99 ist "25f: Toten Code entfernen - NoAlcLogSheet ..." (OPEN). Kein `NoAlcLogSheet`-Treffer mehr in den UI-Test-Dateien.
- AC-4: AKZEPTIERT (siehe F6).
- AC-5: NACHFRAGE. Position nicht geprüft; AC-Text steht im Widerspruch zu TrackerRow.swift (Stufen UNTER Datumsknopf). Siehe Befund B1.
- AC-6: AKZEPTIERT (siehe F5).
- AC-7: AKZEPTIERT. Änderung nur Helferaufruf (Z. 2890); im Beweislauf passed.
- AC-8: AKZEPTIERT. Tests 3, 6, 7 nicht mehr in der Datei (82 -> 77, `grep` ohne Treffer); die drei Ersatztests (`testDatePickerButton...`, `testLevelTrackerShowsStreakInfo`, `testEditorSheetShowsHistoryLink`) passed im Beweislauf. Nutzen: Datum-Eintragen, Serie (`trackerStreak`), Verlauf-Link bleiben abgedeckt.
- AC-9: AKZEPTIERT. Eine Definition; DayDetail-Aufrufe vorhanden; drei DayDetail-Tests passed im Beweislauf (Spec spricht von vier, die Datei enthält drei Tests, Zeilen 137, 142, 167; kein Mangel).
- AC-10: NACHFRAGE (mit Abweichung, akzeptabel). Erase nur des Test-Geräts statt `shutdown all` begründet; Helferwirkung nicht direkt belegt (B3).
- AC-11: AKZEPTIERT mit Abweichung. Statt `Executed N tests` elf `Test case ... passed`-Zeilen bei elf Filtern (B2).
- AC-12: AKZEPTIERT. `git diff origin/main --stat -- . ':!DOCS' ':!.claude'` zeigt nur zwei Testdateien (plus neue Testdatei); kein App-Code.
- AC-13: ausstehend - Gesamtlauf durch Orchestrator.

## Befunde

```json
[
  {
    "id": "B1",
    "severity": "MEDIUM",
    "category": "spec_violation",
    "description": "AC-5 verlangt Beweis, dass die großen Stufen-Icons in eigener Zeile über der trackerDateButton-Zeile stehen. Der Test prüft nur Existenz (sad.exists || happy.exists) und trackerDateButton; keine Frame-Prüfung. Zudem ist die AC-Aussage selbst falsch: Im Code liegen die Stufen-Knöpfe unter der Header-Zeile mit dem Datumsknopf.",
    "evidence": "LeanHealthTimerUITests/LeanHealthTimerUITests.swift:2735-2745 (XCTAssertTrue(sadButton.exists || happyButton.exists)); Meditationstimer iOS/Tracker/TrackerRow.swift:103 (trackerDateButton in Row 1) und :118-121 (Level-Knöpfe in Row 2)",
    "remediation": "Spec/AC-5 korrigieren (Stufen-Icons in eigener Zeile UNTER der Header-Zeile) und im Test per Frames prüfen: sad.frame.minY > dateButton.frame.maxY-ish und alle fünf Knöpfe auf gleicher Höhe (`&&` statt `||`); alternativ AC auf Existenz abschwächen und das ehrlich benennen."
  },
  {
    "id": "B2",
    "severity": "LOW",
    "category": "spec_violation",
    "description": "AC-11 fordert wörtlich 'Executed N tests'; Beweislauf liefert diese Zeile im Parallel-Klon-Modus nicht. Zweck (kein Nulllauf) ist durch elf 'passed'-Zeilen für elf Filter erfüllt.",
    "evidence": "DOCS/artifacts/fix-25e-noalc-karte/test-green-output.txt:116-127 (11x 'Test case ... passed on Clone N'), keine 'Executed'-Zeile",
    "remediation": "AC-11 in der Spec um die Klonvariante ergänzen oder den Lauf mit -parallel-testing-enabled NO wiederholen, damit 'Executed 11 tests' erscheint."
  },
  {
    "id": "B3",
    "severity": "LOW",
    "category": "edge_case",
    "description": "Die Wirksamkeit des Helfers ist im Beweislauf nicht direkt belegt: Test 10 lief schon im RED auf frisch gelöschtem Gerät ohne Helfer grün (Blatt trat dort nicht auf), und das Green-Log zeigt nicht, ob je ein Blatt weggetippt wurde. Der Beweislauf zeigt 'grün auf frischem Gerät', nicht 'Helfer wirkt'. Abweichung vom 'simctl shutdown all' ist wegen Nachbarsitzung vertretbar.",
    "evidence": "DOCS/artifacts/fix-25e-noalc-karte/test-red-output.txt:5-10 (Test 10 grün, Blatt lag nicht über dem Tracker-Tab); test-green-output.txt ohne Helfer-Ausgabe",
    "remediation": "Optional: Helfer meldet per print/XCTContext.runActivity, wenn er ein Blatt behandelt hat, damit der Beleg es zeigt."
  },
  {
    "id": "B4",
    "severity": "LOW",
    "category": "anti_pattern",
    "description": "Helfer scheitert still (kein XCTFail), kostet auf sauberem Gerät ca. 11 s je Test, und sucht 'OK' auch im App-Prozess selbst (könnte einen App-eigenen OK-Knopf antippen).",
    "evidence": "LeanHealthTimerUITests/HealthSheetHelper.swift:25-54 (host === self ? 2 : 1 timeouts; break ohne Meldung; hosts enthält self)",
    "remediation": "Kein Handlungszwang in dieser Runde; bei #24 Dauerlösung (Startargument) ersetzen den Helfer."
  }
]
```

## Verdict Runde 1 (überholt durch Runde 2): AMBIGUOUS

Begründung: Statisch ist die Umsetzung sauber: nur Testcode, genau fünf Tests gestrichen, fünf repariert mit Helferaufruf nach `app.launch()`, Helfer genau einmal definiert, Ersatztests vorhanden und im Beweislauf grün, AC-6 prüft das Verlauf-Blatt am Titel (kein bloßer Existenztest), AC-4 zählt je Tracker einen Knopf. Offen bleibt AC-5: Der Test beweist die geforderte Zeilenposition nicht (nur Existenz, mit `||`), und die AC selbst widerspricht dem Code (Stufen liegen unter dem Datumsknopf). Das ist ein Spec-/Beweislücken-Punkt, kein Produktfehler und kein Falsch-Rot. Dazu zwei dokumentierte Abweichungen (AC-10 Erase statt shutdown all, AC-11 Klonprotokoll), beide inhaltlich vertretbar. AC-13: ausstehend - Gesamtlauf durch Orchestrator. VERIFIED, sobald B1 entschieden ist (Spec korrigieren oder Test um Frame-Prüfung ergänzen) und der Gesamtlauf keine neue Rotmeldung zeigt.

## Runde 2 (statisch, keine Testläufe)

Geprüft: neu gefasster Test AC-5, Einzellauf `test-green-ac5-b1.txt`, Gesamtlauf `regression-output.txt` gegen die 25b-Basis, Spec-Changelog.

- B1 (AC-5): `testLevelTrackerShowsLargeIconsInSeparateRow` (LeanHealthTimerUITests.swift:2708-2770): beide Rand-Stufen mit `waitForExistence` und `&&`; Frame-Vergleich gegen den nächstgelegenen `trackerDateButton` mit `maxY <= sadFrame.minY`; Check, dass kein Datumsknopf vertikal in der Stufen-Zeile liegt (deckt den Datumsknopf des anderen Stufen-Trackers ab); 😢/😊 gleiche Höhe (< 5 pt). Passt zum Layout in TrackerRow.swift:103 (Row 1) und :118-121 (Row 2). Einzellauf: `Executed 1 test, with 0 failures`, `TEST SUCCEEDED`. Der AC-Wortlaut "über" bleibt stehen, der Spec-Changelog stellt die Richtung als Schreibfehler klar und nennt das Layout als maßgeblich. Das genügt bei Spec-Freeze (AC-Text und Test widersprechen sich formal, der Changelog löst das auf). Status: GESCHLOSSEN.
- B2 (AC-11): Gesamtlauf `Executed 92 tests, with 20 tests skipped and 7 failures` (inkl. Wiederholungen), B1-Einzellauf `Executed 1 test`; Changelog regelt zusätzlich den Klonmodus. Status: GESCHLOSSEN.
- B3 (Wirksamkeit Helfer): Beleg weiter nur indirekt, aber der sequentielle Gesamtlauf zeigt alle fünf Cluster-A-Tests plus drei DayDetail-Tests grün. Status: AKZEPTIERT (LOW).
- B4 (stiller Helfer): unverändert, kein Handlungszwang. Status: AKZEPTIERT (LOW).

AC-13 Vergleich: 25b-Basis hatte 14 rot (zehn Cluster A, zwei Cluster C, `testGuidedWorkoutPauseButtonIsBelowProgressRing`, zwei Background-Tests). 25e-Gesamtlauf: 2 rot, beide in der Basis schon rot: `test_breathingExercise_backgroundForeground_sessionStillRunning` (Altfehler, 25b-Gegenprobe, #30) und `testGuidedWorkoutPauseButtonIsBelowProgressRing` (Gruppe E, #83). `testMeditationTabToolbarHasOnlySettings` grün, kein Teil-Ticket. Keine neue Rotmeldung. `test_explicitStop_endsSession`: 1x rot, in der Wiederholung grün; `BackgroundMeditationUITests.swift` ist unverändert (nicht in der Liste der geänderten Dateien), 25e kann ihn nicht verursachen. Bewertung: Umfeld-Flake, beobachten, kein Ticket, solange er nicht dauerhaft rot wird. Der Gesamtlauf stammt vom Stand vor der B1-Korrektur; B1 danach einzeln grün, die Änderung betrifft nur diesen einen Test.

Checkliste (aktualisiert): Punkte 1-3 AKZEPTIERT. AC-1 bis AC-13 AKZEPTIERT (AC-10 mit begründeter Abweichung, AC-5 mit Changelog-Klarstellung).

Befundstatus: B1 geschlossen, B2 geschlossen, B3 akzeptiert, B4 akzeptiert. Keine offenen Befunde.

VERDICT: VERIFIED

## Checkliste (Abschluss nach Runde 2, Formblock für qa_gate)

- [x] 1. HealthSheetHelper mit `dismissHealthSheetIfAny()` genau einmal definiert
  Code reference: LeanHealthTimerUITests/HealthSheetHelper.swift:8
- [x] 2. Privater Helfer in DayDetailHabitsUITests durch Aufruf ersetzt
  Code reference: LeanHealthTimerUITests/DayDetailHabitsUITests.swift:50
- [x] 3. Aufruf in allen fünf verbleibenden Cluster-A-Tests nach `app.launch()`
  Code reference: LeanHealthTimerUITests/LeanHealthTimerUITests.swift:1835
- [x] AC-1 `testNoAlcLevelButtonsHaveIdentifiers` grün, Kennungen generic_💧/✨/💥
- [x] AC-2 Test 2 samt Helfer entfernt, Ersatztest grün
- [x] AC-3 Test 4 entfernt, Teil-Ticket #99
- [x] AC-4 Inline-Knöpfe je Zeile über `generic_💧` gezählt
- [x] AC-5 Stufen in eigener Zeile per Frame (B1 geschlossen), Einzellauf grün
- [x] AC-6 Verlauf-Blatt öffnet nach Tipp auf Verlauf-Link (Titel geprüft)
- [x] AC-7 Alle Stufen im Erfolge-Tab, nur Helfer-Aufruf
- [x] AC-8 Tests 3, 6, 7 entfernt, Ersatztests grün
- [x] AC-9 Helfer einmal, DayDetail-Tests grün
- [x] AC-10 Beweislauf nach `simctl erase` grün (nur iPhone 17 Pro, Nachbarsimulator geschont)
- [x] AC-11 `Executed N tests` mit N ≥ 1 in Gesamt- und Einzellauf (B2 geschlossen)
- [x] AC-12 Diff gegen origin/main nur Testcode
- [x] AC-13 Gesamtlauf ohne neue Rotmeldung, Toolbar-Nebenfund grün

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:3227152613987b087dfc0f8637371c70c4e195967c995af092cabef78ebccb36  LeanHealthTimerUITests/DayDetailHabitsUITests.swift
- sha256:7f30db4e7d58761b6d979af4dc1ee83cbfdc93255f4892b20855abbadc93ef28  LeanHealthTimerUITests/HealthSheetHelper.swift
- sha256:45f76216b53633b2add967813ac3855d6b3b42ea29382def50bf74240af2e69e  LeanHealthTimerUITests/LeanHealthTimerUITests.swift

## Prüfbasis

- base: 49a0e027dd8ae9535479fe7dce196ae39f351b9c
- blob:00e95ba9245d1d8f379455da4366d13b0d3d076f  LeanHealthTimerUITests/DayDetailHabitsUITests.swift
- blob:6a51b8fe6955f2140f4be26047d5d8046f7051f6  LeanHealthTimerUITests/HealthSheetHelper.swift
- blob:b44e9f7cad869150e83829b218b09459597e71a8  LeanHealthTimerUITests/LeanHealthTimerUITests.swift
