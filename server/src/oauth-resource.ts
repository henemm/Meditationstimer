// Übernommen aus loose-ends server/src/oauth-resource.ts @ 24a6da6; angepasst: keine Vorgabe-Adresse, PUBLIC_URL ohne Wert gilt als nicht gesetzt (main verlangt sie mit OAuth-Schlüsseln)
import {
  type AuthInfo, getOAuthProtectedResourceMetadataUrl, OAuthError, OAuthErrorCode, type OAuthTokenVerifier, requireBearerAuth,
} from "@modelcontextprotocol/server";
import type { Route } from "./main.ts";

// The service as an OAuth protected resource (RFC 9728, RFC 8707, RFC 6750).
export const METADATA_PATH = "/.well-known/oauth-protected-resource/mcp";

// The resource comes from the configuration, never from the request's Host.
export function resourceFor(publicUrl: string): URL {
  return new URL("/mcp", publicUrl);
}

// Without an issuer no token is valid; keeps app session tokens away from /mcp.
export const rejectAll: OAuthTokenVerifier = {
  verifyAccessToken: async () => { throw new OAuthError(OAuthErrorCode.InvalidToken, "no issuer"); },
};

// GET only; any other method 405 with Allow: GET and no body. The issuer is the public URL's origin.
export function metadataRoute(publicUrl: string): Route {
  const body = JSON.stringify({
    resource: resourceFor(publicUrl).href,
    authorization_servers: [new URL(publicUrl).origin],
    bearer_methods_supported: ["header"],
  });
  return async (request) => request.method === "GET"
    ? new Response(body, { status: 200, headers: { "content-type": "application/json" } })
    : new Response(null, { status: 405, headers: { allow: "GET" } });
}

// A Response is a finished refusal, an AuthInfo a checked token.
export function bearerGate(publicUrl: string, verifier: OAuthTokenVerifier): (request: Request) => Promise<AuthInfo | Response> {
  const resource = resourceFor(publicUrl);
  return requireBearerAuth({ verifier, expectedResource: resource, resourceMetadataUrl: getOAuthProtectedResourceMetadataUrl(resource) });
}

const LOCAL_HOSTS = new Set(["localhost", "127.0.0.1"]);

// Unset or blank → undefined (no default address; main refuses to start with OAuth keys but without it); an https origin (or http on localhost) → its origin; anything else throws without the value.
export function publicUrlFromEnv(env: NodeJS.ProcessEnv | Record<string, string | undefined>): string | undefined {
  const value = env.PUBLIC_URL?.trim();
  if (!value) return undefined;
  const url = URL.parse(value);
  const secure = url?.protocol === "https:" || (url?.protocol === "http:" && LOCAL_HOSTS.has(url.hostname));
  const bare = url !== null && url.pathname === "/" && url.search === "" && url.hash === "" && !url.username && !url.password
    && !value.includes("?") && !value.includes("#");
  if (!secure || !bare) throw new Error("PUBLIC_URL invalid");
  return url!.origin;
}
