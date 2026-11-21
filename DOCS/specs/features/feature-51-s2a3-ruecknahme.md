---
entity_id: feature-51-s2a3-ruecknahme
type: feature
created: 2026-11-21
updated: 2026-11-21
status: draft
workflow: feature-51-s2a3-ruecknahme
issue: 51
epic: 44
parent: feature-51-s2-bausteine-anwenden
---

# Runde 2a-3: Rücknahme einer Claude-Lieferung anwenden (#51, Schnitt 2a)

## Approval

- [ ] Approved

Freigabe dieser Rundenspec durch den PO.

## Purpose

Runde 2a-3 der freigegebenen Elternspec `DOCS/specs/features/feature-51-s2-bausteine-anwenden.md` umsetzen, die letzte Runde von Schnitt 2a: Rücknahme einzeln (`itemId`) und als Paket (`packageId`), dazu die Abschlussprüfungen (alle lesbaren Beispiele, Round-Trip, Reinheit). Die Elternspec gilt vollständig (Regeln 1–14, ACs der Runde 2a-3, Zuschnitt, Definition of Done je Runde); diese Datei ergänzt nur fünf Präzisierungen aus der Analyse, die die Elternspec offenlässt. Für Henning unsichtbar: `apply` hat auch in dieser Runde keinen Aufrufer.

## Source

- Analyse: `DOCS/context/feature-51-s2a3-ruecknahme.md` (Tech-Lead-Festlegungen, Nachprüfung 2026-11-21)
- Elternspec: `DOCS/specs/features/feature-51-s2-bausteine-anwenden.md` (Regeln 8 und 9, Anmerkung 4, Runde 2a-3)
- Vertrag: `openspec/specs/integrations/claude-lieferformat.md` §3.4 (Rücknahme: genau eines von `itemId` und `packageId`, beide oder keins ist `WITHDRAWAL_TARGET`)
- Beispiele: `Contracts/deliveries/valid/withdraw-item.json`, `withdraw-package.json`, `package-with-withdrawal.json`; ungültig: `Contracts/deliveries/invalid/withdrawal-both.json`, `withdrawal-none.json`

## Dependencies

| Abhängigkeit | Art | Hinweis |
|---|---|---|
| `ClaudeDelivery` (`ClaudeWithdrawal` mit `itemId`, `packageId`, `ClaudeItem.withdrawal`) | Upstream, nur lesen | `read` prüft „genau eines“ nicht; beide oder keins erreichen `apply` |
| `ClaudeApplyState`, `ClaudeOrigin` (`itemId`, `packageId`), `isBlockedByIphone`, `changedOnIphone` | Bestand aus 2a-1/2a-2, wiederverwendet | keine neuen Typen |
| `WorkoutSet`, `AtemView.Preset` (`claude`, `modifiedAt`) | Upstream, nur lesen | Ziel der Rücknahme neben `state.exercises` |
| `openspec/specs/features/claude-annahme.md` | Doku, wird nachgezogen | siehe Definition of Done |
| Watch, Widget | Mitkompilierung | nur `Foundation`; Build aller drei Ziele in der DoD |

## Architektur-Entscheidung (ADR)

Gilt unverändert aus der Elternspec (Abschnitt „Architektur-Entscheidung (ADR)“, u. a. reine Funktion mit explizitem Zustand, Übungen in `claudeState`, keine Wiederherstellung). Diese Runde trifft keine neue Architektur-Entscheidung.

**ADR-Nr.:** keine neue (Verweis auf die ADR der Elternspec, Analyse 2026-11-20)

**Rationale:** Runde 2a-3 setzt nur den in der Elternspec entschiedenen Zuschnitt um; die Präzisierungen legen Prüfreihenfolge, Treffermenge und Schutzverhalten fest, keine Struktur. Erst Treffermenge, dann Sperrprüfung, dann Entfernen ist die einfachste Form von „ganz oder gar nicht“, weil bei einer Ablehnung noch nichts entfernt ist. **Alternative (verworfen):** Je Baustein sofort entfernen, sobald er gefunden ist. Das bricht „ganz oder gar nicht“ bei der Paket-Rücknahme, wenn ein späterer Baustein des Pakets gesperrt ist und die Arbeitskopie schon teilweise geleert wäre. **Alternative (verworfen):** `read` um die Prüfung `WITHDRAWAL_TARGET` erweitern, damit `apply` den Schutzfall nie sieht. Das wäre eine andere Datei (`ClaudeDelivery.swift`) und ein anderer Schnitt; der Dienst weist solche Lieferungen vor der App ab (Vertrag §3.4), und `apply` verhält sich für den Fall, dass sie trotzdem ankommen, definiert statt abstürzend.

## Scope

Die drei Dateien der Runde 2a-3 aus der Elternspec:

- `Meditationstimer iOS/Models/ClaudeApply.swift` (MODIFY: `applyWithdrawal`, Anschluss `.withdrawal` im `switch` von `apply`)
- `LeanHealthTimerTests/ClaudeApplyTests.swift` (MODIFY)
- `openspec/specs/features/claude-annahme.md` (MODIFY, nur Doku, siehe Definition of Done)

Budget kalibriert rund 45 von 250 App-Zeilen. Neue Typen braucht die Runde nicht. Nicht in Scope: Schnitt 2b (Speicher, Laden und Schreiben, Neu-Laden der Tabs, `modifiedAt` im Editor), jede Oberfläche (Schnitt 3), jede Änderung an `read` oder `ClaudeDelivery.swift`, `project.pbxproj`.

## Präzisierungen (gelten zusätzlich zu den Regeln der Elternspec)

1. **Treffer nur auf Gelieferte (präzisiert Regel 9):** Der Abgleich läuft über `claude?.itemId` bzw. `claude?.packageId` in `sets`, `presets` und `exercises`. Bausteine mit `claude == nil` (Hennings eigene) sind nie Ziel einer Rücknahme, auch nicht bei gleicher Kennung als Text.
2. **Ganz oder gar nicht, Prüfreihenfolge (präzisiert Regel 8 und 9):** Zuerst wird die Treffermenge gebildet, dann die Sperrprüfung (`isBlockedByIphone`, Regel 8) für alle getroffenen Programme und Atemübungen, erst danach wird entfernt. Ist irgendein Treffer gesperrt, wird die ganze Lieferung mit `CHANGED_ON_IPHONE` abgelehnt, bevor etwas entfernt wurde. Eine leere Treffermenge ergibt `noEffect` ohne Sperrprüfung. Übungen werden nie gesperrt und nie mit `CHANGED_ON_IPHONE` abgelehnt.
3. **Positionen laufen der Reihe nach auf der Arbeitskopie (präzisiert Regel 1):** Eine Rücknahme sieht auch Bausteine, die eine frühere Position derselben Lieferung angelegt hat (Beispiel `package-with-withdrawal.json`: legt `claude.ruecken-a2` an, nimmt `claude.ruecken-a` zurück).
4. **Schutzverhalten für vertragswidrige Rücknahmen:** Der Vertrag (§3.4) verlangt genau eines von `itemId` und `packageId`; der Dienst weist sonst mit `WITHDRAWAL_TARGET` ab, `read` der App prüft das nicht, und es gibt in dieser Runde keinen Eingriff in `read`. Für Lieferungen, die trotzdem ankommen, gilt: weder `itemId` noch `packageId` → `noEffect` (Regel 9: nichts getroffen); beide gesetzt → Vereinigung der Treffer (ein Baustein, der zu einer der beiden Kennungen passt, wird entfernt). Die zwei Fälle sind als Zusatz an bestehenden Testmethoden abgesichert (siehe AC-9), ohne neue Testmethoden.
5. **Klarstellung zu Anmerkung 4 der Elternspec („Offene Lücken“):** Nach 2a-3 fällt keine **unterstützte** Art mehr auf `KIND_NOT_SUPPORTED` (unterstützt sind `exercise`, `program`, `breath`, `withdrawal`). Der Zweig für `.unsupported` in `apply` bleibt als Schutz für von Hand gebaute Lieferungen und lehnt weiter mit `KIND_NOT_SUPPORTED` ab; aus `read` kommt diese Art nie dort an, weil `read` unbekannte Arten schon selbst mit `KIND_NOT_SUPPORTED` abweist. „Kommt in `apply` nicht mehr vor“ ist in diesem Sinn zu lesen.

## Acceptance Criteria

Keine neuen ACs. AC-2, AC-8b, AC-9, AC-10, AC-11, AC-17, AC-18 und AC-19 gelten wörtlich aus der Elternspec, mit Zusätzen zu AC-9 (aus Präzisierung 4).

- **AC-2 (2a-3): Alle lesbaren Beispiele mit Mindestanzahl.** Given jede lesbare Datei aus `valid/` und ein Zustand, der aus `context.knownExercises` der Datei vorbelegt ist, nämlich **`claude.*`-Kennungen als `ClaudeStoredExercise` in `state.exercises`** (Name aus dem Prüfkontext, übrige Felder feste Testwerte, z. B. `update-with-context.json` mit `claude.vierfuessler-diagonal`) und **nur `own.*`-Kennungen als je eine Phase** mit dieser `exerciseId` und diesem Namen (konsistent mit Regel 10 und AC-13b), When `apply`, Then kein Absturz, Ergebnis `applied` oder `noEffect`, nie `rejected` (insbesondere kein `KIND_NOT_SUPPORTED` mehr). Test: `testAlleLesbarenBeispieleLassenSichAnwenden`. Mindestanzahl wie in Schnitt 1 erzwungen: mindestens 51 Dateien in `valid/`, davon mindestens 32 lesbare. Test: `testApplyBeispielsatzMindestanzahl`.
- **AC-8b (2a-3): `CHANGED_ON_IPHONE` bei Einzel-Rücknahme.** Given ein Programm (bzw. eine Atemübung) mit `modifiedAt` und Rücknahme per `itemId`, Then abgelehnt mit `CHANGED_ON_IPHONE`, Bausteine unverändert, wenn `modifiedAt > lastSnapshotAt` oder `lastSnapshotAt` = `nil`; ohne `modifiedAt` oder bei `modifiedAt ≤ lastSnapshotAt` wird entfernt. Test: `testRuecknahmeEinzelnGeaendertesProgrammAbgelehnt` (deckt beide Arten und beide Seiten der Grenze).
- **AC-9 (2a-3): Rücknahme einzeln.** Given zwei gelieferte Bausteine, When `withdrawal` mit `itemId` des einen, Then dieser ist aus Liste bzw. Übungen entfernt, der andere bleibt, Ergebnis `applied`. Unbekannte `itemId`: `noEffect`. Tests: `testRuecknahmeEinzelnEntferntBaustein`, `testRuecknahmeUnbekannterKennungOhneWirkung`. **Zusatz (Präzisierung 4):** `testRuecknahmeUnbekannterKennungOhneWirkung` deckt auch den Fall ab, dass die Rücknahme weder `itemId` noch `packageId` trägt (von Hand gebaute Lieferung): Ergebnis `noEffect`, Bausteine unverändert. `testRuecknahmeEinzelnEntferntBaustein` deckt auch den Fall ab, dass beide Kennungen gesetzt sind (`itemId` des einen Bausteins, `packageId` eines anderen Pakets): beide Treffer sind entfernt, ein dritter Baustein bleibt, Ergebnis `applied`. Beides ohne neue Testmethode, gleicher Name. Ebenso deckt `testRuecknahmeUnbekannterKennungOhneWirkung` aus Präzisierung 1 ab, dass ein eigener Baustein (`claude == nil`) nicht getroffen wird.
- **AC-10 (2a-3): Rücknahme als Paket.** Given Programm, Atemübung und Übung eines Pakets plus ein Baustein ohne Paket (z. B. aus `package-with-withdrawal.json` aufgebaut), When `withdrawal` mit `packageId`, Then alle Bausteine des Pakets weg, der Rest bleibt. Ist einer der Paket-Bausteine nach der Abschrift geändert, wird die ganze Lieferung abgelehnt (`CHANGED_ON_IPHONE`), Bausteine unverändert. Tests: `testRuecknahmePaketEntferntAlleBausteine`, `testRuecknahmePaketMitGeaendertemBausteinAbgelehnt`.
- **AC-11 (2a-3): Rücknahme einer Übung.** Given eine gelieferte Übung und ein bleibendes Programm, dessen Phase auf sie zeigt, When Rücknahme der Übung, Then Übung entfernt (immer erlaubt, auch bei `lastSnapshotAt` = `nil`), das Programm und seine Phasen (Name, `exerciseId`) unverändert. Test: `testRuecknahmeUebungLaesstProgrammphasenStehen`.
- **AC-17 (2a-3): Ergebnis und Zustand Codable.** Given `ClaudeApplyResult` (alle drei Fälle) und ein `ClaudeApplyState` mit Übung, Programm, Atemübung und Gedächtnis (auch ein `rejected`-Eintrag), When kodiert und dekodiert, Then gleich. Test: `testResultUndStateRoundTrip`.
- **AC-18 (2a-3): Reinheit und Abgrenzung.** `ClaudeApply.swift` importiert nur `Foundation` und enthält weder `UserDefaults` noch `NotificationCenter` noch `Date()`. Test: `testApplyDateiIstFoundationOnlyUndOhneSeiteneffekte` (liest die Quelldatei per `#filePath`-Pfad relativ zum Repo, wie `testModellImportiertNurFoundation` in Schnitt 1). In jeder Runde zusätzlich Nachweis in der Adversary-Prüfung per Durchsicht des Diffs: nur die Dateien der Runde plus Specs/Docs, keine Änderung an `WorkoutTab.swift`, `MeditationTab.swift`, `ExerciseDatabase.swift`, `project.pbxproj`.
- **AC-19 (jede Runde): Bestand bleibt grün und App-Budget eingehalten.** Die vollständige Unit-Suite `LeanHealthTimerTests` läuft grün; iOS, Watch und Widget bauen; der Produktiv-Diff der Runde (App-Code ohne Tests, Löschzeilen mitgezählt) liegt bei höchstens 250 Zeilen und keine Funktion über 50 Zeilen. Nachweis: Protokoll `Executed N tests` mit N ≥ 1, Build aller drei Ziele, Zeilenzahl des Produktiv-Diffs im Validierungsbericht.

## Test Plan

- [ ] 10 neue Tests in `ClaudeApplyTests`: `testAlleLesbarenBeispieleLassenSichAnwenden`, `testApplyBeispielsatzMindestanzahl`, `testRuecknahmeEinzelnGeaendertesProgrammAbgelehnt`, `testRuecknahmeEinzelnEntferntBaustein`, `testRuecknahmeUnbekannterKennungOhneWirkung`, `testRuecknahmePaketEntferntAlleBausteine`, `testRuecknahmePaketMitGeaendertemBausteinAbgelehnt`, `testRuecknahmeUebungLaesstProgrammphasenStehen`, `testResultUndStateRoundTrip`, `testApplyDateiIstFoundationOnlyUndOhneSeiteneffekte`
- [ ] Im RED-Schritt gelöscht (Verhalten ändert sich bewusst): `testRuecknahmeNochNichtUnterstuetzt`
- [ ] RED-Beleg: 2a-3 braucht keine neuen Typen; die Testdatei übersetzt, und die Rücknahme-Tests (AC-2, 8b, 9, 10, 11) scheitern zur Laufzeit, weil `apply` für `withdrawal` noch `KIND_NOT_SUPPORTED` liefert. Tests, die auf dem Bestand schon grün sind (Round-Trip, Reinheit, Mindestanzahl), sind Absicherungen ohne eigenen RED-Beleg und im RED-Bericht als solche genannt. Kein Gerüst im Produktivcode.
- [ ] Vollständige Unit-Suite `LeanHealthTimerTests` grün, `Executed N tests` mit N ≥ 1
- [ ] Kein UI-Test: Die Runde ändert nichts Gespeichertes und nichts Sichtbares (Begründung in der Elternspec, Test Plan)

## Definition of Done

- [ ] Build grün für iOS, Watch und Widget
- [ ] ACs der Runde als Unit-Tests grün, im Protokoll `Executed N tests` mit N ≥ 1
- [ ] Vollständige Unit-Suite grün
- [ ] Produktiv-Diff ≤ 250 Zeilen, Funktionen ≤ 50 Zeilen (AC-19)
- [ ] Adversary-Prüfung: Verdict VERIFIED, Diff-Durchsicht bestätigt (Teil „in jeder Runde“ von AC-18: nur Dateien der Runde plus Specs/Docs, keine Änderung an `WorkoutTab.swift`, `MeditationTab.swift`, `ExerciseDatabase.swift`, `project.pbxproj`)
- [ ] `openspec/specs/features/claude-annahme.md` nachgezogen: Schnitt 2 in 2a (erledigt, Runden 2a-1 bis 2a-3) und 2b (offen) geteilt, Verweis auf die Elternspec `DOCS/specs/features/feature-51-s2-bausteine-anwenden.md`; Verhalten 2 um die Abweichung „Übungen in `claudeState` statt Übungskatalog“ ergänzt

## Changelog

- 2026-11-21: Angelegt als Rundenspec, weil die Elternspec eingefroren ist.
