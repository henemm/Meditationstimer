// B2a-2 Abschrift (Issue #54): TDD RED. Spec: openspec/specs/integrations/claude-dienst.md Abschnitt 4
import { test } from "node:test";
import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";
import { migrate } from "../src/migrate.ts";
import { checkTranscript, getTranscript, putTranscript } from "../src/transcripts.ts";
import { freshPool } from "./db.ts";

const root = join(import.meta.dirname, "..", "..");
const exampleDir = join(root, "Contracts", "transcript");
const migrationsDir = join(import.meta.dirname, "..", "migrations");

type Example = { file: string; transcript: unknown; accepted: boolean };

async function examples(kind: "valid" | "invalid"): Promise<Example[]> {
  const dir = join(exampleDir, kind);
  const names = (await readdir(dir)).filter((name) => name.endsWith(".json")).sort();
  const result: Example[] = [];
  for (const name of names) {
    const json = JSON.parse(await readFile(join(dir, name), "utf8"));
    result.push({ file: `${kind}/${name}`, transcript: json.transcript, accepted: json.expected.accepted });
  }
  return result;
}

function doc(generatedAt: string, extra: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    version: 1,
    generatedAt,
    exercises: [{ id: "builtin.planke", name: "Planke", category: "core", origin: "builtin" }],
    programs: [],
    breaths: [],
    deliveries: [],
    ...extra,
  };
}

async function migrated(t: Parameters<typeof freshPool>[0]) {
  const pool = await freshPool(t);
  await migrate(pool, migrationsDir);
  return pool;
}

// 1. Beispiele aus dem Vertrag

test("Beispiele: es gibt gueltige und ungueltige Beispieldateien", async () => {
  assert.ok((await examples("valid")).length > 0);
  assert.ok((await examples("invalid")).length > 0);
});

test("Beispiele: checkTranscript nimmt an, was expected.accepted erlaubt, und nennt sonst einen Grund", async () => {
  const all = [...(await examples("valid")), ...(await examples("invalid"))];
  assert.ok(all.length > 0);
  for (const example of all) {
    const reason = checkTranscript(example.transcript);
    if (example.accepted) {
      assert.equal(reason, undefined, `${example.file} muss angenommen werden`);
    } else {
      assert.equal(typeof reason, "string", `${example.file} muss abgelehnt werden`);
      assert.ok((reason as string).length > 0, `${example.file}: Grund darf nicht leer sein`);
    }
  }
});

test("checkTranscript lehnt Nicht-Objekte ab", () => {
  for (const bad of [null, undefined, 42, "text", [], true]) {
    const reason = checkTranscript(bad);
    assert.equal(typeof reason, "string");
    assert.ok((reason as string).length > 0);
  }
});

// 4. Groesse

test("Groesse: 501 Uebungen sind ungueltig, 500 sind in Ordnung", () => {
  const exercises = (n: number) =>
    Array.from({ length: n }, (_, i) => ({ id: `own.uebung-${i}`, name: `Uebung ${i}`, category: "core", origin: "own" }));
  assert.equal(checkTranscript(doc("2026-11-13T10:00:00Z", { exercises: exercises(500) })), undefined);
  const reason = checkTranscript(doc("2026-11-13T10:00:00Z", { exercises: exercises(501) }));
  assert.equal(typeof reason, "string");
  assert.ok((reason as string).length > 0);
});

// 2. Ablegen und Lesen

test("Ablage: gueltige Abschrift wird gespeichert und unveraendert zurueckgelesen", async (t) => {
  const pool = await migrated(t);
  const example = (await examples("valid")).find((e) => e.file.endsWith("full.json"));
  assert.ok(example, "valid/full.json fehlt");
  assert.equal(await putTranscript(pool, "konto-a", example.transcript), "stored");
  assert.deepEqual(await getTranscript(pool, "konto-a"), example.transcript);
});

test("Ablage: ohne Abschrift liefert getTranscript undefined", async (t) => {
  const pool = await migrated(t);
  assert.equal(await getTranscript(pool, "konto-a"), undefined);
});

test("Ablage: ungueltige Abschrift ergibt invalid und nichts wird gespeichert", async (t) => {
  const pool = await migrated(t);
  const bad = doc("2026-11-13T10:00:00Z", { trackers: [{ name: "Wasser" }] });
  assert.equal(await putTranscript(pool, "konto-a", bad), "invalid");
  assert.equal(await getTranscript(pool, "konto-a"), undefined);
});

test("Ablage: alle ungueltigen Beispiele ergeben invalid und hinterlassen nichts", async (t) => {
  const pool = await migrated(t);
  const invalid = await examples("invalid");
  assert.ok(invalid.length > 0);
  for (const example of invalid) {
    assert.equal(await putTranscript(pool, "konto-a", example.transcript), "invalid", example.file);
  }
  assert.equal(await getTranscript(pool, "konto-a"), undefined);
});

test("Ablage: ungueltige Abschrift ersetzt keine gespeicherte", async (t) => {
  const pool = await migrated(t);
  const good = doc("2026-11-13T10:00:00Z");
  assert.equal(await putTranscript(pool, "konto-a", good), "stored");
  const bad = doc("2026-11-14T10:00:00Z", { health: {} });
  assert.equal(await putTranscript(pool, "konto-a", bad), "invalid");
  assert.deepEqual(await getTranscript(pool, "konto-a"), good);
});

test("Ablage: neuere generatedAt ersetzt die gespeicherte", async (t) => {
  const pool = await migrated(t);
  const older = doc("2026-11-13T10:00:00Z");
  const newer = doc("2026-11-13T10:00:01Z", { exercises: [] });
  assert.equal(await putTranscript(pool, "konto-a", older), "stored");
  assert.equal(await putTranscript(pool, "konto-a", newer), "stored");
  assert.deepEqual(await getTranscript(pool, "konto-a"), newer);
});

test("Ablage: aeltere generatedAt ergibt stale, die gespeicherte bleibt", async (t) => {
  const pool = await migrated(t);
  const current = doc("2026-11-13T10:00:00Z");
  const older = doc("2026-11-12T10:00:00Z", { exercises: [] });
  assert.equal(await putTranscript(pool, "konto-a", current), "stored");
  assert.equal(await putTranscript(pool, "konto-a", older), "stale");
  assert.deepEqual(await getTranscript(pool, "konto-a"), current);
});

test("Ablage: gleich alte generatedAt ergibt stale, die gespeicherte bleibt", async (t) => {
  const pool = await migrated(t);
  const current = doc("2026-11-13T10:00:00Z");
  const same = doc("2026-11-13T10:00:00Z", { exercises: [] });
  assert.equal(await putTranscript(pool, "konto-a", current), "stored");
  assert.equal(await putTranscript(pool, "konto-a", same), "stale");
  assert.deepEqual(await getTranscript(pool, "konto-a"), current);
});

test("Ablage: Konten sind getrennt", async (t) => {
  const pool = await migrated(t);
  const a = doc("2026-11-13T10:00:00Z");
  const b = doc("2026-11-13T11:00:00Z", { exercises: [] });
  assert.equal(await putTranscript(pool, "konto-a", a), "stored");
  assert.equal(await getTranscript(pool, "konto-b"), undefined);
  assert.equal(await putTranscript(pool, "konto-b", b), "stored");
  assert.deepEqual(await getTranscript(pool, "konto-a"), a);
  assert.deepEqual(await getTranscript(pool, "konto-b"), b);
});

// 3. Datenschutz als zweite Wand in der Datenbank
// ANNAHME: Spec legt Tabelle/Spalten nicht fest: transcripts(account_id text primary key, doc jsonb, generated_at timestamptz, received_at timestamptz)

test("Datenschutz: direktes INSERT mit Feld ausserhalb der Liste scheitert am CHECK, ein gueltiges geht durch", async (t) => {
  const pool = await migrated(t);
  const insert = "INSERT INTO transcripts (account_id, doc, generated_at, received_at) VALUES ($1, $2::jsonb, $3, now())";

  const withTrackers = doc("2026-11-13T10:00:00Z", { trackers: [{ name: "Wasser" }] });
  await assert.rejects(
    pool.query(insert, ["konto-x", JSON.stringify(withTrackers), "2026-11-13T10:00:00Z"]),
    (error: unknown) => (error as { code?: string }).code === "23514",
  );

  await pool.query(insert, ["konto-x", JSON.stringify(doc("2026-11-13T10:00:00Z")), "2026-11-13T10:00:00Z"]);
  assert.equal((await pool.query("SELECT 1 FROM transcripts WHERE account_id = 'konto-x'")).rowCount, 1);
});
