# Validierung #35 Schnitt 2 — fix-35-s2-dauer

Stand: Commit 0d9df0f · 2026-11-27, 08:50 Uhr MEZ · Simulator iPhone 17 Pro, iOS 27.2

## Testergebnisse
- Unit-Suite: 503 total, 503 passed, 0 übersprungen (08:17 MEZ, `test-run-output.txt`)
- UI-Regression (AC-15, AC-9): 9 total, 9 passed, 0 übersprungen (`uitest-regression-output.txt`)
  - `testWorkoutProgramShowsRoundCounter` aus der Spec-Liste wirft im Quelltext unbedingt XCTSkip (vorbestehend), kein Beleg.

## Spec Compliance
- AC-1 bis AC-8: erfüllt, Unit-Tests.
- AC-9: erfüllt, UI-Test grün.
- AC-10: erfüllt — `walk-ac10-countdown.png`, `walk-ac10-nach-countdown.png` (Gesamtring bei null nach dem Countdown).
- AC-11: Quelltext erfüllt (Uhr-Ende vor Live-Activity-Ende und Gong); Simulator: manuelles und natürliches Ende ohne Absturz (`walk-ac11-manuell.png`, `walk-ac11-natuerlich.png`). Effort-Sheet erscheint im Simulator nicht, weil HealthKit dort das Schreiben ablehnt (Code=3); Verhalten bei Schreibfehler identisch mit bc16962 (direkt `close()`).
- AC-12: Quelltext erfüllt (`sessionEnded = true` vor dem ersten `await`); Doppeltipp ohne Absturz, nur ein Schließen (`walk-ac12-doppeltipp.png`). „Genau ein Sheet“ nur auf Gerät belegbar.
- AC-13: erfüllt — `walk-ac13-liveactivity.png`: 3:38 Rest bei 3:50 Programm ~12 s nach Countdown-Ende.
- AC-14: drei App-Dateien, 233 Zeilen; neue Funktionen ≤ 26 Zeilen. Vorbestehend über 50: `togglePause` (68, eine Zeile geändert), `logWorkout` (57, vorher 65).
- AC-16: geführtes Workout ohne `AVAudioSession Hang Risk` (Walk 08:30–08:42 MEZ: 0 Zeilen). Warnungen nur bei Unit-Läufen und freiem Workout (unberührte Klangspieler) → #127.

## Regression
Keine vorher grünen Tests rot.

## Scope
Nur die drei Spec-Dateien; gegen origin/main nur bc16962 und 0d9df0f.

## Offen (nur Gerät, nur auf Hennings Wort)
- Effort-Sheet nach Speichern, Doppeltipp → genau ein Sheet (AC-12).
- Health nimmt `.pause` ohne `.resume` am Ende an (AC-5, Adversary F002).
- Erste Sprachansage nach asynchroner Session-Anmeldung (Adversary F001).

## Ergebnis: PASS
