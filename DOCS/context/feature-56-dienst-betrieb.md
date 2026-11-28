# Context: feature-56-dienst-betrieb (Issue #56, Abschnitt 2: Inbetriebnahme)

Stand: 2026-11-28 18:40 MEZ

## Request Summary

Issue #56 (B2c) wurde per PO-Entscheidung vom 28.11. in zwei Abschnitte geteilt. **Abschnitt 1 (Einbau in henemm-infra)
ist erledigt und validiert** (henemm/henemm-infra#561 gemergt, 1043 Tests grün). Dieser Workflow ist **Abschnitt 2:
Inbetriebnahme** — Dienst live unter `https://habits.henemm.com`, Sicherung/Überwachung nachweislich aktiv, Konnektor in
Hennings Claude-Konto, Ende-zu-Ende-Prüfung. Abnahme = Live-Nachweise L-AC-2 … L-AC-10 der bestehenden Spec.

## Bestehende Spec

`DOCS/specs/infra/habits-dienst-betrieb.md` (Datei steht noch auf `status: draft`, Abschnitt 1 wurde im Vorgänger-Workflow freigegeben und validiert). Enthält bereits Reihenfolge (Schritte 2–6),
PO-Termin, Rückrollweg, Monitor-Falle, Sicherung der Geheimnisse und die Abnahmekriterien L-AC-2 … L-AC-10 für Abschnitt 2.
Für diesen Workflow wird sie um einen Abschnitt-2-Teil ergänzt (Changelog), nicht neu geschrieben.

## Ist-Zustand (live geprüft 2026-11-28 ~18:35 MEZ)

| Punkt | Stand |
|---|---|
| Server rennwienix (SSH-Alias `rennwienix`; `henemm` löst von diesem Mac nicht auf) | erreichbar, 4,2 GB RAM frei, 39 GB Platte frei (74 %) |
| `/home/hem/henemm-infra` | auf `origin/main` 4b054be, enthält `habits/docker-compose.yml`, `scripts/deploy-habits.sh`, `backup-habits-snapshot.sh`, `restore-test-habits.sh`, `docs/habits-runbook.md` (Schritte 1–10). Der Hinweis „Arbeitskopie steht vor dem Einbau“ aus dem Issue ist überholt. |
| `habits/secrets/` | fehlt noch |
| Container/Image habits | keine |
| nginx-Site, Zertifikat habits | keine |
| DNS `habits.henemm.com` | kein A-Eintrag (`dig` leer); Server-IPv4 178.104.143.19 |
| Dienstcode `server/` + `Contracts/` | seit dem gepinnten `HH_COMMIT` d7705c3 unverändert bis origin/main (f1f7d21) → Pin bleibt gültig |
| Loose-Ends-Geheimnisse | `loose-ends/secrets/server.env` enthält `APPLE_KEY_ID` → SiwA-Schlüssel ist auf dem Server vorhanden, Mitbenutzung möglich (Spec-Empfehlung) |

## Related Files

- Dieses Repo: `server/` (Dienst, unverändert), `server/Dockerfile`, `.github/workflows/server.yml`,
  `DOCS/claude-anmeldung-pruefliste.md` (30 Eigenheiten; Betriebspunkte Nr. 8, 10, 14–19, 27, 29, 30 betreffen diesen Abschnitt),
  `DOCS/konzept-claude-verbindung.md` Abschnitt 11.
- henemm-infra: `habits/docker-compose.yml`, `nginx/habits.henemm.com.conf`, `scripts/deploy-habits.sh` (10 Pflicht-Umgebungsnamen,
  Abbruch im Backup-Fenster 02:45–03:30), `scripts/backup.sh`, `monitor.sh`, `restic-prune-heimserver.sh`, `docs/habits-runbook.md`,
  `security/expected-exposure.json` (Teil B, L-AC-10).

## Existing Patterns

- Loose Ends: `scripts/deploy-loose-ends.sh` mit gepinntem Commit, Compose-Stapel db+server, `/health`-Prüfung, altes Image entfernen.
  Belege werden als Textdatei unter `docs/artifacts/<workflow>/` abgelegt (Muster `loose-ends/docs/artifacts/feat-615-s4d-auth-oeffnen/deploy.txt`).
- henemm-infra hat keine GitHub-Actions-Prüfung; Prüfung dort: `python3 -m pytest tests -q`.

## Dependencies / Externe Schritte (nur PO)

- **Namecheap DNS:** kein API-Zugang (henemm-infra `docs/mail.md`) → A-Eintrag ist Handarbeit des PO.
- **Apple Developer Portal:** Sign in with Apple an App-ID einschalten, Services ID `henemm.habits.web` mit Domain und Rücksprung
  anlegen. Services IDs gibt es nicht über die App-Store-Connect-API (in der Analyse per Recherche belegen).
- **Claude-Konnektor:** Hinzufügen und Apple-Anmeldung braucht Hennings Konto.
- Diese drei sind laut Spec in **einem** angekündigten PO-Termin gebündelt. DNS und Apple können vor dem Konnektor liegen;
  der Konnektor erst, wenn der Dienst live ist (Monitor-Falle, Prüfliste Nr. 10: 5 min Cache bei claude.ai).

## Risks

- **Monitor-Falle:** `monitor.sh` alarmiert, sobald `habits-db` existiert und die öffentliche `/health` nicht 200 liefert →
  Dienst erst dauerhaft starten, wenn DNS und Zertifikat stehen.
- **Tür offen:** ohne `ALLOWED_APPLE_SUBS` nimmt der Dienst das erste Konto (Prüfliste Nr. 30) → zwischen erster Anmeldung und
  Tür-Schließen keine Adresse weitergeben; Fenster kurz halten.
- **fail2ban/Drosselung** darf 160.79.104.0/21 nicht sperren (Nr. 14/15).
- **Gemeinsamer Server mit Loose Ends:** nginx-Reload trifft alle Seiten → immer `nginx -t` vor Reload.
- **Geheimnisse:** `APPLE_TOKEN_KEY` muss in der Off-site-Sicherung liegen (L-AC-5), Werte nie in Issue/Spec/Chat.
- **Backup-Fenster** 02:45–03:30: kein Ausrollen.
- **Postgres-Version:** habits-Compose und Rückspielprobe nutzen `postgres:18.6`; auf dem Server liegt nur `postgres:18.7`
  (Loose Ends wurde angehoben). Die Probe zieht nie selbst nach → L-AC-6 würde scheitern. Angleichen an 18.7 per henemm-infra-PR
  (Compose + Probe + Test), vor dem ersten Ausrollen, damit die Datenbank nicht später einen Versionswechsel braucht.
- **Prune-Skript** muss von Hand per scp auf den Heimserver (`habits-einbau.md` §4), sonst wächst der habits-Bestand ohne Aufbewahrung.
- **Ausrollen nur per SSH** aus einer Tailnet-Sitzung (diese Mac-Sitzung kann es: Alias `rennwienix`); `auto-deploy-infra.sh`
  zieht alle 5 min `origin/main` in den Server-Checkout, baut/startet aber nichts; nginx/systemd werden manuell übernommen.
- **Alarm** geht über Telegram (`notify-telegram.sh`) und BetterStack-Heartbeat; habits wird erst geprüft, sobald `habits-db` existiert.
- Hennings Geräte sind nicht betroffen; der Konnektor wird in seinem Claude-Konto angelegt (Web/App), das ist sein Schritt, kein Gerätetest durch Claude.

## Analysis

**Type:** Feature (Inbetriebnahme, Infrastruktur). Kein App-Code, keine Codeänderung in diesem Repo außer Spec/Doku/Belegen.

### Recherche (2026-11-28)

- Apple: Services ID und SiwA-Schlüssel müssen dieselbe Primary App ID haben, sonst `invalid_client`
  ([Forum 820967](https://developer.apple.com/forums/thread/820967), [Forum 813131](https://developer.apple.com/forums/thread/813131)).
  Der Dienst löst auch App-Codes mit `client_id = henemm.Meditationstimer-iOS` ein (für #57) → Mitbenutzung des Loose-Ends-Schlüssels
  (Primary = Loose-Ends-App) ist unsicher.
- Apple-Portal: bekannte 501-Störung beim Speichern der Website-URLs einer Services ID ([Forum 797201](https://developer.apple.com/forums/thread/797201)) → Apple-Schritt zuerst im PO-Termin.
- Services IDs sind nicht über die App-Store-Connect-API anlegbar (nur Portal).
- Namecheap-API nur bei 20 Domains / 50 $ Guthaben bzw. Umsatz plus IP-Freigabe ([Namecheap FAQ](https://www.namecheap.com/support/knowledgebase/article.aspx/9739/63/api--faq)); `setHosts` ersetzt die ganze Zone → für einen Eintrag nicht lohnend, PO trägt ihn ein.

### Affected Files

| Datei | Change | Grund |
|---|---|---|
| henemm-infra `habits/docker-compose.yml` | MODIFY | `postgres:18.6` → `18.7` (nur 18.7 liegt auf dem Server) |
| henemm-infra `scripts/restore-test-habits.sh` | MODIFY | Probe-Image 18.6 → 18.7 |
| henemm-infra `tests/test_habits_konfiguration.py` | MODIFY | erwartete Version 18.7 |
| henemm-infra `docs/habits-runbook.md` | MODIFY | neuer Schlüssel (Primary = Meditationstimer-App), `down` statt `stop`, Tür vor dem ersten Start |
| henemm-infra `security/expected-exposure.json` | MODIFY | Teil B, erst nach Außenprüfung (L-AC-10) |
| Server: `habits/secrets/`, `/etc/nginx/sites-available/habits.henemm.com` + Zertifikat, Prune-Skript auf Heimserver | CREATE | außerhalb Git |
| Dieses Repo: `DOCS/specs/infra/habits-dienst-betrieb.md` | MODIFY | Abschnitt-2-Teil, Changelog |
| Dieses Repo: `docs/artifacts/feature-56-dienst-betrieb/*.txt` | CREATE | Live-Belege L-AC-2 … L-AC-10 |

### Scope / Risk

- henemm-infra PR 1: 3–4 Dateien, ca. ±10 LoC; PR 2 (Teil B): ca. +30 LoC. App-Code: 0.
- Risiko **hoch** (Produktivserver geteilt mit Loose Ends: nginx-Reload trifft alle Seiten; Monitor-Alarm), aber gut rückrollbar.

### Technical Approach (Empfehlung: Variante A)

1. Claude: PR in henemm-infra für Postgres 18.7 (+ Runbook), Tests grün, Merge; `auto-deploy-infra.sh` zieht ihn in den Server-Checkout.
2. Claude, ohne PO: `habits/secrets/` (700/600) mit erzeugten Werten; Apple-Felder bleiben offen bis zum Termin; nginx-Site vorbereitet,
   **nicht** aktiviert; Prune-Skript auf den Heimserver. **Kein** früher Container (auch gestoppt löst `habits-db` den Monitor-Alarm aus).
   `ALLOWED_APPLE_SUBS` vorab aus Hennings vorhandenem Loose-Ends-Konto (Apple-`sub` ist je Team gleich), ohne den Wert auszugeben →
   Tür ist ab dem ersten Start zu. Fallback, wenn die Teams verschieden sind oder die Anmeldung abgewiesen wird: Tür kurz öffnen, eigene `sub` lesen, schließen.
3. **PO-Kontakt 1 (ca. 30 min, angekündigt):** Apple-Portal zuerst (SiwA an `henemm.Meditationstimer-iOS`; Services ID `henemm.habits.web`
   mit Primary = Meditationstimer-App, Domain + Rücksprung; **neuer** SiwA-Schlüssel mit derselben Primary App ID, `.p8` herunterladen),
   dann Namecheap A-Eintrag. Claude übernimmt `.p8` ohne sie anzuzeigen auf den Server, wartet per `dig`, dann in einem Zug: `nginx -t` +
   Reload, certbot, `deploy-habits.sh`, L-AC-2…4 von außen.
4. **PO-Kontakt 2 (ca. 5 min):** Konnektor `https://habits.henemm.com/mcp` in Claude anlegen, mit Apple anmelden — erst wenn L-AC-2/3 grün.
5. Claude: Sicherungslauf + Rückspielprobe (L-AC-5/6), Monitor (L-AC-7), Tür-Nachweis (L-AC-8), Ende-zu-Ende in einem Claude-Gespräch
   über den Konnektor (L-AC-9), Teil B (L-AC-10). Belege als Textdateien, keine Geheimniswerte.

### Varianten

| Variante | PO-Kontakte | Dauer PO | Risiko |
|---|---|---|---|
| **A (empfohlen):** neuer Schlüssel, Primary = Meditationstimer-App | 2 | ca. 35 min | niedrig, Loose Ends unberührt |
| B: Loose-Ends-Schlüssel mitbenutzen (bisherige Spec) | 1 (+1 Nacharbeit) | ca. 40 min | mittel: App-Anmeldung (#57) scheitert voraussichtlich |
| C: Meditationstimer-App unter Loose-Ends-Primary gruppieren | 1–2 | ca. 40 min | mittel: ändert die laufende Loose-Ends-Anmeldung |
| D: Spec wörtlich (3 Termine, Tür offen bis zum Ende) | 3 | ca. 50 min | mittel |

Gekippt wird damit die Spec-Empfehlung „Loose-Ends-Schlüssel mitbenutzen“ und die Reihenfolge „Probe-Container, dann stoppen“.

### Open Questions

- Keine Produktfrage. Termin der zwei PO-Kontakte wird in der Spec-Freigabe angekündigt; ohne seinen Termin keine Inbetriebnahme.
- Technisch vor Kontakt 1 prüfen: Team-ID von Loose Ends = XK87E2B3VR (nur Gleichheit prüfen, Wert nicht ausgeben); Schlüssel-Kontingent je Team.
