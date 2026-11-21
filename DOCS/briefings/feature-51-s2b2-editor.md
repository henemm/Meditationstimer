---
spec_file: DOCS/specs/features/feature-51-s2b2-editor.md
spec_sha256: f6b3f5ef690db4a473535563054c04a03c2026042b421e84a6cf61e80586ac9f
spec_frozen_sha256: 994738fd50cd26c6b02ad70eb2cc26ec31f4a407c6c175343a193cc1567c7c38
---

# PO-Briefing: feature-51-s2b2-editor

- **Spec:** DOCS/specs/features/feature-51-s2b2-editor.md
- **Issue:** #51
- **Erstellt:** 2026-11-21

## Was gebaut wird

Wenn Henning einen von Claude gelieferten Baustein ändert, gilt seine Fassung und spätere Lieferungen überschreiben sie nicht.

## Definition of Done

Im Simulator bleibt Hennings geänderter Baustein bei neuer Lieferung stehen, ein unverändert bestätigter wird aktualisiert; alle Tests grün.

## Wie geprüft wird

Automatische Tests und ein Simulator-Durchlauf belegen Speichern, Ablehnung und Schritt-Übung; Verhalten auf Hennings Geräten wird nicht getestet.

## Kritische Anmerkungen

- Ein im Editor geänderter, zurückgenommener Baustein erscheint wieder als Hennings Fassung; die Spec hat das ohne PO-Frage festgelegt.
- Bis die Abschrift-Funktion (#57) existiert, sperrt jede Änderung diesen Baustein dauerhaft gegen Claude-Lieferungen; gewollt, aber spürbar.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
