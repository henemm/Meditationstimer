---
entity_id: feature-50-gewohnheiten-leiste
type: feature
created: 2026-11-28
updated: 2026-11-28
status: draft
workflow: feat-50-innerer-kreis
issue: 50
epic: 44
---

# Gewohnheiten-Leiste über dem Kalender (#50)

## Approval

- [ ] Approved for implementation

## Purpose

Über dem Kalender im Reiter Erfolge steht eine Leiste mit einer Karte je dauerhafter Gewohnheit (Tracker mit Schalter „Im Kalender anzeigen"). Die Karte zeigt Serie und die letzten sieben Tage; Antippen markiert im Kalender alle Tage, an denen die Gewohnheit eingetragen wurde. Die Tageskreise bleiben unverändert.

## Source

- **Issue:** #50, Epic #44; Konzept `DOCS/konzept-claude-verbindung.md` Abschnitt 9.1
- **Analyse:** `DOCS/context/feat-50-innerer-kreis.md`, nur Abschnitt „Neufassung nach PO-Entscheid (2026-11-28)". Die frühere Idee „innerer Kreis als Summe" (Varianten A/B/C) ist verworfen und nicht Teil dieser Spec.
- **PO-Entscheid 2026-11-28:** Alkohol bleibt in der Mitte (Füllung), die anderen Gewohnheiten kommen darüber in eine Leiste.
- **Entwurf (freigegeben 2026-11-13):** Artefakt „Challenges im Kalender", Abschnitt „Weiterführung von Idee 3" (https://claude.ai/artifact/W4pXWkVtaFxeGfKMQgHAsP).
- **Code:** `Meditationstimer iOS/CalendarView.swift` (`CalendarView.calendarContent`, `MonthView.dayView`), `Services/TrackerDayEntries.swift`, `Services/TrackerManager.swift` (`calculateStreakResult`), `Meditationstimer iOS/Tracker/TrackerEditorSheet.swift` (Schalter `showInCalendarToggle`, existiert, wird bisher nirgends ausgewertet)

## Dependencies

| Abhängigkeit | Art | Zweck |
|--------------|-----|-------|
| `Tracker.isActive`, `Tracker.showInCalendar`, `TrackerLog` (SwiftData) | Upstream | Auswahl der Karten, Einträge |
| `Tracker.effectiveDayAssignment` / `DayAssignment.assignedDay(for:calendar:)` | Upstream | Tageszuordnung |
| `TrackerManager.shared.calculateStreakResult(for:).currentStreak` | Upstream | Serie |
| `TrackerDayEntries` (#47) | Upstream | Filter `!isNoAlc` und Sortierung `isOrderedBefore` werden wiederverwendet (dafür von `private` auf `internal` heben) |
| `MonthView.dayView(for:)` | Downstream | zeichnet den blassen Kreis, setzt Bedienhilfe-Hinweis |
| Tagesansicht (#47), Tageskennung `calendar.day.yyyy-MM-dd` | unverändert | Antippen eines Tages |

## Design-Bezug

Wörtlich aus dem freigegebenen Entwurf (13.11.2026):

- Je Gewohnheit eine Karte: abgerundetes Rechteck, Rand in Linienfarbe, Hintergrund Surface. Links der Name (fett) und das Kennzeichen „dauerhaft" (klein, Großbuchstaben, gedämpft); rechts „Serie N Tage" (klein, gedämpft).
- Darunter eine Reihe von sieben Punkten (10 pt) für die letzten sieben Tage bis einschließlich heute (ältester links, heute rechts): eingetragen = gefüllt in Kartenfarbe; offen = nur grauer Rand; heute ohne Eintrag = dicker Rand in Kartenfarbe.
- Antippen wählt die Karte aus (Rand in Kartenfarbe, verstärkt). Im Kalender bekommt jeder Tag, an dem diese Gewohnheit eingetragen wurde, einen blassen Kreis (Kartenfarbe, ca. 20 % Deckkraft, etwas größer als der Tagesring, ca. 48 pt) HINTER dem Tagesring. Erneutes Antippen hebt die Auswahl auf. Höchstens eine Auswahl gleichzeitig.
- Kartenfarbe: eine feste Farbe für alle dauerhaften Gewohnheiten, abgesetzt von Blau (Meditation), Lila (Workout) und Grün (NoAlc): Rosa `#d6457a` hell, `#f06d9c` dunkel (benannte Farbe im Code, z. B. `Color.habitStrip`, Hell/Dunkel-Variante).
- Der Tracker-Icon darf vor dem Namen stehen (Feld `icon` existiert).

Keine Abweichung vom Entwurf, außer der Icon-Option und den Bedienhilfe-Angaben unten.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Bestehende Muster (reine Logik in `Services/`, `@Query` in der View, Tageszuordnung über `DayAssignment`). Keine Datenmodell-, Persistenz- oder Berechtigungsänderung.
- **Alternative (nicht gewählt):** Markierung direkt im Tagesfeld (Idee 1/2 des Entwurfs); vom PO am 13.11. zugunsten der Leiste verworfen. Ebenfalls verworfen: innerer Kreis als Summe aller Gewohnheiten (PO 2026-11-28).

## Entscheidungen (PO und Tech Lead, verbindlich)

1. Erscheinen: aktive Tracker mit `showInCalendar == true`. Kein solcher Tracker: keine Leiste, kein Leerplatz.
2. NoAlc erscheint nie in der Leiste (bleibt Füllung; Tagesstand kommt aus HealthKit, nicht aus Logs). Filter wie in `TrackerDayEntries.group` (`!isNoAlc`).
3. „Eingetragen an Tag X" = mindestens ein `TrackerLog` dieses Trackers, zugeordnet über `tracker.effectiveDayAssignment.assignedDay(for:calendar:)`, genau einmal (kein zweites cutoffHour, siehe Memory „cutoffHour double shift"). Gilt für alle Trackerarten gleich, auch Vermeiden-Tracker: die Leiste zeigt „eingetragen", keine Bewertung.
4. Serie: vorhandene `TrackerManager.shared.calculateStreakResult(for:).currentStreak`, keine neue Rechnung.
5. Auswahl ist reiner View-Zustand (`@State`), nicht gespeichert. Höchstens eine Karte gleichzeitig.
6. Zeitlich begrenzte Challenges („Tag 5 von 7") gehören nicht zu #50 (kommen mit #63 in dieselbe Leiste). Die Leiste ist eine Liste gleichartiger Karten; es wird nichts davon vorgebaut.
7. Kalenderfilter `calendarFilterEnabled` wirkt nicht auf die Leiste.

## Affected Files

| Datei | Änderung |
|-------|----------|
| `Services/HabitStrip.swift` | CREATE: reine Funktionen (Auswahl der Tracker, eingetragene Tage, Punktzustände, Serie-Text); ohne View und HealthKit-Zugriff |
| `Services/TrackerDayEntries.swift` | MODIFY: `isNoAlc` und `isOrderedBefore` von `private` auf `internal` (kein Verhaltenswechsel) |
| `Meditationstimer iOS/Views/HabitStripView.swift` | CREATE: Leiste und Karten, Auswahl als Binding, Kennungen |
| `Meditationstimer iOS/CalendarView.swift` | MODIFY: Leiste über den Monaten, `@State` Auswahl, Durchreichen an `MonthView`, blasser Kreis und Hinweis in `dayView` |
| `Meditationstimer iOS/Localizable.xcstrings` | MODIFY: neue Texte DE/EN |
| `openspec/specs/features/calendar-view.md` | MODIFY: „Center Segments"/„Focus Tracker"-Abschnitte (Z. 10, 50, 77 ff., 243 ff., Mockup) streichen und durch die Leiste ersetzen; „Inner Fill = NoAlc" bleibt |
| `LeanHealthTimerTests/HabitStripTests.swift`, `LeanHealthTimerUITests/HabitStripUITests.swift` | CREATE: Tests (zählen nicht zum Limit) |

App-Code: 4 Dateien (`HabitStrip.swift`, `HabitStripView.swift`, `CalendarView.swift`, `Localizable.xcstrings`) plus die kleine Sichtbarkeitsänderung in `TrackerDayEntries.swift`. Die Spec-Datei `calendar-view.md` ist Doku.

## Estimated Changes

| Bereich | LoC (ca.) |
|---------|-----------|
| `HabitStrip.swift` | +60 |
| `HabitStripView.swift` | +80 |
| `CalendarView.swift` | +30 |
| `TrackerDayEntries.swift` | ±2 |
| Summe App-Code | ca. 170 (Limit 250) |

Funktionen je ≤ 50 LoC.

## Technischer Ansatz (Regelweg, kein Modell)

Ohne Modell: Auswahl, Tageszuordnung und Punktzustände sind deterministisch.

### `HabitStrip` (`Services/HabitStrip.swift`)

Reine Funktionen, injizierter `Calendar` und „heute"-Datum (Standard `Date()`), kein ModelContext, kein HealthKit.

- `static func trackers(from: [Tracker]) -> [Tracker]`: `isActive && showInCalendar && !TrackerDayEntries.isNoAlc`, sortiert mit `TrackerDayEntries.isOrderedBefore` (`displayOrder`, dann `createdAt`, dann `name`; wie Tracker-Liste und Tagesansicht).
- `static func entryDays(for tracker: Tracker, calendar: Calendar) -> Set<Date>`: Tageszuordnung `tracker.effectiveDayAssignment.assignedDay(for: log.timestamp, calendar: calendar)` je Log, genau einmal; Ergebnis als Menge der zugeordneten Tage (`startOfDay`).
- `enum DotState { case filled, open, todayOpen }` und `static func dots(entryDays: Set<Date>, today: Date, calendar: Calendar) -> [DotState]`: sieben Werte, Index 0 = heute minus 6 Tage, Index 6 = heute. Tag in `entryDays` = `.filled` (auch heute); sonst `.open`; heute ohne Eintrag = `.todayOpen`. „Heute" ist der Kalendertag von `today` über `calendar.startOfDay`. Tage vor Anlage des Trackers werden nicht besonders behandelt (ohne Eintrag = `.open`).
- `static func streakText(_ days: Int) -> String`: lokalisiert, „Serie 1 Tag" bei 1, sonst „Serie N Tage" (auch 0).

Die „heute"-Bestimmung für die Punkte nutzt den Kalendertag. Ein Eintrag mit `cutoffHour:18` vor 18 Uhr zählt zum Vortag (über die Zuordnung); der Punkt für „heute" bleibt dann offen, bis nach 18 Uhr eingetragen wird.

### `HabitStripView` (`Meditationstimer iOS/Views/HabitStripView.swift`)

- Parameter: `trackers: [Tracker]` (bereits gefiltert), `selectedID: Binding<UUID?>`.
- Je Tracker eine Karte (Entwurf, siehe Design-Bezug). Serie über `TrackerManager.shared.calculateStreakResult(for:).currentStreak`, Punkte über `HabitStrip.dots`. Pro Karte einmal je Aufbau berechnen, nicht in einer inneren Schleife je Punkt.
- Antippen: `selectedID = (selectedID == tracker.id) ? nil : tracker.id`. Damit gilt: erneutes Antippen hebt auf, Antippen einer anderen Karte wechselt die Auswahl.
- Karten vertikal gestapelt wie im Entwurf (volle Breite, Abstand 8 pt); bei mehr als drei Karten ist die Leiste auf die Höhe von drei Karten begrenzt und scrollt in sich; jede Karte ist ein eigenes Element, damit später weitere Kartenarten (#63) in dieselbe Liste passen.
- Kartenfarbe als benannte Farbe, Hell/Dunkel über Asset-unabhängige Dynamikfarbe (`UIColor { trait in … }`).
- Bedienhilfe: Leiste Kennung `calendar.habitStrip`. Jede Karte ist ein einziges Element (`.accessibilityElement(children: .ignore)`) mit Kennung `calendar.habit.card`, `accessibilityLabel` = Name, `accessibilityValue` = „ausgewählt" bei Auswahl, sonst leer, und Trait `.isSelected` bei Auswahl.

### `CalendarView` / `MonthView`

- `@State private var selectedHabitID: UUID?` in `CalendarView`.
- Leiste über der Monatsliste (oberhalb des `ScrollViewReader`, außerhalb der Scrollfläche, damit sie beim Blättern stehen bleibt). Nur gezeichnet, wenn `HabitStrip.trackers(from: activeTrackers)` nicht leer ist (kein Leerplatz).
- Die eingetragenen Tage der ausgewählten Gewohnheit werden einmal je Aufbau berechnet (`HabitStrip.entryDays`) und als `highlightedDays: Set<Date>` an `MonthView` gereicht (leer ohne Auswahl). `entryDays` wird nicht je Tageszelle aufgerufen.
- `MonthView.dayView(for:)`: liegt `dayKey` in `highlightedDays`, wird als unterste Schicht der ZStack (hinter Füllung und Ringen) ein `Circle` in Kartenfarbe mit 20 % Deckkraft, 48 pt gezeichnet. Zusätzlich `accessibilityValue("markiert")` an der Tageszelle (sonst leer).
- Kalenderfeld, Ringe, Füllung, Fettdruck, Heute-Punkt und Tippverhalten (Tagesansicht #47) bleiben unverändert. Eine Markierung allein öffnet kein Tagesfenster (`hasActivity` unverändert).
- Ist die ausgewählte Tracker-Id nicht mehr in der Leiste (Tracker inaktiv oder Schalter aus), wird kein Kreis gezeichnet (leere `highlightedDays`) und die Auswahl gilt als aufgehoben.

### Texte (`Localizable.xcstrings`)

| Schlüssel (DE) | EN |
|----------------|----|
| dauerhaft | ongoing |
| Serie %lld Tage | Streak %lld days |
| Serie 1 Tag | Streak 1 day |
| ausgewählt | selected |
| markiert | marked |

Anzeige „dauerhaft" in Großbuchstaben per `.textCase(.uppercase)` in der View. Alle Einträge mit `"extractionState": "manual"` und `"state": "translated"` (sonst Großschreibung im Debug-Build, Memory Bug 38). Der Plural wird über zwei Schlüssel gelöst (1 / sonst), nicht über Pluralvarianten.

## Acceptance Criteria

Ein „Tracker T" ist ein Tracker mit `isActive == true`, nicht NoAlc (Name „NoAlc" oder HealthKit-Typ `numberOfAlcoholicBeverages`).

- **AC-1 Auswahl der Karten:** Given aktive Tracker mit `showInCalendar` an und aus, ein inaktiver mit Schalter an, ein NoAlc-Tracker mit Schalter an, When die Leiste aufgebaut wird, Then erscheinen nur aktive, Nicht-NoAlc-Tracker mit Schalter an.
- **AC-2 Keine Leiste:** Given kein Tracker erfüllt AC-1, When der Erfolge-Reiter angezeigt wird, Then existiert `calendar.habitStrip` nicht und die Monatsliste beginnt ohne Leerplatz.
- **AC-3 Reihenfolge:** Given Tracker mit `displayOrder` 2, 0, 1, When die Leiste aufgebaut wird, Then stehen die Karten in Reihenfolge 0, 1, 2 (wie in der Tagesansicht).
- **AC-4 Eingetragene Tage, Tageszuordnung:** Given ein Tracker mit `dayAssignmentRaw == nil` und ein Log am 13.11. um 17:00, When `entryDays` berechnet wird, Then enthält die Menge den 13.11. und keinen anderen Tag.
- **AC-5 cutoffHour-Grenze:** Given ein Tracker mit `cutoffHour:18`, When Logs am 13.11. um 17:00, um 18:00 und um 00:30 existieren, Then gehören sie zum 12.11., 13.11. und 12.11. (jeweils genau eine Verschiebung, 00:30 nicht zum 11.11.).
- **AC-6 Mehrere Logs, Vermeiden:** Given mehrere Logs am selben Tag oder ein Vermeiden-Tracker (`logNotExists`) mit Log, When `entryDays` berechnet wird, Then zählt der Tag einmal als eingetragen; ein Tag ohne Log zählt nie als eingetragen (keine Wertung).
- **AC-7 Punktzustände:** Given „heute" = 28.11., Einträge am 22., 25. und 28.11., When `dots` berechnet wird, Then ergeben sich sieben Punkte (22.–28.11.) mit `[filled, open, open, filled, open, open, filled]`; ohne Eintrag am 28.11. ist der letzte Punkt `todayOpen`, die anderen offenen `open`.
- **AC-8 Tage vor Anlage:** Given ein Tracker, der erst am 27.11. angelegt wurde, When `dots` berechnet wird, Then sind die Tage davor `open` (keine Sonderbehandlung, kein vierter Zustand).
- **AC-9 Serie-Text:** Given `currentStreak` 0, 1 und 5, When der Text erzeugt wird, Then lautet er „Serie 0 Tage", „Serie 1 Tag", „Serie 5 Tage" (EN „Streak 0 days", „Streak 1 day", „Streak 5 days"). Der Wert stammt unverändert aus `calculateStreakResult(for:)`.
- **AC-10 Karte:** Given ein Tracker mit Schalter an, When die Leiste sichtbar ist, Then zeigt die Karte Name (fett), „dauerhaft" (klein, Großbuchstaben, gedämpft), „Serie N Tage" und sieben Punkte (10 pt) wie im Entwurf.
- **AC-11 Antippen markiert:** Given eine Karte und ein Eintrag an Tag X, When die Karte angetippt wird, Then ist sie ausgewählt und die Tageszelle von X (auch in einem früheren Monat) trägt einen blassen Kreis (Kartenfarbe, ca. 20 %, ca. 48 pt) hinter dem Tagesring; Tageszellen ohne Eintrag dieser Gewohnheit bleiben unmarkiert.
- **AC-12 Aufheben und Wechsel:** Given eine ausgewählte Karte, When sie erneut angetippt wird, Then ist die Auswahl und jede Markierung weg. Wird stattdessen eine andere Karte angetippt, Then ist nur noch diese ausgewählt und nur deren Tage sind markiert (höchstens eine Auswahl).
- **AC-13 Tageskreise unverändert:** Given Tage mit Meditation, Workout und NoAlc, When Leiste vorhanden und eine Karte ausgewählt ist oder nicht, Then sehen Ringe (außen blau 42 pt, Mitte lila 32 pt), NoAlc-Füllung (28 pt), Zahl und Heute-Punkt aus wie vorher; die Markierung liegt dahinter.
- **AC-14 Tagesansicht unverändert:** Given ein Tag mit Aktivität, When er angetippt wird, Then öffnet die Tagesansicht (#47) wie bisher, mit oder ohne Markierung. Ein nur markierter Tag ohne Aktivität öffnet nichts.
- **AC-15 Hell und Dunkel:** Given Hell- und Dunkelmodus, When Leiste und Markierung erscheinen, Then verwenden sie `#d6457a` (hell) bzw. `#f06d9c` (dunkel); Text und Ränder bleiben lesbar.
- **AC-16 Texte lokalisiert:** Given Deutsch bzw. Englisch, When die Leiste erscheint, Then lauten die Texte „dauerhaft"/„ongoing" und „Serie N Tage"/„Streak N days"; im Debug-Build ohne Großschreibung der Schlüssel (außer dem gewollten `.uppercase` bei „dauerhaft").
- **AC-17 Berechnung einmal je Aufbau:** Given ein Monat mit 31 Zellen, When der Kalender aufgebaut wird, Then wird `entryDays` einmal je Aufbau bzw. Datenänderung berechnet, nicht je Zelle (Review-Kriterium, kein Laufzeittest).
- **AC-18 Prüfbarkeit:** Karte Kennung `calendar.habit.card` mit `accessibilityLabel` = Name und `accessibilityValue` „ausgewählt" (sonst leer) sowie Trait `.isSelected`; Leiste `calendar.habitStrip`; markierte Tageszelle (`calendar.day.yyyy-MM-dd`) mit `accessibilityValue` „markiert", unmarkierte mit leerem Wert.

## Test Plan

### Unit-Tests (`LeanHealthTimerTests/HabitStripTests.swift`, In-Memory-SwiftData, injizierter `Calendar` und „heute")

- [ ] AC-1: `test_trackers_onlyActiveShowInCalendarNonNoAlc`
- [ ] AC-2: `test_trackers_noneEnabled_isEmpty`
- [ ] AC-3: `test_trackers_sortedByDisplayOrder`
- [ ] AC-4: `test_entryDays_timestampAssignment_sameDay`
- [ ] AC-5: `test_entryDays_cutoff18_boundaryAndMidnightShiftedOnce`
- [ ] AC-6: `test_entryDays_multipleLogsOneDay_andAvoidTracker_noLogNotEntered`
- [ ] AC-7: `test_dots_filledOpenAndTodayOpen`
- [ ] AC-8: `test_dots_daysBeforeCreation_areOpen`
- [ ] AC-9: `test_streakText_zeroOneMany_DEandEN` (liest aus `de.lproj`/`en.lproj` des App-Bundles; Wert darf nicht der Schlüssel in Großschreibung sein)
- [ ] AC-16: `test_localization_ongoingAndSelectedAndMarked_DEandEN`

Erfolgsnachweis: Protokoll zeigt `Executed N tests` mit N ≥ 1 bzw. `Test case 'HabitStripTests.…' passed` unter Xcode 27.

### UI-Tests (`LeanHealthTimerUITests/HabitStripUITests.swift`, Aufruf nur als `./Scripts/run-uitests.sh HabitStripUITests/<methode>`)

Muster `DayDetailHabitsUITests.swift` (Testdaten über die echte Oberfläche, Launch-Argumente `enable-testing`, `uitest-disk-store`, `uitest-reset-store`, Health-Blätter über `HealthSheetHelper.swift`).

- [ ] AC-1, AC-10: `test_switchOn_cardVisible` — Tracker anlegen, Eintrag heute, „Im Kalender anzeigen" (`showInCalendarToggle`) an, Erfolge-Reiter: `calendar.habitStrip` und `calendar.habit.card` mit Label = Name existieren.
- [ ] AC-2: `test_switchOff_noStrip` — Schalter aus: `calendar.habitStrip` existiert nicht.
- [ ] AC-11: `test_tapCard_marksDayWithEntry_notOtherDay` — Karte antippen: Karte `accessibilityValue` „ausgewählt"; Tageszelle von heute `accessibilityValue` „markiert", eine andere Tageszelle (ohne Eintrag) nicht.
- [ ] AC-12: `test_tapCardAgain_removesMarking` — erneut antippen: Karte nicht ausgewählt, Tageszelle von heute ohne „markiert". Wechsel auf zweite Karte (zwei Tracker): nur noch deren Tage markiert.
- [ ] AC-13, AC-14: `test_dayTap_stillOpensDetailSheet_withSelection` — mit gewählter Karte Tag antippen: `dayDetail.habitsSection` erscheint.
- [ ] AC-17: Review-Punkt im Adversary-Schritt (Suche nach `entryDays`-Aufrufen im Code).
- [ ] AC-15: Hell/Dunkel nicht per Farbe prüfbar: Review und Screenshot im Simulator in beiden Modi als Beleg.

### Regression und Review

- [ ] Komplette bestehende Unit-Suite grün; UI-Regression mindestens `DayDetailHabitsUITests` und die Kalender-Tests (Altlast #25 beachten, keine neuen roten Tests); Aufwand angemessen (Memory „Aufwand angemessen").
- [ ] Verdeckte Elemente bleiben im Zugänglichkeitsbaum: bei Sichtbarkeit zusätzlich `isHittable` prüfen.
- [ ] Screenshots der Leiste mit Auswahl (hell und dunkel) als Beleg.

Zusätzlich vor Übergabe: App im Simulator starten und den Ablauf durchspielen (Memory „Die App wird benutzt"). Keine Tests auf Hennings Geräten.

## Side-Effects

- **Dateien:** siehe Affected Files; nur Erfolge-Reiter betroffen.
- **AppStorage:** keine neuen oder geänderten Schlüssel; Auswahl nur `@State`.
- **Datenmodell/Persistenz:** keine Änderung (`showInCalendar` existiert, wird erstmals ausgewertet; Standardwert bleibt, Nutzer müssen den Schalter selbst einschalten).
- **Permissions/Info.plist:** keine.
- **Lokalisierung:** neue Texte DE/EN in `Localizable.xcstrings` (siehe oben).
- **Audio:** keine.
- **Watch/Widget:** nicht betroffen.
- **Sichtbarkeit:** `TrackerDayEntries.isNoAlc`/`isOrderedBefore` werden `internal`; Verhalten unverändert.
- **Performance:** je Aufbau eine zusätzliche Gruppierung für höchstens einen ausgewählten Tracker plus je Karte Serie und sieben Punkte; keine zusätzlichen HealthKit-Abfragen.

## Definition of Done

- [ ] Build erfolgreich (`xcodebuild`, Scheme „Lean Health Timer", iPhone 17 Pro, iOS 27.2)
- [ ] Alle Unit-Tests grün, inkl. `HabitStripTests` (`Executed N tests`, N ≥ 1)
- [ ] Alle UI-Tests grün, inkl. der neuen (`Executed N tests`, N ≥ 1)
- [ ] AC-1 bis AC-18 erfüllt und im Test Plan abgehakt
- [ ] App im Simulator gestartet und Ablauf durchgespielt (registrierter Durchlauf), Screenshots hell und dunkel
- [ ] Texte DE und EN in `Localizable.xcstrings`
- [ ] `openspec/specs/features/calendar-view.md` nachgezogen (Leiste statt „Center Segments")
- [ ] Issue #50 aktualisiert

## Out of Scope

- Zeitlich begrenzte Challenges und deren Karten („Tag 5 von 7"), #63.
- Innerer Kreis als Summe der Gewohnheiten (verworfen), Änderung von Tageskreisen, NoAlc-Füllung oder HealthKit-Abfragen.
- Bewertung von Tagen (gelungen/misslungen), auch bei Vermeiden-Trackern.
- Speichern der Auswahl, neue Einstellungen, ein Farbfeld je Tracker.
- Tagesansicht (#47) und Nachtragen von Einträgen.

## Risiken

- **Tageszuordnung:** zweite Schicht cutoffHour verschiebt Einträge um einen Tag. Gegenmaßnahme: AC-4/AC-5 als Unit-Tests, Zuordnung nur über `assignedDay`.
- **Doppelter Index „heute":** Punkt „heute offen" vs. Zuordnung `cutoffHour` (siehe Technischer Ansatz); nur Darstellung, in AC-7 abgedeckt.
- **Platz:** viele Karten verdrängen den Kalender. Gegenmaßnahme: Henning wählt über den Schalter, welche Gewohnheiten erscheinen; ab mehr als drei Karten wird die Leiste auf die Höhe von drei Karten begrenzt und scrollt in sich (Kalender bleibt sichtbar).
- **Bedienhilfe:** Farbe ist im UI-Test nicht prüfbar; Prüfung über Kennung/`accessibilityValue` (AC-18).
- **Kartenfarbe:** eine Farbe für alle Gewohnheiten; bei mehreren Karten unterscheidet nur die Auswahl, was markiert ist (bewusst, PO-Entwurf).
- **Spec-Altlast:** `calendar-view.md` beschreibt nie gebaute „Focus Tracker Segments" und widerspricht sonst dem Stand; wird in derselben Änderung bereinigt.

## Changelog

- 2026-11-28: Initial spec created (PO-Entscheid 2026-11-28, Entwurf 13.11. „Weiterführung von Idee 3")
