---
spec_file: docs/specs/features/FEAT-apac-export.md
spec_sha256: dac238ffb8a17bea437e6cc43a334cd9b7bb7efd9488b242653367db18e92370
---

# PO-Briefing: feature-apac-export

- **Spec:** docs/specs/features/FEAT-apac-export.md
- **Issue:** keine
- **Erstellt:** 2026-09-21

## Was gebaut wird

Ein Entwickler-Kommandozeilenwerkzeug liest die verborgene Raumklang-Tonspur aus iPhone-Videos aus und schreibt sie als Rohdaten heraus.

## Definition of Done

Fertig ist, wenn alle fünf automatisierten Prüfungen bestehen und ausschliesslich die fünf vorgesehenen Dateien geändert wurden.

## Wie geprüft wird

Automatisierte Prüfungen zeigen korrekte Spurauswahl, Abbruch bei fehlender oder falscher Spur und passende Dateigrösse — nicht, ob der Toninhalt tatsächlich räumlich ist.

## Kritische Anmerkungen

- Ob die vier Kanäle wirklich unterschiedliche Rauminformation enthalten, wird in dieser Fassung nicht automatisiert geprüft.
- Dass ausschliesslich die fünf vorgesehenen Dateien geändert wurden, ist keinem automatisierten Test zugeordnet, nur einer Checkliste.
- Die Abtastrate wird abweichend von der ursprünglichen Anfrage nicht fest auf 48 kHz gesetzt, sondern aus der Datei gelesen.

## Freigabe-Frage

Reicht dir dieser Nachweis der Funktionsfähigkeit aus, auch ohne Beleg, dass die aufgenommene Raumklang-Information tatsächlich hörbar unterschiedlich ist?
