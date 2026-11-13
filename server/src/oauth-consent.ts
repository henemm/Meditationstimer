// Übernommen aus loose-ends server/src/oauth-consent.ts @ 24a6da6; angepasst: Seitentext für Healthy Habits, Antragsteller ist der Host der client_id statt client_name
import type { IncomingMessage, ServerResponse } from "node:http";
import type Provider from "oidc-provider";

// The consent page of the issuer (#621 S5): after the sign-in the user sees what Claude may do and says yes or no.
// One right, "habits" (read and deliver); there is no right to delete. Nothing here reads a body: the two buttons are
// two forms with their own path, and a POST counts only from this service's own page (Origin) with the interaction cookie.
export type ConsentDeps = { publicUrl: string; log: (event: string) => void };
type Details = Awaited<ReturnType<Provider["interactionDetails"]>>;

const REFUSED = "oauth interaction refused";
const STORE_FAILED = "oauth interaction store failed";
const HEADERS = {
  "content-type": "text/html; charset=utf-8",
  "cache-control": "no-store",
  // same-origin, not no-referrer: with no-referrer a browser sends "Origin: null" on the page's own POST, and the CSRF check would refuse every real click.
  "referrer-policy": "same-origin",
  "x-frame-options": "DENY",
  "x-content-type-options": "nosniff",
  // No form-action: Chrome applies it to the redirect after the form too, and the answer goes to Claude's callback.
  "content-security-policy": "default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'; base-uri 'none'",
};

const escape = (text: string): string =>
  text.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);

function badRequest(res: ServerResponse): void {
  res.writeHead(400, { "content-type": "text/plain; charset=utf-8", "cache-control": "no-store" }).end("bad request");
}

// The applicant is named by the host of its client_id (the address of its metadata document), never by the client_name it
// chose itself: anyone can publish a document with a friendly name. Clipped, escaped when shown.
function applicantHost(details: Details): string {
  const host = URL.parse(String(details.params.client_id ?? ""))?.hostname ?? "";
  return (host !== "" ? host : "Eine Anwendung").slice(0, 60);
}

const STYLE = `body{font:17px/1.45 -apple-system,system-ui,sans-serif;max-width:32rem;margin:2rem auto;padding:0 1rem;color:#1c1c1e}
h1{font-size:1.4rem}ul{padding-left:1.2rem}li{margin:.4rem 0}.no{color:#6b6b70}
form{display:inline}button{font:inherit;padding:.7rem 1.2rem;border-radius:10px;border:1px solid #c7c7cc;background:#fff;margin:.5rem .5rem 0 0}
button.yes{background:#0a60ff;border-color:#0a60ff;color:#fff}
@media(prefers-color-scheme:dark){body{background:#000;color:#f2f2f7}button{background:#1c1c1e;color:#f2f2f7;border-color:#3a3a3c}.no{color:#98989f}}`;

function page(host: string, uid: string): string {
  const who = escape(host);
  const action = `/oauth/interaction/${encodeURIComponent(uid)}`;
  return `<!DOCTYPE html>
<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Healthy Habits</title>
<style>${STYLE}</style></head>
<body><h1>${who} möchte auf Healthy Habits zugreifen</h1>
<p>Wenn du zustimmst, kann ${who} in deinem Namen:</p>
<ul><li>Bausteine lesen: Übungen, Programme, Atemübungen und den Stand der Lieferungen</li>
<li>Übungen, Workout-Programme und Atemübungen liefern, eigene Lieferungen ändern und zurückziehen</li>
<li>Bausteinwünsche melden</li>
<li>deinen Verlauf der letzten 90 Tage lesen: Einheiten, Dauer, Rückmeldung nach dem Training und Serien</li></ul>
<p class="no">Nicht möglich: etwas starten oder eintragen, deine eigenen Inhalte ändern oder löschen. Tracker-Einträge, Stimmung, Notizen
und Daten aus Apple Health kann ${who} nicht lesen.</p>
<p class="no">Du kannst den Zugriff jederzeit in ${who} beenden. „Verbindung trennen“ in der App löscht alles, was der Dienst von dir hat.</p>
<form method="post" action="${action}/confirm"><button class="yes" type="submit">Zulassen</button></form>
<form method="post" action="${action}/abort"><button type="submit">Ablehnen</button></form>
</body></html>`;
}

// GET shows the page for the cookie's interaction in prompt consent; the caller has checked cookie and path.
export async function showConsent(deps: ConsentDeps, provider: Provider, details: Details, req: IncomingMessage, res: ServerResponse): Promise<void> {
  if (req.method !== "GET") {
    deps.log(REFUSED);
    return void res.writeHead(405, { allow: "GET", "cache-control": "no-store" }).end();
  }
  res.writeHead(200, HEADERS).end(page(applicantHost(details), details.uid));
}

// POST from this service's own page: Origin must be the issuer's origin (a browser always sends it on a POST).
function ownPost(deps: ConsentDeps, req: IncomingMessage): boolean {
  return req.method === "POST" && req.headers.origin === new URL(deps.publicUrl).origin;
}

// "confirm" grants exactly what the interaction lacks (the library's own list: habits and offline_access), "abort" ends it
// with access_denied and no description. Anything else is the fixed 400 and changes nothing.
export async function decideConsent(
  deps: ConsentDeps, provider: Provider, details: Details, answer: "confirm" | "abort", req: IncomingMessage, res: ServerResponse,
): Promise<void> {
  req.resume();
  if (req.method !== "POST") {
    deps.log(REFUSED);
    return void res.writeHead(405, { allow: "POST", "cache-control": "no-store" }).end();
  }
  if (!ownPost(deps, req)) {
    deps.log(REFUSED);
    return badRequest(res);
  }
  try {
    if (answer === "abort") {
      return await provider.interactionFinished(req, res, { error: "access_denied" }, { mergeWithLastSubmission: false });
    }
    const accountId = details.session?.accountId;
    const clientId = details.params.client_id;
    if (typeof accountId !== "string" || typeof clientId !== "string") {
      deps.log(REFUSED);
      return badRequest(res);
    }
    const grant = details.grantId ? await provider.Grant.find(details.grantId) : new provider.Grant({ accountId, clientId });
    if (grant === undefined || grant.accountId !== accountId || grant.clientId !== clientId) {
      deps.log(REFUSED);
      return badRequest(res);
    }
    const missing = details.prompt.details as { missingOIDCScope?: string[]; missingResourceScopes?: Record<string, string[]> };
    if (missing.missingOIDCScope?.length) grant.addOIDCScope(missing.missingOIDCScope.join(" "));
    for (const [resource, scopes] of Object.entries(missing.missingResourceScopes ?? {})) grant.addResourceScope(resource, scopes.join(" "));
    const grantId = await grant.save();
    await provider.interactionFinished(req, res, { consent: { grantId } }, { mergeWithLastSubmission: true });
  } catch {
    deps.log(STORE_FAILED);
    if (!res.headersSent) badRequest(res);
  }
}
