// Übernommen aus loose-ends server/src/orders.ts @ 24a6da6 (Muster: Abholen in einer Anweisung mit FOR UPDATE SKIP LOCKED,
// Rückholung nach 10 min, Ergebnis nur vom haltenden Gerät); angepasst: Lieferungen mit Zuständen, Verlauf und Konto in jeder Abfrage.
import type pg from "pg";

export type DeliveryState = "waiting" | "claimed" | "accepted" | "rejected" | "superseded";
export type DeliveryError = { code: string; path: string; message: string };
export type ResultBody = { deliveryId: string; outcome: "accepted" | "rejected"; errors?: DeliveryError[] };
export type DeliveryRow = {
  deliveryId: string;
  state: DeliveryState;
  createdAt: Date;
  claimedAt?: Date;
  decidedAt?: Date;
  errors?: DeliveryError[];
  delivery: unknown;
};

// Eine abgeholte Lieferung ohne Ergebnis wird wieder abholbar, sobald die Abholung länger her ist (Bezug: Abholzeitpunkt).
export const CLAIM_TIMEOUT_MINUTES = 10;

// Eine Anweisung: neue Lieferung im Zustand waiting samt Ereignis. Die Form prüft der Aufrufer (validateDelivery in B2a-5).
export async function putDelivery(pool: pg.Pool, account: string, doc: { deliveryId: string }): Promise<void> {
  await pool.query(
    `WITH ins AS (INSERT INTO deliveries (id, account_id, doc, state) VALUES ($1, $2, $3::jsonb, 'waiting') RETURNING id)
     INSERT INTO delivery_events (delivery_id, state) SELECT id, 'waiting' FROM ins`,
    [doc.deliveryId, account, JSON.stringify(doc)],
  );
}

// Eine Anweisung: die älteste wartende oder rückholbare Lieferung des Kontos geht an genau ein Gerät. Mindestens einmal:
// eine zurückgeholte Lieferung kann zweimal laufen, das alte Gerät bekommt dann beim Ergebnis "conflict".
export async function claimDelivery(
  pool: pg.Pool, account: string, device: string, now: Date = new Date(),
): Promise<{ deliveryId: string; delivery: unknown } | undefined> {
  const result = await pool.query(
    `WITH picked AS (
       SELECT id FROM deliveries
       WHERE account_id = $1 AND (state = 'waiting'
         OR (state = 'claimed' AND claimed_at < $3::timestamptz - make_interval(mins => $4)))
       ORDER BY created_at, seq FOR UPDATE SKIP LOCKED LIMIT 1),
     upd AS (
       UPDATE deliveries d SET state = 'claimed', claimed_by = $2, claimed_at = $3::timestamptz
       FROM picked WHERE d.id = picked.id RETURNING d.id, d.doc),
     ev AS (INSERT INTO delivery_events (delivery_id, at, state, device) SELECT id, $3::timestamptz, 'claimed', $2 FROM upd)
     SELECT id, doc FROM upd`,
    [account, device, now, CLAIM_TIMEOUT_MINUTES],
  );
  const row = result.rows[0];
  return row === undefined ? undefined : { deliveryId: row.id, delivery: row.doc };
}

// Eine Anweisung: das Ergebnis gilt nur vom Gerät, das die Lieferung hält, und nur einmal. Alles andere ist "conflict".
export async function reportResult(pool: pg.Pool, account: string, device: string, body: ResultBody): Promise<"ok" | "conflict"> {
  const stored = JSON.stringify({ outcome: body.outcome, ...(body.errors === undefined ? {} : { errors: body.errors }) });
  const result = await pool.query(
    `WITH upd AS (
       UPDATE deliveries SET state = $4, result = $5::jsonb, decided_at = now()
       WHERE id = $1 AND account_id = $2 AND claimed_by = $3 AND state = 'claimed' RETURNING id),
     ev AS (INSERT INTO delivery_events (delivery_id, state, device) SELECT id, $4, $3 FROM upd)
     SELECT id FROM upd`,
    [body.deliveryId, account, device, body.outcome, stored],
  );
  return result.rowCount === 1 ? "ok" : "conflict";
}

// Eine Anweisung: nur eine wartende Lieferung lässt sich überholen (true), alles andere bleibt unberührt (false).
export async function supersede(pool: pg.Pool, account: string, deliveryId: string): Promise<boolean> {
  const result = await pool.query(
    `WITH upd AS (
       UPDATE deliveries SET state = 'superseded' WHERE id = $1 AND account_id = $2 AND state = 'waiting' RETURNING id),
     ev AS (INSERT INTO delivery_events (delivery_id, state) SELECT id, 'superseded' FROM upd)
     SELECT id FROM upd`,
    [deliveryId, account],
  );
  return result.rowCount === 1;
}

type Listing = { deliveryId?: string; limit?: number };

// Die Lieferungen des Kontos, neueste zuerst; optional eine einzelne Kennung und ein Limit (Standard 50).
export async function listDeliveries(pool: pg.Pool, account: string, options: Listing = {}): Promise<DeliveryRow[]> {
  const result = await pool.query(
    `SELECT id, state, created_at, claimed_at, decided_at, result->'errors' AS errors, doc FROM deliveries
     WHERE account_id = $1 AND ($2::text IS NULL OR id = $2) ORDER BY created_at DESC, seq DESC LIMIT $3`,
    [account, options.deliveryId ?? null, options.limit ?? 50],
  );
  return result.rows.map((r) => ({
    deliveryId: r.id,
    state: r.state,
    createdAt: r.created_at,
    ...(r.claimed_at === null ? {} : { claimedAt: r.claimed_at }),
    ...(r.decided_at === null ? {} : { decidedAt: r.decided_at }),
    ...(r.errors === null ? {} : { errors: r.errors }),
    delivery: r.doc,
  }));
}

export type OpenDelivery = { deliveryId: string; state: "waiting" | "claimed"; createdAt: Date; delivery: unknown };

// Lesefunktion (B2a-4): alle noch nicht entschiedenen Lieferungen des Kontos (waiting oder claimed), älteste zuerst.
export async function openDeliveries(pool: pg.Pool, account: string): Promise<OpenDelivery[]> {
  const result = await pool.query(
    `SELECT id, state, created_at, doc FROM deliveries
     WHERE account_id = $1 AND state IN ('waiting', 'claimed') ORDER BY created_at, seq`,
    [account],
  );
  return result.rows.map((r) => ({ deliveryId: r.id, state: r.state, createdAt: r.created_at, delivery: r.doc }));
}

export type Rejection = { deliveryId: string; decidedAt: Date; errors?: DeliveryError[] };

// Lesefunktion (B2a-4): die in den letzten `days` Tagen abgelehnten Lieferungen des Kontos, neueste zuerst.
export async function recentRejections(pool: pg.Pool, account: string, days: number): Promise<Rejection[]> {
  const result = await pool.query(
    `SELECT id, decided_at, result->'errors' AS errors FROM deliveries
     WHERE account_id = $1 AND state = 'rejected' AND decided_at > now() - make_interval(days => $2)
     ORDER BY decided_at DESC, seq DESC`,
    [account, days],
  );
  return result.rows.map((r) => ({ deliveryId: r.id, decidedAt: r.decided_at, ...(r.errors === null ? {} : { errors: r.errors }) }));
}
