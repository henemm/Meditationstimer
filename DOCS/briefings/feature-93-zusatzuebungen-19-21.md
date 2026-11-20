---
spec_file: DOCS/specs/features/feature-48-uebungskatalog.md
spec_sha256: 4c2975df940a95400b511a3c59964d450fcd9fb52039512b28ca13097f23d79f
spec_frozen_sha256: 04a1849950ba4082b84c10ed7aaf6f904987db9d5600e74776e61097416afbf9
---

# PO-Briefing: feature-93-zusatzuebungen-19-21

- **Spec:** DOCS/specs/features/feature-48-uebungskatalog.md
- **Issue:** #93
- **Erstellt:** 2026-11-16

## Was gebaut wird

Herabschauender Hund, Kobra-Dehnung und Katze-Kuh erhalten im Übungskatalog feste Kennung, Wirkung und Anleitung auf Deutsch und Englisch.

## Definition of Done

Beim Wählen von „Downward Dog" zeigt das Info-Blatt Wirkung und Anleitung auf Deutsch und Englisch; Build grün, nur Tests späterer Runden rot.

## Wie geprüft wird

Tests prüfen Vorhandensein, Kategorie, Namen und Gleichlauf der Einträge; ob die Texte fachlich gut und abgegrenzt sind, prüfen sie nicht.

## Kritische Anmerkungen

- Textqualität (gehaltene Dehnung gegen Bewegungsübung, Rückenhinweis bei Kobra) ist nur durch Durchlauf und Adversary prüfbar.
- Bekannter Altfehler #90: Info-Blatt ist beim ersten Tipp leer; wird hier nicht behoben.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
