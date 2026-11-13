import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateDelivery } from '../src/index.ts';
import { key, loadExamples } from './helpers.ts';

for (const dir of ['valid', 'invalid'] as const) {
  for (const ex of loadExamples(dir)) {
    /** Verhalten: Der Prüfer beurteilt die Beispieldatei genau wie erwartet. */
    test(`${dir}/${ex.file}`, () => {
      const result = validateDelivery(ex.delivery, ex.context);

      assert.equal(result.valid, ex.expected.valid, 'valid');
      assert.equal(result.valid, result.errors.length === 0, 'valid === (errors.length === 0)');

      const expected = (ex.expected.errors ?? []).map(key).sort();
      const actual = result.errors.map(key).sort();
      assert.deepEqual(actual, expected, 'Menge der (code, path)');

      for (const e of result.errors) {
        assert.ok(typeof e.message === 'string' && e.message.trim().length > 0, `message leer bei ${key(e)}`);
        assert.ok(typeof e.hint === 'string' && e.hint.trim().length > 0, `hint leer bei ${key(e)}`);
      }
    });
  }
}
