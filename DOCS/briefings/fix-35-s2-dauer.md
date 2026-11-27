---
spec_file: DOCS/specs/features/feature-35-s2-dauer.md
spec_sha256: 37f145bf6edb29eabe3104e847b81708808d41c2cb3c07358ffb029f0de30d63
spec_frozen_sha256: 077ed71a799c08b18c7ac657a1e7f07d02a761a4c02bba9593190c9187e6fdf9
---

# PO-Briefing: fix-35-s2-dauer

- **Spec:** DOCS/specs/features/feature-35-s2-dauer.md
- **Issue:** #35
- **Erstellt:** 2026-11-27

## Was gebaut wird

Geführte Workouts erscheinen in Health ohne Pausen und ohne Countdown und enden vor dem Schlussgong.

## Definition of Done

In Health zeigt ein Programm mit Pause kürzere aktive Dauer; Ringe starten nach dem Countdown bei null; das Ende liegt vor dem Gong.

## Wie geprüft wird

Automatische Tests prüfen Pausen, Dauer und Kalorien; Ablauf und Gong-Reihenfolge nur im Simulator, echte Health-Dauer nicht ohne Gerätetest.

## Kritische Anmerkungen

- Der Zusatz-Fix gegen die ~22-Sekunden-Blockade beim Auftakt-Klang steht nicht in Ihrer Entscheidung und ändert den Klangspieler des Programms.
- Die echte Health-Dauer ohne Pausen bleibt ungeprüft; Beleg nur per Gerätetest mit Ihrer Freigabe.

## Freigabe-Frage

Soll der Zusatz-Fix gegen die Klang-Blockade in dieses Ticket, oder als eigenes Ticket behandelt werden?

## Ampel

Ampel: rot
