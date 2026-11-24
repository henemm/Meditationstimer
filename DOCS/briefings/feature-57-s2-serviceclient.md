---
spec_file: docs/specs/features/feature-57-s2-serviceclient.md
spec_sha256: 4aab12e640f0cd19aa8b7cdb8d1148a9c4c5cca1690d3ec1453ecd310c3b062e
spec_frozen_sha256: 37825910c0a417cfc87fa23ada0a76c624c6115995bd4db78d3bee3094324905
---

# PO-Briefing: feature-57-s2-serviceclient

- **Spec:** DOCS/specs/features/feature-57-s2-serviceclient.md
- **Issue:** #57
- **Erstellt:** 2026-11-23

## Was gebaut wird

Unsichtbare Grundlage für die spätere Claude-Anmeldung: ein Baustein für das Gespräch mit dem Dienst und ein Testspeicher.

## Definition of Done

Alle neuen und bestehenden Tests sind grün, und die App startet im Simulator ohne sichtbare Veränderung.

## Wie geprüft wird

Tests mit Attrappe belegen Anfragen, Fehlerabbildung und fehlende Geheimnisse in Fehlern; Netzverkehr zum echten Dienst wird nicht geprüft.

## Kritische Anmerkungen

- Nur ein Teilstück von #57: Anmeldezustand, Abgleich und Einstellungsseite folgen in späteren Runden; heute ist nichts nutzbar.
- Die Apple-Anmelde-Berechtigung wandert bewusst in einen späteren Schnitt, damit Gerätebauten nicht scheitern; technische Entscheidung, ohne Folgen für Henning.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
