---
spec_file: docs/specs/features/feature-48-uebungskatalog.md
spec_sha256: fce6dd71b0fedb033a3d0fc7caf33c350ee13aba583553dd4d33e08b5ac3614f
spec_frozen_sha256: b0daf9e0550381eb6c6456843db251611a25c0f345218b404069793e4b4a9ec1
---

# PO-Briefing: feature-48-uebungskatalog

- **Spec:** docs/specs/features/feature-48-uebungskatalog.md
- **Issue:** #48
- **Erstellt:** 2026-11-15

## Was gebaut wird

Programmschritte erhalten einen optionalen Hinweis unter dem Ring und in der Ansage; Übungen kommen aus einem einzigen Katalog.

## Definition of Done

Hinweis erscheint im Training unter dem Ring und wird angesagt, alte Programme bleiben vollständig erhalten, alle Tests grün, Screenshot liegt vor.

## Wie geprüft wird

Automatische Tests belegen Umstellung alter Programme, Hinweisanzeige und Ansagetext; gesprochene Wiedergabe und fachliche Richtigkeit der 24 neuen Übungstexte prüft kein Test.

## Kritische Anmerkungen

- Zusätzlich zum Ticket: veraltete Programmkopie wird entfernt und kaputte Programmdaten werden vor dem Überschreiben gesichert; beides unverlangt, aber schützend.
- Herkunft (mitgeliefert/eigen/von Claude) wird abgeleitet, nicht als eigenes Feld gespeichert; für den PO ohne sichtbare Folge.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
