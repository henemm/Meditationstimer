// Fehlertypen und deutsche Meldungen (message = was falsch ist, hint = Ausweg).
// Spec: openspec/specs/integrations/claude-lieferformat.md, Abschnitt 5.

export const ERROR_CODES = [
  'FORMAT_UNKNOWN', 'FIELD_MISSING', 'FIELD_UNKNOWN', 'FIELD_TYPE', 'TEXT_EMPTY',
  'TEXT_TOO_LONG', 'TEXT_FORBIDDEN_CHAR', 'INVALID_SYMBOL', 'OUT_OF_RANGE', 'LIST_SIZE',
  'TOTAL_TOO_LONG', 'INVALID_ID', 'INVALID_DATE', 'VALUE_NOT_ALLOWED', 'KIND_UNKNOWN',
  'CATEGORY_UNKNOWN', 'EXERCISE_UNKNOWN', 'NAME_TAKEN', 'DUPLICATE_ID', 'WITHDRAWAL_TARGET',
] as const;

export type ErrorCode = (typeof ERROR_CODES)[number];
export type DeliveryError = { code: ErrorCode; path: string; message: string; hint: string };
export type ValidationResult = { valid: boolean; errors: DeliveryError[] };

/** Verbotene Zeichen (Spec Abschnitt 4), inklusive einzelner Surrogate; U+000A nur in mehrzeiligen Feldern erlaubt. */
export function isForbidden(cp: number, multiline: boolean): boolean {
  if (cp === 0x0a) return !multiline;
  return cp <= 0x1f || (cp >= 0x7f && cp <= 0x9f) || cp === 0x2028 || cp === 0x2029
    || (cp >= 0x202a && cp <= 0x202e) || (cp >= 0x2066 && cp <= 0x2069) || (cp >= 0xd800 && cp <= 0xdfff);
}

/** Fremdtext für Meldungen: verbotene Zeichen (auch Zeilenumbruch) werden zu U+FFFD, höchstens 40 Code Points. */
function clean(value: string): string {
  const cps = Array.from(value, (c) => c.codePointAt(0) as number);
  const text = (list: number[]): string => list.map((cp) => String.fromCodePoint(isForbidden(cp, false) ? 0xfffd : cp)).join('');
  return cps.length > 40 ? `${text(cps.slice(0, 39))}…` : text(cps);
}

/** Letztes Pfadsegment (JSON Pointer entschlüsselt) als Feldname; `index` = Segment ist ein Listenindex. */
function label(path: string, index = false): string {
  if (path === '') return 'Die Lieferung';
  const parts = path.split('/');
  const last = (parts[parts.length - 1] ?? '').replaceAll('~1', '/').replaceAll('~0', '~');
  return index ? `Eintrag ${clean(last)}` : `Feld „${clean(last)}“`;
}

/** Kürzt und bereinigt Fremdtext für die Anzeige in Meldungen. */
function show(value: string): string {
  return `„${clean(value)}“`;
}

function e(code: ErrorCode, path: string, message: string, hint: string): DeliveryError {
  return { code, path, message, hint };
}

export const M = {
  formatUnknown: (path: string) =>
    e('FORMAT_UNKNOWN', path, 'Das Format ist nicht „hhhaven.delivery/1“.', 'format muss genau „hhhaven.delivery/1“ lauten.'),
  missing: (path: string) =>
    e('FIELD_MISSING', path, `${label(path)} fehlt, ist aber Pflicht.`, `${label(path)} ergänzen.`),
  unknown: (path: string) =>
    e('FIELD_UNKNOWN', path, `${label(path)} ist im Format nicht vorgesehen.`, `${label(path)} entfernen; es sind nur die im Format beschriebenen Felder erlaubt.`),
  type: (path: string, expected: string, index = false) =>
    e('FIELD_TYPE', path, `${label(path, index)} hat den falschen Typ.`, `${label(path, index)} muss ${expected} sein.`),
  textEmpty: (path: string) =>
    e('TEXT_EMPTY', path, `${label(path)} ist leer oder besteht nur aus Leerzeichen.`, `${label(path)} mit echtem Text füllen (mindestens 1 sichtbares Zeichen).`),
  tooLong: (path: string, len: number, max: number) =>
    e('TEXT_TOO_LONG', path, `${label(path)} hat ${len} Zeichen und ist damit länger als ${max}.`, `${label(path)} auf höchstens ${max} Zeichen kürzen.`),
  forbidden: (path: string, cp: number, multiline: boolean) =>
    e('TEXT_FORBIDDEN_CHAR', path, `${label(path)} enthält das unzulässige Zeichen U+${cp.toString(16).toUpperCase().padStart(4, '0')}.`,
      multiline ? 'Steuerzeichen entfernen; nur Zeilenumbruch (U+000A) ist erlaubt.' : 'Steuerzeichen und Zeilenumbrüche entfernen; dieses Feld ist einzeilig.'),
  symbol: (path: string, why: string) =>
    e('INVALID_SYMBOL', path, `${label(path)} ist kein gültiges Symbol: ${why}.`,
      'Ein bis 16 Zeichen, z. B. ein Emoji; keine Leerzeichen, keine Buchstaben A–Z oder Ziffern 0–9.'),
  range: (path: string, value: number, min: number, max: number) =>
    e('OUT_OF_RANGE', path, `${label(path)} ist ${Number.isFinite(value) ? value : 'unendlich'} und liegt ${value < min ? 'unter' : 'über'} dem erlaubten Bereich ${min} bis ${max}.`,
      `${label(path)} muss zwischen ${min} und ${max} liegen.`),
  listSize: (path: string, len: number, min: number, max: number) =>
    e('LIST_SIZE', path, `${label(path)} hat ${len} Einträge; erlaubt sind ${min} bis ${max}.`,
      `Die Liste auf ${min} bis ${max} Einträge bringen${len > max ? '; Überzähliges in eine weitere Lieferung auslagern' : ''}.`),
  total: (path: string, total: number, max: number) =>
    e('TOTAL_TOO_LONG', path, `Die Gesamtdauer beträgt ${total} s und liegt über ${max} s.`,
      'Runden, Zeiten oder Schritte verringern, bis die Gesamtdauer höchstens ' + `${max} s (${max / 3600} h) beträgt.`),
  invalidId: (path: string, form: string) =>
    e('INVALID_ID', path, `${label(path)} hat nicht das vorgeschriebene Kennungs-Muster.`, form),
  invalidDate: (path: string) =>
    e('INVALID_DATE', path, `${label(path)} ist kein gültiger UTC-Zeitpunkt.`,
      'Format JJJJ-MM-TTThh:mm:ssZ (optional mit 1–3 Nachkommastellen), echtes Kalenderdatum, z. B. 2026-11-13T10:15:00Z.'),
  notAllowed: (path: string, allowed: string) =>
    e('VALUE_NOT_ALLOWED', path, `${label(path)} hat einen nicht erlaubten Wert.`, `Erlaubt ist nur ${allowed}.`),
  kindUnknown: (path: string, kind: string) =>
    e('KIND_UNKNOWN', path, `Die Art ${show(kind)} ist unbekannt.`, 'kind muss „exercise“, „program“, „breath“ oder „withdrawal“ sein.'),
  categoryUnknown: (path: string, value: string) =>
    e('CATEGORY_UNKNOWN', path, `Die Kategorie ${show(value)} ist unbekannt.`,
      'Erlaubt: strength, stretching, core, cardio, legs, upperBody, fullBody, warmup, cooldown.'),
  exerciseUnknown: (path: string, id: string) =>
    e('EXERCISE_UNKNOWN', path, `Die Übung ${show(id)} ist weder eingebaut, noch bekannt, noch Teil dieser Lieferung.`,
      'Eine vorhandene Übungskennung verwenden oder die Übung (kind „exercise“) in derselben Lieferung mitliefern; Programme und Atemübungen sind keine Übungen.'),
  nameTaken: (path: string, name: string) =>
    e('NAME_TAKEN', path, `Es gibt schon eine Übung namens ${show(name)} (Groß-/Kleinschreibung und Leerzeichen zählen nicht).`,
      'Einen anderen Namen wählen oder die vorhandene Übung verwenden.'),
  duplicateId: (path: string, id: string) =>
    e('DUPLICATE_ID', path, `Die Kennung ${show(id)} kommt in dieser Lieferung schon vor.`,
      'Jede itemId nur einmal je Lieferung verwenden; Änderung und Rücknahme desselben Bausteins gehören in getrennte Lieferungen.'),
  withdrawalTarget: (path: string) =>
    e('WITHDRAWAL_TARGET', path, 'Eine Rücknahme braucht genau eines von itemId und packageId; hier sind beide oder keines angegeben.',
      'Entweder itemId (ein Baustein) oder packageId (ein Paket) angeben, nicht beides.'),
};
