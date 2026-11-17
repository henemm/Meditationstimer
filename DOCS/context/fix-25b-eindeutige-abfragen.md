# Context: fix-25b-eindeutige-abfragen (#25, Runde 25b)

## Request Summary
Aus der Bestandsaufnahme #25 die Gruppen B und E: vier UI-Tests scheitern, weil eine Element-Abfrage
mehrere Treffer liefert (`trackerDateButton` dreimal, `info.circle` einmal). Ziel: Die vier Tests
treffen genau das gemeinte Element und laufen grün. Gruppen A (NoAlc/Level, 10 Tests) und C
(Tracker aus Vorlage, 2 Tests) folgen in eigenen Runden unter #25.

## Betroffene Tests (`LeanHealthTimerUITests/LeanHealthTimerUITests.swift`)
| Test | Zeilen | Abfrage | Prüft |
|------|--------|---------|-------|
| `testDatePickerButtonOpensLevelSelectionViewWithDatePicker` | 2746–2794 | `app.buttons["trackerDateButton"]` (:2765) | Tippen öffnet LevelSelectionView mit Datumswahl (Mood-Tracker laut Kommentar) |
| `testDatePickerSheetCloseDoesNotShowCompactSheet` | 2796–~2857 | dto. (:2815) | Schließen des Blatts zeigt kein Kompakt-Blatt |
| `testLevelSelectionViewShowsAdvancedButton` | 2964–~3034 | dto. (:2991) | prüft trotz Name nur den DatePicker |
| `testGuidedWorkoutPauseButtonIsBelowProgressRing` | 2218–~2294 | `app.buttons["info.circle"]` (:2276) | Pause-Knopf liegt unter dem Info-Knopf des Rings (Schutz für Fix #1, `366dfbb`) |

Weitere `trackerDateButton`-Abfragen ohne Eingrenzung: :2730 (`testLevelTrackerShowsDatePickerButton`),
:2886 (`testLevelTrackerShowsLargeIconsInSeparateRow`, Gruppe A).

## App-Seite
- `Meditationstimer iOS/Tracker/TrackerRow.swift:103` setzt `accessibilityIdentifier("trackerDateButton")`
  in `levelBasedLayout`; `TrackerTab.swift:80–81` rendert `ForEach(allTrackers) { TrackerRow }` →
  ein Knopf je stufenbasiertem Tracker, ohne Unterscheidung. Gleiches Muster bei `trackerEditButton`
  (:113, :189) und `trackerStreak` (:311).
- Vorhandenes Muster für Kennungen je Zeile: `dayDetail.habitRow.\(trackerID.uuidString)`
  (DayDetailSheet.swift:485), `calendar.day.\(…)` (CalendarView.swift:572), `generic_\(level.icon)`
  (TrackerRow.swift:153).
- `info.circle`: `Meditationstimer iOS/InfoButton.swift:17`, Knopf ohne Kennung. Auf dem Bildschirm
  des geführten Workouts: ein Info-Knopf im Ring (`WorkoutProgramsView.swift:1258` bzw. :1291), dazu
  bleiben hinter der Überlagerung (`WorkoutTab.swift:201`, nur abgedunkelt) der Kopf „Freies Workout“
  (`WorkoutTab.swift:71`) und die Satzzeilen mit Beschreibung (`WorkoutProgramsView.swift:1541`) im
  Barrierefreiheitsbaum. Siehe Memory „UI-Test: Überlagerungen“.
- Die Kennung `workout.training.infoButton` existiert nur auf dem unfertigen #83-Zweig (`7f2ea36`), nicht
  auf `main`. Der Kommentar vom 2026-11-17 (Fehler an :2278) stammt aus diesem Zweig.

## Existing Patterns (Testseite)
- `.firstMatch` ~101 Stellen, `matching(identifier:)` 11, `descendants(matching:)` 8, `boundBy` 4.
- Apple-Doku: `element` scheitert bei mehr als einem Treffer absichtlich; `firstMatch` versteckt
  Mehrdeutigkeit, wenn sich die Reihenfolge ändert. Empfehlung der Quellen: Kennung je Zeile aus den
  Daten bilden oder Abfrage auf den Container eingrenzen.
  Quellen: https://developer.apple.com/documentation/xcuiautomation/xcuielementquery/element ,
  https://www.simplified.guide/xcuitest/selector-stabilize

## Existing Specs
- `docs/specs/bugfix/tracker-tab-bugs.md:48–73, 140–143, 172–174` (AC4/AC5 Datumsknopf → LevelSelectionView)
- `openspec/specs/features/workouts.md:56–59, 109–121` (Info-Knopf während des Workouts)
- `openspec/specs/features/ui-components.md:15, 196` (InfoButton)

## Dependencies
- Upstream: In-Memory-Store unter `enable-testing` (`Meditationstimer_iOSApp.swift:36–38`); welche
  Tracker beim Start existieren, bestimmt die Trefferzahl.
- Downstream: nur UI-Tests (Kennung `trackerDateButton` sonst nirgends benutzt).

## Risks & Considerations
- Simulator iOS 26.5 ist nicht mehr installiert, `run-uitests.sh` hat 26.5 fest verdrahtet (#74/#77).
  Reproduktion läuft mit einer Kopie des Skripts auf 27.2 im Scratchpad.
- `firstMatch` könnte den falschen Tracker treffen (Test spricht vom Mood-Tracker) → eingrenzen statt raten.
- Überschneidung mit #83 (Info-Knopf-Kennung) — Lösung darf nicht auf eine Kennung bauen, die erst #83 bringt.
- Dateigrenze: TrackerRow.swift, InfoButton/WorkoutProgramsView.swift, Testdatei — innerhalb 4–5 Dateien.

## Reproduktion (2026-11-17, Stand origin/main 2f56d2e, iPhone 17 Pro / iOS 27.2, je 3 Durchläufe)
| Test | Ergebnis | Zeile | Meldung |
|------|----------|-------|---------|
| `testDatePickerButtonOpensLevelSelectionViewWithDatePicker` | 3/3 rot | :2770 | Failed to tap "trackerDateButton" — Multiple matching elements found |
| `testDatePickerSheetCloseDoesNotShowCompactSheet` | 3/3 rot | :2820 | dto. |
| `testLevelSelectionViewShowsAdvancedButton` | 3/3 rot | :2995 | dto. |
| `testGuidedWorkoutPauseButtonIsBelowProgressRing` | 3/3 rot | :2278 | Failed to get matching snapshot — Multiple matching elements found (`info.circle`) |

Deterministisch, keine Flakiness. Der `info.circle`-Fehler tritt auch ohne #83 auf `main` auf — die
Mehrdeutigkeit kommt aus den Info-Knöpfen hinter der Überlagerung, nicht aus #83.
Logs: Scratchpad der Sitzung (`repro-*.log`), Skriptkopie mit `SIMULATOR_OS="27.2"`.

## Analysis

### Type
Bug (Testschuld): Die App verhält sich richtig, die Tests fragen mehrdeutig oder starten den falschen Ablauf.

### Befund aus dem Element-Baum (2026-11-17, Wegwerf-Kopie, `app.debugDescription` vor der Abfrage, iOS 27.2)
- **B (`trackerDateButton`):** genau **zwei** Treffer, nicht drei: Zeile „Mood“ (y≈190) und Zeile „NoAlc“ (y≈390),
  beide sichtbar, Beschriftung „Zum Kalender Hinzufügen“. Beim Teststart existieren nur diese zwei Standard-Tracker
  (`TrackerModels.swift` `createDefaultTrackersIfNeeded`). Beide Knöpfe öffnen dieselbe LevelSelectionView mit
  Datumswahl; die Prüfung der Tests (Datumswahl sichtbar / kein Kompakt-Blatt) gilt für jeden stufenbasierten Tracker.
- **E (`info.circle`):** Root Cause ist **nicht** die Überlagerung allein. Der Test tippt auf den Text „Tabata Classic“
  (öffnet heute nichts mehr) und danach `play.circle.fill` → das **freie Workout** startet („10 x 30s/10s“, Flamme,
  „Set 1 / 10 — Work“, Pause). Dort gibt es keinen Info-Knopf im Ring. Die fünf `info.circle`-Treffer gehören zur
  Programmliste hinter der Überlagerung (einer bei y=-329). Der Test prüft also seit dem Umbau der Programmzeilen
  (Start-Knopf `play.fill` je Zeile, fünffach) nicht mehr das geführte Workout.
- Logs/Bäume: Scratchpad der Sitzung `1f199b28…/scratchpad/tree-date.txt`, `tree-info.txt`.

### Entscheidung
- **B: nur Testseite, `.firstMatch`** an den drei Abfragen (:2765, :2815, :2991). Begründung: Mehrdeutigkeit ist hier
  inhaltlich harmlos (beide Knöpfe gleiches Verhalten), Projektmuster (~101 Stellen), keine App-Änderung. Kommentare
  an den Stellen auf „erster stufenbasierter Tracker (Mood)“ präzisieren.
  - Alternative (verworfen): App-Kennung je Zeile `trackerDateButton.<name>` (TrackerRow.swift:103) + alle fünf
    Testabfragen. Mehr Fläche, Name ist vom Nutzer änderbar, kein Test braucht heute gezielt NoAlc.
- **E: aus dieser Runde heraus, an #83.** Die nötigen Kennungen (`workout.programRow.<Name>.start`,
  `workout.training.infoButton`) bringt Commit 7f2ea36 auf dem #48-Zweig. Dieselben Kennungen hier auf `main`
  nochmals einzubauen erzeugt Doppeländerungen auf zwei Zweigen. Test bleibt bis dahin rot (bekannt, in #25 und #83
  vermerkt); kein `XCTSkip`, damit kein falsches Grün entsteht.
- Nicht in dieser Runde: :2730 und :2884–2888 (Gruppe A).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| LeanHealthTimerUITests/LeanHealthTimerUITests.swift | MODIFY | 3 Abfragen `trackerDateButton` → `.firstMatch`, Kommentare |

### Scope Assessment
- Files: 1 · Estimated LoC: +6/-3 · Risk Level: LOW (nur Testcode, App unberührt)

### Dependencies
- Reihenfolge der Tracker in der Liste: Mood vor NoAlc (Standardanlage). Ändert sich die Reihenfolge, trifft
  `firstMatch` NoAlc — Prüfung bleibt gültig, weil beide denselben Ablauf öffnen.

### Open Questions
- keine (technische Entscheidung, kein Produktthema)
