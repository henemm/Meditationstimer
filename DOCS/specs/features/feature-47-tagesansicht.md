---
entity_id: feature-47-tagesansicht
type: feature
created: 2026-11-13
updated: 2026-11-13
status: draft
workflow: feature-47-tagesansicht
issue: 47
epic: 44
---

# Tagesansicht zeigt alle Gewohnheiten (#47)

## Approval

- [ ] Approved for implementation

## Purpose

Das Antippen eines Tages im Erfolge-Kalender zeigt im Tagesfenster nicht nur Meditation, Workout und NoAlc, sondern jede aktive Gewohnheit (Tracker) mit ihrem Eintrag dieses Tages. Das Fenster öffnet auch an Tagen, an denen es ausschließlich Tracker-Einträge gibt.

## Source

- **Issue:** #47 „[Mac] A1 Tagesansicht zeigt alle Gewohnheiten und öffnet an jedem Tag mit Einträgen", Epic #44
- **Konzept:** `DOCS/konzept-claude-verbindung.md` Abschnitt 9.1 (Z. 208–234)
- **Analyse:** `DOCS/context/feature-47-tagesansicht.md`
- **Code:** `Meditationstimer iOS/CalendarView.swift` (`MonthView.dayView`, `hasActivity`), `Meditationstimer iOS/Views/DayDetailSheet.swift` (`DayDetailSheet`), neu `Services/TrackerDayEntries.swift` (`TrackerDayEntries`)

## Dependencies

| Abhängigkeit | Art | Zweck |
|--------------|-----|-------|
| `Tracker`, `TrackerLog` (`Services/TrackerModels.swift`, SwiftData) | Upstream | Quelle der Einträge |
| `DayAssignment` / `Tracker.effectiveDayAssignment` | Upstream | Tageszuordnung |
| `TrackerLevel.localizedLabel` | Upstream | Level-Anzeige |
| HealthKit (NoAlc, Meditation, Workout) | Upstream, unverändert | bestehende Zusammenfassung |
| `MonthView.dayView` | Downstream | einziger Aufrufer von `DayDetailSheet` |

## Design-Bezug

Freigegeben ist Entwurf B (PO-Entscheidung 2026-11-13): `DOCS/artifacts/feature-47-tagesansicht/entwurf-tagesansicht.html`, veröffentlicht unter https://claude.ai/artifact/9dLQWudTyP1ZP3cvi3wpbB. Ist-Stand-Fotos im selben Ordner (`heute-kalender.png`, `heute-tagesansicht-12-11.png`).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Die Änderung folgt bestehenden Mustern (SwiftData als Quelle der Wahrheit, `@Query` in Views, Tageszuordnung über `DayAssignment`, reine Hilfstypen in `Services/`). Neu ist nur ein lokaler, reiner Gruppierungstyp ohne Einfluss auf Datenmodell, Persistenz oder HealthKit-Anbindung. Keine projektweite Weichenstellung.

## Entscheidungen (PO 2026-11-13, verbindlich)

1. Abschnitt „Gewohnheiten" zeigt alle aktiven Tracker außer dem NoAlc-Tracker.
2. Zeile mit Eintrag: Wert (Level-Label, Zahl bei Zähler, Häkchen bei Ja/Nein und Achtsamkeit, Notiz, Uhrzeit). Zeile ohne Eintrag: grau, neutral „kein Eintrag" (EN „no entry"), kein Rot, keine Wertung.
3. NoAlc bleibt wie heute in Zusammenfassung und Einzelliste (aus HealthKit) und wird im neuen Abschnitt nicht wiederholt.
4. Kein Umbau des Kalenderfelds (innerer Kreis = #50). `showInCalendar` wird hier nicht ausgewertet.
5. `hasActivity` wird nur um „mindestens ein Tracker-Eintrag an diesem Tag" erweitert. Tage nur mit leeren Trackern öffnen das Fenster nicht.
6. `calendarFilterEnabled` blockiert das Öffnen nicht.

## Affected Files

| Datei | Änderung |
|-------|----------|
| `Services/TrackerDayEntries.swift` | CREATE: reine Gruppierung nach Tag plus Anzeigewert |
| `Meditationstimer iOS/CalendarView.swift` | MODIFY: `@Query` aktive Tracker, Gruppierung einmal je Laden, `hasActivity`, Weitergabe an `DayDetailSheet` |
| `Meditationstimer iOS/Views/DayDetailSheet.swift` | MODIFY: neuer Parameter, Abschnitt „Gewohnheiten", accessibilityIdentifier |
| `Meditationstimer iOS/Localizable.xcstrings` | MODIFY: neue Texte DE und EN |
| `LeanHealthTimerTests/TrackerDayEntriesTests.swift` | CREATE: Unit-Tests |
| `LeanHealthTimerUITests/` (eine Testdatei, z. B. `DayDetailHabitsUITests.swift`) | CREATE: UI-Test |

## Estimated Changes

| Bereich | Dateien | LoC (ca.) |
|---------|---------|-----------|
| Produkt | 4 | +160 |
| Tests | 2 | +100 |
| Summe | 6 | +260 |

Leicht über den Scoping-Limits (4–5 Dateien, ±250 LoC), ausschließlich durch die Pflicht-Tests. Die Produktänderung allein bleibt mit 4 Dateien und ca. 160 LoC innerhalb. Eine Aufteilung würde Code ohne Tests liefern und ist deshalb nicht sinnvoll.

## Technischer Ansatz (Regelweg, kein Modell)

Ohne Modell, nur Regeln: Tageszuordnung, Wertdarstellung und Filter sind deterministisch.

### Neuer Typ `TrackerDayEntries` (`Services/TrackerDayEntries.swift`)

- Reine Funktion, keine View, kein ModelContext, kein HealthKit.
- `static func group(trackers: [Tracker], calendar: Calendar = .current) -> [Date: [TrackerDayEntries.Row]]`
- Eine `Row` je aktivem Tracker (außer NoAlc) und Tag, an dem mindestens ein Tracker einen Eintrag hat. Felder: Tracker-Id, Name, Icon, optionaler Eintrag (`Entry`: Anzeigewert, Notiz, Uhrzeit des spätesten Logs dieses Tages).
- `static func hasActivity(mindfulnessMinutes: Double, workoutMinutes: Double, hasNoAlc: Bool, hasTrackerEntries: Bool) -> Bool` bündelt die bisherige Bedingung aus `MonthView.dayView` (Meditation ≥ 2 min oder Workout ≥ 2 min oder NoAlc, Schwellen unverändert übernommen) plus Tracker-Einträge, damit AC-13, AC-14 und AC-16 als Unit-Test prüfbar sind. `MonthView` ruft nur noch diese Funktion auf.
- Das Vorhandensein des Tag-Schlüssels in der Rückgabe von `group` liefert `hasTrackerEntries`. Ein Tag ist in der Rückgabe nur enthalten, wenn mindestens ein Tracker dort einen Log hat. Für Tage ohne Eintrag liefert die Aufrufseite keine Zeilen.
- Tageszuordnung ausschließlich über `tracker.effectiveDayAssignment.assignedDay(for: log.timestamp, calendar:)`. Nicht `TrackerManager.logs(for:on:)` (filtert ohne DayAssignment), und das Ergebnis nicht noch einmal durch cutoffHour schicken (Doppelverschiebung, siehe Memory Bug 37).
- Sortierung der Zeilen: `Tracker.displayOrder` aufsteigend (dasselbe Feld wie die Tracker-Liste, `TrackerTab` Zeile 22), bei Gleichstand nach `createdAt`, dann `name`.
- NoAlc-Erkennung: `name == "NoAlc"` (wie `@Query` in `CalendarView` Zeile 26) oder `healthKitType == HKQuantityTypeIdentifier.numberOfAlcoholicBeverages.rawValue`.
- Anzeigewert je Tracker-Art über `effectiveValueType`:
  - `.levels(levels)`: `levels.first { $0.id == log.value }?.localizedLabel` (Icon des Levels optional davor). Unbekannte Level-Id: Zeile gilt als Eintrag, Wert ist die Zahl als Text.
  - `.integer`: Summe der `value` aller Logs des Tages (nil zählt als 1), als Zahl; mit Ziel: „n / Ziel" nur falls `dailyGoal` gesetzt.
  - `.boolean` (Ja/Nein, Achtsamkeit, Vermeiden): Häkchen.
  - Notiz: `note` des spätesten Logs, falls nicht leer, zusätzlich zur Wertanzeige.
  - Uhrzeit: Zeitstempel des spätesten Logs dieses Tages (Format wie `SessionRow`).

### `CalendarView` / `MonthView`

- `@Query(filter: #Predicate<Tracker> { $0.isActive }, sort: \Tracker.displayOrder)` auf aktive Tracker (bestehendes Muster aus `TrackerTab`).
- Gruppierung einmal je Aufbau bzw. bei Änderung der Tracker-Daten berechnen (nicht je Zelle in `dayView`), Ergebnis an `MonthView` durchreichen.
- `hasActivity` zusätzlich wahr, wenn für `dayKey` Tracker-Einträge existieren.
- `DayDetailSheet(date:mindfulnessMinutes:workoutMinutes:habitRows:)` erhält die Zeilen des Tages.
- Kalenderfeld (Ringe, Füllung, Fettdruck-Logik außer `hasActivity`) bleibt unverändert.
- Beim Erscheinen springt der Kalender sofort auf den aktuellen Monat (bisher erst nach dem Laden der HealthKit-Daten; bis dahin stand er beim ältesten Monat). Endzustand wie bisher, nur ohne Verzögerung; nötig, damit die Tageszelle von heute sofort existiert (PO-Freigabe 2026-11-14 ausstehend).

### `DayDetailSheet`

- Neuer Parameter `habitRows: [TrackerDayEntries.Row]` (Standardwert leer, damit Aufrufer und Previews kompilieren).
- Abschnitt „Gewohnheiten" unter „Einzelne Sessions", nur sichtbar, wenn `habitRows` nicht leer ist.
- Zeile mit Eintrag: Icon, Name, Wert, ggf. Notiz, Uhrzeit. Zeile ohne Eintrag: gesamte Zeile in `.secondary`, Text „kein Eintrag", keine Farbe, kein Symbol der Wertung.
- accessibilityIdentifier: `dayDetail.habitsSection` (Abschnitt), `dayDetail.habitRow.<Tracker-Id>` (Zeile), `dayDetail.habitValue.<Tracker-Id>` (Wert bzw. „kein Eintrag").
- Der Tag-Tap im Kalender erhält zusätzlich einen accessibilityIdentifier je Tageszelle (`calendar.day.<yyyy-MM-dd>`), damit der UI-Test den Tag gezielt antippen kann. Hinweis: die bestehende Tab-Leiste bleibt positionsbasiert.

### Texte (`Localizable.xcstrings`)

| Schlüssel (DE) | EN |
|----------------|----|
| Gewohnheiten | Habits |
| kein Eintrag | no entry |

Beide mit `"extractionState": "manual"` und `"state": "translated"`, sonst Großschreibung im Debug-Build (Memory Bug 38). Weitere Texte (z. B. „%lld / %lld") nur, falls tatsächlich neu nötig, ebenfalls DE und EN.

## Acceptance Criteria

Ein Tracker „T" bezeichnet einen aktiven, nicht gelöschten Tracker ohne NoAlc-Kennzeichen.

- **AC-1 Tageszuordnung Zeitstempel:** Given T mit `dayAssignmentRaw == nil` und ein Log am 13.11. um 17:00, When gruppiert wird, Then erscheint der Eintrag am 13.11. und an keinem anderen Tag.
- **AC-2 Tageszuordnung cutoffHour 18:** Given T mit `dayAssignmentRaw == "cutoffHour:18"` und ein Log am 13.11. um 17:00, When gruppiert wird, Then gehört der Eintrag zum 12.11. (nicht zum 13.11.). Ein Log am 13.11. um 18:00 gehört zum 13.11.
- **AC-3 Keine Doppelverschiebung:** Given T mit `cutoffHour:18` und ein Log am 13.11. um 00:30, When gruppiert wird, Then gehört er genau einmal verschoben zum 12.11. (nicht zum 11.11.).
- **AC-4 Level-Tracker:** Given ein Level-Tracker und ein Log mit `value` = Id eines Levels, When das Fenster den Tag zeigt, Then steht in der Zeile `localizedLabel` dieses Levels.
- **AC-5 Zähler:** Given ein Zähler-Tracker mit drei Logs am selben Tag (value 1, 2, 1), When das Fenster den Tag zeigt, Then zeigt die Zeile die Summe 4 (bei gesetztem Tagesziel 5 als „4 / 5").
- **AC-6 Ja/Nein, Achtsamkeit, Vermeiden:** Given ein Tracker mit boolescher Wertart und mindestens einem Log am Tag, When das Fenster den Tag zeigt, Then zeigt die Zeile ein Häkchen.
- **AC-7 Notiz und Uhrzeit:** Given ein Log mit nichtleerer `note`, When das Fenster den Tag zeigt, Then stehen Notiz und Uhrzeit des spätesten Logs dieses Tages in der Zeile; bei leerer oder fehlender Notiz erscheint keine Notizzeile. Gleicht die Notiz dem Anzeigewert (Level- und Stimmungs-Logs speichern „Icon Label“ als `note`), erscheint ebenfalls keine Notizzeile; eine echte Notiz bleibt sichtbar.
- **AC-8 Leere Zeile:** Given ein aktiver Tracker ohne Log an einem Tag, an dem ein anderer Tracker einen Eintrag hat, When das Fenster den Tag zeigt, Then gibt es für diesen Tracker eine graue Zeile mit dem Text „kein Eintrag" (EN „no entry"), ohne Rot und ohne Wertungssymbol.
- **AC-9 Alle aktiven Tracker:** Given drei aktive Tracker, von denen einer einen Eintrag hat, When das Fenster den Tag zeigt, Then sind alle drei Zeilen sichtbar (eine mit Wert, zwei „kein Eintrag").
- **AC-10 NoAlc ausgenommen:** Given ein NoAlc-Tracker (Name „NoAlc" oder HealthKit-Typ `numberOfAlcoholicBeverages`) mit Log am Tag, When gruppiert wird, Then fehlt er im Abschnitt „Gewohnheiten"; Zusammenfassung und „Einzelne Sessions" zeigen NoAlc unverändert aus HealthKit.
- **AC-11 Inaktive und gelöschte Tracker:** Given ein Tracker mit `isActive == false` oder ein gelöschter Tracker (Logs verschwinden per Cascade), When das Fenster den Tag zeigt, Then erscheint er nicht, auch wenn er an dem Tag Logs hatte, und er öffnet das Fenster nicht.
- **AC-12 Reihenfolge:** Given aktive Tracker mit `displayOrder` 2, 0, 1, When das Fenster den Tag zeigt, Then stehen die Zeilen in der Reihenfolge 0, 1, 2 (wie in der Tracker-Liste).
- **AC-13 Öffnen nur mit Tracker-Eintrag:** Given ein Tag ohne Meditation (< 2 min), ohne Workout (< 2 min), ohne NoAlc, aber mit einem Tracker-Eintrag, When der Nutzer den Tag im Kalender antippt, Then öffnet sich das Tagesfenster mit dem Abschnitt „Gewohnheiten".
- **AC-14 Kein Öffnen bei nur leeren Trackern:** Given ein Tag ohne jede Aktivität und ohne Tracker-Eintrag (nur leere aktive Tracker), When der Nutzer den Tag antippt, Then öffnet sich kein Fenster.
- **AC-15 Kalenderfilter:** Given `calendarFilterEnabled` ist an, When der Nutzer einen Tag mit Tracker-Eintrag antippt, Then öffnet sich das Fenster trotzdem.
- **AC-16 Bestehendes Verhalten:** Given ein Tag mit Meditation, Workout oder NoAlc, When der Nutzer ihn antippt, Then zeigt das Fenster Zusammenfassung und Einzelliste wie bisher, plus (falls aktive Tracker existieren) den Abschnitt „Gewohnheiten". Fettdruck und Ringe im Kalenderfeld bleiben außer durch AC-13 unverändert.
- **AC-17 Gruppierung einmal je Laden:** Given ein Monat mit 31 Zellen, When der Kalender aufgebaut wird, Then wird `TrackerDayEntries.group` nicht je Zelle ausgeführt, sondern einmal je Laden bzw. Datenänderung (Review-Kriterium im Code, kein Laufzeittest).
- **AC-18 Texte lokalisiert:** Given die App läuft auf Deutsch bzw. Englisch, When der Abschnitt erscheint, Then lauten Überschrift und Leertext „Gewohnheiten"/„kein Eintrag" bzw. „Habits"/„no entry"; im Debug-Build ohne Großschreibung.

## Test Plan

### Unit-Tests (`LeanHealthTimerTests/TrackerDayEntriesTests.swift`, In-Memory-SwiftData)

- [ ] AC-1: `test_timestampAssignment_logAt17_belongsToSameDay`
- [ ] AC-2: `test_cutoff18_logAt17_belongsToPreviousDay` und `_logAt18_belongsToSameDay`
- [ ] AC-3: `test_cutoff18_logAfterMidnight_shiftedOnlyOnce`
- [ ] AC-4: `test_levelTracker_showsLocalizedLevelLabel`
- [ ] AC-5: `test_counter_sumsValuesOfDay`
- [ ] AC-6: `test_boolean_showsCheckmark`
- [ ] AC-7: `test_noteAndLatestTime_ofLatestLog`, `test_levelTracker_noteEqualToLevelLabel_isNotShownAsNote`
- [ ] AC-8, AC-9: `test_trackerWithoutLog_emptyRowWhenOtherTrackerHasEntry`
- [ ] AC-10: `test_noAlcTracker_excluded` (nach Name und nach HealthKit-Typ)
- [ ] AC-11: `test_inactiveTracker_notIncluded`
- [ ] AC-12: `test_rowsSortedByDisplayOrder`
- [ ] AC-13/AC-14 (Logik): `test_dayWithoutAnyLog_notInResult` und `test_dayWithOneLog_inResult`
- [ ] AC-13/AC-14: `test_hasActivity_onlyTrackerEntries_true`, `test_hasActivity_nothing_false`
- [ ] AC-16: `test_hasActivity_existingConditionsUnchanged` (Meditation 2 min → wahr, 1,9 min → falsch, Workout analog, NoAlc → wahr, jeweils ohne Tracker-Einträge)
- [ ] AC-18: `test_localization_habitsAndNoEntry_DEandEN` (liest aus `de.lproj`/`en.lproj` des App-Bundles: „Gewohnheiten"/„kein Eintrag" bzw. „Habits"/„no entry"; Wert darf nicht der Schlüssel in Großschreibung sein)

Erfolgsnachweis: Protokoll zeigt `Executed N tests` mit N ≥ 1 für die Klasse bzw. `Test case 'TrackerDayEntriesTests.…' passed` unter Xcode 27.

### UI-Tests (`LeanHealthTimerUITests/`, Aufruf nur als `./Scripts/run-uitests.sh Klasse/Methode`)

- [ ] AC-13, AC-8, AC-6/4: `test_dayWithOnlyTrackerEntry_opensSheet_showsFilledAndEmptyRow`. Aufbau über Launch-Argumente bzw. Testdaten im Simulator mit zwei aktiven Trackern, einem Eintrag an einem Tag ohne Sessions. Tag antippen, dann `dayDetail.habitsSection` existiert, gefüllte Zeile zeigt Wert, leere Zeile zeigt „kein Eintrag". Prüft zusätzlich, dass keine Eingabe von Hand nötig ist.
- [ ] AC-14: `test_dayWithOnlyEmptyTrackers_doesNotOpenSheet`. Tag antippen, `dayDetail.habitsSection` erscheint nicht.
- [ ] AC-15: `test_calendarFilterEnabled_dayWithTrackerEntry_opensSheet`. Gleicher Aufbau wie oben, `calendarFilterEnabled` per Launch-Argument eingeschaltet; Tag antippen, `dayDetail.habitsSection` existiert.

### Regression und Review

- [ ] AC-16: komplette bestehende Unit- und UI-Suite grün (`./Scripts/run-uitests.sh` ohne Filter, Protokoll mit `Executed N tests`).
- [ ] AC-17: Review-Punkt im Adversary-Schritt: `TrackerDayEntries.group` wird nicht in `dayView` bzw. je Zelle aufgerufen (Fundstellen per Suche im Code belegt).
- [ ] Beleg für Issue #47: Screenshot der Tagesansicht mit mehreren Gewohnheiten (aus dem UI-Test als Anhang bzw. aus dem Simulator).
- [ ] Hinweis aus Memory: verdeckte Elemente bleiben im Zugänglichkeitsbaum, daher bei Sichtbarkeit zusätzlich `isHittable` bzw. Existenz des Abschnitts im geöffneten Sheet prüfen.

Zusätzlich vor Übergabe: App im Simulator starten und den Ablauf durchspielen (Memory „Die App wird benutzt"). Keine Tests auf Hennings Geräten.

## Definition of Done

- [ ] Build erfolgreich (`xcodebuild`, Scheme „Lean Health Timer", iPhone 17 Pro, iOS 26.5)
- [ ] Alle Unit-Tests grün, inkl. `TrackerDayEntriesTests` (`Executed N tests`, N ≥ 1)
- [ ] Alle UI-Tests grün, inkl. der drei neuen (`Executed N tests`, N ≥ 1)
- [ ] AC-1 bis AC-18 erfüllt und im Test Plan abgehakt
- [ ] Screenshot der Tagesansicht mit mehreren Gewohnheiten (gefüllt und leer) liegt als Beleg vor
- [ ] App im Simulator gestartet und Ablauf durchgespielt (registrierter Durchlauf)
- [ ] Texte DE und EN in `Localizable.xcstrings` eingetragen
- [ ] Issue #47 aktualisiert; Folgeauftrag zum Nachziehen von `openspec/specs/features/calendar-view.md` vermerkt

## Out of Scope

- Innerer Kreis im Kalenderfeld, Zusammenfassung aller Gewohnheiten im Kalender (#50).
- „Empty Day Tap" aus `openspec/specs/features/calendar-view.md` (Tag ohne jede Aktivität öffnen, NoAlc nachtragen).
- Auswertung von `showInCalendar` und die Frage, ob „nichts eingetragen" bei Vermeiden-Trackern als gelungen gilt (#50).
- Änderung der NoAlc-Darstellung oder der HealthKit-Abfragen.
- Bearbeiten, Nachtragen oder Löschen von Tracker-Einträgen im Fenster.
- Challenges-Leiste über dem Kalender (Konzept 9.1, anderes Ticket).

## Risiken

- Tageszuordnung: falsche Verwendung von `TrackerManager.logs(for:on:)` oder zweite Schicht cutoffHour verschiebt Einträge um einen Tag. Gegenmaßnahme: AC-2/AC-3 als Unit-Tests.
- Doppelanzeige NoAlc: Gegenmaßnahme AC-10 (Ausnahme per Name und HealthKit-Typ).
- Performance: Logs aller aktiven Tracker über SwiftData laden und einmal gruppieren; bestehende 390 HealthKit-Abfragen bleiben unverändert. Gegenmaßnahme AC-17.
- Spec-Widerspruch: `openspec/specs/features/calendar-view.md` nennt nur geloggte „Focus Trackers" und eine wertungsfreie Darstellung. Entwurf B bleibt wertungsfrei (grau, neutral). `calendar-view.md` ist nach Umsetzung nachzuziehen (nicht Teil dieser Änderung).
- Mehrere Tracker, viele leere Zeilen: Fenster wird länger. Das Fenster ist scrollbar; keine Begrenzung in #47.
- Leerer Zustand ohne aktive Tracker: Abschnitt entfällt vollständig.
- Zugänglichkeit im UI-Test: Tab-Knöpfe ohne Kennung, Tageszellen bekommen im Zuge dieser Änderung eine.

## Changelog

- 2026-11-13: Initial spec created (Entwurf B, PO-Entscheidungen 2026-11-13)
- 2026-11-13: TDD RED: API aus den Tests festgelegt: `Row { trackerID: UUID, name: String, icon: String, entry: Entry? }`, `Entry { value: String, note: String?, time: Date }`; Häkchen = `"✓"`, Zähler `"4"` bzw. `"4 / 5"`, unbekannte Level-Id = Zahl als Text, leere Notiz = `nil`. Laufzeitumgebung: Simulator-Runtime iOS 26.5 ist nicht mehr installiert, Tests laufen auf „iPhone 17 Pro" mit iOS 27.2 (Skript-Anpassung als eigenes Issue).
- 2026-11-13: GREEN-Befund: Level- und Stimmungs-Logs speichern das Level selbst als `note` („🙂 Good“, `TrackerRow`, `LevelSelectionView`, `MoodSelectionView`). Zu AC-7 präzisiert: Eine Notiz, die dem Anzeigewert gleicht, ist keine Notiz und wird als `nil` geliefert (sonst steht „Good“ doppelt). UI-Test schließt zusätzlich das zweite Health-Zugriffsblatt nach dem Wechsel in den Erfolge-Tab; Kalender springt beim Erscheinen auf den aktuellen Monat, damit die Tageszelle von heute existiert.
- 2026-11-13: Nach Validierung ergänzt: Source, Dependencies, ADR, Estimated Changes, Definition of Done; `hasActivity` als reine Funktion; Tests für AC-15 bis AC-18
