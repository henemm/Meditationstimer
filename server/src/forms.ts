// Verträge für die Lesewerkzeuge (B2a-4): der Bauplan wird aus dem Lieferformat abgeleitet (eine einzige Quelle der Grenzen),
// die eingebauten Übungen kommen aus dem Katalog. Im Image liegen beide unter /app/Contracts, im Repo an derselben Stelle relativ zu server/.
import { readFileSync } from "node:fs";
import { join } from "node:path";

const contracts = join(import.meta.dirname, "..", "..", "Contracts");
const schema = JSON.parse(readFileSync(join(contracts, "schema", "delivery-v1.schema.json"), "utf8"));

export type CatalogExercise = { id: string; name: string; category: string };
export const builtinExercises: CatalogExercise[] =
  JSON.parse(readFileSync(join(contracts, "catalog", "builtin-exercises.json"), "utf8")).exercises;

export const CATEGORY_NAMES: Record<string, string> = {
  strength: "Kraft", stretching: "Dehnung", core: "Core", cardio: "Cardio", legs: "Beine", upperBody: "Oberkörper",
  fullBody: "Ganzkörper", warmup: "Aufwärmen", cooldown: "Cool-Down",
};

type Node = Record<string, any>;

// Einen "$ref" auf "#/$defs/…" auflösen; alles andere bleibt, wie es ist.
function resolve(node: Node): Node {
  const ref: unknown = node.$ref;
  return typeof ref === "string" ? resolve(schema.$defs[ref.replace("#/$defs/", "")]) : node;
}

// Das Feld in knapper Form: Typ, Grenzen, erlaubte Werte, bei Listen die Felder der Einträge.
function describe(name: string, node: Node, required: boolean): Node {
  const def = resolve(node);
  const values: unknown[] | undefined = def.enum ?? (def.const === undefined ? undefined : [def.const]);
  const field: Node = { name, required, type: values !== undefined ? "enum" : def.type };
  for (const key of ["minimum", "maximum", "minLength", "maxLength", "minItems", "maxItems"]) {
    if (def[key] !== undefined) field[key] = def[key];
  }
  if (values !== undefined) field.values = values;
  if (def.type === "array") field.items = fieldsOf(resolve(def.items));
  // Verschachtelte Objekte (Stufe, Inhalt, Impuls der Challenge) werden mit ihren Feldern gezeigt; Listen von Objekten ebenso.
  if (def.type === "object" && (def.properties !== undefined || def.allOf !== undefined)) field.fields = fieldsOf(def);
  return field;
}

// Bedingte Felder (allOf → if/then): zusätzlich zu den festen Feldern, mit dem Hinweis, wann sie gelten; schon bekannte Namen bleiben unberührt.
function conditionalFields(def: Node, known: Set<string>): Node[] {
  const out: Node[] = [];
  for (const branch of def.allOf ?? []) {
    const then: Node = branch.then ?? {};
    const [key, cond] = Object.entries<Node>(branch.if?.properties ?? {})[0] ?? [];
    const values: unknown[] | undefined = cond?.const === undefined ? cond?.enum : [cond.const];
    for (const [name, node] of Object.entries<Node>(then.properties ?? {})) {
      if (known.has(name) || Object.keys(node).length === 0) continue;
      known.add(name);
      const when = key === undefined || values === undefined ? {} : { when: `${key} = ${values.join(" | ")}` };
      out.push({ ...describe(name, node, (then.required ?? []).includes(name)), ...when });
    }
  }
  return out;
}

function fieldsOf(def: Node, skip: string[] = []): Node[] {
  const required: string[] = def.required ?? [];
  const fixed = Object.entries<Node>(def.properties ?? {})
    .filter(([name]) => !skip.includes(name))
    .map(([name, node]) => describe(name, node, required.includes(name)));
  return [...fixed, ...conditionalFields(def, new Set(Object.keys(def.properties ?? {})))];
}

export type FormKind = "exercise" | "program" | "breath" | "reminder" | "challenge" | "tracker" | "withdrawal";
export const FORM_KINDS: [FormKind, ...FormKind[]] = ["exercise", "program", "breath", "reminder", "challenge", "tracker", "withdrawal"];

const ASSIGNED = ["kind", "itemId", "revision"];
const NOTES: Record<FormKind, string> = {
  exercise: "Kennung (itemId), Fassung (revision) und Zeitpunkt vergibt der Dienst.",
  program: "Kennung (itemId), Fassung (revision) und Zeitpunkt vergibt der Dienst. Schritte verweisen auf Übungen per Kennung (exerciseId).",
  breath: "Kennung (itemId), Fassung (revision) und Zeitpunkt vergibt der Dienst.",
  reminder: "Kennung (itemId), Fassung (revision) und Zeitpunkt vergibt der Dienst. Uhrzeit hh:mm in Ortszeit des Geräts; weekdays aus monday bis sunday, ohne Doppelte; "
    + "lookbackHours 1 bis 24; target: {type: meditation | noalc}, {type: workout, programId?} oder {type: breath, breathId}, Ziele müssen es geben. "
    + "Höchstens sechs Erinnerungen von Claude gleichzeitig.",
  challenge: "Kennung (itemId), Fassung (revision) und Zeitpunkt vergibt der Dienst. 1 bis 6 Stufen, zusammen höchstens 90 Tage; je Stufe days 1 bis 90 und content: "
    + "{type: impulses, impulses} (genau so viele Impulse wie Tage, einer je Tag in Tagesreihenfolge: text, moment day oder evening, question optional) oder "
    + "{type: goal, goal}: goal {type: meditation | workout, minutes 1 bis 180} oder {type: tracker, trackerId} (trackerId aus catalog kind tracker, einer eigenen Lieferung, "
    + "oder builtin.noalc für den eingebauten NoAlc-Tracker). Ein Tag gilt als erreicht, wenn die Minuten erreicht sind bzw. der Tag beim Tracker nach dessen Regeln gelungen ist. "
    + "startDate JJJJ-MM-TT, frühestens der Tag vor dem Liefertag, höchstens 30 Tage danach. Ausgelassene Tage sind neutral.",
  tracker: "Kennung (itemId), Fassung (revision) und Zeitpunkt vergibt der Dienst. Wie der Bildschirm „Eigener Tracker“, ohne Kopplung an Apple Health. "
    + "type good: mode counter (dailyGoal 1 bis 100), yesNo oder levels; type saboteur: mode awareness, avoidance oder levels. levels nur bei mode levels (2 bis 5 Stufen, "
    + "mindestens eine mit effect success), joker und dayStartHour nur bei levels. Vorhandene Tracker änderst du nicht; höchstens zwei neue Gewohnheiten gleichzeitig (overview.building).",
  withdrawal: "Genau eines von itemId oder packageId.",
};

// Bauplan: je Art die Felder mit Pflicht, Typ, Grenzen und erlaubten Werten; Kategorien mit deutschem Namen.
export function buildForms(kind?: FormKind): Node {
  const kinds = kind === undefined ? FORM_KINDS : [kind];
  const forms = Object.fromEntries(kinds.map((k) => [k, {
    note: NOTES[k], fields: fieldsOf(resolve({ $ref: `#/$defs/${k}` }), k === "withdrawal" ? ["kind"] : ASSIGNED),
  }]));
  const showCategories = kind === undefined || kind === "exercise";
  return {
    forms,
    ...(showCategories ? { categories: Object.entries(CATEGORY_NAMES).map(([id, name]) => ({ id, name })) } : {}),
    note: "Texte ohne Steuerzeichen; symbol ist ein Emoji ohne Buchstaben und Ziffern.",
  };
}
