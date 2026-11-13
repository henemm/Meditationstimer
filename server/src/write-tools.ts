// Lieferwerkzeuge (B2a-5): Lieferung aufbauen, durch den Prüfer aus B0 schicken, ablegen. Neu für den Claude-Dienst; Muster der
// Schreibwerkzeuge (erst prüfen, dann speichern, Ablehnung mit Grund und Ausweg): loose-ends server/src/mcp.ts @ 24a6da6.
// Ein String als Ergebnis ist eine Ablehnung (nichts gespeichert), alles andere die JSON-Antwort.
import { randomInt, randomUUID } from "node:crypto";
import type pg from "pg";

import { validateDelivery, type DeliveryError } from "../../Contracts/validator/src/index.ts";
import { knownDeliveries, putDelivery, supersede, type KnownDelivery } from "./deliveries.ts";
import { getTranscript } from "./transcripts.ts";

type Db = pg.Pool | pg.PoolClient;
export type Doc = Record<string, any>;
export type Outcome = Doc | string;
export type Kind = "exercise" | "program" | "breath";

const isRecord = (v: unknown): v is Doc => typeof v === "object" && v !== null && !Array.isArray(v);
const refuse = (what: string, way: string): string => `${what} Ausweg: ${way}`;

// itemId und packageId: Kleinbuchstaben a–z/0–9/-, Umlaute umschrieben, Folgen und Ränder bereinigt, gekürzt.
export function slug(text: string, max = 40): string {
  const plain = text.toLowerCase().replaceAll("ä", "ae").replaceAll("ö", "oe").replaceAll("ü", "ue").replaceAll("ß", "ss");
  return plain.replace(/[^a-z0-9]+/g, "-").replace(/^-+/, "").slice(0, max).replace(/-+$/, "");
}

function randomSuffix(): string {
  return Array.from({ length: 6 }, () => "abcdefghijklmnopqrstuvwxyz0123456789"[randomInt(36)]).join("");
}

export const newItemId = (name: unknown): string =>
  `claude.${slug(typeof name === "string" ? name : "") || "baustein"}-${randomSuffix()}`;

// Paket aus dem Namen im Aufruf (ohne Rand-Leerzeichen); gleicher Name in anderer Schreibweise ergibt dieselbe packageId.
// Ein Wert, der kein Text ist, bekommt eine Platzhalter-Kennung, damit der Prüfer genau den Namen beanstandet.
export function packageOf(name: unknown): Doc | undefined {
  if (name === undefined) return undefined;
  if (typeof name !== "string") return { packageId: "claude.paket", name };
  return { packageId: `claude.${slug(name)}`, name: name.trim() };
}

// Bestand aus Abschrift und Lieferungen (waiting, claimed, accepted) in einer Form.
type Known = {
  id: string; kind: Kind; revision: number; name: unknown; pkg?: Doc; at?: number;
  source: "transcript" | "waiting" | "claimed" | "accepted"; state?: string; origin?: string;
};
type Snapshot = { entries: Known[]; rows: KnownDelivery[]; exercises: { id: string; name: string }[] };

const LISTS: [string, Kind][] = [["exercises", "exercise"], ["programs", "program"], ["breaths", "breath"]];

function fromTranscript(transcript: Doc | undefined): Known[] {
  return LISTS.flatMap(([list, kind]) => ((transcript?.[list] ?? []) as Doc[]).map((e): Known => ({
    id: e.id, kind, revision: e.revision ?? 1, name: e.name, source: "transcript", state: e.state, origin: e.origin,
    ...(typeof e.packageId === "string" ? { pkg: { packageId: e.packageId, name: e.packageName ?? e.packageId.replace(/^claude\./, "") } } : {}),
  })));
}

function fromDeliveries(rows: KnownDelivery[]): Known[] {
  return rows.flatMap((row, at) => {
    const doc = row.delivery as Doc;
    return (doc.items as Doc[]).filter((i) => i.kind !== "withdrawal").map((i): Known => ({
      id: i.itemId, kind: i.kind, revision: i.revision, name: i.name, source: row.state, at,
      ...(isRecord(doc.package) ? { pkg: doc.package } : {}),
    }));
  });
}

// Prüfkontext knownExercises: Übungen der Abschrift (ohne builtin) und Übungen aus Lieferungen, die noch nicht in der Abschrift stehen
// (bei mehreren Fassungen zählt die höchste).
function knownExercises(entries: Known[], transcriptIds: Set<string>): { id: string; name: string }[] {
  const out = new Map<string, Known>();
  for (const e of entries) {
    if (e.kind !== "exercise" || e.origin === "builtin" || typeof e.name !== "string") continue;
    if (e.source !== "transcript" && transcriptIds.has(e.id)) continue;
    const seen = out.get(e.id);
    if (seen === undefined || e.revision > seen.revision) out.set(e.id, e);
  }
  return [...out.values()].map((e) => ({ id: e.id, name: e.name as string }));
}

async function snapshot(pool: Db, owner: string): Promise<Snapshot> {
  const transcript = await getTranscript(pool, owner);
  const own = fromTranscript(transcript);
  const rows = await knownDeliveries(pool, owner);
  const entries = [...own, ...fromDeliveries(rows)];
  return { entries, rows, exercises: knownExercises(entries, new Set(own.map((e) => e.id))) };
}

const highest = (entries: Known[]): Known => entries.reduce((a, b) => (b.revision > a.revision ? b : a));
// Ein Baustein lebt, solange die Abschrift ihn nicht als zurückgenommen führt (ohne Abschrift-Eintrag: solange eine Lieferung ihn trägt).
const isLive = (entries: Known[]): boolean => {
  const own = entries.find((e) => e.source === "transcript");
  return own === undefined ? entries.length > 0 : own.state !== "withdrawn";
};
const inApp = (e: Known): boolean => (e.source === "transcript" ? e.state !== "withdrawn" : e.source !== "waiting");

function envelope(why: unknown, pkg: Doc | undefined, items: Doc[]): Doc {
  return {
    format: "hhhaven.delivery/1", deliveryId: randomUUID(), source: "claude", createdAt: new Date().toISOString(),
    ...(why === undefined ? {} : { why }), ...(pkg === undefined ? {} : { package: pkg }), items,
  };
}

const errorLine = (e: DeliveryError): string => `${e.path === "" ? "Lieferung" : e.path}: ${e.message} Ausweg: ${e.hint}`;

// Der Prüfer aus B0 ist die einzige Instanz für die Form; ohne Fehler wird abgelegt, sonst nichts.
function check(doc: Doc, snap: Snapshot): string | undefined {
  const { errors } = validateDelivery(doc, { knownExercises: snap.exercises });
  return errors.length === 0 ? undefined : `Die Lieferung wurde abgelehnt, nichts wurde gespeichert:\n${errors.map(errorLine).join("\n")}`;
}

async function submit(pool: Db, owner: string, snap: Snapshot, doc: Doc, answer: Doc): Promise<Outcome> {
  const problem = check(doc, snap);
  if (problem !== undefined) return problem;
  await putDelivery(pool, owner, doc as { deliveryId: string });
  return { deliveryId: doc.deliveryId, ...answer, state: "waiting" };
}

// Ein Schreiber je Konto: eine Transaktion mit Kontosperre umschließt Lesen des Bestands, Prüfen und Ablegen bzw. Überholen.
async function locked(pool: pg.Pool, owner: string, run: (db: pg.PoolClient) => Promise<Outcome>): Promise<Outcome> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query("SELECT pg_advisory_xact_lock(hashtextextended('hhhaven:' || $1::text, 0))", [owner]);
    const out = await run(client);
    await client.query("COMMIT");
    return out;
  } catch (error) {
    await client.query("ROLLBACK").catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

// kind, itemId und revision vergibt der Dienst; sie in den Eingaben still zu überschreiben wäre irreführend.
function serviceField(fields: unknown): string | undefined {
  if (!isRecord(fields)) return undefined;
  const name = ["kind", "itemId", "revision"].find((f) => Object.hasOwn(fields, f));
  return name === undefined ? undefined : refuse(`${name} vergibt der Dienst; bitte weglassen.`, `Den Aufruf ohne ${name} wiederholen.`);
}

// exercise_define, program_create, breath_create: why und package aus dem Aufruf, alles andere ist der Eintrag.
export async function createItem(pool: pg.Pool, owner: string, kind: Kind, args: Doc): Promise<Outcome> {
  const { why, package: pkg, ...fields } = args;
  const reserved = serviceField(fields);
  if (reserved !== undefined) return reserved;
  const itemId = newItemId(fields.name);
  const doc = envelope(why, packageOf(pkg), [{ ...fields, kind, itemId, revision: 1 }]);
  return locked(pool, owner, async (db) => submit(db, owner, await snapshot(db, owner), doc, { itemId, revision: 1 }));
}

const NOT_OWN = refuse("Nur eigene Lieferungen von Claude lassen sich ändern oder zurückziehen (eigene und mitgelieferte Inhalte von Henning nie).",
  "Biete Henning stattdessen eine Kopie als neuen Baustein an.");
const NOT_FOUND = refuse("Nicht gefunden: diesen Baustein hat Claude nicht geliefert.", "Kennungen liefert catalog.");

// Eigener, noch lebender Baustein: die Einträge dazu, oder die Ablehnung.
function ownEntries(snap: Snapshot, itemId: string): Known[] | string {
  if (!itemId.startsWith("claude.")) return NOT_OWN;
  const entries = snap.entries.filter((e) => e.id === itemId);
  if (entries.length === 0) return NOT_FOUND;
  if (entries.some((e) => e.origin !== undefined && e.origin !== "claude")) return NOT_OWN;
  return entries;
}

export async function updateItem(pool: pg.Pool, owner: string, args: Doc): Promise<Outcome> {
  return locked(pool, owner, (db) => updateLocked(db, owner, args));
}

async function updateLocked(db: Db, owner: string, args: Doc): Promise<Outcome> {
  const { itemId, basedOnRevision, why, fields } = args;
  if (typeof itemId !== "string") return refuse("itemId fehlt oder ist kein Text.", "itemId aus catalog oder show angeben.");
  const snap = await snapshot(db, owner);
  const entries = ownEntries(snap, itemId);
  if (typeof entries === "string") return entries;
  const state = entries.find((e) => e.source === "transcript")?.state;
  if (state === "adapted") return refuse("Henning hat ihn angepasst.", "Biete eine Kopie an (neuer Baustein).");
  if (state === "withdrawn") return refuse("Der Baustein ist zurückgenommen.", "Biete bei Bedarf eine Kopie als neuen Baustein an.");
  const latest = highest(entries);
  if (basedOnRevision !== latest.revision) return refuse("Stand hat sich geändert, bitte neu lesen.", "Mit show den aktuellen Stand holen und basedOnRevision anpassen.");
  if (!isRecord(fields)) return refuse("fields fehlt oder ist kein Objekt.", "fields = vollständige neue Fassung wie bei der Erstellung, ohne why und package.");
  const reserved = serviceField(fields);
  if (reserved !== undefined) return reserved;
  const revision = latest.revision + 1;
  const doc = envelope(why, latest.pkg, [{ ...fields, kind: latest.kind, itemId, revision }]);
  return submit(db, owner, snap, doc, { itemId, revision });
}

// Wartende Lieferungen (Kennungen), die einen der Bausteine enthalten.
function waitingFor(ids: Set<string>, rows: KnownDelivery[]): string[] {
  return rows.filter((r) => r.state === "waiting" && ((r.delivery as Doc).items as Doc[]).some((i) => ids.has(i.itemId) && i.kind !== "withdrawal"))
    .map((r) => r.deliveryId);
}

const ALREADY = refuse("Rücknahme liegt schon bereit.", "Nichts weiter zu tun; den Stand zeigt delivery_status.");

// Schon zurückgenommen oder zurückgezogen? Eine Rücknahme-Lieferung (waiting, claimed, accepted) für den Baustein oder sein Paket, die
// nicht älter ist als der jüngste Eintrag aus einer Lieferung (die Abschrift zeigt sie vielleicht noch nicht).
function withdrawing(snap: Snapshot, group: Known[]): boolean {
  const pkgId = group.find((e) => e.pkg !== undefined)?.pkg?.packageId;
  const newest = Math.max(-1, ...group.map((e) => e.at ?? -1));
  return snap.rows.some((row, index) => index > newest && ((row.delivery as Doc).items as Doc[]).some((i) =>
    i.kind === "withdrawal" && (i.itemId === group[0]!.id || (pkgId !== undefined && i.packageId === pkgId))));
}

type Target = { ids: Set<string>; live: Known[][]; item: Doc; pkg?: Doc };

// Ziel der Rücknahme: ein Baustein oder ein Paket; die lebenden Gruppen von Einträgen, oder die Ablehnung.
function withdrawTarget(snap: Snapshot, itemId: unknown, pkgName: unknown): Target | string {
  if ((itemId === undefined) === (pkgName === undefined)) return refuse("Genau eins von itemId oder package angeben.", "Einen Baustein über itemId oder ein ganzes Paket über package zurückziehen.");
  if (itemId !== undefined) {
    if (typeof itemId !== "string") return refuse("itemId ist kein Text.", "itemId aus catalog oder show angeben.");
    const entries = ownEntries(snap, itemId);
    if (typeof entries === "string") return entries;
    if (!isLive(entries)) return refuse("Der Baustein ist schon zurückgenommen.", "Nichts weiter zu tun.");
    if (withdrawing(snap, entries)) return ALREADY;
    return { ids: new Set([itemId]), live: [entries], item: { kind: "withdrawal", itemId } };
  }
  const pkg = packageOf(pkgName) as Doc;
  const members = snap.entries.filter((e) => e.pkg?.packageId === pkg.packageId);
  if (members.length === 0) return refuse("Unbekanntes Paket.", "Paketnamen wie bei der Lieferung angeben; Kennungen liefert catalog.");
  const groups = [...new Set(members.map((e) => e.id))].map((id) => snap.entries.filter((e) => e.id === id)).filter(isLive);
  if (groups.length === 0) return refuse("Alle Teile des Pakets sind schon zurückgenommen.", "Nichts weiter zu tun.");
  if (groups.every((g) => withdrawing(snap, g))) return ALREADY;
  return { ids: new Set(groups.map((g) => g[0]!.id)), live: groups, item: { kind: "withdrawal", packageId: pkg.packageId }, pkg };
}

// Wartende Lieferungen werden überholt; nur was schon in der App ist (oder zwischendurch abgeholt wurde), braucht eine Rücknahme-Lieferung.
export async function withdrawItem(pool: pg.Pool, owner: string, args: Doc): Promise<Outcome> {
  return locked(pool, owner, (db) => withdrawLocked(db, owner, args));
}

async function withdrawLocked(db: Db, owner: string, args: Doc): Promise<Outcome> {
  const snap = await snapshot(db, owner);
  const target = withdrawTarget(snap, args.itemId, args.package);
  if (typeof target === "string") return target;
  const doc = envelope(args.why, target.pkg, [target.item]);
  const problem = check(doc, snap);
  if (problem !== undefined) return problem;
  let needed = target.live.some((group) => group.some(inApp));
  const superseded: string[] = [];
  for (const id of waitingFor(target.ids, snap.rows)) {
    if (await supersede(db, owner, id)) superseded.push(id);
    else needed = true;
  }
  if (!needed) return { state: "withdrawn", superseded };
  await putDelivery(db, owner, doc as { deliveryId: string });
  return { deliveryId: doc.deliveryId, state: "waiting", superseded };
}

const textOf = (v: unknown, max: number): v is string => typeof v === "string" && v.trim() !== "" && Array.from(v).length <= max && !v.includes("\u0000");

// Wunsch an Henning: Text 1–1000 Zeichen (nur Leerraum gilt als leer), Kontext optional 1–300.
export async function reportWish(pool: pg.Pool, owner: string, args: Doc): Promise<Outcome> {
  const { text, context } = args;
  if (!textOf(text, 1000)) return refuse("text fehlt oder ist leer, zu lang (über 1000 Zeichen) oder kein Text.", "Den Wunsch in 1 bis 1000 Zeichen formulieren.");
  if (context !== undefined && !textOf(context, 300)) return refuse("context ist leer, zu lang (über 300 Zeichen) oder kein Text.", "context weglassen oder in 1 bis 300 Zeichen fassen.");
  const wishId = randomUUID();
  await pool.query("INSERT INTO wishes (id, account_id, text, context) VALUES ($1, $2, $3, $4)", [wishId, owner, text, context ?? null]);
  return { wishId };
}
