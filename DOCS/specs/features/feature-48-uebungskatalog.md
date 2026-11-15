---
entity_id: feature-48-uebungskatalog
type: feature
created: 2026-11-14
updated: 2026-11-15
status: draft
workflow: feature-48-uebungskatalog
issue: 48
epic: 44
---

# Gemeinsamer Übungskatalog mit festen Kennungen und Hinweis je Übungsschritt (#48)

## Approval

- [ ] Approved

## Purpose

Die 43 eingebauten Übungen und 24 bisher nur als Namensvorschlag vorhandene Übungen werden zu einem Katalog mit festen Kennungen (`builtin.*`); Programmschritte verweisen per Kennung auf ihre Übung, und bestehende eigene Programme laden verlustfrei weiter. Zusätzlich bekommt jeder Schritt einen optionalen kurzen Hinweis, der im Training unter dem Ring steht und (bei eingeschalteten Ansagen) nach dem Namen angesagt wird. Beides ist die Voraussetzung dafür, dass Claude-Lieferungen (#51) Übungen per Kennung ansprechen und Schritte mit Hinweis liefern können.

## Source

- **Issue:** #48 „[Mac] A2 Gemeinsamer Übungskatalog mit festen Kennungen und Hinweis je Übungsschritt", Epic #44
- **Konzept:** `DOCS/konzept-claude-verbindung.md` §6.1 (Z. 89-101), §6.2 (Z. 103-111), §13 Stufe 0
- **Analyse und PO-Entscheidungen:** `DOCS/context/feature-48-uebungskatalog.md`
- **Vertrag:** `Contracts/schema/delivery-v1.schema.json` (`exerciseId`, `hint`), `Contracts/catalog/builtin-exercises.json`, `openspec/specs/integrations/claude-lieferformat.md`
- **Code:** `Meditationstimer iOS/Models/ExerciseInfo.swift`, `Meditationstimer iOS/Services/ExerciseDatabase.swift`, `Meditationstimer iOS/Views/ExerciseDetailSheet.swift`, `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` (`WorkoutPhase`, `PhaseEditorView`, `ProgressRingsView`, `SoundPlayer`), `Meditationstimer iOS/Tabs/WorkoutTab.swift` (Laden/Speichern, Vorgaben)

## Dependencies

| Abhängigkeit | Art | Zweck |
|--------------|-----|-------|
| `Contracts/catalog/builtin-exercises.json` | Upstream (Vertrag) | Quelle der festen Kennungen; wird um 24 Einträge angehängt (catalogVersion 2) |
| `Contracts/schema/delivery-v1.schema.json` | Upstream (Vertrag) | Hinweis-Grenze und -Zeichen; Kennungsmuster dort für `exerciseId` (`builtin|own|claude`), die App übernimmt es |
| `Localizable.xcstrings` | Upstream | Übungsnamen und -texte DE/EN; Schlüssel ist der deutsche Katalogname |
| `@AppStorage("speakExerciseNames")` (`SettingsSheet.swift`) | Upstream, unverändert | schaltet Namens- und Hinweisansage |
| UserDefaults `workoutProgramSets` | Upstream/Downstream | Speicher eigener Programme (JSON-Array), Schlüssel unverändert |
| #51 (B1a, `claude-annahme.md`) | Downstream | braucht Kennungen und das Feld `hint` |
| #53 (B1c, Abschrift) | Downstream | braucht `own.*`-Kennungen |
| Watch, Widget, Intents, HealthKit | unberührt | nutzen weder Programm- noch Übungsdaten |

## Design-Bezug

Freigegeben ist die Alternative „Hinweis unter dem Ring" (PO-Entscheidung 2026-11-14): `DOCS/artifacts/feature-48-uebungskatalog/entwurf.html`, veröffentlicht unter https://claude.ai/artifact/XrPS81A34yJzGMDacNYQiU. Ist-Stand-Screenshots im selben Ordner (`heute-*.jpg`). Im Ring bleibt der Text „Übung"; der Hinweis steht in eigener Zeile zwischen Ring und Zähler.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Die Änderung folgt dem bestehenden Muster (Programme als JSON-Array in UserDefaults, Katalog als Swift-Typ). Gewählt ist Variante (a): `WorkoutPhase` speichert `exerciseId` und `hint` als optionale Felder mit tolerantem Dekodieren; fehlende Kennungen werden beim Laden aus dem Namen abgeleitet. Alternative (b), die Kennung nur zur Laufzeit aus dem Namen zu berechnen, ist verworfen: Für `own.*` und `claude.*` (#51, #53) fehlt dann ein fester Anker, und jede Umbenennung bricht die Zuordnung. Eine Weichenstellung über das Projekt hinaus ist das nicht; der Vertrag (Schema, Katalog-JSON) ist bereits entschieden.

## Entscheidungen (verbindlich)

PO 2026-11-14:

1. Der Hinweis steht im Training **unter dem Ring** (eigene Zeile zwischen Ring und Zähler); im Ring bleibt „Übung".
2. Die 24 Zusatzübungen der früheren Vorschlagsliste bekommen Wirkung und Anleitung (DE/EN), Kategorie und eine `builtin.*`-Kennung und werden Teil des Katalogs (append-only, catalogVersion 2). Danach zeigt die Übungsauswahl nur Katalogübungen plus „Eigene Übung…", die zweite Vorschlagsliste entfällt, es gibt keine Rubrik „Weitere".

Technik (Tech Lead):

3. **Modell:** `WorkoutPhase` erhält `exerciseId: String?` und `hint: String?`, per `decodeIfPresent` in einem eigenen `init(from:)`. Alter Bestand ohne diese Felder lädt verlustfrei.
4. **Kennung aus Name, wenn sie fehlt** (beim Laden, in dieser Reihenfolge): (1) deutscher Katalogname, (2) englischer Name (frühere Vorschlagsliste), (3) Name mit Endung „links"/„rechts" auf eine Katalogübung ohne Endung (z. B. „Beinpendel links" → `builtin.beinpendel`), Vergleich ohne Beachtung von Groß-/Kleinschreibung und ohne Randleerzeichen; sonst (4) `own.<slug>`. Einmal gesetzt, wird eine gespeicherte Kennung nie neu berechnet.
5. **Slug-Regel für `own.*`:** Kleinbuchstaben; ä→ae, ö→oe, ü→ue, ß→ss, übrige Akzente entfernt; jede Folge aus Zeichen außerhalb `[a-z0-9]` wird zu einem `-`; führende und folgende `-` entfallen; bei weniger als 2 Zeichen wird `uebung-` vorangestellt, bei leerem Rest ist der Slug `uebung`; Länge höchstens 63 Zeichen (danach abschneiden, folgende `-` entfernen). Ergebnis passt immer zu `^(builtin|own|claude)\.[a-z0-9][a-z0-9-]{1,62}$`. Zwei Namen mit gleichem Slug teilen sich die Kennung (siehe Known Limitations).
6. **Name und Anzeige:** `name` bleibt gespeichert (bei `builtin.*` der deutsche Katalogname, damit ältere Fassungen lesbar bleiben) und ist der Anzeigename für `own.*`. Für `builtin.*` kommt der angezeigte Name lokalisiert aus dem Katalog.
7. **Herkunft** (mitgeliefert / eigen / von Claude) wird aus dem Präfix der Kennung abgeleitet (`builtin`/`own`/`claude`), kein gespeichertes Feld (passend zum Lieferformat).
8. **Datenverlust-Schutz:** Schlägt das Dekodieren des gespeicherten Programm-Arrays fehl, werden die Rohdaten gesichert, bevor auf die Vorgaben zurückgefallen wird; es wird nie still überschrieben. Ein fehlender Schlüssel (Erststart) ist kein Fehler und erzeugt keine Sicherung.
9. **Hinweis:** optional; eine Zeile; Zeilenumbrüche und alle übrigen vom Lieferschema verbotenen Zeichen (Steuerzeichen U+0000-001F und U+007F-009F, z. B. Tab, sowie Bidi-Steuerzeichen und die Zeilen-/Absatztrenner U+2028/U+2029; geschütztes Leerzeichen U+00A0 gilt als Leerzeichen) werden zu einem Leerzeichen, Ränder getrimmt; leer → `nil`; höchstens 80 UTF-16-Einheiten (strenger als die Grenze von 80 Codepunkten in Schema und Lieferformat, damit jeder Hinweis dort gültig ist); Kürzung nie mitten in einem Zeichen. Gilt für Eingabe und beim Dekodieren gleichermaßen.
10. **Anzeige des Hinweises:** nur in der Arbeitsphase des Schritts (auch pausiert), nicht in der Vorschau „Als nächstes" der Pause.
11. **Ansage:** Es gibt heute genau zwei Sprechstellen: die erste Übung nach dem Countdown und den Beginn jeder Pause, in der die *nächste* Übung angekündigt wird. Gesprochen werden die vier bestehenden Sätze „Übung %d von %d: Name", „letzte Übung: Name" (Schlüssel `Last exercise: %@`, deutscher Wert mit kleinem l, unverändert), „Runde %d von %d: Name", „Letzte Runde: Name" (Texte aus `Localizable.xcstrings`, unverändert). Bei vorhandenem Hinweis wird an den Satz „. Hinweis" angehängt (z. B. „Übung 2 von 5: Planke. Hüfte hoch halten"); ohne Hinweis bleibt der Satz wörtlich wie heute. Der Hinweis wird also mit der Ankündigung der Übung gesprochen, auch wenn diese zu Beginn der Pause erfolgt; Entscheidung 10 regelt nur die Anzeige. Nur bei eingeschalteter Einstellung `speakExerciseNames`; ist sie aus, wird weder Name noch Hinweis gesprochen (unverändert).
12. **Katalogtest:** Ein Swift-Test liest `Contracts/catalog/builtin-exercises.json` (über `#filePath`) und prüft den Gleichlauf mit `ExerciseDatabase` (Kennung, Name, Kategorie, Reihenfolge, Anzahl).
13. **Vorgabeprogramme** verweisen per Kennung. Die tote Kopie mit 10 Vorgaben in `WorkoutProgramsView.swift` wird entfernt; live ist `WorkoutTab.swift` (4 Vorgaben).
14. **Info-Knopf** sucht per Kennung (bei fehlender Kennung über dieselbe Namensableitung). Dadurch zeigt er auch bei früher aus der englischen Liste gewählten Übungen Inhalt (behebt den Bestandsfehler „Plank").

## Die 24 neuen Katalogübungen (angehängt hinter die bestehenden 43)

Die Kennung, der deutsche Katalogname (zugleich Schlüssel in `Localizable.xcstrings`), die Kategorie und der englische Name (bisheriger Vorschlagsname, wird englische Übersetzung und englischer Alias der Namensableitung) sind hier festgelegt. Wirkung und Anleitung (DE/EN) entstehen in der Umsetzung im Stil der bestehenden Einträge. Kategorien nutzen nur vorhandene Werte aus dem Katalog.

| Nr. | Kennung | Deutscher Name | Englischer Name | Kategorie |
|-----|---------|----------------|-----------------|-----------|
| 1 | `builtin.hollow-hold` | Hollow Hold | Hollow Hold | `core` |
| 2 | `builtin.dead-bug` | Dead Bug | Dead Bug | `core` |
| 3 | `builtin.flutter-kicks` | Flutter Kicks | Flutter Kicks | `core` |
| 4 | `builtin.v-ups` | V-Ups | V-Ups | `core` |
| 5 | `builtin.sit-ups` | Sit-ups | Sit-ups | `core` |
| 6 | `builtin.crunches` | Crunches | Crunches | `core` |
| 7 | `builtin.archer-liegestuetze` | Archer-Liegestütze | Archer Push-ups | `upperBody` |
| 8 | `builtin.decline-liegestuetze` | Decline-Liegestütze | Decline Push-ups | `upperBody` |
| 9 | `builtin.dips` | Dips | Dips | `upperBody` |
| 10 | `builtin.klimmzuege` | Klimmzüge | Pull-ups | `upperBody` |
| 11 | `builtin.chin-ups` | Chin-ups | Chin-ups | `upperBody` |
| 12 | `builtin.australische-klimmzuege` | Australische Klimmzüge | Australian Pull-ups | `upperBody` |
| 13 | `builtin.umgekehrtes-rudern` | Umgekehrtes Rudern | Inverted Rows | `upperBody` |
| 14 | `builtin.step-ups` | Step-ups | Step-ups | `legs` |
| 15 | `builtin.wandsitzen` | Wandsitzen | Wall-Sit | `legs` |
| 16 | `builtin.box-jumps` | Box Jumps | Box Jumps | `legs` |
| 17 | `builtin.skater-hops` | Skater Hops | Skater Hops | `cardio` |
| 18 | `builtin.seilspringen` | Seilspringen | Jump Rope | `cardio` |
| 19 | `builtin.herabschauender-hund` | Herabschauender Hund | Downward Dog | `stretching` |
| 20 | `builtin.cobra-dehnung` | Cobra-Dehnung | Cobra Stretch | `stretching` |
| 21 | `builtin.cat-cow` | Cat-Cow | Cat-Cow | `warmup` |
| 22 | `builtin.sitzende-vorbeuge` | Sitzende Vorbeuge | Seated Forward Bend | `stretching` |
| 23 | `builtin.schulter-dehnung-links` | Schulter-Dehnung links | Shoulder Stretch Left | `stretching` |
| 24 | `builtin.schulter-dehnung-rechts` | Schulter-Dehnung rechts | Shoulder Stretch Right | `stretching` |

Hälften für die Umsetzung: A2d-1 = Nr. 1-12, A2d-2 = Nr. 13-24.

## Zuordnung der früheren Vorschlagsliste (69 Namen)

Herleitung aus `exerciseSuggestions` (`WorkoutProgramsView.swift` Z. 221-302) gegen `builtin-exercises.json` und die englischen Übersetzungen in `Localizable.xcstrings` (Stand 2026-11-14): **6** Namen sind exakt Katalognamen (Russian Twists, Mountain Climbers, Glute Bridges, Burpees, High Knees, Butt Kicks), **2** greifen über die Endung links/rechts (Beinpendel links/rechts → `builtin.beinpendel`), **37** sind englische Namen bestehender Katalogübungen (Tabelle unten), **24** werden die neuen Katalogübungen (Tabelle oben, englischer Name = Spalte „Englischer Name"). Kein Name bleibt ohne Katalogentsprechung; ein künftig unbekannter Name wird nach Entscheidung 4 Schritt (4) zu `own.<slug>`.

Die Ableitung „englischer Name → Kennung" (Entscheidung 4 Schritt 2) ist eine feste Tabelle in `ExerciseDatabase`, nicht eine Rückübersetzung zur Laufzeit; sie enthält die 37 Zeilen unten und ab A2d die 24 englischen Namen der neuen Übungen.

| Englischer Name | Kennung |
|-----------------|---------|
| Plank | `builtin.planke` |
| Side Plank Left | `builtin.seitliche-planke-links` |
| Side Plank Right | `builtin.seitliche-planke-rechts` |
| Bicycle Crunches | `builtin.fahrrad-crunches` |
| Leg Raises | `builtin.beinheben` |
| Plank to Downward Dog | `builtin.planke-zu-herabschauender-hund` |
| Push-ups | `builtin.liegestuetze` |
| Diamond Push-ups | `builtin.diamond-liegestuetze` |
| Wide Push-ups | `builtin.breite-liegestuetze` |
| Pike Push-ups | `builtin.pike-liegestuetze` |
| Wall Push-ups | `builtin.wandliegestuetze` |
| Squats | `builtin.kniebeugen` |
| Jump Squats | `builtin.jump-kniebeugen` |
| Lunges | `builtin.ausfallschritte` |
| Reverse Lunges | `builtin.reverse-ausfallschritte` |
| Walking Lunges | `builtin.ausfallschritte-gehend` |
| Bulgarian Split Squats Left | `builtin.bulgarische-split-kniebeugen-links` |
| Bulgarian Split Squats Right | `builtin.bulgarische-split-kniebeugen-rechts` |
| Single-Leg Deadlift Left | `builtin.einbeiniges-kreuzheben-links` |
| Single-Leg Deadlift Right | `builtin.einbeiniges-kreuzheben-rechts` |
| Calf Raises | `builtin.wadenheben` |
| Standing Knee Raises | `builtin.knieheben-stehend` |
| Jumping Jacks | `builtin.hampelmaenner` |
| Marching in Place | `builtin.marschieren-auf-der-stelle` |
| Child's Pose | `builtin.kindspose` |
| Butterfly Stretch | `builtin.schmetterlings-dehnung` |
| Hip Flexor Stretch Left | `builtin.hueftbeuger-dehnung-links` |
| Hip Flexor Stretch Right | `builtin.hueftbeuger-dehnung-rechts` |
| Quadriceps Stretch Left | `builtin.quadrizeps-dehnung-links` |
| Quadriceps Stretch Right | `builtin.quadrizeps-dehnung-rechts` |
| Hamstring Stretch Left | `builtin.hamstring-dehnung-links` |
| Hamstring Stretch Right | `builtin.hamstring-dehnung-rechts` |
| Calf Stretch Left | `builtin.waden-dehnung-links` |
| Calf Stretch Right | `builtin.waden-dehnung-rechts` |
| Hip Circles | `builtin.hueftkreisen` |
| Leg Swing Left | `builtin.beinpendel` |
| Leg Swing Right | `builtin.beinpendel` |

## Spec-Widersprüche (entschieden)

1. **`claudeId` (`claude-annahme.md`, Z. 18) gegen `itemId` (Lieferformat/Schema):** Das Lieferformat samt Schema ist der Vertrag und wird vom Referenz-Prüfer des Dienstes durchgesetzt, es führt. A2 betrifft nur die Übungskennung (`exerciseId` am Schritt, `id` im Katalog) und legt kein Feld `claudeId` an. Aufgelöst wird der Widerspruch in #51 (B1a), Schnitt 1: `claude-annahme.md` wird dort auf die Namen des Schemas umgestellt. A2 trägt nur den Vermerk in `claude-annahme.md` nach (Schnitt A2b-0), damit niemand `claudeId` in den A2-Typen sucht.
2. **`claude-annahme.md`, Z. 37, nennt `own.*` nicht:** Der Abschnitt „Voraussetzung aus A2" wird um `own.<slug>` ergänzt (eigene Übungen, Regel in Entscheidung 5), ebenfalls in A2b-0 nachgezogen.
3. **`workouts.md` Requirement „Audio Cues" / Szenario „Exercise Name TTS (Workout Programs)" ohne Hinweis:** Es wird ein Szenario „Exercise Hint TTS" ergänzt (Entscheidung 11), ferner im Requirement „Workout Programs" ein Szenario für die Hinweiszeile unter dem Ring (Entscheidung 1, 10) und im Requirement „Exercise Database" ein Szenario für Kennungen und Katalogumfang (67 Übungen). Nachzug im Schnitt A2c-2 (gemeinsam mit den Szenarien zu den Vorgaben, siehe AC-26), damit A2b bei 5 Dateien bleibt.

## Scope

### Affected Files und Schnitte

Gesamt 13 Dateien (7 Produkt, 4 Test einschließlich `server/test/mcp-read.test.ts` ab A2d-1, 2 Doku), rund 2.100 Zeilen hinzu inklusive Tests und Texte (Produkt +1.700, davon rund 900 Textzeilen in `Localizable.xcstrings`, Tests +430; rund 400 Zeilen entfallen in A2c-2; Stand nach der Zeilenkorrektur A2d vom 2026-11-15); deshalb in Schnitte geteilt, jeder Schnitt mit höchstens 4-5 Dateien, ±250 Zeilen und jeweils eigenem lauffähigem Stand (Build grün, alle Tests des eigenen und der früheren Schnitte grün; Tests späterer Schnitte aus dem gemeinsamen RED-Commit dürfen rot sein und werden im Prüfbericht einzeln ausgewiesen, PO-Entscheidung 2026-11-15). Zeilen sind Schätzungen. PO-Entscheidung 2026-11-15: Zeilen in `Localizable.xcstrings` zählen nicht zur Grenze von ±250 (Projektregel `scope_guard.loc_exclude_patterns: '\.xcstrings$'` in `.claude/openspec.yaml`); die Texte werden trotzdem voll geprüft (Adversary, fachliche Gegenlesung). JSON zählt weiter mit. Die Regel liegt seit 2026-11-15 auf `main` (PR #86), wirkt aber erst, wenn der Haupt-Checkout auf `main` steht (die Hooks lesen die Konfiguration von dort; der Checkout steht auf einem alten Zweig, Wechsel aus der Worktree-Sitzung gesperrt). PO-Entscheidung 2026-11-15: A2d-1 deshalb in drei Runden zu je 4 Übungen (A2d-1a/b/c), jede einschließlich Texten unter ±250 Zeilen; die Ausnahme für `.xcstrings` wird dafür nicht gebraucht.

| Schnitt | Inhalt | Dateien | Zeilen (ca.) | PO-sichtbar |
|---------|--------|---------|--------------|-------------|
| A2a | Katalog mit Kennung, Namensableitung, Info-Knopf per Kennung | `Meditationstimer iOS/Models/ExerciseInfo.swift`, `Meditationstimer iOS/Services/ExerciseDatabase.swift`, `Meditationstimer iOS/Views/ExerciseDetailSheet.swift`, `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` (nur die zwei Aufrufe `ExerciseDetailSheet(...)` Z. 1242 und 1694 übergeben die aus dem Namen abgeleitete Kennung nach Entscheidung 4; ab A2b-0 die gespeicherte `exerciseId`), `LeanHealthTimerTests/ExerciseCatalogTests.swift` | Produkt 140, Test 90 | Info-Knopf zeigt auch bei englisch gespeicherten Namen Inhalt |
| A2d-1 | Zusatzübungen Nr. 1-12 | `Meditationstimer iOS/Services/ExerciseDatabase.swift`, `Meditationstimer iOS/Localizable.xcstrings`, `Contracts/catalog/builtin-exercises.json`, `server/test/mcp-read.test.ts` (beide festen 43 entfernt, sonst Server-CI rot: im Test „overview" entfällt `assert.equal(doc.counts.exercise.builtin, 43)` ersatzlos, weil die Zeile davor schon gegen die Katalogdatei prüft; im Test „catalog ohne Abschrift" wird `doc.items.length` gegen `(await catalogFile()).length` geprüft und die 43 aus dem Testtitel genommen); `LeanHealthTimerTests/ExerciseCatalogTests.swift` bleibt unverändert (Tests liegen schon aus dem gemeinsamen RED-Commit) | ca. 690 gesamt (Summe der drei Runden, Zeilen darunter; Texte jetzt genau gezählt mit 17 Zeilen je Text statt der früheren Schätzung 630) | kaum: das Info-Blatt der 12 Übungen, die schon heute in der Vorschlagsliste stehen (z. B. „Pull-ups"), zeigt nun Wirkung und Anleitung |
| A2d-1a (#80) | Nr. 1-4 (Hollow Hold, Dead Bug, Flutter Kicks, V-Ups) und Namensschlüssel „Beinpendel" | dieselben Dateien wie A2d-1, einschließlich `server/test/mcp-read.test.ts` | ca. 220: Texte ca. 150 (8 Texte + 1 Name zu je 17 Zeilen), Swift ca. 45, JSON ca. 20, Server-Test ca. 4 | kaum |
| A2d-1b | Nr. 5-8 (Sit-ups, Crunches, Archer-Liegestütze, Decline-Liegestütze), Namensschlüssel Archer/Decline | wie A2d-1a ohne Server-Test | ca. 235: Texte ca. 170, Swift ca. 45, JSON ca. 20 | kaum |
| A2d-1c | Nr. 9-12 (Dips, Klimmzüge, Chin-ups, Australische Klimmzüge), Namensschlüssel Klimmzüge/Australische Klimmzüge | wie A2d-1b | ca. 235 | kaum |
| A2d-2 | Zusatzübungen Nr. 13-24, catalogVersion 2 | wie A2d-1 (`ExerciseCatalogTests.swift` ebenfalls unverändert; `server/test/mcp-read.test.ts` nur, soweit nach A2d-1 noch etwas anzupassen ist) | analog A2d-1: ca. 630 gesamt, davon `Localizable.xcstrings` ca. 450 und Programmcode/JSON ca. 180 | nein |
| A2b-0 | Datenmodell, Migration, Sicherung | `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift`, `Meditationstimer iOS/Tabs/WorkoutTab.swift`, `LeanHealthTimerTests/WorkoutPhaseMigrationTests.swift`; Doku: `openspec/specs/features/claude-annahme.md` | Produkt 110, Test 110 | nein (Datenstand) |
| A2b | Hinweis sichtbar und hörbar, Auswahl aus Katalog | `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift`, `Meditationstimer iOS/Views/ExerciseDetailSheet.swift`, `Meditationstimer iOS/Localizable.xcstrings`, `LeanHealthTimerUITests/WorkoutHintUITests.swift`, `LeanHealthTimerTests/WorkoutPhaseMigrationTests.swift` (Ansage- und Auswahltests) | Produkt 150, Test 130 | ja, erste sichtbare Stufe |
| A2c-1 | Vorgaben mit Kennung | `Meditationstimer iOS/Tabs/WorkoutTab.swift`, `LeanHealthTimerTests/ExerciseCatalogTests.swift` (AC-27), `LeanHealthTimerTests/WorkoutPhaseMigrationTests.swift` (AC-30), `LeanHealthTimerUITests/WorkoutHintUITests.swift` (AC-28) | Produkt rund 40, Test rund 90 | nein (Vorgaben unverändert sichtbar) |
| A2c-2 | Toten Bildschirmteil samt 10er-Kopie und Vorschlagsliste entfernen, Doku-Nachzug | `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift`, `openspec/specs/features/workouts.md` | rund 400 weg, Doku rund 40 | nein (Aufräumen) |

Reihenfolge: A2a → A2d-1 (a → b → c) → A2d-2 → A2b-0 → A2b → A2c-1 → A2c-2. A2d muss vor A2b liegen, damit die Auswahl nur Katalogübungen zeigen kann, ohne dass vorhandene Namen verloren gehen.

### Estimated Changes

| Bereich | Dateien | LoC (ca.) |
|---------|---------|-----------|
| Produkt (alle Schnitte) | 7 verschiedene | +1.700 / -400 (davon rund 900 Zeilen reine Texte in `Localizable.xcstrings`, zählen nicht zur Grenze) |
| Tests | 3 neue Dateien, 1 angepasste (`server/test/mcp-read.test.ts`) | +430 |

## Technischer Ansatz

### Katalog (`ExerciseInfo`, `ExerciseDatabase`) — A2a, A2d

- `ExerciseInfo` erhält `id: String` (Kennung). Die Herkunft ist eine berechnete Eigenschaft (`origin`: `builtin`/`own`/`claude`) aus dem Präfix, kein gespeichertes Feld.
- `ExerciseDatabase`: jeder Eintrag trägt seine Kennung (Reihenfolge wie `builtin-exercises.json`, neue Einträge angehängt). Neue Zugriffe: Suche per Kennung, Ableitung Kennung aus Name nach Entscheidung 4 (inklusive Tabelle englischer Namen) und die Slug-Funktion nach Entscheidung 5 (`own.*`).
- Anzeigename lokalisiert über `String(localized:)` mit dem deutschen Katalognamen als Schlüssel. Für die 43 bestehenden Übungen sind die englischen Namen der früheren Vorschlagsliste bereits englische Übersetzungen dieser deutschen Schlüssel in `Localizable.xcstrings`. Für die 24 neuen gibt es heute nur Einträge mit dem englischen Namen als Schlüssel (z. B. „Pull-ups", von der Vorschlagsliste); A2d legt die fehlenden deutschen Namensschlüssel neu an (Regel im übernächsten Punkt).
- Schlüsselkonvention für die neuen Texte (A2d): `exercise.<slug>.effect` und `exercise.<slug>.instructions`, slug = Kennung ohne `builtin.`; die 43 alten Einträge behalten ihre bisherigen camelCase-Schlüssel.
- `localizedTexts(forId:bundle:)` löst Wirkung und Anleitung künftig über das übergebene Bundle auf (`bundle.localizedString(forKey: "exercise.\(slug).effect", value: <bisheriger Text>, table: nil)`, ebenso `instructions`). Begründung: `ExerciseInfo` hält fertig aufgelöste Texte aus dem Hauptbundle, daher wechselte die Sprache bisher nicht; AC-8 fordert unterschiedliche Texte in DE und EN. Rückfall für die 43 alten Einträge ist der bisherige Text (unverändertes Verhalten). Verworfene Alternative: ein Schlüsselfeld in `ExerciseInfo` (weitere Datei, Änderung an allen 43 Einträgen, kein Mehrwert).
- Namensschlüssel in `Localizable.xcstrings` nur für Namen mit DE ≠ EN; bei DE = EN liefert die Suche ohne Schlüssel den Namen unverändert. In A2d-1 sind das genau vier (Abgleich mit der Tabelle Nr. 1-12): Archer-Liegestütze (Archer Push-ups), Decline-Liegestütze (Decline Push-ups), Klimmzüge (Pull-ups), Australische Klimmzüge (Australian Pull-ups). Gleich lauten Hollow Hold, Dead Bug, Flutter Kicks, V-Ups, Sit-ups, Crunches, Dips und Chin-ups. Die 12 englischen Namen kommen zusätzlich in `englishNameIds`. Zusätzlich, unabhängig von Nr. 1-12: Der fehlende Namensschlüssel der bestehenden Übung „Beinpendel" (EN „Leg Swing", siehe Abschnitt Texte) wird ebenfalls in A2d-1 angelegt; in A2d-1 entstehen also fünf Namensschlüssel. Die heutigen Einträge mit englischem Schlüssel (z. B. „Pull-ups" → DE „Klimmzüge") bleiben unverändert, solange die Vorschlagsliste sie nutzt; sie werden mit der Liste in A2c-2 entfernt, falls dann nichts mehr auf sie verweist.
- `builtin-exercises.json` wird in A2d-2 (nicht schon A2d-1) auf `catalogVersion` 2 gesetzt; nach A2d-1 stehen 55 Einträge bei Version 1, die bestehenden 43 Einträge bleiben unverändert (Reihenfolge, Kennung, Name, Kategorie); die 24 neuen werden angehängt. Der Referenz-Prüfer des Dienstes liest dieselbe Datei.

### Datenmodell und Laden (`WorkoutPhase`, `WorkoutTab`) — A2b-0

- `WorkoutPhase`: neue Felder `exerciseId: String?`, `hint: String?`; eigenes `init(from:)` mit `decodeIfPresent` für beide, übrige Felder (`id`, `name`, `workDuration`, `restDuration`) wie bisher; `encode` schreibt beide Felder nur, wenn gesetzt. Der bestehende `init(id:name:workDuration:restDuration:)` (Z. 210) erhält die Parameter `exerciseId: String? = nil` und `hint: String? = nil` am Ende, sodass alle heutigen Aufrufe unverändert kompilieren. Nach dem Dekodieren: fehlende Kennung ableiten (Entscheidung 4), Hinweis normalisieren (Entscheidung 9).
- Laden in `WorkoutTab` (Pfad `workoutProgramSets`, aktuell `try? JSONDecoder()`): bei vorhandenen Daten, die sich nicht dekodieren lassen, vor dem Rückfall auf Vorgaben die Rohdaten unter einem neuen Sicherungsschlüssel `workoutProgramSetsBackup.<Unix-Sekunden>` in UserDefaults ablegen. Die Dekodier- und Sicherungslogik steht als statische Funktion beim Typ (Name und Signatur werden in der RED-Phase durch die Tests festgelegt), damit sie ohne UI testbar ist. `migrateSets` (Vorgaben per Name ergänzen, Beschreibungen nachfüllen) bleibt unverändert.
- Speichern bleibt ein JSON-Array unter `workoutProgramSets`.

### Editor, Training, Ansage — A2b

- `PhaseEditorView`: Übungsauswahl zeigt die 67 Katalogübungen (lokalisierte Namen, nach Kategorie wie bisher) plus „Eigene Übung…" mit Freitext. Die Prüfung „eigen oder nicht" richtet sich nach Katalog statt nach der Vorschlagsliste (`exerciseSuggestions`); A2b nimmt die Liste aus der Auswahl, aus dieser Prüfung und aus dem Standardnamen neuer Schritte (heute `exerciseSuggestions.first` der alphabetisch sortierten Liste, Z. 302/1830, also „Archer Push-ups"; künftig wie heute der alphabetisch erste Eintrag, nun der Katalogübungen nach lokalisiertem Namen, auf Deutsch „Archer-Liegestütze" `builtin.archer-liegestuetze`, mit gesetzter Kennung — gleiches Verhalten, geprüft in `test_selectingCatalogOrOwnExercise_setsExerciseId`); die dann unbenutzte Liste selbst entfernt erst A2c-2. Wahl aus dem Katalog setzt `exerciseId` und deutschen Katalognamen in `name`; „Eigene Übung…" setzt `own.<slug>` aus dem eingegebenen Namen. Neues einzeiliges Feld „Hinweis (optional)", Eingabe auf 80 UTF-16-Einheiten begrenzt, Normalisierung nach Entscheidung 9.
- `ProgressRingsView`: unter dem Ring (zwischen Ring und Zähler) eine Zeile mit dem Hinweis, nur wenn vorhanden und nur in der Arbeitsphase. Der Name im Training und im Picker kommt lokalisiert aus dem Katalog (`builtin.*`) bzw. unverändert (`own.*`).
- Ansage: Der gesprochene Text wird an den zwei heutigen Sprechstellen gebildet (`beginSessionAfterCountdown` Z. 930-934 und `getNextExerciseNameForTTS` Z. 1399-1425, aufgerufen zu Beginn der Pause Z. 1441-1446); eine kleine reine Funktion bildet aus Satzform, lokalisiertem Namen und Hinweis den Satz nach Entscheidung 11 und ist unit-testbar.
- `ExerciseDetailSheet` (bereits in A2a, AC-7): Suche per Kennung statt per Name; die Detailansicht erhält die Kennung (Fallback: Ableitung aus dem Namen). A2b ändert daran nur den lokalisierten Titel.

### Vorgaben (A2c-1) und Aufräumen (A2c-2)

- Die 4 Vorgabeprogramme in `WorkoutTab.swift` setzen `exerciseId` explizit. `public struct WorkoutProgramsView` (ab Z. 472) bleibt als Namensraum erhalten, weil `WorkoutTab` seine verschachtelten Typen nutzt (`WorkoutSetRow`, `AddSetCard`, `SetEditorView`, `PresetInfoSheet`, `WorkoutProgramSessionCard`, darin Editor und Training). Er verliert seine `View`-Konformität und wird zum reinen Namensraum (`public enum WorkoutProgramsView` ohne Fälle; die verschachtelten Typen bleiben unverändert darin, Aufrufe wie `WorkoutProgramsView.SetEditorView(...)` gelten weiter). Da ein `enum` keine gespeicherten Instanz-Eigenschaften haben darf, entfallen **alle Instanz-Member** des bisherigen Structs (Z. 473 bis vor den ersten verschachtelten Typ und verstreute weitere): sämtliche `@State`-Felder (`sets` mit Startwert `defaultWorkoutSets`, `showingInfo`, `showingEditor`, `showSettings`, `showingCalendar`, `showingNoAlcLog`, `runningSet`), `@EnvironmentObject streakManager`, `setsKey`, `init()`, `body`, `loadSets`/`saveSets`, `migrateSets` (Z. 621), `emojiChoices`/`randomEmoji()` (Z. 656-657) und jedes weitere Instanz-Member; es bleiben nur die verschachtelten Typen (z. B. `OverlayBackgroundEffect`, falls von verbleibenden Typen benutzt, sonst entfällt er mit). Wird ein Instanz-Member noch von einem verschachtelten Typ benutzt, wird es zu `static`. Maßstab ist der Build. Entfernt wird damit auch der tote Bildschirmteil — `loadSets`/`saveSets` auf `workoutProgramSets` (Z. 611 ff., die den Datenschutz aus A2b-0 umgehen würden) —, die nur davon benutzte 10er-Vorgabeliste (Z. 306) und `exerciseSuggestions`; der Rückfall-Typ für Nicht-iOS (Z. 2065) wird ebenfalls zum leeren `public enum WorkoutProgramsView`, damit beide Plattformzweige denselben Typ deklarieren. Vor dem Entfernen weist eine Codesuche nach, dass `WorkoutProgramsView()` nirgends als Bildschirm instanziiert wird (auch `getNextAnnouncementText` ohne Aufrufer, wenn dabei berührt und unreferenziert; sonst unverändert lassen).

### Neue accessibilityIdentifier (für die UI-Tests)

- `workout.phaseEditor.exercisePicker` (Übungsauswahl im Schrittdialog)
- `workout.exercisePicker.option.<exerciseId>` (Zeile je Katalogübung) und `workout.exercisePicker.own` („Eigene Übung…")
- `workout.phaseEditor.hintField` (Hinweisfeld)
- `workout.training.hint` (Hinweiszeile unter dem Ring)
- `workout.training.infoButton` (Info-Knopf im Training)
- Weitere nötige Kennungen für Programmzeilen und Schritt-Hinzufügen-Knopf werden in der RED-Phase benannt und hier im Changelog nachgetragen.

### Texte (`Localizable.xcstrings`)

| Schlüssel (DE) | EN |
|----------------|----|
| Hinweis (optional) | Hint (optional) |
| Beinpendel (fehlt heute als Schlüssel; nur „Beinpendel links/rechts" existieren; Eintrag in A2d-1, das ohnehin die Textdatei ändert) | Leg Swing |
| z. B. 12 Wiederholungen, langsam | e.g. 12 reps, slow |
| 24 Übungsnamen, Wirkung und Anleitung laut Tabelle | Übersetzung je Eintrag |

Alle neuen Einträge mit `"extractionState": "manual"` und `"state": "translated"`, sonst Großschreibung im Debug-Build (Memory Bug 38).

## Acceptance Criteria

Schnitt-Zuordnung in Klammern. „Katalog" meint `ExerciseDatabase` in der App.

### A2a

- **AC-1 Gleichlauf mit dem Vertrag (A2a, nach A2d fortgeschrieben):** Given `Contracts/catalog/builtin-exercises.json` und `ExerciseDatabase`, When beide verglichen werden, Then haben sie gleiche Anzahl, Reihenfolge und je Eintrag gleiche Kennung, gleichen Namen und gleiche Kategorie (Stand A2a: 43, Stand ab A2d-2: 67).
- **AC-2 Kennung gültig und eindeutig (A2a):** Given alle Katalogkennungen, When sie gegen `^(builtin|own|claude)\.[a-z0-9][a-z0-9-]{1,62}$` geprüft werden, Then passt jede, und keine Kennung kommt doppelt vor.
- **AC-3 Deutscher Name → Kennung (A2a):** Given der deutsche Katalogname „Planke", When die Kennung abgeleitet wird, Then lautet sie `builtin.planke`; für jeden Katalognamen liefert die Ableitung dessen Kennung.
- **AC-4 Englischer Name → Kennung (A2a, A2d-1/2 für die 24 neuen):** Given ein Name aus der früheren englischen Vorschlagsliste (z. B. „Plank", „Push-ups"), When die Kennung abgeleitet wird, Then ist es die Kennung der entsprechenden Katalogübung (`builtin.planke`, `builtin.liegestuetze`); jeder englische Name der Tabelle oben liefert nach A2d die dort genannte Kennung.
- **AC-5 Endung links/rechts (A2a):** Given der Name „Beinpendel links" (oder „… rechts"), When die Kennung abgeleitet wird, Then lautet sie `builtin.beinpendel`; ein Name mit „links", dessen Grundname nicht im Katalog steht, wird `own.*`.
- **AC-6 Herkunft aus Präfix (A2a):** Given die Kennungen `builtin.planke`, `own.mein-lauf` und `claude.x1`, When `origin` gelesen wird, Then ist sie `builtin`, `own` bzw. `claude`; es gibt kein gespeichertes Herkunftsfeld.
- **AC-7 Info per Kennung auch bei englischem Namen (A2a):** Given ein Schritt mit dem früher gespeicherten Namen „Plank" ohne Kennung, When der Info-Knopf die Übung sucht, Then findet er den Katalogeintrag „Planke" mit Wirkung und Anleitung (vorher: leer).

### A2d

- **AC-8 24 neue Katalogübungen (A2d-1: Nr. 1-12, A2d-2: Nr. 13-24):** Given die Tabelle „Die 24 neuen Katalogübungen", When der Katalog geladen wird, Then enthält er jede dort genannte Kennung mit deutschem Namen und Kategorie, nicht leerer Wirkung und Anleitung auf Deutsch und auf Englisch; nach A2d-2 hat der Katalog 67 Einträge und `catalogVersion` im JSON ist 2.
- **AC-9 Bestehende 43 unverändert (A2d-1, A2d-2):** Given der Stand vor A2d, When A2d umgesetzt ist, Then stehen die ersten 43 Einträge in `ExerciseDatabase` und JSON in unveränderter Reihenfolge mit unveränderter Kennung, unverändertem Namen und unveränderter Kategorie (append-only).

### A2b-0

- **AC-10 Altbestand lädt verlustfrei (A2b-0):** Given gespeichertes JSON im alten Format (nur `id`, `name`, `workDuration`, `restDuration` je Schritt), When es geladen wird, Then bleiben alle Programme, Schritte, Namen, Zeiten, Runden und Schritt-`id`s unverändert; `hint` ist `nil`, und `exerciseId` ist nach Entscheidung 4 abgeleitet.
- **AC-11 Ableitung beim Laden (A2b-0):** Given alte Schritte mit den Namen „Planke", „Plank", „Beinpendel links" und „Mein Lauf!", When sie geladen werden, Then lauten die Kennungen `builtin.planke`, `builtin.planke`, `builtin.beinpendel` und `own.mein-lauf`; der gespeicherte `name` bleibt je Schritt wörtlich erhalten.
- **AC-12 Slug-Regel (A2b-0):** Given die Namen „Übung 1", „Ä", „!!", „" und ein 100 Zeichen langer Name, When `own.<slug>` gebildet wird, Then entstehen `own.uebung-1`, `own.ae`, `own.uebung`, `own.uebung` und eine Kennung mit höchstens 63 Zeichen nach dem Punkt; jede passt zur Kennungs-Regex.
- **AC-13 Rundreise (A2b-0):** Given ein Programm mit Schritten, die `exerciseId` und `hint` tragen, When es kodiert und wieder dekodiert wird, Then sind alle Felder gleich; gespeicherte Kennungen werden beim Laden nicht neu berechnet (auch nicht bei geändertem Namen).
- **AC-14 Hinweis-Normalisierung (A2b-0):** Given Hinweise „  langsam  ", „a\nb", „a\tb", „a\u{2028}b", „", „   " und „\u{00A0}", When sie normiert werden, Then entstehen „langsam", „a b", „a b", „a b" und dreimal `nil`; ein Hinweis mit mehr als 80 UTF-16-Einheiten wird auf höchstens 80 gekürzt, ohne ein Zeichen (z. B. ein Emoji) zu zerreißen.
- **AC-15 Kaputtes JSON wird gesichert (A2b-0):** Given unter `workoutProgramSets` liegen nicht dekodierbare Daten, When die Programme geladen werden, Then liegen die Rohdaten byte-gleich unter `workoutProgramSetsBackup.<Unix-Sekunden>`, und erst danach greifen die Vorgaben.
- **AC-16 Keine Sicherung ohne Fehler (A2b-0):** Given kein Wert unter `workoutProgramSets` (Erststart) oder gültiges JSON, When geladen wird, Then wird kein Sicherungsschlüssel angelegt.
- **AC-17 Spec-Nachzug (A2b-0):** Given `claude-annahme.md`, When A2b-0 abgeschlossen ist, Then nennt „Voraussetzung aus A2" auch `own.<slug>` und vermerkt, dass `claudeId` in #51 auf die Schema-Namen umgestellt wird (Review-Kriterium).

### A2b

- **AC-18 Hinweis im Editor → im Training sichtbar (A2b):** Given ein Programm mit einem Schritt, in dessen Hinweisfeld „12 Wiederholungen, langsam" steht, When das Programm gestartet ist und der Schritt in der Arbeitsphase läuft, Then steht dieser Text in `workout.training.hint` unter dem Ring (zwischen Ring und Zähler), und im Ring steht weiterhin „Übung".
- **AC-19 Ohne Hinweis keine Zeile (A2b):** Given ein Schritt ohne Hinweis, When er in der Arbeitsphase läuft, Then existiert `workout.training.hint` nicht, und das Layout bleibt wie heute. In der Pause („Als nächstes") steht nie ein Hinweis.
- **AC-20 Ansagetext (A2b):** Given ein Programm mit 5 Schritten, Schritt 2 „Planke" mit dem Hinweis „Hüfte hoch halten", When der Ansagetext für Schritt 2 gebildet wird, Then lautet er „Übung 2 von 5: Planke. Hüfte hoch halten" (englische App-Sprache: „Exercise 2 of 5: Plank. Hüfte hoch halten", Name lokalisiert, Hinweis wörtlich); ohne Hinweis „Übung 2 von 5: Planke" wie heute. Dasselbe Anhängen gilt für die Schlüssel `Last exercise: %@`, `Round %d of %d: %@` und `Last round: %@` (Wortlaut aus `Localizable.xcstrings`).
- **AC-21 Ansage nur bei eingeschalteter Einstellung (A2b):** Given `speakExerciseNames` ist aus, When ein Schritt mit Hinweis beginnt, Then wird weder Name noch Hinweis gesprochen; bei eingeschalteter Einstellung wird der Text nach AC-20 gesprochen, sowohl für die erste Übung (nach dem Countdown) als auch bei der Ankündigung der nächsten Übung zu Beginn der Pause.
- **AC-22 Auswahl zeigt nur Katalog (A2b):** Given die App läuft mit `-AppleLanguages (de)` und der Schrittdialog ist offen, When die Übungsauswahl geöffnet wird, Then enthält sie die 67 Katalogübungen mit deutschen Namen (z. B. `workout.exercisePicker.option.builtin.planke` „Planke") und `workout.exercisePicker.own`, aber keine englischen Vorschlagsnamen wie „Plank" oder „Push-ups".
- **AC-23 Wahl setzt Kennung (A2b):** Given der Nutzer wählt „Planke" aus der Auswahl bzw. „Eigene Übung…" mit dem Namen „Mein Lauf", When er den Schritt speichert und das Programm neu lädt, Then trägt der Schritt `builtin.planke` bzw. `own.mein-lauf`, und der Name „Mein Lauf" bleibt Anzeigename.
- **AC-24 Hinweis-Eingabegrenze (A2b):** Given das Hinweisfeld, When mehr als 80 UTF-16-Einheiten oder ein Zeilenumbruch eingegeben werden, Then wird auf höchstens 80 begrenzt und eine Zeile erzwungen; ein leeres Feld speichert `nil`.
- **AC-25 Texte lokalisiert (A2b):** Given die App läuft auf Deutsch bzw. Englisch, When der Schrittdialog erscheint, Then lauten Feldbeschriftung und Platzhalter „Hinweis (optional)"/„z. B. 12 Wiederholungen, langsam" bzw. „Hint (optional)"/„e.g. 12 reps, slow", im Debug-Build ohne Großschreibung.
- **AC-26 Spec-Nachzug (A2c-2):** Given `openspec/specs/features/workouts.md`, When A2c-2 abgeschlossen ist, Then enthält es Szenarien für die Hinweiszeile, die Hinweisansage und den Katalog mit Kennungen (Review-Kriterium).

### A2c-1 und A2c-2

- **AC-27 Vorgaben mit Kennung (A2c-1; die bisher dateiweite `private let defaultWorkoutSets` in `WorkoutTab.swift` Z. 813 wird dafür dateiweit `let` (internal), damit der Test sie über `@testable import` erreicht):** Given die 4 Vorgabeprogramme in `WorkoutTab.swift`, When sie gebaut werden, Then trägt jeder Schritt eine `exerciseId` mit `builtin.*`, die im Katalog existiert (Unit-Test über die Vorgabeliste).
- **AC-28 Info-Knopf bei Vorgabe (A2c-1):** Given das Vorgabeprogramm „Core Circuit" mit dem Schritt „Planke" wird im Training gestartet, When der Nutzer den Info-Knopf (`workout.training.infoButton`) antippt, Then zeigt das Blatt Wirkung und Anleitung der Planke, nun über die Kennung `builtin.planke` statt über den Namen (heute findet die Namenssuche „Planke" bereits; der Test sichert, dass der Wechsel auf die Kennung nichts verliert).
- **AC-29 Tote Kopie entfernt (A2c-2):** Given `WorkoutProgramsView.swift`, When A2c-2 abgeschlossen ist, Then enthält die Datei weder die Vorgabeliste mit 10 Programmen noch `exerciseSuggestions`; Build und alle Tests sind grün (Review-Kriterium durch Suche im Code).
- **AC-30 Vorhandene Programme der Nutzer bleiben (A2c-1):** Given ein bereits gespeicherter Bestand mit Vorgaben und eigenen Programmen, When die App startet, Then sind alle Programme unverändert vorhanden (`migrateSets` ergänzt weiterhin fehlende Vorgaben per Name).

### Schnittübergreifend

- **AC-31 Unberührt (alle Schnitte):** Given Watch-App und Widget, When gebaut werden, Then sind sie unverändert und kompilieren; AppStorage-Schlüssel `workoutProgramSets` und `speakExerciseNames` sind unverändert; es gibt keine neuen Berechtigungen.

## Test Plan

### Unit-Tests (`LeanHealthTimerTests/`, Aufruf mit `-only-testing`, gültig nur mit `Executed N tests`, N ≥ 1)

`ExerciseCatalogTests.swift` (angelegt in A2a, erweitert in A2d):
- [ ] AC-1: `test_catalog_matchesBuiltinExercisesJson` (Kennung, Name, Kategorie, Reihenfolge, Anzahl; liest die JSON über `#filePath`, Mindestanzahl erzwungen) — Stand A2a erfüllt (2026-11-15), rot nur an der Endanzahl 67 bis A2d
- [x] AC-2: `test_catalogIds_matchRegexAndAreUnique`
- [x] AC-3: `test_idForGermanName_returnsBuiltinId`
- [ ] AC-4: `test_idForEnglishName_returnsBuiltinId` (alle 37 früheren englischen Namen und, ab A2d, die 24 der Tabelle) — die 37 erfüllt in A2a (2026-11-15), die 24 folgen in A2d
- [x] AC-5: `test_idForNameWithLeftRightSuffix_resolvesBase` und `test_idForUnknownSuffixName_isOwn`
- [x] AC-6: `test_origin_derivedFromPrefix`
- [x] AC-7: `test_infoForEnglishName_findsCatalogEntry`
- [ ] AC-8: `test_newExercises_haveTextsInDeAndEn_andCategory` (läuft über alle 24 der Tabelle und bricht bei der ersten fehlenden Kennung ab; nach A2d-1 also erst bei Nr. 13, grün ab A2d-2) und `test_catalog_has67EntriesAndVersion2` (beide liegen schon aus dem gemeinsamen RED-Commit vor und prüfen den Endstand 67 / Version 2; sie bleiben bis A2d-2 rot. Nach A2d-1 stimmen JSON und Katalog in allen 55 Einträgen überein, AC-1 ist dann nur an der Endanzahl rot)
- [ ] AC-9: `test_first43Entries_unchanged`
- [ ] AC-27: `test_defaultPrograms_referenceExistingCatalogIds` (A2c-1)

Erwartetes Testbild nach A2d-1 (Namen wie in `ExerciseCatalogTests.swift`):
- `test_newExercises_haveTextsInDeAndEn_andCategory`: Nr. 1-12 fehlerfrei, Abbruch erst bei Nr. 13 („Kennung builtin.umgekehrtes-rudern fehlt"); grün nach A2d-2
- `test_catalog_matchesBuiltinExercisesJson` und `test_catalog_has67EntriesAndVersion2`: rot nur an 67 Einträgen bzw. Version 2
- `test_idForEnglishName_returnsBuiltinId`: rot nur für die 12 englischen Namen aus Nr. 13-24
- `test_first43Entries_unchanged`, `test_catalogIds_matchRegexAndAreUnique`, `test_idForGermanName_returnsBuiltinId`: grün
- Server: `npm test` grün (Anzahl aus der Katalogdatei gelesen)
- Zwischenstände der drei Runden: nach A2d-1a bricht `test_newExercises_haveTextsInDeAndEn_andCategory` bei Nr. 5 (`builtin.sit-ups`) ab, nach A2d-1b bei Nr. 9 (`builtin.dips`), nach A2d-1c bei Nr. 13; `test_idForEnglishName_returnsBuiltinId` ist entsprechend rot für 20, 16 bzw. 12 Namen; `test_first43Entries_unchanged` und der Gleichlauf aller vorhandenen Einträge (47, 51, 55) sind nach jeder Runde grün bis auf die Endanzahl 67
- App-Durchlauf im Simulator (nach A2d-1c; in A2d-1a/b mit einer Übung der Runde, die in der Vorschlagsliste steht, z. B. „V-Ups" bzw. „Crunches"): im Schritt-Editor „Pull-ups" aus der heutigen Vorschlagsliste wählen (die Auswahl aus dem Katalog kommt erst mit A2b); das Info-Blatt zeigt Wirkung und Anleitung, einmal mit App-Sprache Deutsch (Start mit `-AppleLanguages (de)`) und einmal mit Englisch (`-AppleLanguages (en)`)

`WorkoutPhaseMigrationTests.swift` (Muster `LeanHealthTimerTests/TrackerMigrationTests.swift`):
- [ ] AC-10: `test_oldJson_loadsLossless`
- [ ] AC-11: `test_missingExerciseId_derivedFromName`
- [ ] AC-12: `test_ownSlug_rules`
- [ ] AC-13: `test_roundTrip_keepsExerciseIdAndHint` und `test_storedExerciseId_notRecomputed`
- [ ] AC-14: `test_hint_normalization`
- [ ] AC-15: `test_corruptJson_isBackedUpBeforeFallback` (sucht den Schlüssel über das Präfix `workoutProgramSetsBackup.` und prüft Byte-Gleichheit; ein bereits vorhandener Sicherungsschlüssel derselben Sekunde wird nicht überschrieben)
- [ ] AC-16: `test_noBackup_whenKeyMissingOrValid`
- [ ] AC-20: `test_spokenText_withAndWithoutHint` (reine Funktion für den Ansagetext: alle vier Satzformen mit und ohne Hinweis, Deutsch und Englisch)
- [ ] AC-21: `test_announcement_respectsSpeakSetting` — eine einzige Entscheidungsfunktion (Schritt + Wert von `speakExerciseNames` → zu sprechender Text oder `nil`) liefert bei ausgeschalteter Einstellung `nil` (weder Name noch Hinweis), bei eingeschalteter den Text nach AC-20. Beide Aufrufstellen (erste Übung in `beginSessionAfterCountdown` und Ankündigung der nächsten Übung zu Beginn der Pause) rufen ausschließlich diese Funktion auf; das prüft der Adversary per Codesuche (keine zweite Stelle, die `speakExerciseNames` für Übungsansagen selbst auswertet).
- [ ] AC-23 (Logik): `test_selectingCatalogOrOwnExercise_setsExerciseId` — die Übernahme einer Auswahl in den Schritt (Katalogeintrag „Planke" bzw. „Eigene Übung…" mit „Mein Lauf") setzt `builtin.planke` mit dem deutschen Katalognamen „Planke" als `name` (Schreibregel Entscheidung 6) bzw. `own.mein-lauf` mit „Mein Lauf"; nach Kodieren und Dekodieren unverändert. Ein neuer Schritt ohne Auswahl trägt den alphabetisch ersten Katalogeintrag samt Kennung.

### UI-Tests (`LeanHealthTimerUITests/WorkoutHintUITests.swift`, Aufruf nur als `./Scripts/run-uitests.sh WorkoutHintUITests/<Methode>`)

- [ ] AC-18, AC-19: `test_hintEnteredInEditor_visibleUnderRingInTraining` (Schritt mit Hinweis anlegen, starten, `workout.training.hint` unter dem Ring prüfen; Training anhalten, Hinweis bleibt sichtbar (Entscheidung 10); weiterlaufen lassen, in der folgenden Pause existiert `workout.training.hint` nicht; zweiter Schritt ohne Hinweis zeigt keine Zeile)
- [ ] AC-23 (Oberfläche): `test_pickedExercise_persistsAfterRelaunch` („Planke" aus der Auswahl wählen, zweiten Schritt als „Eigene Übung…" „Mein Lauf" anlegen, speichern, App neu starten, Schritte erneut öffnen: Auswahl steht auf `workout.exercisePicker.option.builtin.planke` bzw. „Eigene Übung…" mit „Mein Lauf"; im Training zeigt der Info-Knopf für „Planke" Wirkung und Anleitung)
- [ ] AC-24: `test_hintField_limitsLengthAndLines` (90 Zeichen eingeben → Feldwert hat höchstens 80 Zeichen; Text mit Zeilenumbruch → Feldwert einzeilig; Feld leeren, speichern, erneut öffnen → Feld leer und im Training keine Hinweiszeile)
- [ ] AC-22: `test_exercisePicker_showsOnlyCatalogNames_german` (Start mit `-AppleLanguages (de)`; `workout.exercisePicker.option.builtin.planke` existiert, kein Eintrag „Plank"/„Push-ups", `workout.exercisePicker.own` existiert)
- [ ] AC-28: `test_infoButton_forPresetPlanke_showsContent` (A2c-1; Vorgabe „Core Circuit")
- [ ] AC-25: `test_hintField_localized_german` (Start mit `-AppleLanguages (de)`; `workout.phaseEditor.hintField` trägt „Hinweis (optional)" und Platzhalter „z. B. 12 Wiederholungen, langsam") und `test_hintField_localized_english` (Start mit `-AppleLanguages (en)`; „Hint (optional)" und „e.g. 12 reps, slow"); beide prüfen, dass der Text nicht in Großbuchstaben erscheint
- Hinweis aus Memory: verdeckte Elemente bleiben im Zugänglichkeitsbaum; bei Sichtbarkeitsprüfungen zusätzlich `isHittable` bzw. Existenz im geöffneten Dialog prüfen. Tab-Knöpfe haben keine Kennung (positionsbasiert).

### Regression und Review

- [ ] AC-29, AC-31: komplette Unit-Suite grün; (am Ende von A2c-2) komplette UI-Suite: alle neuen Tests aus `WorkoutHintUITests` und alle vor #48 grünen Tests grün. Ausnahme ist ausschließlich ein Test, der nachweislich auch auf dem Stand vor #48 scheitert (Altlast #25); er wird mit Lauf auf dem Vorher-Stand im Validierungsbericht belegt, wie bei #47. Watch- und Widget-Scheme bauen.
- [ ] AC-17, AC-26, AC-29, AC-31: Review-Punkte im Adversary-Schritt — Doku-Nachzug nachgewiesen (AC-17, AC-26); Codesuche in `WorkoutProgramsView.swift` findet weder `exerciseSuggestions` noch die 10er-Vorgabeliste (AC-29); Diff über alle Schnitte ändert keine `Info.plist`, keine Entitlements, keine Watch-/Widget-Dateien und keinen der Schlüssel `workoutProgramSets`/`speakExerciseNames` (AC-31).
- [ ] AC-30: `test_existingUserStore_unchangedAfterPresetMigration` (Unit-Test in `WorkoutPhaseMigrationTests.swift`, A2c-1) mit vorbelegtem Bestand (Vorgaben plus eigenes Programm), Ergebnis unverändert.
- [ ] Beleg „Fertig" für Issue #48: Screenshot des Trainings mit sichtbarem Hinweis unter dem Ring (aus dem UI-Test bzw. Simulator, Light und Dark).

Zusätzlich vor jeder PO-sichtbaren Übergabe (A2b, A2c-1, A2c-2): App im Simulator starten und den Ablauf durchspielen (Programm bearbeiten, Hinweis eingeben, Training starten). Keine Tests auf Hennings Geräten.

## Definition of Done

Gilt für den Endstand nach A2c-2. Je Schnitt gilt die Schnitt-Regel aus „Affected Files und Schnitte" (Build grün, Tests des eigenen und der früheren Schnitte grün, Tests späterer Schnitte einzeln im Prüfbericht ausgewiesen) und für A2d-1 das „Erwartete Testbild nach A2d-1".

- [ ] Build erfolgreich (`xcodebuild`, Scheme „Lean Health Timer", iPhone 17 Pro, iOS 27.2; 26.5 ist seit 2026-11-15 nicht mehr installiert)
- [ ] Alle Unit-Tests grün, inkl. `ExerciseCatalogTests` und `WorkoutPhaseMigrationTests` (`Executed N tests`, N ≥ 1)
- [ ] Alle UI-Tests grün, inkl. `WorkoutHintUITests` (`Executed N tests`, N ≥ 1); einzige Ausnahme: Tests, die nachweislich schon auf dem Stand vor #48 scheitern (Altlast #25), belegt im Validierungsbericht (siehe Test Plan, Regression)
- [ ] AC-1 bis AC-31 erfüllt und im Test Plan abgehakt
- [ ] Screenshot Training mit Hinweis unter dem Ring liegt als Beleg vor
- [ ] App im Simulator gestartet und Ablauf durchgespielt (registrierter Durchlauf)
- [ ] Texte DE und EN in `Localizable.xcstrings` eingetragen
- [ ] `claude-annahme.md` und `workouts.md` nachgezogen (AC-17, AC-26); Hinweis an #51 zur Auflösung von `claudeId`/`itemId`
- [ ] Issue #48 aktualisiert; #51 und #53 über die verfügbaren Kennungen und das Feld `hint` informiert

## Expected Behavior

- **Input:** Gespeicherte eigene Programme (alt oder neu), Auswahl einer Katalogübung oder „Eigene Übung…", optionaler Hinweistext je Schritt, Einstellung `speakExerciseNames`.
- **Output:** Jeder Schritt trägt eine gültige Kennung; im Training steht der Hinweis (falls vorhanden) unter dem Ring; bei eingeschalteten Ansagen wird „Name. Hinweis" gesprochen; die Auswahl zeigt nur deutsche (bzw. englische) Katalognamen plus „Eigene Übung…".
- **Side effects:** Neue UserDefaults-Schlüssel `workoutProgramSetsBackup.<Unix-Sekunden>` nur im Fehlerfall des Dekodierens (Rohdatensicherung). `workoutProgramSets` und `speakExerciseNames` unverändert. Beim ersten Speichern nach dem Update enthalten Schritte zusätzlich `exerciseId` (und `hint`, falls gesetzt); ältere App-Fassungen ignorieren die Zusatzfelder. Keine neuen Berechtigungen, keine neuen Audiodateien, keine Änderungen an Info.plist.

## Error Handling

- Nicht dekodierbare Programmdaten: Rohdaten sichern, dann Vorgaben (kein stilles Überschreiben ohne Sicherung).
- Unbekannte Kennung am Schritt (z. B. `claude.*` noch ohne Katalogeintrag): Anzeige über den gespeicherten `name`, Info-Knopf leer wie bisher bei unbekannten Übungen; kein Absturz.
- Hinweis zu lang oder mit Zeilenumbruch: wird normalisiert (Entscheidung 9), nie abgelehnt.

## Known Limitations

- Zwei verschiedene eigene Übungsnamen mit gleichem Slug (z. B. „Lauf!" und „Lauf?") teilen sich dieselbe `own.*`-Kennung; ein Zusammenführen ist im Umfang von #53 zu klären.
- Eine vor A2 gespeicherte Kennungsableitung gilt dauerhaft; wird später ein Katalogname geändert, bleibt die Kennung stabil, der angezeigte Name folgt dem Katalog.
- Der Hinweis steht nicht in der Vorschau „Als nächstes" in der Pause.

## Out of Scope

Ausdrücklich nicht Teil von #48 (Bestandsfehler, die der Analyse bekannt sind):

- Unübersetzte Übungsnamen an Stellen, die A2 nicht berührt (außer Training, Picker und Ansagetext, die ohnehin umgebaut werden).
- Keine Ansage der nächsten Übung bei Pause 0 s.
- Unterschiedlicher Standardwert von `speakExerciseNames` im freien HIIT-Timer (true) gegenüber den Programmen (false).
- Doppelter Ansage-Weg: privater `SoundPlayer` in `WorkoutProgramsView.swift` gegenüber `WorkoutSoundPlayer.swift`.
- Watch-App und Widget bleiben unberührt.
- Annahme und Anwenden von Lieferungen (#51), Abschrift (#53), Herkunftsanzeige „von Claude" in der Liste (#51).

## Risiken

- **Datenverlust beim Laden:** das gesamte Array fällt bei einem einzigen unlesbaren Feld auf Vorgaben zurück. Gegenmaßnahmen: nur optionale Felder, Rohdatensicherung, Altbestands-JSON-Tests (AC-10, AC-15).
- **Zuordnung Name → Kennung:** falsche Zuordnung würde den Info-Inhalt vertauschen. Gegenmaßnahme: Tests für alle deutschen und englischen Namen (AC-3 bis AC-5) und exakter Vergleich, keine Ähnlichkeitssuche.
- **Hoher Textanteil in A2d:** 24 mal Wirkung und Anleitung in DE/EN; fachliche Richtigkeit wird im Adversary-Schritt gegengelesen, Stil an bestehenden Einträgen.
- **Scoping:** gesamt über den Limits, deshalb sechs Schnitte; jeder Schnitt hat einen eigenen lauffähigen Stand.
- **UI-Tests:** keine bestehenden Kennungen in Editor und Training; Aufbau über Startoption `enable-testing`, UserDefaults bleiben zwischen Läufen erhalten (Testdaten gezielt setzen und aufräumen).

## Changelog

- 2026-11-15: PO-Entscheidung (Chat): A2d-1 in drei Runden A2d-1a (#80, Nr. 1-4 + „Beinpendel"), A2d-1b (Nr. 5-8), A2d-1c (Nr. 9-12). Grund: Die `.xcstrings`-Ausnahme liegt auf `main` (PR #86), wirkt aber nicht, solange der Haupt-Checkout auf einem alten Zweig steht. Zwischenstände der Tests je Runde im Test Plan ergänzt.

- 2026-11-15: Runde A2d-1 (#80, Workflow feature-80-zusatzuebungen-1-12): Dateiliste A2d-1/A2d-2 um `server/test/mcp-read.test.ts` ergänzt (feste Anzahl 43 durch Anzahl aus der Katalogdatei ersetzt), `ExerciseCatalogTests.swift` als unverändert gekennzeichnet, Zeilenschätzung auf ca. 630 (davon ca. 450 `Localizable.xcstrings`) korrigiert; PO-Entscheidung: `.xcstrings`-Zeilen zählen nicht zur Grenze von ±250 (`loc_exclude_patterns`), Vorbedingung: Regel im Haupt-Checkout wirksam; Technischer Ansatz um Schlüsselkonvention `exercise.<slug>.effect/.instructions`, Bundle-Auflösung in `localizedTexts(forId:bundle:)` und Namensschlüssel nur bei DE ≠ EN (A2d-1: Archer-Liegestütze, Decline-Liegestütze, Klimmzüge, Australische Klimmzüge; „Beinpendel" bleibt in A2d-1) ergänzt; Test Plan um das erwartete Testbild nach A2d-1 ergänzt.
- 2026-11-15: PO-Entscheidung: jeder Schnitt läuft als eigene Workflow-Runde (Umsetzung, Adversary, Validierung, Sicherung). Runde 1 (Workflow `feature-48-uebungskatalog`) umfasst nur A2a samt kompilierendem Test-API-Gerüst; Adversary VERIFIED. Tests späterer Schnitte sind in dieser Runde erwartet rot (einzeln im Adversary-Protokoll). Folgeschnitte A2d-1 … A2c-2 als neue Workflows gegen diese Spec. Simulator jetzt iPhone 17 Pro, iOS 27.2 (26.5 nicht mehr installiert).
- 2026-11-15: RED-Phase: Namen und Signaturen der testbaren Funktionen sowie die zusätzlichen Bedienkennungen (Programmzeile, Editor-Knöpfe, Info-Blatt) festgelegt in `DOCS/context/feature-48-test-api-vertrag.md`; die Tests decken alle Schnitte ab, je Schnitt werden dessen Tests einzeln grün nachgewiesen.
- 2026-11-15: Achte Spec-Prüfung: `workouts.md`-Nachzug einheitlich in A2c-2; catalogVersion 2 erst in A2d-2, Test je Teilschnitt; `WorkoutPhase`-Init mit Default-Parametern; Vorgabeliste für AC-27 `internal static`; Info-Blatt-Kennungssuche eindeutig in A2a; Schema-Verweis präzisiert.
- 2026-11-15: Siebte Spec-Prüfung: A2c geteilt in A2c-1 (Vorgaben, 4 Dateien) und A2c-2 (Aufräumen, 2 Dateien); beim Umbau zu `enum` entfallen alle Instanz-Member, nicht nur `body`; U+2028/U+2029, Tab und U+00A0 namentlich in Entscheidung 9 und AC-14.
- 2026-11-15: Sechste Spec-Prüfung: `WorkoutProgramsView` wird leeres `enum` als Namensraum (ohne `View`, sonst Build-Fehler ohne `body`); fehlender Textschlüssel „Beinpendel" (EN „Leg Swing") in A2d-1; Hinweis-Normalisierung deckt alle vom Schema verbotenen Zeichen ab; Wortlaut „letzte Übung" laut Textkatalog.
- 2026-11-14: Fünfte Spec-Prüfung (Abgleich mit Code): Ansage an die vier bestehenden Satzformen angepasst, Sprechstellen korrekt benannt (erste Übung, Ankündigung zu Beginn der Pause); AC-28 Vorher-Aussage korrigiert (Namenssuche „Planke" funktioniert heute); A2a nimmt die zwei Aufrufe des Info-Blatts auf; Doku-Nachzug `workouts.md` nach A2c (A2b damit 5 Dateien); A2c entfernt den toten Bildschirmteil von `WorkoutProgramsView` (Typ bleibt als Namensraum).
- 2026-11-14: Dritte Spec-Prüfung: Zuordnungstabelle der 69 Vorschlagsnamen (6 exakt, 2 Endung, 37 englisch, 24 neu) ergänzt; Standardname neuer Schritte festgelegt; AC-29/AC-31 als Review-Kriterien; AC-15 Präfixsuche; Hinweis auch pausiert im UI-Test; Pfad `DOCS/artifacts`; Begründung Hinweisgrenze korrigiert.
- 2026-11-14: Nach Spec-Prüfung: AC-12 Erwartung für „Ä" → `own.ae`; Tests für AC-21 (Entscheidungsfunktion + Codesuche), AC-23 (Logik + Neustart), AC-24 (Eingabefeld), AC-25 (zwei Sprachläufe), AC-19 Pausenteil ergänzt; UI-Ausnahme Altlast #25 in DoD und Regression gleich formuliert; Vorschlagsliste: A2b nimmt sie aus der Auswahl, A2c entfernt sie.
- 2026-11-14: Initial spec created (PO-Entscheidungen 2026-11-14: Hinweis unter dem Ring, 24 Zusatzübungen in den Katalog; Variante (a) mit `exerciseId`/`hint`; Schnitte A2a, A2d-1/2, A2b-0, A2b, A2c; Spec-Widersprüche `claudeId`/`itemId`, `own.*`, TTS-Hinweis entschieden)
