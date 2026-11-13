// Übernommen aus loose-ends server/src/mcp.ts @ 24a6da6 (Muster: zustandslos, createMcpHandler, frischer McpServer je Anfrage,
// Konto nur aus authInfo, Lesewerkzeug-Hülle "reading"); angepasst: Werkzeuge für Bausteine und Lieferungen (B2a-4 Lesen, B2a-5 Liefern).
import type pg from "pg";
import { createMcpHandler, McpServer, type CallToolResult, type McpHttpHandler, type ServerContext } from "@modelcontextprotocol/server";
import { z } from "zod";
import { listDeliveries, openDeliveries, recentRejections } from "./deliveries.ts";
import { buildForms, FORM_KINDS } from "./forms.ts";
import { historyDoc, type HistoryArgs } from "./history.ts";
import { catalogDoc, deliveryStatusDoc, overviewDoc, showDoc, type Kind } from "./read-tools.ts";
import { getTranscript } from "./transcripts.ts";
import { createItem, reportWish, updateItem, withdrawItem, type Doc } from "./write-tools.ts";

// Die elf Grundregeln aus DOCS/konzept-claude-verbindung.md Abschnitt 10, wörtlich, dazu die zwei Zusätze der Spec.
export const INSTRUCTIONS = [
  "Grundregeln:",
  "1. Beginne mit `overview` und nenne Meldungen zuerst.",
  "2. Lies vor dem ersten Liefern den Bauplan und den Katalog. Nutze Vorhandenes, bevor du Neues anlegst.",
  "3. Lass dir vor jedem Liefern bestätigen, was genau du lieferst.",
  "4. Sage „liegt bereit\", solange die App nicht bestätigt hat, und „ist in der App\" erst danach.",
  "5. Nenne Namen, keine Kennungen.",
  "6. Du löschst nie. Du ziehst nur eigene Lieferungen zurück und sagst, wie es zurückgeht.",
  "7. Hennings eigene und die mitgelieferten Inhalte änderst du nicht. Biete eine Kopie an.",
  "8. Lehnt der Dienst ab, gib den Grund weiter und korrigiere.",
  "9. Du startest nichts und trägst nichts ein. Das Eintragen ist Hennings Übung.",
  "10. Impulse laden ein und bewerten nicht. Kein Leistungsdruck, keine Schuld.",
  "11. Trainings sind Vorschläge und kein medizinischer Rat. Halte dich an genannte Einschränkungen und frage im Zweifel nach.",
  "",
  "Werkzeuge zum Lesen: `overview`, `catalog`, `show`, `forms` (der Bauplan), `delivery_status` und `history` (Rückblick auf die Einheiten der letzten 90 Tage).",
  "Werkzeuge zum Liefern: `exercise_define`, `program_create`, `breath_create`, `item_update`, `item_withdraw` und `wish_report`.",
  "Lieferungen erscheinen beim nächsten Öffnen von Healthy Habits.",
  "Trainings sind Vorschläge von Claude und kein medizinischer Rat.",
].join("\n");

const reply = (text: string): CallToolResult => ({ content: [{ type: "text", text }] });
const refusal = (text: string): CallToolResult => ({ ...reply(text), isError: true });

// Das Konto kommt nur aus authInfo (B2b füllt es aus einem echten Token); der Handler prüft selbst keinen Token.
function account(ctx: ServerContext): string | undefined {
  const value = ctx.http?.authInfo?.extra?.account;
  return typeof value === "string" && value !== "" ? value : undefined;
}

// Werkzeug-Hülle: ohne Konto Ablehnung vor jedem Zugriff; ein String vom Werkzeug ist eine Ablehnung, alles andere die JSON-Antwort.
function guarded<A = Record<string, never>>(run: (owner: string, args: A) => Promise<unknown>) {
  return async (args: A, ctx: ServerContext): Promise<CallToolResult> => {
    const owner = account(ctx);
    if (owner === undefined) return refusal("kein Konto");
    const out = await run(owner, args);
    return typeof out === "string" ? refusal(out) : reply(JSON.stringify(out));
  };
}

const ReadOnly = { readOnlyHint: true };
// Lieferwerkzeuge legen etwas ab, löschen nichts und sind nicht wiederholbar (jeder Aufruf ist eine neue Lieferung).
const Writes = { readOnlyHint: false, destructiveHint: false, idempotentHint: false };

// Eingabeschemas der Lieferwerkzeuge: Felder für Claude beschrieben, aber jeder Wert und jedes weitere Feld geht durch (passthrough, unknown);
// die eigentliche Prüfung macht validateDelivery, damit Claude dieselben Gründe und Auswege bekommt wie die App (genaue Grenzen: `forms`).
const field = (text: string) => z.unknown().optional().describe(text);
const WHY = field("Pflicht: warum Claude das liefert, höchstens 300 Zeichen, eine Zeile");
const PACKAGE = field("Optional: Paketname (höchstens 40 Zeichen), um zusammengehörige Bausteine gemeinsam zurückziehen zu können");
const NAME = field("Pflicht: Name, höchstens 40 Zeichen");
const SYMBOL = field("Pflicht: ein Emoji ohne Buchstaben und Ziffern");
const DESCRIPTION = field("Optional: Beschreibung, höchstens 500 Zeichen");
const ROUNDS = field("Pflicht: Runden, ganze Zahl 1 bis 99");
const EXERCISE_FIELDS = {
  name: NAME, nameEn: field("Optional: englischer Name, höchstens 40 Zeichen"),
  category: field("Pflicht: strength, stretching, core, cardio, legs, upperBody, fullBody, warmup oder cooldown"),
  effect: field("Pflicht: Wirkung, höchstens 600 Zeichen"), instructions: field("Pflicht: Anleitung, höchstens 1500 Zeichen"),
  notes: field("Optional: Hinweise, höchstens 600 Zeichen"),
};
const PROGRAM_FIELDS = {
  name: NAME, symbol: SYMBOL, description: DESCRIPTION, rounds: ROUNDS,
  steps: field("Pflicht: 1 bis 40 Schritte {exerciseId, workSeconds 1-600, restSeconds 0-600, hint?}; exerciseId aus catalog oder einer eigenen Lieferung"),
};
const BREATH_FIELDS = {
  name: NAME, symbol: SYMBOL, description: DESCRIPTION, rounds: ROUNDS,
  inhaleSeconds: field("Pflicht: Einatmen in Sekunden, 1 bis 60"), holdInSeconds: field("Pflicht: Halten nach dem Einatmen, 0 bis 60"),
  exhaleSeconds: field("Pflicht: Ausatmen in Sekunden, 1 bis 60"), holdOutSeconds: field("Pflicht: Halten nach dem Ausatmen, 0 bis 60"),
};
const loose = (shape: z.ZodRawShape) => z.looseObject({ ...shape, why: WHY, package: PACKAGE });
const Kinds = z.enum(["exercise", "program", "breath"]);

// Zustandslos: für jede Anfrage ein frischer Server mit den Lesewerkzeugen, nichts wird zwischengespeichert.
export function mcpHandler(pool: pg.Pool): McpHttpHandler {
  return createMcpHandler(() => {
    const server = new McpServer({ name: "healthy-habits", version: "1" }, { instructions: INSTRUCTIONS });
    server.registerTool("overview", {
      description: "Einstieg: Meldungen zuerst (abgelehnte oder lange wartende Lieferungen, fehlende oder alte Abschrift), dann der Bestand in Zahlen je Art und Herkunft",
      inputSchema: z.object({}), annotations: ReadOnly,
    }, guarded(async (owner) => overviewDoc(
      await getTranscript(pool, owner), await openDeliveries(pool, owner), await recentRejections(pool, owner, 14), new Date())));
    server.registerTool("catalog", {
      description: "Bausteine einer Art auflisten oder suchen (Übungen, Programme, Atemübungen); Suche ohne Groß-/Kleinschreibung und Akzente, alle Wörter müssen vorkommen",
      inputSchema: z.object({ kind: Kinds, query: z.string().max(100).optional(), origin: z.enum(["builtin", "own", "claude"]).optional() }),
      annotations: ReadOnly,
    }, guarded<{ kind: Kind; query?: string; origin?: "builtin" | "own" | "claude" }>(async (owner, args) =>
      catalogDoc(await getTranscript(pool, owner), args)));
    server.registerTool("show", {
      description: "Einen Baustein vollständig zeigen, mit Herkunft, Stand und offenen Lieferungen dazu; die Kennung liefert catalog",
      inputSchema: z.object({ id: z.string().max(100) }), annotations: ReadOnly,
    }, guarded<{ id: string }>(async (owner, { id }) =>
      showDoc(await getTranscript(pool, owner), id, await openDeliveries(pool, owner)) ?? "Nicht gefunden; Kennungen liefert catalog"));
    server.registerTool("forms", {
      description: "Bauplan: Felder, Grenzen und erlaubte Werte je Baustein (Übung, Programm, Atemübung, Rücknahme), dazu die Kategorien mit deutschem Namen",
      inputSchema: z.object({ kind: z.enum(FORM_KINDS).optional() }), annotations: ReadOnly,
    }, guarded<{ kind?: (typeof FORM_KINDS)[number] }>(async (_owner, { kind }) => buildForms(kind)));
    server.registerTool("delivery_status", {
      description: "Ist eine Lieferung angekommen? Eine Lieferung (deliveryId) oder die letzten 20: waiting (wartet), in_app (abgeholt), accepted, rejected mit Gründen, withdrawn",
      inputSchema: z.object({ deliveryId: z.string().max(100).optional() }), annotations: ReadOnly,
    }, guarded<{ deliveryId?: string }>(async (owner, { deliveryId }) => {
      const rows = await listDeliveries(pool, owner, { limit: 20, ...(deliveryId === undefined ? {} : { deliveryId }) });
      return rows.length === 0 && deliveryId !== undefined ? "Lieferung nicht gefunden" : deliveryStatusDoc(rows);
    }));
    server.registerTool("history", {
      description: "Rückblick: Einheiten (Meditation, Workout, Atemübung) mit Dauer, Abbruch und Rückmeldung nach dem Training, Zusammenfassung und Serien; Zeitraum from/to als JJJJ-MM-TT (UTC, höchstens 90 Tage, Vorgabe die letzten 30 Tage), Filter kind und programId",
      inputSchema: z.object({ from: z.string().max(20).optional(), to: z.string().max(20).optional(), kind: z.string().max(20).optional(), programId: z.string().max(100).optional() }),
      annotations: ReadOnly,
    }, guarded<HistoryArgs>(async (owner, args) => historyDoc(await getTranscript(pool, owner), args)));
    registerWriteTools(server, pool);
    return server;
  });
}

// Die sechs Lieferwerkzeuge; jede Antwort ist JSON, jede Ablehnung ein Text mit Grund und Ausweg (nichts ist dann gespeichert).
function registerWriteTools(server: McpServer, pool: pg.Pool): void {
  const create = (kind: Kind) => guarded<Doc>((owner, args) => createItem(pool, owner, kind, args));
  server.registerTool("exercise_define", {
    description: "Neue Übung für Henning liefern (Lieferung erscheint beim nächsten Öffnen der App); vorher Bauplan (forms) und Katalog lesen und Henning bestätigen lassen",
    inputSchema: loose(EXERCISE_FIELDS), annotations: Writes,
  }, create("exercise"));
  server.registerTool("program_create", {
    description: "Neues Programm aus Übungen liefern (Schritte verweisen per Kennung auf Übungen); vorher forms und catalog lesen und Henning bestätigen lassen",
    inputSchema: loose(PROGRAM_FIELDS), annotations: Writes,
  }, create("program"));
  server.registerTool("breath_create", {
    description: "Neue Atemübung liefern (Ein-, Halte- und Ausatemzeiten in Sekunden); vorher forms lesen und Henning bestätigen lassen",
    inputSchema: loose(BREATH_FIELDS), annotations: Writes,
  }, create("breath"));
  server.registerTool("item_update", {
    description: "Einen eigenen Baustein von Claude ändern: neue vollständige Fassung in fields; basedOnRevision ist die Fassung, die du zuletzt mit show gelesen hast",
    inputSchema: z.looseObject({
      itemId: field("Pflicht: Kennung des Bausteins (claude.…)"), basedOnRevision: field("Pflicht: zuletzt gelesene Fassung, ganze Zahl"), why: WHY,
      fields: field("Pflicht: vollständige neue Fassung wie bei der Erstellung, ohne why und package (das Paket bleibt)"),
    }), annotations: Writes,
  }, guarded<Doc>((owner, args) => updateItem(pool, owner, args)));
  server.registerTool("item_withdraw", {
    description: "Einen eigenen Baustein oder ein ganzes Paket von Claude zurückziehen (genau eins von itemId oder package); wartende Lieferungen werden überholt, nichts wird gelöscht",
    inputSchema: z.looseObject({ itemId: field("Kennung des Bausteins (claude.…), oder"), package: field("Paketname, nicht beides"), why: WHY }),
    annotations: Writes,
  }, guarded<Doc>((owner, args) => withdrawItem(pool, owner, args)));
  server.registerTool("wish_report", {
    description: "Einen Wunsch für Henning festhalten, den kein Werkzeug erfüllt (Text 1 bis 1000 Zeichen, Kontext optional bis 300)",
    inputSchema: z.looseObject({ text: field("Pflicht: der Wunsch"), context: field("Optional: Anlass, höchstens 300 Zeichen") }), annotations: Writes,
  }, guarded<Doc>((owner, args) => reportWish(pool, owner, args)));
}
