// B2a-6 Nachträge (Issue #54): TDD RED. Spec: openspec/specs/integrations/claude-dienst.md Abschnitt 6, "Nachträge nach der Adversary-Prüfung (B2a-6)"
// Punkte 1 (ein Schreiber je Konto), 2 (doppelte Rücknahme), 3 (Dienstfelder).
import { test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import type pg from "pg";
import { migrate } from "../src/migrate.ts";
import { putTranscript } from "../src/transcripts.ts";
import { claimDelivery, listDeliveries, reportResult } from "../src/deliveries.ts";
import { freshPool } from "./db.ts";
import { call, connect, json, type Doc, type T } from "./mcp-client.ts";

const root = join(import.meta.dirname, "..", "..");
const migrations = join(import.meta.dirname, "..", "migrations");
const HENNING = "henning";
const ANNA = "anna";
const DEVICE = randomUUID();
const ACTIVE_EXERCISE = "claude.vierfuessler-diagonal-x3f9k2"; // active, Revision 1, Paket claude.ruecken-november
const PACKAGE = "Rücken November";

const fullTranscript = (): Doc => JSON.parse(readFileSync(join(root, "Contracts", "transcript", "valid", "full.json"), "utf8")).transcript;

async function migrated(t: T): Promise<pg.Pool> {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  return pool;
}
async function withTranscript(pool: pg.Pool, account = HENNING): Promise<void> {
  const doc = fullTranscript();
  doc.generatedAt = new Date().toISOString();
  assert.equal(await putTranscript(pool, account, doc), "stored");
}
const exercise = (over: Doc = {}): Doc => ({
  name: "Käfer", category: "core", effect: "Stärkt die Bauchmuskeln.", instructions: "Auf den Rücken legen, Arme und Beine strecken.",
  why: "Fehlte für den Rücken.", ...over,
});
const program = (over: Doc = {}): Doc => ({
  name: "Rücken kurz", symbol: "🧘", rounds: 2, steps: [{ exerciseId: "builtin.planke", workSeconds: 30, restSeconds: 10 }], why: "Kurz.", ...over,
});
const breath = (over: Doc = {}): Doc => ({
  name: "Abendatem", symbol: "🌙", inhaleSeconds: 4, holdInSeconds: 2, exhaleSeconds: 6, holdOutSeconds: 0, rounds: 5, why: "Ruhe.", ...over,
});
const fieldsOf = (doc: Doc): Doc => { const { why, package: pkg, ...rest } = doc; return rest; };
const withdrawals = async (pool: pg.Pool, account = HENNING) =>
  (await listDeliveries(pool, account)).filter((r) => (r.delivery as Doc).items?.[0]?.kind === "withdrawal");

// 1. Ein Schreiber je Konto

test("Ein Schreiber: 6 gleichzeitige item_update mit gleicher basedOnRevision -> genau 1 Erfolg, 5 mal „neu lesen“, eine Lieferung Revision + 1", async (t) => {
  const pool = await migrated(t);
  const first = await json(await connect(t, pool, HENNING), "exercise_define", exercise());
  const clients = await Promise.all(Array.from({ length: 6 }, () => connect(t, pool, HENNING)));
  const results = await Promise.all(clients.map((c, i) =>
    call(c, "item_update", { itemId: first.itemId, basedOnRevision: 1, why: `Version ${i}`, fields: fieldsOf(exercise({ effect: `Wirkung ${i}.` })) })));
  const ok = results.filter((r) => !r.isError);
  const failed = results.filter((r) => r.isError);
  assert.equal(ok.length, 1, JSON.stringify(results));
  assert.equal(failed.length, 5);
  for (const f of failed) assert.match(f.text, /neu lesen/);
  assert.equal(JSON.parse(ok[0].text).revision, 2);
  const rows = (await listDeliveries(pool, HENNING)).filter((r) => (r.delivery as Doc).items[0].revision === 2);
  assert.equal(rows.length, 1);
  assert.equal((await listDeliveries(pool, HENNING)).length, 2);
});

test("Ein Schreiber: 6 gleichzeitige item_withdraw auf einen aktiven Abschrift-Baustein -> genau eine Rücknahme-Lieferung", async (t) => {
  const pool = await migrated(t);
  await withTranscript(pool);
  const clients = await Promise.all(Array.from({ length: 6 }, () => connect(t, pool, HENNING)));
  const results = await Promise.all(clients.map((c) => call(c, "item_withdraw", { itemId: ACTIVE_EXERCISE, why: "Weg." })));
  assert.equal(results.filter((r) => !r.isError).length, 1, JSON.stringify(results));
  assert.equal((await withdrawals(pool)).length, 1);
  assert.equal((await listDeliveries(pool, HENNING)).length, 1);
});

test("Ein Schreiber: gleichzeitige Aufrufe zweier Konten blockieren sich nicht, beide gelingen", async (t) => {
  const pool = await migrated(t);
  const [a, b] = await Promise.all([connect(t, pool, HENNING), connect(t, pool, ANNA)]);
  const [ra, rb] = await Promise.all([call(a, "exercise_define", exercise()), call(b, "exercise_define", exercise())]);
  assert.equal(ra.isError, false, ra.text);
  assert.equal(rb.isError, false, rb.text);
  assert.equal((await listDeliveries(pool, HENNING)).length, 1);
  assert.equal((await listDeliveries(pool, ANNA)).length, 1);
});

// 2. Doppelte Rücknahme

test("Doppelte Rücknahme: zweimal nacheinander auf aktiven Abschrift-Baustein -> zweite „schon bereit“, nur eine Lieferung", async (t) => {
  const pool = await migrated(t);
  await withTranscript(pool);
  const client = await connect(t, pool, HENNING);
  await json(client, "item_withdraw", { itemId: ACTIVE_EXERCISE, why: "Weg." });
  const second = await call(client, "item_withdraw", { itemId: ACTIVE_EXERCISE, why: "Nochmal." });
  assert.equal(second.isError, true);
  assert.match(second.text, /schon bereit/);
  assert.equal((await withdrawals(pool)).length, 1);
});

for (const state of ["claimed", "accepted"] as const) {
  test(`Doppelte Rücknahme: erste Rücknahme ${state}, Abschrift zeigt noch active -> zweite „schon bereit“`, async (t) => {
    const pool = await migrated(t);
    await withTranscript(pool);
    const client = await connect(t, pool, HENNING);
    const first = await json(client, "item_withdraw", { itemId: ACTIVE_EXERCISE, why: "Weg." });
    const claimed = await claimDelivery(pool, HENNING, DEVICE);
    assert.equal(claimed?.deliveryId, first.deliveryId);
    if (state === "accepted") assert.equal(await reportResult(pool, HENNING, DEVICE, { deliveryId: first.deliveryId, outcome: "accepted" }), "ok");
    const second = await call(client, "item_withdraw", { itemId: ACTIVE_EXERCISE, why: "Nochmal." });
    assert.equal(second.isError, true, second.text);
    assert.match(second.text, /schon bereit/);
    assert.equal((await withdrawals(pool)).length, 1);
  });
}

test("Doppelte Rücknahme (Paket): zweimal nacheinander -> zweite „schon bereit“, nur eine Rücknahme", async (t) => {
  const pool = await migrated(t);
  await withTranscript(pool);
  const client = await connect(t, pool, HENNING);
  await json(client, "item_withdraw", { package: PACKAGE, why: "Weg." });
  const second = await call(client, "item_withdraw", { package: PACKAGE, why: "Nochmal." });
  assert.equal(second.isError, true);
  assert.match(second.text, /schon bereit/);
  assert.equal((await withdrawals(pool)).length, 1);
});

for (const state of ["claimed", "accepted"] as const) {
  test(`Doppelte Rücknahme (Paket): erste Rücknahme ${state}, Abschrift zeigt noch active -> zweite „schon bereit“`, async (t) => {
    const pool = await migrated(t);
    await withTranscript(pool);
    const client = await connect(t, pool, HENNING);
    const first = await json(client, "item_withdraw", { package: PACKAGE, why: "Weg." });
    assert.equal((await claimDelivery(pool, HENNING, DEVICE))?.deliveryId, first.deliveryId);
    if (state === "accepted") assert.equal(await reportResult(pool, HENNING, DEVICE, { deliveryId: first.deliveryId, outcome: "accepted" }), "ok");
    const second = await call(client, "item_withdraw", { package: PACKAGE, why: "Nochmal." });
    assert.equal(second.isError, true, second.text);
    assert.match(second.text, /schon bereit/);
    assert.equal((await withdrawals(pool)).length, 1);
  });
}

// 3. Dienstfelder

const creators: [string, (over: Doc) => Doc][] = [["exercise_define", exercise], ["program_create", program], ["breath_create", breath]];
const SERVICE_VALUES: Record<string, unknown> = { kind: "exercise", itemId: "claude.eigen-abcdef", revision: 5 };
for (const [tool, make] of creators) {
  for (const [field, value] of Object.entries(SERVICE_VALUES)) {
    test(`Dienstfeld: ${tool} mit ${field} in der Eingabe -> isError „${field} … weglassen“, nichts gespeichert`, async (t) => {
      const pool = await migrated(t);
      const { text, isError } = await call(await connect(t, pool, HENNING), tool, make({ [field]: value }));
      assert.equal(isError, true, text);
      assert.ok(text.includes(field), text);
      assert.match(text, /weglassen/);
      assert.deepEqual(await listDeliveries(pool, HENNING), []);
    });
  }
}

for (const [field, value] of Object.entries(SERVICE_VALUES)) {
  test(`Dienstfeld: item_update mit ${field} in fields -> isError „${field} … weglassen“, nichts Neues gespeichert`, async (t) => {
    const pool = await migrated(t);
    const client = await connect(t, pool, HENNING);
    const first = await json(client, "exercise_define", exercise());
    const { text, isError } = await call(client, "item_update", {
      itemId: first.itemId, basedOnRevision: 1, why: "Neu.", fields: { ...fieldsOf(exercise()), [field]: value },
    });
    assert.equal(isError, true, text);
    assert.ok(text.includes(field), text);
    assert.match(text, /weglassen/);
    assert.equal((await listDeliveries(pool, HENNING)).length, 1);
  });
}

// Deterministisch: Sperre auf das Konto (pg_advisory_xact_lock(hashtextextended('hhhaven:' || account_id, 0))) hält Schreiber auf.
async function lockedAccount(pool: pg.Pool, account: string): Promise<{ release: () => Promise<void> }> {
  const holder = await pool.connect();
  await holder.query("BEGIN");
  await holder.query("SELECT pg_advisory_xact_lock(hashtextextended('hhhaven:' || $1::text, 0))", [account]);
  return { release: async () => { try { await holder.query("COMMIT"); } finally { holder.release(); } } };
}
const PENDING = Symbol("pending");
const settled = <V>(p: Promise<V>, ms: number): Promise<V | typeof PENDING> =>
  Promise.race([p, new Promise<typeof PENDING>((done) => setTimeout(() => done(PENDING), ms))]);

const lockedCases: [string, (itemId: string) => [string, Doc]][] = [
  ["item_update", (itemId) => ["item_update", { itemId, basedOnRevision: 1, why: "Neu.", fields: fieldsOf(exercise({ effect: "Anders." })) }]],
  ["exercise_define", () => ["exercise_define", exercise({ name: "Zweite" })]],
];
for (const [label, make] of lockedCases) {
  test(`Kontosperre: ${label} wartet auf die Sperre des eigenen Kontos, nach COMMIT gelingt der Aufruf`, async (t) => {
    const pool = await migrated(t);
    const client = await connect(t, pool, HENNING);
    const first = await json(client, "exercise_define", exercise());
    const lock = await lockedAccount(pool, HENNING);
    let released = false;
    const unlock = async () => { if (!released) { released = true; await lock.release(); } };
    try {
      const [tool, args] = make(first.itemId);
      const running = call(await connect(t, pool, HENNING), tool, args);
      assert.equal(await settled(running, 300), PENDING, "Aufruf darf unter fremder Kontosperre nicht fertig werden");
      assert.equal((await listDeliveries(pool, HENNING)).length, 1, "keine neue Lieferung während der Sperre");
      await unlock();
      const result = await running;
      assert.equal(result.isError, false, result.text);
      assert.equal((await listDeliveries(pool, HENNING)).length, 2);
    } finally {
      await unlock();
    }
  });
}

test("Kontosperre: Sperre eines anderen Kontos blockiert nicht", async (t) => {
  const pool = await migrated(t);
  const lock = await lockedAccount(pool, ANNA);
  try {
    const result = await settled(call(await connect(t, pool, HENNING), "exercise_define", exercise()), 3000);
    assert.notEqual(result, PENDING, "Aufruf wurde von fremdem Konto blockiert");
    assert.equal((result as { isError: boolean }).isError, false);
  } finally {
    await lock.release();
  }
});
