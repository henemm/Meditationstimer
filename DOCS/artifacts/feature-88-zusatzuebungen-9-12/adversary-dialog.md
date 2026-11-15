# Adversary-Protokoll Runde A2d-1c (#88)

Grundlage: Spec DOCS/specs/features/feature-48-uebungskatalog.md, Tabelle Nr. 9-12, Zeile A2d-1c, Namensschluessel-Regel. Nur lesend geprueft.
Testausgabe ExerciseCatalogTests: docs/artifacts/feature-88-zusatzuebungen-9-12/adversary_test_output.txt (das Ziel /tmp/adversary_test_output.txt blockiert der Hook secret_egress_guard, daher im Projektordner).

## Runde 1 - Pruefung gegen die Checkliste

Selbst gelaufen: ExerciseCatalogTests, 12 Faelle, 7 gruen, 5 rot wie erwartet: test_newExercises (1 Abbruch, ab Nr. 13), test_idForEnglishName (genau 12 Fehler = Nr. 13-24), test_catalog_matchesBuiltinExercisesJson (nur 55 vs 67), test_catalog_has67EntriesAndVersion2, test_defaultPrograms_referenceExistingCatalogIds (17 Meldungen, Nr. 13-24 betreffend, wie in der Spec). Keine unerwartete Rotstelle.

Skript-Pruefungen: JSON 55 == Swift 55 (Kennung, Name, Kategorie, Reihenfolge); Regex und Eindeutigkeit ok; catalogVersion 1; die ersten 51 gegenueber HEAD unveraendert (Praefix gleich), Diff rein additiv (236 Zeilen, 0 Loeschungen, nur 3 Dateien). xcstrings: gueltiges JSON, 723 -> 733 Schluessel, alle Alt-Schluessel unveraendert (auch "Pull-ups" -> de "Klimmzuege"), 10 neue Schluessel (8 Text de+en nicht leer, de != en, extractionState manual, state translated; 2 Namensschluessel "Klimmzuege" -> en "Pull-ups", "Australische Klimmzuege" -> en "Australian Pull-ups"). Swift-Default == de-Eintrag bei allen 8 Texten. englishNameIds: vier neue Aliase (Dips, Pull-ups, Chin-ups, Australian Pull-ups) auf richtige Kennungen, 49 Schluessel, keine Duplikate nach lookupKey (trim + klein). Fachlich: Klimmzuege Obergriff, Chin-ups Untergriff mit mehr Bizeps (Wirkung verweist ausdruecklich auf den Obergriff-Klimmzug), Australische rueckwaerts unter niedriger Stange mit Schwierigkeitshinweis, Dips an Barren/Bank mit Schulterwarnung; klar unterscheidbar, DE und EN inhaltlich deckungsgleich.

## Runde 2 - Gegenpruefung, Kompilat, Regression

- Kompiliertes App-Bundle (DerivedData Debug-iphonesimulator, Lean Health Timer.app): en.lproj/Localizable.strings: "Klimmzuege" => "Pull-ups", "Australische Klimmzuege" => "Australian Pull-ups", "Pull-ups" => "Pull-ups"; acht Text-Schluessel in EN englisch und nicht leer, in de.lproj deutsch, je DE != EN. Kein deutscher Rueckfall. de: "Klimmzuege" => "Klimmzuege", "Pull-ups" => "Klimmzuege" (alter Schluessel intakt). Zirkel/Kollision: "Pull-ups" (de Klimmzuege) und "Klimmzuege" (en Pull-ups) sind gegenseitig konsistent, keine Schleife.
- Vorschlagsliste (WorkoutProgramsView.swift:284-289 enthaelt "Dips", "Pull-ups", "Chin-ups", "Australian Pull-ups"; Anzeige per LocalizedStringKey): "Pull-ups" in DE vorher und nachher "Klimmzuege". "Australian Pull-ups" hat weder vorher noch nachher einen Schluessel, wird in DE also unveraendert englisch angezeigt (Kompilat: None) - bestehendes Verhalten, bleibt laut Spec bis A2c-2, kein Befund dieser Runde. Info per englischem Namen findet die Kennung (test_infoForEnglishName gruen).
- Regression: gesamte Unit-Suite mit derselben Ausschlussliste: Zeile 2 von test-scope-a2d-1c.txt ist byte-identisch zu Zeile 2 von feature-87-zusatzuebungen-5-8/test-scope-a2d-1b.txt (cmp), 14 skip-testing-Eintraege. Ergebnis: 249 passed, 0 failed, ** TEST SUCCEEDED ** (Vorrunde 249/0). Datei: docs/artifacts/feature-88-zusatzuebungen-9-12/test-scope-a2d-1c.txt.
- UI-Tests nicht gelaufen: reine Katalog-/Textdaten, keine Aenderung an Views.
- Kein Befund aus Runde 2.

## Checkliste
- [x] AC-1: JSON 55 == Swift 55 (Skript), Endanzahl 67 erst A2d-2.
- [x] AC-2: Regex/Eindeutigkeit, Test gruen.
- [x] AC-3, AC-5, AC-6: A2a, Tests gruen.
- [x] AC-4: Dips, Pull-ups, Chin-ups, Australian Pull-ups -> richtige Kennung; Nr. 13-24 rot (genau 12).
- [x] AC-7: test_infoForEnglishName gruen.
- [x] AC-8 (Nr. 9-12): Kennung, Name, upperBody, Wirkung und Anleitung DE+EN nicht leer und verschieden, im Kompilat belegt; Nr. 13-24/Version 2/67 ausserhalb A2d-1c.
- [x] AC-9: erste 51 (43 urspruenglich) unveraendert, append-only, catalogVersion 1.
- [x] AC-10 bis AC-30: ausserhalb A2d-1c, bestehende Tests gruen (249/0).
- [x] AC-31: nur 3 Produktdateien, Watch/Widget unberuehrt.

## Befunde
Keine.

## Geprueft (Code reference)
Code reference: Meditationstimer iOS/Services/ExerciseDatabase.swift:470
Code reference: Meditationstimer iOS/Services/ExerciseDatabase.swift:571
Code reference: Contracts/catalog/builtin-exercises.json:259
Code reference: Meditationstimer iOS/Localizable.xcstrings:12311

## Verdict
VERDICT: VERIFIED
Beide Runden: 12-Fall-Katalogsuite wie erwartet (5 erwartete Rotfaelle, genau Nr. 13-24), Scope-Suite 249/0 mit identischer Ausschlussliste, EN/DE-Texte und Namensschluessel im Kompilat belegt, keine Alias- oder Schluesselkollision.

## Geprüfte Dateien

- sha256:4f1bcc90df5a8a52af71ff4458a821d28ace0cd931d0a806aa85600bda502d67  Contracts/catalog/builtin-exercises.json
- sha256:ad40d8c0e7cb56e865f007c31ccbe3de480bb99d078bcf556015c7f259d5d9af  Meditationstimer iOS/Localizable.xcstrings
- sha256:85ade15d4fd7760605e6f399ef402de0282a4c88941871b417621808aa3f422c  Meditationstimer iOS/Services/ExerciseDatabase.swift

## Prüfbasis

- base: 29004470afb9ed4407e21fcd48c2e7c35ff4ed54
- blob:5b2ada7d04bb7f2cf442aabda5d00e85bd62c4c7  Contracts/catalog/builtin-exercises.json
- blob:cf92e7abba281afc7186220db8e90d3e0dcea8b3  Meditationstimer iOS/Localizable.xcstrings
- blob:9149d78c3855a89c05f4372f24ae549f74b51ef0  Meditationstimer iOS/Services/ExerciseDatabase.swift
