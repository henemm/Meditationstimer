// Übernommen aus loose-ends server/src/app-routes.ts @ 24a6da6 (Prüfreihenfolge, admitted, jsonBody, Körperlimit); angepasst:
// Konto über die eingereichte Funktion appAccount statt Sitzung, Lieferungen statt Aufträge, Ergebnis-Körper mit errors.
import type pg from "pg";
import { claimDelivery, reportResult, type ResultBody } from "./deliveries.ts";
import type { Route } from "./main.ts";
import { putTranscript } from "./transcripts.ts";

export type AppDeps = { pool: pg.Pool; appAccount: (request: Request) => Promise<string | undefined> };

const BODY_LIMIT = 256 * 1024;
const uuidForm = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Jede Antwort trägt no-store; eine Ablehnung hat keinen Körper und nennt nie, welche Prüfung fehlschlug.
const status = (code: number) => new Response(null, { status: code, headers: { "cache-control": "no-store" } });
const notAllowed = () => new Response(null, { status: 405, headers: { allow: "POST", "cache-control": "no-store" } });

function isJson(request: Request): boolean {
  const type = request.headers.get("content-type") ?? "";
  return type.split(";")[0].trim().toLowerCase() === "application/json";
}

// Der Körper als Text, beim Lesen gezählt (Content-Length kann lügen); null, sobald er das Limit überschreitet.
async function readLimited(request: Request): Promise<string | null> {
  if (request.body === null) return "";
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > BODY_LIMIT) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }
  return Buffer.concat(chunks).toString("utf8");
}

// Die Gerätekennung aus X-Device in Kleinbuchstaben, null wenn es keine UUID ist.
function device(request: Request): string | null {
  const value = request.headers.get("x-device") ?? "";
  return uuidForm.test(value) ? value.toLowerCase() : null;
}

type Checked = { account: string; device: string };

// Methode, dann Konto, dann Gerät: die erste Verletzung ist die Antwort, sonst Konto (und Gerät).
async function admitted(deps: AppDeps, request: Request, needDevice: boolean): Promise<Checked | Response> {
  if (request.method !== "POST") return notAllowed();
  const account = await deps.appAccount(request);
  if (account === undefined) return status(401);
  if (!needDevice) return { account, device: "" };
  const id = device(request);
  return id === null ? status(400) : { account, device: id };
}

// Inhaltstyp, Größe, dann JSON und Form; der Text der Prüfung verlässt den Dienst nie. Leerer Körper gilt als "kein Inhalt".
async function jsonBody(request: Request, check: (doc: unknown) => void, allowEmpty = false): Promise<{ doc: unknown } | Response> {
  if (!isJson(request)) return status(415);
  const raw = await readLimited(request);
  if (raw === null) return status(413);
  if (allowEmpty && raw.trim() === "") return { doc: undefined };
  try {
    const doc: unknown = JSON.parse(raw);
    check(doc);
    return { doc };
  } catch {
    return status(400);
  }
}

const isObject = (v: unknown): v is Record<string, unknown> => typeof v === "object" && v !== null && !Array.isArray(v);
const sizedText = (v: unknown, min: number, max: number): boolean => typeof v === "string" && v.length >= min && v.length <= max;
const exactKeys = (o: Record<string, unknown>, keys: string[]): boolean => Object.keys(o).every((k) => keys.includes(k));

function checkError(e: unknown): void {
  if (!isObject(e) || !exactKeys(e, ["code", "path", "message"])) throw new Error("form");
  if (!sizedText(e.code, 1, 100) || !sizedText(e.path, 0, 300) || !sizedText(e.message, 1, 300)) throw new Error("form");
}

// Form des Ergebnis-Körpers: errors genau bei rejected, 1 bis 100 Einträge; keine weiteren Schlüssel.
function checkResultBody(doc: unknown): asserts doc is ResultBody {
  if (!isObject(doc) || !exactKeys(doc, ["deliveryId", "outcome", "errors"])) throw new Error("form");
  if (typeof doc.deliveryId !== "string" || !uuidForm.test(doc.deliveryId)) throw new Error("form");
  if (doc.outcome === "accepted") {
    if (doc.errors !== undefined) throw new Error("form");
  } else if (doc.outcome === "rejected") {
    if (!Array.isArray(doc.errors) || doc.errors.length < 1 || doc.errors.length > 100) throw new Error("form");
    doc.errors.forEach(checkError);
  } else {
    throw new Error("form");
  }
}

// Eine ältere Abschrift ist kein Fehler: der Dienst hält schon eine neuere, ein Wiederholen änderte nichts.
async function transcript(deps: AppDeps, request: Request): Promise<Response> {
  const checked = await admitted(deps, request, false);
  if (checked instanceof Response) return checked;
  const body = await jsonBody(request, () => {});
  if (body instanceof Response) return body;
  const outcome = await putTranscript(deps.pool, checked.account, body.doc);
  return status(outcome === "invalid" ? 400 : 204);
}

// Die nächste wartende (oder zurückgeholte) Lieferung des Kontos für dieses Gerät; 204, wenn keine offen ist. Ein Körper wird ignoriert.
async function claim(deps: AppDeps, request: Request): Promise<Response> {
  const checked = await admitted(deps, request, true);
  if (checked instanceof Response) return checked;
  const body = await jsonBody(request, () => {}, true);
  if (body instanceof Response) return body;
  const found = await claimDelivery(deps.pool, checked.account, checked.device);
  if (found === undefined) return status(204);
  return Response.json(found, { headers: { "cache-control": "no-store" } });
}

// "ok" ist 204; "conflict" (fremdes Gerät, fremdes Konto, schon beantwortet, unbekannt) ist 409.
async function result(deps: AppDeps, request: Request): Promise<Response> {
  const checked = await admitted(deps, request, true);
  if (checked instanceof Response) return checked;
  const body = await jsonBody(request, checkResultBody);
  if (body instanceof Response) return body;
  const outcome = await reportResult(deps.pool, checked.account, checked.device, body.doc as ResultBody);
  return status(outcome === "ok" ? 204 : 409);
}

// Ausnahmen werden hier nicht gefangen: der Verteiler in main.ts macht daraus 500 ohne Körper.
export function appRoutes(deps: AppDeps): Record<string, Route> {
  return {
    "/app/transcript": (request) => transcript(deps, request),
    "/app/deliveries/claim": (request) => claim(deps, request),
    "/app/deliveries/result": (request) => result(deps, request),
  };
}
