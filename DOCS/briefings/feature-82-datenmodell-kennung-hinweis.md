---
spec_file: DOCS/specs/features/feature-48-uebungskatalog.md
spec_sha256: 97194c0c6b6872d160739ed7475124bbbf2c85748d2685df7bf71f8a30480355
spec_frozen_sha256: c1bd6ad0efb123b6bdc1727c444f4099d8f11b0e3f77de786d222c334b90ca92
---

# PO-Briefing: feature-82-datenmodell-kennung-hinweis

- **Spec:** DOCS/specs/features/feature-48-uebungskatalog.md (Runde A2b-0)
- **Issue:** #82
- **Erstellt:** 2026-11-16

## Was gebaut wird

Gespeicherte Trainingsprogramme laden unverändert weiter, und jeder Schritt kann künftig Übungskennung und Hinweis tragen; unlesbare Daten werden vorher gesichert.

## Definition of Done

Alle alten Programme erscheinen unverändert, nichts Sichtbares ändert sich, und unlesbare gespeicherte Daten liegen nach dem Start als Kopie vor.

## Wie geprüft wird

Automatische Tests belegen verlustfreies Laden, Hinweis-Bereinigung und Sicherung; eine Wiederherstellung der Sicherung durch die App wird nicht geprüft.

## Kritische Anmerkungen

- Über das Ticket hinaus: Mehrfach-Leerzeichen werden zusammengefasst, byte-gleiche Daten nicht doppelt gesichert; reine Detailregeln ohne Nutzerfolge.
- Nach Datenverlust sieht der Nutzer weiter die Vorgaben; die Sicherung ist nur Vorsorge, keine Wiederherstellung.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
