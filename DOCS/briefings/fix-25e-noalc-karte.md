---
spec_file: DOCS/specs/bugfix/fix-25e-noalc-karte.md
spec_sha256: 83ec42868a5e9869731848186431b7836229416b67a90837c15f349076bb3471
spec_frozen_sha256: 7481e654ccd9644e2fb42cedb1e3ae10294e556f2db506acf9fa035c22f798c0
---

# PO-Briefing: fix-25e-noalc-karte

- **Spec:** DOCS/specs/bugfix/fix-25e-noalc-karte.md
- **Issue:** #25
- **Erstellt:** 2026-11-19

## Was gebaut wird

Zehn rote Tests der NoAlc-Ansicht werden aufgeräumt: fünf repariert, fünf gestrichen, die App selbst bleibt unverändert.

## Definition of Done

Die reparierten Tests laufen auch auf frisch zurückgesetztem Simulator grün, die Gesamtsuite zeigt keine neue Rotmeldung, die App bleibt unberührt.

## Wie geprüft wird

Echte Testläufe im Simulator belegen das; ungeprüft bleibt die Joker-Anzeige, dafür gibt es weiterhin keinen Oberflächentest.

## Kritische Anmerkungen

- Issue #25 konnte nicht gelesen werden; Abgleich nur gegen die Spec, nicht gegen die Ursprungsanfrage.
- Neu: zwei weitere Tests gestrichen, da das alte Eintrage-Blatt unerreichbar ist; Eintragen mit Datum geht weiter über den Datums-Knopf.
- Folge-Ticket: das ungenutzte Blatt samt vier toten Ansichten aus der App entfernen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
