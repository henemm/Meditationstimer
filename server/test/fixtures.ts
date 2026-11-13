// B2b Anmeldung (Issue #55): gemeinsame Testdaten für die fachlichen Tabellen eines Kontos (ersetzt die Aufträge und die
// Abschrift von Loose Ends in den übernommenen Tests).
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import type pg from "pg";
import { claimDelivery, putDelivery, reportResult } from "../src/deliveries.ts";
import { putTranscript } from "../src/transcripts.ts";

const root = join(import.meta.dirname, "..", "..");
export const OWN_TABLES = ["accounts", "sessions", "apple_tokens", "transcripts", "deliveries", "delivery_events", "wishes"] as const;

export const transcriptDoc = (generatedAt = "2026-11-13T08:00:00Z") => ({
  version: 1, generatedAt,
  exercises: [{ id: "builtin.planke", name: "Planke", category: "core", origin: "builtin" }], programs: [], breaths: [], deliveries: [],
});

export async function sampleDelivery(id: string = randomUUID()): Promise<Record<string, unknown> & { deliveryId: string }> {
  const file = JSON.parse(await readFile(join(root, "Contracts", "deliveries", "valid", "exercise-minimal.json"), "utf8"));
  return { ...file.delivery, deliveryId: id };
}

// Eine Abschrift, eine abgeholte und beantwortete Lieferung (mit Verlauf), eine wartende und ein Wunsch für das Konto.
export async function fillAccount(pool: pg.Pool, account: string): Promise<void> {
  assert_stored(await putTranscript(pool, account, transcriptDoc()));
  const device = randomUUID();
  await putDelivery(pool, account, await sampleDelivery());
  const claimed = await claimDelivery(pool, account, device);
  await reportResult(pool, account, device, { deliveryId: claimed!.deliveryId, outcome: "accepted" });
  await putDelivery(pool, account, await sampleDelivery());
  await pool.query("INSERT INTO wishes (id, account_id, text) VALUES ($1, $2, 'Mehr Dehnübungen')", [randomUUID(), account]);
}

function assert_stored(outcome: string): void {
  if (outcome !== "stored") throw new Error(`Abschrift nicht gespeichert: ${outcome}`);
}

// Zeilen je Tabelle für ein Konto (delivery_events über die Lieferungen des Kontos).
export async function ownRows(pool: pg.Pool, account: string): Promise<Record<string, number>> {
  const result: Record<string, number> = {};
  for (const table of OWN_TABLES) {
    const sql = table === "accounts" ? "SELECT count(*)::int AS n FROM accounts WHERE id = $1"
      : table === "delivery_events" ? "SELECT count(*)::int AS n FROM delivery_events e JOIN deliveries d ON d.id = e.delivery_id WHERE d.account_id = $1"
      : `SELECT count(*)::int AS n FROM ${table} WHERE account_id = $1`;
    result[table] = (await pool.query(sql, [account])).rows[0].n;
  }
  return result;
}
export const noRows = Object.fromEntries(OWN_TABLES.map((table) => [table, 0]));
export const totalEvents = async (pool: pg.Pool) => (await pool.query("SELECT count(*)::int AS n FROM delivery_events")).rows[0].n;
