# Context: feature-93-zusatzuebungen-19-21 (#93, Runde A2d-2c von Epic #48)

## Request Summary
Nr. 19-21 der neuen Katalogübungen (Herabschauender Hund `stretching`, Cobra-Dehnung `stretching`, Cat-Cow `warmup`)
werden an den Katalog angehängt, mit Kennung, deutschem Namen, Kategorie, Wirkung und Anleitung DE/EN; dazu
Namensschlüssel „Herabschauender Hund" (EN „Downward Dog") und „Cobra-Dehnung" (EN „Cobra Stretch"). „Cat-Cow" lautet
laut Spec in beiden Sprachen gleich.
Spec: `DOCS/specs/features/feature-48-uebungskatalog.md` (freigegeben), Tabelle Z. 98-100, Rundenzeile A2d-2c Z. 175,
Namensschlüssel-Regel Z. 200, Zwischenstände Z. 316. Schnitt in vier Runden à 3 steht seit A2d-2a in der Spec.

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Services/ExerciseDatabase.swift` | `allExercises` (61 Einträge, Block `// MARK: - A2d-2b (Beine, Cardio)` Z. 530 als Muster), `englishNameIds` Z. 580 (3 neue Aliase nach Z. 635: Downward Dog, Cobra Stretch, Cat-Cow) |
| `Meditationstimer iOS/Localizable.xcstrings` | 6 Textschlüssel `exercise.<slug>.effect/.instructions` (de+en) + 2 Namensschlüssel „Herabschauender Hund", „Cobra-Dehnung" |
| `Contracts/catalog/builtin-exercises.json` | 61 → 64 Einträge, `catalogVersion` bleibt 1 (Version 2 erst in A2d-2d) |
| `LeanHealthTimerTests/ExerciseCatalogTests.swift` Z. 143-145 | Tests aus dem gemeinsamen RED-Commit (#80), unverändert |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` Z. 319-322 | Vorschlagsliste enthält „Downward Dog", „Cobra Stretch", „Cat-Cow" (englisch, `Text(exercise)` Z. 1994) → Weg für den App-Durchlauf; nicht ändern |

## Existing Patterns (A2d-1a/b/c, A2d-2a/b)
- Katalogeintrag: `ExerciseInfo(id:, name:, category:, effect: NSLocalizedString("exercise.<slug>.effect", value: DE, comment:), instructions: …)`.
- `localizedTexts(forId:bundle:)` löst Wirkung/Anleitung über `exercise.<slug>.*` auf → keine Logikänderung, nur Daten.
- Namensschlüssel nur bei DE ≠ EN (deutscher Name als Schlüssel); englischer Name zusätzlich in `englishNameIds`.
- Altschlüssel mit englischem Namen bleiben unverändert, solange die Vorschlagsliste sie nutzt (Spec Z. 200).
- Kategorien `stretching` (z. B. Quadrizeps-/Hamstring-/Waden-Dehnung, Schmetterlings-Dehnung) und `warmup`
  (Marschieren auf der Stelle, Beinpendel, Hüftkreisen) sind schon belegt → kein neuer Fall.

## Dependencies
- Upstream: `Localizable.xcstrings`, Bundle-Lokalisierung.
- Downstream: Info-Blatt (per Kennung), Namensableitung (englischer Name → Kennung), Dienst und Referenz-Prüfer
  (lesen die Vertrags-JSON zur Laufzeit, keine feste Anzahl seit A2d-1a).

## Analysis

### Type
Feature (Runde A2d-2c von Epic #48), reines Anhängen von Daten nach bewährtem Muster, sechste gleichartige Runde.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Services/ExerciseDatabase.swift` | MODIFY | 3 Einträge (herabschauender-hund, cobra-dehnung `stretching`; cat-cow `warmup`) + 3 Aliase in `englishNameIds` |
| `Meditationstimer iOS/Localizable.xcstrings` | MODIFY | 6 Textschlüssel + 2 Namensschlüssel |
| `Contracts/catalog/builtin-exercises.json` | MODIFY | 3 Einträge anhängen |

### Scope Assessment
- Dateien: 3; Programmcode ≈ 45 Zeilen (Swift ≈ 30, JSON ≈ 15), Texte ≈ 143 (8 × 17,8) → gesamt ≈ 190, unter 250.
- Risiko: LOW (nur Anhängen; die 61 vorhandenen Einträge bleiben unverändert).

### Erwartetes Testbild nach A2d-2c (Spec Z. 316)
- `test_newExercises_haveTextsInDeAndEn_andCategory`: Nr. 1-21 fehlerfrei, Abbruch bei Nr. 22 (`builtin.sitzende-vorbeuge`)
- `test_idForEnglishName_returnsBuiltinId`: nur noch 3 Namen rot (Nr. 22-24)
- `test_catalog_matchesBuiltinExercisesJson`, `test_catalog_has67EntriesAndVersion2`: rot nur an Endanzahl 67 / Version 2
- `test_first43Entries_unchanged`, Gleichlauf aller 64 vorhandenen Einträge: grün
- App-Durchlauf im Simulator: „Downward Dog" aus der Vorschlagsliste wählen; Info-Blatt zeigt Wirkung und Anleitung
  auf DE und EN (Name im Info-Blatt bleibt bis A2b englisch, Walk-Test-Lehre #88)

### Alternative
- #89 zuerst lösen, dann Nr. 19-24 als eine Runde ohne Textzählung: verworfen, #89 ist eigenes Ziel und aus der
  Worktree-Sitzung gesperrt.
- Nr. 19-21 mit Nr. 22-24 zusammenlegen: verworfen, 6 Übungen mit 5 Namensschlüsseln lägen bei ca. 400 Zeilen.

## Risks & Considerations
- **Namensabweichung zu den heutigen deutschen Übersetzungen (neu in dieser Runde):** Die Vorschlagsliste zeigt
  Deutschsprachigen heute „Kobra-Dehnung" (Schlüssel „Cobra Stretch", xcstrings Z. 2109) und „Katze-Kuh" (Schlüssel
  „Cat-Cow", Z. 1922). Die freigegebene Spec nennt „Cobra-Dehnung" und „Cat-Cow" (DE = EN, kein Namensschlüssel).
  „Downward Dog" → „Herabschauender Hund" (Z. 3019) stimmt mit der Spec überein. Folge bei Umsetzung laut Spec:
  bis zur Ablösung der Vorschlagsliste (A2c-2) heißt dieselbe Übung in der Liste „Katze-Kuh"/„Kobra-Dehnung", im
  Katalog „Cat-Cow"/„Cobra-Dehnung". Die Tests (Z. 144-145) sind auf die Spec-Namen festgelegt. In `/20-analyse`
  klären, ob das eine Produktfrage ist oder die Spec gilt.
- Altfehler #90 (Info-Blatt beim ersten Tipp leer) kann den App-Durchlauf stören → zweiten Tipp nutzen, im Beleg nennen.
- Fachtexte klar abgrenzen:
  - Herabschauender Hund vs. „Planke zu Herabschauender Hund" (fullBody, Bewegungsübung): hier gehaltene Dehnung von
    Waden, Beinrückseite und Schultern, Fersen Richtung Boden, Knie dürfen leicht gebeugt sein.
  - Cobra-Dehnung: Bauchlage, Oberkörper mit den Armen sanft anheben, Hüfte bleibt am Boden; dehnt Bauch und
    Hüftbeuger, mobilisiert die Brustwirbelsäule; Hinweis: nur so weit, wie der untere Rücken schmerzfrei bleibt.
  - Cat-Cow (`warmup`): Vierfüßlerstand, im Atemrhythmus Rücken runden und ins leichte Hohlkreuz gehen; Mobilisierung
    der Wirbelsäule, keine Haltedehnung.
- Kategorien laut Spec: Nr. 19/20 `stretching`, Nr. 21 `warmup`.
- Altschlüssel „Downward Dog", „Cobra Stretch", „Cat-Cow" nicht ändern, sonst bricht die heutige Vorschlagsliste.

### Open Questions
- [x] **PO-Frage (2026-11-16): deutsche Namen für Nr. 20/21.** Geprüft: Die App zeigt heute in der Vorschlagsliste
  „Kobra-Dehnung" (xcstrings Z. 2115) und „Katze-Kuh" (Z. 1928); die freigegebene Spec (Tabelle Z. 99-100) und die
  Tests (ExerciseCatalogTests Z. 144-145) nennen „Cobra-Dehnung" und „Cat-Cow". Empfehlung Claude: die heutigen
  App-Namen übernehmen (eine Übung, ein Name; „Kobra" ist die deutsche Schreibweise). Folge: Spec-Tabelle Nr. 20/21
  und Namensschlüssel-Regel anpassen (Cat-Cow wird DE ≠ EN → neun statt acht Namensschlüssel in A2d-2), Testzeilen
  144-145 in Phase 4 nachziehen, +1 Namensschlüssel (≈ +18 Zeilen, Summe ≈ 208 < 250). Alternative: Spec gilt
  unverändert, Abweichung bis zur Ablösung der Vorschlagsliste (A2c-2) hinnehmen.
  **Entscheidung PO 2026-11-16: „Kobra-Dehnung", „Katze-Kuh"** (EN unverändert „Cobra Stretch", „Cat-Cow").
  Auftrag für `/30-write-spec`: Spec-Tabelle Nr. 20 Name DE „Kobra-Dehnung", Kennung bleibt `builtin.cobra-dehnung`;
  Nr. 21 Name DE „Katze-Kuh", Kennung bleibt `builtin.cat-cow`; Namensschlüssel-Regel A2d-2: neun Namen mit DE ≠ EN
  (Nr. 21 dazu, „Cat-Cow" aus der Gleich-Liste); Zwischenstände Z. 316 prüfen. Phase 4: Testzeilen 144-145 auf die
  neuen DE-Namen. Die vorhandenen Schlüssel „Cobra Stretch"/„Cat-Cow" liefern DE bereits „Kobra-Dehnung"/„Katze-Kuh";
  neue Namensschlüssel „Kobra-Dehnung" und „Katze-Kuh" (deutscher Name als Schlüssel) kommen hinzu.
