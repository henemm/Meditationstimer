# Spec: Dienst für die Claude-Verbindung (B2a)

**Issue:** #54 (Teil von Epic #44) · **Konzept:** `DOCS/konzept-claude-verbindung.md` Abschnitte 4, 7, 10, 11
**Vertrag:** Lieferformat `openspec/specs/integrations/claude-lieferformat.md` (B0)
**Stand:** 13.11.2026

## 1. Entscheidung: Übernehmen statt Teilen

Der Dienst ist ein eigenes Programm unter `server/` in diesem Repo, gleich gebaut wie der Dienst von Loose Ends
(`henemm/loose-ends`, Ordner `server/`, Stand `24a6da6`): Node 26 mit Type Stripping (kein Build-Schritt), TypeScript-Prüfung,
Postgres, MCP über Streamable HTTP ohne Sitzungszustand (`@modelcontextprotocol/server`), Tests mit `node:test` gegen echtes Postgres.

Die generischen Bausteine werden **als Kopie übernommen**, nicht als gemeinsames Paket geteilt:

- Beide Dienste laufen getrennt (eigene Adresse, eigene Datenbank) und werden einzeln ausgerollt. Ein gemeinsames Paket würde jede
  Änderung an beide koppeln und bräuchte eine eigene Veröffentlichung, für etwa 1 500 Zeilen stabilen Code.
- Jede übernommene Datei nennt in der ersten Zeile ihre Herkunft (`Übernommen aus loose-ends server/src/<datei> @ 24a6da6`)
  und, falls angepasst, was geändert wurde. So bleiben spätere Fixes in Loose Ends nachziehbar.
- Was gekippt wird: Ein Fix in Loose Ends kommt nicht automatisch hierher. Ausgleich: Die Herkunftszeile macht das Nachziehen
  zu einem gezielten Vergleich.

Übernommen werden (B2a): `migrate.ts`, `health.ts`, das Gerüst von `main.ts` (`bridge`, Routentabelle, Start/Stopp, Log-Format),
`test/db.ts`, `scripts/test-local.sh` (Linux- und Homebrew-Pfad), CI-Aufbau (`server.yml`), `Dockerfile`.
Anmeldung (Konten, Apple, OAuth, Tür) übernimmt B2b (#55).

## 2. Schnitte

| Schnitt | Inhalt | Fertig, wenn |
|---|---|---|
| **B2a-1 Gerüst** | `server/` mit `package.json` (gleiche gepinnte Versionen wie Loose Ends), `main.ts` mit `/health`, Migrationen, `Dockerfile`, `scripts/test-local.sh`, CI `server.yml` (Typprüfung + Tests gegen Postgres 18, Image-Start mit `/health`) | `/health` antwortet 200 nach der Migration, 503 davor; Image startet, migriert, endet sauber auf SIGTERM |
| **B2a-2 Abschrift** | Vertrag der Abschrift (Abschnitt 4) als Schema + Beispiele unter `Contracts/transcript/`; Tabellen; Ablegen/Lesen mit Datenschutzgrenze | Beispiele werden wie erwartet angenommen/abgelehnt; Felder außerhalb der Liste kommen nicht in die Datenbank |
| **B2a-3 Warteschlange und App-Schnittstelle** | Tabellen für Lieferungen und Verlauf; Abholen, Ergebnis melden, Abschrift hochladen (Abschnitt 5) | Zweimal Abholen liefert nicht zweimal dieselbe Lieferung an zwei Geräte; Ergebnis nur vom abholenden Gerät |
| **B2a-4 Lesewerkzeuge** | `overview`, `catalog`, `show`, `forms`, `delivery_status`, Server-Anweisung (Abschnitt 6) | Werkzeuge über einen echten MCP-Client getestet |
| **B2a-5 Lieferwerkzeuge** | `exercise_define`, `program_create`, `breath_create`, `item_update`, `item_withdraw`, `wish_report` (Abschnitt 6) | Jede Lieferung läuft durch den Prüfer aus B0; der gemeinsame Beispielsatz wird gleich beurteilt |

Jeder Schnitt ist ein eigener Beitrag mit Tests (zuerst rot, dann grün).

## 3. Konto in B2a

Bis B2b gibt es keine Anmeldung. Konto-Kennung ist ein Text (`account_id`), wie bei Loose Ends.
- MCP: Das Konto kommt nur aus `authInfo.extra.account`. Ohne Konto lehnt jedes Werkzeug mit „kein Konto“ ab.
- App-Schnittstelle: Das Konto liefert eine eingereichte Funktion `appAccount(req) → Promise<string | undefined>`.
- Im Betrieb (ohne B2b) weisen beide Türen alles ab (`rejectAll`), Tests reichen ein Testkonto ein.

## 4. Abschrift, Fassung 1

Die App schickt nach jedem Abgleich eine Abschrift. Der Dienst rechnet nichts nach und hält je Konto nur die neueste.

```json
{
  "version": 1,
  "generatedAt": "2026-11-13T10:00:00Z",
  "exercises": [ { "id": "builtin.planke", "name": "Planke", "category": "core", "origin": "builtin" } ],
  "programs": [ { "id": "claude.ruecken-a", "name": "Rücken A", "symbol": "🧘", "rounds": 2,
                  "steps": [ { "exerciseId": "builtin.planke", "workSeconds": 30, "restSeconds": 15, "hint": "ruhig" } ],
                  "origin": "claude", "revision": 1, "state": "active", "packageId": "claude.ruecken-november" } ],
  "breaths": [ { "id": "own.…", "name": "Box", "symbol": "🌬️", "inhaleSeconds": 4, "holdInSeconds": 4,
                 "exhaleSeconds": 4, "holdOutSeconds": 4, "rounds": 10, "origin": "own" } ],
  "deliveries": [ { "deliveryId": "…", "outcome": "accepted" } ]
}
```

- `origin`: `builtin` (mitgeliefert), `own` (Henning), `claude`. Kennungen wie im Lieferformat (`builtin.*`, `own.*`, `claude.*`).
- Nur bei `origin: "claude"`: `revision`, `state` (`active`, `adapted` = von Henning bearbeitet, `withdrawn` = zurückgenommen),
  optional `packageId`, `packageName`, `why`, `deliveredAt`.
- Übung: `id`, `name`, `nameEn?`, `category`, `origin` und nur bei Claude-Übungen zusätzlich `effect`, `instructions`, `notes?`
  (eingebaute und eigene Übungen ohne Texte: die liest Claude nicht, und die eingebauten stehen im Katalog).
- Programm und Atemübung: Felder wie im Lieferformat (ohne `kind`), plus `origin` und die Claude-Felder.
- `deliveries`: die zuletzt angewendeten Lieferungen mit Ergebnis (höchstens 50).
- Ablage nur, wenn `generatedAt` neuer ist als die gespeicherte; ältere oder gleich alte bleiben ohne Wirkung (204).
- **Datenschutzgrenze:** Kein Feld außerhalb dieser Liste, auf keiner Ebene. Keine Tracker, keine Einträge, keine Notizen,
  nichts aus Apple Health (Konzept 7). Der Verlauf (Einheiten, Serien) kommt erst mit B3a als Fassung 2.
- Grenzen: höchstens 500 Übungen, 200 Programme, 200 Atemübungen; Texte wie im Lieferformat; Körper höchstens 256 KiB.
- **Vertrag:** `Contracts/transcript/transcript-v1.schema.json` (JSON Schema) mit Beispielen `Contracts/transcript/{valid,invalid}/*.json`
  (`expected.accepted`, bei ungültigen `schemaRejects`). Der Dienst prüft mit dem Schema (Ajv als Laufzeit-Abhängigkeit, eine einzige
  Quelle der Regeln) und zusätzlich: Kennungen je Liste eindeutig. Die App (B2d) erzeugt nur Abschriften, die diese Beispiele bestehen.
- **Tabelle:** `transcripts(account_id text PRIMARY KEY, doc jsonb, generated_at timestamptz, received_at timestamptz DEFAULT now())`,
  `generated_at` per CHECK an `doc->>'generatedAt'` gebunden; zweite Datenschutzwand: CHECK, dass `doc` auf oberster Ebene nur
  `version`, `generatedAt`, `exercises`, `programs`, `breaths`, `deliveries` trägt. `getTranscript` gibt das Dokument unverändert zurück.
  Reihenfolge in `putTranscript`: erst Form (`invalid`), dann Alter (`stale`), dann Ablage (`stored`).

## 5. Lieferungen und App-Schnittstelle

Eine Lieferung ist genau ein Dokument im Lieferformat (B0). Zustände: `waiting` (wartet beim Dienst), `claimed` (ein Gerät hat sie
abgeholt), `accepted`, `rejected` (mit Fehlern der App), `superseded` (vor dem Abholen durch eine Rücknahme überholt; nur intern,
nach außen als `withdrawn`). Jeder Zustandswechsel steht im Verlauf (`delivery_events`: Zeitpunkt, Zustand, Gerät).

| Endpunkt | Körper | Antwort |
|---|---|---|
| `POST /app/transcript` | Abschrift | 204; 400 bei falscher Form (ohne Ablage) |
| `POST /app/deliveries/claim`, Kopf `X-Device: <UUID>` | – | 200 mit der ältesten wartenden Lieferung (`{deliveryId, delivery}`) oder 204. Eine abgeholte, aber nach 10 min nicht beantwortete Lieferung wird wieder abholbar. |
| `POST /app/deliveries/result`, Kopf `X-Device` | `{deliveryId, outcome: "accepted"\|"rejected", errors?: [{code, path, message}]}` | 204; 409, wenn dieses Gerät die Lieferung nicht hält; ein zweites Ergebnis zur selben Lieferung: 409 |

Prüfreihenfolge wie bei Loose Ends: 405 → 401 → 400 (Gerät) → 415 → 413 → 400 (Form).

Umsetzung (B2a-3):
- Tabellen: `deliveries(id text PRIMARY KEY = deliveryId, account_id text, doc jsonb, state text CHECK in (waiting, claimed, accepted,
  rejected, superseded), created_at, claimed_by text, claimed_at, result jsonb, decided_at)` mit CHECK „claimed_by und claimed_at
  beide oder keins“, `doc->>'deliveryId' = id`; `delivery_events(delivery_id → deliveries, at, state, device)`.
- `server/src/deliveries.ts`: `putDelivery(pool, account, doc)` (Zustand `waiting`, Ereignis), `claimDelivery(pool, account, device)`
  (älteste wartende oder seit über 10 min abgeholte, `FOR UPDATE SKIP LOCKED`; Ergebnis `{deliveryId, delivery}` oder `undefined`),
  `reportResult(pool, account, device, {deliveryId, outcome, errors?})` → `"ok"` oder `"conflict"`, `supersede(pool, account,
  deliveryId)` → `true` nur aus `waiting`, `listDeliveries(pool, account, {deliveryId?, limit?})` → Zustand, Zeitpunkte, Fehler, Dokument,
  neueste zuerst. `reportResult` für eine unbekannte, fremde oder nicht abgeholte Lieferung: `"conflict"` (Route: 409).
  Ohne `limit` höchstens 50. Alle drei Endpunkte verlangen `Content-Type: application/json` (bei `claim` ist der Körper leer oder `{}`).
  Ergebnis-Körper: nur `deliveryId` (UUID), `outcome`, `errors`; je Fehler `code` 1–100, `path` 0–300, `message` 1–300 Zeichen.
  Jede Funktion arbeitet nur im eigenen Konto.
- Ergebnis-Körper: `outcome` `accepted`/`rejected`; `errors` nur bei `rejected`, Liste mit 1–100 Einträgen `{code, path, message}`
  (Texte, `message` 1–300 Zeichen); sonst 400.
- `server/src/app-routes.ts`: `appRoutes({pool, appAccount})` → Routen für die drei Endpunkte; `X-Device` muss eine UUID sein.
  Körpergrenze 256 KiB. Die Abschrift läuft über `putTranscript` (`invalid` → 400, `stale`/`stored` → 204).

## 6. Werkzeuge für Claude

Englische Namen, deutsche Beschreibungen. Jede Antwort ist JSON-Text; Ablehnungen sind `isError` mit Grund und Ausweg.
Vor jeder Ablehnung wird nichts gespeichert.

| Werkzeug | Eingabe | Ergebnis |
|---|---|---|
| `overview` | – | Meldungen zuerst (abgelehnte Lieferungen der letzten 14 Tage, wartende Lieferungen älter als 24 h, Abschrift älter als 7 Tage oder fehlend), dann Bestand in Zahlen je Art und Herkunft, `generatedAt` und Alter der Abschrift |
| `catalog` | `kind` (`exercise`/`program`/`breath`), `query?`, `origin?` | Liste: `id`, `name`, Herkunft, bei Übungen Kategorie, bei Programmen Dauer und Schrittzahl. Eingebaute Übungen stammen aus dem Katalog (auch ohne Abschrift). Suche ohne Groß-/Kleinschreibung und Akzente, alle Wörter müssen vorkommen. |
| `show` | `id` | Ein Baustein vollständig, mit Herkunft, Stand und offenen Lieferungen dazu |
| `forms` | `kind?` | Bauplan: Felder, Grenzen, erlaubte Werte (aus dem Lieferformat), Kategorien mit deutschem Namen |
| `delivery_status` | `deliveryId?` | Eine oder die letzten 20 Lieferungen: Zustand (`waiting`, `in_app` = abgeholt, `accepted`, `rejected` mit Gründen, `withdrawn`), Zeitpunkte, Inhalt kurz (Art und Name) |
| `exercise_define` | Felder der Übung, `why`, `package?` | `{deliveryId, itemId, state: "waiting"}` |
| `program_create` | Felder des Programms, `why`, `package?` | dito |
| `breath_create` | Felder der Atemübung, `why`, `package?` | dito |
| `item_update` | `itemId`, `basedOnRevision`, vollständige neue Fassung, `why` | dito mit `revision` |
| `item_withdraw` | `itemId` oder `package`, `why` | `{deliveryId, state: "waiting"}` |
| `wish_report` | `text` (1–1000), `context?` (1–300) | `{wishId}` |

Antworten der Lesewerkzeuge (B2a-4), jeweils JSON-Text:
- `overview`: `{ messages: [{kind, text, deliveryId?}], counts: {exercise|program|breath: {builtin, own, claude}}, waiting,
  generatedAt?, transcriptAgeHours? }`. `kind` ist `rejected`, `waiting_long`, `transcript_old` oder `no_transcript`; Reihenfolge:
  abgelehnte, lange wartende, Abschrift. Ohne Abschrift zählen eingebaute Übungen aus dem Katalog, alles andere 0.
- `catalog`: `{ kind, count, items }`; Übung `{id, name, origin, category}`, Programm `{id, name, origin, steps, durationSeconds}`,
  Atemübung `{id, name, origin, durationSeconds}`. Höchstens 100 Einträge, nach Name sortiert. Ohne Abschrift: eingebaute Übungen aus
  dem Katalog, Programme und Atemübungen leer, dazu `note: "noch keine Abschrift"`.
- `show`: `{ kind, item, pending: [{deliveryId, state}] }`; `item` vollständig wie in der Abschrift (eingebaute Übungen ohne Abschrift
  aus dem Katalog). Unbekannt: Ablehnung „Nicht gefunden; Kennungen liefert catalog“.
- `forms`: je Art die Felder mit Pflicht, Typ, Grenzen und erlaubten Werten, abgeleitet aus `Contracts/schema/delivery-v1.schema.json`;
  Kategorien mit deutschem Namen (Kraft, Dehnung, Core, Cardio, Beine, Oberkörper, Ganzkörper, Aufwärmen, Cool-Down).
- `delivery_status`: `{ deliveries: [{deliveryId, state, createdAt, decidedAt?, errors?, items: [{kind, name?, itemId?, packageId?}]}] }`,
  neueste zuerst, höchstens 20; `state` nach außen `waiting`, `in_app` (abgeholt), `accepted`, `rejected`, `withdrawn` (= superseded).
  Unbekannte `deliveryId`: Ablehnung.
- Ohne Konto (`authInfo.extra.account` fehlt): jedes Werkzeug `isError` „kein Konto“. Schnittstelle: `mcpHandler(pool)` wie in Loose Ends.
- Festlegungen: Dauer einer Atemübung `rounds × (Ein + Halten + Aus + Halten)`. Mit Abschrift stammen alle Übungen (auch eingebaute) aus
  der Abschrift. `count` = Zahl aller Treffer vor der Kürzung auf 100. Sortierung `Intl.Collator("de", {sensitivity: "base"})`.
  `waiting` in `overview` = Lieferungen in `waiting` oder `claimed`. `waiting_long` (nur Zustand `waiting`, älter als 24 h) und
  `rejected` tragen `deliveryId`. Suche faltet zusätzlich ß zu ss.
  `show.pending` listet Lieferungen in `waiting` oder `in_app`, die den Baustein enthalten oder zurücknehmen.

Regeln der Lieferwerkzeuge:
- Der Dienst vergibt `deliveryId` (UUID), `itemId` (`claude.` + Name in Kleinbuchstaben a–z/0–9/-, Umlaute umschrieben, gekürzt,
  plus `-` und 6 Zeichen Zufall) und `createdAt`; `source` ist `claude`. Ein Paket wird über seinen Namen angegeben; gleicher Name
  (normalisiert wie bei Übungsnamen) ergibt dieselbe `packageId`.
- Jede Lieferung geht vor dem Speichern durch `validateDelivery` (B0). Prüfkontext `knownExercises`: Übungen der Abschrift
  (ohne `builtin`) und Übungen aus Lieferungen im Zustand `waiting`/`claimed`/`accepted`, die noch nicht in der Abschrift stehen.
- `item_update`: nur `claude.*`-Bausteine, die Claude geliefert hat. Abgelehnt, wenn `basedOnRevision` nicht der höchsten bekannten
  Fassung entspricht („Stand hat sich geändert, bitte neu lesen“), wenn der Baustein in der Abschrift `adapted` ist („Henning hat ihn
  angepasst; biete eine Kopie an“) oder `withdrawn`. Neue `revision` = höchste bekannte + 1.
- `item_withdraw`: nur eigene Lieferungen. Wartet die Lieferung des Bausteins noch (`waiting`), wird sie `superseded` und keine
  Rücknahme verschickt.
- `own.*` und `builtin.*` lassen sich weder ändern noch zurückziehen (Grundregel 7).

Umsetzung der Lieferwerkzeuge (B2a-5):
- Eingaben: `exercise_define {name, nameEn?, category, effect, instructions, notes?, why, package?}`, `program_create {name, symbol,
  description?, rounds, steps: [{exerciseId, workSeconds, restSeconds, hint?}], why, package?}`, `breath_create {name, symbol,
  description?, inhaleSeconds, holdInSeconds, exhaleSeconds, holdOutSeconds, rounds, why, package?}`, `item_update {itemId,
  basedOnRevision, why, fields}` (`fields` = vollständige neue Fassung wie bei der jeweiligen Erstellung, ohne `why`/`package`; das Paket
  bleibt), `item_withdraw {itemId? | package?, why}` (genau eins), `wish_report {text, context?}`. Die MCP-Eingabeschemas sind locker
  (Typen), die eigentliche Prüfung macht `validateDelivery`, damit Claude dieselben Gründe und Auswege bekommt wie die App.
- Jeder Aufruf erzeugt höchstens **eine** Lieferung mit genau einem Eintrag. Antwort: `{deliveryId, itemId, revision, state: "waiting"}`
  bzw. bei Rücknahme `{deliveryId?, state, superseded: [deliveryId…]}`. Ablehnung (`isError`): je Fehler eine Zeile
  „`path`: message Ausweg: hint“; nichts wird gespeichert.
- `itemId` = `claude.` + Name (Kleinbuchstaben, ä→ae, ö→oe, ü→ue, ß→ss, sonst nicht a–z/0–9 → `-`, Folgen zusammengefasst, Rand-`-`
  weg, höchstens 40 Zeichen) + `-` + 6 Zufallszeichen a–z0–9. `packageId` = `claude.` + Paketname nach derselben Regel ohne Zufall.
- Bekannte Fassung eines Bausteins = höchste `revision` aus Abschrift und Lieferungen in `waiting`/`claimed`/`accepted`. Eigentum: der
  Baustein steht mit `origin: "claude"` in der Abschrift oder in einer Lieferung dieses Kontos; sonst „Nur eigene Lieferungen“.
- `item_withdraw`: Alle wartenden Lieferungen, die den Baustein bzw. das Paket enthalten, werden `superseded`. Eine Rücknahme-Lieferung
  entsteht nur, wenn etwas davon schon in der App ist (Abschrift, oder Lieferung `claimed`/`accepted`). Ein schon zurückgenommener
  Baustein (Abschrift `withdrawn`) wird abgelehnt.
- `wish_report`: Tabelle `wishes(id uuid, account_id, created_at, text, context)`; Antwort `{wishId}`.
- Prüfer-Gleichlauf: Für jede Datei in `Contracts/deliveries/` ergibt das Einreichen ihres Inhalts über das passende Werkzeug dieselbe
  Annahme bzw. Ablehnung wie der Prüfer, soweit sie über ein Werkzeug ausdrückbar ist (Umschlagfelder vergibt der Dienst).

**Server-Anweisung** (`instructions` des MCP-Servers): die elf Grundregeln aus Konzept Abschnitt 10, wörtlich, dazu: „Lieferungen
erscheinen beim nächsten Öffnen von Healthy Habits“ und „Trainings sind Vorschläge von Claude und kein medizinischer Rat“.

## 7. Nicht in B2a

Anmeldung und Tür (B2b), Bereitstellung (B2c), Verlauf/`history` (B3a), Erinnerungen, Challenges, Tracker (B4a–B6a).
