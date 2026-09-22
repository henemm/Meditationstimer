---
entity_id: bug_21_uitest_erfolge_tab
type: bug
created: 2026-09-22
updated: 2026-09-22
status: implemented
---

# Bug #21 — UI-Test sucht deutschen Tab-Namen „Erfolge" in englischer App

## Approval

- [x] Approved

## Purpose

`LeanHealthTimerUITests.testAllFourTabsExist()` und weitere Tests suchen den vierten Tab über
`app.tabBars.buttons["Erfolge"]`. XCUITest matcht dabei ausschließlich den `identifier` — bei
fehlendem `.accessibilityIdentifier` füllt iOS diesen implizit mit dem sichtbaren Label. Die App
startet im Test mit `-AppleLanguages (en)`, der Tab zeigt dort „Achievements" (seit dem
Massen-Lokalisierungs-Fix f1b9a4a für Bug 38). Der deutsche String-Lookup läuft ins Leere, der Test
ist seit sieben Monaten unbemerkt rot. Der Fix stellt die Erfolge-Testzugriffe auf einen
positionsbasierten Helper um — ohne Produktcode-Änderung.

## Root Cause

Siehe `docs/artifacts/bug-21-uitest-erfolge-tab/analysis.md` (Checkpoint 1 bestätigt). Kurzfassung:

1. Vierter Tab ist `Label("Erfolge", …)` in `Meditationstimer iOS/ContentView.swift:91`, ohne
   `.accessibilityIdentifier`.
2. XCUITest füllt den `identifier` bei fehlendem Identifier implizit mit dem gerenderten Label →
   auf EN „Achievements", auf DE „Erfolge".
3. `tabBars.buttons["Erfolge"]` matcht laut Apple-Header nur den Identifier, nicht den sichtbaren
   Text → auf EN kein Treffer.
4. Der im Issue vorgeschlagene Accessibility-Identifier-Ansatz ist auf der iPhone-Tab-Bar
   nachweislich wirkungslos (Recherche: Kamil Buczel, iOS26-TabView-UITest-Identifiers-Artikel;
   Nemlig PR #7 bestätigt das Problem und zeigt einen ~100-LoC-UIKit-Workaround, der für diesen Bug
   zu schwer ist). Deshalb kein Produktcode-Eingriff.

## Affected Files

- `LeanHealthTimerUITests/LeanHealthTimerUITests.swift` — 7 Vorkommen von
  `tabBars.buttons["Erfolge"]` (Zeilen 108, 140, 860, 887, 907, 1213, 3080) auf einen
  positionsbasierten Helper umstellen; neue Hilfsfunktion in derselben Datei ergänzen
- `Scripts/run-uitests.sh` — `-parallel-testing-enabled NO` im `xcodebuild test`-Aufruf ergänzen
  (Zeile ~74–81), Voraussetzung, damit der Runner unter Xcode 27.0 nicht auf einem
  Simulator-Klon startet (Issue #23)

## Expected Behavior

- Input: UI-Test greift auf den vierten Tab in der Tab-Bar zu, unabhängig von der Sprache
  (`-AppleLanguages (en)` oder `(de)`)
- Output: Test findet den Tab über seine Position (Index 3), nicht über den Labeltext; der
  gefundene Button zeigt sprachabhängig „Achievements" (EN) bzw. „Erfolge" (DE)
- Side effects: keine — reine Testinfrastruktur, kein App-Verhalten ändert sich

## Fix Approach

1. In `LeanHealthTimerUITests/LeanHealthTimerUITests.swift` eine Hilfsfunktion ergänzen, die einen
   Tab über seinen Index in der Tab-Bar liefert, z. B.
   `func tab(_ index: Int, in app: XCUIApplication) -> XCUIElement`. Reihenfolge:
   0 = Meditation, 1 = Workout, 2 = Tracker, 3 = Erfolge.
2. Die Funktion prüft vor dem Zugriff, dass `app.tabBars.buttons.count == 4` ist, und bricht mit
   einer lesbaren `XCTFail`-Meldung ab, wenn nicht — Schutz gegen stille Fehltreffer bei künftiger
   Tab-Umsortierung.
3. Nur die 7 Erfolge-Stellen (Zeilen 108, 140, 860, 887, 907, 1213, 3080) auf `tab(3, in: app)`
   umstellen. Bestehende `XCTSkip`-Markierungen (Bug 36 u. a.) bleiben unverändert.
4. Die >90 Vorkommen für Meditation/Workout/Tracker bleiben unangetastet (Folge-Issue).
5. `Scripts/run-uitests.sh`: `-parallel-testing-enabled NO` im `xcodebuild test`-Aufruf ergänzen,
   damit der Runner startet (Voraussetzung für den Beweislauf dieses Bugs, siehe Issue #23).

**Out of Scope für dieses Ticket:** Migration der Meditation/Workout/Tracker-Testzugriffe;
Reaktivierung der per `XCTSkip` deaktivierten Tests; Accessibility-Identifier in der App.

## Acceptance Criteria

1. **AC1:** `testAllFourTabsExist` läuft grün bei Start mit `-AppleLanguages (en)`.
2. **AC2:** Derselbe positionsbasierte Zugriff funktioniert auch bei `-AppleLanguages (de)` —
   belegt z. B. durch `testGenericNoAlcTrackerAllLevelsDisplayInErfolge` (läuft auf DE) oder einen
   eigenen kleinen Test.
3. **AC3:** `testErfolgeTabHasCleanLayoutWithoutSheetNavigation` und `testErfolgeTabShowsContent`
   laufen grün.
4. **AC4:** Die Hilfsfunktion schlägt mit einer lesbaren Meldung fehl, wenn die Tab-Bar nicht genau
   vier Buttons enthält (kein stiller Fehltreffer).
5. **AC5:** Der über Index 3 gefundene Tab zeigt sprachabhängig das korrekte Label —
   „Achievements" bei EN, „Erfolge" bei DE — als Beweis, dass Position und Übersetzung getrennte
   Belange sind.
6. **AC6:** `./Scripts/run-uitests.sh testAllFourTabsExist` läuft unter Xcode 27.0 durch (Runner
   startet erfolgreich, Test wird ausgeführt, kein Simulator-Klon-Fehler).
7. **AC7:** Kein Produktcode (`*.swift` außerhalb `LeanHealthTimerUITests/`) wurde geändert.

## Test Plan

- [ ] UI Test: `testAllFourTabsExist` mit `-AppleLanguages (en)` → grün (AC1)
- [ ] UI Test: sprachunabhängiger Nachweis auf DE, z. B. via
      `testGenericNoAlcTrackerAllLevelsDisplayInErfolge` → grün (AC2)
- [ ] UI Test: `testErfolgeTabHasCleanLayoutWithoutSheetNavigation`,
      `testErfolgeTabShowsContent` → grün (AC3)
- [ ] Unit/UI Test: Hilfsfunktion mit manipulierter Tab-Anzahl (z. B. via Vorbedingung/Mock) liefert
      lesbaren Fehlschlag statt Crash oder falschem Treffer (AC4)
- [ ] UI Test: gefundener Tab-Text stimmt je Sprache mit „Achievements"/„Erfolge" überein (AC5)
- [ ] Skript-Lauf: `./Scripts/run-uitests.sh testAllFourTabsExist` beendet sich mit 0 Failures,
      Runner startet ohne Klon-Fehler (AC6)
- [ ] Diff-Review: `git diff --stat` zeigt ausschließlich Änderungen in
      `LeanHealthTimerUITests/LeanHealthTimerUITests.swift` und `Scripts/run-uitests.sh` (AC7)

## Blast Radius

| System | Schweregrad | Details |
|--------|-------------|---------|
| UI-Testsuite | GERING | Betrifft nur Testcode, kein App-Verhalten |
| Produktcode | KEIN | `ContentView.swift` und alle übrigen `*.swift`-Dateien bleiben unverändert |
| CI | KEIN | UI-Tests laufen nicht auf dem Runner (siehe `ci-simulator-entitlements.md`) |

## Scope-Schätzung

≤ 40 LoC (1 Hilfsfunktion + 7 Aufrufstellen in `LeanHealthTimerUITests.swift`, 1 Zeile in
`Scripts/run-uitests.sh`), 2 Dateien.

## Changelog

- 2026-09-22: Initial spec created (Bug #21)
