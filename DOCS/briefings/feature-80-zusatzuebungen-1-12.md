---
spec_file: DOCS/specs/features/feature-48-uebungskatalog.md
spec_sha256: 428ba3642e41da3f1c3917b2dc48861373d88b03913419fb4e53989f07413770
spec_frozen_sha256: 28483cb785e8558437069c2382ee93538a67dd91c414344907f2a0715cde4e14
---

# PO-Briefing: feature-80-zusatzuebungen-1-12

- **Spec:** DOCS/specs/features/feature-48-uebungskatalog.md (nur Schnitt A2d-1)
- **Issue:** #80
- **Erstellt:** 2026-11-15

## Was gebaut wird

Zwölf neue Übungen kommen mit Namen, Wirkung und Anleitung auf Deutsch und Englisch in den Übungskatalog.

## Definition of Done

Das Info-Blatt der zwölf Übungen zeigt Wirkung und Anleitung in beiden Sprachen, der Katalog hat 55 Einträge, die 43 alten bleiben unverändert.

## Wie geprüft wird

Automatische Tests prüfen Texte, Reihenfolge und Gleichstand mit der Vertragsdatei; die Übungen 13 bis 24 bleiben bewusst rot bis zur nächsten Runde.

## Kritische Anmerkungen

- Die Spec nimmt zusätzlich eine Server-Testdatei auf (fünf statt vier Dateien); sonst würde dessen Prüfung mit 55 Einträgen rot.
- Das Ticket verspricht „nichts Sichtbares", die Spec nennt ein sichtbares Info-Blatt für die zwölf Übungen; harmlos.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
