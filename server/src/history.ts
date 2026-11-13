// Rückblick (B3a, Issue #58): reine Funktion des Werkzeugs `history`; mcp.ts holt die Abschrift und reicht sie hierher.
// Spec: openspec/specs/integrations/claude-rueckblick.md Abschnitt 3
import { lastDay, type Entry } from "./read-tools.ts";
import type { HistorySession, Streak, Transcript } from "./transcripts.ts";

export type HistoryArgs = { from?: string; to?: string; kind?: string; programId?: string };
type Doc = Record<string, any>;

const DAY = 86_400_000;
const KINDS = ["meditation", "workout", "breath"] as const;
const MAX_DAYS = 90;
const MAX_SESSIONS = 200;
const collator = new Intl.Collator("de", { sensitivity: "base" });
const round1 = (value: number): number => Math.round(value * 10) / 10;
const dayOf = (ms: number): string => new Date(ms).toISOString().slice(0, 10);

// Tag JJJJ-MM-TT als UTC-Zeitpunkt (0 Uhr) oder undefined, wenn es das Datum nicht gibt.
function parseDay(text: string): number | undefined {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) return undefined;
  const ms = Date.parse(`${text}T00:00:00Z`);
  return Number.isNaN(ms) || dayOf(ms) !== text ? undefined : ms;
}

// Zeitraum in UTC-Tagen (Beginn des ersten und des letzten Tages) oder die Ablehnung mit Ausweg.
function resolveRange(args: HistoryArgs, generatedAt: string): { from: number; to: number } | string {
  const given: Record<string, number | undefined> = {};
  for (const name of ["from", "to"] as const) {
    const text = args[name];
    if (text === undefined) continue;
    given[name] = parseDay(text);
    if (given[name] === undefined) return `${name} ist kein gültiges Datum; erwartet wird JJJJ-MM-TT (UTC-Tag), zum Beispiel ${dayOf(Date.parse(generatedAt))}`;
  }
  const to = given.to ?? parseDay(dayOf(Date.parse(generatedAt)))!;
  const from = given.from ?? to - 30 * DAY;
  if (from > to) return "from liegt nach to; bitte from auf den früheren und to auf den späteren Tag setzen (JJJJ-MM-TT)";
  if ((to - from) / DAY + 1 > MAX_DAYS) return `Der Zeitraum darf höchstens ${MAX_DAYS} Tage umfassen; bitte from und to enger setzen oder in mehreren Abfragen lesen`;
  return { from, to };
}

type Names = Map<string, string>;

function namesOf(transcript: Transcript): Names {
  const names: Names = new Map();
  for (const item of [...transcript.programs, ...transcript.breaths] as { id: string; name: string }[]) names.set(item.id, item.name);
  return names;
}

function feedbackRow(f: NonNullable<HistorySession["feedback"]>): Doc {
  return { rating: f.rating, ...(f.note === undefined ? {} : { note: f.note }) };
}

const streakRow = (s: Streak): Streak => ({ current: s.current, longest: s.longest });

function sessionRow(s: HistorySession, names: Names): Doc {
  const name = s.programId === undefined ? undefined : names.get(s.programId);
  return {
    startedAt: s.startedAt, kind: s.kind,
    ...(s.programId === undefined ? {} : { programId: s.programId }), ...(name === undefined ? {} : { programName: name }),
    durationSeconds: s.durationSeconds, completed: s.completed, ...(s.feedback === undefined ? {} : { feedback: feedbackRow(s.feedback) }),
  };
}

function byKind(found: HistorySession[]): Doc {
  const result: Doc = {};
  for (const kind of KINDS) {
    const of = found.filter((s) => s.kind === kind);
    result[kind] = { count: of.length, completed: of.filter((s) => s.completed).length, minutes: round1(of.reduce((sum, s) => sum + s.durationSeconds, 0) / 60) };
  }
  return result;
}

function byProgram(found: HistorySession[], names: Names): Doc[] {
  const groups = new Map<string, HistorySession[]>();
  for (const s of found) if (s.programId !== undefined) groups.set(s.programId, [...(groups.get(s.programId) ?? []), s]);
  const rows = [...groups].map(([programId, of]) => {
    const completed = of.filter((s) => s.completed).length;
    const feedback = { too_easy: 0, right: 0, too_hard: 0 };
    for (const s of of) if (s.feedback !== undefined) feedback[s.feedback.rating] += 1;
    return {
      programId, name: names.get(programId) ?? programId, kind: of[0]!.kind, count: of.length, completed, aborted: of.length - completed,
      averageMinutes: round1(of.reduce((sum, s) => sum + s.durationSeconds, 0) / of.length / 60), feedback,
    };
  });
  return rows.sort((a, b) => b.count - a.count || collator.compare(a.name, b.name));
}

const STATUSES = ["done", "made_up", "skipped", "open"] as const;
type ProgressDay = { date: string; status: (typeof STATUSES)[number]; note?: string };
type ChallengeDoc = Omit<Entry, "stages" | "progress" | "startDate"> & { title: string; startDate: string; stages: { days: number; content: { type: string; impulses?: { text: string }[] } }[]; progress: { days: ProgressDay[]; goals?: { stage: number; met: number; of: number }[]; extendedBy: number } };

// Eine Challenge für Claude: Zähler, aktueller Tag (1-basiert, vor dem Start 0, höchstens Dauer + Verlängerung), Notizen mit dem Text des Impulses ihres Tages
// und bei Ziel-Stufen die Summen (goals; Ziel-Stufen haben keine Impulse und keine Tageswerte).
function challengeRow(c: ChallengeDoc, today: number): Doc {
  const start = Date.parse(`${c.startDate}T00:00:00Z`) / DAY;
  const total = c.stages.reduce((sum, st) => sum + st.days, 0);
  const impulses = c.stages.flatMap((st) => st.content.impulses ?? Array.from({ length: st.days }, () => undefined));
  const counts = Object.fromEntries(STATUSES.map((status) => [status, c.progress.days.filter((d) => d.status === status).length]));
  const notes = c.progress.days.filter((d) => d.note !== undefined)
    .sort((a, b) => a.date.localeCompare(b.date))
    .map((d) => ({ date: d.date, impulse: impulses[Date.parse(`${d.date}T00:00:00Z`) / DAY - start]?.text, note: d.note }));
  return {
    id: c.id, title: c.title, startDate: c.startDate, totalDays: total, extendedBy: c.progress.extendedBy,
    day: Math.max(0, Math.min(today - start + 1, total + c.progress.extendedBy)), counts, notes,
    ...(c.stages.some((st) => st.content.type === "goal") ? { goals: c.progress.goals ?? [] } : {}),
  };
}

// Challenges, deren Zeitraum (Start bis letzter Tag, UTC-Tage) den Abfragezeitraum berührt; ohne Challenges eine leere Liste.
function challengeRows(transcript: Transcript, range: { from: number; to: number }): Doc[] {
  const today = Math.floor(Date.parse(transcript.generatedAt) / DAY);
  return ((transcript as unknown as { challenges?: ChallengeDoc[] }).challenges ?? [])
    .filter((c) => Date.parse(`${c.startDate}T00:00:00Z`) <= range.to && lastDay(c) * DAY >= range.from)
    .map((c) => challengeRow(c, today));
}

// Die Antwort des Werkzeugs oder ein String mit Grund und Ausweg (Ablehnung). Die Zusammenfassung zählt alle Treffer, die Liste höchstens 200.
export function historyDoc(transcript: Transcript | undefined, args: HistoryArgs): Doc | string {
  if (transcript === undefined) return "noch keine Abschrift; bitte Healthy Habits öffnen, die App schickt sie dann";
  if (transcript.history === undefined) return "Die App schickt noch keinen Verlauf; bitte Healthy Habits aktualisieren und öffnen";
  if (args.kind !== undefined && !(KINDS as readonly string[]).includes(args.kind)) return "kind ist unbekannt; erlaubt sind meditation, workout und breath";
  const range = resolveRange(args, transcript.generatedAt);
  if (typeof range === "string") return range;
  const names = namesOf(transcript);
  const found = transcript.history.sessions
    .filter((s) => { const t = Date.parse(s.startedAt); return t >= range.from && t < range.to + DAY; })
    .filter((s) => args.kind === undefined || s.kind === args.kind)
    .filter((s) => args.programId === undefined || s.programId === args.programId)
    .sort((a, b) => Date.parse(b.startedAt) - Date.parse(a.startedAt));
  return {
    generatedAt: transcript.generatedAt, range: { from: dayOf(range.from), to: dayOf(range.to) }, count: found.length,
    sessions: found.slice(0, MAX_SESSIONS).map((s) => sessionRow(s, names)),
    summary: { byKind: byKind(found), byProgram: byProgram(found, names) },
    streaks: { meditation: streakRow(transcript.history.streaks.meditation), workout: streakRow(transcript.history.streaks.workout) },
    challenges: challengeRows(transcript, range),
  };
}
