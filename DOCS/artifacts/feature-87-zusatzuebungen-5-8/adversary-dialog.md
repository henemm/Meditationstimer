# Adversary-Protokoll Runde A2d-1b (#87)

Grundlage: Spec DOCS/specs/features/feature-48-uebungskatalog.md, Zeile A2d-1b. Nur lesend geprueft.
Testausgabe: /tmp/adversary_test_output.txt

## Runde 1 - Pruefung gegen die Checkliste

Selbst gelaufen: ExerciseCatalogTests, 12 Faelle, 7 gruen, 5 rot wie erwartet: test_newExercises (Abbruch bei Nr. 9), test_idForEnglishName (genau 16 Fehler = Nr. 9-24), test_catalog_matchesBuiltinExercisesJson (nur 51 vs 67), test_catalog_has67EntriesAndVersion2, test_defaultPrograms_referenceExistingCatalogIds. Keine unerwartete Rotstelle.

Skript-Pruefungen: JSON 51 == Swift 51 (Kennung, Name, Kategorie, Reihenfolge); Regex und Eindeutigkeit ok; catalogVersion 1; die ersten 47 gegenueber HEAD unveraendert, Diff rein additiv (236 Zeilen, 0 Loeschungen, nur 3 Dateien). xcstrings: gueltiges JSON, Alt-Schluessel alle unveraendert, +10 Schluessel (8 Text de+en nicht leer, de != en, extractionState manual, state translated; 2 Namensschluessel). Swift-Default == de-Eintrag. englishNameIds: vier neue Aliase auf richtige Kennungen. Fachlich: Sit-ups volle Bewegung, Crunches kleine Bewegung, Archer einseitig, Decline Fuesse erhoeht; Stil wie A2d-1a.

## Runde 2 - Gegenpruefung der Orchestrator-Evidenz und Randfaelle

- Ausschlussliste: Zeile 2 von test-scope-a2d-1a.txt und test-scope-a2d-1b.txt per Skript verglichen: je 14 skip-testing-Eintraege, Zeilen identisch (a == b). Nichts zusaetzlich ausgenommen. Protokoll 1b: 249 "passed", 0 "failed", ** TEST SUCCEEDED **. Gleiche Zahl wie A2d-1a, passend, da A2d-1b nur Katalogdaten ergaenzt.
- localizedTexts(forId:bundle:) (ExerciseDatabase.swift:611-618): loest Wirkung/Anleitung ueber das uebergebene Bundle mit Schluessel exercise.<slug>.effect/.instructions, Slug = Kennung ohne "builtin.". Die Slugs der vier Kennungen entsprechen exakt den xcstrings-Schluesseln. Beweis am kompilierten App-Bundle: en.lproj/Localizable.strings enthaelt fuer alle vier Kennungen englische Wirkung und Anleitung (z. B. "Strengthens the rectus abdominis ...", "Shifts most of the load ..."), de.lproj die deutschen; Namen: en "Archer-Liegestuetze" -> "Archer Push-ups", "Decline-Liegestuetze" -> "Decline Push-ups". Kein deutscher Rueckfall.
- Alias-Kollisionen: lookupKey (Z. 543) trimmt und macht klein; "Sit-Ups", "sit-ups", " CRUNCHES " loesen auf dieselbe Kennung, kein Konflikt. Kein bestehender Alias-Schluessel kollidiert (nur "Bicycle Crunches" enthaelt "Crunches", ist ein anderer Schluessel); Dictionary-Literal wuerde Doppelschluessel zur Laufzeit abbrechen lassen, Test laeuft aber.
- Doppelte xcstrings-Schluessel: "Sit-ups" und "Crunches" existieren als Schluessel nicht (weder vorher noch nachher), Kompilat en/de liefert None dafuer: kein Namensschluessel noetig (DE = EN) und nichts wird anders aufgeloest. "Archer Push-ups"/"Decline Push-ups" waren schon vorhanden (unveraendert), neu sind "Archer-Liegestuetze"/"Decline-Liegestuetze". Case-insensitive Dubletten in der Datei gibt es nur bei Daily check/Daily Check und Rhythm (seconds)/(Seconds): alt, unrelated, nicht von dieser Runde.
- Kein Befund aus Runde 2.

## Checkliste
- [x] AC-1: JSON 51 == Swift 51 (Skript), Endanzahl 67 ausserhalb A2d-1b.
- [x] AC-2: Regex/Eindeutigkeit, Test gruen.
- [x] AC-3: außerhalb A2d-1b (A2a), Test gruen.
- [x] AC-4: vier neue Aliase korrekt, Rest (Nr. 9-24) außerhalb A2d-1b.
- [x] AC-5: außerhalb A2d-1b (A2a), Test gruen.
- [x] AC-6: außerhalb A2d-1b (A2a), Test gruen.
- [x] AC-7: test_infoForEnglishName gruen.
- [x] AC-8 (Nr. 1-8): Nr. 5-8 vollstaendig, DE+EN im Kompilat belegt; Nr. 9-24/Version 2/67 außerhalb A2d-1b.
- [x] AC-9: erste 47 unveraendert, append-only, Version 1.
- [x] AC-10 bis AC-30: außerhalb A2d-1b.
- [x] AC-31: nur 3 Produktdateien, Watch/Widget unberuehrt.

## Befunde
Keine.

## Geprueft (Code reference)
Code reference: Meditationstimer iOS/Services/ExerciseDatabase.swift:611
Code reference: Contracts/catalog/builtin-exercises.json:240
Code reference: Meditationstimer iOS/Localizable.xcstrings:1

## Verdict
VERDICT: VERIFIED
Beide Runden: Evidenz des Orchestrators nachgeprueft (Ausschlussliste identisch, 249/0), EN-Texte im Kompilat belegt, keine Alias- oder Schluesselkollision.

## Geprüfte Dateien

- sha256:733a82467c346ef968c7d4b83177dabcc7064c8b42988e86ec49386804b88993  Contracts/catalog/builtin-exercises.json
- sha256:8ee3191a7c173ef123f0302610dbaa819f018eac67ce76facab53e3e42882303  Meditationstimer iOS/Localizable.xcstrings
- sha256:09e02567c4da875a6124a39c47a089267d5fdeaab6bb9d3ac93fb5cb5fef9b04  Meditationstimer iOS/Services/ExerciseDatabase.swift

## Prüfbasis

- base: 2f56d2efd05e7ab583fc5ce989a12fd0969ad725
- blob:5b2ada7d04bb7f2cf442aabda5d00e85bd62c4c7  Contracts/catalog/builtin-exercises.json
- blob:cf92e7abba281afc7186220db8e90d3e0dcea8b3  Meditationstimer iOS/Localizable.xcstrings
- blob:9149d78c3855a89c05f4372f24ae549f74b51ef0  Meditationstimer iOS/Services/ExerciseDatabase.swift
