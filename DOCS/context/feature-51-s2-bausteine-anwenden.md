# Context: feature-51-s2-bausteine-anwenden (#51, Schnitt 2 von 3)

## Request Summary
Die App soll eine bereits gelesene Claude-Lieferung (Schnitt 1, `ClaudeDelivery.read`) **anwenden**: Übungen, Programme,
Atemübungen übernehmen, Rücknahmen ausführen, ganz oder gar nicht, idempotent über `deliveryId`, „das iPhone gewinnt".
Offen und in der Analyse zu entscheiden: Speicherort, Sicherung von `atemPresets`, Platzhalter für „Zeitpunkt der letzten Abschrift".

## Related Files (Stand HEAD bd96064, #48 gemergt)
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Models/ClaudeDelivery.swift` | Schnitt 1: `ClaudeDelivery.read(_:) throws(ClaudeDeliveryError)` (:57); Typen `ClaudeExercise`/`ClaudeProgram`(+`Step`)/`ClaudeBreath`/`ClaudeWithdrawal`, `ClaudeItem.unsupported`; `why`/`package` nur auf Lieferungsebene |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | `WorkoutSet` (:166, synth. Codable, Hashable), `WorkoutPhase` (:203, custom Codable, `exerciseId?`, `hint?` aus #48); `WorkoutSet.loadStored` mit Sicherung `workoutProgramSetsBackup.<ts>` (:318-337), `migratingPresets` |
| `Meditationstimer iOS/Tabs/WorkoutTab.swift` | Key `workoutProgramSets` (:44); `loadSets` nur in `.onAppear` (:165, :362); `saveSets` schreibt ganzes Array (:379), aus Editor/Löschen/Migration |
| `Meditationstimer iOS/Tabs/AtemView.swift` | `AtemView.Preset` (:43, synth. Codable, Hashable): id, name, emoji, inhale/holdIn/exhale/holdOut, repetitions, description? |
| `Meditationstimer iOS/Tabs/MeditationTab.swift` | Key `atemPresets` (:65); `loadPresets` (:462) **ohne Sicherung**: Lesefehler → Standardwerte, nächstes Speichern überschreibt; `savePresets` (:491) |
| `Meditationstimer iOS/Models/ExerciseInfo.swift` | `ExerciseInfo` (id `builtin.*`, kein Codable), `ExerciseOrigin {builtin, own, claude}` (:46), `ExerciseCategory` mit **deutschen** Rohwerten (:57) |
| `Services/ExerciseDatabase.swift` | statischer Katalog; `info(forId:)` (:627) nur builtin; `exerciseId(forName:)` (:709); `displayName(exerciseId:storedName:)` (:756) nimmt für own/claude den gespeicherten Namen. **Kein Laufzeitspeicher für weitere Übungen** |
| `LeanHealthTimerTests/ClaudeDeliveryDecodingTests.swift` | Schnitt-1-Tests, Muster für `#filePath`-Zugriff auf `Contracts/deliveries/valid` |
| `Contracts/deliveries/valid/*.json` | Beispielsatz (u. a. `exercise-and-program.json`, `package-with-withdrawal.json`, `package-mixed.json`, `program-builtin.json`, `own-exercise-reference.json`) |

## Existing Patterns
- Persistenz: JSON-Array in `UserDefaults`, je Liste genau eine Live-Lade-/Speicherstelle (Tab), Laden nur bei `.onAppear`.
- Rückwärtskompatible Felder: Optionals mit `encodeIfPresent`, custom `init(from:)` (Vorbild `WorkoutPhase` aus #48).
- Sicherung unlesbarer Daten: `WorkoutSet.loadStored` + `backUpUnreadable` (Vorbild für `atemPresets`).
- Vorgaben werden per **Name** ergänzt (`migratingPresets`), UUIDs der Vorgaben nicht stabil.
- Tests: XCTest, Host-App, Beispieldateien per `#filePath`, Mindestanzahl erzwingen.

## Dependencies
- Upstream: `ClaudeDelivery.read`, `ExerciseDatabase` (Kennung ↔ Name, Kategorie), `WorkoutSet`/`WorkoutPhase`, `AtemView.Preset`, `UserDefaults`.
- Downstream: Schnitt 3 (Kennzeichen „von Claude", Info mit Datum/Paket/Warum, Wiederherstellen, UI-Test), #57 (Abgleich mit dem Dienst ruft Anwenden auf, liefert Ergebnis zurück, setzt „Zeitpunkt der letzten Abschrift"), #59 (Tagebuch).
- Watch/Widget: teilen keine der betroffenen Dateien (geprüft, `project.pbxproj:118-145`).

## Existing Specs
- `openspec/specs/features/claude-annahme.md` — übergeordnete Spec, Verhalten 1–9, Schnitt-Zuschnitt
- `openspec/specs/integrations/claude-lieferformat.md` §2–3 (Felder), §7 (Anwendungsregeln)
- `docs/specs/features/feature-51-lieferung-annehmen.md` — Schnitt 1 inkl. „Ausblick: offene Punkte für Schnitt 2"
- `DOCS/context/analyse-51-57-claude-app.md` §5.1, §6, §7 (Teile veraltet: A2 ist inzwischen umgesetzt)

## Offene Punkte für die Analyse
1. **Speicherort:** (a) bestehende Listen + Katalog (Wortlaut `claude-annahme.md` §2), (b) eigener Speicher (Analyse 5.1), (c) Hybrid (Programme/Atemübungen als Kopie in die Listen, Übungen + Verwaltungsdaten/Gedächtnis in kleiner eigener Datei).
2. **Übungen:** Es gibt keinen Laufzeitspeicher; `claude.*`-Übungen brauchen einen (Name, Kategorie-Abbildung engl.→`ExerciseCategory`, Wirkung, Anleitung) und Auflösung in `info(forId:)`/`displayName`.
3. **Widerspruch Rücknahme:** Lieferformat §3.4/Konzept 9 „Zurückgenommenes bleibt wiederherstellbar" vs. `claude-annahme.md` §5 „entfernt" und PO 13.11. „Löschen ohne Papierkorb" (gilt für Hennings Löschen). Issue nennt „Wiederherstellen".
4. **„Angepasst" erkennen:** `modifiedAt` setzen beim Speichern im Editor nur bei echter Inhaltsänderung (Analyse T6).
5. **Zeitpunkt der letzten Abschrift:** existiert nicht; Platzhalter ohne #57 vorwegzunehmen (z. B. `nil` = nie abgeschrieben → jede Henning-Änderung gilt als unbekannt für Claude).
6. **Reload:** Tabs laden nur bei `.onAppear`; nach dem Anwenden Benachrichtigung + Neu-Laden, sonst überschreibt ein offener Tab die Lieferung.
7. **Sicherung `atemPresets`** analog `workoutProgramSets` (vor oder mit Schnitt 2).
8. **Gedächtnis:** letzte 50 `deliveryId`s mit Ergebnis.

## Risks & Considerations
- **Gespeicherte Daten:** neue Felder an `WorkoutSet`/`Preset` ändern synthetisiertes `Hashable`/Codable; alte JSONs müssen unverändert lesbar bleiben (Test mit Alt-JSON).
- **Verlorene Änderungen:** zwei Schreiber (Anwenden + offener Tab) auf denselben Key.
- **Ganz oder gar nicht** über zwei `UserDefaults`-Keys plus Gedächtnis ist nicht atomar; Reihenfolge/Kopie nötig oder ein Speicher.
- **Scoping-Limit** (±250 LoC, 4–5 Dateien): Schnitt 2 droht zu groß; ggf. weiter teilen (z. B. 2a Speicher+Programme/Atem, 2b Übungen+Rücknahme).
- `atemPresets` heute ohne Sicherung: jeder neue Schreibpfad erhöht das Verlustrisiko.
- Vorgaben-UUIDs instabil: nie gelieferte Bausteine über Vorgaben-UUIDs identifizieren, nur über `itemId`.

## Analysis

### Type
Feature (Schnitt 2 von 3 aus #51), für Henning noch unsichtbar.

### Entscheidungen (Tech Lead, 2026-11-20)
1. **Speicherort Hybrid:** Programme und Atemübungen als Kopie in die bestehenden Listen (`workoutProgramSets`, `atemPresets`) mit zwei
   optionalen Feldern je Typ: `claude: ClaudeOrigin?` {itemId, revision, why, packageId?, packageName?, deliveredAt} und `modifiedAt: Date?`.
   Synthetisiertes Codable bleibt, Alt-JSON liest sich unverändert (Test mit Alt-JSON). Übungen und Gedächtnis in **einem** Key
   `claudeState` (Codable `{exercises, log}`), damit beide zusammen geschrieben werden. Gegenvorschlag eigener Gesamtspeicher (Analyse 5.1)
   verworfen: widerspricht „Übernehmen in die bestehenden Listen" (`claude-annahme.md` §2), Henning müsste Geliefertes erst kopieren.
2. **Zeitpunkt der letzten Abschrift** wird nicht gespeichert, sondern ist Parameter `lastSnapshotAt: Date?` der Anwende-Funktion; #57 besitzt
   den Wert. `nil` = nie abgeschrieben → jedes gesetzte `modifiedAt` gilt als Claude unbekannt → `CHANGED_ON_IPHONE`.
3. **Rücknahme entfernt** (PO 13.11., Konzept §9: kein Papierkorb). Lieferformat §3.4 „wiederherstellbar" und Issue-Text „Wiederherstellen"
   sind veraltet; §3.4 in dieser Runde korrigiert, Issue kommentiert. Schnitt 3 baut kein Wiederherstellen.
4. **Übungen** kann Henning nicht bearbeiten → kein `modifiedAt`, Rücknahme einer Übung immer erlaubt. Gespeichert als eigener Codable-Record
   mit englischer Kategorie (Lieferformat), Abbildung auf `ExerciseCategory` über den Fallnamen. Rücknahme einer Übung, die ein bleibendes
   Programm nutzt: Übung weg, Phasen unberührt (Name bleibt gespeichert, Training läuft; nur die Info fehlt).
5. **`own.*`-Verweis** in einem gelieferten Programm: Name aus vorhandenen Phasen mit gleicher `exerciseId`; keiner gefunden → ganze Lieferung
   abgelehnt (`EXERCISE_UNKNOWN`), nichts geändert. `builtin.*` → deutscher Katalogname; `claude.*` → Name aus Lieferung oder `claudeState`.
6. **Ersetzen** (höhere `revision`) behält die lokale UUID, setzt `modifiedAt = nil`, übernimmt `revision`, `why`, Paket neu.
   Gleiche/niedrigere `revision` → ohne Wirkung. Von Henning gelöschter Baustein + höhere Fassung → wird neu angelegt (die Abschrift zeigte
   die Löschung, Claude liefert also bewusst neu).
7. **Ganz oder gar nicht:** reine Funktion `apply(delivery, to: State, lastSnapshotAt:, now:) -> (State, Result)`; jede Ablehnung lässt den
   Zustand unverändert. Ergebnis Codable: angewendet / ohne Wirkung / abgelehnt (Code, Grund). Gedächtnis: letzte 50 `deliveryId`s mit
   Ergebnis, zweite Anwendung liefert das gemerkte Ergebnis und ändert nichts.
8. **Schreiben (2b):** Listen zuerst, `claudeState` zuletzt (Absturz dazwischen: Wiederholung über `revision` ohne Wirkung, nichts verloren).
   Unlesbare Liste beim Anwenden → ablehnen, nichts schreiben, nicht ins Gedächtnis (vorübergehend).

### Zuschnitt (Limit 4–5 Dateien, ±250 LoC)
Geschätzt ~300 Zeilen Quellcode in 6 Dateien → zwei Runden:
- **2a (diese Runde):** reine Anwende-Logik ohne `UserDefaults`, Felder an `WorkoutSet`/`AtemView.Preset`, Unit-Tests über den Beispielsatz.
- **2b (eigene Runde, vor #57):** Laden/Schreiben der Keys, Sicherung `atemPresets` (parametrisiertes `backUpUnreadable`), Neu-Laden offener
  Tabs per Benachrichtigung, `modifiedAt` beim Speichern im Editor nur bei echter Inhaltsänderung, `ExerciseDatabase.info(forId:)` für `claude.*`.

### Affected Files 2a
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Models/ClaudeApply.swift` | CREATE | `ClaudeOrigin`, `ClaudeStoredExercise`, `ClaudeApplyState`, `ClaudeApplyResult`, Gedächtnis, `apply(...)` (~170 LoC) |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | MODIFY | `WorkoutSet` + `claude`, `modifiedAt` (~6 LoC) |
| `Meditationstimer iOS/Tabs/AtemView.swift` | MODIFY | `Preset` + `claude`, `modifiedAt` (~6 LoC) |
| `LeanHealthTimerTests/ClaudeApplyTests.swift` | CREATE | Beispielsatz, Idempotenz, ganz oder gar nicht, Fassungen, `CHANGED_ON_IPHONE`, Rücknahme einzeln/Paket, `own.*`, Alt-JSON |
| `Meditationstimer.xcodeproj/project.pbxproj` | MODIFY | nur falls neue Dateien nicht über Ordner-Referenz erfasst werden |

### Scope Assessment
- Files: 4 (+ ggf. Projektdatei) · Estimated LoC: ~+180 Quellcode, ~+220 Tests · Risk Level: LOW (neuer, nicht aufgerufener Code; Felder optional)

### Befunde für spätere Runden (nicht 2a)
- `WorkoutProgramsView.swift:1664/1766`: Schritt-Editor behandelt jede Nicht-`builtin`-Übung als eigene; Speichern macht aus `claude.x` ein
  `own.<slug>` und kappt die Übungs-Info → 2b oder Schnitt 3.
- `WorkoutProgramsView.swift:1424`: Info-Sheet im Programm leitet die Kennung aus dem Namen ab statt aus `phase.exerciseId` → Schnitt 3.
- `migratingPresets` ergänzt Beschreibung gleichnamiger Programme, auch eines Claude-Programms (ohne `modifiedAt`) → Test in 2b.
- Offener Editor + Anwenden: `onSave` ersetzt per UUID im aktuellen Zustand; nach Neu-Laden überschreibt Hennings Speichern Claudes neue
  Fassung (iPhone gewinnt, `modifiedAt` gesetzt) – gewollt, in 2b-Spec festhalten.
- Alternative für später: gemeinsamer Listen-Besitzer (`ObservableObject`) statt Benachrichtigung; zu groß für diese Runden.

### Open Questions
- keine PO-Frage offen (Rücknahme = entfernen ist PO-Entscheidung 13.11.).
