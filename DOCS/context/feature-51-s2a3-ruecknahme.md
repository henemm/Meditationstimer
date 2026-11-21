# Context: feature-51-s2a3-ruecknahme (#51 Schnitt 2a, Runde 2a-3)

## Request Summary
Letzte Runde der reinen Anwende-Logik: Rücknahme einer Lieferung einzeln (`itemId`) und als Paket (`packageId`), dazu die Abschlussprüfungen „alle lesbaren Beispiele lassen sich anwenden“ (mit Mindestanzahl), Codable-Round-Trip von Ergebnis und Zustand, Reinheit der Datei. Spec `DOCS/specs/features/feature-51-s2-bausteine-anwenden.md` ist für alle drei Runden freigegeben (Abschnitt „Runde 2a-3“: AC-2, AC-8b, AC-9, AC-10, AC-11, AC-17, AC-18, dazu AC-19 für jede Runde; Regeln 8 und 9).

Stand: 2a-1 und 2a-2 sind gemergt (PR #107, Merge fb47174, Unit-Suite 300/300).

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Models/ClaudeApply.swift` (167 Z.) | MODIFY: `applyWithdrawal` neu, Anschluss im `switch` von `apply` (Z. 59–71, heute `default` → `KIND_NOT_SUPPORTED` Z. 66–67) |
| `LeanHealthTimerTests/ClaudeApplyTests.swift` (689 Z.) | MODIFY: befristeten Test `testRuecknahmeNochNichtUnterstuetzt` (Z. 474–486) löschen; neue Tests für AC-2, AC-8b, AC-9, AC-10, AC-11, AC-17, AC-18 |
| `openspec/specs/features/claude-annahme.md` (59 Z.) | MODIFY, nur Doku (DoD): Abschnitt „Schnitte“ Z. 51–58 Punkt 2 in 2a (erledigt) / 2b (offen) teilen, Verweis auf die Runden-Spec; Z. 18 Abweichung Verhalten 2 (Übungen in `state.exercises` statt Katalog) vermerken |
| `Meditationstimer iOS/Models/ClaudeDelivery.swift` | nur lesen: `ClaudeWithdrawal { itemId: String?, packageId: String? }` Z. 34, `case withdrawal` Z. 40; `read` wirft `KIND_NOT_SUPPORTED` für unbekannte Arten (Z. 79–80) |
| `LeanHealthTimerTests/ClaudeDeliveryDecodingTests.swift` | Muster: `testDir` Z. 22–27, `testBeispielsatzMindestanzahl` Z. 63, `testAlleLesbarenBeispieleWerdenGelesen` Z. 68 |
| `Contracts/deliveries/valid/` (51 Dateien) | Beispielsatz; mit Rücknahme: `withdraw-item.json`, `withdraw-package.json`, `package-with-withdrawal.json`, `items-20.json` |

## Existing Patterns
- `apply` arbeitet auf einer Arbeitskopie `work`, `switch` je Positionsart, erste Ablehnung bricht ab (`break`), Übernahme nur ohne Ablehnung, Gedächtnis inline (Z. 72–75).
- Ablehnung inline als `.rejected(code:reason:)`; `changedOnIphone` (Z. 91–92) und `isBlockedByIphone(modifiedAt:lastSnapshotAt:)` (Z. 85–89) gibt es schon und sind für Rücknahme wiederzuverwenden.
- Test-Helfer: `sampleDelivery(_:)` (Z. 26–33, liest aus `Contracts/deliveries/valid` per `#filePath`), `delivery("…", items:)` für In-Memory-JSON, `seeded()`.
- Reinheitstest per Quelltext-Lesen über `#filePath` wie `testModellImportiertNurFoundation` (Schnitt 1).

## Dependencies
- Upstream: `ClaudeDelivery` (Lese-Modell), `WorkoutSet` (`claude`/`modifiedAt`, WorkoutProgramsView.swift:173–174), `Preset` (AtemView.swift:53–54), `ClaudeOrigin.packageId`.
- Downstream: keine Aufrufer außer Tests (Anschluss an Speicher und UI erst in 2b).

## Existing Specs
- `DOCS/specs/features/feature-51-s2-bausteine-anwenden.md` — Runden-Spec, freigegeben
- `openspec/specs/features/claude-annahme.md` — Feature-Spec B1a
- `Contracts/` Lieferformat §3.4 (Rücknahme ohne Wiederherstellen, PO 13.11.)

## Risks & Considerations
- Budget unkritisch: kalibriert ~45 Zeilen App-Code bei Grenze 250; längste Funktion heute 26 Zeilen.
- Watch- und Widget-Build: Datei wird im Widget mit übersetzt (Watch laut 2a-1-Befund nicht); Build beider Ziele bleibt DoD.
- Paket-Rücknahme muss „ganz oder gar nicht“ einhalten: ein geänderter Paket-Baustein lehnt die ganze Lieferung ab, bevor irgendetwas entfernt wird.

## Analysis

### Type
Feature (Teilrunde), voller Prozess, Summe 1 (Scope Medium wegen ~45 LoC, Blast Radius Low, Unsicherheit Low).

### Affected Files (with changes)
Wie in der Spec, Abschnitt „2a-3 (3 Dateien)“: `ClaudeApply.swift`, `ClaudeApplyTests.swift`, `claude-annahme.md`. Kein `project.pbxproj`.

### Scope Assessment
App-Code ~40–50 Zeilen, Tests ~200 Zeilen (zählen nicht), Doku ~10 Zeilen.

### Technical Approach
- `applyWithdrawal(_ w: ClaudeWithdrawal, into work: inout ClaudeApplyState, lastSnapshotAt:) -> ClaudeApplyResult`: Treffermenge bilden (per `itemId` bzw. per `claude.packageId`) über `sets`, `presets`, `exercises`; zuerst Sperrprüfung `isBlockedByIphone` nur für Programme und Atemübungen der Treffermenge → `CHANGED_ON_IPHONE`; erst dann entfernen. Leere Treffermenge → `noEffect`.
- `switch` in `apply` um `.withdrawal` erweitern.

### Tech-Lead-Festlegungen (Spec schweigt, keine PO-Frage)
1. **Rücknahme ohne `itemId` und ohne `packageId`:** `read` lässt sie zu; `apply` behandelt sie als `noEffect` (Regel 9: „Unbekannte Kennung: ohne Wirkung“). Kein Eingriff in `read` (andere Datei, anderer Schnitt).
2. **Beide Kennungen gesetzt:** Vereinigung der Treffer (ein Baustein, der zu einer der beiden passt, wird entfernt). Beispielsatz enthält diesen Fall nicht; Test sichert das Verhalten fest.
3. **`.unsupported` in `apply`:** `read` wirft für unbekannte Arten bereits `KIND_NOT_SUPPORTED`, eine gelesene Lieferung erreicht `apply` also nie damit. Der Zweig bleibt als Schutz für von Hand gebaute Lieferungen und lehnt weiter ab; Spec-Anmerkung 4 („kommt in `apply` nicht mehr vor“) ist so zu lesen, dass keine unterstützte Art mehr dorthin fällt. Wird im Spec-Nachzug dieser Runde klargestellt.

### Dependencies
Keine neuen Typen, keine neuen Imports.

### Reihenfolge
RED: Zwischen-Test löschen, neue Tests rot → GREEN: `applyWithdrawal` + Anschluss → Adversary → Doku `claude-annahme.md` → Validierung (Unit-Suite, iOS/Watch/Widget-Build).

### Open Questions
- Notiert, nicht Teil dieser Runde: `applyProgram` löst `own.*` gegen den Eingangszustand (`state.sets`) statt gegen `work` auf (ClaudeApply.swift:63). Regel 10 sagt „Phase eines Programms im Zustand“, das deckt den Eingangszustand; frühere Positionen derselben Lieferung braucht nur `claude.*` (Regel 1, gelöst). In 2a-2 vom Adversary verifiziert; kein Handlungsbedarf, solange Regel 10 so gilt.
- `ClaudeStoredExercise` ist `Hashable` statt `Equatable` (Spec) — schließt `Equatable` ein, harmlos.

### Nachprüfung 2026-11-21 (Wiedereinstieg nach /clear)
Analyse oben gegen Code und Vertrag geprüft, Zeilenangaben stimmen (`apply`-`switch` Z. 59–68, `default` → `KIND_NOT_SUPPORTED`; Zwischen-Test Z. 474–486). Ergänzungen:
- **Vertrag §3.4 (`claude-lieferformat.md` Z. 113–116):** Genau eines von `itemId`/`packageId`; beide oder keins ist `WITHDRAWAL_TARGET` (Beispiele `invalid/withdrawal-both.json`, `withdrawal-none.json`). Der Dienst weist solche Lieferungen vor der App ab; `read` in der App prüft das nicht (Z. 129–130). Tech-Lead-Festlegungen 1 (keins → `noEffect`) und 2 (beide → Vereinigung) sind damit reines Schutzverhalten für Eingaben, die nach Vertrag nie ankommen. Kein Eingriff in `read` in dieser Runde.
- **Treffer nur auf Gelieferte:** Abgleich per `claude?.itemId` bzw. `claude?.packageId`; Hennings eigene Programme/Atemübungen (`claude == nil`) sind nie Ziel einer Rücknahme.
- **Reihenfolge innerhalb einer Lieferung:** `package-with-withdrawal.json` legt `claude.ruecken-a2` an und nimmt `claude.ruecken-a` zurück; Positionen laufen der Reihe nach auf `work`, Rücknahme sieht also auch in derselben Lieferung neu Angelegtes. Für den Beispielsatz ohne Belang (andere Kennungen).
- **Regel 8 nur bei Wirkung:** leere Treffermenge → `noEffect` ohne Sperrprüfung; Übungen nie gesperrt.
- Unterstützte Arten nach dieser Runde vollständig: `exercise`, `program`, `breath`, `withdrawal`; `.unsupported` bleibt als einziger Fall im Schutzzweig.
