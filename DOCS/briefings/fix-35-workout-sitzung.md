---
spec_file: DOCS/specs/features/feature-35-workout-session-clock.md
spec_sha256: 283f41169bac38fad38633a6498ec1d76b534822c1d47cb79b534c9261873cae
spec_frozen_sha256: f336a36bde6a17fdc779b5f3122632499a1509f309d132e3ee56aedf8d0a0307
---

# PO-Briefing: fix-35-workout-sitzung

- **Spec:** DOCS/specs/features/feature-35-workout-session-clock.md
- **Issue:** #35
- **Erstellt:** 2026-11-26

## Was gebaut wird

Die Zeitrechnung eines Workout-Programms wird aus der Bildschirmansicht gelöst, damit die gespeicherte Dauer automatisch prüfbar wird.

## Definition of Done

Alle Tests und Builds sind grün, ein Simulator-Durchlauf zeigt unverändertes Verhalten, und die Zeitregeln sind per Test festgehalten.

## Wie geprüft wird

Automatische Tests belegen Start, Ende, Pausen und Mindestdauer; die Verdrahtung mit der Ansicht prüfen nur Quelltextsicht, bestehende UI-Tests und Simulator.

## Kritische Anmerkungen

- Das Ticket selbst war nicht lesbar; Abgleich erfolgte nur gegen das Kontextdokument.
- Sichtbar ändert sich nichts: Pausen zählen weiter mit, Doppeleintrag bleibt möglich, bis Schnitt 2 folgt.
- Anbindung der Ansicht an die neue Zeitrechnung ist nicht per Unit-Test gesichert; die Spec benennt das offen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
