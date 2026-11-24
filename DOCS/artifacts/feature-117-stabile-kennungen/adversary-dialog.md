# Adversary Dialog — feature-117-stabile-kennungen
Spec: DOCS/specs/features/feature-117-stabile-kennungen.md
Datum: 2026-11-24 22:35

## Checkliste
- [x] Input: Die App liest Vorgaben aus dem Code (kein Schlüssel, Schlüssel unlesbar, oder Anhängen einer fehlenden Vorgabe durch `migratingPresets`).
- [x] Output: Jede Vorgabe trägt ihre feste Kennung aus der Tabelle; die Abschrift zeigt `own.<kennung>` identisch über App-Starts.
- [x] Side effects: `ClaudeStore.apply` schreibt bei `.missing` künftig die festen Kennungen in den Speicher. Gespeicherte Listen bleiben unverändert, auch Vorgaben darin mit zufälliger alter Kennung. Hat Henning eine Vorgabe aus seiner gespeicherten Liste gelöscht, hängt `migratingPresets` sie wie bisher wieder an, jetzt mit fester Kennung. Doppelte Kennungen sind ausgeschlossen: `migratingPresets` (Programme und Atemübungen) hängt eine Vorgabe nur an, wenn weder ihr Name noch ihre Kennung in der Liste vorkommt. Eine umbenannte Vorgabe zählt damit als vorhanden und wird nicht erneut angehängt (PO-Entscheidung 2026-11-24, aus Adversary-Befund F001).
- [x] **AC-1 (Golden, Programme):** Given der Code, When `defaultWorkoutSets` gelesen wird, Then tragen die 4 Programme (Name → Kennung) genau die Golden-Werte der Tabelle.
- [x] **AC-2 (Golden, Atemübungen):** Given der Code, When `MeditationTab.defaultPresets` gelesen wird, Then tragen die 6 Atemübungen (Name → Kennung) genau die Golden-Werte der Tabelle.
- [x] **AC-3 (verschieden):** Given alle 10 Kennungen, Then sind sie paarweise verschieden. Anzahl je Liste 4 bzw. 6 (kein stilles Hinzufügen ohne Golden-Wert).
- [x] **AC-4 (Abschrift, Schlüssel fehlt):** Given Zustand `.missing` für Programme und Atemübungen, When `TranscriptBuilder` die Abschrift baut, Then steht für jede der 10 Vorgaben `own.<golden-uuid>`.
- [x] **AC-5 (Abschrift, unlesbar):** Given Zustand `.unreadable`, When die Abschrift gebaut wird, Then steht für jede Vorgabe `own.<golden-uuid>`.
- [x] **AC-6 (Abschrift, Anhängen):** Given eine gespeicherte Liste, der eine Vorgabe fehlt, und `migratingPresets` hängt sie an, When die Abschrift gebaut wird, Then steht für die angehängte Vorgabe `own.<golden-uuid>`.
- [x] **AC-7 (gespeichert bleibt):** Given eine gespeicherte Liste mit zufälligen Kennungen (auch für Vorgaben mit Standardnamen), When sie geladen und in die Abschrift übernommen wird, Then bleiben diese Kennungen unverändert, nichts wird auf Golden-Werte umgeschrieben und es entsteht kein Duplikat.
- [x] **AC-8 (apply bei .missing):** Given Zustand `.missing`, When `ClaudeStore.apply` etwas anwendet, Then enthält die geschriebene Liste die Vorgaben mit den Golden-Kennungen.
- [x] **AC-10 (umbenannte Vorgabe):** Given eine gespeicherte Liste, in der eine Vorgabe ihre Golden-Kennung trägt, aber umbenannt ist (z. B. „Mein Burn“ mit der Kennung von „Quick Burn“), When `migratingPresets` (Programme bzw. Atemübungen) läuft, Then wird die Vorgabe mit dem Originalnamen nicht erneut angehängt, die Liste enthält jede Kennung genau einmal und die umbenannte Vorgabe bleibt unverändert.
- [x] **AC-9 (Regression):** Alle bestehenden Unit-Tests (u. a. `ClaudeStoreTests`, `TranscriptBuilderTests`, `WorkoutPhaseMigrationTests`) bleiben grün.

## Dialog

### Runde 1
**Adversary:** Diff gegen 0ffbaa1 gelesen. 10 Golden-UUIDs im Code gegen die Spec-Tabelle verglichen (WorkoutTab.swift, MeditationTab.swift:71ff), alle identisch, paarweise verschieden. Aufrufer von migratingPresets gesucht: ClaudeStore.swift:67/75, TranscriptBuilder.swift:31/34, WorkoutProgramsView.swift:352, MeditationTab.swift:480. Keine zweite Quelle für Vorgaben (ShortcutHandler.swift:109 und WorkoutProgramsView.swift:1346 nutzen nur Namen). Gesamte Unit-Suite im Simulator gelaufen: 459 passed, 0 failed, TEST SUCCEEDED (adversary-test-output.txt).
**Implementierer:** (nicht beteiligt, Isolation)

### Runde 2
**Adversary:** Fokus F001. Beide migratingPresets haben jetzt `name == ... || id == ...` (WorkoutProgramsView.swift:354, MeditationTab.swift:487). Szenario "Mein Burn" mit Kennung von "Quick Burn": Bedingung true, nicht angehängt, Liste ohne Duplikat; Tests testAC10_UmbenanntesProgramm... und testAC10_UmbenannteAtemuebung... passed. Randfälle: (a) Kollision Golden-Kennung mit Zufalls-ID: 2^-122, ignorierbar; wäre zudem korrekt (nicht angehängt). (b) Beschreibungs-Nachtrag läuft nur nach Name; umbenannte Vorgabe ohne Beschreibung bekommt keine, harmlos, vorheriges Verhalten. (c) Vorgabe, deren Name fehlt, aber deren Kennung in der Liste bei fremdem Eintrag steht: nicht angehängt, gewollt laut Spec (PO-Entscheidung). (d) Watch/Widget/Kurzbefehle: nutzen Namen, nicht betroffen. (e) .missing/.unreadable liefern direkt die Konstanten, kein Schreibzugriff im Ladepfad; apply schreibt bei .missing Golden (AC-8 Test passed). (f) Doppelnutzung derselben Konstante-Instanz: Value Types, kein Aliasing.
**Implementierer:** (nicht beteiligt)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERIFIED. Tests: 459 passed, 0 failed (4 Treffer auf "skipped" im Log sind Xcode-Meldungen, keine übersprungenen Tests; passed > 0). Alle 13 Punkte bewiesen.

## Bestätigungen

Confirmation: AC-1/AC-2/AC-3
  Code reference: Meditationstimer iOS/Tabs/WorkoutTab.swift:802
  Evidence: 4 feste UUIDs wie Spec; Golden-Tests passed
  Status: CONFIRMED

Confirmation: AC-2/AC-3, Input/Output
  Code reference: Meditationstimer iOS/Tabs/MeditationTab.swift:71
  Evidence: 6 feste UUIDs wie Spec; Zeile 487 Oder-Bedingung (F001 geschlossen für Atemübungen)
  Status: CONFIRMED

Confirmation: AC-6/AC-7/AC-10
  Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:354
  Evidence: Anhängen nur wenn weder Name noch Kennung vorhanden; AC-4..AC-8, AC-10 Tests passed
  Status: CONFIRMED

Confirmation: AC-9
  Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:352
  Evidence: gesamte Suite 459 passed / 0 failed

## Befunde

Keine blockierenden Befunde.
Finding: F002 (Hinweis)
  Severity: LOW
  Category: edge_case
  Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:357
  Description: Beschreibungs-Nachtrag läuft nur über den Namen; eine umbenannte Vorgabe mit Golden-Kennung und leerer Beschreibung bekommt keine.
  Spec requirement: AC-10 — umbenannte Vorgabe bleibt unverändert
  Conflict: kein Konflikt, entspricht sogar AC-10; nur dokumentiert.
  Remediation: keine nötig.

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: 459 passed, 0 failed, 0 übersprungen
Edge cases: All checked, none broken
Regressions: None found
Checklist: 13/13 points proven

## Geprüfte Dateien

- sha256:9650c0612b9fb7e9448ffb5d8911e7110cd84328c71d0cdf6946196ee2b0e3fd  Meditationstimer iOS/Tabs/MeditationTab.swift
- sha256:1e7136bc7a0a4cf09aef3e8f26d60403c04bf23e2f1d1f085d194adb17f06a40  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- sha256:a8181ae93bfc9eb5070d3b275c01a5af545ec7a7e50d9ae4147486f964daa317  Meditationstimer iOS/Tabs/WorkoutTab.swift

## Prüfbasis

- base: 0ffbaa12df8172b3462e6751952b092d74ddf761
- blob:03923abd2397bd690222e7976da50f527fa03b3a  Meditationstimer iOS/Tabs/MeditationTab.swift
- blob:87d5ec9bdcda77ca860a3e835c225c537a703e44  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
- blob:e314968ea93fc4eab68377c1523d759908f868b3  Meditationstimer iOS/Tabs/WorkoutTab.swift
