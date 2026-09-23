---
entity_id: bug_7_background_meditation
type: bug
created: 2026-04-22
updated: 2026-09-23
status: draft
---

# Bug #7 — Freie Meditation wird nicht im Hintergrund ausgeführt

> **⚠️ TEILWEISE ÜBERHOLT (2026-09-23):** Die Ursachenannahme dieses Tickets („`onDisappear`
> beendet die Sitzung beim Wechsel in den Hintergrund") ist durch Messung widerlegt. Der
> `scenePhase`-Guard aus „Fix Approach" Punkt 1 **steht jedoch weiterhin im Code**: Er wurde am
> 2026-09-23 kurzzeitig entfernt und noch am selben Tag durch Entscheidung des Product Owners
> wiederhergestellt, weil die Entfernung eine gemessene Regression erzeugte. Siehe Abschnitt
> [„Revision 2026-09-23"](#revision-2026-09-23--ursachenannahme-widerlegt-guard-entfernung-zurückgenommen) am Ende dieses Dokuments.
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

## Revision 2026-09-23 — Ursachenannahme widerlegt, Guard-Entfernung zurückgenommen

**Stand nach Entscheidung des Product Owners vom 2026-09-23:** Der `scenePhase`-Guard aus
„Fix Approach" Punkt 1 **bleibt im Code**; seine Entfernung (Commit `1d7d14e`) ist
**zurückgenommen**. Die *Begründung* dieses Tickets bleibt gleichwohl widerlegt: Der Guard
verhindert nicht das, wofür er gebaut wurde — gebraucht wird der `onDisappear`-Pfad aus einem
anderen Grund (siehe „Was die Entfernung angerichtet hat").

Überholt ist damit der dritte Punkt im „Test Plan" („ruft `endSession` NICHT auf wenn `scenePhase`
Background ist"): Dieser Pfad wird beim Hintergrund-Wechsel gar nicht erst erreicht, die Prüfung
liefe ins Leere. Punkt 2 des „Fix Approach" (Entfernung des toten `resetSession`-Aufrufs in
`OffenView`) bleibt gültig.

### Was gemessen wurde — und was dadurch hinfällig ist

Die Ursachenannahme dieses Tickets („`onDisappear` beendet die Sitzung beim Wechsel in den
Hintergrund") ist **durch Messung widerlegt**. Eine temporäre Protokollierung an allen Stellen,
die eine Sitzung beenden könnten, zeigt über drei Durchgänge (iOS 26.5, iPhone 17 Pro) identisch:
Beim Hintergrund-Wechsel feuert `onDisappear` **gar nicht**, `endSession` wird **nicht** gerufen,
es wird **kein** HealthKit-Eintrag geschrieben. Die Sitzung lief unverändert weiter.
Beleg: `DOCS/artifacts/bug-25d-hintergrund-meditation/diagnose-endSession-aufrufe.txt`.

Damit entfällt auch die Grundlage für die Größenordnung im Abschnitt „Blast Radius" (falsche
HealthKit-Dauer beim Hintergrund-Wechsel): dieser Pfad wird beim Hintergrund-Wechsel nie
durchlaufen.

Die roten UI-Tests, die dieses Ticket seinerzeit ausgelöst haben (Issue #25, Cluster D), waren
**Testschuld**, kein Produktfehler: Sie prüften auf `app.buttons["Start"]`. Dieser Knopf gehört zur
Programmliste hinter der Sitzungs-Karte, die nur weich ausgeblendet wird (Unschärfe +
Antipp-Sperre) und deshalb dauerhaft im Bedienhilfen-Baum liegt — unabhängig davon, ob eine
Sitzung läuft oder nicht. Der Test prüfte also etwas, das sich nie ändert.
Nachfolge-Spec: `DOCS/specs/bugfix/BUG-25d-hintergrund-workout.md` (BUG-25d).

### Was mit dem Guard geschehen ist

Das Guard-Konstrukt (`@Environment(\.scenePhase)`, `@State isInBackground`,
`.onChange(of: scenePhase)` und der `.onDisappear`-Block mit `endSession(manual: true)`) wurde am
2026-09-23 mit Commit `1d7d14e` ersatzlos entfernt — als Aufräumen, nicht als Fehlerbehebung. Die
anschließende Regressionsprüfung (nächster Abschnitt) zeigte, dass der Block im **Vordergrund**
gebraucht wird. **Die Entfernung ist daraufhin am selben Tag zurückgenommen worden**; die Datei
entspricht wieder dem Stand vor `1d7d14e`.

Beibehalten wurde aus der Aufräumarbeit nur eine Korrektur: Der Kommentar im `onDisappear`
behauptete eine Ausführungsreihenfolge („`isInBackground` is set via `.onChange` which fires before
`.onDisappear`"), die Apple nirgends zusichert und die nie gemessen wurde. Er ist durch den
tatsächlichen Befund ersetzt — beim reinen Hintergrund-Wechsel feuert `onDisappear` gar nicht, der
Guard ist dort wirkungslos, aber unschädlich; nötig ist der Pfad für die beiden
Vordergrund-Fälle.

Die frühere Fassung dieses Abschnitts behauptete, unter iOS 26.5 feuere `onDisappear`
„deterministisch VOR dem scenePhase-Update (3 von 3 Reproduktionen)" und es werde dabei „ein
HealthKit-Eintrag mit falscher (zu kurzer) Dauer geschrieben". **Das war falsch** und widersprach
dem eigenen Messbeleg. Die Behauptung ist hiermit zurückgezogen.

### Was die Entfernung angerichtet hat — der Grund für die Rücknahme (2026-09-23)

Die Entfernung war **nicht folgenlos**. Der `onDisappear`-Block feuert zwar nicht beim
Hintergrund-Wechsel, wohl aber bei zwei erreichbaren **Vordergrund**-Fällen. In beiden war er die
einzige Aufräumstelle. Gemessen am Stand `1d7d14e`, Beleg:
`DOCS/artifacts/bug-25d-hintergrund-meditation/regressionspruefung-reiterwechsel.txt`.

1. **Programmatischer Reiterwechsel** (Kurzbefehl/Deep-Link, `ContentView.swift`
   `onOpenURL` → `ShortcutHandler.handle` setzt `selectedTab`). Die Reiterleiste ist während einer
   Sitzung ausgeblendet, ein programmatischer Wechsel umgeht das. Gemessen, 4 von 4 Durchgängen:
   Der Wechsel findet statt, die App ist dabei durchgehend im Vordergrund (`app=active`),
   `card.onDisappear` feuert ~1,5 s später, `endSession` wird nie gerufen.
2. **Abgebrochener Startvorlauf** (Einstellung „Countdown vor Start" > 0, dann „Abbrechen").
   `close()` leert `runningSet` direkt, ohne `endSession`.

Zurück bleibt in beiden Fällen eine Geistersitzung: Leerlaufsperre bleibt aktiv (der Bildschirm
sperrt nicht mehr von selbst), Live Activity bleibt offen, `runningSet` bleibt gesetzt, kein
HealthKit-Eintrag. Kehrt man in Fall 1 auf den Workout-Reiter zurück, läuft `card.task` ein zweites
Mal — erneuter Auftakt-Gong, zweite Live Activity über derselben Kennung. In 3 von 4 Durchgängen
ließ sich der Workout-Reiter danach überhaupt nicht mehr betreten.

### Gegenprobe nach der Rücknahme (2026-09-23) — gemessen, nicht behauptet

Der wiederhergestellte Stand ist mit demselben Aufbau nachgemessen worden, mit dem die Regression
festgestellt wurde. Beleg:
`DOCS/artifacts/bug-25d-hintergrund-meditation/gegenprobe-ruecknahme-guard.txt`.

**Szenario A (Deep-Link während laufender Sitzung), 4 von 4 Durchgängen identisch:**
`card.onDisappear` wird erreicht (`isInBackground=false`, `app=active`), der Guard lässt durch,
`endSession(manual: true)` wird gerufen (`sessionEnded=false`, also kein Doppelaufruf), und
`setIdleTimer(false)` kippt die Leerlaufsperre in derselben Zeile von `idle=true` auf
`idle=false`. Die Sitzungskarte ist danach weg. Am Stand `1d7d14e` wurde in denselben 4 von 4
Durchgängen `endSession` **nie** gerufen und `idle` blieb dauerhaft `true`.

**Szenario B (abgebrochener Startvorlauf), 1 Durchgang:** gleiches Bild — Guard durchgelassen,
`endSession` gerufen, `idle` von `true` auf `false`.

Belastbarkeit, offen gesagt: Szenario A beruht auf **einem** sauberen Lauf mit vier Durchgängen
(Runner-PID 24380, 153 s, Ergebnisbündel `…2026.09.23_10-31-45…xcresult`), Szenario B auf **einem**
Durchgang. Zwei frühere Anläufe sind an der Vorbedingung des Testgerüsts gescheitert und ein
dritter war unbrauchbar, weil zeitgleich ein zweiter Agent Oberflächentests auf demselben
Simulator ausführte — alle drei sind Messfehler, keine Produktbefunde, und im Beleg benannt.

Ein Nebenbefund aus dem Aufbau ist **nicht** weiterverfolgt worden und liegt als Issue **#36** vor:
Die Sondenzeile in der `play:`-Closure der Programmliste feuert nie, obwohl die Sitzungskarte
erscheint — es gibt also einen zweiten Weg, `runningSet` zu setzen.

**Issue #14 („Zombie-Session bei Deep-Link während Background") wird durch die Rücknahme *nicht*
ausgeweitet.** Der oben beschriebene Zustand gehört zum Stand `1d7d14e` und ist mit der
Wiederherstellung beseitigt. Es gilt wieder die Aussage der Nachfolge-Spec: Der Stand lässt #14
weder gelöst noch verschärft.

**Issue #13 („scenePhase-Guard ist timing-abhängig") bleibt offen** — den Guard gibt es weiterhin.
Die frühere Aussage, #13 werde gegenstandslos, ist hinfällig. Gemessen ist bisher nur, dass der
Guard beim reinen Hintergrund-Wechsel nie erreicht wird; ob die dort vermutete
Reihenfolge-Abhängigkeit in anderen Fällen besteht, ist **weder bewiesen noch widerlegt**.

## Changelog

- 2026-04-22: Initial spec created (Bug #7)
- 2026-09-22: Entscheidung aus „Fix Approach" Punkt 1 (scenePhase-Guard) zurückgenommen; Abschnitt
  „Revision" ergänzt.
- 2026-09-23: Revisions-Abschnitt berichtigt. Die dort zuvor als Messergebnis dargestellte Ursache
  („`onDisappear` feuert vor dem scenePhase-Update, HealthKit-Eintrag mit falscher Dauer") war
  falsch und ist zurückgezogen — sie widersprach dem eigenen Messbeleg. Ergänzt: Entfernung des
  Guards als Aufräumen statt Fehlerbehebung, Testschuld als tatsächliche Ursache der roten
  Cluster-D-Tests, nachgemessene Nebenwirkung im Vordergrund (Geistersitzung bei Reiterwechsel und
  abgebrochenem Startvorlauf) samt Ausweitung von Issue #14, und die Klarstellung zu Issue #13.
- 2026-09-23 (Entscheidung des Product Owners): Die Guard-Entfernung ist **zurückgenommen** — sie
  erzeugte in 4 von 4 gemessenen Durchgängen eine Regression im Vordergrund (Geistersitzung bei
  programmatischem Reiterwechsel und abgebrochenem Startvorlauf). Die Datei entspricht wieder dem
  Stand vor `1d7d14e`; übernommen wurde nur die Korrektur des Kommentars über die
  Callback-Reihenfolge, der eine von Apple nicht zugesicherte Annahme behauptete und jetzt den
  gemessenen Befund festhält. Daraus folgt: **#13 bleibt offen** (den Guard gibt es weiterhin; die
  frühere Aussage „gegenstandslos" ist hinfällig), **#14 wird nicht ausgeweitet** (der gemeldete
  Zustand gehört zu `1d7d14e` und ist beseitigt). Die übrigen Berichtigungen — widerlegte
  Ursachenannahme, Cluster D als Testschuld — bleiben unverändert bestehen. Die Rücknahme ist
  gegengemessen: `gegenprobe-ruecknahme-guard.txt` (Szenario A 4 von 4, Szenario B 1 Durchgang —
  Guard durchgelassen, `endSession` gerufen, Leerlaufsperre zurückgesetzt).
