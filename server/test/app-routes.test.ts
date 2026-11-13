// B2a-3 App-Schnittstelle (Issue #54): TDD RED. Spec: openspec/specs/integrations/claude-dienst.md Abschnitt 5
import { test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { migrate } from "../src/migrate.ts";
import { appRoutes } from "../src/app-routes.ts";
import { claimDelivery, listDeliveries, putDelivery } from "../src/deliveries.ts";
import { getTranscript } from "../src/transcripts.ts";
import { freshPool } from "./db.ts";

const root = join(import.meta.dirname, "..", "..");
const migrationsDir = join(import.meta.dirname, "..", "migrations");
const ACC = "konto-a";
const SECRET = "GEHEIMER-INHALT-XYZ";

async function setup(t: Parameters<typeof freshPool>[0], account: (req: Request) => Promise<string | undefined> =
  async (req) => req.headers.get("X-Test-Account") ?? undefined) {
  const pool = await freshPool(t);
  await migrate(pool, migrationsDir);
  return { pool, routes: appRoutes({ pool, appAccount: account }) };
}

type Opts = { method?: string; device?: string | null; account?: string | null; type?: string | null; body?: string };
function req(path: string, o: Opts = {}): Request {
  const headers: Record<string, string> = {};
  if (o.account !== null) headers["X-Test-Account"] = o.account ?? ACC;
  if (o.device !== null) headers["X-Device"] = o.device ?? randomUUID();
  if (o.type !== null) headers["Content-Type"] = o.type ?? "application/json";
  const method = o.method ?? "POST";
  return new Request(`http://localhost${path}`, { method, headers, body: method === "GET" || method === "HEAD" ? undefined : (o.body ?? "{}") });
}
const json = (v: unknown) => JSON.stringify(v);

async function transcript(generatedAt = "2026-11-13T10:00:00Z"): Promise<Record<string, unknown>> {
  const f = JSON.parse(await readFile(join(root, "Contracts", "transcript", "valid", "full.json"), "utf8"));
  return { ...f.transcript, generatedAt };
}
async function sample(id: string = randomUUID()) {
  const f = JSON.parse(await readFile(join(root, "Contracts", "deliveries", "valid", "exercise-minimal.json"), "utf8"));
  return { ...f.delivery, deliveryId: id };
}
const errs = [{ code: "x", path: "items[0]", message: "kaputt" }];
const PATHS = ["/app/transcript", "/app/deliveries/claim", "/app/deliveries/result"];

test("Routen: die drei Schluessel sind da", async (t) => {
  const { routes } = await setup(t);
  for (const p of PATHS) assert.equal(typeof routes[p], "function", p);
});

for (const p of PATHS) {
  test(`${p}: GET gibt 405`, async (t) => {
    const { routes } = await setup(t);
    assert.equal((await routes[p](req(p, { method: "GET" }))).status, 405);
  });

  test(`${p}: ohne Konto 401, vor Geraetepruefung`, async (t) => {
    const { routes } = await setup(t, async () => undefined);
    assert.equal((await routes[p](req(p, { device: "kaputt", type: "text/plain" }))).status, 401);
  });

  test(`${p}: 405 kommt vor 401`, async (t) => {
    const { routes } = await setup(t, async () => undefined);
    assert.equal((await routes[p](req(p, { method: "GET" }))).status, 405);
  });
}

for (const p of PATHS.slice(1)) {
  test(`${p}: fehlender X-Device 400`, async (t) => {
    const { routes } = await setup(t);
    assert.equal((await routes[p](req(p, { device: null }))).status, 400);
  });
  test(`${p}: X-Device keine UUID 400`, async (t) => {
    const { routes } = await setup(t);
    assert.equal((await routes[p](req(p, { device: "gerät-1" }))).status, 400);
  });
  test(`${p}: 400 (Geraet) kommt vor 415`, async (t) => {
    const { routes } = await setup(t);
    assert.equal((await routes[p](req(p, { device: "nein", type: "text/plain" }))).status, 400);
  });
}

for (const p of PATHS) {
  test(`${p}: kein application/json gibt 415, vor 413`, async (t) => {
    const { routes } = await setup(t);
    assert.equal((await routes[p](req(p, { type: "text/plain", body: "x".repeat(300 * 1024) }))).status, 415);
    assert.equal((await routes[p](req(p, { type: null }))).status, 415);
  });
  test(`${p}: Koerper ueber 256 KiB gibt 413, vor 400 (Form)`, async (t) => {
    const { routes } = await setup(t);
    const big = json({ pad: "x".repeat(260 * 1024) });
    assert.equal((await routes[p](req(p, { body: big }))).status, 413);
  });
  test(`${p}: kein JSON gibt 400 ohne Inhalt aus dem Koerper`, async (t) => {
    const { routes } = await setup(t);
    const res = await routes[p](req(p, { body: `{"${SECRET}": ` }));
    assert.equal(res.status, 400);
    assert.ok(!(await res.text()).includes(SECRET));
  });
}

test("/app/transcript: gueltig gibt 204 und wird gespeichert", async (t) => {
  const { pool, routes } = await setup(t);
  const doc = await transcript();
  const res = await routes["/app/transcript"](req("/app/transcript", { body: json(doc) }));
  assert.equal(res.status, 204);
  assert.deepEqual(await getTranscript(pool, ACC) as unknown, doc);
});

test("/app/transcript: ungueltige Form gibt 400, nichts gespeichert, Antwort ohne Inhalte", async (t) => {
  const { pool, routes } = await setup(t);
  const res = await routes["/app/transcript"](req("/app/transcript", { body: json({ version: 1, [SECRET]: "geheim" }) }));
  assert.equal(res.status, 400);
  assert.ok(!(await res.text()).includes(SECRET));
  assert.equal(await getTranscript(pool, ACC), undefined);
});

test("/app/transcript: generatedAt am 30. Februar gibt 400 (nicht 500), nichts gespeichert", async (t) => {
  const { pool, routes } = await setup(t);
  const res = await routes["/app/transcript"](req("/app/transcript", { body: json(await transcript("2026-02-30T10:00:00Z")) }));
  assert.equal(res.status, 400);
  assert.equal(await getTranscript(pool, ACC), undefined);
});

test("/app/transcript: aeltere oder gleich alte gibt 204 ohne Wirkung", async (t) => {
  const { pool, routes } = await setup(t);
  const neu = await transcript("2026-11-13T12:00:00Z");
  assert.equal((await routes["/app/transcript"](req("/app/transcript", { body: json(neu) }))).status, 204);
  const alt = { ...(await transcript("2026-11-13T09:00:00Z")), exercises: [] };
  assert.equal((await routes["/app/transcript"](req("/app/transcript", { body: json(alt) }))).status, 204);
  assert.equal((await routes["/app/transcript"](req("/app/transcript", { body: json({ ...neu, exercises: [] }) }))).status, 204);
  assert.deepEqual(await getTranscript(pool, ACC) as unknown, neu);
});

test("/app/transcript: Konto kommt aus appAccount", async (t) => {
  const { pool, routes } = await setup(t);
  await routes["/app/transcript"](req("/app/transcript", { account: "konto-b", body: json(await transcript()) }));
  assert.ok(await getTranscript(pool, "konto-b"));
  assert.equal(await getTranscript(pool, ACC), undefined);
});

test("/app/deliveries/claim: 204 wenn nichts wartet", async (t) => {
  const { routes } = await setup(t);
  const res = await routes["/app/deliveries/claim"](req("/app/deliveries/claim"));
  assert.equal(res.status, 204);
});

test("/app/deliveries/claim: 200 mit deliveryId und delivery, aelteste zuerst", async (t) => {
  const { pool, routes } = await setup(t);
  const a = await sample();
  const b = await sample();
  await putDelivery(pool, ACC, a);
  await putDelivery(pool, ACC, b);
  const res = await routes["/app/deliveries/claim"](req("/app/deliveries/claim"));
  assert.equal(res.status, 200);
  assert.match(res.headers.get("content-type") ?? "", /application\/json/);
  assert.deepEqual(await res.json(), { deliveryId: a.deliveryId, delivery: a });
  const second = await routes["/app/deliveries/claim"](req("/app/deliveries/claim"));
  assert.equal(((await second.json()) as { deliveryId: string }).deliveryId, b.deliveryId);
  assert.equal((await routes["/app/deliveries/claim"](req("/app/deliveries/claim"))).status, 204);
});

test("/app/deliveries/claim: fremdes Konto sieht nichts", async (t) => {
  const { pool, routes } = await setup(t);
  await putDelivery(pool, ACC, await sample());
  assert.equal((await routes["/app/deliveries/claim"](req("/app/deliveries/claim", { account: "konto-b" }))).status, 204);
});

async function claimed(t: Parameters<typeof freshPool>[0]) {
  const s = await setup(t);
  const doc = await sample();
  await putDelivery(s.pool, ACC, doc);
  const device = randomUUID();
  const res = await s.routes["/app/deliveries/claim"](req("/app/deliveries/claim", { device }));
  assert.equal(res.status, 200);
  return { ...s, id: doc.deliveryId, device };
}
const result = (s: { routes: Record<string, (r: Request) => Promise<Response>> }, device: string, body: unknown) =>
  s.routes["/app/deliveries/result"](req("/app/deliveries/result", { device, body: json(body) }));

test("/app/deliveries/result: accepted gibt 204 und Zustand accepted", async (t) => {
  const s = await claimed(t);
  assert.equal((await result(s, s.device, { deliveryId: s.id, outcome: "accepted" })).status, 204);
  assert.equal((await listDeliveries(s.pool, ACC, { deliveryId: s.id }))[0].state, "accepted");
});

test("/app/deliveries/result: rejected mit errors gibt 204 und speichert sie", async (t) => {
  const s = await claimed(t);
  assert.equal((await result(s, s.device, { deliveryId: s.id, outcome: "rejected", errors: errs })).status, 204);
  const [row] = await listDeliveries(s.pool, ACC, { deliveryId: s.id });
  assert.equal(row.state, "rejected");
  assert.deepEqual(row.errors, errs);
});

test("/app/deliveries/result: fremdes Geraet gibt 409", async (t) => {
  const s = await claimed(t);
  assert.equal((await result(s, randomUUID(), { deliveryId: s.id, outcome: "accepted" })).status, 409);
});

test("/app/deliveries/result: zweites Ergebnis gibt 409", async (t) => {
  const s = await claimed(t);
  assert.equal((await result(s, s.device, { deliveryId: s.id, outcome: "accepted" })).status, 204);
  assert.equal((await result(s, s.device, { deliveryId: s.id, outcome: "accepted" })).status, 409);
});

test("/app/deliveries/result: fremdes Konto gibt 409", async (t) => {
  const s = await claimed(t);
  const res = await s.routes["/app/deliveries/result"](req("/app/deliveries/result",
    { account: "konto-b", device: s.device, body: json({ deliveryId: s.id, outcome: "accepted" }) }));
  assert.equal(res.status, 409);
});

const bad: Array<[string, (id: string) => unknown]> = [
  ["errors an accepted", (id) => ({ deliveryId: id, outcome: "accepted", errors: errs })],
  ["rejected ohne errors", (id) => ({ deliveryId: id, outcome: "rejected" })],
  ["rejected mit leerer errors-Liste", (id) => ({ deliveryId: id, outcome: "rejected", errors: [] })],
  ["101 Fehler", (id) => ({ deliveryId: id, outcome: "rejected", errors: Array.from({ length: 101 }, () => errs[0]) })],
  ["message ueber 300 Zeichen", (id) => ({ deliveryId: id, outcome: "rejected", errors: [{ ...errs[0], message: "m".repeat(301) }] })],
  ["leere message", (id) => ({ deliveryId: id, outcome: "rejected", errors: [{ ...errs[0], message: "" }] })],
  ["fehlendes code", (id) => ({ deliveryId: id, outcome: "rejected", errors: [{ path: "p", message: "m" }] })],
  ["unbekannter outcome", (id) => ({ deliveryId: id, outcome: "maybe" })],
  ["fehlender outcome", (id) => ({ deliveryId: id })],
  ["fehlende deliveryId", () => ({ outcome: "accepted" })],
  ["Koerper kein Objekt", () => [1, 2]],
];
for (const [name, make] of bad) {
  test(`/app/deliveries/result: ${name} gibt 400, Lieferung bleibt claimed, ohne Inhalte in der Antwort`, async (t) => {
    const s = await claimed(t);
    const body = make(s.id) as Record<string, unknown>;
    const res = await result(s, s.device, Array.isArray(body) ? body : { ...body, [SECRET]: SECRET });
    assert.equal(res.status, 400);
    assert.ok(!(await res.text()).includes(SECRET));
    assert.equal((await listDeliveries(s.pool, ACC, { deliveryId: s.id }))[0].state, "claimed");
  });
}

test("/app/deliveries/result: genau 100 Fehler und message mit 300 Zeichen sind erlaubt", async (t) => {
  const s = await claimed(t);
  const errors = Array.from({ length: 100 }, () => ({ code: "c", path: "p", message: "m".repeat(300) }));
  assert.equal((await result(s, s.device, { deliveryId: s.id, outcome: "rejected", errors })).status, 204);
});

test("Parallele Abholung ueber die Route: jede Lieferung hoechstens einmal", async (t) => {
  const { pool, routes } = await setup(t);
  for (let i = 0; i < 3; i++) await putDelivery(pool, ACC, await sample());
  const rs = await Promise.all(Array.from({ length: 5 }, () => routes["/app/deliveries/claim"](req("/app/deliveries/claim"))));
  const ok = rs.filter((r) => r.status === 200);
  assert.equal(ok.length, 3);
  assert.equal(rs.filter((r) => r.status === 204).length, 2);
  assert.equal(new Set(await Promise.all(ok.map(async (r) => ((await r.json()) as { deliveryId: string }).deliveryId))).size, 3);
  void claimDelivery;
});
