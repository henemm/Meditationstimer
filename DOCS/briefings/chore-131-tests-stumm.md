---
spec_file: docs/specs/infrastructure/audio-testmodus-stumm.md
spec_sha256: 06540e6e92ddbd05e237b84521e7b9debfd84951b5349ae5dd0e11f1020f33ad
spec_frozen_sha256: 29dea747b2972aed44216c7d3f176b88b89adb6d9cd26557882190c36fc64cb0
---

# PO-Briefing: chore-131-tests-stumm

- **Spec:** docs/specs/infrastructure/audio-testmodus-stumm.md
- **Issue:** #131
- **Erstellt:** 2026-11-27

## Was gebaut wird

Während der UI-Tests im Simulator spielen alle Gongs, Ansagen und Hintergrundklänge mit Lautstärke null, die normale App bleibt hörbar.

## Definition of Done

Die gesamte UI-Suite läuft ohne neue Fehlschläge, ein Simulator-Durchlauf zeigt bei allen Klangstellen Lautstärke 0, die normale App behält ihre Lautstärke.

## Wie geprüft wird

Unit-Tests prüfen die Lautstärke-Entscheidung und die Klangstellen; ob wirklich nichts zu hören ist, belegen nur Logzeilen, kein Hörtest.

## Kritische Anmerkungen

- Neue Klangstellen in anderen Dateien wären künftig nicht automatisch stumm; der Vollständigkeitstest prüft nur die fünf bekannten Dateien.
- Zusätzlich eingebaut: Protokollzeilen nur im Debug-Build, als Nachweis der Stummschaltung; ohne Wirkung für Nutzer.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
