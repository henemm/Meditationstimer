---
spec_file: DOCS/specs/features/feature-117-stabile-kennungen.md
spec_sha256: dcbcedc365ad258e4063557b96d07a4c5f09933a82c950884b3dd717a367d34c
spec_frozen_sha256: 90f28963508416f49d2e5fd8018b4430ea4d265b2543d0ddaf456137bafd7b64
---

# PO-Briefing: feature-117-stabile-kennungen

- **Spec:** DOCS/specs/features/feature-117-stabile-kennungen.md
- **Issue:** #117
- **Erstellt:** 2026-11-24

## Was gebaut wird

Die zehn mitgelieferten Programme und Atemübungen behalten bei jedem App-Start dieselbe Kennung, sodass Claude sie wiedererkennt.

## Definition of Done

Alle zehn Vorgaben tragen nach jedem Neustart dieselbe feste Kennung, gespeicherte Listen bleiben unverändert, und beide Listen sehen aus wie vorher.

## Wie geprüft wird

Tests vergleichen die Kennungen mit fest notierten Werten, prüfen die Abschrift an Claude und die Umbenennung; die sichtbare Oberfläche bleibt ungetestet.

## Kritische Anmerkungen

- ÄNDERUNG gegenüber erster Freigabe: Eine umbenannte Vorgabe kommt nicht mehr zusätzlich unter dem Originalnamen zurück (bisher kam sie zurück).
- Gelöschte Vorgaben kommen weiterhin zurück; bereits gespeicherte Vorgaben behalten ihre alte Zufallskennung (bewusst, dokumentiert).

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
