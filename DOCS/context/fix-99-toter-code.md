# Context: fix-99-toter-code (#99, Teil von #25)

## Request Summary
Toten App-Code entfernen, ohne Verhalten zu ändern. PO-Entscheidung 2026-11-19: reines Löschen zählt nicht gegen die 250-Zeilen-Grenze; Schnitt in zwei Runden (#99 jetzt, #101 danach).

## Scope dieser Runde (#99)
- `Meditationstimer iOS/Tabs/OffenView.swift` (689 Z.) – komplett löschen
- `Meditationstimer iOS/Tabs/WorkoutsView.swift` (809 Z.) – komplett löschen
- `Meditationstimer iOS/NoAlcLogSheet.swift` (277 Z.) – komplett löschen (inkl. `ConsumptionButton`, nur dort genutzt)
- `Meditationstimer iOS/Tabs/AtemView.swift` – nur `showingNoAlcLog` (Z. 198), Toolbar-Knopf (Z. 291) und `.sheet { NoAlcLogSheet() }` (Z. 306–308)
- `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` – nur `showingNoAlcLog` (Z. 478), Toolbar-Knopf (Z. 527) und `.sheet` (Z. 539–541)
- `Localizable.xcstrings` – Schlüssel, die nur in den gelöschten Dateien vorkamen (in der Analyse ermitteln)

## Related Files
| File | Relevance |
|------|-----------|
| `Tabs/MeditationTab.swift` | lebender Meditations-Reiter, nutzt `AtemView.Preset/Row/SessionCard/EditorView/...` – bleibt |
| `Tabs/WorkoutTab.swift` | lebender Workout-Reiter, nutzt `WorkoutProgramsView.*` und `WorkoutSoundPlayer` – bleibt |
| `SettingsSheet.swift` | nutzt `AtemView.AtemSoundTheme` – bleibt |
| `WorkoutSoundPlayer.swift` | eigene Datei, von `WorkoutsView` und `WorkoutTab` genutzt – bleibt |
| `Tracker/LevelSelectionView.swift` | erwähnt `NoAlcLogSheet` nur im Kommentar (Design-Vorbild) |
| `ContentView.swift`, `ShortcutHandler.swift`, `AppIntents/*`, `Services/*`, `UI/CircularRing.swift` | erwähnen `OffenView`/`WorkoutsView` nur in Kommentaren |
| `LeanHealthTimerTests/WorkoutSoundPlayerTests.swift`, `SessionDurationTests.swift`, `LeanHealthTimerUITests.swift:2090` | nur Kommentare/Doku-Verweise, kein Code-Bezug |

## Existing Patterns
- Projekt nutzt `PBXFileSystemSynchronizedRootGroup`: Datei löschen = aus dem Target entfernt, kein `project.pbxproj`-Eingriff.
- Watch-Target bindet aus `Meditationstimer iOS/` nur `auftakt.caf` und `Localizable.xcstrings` ein → gelöschte Dateien betreffen nur das iOS-Target. `#if !os(iOS)`-Platzhalter in `OffenView`/`WorkoutsView` sind damit ebenfalls tot.
- Tab-Navigation seit `0c89531`; seither leben Meditation/Workout in `MeditationTab`/`WorkoutTab`.

## Dependencies
- Upstream der gelöschten Dateien: `TwoPhaseTimerEngine`, `GongPlayer`, `HealthKitManager`, `BackgroundNotifier`, `AmbientSoundPlayer`, `WorkoutSoundPlayer`, `TrackerLevel` – alle bleiben, werden weiter von lebenden Ansichten genutzt.
- Downstream: keine (nur `#Preview` und Kommentare).

## Existing Specs
- `DOCS/specs/bugfix/fix-25e-noalc-karte.md` (AC-3: Befund toter `NoAlcLogSheet`)

## Risks & Considerations
- Dateiprivate Typen gleichen Namens (`OverlayBackgroundEffect`) existieren mehrfach – Löschen beseitigt nur Duplikate.
- Kommentare in lebenden Dateien verweisen weiter auf gelöschte Namen; nur anpassen, wo sie sonst falsch werden (kein Drive-by).
- Übersetzungsschlüssel könnten auch von lebenden Ansichten genutzt werden → nur entfernen, wenn nachweislich sonst nirgends verwendet.
- Nachweis: Build iOS + watchOS, Unit-Suite, UI-Suite ohne neue Rotmeldung, App-Durchlauf im Simulator (Meditation-, Workout-, Tracker-Reiter).

## Analysis

### Type
Refactoring / Aufräumen (Bugfix-Ablauf, kein Verhaltenswechsel)

### Belege (Suche 2026-11-19, alle `.swift` im Repo außer `.claude/`)
- `OffenView`, `WorkoutsView`, `NoAlcLogSheet`, `ConsumptionButton`: außerhalb der eigenen Dateien nur in Kommentaren/Doku-Strings erwähnt; einzige Code-Aufrufe von `NoAlcLogSheet()` sind `OffenView:418`, `WorkoutsView:739`, `AtemView:307`, `WorkoutProgramsView:540`.
- `AtemView(` / `WorkoutProgramsView(` werden nirgends instanziiert (auch nicht in `#Preview`) → deren NoAlc-Knopf ist ebenfalls unerreichbar; nur die eingebetteten Typen leben (Abbau der äußeren Ansicht = #101).
- Alle übrigen Typen in den gelöschten Dateien sind `private` (`RunCard`, `OverlayBackgroundEffect`, `IntervalPhase`, `WorkoutRunnerView`) → keine Fremdnutzung möglich.
- `Meditationstimer Watch App/` und `MeditationstimerWidget/`: keine Treffer. `project.pbxproj`: keine Treffer (synchronisierte Ordnergruppe).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Tabs/OffenView.swift` | DELETE | 689 Z., tot seit `0c89531` |
| `Meditationstimer iOS/Tabs/WorkoutsView.swift` | DELETE | 809 Z., tot seit `0c89531` |
| `Meditationstimer iOS/NoAlcLogSheet.swift` | DELETE | 277 Z., inkl. `ConsumptionButton` |
| `Meditationstimer iOS/Tabs/AtemView.swift` | MODIFY | `showingNoAlcLog` (Z. 198), Knopf `drop.fill` (Z. 291 + Leerzeile), `.sheet { NoAlcLogSheet() }` (Z. 306–308) entfernen, ca. −6 Z. |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | MODIFY | `showingNoAlcLog` (Z. 478), Knopf (Z. 527), `.sheet` (Z. 539–541) entfernen, ca. −5 Z. |
| `Meditationstimer iOS/Localizable.xcstrings` | MODIFY | 19 Schlüssel entfernen, die nur in den gelöschten Dateien vorkommen (Liste unten) |

Interpolierte Schlüssel der gelöschten Dateien (`Set %lld / %lld — %@`, `%lld x %llds/%llds`) bleiben: `WorkoutTab.swift:447/490` nutzt sie weiter.

#### Zu entfernende Übersetzungsschlüssel (nur in toten Dateien, in keiner lebenden `.swift`)
`🔴 Wild: Intensive consumption – be especially mindful` · `🟡 Easy: Increased consumption – watch your balance` · `🟢 Steady: No or moderate consumption – you're on a good path` · `A session is already running. Should it be stopped and the new one started?` · `Could not save to Health` · `Daily logging helps recognize patterns` · `End Session` · `How was it?` · `Log Drinks` · `NoAlc Diary` · `NoAlc tracker not found` · `Open is only available on iOS.` · `Session Already Running` · `Smart Reminders remind you automatically` · `Stop & Start` · `Stop & Start Timer` · `The NoAlc Diary helps you track … three categories for self-reflection.` · `Workouts are only available on iOS.` · `Yesterday Evening`

Ermittelt mit Skript (Schlüssel als Literal in toten Dateien, nicht in lebenden); Gegenprobe in Nicht-Swift-Dateien: nur Doku und `Localizable.xcstrings.bak`.

### Scope Assessment
- Files: 6 (3 DELETE, 3 MODIFY)
- Estimated LoC: +0 / ca. −1.775 (Dateien) −11 (Ansichten) −ca. 400 (xcstrings-JSON)
- Zählt nach PO-Entscheidung 2026-11-19 nicht gegen die 250-Zeilen-Grenze (reines Löschen).
- Risk Level: LOW — keine lebende Ansicht verliert Code; Compiler fängt jede übersehene Referenz.

### Technical Approach
Löschen in einem Schritt, danach Build iOS + watchOS. Kommentare in lebenden Dateien, die die alten Namen als Herkunft nennen („from OffenView", „Design based on NoAlcLogSheet"), bleiben unverändert — sie beschreiben Geschichte und werden nicht falsch; kein Drive-by.
Test-Strategie: kein neuer RED-Test möglich (Ziel ist „nichts ändert sich"). Nachweis = Build beider Ziele, komplette Unit-Suite, UI-Suite ohne neue Rotmeldung gegenüber Stand `main`, App-Durchlauf im Simulator (Meditation-, Workout-, Tracker-Reiter, NoAlc-Eintrag über die Tracker-Zeile).

### Alternative (verworfen)
Dateien behalten und nur aus dem Ziel ausschließen bzw. `NoAlcLogSheet` in `AtemView`/`WorkoutProgramsView` stehen lassen: lässt toten Code liegen und widerspricht dem Ticketziel. Zusammenlegen mit #101 widerspricht dem PO-Schnitt vom 2026-11-19.

### Dependencies
Keine Reihenfolgeabhängigkeit; #101 baut darauf auf (äußere Ansicht von `AtemView`/`WorkoutProgramsView`).

### Open Questions
- keine
