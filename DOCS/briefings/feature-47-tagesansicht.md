---
spec_file: DOCS/specs/features/feature-47-tagesansicht.md
spec_sha256: bf5387f0f88ee0f16ddeb51987a6931b6600df1035b0e343a23385e36efe6659
spec_frozen_sha256: 79d014a0ea56bcc2a00133ee9bc6ac0cd93264277e0cb7efdf3e96d8fb950fd9
---

# PO-Briefing: feature-47-tagesansicht

- **Spec:** DOCS/specs/features/feature-47-tagesansicht.md
- **Issue:** #47
- **Erstellt:** 2026-11-14

## Was gebaut wird

Tippt man im Erfolge-Kalender einen Tag an, zeigt das Fenster jede aktive Gewohnheit mit Eintrag oder "kein Eintrag".

## Definition of Done

Alle Unit- und UI-Tests laufen grün, und ein Screenshot zeigt die Tagesansicht mit mehreren Gewohnheiten, gefüllt und leer.

## Wie geprüft wird

Tests belegen Tageszuordnung, Anzeigewerte, Reihenfolge und Öffnen des Fensters; nicht automatisch geprüft wird, dass die Gruppierung nur einmal je Laden läuft.

## Kritische Anmerkungen

- Kalender springt beim Erscheinen sofort auf den aktuellen Monat; im Ticket nicht verlangt, PO-Freigabe steht aus.

## Freigabe-Frage

Darf der Kalender beim Öffnen sofort auf den aktuellen Monat springen, statt wie bisher erst nach dem Laden der Gesundheitsdaten?

## Ampel

Ampel: rot
