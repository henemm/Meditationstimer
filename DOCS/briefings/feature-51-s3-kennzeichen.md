---
spec_file: DOCS/specs/features/feature-51-s3-kennzeichen.md
spec_sha256: 7b2d887386c8a21e5a5343e0741ffc3f1d87ad96d29138472fc251dfd1b043d4
spec_frozen_sha256: 425ce8e52c7f92d9fb60002e410e51dea7e147d7f3ff1a3966dd0ee07b9bc740
---

# PO-Briefing: feature-51-s3-kennzeichen

- **Spec:** DOCS/specs/features/feature-51-s3-kennzeichen.md
- **Issue:** #51
- **Erstellt:** 2026-11-22

## Was gebaut wird

Von Claude gelieferte Programme und Atemübungen tragen ein Zeichen, zeigen Datum, Paket und Grund, und gelieferte Übungen zeigen ihre Texte.

## Definition of Done

Gelieferte Bausteine zeigen die Kapsel „von Claude“, die Info nennt Datum, Paket und Warum, und die Übungs-Info zeigt beim ersten Tippen Texte.

## Wie geprüft wird

Automatische Tests prüfen Kapsel, Info-Abschnitt, Übungstexte, Englisch und „angepasst“ nach Bearbeitung; das Aussehen in Dunkel und Hell prüft nur ein Simulator-Durchlauf.

## Kritische Anmerkungen

- Zusätzlich eingebaut: der offene Fehler #90 (leere Übungs-Info beim ersten Tippen), nötig, damit gelieferte Übungen sofort Texte zeigen.
- Gelieferte Übungen werden anders als im Konzept beschrieben aufgelöst; für Henning unsichtbar, nur technische Abweichung.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
