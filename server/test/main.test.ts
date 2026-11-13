// Übernommen aus loose-ends server/test/main.test.ts @ 24a6da6; angepasst: nur Gerüstfälle (health, Migration, 503, Start/Stopp, Körpergrenze, Log), ohne Apple/OAuth/MCP/App/Aufträge
import { test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import http from "node:http";
import { connect, createServer } from "node:net";
import { spawn } from "node:child_process";
import { join } from "node:path";
import pg from "pg";
import { start, gated } from "../src/main.ts";
import { ErrorWindow, healthHandler } from "../src/health.ts";


type Doc = Record<string, any>;
type T = { after: (fn: () => Promise<void>) => void; mock: any };
type Options = Partial<Parameters<typeof start>[0]>;

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL fehlt: die Tests laufen nur gegen echtes Postgres");
const migrations = join(import.meta.dirname, "../migrations");
const ISO = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/;

// Each service gets its own schema (search_path in the URL) and its own application_name, so runs never meet.
async function service(t: T, options: Options = {}) {
  const schema = `t_${randomUUID().replaceAll("-", "")}`;
  const applicationName = `hh-test-${schema.slice(2, 14)}`;
  const admin = new pg.Pool({ connectionString: databaseUrl });
  await admin.query(`CREATE SCHEMA ${schema}`);
  const url = new URL(databaseUrl!);
  url.searchParams.set("options", `-c search_path=${schema}`);
  const running = await start({ databaseUrl: url.toString(), port: 0, migrationsDir: migrations, applicationName, ...options });
  t.after(async () => {
    await running.close();
    await admin.query(`DROP SCHEMA ${schema} CASCADE`);
    await admin.end();
  });
  return { ...running, admin, schema, applicationName, databaseUrl: url.toString() };
}

async function health(url: string): Promise<{ status: number; body: Doc }> {
  const answer = await fetch(`${url}/health`);
  return { status: answer.status, body: await answer.json() };
}

function capturedLines(t: T): string[] {
  const lines: string[] = [];
  for (const name of ["log", "error"]) t.mock.method(console, name, (...args: unknown[]) => { lines.push(args.map(String).join(" ")); });
  return lines;
}

async function freePort(): Promise<number> {
  const probe = createServer();
  await new Promise<void>((done) => probe.listen(0, "127.0.0.1", done));
  const port = (probe.address() as { port: number }).port;
  await new Promise((done) => probe.close(done));
  return port;
}

const connections = async (admin: pg.Pool, name: string) =>
  Number((await admin.query("SELECT count(*) AS n FROM pg_stat_activity WHERE application_name = $1", [name])).rows[0].n);


test("AC-1 (S1): after ready, /health answers 200 with exactly five keys", async (t) => {
  const { url, ready } = await service(t);
  await ready;
  const { status, body } = await health(url);
  assert.equal(status, 200);
  assert.deepEqual(Object.keys(body).sort(), ["db", "errorRate", "migrated", "requests", "status"]);
  assert.equal(body.status, "ok");
  assert.equal(body.db, "up");
  assert.equal(body.migrated, true);
  assert.equal(body.errorRate, 0);
  assert.equal(typeof body.requests, "number");
});

test("AC-2 (S1): without a database /health and a gated route answer 503, ready is refused, close does not throw", async () => {
  const port = await freePort();
  const gatedRoute = gated(() => false, async () => new Response("nie", { status: 200 }));
  const running = await start({
    databaseUrl: `postgres://postgres@127.0.0.1:${port}/postgres`, port: 0, migrationsDir: migrations, retryMs: 50, maxAttempts: 20,
    extraRoutes: { "/gesperrt": gatedRoute },
  });
  const refused = assert.rejects(running.ready);
  const { status, body } = await health(running.url);
  assert.equal(status, 503);
  assert.equal(body.migrated, false);
  assert.equal(body.status, "unavailable");
  const answer = await fetch(`${running.url}/gesperrt`);
  assert.equal(answer.status, 503);
  assert.equal(await answer.text(), "");
  await refused;
  await assert.doesNotReject(running.close());
});

test("AC-3 (B2a-1): a gated route answers 200 after ready", async (t) => {
  const ok = gated(() => true, async () => new Response("da", { status: 200 }));
  const { url, ready } = await service(t, { extraRoutes: { "/offen": ok } });
  await ready;
  assert.equal(await (await fetch(`${url}/offen`)).text(), "da");
});

test("AC-4 (S1): an unknown path answers 404 and counts in the next /health", async (t) => {
  const { url, ready } = await service(t);
  await ready;
  const before = (await health(url)).body.requests;
  const missing = await fetch(`${url}/gibt-es-nicht`);
  assert.equal(missing.status, 404);
  assert.equal(await missing.text(), "");
  assert.equal((await health(url)).body.requests, before + 1);
});

test("AC-5 (S1): terminated pool connections leave the process alive and /health recovers within 5 s, without error text", async (t) => {
  const { url, ready, admin, applicationName } = await service(t);
  await ready;
  assert.equal((await health(url)).status, 200);
  const lines = capturedLines(t);
  await admin.query("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE application_name = $1", [applicationName]);
  const deadline = Date.now() + 5000;
  let last = await health(url);
  while (last.status !== 200 && Date.now() < deadline) {
    await new Promise((done) => setTimeout(done, 100));
    last = await health(url);
  }
  assert.equal(last.status, 200);
  assert.equal(last.body.db, "up");
  for (const line of lines) assert.ok(!/terminat|administrator/i.test(line), line);
});

test("AC-6 (S1): close ends server and pool, a second close does not throw, keep-alive does not hold it", async (t) => {
  const { url, ready, close, admin, applicationName } = await service(t);
  await ready;
  const agent = new http.Agent({ keepAlive: true });
  await new Promise<void>((done, fail) => {
    http.get(`${url}/health`, { agent }, (answer) => { answer.resume(); answer.on("end", done); }).on("error", fail);
  });
  const began = Date.now();
  await close();
  assert.ok(Date.now() - began < 2000, `close dauerte ${Date.now() - began} ms`);
  await assert.rejects(fetch(`${url}/health`));
  let open = await connections(admin, applicationName);
  for (let i = 0; open > 0 && i < 20; i++) {
    await new Promise((done) => setTimeout(done, 50));
    open = await connections(admin, applicationName);
  }
  assert.equal(open, 0, "der Pool hält noch Verbindungen");
  await assert.doesNotReject(close());
  agent.destroy();
});

test("AC-7 (S1): ErrorWindow trips only above half of at least 20 answers and forgets after five minutes", () => {
  let clock = 1_000_000;
  const fill = (fives: number, total: number) => {
    const window = new ErrorWindow(() => clock);
    for (let i = 0; i < total; i++) window.record(i < fives ? 500 : 200);
    return window;
  };
  assert.equal(fill(19, 19).tripped(), false);
  const eleven = fill(11, 20);
  assert.equal(eleven.tripped(), true);
  assert.equal(eleven.stats().errorRate, 0.55);
  assert.equal(fill(10, 20).tripped(), false);
  clock += 300_001;
  assert.deepEqual(eleven.stats(), { requests: 0, errors: 0, errorRate: 0 });
  assert.equal(eleven.tripped(), false);
  const plain = new ErrorWindow(() => clock);
  plain.record(404);
  plain.record(200);
  assert.deepEqual(plain.stats(), { requests: 2, errors: 0, errorRate: 0 });
});

test("AC-8 (S1): /health turns 503 on a high error rate and recovers when the window passes", async (t) => {
  let clock = 5_000_000;
  const boom = async (): Promise<Response> => { throw new Error("kaputt"); };
  const { url, ready } = await service(t, { now: () => clock, extraRoutes: { "/boom": boom } });
  await ready;
  for (let i = 0; i < 20; i++) {
    const answer = await fetch(`${url}${i < 11 ? "/boom" : "/gibt-es-nicht"}`);
    await answer.arrayBuffer();
    assert.equal(answer.status, i < 11 ? 500 : 404);
  }
  const tripped = await health(url);
  assert.equal(tripped.status, 503);
  assert.equal(tripped.body.status, "unavailable");
  assert.equal(tripped.body.db, "up");
  assert.equal(tripped.body.migrated, true);
  assert.ok(tripped.body.errorRate > 0.5, String(tripped.body.errorRate));
  assert.equal((await health(url)).body.requests, 20, "/health zählt nicht mit");
  clock += 300_001;
  assert.equal((await health(url)).status, 200);
});

test("AC-9 (S1): a database that never answers gives 503 with db down within a second, no exception", async () => {
  const pool = { query: () => new Promise(() => {}) } as unknown as pg.Pool;
  const handler = healthHandler({ pool, isMigrated: () => true, window: new ErrorWindow(Date.now), timeoutMs: 50 });
  const began = Date.now();
  const answer = await handler();
  assert.ok(Date.now() - began < 1000, `${Date.now() - began} ms`);
  assert.equal(answer.status, 503);
  assert.equal((await answer.json()).db, "down");
});


test("AC-10 (S1): no error text, URL or connection data in any answer or log line; every log line starts ISO", async (t) => {
  const lines = capturedLines(t);
  const leak = async (): Promise<Response> => { throw new Error("geheimer-fehlertext-4711"); };
  const running = await service(t, { extraRoutes: { "/leak": leak } });
  await running.ready;
  const bodies: string[] = [];
  for (const path of ["/health", "/gibt-es-nicht", "/leak"]) bodies.push(await (await fetch(`${running.url}${path}`)).text());
  await running.admin.query("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE application_name = $1", [running.applicationName]);
  await new Promise((done) => setTimeout(done, 200));
  bodies.push(await (await fetch(`${running.url}/health`)).text());
  await running.close();
  const forbidden = ["geheimer-fehlertext-4711", running.databaseUrl, databaseUrl!, "terminating connection"];
  for (const text of [...bodies, ...lines]) for (const word of forbidden) assert.ok(!text.includes(word), `${word} in ${text}`);
  assert.ok(lines.length > 0, "keine Logzeile aufgefangen");
  for (const line of lines) assert.match(line, ISO);
});

const MIB = 1024 * 1024;

// A counting route that reads the whole body; maxSeen is the largest body it ever got.
function counter() {
  const c = { calls: 0, maxSeen: 0, route: async (request: Request) => {
    c.calls++;
    c.maxSeen = Math.max(c.maxSeen, (await request.arrayBuffer()).byteLength);
    return new Response(null, { status: 204 });
  } };
  return c;
}

type Sent = { status: number; connection: string | undefined; body: string } | { aborted: true };
// POST over node:http with a keep-alive agent (so "connection: close" comes from the service); an error after the answer is ignored.
function send(url: string, path: string, parts: Buffer[], headers: Record<string, string> = {}): Promise<Sent> {
  const agent = new http.Agent({ keepAlive: true });
  return new Promise<Sent>((done) => {
    const request = http.request(`${url}${path}`, { method: "POST", headers, agent }, (answer) => {
      let body = "";
      answer.setEncoding("utf8");
      answer.on("data", (chunk) => { body += chunk; });
      const finish = () => done({ status: answer.statusCode!, connection: answer.headers.connection, body });
      answer.on("end", finish);
      answer.on("error", finish);
    });
    request.on("error", () => done({ aborted: true }));
    for (const part of parts) request.write(part);
    request.end();
  }).finally(() => agent.destroy());
}
const sized = (url: string, path: string, size: number) =>
  send(url, path, [Buffer.alloc(size, 0x61)], { "content-type": "application/json", "content-length": String(size) });

// The real process: main.ts as a child, without the test runner's context.
const MAIN = join(import.meta.dirname, "../src/main.ts");
function child(env: Record<string, string>) {
  const base = Object.fromEntries(Object.entries(process.env)
    .filter(([k]) => k !== "NODE_TEST_CONTEXT"));
  const proc = spawn(process.execPath, [MAIN], { env: { ...base, HOST: "127.0.0.1", ...env }, stdio: ["ignore", "pipe", "pipe"] });
  let output = "";
  proc.stdout.on("data", (chunk) => { output += chunk; });
  proc.stderr.on("data", (chunk) => { output += chunk; });
  const exited = new Promise<number | null>((done) => proc.on("exit", (code) => done(code)));
  return { proc, exited, output: () => output };
}
async function within<V>(promise: Promise<V>, ms: number, onLate: () => void): Promise<V | "late"> {
  let timer: NodeJS.Timeout | undefined;
  const late = new Promise<"late">((done) => { timer = setTimeout(() => { onLate(); done("late"); }, ms); });
  try { return await Promise.race([promise, late]); } finally { clearTimeout(timer); }
}


test("process: starts, migrates, answers /health and ends cleanly on SIGTERM with ISO log lines", async (t) => {
  const schema = `t_${randomUUID().replaceAll("-", "")}`;
  const admin = new pg.Pool({ connectionString: databaseUrl });
  await admin.query(`CREATE SCHEMA ${schema}`);
  t.after(async () => { await admin.query(`DROP SCHEMA ${schema} CASCADE`); await admin.end(); });
  const url = new URL(databaseUrl!);
  url.searchParams.set("options", `-c search_path=${schema}`);
  const port = await freePort();
  const run = child({ DATABASE_URL: url.toString(), PORT: String(port) });
  t.after(() => { run.proc.kill("SIGKILL"); });
  let answer: { status: number; body: Doc } | undefined;
  const deadline = Date.now() + 15000;
  while (Date.now() < deadline) {
    answer = await health(`http://127.0.0.1:${port}`).catch(() => undefined);
    if (answer?.status === 200) break;
    await new Promise((done) => setTimeout(done, 100));
  }
  assert.equal(answer?.status, 200, run.output());
  run.proc.kill("SIGTERM");
  const code = await within(run.exited, 10000, () => run.proc.kill("SIGKILL"));
  assert.equal(code, 0, run.output());
  const lines = run.output().split("\n").filter((line) => line !== "");
  for (const line of lines) assert.match(line, ISO);
  for (const word of ["listening", "migrated", "shutting down", "stopped"]) assert.ok(lines.some((l) => l.endsWith(` ${word}`)), word);
  assert.ok(!run.output().includes("postgres://"), "Verbindungsdaten im Log");
});

test("process: without DATABASE_URL it exits 1 and names only the variable", async () => {
  const run = child({ DATABASE_URL: "" });
  const code = await within(run.exited, 10000, () => run.proc.kill("SIGKILL"));
  assert.equal(code, 1);
  assert.match(run.output(), /DATABASE_URL missing/);
});

test("einhaengen: body ueber 1 mib 413", async (t) => {
  const probe = counter();
  const running = await service(t, { extraRoutes: { "/zaehler": probe.route } });
  await running.ready;
  for (const size of [MIB + 1, 2 * MIB]) {
    const sent = await sized(running.url, "/zaehler", size);
    assert.ok(!("aborted" in sent), `${size}: Verbindung abgebrochen statt 413`);
    assert.equal(sent.status, 413, `${size}`);
    assert.equal(sent.body, "", `${size}`);
    assert.equal(sent.connection, "close", `${size}`);
  }
  assert.equal(probe.calls, 0, "Route trotz zu großem Body aufgerufen");
  const exact = await sized(running.url, "/zaehler", MIB);
  assert.ok(!("aborted" in exact) && exact.status === 204, "genau 1 MiB geht durch");
  assert.equal(probe.maxSeen, MIB);
});

// Raw HTTP/1.1 with a Content-Length that claims less than is sent; resolves with all bytes the service answered.
function rawPost(url: string, path: string, claimed: number, size: number): Promise<string> {
  return new Promise((done) => {
    const socket = connect(Number(new URL(url).port), "127.0.0.1");
    let text = "";
    socket.on("data", (chunk) => { text += chunk; });
    socket.on("close", () => done(text));
    socket.on("error", () => {});
    socket.write(`POST ${path} HTTP/1.1\r\nHost: x\r\nContent-Type: application/json\r\nContent-Length: ${claimed}\r\n\r\n`);
    socket.end(Buffer.alloc(size, 0x61));
  });
}

test("einhaengen: luegende content-length", async (t) => {
  const probe = counter();
  const running = await service(t, { extraRoutes: { "/zaehler": probe.route } });
  await running.ready;
  const chunk = Buffer.alloc(64 * 1024, 0x61);
  const chunked = await send(running.url, "/zaehler", Array.from({ length: 20 }, () => chunk), { "content-type": "application/json" });
  assert.ok("aborted" in chunked || (chunked.status === 413 && chunked.connection === "close"), "chunked über 1 MiB");
  assert.equal(probe.calls, 0, "chunked: Route aufgerufen");
  // A Content-Length below the body: the parser hands the route only the claimed bytes, the rest is never buffered as body.
  await rawPost(running.url, "/zaehler", 100, 2 * MIB);
  assert.ok(probe.maxSeen <= MIB, `Route bekam ${probe.maxSeen} Bytes`);
  const after = await health(running.url);
  assert.equal(after.status, 200);
});


test("einhaengen: 413 kippt health nicht", async (t) => {
  const boom = async (): Promise<Response> => { throw new Error("kaputt"); };
  const running = await service(t, { extraRoutes: { "/boom": boom } });
  await running.ready;
  const before = (await health(running.url)).body.requests;
  for (let i = 0; i < 25; i++) {
    const sent = await sized(running.url, "/boom", MIB + 1);
    assert.ok(!("aborted" in sent) && sent.status === 413, `Anfrage ${i + 1}`);
  }
  const still = await health(running.url);
  assert.equal(still.status, 200);
  assert.equal(still.body.requests, before, "413 läuft am Fehlerfenster vorbei");
  for (let i = 0; i < 25; i++) await (await fetch(`${running.url}/boom`)).arrayBuffer();
  assert.equal((await health(running.url)).status, 503, "Gegenprobe: 25 × 500 kippen /health");
});


test("einhaengen: /health is not replaceable by extraRoutes", async (t) => {
  const fake = async () => new Response("gefaelscht", { status: 418 });
  const running = await service(t, { extraRoutes: { "/health": fake } });
  await running.ready;
  const { status, body } = await health(running.url);
  assert.equal(status, 200);
  assert.deepEqual(Object.keys(body).sort(), ["db", "errorRate", "migrated", "requests", "status"]);
});

test("einhaengen: the log never throws", async (t) => {
  const running = await service(t);
  await running.ready;
  t.mock.method(console, "error", () => { throw new Error("EPIPE"); });
  await running.admin.query("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE application_name = $1", [running.applicationName]);
  await new Promise((done) => setTimeout(done, 300));
  const deadline = Date.now() + 5000;
  let last = await health(running.url);
  while (last.status !== 200 && Date.now() < deadline) {
    await new Promise((done) => setTimeout(done, 100));
    last = await health(running.url);
  }
  assert.equal(last.status, 200, "Service lebt trotz werfendem Log");
});
