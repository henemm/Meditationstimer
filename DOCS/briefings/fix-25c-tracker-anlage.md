---
spec_file: DOCS/specs/bugfix/fix-25c-tracker-anlage.md
spec_sha256: 99368afaf34661a9d220f456ad863475b59d27556b3b2b8880f8ed1e62862b54
spec_frozen_sha256: 4cab9cdcdbda98ecc28675a90d7ec4621d4fc7e12e118e73e96ab39a202a0f2a
---

# PO-Briefing: fix-25c-tracker-anlage

- **Spec:** DOCS/specs/bugfix/fix-25c-tracker-anlage.md
- **Issue:** #25
- **Erstellt:** 2026-11-18

## Was gebaut wird

Zwei rote Tracker-Tests werden grün, und die Tracker-Liste zeigt Vorlagennamen auf Deutsch („Dankbarkeit“, „Stimmung“).

## Definition of Done

Beide Tests laufen einzeln grün, die Liste zeigt deutsche Vorlagennamen, die übrige Testsuite bekommt keine neue Rotmeldung, und der normale App-Start bleibt unverändert.

## Wie geprüft wird

Automatische Oberflächentests prüfen Anlegen, Neustart und deutsche Namen; eine Gegenprobe ohne Speichern muss rot werden; der Release-Build wird nur per Build geprüft.

## Kritische Anmerkungen

- Stimmungsstufen („Awful … Great“) und weitere Stellen bleiben englisch; ausgelagert in Issue #97, von dir entschieden.
- Dass der normale Start unverändert bleibt, belegt kein eigener Test, nur Build und Diff-Prüfung.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
