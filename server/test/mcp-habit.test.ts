// B6a Stufenplan, Tagesziel, neue Gewohnheit (Issue #64), Teil Dienst: TDD RED. Spec: openspec/specs/integrations/claude-gewohnheit-stufenplan.md Abschnitt 4
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
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const HOUR = 3_600_000;
const DAY = 24 * HOUR;
const NOW = Date.now();
const day = (offset: number) => new Date(NOW + offset * DAY).toISOString().slice(0, 10);
const ago = (ms: number) => new Date(NOW - ms).toISOString();

const fullV2 = (): Doc => JSON.parse(readFileSync(join(root, "Contracts", "transcript", "v2", "valid", "full.json"), "utf8")).transcript;

async function migrated(t: T): Promise<pg.Pool> {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  return pool;
}

const OWN_TRACKER = "own.0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d";
const NOALC: Doc = {
  id: "builtin.noalc", name: "NoAlc", symbol: "🍷", type: "saboteur", mode: "levels", origin: "builtin",
  levels: [{ name: "Steady", icon: "💧", effect: "success" }, { name: "Easy", icon: "⚡", effect: "needsGrace" }, { name: "Wild", icon: "💥", effect: "breaksStreak" }],
};
const ownTracker = (): Doc => ({ id: OWN_TRACKER, name: "Dankbarkeit", symbol: "🙏", type: "good", mode: "yesNo", origin: "own" });
const tid = (n: number) => `claude.wasser${n}-n5r7t2`;
// Claude-Tracker in der Abschrift, ausgeliefert vor deliveredMsAgo Millisekunden
const claudeTracker = (n: number, deliveredMsAgo: number, over: Doc = {}): Doc => ({
  id: tid(n), name: `Wasser ${n}`, symbol: "💧", type: "good", mode: "counter", dailyGoal: 6, origin: "claude", revision: 1, state: "active",
  deliveredAt: ago(deliveredMsAgo), ...over,
});

const impulseText = (n: number) => `Tag ${n}: Achte heute einmal bewusst auf deinen Atem.`;
const impulseStage = (days: number): Doc => ({
  days, content: { type: "impulses", impulses: Array.from({ length: days }, (_, i) => ({ text: impulseText(i + 1), moment: "day" })) },
});
const goalStage = (days: number, goal: Doc = { type: "meditation", minutes: 10 }): Doc => ({ days, content: { type: "goal", goal } });
const cid = (n: number) => `claude.stufenplan${n}-q7m2xk`;
// Challenge nur aus einer Ziel-Stufe in der Abschrift: beginnt startOffset Tage vor/nach heute
const goalEntry = (n: number, startOffset: number, days: number, over: Doc = {}): Doc => ({
  id: cid(n), title: `Stufenplan ${n}`, symbol: "💧", startDate: day(startOffset),
  stages: [goalStage(days, { type: "tracker", trackerId: "builtin.noalc" })],
  origin: "claude", revision: 1, state: "active", why: "Neue Gewohnheit.", deliveredAt: ago(DAY),
  progress: { days: [], goals: [{ stage: 0, met: 0, of: 1 }], extendedBy: 0 }, ...over,
});

async function withTranscript(pool: pg.Pool, trackers: Doc[], challenges: Doc[] = []): Promise<void> {
  const doc = fullV2();
  doc.generatedAt = new Date(NOW).toISOString();
  doc.trackers = trackers;
  doc.challenges = challenges;
  assert.equal(await putTranscript(pool, HENNING, doc), "stored");
}
async function stored(t: T, trackers: Doc[], challenges: Doc[] = []) {
  const pool = await migrated(t);
  await withTranscript(pool, trackers, challenges);
  return { pool, client: await connect(t, pool, HENNING) };
}

const trackerInput = (over: Doc = {}): Doc => ({ name: "Wasser", symbol: "💧", type: "good", mode: "counter", dailyGoal: 6, why: "Mehr trinken.", ...over });
const LEVELS = [{ name: "Ruhig", icon: "✅", effect: "success" }, { name: "Unruhig", icon: "⚠️", effect: "needsGrace" }, { name: "Wild", icon: "❌", effect: "breaksStreak" }];
const challengeInput = (over: Doc = {}): Doc => ({ title: "Stufenplan", symbol: "💧", startDate: day(1), stages: [goalStage(7)], why: "Schritt für Schritt.", ...over });
const fieldsOf = (doc: Doc): Doc => { const { why, package: pkg, ...rest } = doc; return rest; };
const count = async (pool: pg.Pool) => (await listDeliveries(pool, HENNING)).length;
const deliveryOf = async (pool: pg.Pool, deliveryId: string): Promise<Doc> =>
  (await listDeliveries(pool, HENNING)).find((r) => (r.delivery as Doc).deliveryId === deliveryId)!.delivery as Doc;

// 1. tracker_create

test("Werkzeugliste: tracker_create ist da und nicht schreibgeschützt", async (t) => {
  const tools = (await (await connect(t, await migrated(t), HENNING)).listTools()).tools;
  const tool = tools.find((x) => x.name === "tracker_create");
  assert.ok(tool, "tracker_create fehlt");
  assert.equal(tool.annotations?.readOnlyHint, false);
});

test("tracker_create ohne Konto: „kein Konto“", async (t) => {
  const { text, isError } = await call(await connect(t, await migrated(t)), "tracker_create", trackerInput());
  assert.equal(isError, true);
  assert.match(text, /kein Konto/);
});

const VALID_TRACKERS: Array<[string, Doc]> = [
  ["Zähler mit Tagesziel", {}],
  ["Zähler ohne Tagesziel", { dailyGoal: undefined }],
  ["Ja/Nein", { mode: "yesNo", dailyGoal: undefined }],
  ["Saboteur Bewusstsein", { type: "saboteur", mode: "awareness", dailyGoal: undefined }],
  ["Saboteur Vermeiden", { type: "saboteur", mode: "avoidance", dailyGoal: undefined }],
  ["Stufen mit Joker und Tagesbeginn", { mode: "levels", dailyGoal: undefined, levels: LEVELS, joker: { earnEveryDays: 7, maxOnHand: 3 }, dayStartHour: 4 }],
  ["Stufen ohne Joker", { type: "saboteur", mode: "levels", dailyGoal: undefined, levels: LEVELS }],
];
for (const [name, over] of VALID_TRACKERS) {
  test(`tracker_create: ${name} -> Antwort und gespeicherte Lieferung besteht den Prüfer`, async (t) => {
    const pool = await migrated(t);
    const body = trackerInput(over);
    for (const k of Object.keys(body)) if (body[k] === undefined) delete body[k];
    const answer = await json(await connect(t, pool, HENNING), "tracker_create", body);
    assert.match(answer.deliveryId, UUID);
    assert.equal(typeof answer.itemId, "string");
    assert.ok((answer.itemId as string).startsWith("claude."));
    assert.equal(answer.revision, 1);
    assert.equal(answer.state, "waiting");
    const doc = await deliveryOf(pool, answer.deliveryId);
    assert.deepEqual(validateDelivery(doc).errors, []);
    assert.equal(doc.items.length, 1);
    const item = doc.items[0];
    assert.equal(item.kind, "tracker");
    assert.equal(item.itemId, answer.itemId);
    assert.equal(doc.why, body.why);
    const { why, ...fields } = body;
    for (const [k, v] of Object.entries(fields)) assert.deepEqual(item[k], v, k);
  });
}

const TRACKER_REJECTIONS: Array<[string, Doc, string]> = [
  ["Name leer", { name: "" }, "/items/0/name"],
  ["Name 41 Zeichen", { name: "x".repeat(41) }, "/items/0/name"],
  ["type unbekannt", { type: "neutral" }, "/items/0/type"],
  ["mode passt nicht zum Typ", { mode: "awareness", dailyGoal: undefined }, "/items/0/mode"],
  ["dailyGoal 0", { dailyGoal: 0 }, "/items/0/dailyGoal"],
  ["dailyGoal 101", { dailyGoal: 101 }, "/items/0/dailyGoal"],
  ["dailyGoal bei yesNo", { mode: "yesNo" }, "/items/0/dailyGoal"],
  ["levels fehlen bei mode levels", { mode: "levels", dailyGoal: undefined }, "/items/0/levels"],
  ["levels ohne Erfolgsstufe", { mode: "levels", dailyGoal: undefined, levels: [LEVELS[1], LEVELS[2]] }, "/items/0/levels"],
  ["nur eine Stufe", { mode: "levels", dailyGoal: undefined, levels: [LEVELS[0]] }, "/items/0/levels"],
  ["sechs Stufen", { mode: "levels", dailyGoal: undefined, levels: [...LEVELS, ...LEVELS.map((l, i) => ({ ...l, name: `Z${i}` }))] }, "/items/0/levels"],
  ["Stufenname doppelt", { mode: "levels", dailyGoal: undefined, levels: [LEVELS[0], { ...LEVELS[1], name: "ruhig" }] }, "/items/0/levels/1/name"],
  ["joker ohne levels", { joker: { earnEveryDays: 7, maxOnHand: 3 } }, "/items/0/joker"],
  ["joker earnEveryDays 31", { mode: "levels", dailyGoal: undefined, levels: LEVELS, joker: { earnEveryDays: 31, maxOnHand: 3 } }, "/items/0/joker/earnEveryDays"],
  ["joker maxOnHand 11", { mode: "levels", dailyGoal: undefined, levels: LEVELS, joker: { earnEveryDays: 7, maxOnHand: 11 } }, "/items/0/joker/maxOnHand"],
  ["dayStartHour 24", { mode: "levels", dailyGoal: undefined, levels: LEVELS, dayStartHour: 24 }, "/items/0/dayStartHour"],
  ["dayStartHour ohne levels", { dayStartHour: 4 }, "/items/0/dayStartHour"],
];
for (const [name, over, path] of TRACKER_REJECTIONS) {
  test(`tracker_create: ${name} -> isError mit Pfad ${path}, nichts gespeichert`, async (t) => {
    const pool = await migrated(t);
    const body = trackerInput(over);
    for (const k of Object.keys(body)) if (body[k] === undefined) delete body[k];
    const { text, isError } = await call(await connect(t, pool, HENNING), "tracker_create", body);
    assert.equal(isError, true, text);
    assert.ok(text.includes(path), text);
    assert.equal(await count(pool), 0);
  });
}

for (const [field, value] of Object.entries({ kind: "tracker", itemId: "claude.eigen-abcdef", revision: 5 })) {
  test(`tracker_create mit Dienstfeld ${field} -> isError „weglassen“, nichts gespeichert`, async (t) => {
    const pool = await migrated(t);
    const { text, isError } = await call(await connect(t, pool, HENNING), "tracker_create", trackerInput({ [field]: value }));
    assert.equal(isError, true, text);
    assert.ok(text.includes(field), text);
    assert.match(text, /weglassen/);
    assert.equal(await count(pool), 0);
  });
}

test("tracker_create mit Feld healthKit (keine Kopplung an Apple Health) -> isError, nichts gespeichert", async (t) => {
  const pool = await migrated(t);
  const { text, isError } = await call(await connect(t, pool, HENNING), "tracker_create", trackerInput({ healthKit: true }));
  assert.equal(isError, true, text);
  assert.equal(await count(pool), 0);
});

// 2. item_update nur für Claude-Tracker

test("item_update: Claude-Tracker aus der Abschrift -> Revision 2 als gültige Lieferung", async (t) => {
  const { pool, client } = await stored(t, [NOALC, ownTracker(), claudeTracker(1, 3 * DAY)]);
  const fields = fieldsOf(trackerInput({ name: "Wasser neu", dailyGoal: 8 }));
  const answer = await json(client, "item_update", { itemId: tid(1), basedOnRevision: 1, why: "Mehr.", fields });
  assert.equal(answer.revision, 2);
  const doc = await deliveryOf(pool, answer.deliveryId);
  assert.deepEqual(validateDelivery(doc).errors, []);
  assert.equal(doc.items[0].kind, "tracker");
  assert.equal(doc.items[0].name, "Wasser neu");
  assert.equal(doc.items[0].dailyGoal, 8);
});

test("item_update: wartende tracker_create-Lieferung -> Revision 2 als gültige Lieferung", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, HENNING);
  const first = await json(client, "tracker_create", trackerInput());
  const updated = await json(client, "item_update", { itemId: first.itemId, basedOnRevision: 1, why: "Anders.", fields: fieldsOf(trackerInput({ name: "Trinken" })) });
  assert.equal(updated.revision, 2);
  const doc = await deliveryOf(pool, updated.deliveryId);
  assert.equal(doc.items[0].name, "Trinken");
  assert.deepEqual(validateDelivery(doc).errors, []);
});

test("item_update: eigener und eingebauter Tracker -> isError „Nur eigene“, nichts gespeichert", async (t) => {
  const { pool, client } = await stored(t, [NOALC, ownTracker()]);
  const fields = fieldsOf(trackerInput());
  for (const itemId of [OWN_TRACKER, "builtin.noalc"]) {
    const { text, isError } = await call(client, "item_update", { itemId, basedOnRevision: 1, why: "x", fields });
    assert.equal(isError, true, itemId);
    assert.match(text, /Nur eigene/, itemId);
  }
  assert.equal(await count(pool), 0);
});

// 3. challenge_create mit Stufen und Zielen

test("challenge_create: mehrere Stufen mit Impuls- und Ziel-Stufen -> gültige Lieferung", async (t) => {
  const { pool, client } = await stored(t, [NOALC]);
  const stages = [impulseStage(3), goalStage(7, { type: "meditation", minutes: 10 }), goalStage(7, { type: "workout", minutes: 20 })];
  const answer = await json(client, "challenge_create", challengeInput({ stages }));
  assert.match(answer.deliveryId, UUID);
  assert.equal(answer.state, "waiting");
  const doc = await deliveryOf(pool, answer.deliveryId);
  assert.deepEqual(validateDelivery(doc, { knownTrackers: ["builtin.noalc"] } as unknown as Parameters<typeof validateDelivery>[1]).errors, []);
  assert.deepEqual(doc.items[0].stages, stages);
});

test("challenge_create: sechs Stufen gültig, sieben abgelehnt mit Pfad /items/0/stages", async (t) => {
  const { pool, client } = await stored(t, [NOALC]);
  const six = await call(client, "challenge_create", challengeInput({ stages: Array.from({ length: 6 }, () => goalStage(5)) }));
  assert.equal(six.isError, false, six.text);
  const before = await count(pool);
  const seven = await call(client, "challenge_create", challengeInput({ stages: Array.from({ length: 7 }, () => goalStage(5)) }));
  assert.equal(seven.isError, true, seven.text);
  assert.ok(seven.text.includes("/items/0/stages"), seven.text);
  assert.equal(await count(pool), before);
});

test("challenge_create: Ziel-Stufe auf Tracker aus der Abschrift (Claude, eigen, builtin.noalc)", async (t) => {
  const { pool, client } = await stored(t, [NOALC, ownTracker(), claudeTracker(1, 3 * DAY)]);
  for (const trackerId of [tid(1), OWN_TRACKER, "builtin.noalc"]) {
    const { text, isError } = await call(client, "challenge_create", challengeInput({ stages: [goalStage(7, { type: "tracker", trackerId })] }));
    assert.equal(isError, false, `${trackerId}: ${text}`);
  }
  assert.equal(await count(pool), 3);
});

test("challenge_create: Ziel-Stufe auf Tracker einer wartenden tracker_create-Lieferung", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, HENNING);
  const created = await json(client, "tracker_create", trackerInput());
  const answer = await json(client, "challenge_create", challengeInput({ stages: [goalStage(7, { type: "tracker", trackerId: created.itemId })] }));
  const doc = await deliveryOf(pool, answer.deliveryId);
  assert.deepEqual(validateDelivery(doc, { knownTrackers: [created.itemId] } as unknown as Parameters<typeof validateDelivery>[1]).errors, []);
});

test("challenge_create: Ziel-Stufe auf unbekannten Tracker -> isError mit Pfad, nichts gespeichert", async (t) => {
  const { pool, client } = await stored(t, [NOALC]);
  const path = "/items/0/stages/0/content/goal/trackerId";
  const { text, isError } = await call(client, "challenge_create", challengeInput({ stages: [goalStage(7, { type: "tracker", trackerId: "own.11111111-2222-3333-4444-555555555555" })] }));
  assert.equal(isError, true, text);
  assert.ok(text.includes(path), text);
  assert.equal(await count(pool), 0);
});

const CHALLENGE_REJECTIONS: Array<[string, Doc, string]> = [
  ["Summe der Tage 91", { stages: [goalStage(45), goalStage(46)] }, "/items/0"],
  ["Ziel mit 181 Minuten", { stages: [goalStage(7, { type: "workout", minutes: 181 })] }, "/items/0/stages/0/content/goal/minutes"],
  ["Ziel mit 0 Minuten", { stages: [goalStage(7, { type: "meditation", minutes: 0 })] }, "/items/0/stages/0/content/goal/minutes"],
  ["Ziel-Art unbekannt", { stages: [goalStage(7, { type: "yoga", minutes: 10 })] }, "/items/0/stages/0/content/goal/type"],
  ["Ziel-Stufe mit Impulsliste", { stages: [{ days: 3, content: { type: "goal", goal: { type: "meditation", minutes: 10 }, impulses: [] } }] }, "/items/0/stages/0/content/impulses"],
  ["Ziel-Stufe ohne goal", { stages: [{ days: 3, content: { type: "goal" } }] }, "/items/0/stages/0/content/goal"],
];
for (const [name, over, path] of CHALLENGE_REJECTIONS) {
  test(`challenge_create: ${name} -> isError mit Pfad ${path}, nichts gespeichert`, async (t) => {
    const { pool, client } = await stored(t, [NOALC]);
    const { text, isError } = await call(client, "challenge_create", challengeInput(over));
    assert.equal(isError, true, text);
    assert.ok(text.includes(path), text);
    assert.equal(await count(pool), 0);
  });
}

// 4. Lesen

test("catalog kind tracker: Zeilen {id, name, origin, type, mode}", async (t) => {
  const { client } = await stored(t, [NOALC, ownTracker(), claudeTracker(1, 3 * DAY)]);
  const doc = await json(client, "catalog", { kind: "tracker" });
  assert.equal(doc.kind, "tracker");
  assert.equal(doc.items.length, 3);
  const row = (id: string) => doc.items.find((x: Doc) => x.id === id);
  assert.deepEqual(row("builtin.noalc"), { id: "builtin.noalc", name: "NoAlc", origin: "builtin", type: "saboteur", mode: "levels" });
  assert.deepEqual(row(OWN_TRACKER), { id: OWN_TRACKER, name: "Dankbarkeit", origin: "own", type: "good", mode: "yesNo" });
  assert.deepEqual(row(tid(1)), { id: tid(1), name: "Wasser 1", origin: "claude", type: "good", mode: "counter" });
});

test("show: zeigt einen Tracker mit Stufen bzw. Tagesziel", async (t) => {
  const { client } = await stored(t, [NOALC, claudeTracker(1, 3 * DAY)]);
  const claude = await json(client, "show", { id: tid(1) });
  assert.equal(claude.kind, "tracker");
  assert.equal(claude.item.name, "Wasser 1");
  assert.equal(claude.item.mode, "counter");
  assert.equal(claude.item.dailyGoal, 6);
  assert.equal(claude.item.revision, 1);
  const noalc = await json(client, "show", { id: "builtin.noalc" });
  assert.equal(noalc.kind, "tracker");
  assert.equal(noalc.item.levels.length, 3);
});

test("forms: Art tracker mit Grenzen und Werten, Art challenge mit Ziel-Arten", async (t) => {
  const client = await connect(t, await migrated(t), HENNING);
  const all = await call(client, "forms");
  assert.equal(all.isError, false);
  assert.ok(all.text.includes("tracker"), "forms ohne tracker");
  const only = await call(client, "forms", { kind: "tracker" });
  assert.equal(only.isError, false, only.text);
  const words = ["name", "symbol", "type", "good", "saboteur", "mode", "counter", "yesNo", "awareness", "avoidance", "levels", "dailyGoal",
    "effect", "success", "needsGrace", "breaksStreak", "joker", "earnEveryDays", "maxOnHand", "dayStartHour", "100", "30", "10", "23", "40", "20"];
  for (const word of words) assert.ok(only.text.includes(word), `forms tracker ohne „${word}“`);
  assert.ok(!only.text.includes("inhaleSeconds"));
  const ch = await call(client, "forms", { kind: "challenge" });
  assert.equal(ch.isError, false, ch.text);
  for (const word of ["goal", "meditation", "workout", "tracker", "trackerId", "minutes", "180", "builtin.noalc"]) {
    assert.ok(ch.text.includes(word), `forms challenge ohne „${word}“`);
  }
});

test("overview: counts.tracker zählt Tracker je Herkunft", async (t) => {
  const { client } = await stored(t, [NOALC, ownTracker(), claudeTracker(1, 3 * DAY), claudeTracker(2, 4 * DAY, { state: "withdrawn" })]);
  const doc = await json(client, "overview");
  assert.equal(doc.counts.tracker.builtin, 1, JSON.stringify(doc.counts));
  assert.equal(doc.counts.tracker.own, 1);
  assert.equal(doc.counts.tracker.claude, 2);
});

// 5. Im Aufbau

const buildingOf = async (client: Awaited<ReturnType<typeof connect>>): Promise<Doc> => (await json(client, "overview")).building;
const limitMessages = (doc: Doc): Doc[] => doc.messages.filter((m: Doc) => m.kind === "building_limit");

test("overview.building: ohne Gewohnheiten count 0, limit 2, keine Meldung", async (t) => {
  const { client } = await stored(t, [NOALC, ownTracker()]);
  const doc = await json(client, "overview");
  assert.deepEqual(doc.building, { count: 0, limit: 2, items: [] });
  assert.deepEqual(limitMessages(doc), []);
});

test("overview.building: Claude-Tracker mit deliveredAt vor höchstens 66 Tagen zählt, mit Eintrag {id, name, kind, since}", async (t) => {
  const { client } = await stored(t, [NOALC, claudeTracker(1, 66 * DAY - HOUR)]);
  const building = await buildingOf(client);
  assert.equal(building.count, 1);
  assert.equal(building.limit, 2);
  assert.equal(building.items.length, 1);
  const item = building.items[0];
  assert.equal(item.id, tid(1));
  assert.equal(item.name, "Wasser 1");
  assert.equal(item.kind, "tracker");
  assert.equal(typeof item.since, "string");
  assert.ok(!Number.isNaN(Date.parse(item.since)), item.since);
});

test("overview.building: Tracker mit deliveredAt vor 67 Tagen zählt nicht", async (t) => {
  const { client } = await stored(t, [NOALC, claudeTracker(1, 67 * DAY + HOUR)]);
  assert.deepEqual(await buildingOf(client), { count: 0, limit: 2, items: [] });
});

test("overview.building: zurückgenommener Claude-Tracker zählt nicht", async (t) => {
  const { client } = await stored(t, [claudeTracker(1, 3 * DAY, { state: "withdrawn" })]);
  assert.equal((await buildingOf(client)).count, 0);
});

test("overview.building: eigene und eingebaute Tracker zählen nicht", async (t) => {
  const { client } = await stored(t, [NOALC, ownTracker()]);
  assert.equal((await buildingOf(client)).count, 0);
});

test("overview.building: aktive Claude-Challenge mit Ziel-Stufe, nicht beendet, zählt (kind challenge)", async (t) => {
  const { client } = await stored(t, [NOALC], [goalEntry(1, -10, 30)]);
  const building = await buildingOf(client);
  assert.equal(building.count, 1);
  assert.equal(building.items[0].id, cid(1));
  assert.equal(building.items[0].name, "Stufenplan 1");
  assert.equal(building.items[0].kind, "challenge");
});

test("overview.building: beendete Challenge mit Ziel-Stufe zählt nicht", async (t) => {
  // Start vor 40 Tagen, 30 Tage: Ende vor 11 Tagen
  const { client } = await stored(t, [NOALC], [goalEntry(1, -40, 30)]);
  assert.equal((await buildingOf(client)).count, 0);
});

test("overview.building: Challenge nur mit Impuls-Stufen zählt nicht", async (t) => {
  const impulseOnly = { ...goalEntry(1, -2, 7), stages: [impulseStage(7)], progress: { days: [{ date: day(-2), status: "done" }, { date: day(-1), status: "done" }, { date: day(0), status: "open" }], extendedBy: 0 } };
  const { client } = await stored(t, [NOALC], [impulseOnly]);
  assert.equal((await buildingOf(client)).count, 0);
});

test("overview.building: zurückgezogene Challenge mit Ziel-Stufe zählt nicht", async (t) => {
  const { client } = await stored(t, [NOALC], [goalEntry(1, -10, 30, { state: "withdrawn" })]);
  assert.equal((await buildingOf(client)).count, 0);
});

test("overview.building: Tracker und Challenge zählen zusammen", async (t) => {
  const { client } = await stored(t, [NOALC, claudeTracker(1, 3 * DAY)], [goalEntry(1, -10, 30)]);
  const building = await buildingOf(client);
  assert.equal(building.count, 2);
  assert.deepEqual(building.items.map((i: Doc) => i.id).sort(), [cid(1), tid(1)].sort());
});

test("overview: building_limit erst ab zwei, bei einer Gewohnheit keine Meldung", async (t) => {
  const one = await stored(t, [claudeTracker(1, 3 * DAY)]);
  assert.deepEqual(limitMessages(await json(one.client, "overview")), []);
  const two = await stored(t, [claudeTracker(1, 3 * DAY), claudeTracker(2, 4 * DAY)]);
  const messages = limitMessages(await json(two.client, "overview"));
  assert.equal(messages.length, 1);
  assert.equal(typeof messages[0].text, "string");
  assert.ok(messages[0].text.length > 0);
});

test("overview: bei drei Gewohnheiten weiterhin eine Meldung building_limit, count 3", async (t) => {
  const { client } = await stored(t, [claudeTracker(1, 3 * DAY), claudeTracker(2, 4 * DAY), claudeTracker(3, 5 * DAY)]);
  const doc = await json(client, "overview");
  assert.equal(doc.building.count, 3);
  assert.equal(limitMessages(doc).length, 1);
});

test("Keine Sperre: bei zwei laufenden Gewohnheiten werden tracker_create und challenge_create trotzdem angenommen", async (t) => {
  const { pool, client } = await stored(t, [NOALC, claudeTracker(1, 3 * DAY), claudeTracker(2, 4 * DAY)]);
  const tracker = await call(client, "tracker_create", trackerInput());
  assert.equal(tracker.isError, false, tracker.text);
  const challenge = await call(client, "challenge_create", challengeInput({ stages: [goalStage(7, { type: "tracker", trackerId: "builtin.noalc" })] }));
  assert.equal(challenge.isError, false, challenge.text);
  assert.equal(await count(pool), 2);
});

test("Server-Anweisung: Grundregel zu höchstens zwei neuen Gewohnheiten und tracker_create", async (t) => {
  const text = (await connect(t, await migrated(t), HENNING)).getInstructions() ?? "";
  for (const word of ["höchstens zwei", "ausdrücklich mehr", "einmal", "overview.building", "tracker_create"]) {
    assert.ok(text.includes(word), `Anweisung ohne „${word}“`);
  }
});

// 6. history.challenges.goals

test("history.challenges: goals wie in der Abschrift (Ziel-Stufe, nur Summe)", async (t) => {
  const entry: Doc = {
    ...goalEntry(1, -12, 30),
    stages: [impulseStage(3), goalStage(27, { type: "tracker", trackerId: "builtin.noalc" })],
    progress: {
      days: [0, 1, 2].map((i) => ({ date: day(-12 + i), status: "done" })),
      goals: [{ stage: 1, met: 8, of: 9 }],
      extendedBy: 0,
    },
  };
  const { client } = await stored(t, [NOALC], [entry]);
  const doc = await json(client, "history");
  assert.equal(doc.challenges.length, 1);
  assert.deepEqual(doc.challenges[0].goals, [{ stage: 1, met: 8, of: 9 }]);
  assert.equal(doc.challenges[0].id, cid(1));
  assert.equal(doc.challenges[0].totalDays, 30);
});
