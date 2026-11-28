# Kontext: #50 A4 Kalender – innerer Kreis als Summe aller dauerhaften Gewohnheiten

Workflow `feat-50-innerer-kreis` · Teil von Epic #44 · Konzept `DOCS/konzept-claude-verbindung.md` Abschnitt 9.1

## Request Summary

Der innere Kreis der Tagesfelder im Kalender (Reiter Erfolge) zeigt heute fest den NoAlc-Stand (Füllung in drei
Farben). Künftig soll er alle dauerhaft laufenden Gewohnheiten eines Tages zusammenfassen und dabei die Qualität
sichtbar lassen. Meditation- (außen, blau) und Workout-Ring (Mitte, lila) bleiben. Grundlage ist die vorhandene
Tagesbewertung je Tracker (`DayOutcome`: success / needsGrace / breaksStreak / noData). NoAlc darf an Gewicht
verlieren; Einzelheiten zeigt die Tagesansicht (A1, #47, erledigt).

**Offene PO-Fragen (müssen in der Analyse geklärt werden, Entwurf Pflicht – sichtbare Änderung):**
1. Füllung = Anteil eingetragen, Farbe = Anteil gelungen?
2. Vermeiden-Tracker (`logNotExists`): „nichts eingetragen“ = gelungen; braucht es ein ausdrückliches „heute nicht passiert“?
3. Alle dauerhaften Gewohnheiten oder nur ausgewählte (`showInCalendar`, existiert, wird nicht ausgewertet)?

Zeitlich begrenzte Challenges zählen ausdrücklich NICHT mit (gibt es im Code noch nicht, kommen mit #62 ff.).
Damit gilt heute: „dauerhaft“ = alle aktiven Tracker (`isActive`).

## Related Files

| Datei | Rolle |
|---|---|
| `Meditationstimer iOS/CalendarView.swift` (672 Z.) | `CalendarView` lädt HealthKit-Daten (Minuten, NoAlc-Level je Tag über `TrackerManager.fetchNoAlcLevelFromHealthKit`, Z. 415–421); `MonthView.dayView(for:)` Z. 519–600 zeichnet Füllung (28 pt, `alcoholColor`), Workout-Ring 32 pt, Meditation-Ring 42 pt, roten Heute-Punkt; Tooltip Z. 648 ff. |
| `Services/TrackerDayEntries.swift` (105 Z.) | aus #47: reine Gruppierung je Tag (`group(trackers:)` → `[Date: [Row]]`), filtert `isActive && !isNoAlc`; Tageszuordnung über `effectiveDayAssignment` (kein zweites cutoffHour). Natürlicher Ort für eine reine „Tagessumme“-Funktion. |
| `Services/TrackerModels.swift` | `DayOutcome` (Z. 139), `StreakEffect`, `SuccessCondition`, `StreakCalculator` (Z. 680) mit **privatem** `evaluateDayOutcome(logs:valueType:successCondition:)` Z. 782 – Tagesbewertung je Tracker, muss für die Summe zugänglich werden (internal/static). `showInCalendar` Z. 217. |
| `Services/TrackerManager.swift` | `calculateStreakResult(for:)`, `calculateNoAlcStreakFromHealthKit` (NoAlc läuft über HealthKit, nicht über SwiftData-Logs). |
| `Meditationstimer iOS/Views/DayDetailSheet.swift` | Tagesansicht (A1), bleibt unverändert. |
| `openspec/specs/features/calendar-view.md` | Spec: „Inner Fill = NoAlc level“, dazu nie gebaute „Center Segments“ für Focus Trackers (`showInCalendar`). Muss angepasst werden. |
| `LeanHealthTimerUITests/DayDetailHabitsUITests.swift` | UI-Tests zum Kalender/Tagesansicht (#47), Muster mit `uitest-disk-store`, Tageskennung `calendar.day.yyyy-MM-dd`. |

## Existing Patterns

- Tagesbewertung je Tracker existiert genau einmal (`StreakCalculator.evaluateDayOutcome`) – wiederverwenden, nicht duplizieren.
- Reine Logik ohne View/HealthKit in `Services/` (wie `TrackerDayEntries`) + Unit-Tests; View nur zeichnen.
- Farben NoAlc: `.alcoholSteady/.alcoholEasy/.alcoholWild`, Textfarbe `.alcoholText` auf gefüllten Tagen.
- „Tag hat Aktivität“ über `TrackerDayEntries.hasActivity(...)` (öffnet Tagesansicht).
- Vermeiden-Tracker: `logNotExists` → leerer Tag = `.success`, Eintrag = `.breaksStreak`.

## Dependencies / Dependents

- Abhängig von: #47 (erledigt) – Tagesansicht zeigt die Einzelheiten.
- NoAlc-Tagesstand kommt aus HealthKit (`alcoholDays`), alle anderen aus SwiftData-Logs → die Summe muss beide Quellen zusammenführen.
- Dependents: Spec `calendar-view.md`, Kalender-UI-Tests, Lokalisierung (falls neue Texte, z. B. Tooltip/Bedienhilfe).

## Risks

- **Lesbarkeit:** max. 3–4 Angaben je Tagesfeld (Konzept 9.1); kein zusätzlicher Ring, Füllung ersetzt NoAlc.
- **Vermeiden-Tracker** verfälschen „Anteil eingetragen“: leerer Tag ist dort gelungen, aber nicht „hingeschaut“.
- **Tage vor Anlage eines Trackers** dürfen nicht als „nichts eingetragen“ zählen (sonst wird die Vergangenheit grau).
- **NoAlc-Sonderweg** (HealthKit statt Logs) – Bewertung über `level.streakEffect`.
- Kalender lädt 13 Monate; Summenberechnung muss billig bleiben (reine Funktion über bereits geladene Logs).
- Bestehende UI-Tests, die auf NoAlc-Füllfarbe/Textfarbe bauen, könnten brechen.
- Scoping: 4–5 Dateien, ±250 LoC App-Code – realistisch (Logik ~60, View ~40).

## Analysis

**Type:** Feature (sichtbare Änderung → Entwurf vor Spec)

**Entwurf:** https://claude.ai/artifact/3Ft9CZ9h6CHGUgfU9PBsNC · Repo `DOCS/artifacts/feat-50-innerer-kreis/` (`entwurf.html`, `heute.png` = Simulator-Screenshot, Demo-Daten über Scratch-Kopie eingespielt)
- **A (Empfehlung):** Füllung 28 pt als Kuchenstück = Anteil eingetragen (e/N), Farbe = Anteil gelungen (s/N): alle → kräftig grün (`alcoholSteady`), ≥ Hälfte → hellgrün, sonst grau; Rest der Scheibe als blasse Spur. Zahl weiß ab e/N ≥ ½.
- **B:** volle Scheibe sobald etwas eingetragen, nur Farbe (s/N).
- **C:** N Segmente, je Gewohnheit ihre Tagesbewertung (grün/gelb/rot/leer).

**Empfehlungen zu den offenen PO-Fragen:** (1) A. (2) Kein „heute nicht passiert“; Vermeiden-Tracker (`logNotExists`) ohne Eintrag = eingetragen + gelungen. Alle Presets außer NoAlc sind `logExists`/`meetsGoal`/levels, Vermeiden nur bei eigenen Trackern. (3) Alle aktiven Tracker, `showInCalendar` bleibt unausgewertet (Default false bei allen → sonst leerer Kalender).

**Affected Files (geplant):**
| Datei | Change | Inhalt |
|---|---|---|
| `Services/TrackerModels.swift` | MODIFY | `StreakCalculator.evaluateDayOutcome` von `private` auf internal/static, damit die Summe dieselbe Bewertung nutzt |
| `Services/TrackerDayEntries.swift` oder neu `Services/HabitDaySummary.swift` | MODIFY/CREATE | reine Funktion: je Tag `(tracked, succeeded, total)` über alle aktiven Tracker inkl. NoAlc; Tage vor `createdAt` zählen nicht; NoAlc-Bewertung aus HealthKit-Level (`streakEffect`) |
| `Meditationstimer iOS/CalendarView.swift` | MODIFY | `dayView`: Füllung aus Summe statt `alcoholColor`; `hasActivity` berücksichtigt Summe |
| `openspec/specs/features/calendar-view.md` | MODIFY | „Inner Fill“ neu beschreiben, „Center Segments“ streichen |
| Tests: `LeanHealthTimerTests/…`, `LeanHealthTimerUITests/…` | CREATE | Unit-Tests der Summenfunktion; UI-Test Tagesfeld-Kennung/Wert (z. B. `accessibilityValue` „3 von 4 eingetragen, 2 gelungen“) |

**Scope/Risk:** ~4 App-Dateien, ~120–160 LoC App-Code; Risiko mittel (zentrale Ansicht, aber reine Darstellungslogik; keine Datenmodell-, AppStorage- oder Berechtigungsänderung).

**Technical Approach:** Tagesbewertung je Tracker genau einmal (`evaluateDayOutcome`), Zuordnung über `effectiveDayAssignment` (kein zweites cutoffHour), NoAlc aus `alcoholDays`. Summe als reine Funktion in `Services/`, View zeichnet nur (`Circle().trim`/Sektor-Shape existiert bereits als `MonthView.Sector`). Prüfbarkeit im UI-Test über `accessibilityValue` der Tageszelle statt Farbe.

**Dependencies:** #47 (erledigt). Keine neuen Abhängigkeiten.

**Open Questions:** PO-Entscheid zu Variante (A/B/C), Vermeiden-Tracker, alle vs. ausgewählte – gestellt am 2026-11-28 per Entwurfsseite.

## Neufassung nach PO-Entscheid (2026-11-28) — ersetzt „Analysis“ oben

PO: „beschlossen, dass es so bleibt (mit dem Alkohol in der Mitte) und dass die anderen Gewohnheiten oben drüber kommen.“
Der Entwurf „innerer Kreis als Summe“ (Varianten A/B/C) ist verworfen; Issue #50, Epic #44 und Konzept 9.1 sind nachgezogen.

**Neuer Auftrag #50:** Leiste über dem Kalender (Reiter Erfolge) für dauerhafte Gewohnheiten, nach Artefakt
„Challenges im Kalender“ (https://claude.ai/artifact/W4pXWkVtaFxeGfKMQgHAsP), Abschnitt „Weiterführung von Idee 3“:
- je Tracker mit `showInCalendar == true` (und `isActive`) eine Karte: Name (+ Icon), Kennzeichen „dauerhaft“, „Serie N Tage“, sieben Punkte für die letzten sieben Tage (eingetragen = gefüllt, offen = Rand grau, heute = dicker Rand).
- Antippen einer Karte wählt sie aus (Rand in Farbe); im Kalender bekommen alle Tage mit Eintrag dieser Gewohnheit einen blassen Kreis hinter dem Tagesring. Erneutes Antippen hebt die Auswahl auf.
- Tageskreise unverändert (NoAlc-Füllung bleibt). Keine Tracker mit Schalter an → keine Leiste.

**Affected Files (geplant):**
| Datei | Change | Inhalt |
|---|---|---|
| `Services/TrackerDayEntries.swift` (oder neu `Services/HabitStrip.swift`) | MODIFY/CREATE | reine Funktionen: eingetragene Tage je Tracker (über `effectiveDayAssignment`), Punktzustände der letzten 7 Tage |
| `Meditationstimer iOS/Views/HabitStripView.swift` | CREATE | Leiste mit Karten, Auswahl-Binding, Kennungen für UI-Tests |
| `Meditationstimer iOS/CalendarView.swift` | MODIFY | Leiste über den Monaten, Auswahlzustand, Markierung in `MonthView.dayView` |
| `openspec/specs/features/calendar-view.md` | MODIFY | „Center Segments“ durch Leiste ersetzen |
| Tests | CREATE | Unit: eingetragene Tage, Punkte, Filter `showInCalendar`; UI: Schalter an → Karte sichtbar, Antippen → Tag markiert (`accessibilityValue`) |

**Serie:** vorhandenes `TrackerManager.calculateStreakResult(for:)` (keine neue Rechnung).
**Scope/Risk:** 3 App-Dateien + Spec, ~150–200 LoC App-Code; Risiko niedrig–mittel (nur Darstellung im Erfolge-Reiter, keine Datenmodell-/AppStorage-Änderung; Schalter existiert bereits).
**Alternative (nicht gewählt):** Markierung direkt im Tagesfeld (Idee 1/2 des Entwurfs) — vom PO am 13.11. zugunsten der Leiste verworfen.
**Open Questions:** keine (Entwurf 13.11. gilt als freigegeben).
