---
entity_id: fix-25e-noalc-karte
type: bugfix
created: 2026-11-19
updated: 2026-11-19
status: draft
workflow: fix-25e-noalc-karte
---

# Fix 25e: NoAlc-Karte und Stufen-Tracker — zehn rote UI-Tests ordnen (#25, Runde 25e, Cluster A)

## Approval

- [ ] Approved

## Purpose

Zehn UI-Tests aus Cluster A von #25 sind seit Februar rot. Fünf werden repariert und prüfen danach das heutige
Verhalten (Stufen-Knöpfe, Verlauf); fünf werden gestrichen, weil ihr Nutzen schon von grünen Tests
abgedeckt ist oder die geprüfte Ansicht absichtlich entfernt wurde. Es ist kein Produktfehler beteiligt, die App
bleibt unverändert. Zusätzlich bekommen die Tests einen gemeinsamen Helfer, der das Health-Berechtigungsblatt
wegtippt, damit sie nicht mehr vom Zustand des Simulators abhängen.

## Source

| Feld | Wert |
|------|------|
| Entity | `fix-25e-noalc-karte` |
| Spec-Datei | `DOCS/specs/bugfix/fix-25e-noalc-karte.md` |
| Kontext & Analyse | `DOCS/context/fix-25e-noalc-karte.md` |
| Übergeordnetes Ticket | #25 (Bestandsaufnahme rote UI-Tests), Cluster A |
| Vorige Runden | `DOCS/specs/bugfix/fix-25c-tracker-anlage.md`, `DOCS/specs/bugfix/fix-25b-eindeutige-abfragen.md` |
| Teilweise erledigt | #24 (Health-Berechtigungsblatt) |

## Root Cause

Reproduziert am 2026-11-19 (Stand `49a0e02`, iPhone 17 Pro, iOS 27.2, zehn `-only-testing`-Filter, ohne
`-test-iterations`): `Executed 10 tests, with 10 failures`. Zwei Schichten, unabhängig voneinander.

### Schicht 1 — Umgebung: Health-Berechtigungsblatt (#24)

Ist die HealthKit-Abfrage auf dem Simulator unbeantwortet, legt sich das Systemblatt „Health-Zugriff"
(`HKHealthPrivacyHostAuthorizationView`) über die App. Tab-Tipps gehen ins Leere, der Test sucht auf dem
Meditation-Tab. Betroffen: 7 von 10 Tests in diesem Lauf (1, 5, 6, 7, 8, 9, 10), bei beantworteter Abfrage keiner.
Tests 1–9 haben keine Behandlung dafür; Test 10 behandelt nur Springboard-Alerts. Bestehendes Muster:
`DayDetailHabitsUITests.swift:50-98` (`dismissPermissionAlertsIfAny`).

### Schicht 2 — Testschuld je Test

- **a) Absichtlich entfernte Ansicht (Tests 2, 3, 4, 6, 7, 8):** `c3e4e9d` (2026-02-02, „Remove Legacy NoAlc
  Tracker") hat die eigene NoAlc-Karte samt Info-Knopf, Joker-Anzeige (`noAlcStreak`/`noAlcJokers`), Verlaufsknopf
  (`noAlcHistoryButton`) und Quick-Log entfernt. NoAlc läuft seitdem über `TrackerRow.levelBasedLayout`. Das
  `NoAlcLogSheet` existiert noch als Code, ist aber unerreichbar: Aufrufer sind nur `OffenView` u. a., die seit `0c89531`
  nicht mehr eingebunden sind (Nachtrag, siehe Changelog).
- **b) Suche über das Emoji (Tests 1, 5, 9):** `TrackerRow.levelButtonLarge` setzt `accessibilityLabel(level.localizedLabel)`
  und `accessibilityIdentifier("generic_\(level.icon)")` (`TrackerRow.swift:131-154`). `app.buttons["💧"]` trifft nie.
- **c) Test 10:** prüft bereits `generic_…`, scheitert nur an Schicht 1.

Kein Produktfehler: Seit `c3e4e9d` ist keine Nutzerfunktion verloren (Joker im Erfolge-Tab, `CalendarView.swift:240-254`;
Verlauf über den Editor-Link, `TrackerEditorSheet.swift:378-385`; Eintragen mit Datum über `trackerDateButton`).

## Affected Files

- `LeanHealthTimerUITests/LeanHealthTimerUITests.swift` (MODIFY: 5 Tests gestrichen, 5 repariert oder umgezogen, Helfer-Aufrufe)
- `LeanHealthTimerUITests/HealthSheetHelper.swift` (CREATE: gemeinsamer Health-Blatt-Helfer)
- `LeanHealthTimerUITests/DayDetailHabitsUITests.swift` (MODIFY: privaten Helfer durch gemeinsamen ersetzen)

Der Ordner ist eine `PBXFileSystemSynchronizedRootGroup`, die Projektdatei bleibt unverändert. App-Code wird nicht
geändert.

## Expected Behavior

### Entscheidung je Test

| # | Test | Maßnahme | Begründung |
|---|------|----------|------------|
| 1 | `testNoAlcButtonsShowEmojis` | reparieren, umbenennen in `testNoAlcLevelButtonsHaveIdentifiers` | Kennungen `generic_💧/✨/💥` statt Emoji-Label |
| 2 | `testNoAlcInfoButtonOpensLogSheetWithAdvancedOption` | streichen (Nachtrag) | `NoAlcLogSheet` im Produkt unerreichbar, siehe Changelog |
| 3 | `testNoAlcAdvancedModeHasDatePicker` | streichen | doppelt zu `testDatePickerButtonOpensLevelSelectionViewWithDatePicker` (25b) |
| 4 | `testNoAlcLogSheetShowsCorrectTitle` | streichen (Nachtrag) | `NoAlcLogSheet` im Produkt unerreichbar, siehe Changelog |
| 5 | `testLevelTrackerShowsInlineButtons` | reparieren | Zählung über `generic_💧` |
| 6 | `testNoAlcCardShowsStreakAndJokerInfo` | streichen | Serie: `testLevelTrackerShowsStreakInfo`; Joker-Zeile auf der Zeile bewusst entfernt |
| 7 | `testNoAlcCardShowsHistoryButton` | streichen | doppelt zu `testEditorSheetShowsHistoryLink` |
| 8 | `testNoAlcHistoryButtonOpensHistorySheet` | umziehen | Editor → Verlauf-Link antippen → Verlauf offen (alt prüfte nur Existenz) |
| 9 | `testLevelTrackerShowsLargeIconsInSeparateRow` | reparieren | `generic_😢` statt Label |
| 10 | `testGenericNoAlcTrackerAllLevelsDisplayInErfolge` | nur Helfer | nutzt schon `generic_…` |

### Gemeinsamer Health-Blatt-Helfer

- Neue Datei `HealthSheetHelper.swift` mit `extension XCUIApplication { func dismissHealthSheetIfAny() }`.
- Code aus `DayDetailHabitsUITests.swift:50-98` verschoben (scrollt das Blatt, tippt „Nicht erlauben"); dort bleibt
  nur der Aufruf des gemeinsamen Helfers.
- Aufruf in jedem der fünf verbleibenden Tests nach `app.launch()`.

### Technische Hinweise

`NoAlcLogSheet.ConsumptionButton` (`NoAlcLogSheet.swift:246-271`) hat kein eigenes Label: Label = Emoji + Text, Suche per
`label CONTAINS`. Der Navigationstitel im erweiterten Modus lautet „Log Drinks" (`:131`).

## Out of Scope

- UI-Test für die Joker-Anzeige im Erfolge-Tab: bewusste Testlücke (Logik durch `NoAlcStreakTests` und
  `StreakManagerJokerTests` abgedeckt), nicht in dieser Runde.
- Dauerlösung für #24 (App-Startargument, das die Health-Abfrage im Test unterdrückt): Appcode-Änderung, bleibt in #24.
- Nebenfund `testMeditationTabToolbarHasOnlySettings`: erwartet nur das Zahnrad; das entspricht der App
  (`MeditationTab.swift`). Wird im Abschluss-Regressionslauf beobachtet; ist er rot, entsteht ein eigenes Teil-Ticket unter #25.
- Entfernen des toten `NoAlcLogSheet` und der nicht eingebundenen Ansichten `OffenView`/`AtemView`/`WorkoutsView`/
  `WorkoutProgramsView`: App-Code, eigenes Teil-Ticket.
- Joker-Anzeige auf der Tracker-Zeile wiederherstellen: Produktfrage, kein Testthema.

## Verworfene Alternativen

- **Health-Blatt bis #24 liegen lassen:** Sieben Tests blieben vom Simulatorzustand abhängig, nicht belastbar grün.
- **Simulator-Berechtigung per `simctl privacy`:** HealthKit gehört nicht zu den dort steuerbaren Diensten.
- **App-Startargument gegen die Health-Abfrage:** Appcode-Änderung, gehört zur Dauerlösung #24.
- **Gestrichene Tests auf den heutigen Ort umziehen:** erzeugte Doppelprüfungen zu den grünen Tests aus 25b,
  `testEditorSheetShowsHistoryLink` und `testLevelTrackerShowsStreakInfo`.

## Acceptance Criteria

- **AC-1:** Given die App läuft mit `enable-testing` / When `testNoAlcLevelButtonsHaveIdentifiers` (bisher
  `testNoAlcButtonsShowEmojis`) als `Klasse/Methode` läuft / Then ist er grün und beweist, dass die drei NoAlc-Stufen-Knöpfe
  `generic_💧`, `generic_✨`, `generic_💥` in der Tracker-Liste existieren.
- **AC-2 (Nachtrag):** Given die Datei / When sie geprüft wird / Then ist `testNoAlcInfoButtonOpensLogSheetWithAdvancedOption`
  samt zugehörigem privatem Helfer entfernt; das Eintragen mit Datum bleibt durch
  `testDatePickerButtonOpensLevelSelectionViewWithDatePicker` abgedeckt und grün.
- **AC-3 (Nachtrag):** Given die Datei / When sie geprüft wird / Then ist `testNoAlcLogSheetShowsCorrectTitle` entfernt,
  und die Entfernung des unerreichbaren `NoAlcLogSheet` (App-Code) ist als eigenes Teil-Ticket unter #25 erfasst.
- **AC-4:** Given ein zweiter NoAlc-Tracker wird angelegt / When `testLevelTrackerShowsInlineButtons` läuft / Then ist
  er grün und beweist, dass die Stufen-Knöpfe je Zeile inline erscheinen (Zählung der `generic_💧`-Knöpfe über die
  Kennung statt über das Emoji-Label).
- **AC-5:** Given die Tracker-Liste mit Mood-Tracker / When `testLevelTrackerShowsLargeIconsInSeparateRow` läuft /
  Then ist er grün und beweist, dass die großen Stufen-Icons (`generic_😢` …) in eigener Zeile über der
  `trackerDateButton`-Zeile stehen.
- **AC-6:** Given Tracker mit Verlauf / When `testNoAlcHistoryButtonOpensHistorySheet` (umgezogen) den
  Bearbeiten-Dialog öffnet und den Verlauf-Link antippt / Then ist er grün und beweist, dass das Verlauf-Blatt
  tatsächlich öffnet (nicht nur, dass der Knopf existiert).
- **AC-7:** Given NoAlc-Tracker mit allen drei Stufen / When `testGenericNoAlcTrackerAllLevelsDisplayInErfolge` läuft
  / Then ist er grün und beweist, dass alle Stufen im Erfolge-Tab erscheinen; Änderung nur der Helfer-Aufruf.
- **AC-8:** Given die Tests 3, 6 und 7 / When die Datei geprüft wird / Then sind `testNoAlcAdvancedModeHasDatePicker`,
  `testNoAlcCardShowsStreakAndJokerInfo` und `testNoAlcCardShowsHistoryButton` entfernt; der Nutzen bleibt durch
  `testDatePickerButtonOpensLevelSelectionViewWithDatePicker`, `testLevelTrackerShowsStreakInfo` bzw.
  `testEditorSheetShowsHistoryLink` abgedeckt, und diese drei Tests bleiben grün.
- **AC-9:** Given der gemeinsame Helfer / When `HealthSheetHelper.swift` und `DayDetailHabitsUITests.swift`
  geprüft werden / Then existiert `XCUIApplication.dismissHealthSheetIfAny()` genau einmal, der private Helfer in
  `DayDetailHabitsUITests` ist durch den Aufruf ersetzt, alle fünf verbleibenden Cluster-A-Tests rufen ihn nach `app.launch()`
  auf, und die vier DayDetail-Tests bleiben grün.
- **AC-10 (Beweislauf Schicht 1):** Given ein frisch zurückgesetzter Simulator (Health-Abfrage unbeantwortet), hergestellt
  mit `xcrun simctl shutdown all` und `xcrun simctl erase <UDID>` für „iPhone 17 Pro" / iOS 27.2 (UDID per
  `xcrun simctl list devices available "iOS 27.2"`, gleicher Weg wie `run-uitests.sh`) /
  When die fünf verbleibenden Tests plus DayDetail-Tests als `Klasse/Methode` laufen, ohne `-test-iterations` /
  Then sind alle grün, d. h. ohne beantwortete Health-Abfrage und ohne Wiederholung.
- **AC-11:** Given ein Testlauf / When er ausgewertet wird / Then zählt er nur als bestanden, wenn das Protokoll
  `Executed N tests` mit N ≥ 1 zeigt; Einzeltests werden immer als `Klasse/Methode` aufgerufen (kein Nulllauf, #33).
- **AC-12:** Given die fertige Änderung / When `git diff` gegen `main` geprüft wird / Then zeigt er nur die drei
  Affected Files (plus Spec/Doku dieses Workflows); kein App-Code.
- **AC-13:** Given der Gesamtlauf der UI-Suite / When er mit dem Stand vorher verglichen wird / Then gibt es keine
  neue Rotmeldung; `testMeditationTabToolbarHasOnlySettings` wird dabei beobachtet und bei Rot als eigenes
  Teil-Ticket unter #25 erfasst.

## Test Plan

Hinweis: Läufe über `Scripts/run-uitests.sh` auf iPhone 17 Pro / iOS 27.2, Einzeltests immer als `Klasse/Methode`.
Nur Simulator, keine Geräte des PO.

- [ ] RED: Zehn Tests vor der Änderung ausführen, erwartet `Executed 10 tests, with 10 failures` (am 2026-11-19 belegt,
      Wiederholung im Workflow).
- [ ] GREEN je Teil in dieser Reihenfolge: Helfer auslagern + DayDetail-Lauf → Test 10 und Tests 1, 5, 9 →
      Streichungen 2, 3, 4, 6, 7 → Umzug 8; jeweils `Executed N tests` mit N ≥ 1.
- [ ] Abschluss ohne `-test-iterations`: fünf verbleibende Tests plus DayDetail-Tests.
- [ ] Beweislauf mit frisch zurückgesetztem Simulator (`simctl shutdown all` + `simctl erase <UDID>`, Health-Abfrage
      unbeantwortet), danach erneut Abschlusslauf.
- [ ] Regression: Gesamtlauf der UI-Suite (langer Lauf: nohup + Monitor, nie zwei Simulatoren), Ergebnisliste mit
      Stand vorher vergleichen; `testMeditationTabToolbarHasOnlySettings` beobachten.
- [ ] Diff-Prüfung: nur die drei Affected Files geändert, kein App-Code.
- [ ] Unit-Tests: nicht betroffen (nur UI-Testcode).

## Risiken

- Der Helfer verlängert Läufe um einige Sekunden.
- DayDetail-Tests müssen nach dem Verschieben des Helfers grün bleiben.
- Sieben Tests bleiben ohne Helfer vom Simulatorzustand abhängig; deshalb der Beweislauf mit zurückgesetztem Simulator.

## Scope

- Dateien: 3 (nur Testcode, App unverändert)
- LoC: gemessen nach Umsetzung ca. +146 hinzugefügt / −282 entfernt (fünf Tests gestrichen, ein Test neu aufgebaut, Helfer verschoben).
  Die Grenze von 250 Zeilen zählt im Workflow nur hinzugefügte Testzeilen (Edit-Gate, Issue #94 des Frameworks);
  mit ca. +146 bleibt die Runde darunter. Gemessen und im Prüfbericht ausgewiesen wird der tatsächliche Wert.
- Risiko: niedrig

## Dependencies

| Abhängigkeit | Art | Bedeutung |
|--------------|-----|-----------|
| #24 | Ticket | wird teilweise erledigt (Cluster A + DayDetail); Helfer dort referenzieren |
| 25b / 25c | Muster | Testschuld im Test beheben, Kennungen statt Labels, App unverändert |
| `Meditationstimer iOS/Tracker/TrackerRow.swift:131-154` | Upstream | Kennungen `generic_…`, `trackerStreak`, `trackerDateButton`, unverändert |
| `Meditationstimer iOS/Tabs/MeditationTab.swift` | Upstream | Toolbar nur mit Zahnrad, unverändert |
| `LeanHealthTimerUITests/DayDetailHabitsUITests.swift:50-98` | Quelle | Vorlage des Helfers |

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine

Keine neue ADR nötig: reine Testreparatur nach dem Muster aus 25b/25c.

## Definition of Done

- [ ] Fünf verbleibende Tests laufen einzeln als `Klasse/Methode` grün, je `Executed N tests` mit N ≥ 1
- [ ] Fünf Tests gestrichen, Ersatztests bleiben grün
- [ ] Beweislauf mit zurückgesetztem Simulator und ohne `-test-iterations` grün
- [ ] DayDetail-Tests nach dem Verschieben des Helfers grün
- [ ] Gesamtlauf der UI-Suite ohne neue Rotmeldung; Nebenfund beobachtet und ggf. als Ticket erfasst
- [ ] Diff enthält nur die drei Affected Files (plus Workflow-Doku)
- [ ] #25 mit dem Ergebnis der Runde 25e kommentiert, #24 auf den Helfer verwiesen

## Changelog

- 2026-11-19: Initial spec created
- 2026-11-19: Nach Spec-Prüfung: Testname AC-1 festgelegt, AC-3 akzeptiert beide Titel, Reset-Weg für AC-10, LoC-Schätzung korrigiert
- 2026-11-19 (Nachtrag Umsetzung): Annahme „Tropfen-Knopf in der Toolbar" war falsch. Der Meditation-Tab ist
  `MeditationTab.swift`, seine Toolbar zeigt nur `gearshape` (Accessibility-Baum im Fehlerlauf). `OffenView`, `AtemView`,
  `WorkoutsView`, `WorkoutProgramsView` sind die einzigen Aufrufer von `NoAlcLogSheet()` und werden seit `0c89531`
  (Tab-Navigation) nirgends mehr eingebunden, nur noch in `#Preview`. Das Blatt ist toter Code. Sein Inhalt
  („Advanced" = Datum + drei Stufen) ist vollständig über `trackerDateButton` erreichbar, kein Nutzerverlust.
  Tests 2 und 4 werden deshalb gestrichen statt umgezogen; AC-2/AC-3 angepasst. Der Nebenfund
  `testMeditationTabToolbarHasOnlySettings` entspricht damit der App.
- 2026-11-19 (Adversary B1): AC-5 nannte die Stufen-Zeile „über" der Datumszeile. `TrackerRow.levelBasedLayout`
  ordnet Kopfzeile (Name, `trackerDateButton`, Bearbeiten) als Row 1 und die Stufen-Knöpfe als Row 2 darunter an
  (`TrackerRow.swift:103-121`). Kern von AC-5 ist „eigene Zeile", die Richtung „über" ist ein Schreibfehler der Spec;
  der AC-Wortlaut bleibt wegen Spec-Freeze stehen, maßgeblich ist das Layout der App (Stufen-Zeile unter der Kopfzeile).
  Der Test prüft die Position künftig per Frame (Oberkante `generic_😢` und `generic_😊` ≥ Unterkante des nächstgelegenen
  `trackerDateButton` darüber) statt nur Existenz mit `||`.
- 2026-11-19 (Adversary B2): Läufe mit parallelen Simulator-Klonen drucken unter Xcode 27 kein `Executed N tests`;
  dort gilt als Nachweis: je Filter eine Zeile `Test case '…' passed`, keine `failed`-Zeile, Anzahl = Anzahl Filter.
