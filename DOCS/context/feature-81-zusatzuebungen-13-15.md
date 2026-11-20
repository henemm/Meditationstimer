# Context: feature-81-zusatzuebungen-13-15 (#81, Runde A2d-2a von Epic #48)

## Request Summary
Nr. 13-15 der neuen Katalogübungen (Umgekehrtes Rudern `upperBody`, Step-ups `legs`, Wandsitzen `legs`) werden an
den Katalog angehängt, mit Kennung, deutschem Namen, Kategorie, Wirkung und Anleitung DE/EN; dazu Namensschlüssel
„Umgekehrtes Rudern" (EN „Inverted Rows") und „Wandsitzen" (EN „Wall-Sit"), da DE ≠ EN. „Step-ups" lautet gleich.
Spec: `DOCS/specs/features/feature-48-uebungskatalog.md` (freigegeben), Tabelle Z. 92-94, Rundenzeile A2d-2 Z. 172,
Namensschlüssel-Regel Z. 196, Zwischenstände Z. 311.

## Neuschnitt A2d-2 (2026-11-16)
Bis #89 gelöst ist, zählen Texte in `Localizable.xcstrings` zur 250-Zeilen-Grenze. Messung A2d-1c (Commit cf18c18):
4 Übungen mit 2 Namensschlüsseln = 236 Zeilen (xcstrings 178 = ca. 17,8 je Text, Swift 38, JSON 20).
A2d-2 hat 8 Namensschlüssel (Nr. 13, 15, 18, 19, 20, 22, 23, 24); 4er-Runden mit 3 Schlüsseln lägen bei ca. 254.
Daher vier Runden à 3: #81 A2d-2a (13-15), #92 A2d-2b (16-18), #93 A2d-2c (19-21), #94 A2d-2d (22-24 + catalogVersion 2).
Die Spec-Schnitttabelle (Z. 172) und die Zwischenstände (Z. 311) müssen in der Spec-Phase nachgezogen werden.

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Services/ExerciseDatabase.swift` | `allExercises` (55 Einträge, Block `// MARK: - Oberkörper (A2d-1c)` Z. 470 als Muster), `englishNameIds` Z. 528 (3 neue Aliase: Inverted Rows, Step-ups, Wall-Sit) |
| `Meditationstimer iOS/Localizable.xcstrings` | 6 Textschlüssel `exercise.<slug>.effect/.instructions` (de+en) + 2 Namensschlüssel |
| `Contracts/catalog/builtin-exercises.json` | 55 → 58 Einträge, `catalogVersion` bleibt 1 (Version 2 erst in A2d-2d) |
| `LeanHealthTimerTests/ExerciseCatalogTests.swift` | Tests aus dem gemeinsamen RED-Commit (#80), unverändert |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` Z. 290, 304, 305 | Vorschlagsliste enthält „Inverted Rows", „Step-ups", „Wall-Sit" (englisch, bis A2b) → Weg für den App-Durchlauf; nicht ändern |

## Existing Patterns (A2d-1a/b/c)
- Katalogeintrag: `ExerciseInfo(id:, name:, category:, effect: NSLocalizedString("exercise.<slug>.effect", value: DE, comment:), instructions: …)`.
- `localizedTexts(forId:bundle:)` löst Wirkung/Anleitung über `exercise.<slug>.*` auf → keine Logikänderung, nur Daten.
- Namensschlüssel nur bei DE ≠ EN; englischer Name zusätzlich in `englishNameIds`.
- Für Inverted Rows / Wall-Sit gibt es heute keinen Eintrag in `Localizable.xcstrings` (anders als „Pull-ups" in A2d-1c) → keine Doppelung.

## Dependencies
- Upstream: `Localizable.xcstrings`, Bundle-Lokalisierung.
- Downstream: Info-Blatt (per Kennung), Namensableitung (englischer Name → Kennung), Dienst und Referenz-Prüfer
  (lesen die Vertrags-JSON zur Laufzeit, keine feste Anzahl seit A2d-1a).

## Analysis

### Type
Feature (Runde A2d-2a von Epic #48), reines Anhängen von Daten nach bewährtem Muster, vierte gleichartige Runde.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Services/ExerciseDatabase.swift` | MODIFY | 3 Einträge (umgekehrtes-rudern `upperBody`, step-ups `legs`, wandsitzen `legs`) + 3 Aliase in `englishNameIds` |
| `Meditationstimer iOS/Localizable.xcstrings` | MODIFY | 6 Textschlüssel + 2 Namensschlüssel |
| `Contracts/catalog/builtin-exercises.json` | MODIFY | 3 Einträge anhängen |

### Scope Assessment
- Dateien: 3; Programmcode ≈ 45 Zeilen (Swift ≈ 30, JSON ≈ 15), Texte ≈ 143 (8 × 17,8) → gesamt ≈ 190, unter 250.
- Risiko: LOW (nur Anhängen; die 55 vorhandenen Einträge bleiben unverändert).

### Erwartetes Testbild nach A2d-2a
- `test_newExercises_haveTextsInDeAndEn_andCategory`: Nr. 1-15 fehlerfrei, Abbruch bei Nr. 16 (`builtin.box-jumps`)
- `test_idForEnglishName_returnsBuiltinId`: nur noch 9 Namen rot (Nr. 16-24)
- `test_catalog_matchesBuiltinExercisesJson`, `test_catalog_has67EntriesAndVersion2`: rot nur an Endanzahl 67 / Version 2
- `test_first43Entries_unchanged`, Gleichlauf aller 58 vorhandenen Einträge: grün
- App-Durchlauf im Simulator: „Inverted Rows" aus der Vorschlagsliste wählen; Info-Blatt zeigt Wirkung und Anleitung
  auf DE und EN (Name im Info-Blatt bleibt bis A2b englisch, siehe Walk-Test-Lehre #88)

### Alternative
- #89 zuerst lösen (Haupt-Checkout auf main), dann A2d-2 als eine Runde ohne Textzählung: verworfen für jetzt, weil
  der Wechsel aus Worktree-Sitzungen gesperrt ist (Harness-Isolation) und #89 ein eigenes Ziel ist.
- 4er-Runden (3 Runden): verworfen, Runden mit 3 Namensschlüsseln lägen knapp über 250.

## Risks & Considerations
- Altfehler #90 (Info-Blatt beim ersten Tipp leer) kann den App-Durchlauf stören → zweiten Tipp nutzen, im Beleg nennen.
- Fachtexte klar abgrenzen: Umgekehrtes Rudern ähnelt den Australischen Klimmzügen (Nr. 12) → Unterschied benennen
  (z. B. Rudern an Tisch/Ringen/Band, Fokus mittlerer Rücken, Ellbogen nah am Körper), sonst wirken die Texte doppelt.
- Wandsitzen ist eine Halteübung (isometrisch) → Anleitung mit Haltedauer statt Wiederholungen.
- Kategorien laut Spec: Nr. 13 `upperBody`, Nr. 14/15 `legs` (nicht alle `upperBody` wie in A2d-1c).

### Prüfung der Analyse (2026-11-16, nach /clear)
Gegen den Stand nach A2d-1c (a3f3e94) nachgeprüft: Katalog-JSON 55 Einträge; Muster-Block Z. 470, `englishNameIds`
Z. 528; Spec-Tabelle Nr. 13-15 (Z. 92-94) mit Kennungen/Kategorien wie oben; keine vorhandenen xcstrings-Einträge für
Inverted Rows / Wall-Sit / Step-ups / Wandsitzen / Umgekehrtes Rudern; Vorschlagsliste Z. 290/304/305 bestätigt.
Offene Fragen an den PO: keine (Fachtexte folgen der freigegebenen Spec, Abgrenzung zu Nr. 12 und Haltedauer beim
Wandsitzen siehe Risiken).
