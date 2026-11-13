// Übernommen aus loose-ends server/src/main.ts @ 24a6da6; angepasst: Apple, OAuth, MCP, App-Routen, Aufträge entfernt; Pool-Name "hhhaven"
import http, { type IncomingMessage, type ServerResponse } from "node:http";
import type { AddressInfo } from "node:net";
import { join } from "node:path";
import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";
import { setTimeout as sleep } from "node:timers/promises";
import type { ReadableStream as NodeReadableStream } from "node:stream/web";
import pg from "pg";
import { ErrorWindow, healthHandler } from "./health.ts";
import { migrate } from "./migrate.ts";

export type Route = (request: Request) => Promise<Response>;
export type StartOptions = {
  databaseUrl: string; port: number; host?: string; migrationsDir: string; retryMs?: number; maxAttempts?: number;
  now?: () => number; applicationName?: string; extraRoutes?: Record<string, Route>;
};
export type Running = { url: string; ready: Promise<void>; close: () => Promise<void> };

// One line per event, ISO time first; never user data, database error text or connection data.
const log = (event: string) => console.log(`${new Date().toISOString()} ${event}`);
// Never throws: console.error can fail on a closed stderr (EPIPE), and a log line must not end the process.
const logError = (event: string) => {
  try { console.error(`${new Date().toISOString()} ${event}`); } catch {}
};
const BODY_LIMIT = 1024 * 1024;

// The error listener keeps an idle client's failure (database restart, network cut) from ending the process.
export function createPool(databaseUrl: string, applicationName = "hhhaven"): pg.Pool {
  const pool = new pg.Pool({ connectionString: databaseUrl, application_name: applicationName });
  pool.on("error", () => logError("pool error"));
  return pool;
}

// Retries while the database is not reachable yet; gives up after maxAttempts or when stopped.
async function migrateWithRetry(pool: pg.Pool, dir: string, retryMs: number, maxAttempts: number, signal: AbortSignal) {
  for (let attempt = 1; ; attempt++) {
    try {
      await migrate(pool, dir);
      return;
    } catch {
      if (attempt >= maxAttempts || signal.aborted) throw new Error("migrate gave up");
      logError(`migrate failed, retrying (${attempt}/${maxAttempts})`);
      await sleep(retryMs, undefined, { signal });
    }
  }
}

// Unknown path 404, an exception 500, both without a body; every answer but /health counts in the window.
async function dispatch(routes: Record<string, Route>, window: ErrorWindow, request: Request): Promise<Response> {
  const path = new URL(request.url).pathname;
  const route = Object.hasOwn(routes, path) ? routes[path] : undefined;
  let response: Response;
  try {
    response = route === undefined ? new Response(null, { status: 404 }) : await route(request);
  } catch {
    response = new Response(null, { status: 500 });
  }
  if (path !== "/health") window.record(response.status);
  return response;
}

// Counted while reading (Content-Length may lie or be absent); past the limit the rest is drained, never kept, and the
// answer is null. Draining to the end lets the 413 arrive: closing on unread data would reset the connection first.
function buffered(req: IncomingMessage): Promise<Buffer | null> {
  return new Promise((done, fail) => {
    let chunks: Buffer[] | null = [];
    let size = 0;
    req.on("data", (chunk: Buffer) => {
      size += chunk.length;
      if (size > BODY_LIMIT) chunks = null;
      else chunks?.push(chunk);
    });
    req.once("end", () => done(chunks === null ? null : Buffer.concat(chunks)));
    req.once("error", fail);
  });
}

// node:http in, Request and Response through the route, node:http out; the body is streamed, so SSE answers pass.
async function bridge(req: IncomingMessage, res: ServerResponse, handle: Route): Promise<void> {
  try {
    const headers = new Headers();
    for (let i = 0; i < req.rawHeaders.length; i += 2) headers.append(req.rawHeaders[i], req.rawHeaders[i + 1]);
    const method = req.method ?? "GET";
    const raw = method === "GET" || method === "HEAD" ? undefined : await buffered(req);
    if (raw === null) return void res.writeHead(413, { connection: "close" }).end();
    const body = raw === undefined ? undefined : new Uint8Array(raw);
    const response = await handle(new Request(`http://${req.headers.host ?? "localhost"}${req.url ?? "/"}`, { method, headers, body }));
    res.writeHead(response.status, [...response.headers].flat());
    if (response.body === null) res.end();
    else await pipeline(Readable.fromWeb(response.body as NodeReadableStream), res);
  } catch {
    if (!res.headersSent) res.writeHead(500).end();
    else res.destroy();
  }
}

// 503 without a body until migrate is done: the route needs the database. Later cuts wrap their routes with it.
export function gated(isReady: () => boolean, route: Route): Route {
  return async (request) => (isReady() ? route(request) : new Response(null, { status: 503 }));
}

// Listens first, so /health can answer 503 while migrate still waits for the database; ready settles with migrate.
export async function start(options: StartOptions): Promise<Running> {
  const { databaseUrl, port, host = "127.0.0.1", migrationsDir, retryMs = 2000, maxAttempts = 60 } = options;
  const pool = createPool(databaseUrl, options.applicationName);
  const window = new ErrorWindow(options.now ?? Date.now);
  let migrated = false;
  const isReady = () => migrated;
  // /health last: extraRoutes cannot replace it.
  const routes: Record<string, Route> = {
    ...options.extraRoutes,
    "/health": healthHandler({ pool, isMigrated: isReady, window }),
  };
  const server = http.createServer((req, res) => void bridge(req, res, (request) => dispatch(routes, window, request)));
  try {
    await new Promise<void>((done, fail) => { server.once("error", fail); server.listen(port, host, done); });
  } catch (error) {
    await pool.end();
    throw error;
  }
  log("listening");
  const stop = new AbortController();
  const ready = migrateWithRetry(pool, migrationsDir, retryMs, maxAttempts, stop.signal)
    .then(() => { migrated = true; log("migrated"); });
  ready.catch(() => {});
  let closing: Promise<void> | undefined;
  const close = () => (closing ??= shutdown(server, pool, stop));
  return { url: `http://${host}:${(server.address() as AddressInfo).port}`, ready, close };
}

// Server first (open keep-alive connections are cut), then the pool; never throws.
async function shutdown(server: http.Server, pool: pg.Pool, stop: AbortController) {
  stop.abort();
  const closed = new Promise<void>((done) => server.close(() => done()));
  server.closeAllConnections();
  await closed;
  await pool.end().catch(() => logError("pool end failed"));
}

// The process: settings from the environment, one shutdown on SIGTERM or SIGINT, exit 1 when migrate gives up.
async function main(): Promise<void> {
  const databaseUrl = process.env.DATABASE_URL;
  if (databaseUrl === undefined || databaseUrl === "") {
    logError("DATABASE_URL missing");
    process.exit(1);
  }
  const running = await start({
    databaseUrl, port: Number(process.env.PORT ?? 8080), host: process.env.HOST ?? "127.0.0.1",
    migrationsDir: join(import.meta.dirname, "../migrations"),
  });
  let stopping = false;
  const stop = async (code: number) => {
    if (stopping) return;
    stopping = true;
    log("shutting down");
    await running.close();
    log("stopped");
    process.exit(code);
  };
  process.on("SIGTERM", () => void stop(0));
  process.on("SIGINT", () => void stop(0));
  running.ready.catch(() => { logError("migrate gave up"); void stop(1); });
}

if (import.meta.main) await main();
