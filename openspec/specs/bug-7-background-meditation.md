---
entity_id: bug_7_background_meditation
type: bug
created: 2026-04-22
updated: 2026-04-22
status: draft
---

# Bug #7 — Freie Meditation wird nicht im Hintergrund ausgeführt

> **⚠️ ÜBERHOLT (2026-09-22):** Die hier getroffene Entscheidung, den `onDisappear`-Aufruf mit
> einem `scenePhase`-Guard abzusichern, ist zurückgenommen worden. Siehe Abschnitt
> [„Revision 2026-09-22"](#revision-2026-09-22--guard-zurückgenommen) am Ende dieses Dokuments.
> Der übrige Text bleibt unverändert als Arbeitsstand von 2026-04-22 erhalten.

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

## Revision 2026-09-22 — Guard zurückgenommen

**Status der Entscheidung aus diesem Ticket: ZURÜCKGENOMMEN.**

Betroffen ist ausschließlich Punkt 1 des Abschnitts „Fix Approach" (der `scenePhase`-Guard im
`onDisappear` von `WorkoutProgramSessionCard`) sowie der darauf aufbauende dritte Punkt im
„Test Plan" („ruft `endSession` NICHT auf wenn `scenePhase` Background ist"). Beide sind überholt.
Punkt 2 (Entfernung des toten `resetSession`-Aufrufs in `OffenView`) bleibt gültig.

**Grund:** Der Guard beruhte auf einer Reihenfolge, die Apple nirgends zusichert — der Annahme,
`onChange(of: scenePhase)` feuere stets vor `onDisappear`. Unter iOS 26.5 feuert `onDisappear`
deterministisch VOR dem scenePhase-Update (3 von 3 Reproduktionen). Der Guard greift damit nicht
mehr: Die Sitzung wurde beim Hintergrund-Wechsel beendet und ein HealthKit-Eintrag mit falscher
(zu kurzer) Dauer geschrieben. Das damalige Adversary-Urteil `AMBIGUOUS` hat sich bestätigt.

**Korrekter Weg:** Entkopplung durch **ersatzlose Entfernung** des Guard-Konstrukts
(`@Environment(\.scenePhase)`, `@State isInBackground`, `.onChange(of: scenePhase)` und der
gesamte `.onDisappear`-Block mit `endSession(manual: true)`) — nicht Absicherung. Die Sitzung endet
nur noch über die beiden expliziten Wege: Abbruch-Knopf (xmark) und natürlicher Abschluss
(`onSessionEnd`). Das folgt dem Muster, das in `WorkoutsView.swift` und `AtemView.swift` bereits
gilt.

**Nachfolge-Spec:** `docs/specs/bugfix/BUG-25d-hintergrund-workout.md` (BUG-25d, Issue #25
Cluster D).

**Issue #13 („scenePhase-Guard ist timing-abhängig") wird damit gegenstandslos** — nicht nur
behoben: Ohne Guard existiert kein Reihenfolge-Problem mehr, das timing-abhängig sein könnte.

## Changelog

- 2026-04-22: Initial spec created (Bug #7)
- 2026-09-22: Entscheidung aus „Fix Approach" Punkt 1 (scenePhase-Guard) zurückgenommen; Abschnitt
  „Revision 2026-09-22" ergänzt, Verweis auf `docs/specs/bugfix/BUG-25d-hintergrund-workout.md`
  und auf die Gegenstandslosigkeit von Issue #13.
