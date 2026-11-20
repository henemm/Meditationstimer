# Context: feature-87-zusatzuebungen-5-8 (#87, Runde A2d-1b von Epic #48)

## Request Summary
Nr. 5-8 der neuen Katalogübungen (Sit-ups, Crunches, Archer-Liegestütze, Decline-Liegestütze) werden an den Katalog
angehängt, mit Kennung, deutschem Namen, Kategorie, Wirkung und Anleitung DE/EN; dazu die Namensschlüssel
„Archer-Liegestütze" und „Decline-Liegestütze" (DE ≠ EN). Spec: `DOCS/specs/features/feature-48-uebungskatalog.md`
(freigegeben), Tabelle Z. 84-87, Rundenzeile A2d-1b Z. 170, Namensschlüssel-Regel Z. 196, Zwischenstand Z. 311.

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Services/ExerciseDatabase.swift` | `allExercises` (47 Einträge, Block `// MARK: - Core (A2d-1a)` als Muster), `englishNameIds` (4 neue Aliase) |
| `Meditationstimer iOS/Localizable.xcstrings` | 8 Textschlüssel `exercise.<slug>.effect/.instructions` (de+en) + 2 Namensschlüssel |
| `Contracts/catalog/builtin-exercises.json` | 47 → 51 Einträge, `catalogVersion` bleibt 1 |
| `LeanHealthTimerTests/ExerciseCatalogTests.swift` | Tests aus dem gemeinsamen RED-Commit (#80), unverändert |
| `server/test/mcp-read.test.ts` | seit #80 Anzahl aus der Katalogdatei → keine Änderung nötig |

## Existing Patterns (aus A2d-1a, #80, Commit be98783)
- Katalogeintrag: `ExerciseInfo(id:, name:, category:, effect: NSLocalizedString("exercise.<slug>.effect", value: DE, comment:), instructions: …)`.
- `localizedTexts(forId:bundle:)` löst Wirkung/Anleitung bereits über `exercise.<slug>.*` im übergebenen Bundle auf
  (in #80 gebaut) → keine Logikänderung mehr, nur Daten.
- Namensschlüssel nur bei DE ≠ EN; englischer Name zusätzlich in `englishNameIds`.
- Bestehende Einträge mit englischem Schlüssel („Archer Push-ups" → DE „Archer-Liegestütze", „Decline Push-ups")
  bleiben unverändert (Spec Z. 196).

## Dependencies
- Upstream: `Localizable.xcstrings`, Bundle-Lokalisierung.
- Downstream: Info-Blatt (per Kennung), Namensableitung (englischer Name → Kennung), Dienst und Referenz-Prüfer
  (lesen die Vertrags-JSON zur Laufzeit, keine feste Anzahl mehr).

## Analysis

### Type
Feature (Runde A2d-1b von Epic #48), reines Anhängen von Daten nach bewährtem Muster.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Services/ExerciseDatabase.swift` | MODIFY | 4 Einträge (`core`: sit-ups, crunches; `upperBody`: archer-liegestuetze, decline-liegestuetze) + 4 Aliase in `englishNameIds` |
| `Meditationstimer iOS/Localizable.xcstrings` | MODIFY | 8 Textschlüssel + 2 Namensschlüssel (zählt laut `loc_exclude_patterns` nicht zur Grenze, Regel liegt auf main) |
| `Contracts/catalog/builtin-exercises.json` | MODIFY | 4 Einträge anhängen |

### Scope Assessment
- Dateien: 3; Programmcode ≈ 65 Zeilen (Swift ≈ 45, JSON ≈ 20), Textdatei ≈ 170 (ausgenommen).
- Risiko: LOW (nur Anhängen; die 47 vorhandenen Einträge und ihr Nutzerpfad bleiben unverändert).

### Erwartetes Testbild nach A2d-1b (Spec Z. 311)
- `test_newExercises_haveTextsInDeAndEn_andCategory`: Nr. 1-8 fehlerfrei, Abbruch bei Nr. 9 (`builtin.dips`) → grün erst nach A2d-2
- `test_idForEnglishName_returnsBuiltinId`: nur noch 16 Namen rot (Nr. 9-24)
- `test_first43Entries_unchanged`, Gleichlauf Katalog ↔ JSON für alle 51: grün bis auf die Endanzahl 67
- App-Durchlauf im Simulator: „Crunches" aus der Vorschlagsliste wählen, Info-Blatt zeigt Wirkung und Anleitung auf DE und EN

### Alternative
- Nr. 5-12 in einer Runde (Textdatei zählt ja nicht mehr): verworfen, PO hat am 2026-11-15 drei Runden entschieden,
  und #88 (Nr. 9-12) ist eigenes Ticket.

## Risks & Considerations
- Altfehler #90 (Info-Blatt beim ersten Tipp leer) kann den App-Durchlauf stören → wie in #80 zweiten Tipp nutzen und
  im Beleg nennen, nicht hier beheben.
- Fachtexte (Wirkung/Anleitung) müssen sachlich stimmen; Archer/Decline als Liegestütz-Varianten unter `upperBody`.
