---
spec_file: DOCS/specs/features/feature-48-uebungskatalog.md
spec_sha256: 5b59355236d465e7cf7d05d4b88bc6cc6ba24fb4dd5a929e481f57e9291c1849
spec_frozen_sha256: 83962a9dce5e0672dc61070f78dca8148bfcb724e3adfdc58acfebe38f7bba82
---

# PO-Briefing: feature-88-zusatzuebungen-9-12

- **Spec:** DOCS/specs/features/feature-48-uebungskatalog.md
- **Issue:** #88
- **Erstellt:** 2026-11-15

## Was gebaut wird

Vier weitere Übungen (Dips, Klimmzüge, Chin-ups, Australische Klimmzüge) kommen mit deutscher und englischer Beschreibung in den Katalog.

## Definition of Done

Das Info-Blatt der vier Übungen zeigt Wirkung und Anleitung auf Deutsch und Englisch, der Katalog hat 55 Einträge, die ersten 51 bleiben unverändert.

## Wie geprüft wird

Automatische Tests prüfen Katalog, Namen und Texte der Übungen 1 bis 12; die Anzeigenamen Klimmzüge und Pull-ups sieht nur der Durchlauf im Simulator.

## Kritische Anmerkungen

- Mehrere Katalogtests bleiben bis Runde A2d-2 rot, weil sie den Endstand mit 67 Übungen verlangen.
- Der Changelog der Spec hat keinen Eintrag für diese Runde; inhaltlich deckt die Rundenzeile den Umfang ab.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
