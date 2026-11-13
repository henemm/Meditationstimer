import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateDelivery } from '../src/index.ts';
import { breath, challenge, delivery, exercise, goalStage, impulse, key, program, reminder, stage, tracker, withdrawal } from './helpers.ts';

type Ctx = Parameters<typeof validateDelivery>[1];

function run(input: unknown, context?: Ctx): string[] {
  const r = validateDelivery(input, context);
  assert.equal(r.valid, r.errors.length === 0, 'valid === (errors.length === 0)');
  for (const e of r.errors) {
    assert.ok(e.message.trim().length > 0, `message leer: ${key(e)}`);
    assert.ok(e.hint.trim().length > 0, `hint leer: ${key(e)}`);
  }
  return r.errors.map(key).sort();
}

const only = (code: string, path: string): string[] => [`${code} @ ${path}`];

/** Verhalten: Die Bausteine der Tests sind selbst gültig (sonst sind die Fälle wertlos). */
test('Basis-Bausteine sind gültig', () => {
  assert.deepEqual(run(delivery([exercise(), program(), breath(), withdrawal({ itemId: 'claude.anderes' })])), []);
});

// ---------- mehrere Fehler ----------

/** Verhalten: Mehrere Fehler gleichzeitig werden alle gemeldet. */
test('zwei falsche Zeiten in zwei Schritten ergeben zwei Fehler', () => {
  const steps = [
    { exerciseId: 'builtin.burpees', workSeconds: 0, restSeconds: 10 },
    { exerciseId: 'builtin.burpees', workSeconds: 30, restSeconds: 601 },
  ];
  assert.deepEqual(run(delivery([program({ steps })])), [
    'OUT_OF_RANGE @ /items/0/steps/0/workSeconds',
    'OUT_OF_RANGE @ /items/0/steps/1/restSeconds',
  ]);
});

/** Verhalten: Fehler in verschiedenen Einträgen und im Umschlag werden zusammen gemeldet. */
test('Fehler in Umschlag und mehreren Einträgen werden alle gemeldet', () => {
  const input = delivery([exercise({ category: 'x' }), breath({ rounds: 0 })], { source: 'bot' });
  assert.deepEqual(run(input), [
    'CATEGORY_UNKNOWN @ /items/0/category',
    'OUT_OF_RANGE @ /items/1/rounds',
    'VALUE_NOT_ALLOWED @ /source',
  ]);
});

// ---------- keine Folgefehler ----------

/** Verhalten: Falscher Typ eines Felds ergibt nur FIELD_TYPE. */
test('rounds als Text: nur FIELD_TYPE', () => {
  assert.deepEqual(run(delivery([program({ rounds: '3' })])), only('FIELD_TYPE', '/items/0/rounds'));
});

test('name als Zahl: nur FIELD_TYPE', () => {
  assert.deepEqual(run(delivery([exercise({ name: 5 })])), only('FIELD_TYPE', '/items/0/name'));
});

test('why als Zahl: nur FIELD_TYPE', () => {
  assert.deepEqual(run(delivery([exercise()], { why: 5 })), only('FIELD_TYPE', '/why'));
});

test('steps als Text: nur FIELD_TYPE an der Liste', () => {
  assert.deepEqual(run(delivery([program({ steps: 'x' })])), only('FIELD_TYPE', '/items/0/steps'));
});

test('Schritt als Zahl: nur FIELD_TYPE am Schritt', () => {
  assert.deepEqual(run(delivery([program({ steps: [7] })])), only('FIELD_TYPE', '/items/0/steps/0'));
});

test('package ohne Felder: FIELD_MISSING für packageId und name', () => {
  assert.deepEqual(run(delivery([exercise()], { package: {} })), ['FIELD_MISSING @ /package/name', 'FIELD_MISSING @ /package/packageId']);
});

test('package mit unbekanntem Feld: FIELD_UNKNOWN am Feld', () => {
  const pkg = { packageId: 'claude.mein-paket', name: 'Paket', extra: 1 };
  assert.deepEqual(run(delivery([exercise()], { package: pkg })), only('FIELD_UNKNOWN', '/package/extra'));
});

test('package als Text: nur FIELD_TYPE', () => {
  assert.deepEqual(run(delivery([exercise()], { package: 'x' })), only('FIELD_TYPE', '/package'));
});

test('createdAt als Zahl: nur FIELD_TYPE', () => {
  assert.deepEqual(run(delivery([exercise()], { createdAt: 20261113 })), only('FIELD_TYPE', '/createdAt'));
});

/** Verhalten: Unbekanntes kind ergibt nur KIND_UNKNOWN, auch wenn der Rest Unsinn ist. */
test('unbekanntes kind mit Unsinn in den übrigen Feldern: nur KIND_UNKNOWN', () => {
  const junk = { kind: 'meditation', itemId: '!!', revision: 'x', name: 5, foo: 1 };
  assert.deepEqual(run(delivery([junk])), only('KIND_UNKNOWN', '/items/0/kind'));
});

test('kind fehlt mit Unsinn in den übrigen Feldern: nur FIELD_MISSING am kind', () => {
  const junk = { itemId: '!!', revision: 'x', name: 5, foo: 1 };
  assert.deepEqual(run(delivery([junk])), only('FIELD_MISSING', '/items/0/kind'));
});

test('kind mit falschem Typ: genau FIELD_TYPE an /items/0/kind', () => {
  assert.deepEqual(run(delivery([{ kind: 5, itemId: '!!', foo: 1 }])), only('FIELD_TYPE', '/items/0/kind'));
});

/** Verhalten: Fehlendes oder unbekanntes format verhindert die Prüfung der übrigen Felder nicht. */
test('format fehlt: andere Fehler werden trotzdem gemeldet', () => {
  const input = delivery([exercise()], { why: 5 });
  delete (input as Record<string, unknown>).format;
  assert.deepEqual(run(input), ['FIELD_MISSING @ /format', 'FIELD_TYPE @ /why']);
});

test('format unbekannt: andere Fehler werden trotzdem gemeldet', () => {
  const input = delivery([breath({ rounds: 100 })], { format: 'hhhaven.delivery/2' });
  assert.deepEqual(run(input), ['FORMAT_UNKNOWN @ /format', 'OUT_OF_RANGE @ /items/0/rounds']);
});

/** Verhalten: Wurzel, die kein Objekt ist, ergibt nur FIELD_TYPE an "". */
for (const [label, root] of [['null', null], ['Zahl', 42], ['Text', 'x'], ['Liste', []], ['Wahrheitswert', true]] as const) {
  test(`Wurzel ${label}: nur FIELD_TYPE an ""`, () => {
    assert.deepEqual(run(root), only('FIELD_TYPE', ''));
  });
}

/** Verhalten: Kennungen, die selbst nicht dem Muster entsprechen, lösen keine Folgefehler aus. */
test('zwei ungültige itemId: INVALID_ID, kein DUPLICATE_ID', () => {
  const input = delivery([exercise({ itemId: 'BAD' }), exercise({ itemId: 'BAD', name: 'Andere' })]);
  assert.deepEqual(run(input), ['INVALID_ID @ /items/0/itemId', 'INVALID_ID @ /items/1/itemId']);
});

test('Schritt mit ungültiger exerciseId: nur INVALID_ID, kein EXERCISE_UNKNOWN', () => {
  const steps = [{ exerciseId: 'claude.x', workSeconds: 30, restSeconds: 10 }];
  assert.deepEqual(run(delivery([program({ steps })])), only('INVALID_ID', '/items/0/steps/0/exerciseId'));
});

test('Schritt verweist auf Übung der Lieferung mit ungültiger itemId: nur INVALID_ID', () => {
  const steps = [{ exerciseId: 'claude.Foo', workSeconds: 30, restSeconds: 10 }];
  const input = delivery([exercise({ itemId: 'claude.Foo' }), program({ steps })]);
  const r = run(input);
  assert.ok(!r.some((e) => e.startsWith('EXERCISE_UNKNOWN')), r.join(', '));
});

/** Verhalten: Eine fehlerhafte Übung der Lieferung zählt trotzdem als Ziel eines Bezugs. */
test('Verweis auf fehlerhafte, vorhandene Übung ist kein EXERCISE_UNKNOWN', () => {
  const steps = [{ exerciseId: 'claude.kaputt', workSeconds: 30, restSeconds: 10 }];
  const input = delivery([exercise({ itemId: 'claude.kaputt', category: 'x' }), program({ steps })]);
  assert.deepEqual(run(input), only('CATEGORY_UNKNOWN', '/items/0/category'));
});

/** Verhalten: TOTAL_TOO_LONG wird nicht gemeldet, wenn eine beteiligte Zahl ungültig ist. */
test('Programm: Zeit außerhalb des Bereichs, Gesamtdauer nicht gemeldet', () => {
  const steps = [{ exerciseId: 'builtin.burpees', workSeconds: 601, restSeconds: 0 }];
  assert.deepEqual(run(delivery([program({ rounds: 99, steps })])), only('OUT_OF_RANGE', '/items/0/steps/0/workSeconds'));
});

test('Programm: rounds außerhalb des Bereichs, Gesamtdauer nicht gemeldet', () => {
  const steps = [{ exerciseId: 'builtin.burpees', workSeconds: 600, restSeconds: 600 }];
  assert.deepEqual(run(delivery([program({ rounds: 100, steps })])), only('OUT_OF_RANGE', '/items/0/rounds'));
});

test('Programm: rounds falscher Typ, Gesamtdauer nicht gemeldet', () => {
  const steps = [{ exerciseId: 'builtin.burpees', workSeconds: 600, restSeconds: 600 }];
  assert.deepEqual(run(delivery([program({ rounds: 'x', steps })])), only('FIELD_TYPE', '/items/0/rounds'));
});

test('Programm: zu viele Schritte, Gesamtdauer nicht gemeldet', () => {
  const step = { exerciseId: 'builtin.burpees', workSeconds: 600, restSeconds: 600 };
  const steps = Array.from({ length: 41 }, () => step);
  assert.deepEqual(run(delivery([program({ rounds: 1, steps })])), only('LIST_SIZE', '/items/0/steps'));
});

test('Atemübung: rounds außerhalb des Bereichs, Gesamtdauer nicht gemeldet', () => {
  assert.deepEqual(run(delivery([breath({ rounds: 100, inhaleSeconds: 60, exhaleSeconds: 60 })])), only('OUT_OF_RANGE', '/items/0/rounds'));
});

test('Atemübung: eine Zeit außerhalb des Bereichs, Gesamtdauer nicht gemeldet', () => {
  assert.deepEqual(run(delivery([breath({ rounds: 99, inhaleSeconds: 61 })])), only('OUT_OF_RANGE', '/items/0/inhaleSeconds'));
});

/** Verhalten: Gesamtdauer genau an der Grenze ist gültig, eine Sekunde mehr nicht (Rechenformel). */
test('Gesamtdauer Programm: 14400 gültig, 14401 ungültig', () => {
  const ok = [{ exerciseId: 'builtin.burpees', workSeconds: 600, restSeconds: 600 }];
  assert.deepEqual(run(delivery([program({ rounds: 12, steps: ok })])), []);
  const over = [{ exerciseId: 'builtin.burpees', workSeconds: 600, restSeconds: 601 }];
  const r = run(delivery([program({ rounds: 12, steps: over })]));
  assert.deepEqual(r, only('OUT_OF_RANGE', '/items/0/steps/0/restSeconds'));
  const steps2 = [{ exerciseId: 'builtin.burpees', workSeconds: 600, restSeconds: 600 }, { exerciseId: 'builtin.burpees', workSeconds: 1, restSeconds: 0 }];
  assert.deepEqual(run(delivery([program({ rounds: 12, steps: steps2 })])), only('TOTAL_TOO_LONG', '/items/0'));
});

test('Gesamtdauer Atemübung: 3600 gültig, 3601 ungültig', () => {
  assert.deepEqual(run(delivery([breath({ rounds: 15, inhaleSeconds: 60, holdInSeconds: 60, exhaleSeconds: 60, holdOutSeconds: 60 })])), []);
  assert.deepEqual(
    run(delivery([breath({ rounds: 40, inhaleSeconds: 30, holdInSeconds: 30, exhaleSeconds: 30, holdOutSeconds: 1 })])),
    only('TOTAL_TOO_LONG', '/items/0'),
  );
});

// ---------- JSON-Pointer ----------

/** Verhalten: Pfade sind JSON Pointer mit Escaping (~0 für ~, ~1 für /). */
test('unbekanntes Feld "a/b" an der Wurzel: Pfad /a~1b', () => {
  assert.deepEqual(run(delivery([exercise()], { 'a/b': 1 })), only('FIELD_UNKNOWN', '/a~1b'));
});

test('unbekanntes Feld "a~b" an der Wurzel: Pfad /a~0b', () => {
  assert.deepEqual(run(delivery([exercise()], { 'a~b': 1 })), only('FIELD_UNKNOWN', '/a~0b'));
});

test('unbekanntes Feld "~/" im Eintrag: Pfad /items/0/~0~1', () => {
  assert.deepEqual(run(delivery([exercise({ '~/': 1 })])), only('FIELD_UNKNOWN', '/items/0/~0~1'));
});

test('unbekanntes Feld "" (leerer Name) im Schritt: Pfad endet mit /', () => {
  const steps = [{ exerciseId: 'builtin.burpees', workSeconds: 30, restSeconds: 10, '': 1 }];
  assert.deepEqual(run(delivery([program({ steps })])), only('FIELD_UNKNOWN', '/items/0/steps/0/'));
});

// ---------- Länge in Code Points ----------

/** Verhalten: Länge zählt Code Points; ein Emoji außerhalb der BMP zählt 1. */
test('Name aus 40 Emojis ist gültig, 41 zu lang', () => {
  assert.deepEqual(run(delivery([exercise({ name: '💪'.repeat(40) })])), []);
  assert.deepEqual(run(delivery([exercise({ name: '💪'.repeat(41) })])), only('TEXT_TOO_LONG', '/items/0/name'));
});

test('Symbol aus 16 Emojis ist gültig, 17 ungültig', () => {
  assert.deepEqual(run(delivery([program({ symbol: '💪'.repeat(16) })])), []);
  assert.deepEqual(run(delivery([program({ symbol: '💪'.repeat(17) })])), only('INVALID_SYMBOL', '/items/0/symbol'));
});

test('Textgrenzen: why 300 gültig, 301 zu lang', () => {
  assert.deepEqual(run(delivery([exercise()], { why: 'x'.repeat(300) })), []);
  assert.deepEqual(run(delivery([exercise()], { why: 'x'.repeat(301) })), only('TEXT_TOO_LONG', '/why'));
});

test('Textgrenzen: Übung effect 600/601, instructions 1500/1501', () => {
  assert.deepEqual(run(delivery([exercise({ effect: 'x'.repeat(600), instructions: 'y'.repeat(1500) })])), []);
  assert.deepEqual(run(delivery([exercise({ effect: 'x'.repeat(601) })])), only('TEXT_TOO_LONG', '/items/0/effect'));
  assert.deepEqual(run(delivery([exercise({ instructions: 'y'.repeat(1501) })])), only('TEXT_TOO_LONG', '/items/0/instructions'));
});

// ---------- Textregeln ----------

/** Verhalten: Leerer Text und Text nur aus Leerzeichen/Zeilenumbrüchen ist TEXT_EMPTY. */
test('mehrzeiliges Feld mit " \\n " ist TEXT_EMPTY', () => {
  assert.deepEqual(run(delivery([exercise({ effect: ' \n ' })])), only('TEXT_EMPTY', '/items/0/effect'));
});

test('mehrzeiliges Feld mit NBSP und Zeilenumbruch ist TEXT_EMPTY', () => {
  assert.deepEqual(run(delivery([exercise({ instructions: ' \n ' })])), only('TEXT_EMPTY', '/items/0/instructions'));
});

test('leerer einzeiliger Text ist TEXT_EMPTY', () => {
  assert.deepEqual(run(delivery([exercise({ name: '' })])), only('TEXT_EMPTY', '/items/0/name'));
});

test('einzeiliger Text nur aus NBSP ist TEXT_EMPTY', () => {
  assert.deepEqual(run(delivery([exercise()], { why: '  ' })), only('TEXT_EMPTY', '/why'));
});

test('Zeilenumbruch im mehrzeiligen Feld ist erlaubt', () => {
  assert.deepEqual(run(delivery([exercise({ effect: 'Zeile 1\nZeile 2' })])), []);
});

test('Zeilenumbruch im einzeiligen Feld ist TEXT_FORBIDDEN_CHAR', () => {
  assert.deepEqual(run(delivery([exercise({ name: 'Zeile\n2' })])), only('TEXT_FORBIDDEN_CHAR', '/items/0/name'));
});

/** Verhalten: Verbotene Zeichen werden erkannt (Randwerte der Bereiche). */
for (const [label, ch] of [
  ['U+2028', ' '], ['U+2029', ' '], ['U+0000', '\u0000'], ['U+001F', '\u001F'], ['U+0009 Tab', '\t'],
  ['U+000D', '\r'], ['U+007F', '\u007F'], ['U+0085', '\u0085'], ['U+009F', '\u009F'],
  ['U+202A', '‪'], ['U+202E', '‮'], ['U+2066', '⁦'], ['U+2069', '⁩'],
] as const) {
  test(`${label} im mehrzeiligen Feld: TEXT_FORBIDDEN_CHAR`, () => {
    assert.deepEqual(run(delivery([exercise({ effect: `a${ch}b` })])), only('TEXT_FORBIDDEN_CHAR', '/items/0/effect'));
  });
}

test('NBSP mitten im Text ist erlaubt', () => {
  assert.deepEqual(run(delivery([exercise({ name: 'Wand Sitz' })])), []);
});

/** Verhalten: Reihenfolge je Textfeld: verbotenes Zeichen, dann leer, dann zu lang. */
test('zu lang UND verbotenes Zeichen: nur TEXT_FORBIDDEN_CHAR', () => {
  assert.deepEqual(run(delivery([exercise({ effect: 'a'.repeat(601) + ' ' })])), only('TEXT_FORBIDDEN_CHAR', '/items/0/effect'));
});

test('leer (Leerzeichen) UND verbotenes Zeichen: nur TEXT_FORBIDDEN_CHAR', () => {
  assert.deepEqual(run(delivery([exercise({ effect: '    ' })])), only('TEXT_FORBIDDEN_CHAR', '/items/0/effect'));
});

test('einzeilig zu lang UND mit Zeilenumbruch: nur TEXT_FORBIDDEN_CHAR', () => {
  assert.deepEqual(run(delivery([exercise()], { why: 'a'.repeat(301) + '\n' })), only('TEXT_FORBIDDEN_CHAR', '/why'));
});

/** Verhalten: Symbolregeln. */
for (const [label, symbol] of [['ASCII-Buchstabe', 'A'], ['ASCII-Ziffer', '1'], ['Leerzeichen', '🏃 🏃'], ['NBSP', ' '], ['Zeilenumbruch', '🏃\n'], ['leer', '']] as const) {
  test(`Symbol mit ${label}: INVALID_SYMBOL`, () => {
    assert.deepEqual(run(delivery([program({ symbol })])), only('INVALID_SYMBOL', '/items/0/symbol'));
  });
}

// ---------- Datum ----------

/** Verhalten: createdAt muss ein echter UTC-Zeitpunkt sein. */
for (const [label, value] of [
  ['Stunde 24', '2026-11-13T24:00:00Z'], ['Minute 60', '2026-11-13T10:60:00Z'], ['Sekunde 60', '2026-11-13T10:15:60Z'],
  ['Monat 13', '2026-13-01T10:15:00Z'], ['31. November', '2026-11-31T10:15:00Z'], ['Tag 00', '2026-11-00T10:15:00Z'],
  ['4 Nachkommastellen', '2026-11-13T10:15:00.1234Z'], ['leere Nachkommastellen', '2026-11-13T10:15:00.Z'],
  ['Offset statt Z', '2026-11-13T10:15:00+00:00'], ['kleines z', '2026-11-13T10:15:00z'],
] as const) {
  test(`createdAt ${label}: INVALID_DATE`, () => {
    assert.deepEqual(run(delivery([exercise()], { createdAt: value })), only('INVALID_DATE', '/createdAt'));
  });
}

for (const value of ['2024-02-29T00:00:00Z', '2026-11-13T23:59:59Z', '2026-11-13T10:15:00.1Z', '2026-11-13T10:15:00.123Z']) {
  test(`createdAt ${value} ist gültig`, () => {
    assert.deepEqual(run(delivery([exercise()], { createdAt: value })), []);
  });
}

// ---------- Dubletten ----------

/** Verhalten: Dubletten-Namen werden normalisiert verglichen (Groß-/Kleinschreibung, Leerzeichen). */
test('Name wie Katalogname, andere Schreibung und doppeltes Innen-Leerzeichen: NAME_TAKEN', () => {
  const input = delivery([exercise({ name: '  mountain   CLIMBERS ' })]);
  assert.deepEqual(run(input), only('NAME_TAKEN', '/items/0/name'));
});

test('Name wie Katalogname, nur Großschreibung: NAME_TAKEN', () => {
  assert.deepEqual(run(delivery([exercise({ name: 'BURPEES' })])), only('NAME_TAKEN', '/items/0/name'));
});

test('Name wie Kontext-Übung mit anderer Kennung, andere Schreibung: NAME_TAKEN', () => {
  const context = { knownExercises: [{ id: 'own.rueckenstrecker', name: 'Rücken  Strecker' }] };
  assert.deepEqual(run(delivery([exercise({ name: 'rücken strecker' })]), context), only('NAME_TAKEN', '/items/0/name'));
});

test('Name wie Kontext-Übung mit GLEICHER Kennung: keine Dublette', () => {
  const context = { knownExercises: [{ id: 'claude.test-uebung', name: 'Testübung' }] };
  assert.deepEqual(run(delivery([exercise({ revision: 2 })]), context), []);
});

test('zwei Übungen derselben Lieferung: nur das spätere Vorkommen wird gemeldet', () => {
  const input = delivery([exercise({ name: 'Foo Bar' }), exercise({ itemId: 'claude.zweite', name: 'foo   bar' })]);
  assert.deepEqual(run(input), only('NAME_TAKEN', '/items/1/name'));
});

test('Dubletten-Prüfung nur bei gültigem Namen: zu langer Name ergibt nur TEXT_TOO_LONG', () => {
  const input = delivery([exercise({ name: 'Burpees' + 'x'.repeat(40) }), exercise({ itemId: 'claude.zweite', name: 'Burpees' + 'x'.repeat(40) })]);
  assert.deepEqual(run(input), ['TEXT_TOO_LONG @ /items/0/name', 'TEXT_TOO_LONG @ /items/1/name']);
});

test('Programm und Atemübung mit Namen einer eingebauten Übung sind keine Dublette', () => {
  assert.deepEqual(run(delivery([program({ name: 'Burpees' }), breath({ name: 'burpees' })])), []);
});

/** Verhalten: Länge wird am unveränderten Text gezählt (ohne Trimmen). */
test('Name mit Rand-Leerzeichen: roh 41 Code Points ist TEXT_TOO_LONG, roh 40 gültig', () => {
  assert.deepEqual(run(delivery([exercise({ name: ' ' + 'x'.repeat(39) + ' ' })])), only('TEXT_TOO_LONG', '/items/0/name'));
  assert.deepEqual(run(delivery([exercise({ name: ' ' + 'x'.repeat(38) + ' ' })])), []);
});

/** Verhalten: Die Liste verbotener Zeichen ist abschließend. */
for (const [label, ch] of [['U+2060', '\u2060'], ['U+2065', '\u2065'], ['U+200B', '\u200B'], ['U+00A0', '\u00A0']] as const) {
  test(`${label} im Namen ist gültig`, () => {
    assert.deepEqual(run(delivery([exercise({ name: `a${ch}b` })])), []);
  });
}

// ---------- Kontext ----------

/** Verhalten: Fehlender, leerer und leerer-Listen-Kontext verhalten sich gleich. */
test('context weggelassen, {} und leere Liste ergeben dasselbe Ergebnis', () => {
  const steps = [{ exerciseId: 'own.unbekannt', workSeconds: 30, restSeconds: 10 }];
  const input = delivery([program({ steps })]);
  const expected = only('EXERCISE_UNKNOWN', '/items/0/steps/0/exerciseId');
  assert.deepEqual(run(input), expected);
  assert.deepEqual(run(input, {}), expected);
  assert.deepEqual(run(input, { knownExercises: [] }), expected);
  const good = delivery([program()]);
  assert.deepEqual(run(good), []);
  assert.deepEqual(run(good, {}), []);
  assert.deepEqual(run(good, { knownExercises: [] }), []);
});

test('own.* im Kontext bekannt: Bezug gültig', () => {
  const steps = [{ exerciseId: 'own.bekannt', workSeconds: 30, restSeconds: 10 }];
  assert.deepEqual(run(delivery([program({ steps })]), { knownExercises: [{ id: 'own.bekannt', name: 'Bekannt' }] }), []);
});

test('builtin.* nur über Katalog, nicht über Kontext', () => {
  const steps = [{ exerciseId: 'builtin.gibt-es-nicht', workSeconds: 30, restSeconds: 10 }];
  const context = { knownExercises: [{ id: 'builtin.gibt-es-nicht', name: 'X' }] };
  assert.deepEqual(run(delivery([program({ steps })]), context), only('EXERCISE_UNKNOWN', '/items/0/steps/0/exerciseId'));
});

test('Verweis auf Atemübung der Lieferung ist EXERCISE_UNKNOWN', () => {
  const steps = [{ exerciseId: 'claude.test-atmung', workSeconds: 30, restSeconds: 10 }];
  assert.deepEqual(run(delivery([breath(), program({ steps })])), only('EXERCISE_UNKNOWN', '/items/1/steps/0/exerciseId'));
});

// ---------- Rücknahme ----------

test('Rücknahme mit beiden Zielen und ungültigen Mustern: INVALID_ID je Feld plus WITHDRAWAL_TARGET am Eintrag', () => {
  assert.deepEqual(run(delivery([withdrawal({ itemId: 'Foo', packageId: 'x' })])), [
    'INVALID_ID @ /items/0/itemId', 'INVALID_ID @ /items/0/packageId', 'WITHDRAWAL_TARGET @ /items/0',
  ]);
});

test('Rücknahme mit ungültiger itemId: INVALID_ID', () => {
  assert.deepEqual(run(delivery([withdrawal({ itemId: 'Foo' })])), only('INVALID_ID', '/items/0/itemId'));
});

test('Rücknahme mit ungültiger packageId: INVALID_ID', () => {
  assert.deepEqual(run(delivery([{ kind: 'withdrawal', packageId: 'x' }])), only('INVALID_ID', '/items/0/packageId'));
});

test('Rücknahme eines Pakets ist gültig', () => {
  assert.deepEqual(run(delivery([{ kind: 'withdrawal', packageId: 'claude.mein-paket' }])), []);
});

// ---------- Unveränderlichkeit ----------

/** Verhalten: Die Eingabe wird nicht verändert. */
test('Eingabe und Kontext bleiben unverändert (ungültige Lieferung)', () => {
  const input = delivery(
    [exercise({ name: ' BURPEES ', category: 'x' }), program({ rounds: '3', steps: [{ exerciseId: 'own.x', workSeconds: 0, restSeconds: 1 }] }), { kind: 'zzz' }],
    { why: 5, extra: { a: 1 } },
  );
  const context = { knownExercises: [{ id: 'own.y', name: 'Y' }] };
  const inputBefore = structuredClone(input);
  const contextBefore = structuredClone(context);
  validateDelivery(input, context);
  assert.deepEqual(input, inputBefore);
  assert.deepEqual(context, contextBefore);
});

test('Eingabe bleibt unverändert (gültige Lieferung) und Aufruf ist wiederholbar', () => {
  const input = delivery([exercise(), program(), breath()]);
  const before = structuredClone(input);
  const first = validateDelivery(input);
  const second = validateDelivery(input);
  assert.deepEqual(input, before);
  assert.deepEqual(first, second);
});

// ---------- (a) Normalisierung: Kleinschreibung je Code Point, ohne Kontext ----------

/** Verhalten: Schluss-Sigma wirkt nicht; "ΑΣ" wird zu "ασ". */
test('Name "ΑΣ" gegen Kontextname "ασ": NAME_TAKEN', () => {
  const context = { knownExercises: [{ id: 'own.sigma', name: 'ασ' }] };
  assert.deepEqual(run(delivery([exercise({ name: 'ΑΣ' })]), context), only('NAME_TAKEN', '/items/0/name'));
});

test('Name "ΑΣ" gegen Kontextname "ας" (Schluss-Sigma): keine Dublette', () => {
  const context = { knownExercises: [{ id: 'own.sigma', name: 'ας' }] };
  assert.deepEqual(run(delivery([exercise({ name: 'ΑΣ' })]), context), []);
});

test('Übungen "ΑΣ" und "ας" in einer Lieferung: keine Dublette', () => {
  assert.deepEqual(run(delivery([exercise({ name: 'ΑΣ' }), exercise({ itemId: 'claude.zweite', name: 'ας' })])), []);
});

test('Übungen "Σ" und "σ" in einer Lieferung: NAME_TAKEN am zweiten', () => {
  assert.deepEqual(run(delivery([exercise({ name: 'σ' }), exercise({ itemId: 'claude.zweite', name: 'Σ' })])), only('NAME_TAKEN', '/items/1/name'));
});

// ---------- (b) einzelne Surrogate ----------

/** Verhalten: Einzelne Ersatzzeichen sind TEXT_FORBIDDEN_CHAR, gültige Paare bleiben erlaubt. */
for (const [label, text] of [
  ['hohes Surrogat allein', JSON.parse('"\\ud800"') as string],
  ['tiefes Surrogat allein', JSON.parse('"\\udc00"') as string],
  ['hohes Surrogat vor Text', JSON.parse('"\\ud83dx"') as string],
  ['vertauschtes Paar', JSON.parse('"\\udcaa\\ud83d"') as string],
  ['Surrogat am Ende', JSON.parse('"abc\\udfff"') as string],
] as const) {
  test(`${label} im einzeiligen Feld: TEXT_FORBIDDEN_CHAR`, () => {
    assert.deepEqual(run(delivery([exercise({ name: text })])), only('TEXT_FORBIDDEN_CHAR', '/items/0/name'));
  });
  test(`${label} im mehrzeiligen Feld: TEXT_FORBIDDEN_CHAR`, () => {
    assert.deepEqual(run(delivery([exercise({ effect: text })])), only('TEXT_FORBIDDEN_CHAR', '/items/0/effect'));
  });
}

test('gültiges Surrogatpaar (Emoji) bleibt erlaubt', () => {
  assert.deepEqual(run(delivery([exercise({ name: 'a💪b', effect: '💪\n💪' })])), []);
});

test('einzelnes Surrogat im Symbol: INVALID_SYMBOL', () => {
  assert.deepEqual(run(delivery([program({ symbol: JSON.parse('"\\ud800"') })])), only('INVALID_SYMBOL', '/items/0/symbol'));
});

// ---------- (c) ganze Zahlen: Betrag > 10^9 oder unendlich ----------

function withRounds(json: string): unknown {
  return delivery([program({ rounds: JSON.parse(json) })]);
}

/** Verhalten: Riesige Zahlen sind OUT_OF_RANGE, noch vor der Ganzzahlprüfung. */
for (const json of ['1e21', '1e400', '-1e400', '1000000001', '-1000000001', '1000000000.5', '100']) {
  test(`rounds ${json}: OUT_OF_RANGE`, () => {
    assert.deepEqual(run(withRounds(json)), only('OUT_OF_RANGE', '/items/0/rounds'));
  });
}

test('rounds 5e-1: FIELD_TYPE (keine ganze Zahl)', () => {
  assert.deepEqual(run(withRounds('5e-1')), only('FIELD_TYPE', '/items/0/rounds'));
});

test('rounds 12.5: FIELD_TYPE', () => {
  assert.deepEqual(run(withRounds('12.5')), only('FIELD_TYPE', '/items/0/rounds'));
});

test('rounds 1.2e1 gilt als 12 und ist gültig', () => {
  assert.deepEqual(run(withRounds('1.2e1')), []);
});

test('rounds -0 gilt als 0: OUT_OF_RANGE', () => {
  assert.deepEqual(run(withRounds('-0')), only('OUT_OF_RANGE', '/items/0/rounds'));
});

test('restSeconds -0 gilt als 0: gültig', () => {
  const steps = [{ exerciseId: 'builtin.burpees', workSeconds: 30, restSeconds: JSON.parse('-0') }];
  assert.deepEqual(run(delivery([program({ steps })])), []);
});

test('Atemzeit 1e400: OUT_OF_RANGE', () => {
  assert.deepEqual(run(delivery([breath({ holdInSeconds: JSON.parse('1e400') })])), only('OUT_OF_RANGE', '/items/0/holdInSeconds'));
});

test('revision 1e21: OUT_OF_RANGE', () => {
  assert.deepEqual(run(delivery([exercise({ revision: JSON.parse('1e21') })])), only('OUT_OF_RANGE', '/items/0/revision'));
});

// ---------- (d) message/hint: fremde Inhalte gekürzt und bereinigt ----------

const FORBIDDEN = new RegExp('[\\u0000-\\u001F\\u007F-\\u009F\\u2028\\u2029\\u202A-\\u202E\\u2066-\\u2069\\uD800-\\uDFFF]', 'u');

function allText(input: unknown): string[] {
  const r = validateDelivery(input);
  assert.ok(r.errors.length > 0, 'Fehler erwartet');
  return r.errors.flatMap((e) => [e.message, e.hint]);
}

/** Verhalten: Ein langer unbekannter Feldname steht nicht ungekürzt in message/hint. */
test('1000 Zeichen langer unbekannter Feldname wird nicht vollständig zitiert', () => {
  const name = 'f'.repeat(1000);
  for (const t of allText(delivery([exercise()], { [name]: 1 }))) {
    assert.ok(!t.includes(name), 'Feldname ungekürzt');
    assert.ok(!t.includes('f'.repeat(41)), 'mehr als 40 Code Points des Feldnamens');
  }
});

test('Feldname mit Zeilenumbruch und Steuerzeichen: keine verbotenen Zeichen in message/hint', () => {
  const input = delivery([exercise()], { 'a\nb c\u0000d‮e': 1 });
  for (const t of allText(input)) assert.ok(!FORBIDDEN.test(t), JSON.stringify(t));
});

test('langer unbekannter Feldname im Eintrag und im Schritt: gekürzt', () => {
  const name = 'g'.repeat(500);
  const steps = [{ exerciseId: 'builtin.burpees', workSeconds: 30, restSeconds: 10, [name]: 1 }];
  for (const t of allText(delivery([program({ steps, [name]: 1 })]))) assert.ok(!t.includes('g'.repeat(41)));
});

test('langer falscher Wert (source) wird gekürzt', () => {
  const value = 'v'.repeat(1000);
  for (const t of allText(delivery([exercise()], { source: value }))) assert.ok(!t.includes('v'.repeat(41)));
});

test('falscher format-Wert mit Zeilenumbruch: keine verbotenen Zeichen in message/hint', () => {
  for (const t of allText(delivery([exercise()], { format: 'x\ny z' }))) assert.ok(!FORBIDDEN.test(t), JSON.stringify(t));
});

test('unbekanntes kind mit Steuerzeichen und Länge: gekürzt und bereinigt', () => {
  const value = 'k\n'.repeat(500);
  for (const t of allText(delivery([{ kind: value }]))) {
    assert.ok(!FORBIDDEN.test(t), JSON.stringify(t));
    assert.ok(!t.includes('k'.repeat(41)));
  }
});

test('ungültige Kennung mit Steuerzeichen: keine verbotenen Zeichen in message/hint', () => {
  for (const t of allText(delivery([exercise({ itemId: 'claude.a\u0000\nb' })]))) assert.ok(!FORBIDDEN.test(t), JSON.stringify(t));
});

test('Kategorie mit einzelnem Surrogat: keine verbotenen Zeichen in message/hint', () => {
  for (const t of allText(delivery([exercise({ category: JSON.parse('"\\ud800x"') })]))) assert.ok(!FORBIDDEN.test(t), JSON.stringify(t));
});

test('Text mit verbotenem Zeichen im Namen: message/hint enthalten es nicht', () => {
  for (const t of allText(delivery([exercise({ name: 'a‮b' })]))) assert.ok(!FORBIDDEN.test(t), JSON.stringify(t));
});

test('message/hint sind auch bei normalen Fehlern frei von verbotenen Zeichen', () => {
  for (const t of allText(delivery([exercise({ category: 'x' })]))) assert.ok(!FORBIDDEN.test(t), JSON.stringify(t));
});

// ---------- B4a: Erinnerungen ----------

const rem = (n: number, over: Record<string, unknown> = {}) =>
  Array.from({ length: n }, (_, i) => reminder({ itemId: `claude.erinnerung-${i}`, ...over }));

/** Verhalten: Eine Standard-Erinnerung ist gültig (sonst sind die Fälle wertlos). */
test('Basis-Erinnerung ist gültig', () => {
  assert.deepEqual(run(delivery([reminder()])), []);
});

/** Verhalten: Das Limit zählt nur Erinnerungen, nicht andere Bausteine. */
test('6 Erinnerungen plus 3 Programme sind gültig', () => {
  const programs = [0, 1, 2].map((i) => program({ itemId: `claude.programm-${i}` }));
  assert.deepEqual(run(delivery([...rem(6), ...programs])), []);
});

test('7 Erinnerungen: REMINDER_LIMIT an /items', () => {
  assert.deepEqual(run(delivery(rem(7))), only('REMINDER_LIMIT', '/items'));
});

/** Verhalten: Rücknahmen zählen nicht zum Limit. */
test('6 Erinnerungen plus Rücknahme zählen nicht als 7', () => {
  assert.deepEqual(run(delivery([...rem(6), withdrawal({ itemId: 'claude.alte-erinnerung' })])), []);
});

test('time als Zahl: FIELD_TYPE', () => {
  assert.deepEqual(run(delivery([reminder({ time: 1800 })])), only('FIELD_TYPE', '/items/0/time'));
});

test('weekdays kein Array: FIELD_TYPE', () => {
  assert.deepEqual(run(delivery([reminder({ weekdays: 'monday' })])), only('FIELD_TYPE', '/items/0/weekdays'));
});

test('Wochentag als Zahl: FIELD_TYPE am Eintrag', () => {
  assert.deepEqual(run(delivery([reminder({ weekdays: ['monday', 3] })])), only('FIELD_TYPE', '/items/0/weekdays/1'));
});

/** Verhalten: Jedes weitere Vorkommen eines Wochentags wird gemeldet, das erste nicht. */
test('[mo,mo,mo]: DUPLICATE_VALUE an /1 und /2', () => {
  assert.deepEqual(run(delivery([reminder({ weekdays: ['monday', 'monday', 'monday'] })])), [
    'DUPLICATE_VALUE @ /items/0/weekdays/1',
    'DUPLICATE_VALUE @ /items/0/weekdays/2',
  ]);
});

test('Ziel noalc mit Zusatzfeld: FIELD_UNKNOWN', () => {
  assert.deepEqual(
    run(delivery([reminder({ target: { type: 'noalc', programId: 'builtin.tabata' } })])),
    only('FIELD_UNKNOWN', '/items/0/target/programId'),
  );
});

/** Verhalten: Ein Programm der Lieferung zählt als Ziel, auch wenn es selbst fehlerhaft ist. */
test('Ziel-Programm der Lieferung mit eigenem Fehler: kein TARGET_UNKNOWN', () => {
  const input = delivery([
    program({ rounds: 0 }),
    reminder({ target: { type: 'workout', programId: 'claude.test-programm' } }),
  ]);
  assert.deepEqual(run(input), only('OUT_OF_RANGE', '/items/0/rounds'));
});

test('Ziel-Programm in derselben Lieferung: gültig', () => {
  const input = delivery([program(), reminder({ target: { type: 'workout', programId: 'claude.test-programm' } })]);
  assert.deepEqual(run(input), []);
});

test('Ziel-Atemübung in derselben Lieferung: gültig', () => {
  const input = delivery([breath(), reminder({ target: { type: 'breath', breathId: 'claude.test-atmung' } })]);
  assert.deepEqual(run(input), []);
});

/** Verhalten: Eine Übung ist weder Programm noch Atemübung. */
test('breathId zeigt auf Übung der Lieferung: TARGET_UNKNOWN', () => {
  const input = delivery([exercise(), reminder({ target: { type: 'breath', breathId: 'claude.test-uebung' } })]);
  assert.deepEqual(run(input), only('TARGET_UNKNOWN', '/items/1/target/breathId'));
});

/** Verhalten: Ohne knownPrograms gibt es keinen Programmkatalog, auch builtin.* ist unbekannt. */
test('knownPrograms fehlt: builtin-Programm ist TARGET_UNKNOWN', () => {
  const input = delivery([reminder({ target: { type: 'workout', programId: 'builtin.tabata' } })]);
  assert.deepEqual(run(input), only('TARGET_UNKNOWN', '/items/0/target/programId'));
  assert.deepEqual(run(input, { knownExercises: [] }), only('TARGET_UNKNOWN', '/items/0/target/programId'));
});

test('knownPrograms enthält builtin-Programm: gültig', () => {
  const input = delivery([reminder({ target: { type: 'workout', programId: 'builtin.tabata' } })]);
  assert.deepEqual(run(input, { knownPrograms: ['builtin.tabata'] }), []);
});

/** Verhalten: Ein Kontext nur mit knownExercises funktioniert weiter. */
test('Kontext nur mit knownExercises: Erinnerung und Übung prüfbar', () => {
  const ctx = { knownExercises: [{ id: 'own.x-uebung', name: 'Andere Übung' }] };
  assert.deepEqual(run(delivery([reminder()]), ctx), []);
  assert.deepEqual(run(delivery([exercise({ name: 'Andere Übung' })]), ctx), only('NAME_TAKEN', '/items/0/name'));
});

// ---------- B5a: Impuls-Challenge ----------

const CH = '/items/0';
const ST = `${CH}/stages/0`;
const IMP = `${ST}/content/impulses`;
const codesOf = (input: unknown): string[] => validateDelivery(input).errors.map((e) => e.code);

/** Verhalten: Eine Standard-Challenge ist gültig (sonst sind die Fälle wertlos). */
test('Basis-Challenge ist gültig', () => {
  assert.deepEqual(run(delivery([challenge()])), []);
});

/** Verhalten: Ungültige Tageszahl erzeugt keinen Folgefehler IMPULSE_COUNT. */
test('days 0 mit 7 Impulsen: nur OUT_OF_RANGE, kein IMPULSE_COUNT', () => {
  assert.deepEqual(run(delivery([challenge({ stages: [stage(7, { days: 0 })] })])), only('OUT_OF_RANGE', `${ST}/days`));
});

/** Verhalten: days kein Zahlentyp erzeugt keinen Folgefehler. */
test('days als Text: nur FIELD_TYPE, kein IMPULSE_COUNT', () => {
  assert.deepEqual(run(delivery([challenge({ stages: [stage(7, { days: '7' })] })])), only('FIELD_TYPE', `${ST}/days`));
});

/** Verhalten: Ungültiges Startdatum erzeugt keinen Folgefehler START_IN_PAST. */
test('startDate 31. November: nur INVALID_DATE', () => {
  assert.deepEqual(run(delivery([challenge({ startDate: '2026-11-31' })])), only('INVALID_DATE', `${CH}/startDate`));
});

/** Verhalten: Ungültiges createdAt erzeugt keinen START_IN_PAST, auch bei altem Start. */
test('createdAt ungültig: kein START_IN_PAST und kein OUT_OF_RANGE am Start', () => {
  for (const startDate of ['2026-11-14', '2020-01-01', '2030-01-01']) {
    const codes = codesOf(delivery([challenge({ startDate })], { createdAt: 'gestern' }));
    assert.ok(!codes.includes('START_IN_PAST') && !codes.includes('KIND_UNKNOWN'), `${startDate}: ${codes}`);
    const errs = validateDelivery(delivery([challenge({ startDate })], { createdAt: 'gestern' })).errors;
    assert.ok(!errs.some((e) => e.path === `${CH}/startDate`), `${startDate}: Fehler am Start`);
  }
});

/** Verhalten: Start genau am Vortag des UTC-Tags von createdAt ist gültig. */
test('Start am Vortag von createdAt: gültig', () => {
  assert.deepEqual(run(delivery([challenge({ startDate: '2026-11-12' })])), []);
});

/** Verhalten: Start zwei Tage vor createdAt ist ungültig. */
test('Start zwei Tage vor createdAt: START_IN_PAST', () => {
  assert.deepEqual(run(delivery([challenge({ startDate: '2026-11-11' })])), only('START_IN_PAST', `${CH}/startDate`));
});

/** Verhalten: Start am createdAt-Tag selbst und 30 Tage danach sind gültig, 31 Tage danach nicht. */
test('Start heute gültig, +30 gültig, +31 OUT_OF_RANGE', () => {
  assert.deepEqual(run(delivery([challenge({ startDate: '2026-11-13' })])), []);
  assert.deepEqual(run(delivery([challenge({ startDate: '2026-12-13' })])), []);
  assert.deepEqual(run(delivery([challenge({ startDate: '2026-12-14' })])), only('OUT_OF_RANGE', `${CH}/startDate`));
});

/** Verhalten: Ein Impuls ohne Nachfrage ist gültig. */
test('Impuls ohne question ist gültig', () => {
  const { question, ...bare } = impulse(1);
  void question;
  const st = stage(7);
  (st.content as { impulses: unknown[] }).impulses[0] = bare;
  assert.deepEqual(run(delivery([challenge({ stages: [st] })])), []);
});

/** Verhalten: content ohne Objekt ist ein Typfehler. */
test('content als Text: FIELD_TYPE an content', () => {
  assert.deepEqual(run(delivery([challenge({ stages: [stage(7, { content: 'impulses' })] })])), only('FIELD_TYPE', `${ST}/content`));
});

/** Verhalten: impulses ohne Liste ist ein Typfehler, ohne IMPULSE_COUNT. */
test('impulses als Objekt: FIELD_TYPE an impulses', () => {
  const st = stage(7, { content: { type: 'impulses', impulses: { text: 'x' } } });
  assert.deepEqual(run(delivery([challenge({ stages: [st] })])), only('FIELD_TYPE', IMP));
});

/** Verhalten: Zu wenige und zu viele Impulse ergeben IMPULSE_COUNT an der Liste. */
test('Impulse: sechs bei sieben Tagen und acht bei sieben Tagen -> IMPULSE_COUNT', () => {
  for (const n of [6, 8]) {
    const st = stage(7, { content: { type: 'impulses', impulses: Array.from({ length: n }, (_, i) => impulse(i + 1)) } });
    assert.deepEqual(run(delivery([challenge({ stages: [st] })])), only('IMPULSE_COUNT', IMP), `n=${n}`);
  }
});

/** Verhalten: Bis zu sechs Stufen sind gültig, sieben sind zu viele (LIST_SIZE). */
test('Stufen: sechs gültig, sieben LIST_SIZE', () => {
  assert.deepEqual(run(delivery([challenge({ stages: Array.from({ length: 6 }, () => stage(3)) })])), []);
  assert.deepEqual(run(delivery([challenge({ stages: Array.from({ length: 7 }, () => stage(3)) })])), only('LIST_SIZE', `${CH}/stages`));
});

/** Verhalten: Zwei Stufen sind gültig; Fehler in Stufe 2 werden einzeln gemeldet. */
test('zwei Stufen: gültig, Fehler in Stufe 2 trotzdem gemeldet', () => {
  assert.deepEqual(run(delivery([challenge({ stages: [stage(7), stage(7)] })])), []);
  const bad = stage(7);
  (bad.content as { impulses: Record<string, unknown>[] }).impulses[0] = impulse(1, { text: '' });
  assert.deepEqual(run(delivery([challenge({ stages: [stage(7), bad] })])), only('TEXT_EMPTY', `${CH}/stages/1/content/impulses/0/text`));
});

/** Verhalten: Ungültige days in zwei Stufen werden beide einzeln gemeldet, ohne Folgefehler. */
test('zwei Stufen mit ungültigen days: beide OUT_OF_RANGE', () => {
  assert.deepEqual(run(delivery([challenge({ stages: [stage(7, { days: 0 }), stage(7, { days: 91 })] })])), [
    ...only('OUT_OF_RANGE', `${CH}/stages/0/days`),
    ...only('OUT_OF_RANGE', `${CH}/stages/1/days`),
  ].sort());
});

/** Verhalten: Summe der Tage über 90 -> TOTAL_TOO_LONG am Eintrag. */
test('Stufen: Summe 91 -> TOTAL_TOO_LONG, Summe 90 gültig', () => {
  assert.deepEqual(run(delivery([challenge({ stages: [stage(45), stage(45)] })])), []);
  assert.deepEqual(run(delivery([challenge({ stages: [stage(45), stage(46)] })])), only('TOTAL_TOO_LONG', CH));
});

/** Verhalten: Ungültige days in einer Stufe -> kein Folgefehler TOTAL_TOO_LONG. */
test('Summe mit ungültigem days in einer Stufe: kein TOTAL_TOO_LONG', () => {
  assert.deepEqual(run(delivery([challenge({ stages: [stage(90), stage(7, { days: 0 })] })])), only('OUT_OF_RANGE', `${CH}/stages/1/days`));
  assert.deepEqual(run(delivery([challenge({ stages: [stage(90), stage(7, { days: '7' })] })])), only('FIELD_TYPE', `${CH}/stages/1/days`));
});

// ---------- B6a: Tracker und Ziel-Stufen ----------

const TR = '/items/0';
const GS = `${CH}/stages/0/content/goal`;

/** Verhalten: Der Basis-Tracker und eine Ziel-Stufe sind gültig. */
test('Basis-Tracker und Ziel-Stufe sind gültig', () => {
  assert.deepEqual(run(delivery([tracker()])), []);
  assert.deepEqual(run(delivery([challenge({ stages: [goalStage()] })])), []);
});

/** Verhalten: Ungültiger mode erzeugt keine Folgefehler an dailyGoal oder levels. */
test('mode ungültig: nur VALUE_NOT_ALLOWED am mode, keine Folgefehler', () => {
  assert.deepEqual(run(delivery([tracker({ mode: 'bogus', dailyGoal: 0 })])), only('VALUE_NOT_ALLOWED', `${TR}/mode`));
  assert.deepEqual(run(delivery([tracker({ mode: 'bogus', levels: [] })])), only('VALUE_NOT_ALLOWED', `${TR}/mode`));
  assert.deepEqual(run(delivery([tracker({ mode: 'bogus', dailyGoal: undefined, joker: { earnEveryDays: 7, maxOnHand: 3 } })])), only('VALUE_NOT_ALLOWED', `${TR}/mode`));
});

/** Verhalten: Ungültiger type -> mode wird nicht gegen den Typ geprüft. */
test('type ungültig: nur VALUE_NOT_ALLOWED am type, mode nicht gegen Typ geprüft', () => {
  assert.deepEqual(run(delivery([tracker({ type: 'bogus', mode: 'counter' })])), only('VALUE_NOT_ALLOWED', `${TR}/type`));
  assert.deepEqual(run(delivery([tracker({ type: 'bogus', mode: 'awareness', dailyGoal: undefined })])), only('VALUE_NOT_ALLOWED', `${TR}/type`));
});

/** Verhalten: Dublette der Stufennamen und fehlende Erfolgsstufe gleichzeitig -> beide Fehler. */
test('levels: Dublette und keine Erfolgsstufe ergeben beide Fehler', () => {
  const levels = [
    { name: 'Gleich', icon: '⚠️', effect: 'needsGrace' },
    { name: 'gleich', icon: '❌', effect: 'breaksStreak' },
  ];
  assert.deepEqual(run(delivery([tracker({ mode: 'levels', dailyGoal: undefined, levels })])), [
    ...only('DUPLICATE_VALUE', `${TR}/levels/1/name`),
    ...only('LEVELS_NO_SUCCESS', `${TR}/levels`),
  ].sort());
});

/** Verhalten: Ziel-Tracker aus derselben Lieferung ist gültig. */
test('Ziel-Tracker in derselben Lieferung: gültig', () => {
  const items = [tracker(), challenge({ itemId: 'claude.test-plan', stages: [goalStage(7, { type: 'tracker', trackerId: 'claude.test-tracker' })] })];
  assert.deepEqual(run(delivery(items)), []);
});

/** Verhalten: Eine Übung derselben Lieferung ist kein Tracker. */
test('Ziel-Tracker zeigt auf Übung derselben Lieferung: TARGET_UNKNOWN', () => {
  const items = [exercise(), challenge({ itemId: 'claude.test-plan', stages: [goalStage(7, { type: 'tracker', trackerId: 'claude.test-uebung' })] })];
  assert.deepEqual(run(delivery(items)), only('TARGET_UNKNOWN', `/items/1/stages/0/content/goal/trackerId`));
});

/** Verhalten: Ohne knownTrackers ist builtin.noalc unbekannt, mit Kontext bekannt. */
test('knownTrackers fehlt: builtin.noalc ist unbekannt', () => {
  const ch = challenge({ stages: [goalStage(7, { type: 'tracker', trackerId: 'builtin.noalc' })] });
  assert.deepEqual(run(delivery([ch])), only('TARGET_UNKNOWN', `${GS}/trackerId`));
  assert.deepEqual(run(delivery([ch]), {}), only('TARGET_UNKNOWN', `${GS}/trackerId`));
  assert.deepEqual(run(delivery([ch]), { knownTrackers: ['builtin.noalc'] } as unknown as Ctx), []);
});

/** Verhalten: Ziel-Stufe ohne goal -> FIELD_MISSING am goal. */
test('Ziel-Stufe ohne goal: FIELD_MISSING', () => {
  const st = stage(7, { content: { type: 'goal' } });
  assert.deepEqual(run(delivery([challenge({ stages: [st] })])), only('FIELD_MISSING', GS));
});

// ---------- B6a-Nachtrag: keepStartDate ----------

const keepCtx = (keepStartDate: string): Ctx => ({ keepStartDate }) as unknown as Ctx;

/** Verhalten: Start 5 Tage vor createdAt ohne Kontext bleibt START_IN_PAST. */
test('keepStartDate: ohne Kontext ist Start 5 Tage vor createdAt START_IN_PAST', () => {
  assert.deepEqual(run(delivery([challenge({ startDate: '2026-11-08' })])), only('START_IN_PAST', `${CH}/startDate`));
});

/** Verhalten: Unverändertes Startdatum einer laufenden Challenge ist mit keepStartDate gültig. */
test('keepStartDate gleich startDate: gültig', () => {
  assert.deepEqual(run(delivery([challenge({ startDate: '2026-11-08' })]), keepCtx('2026-11-08')), []);
});

/** Verhalten: Anderes keepStartDate hebt die Prüfung nicht auf. */
test('keepStartDate anderes Datum: weiter START_IN_PAST', () => {
  assert.deepEqual(
    run(delivery([challenge({ startDate: '2026-11-08' })]), keepCtx('2026-11-07')),
    only('START_IN_PAST', `${CH}/startDate`),
  );
});

/** Verhalten: keepStartDate hebt die Obergrenze +30 Tage nicht auf. */
test('keepStartDate gleich startDate bei +31 Tagen: weiter OUT_OF_RANGE', () => {
  assert.deepEqual(
    run(delivery([challenge({ startDate: '2026-12-14' })]), keepCtx('2026-12-14')),
    only('OUT_OF_RANGE', `${CH}/startDate`),
  );
});
