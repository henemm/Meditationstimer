---
spec_file: DOCS/specs/features/feature-117-stabile-kennungen.md
spec_sha256: 1b69660f90a1fbe60b7d20d1700815f1a3bd0f3f6b3506bcd6db9fd688d617a8
spec_frozen_sha256: 6fc127b81eb5a58944c75b3bb7f41df7f2a4506eee5f8808f2fe330167b41326
---

# PO-Briefing: feature-117-stabile-kennungen

- **Spec:** DOCS/specs/features/feature-117-stabile-kennungen.md
- **Issue:** #117
- **Erstellt:** 2026-11-24

## Was gebaut wird

Die zehn mitgelieferten Programme und Atemübungen behalten bei jedem App-Start dieselbe Kennung, sodass Claude sie wiedererkennt.

## Definition of Done

Nach jedem Neustart tragen alle zehn Vorgaben dieselben festen Kennungen, gespeicherte Listen bleiben unverändert, und Programm- und Atemliste sehen aus wie vorher.

## Wie geprüft wird

Tests vergleichen die Kennungen mit fest notierten Werten und prüfen die Abschrift an Claude; sichtbare Oberfläche bleibt unverändert und ungetestet.

## Kritische Anmerkungen

- Bereits gespeicherte Vorgaben behalten ihre alte Zufallskennung; derselbe Name hat auf verschiedenen Installationen verschiedene Kennungen (bewusst, dokumentiert).

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
