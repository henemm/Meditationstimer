# Context: feature-94-zusatzuebungen-22-24 (#94, Runde A2d-2d von Epic #48)

## Request Summary
Nr. 22-24 der neuen Katalogübungen (Sitzende Vorbeuge, Schulter-Dehnung links, Schulter-Dehnung rechts, alle
`stretching`) werden an den Katalog angehängt, mit Kennung, deutschem Namen, Kategorie, Wirkung und Anleitung DE/EN;
Namensschlüssel für alle drei (EN „Seated Forward Bend", „Shoulder Stretch Left/Right"). Letzte Runde von A2d-2:
danach 67 Einträge und `catalogVersion` 2 in der Vertrags-JSON.
Spec: `DOCS/specs/features/feature-48-uebungskatalog.md` (freigegeben), Tabelle Z. 105-107, Rundenzeile A2d-2d Z. 180,
Versionsregel Z. 205, AC-1 Z. 250, AC-4 Z. 253, AC-8 Z. 260, AC-9 Z. 261, Zwischenstände Z. 320.

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Services/ExerciseDatabase.swift` | `allExercises` (64 Einträge, Block `// MARK: - A2d-2c (Dehnung, Mobilisierung)` Z. 556 als Muster), `englishNameIds` Z. 606 (3 neue Aliase nach „Cat-Cow" Z. 664) |
| `Meditationstimer iOS/Localizable.xcstrings` | 6 Textschlüssel `exercise.<slug>.effect/.instructions` (de+en) + 3 Namensschlüssel (deutscher Name als Schlüssel) |
| `Contracts/catalog/builtin-exercises.json` | 64 → 67 Einträge, `catalogVersion` 1 → 2 (Z. 2) |
| `LeanHealthTimerTests/ExerciseCatalogTests.swift` Z. 146-148, 159-160, 270-273 | Tests aus dem gemeinsamen RED-Commit (#80), erwarten Spec-Namen, 67 Einträge, Version 2 |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` Z. 323, 333-334 | Vorschlagsliste enthält „Seated Forward Bend", „Shoulder Stretch Left/Right" → Weg für den App-Durchlauf; nicht ändern |
| `server/src/forms.ts` Z. 11, `server/test/mcp-read.test.ts` Z. 26/93/193 | lesen nur `.exercises` und vergleichen mit der Dateilänge; `catalogVersion` wird nirgends gelesen → keine Anpassung |

## Existing Patterns (A2d-1a/b/c, A2d-2a/b/c)
- Katalogeintrag: `ExerciseInfo(id:, name:, category:, effect: NSLocalizedString("exercise.<slug>.effect", value: DE, comment:), instructions: …)`.
- `localizedTexts(forId:bundle:)` löst Wirkung/Anleitung über `exercise.<slug>.*` auf → keine Logikänderung, nur Daten.
- Namensschlüssel bei DE ≠ EN (deutscher Name als Schlüssel); englischer Name zusätzlich in `englishNameIds`.
- Altschlüssel mit englischem Namen bleiben unverändert, solange die Vorschlagsliste sie nutzt.
- Kategorie `stretching` vielfach belegt (zuletzt Herabschauender Hund, Kobra-Dehnung).

## Dependencies
- Upstream: `Localizable.xcstrings`, Bundle-Lokalisierung.
- Downstream: Info-Blatt (per Kennung), Namensableitung (englischer Name → Kennung), Dienst und Referenz-Prüfer
  (lesen die Vertrags-JSON zur Laufzeit, keine feste Anzahl, keine Versionsprüfung).

## Scope (Schätzung)
- Dateien: 3; Swift ≈ 30, JSON ≈ 16 (inkl. Versionszeile), Texte ≈ 160 (9 × 17,8) → gesamt ≈ 205, unter 250.
- Risiko: LOW (nur Anhängen; die 64 vorhandenen Einträge bleiben unverändert).

## Erwartetes Testbild nach A2d-2d (Spec Z. 320)
- Alle A2d-Tests grün: `test_newExercises_haveTextsInDeAndEn_andCategory`, `test_idForEnglishName_returnsBuiltinId`,
  `test_catalog_matchesBuiltinExercisesJson` (67), `test_catalog_has67EntriesAndVersion2`, `test_first43Entries_unchanged`.
- App-Durchlauf im Simulator: „Seated Forward Bend" aus der Vorschlagsliste wählen; Info-Blatt zeigt Wirkung und
  Anleitung auf DE und EN.

## Risks & Considerations
- **Namensabweichung wie in A2d-2c (Produktfrage für `/20-analyse`):** Die Vorschlagsliste zeigt Deutschsprachigen
  heute „Vorbeuge im Sitzen" (Schlüssel „Seated Forward Bend", xcstrings Z. 9424); Spec und Test (Z. 146) nennen
  „Sitzende Vorbeuge". „Schulter-Dehnung links/rechts" (Z. 9674, 9691) stimmen mit der Spec überein. In A2d-2c hat der
  PO in derselben Lage die heutigen App-Namen gewählt („Kobra-Dehnung", „Katze-Kuh"); die Entscheidung bezog sich auf
  diese zwei Namen, nicht ausdrücklich als allgemeine Regel.
- `catalogVersion` 2 ist reine Vertragsangabe; kein Leser im Code außer dem Test → kein Migrationsrisiko.
- Altfehler #90 (Info-Blatt beim ersten Tipp leer) kann den App-Durchlauf stören → zweiten Tipp nutzen, im Beleg nennen.
- Fachtexte:
  - Sitzende Vorbeuge: Langsitz, aus der Hüfte mit langem Rücken nach vorn, dehnt Beinrückseite und unteren Rücken;
    Abgrenzung zur vorhandenen Hamstring-Dehnung (prüfen, wie diese formuliert ist, um Doppeltexte zu vermeiden).
  - Schulter-Dehnung links/rechts: Arm quer vor der Brust, mit der anderen Hand sanft heranziehen, Schulter tief;
    dehnt hintere Schulter und oberen Rücken. Zwei Einträge mit spiegelbildlichem Text (Seite benennen).
- Altschlüssel „Seated Forward Bend", „Shoulder Stretch Left/Right" nicht ändern, sonst bricht die heutige Vorschlagsliste.

### Open Questions
- [x] (entschieden, siehe unten) Deutscher Name Nr. 22: „Sitzende Vorbeuge" (Spec) oder „Vorbeuge im Sitzen" (heutige App, Linie aus A2d-2c)?

## Analysis

### Type
Feature (Datenerweiterung, letzte Runde A2d-2 von Epic #48)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Services/ExerciseDatabase.swift` | MODIFY | Block `// MARK: - A2d-2d (Dehnung)` mit 3 `ExerciseInfo` nach Katze-Kuh; 3 Aliase in `englishNameIds` (Seated Forward Bend, Shoulder Stretch Left/Right) |
| `Meditationstimer iOS/Localizable.xcstrings` | MODIFY | 6 Textschlüssel `exercise.<slug>.effect/.instructions` (de+en); 3 Namensschlüssel mit deutschem Namen als Schlüssel → EN (Muster „Kobra-Dehnung" Z. 12773) |
| `Contracts/catalog/builtin-exercises.json` | MODIFY | 3 Einträge anhängen (64 → 67), `catalogVersion` 1 → 2 |
| `LeanHealthTimerTests/ExerciseCatalogTests.swift` | MODIFY (nur RED, nur falls PO „Vorbeuge im Sitzen" wählt) | Z. 146 deutscher Name; analog A2d-2c Z. 144-145 |
| `DOCS/specs/features/feature-48-uebungskatalog.md` | MODIFY (nur falls Namenswechsel) | Tabelle Z. 105, Rundenzeile Z. 180 |

### Verifizierte Befunde (2026-11-16)
- JSON: 64 Einträge, `catalogVersion` 1. Tests Z. 146-148 erwarten Nr. 22-24 mit Kategorie `stretching`, Z. 270-273 67 Einträge + Version 2.
- Altschlüssel in xcstrings: „Seated Forward Bend" → de „Vorbeuge im Sitzen" (Z. 9418); „Shoulder Stretch Left/Right" → de „Schulter-Dehnung links/rechts" (Z. 9668/9685) = Spec. Altschlüssel bleiben unverändert (Vorschlagsliste nutzt sie).
- Vorhandene Hamstring-Dehnung links/rechts ist im Stehen (Ferse vorn), nennt Sitzen nur als Alternative → Sitzende Vorbeuge grenzt sich durch Langsitz, beide Beine, Fokus Beinrückseite + unterer Rücken ab.
- Einzige Abweichung Spec ↔ App: Name Nr. 22. A2d-2c-Linie (PO 2026-11-16): heutige App-Namen gewinnen, EN bleibt.

### Scope Assessment
- Files: 3 Produkt/Vertrag (+1 Test, +1 Spec bei Namenswechsel)
- Estimated LoC: ≈ +205 / -1 (Versionszeile); Teständerung 1 Zeile
- Risk Level: LOW (append-only, keine Logik)

### Technical Approach
Reines Anhängen nach dem A2d-2c-Muster. Kennungen fix laut Spec (`builtin.sitzende-vorbeuge`, `builtin.schulter-dehnung-links/-rechts`) — Kennung bleibt auch bei Namenswechsel, da Kennungen nie geändert werden und der Name nur Anzeige ist. Schulter-Texte spiegelbildlich mit benannter Seite. App-Durchlauf: „Seated Forward Bend" aus der Vorschlagsliste, Info-Blatt DE/EN (Altfehler #90: zweiter Tipp, #91: Kategorie im EN-Blatt deutsch, beide im Beleg nennen).
Alternative: Name gemäß Spec („Sitzende Vorbeuge") und den Altschlüssel auf diesen Namen umstellen → ändert, was Nutzer heute sehen; widerspricht der A2d-2c-Linie.

### Dependencies
Upstream Bundle-Lokalisierung; Downstream Info-Blatt, Namensableitung, Server/Referenz-Prüfer (lesen JSON dynamisch, `catalogVersion` ungelesen).

### Open Questions
- [x] PO-Entscheidung 2026-11-16: deutscher Name Nr. 22 = „Vorbeuge im Sitzen" (wie heute in der App). Kennung bleibt `builtin.sitzende-vorbeuge`. Spec Z. 105/180 und Test Z. 146 werden in A2d-2d angepasst (Test in RED-Phase), EN bleibt „Seated Forward Bend".
