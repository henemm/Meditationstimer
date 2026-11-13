// Prüfregeln für Impuls-Challenges (Spec: openspec/specs/integrations/claude-challenge.md, Abschnitt 2).
import { M } from './messages.ts';
import { checkInt, checkSymbol, checkText, field, has, isObj, list, noUnknown, parseDay, checkDay, ptr } from './rules.ts';
import type { Obj, Sink } from './rules.ts';

export const CHALLENGE_MAX_DAYS = 90;
const START_LEAD = 30;
const MOMENTS = ['day', 'evening'];

/** `createdDay`: UTC-Tag von createdAt als Tageszahl, nur wenn createdAt gültig ist. */
export type ChallengeState = Sink & { createdDay: number | undefined };

/** Startdatum: echtes Datum, dann Zeitfenster relativ zum UTC-Tag von createdAt. */
function checkStart(st: ChallengeState, item: Obj, base: string): void {
  const ok = field(st, item, 'startDate', base, true, checkDay);
  if (!ok || st.createdDay === undefined) return;
  const start = parseDay(item.startDate) as number;
  const path = ptr(base, 'startDate');
  if (start < st.createdDay - 1) st.errors.push(M.startInPast(path));
  else if (start > st.createdDay + START_LEAD) st.errors.push(M.startTooLate(path));
}

function checkImpulse(st: ChallengeState, impulse: unknown, path: string): void {
  if (!isObj(impulse)) return void st.errors.push(M.type(path, 'ein Objekt', true));
  noUnknown(st, impulse, path, ['text', 'moment', 'question']);
  field(st, impulse, 'text', path, true, (v, p) => checkText(v, p, 300, true));
  field(st, impulse, 'moment', path, true, (v, p) =>
    typeof v !== 'string' ? M.type(p, 'ein Text') : MOMENTS.includes(v) ? null : M.notAllowed(p, '„day“ oder „evening“'));
  field(st, impulse, 'question', path, false, (v, p) => checkText(v, p, 120, false));
}

/** Inhalt der Stufe; gibt die Impulsliste zurück, wenn es eine gültige Impuls-Liste ist, sonst undefined. */
function checkContent(st: ChallengeState, stage: Obj, base: string): unknown[] | undefined {
  const path = ptr(base, 'content');
  if (!has(stage, 'content')) return void st.errors.push(M.missing(path));
  const content = stage.content;
  if (!isObj(content)) return void st.errors.push(M.type(path, 'ein Objekt'));
  const typePath = ptr(path, 'type');
  if (!has(content, 'type')) return void st.errors.push(M.missing(typePath));
  if (typeof content.type !== 'string') return void st.errors.push(M.type(typePath, 'ein Text'));
  if (content.type !== 'impulses') return void st.errors.push(M.contentType(typePath));
  noUnknown(st, content, path, ['type', 'impulses']);
  const impulses = list(st, content, 'impulses', path, 0, Number.POSITIVE_INFINITY);
  const listPath = ptr(path, 'impulses');
  impulses?.forEach((imp, i) => checkImpulse(st, imp, ptr(listPath, i)));
  return impulses;
}

/** Prüft eine Stufe; gibt `days` zurück, wenn gültig, sonst undefined. */
function checkStage(st: ChallengeState, stage: unknown, path: string): number | undefined {
  if (!isObj(stage)) return void st.errors.push(M.type(path, 'ein Objekt', true));
  noUnknown(st, stage, path, ['days', 'content']);
  const daysOk = field(st, stage, 'days', path, true, (v, p) => checkInt(v, p, 1, CHALLENGE_MAX_DAYS));
  const impulses = checkContent(st, stage, path);
  const days = daysOk ? (stage.days as number) : undefined;
  if (days !== undefined && impulses !== undefined && impulses.length !== days) {
    st.errors.push(M.impulseCount(ptr(ptr(path, 'content'), 'impulses'), impulses.length, days));
  }
  return days;
}

/** Prüft eine Challenge (ohne itemId/revision, die prüft der Aufrufer). */
export function checkChallenge(st: ChallengeState, item: Obj, base: string): void {
  noUnknown(st, item, base, ['kind', 'itemId', 'revision', 'title', 'symbol', 'description', 'startDate', 'stages']);
  field(st, item, 'title', base, true, (v, p) => checkText(v, p, 40, false));
  field(st, item, 'symbol', base, true, checkSymbol);
  field(st, item, 'description', base, false, (v, p) => checkText(v, p, 500, true));
  checkStart(st, item, base);
  const stages = list(st, item, 'stages', base, 1, 1);
  if (stages === undefined) return;
  const days = stages.map((s, i) => checkStage(st, s, ptr(ptr(base, 'stages'), i)));
  if (days.some((d) => d === undefined)) return;
  const total = (days as number[]).reduce((a, b) => a + b, 0);
  if (total > CHALLENGE_MAX_DAYS) st.errors.push(M.totalDays(base, total, CHALLENGE_MAX_DAYS));
}
