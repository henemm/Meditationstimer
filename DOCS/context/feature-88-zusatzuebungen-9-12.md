# Context: feature-88-zusatzuebungen-9-12 (#88, Runde A2d-1c von Epic #48)

## Request Summary
Nr. 9-12 der neuen Katalogübungen (Dips, Klimmzüge, Chin-ups, Australische Klimmzüge) werden an den Katalog
angehängt, mit Kennung, deutschem Namen, Kategorie `upperBody`, Wirkung und Anleitung DE/EN; dazu die
Namensschlüssel „Klimmzüge" (EN „Pull-ups") und „Australische Klimmzüge" (EN „Australian Pull-ups"), da DE ≠ EN.
Spec: `DOCS/specs/features/feature-48-uebungskatalog.md` (freigegeben), Tabelle Z. 88-91, Rundenzeile A2d-1c Z. 171,
Namensschlüssel-Regel Z. 196, Zwischenstand Z. 311, App-Durchlauf Z. 312.

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Services/ExerciseDatabase.swift` | `allExercises` (51 Einträge, Block `// MARK: - Core / Oberkörper (A2d-1b)` Z. 436 als Muster), `englishNameIds` Z. 494 (4 neue Aliase: Dips, Pull-ups, Chin-ups, Australian Pull-ups) |
| `Meditationstimer iOS/Localizable.xcstrings` | 8 Textschlüssel `exercise.<slug>.effect/.instructions` (de+en) + 2 Namensschlüssel |
| `Contracts/catalog/builtin-exercises.json` | 51 → 55 Einträge, `catalogVersion` bleibt 1 |
| `LeanHealthTimerTests/ExerciseCatalogTests.swift` | Tests aus dem gemeinsamen RED-Commit (#80), unverändert |

## Existing Patterns (aus A2d-1a #80 und A2d-1b #87, Commit 007b4fc)
- Katalogeintrag: `ExerciseInfo(id:, name:, category:, effect: NSLocalizedString("exercise.<slug>.effect", value: DE, comment:), instructions: …)`.
- `localizedTexts(forId:bundle:)` löst Wirkung/Anleitung über `exercise.<slug>.*` auf → keine Logikänderung, nur Daten.
- Namensschlüssel nur bei DE ≠ EN; englischer Name zusätzlich in `englishNameIds`.
- Bestehende Einträge mit englischem Schlüssel („Pull-ups" → DE „Klimmzüge", „Australian Pull-ups") bleiben
  unverändert, solange die Vorschlagsliste sie nutzt (Spec Z. 196).

## Dependencies
- Upstream: `Localizable.xcstrings`, Bundle-Lokalisierung.
- Downstream: Info-Blatt (per Kennung), Namensableitung (englischer Name → Kennung), Dienst und Referenz-Prüfer
  (lesen die Vertrags-JSON zur Laufzeit, keine feste Anzahl).

## Analysis

### Type
Feature (Runde A2d-1c von Epic #48), reines Anhängen von Daten nach bewährtem Muster, dritte gleichartige Runde.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Services/ExerciseDatabase.swift` | MODIFY | 4 Einträge `upperBody` (dips, klimmzuege, chin-ups, australische-klimmzuege) + 4 Aliase in `englishNameIds` |
| `Meditationstimer iOS/Localizable.xcstrings` | MODIFY | 8 Textschlüssel + 2 Namensschlüssel (zählt laut `loc_exclude_patterns` nicht zur Grenze) |
| `Contracts/catalog/builtin-exercises.json` | MODIFY | 4 Einträge anhängen |

### Scope Assessment
- Dateien: 3; Programmcode ≈ 65 Zeilen (Swift ≈ 45, JSON ≈ 20), Textdatei ≈ 170 (ausgenommen).
- Risiko: LOW (nur Anhängen; die 51 vorhandenen Einträge bleiben unverändert).

### Erwartetes Testbild nach A2d-1c (Spec Z. 311)
- `test_newExercises_haveTextsInDeAndEn_andCategory`: Nr. 1-12 fehlerfrei, Abbruch bei Nr. 13 (`builtin.umgekehrtes-rudern`) → grün erst nach A2d-2
- `test_idForEnglishName_returnsBuiltinId`: nur noch 12 Namen rot (Nr. 13-24)
- `test_first43Entries_unchanged`, Gleichlauf Katalog ↔ JSON für alle 55: grün bis auf die Endanzahl 67
- App-Durchlauf im Simulator (Spec Z. 312): „Pull-ups" aus der Vorschlagsliste wählen, Info-Blatt zeigt Wirkung
  und Anleitung auf DE und EN; hier wechselt auch der Name (Klimmzüge ↔ Pull-ups)

### Alternative
- Nr. 9-24 (A2d-1c und A2d-2) in einer Runde: verworfen, PO hat am 2026-11-15 drei Runden für A2d-1 entschieden;
  A2d-2 ist eigener Schnitt mit eigener Grenze.

## Risks & Considerations
- Altfehler #90 (Info-Blatt beim ersten Tipp leer) kann den App-Durchlauf stören → zweiten Tipp nutzen, im Beleg nennen.
- Erste Runde, in der ein bestehender englischer Schlüssel („Pull-ups") und der neue deutsche Namensschlüssel
  „Klimmzüge" nebeneinander existieren → im Durchlauf prüfen, dass Name auf DE „Klimmzüge" und auf EN „Pull-ups" lautet.
- Fachtexte: Klimmzüge (Obergriff), Chin-ups (Untergriff, mehr Bizeps), Australische Klimmzüge (schräg unter
  niedriger Stange) sachlich klar unterscheiden; Dips an Barren oder Bank.
