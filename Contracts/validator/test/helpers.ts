import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

export const CONTRACTS_DIR = join(import.meta.dirname, '..', '..');
export const SCHEMA_PATH = join(CONTRACTS_DIR, 'schema', 'delivery-v1.schema.json');

export type ExpectedError = { code: string; path: string };
export type Example = {
  file: string;
  dir: 'valid' | 'invalid';
  description: string;
  context?: { knownExercises?: { id: string; name: string }[]; knownPrograms?: string[]; knownBreaths?: string[]; knownTrackers?: string[] };
  delivery: unknown;
  expected: {
    valid: boolean;
    errors?: ExpectedError[];
    reason?: string;
    remedy?: string;
    schemaRejects?: boolean;
  };
};

export function loadExamples(dir: 'valid' | 'invalid'): Example[] {
  const folder = join(CONTRACTS_DIR, 'deliveries', dir);
  return readdirSync(folder)
    .filter((f) => f.endsWith('.json'))
    .sort()
    .map((f) => {
      const parsed = JSON.parse(readFileSync(join(folder, f), 'utf8'));
      return { file: f, dir, ...parsed } as Example;
    });
}

export function key(e: { code: string; path: string }): string {
  return `${e.code} @ ${e.path}`;
}

// ---- Bausteine für gezielte Regeltests (jeder Baustein für sich gültig) ----

type Obj = Record<string, unknown>;

export function exercise(over: Obj = {}): Obj {
  return {
    kind: 'exercise',
    itemId: 'claude.test-uebung',
    revision: 1,
    name: 'Testübung',
    category: 'core',
    effect: 'Stärkt den Rumpf.',
    instructions: 'Langsam und kontrolliert ausführen.',
    ...over,
  };
}

export function program(over: Obj = {}): Obj {
  return {
    kind: 'program',
    itemId: 'claude.test-programm',
    revision: 1,
    name: 'Testprogramm',
    symbol: '🏃',
    rounds: 2,
    steps: [{ exerciseId: 'builtin.burpees', workSeconds: 30, restSeconds: 10 }],
    ...over,
  };
}

export function breath(over: Obj = {}): Obj {
  return {
    kind: 'breath',
    itemId: 'claude.test-atmung',
    revision: 1,
    name: 'Testatmung',
    symbol: '🌬',
    inhaleSeconds: 4,
    holdInSeconds: 4,
    exhaleSeconds: 4,
    holdOutSeconds: 4,
    rounds: 5,
    ...over,
  };
}

export function reminder(over: Obj = {}): Obj {
  return {
    kind: 'reminder',
    itemId: 'claude.test-erinnerung',
    revision: 1,
    title: 'Testerinnerung',
    message: 'Zeit für eine Pause.',
    time: '18:00',
    weekdays: ['monday', 'thursday'],
    lookbackHours: 12,
    target: { type: 'meditation' },
    ...over,
  };
}

export function impulse(n: number, over: Obj = {}): Obj {
  return { text: `Tag ${n}: Achte heute einmal bewusst auf deinen Atem.`, moment: 'day', question: 'Was ist dir aufgefallen?', ...over };
}

export function stage(days = 7, over: Obj = {}): Obj {
  return {
    days,
    content: { type: 'impulses', impulses: Array.from({ length: days }, (_, i) => impulse(i + 1)) },
    ...over,
  };
}

export function challenge(over: Obj = {}): Obj {
  return {
    kind: 'challenge',
    itemId: 'claude.test-challenge',
    revision: 1,
    title: 'Testchallenge',
    symbol: '🧘',
    startDate: '2026-11-14',
    stages: [stage(7)],
    ...over,
  };
}

export function tracker(over: Obj = {}): Obj {
  const t: Obj = {
    kind: 'tracker',
    itemId: 'claude.test-tracker',
    revision: 1,
    name: 'Testtracker',
    symbol: '💧',
    type: 'good',
    mode: 'counter',
    dailyGoal: 6,
    ...over,
  };
  // undefined in over entfernt das Feld
  for (const k of Object.keys(t)) if (t[k] === undefined) delete t[k];
  return t;
}

export function goalStage(days = 7, goal: Obj = { type: 'meditation', minutes: 10 }, over: Obj = {}): Obj {
  return { days, content: { type: 'goal', goal }, ...over };
}

export function withdrawal(over: Obj = {}): Obj {
  return { kind: 'withdrawal', itemId: 'claude.test-uebung', ...over };
}

export function delivery(items: unknown[], over: Obj = {}): Obj {
  return {
    format: 'hhhaven.delivery/1',
    deliveryId: '6f1c2a9e-3b7d-4c11-9a0e-5d2f8b4e7a10',
    source: 'claude',
    createdAt: '2026-11-13T10:15:00Z',
    why: 'Ein kurzer Grund für die Lieferung.',
    items,
    ...over,
  };
}
