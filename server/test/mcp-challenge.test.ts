// B5a Einfache Impuls-Challenge (Issue #62), Teil Dienst: TDD RED. Spec: openspec/specs/integrations/claude-challenge.md Abschnitt 4
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
const DAY = 24 * 3_600_000;
const NOW = Date.now();
// UTC-Kalendertag relativ zu "jetzt" (offset < 0: Vergangenheit)
const day = (offset: number) => new Date(NOW + offset * DAY).toISOString().slice(0, 10);

const fullV2 = (): Doc => JSON.parse(readFileSync(join(root, "Contracts", "transcript", "v2", "valid", "full.json"), "utf8")).transcript;

async function migrated(t: T): Promise<pg.Pool> {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  return pool;
}

const impulseText = (n: number) => `Tag ${n}: Achte heute einmal bewusst auf deinen Atem.`;
const impulses = (days: number): Doc[] => Array.from({ length: days }, (_, i) => ({ text: impulseText(i + 1), moment: i % 2 === 0 ? "day" : "evening", question: "Was ist dir aufgefallen?" }));
const stage = (days: number): Doc => ({ days, content: { type: "impulses", impulses: impulses(days) } });
const input = (over: Doc = {}): Doc => ({
  title: "Atem-Woche", symbol: "🧘", description: "Eine Woche Atem.", startDate: day(1), stages: [stage(7)], why: "Mehr Ruhe.", ...over,
});
const fieldsOf = (doc: Doc): Doc => { const { why, package: pkg, ...rest } = doc; return rest; };
const count = async (pool: pg.Pool) => (await listDeliveries(pool, HENNING)).length;

type Status = "done" | "skipped" | "made_up" | "open";
const cid = (n: number) => `claude.atem-woche${n}-q7m2xk`;
// Challenge in der Abschrift: beginnt startOffset Tage vor/nach heute, Verlauf je Eintrag in statuses (Notizen je Datum in notes)
function entry(n: number, startOffset: number, totalDays: number, statuses: Status[], over: Doc = {}, notes: Record<number, string> = {}): Doc {
  return {
    id: cid(n), title: `Atem-Woche ${n}`, symbol: "🧘", startDate: day(startOffset), stages: [stage(totalDays)],
    origin: "claude", revision: 1, state: "active", why: "Mehr Ruhe.",
    progress: { days: statuses.map((status, i) => ({ date: day(startOffset + i), status, ...(notes[i] === undefined ? {} : { note: notes[i] }) })), extendedBy: 0 },
    ...over,
  };
}
async function withChallenges(pool: pg.Pool, challenges: Doc[]): Promise<void> {
  const doc = fullV2();
  doc.generatedAt = new Date(NOW).toISOString();
  doc.challenges = challenges;
  assert.equal(await putTranscript(pool, HENNING, doc), "stored");
}
async function stored(t: T, challenges: Doc[]) {
  const pool = await migrated(t);
  await withChallenges(pool, challenges);
  return { pool, client: await connect(t, pool, HENNING) };
}

// 1. challenge_create

test("Werkzeugliste: challenge_create ist da und nicht schreibgeschützt", async (t) => {
  const tools = (await (await connect(t, await migrated(t), HENNING)).listTools()).tools;
  const tool = tools.find((x) => x.name === "challenge_create");
  assert.ok(tool, "challenge_create fehlt");
  assert.equal(tool.annotations?.readOnlyHint, false);
});

test("challenge_create ohne Konto: „kein Konto“", async (t) => {
  const { text, isError } = await call(await connect(t, await migrated(t)), "challenge_create", input());
  assert.equal(isError, true);
  assert.match(text, /kein Konto/);
});

test("challenge_create: gültige Eingabe -> Antwort und gespeicherte Lieferung besteht den Prüfer", async (t) => {
  const pool = await migrated(t);
  const body = input();
  const answer = await json(await connect(t, pool, HENNING), "challenge_create", body);
  assert.match(answer.deliveryId, UUID);
  assert.equal(typeof answer.itemId, "string");
  assert.equal(answer.revision, 1);
  assert.equal(answer.state, "waiting");
  const row = (await listDeliveries(pool, HENNING)).find((r) => (r.delivery as Doc).deliveryId === answer.deliveryId);
  assert.ok(row);
  const doc = row.delivery as Doc;
  assert.deepEqual(validateDelivery(doc).errors, []);
  assert.equal(doc.items.length, 1);
  assert.equal(doc.items[0].kind, "challenge");
  assert.equal(doc.items[0].itemId, answer.itemId);
  assert.equal(doc.items[0].startDate, body.startDate);
  assert.deepEqual(doc.items[0].stages, body.stages);
  assert.equal(doc.why, body.why);
});

test("challenge_create: Impuls ohne Nachfrage und Start heute sind gültig", async (t) => {
  const st = stage(2);
  delete st.content.impulses[0].question;
  const { text, isError } = await call(await connect(t, await migrated(t), HENNING), "challenge_create", input({ startDate: day(0), stages: [st] }));
  assert.equal(isError, false, text);
});

const REJECTIONS: Array<[string, Doc, string]> = [
  ["sieben Stufen", { stages: Array.from({ length: 7 }, () => stage(3)) }, "/items/0/stages"],
  ["Impulse zu wenig", { stages: [{ days: 7, content: { type: "impulses", impulses: impulses(6) } }] }, "/items/0/stages/0/content/impulses"],
  ["Start zwei Tage in der Vergangenheit", { startDate: day(-2) }, "/items/0/startDate"],
  ["Start 40 Tage in der Zukunft", { startDate: day(40) }, "/items/0/startDate"],
  ["31. November", { startDate: "2026-11-31" }, "/items/0/startDate"],
  ["Stufe 91 Tage", { stages: [stage(91)] }, "/items/0/stages/0/days"],
  ["Titel leer", { title: "" }, "/items/0/title"],
  ["moment unbekannt", { stages: [{ days: 1, content: { type: "impulses", impulses: [{ text: "Hallo.", moment: "night" }] } }] }, "/items/0/stages/0/content/impulses/0/moment"],
];
for (const [name, over, path] of REJECTIONS) {
  test(`challenge_create: ${name} -> isError mit Pfad ${path}, nichts gespeichert`, async (t) => {
    const pool = await migrated(t);
    const { text, isError } = await call(await connect(t, pool, HENNING), "challenge_create", input(over));
    assert.equal(isError, true, text);
    assert.ok(text.includes(path), text);
    assert.equal(await count(pool), 0);
  });
}

for (const [field, value] of Object.entries({ kind: "challenge", itemId: "claude.eigen-abcdef", revision: 5 })) {
  test(`challenge_create mit Dienstfeld ${field} -> isError „weglassen“, nichts gespeichert`, async (t) => {
    const pool = await migrated(t);
    const { text, isError } = await call(await connect(t, pool, HENNING), "challenge_create", input({ [field]: value }));
    assert.equal(isError, true, text);
    assert.ok(text.includes(field), text);
    assert.match(text, /weglassen/);
    assert.equal(await count(pool), 0);
  });
}

// 2. Lesen

test("catalog kind challenge: Challenge mit id, name und origin", async (t) => {
  const { client } = await stored(t, [entry(1, -2, 7, ["done", "skipped", "open"])]);
  const doc = await json(client, "catalog", { kind: "challenge" });
  assert.equal(doc.kind, "challenge");
  assert.equal(doc.items.length, 1);
  assert.equal(doc.items[0].id, cid(1));
  assert.equal(doc.items[0].name, "Atem-Woche 1");
  assert.equal(doc.items[0].origin, "claude");
});

test("show: zeigt eine Challenge", async (t) => {
  const { client } = await stored(t, [entry(1, -2, 7, ["done", "skipped", "open"])]);
  const doc = await json(client, "show", { id: cid(1) });
  assert.equal(doc.kind, "challenge");
  assert.equal(doc.item.title, "Atem-Woche 1");
  assert.equal(doc.item.revision, 1);
});

test("forms: Art challenge mit Grenzen 90 (Tage), 300 (Impuls), 120 (Nachfrage)", async (t) => {
  const client = await connect(t, await migrated(t), HENNING);
  const all = await call(client, "forms");
  assert.equal(all.isError, false);
  assert.ok(all.text.includes("challenge"), "forms ohne challenge");
  const only = await call(client, "forms", { kind: "challenge" });
  assert.equal(only.isError, false, only.text);
  for (const word of ["startDate", "stages", "days", "impulses", "moment", "evening", "question", "90", "300", "120"]) {
    assert.ok(only.text.includes(word), `forms challenge ohne „${word}“`);
  }
  assert.ok(!only.text.includes("inhaleSeconds"));
});

test("Server-Anweisung: Grundregel 10 wörtlich und Ausgelassene Tage sind neutral", async (t) => {
  const text = (await connect(t, await migrated(t), HENNING)).getInstructions() ?? "";
  assert.ok(text.includes("10. Impulse laden ein und bewerten nicht. Kein Leistungsdruck, keine Schuld."), text);
  assert.ok(text.includes("Ausgelassene Tage sind neutral; frag nach, statt zu bewerten."), text);
  assert.ok(text.includes("challenge_create"), "Anweisung nennt challenge_create nicht");
});

// 3. overview

test("overview: counts.challenge zählt Challenges je Herkunft", async (t) => {
  const { client } = await stored(t, [entry(1, -2, 30, ["done", "done", "open"]), entry(2, -1, 30, ["done", "open"])]);
  const doc = await json(client, "overview");
  assert.equal(doc.counts.challenge.claude, 2, JSON.stringify(doc.counts));
  assert.equal(doc.counts.challenge.own, 0);
});

const endingMessages = (doc: Doc): Doc[] => doc.messages.filter((m: Doc) => m.kind === "challenge_ending");

test("overview: aktive Challenge, die in 2 Tagen endet, meldet challenge_ending mit Kennung", async (t) => {
  // Start vor 4 Tagen, 7 Tage: letzter Tag ist heute + 2
  const { client } = await stored(t, [entry(1, -4, 7, ["done", "skipped", "done", "done", "open"])]);
  const messages = endingMessages(await json(client, "overview"));
  assert.equal(messages.length, 1);
  assert.ok(JSON.stringify(messages[0]).includes(cid(1)), JSON.stringify(messages[0]));
  assert.equal(typeof messages[0].text, "string");
});

test("overview: endet am letzten Tag heute oder morgen -> challenge_ending", async (t) => {
  const { client } = await stored(t, [
    entry(1, -6, 7, ["done", "done", "done", "done", "done", "done", "open"]),
    entry(2, -5, 7, ["done", "done", "done", "done", "done", "open"]),
  ]);
  const messages = endingMessages(await json(client, "overview"));
  assert.equal(messages.length, 2);
});

test("overview: endet erst in 3 Tagen -> keine Meldung challenge_ending", async (t) => {
  const { client } = await stored(t, [entry(1, -3, 7, ["done", "skipped", "done", "open"])]);
  assert.deepEqual(endingMessages(await json(client, "overview")), []);
});

test("overview: Verlängerung (extendedBy) verschiebt das Ende, dann keine Meldung", async (t) => {
  const { client } = await stored(t, [entry(1, -4, 7, ["done", "skipped", "done", "done", "open"], {
    progress: { days: ["done", "skipped", "done", "done", "open"].map((status, i) => ({ date: day(-4 + i), status })), extendedBy: 3 },
  })]);
  assert.deepEqual(endingMessages(await json(client, "overview")), []);
});

test("overview: zurückgezogene Challenge, die bald endet, meldet nichts", async (t) => {
  const { client } = await stored(t, [entry(1, -4, 7, ["done", "skipped", "done", "done", "open"], { state: "withdrawn" })]);
  assert.deepEqual(endingMessages(await json(client, "overview")), []);
});

// 4. history.challenges

test("history.challenges: Felder, Zählung, aktueller Tag und Notizen mit Impuls-Text", async (t) => {
  const progress = {
    days: [
      { date: day(-4), status: "done", note: "Viermal zum Handy gegriffen." },
      { date: day(-3), status: "skipped" },
      { date: day(-2), status: "made_up", note: "Abends nachgeholt." },
      { date: day(-1), status: "done" },
      { date: day(0), status: "open" },
    ],
    extendedBy: 1,
  };
  const { client } = await stored(t, [entry(1, -4, 7, ["done", "done", "done", "done", "open"], { progress })]);
  const doc = await json(client, "history");
  assert.equal(doc.challenges.length, 1);
  const c = doc.challenges[0];
  assert.equal(c.id, cid(1));
  assert.equal(c.title, "Atem-Woche 1");
  assert.equal(c.startDate, day(-4));
  assert.equal(c.totalDays, 7);
  assert.equal(c.extendedBy, 1);
  assert.equal(c.day, 5);
  assert.deepEqual(c.counts, { done: 2, made_up: 1, skipped: 1, open: 1 });
  const notes = [...c.notes].sort((a: Doc, b: Doc) => a.date.localeCompare(b.date));
  assert.deepEqual(notes, [
    { date: day(-4), impulse: impulseText(1), note: "Viermal zum Handy gegriffen." },
    { date: day(-2), impulse: impulseText(3), note: "Abends nachgeholt." },
  ]);
});

test("history.challenges: ohne Notizen ist notes leer, und es erscheinen keine fremden Felder", async (t) => {
  const { client } = await stored(t, [entry(1, -1, 7, ["done", "open"])]);
  const doc = await json(client, "history");
  assert.deepEqual(doc.challenges[0].notes, []);
  assert.deepEqual(Object.keys(doc.challenges[0]).sort(), ["counts", "day", "extendedBy", "id", "notes", "startDate", "title", "totalDays"]);
});

test("history.challenges: Notiz steht nur, wenn sie in progress steht (Nachfrage-Text des Impulses ist keine Notiz)", async (t) => {
  const { client } = await stored(t, [entry(1, -2, 7, ["done", "done", "open"], {}, { 1: "Nur diese." })]);
  const c = (await json(client, "history")).challenges[0];
  assert.deepEqual(c.notes, [{ date: day(-1), impulse: impulseText(2), note: "Nur diese." }]);
});

test("history.challenges: day ist höchstens totalDays + extendedBy", async (t) => {
  // ANNAHME: abgelaufene Challenge, Verlauf deckt die 7 Tage ab und endet vor heute
  const done: Status[] = ["done", "done", "done", "done", "done", "done", "done"];
  const { client } = await stored(t, [entry(1, -9, 7, done)]);
  const c = (await json(client, "history")).challenges[0];
  assert.equal(c.day, 7);
});

test("history.challenges: nur Challenges, deren Zeitraum den Abfragezeitraum berührt (Grenzen einschließlich)", async (t) => {
  const done7: Status[] = ["done", "done", "done", "done", "done", "done", "done"];
  // Zeitraum von entry(1): heute-26 bis heute-20; entry(2): heute-4 bis heute+2
  const { client } = await stored(t, [entry(1, -26, 7, done7), entry(2, -4, 7, ["done", "done", "done", "done", "open"])]);
  const ids = async (args: Doc) => (await json(client, "history", args)).challenges.map((c: Doc) => c.id).sort();
  assert.deepEqual(await ids({}), [cid(1), cid(2)].sort());
  assert.deepEqual(await ids({ from: day(-20), to: day(-15) }), [cid(1)]);
  assert.deepEqual(await ids({ from: day(-19), to: day(-5) }), []);
  assert.deepEqual(await ids({ from: day(-30), to: day(-4) }), [cid(1), cid(2)].sort());
  assert.deepEqual(await ids({ from: day(-30), to: day(-5) }), [cid(1)]);
});

test("history.challenges: ohne Challenges in der Abschrift eine leere Liste", async (t) => {
  // ANNAHME: Feld ist immer da, leer wenn die Abschrift keine Challenges enthält
  const { client } = await stored(t, []);
  assert.deepEqual((await json(client, "history")).challenges, []);
});

// 5. item_update und item_withdraw

test("item_update einer wartenden Challenge: neue Fassung Revision 2 als gültige Lieferung", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, HENNING);
  const first = await json(client, "challenge_create", input());
  const updated = await json(client, "item_update", {
    itemId: first.itemId, basedOnRevision: 1, why: "Kürzer.", fields: fieldsOf(input({ title: "Atem-Woche neu", stages: [stage(5)] })),
  });
  assert.equal(updated.revision, 2);
  const row = (await listDeliveries(pool, HENNING)).find((r) => (r.delivery as Doc).deliveryId === updated.deliveryId);
  const item = (row!.delivery as Doc).items[0];
  assert.equal(item.kind, "challenge");
  assert.equal(item.title, "Atem-Woche neu");
  assert.equal(item.revision, 2);
  assert.deepEqual(validateDelivery(row!.delivery as Doc).errors, []);
});

test("item_update einer Challenge aus der Abschrift: Revision 2", async (t) => {
  const { client } = await stored(t, [entry(1, -1, 7, ["done", "open"])]);
  const result = await call(client, "item_update", {
    itemId: cid(1), basedOnRevision: 1, why: "Anders.", fields: fieldsOf(input({ title: "Atem-Woche 1 neu", startDate: day(-1) })),
  });
  assert.equal(result.isError, false, result.text);
  assert.equal(JSON.parse(result.text).revision, 2);
});

test("item_withdraw einer Challenge aus der Abschrift: Rücknahme-Lieferung", async (t) => {
  const { pool, client } = await stored(t, [entry(1, -1, 7, ["done", "open"])]);
  const answer = await json(client, "item_withdraw", { itemId: cid(1), why: "Nicht mehr passend." });
  const row = (await listDeliveries(pool, HENNING)).find((r) => (r.delivery as Doc).deliveryId === answer.deliveryId);
  const item = (row!.delivery as Doc).items[0];
  assert.equal(item.kind, "withdrawal");
  assert.equal(item.itemId, cid(1));
});

// B6a-Nachtrag: laufende Challenge mit unverändertem Startdatum ändern

test("item_update einer laufenden Challenge (Start vor 5 Tagen) mit unverändertem startDate: Revision 2", async (t) => {
  const { client } = await stored(t, [entry(1, -5, 7, ["done", "done", "open", "open", "open"])]);
  const result = await call(client, "item_update", {
    itemId: cid(1), basedOnRevision: 1, why: "Neuer Titel.", fields: fieldsOf(input({ title: "Atem-Woche 1 neu", startDate: day(-5) })),
  });
  assert.equal(result.isError, false, result.text);
  assert.equal(JSON.parse(result.text).revision, 2);
});

test("item_update einer laufenden Challenge mit anderem vergangenen startDate: Fehler START_IN_PAST", async (t) => {
  const { client } = await stored(t, [entry(1, -5, 7, ["done", "done", "open", "open", "open"])]);
  const result = await call(client, "item_update", {
    itemId: cid(1), basedOnRevision: 1, why: "Anderer Start.", fields: fieldsOf(input({ title: "Atem-Woche 1 neu", startDate: day(-4) })),
  });
  assert.equal(result.isError, true, result.text);
  assert.ok(result.text.includes("/items/0/startDate") && result.text.includes("Vergangenheit"), result.text);
});
