# Spec: Anmeldung mit Apple, OAuth für Claude und Tür (B2b)

**Issue:** #55 (Teil von Epic #44) · **Konzept:** `DOCS/konzept-claude-verbindung.md` Abschnitte 4, 11, 12
**Baut auf:** `openspec/specs/integrations/claude-dienst.md` (B2a) · **Stand:** 13.11.2026

## 1. Vorgehen

Wie in B2a (Abschnitt 1 dort): Die Anmeldebausteine von Loose Ends (`henemm/loose-ends` `server/` @ `24a6da6`) werden **übernommen**,
jede Datei mit Herkunftszeile. Dort sind sie gegen claude.ai und Apple im Betrieb erprobt; nichts wird neu erfunden (Konzept 4).

| Übernommen | Anpassung |
|---|---|
| `accounts.ts` | `deleteAccount` löscht die fachlichen Zeilen dieses Dienstes: `transcripts`, `delivery_events` und `deliveries`, `wishes` (statt Aufträge/Abschrift von Loose Ends). Eigene Sperr-Kennungen (keine Gleichheit mit Loose Ends nötig, aber eigene Zahlen). |
| `apple.ts`, `apple-jwks.ts`, `apple-client.ts`, `apple-vault.ts`, `auth.ts` | keine fachliche Anpassung |
| `oauth-adapter.ts`, `oauth-interaction.ts`, `oauth-return.ts` | keine fachliche Anpassung |
| `oauth-provider.ts` | Scope `habits` statt `tasks`. |
| `oauth-resource.ts` | Keine Vorgabe-Adresse: `PUBLIC_URL` ist Pflicht, sobald OAuth-Schlüssel gesetzt sind (sonst Ende mit Code 1, Meldung nennt nur den Variablennamen). |
| `oauth-consent.ts` | Seitentext für Healthy Habits (Abschnitt 4). **Behebt die bekannte Lücke von Loose Ends:** Die Seite nennt als Antragsteller den Host der `client_id` (z. B. „claude.ai“), nicht den selbst gewählten `client_name`. |
| Migrationen 002–005 | zusammengezogen zu `server/migrations/005_accounts.sql`: `accounts`, `sessions`, `apple_tokens` (mit `client_id NOT NULL`, Schlüssel `(account_id, client_id)`), `oauth_records`. Bestehende Tabellen erhalten keinen Fremdschlüssel (wie Loose Ends); `deleteAccount` räumt sie selbst. |
| `main.ts` | `doors(pool, …)` aus B2a bekommt die echten Prüfer: `/mcp` hinter `bearerGate(publicUrl, providerVerifier)`; `/app/*` mit `appAccount` aus der App-Sitzung (`Authorization: Bearer <sessionToken>`, `resolveSession`); `/auth/apple`, `/auth/logout`, `/auth/delete`; Aussteller-Pfade, Ressourcen-Metadaten, Apple-Rückweg und Interaktion wie Loose Ends. Ohne OAuth-Schlüssel bzw. `PUBLIC_URL` bleibt `/mcp` bei `rejectAll` (401) und der Aussteller antwortet 503; ohne Apple-Konfiguration antwortet `/auth/apple` 503, `/app/*` und `/auth/delete` ohne Sitzung 401. OAuth-Schlüssel ohne `PUBLIC_URL`: Ende mit Code 1. |

Umgebungsvariablen wie Loose Ends: `DATABASE_URL`, `PORT`, `HOST`, `PUBLIC_URL`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_CLIENT_IDS`,
`APPLE_PRIVATE_KEY`, `APPLE_TOKEN_KEY`, `APPLE_WEB_CLIENT_ID`, `ALLOWED_APPLE_SUBS`, `OAUTH_COOKIE_KEYS`, `OAUTH_SIGNING_JWK`.
Abhängigkeiten zusätzlich: `oidc-provider` 9.13.3, dev `@types/oidc-provider` 9.13.1 (exakt wie Loose Ends).

## 2. Tür

- `ALLOWED_APPLE_SUBS` gesetzt: nur diese Apple-Konten kommen hinein, über App-Anmeldung **und** Web-Anmeldung für Claude.
- Nicht gesetzt: nur das erste Konto wird angelegt, danach nur noch dieses (Zeitfenster für die Ersteinrichtung, wie Loose Ends).
- Ein fremdes Konto wird abgewiesen, bevor irgendetwas gespeichert wird (kein Konto, keine Sitzung, kein Apple-Token, kein OAuth-Grant).
  Belegt durch Tests für beide Wege.

## 3. Dasselbe Konto für App und Claude

App-Anmeldung (`/auth/apple`) und Web-Anmeldung für Claude (OAuth-Interaktion über Apple) führen über `apple_sub` zum selben Konto.
Was Claude liefert, holt die App mit ihrer Sitzung ab; was die App als Abschrift schickt, liest Claude. Belegt durch einen Ende-zu-Ende-Test
im Prozess: Konto über beide Wege angemeldet (Apple und claude.ai durch eingereichtes `fetch` ersetzt) → Claude liefert über `/mcp` →
App holt über `/app/deliveries/claim` ab.

## 4. Zustimmungsseite

Überschrift „<Host> möchte auf Healthy Habits zugreifen“. Liste, was möglich ist: Bausteine lesen (Übungen, Programme, Atemübungen,
Stand der Lieferungen); Übungen, Workout-Programme und Atemübungen liefern, eigene Lieferungen ändern und zurückziehen; Bausteinwünsche
melden. Was nicht möglich ist: etwas starten oder eintragen, Hennings eigene Inhalte ändern, löschen, Tracker-Einträge, Stimmung,
Notizen oder Daten aus Apple Health lesen. Hinweis: Zugriff jederzeit in Claude beenden; „Verbindung trennen“ in der App löscht alles beim Dienst.

## 5. Verbindung trennen

`POST /auth/delete` mit App-Sitzung: löscht Konto, Sitzungen, Apple-Tokens, OAuth-Datensätze (Grants, Token), Abschrift, Lieferungen
mit Verlauf und Wünsche dieses Kontos; widerruft danach die Apple-Tokens so gut wie möglich; Antwort 204. Danach gilt weder die
App-Sitzung noch ein Claude-Token (401). Andere Konten bleiben unberührt (Test).

## 6. Prüfliste der Claude-Anmeldung

`DOCS/claude-anmeldung-pruefliste.md` übernimmt die 30 bekannten Eigenheiten aus Loose Ends (Fundstellen dort) und ordnet jeder
Eigenheit zu, wo sie hier gesichert ist: Testname (B2b) oder Betriebsschritt (B2c, z. B. nginx-Einstellungen, Absender-Netz,
Apple-Portal). Jede Eigenheit, die sich im Code zeigt, hat einen Test.

## 7. Fertig, wenn

Alle übernommenen Tests (angepasst) und die neuen Tests zu Abschnitt 2, 3 und 5 grün; Prüfliste im Repo, jede Zeile zugeordnet.
Echte Anmeldung mit Apple und claude.ai erst nach Bereitstellung (B2c).
