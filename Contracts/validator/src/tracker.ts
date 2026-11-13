// Prüfregeln für Gewohnheiten/Tracker (Spec: openspec/specs/integrations/claude-gewohnheit-stufenplan.md, Abschnitt 1).
import { M } from './messages.ts';
import { checkInt, checkSymbol, checkText, field, has, isObj, isScopedId, list, noUnknown, normalizeName, ptr } from './rules.ts';
import type { Obj, Sink } from './rules.ts';

const TYPES = ['good', 'saboteur'];
const MODES: Record<string, string[]> = { good: ['counter', 'yesNo', 'levels'], saboteur: ['awareness', 'avoidance', 'levels'] };
const ALL_MODES = ['counter', 'yesNo', 'levels', 'awareness', 'avoidance'];
const EFFECTS = ['success', 'needsGrace', 'breaksStreak'];
const ALLOWED = ['kind', 'itemId', 'revision', 'name', 'symbol', 'type', 'mode', 'dailyGoal', 'levels', 'joker', 'dayStartHour'];

/** Tracker der Lieferung (auch fehlerhafte) mit musterkonformer Kennung. */
export function collectTrackerIds(items: unknown[], into: Set<string>): void {
  for (const it of items) {
    if (isObj(it) && it.kind === 'tracker' && typeof it.itemId === 'string' && isScopedId(it.itemId, ['claude'])) into.add(it.itemId);
  }
}

/** Ein Text-Feld mit festem Wertevorrat; gibt den Wert zurück, wenn gültig. */
function enumField(st: Sink, item: Obj, key: string, base: string, allowed: string[], text: string): string | undefined {
  const ok = field(st, item, key, base, true, (v, p) =>
    typeof v !== 'string' ? M.type(p, 'ein Text') : allowed.includes(v) ? null : M.notAllowed(p, text));
  return ok ? (item[key] as string) : undefined;
}

function checkLevel(st: Sink, level: unknown, path: string): void {
  if (!isObj(level)) return void st.errors.push(M.type(path, 'ein Objekt', true));
  noUnknown(st, level, path, ['name', 'icon', 'effect']);
  field(st, level, 'name', path, true, (v, p) => checkText(v, p, 20, false));
  field(st, level, 'icon', path, true, checkSymbol);
  field(st, level, 'effect', path, true, (v, p) =>
    typeof v !== 'string' ? M.type(p, 'ein Text') : EFFECTS.includes(v) ? null : M.notAllowed(p, 'success, needsGrace oder breaksStreak'));
}

/** Stufennamen normalisiert eindeutig (Fehler an der späteren Stufe). */
function checkLevelNames(st: Sink, levels: unknown[], base: string): void {
  const seen = new Set<string>();
  levels.forEach((l, i) => {
    if (!isObj(l) || checkText(l.name, '', 20, false) !== null) return;
    const name = normalizeName(l.name as string);
    if (seen.has(name)) st.errors.push(M.duplicateValue(ptr(ptr(base, i), 'name'), l.name as string));
    seen.add(name);
  });
}

function checkLevels(st: Sink, item: Obj, base: string): void {
  const levels = list(st, item, 'levels', base, 2, 5);
  if (levels === undefined) return;
  const path = ptr(base, 'levels');
  levels.forEach((l, i) => checkLevel(st, l, ptr(path, i)));
  checkLevelNames(st, levels, path);
  const effects = levels.map((l) => (isObj(l) ? l.effect : undefined));
  const valid = effects.every((e) => typeof e === 'string' && EFFECTS.includes(e));
  if (valid && !effects.includes('success')) st.errors.push(M.levelsNoSuccess(path));
}

function checkJoker(st: Sink, joker: unknown, path: string): void {
  if (!isObj(joker)) return void st.errors.push(M.type(path, 'ein Objekt'));
  noUnknown(st, joker, path, ['earnEveryDays', 'maxOnHand']);
  field(st, joker, 'earnEveryDays', path, true, (v, p) => checkInt(v, p, 1, 30));
  field(st, joker, 'maxOnHand', path, true, (v, p) => checkInt(v, p, 1, 10));
}

/** Modusabhängige Felder: nur das, was zum Modus passt, ist erlaubt. */
function checkModeFields(st: Sink, item: Obj, base: string, mode: string): void {
  const fieldsFor: string[] = mode === 'counter' ? ['dailyGoal'] : mode === 'levels' ? ['levels', 'joker', 'dayStartHour'] : [];
  for (const key of ['dailyGoal', 'levels', 'joker', 'dayStartHour']) {
    if (!fieldsFor.includes(key) && has(item, key)) st.errors.push(M.unknown(ptr(base, key)));
  }
  if (mode === 'counter') field(st, item, 'dailyGoal', base, false, (v, p) => checkInt(v, p, 1, 100));
  if (mode !== 'levels') return;
  checkLevels(st, item, base);
  if (has(item, 'joker')) checkJoker(st, item.joker, ptr(base, 'joker'));
  field(st, item, 'dayStartHour', base, false, (v, p) => checkInt(v, p, 0, 23));
}

/** Prüft einen Tracker (ohne itemId/revision, die prüft der Aufrufer). */
export function checkTracker(st: Sink, item: Obj, base: string): void {
  noUnknown(st, item, base, ALLOWED);
  field(st, item, 'name', base, true, (v, p) => checkText(v, p, 40, false));
  field(st, item, 'symbol', base, true, checkSymbol);
  const type = enumField(st, item, 'type', base, TYPES, '„good“ oder „saboteur“');
  const allowed = type === undefined ? ALL_MODES : (MODES[type] as string[]);
  const text = type === undefined ? 'counter, yesNo, levels, awareness oder avoidance' : `${allowed.join(', ')}`
    + ` (passend zum Typ „${type}“)`;
  const mode = enumField(st, item, 'mode', base, allowed, text);
  if (mode !== undefined) checkModeFields(st, item, base, mode);
}
