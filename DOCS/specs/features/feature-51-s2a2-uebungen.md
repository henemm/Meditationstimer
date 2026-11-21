---
entity_id: feature-51-s2a2-uebungen
type: feature
created: 2026-11-21
updated: 2026-11-21
status: draft
workflow: feature-51-s2a2-uebungen
issue: 51
epic: 44
parent: feature-51-s2-bausteine-anwenden
---

# Runde 2a-2: Übungen aus einer Claude-Lieferung anwenden (#51, Schnitt 2a)

## Approval

- [ ] Approved

Freigabe dieser Rundenspec durch den PO.

## Purpose

Runde 2a-2 der freigegebenen Elternspec `DOCS/specs/features/feature-51-s2-bausteine-anwenden.md` umsetzen. Die Elternspec gilt vollständig (Regeln 1–14, ACs der Runde 2a-2, Zuschnitt, Definition of Done je Runde); diese Datei ergänzt nur drei Präzisierungen aus der Analyse, die die Elternspec offenlässt. Für Henning unsichtbar: `apply` hat auch in dieser Runde keinen Aufrufer.

## Source

- Analyse: `DOCS/context/feature-51-s2a2-uebungen.md`
- Elternspec: `DOCS/specs/features/feature-51-s2-bausteine-anwenden.md`
- Beleg Reihenfolge: `Contracts/deliveries/valid/program-before-exercise.json`

## Dependencies

| Abhängigkeit | Art | Hinweis |
|---|---|---|
| `ClaudeDelivery` (`ClaudeExercise`, `ClaudeItem`) | Upstream, nur lesen | `read` prüft die Kategorie nicht; ein unbekannter Wert erreicht `apply` |
| `ExerciseCategory` (`ExerciseInfo.swift`) | Upstream, nur lesen | Abbildung über Fallnamen (`CaseIterable`), Datei bleibt unverändert |
| `ExerciseDatabase.info(forId:)`, `WorkoutSet`/`WorkoutPhase` | Upstream, nur lesen | wie 2a-1 |
| Watch, Widget | Mitkompilierung | nur `Foundation`; Build aller drei Ziele in der DoD |

## Architektur-Entscheidung (ADR)

Gilt unverändert aus der Elternspec (Abschnitt „Architektur-Entscheidung (ADR)“, u. a. Übungen in `claudeState` statt im Übungskatalog). Diese Runde trifft keine neue Architektur-Entscheidung.

**ADR-Nr.:** keine neue (Verweis auf die ADR der Elternspec, Analyse 2026-11-20)

**Rationale:** Runde 2a-2 setzt nur den in der Elternspec entschiedenen Zuschnitt um; die drei Präzisierungen legen Prüfreihenfolge und Suchort fest, keine Struktur. **Alternative (verworfen):** `claude.*` nur aus bereits angewendeten Positionen auflösen; einfacher, scheitert aber an `program-before-exercise.json` und damit an AC-2 in 2a-3.

## Scope

Die zwei Dateien der Runde 2a-2 aus der Elternspec:

- `Meditationstimer iOS/Models/ClaudeApply.swift` (MODIFY: `ClaudeStoredExercise`, `exercises` im Zustand, `applyExercise`, `mapCategory`, Erweiterung `resolveStepName`)
- `LeanHealthTimerTests/ClaudeApplyTests.swift` (MODIFY)

Budget kalibriert rund 98 von 250 App-Zeilen. Nicht in Scope: alles aus 2a-3 (Rücknahme, Mindestanzahl, Round-Trip, Reinheits-Test, `claude-annahme.md`) und 2b.

## Präzisierungen (gelten zusätzlich zu den Regeln der Elternspec)

1. **Kategorie vor Revision (präzisiert Regel 12 der Elternspec):** Die Kategorie wird geprüft, bevor die `revision` verglichen wird. Eine unbekannte Kategorie lehnt die Lieferung mit `CATEGORY_UNKNOWN` ab, auch wenn die Position sonst ohne Wirkung wäre (gleiche oder niedrigere `revision`).
2. **`claude.*` aus jeder `exercise`-Position (präzisiert Regel 1 und Regel 10 der Elternspec):** „Übung derselben Lieferung“ ist jede `exercise`-Position der Lieferung, auch eine, die erst nach dem Programm in der Liste steht (Beleg `program-before-exercise.json`; Voraussetzung für AC-2 in 2a-3). Aufgelöst wird zuerst in den `exercise`-Positionen der Lieferung, dann in den Übungen der Arbeitskopie (`state.exercises`, einschließlich bereits angewendeter Positionen). Der Klammersatz in Regel 1 („ein Programm darf ab 2a-2 auf eine Übung derselben Lieferung zeigen“) ist in diesem Sinn zu lesen.
3. **`own.*` und Randfall (präzisiert Regel 1 und Regel 10 der Elternspec):** `own.*` wird wie in Regel 10 gegen die Phasen der Programme im Eingangszustand aufgelöst. Eine Auflösung über die Arbeitskopie brächte nichts Neues: Ein geliefertes Programm kann eine `own.*`-Phase nur erzeugen, wenn derselbe Verweis schon im Zustand auflöst. Randfall: Eine Übung derselben Lieferung mit gleicher oder niedrigerer `revision` (ohne Wirkung) und anderem Namen liefert trotzdem ihren Namen aus der Lieferung an die Programmphase (Regel 10 wörtlich).

Regel 8 bleibt unverändert: Übungen werden nie mit `CHANGED_ON_IPHONE` abgelehnt.

## Acceptance Criteria

Keine neuen ACs. AC-1b, AC-6b, AC-12, AC-13b und AC-16 gelten wörtlich aus der Elternspec, mit Zusätzen zu AC-13b und AC-16.

- **AC-1b (2a-2): Anlegen Übung mit Programm.** Given `Contracts/deliveries/valid/exercise-and-program.json` gelesen und leerer Zustand, When `apply`, Then Ergebnis `applied`; eine Übung im Zustand (Name, englische Kategorie, `claude.itemId`, `revision`, `why`), ein `WorkoutSet` mit Phasen, deren Namen aus der Übung derselben Lieferung stammen; Gedächtnis hat die `deliveryId`. Test: `testAnlegenUebungUndProgrammAusBeispielsatz`.
- **AC-6b (2a-2): Höhere Revision ersetzt Übung, gleiche oder niedrigere nicht.** Given Übung in `revision` 1, When `revision` 2, Then Inhalt ersetzt, `claude.revision` = 2, Anzahl gleich, `applied`. Given Übung in `revision` 2, When Lieferung mit `revision` 2 bzw. 1, Then Bausteine unverändert, `noEffect`. Tests: `testHoehereRevisionErsetztUebung`, `testUebungGleicheOderNiedrigereRevisionOhneWirkung`.
- **AC-12 (2a-2): `own.*`-Verweis.** Given ein Programm im Zustand mit Phase (`exerciseId` `own.x`, Name „Eigene“), When geliefertes Programm mit Schritt `own.x`, Then neue Phase trägt den Namen „Eigene“. Ohne passende Phase im Zustand: `rejected` mit `EXERCISE_UNKNOWN`, Bausteine unverändert. Beleg über `own-exercise-reference.json`. Tests: `testOwnVerweisLoestNamenAusVorhandenerPhaseAuf`, `testOwnVerweisOhnePhaseLehntMitExerciseUnknownAb`.
- **AC-13b (2a-2): `claude.*`-Verweis.** Given Schritt mit `claude.*`, Then Name aus der Übung derselben Lieferung, sonst aus `state.exercises`; in keinem von beiden: `EXERCISE_UNKNOWN`, Bausteine unverändert. Tests: `testClaudeVerweisNutztLieferungOderZustand`, `testClaudeVerweisUnbekanntLehntAb`. **Zusatz:** `testClaudeVerweisNutztLieferungOderZustand` deckt auch den Fall ab, dass die Übung in der Lieferung erst nach dem Programm steht (Beleg `program-before-exercise.json`); keine neue Testmethode, gleicher Name. Ebenso deckt er den Randfall aus Präzisierung 3 ab: Übung im Zustand in `revision` 2 mit Name „Alt“, Lieferung mit derselben Übung in `revision` 2 und Name „Neu“ plus Programm mit Schritt auf diese Übung → die Übung bleibt „Alt“ (ohne Wirkung), die neue Programmphase heißt „Neu“, Ergebnis `applied` (das Programm ist neu). (Der 2a-1-Test `testProgrammMitOwnOderClaudeVerweisLehntMitExerciseUnknownAb` wird im RED-Schritt gelöscht, weil das Verhalten sich bewusst ändert.)
- **AC-16 (2a-2): Kategorie.** Given jede der neun englischen Kategorien, When abgebildet, Then der jeweilige `ExerciseCategory`-Fall mit deutschem Rohwert, vollständig: `strength` → „Kraft“, `stretching` → „Dehnung“, `core` → „Core“, `cardio` → „Cardio“, `legs` → „Beine“, `upperBody` → „Oberkörper“, `fullBody` → „Ganzkörper“, `warmup` → „Aufwärmen“, `cooldown` → „Cool-Down“ (Quelle: `ExerciseInfo.swift`, `enum ExerciseCategory`; Lieferformat §3.1); `ClaudeStoredExercise` speichert den englischen Text; ein unbekannter Wert lehnt die Lieferung ab (`CATEGORY_UNKNOWN`, Bausteine unverändert). Tests: `testAlleNeunKategorienWerdenAbgebildet`, `testUnbekannteKategorieLehntMitCategoryUnknownAb`. **Zusatz:** `testUnbekannteKategorieLehntMitCategoryUnknownAb` deckt auch den Fall ab, dass die Übung mit unbekannter Kategorie dieselbe `revision` wie die gespeicherte hat.
- **AC-19 (jede Runde): Bestand bleibt grün und App-Budget eingehalten.** Die vollständige Unit-Suite `LeanHealthTimerTests` läuft grün; iOS, Watch und Widget bauen; der Produktiv-Diff der Runde (App-Code ohne Tests, Löschzeilen mitgezählt) liegt bei höchstens 250 Zeilen und keine Funktion über 50 Zeilen. Nachweis: Protokoll `Executed N tests` mit N ≥ 1, Build aller drei Ziele, Zeilenzahl des Produktiv-Diffs im Validierungsbericht.

## Test Plan

- [ ] 9 neue Tests in `ClaudeApplyTests`: `testAnlegenUebungUndProgrammAusBeispielsatz`, `testHoehereRevisionErsetztUebung`, `testUebungGleicheOderNiedrigereRevisionOhneWirkung`, `testOwnVerweisLoestNamenAusVorhandenerPhaseAuf`, `testOwnVerweisOhnePhaseLehntMitExerciseUnknownAb`, `testClaudeVerweisNutztLieferungOderZustand`, `testClaudeVerweisUnbekanntLehntAb`, `testAlleNeunKategorienWerdenAbgebildet`, `testUnbekannteKategorieLehntMitCategoryUnknownAb`
- [ ] Im RED-Schritt gelöscht (Verhalten ändert sich bewusst): `testUebungslieferungNochNichtUnterstuetzt`, `testProgrammMitOwnOderClaudeVerweisLehntMitExerciseUnknownAb`
- [ ] RED-Beleg: Übersetzungsfehler der Testdatei, weil `ClaudeStoredExercise` und das Feld `exercises` in `ClaudeApplyState` fehlen. Kein Gerüst im Produktivcode.
- [ ] Vollständige Unit-Suite `LeanHealthTimerTests` grün, `Executed N tests` mit N ≥ 1
- [ ] Kein UI-Test: Die Runde ändert nichts Gespeichertes und nichts Sichtbares (Begründung in der Elternspec, Test Plan)

## Definition of Done

- [ ] Build grün für iOS, Watch und Widget
- [ ] ACs der Runde als Unit-Tests grün, im Protokoll `Executed N tests` mit N ≥ 1
- [ ] Vollständige Unit-Suite grün
- [ ] Produktiv-Diff ≤ 250 Zeilen, Funktionen ≤ 50 Zeilen (AC-19)
- [ ] Adversary-Prüfung: Verdict VERIFIED, Diff-Durchsicht bestätigt (Teil „in jeder Runde“ von AC-18 der Elternspec: nur Dateien der Runde plus Specs/Docs, keine Änderung an `WorkoutTab.swift`, `MeditationTab.swift`, `ExerciseDatabase.swift`, `project.pbxproj`)

## Changelog

- 2026-11-21: Angelegt als Rundenspec, weil die Elternspec nach Abschluss von 2a-1 eingefroren ist.
- 2026-11-21: Nach Validierung (INVALID): Dependencies und ADR-Verweis ergänzt; Randfall aus Präzisierung 3 testbar gemacht (Zusatz in AC-13b).
- 2026-11-21: Nach zweiter Validierung (INVALID): ADR-Nr. und Rationale ergänzt; `own.*` bleibt beim Eingangszustand wie Regel 10 (Auflösung über die Arbeitskopie wäre nicht unterscheidbar, Zusatz in AC-12 gestrichen); Präzisierung 3 erweitert Regel 10 damit nicht mehr (Präzisierung 2 bleibt eine ausgewiesene Präzisierung von Regel 1 und 10).
