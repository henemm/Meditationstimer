---
spec_file: DOCS/specs/features/feature-57-s5-einstellungen.md
spec_sha256: e167096a152c0743229b5375a09c1fdfee914d791824593cff14743c93e72287
spec_frozen_sha256: 9e83d40cf0053eaa27b51873a6ea4309ce28c3383a89f11edd5ae1578752f9ee
---

# PO-Briefing: feature-57-s5-einstellungen

- **Spec:** DOCS/specs/features/feature-57-s5-einstellungen.md
- **Issue:** #57
- **Erstellt:** 2026-11-25

## Was gebaut wird

In den Einstellungen gibt es eine eigene Seite „Claude-Verbindung“ zum An- und Abmelden, Trennen und Ansehen des letzten Abgleichs.

## Definition of Done

Die Seite zeigt im Simulator Anmelden, Abmelden und Trennen mit Rückfrage korrekt an, die Store-Version zeigt nichts davon, alle Tests laufen grün.

## Wie geprüft wird

Automatische Tests mit Test-Anmeldeknopf belegen Anmelden, Abmelden, Trennen und Hinweise; die echte Apple-Anmeldung wird nicht geprüft.

## Kritische Anmerkungen

- Lieferliste und „Was Claude sieht“ fehlen bewusst und folgen in Schnitt 5b; das Folge-Ticket existiert noch nicht.
- Echte Anmeldung am Gerät ist nicht Teil der Abnahme und wartet auf #56 und dein Okay.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
