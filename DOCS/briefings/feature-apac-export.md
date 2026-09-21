---
spec_file: docs/specs/features/FEAT-apac-export.md
spec_sha256: b8fb03beeedc34db7b066ebd42e5f1b81df5c5f4cf0e11b91df56d73d3459e1e
---

# PO-Briefing: feature-apac-export

- **Spec:** docs/specs/features/FEAT-apac-export.md
- **Issue:** keine (Ursprungsanfrage stand in Kontext-Dokumenten, keine GitHub-Issue)
- **Erstellt:** 2026-09-21

## Was gebaut wird

Ein Kommandozeilen-Werkzeug liest die verborgene Raumklang-Tonspur aus iPhone-Aufnahmen aus und macht sie nutzbar.

## Definition of Done

Das Werkzeug läuft, erkennt die Raumspur zuverlässig, bricht bei fehlender oder falscher Spur kontrolliert ab, und alle festgelegten Prüfungen bestehen.

## Wie geprüft wird

Automatisierte Prüfungen kontrollieren Format, Dateigröße und Abbruchverhalten anhand einer echten Testaufnahme; ob der Klang tatsächlich räumlich ist, wird nicht geprüft.

## Kritische Anmerkungen

- Der einzige Inhalts-Beweis — dass die vier Kanäle wirklich unterschiedliche Rauminformation tragen — fehlt in dieser Fassung.
- Ein Prüfpunkt (nur die erlaubten Dateien wurden geändert) hat keinen zugehörigen automatisierten Test.
- Der Fehlerfall "falsche Raumspur" wird nur künstlich simuliert, nie mit einer echten fehlerhaften Aufnahme.

## Freigabe-Frage

Reicht es, wenn Format und Dateigröße stimmen, auch ohne Beweis dass die Kanäle wirklich unterschiedliche Rauminformation enthalten?
