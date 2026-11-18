---
spec_file: DOCS/specs/bugfix/fix-25c-tracker-anlage.md
spec_sha256: 61d62a3a52202f87e486162d2122151aea3af7220c0f8d1a0aee8ab3d1253f67
spec_frozen_sha256: c24d7aeada97ffa449e7ff691b258f42d6b25e462f4c9f6b4e4ea66dd630b0b3
---

# PO-Briefing: fix-25c-tracker-anlage

- **Spec:** DOCS/specs/bugfix/fix-25c-tracker-anlage.md
- **Issue:** #25
- **Erstellt:** 2026-11-18

## Was gebaut wird

Zwei rote Tests zur Gewohnheits-Anlage werden grün, und die deutsche App zeigt Vorlagen-Namen wie „Dankbarkeit“ statt „Gratitude“.

## Definition of Done

Beide Tests laufen grün, die übrige Testsuite zeigt keine neue Rotmeldung, und die Tracker-Liste zeigt deutsche Vorlagen-Namen.

## Wie geprüft wird

Automatische Oberflächentests prüfen Anlegen, Neustart und deutsche Namen; der Schutz des Normalbetriebs wird nur per Release-Build-Prüfung belegt.

## Kritische Anmerkungen

- Zusatz zum Ticket: Namensanzeige wird in der App geändert; du hast das am 18.11. entschieden, Stimmungsstufen folgen in #97.
- Release-Unverändertheit hat keinen eigenen automatischen Test, nur Build-Prüfung auf Warnungen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
