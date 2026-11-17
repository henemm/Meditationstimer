---
spec_file: DOCS/specs/bugfix/fix-25b-eindeutige-abfragen.md
spec_sha256: 23fd704ea0d377f56391c950a5010c0093d47dabca668dabd9bc2c81df9a2cb6
spec_frozen_sha256: 53c5a9511b459b70b0a5bde2e39bcb11eeb318e938bd81575b660334e9cecf8f
---

# PO-Briefing: fix-25b-eindeutige-abfragen

- **Spec:** DOCS/specs/bugfix/fix-25b-eindeutige-abfragen.md
- **Issue:** #25
- **Erstellt:** 2026-11-17

## Was gebaut wird

Drei automatische Oberflächentests, die heute wegen mehrdeutiger Knopf-Suche scheitern, finden künftig eindeutig den Datumsknopf und laufen grün.

## Definition of Done

Die drei Tests laufen einzeln grün, die restliche Testsuite wird nicht schlechter, und an der App selbst ändert sich nichts.

## Wie geprüft wird

Die drei Tests laufen vorher rot, nachher grün; ein Gesamtlauf vergleicht den Stand davor und danach. Ob die App-Bedienung selbst stimmt, wird nicht berührt.

## Kritische Anmerkungen

- Der Test zum geführten Workout (Info-Knopf) bleibt bewusst rot und wartet auf #83; er gehört nicht zu dieser Runde.
- Die Suche nimmt künftig stillschweigend den ersten Knopf; wechselt die Tracker-Reihenfolge, wird ein anderer getestet, gleichwertig.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
