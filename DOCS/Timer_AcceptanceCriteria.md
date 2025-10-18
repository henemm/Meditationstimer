**18.10.2025 – Debug-Analyse nach Build:**
Die EndSession-Logik und die LiveActivityController-Aufrufe werden korrekt ausgeführt (siehe Debug-Ausgabe):
• engine.cancel() und engine.gong.stopAll() werden aufgerufen
• liveActivity.end(immediate: true) wird ausgeführt
• Session wechselt in den .finished-State

Trotzdem wird nach "Beenden" die Live Activity im Widget nicht entfernt und der Timer läuft weiter. Das Problem tritt immer auf, obwohl die cancelScheduled()-Logik jetzt wie im Workouts-Tab portiert ist und der Build fehlerfrei ist.

**Erkenntnis:**
Das Problem liegt tiefer im Zusammenspiel von State, Timer und Live Activity. Die EndSession- und Timer-Abbruch-Logik ist jetzt identisch mit WorkoutsView, aber das Widget/Live Activity wird nicht gestoppt. Es gibt keine offensichtlichen Build- oder Swift-Fehler mehr.

**Nächster Schritt:**
Weitere Analyse der LiveActivityController-Logik und des State-Managements im Atem-Tab. Prüfen, ob nach dem Aufruf von liveActivity.end(immediate: true) noch Timer- oder State-Updates ausgelöst werden, die die Live Activity reaktivieren.
### 18.10.2025
- Build erfolgreich, aber Fehler im AtemView immer vorhanden: Timer/Live Activity werden nach "Beenden" nicht gestoppt. Fehler tritt trotz korrekter EndSession-Logik und Build-Erfolg immer auf. Weitere Analyse und Debugging erforderlich.
# Timer Reparatur – Akzeptanzkriterien & Erkenntnisse

## AI Gedächtnis - Behobene Probleme

### AtemView Timer-Problem - Behoben am 18.10.2025

**Problem:** Live Activity wurde nicht automatisch beendet bei natürlichem Session-Ende, weil `.onChange(of: finished)` fehlte.

**Root Cause:** AtemView verwendet direkte State-Variablen (`@State private var finished = false`) statt SessionEngine. Als `finished = true` gesetzt wurde, wurde nur die UI auf "Fertig" umgeschaltet, aber keine automatische Session-Beendigung ausgelöst. In OffenView/WorkoutsView gibt es `.onChange(of: engine.state)` der automatisch `endSession()` aufruft.

**Lösung:** 
- `.onChange(of: finished)` Modifier hinzugefügt, der `endSession(manual: false)` aufruft wenn `finished` true wird
- Live Activity Beendigung in `endSession()` reaktiviert: `await liveActivity.end(immediate: true)`

**Kniff:** AtemView benötigte den gleichen automatischen Cleanup-Mechanismus wie die anderen Views, aber mit State-Variablen statt Engine-State.

---

## Live Activity Spezifikationen & Architektur

### Atem Live Activity Spec (aus ATem-LiveActivity-Spec.md)
**Zweck:** Sicherstellen, dass beim Start einer Atem-Session eine Live Activity gestartet/aktualisiert/beendet wird, ohne mehrere parallele Timer.

**Ablauf:**
1. Nutzer tippt Play → compute sessionEnd = now + preset.totalSeconds
2. Call `liveActivity.requestStart(title: preset.name, phase: 1, endDate: sessionEnd, ownerId: "AtemTab")`
   - `.started` → start local engine & UI overlay
   - `.conflict` → show Alert mit Optionen "Beenden & Starten" oder "Abbrechen"
   - `.failed` → start local engine anyway
3. Bei Phasewechseln: update nur emoji/icon, nicht countdown time
4. Bei Ende: call `await liveActivity.end()` and cleanup

**Visual:** Phase arrows (SF symbols: arrow.up/down/left/right) und timer in Dynamic Island.

### Live Activity Bug (aus LiveActivity-Bug-Spec.md)
**Problem:** Live Activity stoppt nicht nach "Beenden" - `end()` wird aufgerufen, aber sofort folgt `start()`/`requestStart()`.

**Hypothesen:**
1. Timer engine hat pending callbacks nach `end()`
2. Multiple LiveActivityController instances
3. Delayed Task/DispatchWorkItem triggert `start()` nach `end()`

**Reproduktion:** Start session → Press "Beenden" → check logs for `end()` followed by `start()` within <1s.

### Live Activity Concept (aus LiveActivity-Concept.md)
**Per-Tab Rendering:**
- **Offen:** Phases "Meditation"/"Besinnung" → emoji icons (🧘‍♂️ / 🍃)
- **Atem:** Phases Einatmen/Halten/Ausatmen → arrow symbols (up/left/down/right)
- **Workouts:** TBD

**UI Rules:** Phase icon ersetzt app icon in leading region, timer in trailing region.

### Timer Architektur (aus TIMER_ARCHITECTURE.md)
**Regel:** Maximal ein aktiver Timer/Live Activity gleichzeitig.
**Implementierung:** Jeder Tab kann eigene Timer-Engine verwenden.
**Ownership:** Tab ist verantwortlich für sauberes Beenden.
**Runtime-Guard:** Ownership-Prüfung in LiveActivityController mit `ownerId` (z.B. "AtemTab").

### Countdown Sync (aus CountdownSyncProjekt.md)
**Problem:** Ring-Anzeige und Live Activity zeigen unterschiedliche Restzeiten.
**Ursache:** Endzeit wird doppelt berechnet - einmal für Live Activity, einmal für Engine.
**Lösung:** Endzeit muss aus derselben Quelle kommen (Ring-Logik).

---

## Ziel
- Robuste, einheitliche Timer-Logik für alle Meditationstabs (Atem, Workouts, Offen)
- Der äußere Ring zeigt immer die Gesamtdauer der Session
- "Beenden" stoppt den Timer und entfernt die Live Activity im Widget garantiert
- Es darf immer nur eine Live Activity/Timer im Widget erscheinen
- UI bleibt konsistent und nachvollziehbar
- Die GUI darf nicht verändert werden (kein Layout-, Button-, oder Flow-Change)
- Jede Codeübergabe ist build-validiert

## Versuche & Erkenntnisse
	- Portierung der EndSession-Logik aus WorkoutsView nach AtemView
	- Build-Validierung nach jedem Schritt
	- Entfernen/Ändern von GongPlayer.stopAll(), engine.cancel(), Session-Start-Logik
	- Dual-Ring-UI und CircularRing-Parameter angepasst
	- Rücksetzung auf letzte stabile Commits

**18.10.2025 – onChange reaktiviert:**
.onChange(of: engine.state) reaktiviert, um phaseStart und phaseDuration für den inneren Ring (Phasen-Anzeige) zu setzen. Live Activity-Teile bleiben auskommentiert.
- Rücksetzung auf letzte stabile Commits:
	Erwartung: Timer- und Live Activity-Fehler werden durch Rückkehr zum letzten funktionierenden Stand behoben.
	Vorgehen: Mit Git auf Commit <SHA> zurückgesetzt, Build validiert, keine neuen Features oder Logikänderungen übernommen.
	Ergebnis: Fehlerbild bleibt bestehen – nach "Beenden" läuft der Timer weiter und/oder die Live Activity bleibt aktiv. Keine Verbesserung gegenüber vorherigem Stand.
	Erkenntnis: Der Fehler ist nicht durch einen einzelnen Commit entstanden, sondern steckt tiefer in der Logik oder im Zusammenspiel von State, Timer und Live Activity.
- Bisher konnte keiner dieser Ansätze das Problem lösen: Timer/Live Activity werden nach "Beenden" nicht gestoppt.

## Offene Probleme
- Timer im Atem-Tab muss nach "Beenden" garantiert gestoppt sein und die Live Activity entfernt werden
- Widget darf nie zwei Timer gleichzeitig anzeigen
- UI muss nach "Beenden" in den konsistenten Idle-State zurückkehren

## Nächste Schritte
1. Funktion testen: Timer auf Lockscreen/Dynamic Island nach "Beenden" entfernen (sollte jetzt weg sein, da kein Live Activity-Code).
2. Wenn Timer weg: Live Activity-Code war das Problem – nächsten Schritt: Timer von WorkoutsView übernehmen.
3. Wenn Timer bleibt: Externes Debugging für anderes System.

---
Letzte Aktualisierung: 18.10.2025
