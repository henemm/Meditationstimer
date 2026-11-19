---
spec_file: DOCS/specs/bugfix/fix-99-toter-code.md
spec_sha256: fce0a42a6d41ec241e2d32479a46fd30c184a89177773f9f4309e40951debe33
spec_frozen_sha256: 30581c8fcf8f78bbf241ab906e983c8dbe7596e06e2ae58d8414b1188d9f3b8b
---

# PO-Briefing: fix-99-toter-code

- **Spec:** DOCS/specs/bugfix/fix-99-toter-code.md
- **Issue:** #99
- **Erstellt:** 2026-11-19

## Was gebaut wird

Ungenutzte alte Bildschirme und ihre Texte werden aus der App entfernt; für Nutzer ändert sich nichts.

## Definition of Done

Beide Apps bauen, die Tests zeigen keine neuen Fehler, und Meditation, Workout und Tracker samt NoAlc-Eintrag funktionieren im Simulator wie vorher.

## Wie geprüft wird

Bauen, bestehende Tests und ein Prüfskript belegen, dass nichts fehlt; neue Tests gibt es nicht, das Verhalten prüft nur der Simulator-Durchlauf.

## Kritische Anmerkungen

- Zwei der vier im Ticket genannten Ansichten (Atem, Workout-Programme) werden nur teilweise entfernt; der Rest folgt in #101 (von dir so geschnitten).
- Übersetzungstexte prüft kein Bau-Werkzeug; ein übersehener Text fiele nur im Simulator-Durchlauf auf.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
