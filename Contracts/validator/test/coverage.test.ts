import { test } from 'node:test';
import assert from 'node:assert/strict';
import { ERROR_CODES } from '../src/index.ts';
import { loadExamples } from './helpers.ts';

const SPEC_CODES = [
  'FORMAT_UNKNOWN', 'FIELD_MISSING', 'FIELD_UNKNOWN', 'FIELD_TYPE', 'TEXT_EMPTY', 'TEXT_TOO_LONG',
  'TEXT_FORBIDDEN_CHAR', 'INVALID_SYMBOL', 'OUT_OF_RANGE', 'LIST_SIZE', 'TOTAL_TOO_LONG', 'INVALID_ID',
  'INVALID_DATE', 'VALUE_NOT_ALLOWED', 'KIND_UNKNOWN', 'CATEGORY_UNKNOWN', 'EXERCISE_UNKNOWN',
  'NAME_TAKEN', 'DUPLICATE_ID', 'WITHDRAWAL_TARGET',
  'INVALID_TIME', 'DUPLICATE_VALUE', 'TARGET_UNKNOWN', 'REMINDER_LIMIT',
  'START_IN_PAST', 'IMPULSE_COUNT',
];

/** Verhalten: ERROR_CODES enthält genau die 26 Codes aus der Spec. */
test('ERROR_CODES == Spec-Liste', () => {
  assert.equal(SPEC_CODES.length, 24);
  assert.deepEqual([...ERROR_CODES].sort(), [...SPEC_CODES].sort());
  assert.equal(new Set(ERROR_CODES).size, ERROR_CODES.length, 'keine Doppelten');
});

/** Verhalten: Leere Ordner ergeben kein falsches Grün. */
test('Beispielsatz ist nicht leer', () => {
  assert.ok(loadExamples('valid').length > 0, 'keine gültigen Beispiele');
  assert.ok(loadExamples('invalid').length > 0, 'keine ungültigen Beispiele');
});

/** Verhalten: Jede ungültige Datei erwartet genau einen Fehler. */
test('jede ungültige Datei erwartet genau einen Fehler', () => {
  const bad = loadExamples('invalid').filter(
    (ex) => ex.expected.valid !== false || ex.expected.errors?.length !== 1,
  );
  assert.deepEqual(bad.map((b) => b.file), []);
});

/** Verhalten: Gültige Dateien erwarten valid true. */
test('gültige Dateien erwarten valid: true', () => {
  const bad = loadExamples('valid').filter((ex) => ex.expected.valid !== true);
  assert.deepEqual(bad.map((b) => b.file), []);
});

/** Verhalten: Der Beispielsatz deckt jeden Fehlercode mindestens einmal ab. */
test('jeder Code ist durch ein Beispiel abgedeckt', () => {
  const covered = new Set(loadExamples('invalid').flatMap((ex) => (ex.expected.errors ?? []).map((e) => e.code)));
  const missing = [...ERROR_CODES].filter((c) => !covered.has(c));
  assert.deepEqual(missing, []);
});
