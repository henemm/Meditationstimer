# Kontext: fix-35-workout-sitzung (#35)

**Erstellt:** 2026-11-26 · Phase 1 (Kontext) · Score 4 (voller Prozess, Analyse getrennt)

## Request Summary

Ob ein **geführtes Workout-Programm** die richtige Dauer in HealthKit schreibt, ist heute weder per UI-Test
(Simulator schreibt nie einen Eintrag) noch per Unit-Test (Logik steckt inline in der View) prüfbar.
Ziel: Sitzungsführung (Start, Ende, Dauer, Schreibauftrag) prüfbar machen — Weg A (Typ herauslösen) oder
B (Schreibweg einspeisbar). Nebenpunkt: klären, warum im Simulator nie ein Eintrag entsteht.
Voraussetzung für #49 (Mac A3 Tagebuch: braucht Programm-Kennung, Dauer, beendet/abgebrochen).

## Related Files

| Datei | Rolle |
|---|---|
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` (1843 Z.) | `WorkoutProgramSessionCard` (417): State 431–440, `beginSessionAfterCountdown` 668–689, `endSession(manual:)` 691–754, `togglePause` 756–819; `ProgressRingsView` (823) mit Phasen-Timer 1078–1234 |
| `Meditationstimer iOS/Tabs/WorkoutTab.swift` | einziger Aufrufer der Session-Card (247); freies Workout mit gleichem Inline-Muster (397, 412, 738–775); Health-Berechtigungsprüfung nur dort (351–361, 174–183, 530) |
| `Services/HealthKitManager.swift` | Singleton, kein Protokoll; `logWorkout(start:end:activity:)` 176, `relateEffortScore` 844, `requestAuthorization` 71–141, `isAuthorized` 266–311 |
| `Services/TwoPhaseTimerEngine.swift` | Vorbild für herausgelösten, getesteten Zeittyp (ObservableObject, `private(set)` Zeitpunkte) |
| `LeanHealthTimerTests/SessionDurationTests.swift` | Zeilen 30–36: dokumentiert, dass der Programm-Weg nicht prüfbar ist |
| `LeanHealthTimerTests/HealthKitManagerTests.swift` 378–420 | `MockHealthKitManager`, an nichts angebunden |
| `Meditationstimer iOS/LiveActivityController.swift` | `@MainActor`, Live Activity start/update/end aus der Card |

## Existing Patterns

- `TwoPhaseTimerEngine`: einziger herausgelöster Zeittyp, getestet in `TwoPhaseTimerTests`, `SessionDurationTests`.
- Alle anderen Sitzungsarten (freies Workout, Atem, Meditation) schreiben ebenfalls inline aus der View; kein gemeinsamer Sitzungstyp.
- Testziel `LeanHealthTimerTests`: synchronisierter Ordner, `@testable import Lean_Health_Timer`, Produktivcode kommt über den Host.

## Befunde (aus Code gelesen, nicht zur Laufzeit belegt)

1. **Pausen werden nicht abgezogen:** HealthKit bekommt nur `sessionStart` … `Date()`; `pausedSessionAccum` dient nur UI/Live Activity. Live Activity zieht Pausen ab, HealthKit nicht. Kalorien ebenfalls über die volle Spanne.
2. **Endzeit enthält Wartezeit:** `endDate = Date()` (722) erst *nach* Live-Activity-Ende und Schlussgong-Sleep (712–716) bzw. 0,3 s bei Abbruch. Freies Workout nimmt `Date()` *vor* dem Gong (WorkoutTab 740) — uneinheitlich.
3. **Countdown landet evtl. in der Dauer:** `sessionStart` wird beim Erzeugen der View gesetzt und in `beginSessionAfterCountdown` nicht neu gesetzt.
4. **Doppelaufruf-Fenster:** `sessionEnded`-Wächter (695) wird erst nach zwei `await` gesetzt.
5. **Hintergrund:** `endSession` wird im Hintergrund nie aufgerufen (Guard 564, gemessen in BUG-25d).

## Simulator-Nebenpunkt — stärkste Spur

Der Programm-Weg fragt **nie** nach Health-Berechtigung: Play setzt direkt `runningSet` (WorkoutTab 95); nur das freie
Workout prüft `isAuthorized()` / zeigt den Hinweis. `logWorkout` läuft im frischen Simulator ohne Freigabe, wirft, der Fehler
wird nur per `print` geschluckt (WPV 744–745). Passt zu „kein Berechtigungsblatt, 0 Workouts“. Entitlement vorhanden;
Usage-Descriptions als `INFOPLIST_KEY_*` (pbxproj 946–947) neben explizitem `INFOPLIST_FILE` (942) — prüfen, ob sie im
gebauten Info.plist ankommen. **Noch zu reproduzieren** (Analyse-Phase).

## Dependencies / Dependents

- Card hängt an `LiveActivityController`, `StreakManager` (App-Target, `@MainActor`), `fileprivate SoundPlayer` (WPV 52), `HealthKitManager.shared`.
- Nach erfolgreichem Schreiben: `streakManager.updateStreaks()`, Effort-Sheet (iOS 18) oder `close()`.
- #49 braucht aus dem Sitzungstyp: Programm-Kennung, Dauer, beendet vs. abgebrochen (`manual`).

## Existing Specs

- `DOCS/specs/bugfix/BUG-25d-hintergrund-workout.md` (Einschränkung 295–348, Abgrenzung 411–420; Zeilenverweis 983 jetzt 722)
- `openspec/specs/integrations/healthkit.md` (Workout-Szenarien 19–27, 153–156), `openspec/specs/features/workouts.md`, `workout-phase-timer-live-activity.md`
- Artefakte nur im Haupt-Repo: `DOCS/artifacts/bug-25d-hintergrund-meditation/`

## Risks

- **Umfang Weg A:** ~150–250 LoC verschoben (State, endSession, togglePause, Live-Activity-Zeitrechnung; Phasen-Engine aus ProgressRingsView weitere ~160) → Schnitt nötig, sonst Grenze 250 LoC gesprengt.
- **Zielmitgliedschaft:** `Services/` ist kein synchronisierter Ordner → neue Datei braucht pbxproj-Eintrag; unter `Meditationstimer iOS/` landet sie automatisch auch im Watch-Ziel, falls keine Ausnahme.
- **Concurrency:** Sitzungstyp sollte `@MainActor` sein und über Protokolle an HealthKit/Live Activity hängen.
- **Semantik offen (PO-Frage):** Sollen Pausen, Countdown und Schlussgong-Wartezeit in die geschriebene Dauer zählen? Heute zählen sie (unbeabsichtigt) mit.

## Analysis

**Type:** Feature (Prüfbarkeit / Refactor) mit Bug-Nebenpunkt (Simulator-Schreibweg)

### Strategische Bewertung (Plan-Agent, im Code verifiziert)

| | A voller Sitzungstyp | B nur Schreib-Protokoll | **A' Uhr-Werttyp + Schreib-Protokoll** |
|---|---|---|---|
| App-Dateien | 4–5 | 2–3 | 3–4 |
| App-LoC | 200–300 (Grenzrisiko) | 40–60 | **90–130** |
| Beweisbar | alles inkl. Live Activity | nur „logWorkout wurde gerufen“ — Zeiten bleiben inline, **Ziel verfehlt** | Start/Ende/aktive Dauer/Pausen/Grund/Doppelaufruf, mit Fake-Uhr; nicht: dünner View-Klebstoff |
| #49 bereit | ja | nein | weitgehend (programId + Grund ins Ergebnis) |

**Empfehlung:** A' in Schnitten.
- **Schnitt 1 (diese Runde, reiner Umbau):** `WorkoutSessionClock` (Sendable struct: start, pause, resume, end, activeDuration, reason) + Protokoll `WorkoutLogging` (HealthKitManager konform, Fake im Test). View nutzt beides mit **heutiger** Semantik; Charakterisierungstests halten das heutige Verhalten fest. ~100–130 LoC, 4 Dateien. Sleeps/Gong/Live Activity bleiben in der View.
- **Schnitt 2 (PO-Entscheidung):** Semantik umschalten, je Punkt einzeln, sichtbar im Testdiff.
- **Schnitt 3:** #49-Felder (programId, beendet/abgebrochen) + Ablage fürs Tagebuch.
- **Schnitt 4 (später, optional):** Phasen-Engine aus ProgressRingsView (~160 LoC), Live-Activity-Rechnung.

**Risiken:** Live-Activity-Rechnung 3× dupliziert (492, 766, 807) — in Runde 1 in der View lassen. `sessionStart` steuert auch Ringe/Phasen (463, 876) → Countdown-Korrektur ist Verhaltensänderung, kein Umbau. pbxproj: `Services/` nicht synchronisiert → Datei nur ins iOS-Ziel eintragen, Build des Testziels prüft Mitgliedschaft. Uhr als struct in `@State` vermeidet MainActor-Init-Warnungen.

### PO-Entscheidungen (Verhalten, nicht Umbau)
1. Pausen in der geschriebenen Dauer? (betrifft auch kcal: 12 kcal/min × Zeit) — Alternative 1b: Pausen als `HKWorkoutEvent` (pause/resume) über den Builder schreiben, Start/Ende bleiben ehrlich, Health rechnet aktive Dauer.
2. Countdown mitzählen? (hängt an Phasen-/Ringlogik)
3. Endzeit vor oder nach dem Schlussgong? (heute: nach Gong + 0,3 s; freies Workout: vor Gong — uneinheitlich)
4. 3-s-Mindestschwelle auf Wandzeit oder aktive Zeit?
5. Berechtigungsabfrage/Hinweis auf dem Programm-Weg (eigene Runde/Issue)

**Doppelaufruf-Wächter** (`sessionEnded` erst nach zwei `await`): Fehlerkorrektur ohne sichtbare Änderung außer „kein doppelter Eintrag“ — als benannter Fix, nicht versteckt im Umbau.

### Simulator-Nebenpunkt — geklärt (nachgestellt 2026-11-26)

- **Ursache belegt:** Programm-Weg fragt nie nach Health-Freigabe (`WorkoutTab.swift:95`). Einzige Startabfrage deckt nur Achtsamkeit (`PhoneMindfulnessReceiver.swift:39-44`). Ohne Trainings-Freigabe verwirft healthd den Builder (`Active -> Discarded`), 0 Workouts; Fehler nur per `print` (WPV 744–745).
- **Gegenprobe:** volle Freigabe (Blatt im Erfolge-Tab, `CalendarView.swift:321`) → 1 Workout.
- Info.plist-Texte und Entitlement sind vorhanden (H2 widerlegt).
- **Produktfehler auf echten Geräten:** ja, eng begrenzt → eigenes Issue **#122**, nicht Teil von #35.
- Simulator-Laufzeit ist iOS **27.2** (CLAUDE.md sagt noch 26.5; Skript nutzt 27.2).
- Belege: Sitzungs-Scratchpad `sim35/` (run1 = 0 Workouts, db8 = 1 Workout).

### Festlegung für die Spec (Schnitt 1)

- Weg **A'**: `WorkoutSessionClock` (reiner Werttyp) + Protokoll `WorkoutLogging`, View nutzt beides, **Verhalten unverändert**.
- Charakterisierungstests halten heutiges Verhalten fest (Pausen zählen mit, Endzeit nach Gong, Start bei View-Erzeugung).
- Nicht in Schnitt 1: Semantik-Änderungen (PO-Fragen 1–4, Schnitt 2), Doppelaufruf-Wächter (Schnitt 2, benannter Fix), Freigabe-Abfrage (#122), #49-Felder (Schnitt 3), Phasen-Engine (Schnitt 4).

### Open Questions
- Keine für Schnitt 1 (reiner Umbau ohne sichtbare Änderung). PO-Fragen 1–4 werden vor Schnitt 2 gestellt.
