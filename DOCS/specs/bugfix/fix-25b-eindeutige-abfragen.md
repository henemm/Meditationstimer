---
entity_id: fix-25b-eindeutige-abfragen
type: bugfix
created: 2026-11-17
updated: 2026-11-17
status: draft
workflow: fix-25b-eindeutige-abfragen
---

# Fix 25b: Eindeutige UI-Test-Abfragen für `trackerDateButton` (#25, Runde 25b)

## Approval

- [ ] Approved

## Purpose

Drei UI-Tests scheitern deterministisch mit „Multiple matching elements found“, weil
`app.buttons["trackerDateButton"]` beim Teststart zwei Treffer liefert (Standard-Tracker Mood und
NoAlc). Beide Knöpfe öffnen dieselbe LevelSelectionView mit Datumswahl. Der Fix liegt allein auf
der Testseite: die Abfrage greift gezielt den ersten Treffer. Die App bleibt unverändert.

## Source

| Feld | Wert |
|------|------|
| Entity | `fix-25b-eindeutige-abfragen` |
| Spec-Datei | `DOCS/specs/bugfix/fix-25b-eindeutige-abfragen.md` |
| Kontext & Analyse | `DOCS/context/fix-25b-eindeutige-abfragen.md` |
| Übergeordnetes Ticket | #25 (Bestandsaufnahme rote UI-Tests), Gruppe B |

## Root Cause

Beim Start mit `enable-testing` (In-Memory-Store) legt `createDefaultTrackersIfNeeded`
(`TrackerModels.swift`) genau zwei Standard-Tracker an: Mood, dann NoAlc. `TrackerRow.swift:103`
setzt in `levelBasedLayout` für jeden stufenbasierten Tracker dieselbe Kennung `trackerDateButton`.
Der Element-Baum (iOS 27.2) zeigt zwei sichtbare Treffer (Zeile Mood y≈190, Zeile NoAlc y≈390).
`XCUIElementQuery.element` scheitert bei mehr als einem Treffer absichtlich. Die App verhält sich
richtig; es ist Testschuld.

Reproduziert am 2026-11-17 (Stand `2f56d2e`, iPhone 17 Pro, iOS 27.2, je 3 Durchläufe, 3/3 rot):

| Test | Zeile |
|------|-------|
| `testDatePickerButtonOpensLevelSelectionViewWithDatePicker` | :2770 (Abfrage :2765) |
| `testDatePickerSheetCloseDoesNotShowCompactSheet` | :2820 (Abfrage :2815) |
| `testLevelSelectionViewShowsAdvancedButton` | :2995 (Abfrage :2991) |

## Affected Files

- `LeanHealthTimerUITests/LeanHealthTimerUITests.swift` (MODIFY, ca. +6/-3)

Keine weitere Datei wird geändert. Insbesondere bleibt `Meditationstimer iOS/Tracker/TrackerRow.swift`
unberührt.

## Expected Behavior

- Änderung: An den drei Abfragen (:2765, :2815, :2991) wird `.firstMatch` ergänzt
  (`app.buttons["trackerDateButton"].firstMatch`). Die zugehörigen Kommentare werden auf
  „erster stufenbasierter Tracker (Mood)“ präzisiert.
- Input: App-Start mit `enable-testing`, Tracker-Tab, Standardtracker Mood und NoAlc.
- Output: Die Abfrage trifft eindeutig einen Knopf; Tippen öffnet die LevelSelectionView mit
  Datumswahl; die Prüfungen der drei Tests (Datumswahl sichtbar, kein Kompakt-Blatt nach dem
  Schließen) laufen durch.
- Gültigkeit der Prüfung: Beide Knöpfe öffnen dasselbe Blatt mit demselben Verhalten. Die Prüfung
  gilt daher für jeden stufenbasierten Tracker; sollte die Reihenfolge einmal wechseln und
  `firstMatch` NoAlc treffen, bleibt sie gültig.
- Side effects: keine. Kein Produktcode, keine Lokalisierung, keine AppStorage-Keys, keine
  Berechtigungen.

## Nicht im Scope

- **Gruppe E:** `testGuidedWorkoutPauseButtonIsBelowProgressRing` (`info.circle`, :2276). Root Cause
  ist nicht die Überlagerung allein: Der Test startet seit dem Umbau der Programmzeilen das freie
  Workout statt des geführten, dort gibt es keinen Info-Knopf im Ring. Die nötigen Kennungen
  (`workout.programRow.<Name>.start`, `workout.training.infoButton`) liefert #83. Der Test bleibt
  unverändert und rot, ohne `XCTSkip`, damit kein falsches Grün entsteht.
- **Gruppe A:** die Abfragen :2730 (`testLevelTrackerShowsDatePickerButton`) und :2884–2888
  (`testLevelTrackerShowsLargeIconsInSeparateRow`) bleiben unverändert; sie gehören zu eigenen
  Runden unter #25.

## Verworfene Alternative

App-Kennung je Zeile, z. B. `trackerDateButton.<name>` in `TrackerRow.swift:103`, plus Anpassung
aller fünf Testabfragen. Das entspräche den Mustern `dayDetail.habitRow.<uuid>` und
`calendar.day.<…>` und ist die von Apple und Praxisquellen empfohlene Variante für mehrfach
auftretende Zeilen. Verworfen, weil:

1. Mehr Fläche: eine App-Datei zusätzlich, alle fünf Abfragen inklusive Gruppe A müssten mit.
2. Der Tracker-Name ist vom Nutzer änderbar und taugt nicht als stabile Kennung; die UUID wäre
   in Tests nicht vorab bekannt.
3. Kein Test braucht heute gezielt die NoAlc-Zeile; die Mehrdeutigkeit ist inhaltlich harmlos.
4. `.firstMatch` ist Projektmuster (ca. 101 Stellen).

Würde ein Test später gezielt einen bestimmten Tracker brauchen, wird die Kennung je Zeile dann
nachgezogen.

## Acceptance Criteria

1. `testDatePickerButtonOpensLevelSelectionViewWithDatePicker`, `testDatePickerSheetCloseDoesNotShowCompactSheet`
   und `testLevelSelectionViewShowsAdvancedButton` laufen jeweils einzeln als `Klasse/Methode`
   grün; im Protokoll steht je Lauf `Executed N tests` mit N ≥ 1 (kein Nulllauf).
2. Kein anderer Test in `LeanHealthTimerUITests.swift` wird durch die Änderung rot (Vergleich der
   Ergebnisliste vor und nach der Änderung; erwartet rot bleiben nur bekannte Fälle aus #25).
3. `git diff` gegen `main` zeigt ausschließlich `LeanHealthTimerUITests/LeanHealthTimerUITests.swift`
   (plus Spec/Doku-Dateien dieses Workflows); keine App-Datei ändert sich.
4. `testGuidedWorkoutPauseButtonIsBelowProgressRing` ist im Diff unverändert, ohne `XCTSkip`.
5. Die Abfragen an :2730 und :2884–2888 sind im Diff unverändert.

## Test Plan

Hinweis: Simulator iOS 26.5 ist nicht installiert, `Scripts/run-uitests.sh` hat 26.5 fest
verdrahtet (#74/#77). Läufe erfolgen auf iPhone 17 Pro / iOS 27.2 mit einer Skriptkopie im
Scratchpad (`SIMULATOR_OS="27.2"`), Repo-Skript bleibt unverändert.

- [ ] RED: Die drei Tests vor der Änderung einzeln ausführen, je 3/3 rot mit
      „Multiple matching elements found“ (bereits am 2026-11-17 belegt, Wiederholung im Workflow).
- [ ] GREEN: Nach der Änderung jeden der drei Tests einzeln als `Klasse/Methode` ausführen, je
      mehrere Durchläufe, jeweils `Executed N tests` mit N ≥ 1 und kein Fehler.
- [ ] Regression: Komplette Datei bzw. Suite `LeanHealthTimerUITests` laufen lassen (langer Lauf:
      nohup + Monitor, nie zwei Simulatoren), Ergebnisliste mit dem Stand vor der Änderung
      vergleichen; keine neue Rotmeldung.
- [ ] Diff-Prüfung: nur die Testdatei geändert, Gruppe-E-Test und Gruppe-A-Abfragen unverändert.
- [ ] Unit-Tests: nicht betroffen (nur UI-Testcode).

## Risiken

- `.firstMatch` versteckt künftige Mehrdeutigkeit, falls sich die Reihenfolge ändert. Abgefangen
  durch die Gleichwertigkeit beider Knöpfe (siehe Expected Behavior).
- Abhängigkeit: Standardanlage Mood vor NoAlc unter `enable-testing`.
- Umfang: 1 Datei, ca. +6/-3 LoC, Risiko niedrig (nur Testcode).

## Scope

- Dateien: 1 (`LeanHealthTimerUITests/LeanHealthTimerUITests.swift`)
- LoC: ca. +6/-3
- Risiko: niedrig (nur Testcode)

## Dependencies

| Abhängigkeit | Art | Bedeutung |
|--------------|-----|-----------|
| `TrackerModels.swift` `createDefaultTrackersIfNeeded` | Upstream | legt unter `enable-testing` Mood vor NoAlc an; bestimmt, welchen Knopf `firstMatch` trifft |
| `Meditationstimer iOS/Tracker/TrackerRow.swift:103` | Upstream | vergibt die Kennung `trackerDateButton` (unverändert) |
| #83 | Folgearbeit | bringt die Kennungen für den Gruppe-E-Test |

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine

Keine neue ADR nötig: reine Testanpassung nach bestehendem Projektmuster (`.firstMatch`).

## Definition of Done

- [ ] Die drei Tests laufen einzeln als `Klasse/Methode` grün, je `Executed N tests` mit N ≥ 1
- [ ] Regressionslauf der UI-Suite ohne neue Rotmeldung gegenüber dem Stand vorher
- [ ] Diff enthält nur die Testdatei (plus Workflow-Doku); App-Code unverändert
- [ ] Gruppe-E-Test und Gruppe-A-Abfragen unverändert
- [ ] #25 mit dem Ergebnis der Runde 25b kommentiert

## Changelog

- 2026-11-17: Initial spec created
- 2026-11-17: Scope, Dependencies, ADR-Hinweis und Definition of Done ergänzt (Spec-Validierung)
