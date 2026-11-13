import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateDelivery } from '../src/index.ts';
import { breath, delivery, exercise, key, program, withdrawal } from './helpers.ts';

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
