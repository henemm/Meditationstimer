---
spec_file: DOCS/specs/features/feature-51-s2b-speichern.md
spec_sha256: 14b25ea8f21db0998a005561e8628a7c471d67bca9f62fb58c8dd9fdb11eb9de
spec_frozen_sha256: b78f96b35997765b8d0df90886d0169af2a5d210b054f8d082d914069367fd17
---

# PO-Briefing: feature-51-s2b-speichern

- **Spec:** DOCS/specs/features/feature-51-s2b-speichern.md
- **Issue:** #51
- **Erstellt:** 2026-11-21

## Was gebaut wird

Von Claude gelieferte Programme und Atemübungen werden dauerhaft gespeichert, erscheinen in den Listen und überstehen einen App-Neustart.

## Definition of Done

Eine per Testeinstieg gelieferte Übung erscheint in der Liste, bleibt nach Neustart erhalten, die Vorgaben bleiben unverändert, und die Rücknahme räumt sie wieder ab.

## Wie geprüft wird

Automatische Tests prüfen Speichern, Neustart, beschädigte Daten und Aktualisierung offener Listen; echte Lieferungen aus dem Dienst werden noch nicht getestet.

## Kritische Anmerkungen

- Schutz eigener Bearbeitungen (Zeitstempel) ist auf Runde 2b-2 verschoben; bis dahin ohne Wirkung.
- Info-Blatt für Claude-Übungen von 2b nach Schnitt 3 verschoben, nicht vom PO entschieden; nichts Sichtbares betroffen.
- Dass die Release-Version den Testeinstieg nicht enthält, ist behauptet, aber nicht getestet.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
