// B3a Rückblick (Issue #58): TDD RED. Spec: openspec/specs/integrations/claude-rueckblick.md Abschnitt 2
import { test } from "node:test";
import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";
import { migrate } from "../src/migrate.ts";
import { checkTranscript, getTranscript, putTranscript } from "../src/transcripts.ts";
import { freshPool } from "./db.ts";

const root = join(import.meta.dirname, "..", "..");
const migrationsDir = join(import.meta.dirname, "..", "migrations");
const STREAKS = { meditation: { current: 1, longest: 2 }, workout: { current: 0, longest: 0 } };

type Example = { file: string; transcript: any; accepted: boolean };

async function examples(dir: string[], kind: "valid" | "invalid"): Promise<Example[]> {
  const folder = join(root, "Contracts", "transcript", ...dir, kind);
  const names = (await readdir(folder)).filter((name) => name.endsWith(".json")).sort();
  const result: Example[] = [];
  for (const name of names) {
    const json = JSON.parse(await readFile(join(folder, name), "utf8"));
    result.push({ file: `${dir.join("/")}/${kind}/${name}`, transcript: json.transcript, accepted: json.expected.accepted });
  }
  return result;
}

function doc(version: 1 | 2, generatedAt: string, extra: Record<string, unknown> = {}): Record<string, any> {
  return {
    version,
    generatedAt,
    exercises: [{ id: "builtin.planke", name: "Planke", category: "core", origin: "builtin" }],
    programs: [],
    breaths: [],
    deliveries: [],
    ...(version === 2 ? { history: { sessions: [], streaks: STREAKS } } : {}),
    ...extra,
  };
}

async function migrated(t: Parameters<typeof freshPool>[0]) {
  const pool = await freshPool(t);
  await migrate(pool, migrationsDir);
  return pool;
}

// 1. Beispiele

test("v2-Beispiele: es gibt gültige und ungültige Dateien", async () => {
  assert.ok((await examples(["v2"], "valid")).length > 0);
  assert.ok((await examples(["v2"], "invalid")).length > 0);
});

test("v2-Beispiele: checkTranscript nimmt genau an, was expected.accepted erlaubt", async () => {
  const all = [...(await examples(["v2"], "valid")), ...(await examples(["v2"], "invalid"))];
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

test("v1-Beispiele: bleiben wie bisher (gültige angenommen, ungültige abgelehnt)", async () => {
  const all = [...(await examples([], "valid")), ...(await examples([], "invalid"))];
  assert.ok(all.length > 0);
  for (const example of all) {
    const reason = checkTranscript(example.transcript);
    if (example.accepted) assert.equal(reason, undefined, `${example.file} muss angenommen werden`);
    else assert.equal(typeof reason, "string", `${example.file} muss abgelehnt werden`);
  }
});

// 2. Ablage

test("Ablage v2: wird gespeichert und unverändert zurückgelesen", async (t) => {
  const pool = await migrated(t);
  const example = (await examples(["v2"], "valid")).find((e) => e.file.endsWith("full.json"));
  assert.ok(example, "v2/valid/full.json fehlt");
  assert.equal(await putTranscript(pool, "konto-a", example.transcript), "stored");
  assert.deepEqual(await getTranscript(pool, "konto-a"), example.transcript);
});

test("Ablage: Fassung 2 löst Fassung 1 ab, wenn generatedAt neuer ist", async (t) => {
  const pool = await migrated(t);
  const v1 = doc(1, "2026-11-13T10:00:00Z");
  const v2 = doc(2, "2026-11-13T10:00:01Z");
  assert.equal(await putTranscript(pool, "konto-a", v1), "stored");
  assert.equal(await putTranscript(pool, "konto-a", v2), "stored");
  assert.deepEqual(await getTranscript(pool, "konto-a"), v2);
});

test("Ablage: Fassung 1 löst Fassung 2 ab, wenn generatedAt neuer ist", async (t) => {
  const pool = await migrated(t);
  const v2 = doc(2, "2026-11-13T10:00:00Z");
  const v1 = doc(1, "2026-11-13T10:00:01Z");
  assert.equal(await putTranscript(pool, "konto-a", v2), "stored");
  assert.equal(await putTranscript(pool, "konto-a", v1), "stored");
  assert.deepEqual(await getTranscript(pool, "konto-a"), v1);
});

test("Ablage: ältere Fassung 1 ersetzt keine neuere Fassung 2 (stale)", async (t) => {
  const pool = await migrated(t);
  const v2 = doc(2, "2026-11-13T10:00:00Z");
  assert.equal(await putTranscript(pool, "konto-a", v2), "stored");
  assert.equal(await putTranscript(pool, "konto-a", doc(1, "2026-11-12T10:00:00Z")), "stale");
  assert.deepEqual(await getTranscript(pool, "konto-a"), v2);
});

// 3. Datenschutz in der Datenbank
// ANNAHME: Tabelle transcripts(account_id, doc, generated_at, received_at) wie in transcripts.test.ts

test("Datenschutz DB: history ist in Fassung 2 erlaubt, in Fassung 1 nicht", async (t) => {
  const pool = await migrated(t);
  const insert = "INSERT INTO transcripts (account_id, doc, generated_at, received_at) VALUES ($1, $2::jsonb, $3, now())";
  const at = "2026-11-13T10:00:00Z";
  const code = (error: unknown) => (error as { code?: string }).code === "23514";

  await pool.query(insert, ["konto-v2", JSON.stringify(doc(2, at)), at]);
  assert.equal((await pool.query("SELECT 1 FROM transcripts WHERE account_id = 'konto-v2'")).rowCount, 1);

  const v1WithHistory = doc(1, at, { history: { sessions: [], streaks: STREAKS } });
  await assert.rejects(pool.query(insert, ["konto-v1", JSON.stringify(v1WithHistory), at]), code);
});

test("Datenschutz DB: oberstes Feld trackers scheitert in beiden Fassungen am CHECK", async (t) => {
  const pool = await migrated(t);
  const insert = "INSERT INTO transcripts (account_id, doc, generated_at, received_at) VALUES ($1, $2::jsonb, $3, now())";
  const at = "2026-11-13T10:00:00Z";
  for (const version of [1, 2] as const) {
    const bad = doc(version, at, { trackers: [{ name: "Wasser" }] });
    await assert.rejects(
      pool.query(insert, [`konto-${version}`, JSON.stringify(bad), at]),
      (error: unknown) => (error as { code?: string }).code === "23514",
      `Fassung ${version}`,
    );
  }
});
