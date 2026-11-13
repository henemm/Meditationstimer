// Übernommen aus loose-ends server/src/transcripts.ts @ 24a6da6 (Muster: einzelnes INSERT … ON CONFLICT … WHERE, Form vor Ablage);
// angepasst: Form kommt aus dem JSON-Schema (Ajv) statt aus handgeschriebenen Prüfungen, Ergebnis "invalid" | "stale" | "stored".
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { Ajv2020 } from "ajv/dist/2020.js";
import type pg from "pg";

// Die Abschrift als Dokument; die Form sichert das Schema (Contracts/transcript/transcript-v1.schema.json).
export type Transcript = {
  version: 1;
  generatedAt: string;
  exercises: { id: string }[];
  programs: { id: string }[];
  breaths: { id: string }[];
  deliveries: { deliveryId: string; outcome: string }[];
};

// Einmal kompiliert; das Schema ist die einzige Quelle der Regeln. Im Image liegt es unter /app/Contracts, im Repo an derselben Stelle relativ zu server/.
const schemaPath = join(import.meta.dirname, "..", "..", "Contracts", "transcript", "transcript-v1.schema.json");
const validate = new Ajv2020({ allErrors: false, strict: true, strictRequired: false }).compile(JSON.parse(readFileSync(schemaPath, "utf8")));

const lists = ["exercises", "programs", "breaths"] as const;

// Kennungen je Liste eindeutig; nennt nur Liste und Position, nie Inhalte.
function duplicateId(doc: Transcript): string | undefined {
  for (const name of lists) {
    const seen = new Set<string>();
    for (const [index, item] of doc[name].entries()) {
      if (seen.has(item.id)) return `/${name}/${index}/id: Kennung kommt in der Liste mehrfach vor`;
      seen.add(item.id);
    }
  }
  return undefined;
}

// Grund (deutsch, mit Pfad, ohne Inhalte aus dem Dokument) oder undefined, wenn die Abschrift gültig ist.
export function checkTranscript(doc: unknown): string | undefined {
  if (!validate(doc)) {
    const path = validate.errors?.[0]?.instancePath || "Wurzel";
    return `${path}: entspricht nicht der Abschrift, Fassung 1`;
  }
  return duplicateId(doc as Transcript);
}

// Erst Form, dann ein Statement: die erste Abschrift wird abgelegt, eine neuere ersetzt sie, eine ältere oder gleich alte nicht.
export async function putTranscript(pool: pg.Pool, account: string, doc: unknown): Promise<"stored" | "stale" | "invalid"> {
  if (checkTranscript(doc) !== undefined) return "invalid";
  const transcript = doc as Transcript;
  const result = await pool.query(
    `INSERT INTO transcripts (account_id, doc, generated_at) VALUES ($1, $2::jsonb, $3)
     ON CONFLICT (account_id) DO UPDATE SET doc = excluded.doc, generated_at = excluded.generated_at, received_at = now()
     WHERE transcripts.generated_at < excluded.generated_at
     RETURNING account_id`,
    [account, JSON.stringify(transcript), transcript.generatedAt],
  );
  return result.rowCount === 1 ? "stored" : "stale";
}

// Ein Statement: die abgelegte Abschrift des Kontos unverändert, oder undefined.
export async function getTranscript(pool: pg.Pool, account: string): Promise<Transcript | undefined> {
  const result = await pool.query<{ doc: Transcript }>("SELECT doc FROM transcripts WHERE account_id = $1", [account]);
  return result.rows[0]?.doc;
}
