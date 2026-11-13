// Prüfregeln für Impuls-Challenges (Spec: openspec/specs/integrations/claude-challenge.md, Abschnitt 2).
import { M } from './messages.ts';
import { checkDay, checkId, checkInt, checkSymbol, checkText, field, has, isObj, isScopedId, list, noUnknown, parseDay, ptr } from './rules.ts';
import type { Check, Obj, Sink } from './rules.ts';

export const CHALLENGE_MAX_DAYS = 90;
const START_LEAD = 30;
const MAX_STAGES = 6;
const MOMENTS = ['day', 'evening'];
const GOAL_TYPES = ['meditation', 'workout', 'tracker'];
const TRACKER_ID_FORM = 'Muster: „builtin.“, „own.“ oder „claude.“ gefolgt von 2–63 Zeichen aus a–z, 0–9 und „-“ (nicht am Anfang).';

/** `createdDay`: UTC-Tag von createdAt als Tageszahl, nur wenn createdAt gültig ist; `trackers`: bekannte Tracker-Kennungen. */
export type ChallengeState = Sink & { createdDay: number | undefined; trackers: Set<string> };

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

/** Impuls-Liste einer Impuls-Stufe; gibt sie zurück (auch bei falscher Größe), sonst undefined. */
function checkImpulses(st: ChallengeState, content: Obj, path: string): unknown[] | undefined {
  noUnknown(st, content, path, ['type', 'impulses']);
  const impulses = list(st, content, 'impulses', path, 0, Number.POSITIVE_INFINITY);
  const listPath = ptr(path, 'impulses');
  impulses?.forEach((imp, i) => checkImpulse(st, imp, ptr(listPath, i)));
  return impulses;
}

/** Bezug auf einen Tracker: Kennungsmuster, dann bekannt (Prüfkontext oder Lieferung)? */
function trackerRef(st: ChallengeState): Check {
  return (v, p) => {
    const err = checkId(v, p, (s) => isScopedId(s, ['builtin', 'own', 'claude']), TRACKER_ID_FORM);
    if (err !== null) return err;
    return st.trackers.has(v as string) ? null : M.trackerUnknown(p, v as string);
  };
}

/** Ziel einer Ziel-Stufe: Art, dann die zur Art passenden Felder. */
function checkGoal(st: ChallengeState, goal: unknown, path: string): void {
  if (!isObj(goal)) return void st.errors.push(M.type(path, 'ein Objekt'));
  const typePath = ptr(path, 'type');
  if (!has(goal, 'type')) return void st.errors.push(M.missing(typePath));
  if (typeof goal.type !== 'string') return void st.errors.push(M.type(typePath, 'ein Text'));
  if (!GOAL_TYPES.includes(goal.type)) return void st.errors.push(M.notAllowed(typePath, 'meditation, workout oder tracker'));
  const tracker = goal.type === 'tracker';
  noUnknown(st, goal, path, tracker ? ['type', 'trackerId'] : ['type', 'minutes']);
  if (tracker) field(st, goal, 'trackerId', path, true, trackerRef(st));
  else field(st, goal, 'minutes', path, true, (v, p) => checkInt(v, p, 1, 180));
}

/** Inhalt der Stufe; gibt die Impulsliste zurück, wenn es eine Impuls-Stufe ist, sonst undefined. */
function checkContent(st: ChallengeState, stage: Obj, base: string): unknown[] | undefined {
  const path = ptr(base, 'content');
  if (!has(stage, 'content')) return void st.errors.push(M.missing(path));
  const content = stage.content;
  if (!isObj(content)) return void st.errors.push(M.type(path, 'ein Objekt'));
  const typePath = ptr(path, 'type');
  if (!has(content, 'type')) return void st.errors.push(M.missing(typePath));
  if (typeof content.type !== 'string') return void st.errors.push(M.type(typePath, 'ein Text'));
  if (content.type === 'impulses') return checkImpulses(st, content, path);
  if (content.type !== 'goal') return void st.errors.push(M.contentType(typePath));
  noUnknown(st, content, path, ['type', 'goal']);
  if (!has(content, 'goal')) st.errors.push(M.missing(ptr(path, 'goal')));
  else checkGoal(st, content.goal, ptr(path, 'goal'));
  return undefined;
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
  const stages = list(st, item, 'stages', base, 1, MAX_STAGES);
  if (stages === undefined) return;
  const days = stages.map((s, i) => checkStage(st, s, ptr(ptr(base, 'stages'), i)));
  if (days.some((d) => d === undefined)) return;
  const total = (days as number[]).reduce((a, b) => a + b, 0);
  if (total > CHALLENGE_MAX_DAYS) st.errors.push(M.totalDays(base, total, CHALLENGE_MAX_DAYS));
}
