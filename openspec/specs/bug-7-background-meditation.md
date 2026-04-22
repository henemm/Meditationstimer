---
entity_id: bug_7_background_meditation
type: bug
created: 2026-04-22
updated: 2026-04-22
status: draft
---

# Bug #7 — Freie Meditation wird nicht im Hintergrund ausgeführt

## Approval

- [ ] Approved

## Purpose

Aktive Sessions (insbesondere Geführtes Workout) werden beim Wechsel in den App-Hintergrund beendet, weil `onDisappear`-Handler bedingungslos `endSession` bzw. `resetSession` aufrufen. Der Fix entfernt diese unbeabsichtigten Kills und bereinigt toten Code in OffenView.

## Affected Files

- `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` — `onDisappear` in `WorkoutProgramSessionCard` (Zeilen 804–809) ruft `endSession(manual: true)` auf, BESTÄTIGT als Root Cause
- `Meditationstimer iOS/Tabs/OffenView.swift` — `onDisappear` (Zeile 480–483) ruft `resetSession(logPartialSession: true)` auf, OffenView ist kein aktiver Tab mehr (toter Code)

## Expected Behavior

- Input: User startet eine Session (z.B. Geführtes Workout), wechselt die App in den Hintergrund und kehrt zurück
- Output: Session läuft nach Rückkehr in den Vordergrund weiter; Timer zeigt korrekte verstrichene Zeit; keine Session wurde vorzeitig beendet
- Side effects: Kein unbeabsichtigter HealthKit-Log mit falscher Dauer; Live Activity bleibt konsistent mit App-State

## Root Cause

`WorkoutProgramSessionCard.onDisappear` feuert beim Scene-Übergang (Background/Foreground) und ruft bedingungslos `endSession(manual: true)` auf. Das beendet die laufende Session, obwohl der User sie nicht manuell gestoppt hat.

`OffenView.onDisappear` enthält identisches Muster mit `resetSession`, ist aber inaktiv (View wird nicht mehr als Tab angezeigt); der Code ist Aufräum-Kandidat.

## Fix Approach

1. `WorkoutProgramsView.swift`: `onDisappear`-Block so absichern, dass `endSession` nur aufgerufen wird, wenn der User tatsächlich die View per Navigation verlässt — nicht beim Scene-Übergang in den Hintergrund. Konkret: Bedingung prüfen ob die Session noch aktiv ist UND ob die Scene wirklich verlassen wird (z.B. via `scenePhase != .background`), oder den `endSession`-Aufruf aus `onDisappear` entfernen und nur noch über explizite Stop-Buttons auslösen.
2. `OffenView.swift`: `onDisappear`-Block mit `resetSession` entfernen (toter Code, kein aktiver Tab).

**Out of Scope für dieses Ticket:** Background-Recovery (Timer-Resync nach Rückkehr aus Hintergrund) für alle 4 Views — das ist ein separates Feature-Issue.

## Test Plan

- [ ] UI Test: Geführtes Workout starten → App in Hintergrund schicken → zurückkehren → Session ist noch aktiv und Timer läuft
- [ ] UI Test: Geführtes Workout starten → Stop-Button tippen → Session wird korrekt beendet (Regression: expliziter Stop muss weiterhin funktionieren)
- [ ] Unit Test: `WorkoutProgramSessionCard` ruft `endSession` NICHT auf wenn `scenePhase` Background ist
- [ ] Unit Test: `OffenView` hat keinen `resetSession`-Aufruf in `onDisappear` mehr

## Blast Radius

| System | Schweregrad | Details |
|--------|-------------|---------|
| HealthKit | SCHWER | Falsche Dauer wird geloggt (geplante statt tatsächliche Zeit) |
| Streaks | MITTEL | Streak-Tage könnten fehlen oder falsch gezählt werden |
| Live Activity | MITTEL | Zeigt "läuft" obwohl App intern idle ist |

## Changelog

- 2026-04-22: Initial spec created (Bug #7)
