---
entity_id: fix-25c-tracker-anlage
type: bugfix
created: 2026-11-18
updated: 2026-11-18
status: draft
workflow: fix-25c-tracker-anlage
---

# Fix 25c: Tracker-Anlage aus Vorlage — zwei rote UI-Tests grün, Zweck erhalten (#25, Runde 25c, Cluster C)

## Approval

- [ ] Approved

## Purpose

Zwei UI-Tests aus Cluster C von #25 sind seit Februar rot. Sie sollen grün werden und weiterhin prüfen, wofür
sie gebaut wurden: Eine Gewohnheit aus einer Vorlage erscheint nach dem Anlegen in der Liste (C1) und übersteht
einen Neustart der App (C2). C2 ist Testschuld; die App-Logik zum Speichern bleibt unverändert, nur ein DEBUG-Testschalter für eine
Speicherdatei kommt dazu. C1 deckte in TDD RED einen echten Anzeigefehler auf: Die Tracker-Liste zeigt Namen aus
Vorlagen englisch („Gratitude“, „Mood“), obwohl die App deutsch läuft. Der PO hat am 2026-11-18 entschieden, die
Namen in der Liste in dieser Runde mit zu korrigieren.

## Source

| Feld | Wert |
|------|------|
| Entity | `fix-25c-tracker-anlage` |
| Spec-Datei | `DOCS/specs/bugfix/fix-25c-tracker-anlage.md` |
| Kontext & Analyse | `DOCS/context/fix-25c-tracker-anlage.md` |
| Übergeordnetes Ticket | #25 (Bestandsaufnahme rote UI-Tests), Cluster C |
| Vorige Runde | `DOCS/specs/bugfix/fix-25b-eindeutige-abfragen.md` |

## Root Cause

Reproduziert am 2026-11-18 (Stand `5a5ca62`, iPhone 17 Pro, iOS 27.2).

| Test | Ergebnis | Stelle |
|------|----------|--------|
| `testPresetTapCreatesVisibleTracker` (C1) | rot, 3/3 Wiederholungen | `:313` „Add Tracker button should exist“ |
| `testTrackerCreationFromPresetPersistsAfterRestart` (C2) | rot | `:396` „Doomscrolling tracker should persist after app restart“ |

- **C1 — Sprache:** Der Test startet mit `-AppleLanguages (de)`, sucht aber `app.buttons["Add Tracker"]`.
  XCUITest vergleicht den Schlüssel mit Kennung oder Beschriftung; die deutsche Beschriftung lautet „Tracker
  hinzufügen“ (`Localizable.xcstrings:868`), die Kennung `addTrackerButton` (`TrackerTab.swift:157`). Kein Treffer,
  Test rot. Die App ist an dieser Stelle richtig.
- **C1 — Anzeigename (Befund TDD RED, 2026-11-18):** Mit der Kennung kommt C1 bis `:328` und scheitert dort 3/3:
  Der Tracker ist angelegt, die Liste zeigt ihn als „Gratitude“. `TrackerRow.swift:88` und `:169` zeigen
  `Text(tracker.name)` wörtlich; gespeichert wird der englische Schlüssel (`TrackerModels.swift:559`), der zugleich
  Logik-Schlüssel ist (`TrackerRow.swift:35`). Die Übersetzungen „Gratitude“→„Dankbarkeit“, „Mood“→„Stimmung“ stehen
  im String-Katalog, werden in der Liste aber nie nachgeschlagen. Beleg: UI-Hierarchie beim Fehlschlag.
- **C2 — Testmodus:** `enable-testing` schaltet seit `68c4f9f` (2026-01-17) SwiftData auf „nur im Arbeitsspeicher“
  (`Meditationstimer_iOSApp.swift:32-43`). Der Test kam acht Tage später (`e7f467e`) und startet die App beim
  zweiten Mal mit demselben Argument neu, also mit leerem Speicher. Er konnte in dieser Form nie grün sein. C2
  kommt bis `:382` durch (Anlegen und Anzeigen funktionieren); erst die Prüfung nach dem Neustart scheitert.

## Affected Files

- `LeanHealthTimerUITests/LeanHealthTimerUITests.swift` (MODIFY, Zeilen ca. 293–397)
- `Meditationstimer iOS/Meditationstimer_iOSApp.swift` (MODIFY, Zeilen 31–50)
- `Meditationstimer iOS/Tracker/TrackerRow.swift` (MODIFY, Zeilen 88 und 169, nur Anzeige des Namens)

Keine weitere Datei wird geändert. `TrackerTab.swift`, `AddTrackerSheet.swift` und `TrackerModels.swift` bleiben
unberührt. Der gespeicherte Name bleibt der englische Schlüssel.

## Expected Behavior

### C1 — `testPresetTapCreatesVisibleTracker` (nur Test)

- Änderung: `app.buttons["Add Tracker"]` wird zu `app.buttons["addTrackerButton"]` (sprachunabhängige Kennung).
- Der Test prüft weiterhin: Vorlage antippen → Tracker erscheint sichtbar in der Liste, und zwar unter seinem
  deutschen Namen „Dankbarkeit“ (Testtext unverändert).

### C1 — Anzeigename in der Tracker-Liste (App)

- `TrackerRow.swift:88` und `:169` zeigen den Namen übersetzt:
  `Text(String(localized: String.LocalizationValue(tracker.name)))` statt `Text(tracker.name)`. `String(localized:)`
  statt `LocalizedStringKey`, damit eigene Namen von Nutzern nicht als Markdown gedeutet werden.
- Gibt es zu einem Namen keinen Eintrag im String-Katalog (eigene Tracker), erscheint er unverändert.
- `tracker.name` selbst und alle Vergleiche damit (z. B. `TrackerRow.swift:35`) bleiben unverändert.
- Nicht in dieser Runde (eigenes Ticket #97): Stimmungsstufen „Awful … Great“, `LevelSelectionView.swift:64`,
  `SmartRemindersView.swift:460`.

### C2 — `testTrackerCreationFromPresetPersistsAfterRestart` (Test + DEBUG-Schalter)

App (`Meditationstimer_iOSApp.swift`):

- Der Container-Aufbau (Zeilen 31–50) wird in eine Funktion `makeModelContainer()` gezogen.
- Unter `#if DEBUG` werden zwei neue Startargumente gelesen:
  - `uitest-disk-store`: nutzt `ModelConfiguration(url:)` auf `Application Support/uitest.store` (Verzeichnis wird
    bei Bedarf angelegt). Hat Vorrang vor dem In-Memory-Modus von `enable-testing`.
  - `uitest-reset-store`: löscht `uitest.store`, `uitest.store-wal` und `uitest.store-shm` vor dem Öffnen. Die
    `-wal`-Datei muss mit weg, sonst könnte SQLite im WAL-Modus alte Daten zurückspielen.
- Der DEBUG-Zweig zweigt vorne ab, damit `schema` im Release-Build nicht als ungenutzt gewarnt wird.
- Ohne diese Argumente verhält sich der Start exakt wie bisher (normaler `default.store`, bzw. In-Memory unter
  `enable-testing`). Der normale Speicher des Simulators wird nie berührt.

Test:

- Erster Start mit `enable-testing`, `uitest-disk-store`, `uitest-reset-store`: Vorlage Doomscrolling anlegen,
  Tracker erscheint in der Liste.
- Neustart nur mit `enable-testing`, `uitest-disk-store`: Doomscrolling-Tracker ist weiterhin sichtbar.
- Der Anlege-Knopf wird in beiden Teilen per `addTrackerButton` angesprochen.

Warum der Reset Pflicht ist: Der Seed `createDefaultTrackersIfNeeded` (`Services/TrackerModels.swift:893`) legt nur
bei leerem Speicher NoAlc und Mood an; Doomscrolling ist nur Vorlage (`TrackerModels.swift:583`). Ohne Reset beim
ersten Start könnte ein Rest aus früheren Läufen den Test falsch grün machen.

- Side effects: In der deutschen App zeigt die Tracker-Liste Namen aus Vorlagen deutsch (gewollt, PO 2026-11-18). Keine Lokalisierung, keine AppStorage-Keys, keine Berechtigungen. Release-Build
  unverändert. Die übrigen ca. 45 UI-Tests starten nur mit `enable-testing` und bleiben In-Memory.

## Verworfene Alternativen

- **Alternative: Unit-Test statt Neustart.** Neustart-Teil streichen und das Speichern per Unit-Test mit
  Datei-Container prüfen (`createFromPreset` → `save` → Container neu öffnen). Kein App-Code nötig, aber der Test
  prüft nicht, dass das Blatt `save()` aufruft (`AddTrackerSheet.swift:107–111`) — genau der Ursprungsfehler.
  Verworfen, weil der Zweck des Tests (echte Kette) verloren ginge.
- **Verworfen: `enable-testing` generell auf Datei umstellen.** Kippt die Entscheidung aus `68c4f9f` (Abstürze und
  Wechselwirkung zwischen Tests bei geteiltem Speicher) und riskiert alle ca. 45 anderen UI-Tests.

## Acceptance Criteria

1. `testPresetTapCreatesVisibleTracker` läuft einzeln als `Klasse/Methode` grün und prüft weiterhin die
   Sichtbarkeit des Trackers nach dem Anlegen.
2. `testTrackerCreationFromPresetPersistsAfterRestart` läuft einzeln als `Klasse/Methode` grün und prüft die
   echte Kette Vorlage → Speichern → Neustart. Nachweis: Würde `modelContext.save()` in
   `AddTrackerSheet.swift:107–111` fehlen, wäre der Test rot (Gegenprobe durch temporäres Entfernen, danach
   zurückgenommen).
3. Normalstart und Release-Build sind unverändert: Die neuen Argumente stehen ausschließlich unter `#if DEBUG`;
   ein Release-Build erzeugt keine neue Warnung; ohne die Argumente wird kein `uitest.store` angelegt und der
   `default.store` nicht angefasst.
4. Ein Testlauf zählt nur als bestanden, wenn das Protokoll `Executed N tests` mit N ≥ 1 zeigt; Einzeltests
   werden immer als `Klasse/Methode` aufgerufen (kein Nulllauf, siehe #33).
5. Gesamtlauf der UI-Suite zeigt keine neue Rotmeldung gegenüber dem Stand vorher (erwartet rot bleiben nur
   bekannte Fälle aus #25 außerhalb von Cluster C).
6. `git diff` gegen `main` zeigt nur die drei Affected Files (plus Spec/Doku dieses Workflows).
7. In der deutschen App zeigt die Tracker-Liste „Dankbarkeit“ statt „Gratitude“ und „Stimmung“ statt „Mood“; ein
   eigener Tracker mit frei gewähltem Namen erscheint unverändert.
   - Test: `testPresetTapCreatesVisibleTracker` (deutsch) prüft „Dankbarkeit“ nach dem Anlegen.
   - Test: neuer UI-Test `testTrackerListShowsGermanPresetNames` (deutsch, `enable-testing`): „Stimmung“ sichtbar,
     „Mood“ nicht vorhanden; danach Vorlage „Doomscrolling“ anlegen (Name ohne Eintrag im String-Katalog, steht
     stellvertretend für einen eigenen Namen) → erscheint unverändert als „Doomscrolling“.

## Test Plan

Hinweis: Simulator iOS 26.5 ist nicht installiert, `Scripts/run-uitests.sh` hat 26.5 fest verdrahtet (#74/#77).
Läufe erfolgen auf iPhone 17 Pro / iOS 27.2 mit einer Skriptkopie im Scratchpad (`SIMULATOR_OS="27.2"`); das
Repo-Skript bleibt unverändert.

- [ ] RED: Beide Tests vor der Änderung einzeln als `Klasse/Methode` ausführen, C1 rot an `:313`, C2 rot an `:396`
      (am 2026-11-18 belegt, Wiederholung im Workflow).
- [ ] GREEN C1: Nach der Testanpassung einzeln ausführen, mehrere Durchläufe, `Executed N tests` mit N ≥ 1.
- [ ] GREEN C2: Nach App-Start-Änderung und Testanpassung einzeln ausführen, mehrere Durchläufe hintereinander
      (zeigt, dass der Reset greift), `Executed N tests` mit N ≥ 1.
- [ ] Gegenprobe C2: `save()` im Blatt temporär entfernen → C2 muss rot werden; Änderung zurücknehmen.
- [ ] Release-Build: `xcodebuild` Release (oder Analyse des DEBUG-Schutzes) ohne neue Warnung.
- [ ] Regression: Gesamtlauf der UI-Suite (langer Lauf: nohup + Monitor, nie zwei Simulatoren), Ergebnisliste mit
      dem Stand vorher vergleichen.
- [ ] Diff-Prüfung: nur die drei Affected Files geändert.
- [ ] RED/GREEN AC 7: `testTrackerListShowsGermanPresetNames` vor der Änderung rot („Mood“ statt „Stimmung“),
      danach grün, `Executed N tests` mit N ≥ 1.
- [ ] Zusätzlich Durchlauf im Simulator (deutsch) als Nutzerbeleg: Liste zeigt „Stimmung“ und nach Anlegen
      „Dankbarkeit“.
- [ ] Unit-Tests: nicht betroffen (App-Start-Änderung nur unter `#if DEBUG`).

## Risiken

- App-Start ist kritischer Pfad: Änderung strikt unter `#if DEBUG`, Normalstart unverändert.
- Dateizustand zwischen Läufen: durch `uitest-reset-store` beim ersten Start abgefangen.
- Eigene Datei `uitest.store`, getrennt vom normalen Speicher; keine Berührung von Nutzerdaten im Simulator.
- Umfang: 2 Dateien, ca. +35/−8 LoC, Risiko niedrig (alles Neue unter `#if DEBUG`).

## Scope

- Dateien: 3
- LoC: ca. +37/−10
- Risiko: niedrig
- Reihenfolge: C1 → App-Start → C2 → Gesamtlauf der UI-Suite

## Dependencies

| Abhängigkeit | Art | Bedeutung |
|--------------|-----|-----------|
| `Meditationstimer_iOSApp.swift:31-50` | Upstream | einzige Stelle, die Startargumente liest und den echten Container baut (übrige `ModelConfiguration`-Treffer sind Previews) |
| `Services/TrackerModels.swift:893` | Upstream | Seed legt nur bei leerem Speicher NoAlc/Mood an; macht den Reset beim ersten Start nötig |
| `Meditationstimer iOS/Tracker/AddTrackerSheet.swift:107-111` | Upstream | `createFromPreset` → `save()` → `dismiss()`; die zu beweisende Kette, unverändert |
| `Meditationstimer iOS/Tabs/TrackerTab.swift:157` | Upstream | Kennung `addTrackerButton`, unverändert |
| #74/#77 | Umfeld | iOS 26.5 nicht installiert; eigenes Ticket, nicht Teil dieser Runde |

Kein Widget-, Watch- oder App-Group-Zugriff auf den Speicher.

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine

Keine neue ADR nötig: DEBUG-Testschalter nach dem bestehenden Muster `enable-testing`; die Entscheidung `68c4f9f`
(In-Memory für UI-Tests) bleibt Standard.

## Definition of Done

- [ ] C1 und C2 laufen einzeln als `Klasse/Methode` grün, je `Executed N tests` mit N ≥ 1
- [ ] Gegenprobe zeigt: ohne `save()` wird C2 rot
- [ ] Gesamtlauf der UI-Suite ohne neue Rotmeldung gegenüber dem Stand vorher
- [ ] Release-Build unverändert, keine neue Warnung
- [ ] Diff enthält nur die drei Affected Files (plus Workflow-Doku)
- [ ] Tracker-Liste zeigt in der deutschen App die deutschen Namen der Vorlagen
- [ ] #25 mit dem Ergebnis der Runde 25c kommentiert

## Changelog

- 2026-11-18: Initial spec created
- 2026-11-18: Befund TDD RED (C1 zeigt „Gratitude“); PO-Entscheidung: Anzeigename in der Liste in dieser Runde
  korrigieren, Rest in #97
