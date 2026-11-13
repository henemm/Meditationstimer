// B2b Anmeldung (Issue #55): TDD RED. Spec: openspec/specs/integrations/claude-anmeldung.md Abschnitte 2, 3 und 5.
// Der ganze Weg läuft durch den echten Dienst (start) gegen ein Wegwerf-Postgres; nur Apple und claude.ai sind durch ein
// eingereichtes fetch ersetzt (Muster: oauth-return.test.ts und main.test.ts aus Loose Ends).
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
import { fillAccount, noRows, ownRows, transcriptDoc } from "./fixtures.ts";

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

// Spec 2: fremdes Konto, App-Weg. Nichts wird gespeichert.
test("tuer app: fremdes konto wird abgewiesen, nichts gespeichert", async (t) => {
  const world = fakeWorld();
  const running = await service(t, world, new Set([HENNING]));
  const refused = await appSignIn(running, world, FREMD);
  assert.deepEqual(refused, { status: 401, sessionToken: undefined });
  for (const table of ["accounts", "sessions", "apple_tokens", "oauth_records"]) assert.equal(await count(running.pool, table), 0, table);
  const welcome = await appSignIn(running, world, HENNING);
  assert.equal(welcome.status, 200, "das erlaubte Konto kommt hinein");
  assert.equal(await count(running.pool, "accounts"), 1);
});

// Spec 2: fremdes Konto, Web-Weg für Claude: access_denied, kein Konto, keine Sitzung, kein Apple-Token, kein OAuth-Grant.
test("tuer web: fremdes konto wird abgewiesen, nichts gespeichert", async (t) => {
  const world = fakeWorld();
  const running = await service(t, world, new Set([HENNING]));
  const refused = await webSignIn(running, world, FREMD);
  assert.equal(refused.callback.searchParams.get("error"), "access_denied");
  assert.equal(refused.callback.searchParams.get("code"), null);
  for (const table of ["accounts", "sessions", "apple_tokens"]) assert.equal(await count(running.pool, table), 0, table);
  assert.equal(await oauthRows(running.pool, GRANTS), 0, "OAuth-Grant, Code, Token oder Sitzung gespeichert");
  const { token } = await claudeToken(running, world, HENNING);
  assert.ok(token.access_token, "das erlaubte Konto kommt hinein");
  assert.equal(await count(running.pool, "accounts"), 1);
});

// Spec 2: ohne Liste kommt nur das erste Konto hinein, über beide Wege; dasselbe Konto danach wieder.
test("tuer ohne liste: erstes konto, danach nur noch dieses, ueber beide wege", async (t) => {
  const world = fakeWorld();
  const running = await service(t, world);
  assert.equal((await appSignIn(running, world, HENNING)).status, 200);
  assert.equal((await appSignIn(running, world, ANNA)).status, 401, "App: zweites Konto");
  const web = await webSignIn(running, world, ANNA);
  assert.equal(web.callback.searchParams.get("error"), "access_denied", "Web: zweites Konto");
  assert.equal(await count(running.pool, "accounts"), 1);
  assert.equal(await oauthRows(running.pool, GRANTS), 0);
  assert.ok((await claudeToken(running, world, HENNING)).token.access_token, "Web: das erste Konto");
  assert.equal(await count(running.pool, "accounts"), 1);
});

// Spec 3: ein Konto, zwei Wege; Claude liefert, die App holt ab; die App schickt die Abschrift, Claude liest sie.
test("ende zu ende: dasselbe konto ueber app und web, claude liefert, app holt ab", async (t) => {
  const world = fakeWorld();
  const running = await service(t, world, new Set([HENNING]));
  const app = await appSignIn(running, world, HENNING);
  assert.equal(app.status, 200);
  const { token, consent } = await claudeToken(running, world, HENNING);
  assert.ok(token.refresh_token, "offline_access: Claude bekommt ein Refresh-Token");
  assert.match(consent.body, /<h1>claude\.ai möchte auf Healthy Habits zugreifen<\/h1>/, "Zustimmungsseite nennt den Host der client_id");
  assert.equal(token.scope, "habits");
  const accounts = (await running.pool.query("SELECT id, apple_sub FROM accounts")).rows;
  assert.equal(accounts.length, 1, "genau ein Konto für beide Wege");
  assert.equal(accounts[0].apple_sub, HENNING);
  const owners = (await running.pool.query("SELECT DISTINCT account_id FROM oauth_records WHERE model IN ('Grant', 'AccessToken')")).rows;
  assert.deepEqual(owners, [{ account_id: accounts[0].id }], "Claudes Token gehört zum selben Konto");

  // App -> Claude: Abschrift
  const stored = await appCall(running, app.sessionToken!, "/app/transcript", transcriptDoc(new Date().toISOString()));
  assert.equal(stored.status, 204, stored.body);
  const claude = await mcp(t, running, token.access_token);
  const catalog = await tool(claude, "catalog", { kind: "exercise" });
  assert.ok(JSON.stringify(catalog).includes("builtin.planke"), "Claude liest die Abschrift der App");

  // Claude -> App: Lieferung
  const delivered = await tool(claude, "exercise_define", {
    name: "Käfer", category: "core", effect: "Stärkt die Bauchmuskeln.", instructions: "Auf den Rücken legen, Arme und Beine strecken.", why: "Fehlte für den Rücken.",
  });
  assert.equal(delivered.state, "waiting");
  const device = randomUUID();
  const claim = await appCall(running, app.sessionToken!, "/app/deliveries/claim", {}, device);
  assert.equal(claim.status, 200, claim.body);
  assert.equal(JSON.parse(claim.body).deliveryId, delivered.deliveryId);
  assert.equal((await appCall(running, app.sessionToken!, "/app/deliveries/claim", {}, device)).status, 204, "nichts weiter offen");
  const result = await appCall(running, app.sessionToken!, "/app/deliveries/result", { deliveryId: delivered.deliveryId, outcome: "accepted" }, device);
  assert.equal(result.status, 204, result.body);
  const status = await tool(claude, "delivery_status", { deliveryId: delivered.deliveryId });
  assert.equal(status.deliveries[0].state, "accepted", "Claude sieht die Antwort der App");
});

// Spec 5: Verbindung trennen löscht alles des Kontos; danach 401; ein anderes Konto bleibt unberührt.
test("verbindung trennen: alles des kontos weg, 401 fuer sitzung und claude-token, anderes konto unberuehrt", async (t) => {
  const world = fakeWorld();
  const running = await service(t, world, new Set([HENNING, ANNA]));
  const henning = { app: await appSignIn(running, world, HENNING), claude: (await claudeToken(running, world, HENNING)).token };
  const anna = { app: await appSignIn(running, world, ANNA), claude: (await claudeToken(running, world, ANNA)).token };
  assert.equal(henning.app.status, 200);
  assert.equal(anna.app.status, 200);
  const ids = Object.fromEntries((await running.pool.query("SELECT id, apple_sub FROM accounts")).rows.map((row) => [row.apple_sub, row.id]));
  await fillAccount(running.pool, ids[HENNING]);
  await fillAccount(running.pool, ids[ANNA]);
  const annaBefore = await ownRows(running.pool, ids[ANNA]);
  const annaOauth = (await running.pool.query("SELECT count(*) FROM oauth_records WHERE account_id = $1 OR grant_id IN (SELECT grant_id FROM oauth_records WHERE account_id = $1)", [ids[ANNA]])).rows[0].count;
  assert.ok(annaBefore.deliveries > 0 && annaBefore.transcripts > 0 && annaBefore.wishes > 0 && annaBefore.delivery_events > 0);

  const gone = await raw(running.url, "/auth/delete", { method: "POST", headers: { authorization: `Bearer ${henning.app.sessionToken}` } });
  assert.equal(gone.status, 204);
  assert.deepEqual(await ownRows(running.pool, ids[HENNING]), noRows, "Zeilen des Kontos übrig");
  const left = (await running.pool.query("SELECT count(*) FROM oauth_records WHERE account_id = $1 OR payload::text LIKE '%' || $1 || '%'", [ids[HENNING]])).rows[0].count;
  assert.equal(Number(left), 0, "OAuth-Datensätze des Kontos übrig");
  assert.deepEqual(world.revokes.sort(), [APP, WEB].sort(), "Apple-Tokens beider Wege widerrufen");

  assert.equal((await appCall(running, henning.app.sessionToken!, "/app/deliveries/claim")).status, 401, "App-Sitzung nach dem Trennen");
  const closed = await mcpStatus(running, henning.claude.access_token);
  assert.equal(closed.status, 401, "Claude-Token nach dem Trennen");
  assert.match(String(closed.headers["www-authenticate"]), /^Bearer /);
  const refresh = await raw(running.url, "/oauth/token", { method: "POST", headers: FORM,
    body: new URLSearchParams({ grant_type: "refresh_token", refresh_token: henning.claude.refresh_token, client_id: CID }).toString() });
  assert.equal(refresh.status, 400, "Refresh-Token nach dem Trennen");

  assert.deepEqual(await ownRows(running.pool, ids[ANNA]), annaBefore, "anderes Konto verändert");
  assert.equal(Number((await running.pool.query("SELECT count(*) FROM oauth_records WHERE account_id = $1 OR grant_id IN (SELECT grant_id FROM oauth_records WHERE account_id = $1)", [ids[ANNA]])).rows[0].count), Number(annaOauth));
  assert.equal((await appCall(running, anna.app.sessionToken!, "/app/deliveries/claim")).status, 200, "Sitzung des anderen Kontos gilt");
  assert.notEqual((await mcpStatus(running, anna.claude.access_token)).status, 401, "Claude-Token des anderen Kontos gilt");
});
