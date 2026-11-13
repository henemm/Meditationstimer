// Reine Funktionen der Lesewerkzeuge (B2a-4); mcp.ts holt die Daten und reicht sie hierher. Muster der Suche: loose-ends server/src/mcp.ts @ 24a6da6.
import type { DeliveryRow, OpenDelivery, Rejection } from "./deliveries.ts";
import { builtinExercises } from "./forms.ts";
import type { Transcript } from "./transcripts.ts";

export type Kind = "exercise" | "program" | "breath" | "reminder" | "challenge";
type Origin = "builtin" | "own" | "claude";
export type Entry = { id: string; name: string; origin: Origin; category?: string; rounds?: number; state?: string; enabled?: boolean; time?: string; weekdays?: string[]; target?: unknown; startDate?: string; stages?: { days: number }[]; progress?: { extendedBy: number }; steps?: { workSeconds: number; restSeconds: number }[] };
type Lists = Record<Kind, Entry[]>;
type Doc = Record<string, any>;

const HOUR = 3_600_000;
const DAY = 24 * HOUR;
const collator = new Intl.Collator("de", { sensitivity: "base" });
// ß zerfällt nicht in Grund- und Akzentzeichen, daher eigens zu ss.
const plain = (text: string): string => text.normalize("NFD").replace(/\p{M}/gu, "").toLowerCase().replaceAll("ß", "ss");

// Ohne Abschrift gibt es nur die eingebauten Übungen aus dem Katalog.
function lists(transcript: Transcript | undefined): Lists {
  if (transcript === undefined) {
    const exercise = builtinExercises.map((e) => ({ ...e, origin: "builtin" as const }));
    return { exercise, program: [], breath: [], reminder: [], challenge: [] };
  }
  const doc = transcript as unknown as { exercises: Entry[]; programs: Entry[]; breaths: Entry[]; reminders?: (Entry & { title: string })[]; challenges?: (Entry & { title: string })[] };
  // Erinnerungen und Challenges tragen ihren Namen im Feld title (Fassung 2, optional).
  const reminder = (doc.reminders ?? []).map((e) => ({ ...e, name: e.title }));
  const challenge = (doc.challenges ?? []).map((e) => ({ ...e, name: e.title }));
  return { exercise: doc.exercises, program: doc.programs, breath: doc.breaths, reminder, challenge };
}

export function ageHours(transcript: Transcript, now: Date): number {
  return Math.floor((now.getTime() - new Date(transcript.generatedAt).getTime()) / HOUR);
}

type Message = { kind: string; text: string; deliveryId?: string; itemId?: string };

const dayOf = (ms: number): number => Math.floor(ms / DAY);
const totalDays = (e: Entry): number => (e.stages ?? []).reduce((sum, st) => sum + st.days, 0);

// Letzter Tag einer Challenge als UTC-Tageszahl: startDate + Summe(days) + extendedBy - 1 (Spec claude-challenge.md, Festlegungen).
export function lastDay(e: Entry): number {
  return dayOf(Date.parse(`${e.startDate}T00:00:00Z`)) + totalDays(e) + (e.progress?.extendedBy ?? 0) - 1;
}

// Aktive Challenges, deren letzter Tag heute, morgen oder übermorgen (UTC-Tage von generatedAt) ist.
function endingMessages(transcript: Transcript | undefined): Message[] {
  if (transcript === undefined) return [];
  const today = dayOf(Date.parse(transcript.generatedAt));
  return lists(transcript).challenge
    .filter((e) => e.state === "active" && lastDay(e) >= today && lastDay(e) <= today + 2)
    .map((e) => ({ kind: "challenge_ending", itemId: e.id, text: `Die Challenge „${e.name}“ endet ${["heute", "morgen", "übermorgen"][lastDay(e) - today]}` }));
}

// Meldungen zuerst: abgelehnte, lange wartende, Abschrift (fehlend oder zu alt).
export function overviewMessages(transcript: Transcript | undefined, open: OpenDelivery[], rejected: Rejection[], now: Date): Message[] {
  const messages: Message[] = rejected.map((r) => ({
    kind: "rejected", deliveryId: r.deliveryId,
    text: `Die App hat eine Lieferung abgelehnt${r.errors?.[0] === undefined ? "" : `: ${r.errors[0].message}`}`,
  }));
  for (const d of open) {
    if (d.state === "waiting" && now.getTime() - d.createdAt.getTime() > DAY) {
      messages.push({ kind: "waiting_long", deliveryId: d.deliveryId, text: "Eine Lieferung wartet seit über 24 Stunden darauf, dass die App geöffnet wird" });
    }
  }
  if (transcript === undefined) messages.push({ kind: "no_transcript", text: "Es gibt noch keine Abschrift der App; bitte Healthy Habits öffnen" });
  else if (now.getTime() - new Date(transcript.generatedAt).getTime() > 7 * DAY) {
    messages.push({ kind: "transcript_old", text: "Die Abschrift der App ist älter als 7 Tage; der Bestand kann veraltet sein" });
  }
  messages.push(...endingMessages(transcript));
  if (transcript?.version === 1) messages.push({ kind: "history_missing", text: "Die App schickt noch keinen Verlauf; bitte Healthy Habits aktualisieren und öffnen" });
  return messages;
}

export function overviewDoc(transcript: Transcript | undefined, open: OpenDelivery[], rejected: Rejection[], now: Date): Doc {
  const all = lists(transcript);
  const counts: Doc = {};
  for (const kind of Object.keys(all) as Kind[]) {
    counts[kind] = { builtin: 0, own: 0, claude: 0 };
    for (const entry of all[kind]) counts[kind][entry.origin] += 1;
  }
  return {
    messages: overviewMessages(transcript, open, rejected, now), counts, waiting: open.length,
    activeClaudeReminders: all.reminder.filter((e) => e.origin === "claude" && e.state === "active" && e.enabled === true).length,
    ...(transcript === undefined ? {} : { generatedAt: transcript.generatedAt, transcriptAgeHours: ageHours(transcript, now) }),
  };
}

const roundsTotal = (e: Entry): number => (e.rounds ?? 1) * (e.steps ?? []).reduce((sum, s) => sum + s.workSeconds + s.restSeconds, 0);
const breathTotal = (e: Doc): number => e.rounds * (e.inhaleSeconds + e.holdInSeconds + e.exhaleSeconds + e.holdOutSeconds);

function row(kind: Kind, e: Entry): Doc {
  const { id, name, origin } = e;
  if (kind === "exercise") return { id, name, origin, category: e.category };
  if (kind === "challenge") return { id, name, origin, startDate: e.startDate, totalDays: totalDays(e) };
  if (kind === "reminder") return { id, name, origin, time: e.time, weekdays: e.weekdays, target: e.target };
  if (kind === "program") return { id, name, origin, steps: e.steps?.length ?? 0, durationSeconds: roundsTotal(e) };
  return { id, name, origin, durationSeconds: breathTotal(e) };
}

// Suche ohne Groß-/Kleinschreibung und Akzente, alle Wörter müssen im Namen vorkommen; höchstens 100 Zeilen, nach Name sortiert.
export function catalogDoc(transcript: Transcript | undefined, args: { kind: Kind; query?: string; origin?: Origin }): Doc {
  const words = plain(args.query ?? "").split(/\s+/).filter((w) => w !== "");
  const found = lists(transcript)[args.kind]
    .filter((e) => args.origin === undefined || e.origin === args.origin)
    .filter((e) => words.every((w) => plain(e.name).includes(w)))
    .sort((a, b) => collator.compare(a.name, b.name));
  return {
    kind: args.kind, count: found.length, items: found.slice(0, 100).map((e) => row(args.kind, e)),
    ...(transcript === undefined ? { note: "noch keine Abschrift" } : {}),
  };
}

// Lieferungen in waiting oder claimed, die den Baustein enthalten oder (einzeln oder als Paket) zurücknehmen.
function pendingFor(item: Doc, open: OpenDelivery[]): Doc[] {
  const touches = (d: OpenDelivery) => ((d.delivery as Doc).items as Doc[]).some((i) =>
    i.itemId === item.id || (i.kind === "withdrawal" && i.packageId !== undefined && i.packageId === item.packageId));
  return open.filter(touches).map((d) => ({ deliveryId: d.deliveryId, state: d.state === "claimed" ? "in_app" : "waiting" }));
}

export function showDoc(transcript: Transcript | undefined, id: string, open: OpenDelivery[]): Doc | undefined {
  const all = lists(transcript);
  for (const kind of ["exercise", "program", "breath", "reminder", "challenge"] as Kind[]) {
    const item = all[kind].find((e) => e.id === id);
    if (item !== undefined) return { kind, item, pending: pendingFor(item, open) };
  }
  return undefined;
}

const OUTER_STATE: Record<string, string> = { waiting: "waiting", claimed: "in_app", accepted: "accepted", rejected: "rejected", superseded: "withdrawn" };

// Inhalt kurz: Art und Name, bei Rücknahmen Baustein- oder Paketkennung.
function brief(delivery: unknown): Doc[] {
  return ((delivery as Doc).items as Doc[]).map((i) => ({
    kind: i.kind, ...(i.name === undefined ? {} : { name: i.name }),
    ...(i.itemId === undefined ? {} : { itemId: i.itemId }), ...(i.packageId === undefined ? {} : { packageId: i.packageId }),
  }));
}

export function deliveryStatusDoc(rows: DeliveryRow[]): Doc {
  return {
    deliveries: rows.map((r) => ({
      deliveryId: r.deliveryId, state: OUTER_STATE[r.state], createdAt: r.createdAt,
      ...(r.decidedAt === undefined ? {} : { decidedAt: r.decidedAt }),
      ...(r.errors === undefined ? {} : { errors: r.errors }), items: brief(r.delivery),
    })),
  };
}
