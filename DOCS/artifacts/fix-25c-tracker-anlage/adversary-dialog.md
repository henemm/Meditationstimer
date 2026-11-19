# Adversary-Protokoll fix-25c-tracker-anlage (2026-11-19)

## Checkliste
- [x] C1-Test: addTrackerButton statt "Add Tracker", prüft "Dankbarkeit". Beweis: Testdiff (addTrackerButton); Einzellauf testPresetTapCreatesVisibleTracker passed (44.0 s), TEST SUCCEEDED; in Suite erneut passed (26.2 s).
- [x] TrackerRow :88/:169 String(localized: String.LocalizationValue(tracker.name)); tracker.name und Vergleiche (:35) unverändert; keine #97-Stellen berührt. Beweis: git diff (nur diese 2 Zeilen).
- [x] makeModelContainer, uitest-disk-store (Application Support/uitest.store, create: true, Vorrang vor In-Memory, da vorzeitiges return), uitest-reset-store (store, -wal, -shm), alles in #if DEBUG; ohne Argumente wie bisher (ModelConfiguration(isStoredInMemoryOnly: inMemory)). Beweis: Meditationstimer_iOSApp.swift:40-68 (Diff); einziger produktiver ModelContainer-Aufbau (grep).
- [x] C2: erster Start enable-testing + uitest-disk-store + uitest-reset-store, Neustart nur enable-testing + uitest-disk-store. Beweis: Testdiff (baseArguments + reset); Einzellauf passed (56.0 s); Wiederholungslauf direkt danach passed (98.7 s, Reset greift, keine Reste); Suite passed (42.5 s).
- [x] AC-1: C1 grün (s. o.).
- [x] AC-2: C2 grün mit echtem Neustart gegen Dateispeicher. Gegenprobe (save() entfernen) von mir nicht wiederholt (read-only), siehe F001.
- [x] AC-3: Ohne Argumente kein uitest.store: Code nur hinter args.contains("uitest-disk-store") in #if DEBUG; nur enable-testing bleibt In-Memory. Release-Build (generic/platform=iOS Simulator, CODE_SIGNING_ALLOWED=NO): BUILD SUCCEEDED, keine Warnung in den zwei Dateien; schema wird in Release genutzt (Zeile 65).
- [x] AC-4: Konsolenausgabe des Skripts filtert "Executed N tests" weg (Adversary, F001); das vollständige Protokoll `/tmp/xcuitest_output.log` des Komplettlaufs zeigt `Executed 116 tests, with 19 tests skipped and 36 failures` mit den drei Zieltests als passed. Beweis: Nachtrag Orchestrator unten. Einzeltests liefen als Klasse/Methode.
- [x] AC-5: keine neue Rotmeldung (Tabelle unten).
- [x] AC-6: git diff --stat origin/main: CLAUDE.md und Scripts/run-uitests.sh (#74, eigener Commit 8a86e6a), DOCS/*, UI-Tests, die zwei Source-Dateien. Keine weitere Datei.
- [x] AC-7: testTrackerListShowsGermanPresetNames passed (48.8 s; Suite 32.6 s): "Stimmung" sichtbar, "Mood" nicht, Doomscrolling unverändert. Markdown: String(localized: String.LocalizationValue(String)) deutet Namen wörtlich, kein LocalizedStringKey, keine Markdown-Interpretation.

## Befunde (Schema adversary_dialog.py)
```json
[
  {"id": "F001", "status": "ERLEDIGT - kein Defekt (Runde 2: /tmp/xcuitest_output.log enthält Executed 116 tests)", "severity": "LOW", "category": "spec_violation",
   "description": "AC-4 verlangt 'Executed N tests' im Protokoll; Scripts/run-uitests.sh gibt diese Zeile nicht aus (nur Test Case passed, Test Suite passed, TEST SUCCEEDED). Gegenprobe (save() entfernen -> C2 rot) wurde von mir nicht wiederholt, nur als Developer-Artefakt vorhanden (gegenprobe-c2.txt).",
   "evidence": "Scratchpad c1.log/c2.log/c3.log: grep Executed ohne Treffer, Test Case passed vorhanden",
   "remediation": "AC-4 sinngemäß über Test-Case-Zeile belegen oder Skript um Executed-Zeile ergänzen (eigenes Ticket, Bezug #33)."}
]
```

## Regressionsvergleich (Komplettlauf: 12 rote Tests, je 6 Fehlversuche, 19 übersprungen, EXIT=1 wegen bekannter Rotfälle)
| Test | Basis 25b | jetzt |
|---|---|---|
| test_breathingExercise_backgroundForeground_sessionStillRunning | rot (bekannt) | rot |
| test_freeWorkout_backgroundForeground_sessionStillRunning | rot (bekannt) | rot |
| testGuidedWorkoutPauseButtonIsBelowProgressRing | rot (E) | rot |
| testLevelTrackerShowsInlineButtons | rot (A) | rot |
| testLevelTrackerShowsLargeIconsInSeparateRow | rot (A) | rot |
| testNoAlcAdvancedModeHasDatePicker | rot (A) | rot |
| testNoAlcButtonsShowEmojis | rot (A) | rot |
| testNoAlcCardShowsHistoryButton | rot (A) | rot |
| testNoAlcCardShowsStreakAndJokerInfo | rot (A) | rot |
| testNoAlcHistoryButtonOpensHistorySheet | rot (A) | rot |
| testNoAlcInfoButtonOpensLogSheetWithAdvancedOption | rot (A) | rot |
| testNoAlcLogSheetShowsCorrectTitle | rot (A) | rot |
| testPresetTapCreatesVisibleTracker | rot (C) | GRÜN |
| testTrackerCreationFromPresetPersistsAfterRestart | rot (C) | GRÜN |
| testTrackerListShowsGermanPresetNames | neu | GRÜN |

Neue Rotfälle gegenüber der Basis: keine.


## Nachtrag Orchestrator zu F001 (2026-11-19)

F001 ist kein Defekt: `Scripts/run-uitests.sh` schreibt das vollständige xcodebuild-Protokoll nach
`/tmp/xcuitest_output.log` und filtert nur die Konsolenausgabe (Zeile 86), daher fehlt `Executed` dort.
Im vollständigen Protokoll des Komplettlaufs steht `Executed 116 tests, with 19 tests skipped and 36 failures`
(36 Fehlversuche = 12 bekannte Rotfälle × 3 Iterationen, siehe Tabelle), N ≥ 1 ist damit belegt. AC-4 erfüllt.
Dass die Konsolenzeile fehlt, ist Teil der offenen Werkzeugtickets #33/#29, nicht dieser Runde.

## Nutzer-Durchlauf im Simulator (Orchestrator, 2026-11-19)

Scratch-Kopie des aktuellen Stands, iPhone 17 Pro / iOS 27.2, App frisch installiert, deutsch, `enable-testing`.
Health-Dialog abgelehnt, Tab Tracker geöffnet: Liste zeigt „NoAlc“ und „Stimmung“ (kein „Mood“) — `walk1-liste.png`.
„Tracker hinzufügen“ → Vorlage „Dankbarkeit“ → Liste zeigt neue Karte „Dankbarkeit“ — `walk2-nach-anlegen.png`.
Protokoll: `Executed 1 test, with 0 failures` (`testWalk25c`, nur in der Scratch-Kopie, nicht im Repo).

## Dialog

### Runde 1
**Adversary:** F001 (LOW): Skriptausgabe enthält keine Zeile `Executed N tests`, AC-4 so nicht belegbar; Gegenprobe save() entfernen von mir nicht wiederholt (read-only).
**Implementierer:** Skript schreibt das volle Protokoll nach /tmp/xcuitest_output.log (Zeile 86); Gegenprobe liegt in gegenprobe-c2.txt; Nutzer-Durchlauf im Simulator mit Screenshots.
**Verdict:** Vorläufig VERIFIED mit LOW-Befund F001, Nachprüfung in Runde 2.

### Runde 2
**Adversary:** Nachgeprüft. (1) `grep Executed /tmp/xcuitest_output.log | tail -2` liefert `Executed 116 tests, with 19 tests skipped and 36 failures (0 unexpected)`; Skript Zeile 86 `tee /tmp/xcuitest_output.log | grep -E ...` filtert nur die Konsole. 36 Fehlversuche = 12 bekannte Rotfälle x 3 Iterationen, passt zur Tabelle. walk1-liste.png zeigt NoAlc und "Stimmung" (kein "Mood"), walk2-nach-anlegen.png zusätzlich "Dankbarkeit". (2) gegenprobe-c2.txt enthält 6 Treffer auf `Doomscrolling tracker should persist after app restart` bei LeanHealthTimerUITests.swift:400 und zweimal `testTrackerCreationFromPresetPersistsAfterRestart` failed (39.4 s, 37.5 s); der Diff von AddTrackerSheet.swift ist leer (0 Zeilen), save() ist also wieder da.
**Implementierer:** Belege wie oben, keine Codeänderung nötig.
**Verdict:** F001 AKZEPTIERT (kein Defekt, AC-4 erfüllt). Gegenprobe AC-2 AKZEPTIERT (C2 wird ohne save() rot, Änderung zurückgenommen). Keine offenen Befunde.

## Code-Referenzen der bestätigten Punkte

- AC-1 / AC-7 (Test C1)
  Code reference: LeanHealthTimerUITests/LeanHealthTimerUITests.swift:293
- AC-2 (Test C2)
  Code reference: LeanHealthTimerUITests/LeanHealthTimerUITests.swift:334
- AC-2 (Gegenprobe, save() unverändert)
  Code reference: Meditationstimer iOS/Tracker/AddTrackerSheet.swift:109
- AC-3 (DEBUG-Schalter, Disk-Store)
  Code reference: Meditationstimer iOS/Meditationstimer_iOSApp.swift:44
- AC-7 (Anzeige übersetzt)
  Code reference: Meditationstimer iOS/Tracker/TrackerRow.swift:88
- AC-7 (Anzeige übersetzt, zweites Layout)
  Code reference: Meditationstimer iOS/Tracker/TrackerRow.swift:169
- AC-7 (Test deutsche Namen)
  Code reference: LeanHealthTimerUITests/LeanHealthTimerUITests.swift:405

VERDICT: VERIFIED
Begründung: Alle drei Zieltests grün (C2 auch im Folgelauf), Suite ohne neuen Rotfall (Executed 116, 36 Fehlversuche = 12 bekannte Rotfälle x 3), Release-Build ohne Warnung, Diff im Scope, Gegenprobe belegt, Nutzer-Durchlauf per Screenshot bestätigt; F001 erledigt.

## Geprüfte Dateien

- sha256:29aebc99b6d3ba8120ef0dff68ef038c8b89c0d03281bf47d18d62211a40b71c  LeanHealthTimerUITests/LeanHealthTimerUITests.swift
- sha256:e047d5b327a551c3546cdeb32336e70a27428383615b5656e82b7040522c3c6e  Meditationstimer iOS/Meditationstimer_iOSApp.swift
- sha256:2fbbcb3d69d299a6bd4a20bc15ae10284547cb379f2098a4ee2d860fcca567d1  Meditationstimer iOS/Tracker/AddTrackerSheet.swift
- sha256:dfbeaaa674c3c86b7612392c29e586f51943561b41855fc3a490ceb852ddac8c  Meditationstimer iOS/Tracker/TrackerRow.swift

## Prüfbasis

- base: 5a5ca62d8357212fd10fc623fdfd73ff38ac0dcc
- blob:48ac7677d3b2399f2ad881083065f9f6faa48f2b  LeanHealthTimerUITests/LeanHealthTimerUITests.swift
- blob:60156c3f251b90fa2fdc0bc98b7bbe7aac6daddd  Meditationstimer iOS/Meditationstimer_iOSApp.swift
- blob:54428538278d3e3051919ec0826ac9961cc8c5c8  Meditationstimer iOS/Tracker/AddTrackerSheet.swift
- blob:f46fc5e77716e09e566bca62b211d523f5b94184  Meditationstimer iOS/Tracker/TrackerRow.swift
