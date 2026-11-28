---
spec_file: DOCS/specs/features/feature-50-gewohnheiten-leiste.md
spec_sha256: 8a6236504e48d43c192fb273b47f00f090807b6e84d654ff258401800336aa75
spec_frozen_sha256: 9d3e344ac7cdd4e6a26c52143b3d0a1311297bd1b4d45f1204f937b28b2bd50d
---

# PO-Briefing: feat-50-innerer-kreis

- **Spec:** DOCS/specs/features/feature-50-gewohnheiten-leiste.md
- **Issue:** #50
- **Erstellt:** 2026-11-28

## Was gebaut wird

Im Erfolge-Reiter erscheint über dem Kalender eine Leiste mit Karten für dauerhafte Gewohnheiten, Antippen markiert deren Eintragstage.

## Definition of Done

Gewohnheiten mit eingeschaltetem Kalender-Schalter erscheinen als Karten mit Serie und sieben Punkten; Antippen markiert im Kalender ihre Tage, Tageskreise bleiben unverändert.

## Wie geprüft wird

Automatische Tests belegen Auswahl, Tageszuordnung, Punkte, Serie-Text, Texte und Antippen; Farben in Hell und Dunkel nur per Screenshot, nicht automatisch.

## Kritische Anmerkungen

- Über die Anfrage hinaus: Icon vor dem Namen und Scrollen der Leiste ab vier Karten, beides aus dem freigegebenen Entwurf.
- Hell/Dunkel-Farbe und "Berechnung einmal je Aufbau" sind nur per Screenshot bzw. Code-Durchsicht prüfbar, kein automatischer Test.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
