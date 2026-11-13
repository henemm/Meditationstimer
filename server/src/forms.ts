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
  const field: Node = { name, required, type: def.enum !== undefined ? "enum" : def.type };
  for (const key of ["minimum", "maximum", "minLength", "maxLength", "minItems", "maxItems"]) {
    if (def[key] !== undefined) field[key] = def[key];
  }
  if (def.enum !== undefined) field.values = def.enum;
  if (def.type === "array") field.items = fieldsOf(resolve(def.items));
  return field;
}

function fieldsOf(def: Node, skip: string[] = []): Node[] {
  const required: string[] = def.required ?? [];
  return Object.entries<Node>(def.properties ?? {})
    .filter(([name]) => !skip.includes(name))
    .map(([name, node]) => describe(name, node, required.includes(name)));
}

export type FormKind = "exercise" | "program" | "breath" | "reminder" | "withdrawal";
export const FORM_KINDS: [FormKind, ...FormKind[]] = ["exercise", "program", "breath", "reminder", "withdrawal"];

const ASSIGNED = ["kind", "itemId", "revision"];
const NOTES: Record<FormKind, string> = {
  exercise: "Kennung (itemId), Fassung (revision) und Zeitpunkt vergibt der Dienst.",
  program: "Kennung (itemId), Fassung (revision) und Zeitpunkt vergibt der Dienst. Schritte verweisen auf Übungen per Kennung (exerciseId).",
  breath: "Kennung (itemId), Fassung (revision) und Zeitpunkt vergibt der Dienst.",
  reminder: "Kennung (itemId), Fassung (revision) und Zeitpunkt vergibt der Dienst. Uhrzeit hh:mm in Ortszeit des Geräts; weekdays aus monday bis sunday, ohne Doppelte; "
    + "lookbackHours 1 bis 24; target: {type: meditation | noalc}, {type: workout, programId?} oder {type: breath, breathId}, Ziele müssen es geben. "
    + "Höchstens sechs Erinnerungen von Claude gleichzeitig.",
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
