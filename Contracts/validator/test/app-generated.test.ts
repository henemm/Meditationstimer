import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { Ajv2020 } from 'ajv/dist/2020.js';
import { CONTRACTS_DIR } from './helpers.ts';

// #57 Schnitt 3: Goldendateien der App (Contracts/transcript/app-generated/) gegen das Schema der Abschrift Fassung 1.
// Ajv-Optionen wie im Dienst (server/src/transcripts.ts), damit die Dateien so geprüft werden wie eine echte Abschrift.

const SCHEMA_PATH = join(CONTRACTS_DIR, 'transcript', 'transcript-v1.schema.json');
const GOLDEN_DIR = join(CONTRACTS_DIR, 'transcript', 'app-generated');
const REQUIRED = ['empty.json', 'full.json', 'limits.json'];

const ajv = new Ajv2020({ allErrors: false, strict: true, strictRequired: false });
const validate = ajv.compile(JSON.parse(readFileSync(SCHEMA_PATH, 'utf8')));

// Fehlender Ordner darf das Laden des Moduls nicht abbrechen; die Mindestzahl-Prüfung scheitert dann.
const files: string[] = existsSync(GOLDEN_DIR)
  ? readdirSync(GOLDEN_DIR).filter((f) => f.endsWith('.json')).sort()
  : [];

type Obj = Record<string, any>;
const read = (f: string): Obj => JSON.parse(readFileSync(join(GOLDEN_DIR, f), 'utf8'));

test('Mindestzahl Goldendateien', () => {
  assert.ok(existsSync(GOLDEN_DIR), `Ordner fehlt: ${GOLDEN_DIR}`);
  assert.ok(files.length >= 3, `mindestens 3 Goldendateien erwartet, gefunden: ${files.length}`);
  for (const f of REQUIRED) assert.ok(files.includes(f), `${f} fehlt in app-generated/`);
});

for (const f of files) {
  test(`Goldendateien sind schemagültig: ${f}`, () => {
    const ok = validate(read(f));
    assert.ok(ok, JSON.stringify(validate.errors));
  });
}

test('Goldendateien sind schemagültig: Pflichtdateien vorhanden und gültig', () => {
  // Nulllauf-Schutz: auch bei leerem Ordner scheitert dieser Fall, statt still zu bestehen.
  for (const f of REQUIRED) {
    assert.ok(files.includes(f), `${f} fehlt`);
    assert.ok(validate(read(f)), `${f}: ${JSON.stringify(validate.errors)}`);
  }
});

test('Prüfer lehnt veränderte Goldendatei ab', () => {
  assert.ok(files.includes('full.json'), 'full.json fehlt, Mutationen nicht prüfbar');
  const fresh = (): Obj => structuredClone(read('full.json'));
  assert.ok(validate(fresh()), 'unveränderte full.json muss gültig sein');

  const mutations: [string, (t: Obj) => void][] = [
    ['zusätzliches Feld calories', (t) => { t.calories = 100; }],
    ['workSeconds 601', (t) => {
      const p = t.programs.find((x: Obj) => Array.isArray(x.steps) && x.steps.length > 0);
      assert.ok(p, 'kein Programm mit Schritten in full.json');
      p.steps[0].workSeconds = 601;
    }],
    ['Claude-Programm ohne state', (t) => {
      const p = t.programs.find((x: Obj) => x.origin === 'claude');
      assert.ok(p, 'kein Claude-Programm in full.json');
      delete p.state;
    }],
    ['generatedAt mit +01:00', (t) => { t.generatedAt = '2026-11-24T09:30:00+01:00'; }],
  ];
  for (const [name, mutate] of mutations) {
    const t = fresh();
    mutate(t);
    assert.equal(validate(t), false, `Mutation „${name}“ wurde nicht abgelehnt`);
  }
});

function realDate(s: string): boolean {
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d{1,3})?Z$/.exec(s);
  if (!m) return false;
  const [y, mo, d, h, mi, se] = m.slice(1, 7).map(Number);
  const dt = new Date(Date.UTC(y, mo - 1, d, h, mi, se));
  return dt.getUTCFullYear() === y && dt.getUTCMonth() === mo - 1 && dt.getUTCDate() === d &&
    dt.getUTCHours() === h && dt.getUTCMinutes() === mi && dt.getUTCSeconds() === se;
}

test('Kennungen eindeutig, Daten echt', () => {
  assert.ok(files.length >= 3, `Goldendateien fehlen (gefunden: ${files.length})`);
  for (const f of files) {
    const t = read(f);
    for (const list of ['exercises', 'programs', 'breaths']) {
      const ids: string[] = (t[list] as Obj[]).map((x) => x.id);
      assert.equal(new Set(ids).size, ids.length, `${f}: doppelte Kennung in ${list}`);
    }
    assert.ok(realDate(t.generatedAt), `${f}: generatedAt ist kein echtes Datum: ${t.generatedAt}`);
    for (const list of ['exercises', 'programs', 'breaths']) {
      for (const x of t[list] as Obj[]) {
        if (x.deliveredAt !== undefined) assert.ok(realDate(x.deliveredAt), `${f}: ${x.id} deliveredAt ${x.deliveredAt}`);
      }
    }
  }
});
