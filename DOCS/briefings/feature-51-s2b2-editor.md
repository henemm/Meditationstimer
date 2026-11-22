---
spec_file: DOCS/specs/features/feature-51-s2b2-editor.md
spec_sha256: 526d00207f7c03a070a2993cffcb4ff68b169ab8f2325695e5a8421443cfea83
spec_frozen_sha256: f2aa3781c534bdeb6e6e1ef06c98bac267b84fc81741f8aea92b12c0ee283109
---

# PO-Briefing: feature-51-s2b2-editor

- **Spec:** DOCS/specs/features/feature-51-s2b2-editor.md
- **Issue:** #51
- **Erstellt:** 2026-11-21

## Was gebaut wird

Ändert Henning einen von Claude gelieferten Baustein, gilt seine Fassung; spätere Lieferungen überschreiben sie nicht.

## Definition of Done

Im Simulator bleibt Hennings geänderter Baustein bei neuer Lieferung stehen, ein unverändert bestätigter wird aktualisiert, neue Atemübungen lassen sich sofort speichern; alle Tests grün.

## Wie geprüft wird

Automatische Tests und ein Simulator-Durchlauf belegen Speichern, Ablehnung, Schritt-Übung und Neu-Anlegen ohne Änderung; Hennings Geräte werden nicht getestet.

## Kritische Anmerkungen

- Neu angelegte Übungen oder Programme werden auch ohne Änderung gespeichert; ein zwischenzeitlicher Spec-Fehler ist behoben und getestet.
- Ein im Editor geänderter, zurückgenommener Baustein erscheint wieder als Hennings Fassung; ohne PO-Frage festgelegt.
- Bis die Abschrift-Funktion existiert, sperrt jede Änderung den Baustein dauerhaft gegen Claude-Lieferungen; gewollt, aber spürbar.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
