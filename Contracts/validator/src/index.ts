// Referenz-Prüfer für Lieferungen (Spec: openspec/specs/integrations/claude-lieferformat.md).
// Deterministisch, ohne Laufzeit-Abhängigkeiten; die Eingabe wird nie verändert.
import { loadCatalog } from './catalog.ts';
import type { DeliveryError, ValidationResult } from './messages.ts';
import { M } from './messages.ts';
import { checkReminder, collectTargetIds, REMINDER_MAX } from './reminder.ts';
import type { TargetIds } from './reminder.ts';
import {
  checkDate, checkId, checkInt, checkSymbol, checkText, field, has, isDeliveryId, isObj, isScopedId, list, noUnknown, normalizeName, ptr,
} from './rules.ts';
import type { Check, Obj } from './rules.ts';

export { ERROR_CODES } from './messages.ts';
export type { DeliveryError, ErrorCode, ValidationResult } from './messages.ts';

export type KnownExercise = { id: string; name: string };
export type ValidationContext = { knownExercises?: KnownExercise[]; knownPrograms?: string[]; knownBreaths?: string[] };

const FORMAT = 'hhhaven.delivery/1';
const CATEGORIES = ['strength', 'stretching', 'core', 'cardio', 'legs', 'upperBody', 'fullBody', 'warmup', 'cooldown'];
const ITEM_ID_FORM = 'Muster: „claude.“ gefolgt von 2–63 Zeichen aus a–z, 0–9 und „-“ (nicht am Anfang), z. B. claude.ruecken-a.';
const EXERCISE_ID_FORM = 'Muster: „builtin.“, „own.“ oder „claude.“ gefolgt von 2–63 Zeichen aus a–z, 0–9 und „-“ (nicht am Anfang).';
const DELIVERY_ID_FORM = 'Muster: 8–64 Zeichen aus A–Z, a–z, 0–9 und „-“, nicht mit „-“ beginnend (eine UUID passt).';

type State = {
  errors: DeliveryError[];
  builtinIds: Set<string>;
  builtinNames: Set<string>;
  context: { id: string; name: string }[];
  deliveryExerciseIds: Set<string>;
  seenItemIds: Set<string>;
  seenNames: Set<string>;
  targets: TargetIds;
};

const isItemId = (s: string): boolean => isScopedId(s, ['claude']);
const itemIdCheck: Check = (v, p) => checkId(v, p, isItemId, ITEM_ID_FORM);
const single = (max: number): Check => (v, p) => checkText(v, p, max, false);
const multi = (max: number): Check => (v, p) => checkText(v, p, max, true);
const int = (min: number, max: number): Check => (v, p) => checkInt(v, p, min, max);

function checkPackage(st: State, pkg: unknown, path: string): void {
  if (!isObj(pkg)) {
    st.errors.push(M.type(path, 'ein Objekt'));
    return;
  }
  noUnknown(st, pkg, path, ['packageId', 'name']);
  field(st, pkg, 'packageId', path, true, itemIdCheck);
  field(st, pkg, 'name', path, true, single(40));
}

function checkEnvelope(st: State, d: Obj): void {
  noUnknown(st, d, '', ['format', 'deliveryId', 'source', 'createdAt', 'why', 'package', 'items']);
  field(st, d, 'format', '', true, (v, p) => (typeof v !== 'string' ? M.type(p, 'ein Text') : v === FORMAT ? null : M.formatUnknown(p)));
  field(st, d, 'deliveryId', '', true, (v, p) => checkId(v, p, isDeliveryId, DELIVERY_ID_FORM));
  field(st, d, 'source', '', true, (v, p) => (typeof v !== 'string' ? M.type(p, 'ein Text') : v === 'claude' ? null : M.notAllowed(p, '„claude“')));
  field(st, d, 'createdAt', '', true, checkDate);
  field(st, d, 'why', '', true, single(300));
  if (has(d, 'package')) checkPackage(st, d.package, '/package');
}

/** Übungen der Lieferung (auch fehlerhafte) zählen für Bezüge; nur Kennungen im Muster. */
function collectExerciseIds(st: State, items: unknown[]): void {
  for (const it of items) {
    if (isObj(it) && it.kind === 'exercise' && typeof it.itemId === 'string' && isItemId(it.itemId)) {
      st.deliveryExerciseIds.add(it.itemId);
    }
  }
}

function checkNameTaken(st: State, item: Obj, path: string): void {
  const name = normalizeName(item.name as string);
  const id = item.itemId;
  const taken = st.builtinNames.has(name) || st.seenNames.has(name)
    || st.context.some((c) => c.id !== id && normalizeName(c.name) === name);
  st.seenNames.add(name);
  if (taken) st.errors.push(M.nameTaken(path, item.name as string));
}

function checkExercise(st: State, item: Obj, base: string): void {
  noUnknown(st, item, base, ['kind', 'itemId', 'revision', 'name', 'nameEn', 'category', 'effect', 'instructions', 'notes']);
  const nameOk = field(st, item, 'name', base, true, single(40));
  field(st, item, 'nameEn', base, false, single(40));
  field(st, item, 'category', base, true, (v, p) =>
    typeof v !== 'string' ? M.type(p, 'ein Text') : CATEGORIES.includes(v) ? null : M.categoryUnknown(p, v));
  field(st, item, 'effect', base, true, multi(600));
  field(st, item, 'instructions', base, true, multi(1500));
  field(st, item, 'notes', base, false, multi(600));
  if (nameOk) checkNameTaken(st, item, ptr(base, 'name'));
}

function exerciseRef(st: State): Check {
  return (v, p) => {
    const err = checkId(v, p, (s) => isScopedId(s, ['builtin', 'own', 'claude']), EXERCISE_ID_FORM);
    if (err !== null) return err;
    const id = v as string;
    const known = id.startsWith('builtin.')
      ? st.builtinIds.has(id)
      : st.deliveryExerciseIds.has(id) || st.context.some((c) => c.id === id);
    return known ? null : M.exerciseUnknown(p, id);
  };
}

/** Prüft einen Schritt; gibt Arbeits- plus Pausenzeit zurück, wenn beide gültig sind, sonst undefined. */
function checkStep(st: State, step: unknown, path: string): number | undefined {
  if (!isObj(step)) {
    st.errors.push(M.type(path, 'ein Objekt', true));
    return undefined;
  }
  noUnknown(st, step, path, ['exerciseId', 'workSeconds', 'restSeconds', 'hint']);
  field(st, step, 'exerciseId', path, true, exerciseRef(st));
  const work = field(st, step, 'workSeconds', path, true, int(1, 600));
  const rest = field(st, step, 'restSeconds', path, true, int(0, 600));
  field(st, step, 'hint', path, false, single(80));
  return work && rest ? (step.workSeconds as number) + (step.restSeconds as number) : undefined;
}

function checkProgram(st: State, item: Obj, base: string): void {
  noUnknown(st, item, base, ['kind', 'itemId', 'revision', 'name', 'symbol', 'description', 'rounds', 'steps']);
  field(st, item, 'name', base, true, single(40));
  field(st, item, 'symbol', base, true, checkSymbol);
  field(st, item, 'description', base, false, multi(500));
  const roundsOk = field(st, item, 'rounds', base, true, int(1, 99));
  const steps = list(st, item, 'steps', base, 1, 40);
  if (steps === undefined) return;
  const sums = steps.map((s, i) => checkStep(st, s, ptr(ptr(base, 'steps'), i)));
  const sizeOk = steps.length >= 1 && steps.length <= 40;
  if (!roundsOk || !sizeOk || sums.some((s) => s === undefined)) return;
  const total = (item.rounds as number) * (sums as number[]).reduce((a, b) => a + b, 0);
  if (total > 14400) st.errors.push(M.total(base, total, 14400));
}

const BREATH_TIMES: [string, number, number][] = [
  ['inhaleSeconds', 1, 60], ['holdInSeconds', 0, 60], ['exhaleSeconds', 1, 60], ['holdOutSeconds', 0, 60],
];

function checkBreath(st: State, item: Obj, base: string): void {
  noUnknown(st, item, base, ['kind', 'itemId', 'revision', 'name', 'symbol', 'description', 'rounds', ...BREATH_TIMES.map((t) => t[0])]);
  field(st, item, 'name', base, true, single(40));
  field(st, item, 'symbol', base, true, checkSymbol);
  field(st, item, 'description', base, false, multi(500));
  const timesOk = BREATH_TIMES.map(([key, min, max]) => field(st, item, key, base, true, int(min, max)));
  const roundsOk = field(st, item, 'rounds', base, true, int(1, 99));
  if (!roundsOk || timesOk.includes(false)) return;
  const cycle = BREATH_TIMES.reduce((sum, [key]) => sum + (item[key] as number), 0);
  const total = (item.rounds as number) * cycle;
  if (total > 3600) st.errors.push(M.total(base, total, 3600));
}

function checkWithdrawal(st: State, item: Obj, base: string): void {
  noUnknown(st, item, base, ['kind', 'itemId', 'packageId']);
  const hasItem = has(item, 'itemId');
  const hasPackage = has(item, 'packageId');
  if (hasItem === hasPackage) st.errors.push(M.withdrawalTarget(base));
  if (hasPackage) field(st, item, 'packageId', base, false, itemIdCheck);
}

/** itemId und (außer bei Rücknahmen) revision; Dubletten nur bei gültigem Muster. */
function checkIdentity(st: State, item: Obj, base: string, kind: string): void {
  const withdrawal = kind === 'withdrawal';
  if (withdrawal && !has(item, 'itemId')) return;
  const idOk = field(st, item, 'itemId', base, true, itemIdCheck);
  if (idOk) {
    const id = item.itemId as string;
    if (st.seenItemIds.has(id)) st.errors.push(M.duplicateId(ptr(base, 'itemId'), id));
    st.seenItemIds.add(id);
  }
}

function checkItem(st: State, item: unknown, base: string): void {
  if (!isObj(item)) {
    st.errors.push(M.type(base, 'ein Objekt', true));
    return;
  }
  const kindPath = ptr(base, 'kind');
  if (!has(item, 'kind')) return void st.errors.push(M.missing(kindPath));
  const kind = item.kind;
  if (typeof kind !== 'string') return void st.errors.push(M.type(kindPath, 'ein Text'));
  if (!['exercise', 'program', 'breath', 'reminder', 'withdrawal'].includes(kind)) return void st.errors.push(M.kindUnknown(kindPath, kind));
  checkIdentity(st, item, base, kind);
  if (kind !== 'withdrawal') field(st, item, 'revision', base, true, int(1, 1_000_000));
  if (kind === 'exercise') checkExercise(st, item, base);
  else if (kind === 'program') checkProgram(st, item, base);
  else if (kind === 'breath') checkBreath(st, item, base);
  else if (kind === 'reminder') checkReminder(st, item, base);
  else checkWithdrawal(st, item, base);
}

/** Kennungsliste aus dem Prüfkontext; alles, was keine Liste von Texten ist, zählt als fehlend. */
function idSet(v: unknown): Set<string> {
  return new Set(Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : []);
}

function newState(context: ValidationContext | undefined): State {
  const catalog = loadCatalog();
  const known = Array.isArray(context?.knownExercises) ? context.knownExercises : [];
  return {
    errors: [],
    builtinIds: new Set(catalog.map((c) => c.id)),
    builtinNames: new Set(catalog.map((c) => normalizeName(c.name))),
    context: known.filter((k) => typeof k?.id === 'string' && typeof k?.name === 'string'),
    deliveryExerciseIds: new Set(),
    seenItemIds: new Set(),
    seenNames: new Set(),
    targets: { programs: idSet(context?.knownPrograms), breaths: idSet(context?.knownBreaths) },
  };
}

export function validateDelivery(input: unknown, context?: ValidationContext): ValidationResult {
  const st = newState(context);
  if (!isObj(input)) {
    st.errors.push(M.type('', 'ein Objekt'));
    return { valid: false, errors: st.errors };
  }
  checkEnvelope(st, input);
  const items = list(st, input, 'items', '', 1, 20);
  if (items !== undefined) {
    collectExerciseIds(st, items);
    collectTargetIds(items, st.targets);
    const reminders = items.filter((it) => isObj(it) && it.kind === 'reminder').length;
    if (reminders > REMINDER_MAX) st.errors.push(M.reminderLimit('/items', reminders, REMINDER_MAX));
    items.forEach((item, i) => checkItem(st, item, ptr('/items', i)));
  }
  return { valid: st.errors.length === 0, errors: st.errors };
}
