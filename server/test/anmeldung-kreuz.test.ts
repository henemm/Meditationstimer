// B2b Anmeldung (Issue #55), Regressionstests Kreuzzugriff: Spec claude-anmeldung.md Abschnitte 2, 3, 5 und claude-dienst.md Abschnitt 3.
// Festgeschrieben wird bestehendes Verhalten: App-Sitzung und Claude-Token sind nicht austauschbar, und jedes Token sieht nur sein Konto.
// Aufbau wie anmeldung.test.ts (echter Prozess, Wegwerf-Postgres, Apple und claude.ai über eingereichtes fetch).
import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash, generateKeyPairSync, randomBytes, randomUUID, sign } from "node:crypto";
import http from "node:http";
import { join } from "node:path";
import pg from "pg";
import { Client, StreamableHTTPClientTransport } from "@modelcontextprotocol/client";
import { loadAppleConfig } from "../src/apple.ts";
import { start } from "../src/main.ts";
import { oauthKeysFromEnv } from "../src/oauth-provider.ts";
import { transcriptDoc } from "./fixtures.ts";

type Doc = Record<string, any>;
type T = { after: (fn: () => Promise<void>) => void };
type Raw = { status: number; headers: http.IncomingHttpHeaders; body: string };

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL fehlt: die Tests laufen nur gegen echtes Postgres");
const migrations = join(import.meta.dirname, "../migrations");
const ORIGIN = "https://hhhaven.test";
const RESOURCE = `${ORIGIN}/mcp`;
const CID = "https://claude.ai/oauth/mcp-oauth-client-metadata";
const CB = "https://claude.ai/api/mcp/auth_callback";
const APP = "de.hhhaven.app";
const WEB = "de.hhhaven.app.web";
const KEYS_URL = "https://appleid.apple.com/auth/keys";
const TOKEN_URL = "https://appleid.apple.com/auth/token";
const REVOKE_URL = "https://appleid.apple.com/auth/revoke";
const PROXY = { host: "hhhaven.test", "x-forwarded-proto": "https" };
const FORM = { "content-type": "application/x-www-form-urlencoded" };
const HENNING = "001234.henning.0815";
const ANNA = "001234.anna.0815";
const FREMD = "001234.fremd.0815";
const RAW_NONCE = "nonce-roh-0815";

const rsa = generateKeyPairSync("rsa", { modulusLength: 2048 });
const JWK = { ...rsa.publicKey.export({ format: "jwk" }), kid: "R1", alg: "RS256", use: "sig" };
const ES256 = generateKeyPairSync("ec", { namedCurve: "P-256" });
const keys = oauthKeysFromEnv({
  OAUTH_COOKIE_KEYS: `cookie-schluessel-${randomBytes(16).toString("hex")}`,
  OAUTH_SIGNING_JWK: JSON.stringify(ES256.privateKey.export({ format: "jwk" })),
})!;
const config = loadAppleConfig({
  APPLE_TEAM_ID: "TEAMANM001", APPLE_KEY_ID: "KEYANM0001", APPLE_CLIENT_IDS: APP, APPLE_WEB_CLIENT_ID: WEB,
  APPLE_PRIVATE_KEY: (generateKeyPairSync("ec", { namedCurve: "P-256" }).privateKey.export({ type: "pkcs8", format: "pem" }) as string).replace(/\n/g, "\\n"),
  APPLE_TOKEN_KEY: randomBytes(32).toString("base64"),
});

const seg = (x: unknown) => Buffer.from(JSON.stringify(x)).toString("base64url");
const shaHex = (value: string) => createHash("sha256").update(value).digest("hex");

// Apple und claude.ai in einem eingereichten fetch: Schlüssel, Token-Endpunkt, Widerruf und Claudes Client-Dokument.
function fakeWorld() {
  const w = {
    sub: HENNING, nonce: "", revokes: [] as string[],
    id(aud: string, nonce: string): string {
      const now = Math.floor(Date.now() / 1000);
      const data = `${seg({ alg: "RS256", kid: "R1" })}.${seg({ iss: "https://appleid.apple.com", aud, sub: w.sub, iat: now, exp: now + 600, nonce })}`;
      return `${data}.${sign("sha256", Buffer.from(data), rsa.privateKey).toString("base64url")}`;
    },
    fetch: (async (input: string | URL | Request, init?: RequestInit) => {
      const url = String(input instanceof Request ? input.url : input);
      if (url === KEYS_URL) return Response.json({ keys: [JWK] });
      if (url === REVOKE_URL) { w.revokes.push(new URLSearchParams(String(init?.body)).get("client_id")!); return new Response("", { status: 200 }); }
      if (url === TOKEN_URL) {
        const aud = new URLSearchParams(String(init?.body)).get("client_id")!;
        return Response.json({ refresh_token: `REFRESH-${randomUUID()}`, id_token: w.id(aud, shaHex(w.nonce)) });
      }
      if (url === CID) {
        return Response.json({ client_id: CID, client_name: "Claude", redirect_uris: [CB], token_endpoint_auth_method: "none",
          grant_types: ["authorization_code", "refresh_token"], response_types: ["code"] });
      }
      return new Response("not found", { status: 404 });
    }) as typeof fetch,
  };
  return w;
}
type World = ReturnType<typeof fakeWorld>;

async function service(t: T, world: World, allowedSubs?: ReadonlySet<string>) {
  const admin = new pg.Pool({ connectionString: databaseUrl });
  const schema = `t_${randomUUID().replaceAll("-", "")}`;
  await admin.query(`CREATE SCHEMA ${schema}`);
  const parsed = new URL(databaseUrl!);
  parsed.searchParams.set("options", `-c search_path=${schema}`);
  const running = await start({
    databaseUrl: parsed.toString(), port: 0, migrationsDir: migrations, applicationName: `hh-anm-${randomUUID().slice(0, 8)}`,
    auth: { config, fetch: world.fetch, allowedSubs }, oauth: { publicUrl: ORIGIN, keys, fetch: world.fetch },
  });
  const pool = new pg.Pool({ connectionString: parsed.toString() });
  t.after(async () => { await running.close(); await pool.end(); await admin.query(`DROP SCHEMA ${schema} CASCADE`); await admin.end(); });
  await running.ready;
  return { ...running, pool };
}
type Running = Awaited<ReturnType<typeof service>>;

function raw(url: string, path: string, options: { method?: string; headers?: Record<string, string>; body?: string } = {}): Promise<Raw> {
  return new Promise((done, fail) => {
    const request = http.request(`${url}${path}`, { method: options.method ?? "GET", headers: { ...PROXY, ...options.headers } }, (answer) => {
      let body = "";
      answer.setEncoding("utf8");
      answer.on("data", (chunk) => { body += chunk; });
      answer.on("end", () => done({ status: answer.statusCode!, headers: answer.headers, body }));
    });
    request.on("error", fail);
    request.end(options.body);
  });
}

// Weg 1: Anmeldung in der App; liefert den Sitzungs-Token oder den Status der Ablehnung.
async function appSignIn(running: Running, world: World, sub: string): Promise<{ status: number; sessionToken?: string }> {
  world.sub = sub;
  const identityToken = world.id(APP, shaHex(RAW_NONCE));
  const answer = await raw(running.url, "/auth/apple", {
    method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ identityToken, nonce: RAW_NONCE, code: "CODE-APP" }),
  });
  return { status: answer.status, sessionToken: answer.status === 200 ? JSON.parse(answer.body).sessionToken : undefined };
}

type Jar = Map<string, string>;
async function step(running: Running, jar: Jar, path: string, options: { method?: string; headers?: Record<string, string>; body?: string } = {}): Promise<Raw> {
  const cookie = [...jar].map(([k, v]) => `${k}=${v}`).join("; ");
  const answer = await raw(running.url, path, { ...options, headers: { ...(cookie ? { cookie } : {}), ...options.headers } });
  for (const line of [answer.headers["set-cookie"] ?? []].flat()) {
    const [pair] = line.split(";");
    const at = pair.indexOf("=");
    jar.set(pair.slice(0, at), pair.slice(at + 1));
  }
  return answer;
}
// Folgt Weiterleitungen innerhalb des Dienstes bis zu einer Seite oder bis Claudes Rücksprung.
async function follow(running: Running, jar: Jar, first: Raw): Promise<{ page?: Raw; callback?: URL }> {
  let answer = first;
  for (let i = 0; i < 10; i++) {
    const location = answer.headers.location;
    if (location === undefined) return { page: answer };
    const next = new URL(location, ORIGIN);
    if (next.origin !== ORIGIN) return { callback: next };
    answer = await step(running, jar, `${next.pathname}${next.search}`);
  }
  throw new Error("zu viele Weiterleitungen");
}

// Weg 2: Web-Anmeldung für Claude. Ergebnis ist Claudes Rücksprung (code oder error) und die Zustimmungsseite, falls sie kam.
async function webSignIn(running: Running, world: World, sub: string): Promise<{ callback: URL; verifier: string; consent?: Raw }> {
  world.sub = sub;
  const verifier = randomBytes(32).toString("base64url");
  const query = new URLSearchParams({ client_id: CID, redirect_uri: CB, response_type: "code", scope: "habits offline_access", state: "s1",
    resource: RESOURCE, code_challenge: createHash("sha256").update(verifier).digest("base64url"), code_challenge_method: "S256" });
  const jar: Jar = new Map();
  const auth = await step(running, jar, `/oauth/auth?${query}`);
  const interaction = new URL(String(auth.headers.location), ORIGIN).pathname;
  const toApple = await step(running, jar, interaction);
  assert.equal(toApple.status, 303, `Hinweg: ${toApple.status} ${toApple.body.slice(0, 120)}`);
  const state = new URL(String(toApple.headers.location)).searchParams.get("state")!;
  const uid = interaction.split("/").at(-1)!;
  world.nonce = (await running.pool.query("SELECT payload FROM oauth_records WHERE model = 'AppleLogin' AND uid = $1", [uid])).rows[0].payload.nonce;
  const back = await raw(running.url, "/oauth/apple/return", { method: "POST", headers: FORM, body: new URLSearchParams({ state, code: "CODE-WEB" }).toString() });
  assert.equal(back.status, 303, `Rückweg: ${back.status}`);
  const finish = new URL(String(back.headers.location));
  const done = await follow(running, jar, await step(running, jar, `${finish.pathname}${finish.search}`));
  if (done.callback) return { callback: done.callback, verifier };
  const consent = done.page!;
  assert.equal(consent.status, 200, `Zustimmungsseite: ${consent.status}`);
  return { consent, verifier, ...(await confirm(running, jar, consent)) };
}
// "Zulassen" auf der Seite: das Formular der Seite wird gesendet, mit Origin des Dienstes.
async function confirm(running: Running, jar: Jar, consent: Raw): Promise<{ callback: URL }> {
  const action = /action="([^"]+\/confirm)"/.exec(consent.body)![1];
  const answer = await step(running, jar, action, { method: "POST", headers: { origin: ORIGIN } });
  const done = await follow(running, jar, answer);
  assert.ok(done.callback, "kein Rücksprung zu Claude");
  return { callback: done.callback };
}
async function tokenFor(running: Running, callback: URL, verifier: string): Promise<Doc> {
  const code = callback.searchParams.get("code");
  assert.ok(code, `kein Code: ${callback.href}`);
  const answer = await raw(running.url, "/oauth/token", { method: "POST", headers: FORM, body: new URLSearchParams({
    grant_type: "authorization_code", code, redirect_uri: CB, client_id: CID, code_verifier: verifier, resource: RESOURCE }).toString() });
  assert.equal(answer.status, 200, answer.body);
  return JSON.parse(answer.body);
}
async function claudeToken(running: Running, world: World, sub: string): Promise<{ token: Doc; consent: Raw }> {
  const result = await webSignIn(running, world, sub);
  assert.ok(result.consent, `keine Zustimmungsseite: ${result.callback}`);
  return { token: await tokenFor(running, result.callback, result.verifier), consent: result.consent };
}

async function mcp(t: T, running: Running, accessToken: string): Promise<Client> {
  const client = new Client({ name: "test", version: "1" });
  await client.connect(new StreamableHTTPClientTransport(new URL(`${running.url}/mcp`), { requestInit: { headers: { Authorization: `Bearer ${accessToken}` } } }));
  t.after(async () => { await client.close(); });
  return client;
}
const tool = async (client: Client, name: string, args: Doc = {}): Promise<Doc> => {
  const result: Doc = await client.callTool({ name, arguments: args });
  assert.notEqual(result.isError, true, JSON.stringify(result));
  return JSON.parse(result.content.map((part: Doc) => part.text).join(""));
};
const mcpStatus = async (running: Running, accessToken: string) => (await raw(running.url, "/mcp", {
  method: "POST", body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/list" }),
  headers: { "content-type": "application/json", accept: "application/json, text/event-stream", authorization: `Bearer ${accessToken}` },
}));

const appCall = (running: Running, session: string, path: string, body: unknown = {}, device = randomUUID()) => raw(running.url, path, {
  method: "POST", body: JSON.stringify(body), headers: { authorization: `Bearer ${session}`, "content-type": "application/json", "x-device": device },
});
const oauthRows = async (pool: pg.Pool, models: string[]) =>
  Number((await pool.query("SELECT count(*) FROM oauth_records WHERE model = ANY($1)", [models])).rows[0].count);
const GRANTS = ["Grant", "AccessToken", "RefreshToken", "AuthorizationCode", "Session"];
const count = async (pool: pg.Pool, table: string) => Number((await pool.query(`SELECT count(*) FROM ${table}`)).rows[0].count);

const A_ITEM = "claude.alpha-aaaaaa";
const B_ITEM = "claude.beta-bbbbbb";
const claudeItem = (id: string, name: string) => ({
  id, name, category: "core", origin: "claude", effect: `Wirkung ${name}.`, instructions: `Anleitung ${name}.`,
  revision: 1, state: "active", why: `Grund ${name}.`,
});
const ownDoc = (id: string, name: string) => ({ ...transcriptDoc(new Date().toISOString()), exercises: [claudeItem(id, name)] });
const accountId = async (pool: pg.Pool, sub: string) => (await pool.query("SELECT id FROM accounts WHERE apple_sub = $1", [sub])).rows[0].id as string;
const deliveriesOf = async (pool: pg.Pool, account: string) =>
  Number((await pool.query("SELECT count(*) FROM deliveries WHERE account_id = $1", [account])).rows[0].count);

type Person = { app: string; token: Doc; client: Client; account: string; delivery: string };
// Zwei Konten, je mit App-Sitzung, Claude-Token, Abschrift (mit einem Claude-Baustein) und einer wartenden Lieferung.
async function twoAccounts(t: T) {
  const world = fakeWorld();
  const running = await service(t, world, new Set([HENNING, ANNA]));
  async function person(sub: string, item: string, name: string): Promise<Person> {
    const app = await appSignIn(running, world, sub);
    assert.equal(app.status, 200);
    const { token } = await claudeToken(running, world, sub);
    const stored = await appCall(running, app.sessionToken!, "/app/transcript", ownDoc(item, name));
    assert.equal(stored.status, 204, stored.body);
    const client = await mcp(t, running, token.access_token);
    const delivered = await tool(client, "exercise_define", { name: `Neu ${name}`, category: "core", effect: "Wirkung.", instructions: "Anleitung.", why: "Grund." });
    return { app: app.sessionToken!, token, client, account: await accountId(running.pool, sub), delivery: delivered.deliveryId };
  }
  const a = await person(HENNING, A_ITEM, "Alpha");
  const b = await person(ANNA, B_ITEM, "Beta");
  return { running, a, b };
}

// 1. Eine App-Sitzung ist kein Claude-Token.
test("kreuz: gueltige app-sitzung an /mcp -> 401 mit www-authenticate", async (t) => {
  const { running, a } = await twoAccounts(t);
  const answer = await mcpStatus(running, a.app);
  assert.equal(answer.status, 401);
  assert.match(String(answer.headers["www-authenticate"]), /^Bearer /);
  assert.equal((await mcpStatus(running, a.token.access_token)).status !== 401, true, "Gegenprobe: das echte Claude-Token wird angenommen");
});

// 2. Claude-Access- und Refresh-Token sind keine App-Sitzung.
test("kreuz: claude-access- und refresh-token an den app-tueren -> 401", async (t) => {
  const { running, a } = await twoAccounts(t);
  const paths: [string, unknown][] = [
    ["/app/deliveries/claim", {}], ["/app/transcript", transcriptDoc(new Date().toISOString())],
    ["/app/deliveries/result", { deliveryId: a.delivery, outcome: "accepted" }], ["/auth/delete", {}],
  ];
  for (const credential of [a.token.access_token, a.token.refresh_token] as string[]) {
    for (const [path, body] of paths) {
      assert.equal((await appCall(running, credential, path, body)).status, 401, `${path} mit ${credential.slice(0, 6)}`);
    }
  }
  assert.equal(await count(running.pool, "accounts"), 2, "kein Konto gelöscht");
  assert.equal((await appCall(running, a.app, "/app/deliveries/claim")).status, 200, "Gegenprobe: die App-Sitzung wird angenommen");
});

// 3. Kein Zugriff über Kontengrenzen.
test("kreuz: claude-token von A sieht und aendert nur A, app-sitzung von A holt nichts von B", async (t) => {
  const { running, a, b } = await twoAccounts(t);
  const seen = async (p: Person) => ({
    overview: JSON.stringify(await tool(p.client, "overview")),
    catalog: JSON.stringify(await tool(p.client, "catalog", { kind: "exercise" })),
    status: JSON.stringify(await tool(p.client, "delivery_status", {})),
  });
  const sa = await seen(a);
  assert.ok(sa.catalog.includes("Alpha") && sa.catalog.includes(A_ITEM), "A sieht den eigenen Baustein");
  assert.ok(sa.status.includes(a.delivery), "A sieht die eigene Lieferung");
  for (const [name, text] of Object.entries(sa)) {
    assert.ok(!text.includes("Beta") && !text.includes(B_ITEM) && !text.includes(b.delivery), `${name} verrät etwas von B`);
  }
  const own = await tool(a.client, "show", { id: A_ITEM });
  assert.ok(JSON.stringify(own).includes("Alpha"), "show: eigener Baustein");
  const foreign: Doc = await a.client.callTool({ name: "show", arguments: { id: B_ITEM } });
  assert.ok(!JSON.stringify(foreign).includes("Beta") && !JSON.stringify(foreign).includes("Wirkung Beta"), "show: fremder Baustein");
  const foreignStatus = JSON.stringify(await a.client.callTool({ name: "delivery_status", arguments: { deliveryId: b.delivery } }));
  assert.ok(!foreignStatus.includes("Beta") && !foreignStatus.includes('"waiting"'), "delivery_status: fremde Lieferung");

  // Ändern und Zurückziehen fremder Bausteine scheitert und lässt B unberührt.
  const before = await deliveriesOf(running.pool, b.account);
  const beforeA = await deliveriesOf(running.pool, a.account);
  const update: Doc = await a.client.callTool({ name: "item_update", arguments: { itemId: B_ITEM, basedOnRevision: 1, why: "Fremd.",
    fields: { name: "Beta", category: "core", effect: "Gekapert.", instructions: "Gekapert." } } });
  const withdraw: Doc = await a.client.callTool({ name: "item_withdraw", arguments: { itemId: B_ITEM, why: "Fremd." } });
  assert.equal(update.isError, true, "item_update auf fremden Baustein");
  assert.equal(withdraw.isError, true, "item_withdraw auf fremden Baustein");
  assert.equal(await deliveriesOf(running.pool, b.account), before, "B hat neue Lieferungen");
  assert.equal(await deliveriesOf(running.pool, a.account), beforeA, "auch bei A entstand nichts");
  const states = (await running.pool.query("SELECT state FROM deliveries WHERE id = $1", [b.delivery])).rows;
  assert.deepEqual(states, [{ state: "waiting" }], "B's Lieferung unverändert");

  // App-Sitzung von A holt nur A's Lieferung; B's bleibt wartend.
  const device = randomUUID();
  const claim = await appCall(running, a.app, "/app/deliveries/claim", {}, device);
  assert.equal(claim.status, 200, claim.body);
  assert.equal(JSON.parse(claim.body).deliveryId, a.delivery);
  assert.equal((await appCall(running, a.app, "/app/deliveries/claim", {}, device)).status, 204, "A hat nichts weiter; B's Lieferung bleibt unsichtbar");
  const foreignResult = await appCall(running, a.app, "/app/deliveries/result", { deliveryId: b.delivery, outcome: "accepted" }, device);
  assert.equal(foreignResult.status, 409, "A kann B's Lieferung nicht beantworten");
  assert.equal((await running.pool.query("SELECT state FROM deliveries WHERE id = $1", [b.delivery])).rows[0].state, "waiting");
  const claimB = await appCall(running, b.app, "/app/deliveries/claim", {}, randomUUID());
  assert.equal(JSON.parse(claimB.body).deliveryId, b.delivery, "B holt die eigene Lieferung ab");
});
