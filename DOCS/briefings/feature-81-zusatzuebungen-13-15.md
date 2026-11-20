---
spec_file: DOCS/specs/features/feature-48-uebungskatalog.md
spec_sha256: 0d139b30ee4f2b740723aef9253591d777467c6a65f3ae91ef63d6a00209066d
spec_frozen_sha256: af5e38c61f6116d87c3adca5d291615593917746cc9f136e666a60f9a070e65e
---

# PO-Briefing: feature-81-zusatzuebungen-13-15

- **Spec:** DOCS/specs/features/feature-48-uebungskatalog.md
- **Issue:** #81
- **Erstellt:** 2026-11-16

## Was gebaut wird

Umgekehrtes Rudern, Step-ups und Wandsitzen erhalten im Übungskatalog feste Kennung, Wirkung und Anleitung auf Deutsch und Englisch.

## Definition of Done

Beim Wählen von „Inverted Rows" zeigt das Info-Blatt Wirkung und Anleitung auf Deutsch und Englisch; Build grün, nur Tests späterer Runden rot.

## Wie geprüft wird

Tests prüfen Vorhandensein, Kategorie und Gleichlauf der Einträge; ob die Texte fachlich gut und von Australischen Klimmzügen abgegrenzt sind, prüfen sie nicht.

## Kritische Anmerkungen

- Textqualität (Abgrenzung zu Nr. 12, Haltedauer beim Wandsitzen) ist nur durch Durchlauf und Adversary prüfbar, nicht automatisch.
- Bekannter Altfehler #90: Info-Blatt ist beim ersten Tipp leer; wird hier nicht behoben.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
