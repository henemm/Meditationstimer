// B3a Rückblick (Issue #58): TDD RED. Spec: openspec/specs/integrations/claude-rueckblick.md Abschnitt 3
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import type pg from "pg";
import { migrate } from "../src/migrate.ts";
import { putTranscript } from "../src/transcripts.ts";
import { freshPool } from "./db.ts";
import { call, connect, json, type Doc, type T } from "./mcp-client.ts";

const root = join(import.meta.dirname, "..", "..");
const migrations = join(import.meta.dirname, "..", "migrations");
const HENNING = "henning";
const ANNA = "anna";
const DAY = 24 * 3_600_000;
const RUECKEN = "claude.ruecken-a-7hq2mz";
const TABATA = "builtin.tabata";
const BOX = "own.8e4f9c1a-52b4-4f08-8e6a-0c9b1d2e3f45";
const ABEND = "claude.abendatem-p0x8rt";

const readJson = async (...parts: string[]) => JSON.parse(await readFile(join(root, ...parts), "utf8"));
const NOW = Date.now();
const day = (daysAgo: number) => new Date(NOW - daysAgo * DAY).toISOString().slice(0, 10);
// Zeitpunkt am UTC-Tag von "vor daysAgo Tagen" zur gegebenen Uhrzeit (liegt nie nach generatedAt, solange daysAgo >= 1)
const at = (daysAgo: number, time = "12:00:00") => `${day(daysAgo)}T${time}Z`;

type Session = Doc;
const meditation = (startedAt: string, durationSeconds = 600, completed = true): Session => ({ startedAt, kind: "meditation", durationSeconds, completed });
const workout = (startedAt: string, programId: string, durationSeconds: number, completed: boolean, rating?: string): Session =>
  ({ startedAt, kind: "workout", programId, durationSeconds, completed, ...(rating ? { feedback: { rating } } : {}) });
const breath = (startedAt: string, programId: string, durationSeconds: number, completed = true): Session =>
  ({ startedAt, kind: "breath", programId, durationSeconds, completed });

const STREAKS = { meditation: { current: 4, longest: 21 }, workout: { current: 0, longest: 9 } };

async function v2(sessions: Session[], streaks: Doc = STREAKS): Promise<Doc> {
  const doc = (await readJson("Contracts", "transcript", "v2", "valid", "full.json")).transcript;
  doc.generatedAt = new Date(NOW).toISOString();
  doc.history = { sessions, streaks };
  return doc;
}

async function v1(): Promise<Doc> {
  const doc = (await readJson("Contracts", "transcript", "valid", "full.json")).transcript;
  doc.generatedAt = new Date(NOW).toISOString();
  return doc;
}

async function migrated(t: T): Promise<pg.Pool> {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  return pool;
}

async function setup(t: T, sessions: Session[], account = HENNING) {
  const pool = await migrated(t);
  assert.equal(await putTranscript(pool, account, await v2(sessions)), "stored");
  return { pool, client: await connect(t, pool, account) };
}

const startedAts = (doc: Doc) => doc.sessions.map((s: Doc) => s.startedAt);

// 1. Werkzeug und Anweisung

test("history: Werkzeug ist da und schreibgeschützt markiert", async (t) => {
  const client = await connect(t, await migrated(t), HENNING);
  const tool = (await client.listTools()).tools.find((x) => x.name === "history");
  assert.ok(tool, "history fehlt");
  assert.equal(tool.annotations?.readOnlyHint, true);
});

test("Server-Anweisung nennt history", async (t) => {
  const client = await connect(t, await migrated(t), HENNING);
  assert.ok((client.getInstructions() ?? "").includes("history"));
});

// 2. Ablehnungen

test("history ohne Konto: „kein Konto“", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, HENNING, await v2([]));
  const { text, isError } = await call(await connect(t, pool), "history");
  assert.equal(isError, true);
  assert.match(text, /kein Konto/);
});

test("history ohne Abschrift: Ablehnung „noch keine Abschrift“", async (t) => {
  const { text, isError } = await call(await connect(t, await migrated(t), HENNING), "history");
  assert.equal(isError, true);
  assert.match(text, /noch keine Abschrift/);
});

test("history bei Abschrift Fassung 1: Ablehnung mit Hinweis zu aktualisieren", async (t) => {
  const pool = await migrated(t);
  assert.equal(await putTranscript(pool, HENNING, await v1()), "stored");
  const { text, isError } = await call(await connect(t, pool, HENNING), "history");
  assert.equal(isError, true);
  assert.match(text, /aktualisieren/);
});

// 3. Zeitraum

test("history: Vorgabe sind die letzten 30 Tage bis generatedAt", async (t) => {
  const { client } = await setup(t, [meditation(at(31)), meditation(at(29)), meditation(at(1))]);
  const doc = await json(client, "history");
  assert.deepEqual(startedAts(doc), [at(1), at(29)]);
  assert.equal(doc.count, 2);
  assert.deepEqual(doc.range, { from: day(30), to: day(0) });
  assert.equal(doc.generatedAt, new Date(NOW).toISOString());
});

test("history: from und to gelten einschließlich (UTC-Tage)", async (t) => {
  const edges = [at(6, "23:59:59"), at(5, "00:00:00"), at(5, "23:59:59"), at(4, "00:00:00")];
  const { client } = await setup(t, edges.map((e) => meditation(e)));
  const doc = await json(client, "history", { from: day(5), to: day(5) });
  assert.deepEqual(startedAts(doc), [at(5, "23:59:59"), at(5, "00:00:00")]);
  assert.deepEqual(doc.range, { from: day(5), to: day(5) });
  const wide = await json(client, "history", { from: day(6), to: day(4) });
  assert.equal(wide.count, 4);
});

test("history: ältere Einheiten bis 90 Tage sind mit explizitem from erreichbar", async (t) => {
  const { client } = await setup(t, [meditation(at(60)), meditation(at(2))]);
  const doc = await json(client, "history", { from: day(80), to: day(0) });
  assert.deepEqual(startedAts(doc), [at(2), at(60)]);
});

test("history: Filter kind und programId", async (t) => {
  const { client } = await setup(t, [
    meditation(at(1)), workout(at(2), RUECKEN, 600, true), workout(at(3), TABATA, 240, true), breath(at(4), BOX, 160),
  ]);
  const byKind = await json(client, "history", { kind: "workout" });
  assert.equal(byKind.count, 2);
  assert.ok(byKind.sessions.every((s: Doc) => s.kind === "workout"));
  const byProgram = await json(client, "history", { programId: RUECKEN });
  assert.equal(byProgram.count, 1);
  assert.equal(byProgram.sessions[0].programId, RUECKEN);
  const both = await json(client, "history", { kind: "breath", programId: BOX });
  assert.equal(both.count, 1);
  const none = await json(client, "history", { kind: "meditation", programId: BOX });
  assert.equal(none.count, 0);
  assert.deepEqual(none.sessions, []);
});

test("history: neueste zuerst, unabhängig von der Reihenfolge in der Abschrift", async (t) => {
  const { client } = await setup(t, [meditation(at(5)), meditation(at(1)), meditation(at(3)), meditation(at(2))]);
  assert.deepEqual(startedAts(await json(client, "history")), [at(1), at(2), at(3), at(5)]);
});

test("history: höchstens 200 Einheiten, count nennt alle 250 Treffer", async (t) => {
  const many: Session[] = [];
  for (let n = 0; n < 250; n++) many.push(meditation(new Date(NOW - (n + 1) * 3_600_000 * 2.5).toISOString().replace(/\.\d+Z$/, "Z")));
  const { client } = await setup(t, many);
  const doc = await json(client, "history", { from: day(30), to: day(0) });
  assert.equal(doc.count, 250);
  assert.equal(doc.sessions.length, 200);
  const sorted = [...many].sort((a, b) => b.startedAt.localeCompare(a.startedAt));
  assert.equal(doc.sessions[0].startedAt, sorted[0].startedAt);
  assert.equal(doc.sessions[199].startedAt, sorted[199].startedAt);
});

// 4. Felder der Einheiten

test("history: Einheit trägt programName aus der Abschrift, Rückmeldung und Dauer", async (t) => {
  const { client } = await setup(t, [
    { ...workout(at(1), RUECKEN, 720, false, "too_hard"), feedback: { rating: "too_hard", note: "Nach der Planke war Schluss." } },
    meditation(at(2), 900),
    breath(at(3), BOX, 160),
  ]);
  const doc = await json(client, "history");
  const [w, m, b] = doc.sessions;
  assert.deepEqual(w, { startedAt: at(1), kind: "workout", programId: RUECKEN, programName: "Rücken A", durationSeconds: 720,
    completed: false, feedback: { rating: "too_hard", note: "Nach der Planke war Schluss." } });
  assert.equal(m.kind, "meditation");
  assert.equal(m.programId, undefined);
  assert.equal(m.programName, undefined);
  assert.equal(m.durationSeconds, 900);
  assert.equal(b.programName, "Box");
});

test("history: fehlt der Baustein in der Abschrift, steht die Einheit ohne programName da", async (t) => {
  // ANNAHME: Direkt per INSERT abgelegt, weil putTranscript unbekannte Kennungen ablehnt (Spec: "z. B. gelöscht").
  const pool = await migrated(t);
  const doc = await v2([workout(at(1), "own.geloescht-0001", 300, true)]);
  doc.programs = doc.programs.filter((p: Doc) => p.id !== "own.geloescht-0001");
  await pool.query("INSERT INTO transcripts (account_id, doc, generated_at, received_at) VALUES ($1, $2::jsonb, $3, now())",
    [HENNING, JSON.stringify(doc), doc.generatedAt]);
  const result = await json(await connect(t, pool, HENNING), "history");
  assert.equal(result.count, 1);
  assert.equal(result.sessions[0].programId, "own.geloescht-0001");
  assert.ok(!("programName" in result.sessions[0]));
});

// 5. Zusammenfassung und Serien

async function summaryDoc(t: T): Promise<Doc> {
  const { client } = await setup(t, [
    workout(at(1), RUECKEN, 720, false, "too_hard"), workout(at(2), RUECKEN, 600, true, "right"),
    workout(at(3), RUECKEN, 660, false, "too_hard"), workout(at(4), RUECKEN, 540, false),
    workout(at(5), TABATA, 240, true, "too_easy"), workout(at(6), TABATA, 250, true, "right"),
    meditation(at(7), 900), meditation(at(8), 600), meditation(at(9), 100, false),
    breath(at(10), BOX, 160, true),
    breath(at(11), ABEND, 100, true), breath(at(12), ABEND, 100, false),
  ]);
  return json(client, "history");
}

test("history: summary.byKind zählt Einheiten, beendete und Minuten (eine Nachkommastelle)", async (t) => {
  const doc = await summaryDoc(t);
  assert.deepEqual(doc.summary.byKind.workout, { count: 6, completed: 3, minutes: 50.2 });
  assert.deepEqual(doc.summary.byKind.meditation, { count: 3, completed: 2, minutes: 26.7 });
  assert.deepEqual(doc.summary.byKind.breath, { count: 3, completed: 2, minutes: 6.0 });
});

test("history: summary.byProgram nach count absteigend, dann Name, mit Durchschnitt und Rückmeldungen", async (t) => {
  const doc = await summaryDoc(t);
  // ANNAHME: Einheiten ohne programId (Meditation) kommen in byProgram nicht vor.
  const list: Doc[] = doc.summary.byProgram.filter((p: Doc) => p.programId !== undefined);
  assert.deepEqual(list.map((p) => p.name), ["Rücken A", "Abendatem", "Tabata", "Box"]);
  assert.deepEqual(list[0], { programId: RUECKEN, name: "Rücken A", kind: "workout", count: 4, completed: 1, aborted: 3,
    averageMinutes: 10.5, feedback: { too_easy: 0, right: 1, too_hard: 2 } });
  const tabata = list.find((p) => p.programId === TABATA)!;
  assert.equal(tabata.count, 2);
  assert.equal(tabata.completed, 2);
  assert.equal(tabata.aborted, 0);
  assert.equal(tabata.averageMinutes, 4.1);
  assert.deepEqual(tabata.feedback, { too_easy: 1, right: 1, too_hard: 0 });
  const abend = list.find((p) => p.programId === ABEND)!;
  assert.deepEqual([abend.kind, abend.count, abend.completed, abend.aborted, abend.averageMinutes], ["breath", 2, 1, 1, 1.7]);
});

test("history: streaks stehen wie in der Abschrift in der Antwort", async (t) => {
  const { client } = await setup(t, [meditation(at(1))]);
  assert.deepEqual((await json(client, "history")).streaks, STREAKS);
});

// 6. Ungültige Eingaben

test("history: ungültige Eingaben werden mit Ausweg abgelehnt", async (t) => {
  const { client } = await setup(t, [meditation(at(1))]);
  const cases: Array<[string, Doc]> = [
    ["Datum 2026-13-01", { from: "2026-13-01" }],
    ["Datum kein Datum", { to: "gestern" }],
    ["from nach to", { from: day(2), to: day(5) }],
    ["Zeitraum 91 Tage", { from: day(91), to: day(0) }],
    ["kind run", { kind: "run" }],
  ];
  for (const [name, args] of cases) {
    const { text, isError } = await call(client, "history", args);
    assert.equal(isError, true, name);
    assert.ok(text.length > 20, `${name}: Ablehnung braucht einen erklärenden Text mit Ausweg`);
  }
  assert.match((await call(client, "history", { from: "2026-13-01" })).text, /JJJJ-MM-TT/);
});

// 7. Konten getrennt

test("history: Konten sind getrennt", async (t) => {
  const pool = await migrated(t);
  assert.equal(await putTranscript(pool, HENNING, await v2([meditation(at(1), 600)])), "stored");
  assert.equal(await putTranscript(pool, ANNA, await v2([workout(at(2), TABATA, 240, true), workout(at(3), TABATA, 240, true)],
    { meditation: { current: 0, longest: 0 }, workout: { current: 2, longest: 2 } })), "stored");
  const henning = await json(await connect(t, pool, HENNING), "history");
  const anna = await json(await connect(t, pool, ANNA), "history");
  assert.deepEqual(henning.sessions.map((s: Doc) => s.kind), ["meditation"]);
  assert.deepEqual(anna.sessions.map((s: Doc) => s.kind), ["workout", "workout"]);
  assert.deepEqual(anna.streaks.workout, { current: 2, longest: 2 });
  const other = await call(await connect(t, pool, "bernd"), "history");
  assert.equal(other.isError, true);
});

// 8. overview

test("overview: Fassung 1 meldet history_missing, Fassung 2 nicht", async (t) => {
  const poolOld = await migrated(t);
  await putTranscript(poolOld, HENNING, await v1());
  const old = await json(await connect(t, poolOld, HENNING), "overview");
  const kinds = old.messages.map((m: Doc) => m.kind);
  assert.ok(kinds.includes("history_missing"), `Meldungen: ${kinds}`);
  assert.equal(kinds[kinds.length - 1], "history_missing");
  assert.equal(typeof old.messages[kinds.length - 1].text, "string");

  const poolNew = await migrated(t);
  await putTranscript(poolNew, HENNING, await v2([]));
  const fresh = await json(await connect(t, poolNew, HENNING), "overview");
  assert.ok(!fresh.messages.some((m: Doc) => m.kind === "history_missing"));
});

// 9. Härtung (Nachtrag Adversary): nur bekannte Felder, auch bei Abschrift an der Prüfung vorbei

test("history: zusätzliche Felder in Einheit, Rückmeldung und Serie erscheinen nicht in der Antwort", async (t) => {
  // ANNAHME: Direkt per INSERT abgelegt, wie beim fehlenden Baustein; ein CHECK in der Datenbank könnte das schon ablehnen.
  const pool = await migrated(t);
  const doc = await v2([
    { ...workout(at(1), RUECKEN, 720, false, "too_hard"), heartRate: 151, feedback: { rating: "too_hard", note: "Hart.", effort: 9 } },
  ], { meditation: { current: 4, longest: 21, extra: "x" }, workout: { current: 0, longest: 9 }, mood: "gut" });
  await pool.query("INSERT INTO transcripts (account_id, doc, generated_at, received_at) VALUES ($1, $2::jsonb, $3, now())",
    [HENNING, JSON.stringify(doc), doc.generatedAt]);
  const { text, isError } = await call(await connect(t, pool, HENNING), "history");
  assert.notEqual(isError, true, text);
  for (const forbidden of ["heartRate", "effort", "mood", "extra"]) assert.ok(!text.includes(forbidden), `Antwort enthält ${forbidden}`);
  const result = JSON.parse(text);
  assert.deepEqual(result.sessions[0], { startedAt: at(1), kind: "workout", programId: RUECKEN, programName: "Rücken A", durationSeconds: 720,
    completed: false, feedback: { rating: "too_hard", note: "Hart." } });
  assert.deepEqual(result.streaks, STREAKS);
});
