// B2a-3 Lieferungen (Issue #54): TDD RED. Spec: openspec/specs/integrations/claude-dienst.md Abschnitt 5
import { test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { migrate } from "../src/migrate.ts";
import { claimDelivery, listDeliveries, putDelivery, reportResult, supersede } from "../src/deliveries.ts";
import { freshPool } from "./db.ts";

const root = join(import.meta.dirname, "..", "..");
const migrationsDir = join(import.meta.dirname, "..", "migrations");
const A = "konto-a";
const B = "konto-b";

async function migrated(t: Parameters<typeof freshPool>[0]) {
  const pool = await freshPool(t);
  await migrate(pool, migrationsDir);
  return pool;
}

async function sample(id: string = randomUUID()): Promise<Record<string, unknown> & { deliveryId: string }> {
  const file = JSON.parse(await readFile(join(root, "Contracts", "deliveries", "valid", "exercise-minimal.json"), "utf8"));
  return { ...file.delivery, deliveryId: id };
}

async function put(pool: Parameters<typeof putDelivery>[0], account: string, id: string = randomUUID()): Promise<string> {
  await putDelivery(pool, account, await sample(id));
  return id;
}

const errs = [{ code: "unknown_exercise", path: "items[0]", message: "Übung unbekannt" }];

test("Abholen: aelteste zuerst, in Reihenfolge des Eingangs, dann leer", async (t) => {
  const pool = await migrated(t);
  const ids = [await put(pool, A), await put(pool, A), await put(pool, A)];
  const d = randomUUID();
  for (const id of ids) {
    const got = await claimDelivery(pool, A, d);
    assert.equal(got?.deliveryId, id);
    assert.equal((got?.delivery as { deliveryId: string }).deliveryId, id);
  }
  assert.equal(await claimDelivery(pool, A, d), undefined);
});

test("Abholen: ohne Lieferungen undefined", async (t) => {
  const pool = await migrated(t);
  assert.equal(await claimDelivery(pool, A, randomUUID()), undefined);
});

test("Abholen: dieselbe Lieferung nie an zwei Geraete", async (t) => {
  const pool = await migrated(t);
  const first = await put(pool, A);
  const second = await put(pool, A);
  assert.equal((await claimDelivery(pool, A, randomUUID()))?.deliveryId, first);
  assert.equal((await claimDelivery(pool, A, randomUUID()))?.deliveryId, second);
  assert.equal(await claimDelivery(pool, A, randomUUID()), undefined);
});

test("Rueckholung: nach mehr als 10 min ohne Ergebnis wieder abholbar, davor nicht", async (t) => {
  const pool = await migrated(t);
  const id = await put(pool, A);
  const t0 = new Date();
  assert.equal((await claimDelivery(pool, A, randomUUID(), t0))?.deliveryId, id);
  assert.equal(await claimDelivery(pool, A, randomUUID(), new Date(t0.getTime() + 9 * 60_000)), undefined);
  const other = randomUUID();
  assert.equal((await claimDelivery(pool, A, other, new Date(t0.getTime() + 11 * 60_000)))?.deliveryId, id);
});

test("Rueckholung: das neue Geraet haelt die Lieferung, das alte bekommt conflict", async (t) => {
  const pool = await migrated(t);
  const id = await put(pool, A);
  const old = randomUUID();
  const neu = randomUUID();
  const t0 = new Date();
  await claimDelivery(pool, A, old, t0);
  await claimDelivery(pool, A, neu, new Date(t0.getTime() + 11 * 60_000));
  assert.equal(await reportResult(pool, A, old, { deliveryId: id, outcome: "accepted" }), "conflict");
  assert.equal(await reportResult(pool, A, neu, { deliveryId: id, outcome: "accepted" }), "ok");
});

test("Parallel: 5 Geraete, 3 Lieferungen, jede hoechstens einmal", async (t) => {
  const pool = await migrated(t);
  const ids = [await put(pool, A), await put(pool, A), await put(pool, A)];
  const results = await Promise.all(Array.from({ length: 5 }, () => claimDelivery(pool, A, randomUUID())));
  const got = results.filter((r) => r !== undefined).map((r) => r!.deliveryId);
  assert.equal(new Set(got).size, got.length, "keine doppelt");
  assert.equal(got.length, 3);
  assert.deepEqual([...got].sort(), [...ids].sort());
});

test("Ergebnis: accepted vom haltenden Geraet, Zustand accepted, zweites Ergebnis conflict", async (t) => {
  const pool = await migrated(t);
  const id = await put(pool, A);
  const d = randomUUID();
  await claimDelivery(pool, A, d);
  assert.equal(await reportResult(pool, A, d, { deliveryId: id, outcome: "accepted" }), "ok");
  const [row] = await listDeliveries(pool, A, { deliveryId: id });
  assert.equal(row.state, "accepted");
  assert.ok(row.decidedAt);
  assert.equal(await reportResult(pool, A, d, { deliveryId: id, outcome: "accepted" }), "conflict");
  assert.equal(await reportResult(pool, A, d, { deliveryId: id, outcome: "rejected", errors: errs }), "conflict");
  assert.equal((await listDeliveries(pool, A, { deliveryId: id }))[0].state, "accepted");
});

test("Ergebnis: rejected speichert die Fehler", async (t) => {
  const pool = await migrated(t);
  const id = await put(pool, A);
  const d = randomUUID();
  await claimDelivery(pool, A, d);
  assert.equal(await reportResult(pool, A, d, { deliveryId: id, outcome: "rejected", errors: errs }), "ok");
  const [row] = await listDeliveries(pool, A, { deliveryId: id });
  assert.equal(row.state, "rejected");
  assert.deepEqual(row.errors, errs);
});

test("Ergebnis: fremdes Geraet bekommt conflict, Zustand bleibt claimed", async (t) => {
  const pool = await migrated(t);
  const id = await put(pool, A);
  await claimDelivery(pool, A, randomUUID());
  assert.equal(await reportResult(pool, A, randomUUID(), { deliveryId: id, outcome: "accepted" }), "conflict");
  assert.equal((await listDeliveries(pool, A, { deliveryId: id }))[0].state, "claimed");
});

test("Ergebnis: nicht abgeholte oder unbekannte Lieferung gibt conflict", async (t) => {
  const pool = await migrated(t);
  const id = await put(pool, A);
  assert.equal(await reportResult(pool, A, randomUUID(), { deliveryId: id, outcome: "accepted" }), "conflict");
  assert.equal(await reportResult(pool, A, randomUUID(), { deliveryId: randomUUID(), outcome: "accepted" }), "conflict");
});

test("Verlauf: delivery_events enthaelt waiting, claimed, accepted mit Geraet beim Abholen", async (t) => {
  const pool = await migrated(t);
  const id = await put(pool, A);
  const d = randomUUID();
  await claimDelivery(pool, A, d);
  await reportResult(pool, A, d, { deliveryId: id, outcome: "accepted" });
  const rows = (await pool.query("SELECT state, device, at FROM delivery_events WHERE delivery_id = $1 ORDER BY at, state", [id])).rows;
  const states = rows.map((r) => r.state);
  for (const s of ["waiting", "claimed", "accepted"]) assert.ok(states.includes(s), `Ereignis ${s} fehlt: ${states}`);
  assert.equal(rows.find((r) => r.state === "claimed").device, d);
});

test("Ueberholen: aus waiting true, Zustand superseded, nie abholbar", async (t) => {
  const pool = await migrated(t);
  const first = await put(pool, A);
  const second = await put(pool, A);
  assert.equal(await supersede(pool, A, first), true);
  assert.equal((await claimDelivery(pool, A, randomUUID()))?.deliveryId, second);
  assert.equal(await claimDelivery(pool, A, randomUUID()), undefined);
  const row = (await listDeliveries(pool, A)).find((r) => r.deliveryId === first);
  assert.equal(row?.state, "superseded");
});

test("Ueberholen: aus claimed, accepted, rejected und bei unbekannter Kennung false", async (t) => {
  const pool = await migrated(t);
  const c = await put(pool, A);
  const acc = await put(pool, A);
  const rej = await put(pool, A);
  const d = randomUUID();
  await claimDelivery(pool, A, d);
  await claimDelivery(pool, A, d);
  await claimDelivery(pool, A, d);
  await reportResult(pool, A, d, { deliveryId: acc, outcome: "accepted" });
  await reportResult(pool, A, d, { deliveryId: rej, outcome: "rejected", errors: errs });
  assert.equal(await supersede(pool, A, c), false);
  assert.equal(await supersede(pool, A, acc), false);
  assert.equal(await supersede(pool, A, rej), false);
  assert.equal(await supersede(pool, A, randomUUID()), false);
});

test("Ueberholen: zweites Mal false", async (t) => {
  const pool = await migrated(t);
  const id = await put(pool, A);
  assert.equal(await supersede(pool, A, id), true);
  assert.equal(await supersede(pool, A, id), false);
});

test("Liste: Zustand, Zeitpunkte, Dokument; Filter und Limit", async (t) => {
  const pool = await migrated(t);
  const ids = [await put(pool, A), await put(pool, A), await put(pool, A)];
  await claimDelivery(pool, A, randomUUID());
  const all = await listDeliveries(pool, A);
  assert.equal(all.length, 3);
  const byId = new Map(all.map((r) => [r.deliveryId, r]));
  assert.equal(byId.get(ids[0])!.state, "claimed");
  assert.ok(byId.get(ids[0])!.claimedAt);
  assert.equal(byId.get(ids[1])!.state, "waiting");
  assert.equal(byId.get(ids[1])!.claimedAt, undefined);
  assert.ok(byId.get(ids[1])!.createdAt);
  assert.equal((byId.get(ids[1])!.delivery as { deliveryId: string }).deliveryId, ids[1]);
  assert.equal((await listDeliveries(pool, A, { deliveryId: ids[2] })).length, 1);
  assert.equal((await listDeliveries(pool, A, { limit: 2 })).length, 2);
});

test("Konten getrennt: fremde Lieferung nicht abholbar, meldbar, sichtbar oder ueberholbar", async (t) => {
  const pool = await migrated(t);
  const id = await put(pool, A);
  assert.equal(await claimDelivery(pool, B, randomUUID()), undefined);
  assert.deepEqual(await listDeliveries(pool, B), []);
  assert.deepEqual(await listDeliveries(pool, B, { deliveryId: id }), []);
  assert.equal(await supersede(pool, B, id), false);
  const d = randomUUID();
  assert.equal((await claimDelivery(pool, A, d))?.deliveryId, id);
  assert.equal(await reportResult(pool, B, d, { deliveryId: id, outcome: "accepted" }), "conflict");
  assert.equal((await listDeliveries(pool, A, { deliveryId: id }))[0].state, "claimed");
});

test("Konten getrennt: Rueckholung gilt nicht fuer fremdes Konto", async (t) => {
  const pool = await migrated(t);
  await put(pool, A);
  const t0 = new Date();
  await claimDelivery(pool, A, randomUUID(), t0);
  assert.equal(await claimDelivery(pool, B, randomUUID(), new Date(t0.getTime() + 11 * 60_000)), undefined);
});
