import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { Ajv2020 } from 'ajv/dist/2020.js';
import { SCHEMA_PATH, loadExamples } from './helpers.ts';

const schema = JSON.parse(readFileSync(SCHEMA_PATH, 'utf8'));
const ajv = new Ajv2020({ allErrors: true, strict: false });
const validate = ajv.compile(schema);

/** Verhalten: Das Schema lässt sich kompilieren. */
test('Schema kompiliert', () => {
  assert.equal(typeof validate, 'function');
});

for (const ex of loadExamples('valid')) {
  /** Verhalten: Jedes gültige Beispiel besteht auch das Schema. */
  test(`valid/${ex.file} besteht das Schema`, () => {
    assert.equal(validate(ex.delivery), true, JSON.stringify(validate.errors));
  });
}

for (const ex of loadExamples('invalid')) {
  const rejects = ex.expected.schemaRejects;
  /** Verhalten: schemaRejects sagt genau, ob das Schema die Lieferung ablehnt. */
  test(`invalid/${ex.file}: Schema ${rejects ? 'lehnt ab' : 'besteht'}`, () => {
    assert.equal(typeof rejects, 'boolean', 'schemaRejects muss true oder false sein');
    assert.equal(validate(ex.delivery), !rejects);
  });
}
