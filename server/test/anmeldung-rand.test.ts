// B2b Anmeldung (Issue #55): Eigenheiten der Claude-Anmeldung, die sich im Code zeigen und in den übernommenen Tests keinen
// eigenen Fall hatten (DOCS/claude-anmeldung-pruefliste.md, Nr. 11, 13, 17, 22). Der Dienst läuft echt, claude.ai ist ein eingereichtes fetch.
import { test } from "node:test";
import assert from "node:assert/strict";
import { generateKeyPairSync, randomUUID } from "node:crypto";
import http from "node:http";
import { join } from "node:path";
import pg from "pg";
import { OAuthError, OAuthErrorCode, type AuthInfo } from "@modelcontextprotocol/server";
import { findOrCreate } from "../src/accounts.ts";
import { start } from "../src/main.ts";
import { oauthKeysFromEnv } from "../src/oauth-provider.ts";

type T = { after: (fn: () => Promise<void>) => void };
type Raw = { status: number; headers: http.IncomingHttpHeaders; body: string };

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL fehlt: die Tests laufen nur gegen echtes Postgres");
const migrations = join(import.meta.dirname, "../migrations");
const ORIGIN = "https://hhhaven.test";
const CODE_CID = "https://claude.ai/oauth/claude-code-client-metadata";
const WEB_CID = "https://claude.ai/oauth/mcp-oauth-client-metadata";
const PROXY = { host: "hhhaven.test", "x-forwarded-proto": "https" };
const keys = oauthKeysFromEnv({
  OAUTH_COOKIE_KEYS: "cookie-schluessel-".padEnd(40, "k"),
  OAUTH_SIGNING_JWK: JSON.stringify(generateKeyPairSync("ec", { namedCurve: "P-256" }).privateKey.export({ format: "jwk" })),
})!;

// Claudes Client-Dokumente: das gehostete (Rücksprung bei claude.ai) und das von Claude Code (Loopback, kein application_type).
const documents: Record<string, object> = {
  [WEB_CID]: { client_id: WEB_CID, client_name: "Claude", redirect_uris: ["https://claude.ai/api/mcp/auth_callback"], token_endpoint_auth_method: "none",
    grant_types: ["authorization_code", "refresh_token"], response_types: ["code"] },
  [CODE_CID]: { client_id: CODE_CID, client_name: "Claude Code", redirect_uris: ["http://localhost/callback", "http://127.0.0.1/callback"],
    token_endpoint_auth_method: "none", grant_types: ["authorization_code", "refresh_token"], response_types: ["code"] },
};
const claudeFetch = (async (input: string | URL | Request) => {
  const url = String(input instanceof Request ? input.url : input);
  return url in documents ? Response.json(documents[url]) : new Response("not found", { status: 404 });
}) as typeof fetch;

async function service(t: T, oauth: Record<string, unknown> = {}) {
  const admin = new pg.Pool({ connectionString: databaseUrl });
  const schema = `t_${randomUUID().replaceAll("-", "")}`;
  await admin.query(`CREATE SCHEMA ${schema}`);
  const parsed = new URL(databaseUrl!);
  parsed.searchParams.set("options", `-c search_path=${schema}`);
  const running = await start({ databaseUrl: parsed.toString(), port: 0, migrationsDir: migrations, applicationName: `hh-rand-${randomUUID().slice(0, 8)}`,
    oauth: { publicUrl: ORIGIN, keys, fetch: claudeFetch, ...oauth } });
  const pool = new pg.Pool({ connectionString: parsed.toString() });
  t.after(async () => { await running.close(); await pool.end(); await admin.query(`DROP SCHEMA ${schema} CASCADE`); await admin.end(); });
  await running.ready;
  return { ...running, pool };
}

function raw(url: string, path: string, options: { method?: string; headers?: Record<string, string>; body?: string } = {}): Promise<Raw> {
  return new Promise((done, fail) => {
    const request = http.request(`${url}${path}`, { method: options.method ?? "GET", headers: options.headers }, (answer) => {
      let body = "";
      answer.setEncoding("utf8");
      answer.on("data", (chunk) => { body += chunk; });
      answer.on("end", () => done({ status: answer.statusCode!, headers: answer.headers, body }));
    });
    request.on("error", fail);
    request.end(options.body);
  });
}
const authorize = (clientId: string, redirectUri: string) => `/oauth/auth?${new URLSearchParams({
  client_id: clientId, redirect_uri: redirectUri, response_type: "code", scope: "habits offline_access", state: "s1",
  resource: `${ORIGIN}/mcp`, code_challenge: "c".repeat(43), code_challenge_method: "S256" })}`;

// Nr. 11: claude.ai folgt den MCP-Revisionen 2025-03-26, 2025-06-18 und 2025-11-25 und beginnt mit initialize.
test("mcp revisionen: initialize wird in allen drei Revisionen beantwortet", async (t) => {
  let account = "";
  const verifier = { verifyAccessToken: async (token: string): Promise<AuthInfo> => {
    if (token !== "gut") throw new OAuthError(OAuthErrorCode.InvalidToken, "unknown");
    return { token, clientId: "claude-test", scopes: ["habits"], expiresAt: Math.floor(Date.now() / 1000) + 3600, resource: new URL(`${ORIGIN}/mcp`), extra: { account } };
  } };
  const running = await service(t, { verifier });
  account = await findOrCreate(running.pool, "001234.revisionen.0815");
  for (const protocolVersion of ["2025-03-26", "2025-06-18", "2025-11-25"]) {
    const answer = await raw(running.url, "/mcp", { method: "POST", body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "initialize",
      params: { protocolVersion, capabilities: {}, clientInfo: { name: "claude-ai", version: "1" } } }),
    headers: { "content-type": "application/json", accept: "application/json, text/event-stream", authorization: "Bearer gut" } });
    assert.equal(answer.status, 200, `${protocolVersion}: ${answer.status} ${answer.body.slice(0, 200)}`);
    const result = JSON.parse(/^data: (.*)$/m.exec(answer.body)?.[1] ?? answer.body).result;
    assert.equal(result.protocolVersion, protocolVersion, `${protocolVersion}: Revision nicht bestätigt`);
    assert.equal(result.serverInfo.name, "healthy-habits");
  }
});

// Nr. 13: Claude Code ruft mit einem Loopback-Rücksprung samt Port zurück; sein Dokument hat kein application_type: native.
// Das ist wie in Loose Ends nicht unterstützt. Der Test hält fest, dass der Dienst dann nicht zum Loopback weiterleitet.
test("claude code: loopback-ruecksprung mit port wird abgelehnt, ohne weiterleitung", async (t) => {
  const running = await service(t);
  const refused = await raw(running.url, authorize(CODE_CID, "http://localhost:51234/callback"), { headers: PROXY });
  assert.equal(refused.status, 400);
  assert.match(refused.body, /invalid_redirect_uri/);
  assert.equal(refused.headers.location, undefined, "Weiterleitung zum Loopback");
  const listed = await raw(running.url, authorize(CODE_CID, "http://localhost/callback"), { headers: PROXY });
  assert.equal(listed.status, 303, "der im Dokument genannte Rücksprung ohne Port gilt");
});

// Nr. 17: TLS endet am nginx; provider.proxy = true heißt, X-Forwarded-Proto zählt. Mit https markiert der Dienst sein Cookie secure.
test("proxy: x-forwarded-proto bestimmt das secure-cookie, der aussteller bleibt der konfigurierte origin", async (t) => {
  const running = await service(t);
  const cookies = async (headers: Record<string, string>) => {
    const answer = await raw(running.url, authorize(WEB_CID, "https://claude.ai/api/mcp/auth_callback"), { headers });
    assert.equal(answer.status, 303, answer.body);
    return [answer.headers["set-cookie"] ?? []].flat();
  };
  const behind = await cookies(PROXY);
  assert.ok(behind.length > 0 && behind.every((line) => /;\s*secure/i.test(line)), `Cookies hinter dem Proxy ohne secure: ${behind.join(" | ")}`);
  const direct = await cookies({ host: "hhhaven.test" });
  assert.ok(direct.length > 0 && direct.every((line) => !/;\s*secure/i.test(line)), "ohne X-Forwarded-Proto gilt die Verbindung als unverschlüsselt");
  for (const host of ["hhhaven.test", "evil.example"]) {
    const meta = JSON.parse((await raw(running.url, "/.well-known/oauth-authorization-server", { headers: { ...PROXY, host } })).body);
    assert.equal(meta.issuer, ORIGIN, `Aussteller folgt dem Host ${host}`);
  }
});

// Nr. 22: id_token_signed_response_alg ES256, weil der Dienst nur einen ES256-Schlüssel hat; sonst wäre Claudes Dokument ohne Angabe ungültig.
test("es256: der aussteller kennt nur ES256 und claudes dokument ohne angabe wird angenommen", async (t) => {
  const running = await service(t);
  const meta = JSON.parse((await raw(running.url, "/.well-known/openid-configuration", { headers: PROXY })).body);
  assert.deepEqual(meta.id_token_signing_alg_values_supported, ["ES256"]);
  assert.equal((await raw(running.url, authorize(WEB_CID, "https://claude.ai/api/mcp/auth_callback"), { headers: PROXY })).status, 303);
});
