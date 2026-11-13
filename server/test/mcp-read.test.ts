// B2a-4 Lesewerkzeuge (Issue #54): TDD RED. Spec: openspec/specs/integrations/claude-dienst.md Abschnitt 6
import { test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import type pg from "pg";
import { migrate } from "../src/migrate.ts";
import { putTranscript } from "../src/transcripts.ts";
import { claimDelivery, putDelivery, reportResult, supersede } from "../src/deliveries.ts";
import { freshPool } from "./db.ts";
import { call, connect, json, type Doc, type T } from "./mcp-client.ts";

const root = join(import.meta.dirname, "..", "..");
const migrations = join(import.meta.dirname, "..", "migrations");
const HENNING = "henning";
const ANNA = "anna";
const DEVICE = randomUUID();
const HOUR = 3_600_000;
const DAY = 24 * HOUR;
const READ_TOOLS = ["catalog", "delivery_status", "forms", "overview", "show"];

const read = async (...parts: string[]) => JSON.parse(await readFile(join(root, ...parts), "utf8"));
const fullTranscript = async (): Promise<Doc> => (await read("Contracts", "transcript", "valid", "full.json")).transcript;
const catalogFile = async (): Promise<Doc[]> => (await read("Contracts", "catalog", "builtin-exercises.json")).exercises;
const delivery = async (file = "exercise-minimal.json", id: string = randomUUID()): Promise<Doc & { deliveryId: string }> =>
  ({ ...(await read("Contracts", "deliveries", "valid", file)).delivery, deliveryId: id });

// full.json trägt ein festes Datum von 2026; damit "Abschrift zu alt" nur dort auftritt, wo gewollt, wird es auf jetzt gesetzt.
async function transcript(ageMs = 0, change: (doc: Doc) => void = () => {}): Promise<Doc> {
  const doc = await fullTranscript();
  doc.generatedAt = new Date(Date.now() - ageMs).toISOString();
  change(doc);
  return doc;
}

async function migrated(t: T): Promise<pg.Pool> {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  return pool;
}

async function put(pool: pg.Pool, account = HENNING, file = "exercise-minimal.json"): Promise<string> {
  const doc = await delivery(file);
  await putDelivery(pool, account, doc);
  return doc.deliveryId;
}

const backdate = (pool: pg.Pool, id: string, column: "created_at" | "decided_at", ms: number) =>
  pool.query(`UPDATE deliveries SET ${column} = now() - ($2 || ' milliseconds')::interval WHERE id = $1`, [id, String(ms)]);

// 1. Werkzeugliste und Server-Anweisung

test("Werkzeugliste: die fünf Lesewerkzeuge sind da und schreibgeschützt markiert", async (t) => {
  const client = await connect(t, await migrated(t), HENNING);
  const tools = (await client.listTools()).tools;
  for (const name of READ_TOOLS) {
    const tool = tools.find((x) => x.name === name);
    assert.ok(tool, `${name} fehlt`);
    assert.equal(tool.annotations?.readOnlyHint, true, `${name} muss readOnlyHint tragen`);
  }
});

test("Server-Anweisung: alle elf Grundregeln und die zwei Zusätze stehen drin", async (t) => {
  const client = await connect(t, await migrated(t), HENNING);
  const text = client.getInstructions() ?? "";
  const keywords = ["overview", "Bauplan", "forms", "bestätigen", "liegt bereit", "Namen", "löschst nie", "Kopie", "Grund",
    "startest nichts", "bewerten nicht", "medizinischer Rat", "nächsten Öffnen von Healthy Habits"];
  for (const word of keywords) assert.ok(text.includes(word), `Anweisung ohne „${word}“`);
});

// 2. Ohne Konto

test("Ohne Konto: jedes der fünf Werkzeuge lehnt mit „kein Konto“ ab", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, HENNING, await transcript());
  const client = await connect(t, pool);
  const args: Record<string, Doc> = { overview: {}, catalog: { kind: "exercise" }, show: { id: "builtin.planke" }, forms: {}, delivery_status: {} };
  for (const name of READ_TOOLS) {
    const { text, isError } = await call(client, name, args[name]);
    assert.equal(isError, true, name);
    assert.match(text, /kein Konto/, name);
  }
});

// 3. overview

test("overview ohne Abschrift: Meldung no_transcript, eingebaute Übungen aus dem Katalog, sonst 0", async (t) => {
  const client = await connect(t, await migrated(t), HENNING);
  const doc = await json(client, "overview");
  assert.equal(doc.messages[0].kind, "no_transcript");
  assert.equal(doc.counts.exercise.builtin, (await catalogFile()).length);
  assert.equal(doc.counts.exercise.builtin, 43);
  for (const [kind, origin] of [["exercise", "own"], ["exercise", "claude"], ["program", "builtin"], ["program", "own"],
    ["program", "claude"], ["breath", "builtin"], ["breath", "own"], ["breath", "claude"]]) {
    assert.equal(doc.counts[kind][origin], 0, `${kind}/${origin}`);
  }
  assert.equal(doc.generatedAt, undefined);
});

test("overview mit Abschrift: Zählung je Art und Herkunft wie in full.json, generatedAt, keine Meldung", async (t) => {
  const pool = await migrated(t);
  const stored = await transcript();
  await putTranscript(pool, HENNING, stored);
  const doc = await json(await connect(t, pool, HENNING), "overview");
  assert.deepEqual(doc.counts.exercise, { builtin: 1, own: 1, claude: 1 });
  assert.deepEqual(doc.counts.program, { builtin: 1, own: 0, claude: 1 });
  assert.deepEqual(doc.counts.breath, { builtin: 0, own: 1, claude: 1 });
  assert.equal(new Date(doc.generatedAt).getTime(), new Date(stored.generatedAt).getTime());
  assert.deepEqual(doc.messages, []);
});

test("overview: eine abgelehnte Lieferung erscheint als Meldung rejected mit deliveryId", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, HENNING, await transcript());
  const id = await put(pool);
  await claimDelivery(pool, HENNING, DEVICE);
  assert.equal(await reportResult(pool, HENNING, DEVICE, { deliveryId: id, outcome: "rejected",
    errors: [{ code: "unknown_exercise", path: "items[0]", message: "Übung unbekannt" }] }), "ok");
  const doc = await json(await connect(t, pool, HENNING), "overview");
  assert.equal(doc.messages.length, 1);
  assert.equal(doc.messages[0].kind, "rejected");
  assert.equal(doc.messages[0].deliveryId, id);
  assert.equal(typeof doc.messages[0].text, "string");
});

test("overview: eine vor über 14 Tagen abgelehnte Lieferung meldet sich nicht mehr", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, HENNING, await transcript());
  const id = await put(pool);
  await claimDelivery(pool, HENNING, DEVICE);
  await reportResult(pool, HENNING, DEVICE, { deliveryId: id, outcome: "rejected",
    errors: [{ code: "x", path: "", message: "Fehler" }] });
  await backdate(pool, id, "decided_at", 15 * DAY);
  const doc = await json(await connect(t, pool, HENNING), "overview");
  assert.ok(!doc.messages.some((m: Doc) => m.kind === "rejected"));
});

test("overview: eine über 24 h wartende Lieferung meldet waiting_long, eine frische nicht", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, HENNING, await transcript());
  const fresh = await put(pool);
  const old = await put(pool);
  await backdate(pool, old, "created_at", 25 * HOUR);
  const doc = await json(await connect(t, pool, HENNING), "overview");
  const kinds = doc.messages.map((m: Doc) => m.kind);
  assert.deepEqual(kinds, ["waiting_long"]);
  assert.equal(doc.waiting, 2);
  assert.ok(![doc.messages[0].deliveryId].includes(fresh));
});

test("overview: Abschrift älter als 7 Tage meldet transcript_old, jünger nicht", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, HENNING, await transcript(8 * DAY));
  const doc = await json(await connect(t, pool, HENNING), "overview");
  assert.deepEqual(doc.messages.map((m: Doc) => m.kind), ["transcript_old"]);
  assert.ok(doc.transcriptAgeHours >= 8 * 24 - 1);

  const pool2 = await migrated(t);
  await putTranscript(pool2, HENNING, await transcript(6 * DAY));
  assert.deepEqual((await json(await connect(t, pool2, HENNING), "overview")).messages, []);
});

test("overview: Reihenfolge der Meldungen ist abgelehnt, lange wartend, Abschrift", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, HENNING, await transcript(8 * DAY));
  const waiting = await put(pool);
  await backdate(pool, waiting, "created_at", 30 * HOUR);
  const rejected = await put(pool);
  await claimDelivery(pool, HENNING, DEVICE);
  await reportResult(pool, HENNING, DEVICE, { deliveryId: rejected, outcome: "rejected",
    errors: [{ code: "x", path: "", message: "Fehler" }] });
  const doc = await json(await connect(t, pool, HENNING), "overview");
  assert.deepEqual(doc.messages.map((m: Doc) => m.kind), ["rejected", "waiting_long", "transcript_old"]);
});

// 4. catalog

test("catalog ohne Abschrift: 43 eingebaute Übungen mit Kategorie und Hinweis, Programme leer", async (t) => {
  const client = await connect(t, await migrated(t), HENNING);
  const doc = await json(client, "catalog", { kind: "exercise" });
  assert.equal(doc.kind, "exercise");
  assert.equal(doc.items.length, 43);
  for (const item of doc.items) {
    assert.equal(item.origin, "builtin");
    assert.equal(typeof item.category, "string");
    assert.match(item.id, /^builtin\./);
  }
  const burpees = doc.items.find((i: Doc) => i.id === "builtin.burpees");
  assert.equal(burpees.name, "Burpees");
  assert.equal(burpees.category, "fullBody");
  for (const kind of ["program", "breath"]) {
    const empty = await json(client, "catalog", { kind });
    assert.deepEqual(empty.items, []);
    assert.equal(empty.note, "noch keine Abschrift");
  }
});

test("catalog mit Abschrift: Filter origin trennt eigene und Claude-Übungen", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, HENNING, await transcript());
  const client = await connect(t, pool, HENNING);
  const own = await json(client, "catalog", { kind: "exercise", origin: "own" });
  assert.deepEqual(own.items.map((i: Doc) => i.name), ["Schulterkreisen"]);
  const claude = await json(client, "catalog", { kind: "exercise", origin: "claude" });
  assert.deepEqual(claude.items.map((i: Doc) => [i.id, i.name, i.category]),
    [["claude.vierfuessler-diagonal-x3f9k2", "Vierfüßler diagonal", "core"]]);
});

test("catalog: Suche ignoriert Groß-/Kleinschreibung und Akzente, alle Wörter müssen vorkommen", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, HENNING, await transcript());
  const client = await connect(t, pool, HENNING);
  const names = async (query: string, kind = "exercise") =>
    (await json(client, "catalog", { kind, query })).items.map((i: Doc) => i.name);
  assert.deepEqual(await names("vierfussler"), ["Vierfüßler diagonal"]);
  assert.deepEqual(await names("VIERFÜSSLER"), ["Vierfüßler diagonal"]);
  assert.deepEqual(await names("diagonal vierfussler"), ["Vierfüßler diagonal"]);
  assert.deepEqual(await names("diagonal planke"), []);
  assert.deepEqual(await names("RUCKEN", "program"), ["Rücken A"]);
});

test("catalog: Programme mit Schrittzahl und Dauer = Runden × Σ(Arbeit + Pause)", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, HENNING, await transcript());
  const doc = await json(await connect(t, pool, HENNING), "catalog", { kind: "program" });
  const byName = (name: string) => doc.items.find((i: Doc) => i.name === name);
  assert.equal(byName("Rücken A").steps, 2);
  assert.equal(byName("Rücken A").durationSeconds, 2 * (40 + 15 + 30 + 15));
  assert.equal(byName("Rücken A").origin, "claude");
  assert.equal(byName("Tabata").steps, 1);
  assert.equal(byName("Tabata").durationSeconds, 8 * (20 + 10));
  assert.equal(byName("Tabata").origin, "builtin");
});

test("catalog: Atemübungen mit Herkunft und Dauer", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, HENNING, await transcript());
  const doc = await json(await connect(t, pool, HENNING), "catalog", { kind: "breath" });
  const byName = (name: string) => doc.items.find((i: Doc) => i.name === name);
  assert.equal(byName("Box").origin, "own");
  assert.equal(byName("Box").durationSeconds, 10 * (4 + 4 + 4 + 4));
  assert.equal(byName("Abendatem").durationSeconds, 10 * (4 + 2 + 6 + 0));
});

test("catalog: nach Name sortiert und auf höchstens 100 Einträge begrenzt", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, HENNING, await transcript(0, (doc) => {
    for (let n = 0; n < 120; n++) {
      doc.exercises.push({ id: `own.${randomUUID()}`, name: `Zusatz ${String(n).padStart(3, "0")}`, category: "core", origin: "own" });
    }
  }));
  const client = await connect(t, pool, HENNING);
  const limited = await json(client, "catalog", { kind: "exercise", origin: "own" });
  assert.equal(limited.items.length, 100);
  const collator = new Intl.Collator("de", { sensitivity: "base" });
  const names: string[] = limited.items.map((i: Doc) => i.name);
  assert.deepEqual(names, [...names].sort(collator.compare));

  const ascii = await json(await connect(t, await migrated(t), HENNING), "catalog", { kind: "exercise" });
  const asciiNames: string[] = ascii.items.map((i: Doc) => i.name);
  assert.deepEqual(asciiNames, [...asciiNames].sort(collator.compare));
});

// 5. show

test("show: Programm aus der Abschrift vollständig, mit Stand und Herkunft", async (t) => {
  const pool = await migrated(t);
  const stored = await transcript();
  await putTranscript(pool, HENNING, stored);
  const doc = await json(await connect(t, pool, HENNING), "show", { id: "claude.ruecken-a-7hq2mz" });
  assert.equal(doc.kind, "program");
  assert.deepEqual(doc.item, stored.programs.find((p: Doc) => p.id === "claude.ruecken-a-7hq2mz"));
  assert.equal(doc.item.state, "adapted");
  assert.equal(doc.item.revision, 2);
  assert.deepEqual(doc.pending, []);
});

test("show: eingebaute Übung ohne Abschrift kommt aus dem Katalog", async (t) => {
  const doc = await json(await connect(t, await migrated(t), HENNING), "show", { id: "builtin.burpees" });
  assert.equal(doc.kind, "exercise");
  assert.equal(doc.item.name, "Burpees");
  assert.equal(doc.item.category, "fullBody");
});

test("show: pending nennt wartende Lieferungen zu diesem Baustein, aber keine fremden oder erledigten", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, HENNING, await transcript());
  const matching = await delivery("exercise-and-program.json");
  matching.items[1].itemId = "claude.ruecken-a-7hq2mz";
  await putDelivery(pool, HENNING, matching);
  const other = await delivery("breath.json");
  await putDelivery(pool, HENNING, other);
  const client = await connect(t, pool, HENNING);
  const doc = await json(client, "show", { id: "claude.ruecken-a-7hq2mz" });
  assert.deepEqual(doc.pending.map((p: Doc) => p.deliveryId), [matching.deliveryId]);
  assert.equal(doc.pending[0].state, "waiting");

  await claimDelivery(pool, HENNING, DEVICE);
  await reportResult(pool, HENNING, DEVICE, { deliveryId: matching.deliveryId, outcome: "accepted" });
  assert.deepEqual((await json(client, "show", { id: "claude.ruecken-a-7hq2mz" })).pending, []);
});

test("show: unbekannte Kennung wird abgelehnt und verweist auf catalog", async (t) => {
  const client = await connect(t, await migrated(t), HENNING);
  const { text, isError } = await call(client, "show", { id: "claude.gibt-es-nicht" });
  assert.equal(isError, true);
  assert.match(text, /catalog/);
});

// 6. forms

test("forms: alle vier Arten mit Grenzen aus dem Lieferformat", async (t) => {
  const { text, isError } = await call(await connect(t, await migrated(t), HENNING), "forms");
  assert.equal(isError, false);
  JSON.parse(text);
  for (const word of ["exercise", "program", "breath", "withdrawal", "workSeconds", "restSeconds", "rounds", "hint", "inhaleSeconds", "steps"]) {
    assert.ok(text.includes(word), `forms ohne „${word}“`);
  }
  for (const limit of ["600", "99", "80", "40"]) assert.ok(text.includes(limit), `forms ohne Grenze ${limit}`);
});

test("forms: die neun Kategorien mit deutschem Namen", async (t) => {
  const { text } = await call(await connect(t, await migrated(t), HENNING), "forms");
  for (const key of ["strength", "stretching", "core", "cardio", "legs", "upperBody", "fullBody", "warmup", "cooldown"]) {
    assert.ok(text.includes(key), `Kategorie ${key}`);
  }
  for (const name of ["Kraft", "Dehnung", "Core", "Cardio", "Beine", "Oberkörper", "Ganzkörper", "Aufwärmen", "Cool-Down"]) {
    assert.ok(text.includes(name), `deutscher Name ${name}`);
  }
});

test("forms: mit kind nur die gewünschte Art", async (t) => {
  const client = await connect(t, await migrated(t), HENNING);
  const breath = (await call(client, "forms", { kind: "breath" })).text;
  assert.ok(breath.includes("inhaleSeconds"));
  assert.ok(!breath.includes("workSeconds"));
});

// 7. delivery_status

test("delivery_status: Zustände nach außen, mit Fehlern und Inhalt kurz", async (t) => {
  const pool = await migrated(t);
  const rejected = await put(pool);
  const accepted = await put(pool);
  const inApp = await put(pool);
  const withdrawn = await put(pool);
  const waiting = await put(pool, HENNING, "exercise-and-program.json");
  assert.equal(await supersede(pool, HENNING, withdrawn), true);
  for (const id of [rejected, accepted, inApp]) {
    const got = await claimDelivery(pool, HENNING, DEVICE);
    assert.equal(got?.deliveryId, id);
  }
  const errors = [{ code: "unknown_exercise", path: "items[0]", message: "Übung unbekannt" }];
  await reportResult(pool, HENNING, DEVICE, { deliveryId: rejected, outcome: "rejected", errors });
  await reportResult(pool, HENNING, DEVICE, { deliveryId: accepted, outcome: "accepted" });
  const doc = await json(await connect(t, pool, HENNING), "delivery_status");
  const state = (id: string) => doc.deliveries.find((d: Doc) => d.deliveryId === id);
  assert.equal(state(waiting).state, "waiting");
  assert.equal(state(inApp).state, "in_app");
  assert.equal(state(accepted).state, "accepted");
  assert.equal(state(rejected).state, "rejected");
  assert.equal(state(withdrawn).state, "withdrawn");
  assert.equal(state(rejected).errors[0].message, "Übung unbekannt");
  assert.ok(state(accepted).decidedAt);
  assert.ok(state(waiting).createdAt);
  assert.deepEqual(state(waiting).items.map((i: Doc) => [i.kind, i.name]),
    [["exercise", "Vierfüßler diagonal"], ["program", "Rücken A"]]);
});

test("delivery_status: neueste zuerst, höchstens 20", async (t) => {
  const pool = await migrated(t);
  const ids: string[] = [];
  for (let n = 0; n < 25; n++) ids.push(await put(pool));
  const doc = await json(await connect(t, pool, HENNING), "delivery_status");
  assert.equal(doc.deliveries.length, 20);
  assert.deepEqual(doc.deliveries.map((d: Doc) => d.deliveryId), ids.slice(5).reverse());
});

test("delivery_status: einzelne Lieferung per deliveryId, unbekannte wird abgelehnt", async (t) => {
  const pool = await migrated(t);
  const first = await put(pool);
  await put(pool);
  const client = await connect(t, pool, HENNING);
  const doc = await json(client, "delivery_status", { deliveryId: first });
  assert.deepEqual(doc.deliveries.map((d: Doc) => d.deliveryId), [first]);
  const unknown = await call(client, "delivery_status", { deliveryId: randomUUID() });
  assert.equal(unknown.isError, true);
});

test("delivery_status: ein fremdes Konto sieht nichts, auch nicht per deliveryId", async (t) => {
  const pool = await migrated(t);
  const foreign = await put(pool, ANNA);
  const client = await connect(t, pool, HENNING);
  assert.deepEqual((await json(client, "delivery_status")).deliveries, []);
  assert.equal((await call(client, "delivery_status", { deliveryId: foreign })).isError, true);
});
