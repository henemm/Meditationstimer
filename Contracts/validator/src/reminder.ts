// Prüfregeln für Erinnerungen (Spec: openspec/specs/integrations/claude-erinnerung.md, Abschnitt 2).
import type { DeliveryError } from './messages.ts';
import { M } from './messages.ts';
import { checkId, checkInt, checkText, field, has, isObj, isScopedId, list, noUnknown, ptr } from './rules.ts';
import type { Check, Obj, Sink } from './rules.ts';

export const REMINDER_MAX = 6;
const WEEKDAYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
const TARGET_TYPES = ['meditation', 'workout', 'breath', 'noalc'];
const TARGET_ID_FORM = 'Muster: „builtin.“, „own.“ oder „claude.“ gefolgt von 2–63 Zeichen aus a–z, 0–9 und „-“ (nicht am Anfang).';
const isTargetId = (s: string): boolean => isScopedId(s, ['builtin', 'own', 'claude']);

/** Kennungen, auf die Erinnerungen zeigen dürfen: bekannte (Prüfkontext) und solche aus der Lieferung. */
export type TargetIds = { programs: Set<string>; breaths: Set<string> };
export type ReminderState = Sink & { targets: TargetIds };

/** Programme und Atemübungen der Lieferung (auch fehlerhafte) mit musterkonformer Kennung. */
export function collectTargetIds(items: unknown[], into: TargetIds): void {
  for (const it of items) {
    if (!isObj(it) || typeof it.itemId !== 'string' || !isScopedId(it.itemId, ['claude'])) continue;
    if (it.kind === 'program') into.programs.add(it.itemId);
    if (it.kind === 'breath') into.breaths.add(it.itemId);
  }
}

const isDigit = (c: string | undefined): boolean => c !== undefined && c >= '0' && c <= '9';

/** Uhrzeit hh:mm, genau fünf Zeichen, 00:00 bis 23:59. */
function checkTime(v: unknown, path: string): DeliveryError | null {
  if (typeof v !== 'string') return M.type(path, 'ein Text');
  const c = Array.from(v);
  const digits = [0, 1, 3, 4].every((i) => isDigit(c[i]));
  if (c.length !== 5 || c[2] !== ':' || !digits) return M.invalidTime(path);
  const hour = Number(c[0]! + c[1]!);
  const minute = Number(c[3]! + c[4]!);
  return hour <= 23 && minute <= 59 ? null : M.invalidTime(path);
}

/** Wochentage: Typ der Liste, Größe 1–7, je Eintrag Typ, erlaubter Wert, dann Dublette. */
function checkWeekdays(st: Sink, item: Obj, base: string): void {
  const days = list(st, item, 'weekdays', base, 1, 7);
  if (days === undefined) return;
  const seen = new Set<string>();
  days.forEach((d, i) => {
    const path = ptr(ptr(base, 'weekdays'), i);
    if (typeof d !== 'string') return void st.errors.push(M.type(path, 'ein Text', true));
    if (!WEEKDAYS.includes(d)) return void st.errors.push(M.notAllowed(path, 'monday, tuesday, wednesday, thursday, friday, saturday oder sunday'));
    if (seen.has(d)) st.errors.push(M.duplicateValue(path, d));
    seen.add(d);
  });
}

/** Bezugsfeld (programId/breathId): Kennungsmuster, dann bekannt? */
function targetRef(known: (id: string) => boolean, what: string): Check {
  return (v, p) => {
    const err = checkId(v, p, isTargetId, TARGET_ID_FORM);
    if (err !== null) return err;
    return known(v as string) ? null : M.targetUnknown(p, v as string, what);
  };
}

function checkTarget(st: ReminderState, item: Obj, base: string, known: { programs: Set<string>; breaths: Set<string> }): void {
  const path = ptr(base, 'target');
  if (!has(item, 'target')) return void st.errors.push(M.missing(path));
  const t = item.target;
  if (!isObj(t)) return void st.errors.push(M.type(path, 'ein Objekt'));
  const typePath = ptr(path, 'type');
  if (!has(t, 'type')) return void st.errors.push(M.missing(typePath));
  if (typeof t.type !== 'string') return void st.errors.push(M.type(typePath, 'ein Text'));
  if (!TARGET_TYPES.includes(t.type)) return void st.errors.push(M.notAllowed(typePath, 'meditation, workout, breath oder noalc'));
  const extra = t.type === 'workout' ? 'programId' : t.type === 'breath' ? 'breathId' : undefined;
  noUnknown(st, t, path, extra === undefined ? ['type'] : ['type', extra]);
  if (t.type === 'workout') field(st, t, 'programId', path, false, targetRef((id) => known.programs.has(id), 'Programm'));
  if (t.type === 'breath') field(st, t, 'breathId', path, true, targetRef((id) => known.breaths.has(id), 'Atemübung'));
}

/** Prüft eine Erinnerung (ohne itemId/revision, die prüft der Aufrufer). */
export function checkReminder(st: ReminderState, item: Obj, base: string): void {
  noUnknown(st, item, base, ['kind', 'itemId', 'revision', 'title', 'message', 'time', 'weekdays', 'lookbackHours', 'target']);
  field(st, item, 'title', base, true, (v, p) => checkText(v, p, 40, false));
  field(st, item, 'message', base, true, (v, p) => checkText(v, p, 200, true));
  field(st, item, 'time', base, true, checkTime);
  checkWeekdays(st, item, base);
  field(st, item, 'lookbackHours', base, true, (v, p) => checkInt(v, p, 1, 24));
  checkTarget(st, item, base, st.targets);
}
