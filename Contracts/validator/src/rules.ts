// Primitive Prüfregeln (Text, Zahl, Kennung, Symbol, Datum). Längen in Code Points.
import type { DeliveryError } from './messages.ts';
import { M } from './messages.ts';

export type Obj = Record<string, unknown>;

export function isObj(v: unknown): v is Obj {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

export function has(o: Obj, key: string): boolean {
  return Object.hasOwn(o, key);
}

export function ptr(base: string, key: string | number): string {
  return `${base}/${String(key).replaceAll('~', '~0').replaceAll('/', '~1')}`;
}

function isForbidden(cp: number, multiline: boolean): boolean {
  if (cp === 0x0a) return !multiline;
  return cp <= 0x1f || (cp >= 0x7f && cp <= 0x9f) || cp === 0x2028 || cp === 0x2029
    || (cp >= 0x202a && cp <= 0x202e) || (cp >= 0x2066 && cp <= 0x2069);
}

const isBlankChar = (cp: number): boolean => cp === 0x20 || cp === 0xa0 || cp === 0x0a;

/** Textfeld: Typ, dann verbotene Zeichen, dann leer, dann zu lang. */
export function checkText(v: unknown, path: string, max: number, multiline: boolean): DeliveryError | null {
  if (typeof v !== 'string') return M.type(path, 'ein Text');
  const cps = Array.from(v, (c) => c.codePointAt(0) as number);
  const bad = cps.find((cp) => isForbidden(cp, multiline));
  if (bad !== undefined) return M.forbidden(path, bad, multiline);
  if (cps.every(isBlankChar)) return M.textEmpty(path);
  if (cps.length > max) return M.tooLong(path, cps.length, max);
  return null;
}

export function checkInt(v: unknown, path: string, min: number, max: number): DeliveryError | null {
  if (typeof v !== 'number' || !Number.isInteger(v)) return M.type(path, 'eine ganze Zahl');
  return v < min || v > max ? M.range(path, v, min, max) : null;
}

/** Symbol: 1–16 Code Points, keine verbotenen Zeichen, keine Leerzeichen, keine ASCII-Buchstaben/-Ziffern. */
export function checkSymbol(v: unknown, path: string): DeliveryError | null {
  if (typeof v !== 'string') return M.type(path, 'ein Text');
  const cps = Array.from(v, (c) => c.codePointAt(0) as number);
  if (cps.length < 1 || cps.length > 16) return M.symbol(path, `${cps.length} Zeichen statt 1 bis 16`);
  for (const cp of cps) {
    if (isForbidden(cp, false)) return M.symbol(path, 'enthält ein unzulässiges Zeichen');
    if (isBlankChar(cp)) return M.symbol(path, 'enthält ein Leerzeichen');
    const ascii = (cp >= 0x30 && cp <= 0x39) || (cp >= 0x41 && cp <= 0x5a) || (cp >= 0x61 && cp <= 0x7a);
    if (ascii) return M.symbol(path, 'enthält einen ASCII-Buchstaben oder eine Ziffer');
  }
  return null;
}

const isLower = (c: string): boolean => (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9');

/** Kennung: Präfix, dann [a-z0-9] gefolgt von 1–62 Zeichen aus [a-z0-9-]. */
export function isScopedId(s: string, prefixes: readonly string[]): boolean {
  const prefix = prefixes.find((p) => s.startsWith(`${p}.`));
  if (prefix === undefined) return false;
  const rest = s.slice(prefix.length + 1);
  if (rest.length < 2 || rest.length > 63 || !isLower(rest[0] as string)) return false;
  return [...rest].every((c) => isLower(c) || c === '-');
}

/** Lieferkennung: [A-Za-z0-9] gefolgt von 7–63 Zeichen aus [A-Za-z0-9-]. */
export function isDeliveryId(s: string): boolean {
  if (s.length < 8 || s.length > 64) return false;
  const alnum = (c: string): boolean => isLower(c) || (c >= 'A' && c <= 'Z');
  return alnum(s[0] as string) && [...s].every((c) => alnum(c) || c === '-');
}

export function checkId(v: unknown, path: string, ok: (s: string) => boolean, form: string): DeliveryError | null {
  if (typeof v !== 'string') return M.type(path, 'ein Text');
  return ok(v) ? null : M.invalidId(path, form);
}

const DATE_SHAPE = /^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})(\.[0-9]{1,3})?Z$/;

function daysInMonth(year: number, month: number): number {
  if (month === 2) return year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0) ? 29 : 28;
  return [4, 6, 9, 11].includes(month) ? 30 : 31;
}

export function checkDate(v: unknown, path: string): DeliveryError | null {
  if (typeof v !== 'string') return M.type(path, 'ein Text');
  const m = DATE_SHAPE.exec(v);
  if (m === null) return M.invalidDate(path);
  const [year, month, day, hour, minute, second] = m.slice(1, 7).map(Number) as [number, number, number, number, number, number];
  const ok = month >= 1 && month <= 12 && day >= 1 && day <= daysInMonth(year, month)
    && hour <= 23 && minute <= 59 && second <= 59;
  return ok ? null : M.invalidDate(path);
}

/** Namen vergleichen: U+0020/U+00A0 am Rand weg, innen zu einem U+0020, dann Kleinschreibung. */
export function normalizeName(s: string): string {
  const words: string[] = [];
  let cur = '';
  for (const c of s) {
    if (c === ' ' || c === ' ') {
      if (cur !== '') words.push(cur);
      cur = '';
    } else cur += c;
  }
  if (cur !== '') words.push(cur);
  return words.join(' ').toLowerCase();
}
