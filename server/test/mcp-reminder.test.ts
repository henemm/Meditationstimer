// B4a Smarte Erinnerung (Issue #60), Teil Dienst: TDD RED. Spec: openspec/specs/integrations/claude-erinnerung.md Abschnitte 3 und 4
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import type pg from "pg";
import { migrate } from "../src/migrate.ts";
import { putTranscript } from "../src/transcripts.ts";
import { listDeliveries } from "../src/deliveries.ts";
import { validateDelivery } from "../../Contracts/validator/src/index.ts";
import { freshPool } from "./db.ts";
import { call, connect, json, type Doc, type T } from "./mcp-client.ts";

const root = join(import.meta.dirname, "..", "..");
const migrations = join(import.meta.dirname, "..", "migrations");
const HENNING = "henning";
const ANNA = "anna";
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const OWN_BREATH = "own.8e4f9c1a-52b4-4f08-8e6a-0c9b1d2e3f45";
const CLAUDE_PROGRAM = "claude.ruecken-a-7hq2mz";

const fullV2 = (): Doc => JSON.parse(readFileSync(join(root, "Contracts", "transcript", "v2", "valid", "full.json"), "utf8")).transcript;

async function migrated(t: T): Promise<pg.Pool> {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  return pool;
}

const target = (over: Doc = {}): Doc => ({ type: "workout", programId: "builtin.tabata", ...over });
const reminder = (over: Doc = {}): Doc => ({
  title: "Rücken A", message: "Zeit für Rücken A, falls heute noch kein Training war.", time: "18:00",
  weekdays: ["monday", "thursday"], lookbackHours: 12, target: target(), why: "Rücken stärken.", ...over,
});
const fieldsOf = (doc: Doc): Doc => { const { why, package: pkg, ...rest } = doc; return rest; };

const rid = (n: number) => `claude.erinnerung${n}-k3x9p2`;
const claudeEntry = (n: number, over: Doc = {}): Doc => ({
  id: rid(n), title: `Erinnerung ${n}`, message: "Hallo.", time: "18:00", weekdays: ["monday"], lookbackHours: 12, enabled: true,
  target: { type: "meditation" }, origin: "claude", revision: 1, state: "active", ...over,
});
const ownEntry = (n: number): Doc => ({
  id: `own.0b1c2d3e-4f50-4a61-8b72-9c8d7e6f5a${String(n).padStart(2, "0")}`, title: `Eigene ${n}`, message: "Hallo.", time: "09:00",
  weekdays: ["friday"], lookbackHours: 4, enabled: true, target: { type: "noalc" }, origin: "own",
});

async function withReminders(pool: pg.Pool, reminders: Doc[], account = HENNING): Promise<void> {
  const doc = fullV2();
  doc.generatedAt = new Date().toISOString();
  doc.reminders = reminders;
  assert.equal(await putTranscript(pool, account, doc), "stored");
}
const activeEntries = (count: number): Doc[] => Array.from({ length: count }, (_, i) => claudeEntry(i + 1));
const count = async (pool: pg.Pool, account = HENNING) => (await listDeliveries(pool, account)).length;

// 1. Werkzeug

test("Werkzeugliste: reminder_create ist da und nicht schreibgeschützt", async (t) => {
  const tools = (await (await connect(t, await migrated(t), HENNING)).listTools()).tools;
  const tool = tools.find((x) => x.name === "reminder_create");
  assert.ok(tool, "reminder_create fehlt");
  assert.equal(tool.annotations?.readOnlyHint, false);
});

test("reminder_create ohne Konto: „kein Konto“", async (t) => {
  const { text, isError } = await call(await connect(t, await migrated(t)), "reminder_create", reminder());
  assert.equal(isError, true);
  assert.match(text, /kein Konto/);
});

test("reminder_create: gültige Eingabe -> Antwort und gespeicherte Lieferung besteht den Prüfer", async (t) => {
  const pool = await migrated(t);
  await withReminders(pool, []);
  const input = reminder();
  const answer = await json(await connect(t, pool, HENNING), "reminder_create", input);
  assert.match(answer.deliveryId, UUID);
  assert.equal(typeof answer.itemId, "string");
  assert.equal(answer.revision, 1);
  assert.equal(answer.state, "waiting");
  const row = (await listDeliveries(pool, HENNING)).find((r) => (r.delivery as Doc).deliveryId === answer.deliveryId);
  assert.ok(row);
  const doc = row.delivery as Doc;
  assert.deepEqual(validateDelivery(doc, { knownPrograms: ["builtin.tabata"] } as any).errors, []);
  assert.equal(doc.items.length, 1);
  assert.equal(doc.items[0].kind, "reminder");
  assert.equal(doc.items[0].itemId, answer.itemId);
  assert.deepEqual(doc.items[0].target, input.target);
  assert.equal(doc.items[0].time, "18:00");
  assert.equal(doc.why, input.why);
});

for (const [field, value] of Object.entries({ kind: "reminder", itemId: "claude.eigen-abcdef", revision: 5 })) {
  test(`reminder_create mit Dienstfeld ${field} -> isError „weglassen“, nichts gespeichert`, async (t) => {
    const pool = await migrated(t);
    const { text, isError } = await call(await connect(t, pool, HENNING), "reminder_create", reminder({ [field]: value }));
    assert.equal(isError, true, text);
    assert.ok(text.includes(field), text);
    assert.match(text, /weglassen/);
    assert.equal(await count(pool), 0);
  });
}

// 2. Bezüge

test("Bezug: eingebautes und Claude-Programm aus der Abschrift sind gültig", async (t) => {
  const pool = await migrated(t);
  await withReminders(pool, []);
  const client = await connect(t, pool, HENNING);
  for (const programId of ["builtin.tabata", CLAUDE_PROGRAM]) {
    const { text, isError } = await call(client, "reminder_create", reminder({ target: target({ programId }) }));
    assert.equal(isError, false, text);
  }
});

test("Bezug: Programm aus wartender Lieferung (program_create) ist gültig", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, HENNING);
  const program = await json(client, "program_create", {
    name: "Rücken kurz", symbol: "🧘", rounds: 2, steps: [{ exerciseId: "builtin.planke", workSeconds: 30, restSeconds: 10 }], why: "Kurz.",
  });
  const { text, isError } = await call(client, "reminder_create", reminder({ target: target({ programId: program.itemId }) }));
  assert.equal(isError, false, text);
});

test("Bezug: unbekanntes Programm -> isError mit Pfad /items/0/target/programId", async (t) => {
  const pool = await migrated(t);
  await withReminders(pool, []);
  const { text, isError } = await call(await connect(t, pool, HENNING), "reminder_create", reminder({ target: target({ programId: "claude.gibt-es-nicht-abcdef" }) }));
  assert.equal(isError, true);
  assert.ok(text.includes("/items/0/target/programId"), text);
  assert.equal(await count(pool), 0);
});

test("Bezug: Atemübung aus Abschrift und aus wartender Lieferung gültig, unbekannte abgelehnt mit Pfad …/breathId", async (t) => {
  const pool = await migrated(t);
  await withReminders(pool, []);
  const client = await connect(t, pool, HENNING);
  const breathTarget = (breathId: string) => ({ type: "breath", breathId });
  assert.equal((await call(client, "reminder_create", reminder({ target: breathTarget(OWN_BREATH) }))).isError, false);
  const breath = await json(client, "breath_create", {
    name: "Abendatem2", symbol: "🌙", inhaleSeconds: 4, holdInSeconds: 2, exhaleSeconds: 6, holdOutSeconds: 0, rounds: 5, why: "Ruhe.",
  });
  assert.equal((await call(client, "reminder_create", reminder({ target: breathTarget(breath.itemId) }))).isError, false);
  const bad = await call(client, "reminder_create", reminder({ target: breathTarget("claude.gibt-es-nicht-abcdef") }));
  assert.equal(bad.isError, true);
  assert.ok(bad.text.includes("/items/0/target/breathId"), bad.text);
});

// 3. Obergrenze sechs

const LIMIT_TEXT = (text: string) => { assert.match(text, /sechs/); assert.ok(text.includes("item_withdraw"), text); };

test("Grenze: bei 5 aktiven in der Abschrift ist die 6. erlaubt, die 7. abgelehnt (Text mit „sechs“ und item_withdraw), nichts gespeichert", async (t) => {
  const pool = await migrated(t);
  await withReminders(pool, activeEntries(5));
  const client = await connect(t, pool, HENNING);
  const sixth = await call(client, "reminder_create", reminder());
  assert.equal(sixth.isError, false, sixth.text);
  const seventh = await call(client, "reminder_create", reminder({ title: "Siebte" }));
  assert.equal(seventh.isError, true);
  LIMIT_TEXT(seventh.text);
  assert.equal(await count(pool), 1);
});

test("Grenze: wartende Lieferungen zählen mit (ohne Abschrift: 6 gehen, die 7. nicht)", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, HENNING);
  for (let n = 0; n < 6; n++) {
    const r = await call(client, "reminder_create", reminder({ target: { type: "meditation" }, title: `E${n}` }));
    assert.equal(r.isError, false, `${n}: ${r.text}`);
  }
  const seventh = await call(client, "reminder_create", reminder({ target: { type: "meditation" } }));
  assert.equal(seventh.isError, true);
  LIMIT_TEXT(seventh.text);
  assert.equal(await count(pool), 6);
});

test("Grenze: abgeschaltete und zurückgezogene Erinnerungen in der Abschrift zählen nicht", async (t) => {
  const pool = await migrated(t);
  await withReminders(pool, [
    ...activeEntries(4),
    claudeEntry(5, { enabled: false }),
    claudeEntry(6, { state: "withdrawn" }),
    claudeEntry(7, { enabled: false, state: "withdrawn" }),
  ]);
  const client = await connect(t, pool, HENNING);
  assert.equal((await call(client, "reminder_create", reminder())).isError, false);
  assert.equal((await call(client, "reminder_create", reminder())).isError, false);
  const third = await call(client, "reminder_create", reminder());
  assert.equal(third.isError, true);
  LIMIT_TEXT(third.text);
});

test("Grenze: eine Erinnerung mit wartender Rücknahme zählt nicht", async (t) => {
  const pool = await migrated(t);
  await withReminders(pool, activeEntries(6));
  const client = await connect(t, pool, HENNING);
  const full = await call(client, "reminder_create", reminder());
  assert.equal(full.isError, true);
  LIMIT_TEXT(full.text);
  await json(client, "item_withdraw", { itemId: rid(1), why: "Weg." });
  const again = await call(client, "reminder_create", reminder());
  assert.equal(again.isError, false, again.text);
});

test("Grenze: item_update einer bestehenden Erinnerung bei voller Grenze ist erlaubt", async (t) => {
  const pool = await migrated(t);
  await withReminders(pool, activeEntries(6));
  const result = await call(await connect(t, pool, HENNING), "item_update", {
    itemId: rid(2), basedOnRevision: 1, why: "Später.", fields: fieldsOf(reminder({ time: "19:30", target: { type: "meditation" } })),
  });
  assert.equal(result.isError, false, result.text);
  assert.equal(JSON.parse(result.text).revision, 2);
});

test("Grenze: eigene Erinnerungen zählen nicht", async (t) => {
  const pool = await migrated(t);
  await withReminders(pool, [...[1, 2, 3, 4, 5, 6].map(ownEntry), ...activeEntries(5)]);
  const client = await connect(t, pool, HENNING);
  assert.equal((await call(client, "reminder_create", reminder())).isError, false);
  assert.equal((await call(client, "reminder_create", reminder())).isError, true);
});

test("Grenze: Konten sind getrennt", async (t) => {
  const pool = await migrated(t);
  await withReminders(pool, activeEntries(6), HENNING);
  await withReminders(pool, [], ANNA);
  assert.equal((await call(await connect(t, pool, HENNING), "reminder_create", reminder())).isError, true);
  const anna = await call(await connect(t, pool, ANNA), "reminder_create", reminder());
  assert.equal(anna.isError, false, anna.text);
});

// 4. Lesen

const stored = async (t: T) => {
  const pool = await migrated(t);
  await withReminders(pool, [ownEntry(1), claudeEntry(1, { target: { type: "workout", programId: "builtin.tabata" }, weekdays: ["monday", "thursday"] })]);
  return pool;
};

test("catalog kind reminder: eigene und Claude-Erinnerungen mit id, name, origin, time, weekdays, target", async (t) => {
  const pool = await stored(t);
  const doc = await json(await connect(t, pool, HENNING), "catalog", { kind: "reminder" });
  assert.equal(doc.items.length, 2);
  const claude = doc.items.find((i: Doc) => i.id === rid(1));
  assert.equal(claude.name, "Erinnerung 1");
  assert.equal(claude.origin, "claude");
  assert.equal(claude.time, "18:00");
  assert.deepEqual(claude.weekdays, ["monday", "thursday"]);
  assert.deepEqual(claude.target, { type: "workout", programId: "builtin.tabata" });
  const own = doc.items.find((i: Doc) => i.origin === "own");
  assert.equal(own.name, "Eigene 1");
});

test("show: zeigt eine Erinnerung", async (t) => {
  const pool = await stored(t);
  const doc = await json(await connect(t, pool, HENNING), "show", { id: rid(1) });
  assert.equal(doc.kind, "reminder");
  assert.equal(doc.item.title, "Erinnerung 1");
  assert.equal(doc.item.revision, 1);
});

test("forms: Art reminder mit lookbackHours 1–24 und den Wochentagen", async (t) => {
  const client = await connect(t, await migrated(t), HENNING);
  const { text, isError } = await call(client, "forms");
  assert.equal(isError, false);
  for (const word of ["reminder", "lookbackHours", "weekdays", "monday", "sunday", "target", "24"]) assert.ok(text.includes(word), `forms ohne „${word}“`);
  const only = await call(client, "forms", { kind: "reminder" });
  assert.equal(only.isError, false, only.text);
  assert.ok(only.text.includes("lookbackHours"));
  assert.ok(!only.text.includes("inhaleSeconds"));
});

test("overview: Erinnerungen je Herkunft und activeClaudeReminders", async (t) => {
  const pool = await migrated(t);
  await withReminders(pool, [ownEntry(1), ownEntry(2), ...activeEntries(3), claudeEntry(4, { enabled: false })]);
  const doc = await json(await connect(t, pool, HENNING), "overview");
  assert.equal(doc.counts.reminder.own, 2);
  assert.equal(doc.counts.reminder.claude, 4);
  assert.equal(doc.activeClaudeReminders ?? doc.counts?.activeClaudeReminders, 3, JSON.stringify(doc));
});

test("Server-Anweisung: höchstens sechs Erinnerungen, laden ein und mahnen nicht", async (t) => {
  const text = (await connect(t, await migrated(t), HENNING)).getInstructions() ?? "";
  assert.ok(text.includes("sechs"), text);
  assert.match(text, /Erinnerungen/);
  assert.match(text, /mahnen nicht/);
});

// 5. item_update und item_withdraw

test("item_update einer wartenden Erinnerung: neue Fassung Revision 2 als gültige Lieferung", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, HENNING);
  const first = await json(client, "reminder_create", reminder({ target: { type: "meditation" } }));
  const updated = await json(client, "item_update", {
    itemId: first.itemId, basedOnRevision: 1, why: "Später.", fields: fieldsOf(reminder({ time: "20:00", target: { type: "meditation" } })),
  });
  assert.equal(updated.revision, 2);
  const row = (await listDeliveries(pool, HENNING)).find((r) => (r.delivery as Doc).deliveryId === updated.deliveryId);
  const item = (row!.delivery as Doc).items[0];
  assert.equal(item.kind, "reminder");
  assert.equal(item.time, "20:00");
  assert.equal(item.revision, 2);
  assert.deepEqual(validateDelivery(row!.delivery as Doc).errors, []);
});

test("item_withdraw einer Erinnerung aus der Abschrift: Rücknahme-Lieferung", async (t) => {
  const pool = await stored(t);
  const answer = await json(await connect(t, pool, HENNING), "item_withdraw", { itemId: rid(1), why: "Nicht mehr nötig." });
  const row = (await listDeliveries(pool, HENNING)).find((r) => (r.delivery as Doc).deliveryId === answer.deliveryId);
  const item = (row!.delivery as Doc).items[0];
  assert.equal(item.kind, "withdrawal");
  assert.equal(item.itemId, rid(1));
});
