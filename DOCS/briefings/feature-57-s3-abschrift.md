---
spec_file: DOCS/specs/features/feature-57-s3-abschrift.md
spec_sha256: df6c75d9ca0508bb5330af8dee6fa75cfa9d938ae05bc44cc347adfc3e988ba5
spec_frozen_sha256: c32135dd662723a17e479a6d26f509a11119a08e09aa3941e4a454e84480667a
---

# PO-Briefing: feature-57-s3-abschrift

- **Spec:** DOCS/specs/features/feature-57-s3-abschrift.md
- **Issue:** #57
- **Erstellt:** 2026-11-24

## Was gebaut wird

Die App kann die Übersicht ihrer Übungen, Programme, Atemübungen und Lieferergebnisse für Claude als Datei erzeugen, noch unsichtbar und ohne Versand.

## Definition of Done

Alle neuen Tests und Beispieldateien sind grün, die App startet im Simulator unverändert, und nichts ruft den neuen Baustein auf.

## Wie geprüft wird

Tests vergleichen die erzeugte Datei Byte für Byte mit geprüften Beispielen und dem Dienst-Format; ein echter Versand wird nicht getestet.

## Kritische Anmerkungen

- Eigene Übungen fehlen in der Übersicht, weil sie keine Kategorie haben; Claude sieht sie nicht.
- Ungültige Bausteine werden stillschweigend ausgelassen, damit der Dienst nicht alles ablehnt; Claude bleiben sie unsichtbar.
- Nie geänderte Vorgaben erhalten bei jedem App-Start neue Kennungen; Schnitt 4 muss das lösen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
