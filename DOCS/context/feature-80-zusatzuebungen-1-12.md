# Context: feature-80-zusatzuebungen-1-12 (#80, Schnitt A2d-1 von Epic #48)

## Request Summary
Die ersten 12 der 24 neuen Katalogübungen (Spec-Tabelle Nr. 1-12: Hollow Hold … Australische Klimmzüge) werden an
den Katalog angehängt, mit Kennung, deutschem Namen, Kategorie, Wirkung und Anleitung auf Deutsch und Englisch.
Vertrags-JSON gleichgezogen: 55 Einträge, `catalogVersion` bleibt 1. Spec: `DOCS/specs/features/feature-48-uebungskatalog.md`
(freigegeben), Tabelle Z. 74-101, Ansatz Z. 186-191, AC-1, AC-4, AC-8, AC-9.

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Services/ExerciseDatabase.swift` | `allExercises` (43 Einträge mit `NSLocalizedString("exercise.<x>.effect", value: <DE>)`), `englishNameIds` (37 englische Namen → Kennung, 12 neue kommen dazu), `localizedTexts(forId:bundle:)` (Z. 535) |
| `Meditationstimer iOS/Models/ExerciseInfo.swift` | `ExerciseInfo` speichert bereits aufgelöste Texte, keine Text-Schlüssel |
| `Meditationstimer iOS/Localizable.xcstrings` | Muster: Name als Schlüssel (`Planke` → en `Plank`), Texte als `exercise.<x>.effect`/`.instructions` mit de+en |
| `Contracts/catalog/builtin-exercises.json` | 43 Einträge `{id,name,category}`, Version 1; nur anhängen |
| `LeanHealthTimerTests/ExerciseCatalogTests.swift` | Tests aus dem gemeinsamen RED-Commit (nicht ändern) |
| `server/test/mcp-read.test.ts` | Z. 94, 190, 194: feste Zahl **43** für den Katalog — liest dieselbe JSON |
| `Contracts/validator/src/catalog.ts`, `server/src/forms.ts`, `server/Dockerfile` | lesen die JSON zur Laufzeit (keine feste Anzahl gefunden) |

## Existing Patterns
- Katalogeintrag: `ExerciseInfo(id:, name:, category:, effect: NSLocalizedString(key, value: DE, comment:), instructions: …)`;
  englische Texte nur im String-Katalog.
- Englischer Name = englische Übersetzung des deutschen Namensschlüssels; zusätzlich Alias in `englishNameIds`
  (bei gleichem Namen, z. B. „Dips“, trifft schon der deutsche Name).

## Dependencies
- Upstream: `Localizable.xcstrings`, Bundle-Lokalisierung.
- Downstream: Info-Blatt (per Kennung), Namensableitung, Dienst (`catalog`-Werkzeug, Zählung `counts.exercise.builtin`),
  Referenz-Prüfer (Kennungen in Lieferungen).

## Erwartetes Testbild nach A2d-1
- `test_newExercises_haveTextsInDeAndEn_andCategory` läuft über alle 24 und bricht per `XCTUnwrap` bei Nr. 13 ab →
  bleibt rot bis A2d-2, aber nur mit „Kennung builtin.umgekehrtes-rudern fehlt"; Nr. 1-12 müssen davor fehlerfrei sein.
- `test_catalog_matchesBuiltinExercisesJson`, `test_first43Entries_unchanged`: rot nur an der Endanzahl (55 statt 67).
- `test_idForEnglishName_returnsBuiltinId`: 12 statt 24 Fehlmeldungen.

## Risks & Considerations
- **`localizedTexts(forId:bundle:)` gibt Wirkung/Anleitung aus dem Hauptbundle zurück**, nicht aus dem übergebenen
  Bundle; der Test fordert `tEn.effect != tDe.effect` → muss die Text-Schlüssel kennen (Schlüssel in `ExerciseInfo`
  oder aus der Kennung ableitbar). Betrifft auch die 43 bestehenden nicht (Test prüft nur die neuen).
- **Dienst-Tests mit fester 43** würden mit 55 Einträgen rot (Server-CI); in der Spec-Dateiliste von A2d-1 nicht
  genannt → in der Analyse klären (vermutlich Anzahl aus der Datei statt fester Zahl).
- Dateigrenze: ExerciseDatabase, ExerciseInfo (falls Schlüssel), xcstrings, JSON, Server-Test = 5.
- Zeilen: ~200 Textzeilen (xcstrings zählt mechanisch) + ~60 Swift → nahe der 250er-Grenze.
- Bilder/Kategorien: nur vorhandene Kategorien (`core`, `upperBody`).

## Analysis

### Type
Feature (Schnitt A2d-1 von Epic #48)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Services/ExerciseDatabase.swift` | MODIFY | 12 Einträge an `allExercises` anhängen (Schlüssel `exercise.<slug>.effect/.instructions`, slug = Kennung ohne `builtin.`); 12 englische Namen in `englishNameIds`; `localizedTexts(forId:bundle:)` löst Wirkung/Anleitung über das übergebene Bundle auf: `bundle.localizedString(forKey: "exercise.\(slug).effect", value: info.effect, table: nil)` (Rückfall = bisheriger Text für die 43 alten mit camelCase-Schlüsseln) |
| `Meditationstimer iOS/Localizable.xcstrings` | MODIFY | 24 Textschlüssel (de+en, `state: translated`); Namensschlüssel nur für die 4 Namen mit DE≠EN (Archer-Liegestütze, Decline-Liegestütze, Klimmzüge, Australische Klimmzüge); bei DE=EN liefert die Suche ohne Schlüssel den Namen unverändert |
| `Contracts/catalog/builtin-exercises.json` | MODIFY | 12 Einträge anhängen (55), `catalogVersion` bleibt 1 |
| `server/test/mcp-read.test.ts` | MODIFY | feste 43 entfernen (Z. 95 ersatzlos, Z. 194 → `(await catalogFile()).length`, Titel Z. 190); sonst Server-CI rot (`server.yml` läuft bei `Contracts/catalog/**`, kein Deploy-Job) |
| `LeanHealthTimerTests/ExerciseCatalogTests.swift` | – | unverändert (gemeinsamer RED-Commit) |

### Befund `localizedTexts`
Texte entstehen per `NSLocalizedString` beim Aufbau des Katalogs im Hauptbundle; `ExerciseInfo` hält fertige Texte, keine
Schlüssel. Daher wechselt `localizedTexts` die Sprache für Wirkung/Anleitung nicht → AC-8 (`tEn.effect != tDe.effect`)
wäre nie grün. Alternative (Schlüsselfeld in `ExerciseInfo`) verworfen: weitere Datei, Änderung an allen 43 Aufrufen,
kein Mehrwert. `Bundle(path: …/en.lproj)` hat keinen Sprachrückfall; fehlender Schlüssel → `value` (nie leer).
Unabhängig bestätigt durch Plan-Bewertung.

### Scope Assessment
- Dateien: 4 (Test unverändert)
- LoC realistisch: xcstrings ≈ 450 (24 × ~16 + 4 Namen × ~17), Swift ≈ 115, JSON ≈ 60, Server-Test ≈ 4 → **≈ 630**
  (Spec schätzte 240; ein xcstrings-Eintrag de+en belegt ~16 Zeilen). Programmcode ohne xcstrings ≈ 180.
- Risiko: LOW (nur Anhängen; Nutzerpfad der 43 alten unverändert)

### Erwartetes Testbild nach A2d-1 (für den Prüfbericht)
- `test_newExercises_haveTextsInDeAndEn_andCategory`: Nr. 1-12 fehlerfrei, Abbruch bei Nr. 13 → grün erst nach A2d-2
- `test_catalog_matchesBuiltinExercisesJson`, `test_catalog_has67EntriesAndVersion2`: rot nur an 67/Version 2
- `test_idForEnglishName_returnsBuiltinId`: nur noch die 12 Namen aus Nr. 13-24 rot
- `test_first43Entries_unchanged`, `test_catalogIds_matchRegexAndAreUnique`, `test_idForGermanName_returnsBuiltinId`: grün
- Server: `npm test` grün
- App-Durchlauf: Schritt „Klimmzüge"/„Pull-ups" anlegen, Info-Blatt zeigt Wirkung und Anleitung

### Optionen zur Zeilengrenze (±250 je Runde, Edit-Gate zählt .xcstrings mit)
| Option | Zeilen/Runde | Runden für 24 Übungen | Bemerkung |
|---|---|---|---|
| (a) 4 Übungen je Runde | ≈ 200 | 6 | passt; Katalog zwischendurch 47/51/55/… |
| (b) xcstrings-Textzeilen nicht zählen (Projektregel `loc_exclude_patterns`) | ≈ 180 Code | 2 | PO-Entscheid nötig; Code bleibt unter 250 |
| (c) Namensschlüssel nur bei DE≠EN | spart ≈ 140 | – | wird in jedem Fall angewendet |

Empfehlung: (b) + (c). Alternative: (a) (Plan-Bewertung empfahl (a)+(c)).

### Spec-Korrekturen (in /30-write-spec)
- A2d-1/A2d-2 Zeilenschätzung 240 → ≈ 630; Server-Test als Datei ergänzen
- Schlüsselkonvention `exercise.<slug>.*` und Anpassung `localizedTexts` in „Technischer Ansatz"

### Entscheidungen
- [x] PO 2026-11-15: Option (b), Übersetzungstexte zählen nicht zur Zeilengrenze; dazu (c). Eingetragen in
  `.claude/openspec.yaml` (`scope_guard.loc_exclude_patterns: '\.xcstrings$'`) im Arbeitsordner.
  **Technische Vorbedingung vor /50-implement:** Die Hooks lesen die Konfiguration aus dem Haupt-Checkout
  (`find_project_root` löst Worktrees zum Haupt-Repo auf). Die Regel muss daher vorher als eigene kleine
  Änderung auf `main` liegen und im Haupt-Checkout angekommen sein, sonst sperrt das Edit-Gate trotzdem.
  Prüfen mit `python3 -c "import config_loader as c; print(c.get_scope_loc_config())"` (muss `\.xcstrings$` zeigen).
- Folge für A2d-2: ebenfalls eine Runde (Nr. 13-24).

### Open Questions
- keine
