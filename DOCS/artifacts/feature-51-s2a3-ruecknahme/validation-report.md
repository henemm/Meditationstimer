# Validation Report: feature-51-s2a3-ruecknahme (#51 Runde 2a-3)

Datum: 2026-11-21 · Stand: `61f1b7e`

## Test Results
- Unit-Suite `LeanHealthTimerTests` (iPhone 17 Pro, iOS 27.2): `Executed 309 tests, with 0 failures`, `** TEST SUCCEEDED **`
- Alle zehn neuen Tests der Runde einzeln im Protokoll als `passed` gefunden; `testRuecknahmeNochNichtUnterstuetzt` wie vorgesehen entfernt (0 Treffer)
- Watch-App (`Meditationstimer Watch App`, watchOS Simulator): `** BUILD SUCCEEDED **`
- Widget (`MeditationstimerWidgetExtension`, iOS Simulator): `** BUILD SUCCEEDED **`
- iOS-App: im Testlauf gebaut
- UI-Tests: keine; die Runde ändert nichts Sichtbares und nichts Gespeichertes, `apply` hat noch keinen Aufrufer (Spec, Test Plan)

## Spec Compliance
| AC | Test(s) | Status |
|----|---------|--------|
| AC-2 | `testAlleLesbarenBeispieleLassenSichAnwenden`, `testApplyBeispielsatzMindestanzahl` | grün |
| AC-8b | `testRuecknahmeEinzelnGeaendertesProgrammAbgelehnt` | grün |
| AC-9 | `testRuecknahmeEinzelnEntferntBaustein` (inkl. beide Kennungen → Vereinigung), `testRuecknahmeUnbekannterKennungOhneWirkung` (inkl. keine Kennung, eigener Baustein) | grün |
| AC-10 | `testRuecknahmePaketEntferntAlleBausteine`, `testRuecknahmePaketMitGeaendertemBausteinAbgelehnt` | grün |
| AC-11 | `testRuecknahmeUebungLaesstProgrammphasenStehen` | grün |
| AC-17 | `testResultUndStateRoundTrip` | grün |
| AC-18 | `testApplyDateiIstFoundationOnlyUndOhneSeiteneffekte`; Diff-Durchsicht siehe Scope Check | grün |
| AC-19 | Suite grün, drei Ziele bauen, Produktiv-Diff 20 Zeilen, `applyWithdrawal` 17 Zeilen | erfüllt |

Code-Durchsicht: `applyWithdrawal` bildet erst die Treffermenge über `claude?.itemId`/`claude?.packageId` (eigene Bausteine nie getroffen), prüft dann die Sperre nur für Programme und Atemübungen und entfernt erst danach (Präzisierung 1, 2, 4). Positionen laufen auf der Arbeitskopie `work` (Präzisierung 3).

## Regression Check
- Keine Regressionen: alle 309 Unit-Tests grün (300 aus 2a-2, +10 neu, −1 entfernt).

## Scope Check
- Geänderte Dateien seit dem letzten Stand auf `main`: `Meditationstimer iOS/Models/ClaudeApply.swift` (+20/−0), `LeanHealthTimerTests/ClaudeApplyTests.swift`, `openspec/specs/features/claude-annahme.md` (Doku-DoD), Kontext, Spec, Briefing, Artefakte
- Produktiv-Diff: 20 Zeilen (Limit 250)
- Keine Änderung an `WorkoutTab.swift`, `MeditationTab.swift`, `ExerciseDatabase.swift`, `project.pbxproj`, `ClaudeDelivery.swift`

## Dokumentation
- `openspec/specs/features/claude-annahme.md`: Schnitt 2 in 2a (erledigt) und 2b (offen) geteilt, Elternspec verlinkt, Abweichung „Übungen in `claudeState`“ ergänzt — in dieser Runde bereits erledigt, kein weiterer Nachzug nötig.

## Adversary
- `adversary-dialog.md`: valid, 16 Punkte bewiesen, 2 Runden, Verdict VERIFIED; Prüfsummen der drei geprüften Dateien stimmen mit dem validierten Stand überein.

## Result: PASS
