# Context: fix-25e-noalc-karte (#25, Runde 25e — Cluster A)

## Request Summary
Die zehn UI-Tests aus Cluster A von #25 (NoAlc-Karte / Stufen-Tracker) sind seit Februar rot. Sie sollen grün
werden und dabei das heutige Verhalten prüfen; wo die App wirklich etwas verloren hat, wird das behoben oder als
eigener Fehler erfasst.

## Reproduktion (2026-11-19, iPhone 17 Pro, iOS 27.2, Stand 49a0e02)
`xcodebuild test` mit zehn `-only-testing`-Filtern, ohne Wiederholung (Skript-Kopie im Scratchpad, gleicher
Simulator und gleiche Einstellungen wie `run-uitests.sh`, nur ohne `-test-iterations 3`).
Ergebnis: `Executed 10 tests, with 10 failures`.

| # | Test | Stelle | Zustand der App beim Scheitern |
|---|------|--------|-------------------------------|
| 1 | `testNoAlcButtonsShowEmojis` | `:1851` 💧 fehlt | Health-Blatt über Meditation-Tab |
| 2 | `testNoAlcInfoButtonOpensLogSheetWithAdvancedOption` | `:1957` info.circle fehlt | Tracker-Tab (NoAlc, Mood sichtbar) |
| 3 | `testNoAlcAdvancedModeHasDatePicker` | `:2011` info.circle mehrfach | Meditation-Tab (dort viele info.circle) |
| 4 | `testNoAlcLogSheetShowsCorrectTitle` | `:2064` info.circle mehrfach | wie 3 |
| 5 | `testLevelTrackerShowsInlineButtons` | `:2362` addTrackerButton fehlt | Health-Blatt über Meditation-Tab |
| 6 | `testNoAlcCardShowsStreakAndJokerInfo` | `:2443` `noAlcStreak` fehlt | Health-Blatt |
| 7 | `testNoAlcCardShowsHistoryButton` | `:2506` `noAlcHistoryButton` fehlt | Health-Blatt |
| 8 | `testNoAlcHistoryButtonOpensHistorySheet` | `:2524` | Health-Blatt |
| 9 | `testLevelTrackerShowsLargeIconsInSeparateRow` | `:2932` `trackerDateButton` fehlt | Health-Blatt |
| 10 | `testGenericNoAlcTrackerAllLevelsDisplayInErfolge` | `:3208` `generic_✨` fehlt | Health-Blatt nach Erfolge-Tab (#24) |

Belege: UI-Hierarchien aus dem xcresult (Scratchpad, `att/manifest.json`). Test 10 war am 2026-11-17 im
Regressionslauf von 25b grün — dort war die Health-Abfrage auf dem Simulator schon beantwortet.

## Ursachen (zwei Schichten)

### Schicht 1 — Umgebung: Health-Berechtigungsblatt (#24)
Ist die HealthKit-Abfrage auf dem Simulator noch unbeantwortet, legt sich das Systemblatt „Health-Zugriff"
(`HKHealthPrivacyHostAuthorizationView`) über die App. Tab-Tipps gehen ins Leere, der Test sucht auf dem
Meditation-Tab. Betrifft 7 von 10 Tests in diesem Lauf, bei beantworteter Abfrage keinen. Die Tests 1–9 haben
keinerlei Behandlung dafür; Test 10 behandelt nur Springboard-Alerts, nicht das In-App-Blatt.
Bestehendes Muster: `DayDetailHabitsUITests.swift:50-98` (`dismissPermissionAlertsIfAny`, scrollt das Blatt
und tippt „Nicht erlauben"). Eigenes Ticket #24 (offen).

### Schicht 2 — Testschuld je Test (unabhängig von Schicht 1)
**a) Prüft eine absichtlich entfernte Ansicht (Tests 2, 3, 4, 6, 7, 8).** `c3e4e9d` (2026-02-02, „Remove Legacy
NoAlc Tracker - only Generic NoAlc remains") hat die eigene NoAlc-Karte samt Info-Knopf, Joker-Anzeige
(`noAlcStreak`/`noAlcJokers`), Verlaufsknopf (`noAlcHistoryButton`) und Quick-Log entfernt. NoAlc läuft seitdem
über `TrackerRow.levelBasedLayout` wie jede Stufen-Gewohnheit. Was die Tests inhaltlich wollten, gibt es heute
an anderer Stelle:
- Serie 🔥: `TrackerRow.swift:300-311`, Kennung `trackerStreak` (geprüft von `testLevelTrackerShowsStreakInfo`).
  Joker-Anzeige auf der Zeile: gibt es nicht mehr.
- Verlauf: über den Bearbeiten-Dialog (`TrackerEditorSheet.swift:385`), geprüft von `testEditorSheetShowsHistoryLink`.
- Eintragen mit Datum („Erweitert" + Datumsauswahl): `LevelSelectionView.swift:83-121` über `trackerDateButton`
  (geprüft von den drei 25b-Tests).
- `NoAlcLogSheet` (Titel „Yesterday Evening"/„Today", „Advanced", DatePicker) lebt weiter, erreichbar über das
  Tropfen-Symbol (`drop.fill`) in der Toolbar von Meditation/Atem/Workout (`OffenView.swift:400,417`).

**b) Sucht Stufen-Knöpfe über das Emoji (Tests 1, 5, 9).** `TrackerRow.levelButtonLarge` setzt
`accessibilityLabel(level.localizedLabel)` und `accessibilityIdentifier("generic_\(level.icon)")`
(`TrackerRow.swift:131-154`). Der sichtbare Emoji-Text ist damit kein Suchschlüssel mehr;
`app.buttons["💧"]` / `["😢"]` trifft nie. Kennung `generic_…` seit `c02836f` (2026-02-01).
Test 5 legt zusätzlich einen zweiten NoAlc-Tracker an und zählt „💧"-Knöpfe — ebenfalls über Emoji.

**c) Test 10:** prüft bereits `generic_…`; scheitert nur an Schicht 1.

## Related Files
| File | Relevance |
|------|-----------|
| `LeanHealthTimerUITests/LeanHealthTimerUITests.swift:1832-2080, 2342-2530, 2904-2950, 3081-3260` | Die zehn Tests |
| `LeanHealthTimerUITests/DayDetailHabitsUITests.swift:50-98` | Vorbild für das Wegtippen des Health-Blatts |
| `Meditationstimer iOS/Tracker/TrackerRow.swift:82-154, 296-363` | Stufen-Layout, Kennungen `generic_…`, `trackerStreak`, `trackerDateButton` |
| `Meditationstimer iOS/NoAlcLogSheet.swift` | Eintrage-Blatt (Titel, Advanced, DatePicker) |
| `Meditationstimer iOS/Tabs/OffenView.swift:400-418` | Zugang zum NoAlcLogSheet über `drop.fill` |
| `Services/TrackerModels.swift:160-175` | Stufen-Icons NoAlc (💧✨💥) und Mood (😢…😊) |

## Existing Patterns
- 25b/25c: Testschuld im Test beheben, App unverändert, wenn sie richtig arbeitet.
- Tab-Zugriff positionsbasiert über `tab(_:in:)` (`LeanHealthTimerUITests.swift:9-16`); 54 Stellen nutzen noch
  `tabBars.buttons["Tracker"]` (trifft per Label, funktioniert in DE und EN).
- Sprachunabhängige Kennungen statt Labels (`addTrackerButton`, `generic_…`).

## Dependencies
- Upstream: `enable-testing` legt Mood und NoAlc als Standard-Tracker an (In-Memory-Speicher).
- Downstream: keine — nur Testcode betroffen, solange Schicht 2 reine Testschuld bleibt.

## Recherche
- Apple-Doku `XCUIElementQuery` subscript: Treffer über Kennung (developer.apple.com/documentation/xcuiautomation/xcuielementquery).
- Use Your Loaf „UI Testing Quick Guide" und Apple-Forum thread/10428: Ein gesetztes `accessibilityLabel`
  ersetzt den sichtbaren Text als Label; Kennungen sind der sprachunabhängige Weg.

## Risks & Considerations
- Ohne Schicht 1 bleiben bis zu 7 Tests vom Zustand des Simulators abhängig — grün nur, wenn die Abfrage schon
  beantwortet ist. Entweder in dieser Runde ein gemeinsamer Helfer (Muster DayDetailHabitsUITests) oder
  bewusst #24 überlassen; das entscheidet die Analyse.
- Entfernte Ansicht: Streichen vs. Umziehen auf den heutigen Ort. Umziehen darf keine Doppelprüfung zu
  bestehenden grünen Tests erzeugen (25b, `testEditorSheetShowsHistoryLink`, `testLevelTrackerShowsStreakInfo`).
- Kein Produktfehler gefunden; die Joker-Anzeige auf der Zeile fehlt seit der bewussten Entfernung im Februar —
  ob sie fehlen soll, ist eine Produktfrage, keine Testfrage.
- Scoping: nur `LeanHealthTimerUITests.swift` (+ evtl. Helfer); Zeilen werden beim Streichen negativ.

## Analysis

### Type
Bug (Testschuld + Umgebung) — kein Produktfehler. Unabhängig bestätigt (Bug-Intake 2026-11-19): seit `c3e4e9d`
ist keine Nutzerfunktion verloren. NoAlc-Joker lebt im Erfolge-Tab (`CalendarView.swift:240-254`), Verlauf über
den Editor-Link (`TrackerEditorSheet.swift:378-385`), Eintragen mit Datum über `trackerDateButton` und über das
Tropfen-Blatt (`OffenView.swift:400`, `AtemView.swift:291`, `WorkoutsView.swift:707`, `WorkoutProgramsView.swift:527`).

### Entscheidung je Test
| # | Test | Maßnahme | Begründung |
|---|------|----------|------------|
| 1 | `testNoAlcButtonsShowEmojis` | Kennungen `generic_💧/✨/💥` statt Emoji-Label, umbenennen | Label ist „Steady" usw. |
| 2 | `testNoAlcInfoButtonOpensLogSheetWithAdvancedOption` | Einstieg Tropfen-Knopf (Meditation-Tab), „Advanced" prüfen | Nutzen sonst ungeprüft |
| 3 | `testNoAlcAdvancedModeHasDatePicker` | streichen | doppelt zu `testDatePickerButtonOpensLevelSelectionViewWithDatePicker` |
| 4 | `testNoAlcLogSheetShowsCorrectTitle` | Einstieg Tropfen-Knopf, Titel „Yesterday Evening"/„Today" | Titel sonst ungeprüft |
| 5 | `testLevelTrackerShowsInlineButtons` | Zählung über `generic_💧` | Emoji-Label trifft nie |
| 6 | `testNoAlcCardShowsStreakAndJokerInfo` | streichen | Serie: `testLevelTrackerShowsStreakInfo`; Joker-Zeile bewusst entfernt |
| 7 | `testNoAlcCardShowsHistoryButton` | streichen | doppelt zu `testEditorSheetShowsHistoryLink` |
| 8 | `testNoAlcHistoryButtonOpensHistorySheet` | umziehen: Editor → Verlauf-Link antippen → Verlauf offen | 2539 prüft nur Existenz |
| 9 | `testLevelTrackerShowsLargeIconsInSeparateRow` | `generic_😢` statt Label ab ~2935 | Emoji-Label |
| 10 | `testGenericNoAlcTrackerAllLevelsDisplayInErfolge` | nur Health-Helfer | nutzt schon `generic_…` |

Health-Blatt (Schicht 1): gemeinsamer Helfer als `XCUIApplication`-Extension `dismissHealthSheetIfAny()` in neuer
Datei `LeanHealthTimerUITests/HealthSheetHelper.swift` (Code aus `DayDetailHabitsUITests.swift:50-98` verschoben,
dort ein Aufruf). Ordner ist `PBXFileSystemSynchronizedRootGroup` → keine Projektdatei-Änderung. In allen zehn
(bzw. sieben verbleibenden) Tests nach `app.launch()` aufrufen.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LeanHealthTimerUITests/LeanHealthTimerUITests.swift` | MODIFY | 3 Tests gestrichen, 7 repariert/umgezogen, Helfer-Aufrufe |
| `LeanHealthTimerUITests/HealthSheetHelper.swift` | CREATE | gemeinsamer Health-Blatt-Helfer |
| `LeanHealthTimerUITests/DayDetailHabitsUITests.swift` | MODIFY | privaten Helfer durch gemeinsamen ersetzen |

### Scope Assessment
- Files: 3 (nur Testcode, App unverändert)
- Estimated LoC: ca. +110 / −170
- Risk Level: LOW — nur Tests; Risiko: Helfer verlängert Läufe um einige Sekunden, DayDetail-Tests müssen nach dem Verschieben grün bleiben.

### Technical Approach
Reihenfolge: Helfer auslagern + DayDetail-Lauf → Test 10 und Kennungs-Tests (1, 5, 9) → Streichungen (3, 6, 7) →
Umzug 8 → Umzüge 2 und 4 auf den Tropfen-Knopf. Abschluss: alle sieben verbleibenden plus DayDetail ohne
`-test-iterations`, jeweils `Executed N tests` mit N ≥ 1; zusätzlich einmal mit frisch zurückgesetztem Simulator
(Health-Abfrage unbeantwortet), damit Schicht 1 wirklich bewiesen ist.

`NoAlcLogSheet.ConsumptionButton` (`NoAlcLogSheet.swift:246-271`) hat kein eigenes Label: Label = Emoji + Text,
Suche per `label CONTAINS`. Navigationstitel „Log Drinks" (`:131`) im erweiterten Modus.

### Alternativen (verworfen)
- (b) Health-Blatt bis #24 liegen lassen: 7 Tests blieben vom Simulatorzustand abhängig → nicht belastbar grün.
- Simulator-Berechtigung per `simctl privacy`: HealthKit gehört nicht zu den dort steuerbaren Diensten.
- App-Startargument, das die Health-Abfrage im Test unterdrückt: Appcode-Änderung, gehört zu #24 (Dauerlösung).

### Dependencies
#24 wird dadurch nur teilweise erledigt (Cluster A + DayDetail); Helfer in #24 referenzieren.

### Open Questions
- keine PO-Frage. Joker-Anzeige im Erfolge-Tab hat keinen UI-Test (Logik durch `NoAlcStreakTests`,
  `StreakManagerJokerTests` abgedeckt) — bewusste Testlücke, nicht in dieser Runde.
- Nebenfund außerhalb Cluster A: `testMeditationTabToolbarHasOnlySettings` (`:1404-1429`) erwartet keinen
  Tropfen-/Kalender-Knopf, `OffenView.swift:400-401` zeigt beide. Im Abschluss-Regressionslauf prüfen; ist er rot,
  eigenes Teil-Ticket unter #25.
