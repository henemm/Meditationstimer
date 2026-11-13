// B2a-6 Nachträge (Issue #54): TDD RED. Spec: claude-dienst.md Abschnitt 6, Punkt "Türen im Betrieb".
import { test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { createServer } from "node:net";
import { spawn } from "node:child_process";
import { join } from "node:path";
import pg from "pg";

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL fehlt: die Tests laufen nur gegen echtes Postgres");
const MAIN = join(import.meta.dirname, "../src/main.ts");

async function freePort(): Promise<number> {
  const probe = createServer();
  await new Promise<void>((done) => probe.listen(0, "127.0.0.1", done));
  const port = (probe.address() as { port: number }).port;
  await new Promise((done) => probe.close(done));
  return port;
}

test("Türen im Betrieb: Prozess nach Migration -> /mcp (POST, GET) und /app/deliveries/claim ohne Anmeldung 401, GET /app/transcript 405", async (t) => {
  const schema = `t_${randomUUID().replaceAll("-", "")}`;
  const admin = new pg.Pool({ connectionString: databaseUrl });
  await admin.query(`CREATE SCHEMA ${schema}`);
  t.after(async () => { await admin.query(`DROP SCHEMA ${schema} CASCADE`); await admin.end(); });
  const url = new URL(databaseUrl!);
  url.searchParams.set("options", `-c search_path=${schema}`);
  const port = await freePort();
  const base = Object.fromEntries(Object.entries(process.env).filter(([k]) => k !== "NODE_TEST_CONTEXT"));
  const proc = spawn(process.execPath, [MAIN], { env: { ...base, HOST: "127.0.0.1", DATABASE_URL: url.toString(), PORT: String(port) }, stdio: ["ignore", "pipe", "pipe"] });
  let output = "";
  proc.stdout.on("data", (c) => { output += c; });
  proc.stderr.on("data", (c) => { output += c; });
  t.after(() => { proc.kill("SIGKILL"); });
  const root = `http://127.0.0.1:${port}`;
  let up = false;
  const deadline = Date.now() + 15000;
  while (Date.now() < deadline && !up) {
    up = (await fetch(`${root}/health`).catch(() => undefined))?.status === 200;
    if (!up) await new Promise((done) => setTimeout(done, 100));
  }
  assert.ok(up, output);

  const mcpPost = await fetch(`${root}/mcp`, { method: "POST", headers: { "Content-Type": "application/json", Accept: "application/json, text/event-stream" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/list" }) });
  assert.equal(mcpPost.status, 401, "POST /mcp");
  assert.equal((await fetch(`${root}/mcp`, { headers: { Accept: "text/event-stream" } })).status, 401, "GET /mcp");
  const claim = await fetch(`${root}/app/deliveries/claim`, { method: "POST", headers: { "X-Device": randomUUID(), "Content-Type": "application/json" }, body: "{}" });
  assert.equal(claim.status, 401, "POST /app/deliveries/claim");
  assert.equal((await fetch(`${root}/app/transcript`)).status, 405, "GET /app/transcript");
});
