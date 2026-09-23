---
spec_file: docs/specs/bugfix/BUG-25d-hintergrund-workout.md
spec_sha256: 232600bf929d38ecc562632cc41553a1ad83e4231b06a7be94814b3cf37212d0
---

# PO-Briefing: bug-25d-hintergrund-meditation

- **Spec:** DOCS/specs/bugfix/BUG-25d-hintergrund-workout.md
- **Issue:** #25 (Cluster D)
- **Erstellt:** 2026-09-23

## Was gebaut wird

Zwei fehlerhafte Testprüfungen werden korrigiert; am Verhalten der App selbst ändert sich nichts.

## Definition of Done

Die drei betroffenen Tests laufen nachweislich grün, und am Produktverhalten der App ändert sich nichts messbar.

## Wie geprüft wird

Automatisierte Tests bestätigen Sitzungszustand und Abbruch-Verhalten; ob die vollständige Workout-Dauer korrekt gespeichert wird, bleibt unbewiesen.

## Kritische Anmerkungen

- Ein Test war monatelang falsch grün und prüfte nie den Abbruch-Knopf, sondern einen Zufallsknopf.
- Der zweite im Ticket genannte Test (Atemübung) wird hier nicht behoben, sondern separat verschoben (#32).
- Der Nachweis, dass eine vollständige Workout-Sitzung korrekt gespeichert wird, fehlt weiterhin (#35).

## Freigabe-Frage

Genügt dir, dass am Produkt nichts geändert wird und nur die Tests korrigiert sind, oder soll die offene Dauer-Prüfung vorher geklärt werden?
