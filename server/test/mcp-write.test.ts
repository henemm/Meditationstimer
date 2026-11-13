// B2a-5 Lieferwerkzeuge (Issue #54): TDD RED. Spec: openspec/specs/integrations/claude-dienst.md Abschnitt 6
// ("Regeln der Lieferwerkzeuge", "Umsetzung der Lieferwerkzeuge (B2a-5)") und claude-lieferformat.md.
import { test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import type pg from "pg";
import { migrate } from "../src/migrate.ts";
import { putTranscript } from "../src/transcripts.ts";
import { claimDelivery, listDeliveries } from "../src/deliveries.ts";
import { validateDelivery } from "../../Contracts/validator/src/index.ts";
import { freshPool } from "./db.ts";
import { call, connect, json, type Doc, type T } from "./mcp-client.ts";

const root = join(import.meta.dirname, "..", "..");
const migrations = join(import.meta.dirname, "..", "migrations");
const HENNING = "henning";
const ANNA = "anna";
const DEVICE = randomUUID();
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const WRITE_TOOLS = ["exercise_define", "program_create", "breath_create", "item_update", "item_withdraw", "wish_report"];

const read = (...parts: string[]): any => JSON.parse(readFileSync(join(root, ...parts), "utf8"));
const fullTranscript = (): Doc => read("Contracts", "transcript", "valid", "full.json").transcript;
const emptyTranscript = (): Doc => read("Contracts", "transcript", "valid", "empty.json").transcript;
const OWN_ID = "own.7d3e9c1a-52b4-4f08-8e6a-0c9b1d2e3f45"; // "Schulterkreisen" in full.json
const ACTIVE_EXERCISE = "claude.vierfuessler-diagonal-x3f9k2"; // active, Revision 1, Paket claude.ruecken-november
const ADAPTED_PROGRAM = "claude.ruecken-a-7hq2mz"; // adapted, Revision 2
const WITHDRAWN_BREATH = "claude.abendatem-p0x8rt"; // withdrawn

async function migrated(t: T): Promise<pg.Pool> {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  return pool;
}

async function withTranscript(pool: pg.Pool, account = HENNING, doc: Doc = fullTranscript()): Promise<void> {
  doc.generatedAt = new Date().toISOString();
  assert.equal(await putTranscript(pool, account, doc), "stored");
}

const exercise = (over: Doc = {}): Doc => ({
  name: "Käfer", category: "core", effect: "Stärkt die Bauchmuskeln.", instructions: "Auf den Rücken legen, Arme und Beine strecken.",
  why: "Fehlte für den Rücken.", ...over,
});
const program = (steps: Doc[], over: Doc = {}): Doc => ({
  name: "Rücken kurz", symbol: "🧘", rounds: 2, steps, why: "Kurze Einheit.", ...over,
});
const step = (exerciseId = "builtin.planke", over: Doc = {}): Doc => ({ exerciseId, workSeconds: 30, restSeconds: 10, ...over });
const breath = (over: Doc = {}): Doc => ({
  name: "Abendatem", symbol: "🌙", inhaleSeconds: 4, holdInSeconds: 2, exhaleSeconds: 6, holdOutSeconds: 0, rounds: 5,
  why: "Zum Runterkommen.", ...over,
});

async function stored(pool: pg.Pool, account: string, deliveryId: string): Promise<Doc> {
  const rows = await listDeliveries(pool, account, { deliveryId });
  assert.equal(rows.length, 1, "Lieferung nicht gespeichert");
  return rows[0] as unknown as Doc;
}

const count = async (pool: pg.Pool, table: string): Promise<number> =>
  Number((await pool.query(`SELECT count(*) AS n FROM ${table}`)).rows[0].n);

// 1. Werkzeugliste

test("Werkzeugliste: sechs Lieferwerkzeuge sind da und nicht schreibgeschützt markiert, die Lesewerkzeuge bleiben", async (t) => {
  const client = await connect(t, await migrated(t), HENNING);
  const tools = (await client.listTools()).tools;
  for (const name of WRITE_TOOLS) {
    const tool = tools.find((x) => x.name === name);
    assert.ok(tool, `${name} fehlt`);
    assert.equal(tool.annotations?.readOnlyHint, false, `${name} muss readOnlyHint: false tragen`);
  }
  for (const name of ["overview", "catalog", "show", "forms", "delivery_status"]) assert.ok(tools.some((x) => x.name === name), name);
});

// 2. Ohne Konto

test("Ohne Konto: alle sechs Lieferwerkzeuge lehnen mit „kein Konto“ ab und speichern nichts", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool);
  const args: Record<string, Doc> = {
    exercise_define: exercise(), program_create: program([step()]), breath_create: breath(),
    item_update: { itemId: "claude.x-abcdef", basedOnRevision: 1, why: "Grund", fields: exercise() },
    item_withdraw: { itemId: "claude.x-abcdef", why: "Grund" }, wish_report: { text: "Ich wünsche mir etwas." },
  };
  for (const name of WRITE_TOOLS) {
    const { text, isError } = await call(client, name, args[name]);
    assert.equal(isError, true, name);
    assert.match(text, /kein Konto/, name);
  }
  assert.equal(await count(pool, "deliveries"), 0);
  assert.equal(await count(pool, "wishes"), 0);
});

// 3. Gültige Erstellung

test("exercise_define: Antwort mit deliveryId, itemId, Revision 1, waiting; gespeichert als gültiges Lieferformat", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, HENNING);
  const input = exercise({ nameEn: "Dead Bug", notes: "Langsam bewegen." });
  const answer = await json(client, "exercise_define", input);
  assert.match(answer.deliveryId, UUID);
  assert.match(answer.itemId, /^claude\.kaefer-[a-z0-9]{6}$/);
  assert.equal(answer.revision, 1);
  assert.equal(answer.state, "waiting");
  const row = await stored(pool, HENNING, answer.deliveryId);
  assert.equal(row.state, "waiting");
  const doc = row.delivery as Doc;
  assert.deepEqual(validateDelivery(doc).errors, []);
  assert.equal(doc.format, "hhhaven.delivery/1");
  assert.equal(doc.source, "claude");
  assert.equal(doc.deliveryId, answer.deliveryId);
  assert.ok(Math.abs(Date.now() - new Date(doc.createdAt).getTime()) < 60_000, "createdAt = jetzt");
  assert.equal(doc.why, input.why);
  assert.equal(doc.package, undefined);
  const { why, ...fields } = input;
  assert.deepEqual(doc.items, [{ kind: "exercise", itemId: answer.itemId, revision: 1, ...fields }]);
});

test("program_create: gespeichert als gültiges Lieferformat mit den eingereichten Feldern", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, HENNING);
  const input = program([step("builtin.planke", { hint: "Rücken gerade" }), step("builtin.kindspose", { restSeconds: 0 })], { description: "Kurz und knapp." });
  const answer = await json(client, "program_create", input);
  assert.match(answer.deliveryId, UUID);
  assert.match(answer.itemId, /^claude\.ruecken-kurz-[a-z0-9]{6}$/);
  assert.equal(answer.revision, 1);
  assert.equal(answer.state, "waiting");
  const doc = (await stored(pool, HENNING, answer.deliveryId)).delivery as Doc;
  assert.deepEqual(validateDelivery(doc).errors, []);
  assert.equal(doc.source, "claude");
  assert.equal(doc.why, input.why);
  const { why, ...fields } = input;
  assert.deepEqual(doc.items, [{ kind: "program", itemId: answer.itemId, revision: 1, ...fields }]);
});

test("breath_create: gespeichert als gültiges Lieferformat mit den eingereichten Feldern", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, HENNING);
  const input = breath({ description: "Lang ausatmen." });
  const answer = await json(client, "breath_create", input);
  assert.match(answer.deliveryId, UUID);
  assert.match(answer.itemId, /^claude\.abendatem-[a-z0-9]{6}$/);
  assert.equal(answer.revision, 1);
  assert.equal(answer.state, "waiting");
  const doc = (await stored(pool, HENNING, answer.deliveryId)).delivery as Doc;
  assert.deepEqual(validateDelivery(doc).errors, []);
  const { why, ...fields } = input;
  assert.deepEqual(doc.items, [{ kind: "breath", itemId: answer.itemId, revision: 1, ...fields }]);
});

test("Slug: „Rücken Übung ß“ wird zu claude.ruecken-uebung-ss-xxxxxx", async (t) => {
  const client = await connect(t, await migrated(t), HENNING);
  const answer = await json(client, "exercise_define", exercise({ name: "Rücken Übung ß" }));
  assert.match(answer.itemId, /^claude\.ruecken-uebung-ss-[a-z0-9]{6}$/);
});

test("Slug: Sonderzeichen und Leerraum werden zu einem einzelnen Bindestrich, Rand-Bindestriche entfallen", async (t) => {
  const client = await connect(t, await migrated(t), HENNING);
  const answer = await json(client, "breath_create", breath({ name: "  !Box -- Atmen?  " }));
  assert.match(answer.itemId, /^claude\.box-atmen-[a-z0-9]{6}$/);
});

test("Slug: höchstens 40 Zeichen (40 × „ü“ ergibt 20 × „ue“)", async (t) => {
  const client = await connect(t, await migrated(t), HENNING);
  const answer = await json(client, "exercise_define", exercise({ name: "ü".repeat(40) }));
  assert.equal(answer.itemId.slice("claude.".length, -7), "ue".repeat(20));
  assert.match(answer.itemId, /^claude\.[a-z0-9-]+-[a-z0-9]{6}$/);
});

test("Zwei Aufrufe mit demselben Namen (Programm) ergeben verschiedene itemIds und deliveryIds", async (t) => {
  const client = await connect(t, await migrated(t), HENNING);
  const a = await json(client, "program_create", program([step()]));
  const b = await json(client, "program_create", program([step()]));
  assert.notEqual(a.itemId, b.itemId);
  assert.notEqual(a.deliveryId, b.deliveryId);
});

// 4. Pakete

test("Paket: Name wird zum Umschlag-Paket {packageId, name}", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, HENNING);
  const answer = await json(client, "exercise_define", exercise({ package: "Rücken November" }));
  const doc = (await stored(pool, HENNING, answer.deliveryId)).delivery as Doc;
  assert.deepEqual(doc.package, { packageId: "claude.ruecken-november", name: "Rücken November" });
  assert.deepEqual(validateDelivery(doc).errors, []);
});

test("Paket: gleicher Name in anderer Schreibweise ergibt dieselbe packageId", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, HENNING);
  const a = await json(client, "breath_create", breath({ package: "Rücken November" }));
  const b = await json(client, "breath_create", breath({ package: "  RÜCKEN   november " }));
  const docA = (await stored(pool, HENNING, a.deliveryId)).delivery as Doc;
  const docB = (await stored(pool, HENNING, b.deliveryId)).delivery as Doc;
  assert.equal(docA.package.packageId, "claude.ruecken-november");
  assert.equal(docB.package.packageId, docA.package.packageId);
  assert.equal(docA.package.name, "Rücken November");
  assert.equal(docB.package.name, "RÜCKEN   november"); // wie im Aufruf, getrimmt
});

// 5. Ablehnungen

const rejections: [string, string, Doc, string][] = [
  ["workSeconds 601", "program_create", program([step("builtin.planke", { workSeconds: 601 })]), "/items/0/steps/0/workSeconds"],
  ["unbekannte Kategorie", "exercise_define", exercise({ category: "yoga" }), "/items/0/category"],
  ["Übung ohne Wirkung", "exercise_define", (() => { const e = exercise(); delete e.effect; return e; })(), "/items/0/effect"],
  ["unbekannte builtin-Übung im Schritt", "program_create", program([step("builtin.gibt-es-nicht")]), "/items/0/steps/0/exerciseId"],
  ["Name wie eingebaute Übung", "exercise_define", exercise({ name: "Planke" }), "/items/0/name"],
  ["Atemübung mit 0 Sekunden Einatmen", "breath_create", breath({ inhaleSeconds: 0 }), "/items/0/inhaleSeconds"],
  ["ungültiger why (zu lang)", "exercise_define", exercise({ why: "x".repeat(301) }), "/why"],
];
for (const [label, tool, input, path] of rejections) {
  test(`Ablehnung: ${label} -> isError mit Pfad ${path} und Ausweg, nichts gespeichert`, async (t) => {
    const pool = await migrated(t);
    const { text, isError } = await call(await connect(t, pool, HENNING), tool, input);
    assert.equal(isError, true, text);
    assert.ok(text.includes(path), `Pfad ${path} fehlt in: ${text}`);
    assert.match(text, /Ausweg/);
    assert.deepEqual(await listDeliveries(pool, HENNING), []);
  });
}

// 6. Bezüge

test("Bezug: Programm mit Übung aus einer früheren, noch wartenden exercise_define-Lieferung ist gültig", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, HENNING);
  const ex = await json(client, "exercise_define", exercise());
  const answer = await json(client, "program_create", program([step(ex.itemId)]));
  const doc = (await stored(pool, HENNING, answer.deliveryId)).delivery as Doc;
  const known = [{ id: ex.itemId, name: "Käfer" }];
  assert.deepEqual(validateDelivery(doc, { knownExercises: known }).errors, []);
  assert.equal(doc.items[0].steps[0].exerciseId, ex.itemId);
});

test("Bezug: Programm mit own.*-Übung aus der Abschrift ist gültig", async (t) => {
  const pool = await migrated(t);
  await withTranscript(pool);
  const answer = await json(await connect(t, pool, HENNING), "program_create", program([step(OWN_ID)]));
  assert.match(answer.deliveryId, UUID);
});

test("Bezug: Programm mit unbekannter own.*-Übung wird abgelehnt, nichts gespeichert", async (t) => {
  const pool = await migrated(t);
  await withTranscript(pool);
  const { text, isError } = await call(await connect(t, pool, HENNING), "program_create",
    program([step("own.00000000-0000-4000-8000-000000000000")]));
  assert.equal(isError, true);
  assert.ok(text.includes("/items/0/steps/0/exerciseId"), text);
  assert.deepEqual(await listDeliveries(pool, HENNING), []);
});

test("Bezug: ohne Abschrift ist own.* unbekannt und wird abgelehnt", async (t) => {
  const pool = await migrated(t);
  const { isError } = await call(await connect(t, pool, HENNING), "program_create", program([step(OWN_ID)]));
  assert.equal(isError, true);
});

test("Bezug: Übung aus der Abschrift (Name vergeben) kann nicht erneut als neue Übung definiert werden", async (t) => {
  const pool = await migrated(t);
  await withTranscript(pool);
  const { text, isError } = await call(await connect(t, pool, HENNING), "exercise_define", exercise({ name: "Schulterkreisen" }));
  assert.equal(isError, true);
  assert.ok(text.includes("/items/0/name"), text);
});

// 7. Prüfer-Gleichlauf

type Plan = { dir: "valid" | "invalid"; file: string; data: Doc; skip?: string };
const KINDS: Record<string, string> = { exercise: "exercise_define", program: "program_create", breath: "breath_create" };
const NOT_IN_ITEM = ["/items/0/itemId", "/items/0/revision", "/items/0/kind"];

function plan(): Plan[] {
  const plans: Plan[] = [];
  for (const dir of ["valid", "invalid"] as const) {
    for (const file of readdirSync(join(root, "Contracts", "deliveries", dir)).sort()) {
      const data = read("Contracts", "deliveries", dir, file);
      const items = data.delivery?.items;
      if (!Array.isArray(items) || items.length !== 1 || !(items[0]?.kind in KINDS)) continue; // nicht über ein Werkzeug ausdrückbar
      let skip: string | undefined;
      if (dir === "invalid") {
        const errors: { code: string; path: string }[] = data.expected.errors;
        if (!errors.every((e) => e.path.startsWith("/items/0/") && !NOT_IN_ITEM.includes(e.path))) continue; // Fehler außerhalb des Eintrags
      } else if (items[0].kind === "exercise" && data.context?.knownExercises?.length) {
        skip = "Aktualisierung derselben Übung (itemId vergibt der Dienst)";
      }
      plans.push({ dir, file, data, ...(skip === undefined ? {} : { skip }) });
    }
  }
  return plans;
}

const plans = plan();
const checked = plans.filter((p) => p.skip === undefined);
const skipped = plans.length - checked.length;

// Kontext der Datei als Abschrift nachbilden (own.* und claude.* aus knownExercises).
function transcriptFor(known: { id: string; name: string }[]): Doc {
  const doc = emptyTranscript();
  const claudeExample = fullTranscript().exercises[2];
  for (const { id, name } of known) {
    if (id.startsWith("own.")) doc.exercises.push({ id, name, category: "warmup", origin: "own" });
    else if (id.startsWith("claude.")) doc.exercises.push({ ...claudeExample, id, name, nameEn: undefined, packageId: undefined, packageName: undefined });
  }
  return JSON.parse(JSON.stringify(doc));
}

for (const p of checked) {
  test(`Gleichlauf ${p.dir}/${p.file}: ${p.dir === "valid" ? "wird angenommen" : "wird mit erwartetem Pfad abgelehnt"}`, async (t) => {
    const pool = await migrated(t);
    const known = p.data.context?.knownExercises ?? [];
    if (known.length > 0) await withTranscript(pool, HENNING, transcriptFor(known));
    const { kind, itemId, revision, ...fields } = p.data.delivery.items[0];
    const args: Doc = { ...fields, why: p.data.delivery.why };
    if (p.data.delivery.package !== undefined) args.package = p.data.delivery.package.name;
    const { text, isError } = await call(await connect(t, pool, HENNING), KINDS[kind], args);
    if (p.dir === "valid") {
      assert.equal(isError, false, `${p.file} sollte angenommen werden: ${text}`);
      assert.equal((await listDeliveries(pool, HENNING)).length, 1);
    } else {
      assert.equal(isError, true, `${p.file} sollte abgelehnt werden`);
      for (const e of p.data.expected.errors) assert.ok(text.includes(e.path), `Pfad ${e.path} fehlt in: ${text}`);
      assert.deepEqual(await listDeliveries(pool, HENNING), []);
    }
  });
}

test(`Gleichlauf: mindestens 30 Dateien werden geprüft (geprüft ${checked.length}, übersprungen ${skipped})`, () => {
  assert.ok(checked.length >= 30, `nur ${checked.length} Dateien geprüft`);
});

// 8. item_update

async function defineExercise(client: Awaited<ReturnType<typeof connect>>, over: Doc = {}): Promise<Doc> {
  return json(client, "exercise_define", exercise(over));
}

test("item_update: mit richtiger basedOnRevision entsteht eine neue Lieferung mit Revision + 1", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, HENNING);
  const first = await defineExercise(client);
  const fields = exercise({ effect: "Neu formuliert." });
  const { why, ...rest } = fields;
  const answer = await json(client, "item_update", { itemId: first.itemId, basedOnRevision: 1, why: "Präzisiert.", fields: rest });
  assert.match(answer.deliveryId, UUID);
  assert.notEqual(answer.deliveryId, first.deliveryId);
  assert.equal(answer.itemId, first.itemId);
  assert.equal(answer.revision, 2);
  assert.equal(answer.state, "waiting");
  const doc = (await stored(pool, HENNING, answer.deliveryId)).delivery as Doc;
  assert.equal(doc.why, "Präzisiert.");
  assert.deepEqual(doc.items, [{ kind: "exercise", itemId: first.itemId, revision: 2, ...rest }]);
  assert.deepEqual(validateDelivery(doc, { knownExercises: [{ id: first.itemId, name: "Käfer" }] }).errors, []);
});

test("item_update: die höchste Fassung darf nur in einer wartenden Lieferung stehen", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, HENNING);
  const first = await defineExercise(client);
  const { why, ...rest } = exercise();
  await json(client, "item_update", { itemId: first.itemId, basedOnRevision: 1, why: "Zwei.", fields: rest });
  const stale = await call(client, "item_update", { itemId: first.itemId, basedOnRevision: 1, why: "Drei.", fields: rest });
  assert.equal(stale.isError, true);
  assert.match(stale.text, /neu lesen/);
  const third = await json(client, "item_update", { itemId: first.itemId, basedOnRevision: 2, why: "Drei.", fields: rest });
  assert.equal(third.revision, 3);
});

test("item_update: falsche basedOnRevision -> isError „neu lesen“, nichts Neues gespeichert", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, HENNING);
  const first = await defineExercise(client);
  const { why, ...rest } = exercise();
  const { text, isError } = await call(client, "item_update", { itemId: first.itemId, basedOnRevision: 7, why: "x", fields: rest });
  assert.equal(isError, true);
  assert.match(text, /neu lesen/);
  assert.equal((await listDeliveries(pool, HENNING)).length, 1);
});

test("item_update: Baustein aus der Abschrift (active) wird fortgeschrieben, das Paket bleibt erhalten", async (t) => {
  const pool = await migrated(t);
  await withTranscript(pool);
  const client = await connect(t, pool, HENNING);
  const fields = { name: "Vierfüßler diagonal", category: "core", effect: "Stärkt Rücken und Rumpf, neu.", instructions: "Arm und Bein diagonal strecken." };
  const answer = await json(client, "item_update", { itemId: ACTIVE_EXERCISE, basedOnRevision: 1, why: "Klarer.", fields });
  assert.equal(answer.revision, 2);
  const doc = (await stored(pool, HENNING, answer.deliveryId)).delivery as Doc;
  assert.deepEqual(doc.package, { packageId: "claude.ruecken-november", name: "Rücken November" });
  assert.deepEqual(doc.items, [{ kind: "exercise", itemId: ACTIVE_EXERCISE, revision: 2, ...fields }]);
});

test("item_update: Paket einer wartenden Lieferung bleibt erhalten", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, HENNING);
  const first = await defineExercise(client, { package: "Rücken November" });
  const { why, package: pkg, ...rest } = exercise();
  const answer = await json(client, "item_update", { itemId: first.itemId, basedOnRevision: 1, why: "Neu.", fields: rest });
  const doc = (await stored(pool, HENNING, answer.deliveryId)).delivery as Doc;
  assert.equal(doc.package.packageId, "claude.ruecken-november");
});

test("item_update: Baustein in der Abschrift mit Zustand adapted -> isError mit „Kopie“", async (t) => {
  const pool = await migrated(t);
  await withTranscript(pool);
  const { text, isError } = await call(await connect(t, pool, HENNING), "item_update", {
    itemId: ADAPTED_PROGRAM, basedOnRevision: 2, why: "x",
    fields: { name: "Rücken A", symbol: "🧘", rounds: 2, steps: [step()] },
  });
  assert.equal(isError, true);
  assert.match(text, /Kopie/);
  assert.deepEqual(await listDeliveries(pool, HENNING), []);
});

test("item_update: zurückgenommener Baustein (withdrawn) -> isError", async (t) => {
  const pool = await migrated(t);
  await withTranscript(pool);
  const { isError } = await call(await connect(t, pool, HENNING), "item_update", {
    itemId: WITHDRAWN_BREATH, basedOnRevision: 1, why: "x",
    fields: { name: "Abendatem", symbol: "🌙", inhaleSeconds: 4, holdInSeconds: 2, exhaleSeconds: 6, holdOutSeconds: 0, rounds: 10 },
  });
  assert.equal(isError, true);
  assert.deepEqual(await listDeliveries(pool, HENNING), []);
});

test("item_update: own.* und builtin.* -> isError „Nur eigene“", async (t) => {
  const pool = await migrated(t);
  await withTranscript(pool);
  const client = await connect(t, pool, HENNING);
  const { why, ...rest } = exercise();
  for (const itemId of [OWN_ID, "builtin.planke"]) {
    const { text, isError } = await call(client, "item_update", { itemId, basedOnRevision: 1, why: "x", fields: rest });
    assert.equal(isError, true, itemId);
    assert.match(text, /Nur eigene/, itemId);
  }
  assert.deepEqual(await listDeliveries(pool, HENNING), []);
});

test("item_update: unbekannte claude.*-Kennung -> isError", async (t) => {
  const pool = await migrated(t);
  const { why, ...rest } = exercise();
  const { isError } = await call(await connect(t, pool, HENNING), "item_update", {
    itemId: "claude.gibt-es-nicht-abcdef", basedOnRevision: 1, why: "x", fields: rest,
  });
  assert.equal(isError, true);
  assert.deepEqual(await listDeliveries(pool, HENNING), []);
});

test("item_update: ungültige neue Fassung wird mit Pfad abgelehnt, nichts gespeichert", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, HENNING);
  const first = await defineExercise(client);
  const { why, ...rest } = exercise({ category: "yoga" });
  const { text, isError } = await call(client, "item_update", { itemId: first.itemId, basedOnRevision: 1, why: "x", fields: rest });
  assert.equal(isError, true);
  assert.ok(text.includes("/items/0/category"), text);
  assert.equal((await listDeliveries(pool, HENNING)).length, 1);
});

// 9. item_withdraw

test("item_withdraw: Baustein nur wartend -> Lieferung superseded, keine neue Lieferung, Antwort nennt sie", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, HENNING);
  const first = await defineExercise(client);
  const answer = await json(client, "item_withdraw", { itemId: first.itemId, why: "Doch nicht nötig." });
  assert.deepEqual(answer.superseded, [first.deliveryId]);
  assert.equal(answer.state, "withdrawn");
  assert.equal(answer.deliveryId, undefined);
  const rows = await listDeliveries(pool, HENNING);
  assert.equal(rows.length, 1);
  assert.equal(rows[0]?.state, "superseded");
});

test("item_withdraw: Baustein in der Abschrift (aktiv) -> neue Rücknahme-Lieferung {kind: withdrawal, itemId}", async (t) => {
  const pool = await migrated(t);
  await withTranscript(pool);
  const answer = await json(await connect(t, pool, HENNING), "item_withdraw", { itemId: ACTIVE_EXERCISE, why: "Passt nicht mehr." });
  assert.match(answer.deliveryId, UUID);
  assert.equal(answer.state, "waiting");
  const doc = (await stored(pool, HENNING, answer.deliveryId)).delivery as Doc;
  assert.deepEqual(doc.items, [{ kind: "withdrawal", itemId: ACTIVE_EXERCISE }]);
  assert.equal(doc.why, "Passt nicht mehr.");
  assert.equal(doc.source, "claude");
  assert.deepEqual(validateDelivery(doc).errors, []);
});

test("item_withdraw: Baustein, den ein Gerät schon abgeholt hat (claimed), bekommt eine Rücknahme-Lieferung", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, HENNING);
  const first = await defineExercise(client);
  assert.equal((await claimDelivery(pool, HENNING, DEVICE))?.deliveryId, first.deliveryId);
  const answer = await json(client, "item_withdraw", { itemId: first.itemId, why: "Zurück." });
  assert.match(answer.deliveryId, UUID);
  const doc = (await stored(pool, HENNING, answer.deliveryId)).delivery as Doc;
  assert.deepEqual(doc.items, [{ kind: "withdrawal", itemId: first.itemId }]);
});

test("item_withdraw: Paket mit Teil in der App -> Rücknahme mit packageId, wartende Teile werden überholt", async (t) => {
  const pool = await migrated(t);
  await withTranscript(pool);
  const client = await connect(t, pool, HENNING);
  const waiting = await json(client, "breath_create", breath({ package: "Rücken November" }));
  const answer = await json(client, "item_withdraw", { package: "Rücken November", why: "Paket aufgeben." });
  assert.match(answer.deliveryId, UUID);
  assert.equal(answer.state, "waiting");
  assert.deepEqual(answer.superseded, [waiting.deliveryId]);
  const doc = (await stored(pool, HENNING, answer.deliveryId)).delivery as Doc;
  assert.deepEqual(doc.items, [{ kind: "withdrawal", packageId: "claude.ruecken-november" }]);
  assert.equal((await stored(pool, HENNING, waiting.deliveryId)).state, "superseded");
});

test("item_withdraw: Paket, das nur aus wartenden Teilen besteht -> alle überholt, keine neue Lieferung", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, HENNING);
  const a = await json(client, "breath_create", breath({ package: "Abend" }));
  const b = await json(client, "exercise_define", exercise({ package: "Abend" }));
  const answer = await json(client, "item_withdraw", { package: "abend", why: "Weg damit." });
  assert.deepEqual([...answer.superseded].sort(), [a.deliveryId, b.deliveryId].sort());
  assert.equal(answer.deliveryId, undefined);
  assert.equal(answer.state, "withdrawn");
  const rows = await listDeliveries(pool, HENNING);
  assert.equal(rows.length, 2);
  assert.ok(rows.every((r) => r.state === "superseded"));
});

test("item_withdraw: beides oder keins von itemId/package -> isError, nichts gespeichert", async (t) => {
  const pool = await migrated(t);
  await withTranscript(pool);
  const client = await connect(t, pool, HENNING);
  for (const input of [{ itemId: ACTIVE_EXERCISE, package: "Rücken November", why: "x" }, { why: "x" }]) {
    const { isError } = await call(client, "item_withdraw", input);
    assert.equal(isError, true, JSON.stringify(input));
  }
  assert.deepEqual(await listDeliveries(pool, HENNING), []);
});

test("item_withdraw: own.*, builtin.* und unbekannte claude.* -> isError, nichts gespeichert", async (t) => {
  const pool = await migrated(t);
  await withTranscript(pool);
  const client = await connect(t, pool, HENNING);
  for (const itemId of [OWN_ID, "builtin.planke", "claude.gibt-es-nicht-abcdef"]) {
    const { isError } = await call(client, "item_withdraw", { itemId, why: "x" });
    assert.equal(isError, true, itemId);
  }
  assert.deepEqual(await listDeliveries(pool, HENNING), []);
});

test("item_withdraw: unbekanntes Paket -> isError, nichts gespeichert", async (t) => {
  const pool = await migrated(t);
  await withTranscript(pool);
  const { isError } = await call(await connect(t, pool, HENNING), "item_withdraw", { package: "Gibt es nicht", why: "x" });
  assert.equal(isError, true);
  assert.deepEqual(await listDeliveries(pool, HENNING), []);
});

test("item_withdraw: Paket, dessen Teile alle schon zurückgenommen sind -> isError", async (t) => {
  const pool = await migrated(t);
  const doc = fullTranscript();
  for (const item of [...doc.exercises, ...doc.programs, ...doc.breaths]) {
    if (item.packageId === "claude.ruecken-november") item.state = "withdrawn";
  }
  await withTranscript(pool, HENNING, doc);
  const { isError } = await call(await connect(t, pool, HENNING), "item_withdraw", { package: "Rücken November", why: "x" });
  assert.equal(isError, true);
  assert.deepEqual(await listDeliveries(pool, HENNING), []);
});

test("item_withdraw: schon zurückgenommener Baustein (Abschrift withdrawn) -> isError", async (t) => {
  const pool = await migrated(t);
  await withTranscript(pool);
  const { isError } = await call(await connect(t, pool, HENNING), "item_withdraw", { itemId: WITHDRAWN_BREATH, why: "x" });
  assert.equal(isError, true);
  assert.deepEqual(await listDeliveries(pool, HENNING), []);
});

// 10. wish_report

test("wish_report: wird in wishes gespeichert, Antwort {wishId}", async (t) => {
  const pool = await migrated(t);
  const answer = await json(await connect(t, pool, HENNING), "wish_report", { text: "Mehr Dehnübungen bitte.", context: "Beim Rückenprogramm" });
  assert.match(answer.wishId, UUID);
  const rows = (await pool.query("SELECT id, account_id, text, context FROM wishes")).rows;
  assert.equal(rows.length, 1);
  assert.equal(rows[0].id, answer.wishId);
  assert.equal(rows[0].account_id, HENNING);
  assert.equal(rows[0].text, "Mehr Dehnübungen bitte.");
  assert.equal(rows[0].context, "Beim Rückenprogramm");
});

test("wish_report: context ist optional, Grenzen 1000 und 300 sind erlaubt", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, HENNING);
  await json(client, "wish_report", { text: "Nur Text." });
  await json(client, "wish_report", { text: "w".repeat(1000), context: "c".repeat(300) });
  assert.equal(await count(pool, "wishes"), 2);
});

test("wish_report: leerer Text, Text über 1000 und context über 300 -> isError, nichts gespeichert", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, HENNING);
  for (const input of [{ text: "" }, { text: " \u00a0\n " }, { text: "w".repeat(1001) }, { text: "ok", context: "c".repeat(301) }]) {
    const { isError } = await call(client, "wish_report", input);
    assert.equal(isError, true, JSON.stringify(input).slice(0, 40));
  }
  assert.equal(await count(pool, "wishes"), 0);
});

// 11. Konten getrennt

test("Konten getrennt: Konto B kann Bausteine von A weder ändern noch zurücknehmen noch einbinden", async (t) => {
  const pool = await migrated(t);
  const a = await connect(t, pool, HENNING);
  const b = await connect(t, pool, ANNA);
  const first = await defineExercise(a);
  const { why, ...rest } = exercise();
  assert.equal((await call(b, "item_update", { itemId: first.itemId, basedOnRevision: 1, why: "x", fields: rest })).isError, true);
  assert.equal((await call(b, "item_withdraw", { itemId: first.itemId, why: "x" })).isError, true);
  assert.equal((await call(b, "program_create", program([step(first.itemId)]))).isError, true);
  assert.equal((await stored(pool, HENNING, first.deliveryId)).state, "waiting");
  assert.deepEqual(await listDeliveries(pool, ANNA), []);
});

test("Konten getrennt: Lieferungen und Wünsche landen im Konto des Aufrufers", async (t) => {
  const pool = await migrated(t);
  const b = await connect(t, pool, ANNA);
  const answer = await json(b, "breath_create", breath());
  await json(b, "wish_report", { text: "Wunsch von Anna." });
  assert.equal((await listDeliveries(pool, ANNA)).length, 1);
  assert.deepEqual(await listDeliveries(pool, HENNING), []);
  assert.equal((await stored(pool, ANNA, answer.deliveryId)).state, "waiting");
  assert.equal((await pool.query("SELECT account_id FROM wishes")).rows[0].account_id, ANNA);
});
