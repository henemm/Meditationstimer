# Spec: Stufenplan, Tagesziel und neue Gewohnheit von Claude (B6a)

**Issue:** #64 (Teil von Epic #44) · **Konzept:** `DOCS/konzept-claude-verbindung.md` Abschnitte 2 (Nachtrag 13.11.: höchstens zwei neue
Gewohnheiten gleichzeitig), 6.4, 6.5, 7, 9.1, 16 (Annahme 2: bei vorhandenen Trackern nur die Summe)
**Baut auf:** B5a (`claude-challenge.md`) · **App-Seite:** B6b (#65) · **Stand:** 13.11.2026

## 1. Neue Art `tracker` (Gewohnheit)

Möglichkeiten wie im Bildschirm „Eigener Tracker“ (`Meditationstimer iOS/Tracker/CustomTrackerSheet.swift`), ohne Kopplung an
Apple Health (kein Feld dafür). Vorhandene Tracker (eingebaut oder eigene) ändert Claude nie (`item_update` nur für `claude.*`).

| Feld | Pflicht | Regel |
|---|---|---|
| `kind`, `itemId`, `revision` | ja | wie bei allen Bausteinen |
| `name` | ja | einzeilig 1–40 |
| `symbol` | ja | Symbol wie bei Programmen |
| `type` | ja | `good` oder `saboteur` |
| `mode` | ja | bei `good`: `counter`, `yesNo`, `levels`; bei `saboteur`: `awareness`, `avoidance`, `levels`; sonst `VALUE_NOT_ALLOWED` |
| `dailyGoal` | nein | nur bei `counter`: ganze Zahl 1–100 |
| `levels` | bei `levels` ja, sonst verboten | Liste 2–5 Stufen `{name (einzeilig 1–20), icon (Symbol), effect: success|needsGrace|breaksStreak}`; Namen normalisiert eindeutig (`DUPLICATE_VALUE`); mindestens eine mit `success`, sonst `LEVELS_NO_SUCCESS` an der Liste |
| `joker` | nein, nur bei `levels` | `{earnEveryDays 1–30, maxOnHand 1–10}` |
| `dayStartHour` | nein, nur bei `levels` | ganze Zahl 0–23 (Tageswechsel, wie „Tag beginnt um“) |

Ein Feld, das zum `mode` nicht passt (z. B. `dailyGoal` bei `yesNo`), ist `FIELD_UNKNOWN` an diesem Feld. Gilt `mode` selbst als
ungültig, werden die modusabhängigen Felder nicht weiter geprüft (keine Folgefehler).

## 2. Challenge mit Stufen und Tagesziel

Erweiterung der Art `challenge` aus B5a:
- `stages`: 1–6 Stufen (bisher genau 1); Summe der `days` höchstens 90 (`TOTAL_TOO_LONG`).
- `content` einer Stufe ist entweder `{type: "impulses", impulses}` (wie B5a) oder `{type: "goal", goal}`:

| `goal.type` | weitere Felder | Tag gilt als erreicht, wenn … (App, B6b) |
|---|---|---|
| `meditation` | `minutes` 1–180 | an diesem Tag mindestens so viele Minuten Meditation |
| `workout` | `minutes` 1–180 | an diesem Tag mindestens so viele Minuten Workout |
| `tracker` | `trackerId` (`builtin|own|claude.*`) | der Tag beim Tracker nach dessen eigenen Regeln „gelungen“ ist |

`trackerId` muss auf einen Tracker zeigen: in derselben Lieferung (`kind: "tracker"`) oder im Prüfkontext `knownTrackers: string[]`;
sonst `TARGET_UNKNOWN`. Der eingebaute NoAlc-Tracker heißt `builtin.noalc`.

Neuer Fehlercode: `LEVELS_NO_SUCCESS`. Beispielsatz: `Contracts/deliveries/**/tracker-*.json`, `challenge-stages-*.json`.

## 3. Abschrift

Fassung 2 erhält optional:
- `trackers` (höchstens 50): alle Tracker als **Bausteine**: `id`, `name`, `symbol`, `type`, `mode`, `dailyGoal?`, `levels?` (wie oben),
  `origin` (`builtin`, `own`, `claude`) und bei `claude` die Claude-Felder. **Keine Einträge, keine Notizen, keine Werte, keine Serien
  einzelner Tracker** (Konzept 7).
- Challenges mit Ziel-Stufen: `progress.goals` (Liste, je Ziel-Stufe höchstens ein Eintrag) `{stage (0-basiert), met, of}` mit
  `0 ≤ met ≤ of ≤ days der Stufe` — nur die Summe, auch bei NoAlc (Annahme 2). `progress.days` enthält nur noch Tage aus
  Impuls-Stufen (lückenlos je Stufe ab deren erstem Tag bis heute bzw. Stufenende).
- Die Datenbank-Wand erlaubt `trackers` als obersten Schlüssel nur in Fassung 2.

## 4. Dienst

- Werkzeug `tracker_create {name, symbol, type, mode, dailyGoal?, levels?, joker?, dayStartHour?, why, package?}`; `challenge_create`
  nimmt mehrere Stufen und Ziel-Stufen; Prüfkontext `knownTrackers` aus Abschrift und Lieferungen.
- Lesewerkzeuge kennen `tracker` (catalog-Zeile `{id, name, origin, type, mode}`, show, forms, `counts.tracker`). `history.challenges`
  gibt zusätzlich `goals` aus (wie in der Abschrift).
- **Im Aufbau** (PO-Entscheidung 13.11.): `overview.building = {count, limit: 2, items: [{id, name, kind, since}]}` — Claude-Tracker mit
  `state: "active"`, deren `deliveredAt` höchstens 66 Tage zurückliegt, und aktive Claude-Challenges mit mindestens einer Ziel-Stufe, die
  noch nicht beendet sind. Ab `count ≥ 2` steht in `overview.messages` `building_limit` (Hinweis, keine Sperre).
- Der Dienst sperrt nicht: Henning darf ausdrücklich mehr wollen. Die Grundregel steht in der Server-Anweisung:
  „Stoße von dir aus höchstens zwei neue Gewohnheiten oder Stufenpläne gleichzeitig an (overview.building). Wünscht Henning ausdrücklich
  mehr, weise einmal darauf hin und folge dann seinem Wunsch. Beobachtende Gewohnheiten zählen nicht mit.“

Festlegungen: `builtin.noalc` ist bekannt, wenn er in der Abschrift unter `trackers` steht (die App schickt ihn immer mit).
`building.items[].kind` ist `tracker` oder `challenge`; `since` ist bei Trackern `deliveredAt` (noch nicht in der Abschrift: `createdAt`
der Lieferung), bei Challenges `startDate`. Eine Challenge ist beendet, wenn ihr letzter Tag (`startDate + Summe(days) + extendedBy − 1`)
vor dem UTC-Tag von `generatedAt` liegt. `progress.days` darf bei reinen Ziel-Challenges leer sein. `history.challenges[].goals` erscheint
nur bei Challenges mit Ziel-Stufe. `forms` nennt alle Grenzen auch verschachtelter Felder (z. B. 300 für Impuls-Text).
`building` zählt auch Claude-Tracker und Ziel-Challenges aus offenen Lieferungen (`waiting`/`claimed`), die noch nicht in der Abschrift
stehen und nicht zurückgezogen sind. Die 66 Tage beim Tracker zählen ab Serverzeit; ein Claude-Tracker ohne `deliveredAt` gilt als im Aufbau.

Nachträge nach der Adversary-Prüfung:
- **Laufende Challenge ändern:** `item_update` einer Challenge, deren `startDate` unverändert bleibt, wird nicht wegen `START_IN_PAST`
  abgelehnt. Umsetzung: Prüfkontext `keepStartDate?: string` — ist `startDate` gleich diesem Wert, entfällt die Prüfung „frühestens
  Vortag“ (die Obergrenze +30 Tage bleibt). Der Dienst setzt `keepStartDate` bei `item_update` auf das `startDate` der höchsten bekannten Fassung.
- **Beobachtende Gewohnheiten:** In `overview.building` zählen Claude-Tracker mit `mode: "awareness"` nicht mit (Wahrnehmen ist Beobachten,
  nicht Aufbauen; Konzept 9.1). Alle anderen Modi zählen.

## 5. Fertig, wenn

Prüfer und Dienst beurteilen den erweiterten Beispielsatz gleich; Abschrift-Beispiele mit Trackern und Ziel-Stufen (gültig; ungültig:
Einträge/Notizen/Werte an Trackern, `met > of`, Ziel-Stufe mit Tagesliste); Dienst-Tests für `tracker_create`, Stufen-Challenges,
`overview.building`, `history.challenges.goals`; alle Tests grün.
