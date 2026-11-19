---
spec_file: DOCS/specs/features/feature-48-uebungskatalog.md
spec_sha256: a64c1572ab696325727c8662edf5aa80ba7ae5a0a945611b276827e57ad8809b
spec_frozen_sha256: 60b91b3df329af11441bf9ce1817a72507e572b5a006b5ff8829557815a0786c
---

# PO-Briefing: feature-84-vorgaben-kennung

- **Spec:** DOCS/specs/features/feature-48-uebungskatalog.md (Runde A2c-1)
- **Issue:** #84
- **Erstellt:** 2026-11-19

## Was gebaut wird

Die vier mitgelieferten Trainingsprogramme erhalten intern feste Übungskennungen; sichtbar bleibt alles wie bisher.

## Definition of Done

Alle 24 Schritte tragen gültige Kennungen, vorhandene Nutzerprogramme bleiben unverändert, Info-Knopf bei „Planke" zeigt Inhalt, App-Durchlauf ist belegt.

## Wie geprüft wird

Unit-Tests prüfen Kennungen und den Schutz der Nutzerprogramme; ein UI-Test sichert den Info-Knopf, beweist die Kennung aber nicht.

## Kritische Anmerkungen

- Der UI-Test zum Info-Knopf war schon grün; er ist nur Regressionsschutz, den Kennungsnachweis liefert allein der Unit-Test.
- Eine umbenannte gespeicherte Vorgabe wird weiterhin doppelt ergänzt (bekanntes, bewusst unverändertes Verhalten).

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
