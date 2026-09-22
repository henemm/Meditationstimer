---
spec_file: docs/specs/bugfix/BUG-25d-hintergrund-workout.md
spec_sha256: 7ecbc5abca725215824f77ac12addcd39706eef4b210ba0bebc809e57945d0bb
---

# PO-Briefing: bug-25d-hintergrund-meditation

- **Spec:** docs/specs/bugfix/BUG-25d-hintergrund-workout.md
- **Issue:** #25 (Cluster D)
- **Erstellt:** 2026-09-22

## Was gebaut wird

Ein geführtes Workout läuft beim App-Wechsel im Hintergrund weiter, statt vorzeitig mit falscher Dauer zu enden.

## Definition of Done

Der bereits rote Hintergrund-Test wird grün, der Abbruch-Knopf funktioniert weiterhin, und ein durchlaufendes Workout schreibt die volle Dauer.

## Wie geprüft wird

Drei automatisierte Tests bestätigen es, einer läuft real bis zu 5 Minuten; ob die Anzeige sichtbar bleibt, bleibt ungeprüft.

## Kritische Anmerkungen

- Cluster D bleibt nur halb erledigt: der zweite rote Test (falsche Atem-Preset-Namen) wird nicht repariert, nur verschoben.
- Der neue Test hängt an einem bestimmten Workout-Programm und einer versteckten Anzeigeschwelle — beide könnten unbemerkt brechen.
- Ob die Live Activity beim Hintergrund-Wechsel sichtbar bleibt, kann kein Test beweisen — nur der HealthKit-Eintrag.

## Freigabe-Frage

Reicht es, den bekannten Fehler zu beheben, während der zweite kaputte Test in diesem Cluster offen bleibt?
