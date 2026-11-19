---
spec_file: DOCS/specs/bugfix/fix-25e-noalc-karte.md
spec_sha256: 4a1fa8882919194e44ce952982d8d4813ab137fbaa0601b1352c57db24c82ce5
spec_frozen_sha256: 04ec51aba36ecf9186882dd419119006c5a712023d4da73e91f865bdebc14ec5
---

# PO-Briefing: fix-25e-noalc-karte

- **Spec:** DOCS/specs/bugfix/fix-25e-noalc-karte.md
- **Issue:** #25
- **Erstellt:** 2026-11-19

## Was gebaut wird

Zehn seit Februar rote Prüfabläufe rund um NoAlc und Stufen-Gewohnheiten werden repariert oder gestrichen; die App selbst bleibt unverändert.

## Definition of Done

Die sieben verbleibenden Tests laufen auch auf frisch zurückgesetztem Simulator grün, drei veraltete sind entfernt, und der Gesamtlauf zeigt keine neue Rotmeldung.

## Wie geprüft wird

Jeder Test läuft einzeln und im Gesamtlauf; nachgewiesen wird die Prüfung des heutigen Verhaltens, nicht die Joker-Anzeige, die ungetestet bleibt.

## Kritische Anmerkungen

- Drei Tests werden gestrichen statt repariert; ihr Nutzen ist laut Spec durch bestehende grüne Tests abgedeckt.
- Joker-Anzeige in der Tracker-Zeile fehlt seit Februar und hat keinen UI-Test; ob das gewollt ist, bleibt offen.
- Ein Nebenfund (Toolbar-Test auf dem Meditation-Tab) wird nur beobachtet und bei Rot als eigenes Ticket erfasst.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
