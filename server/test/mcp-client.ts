// MCP-Testgeschirr, übernommen aus loose-ends server/test/mcp.test.ts: ein echter MCP-Client im Prozess, ohne Port.
// Jede Anfrage geht direkt an handler.fetch, das Konto reist in authInfo.extra.account mit.
import type pg from "pg";
import { Client, StreamableHTTPClientTransport } from "@modelcontextprotocol/client";
import { mcpHandler } from "../src/mcp.ts";
import type { freshPool } from "./db.ts";

export type Doc = Record<string, any>;
export type T = Parameters<typeof freshPool>[0];

export async function connect(t: T, pool: pg.Pool, account?: string): Promise<Client> {
  const handler = mcpHandler(pool);
  const authInfo = account === undefined ? undefined : { token: "test", clientId: "test", scopes: [], extra: { account } };
  const transport = new StreamableHTTPClientTransport(new URL("http://mcp.test/mcp"), {
    fetch: (url, init) => handler.fetch(new Request(url, init), { authInfo }),
  });
  const client = new Client({ name: "test", version: "1" });
  await client.connect(transport);
  t.after(async () => { await client.close(); await handler.close(); });
  return client;
}

export async function call(client: Client, name: string, args: Doc = {}): Promise<{ text: string; isError: boolean }> {
  const result: Doc = await client.callTool({ name, arguments: args });
  return { text: result.content.map((part: Doc) => part.text).join(""), isError: result.isError === true };
}

export async function json(client: Client, name: string, args: Doc = {}): Promise<Doc> {
  const { text, isError } = await call(client, name, args);
  if (isError) throw new Error(`${name} lieferte einen Fehler: ${text}`);
  return JSON.parse(text);
}
