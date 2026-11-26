---
spec_file: DOCS/specs/features/feature-35-s2-dauer.md
spec_sha256: 85e6008b65c90eb223c5696a4ef7ac35282dc6fa08a4a57e1269cb0b71a3a2a5
spec_frozen_sha256: af36b8c105502b78dd362280ab06113959dbfc97372623f0a7a10d672d44987b
---

# PO-Briefing: fix-35-s2-dauer

- **Spec:** DOCS/specs/features/feature-35-s2-dauer.md
- **Issue:** #35
- **Erstellt:** 2026-11-26

## Was gebaut wird

Das geführte Workout-Programm schreibt in Health nur die echte Trainingszeit: Pausen als Pause, ohne Countdown, Ende vor Schlussgong.

## Definition of Done

Im Simulator starten die Ringe nach dem Countdown bei null, und die Prüfungen zu Pausen, Mindestdauer und Doppel-Beenden sind grün.

## Wie geprüft wird

Automatische Tests beweisen Pausenrechnung, Mindestdauer und Kalorien; Reihenfolge vor dem Gong und Anzeige zeigt nur der Simulator-Durchlauf.

## Kritische Anmerkungen

- Ob Health die Pausen wirklich von der Dauer abzieht, ist nur auf dem Gerät prüfbar; Beleg steht aus.
- Ende vor Gong und Doppel-Beenden-Schutz haben keinen Unit-Test, nur Quelltextprüfung und Simulator.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
