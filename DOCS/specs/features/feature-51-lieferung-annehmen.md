---
entity_id: feature-51-lieferung-annehmen
type: feature
created: 2026-11-20
updated: 2026-11-20
status: draft
workflow: feature-51-lieferung-annehmen
issue: 51
epic: 44
---

# App liest Lieferungen von Claude ein (B1a, #51, Schnitt 1 von 3)

## Approval

- [ ] Approved

## Purpose

Die App bekommt ein reines Lese-Modell für Lieferungen von Claude (Format `hhhaven.delivery/1`): Ein Einstieg `read(Data)` macht aus den Rohdaten eine typisierte Lieferung oder meldet `APP_CANNOT_READ` bzw. `KIND_NOT_SUPPORTED` mit kurzem deutschem Grund. Ein Gleichlauf-Test über den gemeinsamen Beispielsatz aus B0 beweist, dass jede gültige Beispiellieferung richtig gelesen wird. Das ist der Unterbau für das Anwenden (Schnitt 2) und die Anzeige (Schnitt 3).

**Für Henning noch unsichtbar:** Diese Runde ändert nichts, was in der App zu sehen oder zu bedienen ist. Es wird nichts gespeichert, nichts angewendet, keine Liste und keine Ansicht berührt. Sichtbar wird Claudes Lieferung erst mit Schnitt 2 (Anwenden) und Schnitt 3 (Zeichen „von Claude“).

## Source

- **Issue:** #51 „B1a App liest Lieferungen von Claude ein", Epic #44
- **Übergeordnete Spec (drei Schnitte):** `openspec/specs/features/claude-annahme.md`
- **Analyse:** `DOCS/context/feature-51-lieferung-annehmen.md`
- **Format:** `openspec/specs/integrations/claude-lieferformat.md`, `Contracts/schema/delivery-v1.schema.json`, Beispielsatz `Contracts/deliveries/valid/`
- **Formvorbild Test:** `LeanHealthTimerTests/ExerciseCatalogTests.swift` (Contracts-Datei per `#filePath`)

## Dependencies

| Abhängigkeit | Art | Zweck |
|--------------|-----|-------|
| `Contracts/schema/delivery-v1.schema.json` | Upstream (Vertrag) | Feldnamen und Formen, die das Modell 1:1 spiegelt |
| `Contracts/deliveries/valid/` | Upstream (Beispielsatz) | Prüfmaterial des Gleichlauf-Tests, nur lesend |
| Referenz-Prüfer `Contracts/validator` | Vorbild, nicht nachbauen | Der Dienst prüft strikt; die App prüft nicht ein zweites Mal (PO 13.11.2026) |
| Schnitt 2 (Anwenden) und #57 (Abgleich mit dem Dienst) | Downstream | rufen später denselben Einstieg `read(Data)` auf |
| Watch, Widget | Berührung nur durch Kompilierung | Der Ordner `Models/` ist synchronisiert, die Datei wird auch dort übersetzt: nur Foundation verwenden |

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Eigene Wire-Typen spiegeln das Schema 1:1 (Kategorie als englischer String, `exerciseId` unverändert, Schritte ohne Namen). Kein Mapping auf `WorkoutSet`, `WorkoutPhase`, `AtemView.Preset` oder `ExerciseInfo` und keine Namensauflösung: beides ist Anwenden und gehört in Schnitt 2, sonst entsteht ungenutzter Code. Kein zweiter Prüfer in Swift: die App dekodiert nur.

## Scope

### Affected Files (2 neu)

| Datei | Inhalt |
|---|---|
| `Meditationstimer iOS/Models/ClaudeDelivery.swift` | Lese-Modell (nur Foundation) |
| `LeanHealthTimerTests/ClaudeDeliveryDecodingTests.swift` | Gleichlauf-Test und Fehlerfälle |

### Estimated Changes

Dazu kommt die Pflege der übergeordneten Spec (`openspec/specs/features/claude-annahme.md`). Geschätzt etwa 250 Zeilen neuer Code (Modell rund 110, Test rund 140), keine Funktion über 50 Zeilen.

### Ausdrücklich nicht in dieser Runde

- Anwenden von Lieferungen, Gedächtnis der `deliveryId`s, Fassungen, „iPhone gewinnt“, Rücknahme-Wirkung
- Speicherung jeder Art, UserDefaults, Dateien
- Felder an `WorkoutSet`, `WorkoutPhase`, `AtemView.Preset`, `ExerciseInfo` (kommen in Schnitt 2, weil ihre Form vom Speicherort abhängt)
- Jede Oberfläche, Texte, Lokalisierung
- `project.pbxproj` (beide Ordner sind synchronisiert), `Contracts/`

## Expected Behavior

### Modell (Signaturen, Ausschnitt)

```swift
struct ClaudeDelivery { // Hülle: format, deliveryId, source, createdAt (Date), why, package?, items
    static func read(_ data: Data) throws(ClaudeDeliveryError) -> ClaudeDelivery
}
enum ClaudeItem {       // über "kind"
    case exercise(...), program(...), breath(...)
    case withdrawal(itemId: String?, packageId: String?)
    case unsupported(kind: String)   // reminder, challenge, tracker
}
struct ClaudeDeliveryError: Error { let code: String; let reason: String }
```

Die genaue Form (Struct oder Enum, benannte Felder) bestimmt der Developer; maßgeblich sind die Verhaltensregeln unten und die Acceptance Criteria.

### Regeln

1. **Hülle:** `format`, `deliveryId`, `source`, `createdAt`, `why`, `items`, optional `package` (`packageId`, `name`) werden gelesen. Fehlt ein Pflichtfeld oder hat ein Feld den falschen Typ: `APP_CANNOT_READ`.
2. **Positionen:** `exercise` (`itemId`, `revision`, `name`, optional `nameEn`, `category` als Text, `effect`, `instructions`, optional `notes`), `program` (`itemId`, `revision`, `name`, `symbol`, optional `description`, `rounds`, `steps` mit `exerciseId`, `workSeconds`, `restSeconds`, optional `hint`), `breath` (`itemId`, `revision`, `name`, `symbol`, optional `description`, `inhaleSeconds`, `holdInSeconds`, `exhaleSeconds`, `holdOutSeconds`, `rounds`), `withdrawal` (genau eines von `itemId` oder `packageId`, wie im Schema).
3. **Nicht unterstützte Arten:** `reminder`, `challenge`, `tracker` werden nicht ausgelesen (Inhalt egal), nur als `unsupported` vermerkt. Enthält eine Lieferung mindestens eine solche Position, auch neben lesbaren, ist das Ergebnis von `read` für die **ganze** Lieferung `KIND_NOT_SUPPORTED`.
4. **Unbekannte Schlüssel** (in Hülle, Positionen, Schritten) werden toleriert und ignoriert; der Dienst prüft streng.
5. **Datum:** `createdAt` wird mit und ohne Millisekunden gelesen (`ISO8601DateFormatter` mit und ohne `.withFractionalSeconds`; die Standardstrategie `.iso8601` kann keine Millisekunden). Unlesbares Datum: `APP_CANNOT_READ`.
6. **Fehler:** kaputtes JSON, Hülle oder Pflichtfeld nicht lesbar, unbekannte Art (nicht in der Liste der sieben): `APP_CANNOT_READ` mit kurzem deutschem Grund; `KIND_NOT_SUPPORTED` nach Regel 3 ebenfalls mit deutschem Grund. Reihenfolge: ist die Hülle oder eine lesbare Position kaputt, gilt `APP_CANNOT_READ`; nur wenn alles lesbar ist und eine nicht unterstützte Art vorkommt, `KIND_NOT_SUPPORTED`.
7. **Nebenwirkungen:** keine. `read` ist rein, schreibt nichts und liest nichts außer den übergebenen Daten.

## Tatsächliche Zahlen des Beispielsatzes

Nachgezählt am 2026-11-20 in `Contracts/deliveries/valid/` (Dateien, nicht Positionen):

| Größe | Wert |
|---|---|
| Dateien gesamt | 51 |
| mit mindestens einer Position reminder/challenge/tracker (auch gemischt) | 19 |
| lesbar | 32 |
| Dateien mit mindestens einer Übung (`exercise`) | 9 |
| mit mindestens einem Programm (`program`) | 20 |
| mit mindestens einer Atemübung (`breath`) | 7 |
| mit mindestens einer Rücknahme (`withdrawal`) | 4 |

Die Art-Zahlen zählen Dateien, in denen die Art vorkommt (eine gemischte Datei zählt mehrfach). Gemischte Beispiele mit nicht unterstützter Art neben lesbarer: `reminder-program-in-delivery.json`, `reminder-workout-program.json`. Die Mindestanzahlen im Test sind Untergrenzen (≥), damit der Beispielsatz wachsen darf, aber nicht still schrumpft.

## Acceptance Criteria

Alle Tests liegen in `LeanHealthTimerTests/ClaudeDeliveryDecodingTests.swift` (Klasse bzw. Suite `ClaudeDeliveryDecodingTests`); die Namen sind Vorgaben für QA und dürfen nur in der Schreibweise abweichen.

- **AC-1: Beispielsatz vollständig gefunden.** In `valid/` liegen mindestens 51 Dateien; die Dateien werden per `#filePath` gelesen, jede Datei als `{description, delivery, …}` ausgepackt. Test: `testBeispielsatzMindestanzahl`.
- **AC-2: Alle lesbaren Beispiele werden gelesen.** Jede Datei ohne reminder/challenge/tracker wird von `read` ohne Fehler gelesen; es gibt mindestens 32 solche Dateien. Test: `testAlleLesbarenBeispieleWerdenGelesen`.
- **AC-3: Nicht unterstützte Arten lehnen ab.** Jede Datei mit mindestens einer Position reminder/challenge/tracker, auch gemischte, liefert `KIND_NOT_SUPPORTED` mit nichtleerem deutschem Grund; es gibt mindestens 19 solche Dateien. Test: `testNichtUnterstuetzteArtenLehnenGanzeLieferungAb`.
- **AC-4: Je Art ein Beispiel.** Unter den gelesenen Dateien gibt es mindestens je ein Beispiel für `exercise`, `program`, `breath` und `withdrawal`, und das Modell liefert für jede dieser Arten den passenden Fall. Test: `testJedeArtMindestensEinmalGelesen`.
- **AC-5: Feldvergleich gegen Roh-JSON.** Für jede gelesene Datei stimmt gegen das Roh-JSON (`JSONSerialization`): Anzahl Positionen, je Position `itemId` und `revision` (bei Rücknahme `itemId`/`packageId`), `name`, bei Programmen `rounds` und Schrittzahl und je Schritt `exerciseId`, `workSeconds`, `restSeconds` und `hint` (auch dessen Fehlen), bei Atemübungen die vier Atemzeiten und `rounds`, sowie `package` (`packageId`, `name`) und `why`. Test: `testFelderStimmenMitRohJsonUeberein`.
- **AC-6: Datum mit Millisekunden.** `created-at-millis.json` liefert den Zeitpunkt auf die Millisekunde genau (der Wert aus dem Roh-JSON, mit `ISO8601DateFormatter` und Millisekunden unabhängig berechnet). Test: `testCreatedAtMitMillisekundenAufDieMillisekunde`.
- **AC-7: Datum ohne Millisekunden.** Mindestens eine Datei ohne Millisekunden (z. B. `package-mixed.json`, `2026-11-13T10:15:00Z`) liefert den richtigen Zeitpunkt. Test: `testCreatedAtOhneMillisekunden`.
- **AC-8: Kaputtes JSON.** Kein JSON (z. B. abgeschnittener Text, leere Daten) liefert `APP_CANNOT_READ` mit deutschem Grund. Test: `testKaputtesJsonIstAppCannotRead`.
- **AC-9: Fehlendes Pflichtfeld.** Wird aus einer gültigen Lieferung ein Pflichtfeld entfernt (Hülle: `deliveryId`; Position: `itemId` bzw. `rounds` beim Programm), liefert `read` `APP_CANNOT_READ`. Test: `testFehlendesPflichtfeldIstAppCannotRead`.
- **AC-10: Unbekannter Zusatzschlüssel.** Ein zusätzlicher unbekannter Schlüssel in Hülle, Position und Schritt ändert das Ergebnis nicht (gleiche Felder wie ohne). Test: `testUnbekannterZusatzschluesselWirdToleriert`.
- **AC-11: `invalid/` wird nicht ausgewertet.** Die Tests lesen nur `Contracts/deliveries/valid/`; es gibt keinen Prüf-Gleichlauf gegen die ungültigen Beispiele (das wäre ein zweiter Prüfer). Kein eigener Test: Nachweis in der Adversary-Prüfung per Durchsicht der Testdatei.
- **AC-12: Reine Foundation-Datei.** `ClaudeDelivery.swift` importiert nur `Foundation` (Watch- und Widget-Übersetzung bleiben unberührt). Test: `testModellImportiertNurFoundation` (liest die Quelldatei per `#filePath`-Pfad relativ zum Repo und prüft die `import`-Zeilen).
- **AC-13: Keine Seiteneffekte im Bestand.** Gespeicherte Listen, `WorkoutSet`, `WorkoutPhase`, `AtemView.Preset`, `ExerciseInfo`, UserDefaults und `project.pbxproj` bleiben unverändert; die bestehende Unit-Suite bleibt grün (263 Tests laufen weiter; neue Tests kommen hinzu). Nachweis: Diff der Runde enthält nur die zwei neuen Dateien und Specs/Docs; vollständiger Unit-Lauf mit `Executed N tests`, N ≥ 1.

AC-12 ist absichtlich eine einfache Codesuche, damit die Abgrenzung „nur Foundation“ nicht still verloren geht.

## Test Plan

- [ ] Unit Test: AC-1 bis AC-10 und AC-12 in `ClaudeDeliveryDecodingTests` (zuerst rot: `ClaudeDelivery` fehlt noch, der Übersetzungsfehler ist der RED-Beleg)
- [ ] Unit Test: vollständige Unit-Suite (`LeanHealthTimerTests`) bleibt grün (AC-13)
- [ ] UI Test: keiner. Die Runde ändert keine Oberfläche (reines Modell, für Henning unsichtbar); UI-Tests folgen mit Schnitt 3
- [ ] Nachweis App-Durchlauf: nicht anwendbar, da nichts in der App erreichbar ist; die App muss nur weiter bauen und starten (Build aller Ziele, die den Ordner `Models/` übersetzen: iOS, Watch, Widget)

## Definition of Done

- [ ] Build grün für iOS, Watch und Widget (alle Ziele, die `Models/` übersetzen)
- [ ] AC-1 bis AC-10 und AC-12 als Unit-Tests grün, im Protokoll `Executed N tests` mit N ≥ 1
- [ ] Vollständige Unit-Suite `LeanHealthTimerTests` grün (AC-13)
- [ ] AC-11 in der Adversary-Prüfung bestätigt, Verdict VERIFIED
- [ ] `openspec/specs/features/claude-annahme.md` auf Stand (Schnitt 1 erledigt, `itemId`)

## Alternativen

- **Felder schon jetzt an `WorkoutSet` und `Preset` (Wortlaut der übergeordneten Spec):** verworfen für Schnitt 1. Die Form hängt vom Speicherort ab, und unbenutzte Felder ändern die synthetisierte Gleichheit (`Hashable`) gespeicherter Listen. Das wäre ein Eingriff in gespeicherte Daten, bevor er gebraucht wird.
- **Direkt in App-Typen dekodieren statt eigener Wire-Typen:** verworfen. Der Schema-Schritt hat keinen Namen, Kategorien sind englisch statt der deutschen Rohwerte der App, und die Rücknahme hat keinen App-Typ.
- **Gekippt wird dadurch keine ADR;** abgewichen wird nur vom Zuschnitt in `claude-annahme.md` (Schnitt 1 = Modell-Felder), der dort in derselben Runde angepasst wird.

## Ausblick: offene Punkte für Schnitt 2 (nicht entschieden)

- Speicherort gelieferter Bausteine: bestehende Listen und Katalog (Wortlaut der übergeordneten Spec) oder eigener Speicher (frühere Analyse 5.1). Ein Vorschlag liegt vor (Hybrid: Programme und Atemübungen als Kopie in die bestehenden Listen, Übungen und Verwaltungsdaten in einer kleinen eigenen Datei), entschieden wird er in der Analyse von Schnitt 2.
- `atemPresets` hat keine Sicherung bei Lesefehler (Standardwerte überschreiben); Sicherung analog `workoutProgramSets` vor oder mit Schnitt 2.
- Zeitpunkt der letzten Abschrift existiert in der App noch nicht (#57/#59); für die Regel „das iPhone gewinnt“ braucht Schnitt 2 einen Platzhalter, ohne #57 vorwegzunehmen.

## Risiken

- Niedrig: neuer, isolierter Code; gespeicherte Daten werden nicht berührt.
- Der Beispielsatz wächst vermutlich mit späteren Arten (B4b bis B6b): Die Mindestanzahlen sind Untergrenzen; wird eine bisher nicht unterstützte Art später lesbar, ändert sich die Zählung der Dateien in AC-2/AC-3 und die Spec ist dann mit anzupassen.

## Changelog

- 2026-11-20: Initial spec created (Schnitt 1 von 3, #51)
- 2026-11-20: AC-11 ohne selbstbezüglichen Codesuche-Test (Adversary-Durchsicht), AC-3 als Untergrenze
