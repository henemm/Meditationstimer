// Übernommen aus loose-ends server/src/mcp.ts @ 24a6da6 (Muster: zustandslos, createMcpHandler, frischer McpServer je Anfrage,
// Konto nur aus authInfo, Lesewerkzeug-Hülle "reading"); angepasst: Werkzeuge für Bausteine und Lieferungen (B2a-4: nur Lesen).
import type pg from "pg";
import { createMcpHandler, McpServer, type CallToolResult, type McpHttpHandler, type ServerContext } from "@modelcontextprotocol/server";
import { z } from "zod";
import { listDeliveries, openDeliveries, recentRejections } from "./deliveries.ts";
import { buildForms, FORM_KINDS } from "./forms.ts";
import { catalogDoc, deliveryStatusDoc, overviewDoc, showDoc, type Kind } from "./read-tools.ts";
import { getTranscript } from "./transcripts.ts";

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
  "Werkzeuge zum Lesen: `overview`, `catalog`, `show`, `forms` (der Bauplan) und `delivery_status`.",
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

// Lesewerkzeug: ohne Konto Ablehnung vor jedem Lesen; ein String vom Werkzeug ist eine Ablehnung, alles andere die JSON-Antwort.
function reading<A = Record<string, never>>(run: (owner: string, args: A) => Promise<unknown>) {
  return async (args: A, ctx: ServerContext): Promise<CallToolResult> => {
    const owner = account(ctx);
    if (owner === undefined) return refusal("kein Konto");
    const out = await run(owner, args);
    return typeof out === "string" ? refusal(out) : reply(JSON.stringify(out));
  };
}

const ReadOnly = { readOnlyHint: true };
const Kinds = z.enum(["exercise", "program", "breath"]);

// Zustandslos: für jede Anfrage ein frischer Server mit den Lesewerkzeugen, nichts wird zwischengespeichert.
export function mcpHandler(pool: pg.Pool): McpHttpHandler {
  return createMcpHandler(() => {
    const server = new McpServer({ name: "healthy-habits", version: "1" }, { instructions: INSTRUCTIONS });
    server.registerTool("overview", {
      description: "Einstieg: Meldungen zuerst (abgelehnte oder lange wartende Lieferungen, fehlende oder alte Abschrift), dann der Bestand in Zahlen je Art und Herkunft",
      inputSchema: z.object({}), annotations: ReadOnly,
    }, reading(async (owner) => overviewDoc(
      await getTranscript(pool, owner), await openDeliveries(pool, owner), await recentRejections(pool, owner, 14), new Date())));
    server.registerTool("catalog", {
      description: "Bausteine einer Art auflisten oder suchen (Übungen, Programme, Atemübungen); Suche ohne Groß-/Kleinschreibung und Akzente, alle Wörter müssen vorkommen",
      inputSchema: z.object({ kind: Kinds, query: z.string().max(100).optional(), origin: z.enum(["builtin", "own", "claude"]).optional() }),
      annotations: ReadOnly,
    }, reading<{ kind: Kind; query?: string; origin?: "builtin" | "own" | "claude" }>(async (owner, args) =>
      catalogDoc(await getTranscript(pool, owner), args)));
    server.registerTool("show", {
      description: "Einen Baustein vollständig zeigen, mit Herkunft, Stand und offenen Lieferungen dazu; die Kennung liefert catalog",
      inputSchema: z.object({ id: z.string().max(100) }), annotations: ReadOnly,
    }, reading<{ id: string }>(async (owner, { id }) =>
      showDoc(await getTranscript(pool, owner), id, await openDeliveries(pool, owner)) ?? "Nicht gefunden; Kennungen liefert catalog"));
    server.registerTool("forms", {
      description: "Bauplan: Felder, Grenzen und erlaubte Werte je Baustein (Übung, Programm, Atemübung, Rücknahme), dazu die Kategorien mit deutschem Namen",
      inputSchema: z.object({ kind: z.enum(FORM_KINDS).optional() }), annotations: ReadOnly,
    }, reading<{ kind?: (typeof FORM_KINDS)[number] }>(async (_owner, { kind }) => buildForms(kind)));
    server.registerTool("delivery_status", {
      description: "Ist eine Lieferung angekommen? Eine Lieferung (deliveryId) oder die letzten 20: waiting (wartet), in_app (abgeholt), accepted, rejected mit Gründen, withdrawn",
      inputSchema: z.object({ deliveryId: z.string().max(100).optional() }), annotations: ReadOnly,
    }, reading<{ deliveryId?: string }>(async (owner, { deliveryId }) => {
      const rows = await listDeliveries(pool, owner, { limit: 20, ...(deliveryId === undefined ? {} : { deliveryId }) });
      return rows.length === 0 && deliveryId !== undefined ? "Lieferung nicht gefunden" : deliveryStatusDoc(rows);
    }));
    return server;
  });
}
