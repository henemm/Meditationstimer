---
spec_file: DOCS/specs/features/feature-48-uebungskatalog.md
spec_sha256: 3e8e37605342f99de55f67c27b48b98651d739195dae8a7a4aba01dcea9a89d2
spec_frozen_sha256: 9120e8f11cdadf6cdee231937fac3d5f9e51f5ba2c0b5fe258c48aebdc0c2473
---

# PO-Briefing: feature-83-hinweis-katalogauswahl

- **Spec:** DOCS/specs/features/feature-48-uebungskatalog.md (Runde A2b)
- **Issue:** #83
- **Erstellt:** 2026-11-17

## Was gebaut wird

Trainingsschritte bekommen ein Hinweisfeld, der Hinweis steht unter dem Ring und wird angesagt; die Übungsauswahl zeigt nur die 67 Katalogübungen.

## Definition of Done

Ein eingegebener Hinweis erscheint im Training unter dem Ring und wird nach dem Namen angesagt, die Auswahl zeigt nur deutsche Katalognamen plus „Eigene Übung…“.

## Wie geprüft wird

Unit- und UI-Tests decken AC-18 bis AC-25 ab; Sprechen selbst wird nur als Text geprüft, nicht gehört.

## Kritische Anmerkungen

- Bei Rückfall der Auswahl auf eine andere Listenform ändert sich die Bedienung sichtbar; die Spec sieht dafür vorher einen Entwurf an dich vor.
- Der Hinweis wird auch bei englischer App-Sprache wörtlich, also unübersetzt, angesagt.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
