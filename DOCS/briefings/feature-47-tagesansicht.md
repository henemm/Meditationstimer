---
spec_file: DOCS/specs/features/feature-47-tagesansicht.md
spec_sha256: d4c9de49aedf6d5356d124db0699127bb3bbf13a13662b2c4b1d1c1c4f7d6eb7
spec_frozen_sha256: dba6e68f5bcc86bf3919b3ce9858b5a5914feffad8109f010093fddae8840227
---

# PO-Briefing: feature-47-tagesansicht

- **Spec:** DOCS/specs/features/feature-47-tagesansicht.md
- **Issue:** #47
- **Erstellt:** 2026-11-13

## Was gebaut wird

Tippt man im Erfolge-Kalender einen Tag an, zeigt das Fenster jede aktive Gewohnheit mit Eintrag oder "kein Eintrag".

## Definition of Done

Alle Unit- und UI-Tests laufen grün, und ein Screenshot zeigt die Tagesansicht mit mehreren Gewohnheiten, gefüllt und leer.

## Wie geprüft wird

Tests belegen Tageszuordnung, Anzeigewerte, Reihenfolge und Öffnen des Fensters; nicht automatisch geprüft wird, dass die Gruppierung nur einmal je Laden läuft.

## Kritische Anmerkungen

- Tage mit nur leeren Gewohnheiten öffnen kein Fenster; NoAlc fehlt im neuen Abschnitt. Beides ist von dir entschieden.
- Einmalige Berechnung (AC-17) wird nur per Code-Durchsicht geprüft, kein Test; reine Umsetzungsfrage.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
