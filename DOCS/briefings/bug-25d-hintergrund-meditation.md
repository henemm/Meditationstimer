---
spec_file: docs/specs/bugfix/BUG-25d-hintergrund-workout.md
spec_sha256: 966b3fcf34e989861ce8f44c6db3d6386ec99c3071acea10de0193346e0e5cba
---

# PO-Briefing: bug-25d-hintergrund-meditation

- **Spec:** DOCS/specs/bugfix/BUG-25d-hintergrund-workout.md
- **Issue:** #25 (Cluster D)
- **Erstellt:** 2026-09-23

## Was gebaut wird

Zwei fehlerhafte Prüfungen bei Hintergrund-Wechseln im geführten Workout werden korrigiert — kein Produktfehler wird behoben, es gab keinen.

## Definition of Done

Beide korrigierten Tests laufen grün, der nicht führbare lange Test ist entfernt, und Ersatz sowie Aufräumarbeit sind eindeutig als solche gekennzeichnet.

## Wie geprüft wird

Zwei UI-Tests prüfen den tatsächlichen Sitzungszustand statt eines untauglichen Knopfs; ein Unit-Test belegt nur die Zeitrechnung, nicht den echten Workout-Pfad.

## Kritische Anmerkungen

- Der eigentliche Nachweis der geschriebenen Workout-Dauer fehlt weiterhin — nur die Zeitquelle ist getestet, nicht der reale Schreibweg.
- Der zweite im Ticket genannte Test (Atemübung) wird hier nicht behoben, sondern in ein anderes Ticket verschoben.
- Beide Punkte stehen in der Spec, sind aber nicht hervorgehoben — echte Lücken bleiben trotzdem bestehen.

## Freigabe-Frage

Reicht dir die teilweise Testabdeckung mit offen ausgewiesenen Lücken, oder soll nachgebessert werden?
