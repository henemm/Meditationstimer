---
spec_file: DOCS/specs/features/feature-48-uebungskatalog.md
spec_sha256: cade3971ad100908c5b3bb2ff60a36dc97daee4b735ac11fee8852ae72e40204
spec_frozen_sha256: 83962a9dce5e0672dc61070f78dca8148bfcb724e3adfdc58acfebe38f7bba82
---

# PO-Briefing: feature-80-zusatzuebungen-1-12

- **Spec:** DOCS/specs/features/feature-48-uebungskatalog.md
- **Issue:** #80
- **Erstellt:** 2026-11-15

## Was gebaut wird

Vier neue Übungen (Hollow Hold, Dead Bug, Flutter Kicks, V-Ups) mit deutscher und englischer Beschreibung kommen in den Katalog.

## Definition of Done

Das Info-Blatt der vier Übungen zeigt Wirkung und Anleitung auf Deutsch und Englisch, der Katalog hat 47 Einträge, die Server-Prüfung bleibt grün.

## Wie geprüft wird

Automatische Tests prüfen Katalog, Namen und Texte der vier Übungen; der Gesamttest bleibt bis zur letzten Runde absichtlich rot.

## Kritische Anmerkungen

- Der Namenseintrag „Beinpendel" (englisch „Leg Swing") hat keinen eigenen Test; er wird nur im Durchlauf sichtbar.
- Mehrere Katalogtests bleiben bis Runde A2d-2 rot, weil sie den Endstand mit 67 Übungen verlangen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
