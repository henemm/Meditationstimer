---
entity_id: fix-101-aeussere-ansichten
type: bugfix
created: 2026-11-19
updated: 2026-11-19
status: draft
workflow: fix-101-aeussere-ansichten
---

# Fix 25g: Tote äußere Ansichten entfernen (#101, Teil von #25, zweiter Schnitt aus #99)

## Approval

- [ ] Approved

## Purpose

Die äußeren Bildschirmansichten `AtemView` und `WorkoutProgramsView` werden nirgends mehr erzeugt; die App nutzt seit der
Tab-Navigation nur `MeditationTab` und `WorkoutTab`. Die toten äußeren Ansichten (samt Watch-Platzhaltern, Standardvorlagen,
Laden/Sichern und Übersetzungsschlüsseln) werden entfernt. Die verschachtelten Bausteine bleiben, weil Tabs und
Einstellungen sie benutzen. Für den Nutzer ändert sich nichts.

## Source

| Feld | Wert |
|------|------|
| Entity | `fix-101-aeussere-ansichten` |
| Spec-Datei | `DOCS/specs/bugfix/fix-101-aeussere-ansichten.md` |
| Kontext & Analyse | `DOCS/context/fix-101-aeussere-ansichten.md` (Abschnitt "Analysis" maßgeblich) |
| Übergeordnetes Ticket | #25 (Bestandsaufnahme rote UI-Tests), Runde 25g; Folgeschnitt aus #99 |
| Vorige Runde | `DOCS/specs/bugfix/fix-99-toter-code.md` (Muster für den Nachweis) |
| PO-Entscheidung | 2026-11-19: reines Löschen zählt nicht gegen die 250-Zeilen-Grenze; Schnitt in zwei Runden (#99, dann #101) |

## Root Cause

Kein Fehler, sondern Altlast. Seit `0c89531` leben Meditation und Workout in `MeditationTab` und `WorkoutTab`.
`AtemView(` und `WorkoutProgramsView(` werden in Quellen, Tests und Previews nirgends erzeugt. Von außen werden nur
verschachtelte Typen angesprochen (`AtemView.Preset/Row/AddPresetCard/EditorView/PresetInfoSheet/SessionCard/AtemSoundTheme`,
`WorkoutProgramsView.WorkoutSetRow/AddSetCard/SetEditorView/PresetInfoSheet/WorkoutProgramSessionCard`).

Tot sind (Zeilen laut Analyse, Stand vor der Änderung):

- `AtemView.swift`: Watch-Platzhalter Z. 37-51 (`#if !os(iOS)`), `defaultPresets` Z. 177-191, Zustand/Laden/Migrieren/Sichern
  Z. 193-253, `init`/`body` Z. 255-366 (inkl. `.onReceive(.startBreathingSession)`), dateiprivates `OverlayBackgroundEffect`
  Z. 369-380 (steht innerhalb der Hülle, nur vom toten `body` genutzt).
- `WorkoutProgramsView.swift`: `defaultWorkoutSets` Z. 304-468, äußere Ansicht Z. 470-652 (Zustand, `body`, verschachteltes
  `OverlayBackgroundEffect`, `loadSets`/`migrateSets`/`saveSets`, `emojiChoices`), Watch-Platzhalter Z. 2058-2065.
- Das Watch-Target bezieht aus `Meditationstimer iOS/` nur `auftakt.caf` und `Localizable.xcstrings`: die
  `#if !os(iOS)`-Platzhalter werden nie übersetzt.
- Der Kurzbefehl "Atem starten" läuft lebend über `ContentView` (Reiterwechsel auf `.startBreathingSession`); nur der
  Empfänger in `AtemView.body` ist tot.
- `streakManager` in `WorkoutProgramSessionCard` (Z. 680) ist ein eigenes und bleibt.

## Affected Files

- `Meditationstimer iOS/Tabs/AtemView.swift` (MODIFY, ca. -210 Z. plus Hülle)
- `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` (MODIFY, ca. -350 Z. plus Hülle)
- `Meditationstimer iOS/Localizable.xcstrings` (MODIFY: 12 Schlüssel entfernen, ca. -250 JSON-Zeilen)

Keine Änderung an `MeditationTab.swift`, `WorkoutTab.swift`, `SettingsSheet.swift`, `ContentView.swift` und Tests. Dazu kommen
Spec und Kontextdatei dieses Workflows sowie ein einmaliges Prüfskript im Scratchpad (nicht im Repo).

## Expected Behavior

- Input: keiner, reine Codebereinigung.
- Output: App verhält sich unverändert. Meditation- und Workout-Reiter zeigen dieselben Vorlagen, Info-Blätter, Editoren und
  Sitzungen wie zuvor; "Atem starten" wechselt weiter den Reiter.
- Side effects: keine. Gespeicherte Schlüssel `atemPresets`, `workoutProgramSets`, `atemSoundTheme` bleiben unverändert.
  Benutzer-Vorlagen speichern ihren Beschreibungstext aufgelöst, nicht als Übersetzungsschlüssel; das Entfernen der
  Schlüssel ändert gespeicherte Daten nicht.

### Kernentscheidung: Hülle als caseloser Namensraum

`public struct AtemView: View` wird `enum AtemView`, `WorkoutProgramsView` entsprechend `enum WorkoutProgramsView` (ohne
`public`, nichts außerhalb des Moduls). Ein caseloser `enum` ist die übliche Swift-Form eines reinen Namensraums: nicht
instanziierbar, alle qualifizierten Namen (`AtemView.Preset` usw.) bleiben wörtlich gleich, damit bleiben Konsumenten und
Tests unangetastet. Die `#if !os(iOS) ... #else`-Zweige werden zu `#if os(iOS)`.

### Verworfene Alternativen

- **(b) Struct mit Platzhalter-`body` behalten:** lässt ein totes, aufrufbares `View` stehen; widerspricht dem Ticketziel.
- **(c) Bausteine auf die oberste Ebene ziehen (`AtemPreset`, `AtemSessionCard` ...):** langfristig sauberer, aber
  Umbenennung in allen Konsumenten und Tests, Namenskonflikt (`PresetInfoSheet` gibt es in beiden Dateien), sprengt "Bausteine
  behalten" und die Grenze für Neues. Bei Bedarf eigenes Ticket.
- **Mit weiteren Aufräumarbeiten bündeln (Kommentare, `OverlayBackgroundEffect` in Tabs):** Drive-by, nicht Teil des Tickets.

### Zu entfernende Übersetzungsschlüssel (12, nur im toten Teil)

- Die 10 langen Programmbeschreibungen aus `defaultWorkoutSets` (genaue Literale per Prüfskript aus dem Quelltext vor der
  Änderung ermittelt und im Validierungsbeleg wörtlich aufgeführt).
- `Breathe is only available on iOS.`
- `Workout programs are only available on iOS.`

Die Schlüsselzahl ist 12 (die Zählung 11 in der Kontext-Zusammenfassung ist überholt). Es bleiben: die sechs
Atem-Beschreibungen aus `AtemView.defaultPresets` (`MeditationTab` nutzt dieselben Schlüssel) und die kürzeren Varianten,
die `WorkoutTab` nutzt.

## Out of Scope

- Eigene Kopien von `defaultPresets`/`defaultWorkoutSets`/`OverlayBackgroundEffect` in `MeditationTab` und `WorkoutTab`.
- Umbenennen oder Verschieben der verschachtelten Typen (Alternative c).
- Kommentare in lebenden Dateien, die alte Namen nennen.
- Änderungen an gespeicherten Schlüsseln, Reiterverhalten, Kurzbefehlen.

## Acceptance Criteria

- **AC-1 (Prüfskript, äußere Ansicht weg):** Given `AtemView.swift` / When das Prüfskript sucht / Then gibt es keine
  Deklaration `struct AtemView`, keinen `body`-Member der Hülle, kein `defaultPresets`, kein `presetsKey`, kein
  `.onReceive(.startBreathingSession)`, kein `OverlayBackgroundEffect` und keinen `#if !os(iOS)`-Platzhalter ("Breathe is
  only available on iOS."); die Hülle ist `enum AtemView`.
- **AC-2 (Prüfskript, WorkoutProgramsView):** Given `WorkoutProgramsView.swift` / When das Prüfskript sucht / Then gibt es
  keine Deklaration `struct WorkoutProgramsView`, kein `defaultWorkoutSets`, kein `loadSets`/`migrateSets`/`saveSets`, kein
  `emojiChoices`, kein `OverlayBackgroundEffect` und keinen Watch-Platzhalter ("Workout programs are only available on
  iOS."); die Hülle ist `enum WorkoutProgramsView`.
- **AC-3 (Bausteine vorhanden):** Given beide Dateien / When das Prüfskript sucht / Then sind alle verschachtelten Typen
  weiterhin deklariert: in `AtemView` `Preset`, `Phase`, `AtemSoundTheme`, `GongPlayer`, `Row`, `AddPresetCard`,
  `PresetInfoSheet`, `SessionCard`, `EditorView`, `AtemWheelPicker`, `AtemGlassCard`; in `WorkoutProgramsView` `Cue`,
  `SoundPlayer`, `WorkoutSet`, `WorkoutPhase`, `SessionPhase`, `WorkoutProgramSessionCard`, `ProgressRingsView`,
  `WorkoutSetRow`, `AddSetCard`, `PresetInfoSheet`, `ExerciseSheetWrapper`, `SetEditorView`, `PhaseEditorView`,
  `WorkoutWheelPicker`, `WorkoutGlassCard`, sowie `exerciseSuggestions`.
- **AC-4 (Katalog):** Given `Localizable.xcstrings` / When das Prüfskript sie lädt / Then ist sie gültiges JSON, die 12
  Schlüssel fehlen, die sechs Atem-Beschreibungen aus `defaultPresets` und die Schlüssel der `WorkoutTab`-Beschreibungen sind
  weiterhin vorhanden. Der Skriptlauf vor der Änderung (RED-Beleg) findet alle Kriterien AC-1, AC-2 und AC-4 verletzt, der
  Lauf danach ist grün.
- **AC-5 (Builds):** Given der Stand nach der Änderung / When iOS (`Lean Health Timer`, iPhone 17 Pro, iOS 27.2) und
  watchOS gebaut werden / Then bauen beide ohne Fehler.
- **AC-6 (Unit-Suite):** Given die komplette Unit-Suite (`-only-testing:LeanHealthTimerTests`) / When sie läuft / Then ist sie
  grün, mit `Executed N tests` und N >= 1 im Protokoll.
- **AC-7 (UI-Suite):** Given die UI-Suite im Gesamtlauf / When sie gegen den Stand `main` verglichen wird / Then gibt es
  keine neue Rotmeldung (Einzeltests nur als `Klasse/Methode`, kein Nulllauf, #33).
- **AC-8 (App-Durchlauf):** Given die App im Simulator (iPhone 17 Pro, iOS 27.2) mit dem Stand dieser Änderung / When
  Meditation- und Workout-Reiter nacheinander durchgespielt werden (Vorlage starten, Vorlage bearbeiten, Info-Blatt öffnen,
  neue Vorlage anlegen) / Then funktioniert alles wie zuvor; Screenshots als Beleg. Der Kurzbefehl-Reiterwechsel "Atem starten"
  über `ContentView` ist durch die bestehenden Tests bzw. den Durchlauf belegt.
- **AC-9 (Diff):** Given der Diff gegen `main` / When er geprüft wird / Then enthält er nur die drei Affected Files plus
  Spec/Kontext dieses Workflows; in den beiden Swift-Dateien sind es Löschungen plus die Hüllen-Umstellung und die
  `#if`-Anpassung (unter 20 neue/geänderte Zeilen).

## Test Plan

Nur Simulator, keine Geräte des PO. UI-Läufe über `Scripts/run-uitests.sh`.

Ein RED-Test im üblichen Sinn ist nicht möglich, weil das Ziel "nichts ändert sich" lautet. Wie in #99 ist der RED-Beleg ein
einmaliges Prüfskript im Scratchpad (keine Datei im Repo), das vor der Änderung rot und danach grün ist; Befehle und
Ausgabe kommen wörtlich in den Validierungsbeleg.

- [ ] Prüfskript AC-1 bis AC-4 (`grep` auf die Kriterien, `python3 -c json.load` plus Schlüsselprüfung) vorher ROT,
      nachher GRÜN.
- [ ] Build iOS und Build watchOS ohne Fehler.
- [ ] Unit-Test: komplette Unit-Suite grün, `Executed N tests` mit N >= 1.
- [ ] UI-Test: Gesamtlauf (langer Lauf: nohup + Monitor, nie zwei Simulatoren), Ergebnisliste gegen `main`, keine neue
      Rotmeldung.
- [ ] App-Durchlauf im Simulator: Meditation- und Workout-Reiter wie in AC-8, Screenshots.
- [ ] Diff-Prüfung gemäß AC-9.

## Risiken

- Ein übersehener Bezug auf entfernte Member: der Compiler fängt ihn beim Build (iOS und watchOS).
- Ein Übersetzungsschlüssel könnte doch lebend genutzt werden: nur entfernen, wenn nachweislich in keiner lebenden `.swift`
  vorhanden (Prüfskript mit Gegenprobe); der Compiler prüft Schlüssel nicht, deshalb zusätzlich der App-Durchlauf.
- Der `enum` ändert die Sichtbarkeit (`public` entfällt): unkritisch, da App-Target ohne externe Konsumenten.

## Scope

- Dateien: 3 (alle MODIFY), plus Spec/Kontext
- LoC: ca. -560 Swift, ca. -250 JSON, neu/geändert unter 20; nach PO-Entscheidung zählt Löschen nicht gegen 250
- Risiko: niedrig

## Dependencies

| Abhängigkeit | Art | Bedeutung |
|--------------|-----|-----------|
| #99 | Ticket | gemergt (PR #102), erste Runde |
| #25 | Ticket | übergeordnete Bestandsaufnahme |
| `MeditationTab`, `WorkoutTab`, `SettingsSheet` | Konsumenten | nutzen die verschachtelten Typen unverändert |
| `ContentView` | Code | behält den lebenden Empfänger für `.startBreathingSession`/`.startWorkoutSession` |

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine. Entfernen von totem Code ohne Verhaltensänderung; die Wahl des Namensraum-`enum` ist oben begründet.

## Definition of Done

- [ ] Äußere Ansichten, Platzhalter, Standardvorlagen und `OverlayBackgroundEffect` entfernt, Hüllen als `enum` (AC-1, AC-2)
- [ ] Alle verschachtelten Bausteine vorhanden (AC-3)
- [ ] 12 Schlüssel entfernt, sechs Atem-Beschreibungen erhalten, JSON gültig (AC-4)
- [ ] Build iOS und watchOS grün (AC-5)
- [ ] Unit-Suite grün (AC-6)
- [ ] UI-Suite ohne neue Rotmeldung gegenüber `main` (AC-7)
- [ ] App-Durchlauf Meditation- und Workout-Reiter belegt (AC-8)
- [ ] Diff nur Affected Files (AC-9)
- [ ] #101, #99 und #25 mit dem Ergebnis kommentiert

## Changelog

- 2026-11-19: Initial spec created
