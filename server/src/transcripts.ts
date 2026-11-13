// Übernommen aus loose-ends server/src/transcripts.ts @ 24a6da6 (Muster: einzelnes INSERT … ON CONFLICT … WHERE, Form vor Ablage);
// angepasst: Form kommt aus dem JSON-Schema (Ajv) statt aus handgeschriebenen Prüfungen, Ergebnis "invalid" | "stale" | "stored".
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { Ajv2020 } from "ajv/dist/2020.js";
import type pg from "pg";

// Die Abschrift als Dokument; die Form sichert das Schema (Contracts/transcript/transcript-v1.schema.json).
export type HistorySession = {
  startedAt: string; kind: "meditation" | "workout" | "breath"; programId?: string; durationSeconds: number; completed: boolean;
  feedback?: { rating: "too_easy" | "right" | "too_hard"; note?: string };
};
export type ChallengeEntry = {
  id: string; startDate: string; stages: { days: number }[]; deliveredAt?: string;
  progress: { days: { date: string; status: string; note?: string }[]; extendedBy: number };
};
export type Streak = { current: number; longest: number };
export type History = { sessions: HistorySession[]; streaks: { meditation: Streak; workout: Streak } };

// Fassung 1 (ohne Verlauf) und Fassung 2 (mit history); Spec: openspec/specs/integrations/claude-rueckblick.md
export type Transcript = {
  version: 1 | 2;
  generatedAt: string;
  exercises: { id: string }[];
  programs: { id: string }[];
  breaths: { id: string }[];
  deliveries: { deliveryId: string; outcome: string }[];
  history?: History;
  reminders?: { id: string; target: { type: string; programId?: string; breathId?: string } }[];
  challenges?: ChallengeEntry[];
};

// Einmal kompiliert; das Schema ist die einzige Quelle der Regeln. Im Image liegt es unter /app/Contracts, im Repo an derselben Stelle relativ zu server/.
const schemaPath = (version: 1 | 2) => join(import.meta.dirname, "..", "..", "Contracts", "transcript", `transcript-v${version}.schema.json`);
const ajv = new Ajv2020({ allErrors: false, strict: true, strictRequired: false });
const validators = {
  1: ajv.compile(JSON.parse(readFileSync(schemaPath(1), "utf8"))),
  2: ajv.compile(JSON.parse(readFileSync(schemaPath(2), "utf8"))),
};

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

// Erinnerungen (Fassung 2, Spec claude-erinnerung.md Abschnitt 3): Kennungen eindeutig, Ziel-Programm bzw. Ziel-Atemübung steht in der Abschrift
// (ein Programm, das auf eine Atemübung zeigt, oder umgekehrt, fällt hier durch). Nennt nur Pfade, nie Inhalte.
function reminderProblem(doc: Transcript): string | undefined {
  const programs = new Set(doc.programs.map((p) => p.id));
  const breaths = new Set(doc.breaths.map((b) => b.id));
  const seen = new Set<string>();
  for (const [index, reminder] of (doc.reminders ?? []).entries()) {
    if (seen.has(reminder.id)) return `/reminders/${index}/id: Kennung kommt in der Liste mehrfach vor`;
    seen.add(reminder.id);
    const { type, programId, breathId } = reminder.target;
    if (type === "workout" && programId !== undefined && !programs.has(programId)) return `/reminders/${index}/target/programId: kein Programm in der Abschrift`;
    if (type === "breath" && !breaths.has(breathId!)) return `/reminders/${index}/target/breathId: keine Atemübung in der Abschrift`;
  }
  return undefined;
}

const DAY = 86_400_000;
const dayNumber = (text: string): number => Date.parse(`${text.slice(0, 10)}T00:00:00Z`) / DAY;

// Echtes Kalenderdatum? Der Tag wird über Date.UTC zurückgerechnet (30. Februar bleibt nicht 30. Februar).
function realDate(text: unknown): boolean {
  const m = typeof text === "string" ? /^(\d{4})-(\d{2})-(\d{2})/.exec(text) : null;
  if (m === null) return false;
  const [y, mo, d] = [Number(m[1]), Number(m[2]), Number(m[3])];
  const back = new Date(Date.UTC(y, mo - 1, d));
  back.setUTCFullYear(y);
  return back.getUTCFullYear() === y && back.getUTCMonth() === mo - 1 && back.getUTCDate() === d;
}

// Erster Zeitstempel ohne echtes Kalenderdatum (Pfad, nie Inhalt) oder undefined.
function calendarProblem(doc: Transcript): string | undefined {
  if (!realDate(doc.generatedAt)) return "/generatedAt: kein echtes Kalenderdatum";
  for (const name of [...lists, "reminders", "challenges"] as const) {
    for (const [index, item] of ((doc[name] ?? []) as { deliveredAt?: unknown }[]).entries()) {
      if (item.deliveredAt !== undefined && !realDate(item.deliveredAt)) return `/${name}/${index}/deliveredAt: kein echtes Kalenderdatum`;
    }
  }
  for (const [index, s] of (doc.history?.sessions ?? []).entries()) {
    if (!realDate(s.startedAt)) return `/history/sessions/${index}/startedAt: kein echtes Kalenderdatum`;
  }
  for (const [index, c] of (doc.challenges ?? []).entries()) {
    if (!realDate(c.startDate)) return `/challenges/${index}/startDate: kein echtes Kalenderdatum`;
    for (const [at, d] of c.progress.days.entries()) {
      if (!realDate(d.date)) return `/challenges/${index}/progress/days/${at}/date: kein echtes Kalenderdatum`;
    }
  }
  return undefined;
}

// Challenges (Fassung 2, Spec claude-challenge.md Abschnitt 3): Kennungen eindeutig; Tage lückenlos ab startDate, keiner nach dem UTC-Tag von
// generatedAt, höchstens Gesamtdauer + extendedBy. Nennt nur Pfade, nie Inhalte.
function challengeProblem(doc: Transcript): string | undefined {
  const today = dayNumber(doc.generatedAt);
  const seen = new Set<string>();
  for (const [index, c] of (doc.challenges ?? []).entries()) {
    if (seen.has(c.id)) return `/challenges/${index}/id: Kennung kommt in der Liste mehrfach vor`;
    seen.add(c.id);
    const start = dayNumber(c.startDate);
    const total = c.stages.reduce((sum, st) => sum + st.days, 0) + c.progress.extendedBy;
    if (c.progress.days.length > total) return `/challenges/${index}/progress/days: mehr Tage als Dauer plus Verlängerung`;
    for (const [at, d] of c.progress.days.entries()) {
      if (dayNumber(d.date) !== start + at) return `/challenges/${index}/progress/days/${at}/date: Tage müssen lückenlos ab startDate aufsteigen`;
      if (dayNumber(d.date) > today) return `/challenges/${index}/progress/days/${at}/date: liegt nach dem Tag von generatedAt`;
    }
  }
  return undefined;
}

// Was das Schema nicht kann (Fassung 2): Zeitfenster, Kennungen der Bausteine, Serien. Nennt nur Pfade, nie Inhalte.
function historyProblem(doc: Transcript): string | undefined {
  const history = doc.history!;
  const generated = new Date(doc.generatedAt).getTime();
  const programs = new Set(doc.programs.map((p) => p.id));
  const breaths = new Set(doc.breaths.map((b) => b.id));
  for (const [index, session] of history.sessions.entries()) {
    const started = new Date(session.startedAt).getTime();
    if (started > generated) return `/history/sessions/${index}/startedAt: liegt nach generatedAt`;
    if (started < generated - 90 * DAY) return `/history/sessions/${index}/startedAt: liegt mehr als 90 Tage vor generatedAt`;
    const known = session.kind === "workout" ? programs : session.kind === "breath" ? breaths : undefined;
    if (known !== undefined && !known.has(session.programId!)) return `/history/sessions/${index}/programId: kein Baustein dieser Art in der Abschrift`;
  }
  for (const name of ["meditation", "workout"] as const) {
    if (history.streaks[name].current > history.streaks[name].longest) return `/history/streaks/${name}: current ist größer als longest`;
  }
  return undefined;
}

// Grund (deutsch, mit Pfad, ohne Inhalte aus dem Dokument) oder undefined, wenn die Abschrift gültig ist.
export function checkTranscript(doc: unknown): string | undefined {
  const version = (doc as { version?: unknown } | null)?.version;
  if (version !== 1 && version !== 2) return "/version: nur Fassung 1 und 2 der Abschrift werden angenommen";
  const validate = validators[version];
  if (!validate(doc)) {
    const path = validate.errors?.[0]?.instancePath || "Wurzel";
    return `${path}: entspricht nicht der Abschrift, Fassung ${version}`;
  }
  return duplicateId(doc as Transcript) ?? calendarProblem(doc as Transcript) ?? (version === 2 ? historyProblem(doc as Transcript) ?? reminderProblem(doc as Transcript) ?? challengeProblem(doc as Transcript) : undefined);
}

// Erst Form, dann ein Statement: die erste Abschrift wird abgelegt, eine neuere ersetzt sie, eine ältere oder gleich alte nicht.
export async function putTranscript(pool: pg.Pool | pg.PoolClient, account: string, doc: unknown): Promise<"stored" | "stale" | "invalid"> {
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
export async function getTranscript(pool: pg.Pool | pg.PoolClient, account: string): Promise<Transcript | undefined> {
  const result = await pool.query<{ doc: Transcript }>("SELECT doc FROM transcripts WHERE account_id = $1", [account]);
  return result.rows[0]?.doc;
}
