# Context: feature-92-zusatzuebungen-16-18 (#92, Runde A2d-2b von Epic #48)

## Request Summary
Nr. 16-18 der neuen Katalogübungen (Box Jumps `legs`, Skater Hops `cardio`, Seilspringen `cardio`) werden an den
Katalog angehängt, mit Kennung, deutschem Namen, Kategorie, Wirkung und Anleitung DE/EN; dazu Namensschlüssel
„Seilspringen" (EN „Jump Rope"), da DE ≠ EN. „Box Jumps" und „Skater Hops" lauten gleich.
Spec: `DOCS/specs/features/feature-48-uebungskatalog.md` (freigegeben), Tabelle Z. 95-97, Rundenzeile A2d-2b Z. 174,
Namensschlüssel-Regel Z. 200, Zwischenstände Z. 316. Der Schnitt in vier Runden à 3 ist seit A2d-2a in der Spec
nachgezogen; für diese Runde muss die Spec nicht geändert werden.

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Services/ExerciseDatabase.swift` | `allExercises` (58 Einträge, Block `// MARK: - A2d-2a (Rücken, Beine)` Z. 504 als Muster), `englishNameIds` Z. 554 (3 neue Aliase: Box Jumps, Skater Hops, Jump Rope; Muster Z. 604-606) |
| `Meditationstimer iOS/Localizable.xcstrings` | 6 Textschlüssel `exercise.<slug>.effect/.instructions` (de+en) + 1 Namensschlüssel „Seilspringen" |
| `Contracts/catalog/builtin-exercises.json` | 58 → 61 Einträge, `catalogVersion` bleibt 1 (Version 2 erst in A2d-2d) |
| `LeanHealthTimerTests/ExerciseCatalogTests.swift` | Tests aus dem gemeinsamen RED-Commit (#80), unverändert |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` Z. 313-315 | Vorschlagsliste enthält „Box Jumps", „Skater Hops", „Jump Rope" (englisch, bis A2b) → Weg für den App-Durchlauf; nicht ändern |

## Existing Patterns (A2d-1a/b/c, A2d-2a)
- Katalogeintrag: `ExerciseInfo(id:, name:, category:, effect: NSLocalizedString("exercise.<slug>.effect", value: DE, comment:), instructions: …)`.
- `localizedTexts(forId:bundle:)` löst Wirkung/Anleitung über `exercise.<slug>.*` auf → keine Logikänderung, nur Daten.
- Namensschlüssel nur bei DE ≠ EN (deutscher Name als Schlüssel, Muster „Wandsitzen" Z. 12506); englischer Name
  zusätzlich in `englishNameIds`.
- Vorhandener Eintrag mit englischem Schlüssel „Jump Rope" → DE „Seilspringen" (xcstrings Z. 6320) bleibt unverändert,
  genau wie „Pull-ups" → „Klimmzüge" in A2d-1c (Spec Z. 200: Altschlüssel bleiben, solange die Vorschlagsliste sie nutzt;
  Entfernen erst in A2c-2). Der neue Schlüssel „Seilspringen" kommt zusätzlich, keine Doppelung im Sinne gleicher Keys.
- Kategorie `cardio` ist schon belegt (Mountain Climbers, High Knees, Hampelmänner, Butt Kicks) → kein neuer Fall.

## Dependencies
- Upstream: `Localizable.xcstrings`, Bundle-Lokalisierung.
- Downstream: Info-Blatt (per Kennung), Namensableitung (englischer Name → Kennung), Dienst und Referenz-Prüfer
  (lesen die Vertrags-JSON zur Laufzeit, keine feste Anzahl seit A2d-1a).

## Analysis

### Type
Feature (Runde A2d-2b von Epic #48), reines Anhängen von Daten nach bewährtem Muster, fünfte gleichartige Runde.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Services/ExerciseDatabase.swift` | MODIFY | 3 Einträge (box-jumps `legs`, skater-hops `cardio`, seilspringen `cardio`) + 3 Aliase in `englishNameIds` |
| `Meditationstimer iOS/Localizable.xcstrings` | MODIFY | 6 Textschlüssel + 1 Namensschlüssel |
| `Contracts/catalog/builtin-exercises.json` | MODIFY | 3 Einträge anhängen |

### Scope Assessment
- Dateien: 3; Programmcode ≈ 45 Zeilen (Swift ≈ 30, JSON ≈ 15), Texte ≈ 125 (7 × 17,8) → gesamt ≈ 170, unter 250.
- Risiko: LOW (nur Anhängen; die 58 vorhandenen Einträge bleiben unverändert).

### Erwartetes Testbild nach A2d-2b
- `test_newExercises_haveTextsInDeAndEn_andCategory`: Nr. 1-18 fehlerfrei, Abbruch bei Nr. 19 (`builtin.herabschauender-hund`)
- `test_idForEnglishName_returnsBuiltinId`: nur noch 6 Namen rot (Nr. 19-24)
- `test_catalog_matchesBuiltinExercisesJson`, `test_catalog_has67EntriesAndVersion2`: rot nur an Endanzahl 67 / Version 2
- `test_first43Entries_unchanged`, Gleichlauf aller 61 vorhandenen Einträge: grün
- App-Durchlauf im Simulator: „Jump Rope" aus der Vorschlagsliste wählen; Info-Blatt zeigt Wirkung und Anleitung
  auf DE und EN (Name im Info-Blatt bleibt bis A2b englisch, siehe Walk-Test-Lehre #88)

### Alternative
- #89 zuerst lösen (Haupt-Checkout auf main), dann den Rest von A2d-2 (16-24) als eine Runde ohne Textzählung:
  verworfen für jetzt, weil der Wechsel aus Worktree-Sitzungen gesperrt ist und #89 ein eigenes Ziel ist.
- Nr. 16-18 mit Nr. 19-21 zusammenlegen: verworfen, 6 Übungen mit 3 Namensschlüsseln lägen bei ca. 300 Zeilen.

## Risks & Considerations
- Altfehler #90 (Info-Blatt beim ersten Tipp leer) kann den App-Durchlauf stören → zweiten Tipp nutzen, im Beleg nennen.
- Fachtexte klar abgrenzen:
  - Box Jumps vs. Jump-Kniebeugen (Z. 98): Sprung auf eine stabile Erhöhung, weiche Landung oben, Abstieg gehend statt
    springend (Achillessehne schonen); Sicherheitshinweis zu stabiler, rutschfester Box.
  - Skater Hops vs. Hampelmänner/High Knees: seitlicher Sprung von einem Bein aufs andere, Fokus Gesäß außen,
    Gleichgewicht und seitliche Stabilität im Knie.
  - Seilspringen: braucht ein Seil (anders als die übrigen Cardio-Übungen ohne Gerät); kleine Sprünge auf den Ballen,
    Drehung aus den Handgelenken; Anleitung mit Zeitintervall statt Wiederholungen.
- Kategorien laut Spec: Nr. 16 `legs`, Nr. 17/18 `cardio`.
- Doppelter Sinn „Jump Rope": alter englischer Schlüssel bleibt; nichts an ihm ändern, sonst bricht die heutige
  Vorschlagsliste auf Deutsch.

Offene Fragen an den PO: keine (Fachtexte folgen der freigegebenen Spec).
