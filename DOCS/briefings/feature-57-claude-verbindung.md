---
spec_file: docs/specs/features/feature-57-s1-bausteine.md
spec_sha256: f69b6ab3023541fb5bb38ccc34b1000f6a3683ea96739ab3764b02899c506857
spec_frozen_sha256: cd79915fa27a880c11be827b813db939c0eb91f69a7c026719531267599a5f05
---

# PO-Briefing: feature-57-claude-verbindung

- **Spec:** docs/specs/features/feature-57-s1-bausteine.md
- **Issue:** #57
- **Erstellt:** 2026-11-23

## Was gebaut wird

Unsichtbare Grundbausteine der Claude-Verbindung: Ein-/Aus-Schalter, Anmeldecode, sicherer Sitzungsspeicher und Geräte-Kennung.

## Definition of Done

Alle neuen und bisherigen Tests laufen grün, die App startet im Simulator unverändert, und in den Einstellungen erscheint noch nichts Neues.

## Wie geprüft wird

Automatische Tests mit Schlüsselbund-Attrappe belegen Schalter, Adressen, Anmeldecode und Fehlerfälle; echter Schlüsselbund, Netzwerk und Apple-Anmeldung bleiben ungeprüft.

## Kritische Anmerkungen

- Anmeldung, Abgleich und Einstellungsseite aus Issue #57 fehlen noch; sie folgen in den Schnitten 2 bis 5.
- Offen für Schnitt 4: Ticket verlangt Abgleich im Hintergrund und nach eigenen Änderungen, die Spec nur beim Start.
- Kein UI-Test, begründet: nichts Sichtbares.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
