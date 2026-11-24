---
spec_file: DOCS/specs/features/feature-57-s4-abgleich.md
spec_sha256: 9866c74fd93f2a95e555c36ac2b49a2af7263ca29cc998de481e6997d86c7947
spec_frozen_sha256: e3a370ba218ff841a7753f2be3baf15d4580ec31644653f1695759ddaaf47489
---

# PO-Briefing: feature-57-s4-abgleich

- **Spec:** DOCS/specs/features/feature-57-s4-abgleich.md
- **Issue:** #57
- **Erstellt:** 2026-11-24

## Was gebaut wird

Die App holt Lieferungen von Claude ab, wendet sie an, meldet das Ergebnis und sendet ihren Stand zurück, noch unsichtbar.

## Definition of Done

Alle Tests und Builds sind grün, und die App startet im Simulator ohne Absturz und ohne Netzverkehr, weil noch niemand angemeldet ist.

## Wie geprüft wird

Automatische Tests mit Testdienst belegen Ablauf, Fehlerfälle und Meldungen; echter Dienst und Anmeldung werden erst mit Schnitt 5 geprüft.

## Kritische Anmerkungen

- Nur Start und Vordergrund lösen den Abgleich aus; „nach eigenen Änderungen“ und „im Hintergrund“ aus dem Ticket fehlen vorerst.
- Der Ende-zu-Ende-Test mit echtem Dienst aus dem Ticket entfällt hier, da die Anmeldung erst in Schnitt 5 kommt.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
