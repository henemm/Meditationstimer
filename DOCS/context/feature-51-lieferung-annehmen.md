# Context: feature-51-lieferung-annehmen (#51, B1a)

## Request Summary
Die App liest eine Lieferung von Claude (Format `hhhaven.delivery/1`) ein, übernimmt Übungen, Programme und Atemübungen
ganz oder gar nicht und genau einmal je `deliveryId`, kennzeichnet sie als „von Claude“ und kann sie einzeln oder als Paket
zurücknehmen. Ohne Netz; getestet mit dem gemeinsamen Beispielsatz aus B0.

## Maßgebliche Vorgaben (neuer als der Issue-Text)
- Spec liegt schon vor: `openspec/specs/features/claude-annahme.md` (Stand 13.11.2026), mit drei Schnitten.
- PO 13.11.: **Kein zweiter Prüfer in Swift.** Der Dienst prüft mit dem Referenz-Prüfer, die App dekodiert nur mit `Codable`
  (`APP_CANNOT_READ`, `KIND_NOT_SUPPORTED`). Der Issue-Satz „gleich beurteilen wie der Referenz-Prüfer“ ist damit überholt:
  Die Tests verlangen nur, dass alle gültigen Beispiele gelesen und richtig übernommen werden.
- PO 13.11. „Ort der Wahrheit“: Das iPhone gewinnt nur bei Änderungen **nach der letzten Abschrift** (`CHANGED_ON_IPHONE`).
  Der Issue-Satz „angepasst → spätere Änderungen immer abgelehnt“ ist damit überholt.
- Brücke B1b/B1c entfällt (Konzept Abschnitt 2), Lieferungen kommen später nur über den Dienst (#57).

## Related Files
| Datei | Relevanz |
|---|---|
| `Contracts/schema/delivery-v1.schema.json` | Format; Kennungen `claude.<slug>`, Übungsbezüge `builtin.`/`own.`/`claude.` |
| `Contracts/deliveries/valid/` (51), `invalid/` (154) | Beispielsatz; Datei = `{description, delivery, context?, expected}` |
| `Contracts/validator/src/index.ts` | Referenz-Prüfer (TypeScript), nur Vorbild, nicht nachbauen |
| `openspec/specs/integrations/claude-lieferformat.md` | Format-Spec; Abschnitt 7 (Z. 206) Anwende-Regeln, Swift-Hinweise Z. 69/120/131 |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:166-239,318-332` | `WorkoutSet`/`WorkoutPhase` (Codable, `exerciseId`, `hint`), Laden mit Sicherung |
| `Meditationstimer iOS/Tabs/WorkoutTab.swift:44` | Ablage Programme: UserDefaults `workoutProgramSets` |
| `Meditationstimer iOS/Tabs/AtemView.swift:43-52` | `AtemView.Preset` (Codable) |
| `Meditationstimer iOS/Tabs/MeditationTab.swift:65` | Ablage Atemübungen: UserDefaults `atemPresets` |
| `Meditationstimer iOS/Services/ExerciseDatabase.swift:44ff, 620-770` | Eingebauter Katalog, `info(forId:)`, `exerciseId(forName:)` |
| `Meditationstimer iOS/Models/ExerciseInfo.swift:10-57` | `ExerciseInfo`, `ExerciseOrigin` (aus Präfix abgeleitet) |
| `LeanHealthTimerTests/ExerciseCatalogTests.swift:19-22` | Muster: Contracts-Datei per `#filePath` lesen |
| `LeanHealthTimerTests/WorkoutPhaseMigrationTests.swift` | Muster: UserDefaults-Suite je Test, Alt-Daten-Lesetest |
| `DOCS/context/analyse-51-57-claude-app.md` | Frühere Analyse (vor #48), Abschnitt 2 Doppel-Laden der Listen, 5.1 eigener Speicher |

## Existing Patterns
- Programme und Atemübungen sind `Codable`-Structs als JSON in UserDefaults, keine SwiftData-Modelle. Neue Felder optional
  halten, eigener Decoder wie bei `WorkoutPhase` (#48) für Alt-Daten.
- Kennungen statt Namen: `exerciseId` mit Präfix bestimmt die Herkunft (`ExerciseOrigin`).
- Contracts-Dateien werden in Tests über `#filePath` gelesen, nicht ins Bundle kopiert.

## Dependencies
- Upstream: Format B0 (#46, geschlossen), Katalog-Kennungen und `hint` aus A2 (#48/#84/#85, geschlossen).
- Downstream: #57 (Abgleich mit dem Dienst ruft den Annahme-Kern auf, liefert den Zeitpunkt der letzten Abschrift),
  #59 (Abschrift), B4b–B6b (weitere Arten).

## Risks & Considerations
- **Gelieferte Übungen haben noch keinen Speicher.** Eigene Übungen existieren nur als Schrittname; für `claude.*`-Übungen
  (Wirkung, Anleitung) braucht es eine Ablage, die `ExerciseDatabase.info(forId:)` mitliest.
- **Zeitpunkt der letzten Abschrift** gibt es erst mit #57/#59. Für #51 muss ein Platzhalter-Wert (z. B. gespeicherter Zeitstempel,
  anfangs leer) festgelegt werden, ohne #57 vorwegzunehmen.
- **Doppeltes Laden/Zurückschreiben** der Listen durch je zwei Ansichten (Spec Punkt 8): Nach dem Anwenden müssen offene Listen
  neu laden, sonst überschreiben sie die Lieferung.
- **Umfang:** Spec ist in drei Schnitte geteilt; je Schnitt eine eigene Workflow-Runde (Memory „Runde je Schnitt“).
  Diese Runde = Schnitt 1 (optionale Felder, Einlesen, Gleichlauf-Test über die gültigen Beispiele).
- **Schnitt 3 ist sichtbar** (Zeichen „von Claude“, Info-Ansicht): braucht vorher einen Entwurf zum Ansehen (globale Regel
  „Entwurf vor Spec bei UI-Änderungen“).
- Alte gespeicherte Listen müssen unverändert lesbar bleiben (Datenverlust wäre schwerwiegend).

## Analysis

### Type
Feature (Schnitt 1 von 3 der Spec `openspec/specs/features/claude-annahme.md`)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Models/ClaudeDelivery.swift` | CREATE | Reines Lese-Modell der Lieferung (nur Foundation): Hülle, `ClaudeItem`-Enum über `kind` (exercise, program, breath, withdrawal itemId/packageId, unsupported), Datum mit/ohne Millisekunden, Einstieg `read(Data)` mit Fehlern `APP_CANNOT_READ` / `KIND_NOT_SUPPORTED` und deutschem Kurzgrund |
| `LeanHealthTimerTests/ClaudeDeliveryDecodingTests.swift` | CREATE | Gleichlauf-Test über `Contracts/deliveries/valid/` per `#filePath` plus Fehlerfälle |
| `openspec/specs/features/claude-annahme.md` | MODIFY (Phase 3) | `claudeId` → `itemId` (Schema führt, feature-48 Z. 163); Schnitt-Zuschnitt präzisieren (Modell-Felder an App-Typen erst Schnitt 2) |

Nicht angefasst: `WorkoutSet`/`WorkoutPhase`, `AtemView.Preset`, `ExerciseInfo`, UserDefaults-Ablagen, `project.pbxproj`
(beide Ordner synchronisiert), `Contracts/`.

### Scope Assessment
- Files: 2 Code/Test (+1 Spec)
- Estimated LoC: +~250 / -0
- Risk Level: LOW — neuer, isolierter Code; gespeicherte Daten werden nicht berührt.

### Technical Approach
- Eigene Wire-Typen spiegeln das Schema 1:1 (Kategorie als String, `exerciseId` unverändert). Kein Mapping auf App-Typen, keine
  Namensauflösung der Schritte (Schema-Step hat keinen Namen) — beides ist Anwenden und gehört in Schnitt 2, sonst entsteht
  ungenutzter Code.
- Abweichung vom Spec-Wortlaut „Schnitt 1 = Modell-Felder (optional)“: Die Zusatzfelder an `WorkoutSet`/`Preset` kommen erst in
  Schnitt 2, weil ihre Form vom Speicherort abhängt (offene Punkte). Kein Eingriff in gespeicherte Listen, bevor er gebraucht wird.
- Fehlerregel: Hülle oder Pflichtfeld nicht lesbar → `APP_CANNOT_READ`; lesbar, aber mindestens eine Position
  reminder/challenge/tracker → ganze Lieferung `KIND_NOT_SUPPORTED`. Unbekannte Schlüssel werden toleriert (Dienst prüft strikt
  mit dem Referenz-Prüfer; kein zweiter Prüfer in Swift).
- Datum: `ISO8601DateFormatter` mit und ohne `.withFractionalSeconds` (Standardstrategie `.iso8601` kann keine Millisekunden).
- Datei kompiliert automatisch auch für Watch und Widget (synchronisierter Ordner) → nur Foundation verwenden.

### Gleichlauf-Test (Definition)
- Alle Dateien in `Contracts/deliveries/valid/` lesen, `delivery` auspacken. Gezählt am 2026-11-20: 51 Dateien, davon 19 mit
  reminder/challenge/tracker (auch gemischt, z. B. `reminder-workout-program.json`) → `KIND_NOT_SUPPORTED`; 32 → angenommen.
  Mindestanzahl erzwingen (≥ 51 gesamt, ≥ 32 lesbar), je Art mindestens ein Beispiel (Dateien: exercise 9, program 20,
  breath 7, withdrawal 4).
- Je angenommener Datei: Anzahl Positionen, `itemId`, `revision`, `name`, Runden, Schrittzahl, `hint`, Atemzeiten, `package`
  gleich dem Roh-JSON.
- `created-at-millis.json`: Zeitpunkt auf die Millisekunde; eine Datei ohne Millisekunden ebenfalls.
- Zusatz: kaputtes JSON und fehlendes Pflichtfeld → `APP_CANNOT_READ`; unbekannter Zusatzschlüssel → toleriert. `invalid/` wird
  nicht als Prüf-Gleichlauf ausgewertet (wäre ein zweiter Prüfer).

### Dependencies
- Liest nur `Contracts/` (Schema B0, Beispielsatz). Keine Abhängigkeit zu Listen oder Ansichten.
- Downstream: Schnitt 2 (Anwenden) baut auf `ClaudeDelivery.read` auf; #57 ruft später denselben Einstieg.

### Alternativen
- Felder schon jetzt an `WorkoutSet`/`Preset` (Spec-Wortlaut): verworfen für Schnitt 1 — Form hängt vom Speicherort ab, und
  unbenutzte Felder ändern die synthetisierte Gleichheit (`Hashable`) gespeicherter Listen.
- Direkt in App-Typen dekodieren statt eigener Wire-Typen: verworfen — Schema-Step hat keinen Namen, Kategorien sind englisch
  statt der deutschen Rohwerte, Rücknahme hat keinen App-Typ.

### Open Questions (für Schnitt 2, nicht für diese Runde)
- [ ] Speicherort gelieferter Bausteine: Spec „bestehende Listen/Katalog“ vs. Analyse 5.1 „eigener Speicher“. Vorschlag Hybrid:
  Programme/Atem als Kopie in die bestehenden Listen, Übungen und Verwaltungsdaten (Fassung, Paket, deliveryId-Gedächtnis) in
  einer kleinen eigenen Datei.
- [ ] `atemPresets` hat keine Sicherung bei Lesefehler (Defaults überschreiben) → vor oder mit Schnitt 2 Sicherung analog
  `workoutProgramSets`.
- [ ] Zeitpunkt der „letzten Abschrift“ existiert in der App noch nicht (#57/#59).
