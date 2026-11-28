---
spec_file: docs/specs/infra/habits-dienst-betrieb.md
spec_sha256: ec25a790ab78587c6da09b29278e1d81e89367927dd205a259b6fcf5afc40d69
spec_frozen_sha256: b1a66d94828ec7b39f7abfd1c1abe4f73a6c015a35b2c4b4159ddc0589a6a320
---

# PO-Briefing: feat-56-habits-dienst-betrieb

- **Spec:** docs/specs/infra/habits-dienst-betrieb.md
- **Issue:** #56
- **Erstellt:** 2026-11-28

## Was gebaut wird

Der Dienst für die Claude-Verbindung läuft unter eigener Adresse, gesichert und überwacht, und Claude kann über Hennings Konto darauf zugreifen.

## Definition of Done

Der Dienst antwortet unter seiner Adresse, Sicherung und Überwachung sind nachweislich aktiv, und Claude liefert ein Beispiel, das als „wartet“ ankommt.

## Wie geprüft wird

Automatische Tests und Prüfbefehle belegen Dienst, Drosselung, Sicherung und Überwachung; die Prüfung in Claude selbst erfolgt einmal live und wird im Issue dokumentiert.

## Kritische Anmerkungen

- Das Issue nennt für Henning nur den Konnektor-Schritt; die Spec bündelt zusätzlich Adresseintrag und Apple-Portal in einem angekündigten Termin.
- Zusatz: Der bestehende Apple-Schlüssel von Loose Ends wird mitbenutzt; sonst müsste Henning einen neuen anlegen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
