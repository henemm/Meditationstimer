---
entity_id: fix-99-toter-code
type: bugfix
created: 2026-11-19
updated: 2026-11-19
status: draft
workflow: fix-99-toter-code
---

# Fix 25f: Toten Code entfernen (#99, Teil von #25)

## Approval

- [ ] Approved

## Purpose

`OffenView`, `WorkoutsView` und `NoAlcLogSheet` (samt `ConsumptionButton`) sind seit der Tab-Navigation (`0c89531`) von
nirgends mehr erreichbar. Sie werden gelöscht, ebenso die unerreichbaren NoAlc-Knöpfe in `AtemView` und
`WorkoutProgramsView` und die Übersetzungsschlüssel, die nur dort vorkamen. Es ist reines Löschen: Für den Nutzer ändert
sich nichts, die App verhält sich vorher und nachher gleich.

## Source

| Feld | Wert |
|------|------|
| Entity | `fix-99-toter-code` |
| Spec-Datei | `DOCS/specs/bugfix/fix-99-toter-code.md` |
| Kontext & Analyse | `DOCS/context/fix-99-toter-code.md` |
| Übergeordnetes Ticket | #25 (Bestandsaufnahme rote UI-Tests), Runde 25f |
| Vorige Runde | `DOCS/specs/bugfix/fix-25e-noalc-karte.md` (Befund: `NoAlcLogSheet` unerreichbar, AC-3) |
| Folgeticket | #101 (äußere Ansichten `AtemView`/`WorkoutProgramsView` abbauen) |
| PO-Entscheidung | 2026-11-19: reines Löschen zählt nicht gegen die 250-Zeilen-Grenze; Schnitt in zwei Runden (#99, dann #101) |

## Root Cause

Kein Fehler, sondern Altlast. Seit `0c89531` (Tab-Navigation) leben Meditation und Workout in `MeditationTab` und
`WorkoutTab`. Die alten Gesamtansichten `OffenView` und `WorkoutsView` werden nirgends mehr eingebunden, nur noch in
`#Preview` und Kommentaren. `NoAlcLogSheet` hat als Aufrufer nur diese toten Ansichten (`OffenView:418`,
`WorkoutsView:739`) sowie die selbst nicht instanziierten `AtemView:307` und `WorkoutProgramsView:540`.

Belege (Suche 2026-11-19 über alle `.swift` außer `.claude/`):

- `OffenView`, `WorkoutsView`, `NoAlcLogSheet`, `ConsumptionButton` kommen außerhalb der eigenen Dateien nur in
  Kommentaren und Doku-Strings vor.
- `AtemView(` und `WorkoutProgramsView(` werden nirgends instanziiert (auch nicht in `#Preview`). Ihr NoAlc-Knopf ist
  unerreichbar; lebendig sind nur die eingebetteten Typen.
- Alle übrigen Typen der gelöschten Dateien (`RunCard`, `OverlayBackgroundEffect`, `IntervalPhase`, `WorkoutRunnerView`)
  sind `private`, eine Fremdnutzung ist ausgeschlossen. `OverlayBackgroundEffect` existiert dateiprivat mehrfach; das
  Löschen beseitigt nur Duplikate.
- `Meditationstimer Watch App/`, `MeditationstimerWidget/` und `project.pbxproj`: keine Treffer. Das Projekt nutzt
  `PBXFileSystemSynchronizedRootGroup`, Löschen entfernt eine Datei aus dem Target ohne Projektdatei-Eingriff. Das
  Watch-Target bindet aus `Meditationstimer iOS/` nur `auftakt.caf` und `Localizable.xcstrings` ein.

## Affected Files

- `Meditationstimer iOS/Tabs/OffenView.swift` (DELETE, 689 Z.)
- `Meditationstimer iOS/Tabs/WorkoutsView.swift` (DELETE, 809 Z.)
- `Meditationstimer iOS/NoAlcLogSheet.swift` (DELETE, 277 Z., inkl. `ConsumptionButton`)
- `Meditationstimer iOS/Tabs/AtemView.swift` (MODIFY: `showingNoAlcLog` Z. 198, Knopf `drop.fill` Z. 291, `.sheet` Z. 306–308; ca. −6 Z.)
- `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` (MODIFY: `showingNoAlcLog` Z. 478, Knopf Z. 527, `.sheet` Z. 539–541; ca. −5 Z.)
- `Meditationstimer iOS/Localizable.xcstrings` (MODIFY: 19 Schlüssel entfernen)

Sechs Dateien statt der üblichen vier bis fünf: drei davon werden nur gelöscht, das zählt nach PO-Entscheidung nicht gegen
die Grenzen. Neu angelegt wird nichts.

## Expected Behavior

- Input: keiner, reine Codebereinigung.
- Output: App verhält sich unverändert. Meditation-, Workout- und Tracker-Reiter funktionieren wie zuvor; NoAlc wird
  weiterhin über die Tracker-Zeile (`TrackerRow.levelBasedLayout`) eingetragen.
- Side effects: keine. Der Compiler fängt jede übersehene Referenz.

### Zu entfernende Übersetzungsschlüssel (19, nur in toten Dateien, in keiner lebenden `.swift`)

`🔴 Wild: Intensive consumption – be especially mindful` · `🟡 Easy: Increased consumption – watch your balance` ·
`🟢 Steady: No or moderate consumption – you're on a good path` ·
`A session is already running. Should it be stopped and the new one started?` · `Could not save to Health` ·
`Daily logging helps recognize patterns` · `End Session` · `How was it?` · `Log Drinks` · `NoAlc Diary` ·
`NoAlc tracker not found` · `Open is only available on iOS.` · `Session Already Running` ·
`Smart Reminders remind you automatically` · `Stop & Start` · `Stop & Start Timer` ·
`The NoAlc Diary helps you track … three categories for self-reflection.` · `Workouts are only available on iOS.` ·
`Yesterday Evening`

Ermittelt per Skript (Schlüssel als Literal in toten, nicht in lebenden Dateien); Gegenprobe in Nicht-Swift-Dateien: nur
Doku und `Localizable.xcstrings.bak`. Die interpolierten Schlüssel `Set %lld / %lld — %@` und `%lld x %llds/%llds`
bleiben, weil `WorkoutTab.swift:447/490` sie weiter nutzt.

## Out of Scope

- Abbau der äußeren Ansichten `AtemView` und `WorkoutProgramsView` selbst: #101. Die eingebetteten Typen (`Preset`,
  `Row`, `SessionCard`, `EditorView`, `AtemSoundTheme`, `WorkoutProgramsView.*`) bleiben unverändert, sie werden von
  `MeditationTab`, `WorkoutTab` und `SettingsSheet` genutzt.
- `WorkoutSoundPlayer.swift` bleibt (von `WorkoutTab` genutzt).
- Kommentare in lebenden Dateien, die alte Namen als Herkunft nennen (z. B. „from OffenView", „Design based on
  NoAlcLogSheet" in `LevelSelectionView`, `ContentView`, `ShortcutHandler`, `AppIntents/*`, `Services/*`,
  `UI/CircularRing.swift`, Testdateien): bleiben unverändert. Sie beschreiben Geschichte und werden nicht falsch; kein
  Drive-by.
- Joker-Anzeige oder andere NoAlc-Produktfragen: nicht Teil dieser Runde.

## Verworfene Alternativen

- **Dateien behalten und nur aus dem Target ausschließen, oder `NoAlcLogSheet` in `AtemView`/`WorkoutProgramsView`
  stehen lassen:** lässt toten Code liegen und widerspricht dem Ticketziel.
- **Zusammenlegen mit #101:** widerspricht dem PO-Schnitt vom 2026-11-19 (zwei Runden, je klar prüfbar).
- **Kommentare mit alten Namen mitbereinigen:** Drive-by außerhalb des Tickets, vergrößert den Diff ohne Nutzen.

## Acceptance Criteria

- **AC-1:** Given der Stand nach der Änderung / When die Dateien und der Swift-Code geprüft werden / Then existieren
  `OffenView.swift`, `WorkoutsView.swift` und `NoAlcLogSheet.swift` nicht mehr, und kein Swift-Code außerhalb von
  Kommentaren und String-Literalen in Doku-Kommentaren referenziert `OffenView`, `WorkoutsView`, `NoAlcLogSheet` oder
  `ConsumptionButton`.
- **AC-2:** Given `AtemView.swift` und `WorkoutProgramsView.swift` / When sie geprüft werden / Then sind
  `showingNoAlcLog`, der `drop.fill`-Toolbar-Knopf und das `.sheet { NoAlcLogSheet() }` entfernt, und die eingebetteten
  Typen (`Preset`, `Row`, `SessionCard`, `EditorView`, `AtemSoundTheme`, `WorkoutProgramsView.*`) sind unverändert.
- **AC-3:** Given `Localizable.xcstrings` / When sie geprüft wird / Then fehlen die 19 gelisteten Schlüssel, die
  interpolierten Schlüssel `Set %lld / %lld — %@` und `%lld x %llds/%llds` sind weiterhin vorhanden, und die Datei ist
  gültiges JSON.
- **AC-4:** Given der Stand nach der Änderung / When iOS- und watchOS-Ziel gebaut werden / Then bauen beide ohne Fehler.
- **AC-5:** Given der Stand nach der Änderung / When die komplette Unit-Suite läuft / Then ist sie grün, mit
  `Executed N tests` und N ≥ 1 im Protokoll.
- **AC-6:** Given die UI-Suite / When sie im Gesamtlauf gegen den Stand `main` verglichen wird / Then gibt es keine neue
  Rotmeldung (Einzeltests immer als `Klasse/Methode`, kein Nulllauf, #33).
- **AC-7 (App-Durchlauf):** Given die App im Simulator (iPhone 17 Pro, iOS 27.2) mit dem Stand dieser Änderung / When
  Meditation-, Workout- und Tracker-Reiter nacheinander geöffnet und ein NoAlc-Eintrag über die Tracker-Zeile gemacht
  wird / Then öffnen sich alle Reiter, und der NoAlc-Eintrag funktioniert wie zuvor.
- **AC-8:** Given der Diff gegen `main` / When er geprüft wird / Then enthält er nur die sechs Affected Files (plus
  Spec/Doku dieses Workflows); in den beiden Ansichten sind es ausschließlich Löschungen.

## Test Plan

Hinweis: Nur Simulator, keine Geräte des PO. UI-Läufe über `Scripts/run-uitests.sh`.

Entscheidung zur Teststrategie: Ein neuer RED-Test ist nicht möglich, weil das Ziel „nichts ändert sich" lautet; ein Test
auf Abwesenheit wäre vor der Änderung rot und danach dauerhaft ohne Nutzen. Die Projektpraxis (Bestandsaufnahme #25) setzt
auf Compiler und bestehende Suiten. Deshalb ist der Nachweis für AC-1 bis AC-3 ein einmaliges Prüfskript im Scratchpad
(keine Datei im Repo): `ls` der drei Pfade, `grep -rn` nach den vier Namen über alle `.swift` (Treffer nur in
Kommentaren erlaubt, von Hand gegen die Liste in der Analyse geprüft), `grep` nach `showingNoAlcLog` und `drop.fill` in
den beiden Ansichten, `python3 -c json.load` plus Schlüsselprüfung für `Localizable.xcstrings`. Befehle und Ausgabe
werden wörtlich in den Validierungsbeleg im Repo übernommen, damit der Nachweis nach der Sitzung wiederholbar bleibt.

- [ ] Nachweis AC-1 bis AC-3: Prüfskript (Pfade, Suche, JSON-Schlüsselprüfung) vor und nach der Änderung; vorher Treffer,
      nachher keine außer erlaubten Kommentaren.
- [ ] Build iOS (`Lean Health Timer`, iPhone 17 Pro, iOS 27.2) und Build watchOS ohne Fehler.
- [ ] Unit-Test: komplette Unit-Suite (`-only-testing:LeanHealthTimerTests`) grün, `Executed N tests` mit N ≥ 1.
- [ ] UI-Test: Gesamtlauf der UI-Suite (langer Lauf: nohup + Monitor, nie zwei Simulatoren), Ergebnisliste mit Stand
      `main` vergleichen, keine neue Rotmeldung.
- [ ] App-Durchlauf im Simulator: Meditation-, Workout-, Tracker-Reiter öffnen, NoAlc-Eintrag über die Tracker-Zeile;
      Screenshots als Beleg.
- [ ] Diff-Prüfung: nur sechs Affected Files, in den Ansichten nur Löschungen.

## Risiken

- Dateiprivate Typen gleichen Namens (`OverlayBackgroundEffect`) existieren mehrfach: Löschen beseitigt nur Duplikate.
- Kommentare in lebenden Dateien nennen weiter gelöschte Namen; bewusst unverändert (kein Drive-by).
- Ein Übersetzungsschlüssel könnte doch von einer lebenden Ansicht genutzt werden: nur entfernen, wenn nachweislich
  nirgends sonst verwendet (Skript-Nachweis, Gegenprobe in Nicht-Swift-Dateien); der Compiler prüft Schlüssel nicht,
  deshalb zusätzlich der App-Durchlauf (AC-7).
- Eine übersehene Referenz fällt beim Build auf, nicht still zur Laufzeit.

## Scope

- Dateien: 6 (3 DELETE, 3 MODIFY)
- LoC: +0 / ca. −1.775 (gelöschte Dateien) −11 (Ansichten) −ca. 400 (xcstrings-JSON)
- Nach PO-Entscheidung 2026-11-19 zählt reines Löschen nicht gegen die 250-Zeilen-Grenze.
- Risiko: niedrig

## Dependencies

| Abhängigkeit | Art | Bedeutung |
|--------------|-----|-----------|
| #25 | Ticket | übergeordnete Bestandsaufnahme; Runde 25e hat den Befund geliefert |
| #101 | Ticket | baut darauf auf: äußere Ansichten `AtemView`/`WorkoutProgramsView` abbauen |
| Upstream der gelöschten Dateien | Code | `TwoPhaseTimerEngine`, `GongPlayer`, `HealthKitManager`, `BackgroundNotifier`, `AmbientSoundPlayer`, `WorkoutSoundPlayer`, `TrackerLevel` bleiben, von lebenden Ansichten genutzt |
| `Tabs/MeditationTab.swift`, `Tabs/WorkoutTab.swift`, `SettingsSheet.swift` | Konsumenten | nutzen die eingebetteten Typen von `AtemView`/`WorkoutProgramsView`, unverändert |

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine

Keine neue ADR nötig: Entfernen von totem Code ohne Verhaltensänderung.

## Definition of Done

- [ ] Drei Dateien gelöscht, keine Referenz außerhalb von Kommentaren (AC-1)
- [ ] NoAlc-Knöpfe in `AtemView`/`WorkoutProgramsView` entfernt, eingebettete Typen unverändert (AC-2)
- [ ] 19 Schlüssel entfernt, interpolierte Schlüssel erhalten, JSON gültig (AC-3)
- [ ] Build iOS und watchOS grün (AC-4)
- [ ] Komplette Unit-Suite grün (AC-5)
- [ ] UI-Suite ohne neue Rotmeldung gegenüber `main` (AC-6)
- [ ] App-Durchlauf im Simulator belegt (AC-7)
- [ ] Diff enthält nur die sechs Affected Files (AC-8)
- [ ] #99 und #25 mit dem Ergebnis kommentiert; #101 als Folgeschritt benannt

## Changelog

- 2026-11-19: Initial spec created
- 2026-11-19: Prüfbefehle für AC-1 bis AC-3 kommen wörtlich in den Validierungsbeleg (Hinweis Spec-Validator)
