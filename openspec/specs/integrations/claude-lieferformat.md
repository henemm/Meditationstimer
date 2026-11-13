# Spec: Lieferformat für Claude-Lieferungen (B0)

**Issue:** #46 (Teil von Epic #44) · **Konzept:** `DOCS/konzept-claude-verbindung.md` Abschnitte 6.1–6.3, 6.7, 11
**Stand:** 13.11.2026 · **Status:** umgesetzt mit B0

## Zweck

Ein verbindliches Format, in dem Claude Übungen, Workout-Programme und Atemübungen an Healthy Habits liefert.
Der Dienst (B2a), die Brücke (B1b) und die App (B1a) prüfen jede Lieferung nach denselben Regeln. Damit die
Regeln nicht auseinanderlaufen, gibt es einen gemeinsamen Satz Beispiel-Lieferungen mit erwartetem Ergebnis,
den beide Seiten in ihren automatischen Tests gleich beurteilen müssen.

## Bestandteile im Repo

| Pfad | Inhalt |
|---|---|
| `Contracts/schema/delivery-v1.schema.json` | Formatbeschreibung als JSON Schema (Draft 2020-12). Deckt Form, Typen, Grenzen und Zeichenregeln ab. |
| `Contracts/catalog/builtin-exercises.json` | Feste Kennungen der 43 eingebauten Übungen (Kennung, deutscher Name, Kategorie). Wird von A2 als Quelle der Kennungen übernommen. |
| `Contracts/deliveries/valid/*.json` | Gültige Beispiel-Lieferungen |
| `Contracts/deliveries/invalid/*.json` | Ungültige Beispiel-Lieferungen, je **genau ein** Fehler |
| `Contracts/validator/` | Referenz-Prüfer in TypeScript (Node 22, ohne Laufzeit-Abhängigkeiten) mit Tests |

Was das Schema nicht ausdrücken kann (Bezüge, Dubletten, Kalenderdatum, Gesamtdauer), prüft nur der Prüfer.
Maßgeblich ist der Prüfer; das Schema ist die lesbare Beschreibung und lehnt nie etwas ab, das der Prüfer annimmt.

## 1. Umschlag (Lieferung)

| Feld | Pflicht | Regel |
|---|---|---|
| `format` | ja | Genau `"hhhaven.delivery/1"`. Anderer Text: `FORMAT_UNKNOWN`. |
| `deliveryId` | ja | Feste Lieferkennung, `^[A-Za-z0-9][A-Za-z0-9-]{7,63}$` (UUID passt). Zweimal dieselbe Lieferung anwenden ändert nichts (Regel für die App, siehe 6). |
| `source` | ja | Genau `"claude"`. Sonst `VALUE_NOT_ALLOWED`. |
| `createdAt` | ja | UTC-Zeitpunkt `JJJJ-MM-TTThh:mm:ssZ`, optional mit 1–3 Nachkommastellen der Sekunde (`…:ss.sssZ`). Muss ein echtes Kalenderdatum sein (kein 30.2.), Stunde 00–23, Minute und Sekunde 00–59. |
| `why` | ja | Warum, ein bis zwei Sätze. Einzeiliger Text, 1–300 Zeichen. |
| `package` | nein | Paket: Objekt `{ packageId, name }`. `packageId` wie eine Lieferkennung eines Bausteins (siehe 2), `name` einzeilig 1–40. Alle Bausteine dieser Lieferung gehören zum Paket. |
| `items` | ja | Liste mit 1–20 Einträgen (Bausteine und Rücknahmen). |

Weitere Felder sind nicht erlaubt (`FIELD_UNKNOWN`), auf jeder Ebene. Neue Felder kommen nur mit einer neuen Formatfassung.

## 2. Gemeinsame Felder eines Bausteins

| Feld | Regel |
|---|---|
| `kind` | `"exercise"`, `"program"`, `"breath"` oder `"withdrawal"`. Sonst `KIND_UNKNOWN`; der Eintrag wird dann nicht weiter geprüft. |
| `itemId` | Kennung des Bausteins, von Claude bzw. vom Dienst vergeben: `^claude\.[a-z0-9][a-z0-9-]{1,62}$`. Bleibt über Änderungen gleich. Innerhalb einer Lieferung eindeutig (auch über Rücknahmen hinweg), sonst `DUPLICATE_ID` am zweiten Vorkommen. |
| `revision` | Ganze Zahl 1–1 000 000. 1 = neu, höher = geänderte Fassung desselben Bausteins. (Nicht bei Rücknahmen.) |

## 3. Bausteine

### 3.1 Übung (`kind: "exercise"`)

| Feld | Pflicht | Regel |
|---|---|---|
| `name` | ja | einzeilig 1–40 |
| `nameEn` | nein | einzeilig 1–40 |
| `category` | ja | einer der neun Werte `strength`, `stretching`, `core`, `cardio`, `legs`, `upperBody`, `fullBody`, `warmup`, `cooldown` (wie die Fälle von `ExerciseCategory` in der App). Sonst `CATEGORY_UNKNOWN`. |
| `effect` | ja | Wirkung, mehrzeilig 1–600 |
| `instructions` | ja | Anleitung, mehrzeilig 1–1500 |
| `notes` | nein | Anmerkung, mehrzeilig 1–600 |

Eine neue Übung ohne Wirkung oder Anleitung ist ungültig (`FIELD_MISSING` bzw. `TEXT_EMPTY`), damit der Info-Knopf im Training nie leer ist.

**Keine Dublette:** Ist der normalisierte Name gleich dem Namen einer eingebauten Übung, einer **früheren** Übung derselben Lieferung
(nur das spätere Vorkommen wird gemeldet) oder einer bekannten Übung aus dem Prüfkontext (siehe 5) mit anderer Kennung, gilt `NAME_TAKEN`
am Feld `name`. Geprüft wird nur, wenn der Name für sich gültig ist.
Normalisieren: Leerzeichen (U+0020, U+00A0) am Rand entfernen, Folgen davon im Inneren zu einem U+0020 zusammenfassen, dann Kleinschreibung
(Unicode-Standardabbildung, `toLowerCase()` bzw. `lowercased()`).

### 3.2 Workout-Programm (`kind: "program"`)

| Feld | Pflicht | Regel |
|---|---|---|
| `name` | ja | einzeilig 1–40 |
| `symbol` | ja | Symbol (siehe 4) |
| `description` | nein | mehrzeilig 1–500 |
| `rounds` | ja | ganze Zahl 1–99 |
| `steps` | ja | Liste mit 1–40 Schritten |

Schritt:

| Feld | Pflicht | Regel |
|---|---|---|
| `exerciseId` | ja | Muster `^(builtin\|own\|claude)\.[a-z0-9][a-z0-9-]{1,62}$`, sonst `INVALID_ID`. Muss auf eine Übung zeigen, sonst `EXERCISE_UNKNOWN` (siehe unten). |
| `workSeconds` | ja | ganze Zahl 1–600 |
| `restSeconds` | ja | ganze Zahl 0–600 |
| `hint` | nein | Hinweis, wird angezeigt und angesagt: einzeilig 1–80 |

Bezug: `builtin.*` muss im Katalog stehen. `claude.*` und `own.*` müssen als Übung in derselben Lieferung stehen (`kind: "exercise"`)
oder im Prüfkontext bekannt sein. Ein Verweis auf ein Programm oder eine Atemübung ist `EXERCISE_UNKNOWN`.

Gesamtdauer `rounds × Σ(workSeconds + restSeconds)` höchstens 14 400 s (4 h), sonst `TOTAL_TOO_LONG` am Baustein.
Wird nur geprüft, wenn alle beteiligten Zahlen für sich gültig sind.

### 3.3 Atemübung (`kind: "breath"`)

| Feld | Pflicht | Regel |
|---|---|---|
| `name` | ja | einzeilig 1–40 |
| `symbol` | ja | Symbol (siehe 4) |
| `description` | nein | mehrzeilig 1–500 |
| `inhaleSeconds` | ja | ganze Zahl 1–60 |
| `holdInSeconds` | ja | ganze Zahl 0–60 |
| `exhaleSeconds` | ja | ganze Zahl 1–60 |
| `holdOutSeconds` | ja | ganze Zahl 0–60 |
| `rounds` | ja | ganze Zahl 1–99 |

Gesamtdauer `rounds × (Ein + Halten + Aus + Halten)` höchstens 3 600 s (1 h), sonst `TOTAL_TOO_LONG` am Baustein.
Ein- und Ausatmen sind strenger als der App-Editor (dort 0–60), weil 0 Sekunden Atmen keine Übung ergibt.

### 3.4 Rücknahme (`kind: "withdrawal"`)

Genau eines der Felder `itemId` (ein Baustein) oder `packageId` (ein ganzes Paket), beide im Muster aus 2. Beide oder keins:
`WITHDRAWAL_TARGET` am Eintrag. Keine weiteren Felder. Zurückgenommenes bleibt in der App wiederherstellbar (Konzept 9).

## 4. Text- und Zahlenregeln

- **Länge** = Anzahl Unicode-Skalarwerte (Code Points): TypeScript `[...s].length`, Swift `s.unicodeScalars.count`.
- **Verbotene Zeichen** in allen Texten: U+0000–U+001F (außer U+000A in mehrzeiligen Feldern), U+007F–U+009F, U+2028, U+2029,
  U+202A–U+202E, U+2066–U+2069. Sonst `TEXT_FORBIDDEN_CHAR`. Einzeilige Felder erlauben also keinen Zeilenumbruch.
- **Leer:** Besteht ein Text nur aus U+0020, U+00A0 und U+000A (oder ist er leer), gilt `TEXT_EMPTY`.
- Reihenfolge je Textfeld: verbotene Zeichen, dann leer, dann zu lang (`TEXT_TOO_LONG`). Es wird nur der erste zutreffende Fehler gemeldet.
- **Symbol:** 1–16 Code Points, keine verbotenen Zeichen, kein Leerzeichen (U+0020, U+00A0, U+000A), keine ASCII-Buchstaben oder -Ziffern.
  Sonst `INVALID_SYMBOL`.
- **Ganze Zahlen:** JSON-Zahl mit ganzzahligem Wert (`12` und `12.0` gelten gleich). `12.5`, Text oder Wahrheitswert: `FIELD_TYPE`.
  Hinweis für Swift: `JSONSerialization` liefert Wahrheitswerte als `NSNumber`; sie müssen als `FIELD_TYPE` erkannt werden.
- **Bereich** verlassen: `OUT_OF_RANGE`. Listenlänge außerhalb der Grenzen: `LIST_SIZE` an der Liste.
- **Kennungen und Lieferkennung** im falschen Muster: `INVALID_ID`. Zeitpunkt im falschen Muster oder kein echtes Datum: `INVALID_DATE`.

## 5. Prüfer

```ts
validateDelivery(input: unknown, context?: { knownExercises?: { id: string; name: string }[] }): {
  valid: boolean;               // true genau dann, wenn errors leer ist
  errors: { code: ErrorCode; path: string; message: string; hint: string }[];
}
```

- `input` ist der bereits geparste JSON-Wert. Der Katalog der eingebauten Übungen wird aus `Contracts/catalog/builtin-exercises.json` gelesen.
- `context.knownExercises`: Übungen, die außerhalb der Lieferung schon bekannt sind (eigene `own.*` und frühere Lieferungen `claude.*`), z. B. aus der Abschrift.
- `path` ist ein JSON Pointer (RFC 6901) auf die Fehlerstelle, z. B. `/items/0/steps/1/workSeconds`; die Wurzel ist `""`.
  Fehlendes Feld: Pfad des fehlenden Felds (`/why`). Unbekanntes Feld: Pfad dieses Felds.
- `message` nennt auf Deutsch, was falsch ist, `hint` den Ausweg (Konzept 4: „Ablehnungen nennen den Ausweg“). Beide nie leer.
- Fehlerort: Jeder Fehler an einem Feld hat den Pfad dieses Felds (z. B. `FORMAT_UNKNOWN` an `/format`, `INVALID_ID` an
  `/items/0/packageId`). Ausnahmen mit Pfad des Eintrags: `TOTAL_TOO_LONG`, `WITHDRAWAL_TARGET`. Je Feld höchstens ein Fehler.
  Vorrang je Feld: Typ, dann Muster bzw. Textregeln (4), dann Bereich, dann Bezug/Dublette. `WITHDRAWAL_TARGET` hindert nicht
  an der Prüfung der vorhandenen Felder `itemId`/`packageId`.
- `kind` ist kein Text: `FIELD_TYPE` an `/items/N/kind`; Text, aber unbekannt: `KIND_UNKNOWN`. In beiden Fällen nur dieser eine Fehler für den Eintrag.
- `package` ist kein Objekt: `FIELD_TYPE` an `/package`. Darin gelten `FIELD_MISSING` und `FIELD_UNKNOWN` wie überall.
- Textlänge wird am unveränderten Text gezählt (ohne Trimmen). Die Liste verbotener Zeichen in 4 ist abschließend.
- `NAME_TAKEN` gilt nur für Übungen; Programme und Atemübungen dürfen heißen wie eine Übung.
- Der Prüfer meldet **alle** Fehler, aber keine Folgefehler:
  - Wurzel kein Objekt: nur `FIELD_TYPE` an `""`.
  - Feld mit falschem Typ: nur `FIELD_TYPE` an diesem Feld, sein Inhalt wird nicht weiter geprüft.
  - Eintrag mit unbekanntem `kind` oder ohne `kind`: nur dieser eine Fehler für den Eintrag.
  - Eine Übung derselben Lieferung zählt für Bezüge auch dann, wenn sie selbst Fehler hat.
  - Fehlt `format` oder ist es unbekannt, werden die übrigen Felder trotzdem geprüft.
  - `DUPLICATE_ID` und Bezüge berücksichtigen nur Kennungen, die selbst dem Muster entsprechen.
  - Bei falscher Listenlänge (`LIST_SIZE`) werden die vorhandenen Einträge trotzdem einzeln geprüft.
  - `TOTAL_TOO_LONG` wird nur geprüft, wenn `rounds` und alle Zeiten des Bausteins für sich gültig sind (bei Programmen auch die Schrittzahl).
- Codes (vollständige Liste): `FORMAT_UNKNOWN`, `FIELD_MISSING`, `FIELD_UNKNOWN`, `FIELD_TYPE`, `TEXT_EMPTY`, `TEXT_TOO_LONG`,
  `TEXT_FORBIDDEN_CHAR`, `INVALID_SYMBOL`, `OUT_OF_RANGE`, `LIST_SIZE`, `TOTAL_TOO_LONG`, `INVALID_ID`, `INVALID_DATE`,
  `VALUE_NOT_ALLOWED`, `KIND_UNKNOWN`, `CATEGORY_UNKNOWN`, `EXERCISE_UNKNOWN`, `NAME_TAKEN`, `DUPLICATE_ID`, `WITHDRAWAL_TARGET`.

## 6. Beispielsatz

Jede Datei unter `Contracts/deliveries/` hat diese Form:

```json
{
  "description": "Was das Beispiel zeigt",
  "context": { "knownExercises": [ { "id": "own.…", "name": "…" } ] },
  "delivery": { "…": "die Lieferung" },
  "expected": { "valid": true }
}
```

Bei ungültigen Beispielen:

```json
"expected": {
  "valid": false,
  "errors": [ { "code": "OUT_OF_RANGE", "path": "/items/0/steps/0/workSeconds" } ],
  "reason": "Ablehnungsgrund in Alltagssprache",
  "remedy": "Ausweg",
  "schemaRejects": true
}
```

- `context` ist optional. `errors` ist die erwartete **Menge** von (code, path); die Reihenfolge zählt nicht.
- `schemaRejects` sagt, ob schon das JSON Schema die Lieferung ablehnt (sonst nur der Prüfer).
- Beide Seiten (Prüfer hier, App in B1a) müssen jede Datei genau so beurteilen: gleiches `valid`, gleiche Menge (code, path).
- Ein gültiges Beispiel muss auch das Schema bestehen.

## 7. Regeln für die Anwendung in der App (Vorgabe für B1a, hier nur festgehalten)

- Eine `deliveryId`, die schon verarbeitet wurde, wird nicht erneut angewendet; das Ergebnis der ersten Verarbeitung gilt.
- Ein Baustein mit `revision` ≤ der gespeicherten Fassung ändert nichts.
- Hat Henning einen gelieferten Baustein bearbeitet („angepasst“), wird eine höhere Fassung abgelehnt statt überschrieben.
- Eine Lieferung wird ganz oder gar nicht angewendet.

## 8. Akzeptanzkriterien (B0)

1. Schema, Katalog, Beispielsatz und Prüfer liegen im Repo.
2. Für jede Beispieldatei liefert der Prüfer genau das erwartete Ergebnis; jedes gültige Beispiel besteht das Schema; jedes Beispiel mit
   `schemaRejects: true` scheitert am Schema, jedes mit `false` besteht es.
3. Jede Fehlermeldung des Prüfers hat nicht leere `message` und `hint`.
4. Der Beispielsatz deckt jeden Fehlercode aus 5 mindestens einmal ab und jede Zahlengrenze an beiden Rändern (gültig und ungültig).
5. Die Tests laufen automatisch in der CI.
