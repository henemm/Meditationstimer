// B2a-6 Nachträge (Issue #54): TDD RED. Spec: claude-dienst.md Abschnitt 6, Punkt "Körper der App-Schnittstelle".
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
const ACC = "konto-a";

async function setup(t: Parameters<typeof freshPool>[0]) {
  const pool = await freshPool(t);
  await migrate(pool, join(import.meta.dirname, "..", "migrations"));
  return { pool, routes: appRoutes({ pool, appAccount: async () => ACC }) };
}
function post(path: string, body: Uint8Array<ArrayBuffer>, device = randomUUID()): Request {
  return new Request(`http://localhost${path}`, { method: "POST", headers: { "X-Device": device, "Content-Type": "application/json" }, body });
}
const bytes = (s: string): Uint8Array<ArrayBuffer> => new TextEncoder().encode(s) as Uint8Array<ArrayBuffer>;
async function transcriptText(): Promise<string> {
  const f = JSON.parse(await readFile(join(root, "Contracts", "transcript", "valid", "full.json"), "utf8"));
  return JSON.stringify({ ...f.transcript, generatedAt: "2026-11-13T10:00:00Z" });
}
async function claimedDelivery(t: Parameters<typeof freshPool>[0]) {
  const s = await setup(t);
  const f = JSON.parse(await readFile(join(root, "Contracts", "deliveries", "valid", "exercise-minimal.json"), "utf8"));
  const id = randomUUID();
  await putDelivery(s.pool, ACC, { ...f.delivery, deliveryId: id });
  const device = randomUUID();
  assert.equal((await claimDelivery(s.pool, ACC, device))?.deliveryId, id);
  return { ...s, id, device };
}

function broken(kind: string, text: string, slot: "value" | "key"): Uint8Array<ArrayBuffer> {
  // Wert: der Schadtext steckt im Wert eines vorhandenen, sonst gültigen Namens (tief im Transcript).
  // Schlüssel: zusätzliches Feld vorn.
  const NAME = '"name":"';
  const at = text.indexOf(NAME, text.indexOf('"exercises"'));
  assert.ok(at > 0, "Beispiel-Transcript hat keinen Namen");
  const cut = at + NAME.length;
  const frag = kind === "nul" ? "a\\u0000b" : "a\\ud800b";
  if (slot === "value") {
    if (kind === "utf8") return concat(bytes(text.slice(0, cut) + "a"), Uint8Array.from([0xff]), bytes("b" + text.slice(cut)));
    return bytes(text.slice(0, cut) + frag + text.slice(cut));
  }
  return bytes(`{"${frag}":"x",${text.slice(1)}`);
}
function concat(...parts: Uint8Array[]): Uint8Array<ArrayBuffer> {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let at = 0;
  for (const p of parts) { out.set(p, at); at += p.length; }
  return out;
}

const variants: [string, string, "value" | "key"][] = [
  ["ungültiges UTF-8 (0xFF)", "utf8", "value"],
  ["\\u0000 in einem Wert", "nul", "value"],
  ["\\u0000 in einem Schlüssel", "nul", "key"],
  ["einzelnes Surrogat \\ud800 tief verschachtelt in einem Wert", "sur", "value"],
  ["einzelnes Surrogat \\ud800 in einem Schlüssel", "sur", "key"],
];

for (const [label, kind, slot] of variants) {
  test(`/app/transcript: ${label} -> 400, nie 500, nichts gespeichert`, async (t) => {
    const { pool, routes } = await setup(t);
    const res = await routes["/app/transcript"](post("/app/transcript", broken(kind, await transcriptText(), slot)));
    assert.equal(res.status, 400);
    assert.equal(await getTranscript(pool, ACC), undefined);
  });
}

// Für das Ergebnis: ein sonst gültiger rejected-Körper, der Schadtext steckt tief in errors[0].message bzw. in einem Schlüssel.
function resultBody(kind: string, slot: "value" | "key", id: string): Uint8Array<ArrayBuffer> {
  const head = `{"deliveryId":"${id}","outcome":"rejected","errors":[{"code":"c","path":"p",`;
  switch (kind) {
    case "utf8": return concat(bytes(`${head}"message":"a`), Uint8Array.from([0xff]), bytes('b"}]}'));
    case "nul": return bytes(slot === "value" ? `${head}"message":"a\\u0000b"}]}` : `${head}"message":"m","a\\u0000b":"x"}]}`);
    default: return bytes(slot === "value" ? `${head}"message":"a\\ud800b"}]}` : `${head}"message":"m","a\\ud800b":"x"}]}`);
  }
}
for (const [label, kind, slot] of variants) {
  test(`/app/deliveries/result: ${label} -> 400, nie 500, Lieferung bleibt claimed`, async (t) => {
    const s = await claimedDelivery(t);
    const res = await s.routes["/app/deliveries/result"](post("/app/deliveries/result", resultBody(kind, slot, s.id), s.device));
    assert.equal(res.status, 400);
    assert.equal((await listDeliveries(s.pool, ACC, { deliveryId: s.id }))[0].state, "claimed");
  });
}

test("/app/deliveries/claim: Körper mit \\u0000 oder ungültigem UTF-8 -> 400, nie 500", async (t) => {
  const { routes } = await setup(t);
  for (const body of [bytes('{"a\\u0000b":1}'), concat(bytes('{"a":"'), Uint8Array.from([0xff]), bytes('"}')), bytes('{"a":"\\ud800"}')]) {
    assert.equal((await routes["/app/deliveries/claim"](post("/app/deliveries/claim", body))).status, 400);
  }
});
