# Context: feature-47-tagesansicht

## Request Summary
Antippen eines Tages im Erfolge-Kalender zeigt jede Gewohnheit (Tracker) mit ihrem Eintrag dieses Tages, nicht nur Meditation, Workout, NoAlc. Die Tagesansicht öffnet auch an Tagen, an denen nur Tracker-Einträge existieren. (Issue #47, Teil von Epic #44, Konzept `DOCS/konzept-claude-verbindung.md` 9.1)

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Views/DayDetailSheet.swift` (454 Z.) | Zeigt heute nur Meditation/Workout/NoAlc (`loadSessions` :170, `fetchSessions` :208). Parameter `date`, `mindfulnessMinutes`, `workoutMinutes`; kein ModelContext. |
| `Meditationstimer iOS/CalendarView.swift` | `loadActivityDays()` :368 (13 Monate, NoAlc je Tag per HealthKit :410); `MonthView.dayView` :510, `hasActivity` :522, Tap :564-568, `.sheet` :570-578. |
| `Services/TrackerModels.swift` | `Tracker` :200, `TrackerLog` :440, `DayAssignment` :91-108, `effectiveDayAssignment`. |
| `Services/TrackerManager.swift` | `logs(for:on:in:)` :184 (ohne DayAssignment!), NoAlc aus HealthKit :310. |
| `Meditationstimer iOS/Localizable.xcstrings` | Neue Texte DE und EN. |
| `LeanHealthTimerTests/`, `LeanHealthTimerUITests/` | Kein Test für DayDetailSheet oder `hasActivity`; kein UI-Test, der einen Tag antippt; keine accessibilityIdentifier in Kalender/Sheet. |

## Existing Patterns
- Tracker sind eine Entität (`Tracker`, SwiftData); Presets und benutzerdefinierte Tracker identisch. SwiftData ist Quelle der Wahrheit, HealthKit optional gespiegelt.
- NoAlc wird für die Anzeige aus HealthKit gelesen und als Pseudo-Session `.noalc(level)` angehängt.
- Tageszuordnung: `Tracker.effectiveDayAssignment.assignedDay(for: log.timestamp)` (NoAlc: `cutoffHour:18`).
- Level-Labels über `TrackerLevel.localizedLabel`.

## Dependencies
- Upstream: SwiftData `Tracker`/`TrackerLog`, HealthKit, `DayAssignment`, `TrackerManager`.
- Downstream: `DayDetailSheet` wird nur aus `MonthView.dayView` aufgerufen; `hasActivity` steuert Fettdruck (:551) und Tap (:566).

## Existing Specs
- `openspec/specs/features/calendar-view.md`: „Day Detail – Tracker Section“ (:130-138), „Empty Day Tap“ (:140-146), Day Detail Content (:121-128). Spec nennt nur geloggte „Focus Trackers“, das Issue verlangt alle.
- `openspec/specs/features/trackers.md`, `DOCS/specs/features/FEAT-39-generic-tracker-completion.md`.

## Risks & Considerations
- cutoffHour-Doppelverschiebung (Memory): Tag nie über reine Tagesgrenze filtern, sondern `assignedDay`. Nicht erneut durch cutoffHour schicken.
- Doppelanzeige NoAlc (HealthKit-Level und evtl. Tracker-Log).
- Performance: 390 sequenzielle HealthKit-Abfragen existieren schon; Tracker-Logs einmal aus SwiftData laden und nach Tag gruppieren, nicht je Zelle neu berechnen.
- Kalenderfilter (`calendarFilterEnabled`) darf das Öffnen nicht blockieren.
- Offene Entscheidung für die Analyse: alle aktiven Tracker oder nur `showInCalendar`; ausgeblendete Tracker.
- Neue Texte brauchen DE und EN (sonst Großschreibung im Debug-Build, Memory Bug 38).
- UI-Tests brauchen neue accessibilityIdentifier; Tab-Knöpfe nur positionsbasiert ansprechen (Memory).

## Analysis

### Type
Feature (Teil von Epic #44, Konzept 9.1)

### Befund (am Code belegt)
- `DayDetailSheet` kennt keinen SwiftData-Zugriff; Tracker-Einträge kommen nirgends vor.
- `MonthView.dayView` öffnet das Blatt nur bei `hasActivity` (Meditation/Workout ≥ 2 min oder NoAlc, :522/:566). Ein Tag mit nur Tracker-Logs ist nicht antippbar.
- `TrackerManager.logs(for:on:)` filtert nach reiner Tagesgrenze, ohne `DayAssignment`. Für die Anzeige ungeeignet (cutoffHour-Doppelverschiebung, Memory). Stattdessen `tracker.effectiveDayAssignment.assignedDay(for: log.timestamp)`.
- NoAlc kommt für die Anzeige aus HealthKit (`fetchNoAlcLevelFromHealthKit`), parallel existiert ein NoAlc-Tracker in SwiftData → Doppelanzeige vermeiden: NoAlc-Tracker aus dem Gewohnheiten-Abschnitt ausnehmen.

### Technical Approach (Regelweg, kein Modell)
1. Neue reine Funktion `TrackerDayEntries.group(trackers:calendar:)` in `Services/`: `[Date: [Entry]]`, Tag über `assignedDay`, Eintrag = Tracker (Icon, Name) + Anzeigewert (Level-Label über `value` = Level-Id, Zahl bei Zähler, ✓ bei Ja/Nein/Achtsamkeit, Notiz, Uhrzeit). Einmal je Kalender-Laden berechnet, nicht je Zelle.
2. `CalendarView`: `@Query` auf alle aktiven Tracker (bestehendes Muster, wie `noAlcTrackers`), Gruppierung in `MonthView` durchreichen; `hasActivity` um „hat Tracker-Einträge“ erweitern. `calendarFilterEnabled` blockiert das Öffnen nicht.
3. `DayDetailSheet`: neuer Parameter `trackerEntries`, Abschnitt „Gewohnheiten“ unter den Sessions, accessibilityIdentifier für UI-Test.
4. Texte DE+EN in `Localizable.xcstrings`.

### Alternative (ADR-/Spec-Bezug)
- B: alle aktiven Gewohnheiten, leere grau („kein Eintrag“). Kippt nichts, aber widerspricht der wertungsfreien Linie der Spec („non-judgmental presentation“).
- C: Abschnitt nur für `showInCalendar`-Tracker (so steht es sinngemäß in der Spec „Focus Trackers“). Würde das Issue („jede Gewohnheit“) verfehlen.
- Offen/außerhalb: „Empty Day Tap“ (Tag ohne jede Aktivität öffnen, NoAlc nachtragen) steht in der Spec, ist aber nicht Teil von #47 → eigenes Ziel, nicht hier.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| Services/TrackerDayEntries.swift | CREATE | Gruppierung nach Tag + Anzeigewert (rein, testbar) |
| Meditationstimer iOS/CalendarView.swift | MODIFY | @Query, hasActivity, Weitergabe an Sheet (~+40) |
| Meditationstimer iOS/Views/DayDetailSheet.swift | MODIFY | Abschnitt „Gewohnheiten“ (~+70) |
| Meditationstimer iOS/Localizable.xcstrings | MODIFY | neue Texte DE/EN |
| LeanHealthTimerTests/TrackerDayEntriesTests.swift | CREATE | Tageszuordnung (cutoff 18), Werte je Tracker-Art, NoAlc ausgenommen |
| LeanHealthTimerUITests/… | CREATE/MODIFY | Tag mit nur Tracker-Eintrag antippen, Abschnitt sichtbar |

### Scope Assessment
- Files: 6 (davon 2 Test-Dateien; Quelle 4) — leicht über 4–5 durch Tests
- Estimated LoC: ca. +260 (Produkt ~+160, Tests ~+100)
- Risk Level: LOW–MEDIUM (Tageszuordnung, Doppelanzeige NoAlc)

### Dependencies
DayDetailSheet nur aus MonthView.dayView aufgerufen. Upstream: SwiftData Tracker/TrackerLog, DayAssignment.

### Design-Vorschau
https://claude.ai/artifact/9dLQWudTyP1ZP3cvi3wpbB — Datei `docs/artifacts/feature-47-tagesansicht/entwurf-tagesansicht.html`. Phase bleibt `phase2_analyse`, bis der Entwurf freigegeben ist.

### Open Questions
- [x] Entwurf A oder B? → **B entschieden (PO 2026-11-13)**, siehe „Entscheidungen“ unten.

### Entscheidungen PO 2026-11-13 (nach Modellwechsel, per Auswahl)
- **Aufteilung bestätigt:** Die wesentliche Information steht im Kalenderfeld über den inneren Kreis (#50, eigenes Ticket). #47 baut nur das Tagesfenster (Einzelheiten) und das Öffnen an Tagen, an denen es nur Tracker-Einträge gibt. Kein Umbau des Kalenderfelds in #47.
- **Entwurf B:** Abschnitt „Gewohnheiten“ zeigt **alle aktiven Tracker**. Mit Eintrag: Wert (Level-Label, Zahl, ✓, Notiz, Uhrzeit). Ohne Eintrag: grau, neutral „kein Eintrag“, kein Rot und keine Wertung. Begründung: Der innere Kreis (#50) zeigt einen Anteil, also muss das Fenster benennen können, welche Gewohnheiten fehlen.
- Der NoAlc-Tracker bleibt aus dem Gewohnheiten-Abschnitt ausgenommen, weil er schon in Zusammenfassung und Liste aus HealthKit erscheint (Ist-Stand, so lassen).
- `showInCalendar` und die Frage „nichts eingetragen = gelungen“ bei Vermeiden-Trackern gehören zu #50 und werden hier nicht entschieden. Für #47 werden alle aktiven Tracker gezeigt, leere Zeilen einheitlich „kein Eintrag“.
- Technischer Ansatz angepasst: `TrackerDayEntries` liefert je Tag alle aktiven Tracker (ohne NoAlc) mit optionalem Eintrag. `hasActivity` wird nur um „hat mindestens einen Tracker-Eintrag“ erweitert; leere Tracker allein öffnen das Fenster nicht (Empty Day Tap bleibt außerhalb).

## Sitzungsstand 2026-11-13 (Analyse unterbrochen, Modellwechsel)

### Echter Ist-Stand (Fotos von Henning, im Repo)
- `docs/artifacts/feature-47-tagesansicht/heute-kalender.png` und `heute-tagesansicht-12-11.png`: App dunkel. Kalender: äußere Ringe blau (Meditation), violett (Workout), innere Füllung grün/gelb/rot (NoAlc). Tagesfenster am 12.11.: „Zusammenfassung“ (Meditation 10 Min, Workouts 7 Min, NoAlc „Kaum“), „Einzelne Sessions“ (Zeile „Alcohol Tracking“ → Kaum, Meditation 07:55 · 10 Min, HIIT 08:06 · 7 Min · 86 kcal). NoAlc steht heute in Zusammenfassung UND Liste; so lassen.
- Der Tag-Tipp öffnet das Fenster bei Henning (bestätigt per Auswahl). Simulator-Nachstellung scheiterte am Health-Dialog, wurde von Henning abgebrochen, nicht wieder aufnehmen.

### Vorschau (veröffentlicht, Version 3)
https://claude.ai/artifact/9dLQWudTyP1ZP3cvi3wpbB, Datei `docs/artifacts/feature-47-tagesansicht/entwurf-tagesansicht.html`: links Foto „Heute“, Entwurf A (nur Einträge) und B (alle, leere grau), darunter Idee 1 (Punkt im Kalender) und Idee 2 (Tracker-Reiter zurückblättern).

### Hennings Rückmeldungen
- Zum Entwurf A/B: „Dieser Reiter ist sehr verborgen. Eine wesentliche Information sollte dort nicht zu finden sein.“ (A/B nicht entschieden.)
- Idee 1 (Punkt im Kalender): „finde ich nicht gut“, abgelehnt.
- Idee 2 (Zurückblättern im Tracker): „verstehe ich nicht“, nicht erklärt genug; Henning verlangt gründliches Nachdenken, keine weiteren Ratevorschläge.

### Neu gelesen: Konzept 9.1 (`DOCS/konzept-claude-verbindung.md` Z. 208–234)
- Zweck laut PO (13.11.): Ansporn, gelegentlich Rückblick; ein Tag soll zeigen, was getan wurde und was bemerkt wurde.
- Entschieden: Der **innere Kreis** des Kalenders fasst künftig alle dauerhaften Gewohnheiten zusammen (statt fest NoAlc); „Einzelheiten zeigt das Antippen des Tages“. Tagesansicht = Detail, öffnet an jedem Tag mit Einträgen. Challenges als Leiste über dem Kalender.
- Noch offen im Konzept: Füllung/Farbe des inneren Kreises, ob alle oder nur ausgewählte Gewohnheiten zählen (Schalter `showInCalendar` wird vom Kalender bisher nicht ausgewertet), Lesbarkeitsgrenze 3–4 Angaben je Tagesfeld.

### Arbeitshypothese (NICHT bestätigt, Henning fragen bzw. ihm so vorlegen)
Hennings „wesentliche Information“ sind die Gewohnheiten selbst. Das Konzept löst die Sichtbarkeit nicht im Fenster, sondern über den inneren Kreis im Kalender selbst. Dann ist #47 nur der Detail-Teil, und die Sichtbarkeit gehört in ein anderes Ticket (innerer Kreis, evtl. in Epic #44 schon vorhanden: vor dem Anlegen `gh issue list` prüfen). Alternative: #47 verbreitern und Gewohnheiten im Kalenderfeld selbst zeigen.

### Nächster Schritt
Henning die Hypothese in Alltagssprache vorlegen (Kalenderfeld zeigt bereits Ringe; der innere Kreis soll künftig die Gewohnheiten zusammenfassen; das Fenster liefert nur die Einzelheiten), danach A/B klären. Phase bleibt `phase2_analyse`; Spec erst nach Freigabe des Entwurfs.
