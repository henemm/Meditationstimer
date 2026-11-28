---
entity_id: habits-dienst-betrieb
type: feature
created: 2026-11-28
updated: 2026-11-28
status: draft
workflow: feature-56-dienst-betrieb
---

# Habits-Dienst in Betrieb nehmen (Issue #56, B2c)

## Approval

- [ ] Approved

## Purpose

Der Dienst der Claude-Verbindung (`server/`, MCP + OAuth 2.1 + Sign in with Apple) läuft produktiv unter `https://habits.henemm.com`, nachweislich gesichert und überwacht. Claude kann damit über Hennings Konto den Katalog lesen und ein Beispiel liefern, das als „wartet" (`delivery_status = waiting`) ankommt.

## Source

- **Dienst (unverändert):** `server/` in diesem Repo, Stand `d7705c320e6a47d9971991635c67960f1b98e745`
- **Betriebsvorlage:** henemm/henemm-infra PR #454 (Zweig `claude/friendly-dirac-b5tg6a`, veraltet), neu aufzusetzen auf aktuelles `main` von henemm-infra
- **Muster:** `henemm-infra/loose-ends/` (Compose, `secrets/` 700/600)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| B2a (#54), B2b (#55) | issue (geschlossen) | Dienst und Migrationen 001–009 |
| #57 | issue | Folgearbeit App-Abgleich (Mac), nicht Teil dieser Spec |
| henemm-infra `scripts/backup.sh`, `monitor.sh`, `restic-prune-heimserver.sh` | script | Sicherung, Gesundheitsprüfung, Aufbewahrung |
| Namecheap | extern (nur PO) | DNS-A-Eintrag |
| Apple Developer Portal | extern (nur PO) | Sign in with Apple, Services ID, Schlüssel |
| Claude-App (Konnektor) | extern (nur PO) | Konnektor anlegen, anmelden |
| nginx, certbot, Docker | Server | Reverse-Proxy, Zertifikat, Container |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| henemm-infra `habits/docker-compose.yml` | CREATE | habits-db (postgres:18.6 in Abschnitt 1; in Abschnitt 2 auf 18.7 angehoben, siehe dort), habits-server auf 127.0.0.1:8781 |
| henemm-infra `habits/.gitignore` | CREATE | `secrets/` nie versionieren |
| henemm-infra `nginx/habits.henemm.com.conf` | CREATE | Erlaubnisliste /health, /mcp, Discovery, /oauth/*, /auth/*, /app/*; keine Sperre vor `/.well-known/*`; Anthropic-Netz 160.79.104.0/21 nicht sperren |
| henemm-infra `scripts/deploy-habits.sh` | CREATE | fester `HH_COMMIT=d7705c320e6a47d9971991635c67960f1b98e745` (voller SHA), prüft die zehn Pflicht-Umgebungsnamen, bricht im Backup-Fenster 02:45–03:30 ab |
| henemm-infra `scripts/backup-habits-snapshot.sh` | CREATE | SQL-Dump der habits-db |
| henemm-infra `scripts/restore-test-habits.sh` | CREATE | Rückspielprobe gegen Wegwerf-DB |
| henemm-infra `scripts/backup.sh` | MODIFY | nur Habits-Einfügung: Snapshot, restic mit Tag `habits`, Rückspielprobe nach Gregor/Loose Ends; Secrets-Ordner sichern (siehe Details) |
| henemm-infra `scripts/monitor.sh` | MODIFY | nur Habits-Einfügung (Teil-Check, kein BetterStack-Monitor); keine Altstände aus dem PR-Zweig (kein Entfernen von mailadmin/tailscale/gregor, kein wireguard) |
| henemm-infra `scripts/restic-prune-heimserver.sh` | MODIFY | Tag `habits` in die Aufbewahrung |
| henemm-infra `tests/test_*habits*.py` | CREATE | die 60 Habits-Tests der Vorlage |
| henemm-infra `docs/habits-runbook.md` | CREATE | Schritte 1–10 plus Ergänzung zur Sicherung von `APPLE_TOKEN_KEY` und `habits/secrets` |
| henemm-infra `docs/habits-einbau.md` | CREATE | Einbauanleitung, Teil B |
| henemm-infra `docs/backup-offsite.md`, `docs/backup-restore.md` | MODIFY | Habits ergänzen |
| henemm-infra `security/expected-exposure.json` | MODIFY | Teil B, erst nach erfolgreicher Außenprüfung |
| Server live: `/etc/nginx/sites-available/habits.henemm.com`, Zertifikat, `henemm-infra/habits/secrets/`, Prune-Skript auf Heimserver | CREATE/MODIFY | nicht versioniert bzw. außerhalb Git |
| Dieses Repo | keine | keine Codeänderung; nur Vermerk im Issue #56 |

### Estimated Changes
- Files: ca. 16 in henemm-infra, 0 in diesem Repo
- LoC: ca. +1500/-0 (überwiegend Tests und Skripte der Vorlage)

## Implementation Details

**Reihenfolge (Abschnitt 1 und Gesamtbild; für Abschnitt 2 gilt die korrigierte Reihenfolge unten)**

1. Claude: Vorlage auf aktuelles henemm-infra-`main` neu aufsetzen (nur Habits-Einfügungen), `HH_COMMIT` setzen, Tests grün, übernehmen.
2. Claude: `habits/secrets/` anlegen (700/600). Erzeugte Werte (DB-Passwort, `APPLE_TOKEN_KEY` = base64 32 Byte, Cookie-Schlüssel ≥ 32 Zeichen); Apple-Werte zunächst gültig geformte Platzhalter (EC P-256). **Kein früher Container**, auch keine kurze lokale Probe: schon ein vorhandener `habits-db` (auch gestoppt) löst den Monitor-Alarm aus. Falls dennoch einer gestartet wurde, danach `docker compose down`, nie `stop`.
3. PO, gebündelt in angekündigten Kontakten (siehe unten: zwei Kontakte).
4. Claude: nginx und certbot einrichten, erst dann Dienst dauerhaft starten, ausrollen, Außenprüfung, echte Apple-Werte eintragen, erneut ausrollen.
5. PO: Konnektor in Claude anlegen, einmal mit Apple anmelden.
6. Claude: Restore-Test einmal; Teil B `security/expected-exposure.json`; Ende-zu-Ende-Prüfung. (Die Tür, `ALLOWED_APPLE_SUBS`, ist nicht erst hier, sondern schon vor dem ersten Start geschlossen; siehe Abschnitt 2.)

**Monitor-Falle:** `monitor.sh` alarmiert, sobald `habits-db` existiert und die öffentliche `/health` nicht 200 liefert. Der Dienst darf deshalb erst dauerhaft laufen, wenn DNS und Zertifikat stehen.

**Sicherung der Geheimnisse:** `backup.sh` sammelt Umgebungsdateien nur per `find … -name '*.env'` bis Tiefe 3 unter `/home/hem/henemm-infra`. `habits/secrets/` (Tiefe 2) wird nur erfasst, wenn die Dateien auf `.env` enden; `db-password` und ähnliche Dateien nicht. Vor dem Einbau prüfen, was erfasst wird; fehlt etwas, `habits/secrets` explizit in die Liste der gesicherten Dateien aufnehmen (restic-verschlüsselt, off-site). Ohne gesichertes `APPLE_TOKEN_KEY` sind die verschlüsselt gespeicherten Apple-Token nach Serververlust unbrauchbar; das Runbook nennt Ort und Wiederherstellung (ohne Werte).

**PO-Kontakte (angekündigt, zwei statt einem Termin; ersetzt den früheren Sammeltermin mit Mitbenutzung des Loose-Ends-Schlüssels, Begründung: Primary App ID, siehe Abschnitt 2)**

1. Kontakt 1: Apple-Portal und Namecheap (Einzelheiten in Abschnitt 2).
2. Kontakt 2: Claude-App, Konnektor mit Adresse `https://habits.henemm.com/mcp` anlegen und einmal mit Apple anmelden.

Werte (Schlüssel, Token, IDs aus secrets) gehen nie in Spec, Issue oder Nachrichten.

**Ende-zu-Ende-Prüfung:** In einem echten Claude-Gespräch über Hennings Konto mit dem Konnektor: `overview` und `catalog` lesen, Beispiel über `exercise_define` liefern, danach `delivery_status = waiting`.

**Rückrollweg**

- Dienst: `docker compose -f habits/docker-compose.yml down` (Daten bleiben im Volume); zurück auf früheren `HH_COMMIT` setzen und neu ausrollen.
- nginx: Site-Datei aus `sites-enabled` entfernen, `nginx -t`, Reload; andere Seiten bleiben unberührt.
- Sicherung/Monitor: die Habits-Einfügungen in `backup.sh`, `monitor.sh`, Prune-Skript per Revert des henemm-infra-Eintrags zurücknehmen; vorher Container mit `docker compose down` entfernen (nie nur `stop`), sonst Monitor-Alarm.
- Tür: `ALLOWED_APPLE_SUBS` beim Zurückrollen nie leeren, sondern den Dienst mit `down` beenden. (Der einmalige Fallback der Ersteinrichtung in Abschnitt 2 ist kein Zurückrollen.)
- Apple/DNS: nur bei endgültigem Abbau durch den PO entfernen.

### Drosselung je Bereich (Issue-Umfang)
Die Vorlage bringt in `nginx/habits.henemm.com.conf` fünf eigene Drosselungszonen `habits_*` mit (je Bereich: Gesundheit, Claude-Zugang /mcp, Anmeldung/OAuth samt Discovery, App-Anmeldung /auth, App-Abgleich /app), gleiche Bauart wie Loose Ends. Sie werden unverändert übernommen; das Netz von Anthropic (160.79.104.0/21) wird dabei nicht gesperrt.

## Abschnitt 2: Inbetriebnahme (Workflow feature-56-dienst-betrieb)

Abschnitt 1 (Einbau in henemm-infra, PR #561, 1043 Tests grün) ist erledigt und validiert. Abschnitt 2 nimmt den Dienst live in Betrieb. Er gilt auf Grundlage der Analyse vom 2026-11-28 (Variante A) und korrigiert die älteren Stellen oben (Schlüssel mitbenutzen, früher Container, Tür erst am Ende). Kein App-Code, keine Codeänderung in diesem Repo außer Spec und Belegen.

### Affected Files (Abschnitt 2)

| Datei | Change | Grund |
|---|---|---|
| henemm-infra `habits/docker-compose.yml` | MODIFY | `postgres:18.6` → `18.7` (`docker images` auf rennwienix am 2026-11-28 zeigt nur `postgres:18.7`; Ausgabe als Beleg zu L-AC-1b) |
| henemm-infra `scripts/restore-test-habits.sh` | MODIFY | Probe-Image 18.6 → 18.7 |
| henemm-infra `tests/test_habits_konfiguration.py` | MODIFY | erwartete Version 18.7 |
| henemm-infra `docs/habits-runbook.md` | MODIFY | neuer Schlüssel (Primary = Meditationstimer-App), `down` statt `stop`, Tür vor dem ersten Start |
| henemm-infra `security/expected-exposure.json` | MODIFY | Teil B, erst nach Außenprüfung (L-AC-10) |
| Server: `habits/secrets/`, `/etc/nginx/sites-available/habits.henemm.com` + Zertifikat, Prune-Skript auf Heimserver | CREATE | außerhalb Git |
| Dieses Repo: `DOCS/specs/infra/habits-dienst-betrieb.md` | MODIFY | Abschnitt-2-Teil, Changelog |
| Dieses Repo: `DOCS/artifacts/feature-56-dienst-betrieb/*.txt` | CREATE | Live-Belege L-AC-1b … L-AC-11 |

Umfang: henemm-infra PR 1 (Postgres 18.7, Runbook) 3–4 Dateien, ca. ±10 LoC; PR 2 (Teil B) ca. +30 LoC; App-Code 0. Risiko hoch (Produktivserver geteilt mit Loose Ends: nginx-Reload trifft alle Seiten; Monitor-Alarm), aber gut rückrollbar.

### Reihenfolge (Variante A)

1. **Claude:** PR in henemm-infra für Postgres 18.7 (Compose, Rückspielprobe, Test, Runbook), Tests grün, Merge; `auto-deploy-infra.sh` zieht ihn in den Server-Checkout.
2. **Claude, ohne PO:** `habits/secrets/` (700/600) mit erzeugten Werten; Apple-Felder zunächst gültig geformte Platzhalter (wie Implementation Details Schritt 2), echte Werte nach Kontakt 1; nginx-Site vorbereitet, **nicht** aktiviert; Prune-Skript auf den Heimserver kopieren (`habits-einbau.md` §4). **Kein früher Container** (auch gestoppt löst `habits-db` den Monitor-Alarm aus); falls doch einer entstanden ist: `docker compose down`, nie `stop`.
   - **Tür vorab:** `ALLOWED_APPLE_SUBS` wird vor dem ersten Start aus Hennings vorhandenem Loose-Ends-Konto gesetzt (Wert direkt per Datenbankabfrage in die Umgebungsdatei des Dienstes, nie ausgegeben). Grundlage: Apples Benutzerkennung ist je Entwickler-Team gleich (Apple, „Transferring your apps and users to another team“, siehe Recherche). Vorbedingung, geprüft und belegt in L-AC-1d: die Team-ID in der Umgebungsdatei von Loose Ends ist gleich `XK87E2B3VR` (der Prüfbefehl vergleicht nur und gibt `gleich`/`verschieden` aus) und die Loose-Ends-Datenbank hat genau ein Konto. Damit ist die Tür ab dem ersten Start geschlossen.
   - **Fallback (nur wenn die Vorbedingung nicht erfüllt ist oder Hennings Anmeldung in Kontakt 2 abgewiesen wird):** Ersteinrichtung nach Prüfliste Nr. 30: Dienst ohne `ALLOWED_APPLE_SUBS` ausrollen (wie Schritt 3, damit L-AC-2/L-AC-3 vor Kontakt 2 grün sind); Kontakt 2 folgt dann unmittelbar im selben Termin, sodass vom ersten Start bis zur gesetzten Liste höchstens 60 Minuten vergehen; Henning meldet sich als erstes Konto an (der Dienst nimmt nur das erste Konto an); sofort danach setzt Claude `ALLOWED_APPLE_SUBS` aus der Kontentabelle des Habits-Dienstes und rollt erneut aus. Die Adresse wird vorher nirgends veröffentlicht. Beleg: L-AC-8.
3. **PO-Kontakt 1** (ca. 30 min, angekündigt): Apple-Portal zuerst, dann Namecheap (Schritte unten). Claude übernimmt die `.p8` ohne sie anzuzeigen auf den Server, wartet per `dig` auf den A-Eintrag, dann in einem Zug: `nginx -t` + Reload, certbot, `deploy-habits.sh`, L-AC-2 bis L-AC-4 von außen.
4. **PO-Kontakt 2** (ca. 5 min): Konnektor in Claude anlegen und mit Apple anmelden; erst wenn L-AC-2 und L-AC-3 grün sind (Claude-Cache zu Konnektoren etwa 5 min).
5. **Claude:** Sicherungslauf und Rückspielprobe (L-AC-5, L-AC-6), Monitor (L-AC-7), Tür-Nachweis (L-AC-8), Ende-zu-Ende in einem Claude-Gespräch über den Konnektor (L-AC-9), Teil B (L-AC-10). Belege als Textdateien, keine Geheimniswerte.

Ausrollen nur per SSH aus einer Tailnet-Sitzung (Alias `rennwienix`), nie im Backup-Fenster 02:45–03:30; vor jedem nginx-Reload `nginx -t`.

### PO-Kontakt 1 (Alltagssprache, nummeriert)

1. Im Apple-Entwicklerportal bei der App mit der Kennung `henemm.Meditationstimer-iOS` „Sign in with Apple" einschalten.
2. Eine neue „Services ID" mit der Kennung `henemm.habits.web` anlegen. Als Hauptapp (Primary App ID) die Meditationstimer-App wählen (`henemm.Meditationstimer-iOS`), nicht die Loose-Ends-App. Dieser Schritt kommt zuerst, weil Apple beim Speichern der Website-Adressen zeitweise eine Störung (501) meldet; dann später noch einmal versuchen.
3. In dieser Services ID als Domain `habits.henemm.com` und als Rücksprung-Adresse `https://habits.henemm.com/oauth/apple/return` eintragen.
4. Einen **neuen** Sign-in-with-Apple-Schlüssel anlegen, mit derselben Hauptapp (Primary App ID = Meditationstimer-App), und die `.p8`-Datei herunterladen und an Claude übergeben. Den Loose-Ends-Schlüssel nicht mitbenutzen: Services ID und Schlüssel müssen dieselbe Primary App ID haben, sonst meldet Apple `invalid_client`.
5. Bei Namecheap einen A-Eintrag anlegen: Host `habits` (also `habits.henemm.com`) auf `178.104.143.19`.

### PO-Kontakt 2 (Alltagssprache, nummeriert)

1. In der Claude-App einen neuen Konnektor anlegen mit der Adresse `https://habits.henemm.com/mcp`.
2. Einmal mit Apple anmelden. Claude meldet, sobald der Ablauf geprüft ist.

Werte (Schlüssel, Token, IDs) gehen nie in Spec, Issue oder Nachrichten.

### Varianten

| Variante | PO-Kontakte | Dauer PO | Risiko |
|---|---|---|---|
| **A (gewählt):** neuer Schlüssel, Primary = Meditationstimer-App | 2 | ca. 35 min | niedrig, Loose Ends unberührt |
| B: Loose-Ends-Schlüssel mitbenutzen (frühere Spec) | 1 (+1 Nacharbeit) | ca. 40 min | mittel: App-Anmeldung (#57) scheitert voraussichtlich |
| C: Meditationstimer-App unter Loose-Ends-Primary gruppieren | 1–2 | ca. 40 min | mittel: ändert die laufende Loose-Ends-Anmeldung |
| D: Spec wörtlich (3 Termine, Tür offen bis zum Ende) | 3 | ca. 50 min | mittel |

### Recherche-Quellen (2026-11-28)

- Services ID und Schlüssel müssen dieselbe Primary App ID haben, sonst `invalid_client`: Apple Developer Forums [820967](https://developer.apple.com/forums/thread/820967), [813131](https://developer.apple.com/forums/thread/813131). Der Dienst löst auch App-Codes mit `client_id = henemm.Meditationstimer-iOS` ein (für #57), daher scheidet die Mitbenutzung des Loose-Ends-Schlüssels (Primary = Loose-Ends-App) aus.
- Störung 501 beim Speichern der Website-URLs einer Services ID: [Forum 797201](https://developer.apple.com/forums/thread/797201).
- Services IDs sind nicht über die App-Store-Connect-API anlegbar, nur im Portal.
- Apples Benutzerkennung (`sub`) ist je Entwickler-Team gleich und wird beim Wechsel des Teams umgeschlüsselt: Apple Developer Documentation [Transferring your apps and users to another team](https://developer.apple.com/documentation/sign_in_with_apple/transferring-your-apps-and-users-to-another-team).
- Namecheap-API erst ab 20 Domains bzw. 50 $ Guthaben/Umsatz plus IP-Freigabe, `setHosts` ersetzt die ganze Zone: [Namecheap FAQ](https://www.namecheap.com/support/knowledgebase/article.aspx/9739/63/api--faq); der PO trägt den einen Eintrag selbst ein.

## Test Plan

### Automated Tests (TDD RED), Abschnitt 1

Die 60 Habits-Tests der Vorlage in `henemm-infra/tests/test_*habits*.py` sind die automatisierten Tests. RED-Nachweis: Tests laufen gegen aktuelles henemm-infra-`main` ohne den Einbau und schlagen fehl (Dateien/Einfügungen fehlen).

- [ ] Test 1: GIVEN aktuelles `main` ohne Habits-Einbau WHEN `pytest tests -k habits` THEN rot (RED-Nachweis).
- [ ] Test 2: GIVEN eingebauter Stand WHEN `pytest tests` THEN alle grün, 60 Habits-Tests, keine Regression in bestehenden Tests zu backup.sh/monitor.sh.
- [ ] Test 3: GIVEN `deploy-habits.sh` WHEN Pflichtnamen fehlen oder falsch geformt sind THEN Abbruch vor dem Start.
- [ ] Test 4: GIVEN `monitor.sh` ohne `habits-db` WHEN Lauf THEN kein Habits-Alarm.

### Abschnitt 2

Abschnitt 2 wird nicht per TDD-Unit-Test geprüft, sondern per Live-Nachweisen: `curl`, `restic`, `monitor.sh`, `stat`, `grep` und ein echtes Claude-Gespräch über den Konnektor. Die einzige automatisierte Prüfung sind die henemm-infra-Tests für die Versionsänderung.

- [ ] Test 5 (RED/GREEN): GIVEN der Test in `tests/test_habits_konfiguration.py` erwartet `postgres:18.7` WHEN er vor der Änderung läuft THEN rot (Compose und Probe stehen auf 18.6); nach der Änderung grün.
- [ ] Live-Nachweise L-AC-1b bis L-AC-11 (siehe Acceptance Criteria), je mit Beleg-Textdatei unter `DOCS/artifacts/feature-56-dienst-betrieb/`.

## Acceptance Criteria

Aufteilung nach PO-Entscheidung 2026-11-28: **Abschnitt 1** = Einbau in henemm-infra, geprüft und übernommen (erledigt). **Abschnitt 2** (Workflow `feature-56-dienst-betrieb`) = Inbetriebnahme mit zwei PO-Kontakten und Live-Nachweisen; Issue #56 bleibt bis zum Ende von Abschnitt 2 offen.

### Abschnitt 1

- **AC-1:** Given der Einbau in henemm-infra ist auf aktuellem Stand übernommen / When `cd /home/hem/henemm-infra && python3 -m pytest tests` läuft / Then alle Tests grün, darin die 60 Habits-Tests, und `HH_COMMIT` in `scripts/deploy-habits.sh` ist `d7705c320e6a47d9971991635c67960f1b98e745`.
- **AC-5a:** Given der Einbau-Stand / When `scripts/backup.sh` gelesen und `tests/test_habits_betrieb_56.py::test_backup_sichert_habits_secrets_vollstaendig` sowie `tests/test_backup_habits.py` laufen / Then `habits/secrets` (auch `db-password`) geht in den restic-Aufruf, ein fehlender Ordner bricht die Sicherung nicht, eine scheiternde Docker-Abfrage nach `habits-db` bricht ohne Heartbeat ab.
- **AC-11:** Given der Einbau-Stand / When `git grep` nach Geheimniswerten im Einbau sucht / Then keine Geheimniswerte in Repo, Issue oder Nachrichten.

### Abschnitt 2 (Inbetriebnahme, Live-Nachweise)

Für jede L-AC gilt: Der Beleg liegt als Textdatei unter `DOCS/artifacts/feature-56-dienst-betrieb/` in diesem Repo, ohne Geheimniswerte.

- **L-AC-1b:** Given der PR für Postgres 18.7 ist gemergt / When `python3 -m pytest tests -q` in henemm-infra und `grep image habits/docker-compose.yml` / Then alle `tests/test_habits_*.py` grün; die Menge der übrigen fehlschlagenden Tests ist identisch mit einem Lauf auf `main` vor der Änderung im selben Wegwerfklon (Vorher-Nachher-Vergleich, beide Listen im Beleg); Image `postgres:18.7` in Compose und Probe, kein `18.6` mehr in `habits/` und `scripts/*habits*`.
- **L-AC-1d:** Given die Umgebungsdatei von Loose Ends auf rennwienix / When ein Vergleichsbefehl die dortige `APPLE_TEAM_ID` mit `XK87E2B3VR` vergleicht (Ausgabe nur `gleich`/`verschieden`) und eine Zählabfrage die Konten der Loose-Ends-Datenbank zählt (Ausgabe nur die Zahl) / Then `gleich` und `1` → Tür vorab; sonst gilt der Fallback (L-AC-8b). Beleg: beide Ausgaben mit Zeitstempel.
- **L-AC-1c:** Given Secrets angelegt und die echten Apple-Werte nach Kontakt 1 eingetragen, unmittelbar vor dem ersten `deploy-habits.sh` / When `stat` auf `habits/secrets` und Dateien / Then Ordner 700, Dateien 600, in der Umgebungsdatei die Namen `DATABASE_URL`, `PUBLIC_URL`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_CLIENT_IDS`, `APPLE_WEB_CLIENT_ID`, `APPLE_TOKEN_KEY`, `OAUTH_COOKIE_KEYS`, `OAUTH_SIGNING_JWK` plus `ALLOWED_APPLE_SUBS` (außer im Fallback vor Kontakt 2) mit nicht leerem Wert, dazu die Datei für das Datenbank-Passwort (Prüfung per Zählung `^NAME=.+`, nur Namen und Zählung im Beleg).
- L-AC-2: Given der Dienst ist ausgerollt / When `curl -s -w '%{http_code}' https://habits.henemm.com/health` / Then Antwort 200 und der Inhalt enthält `"migrated":true`.
- L-AC-3: Given keine Anmeldung / When `curl -si -X POST https://habits.henemm.com/mcp` / Then 401 mit Header `WWW-Authenticate`.
- L-AC-4: Given die nginx-Konfiguration ist live / When `sudo nginx -T | grep -E 'habits_|nodelay'` (der Block `location = /health` der Habits-Site enthält `limit_req zone=habits_health burst=10 nodelay`, Auszug mit Zeilennummern im Beleg), dann 25 Anfragen auf `https://habits.henemm.com/health` innerhalb von 3 Sekunden von einem Rechner, und `sudo fail2ban-client status` samt `nginx -T | grep -E 'deny|allow'` / Then die fünf Zonen `habits_health`, `habits_mcp`, `habits_oauth`, `habits_auth`, `habits_app` sind geladen; von den 25 Antworten sind mindestens 10 Antworten 200 und mindestens 5 Antworten 429 (Zone 30 r/min, burst 10, `limit_req_status 429`); keine Sperrregel und keine fail2ban-Sperre trifft 160.79.104.0/21.
- L-AC-5: Given der Dienst läuft / When ein `backup.sh`-Lauf erfolgt / Then er endet erfolgreich, `restic snapshots --tag habits` zeigt einen neuen Snapshot und `habits/secrets` ist in der Sicherung enthalten: der Snapshot dieses Laufs, der die Geheimnisdateien enthält (`restic snapshots` nach Lauf-Zeitstempel, ID im Beleg), listet per `restic ls <ID>` die Dateien `habits/secrets/server.env` und `habits/secrets/db-password` (nur Dateinamen im Beleg), und `restic dump <ID>` von `habits/secrets/server.env`, gefiltert auf `grep -c '^APPLE_TOKEN_KEY=.\+'`, ergibt `1` (nur die Zählung im Beleg, nie der Wert).
- L-AC-6: Given ein aktueller Habits-Snapshot / When `sudo bash scripts/restore-test-habits.sh` / Then Exit-Code 0.
- L-AC-7: Given der Dienst läuft / When `bash scripts/monitor.sh` / Then die Ausgabe enthält für `https://habits.henemm.com/health` kein FAIL/Alarm und der Lauf endet mit Exit 0; es wurde kein eigener BetterStack-Monitor für habits angelegt (habits ist Teil-Check von `monitor.sh`, `git diff 4b054be..origin/main -- scripts/monitor.sh` in henemm-infra enthält keine BetterStack-Monitor-Anlage).
- **L-AC-8 (präzisiert; Teil (a) nur ohne Fallback, im Fallback ersetzt durch L-AC-8b; (b) und (c) immer):** Given der Name `ALLOWED_APPLE_SUBS` ist mit Hennings Konto gesetzt, und zwar vor dem ersten `deploy-habits.sh` / When ein anderes Konto sich anmelden will / Then wird es abgelehnt. Belegt durch: (a, live) Zeitstempel: die Änderungszeit der Umgebungsdatei mit dem Namen `ALLOWED_APPLE_SUBS` liegt vor der Erstellzeit des ersten `habits-server`-Containers (`docker inspect -f '{{.Created}}'`); (b, live) nach Kontakt 2 gibt eine SQL-Abfrage auf die Kontentabelle (genau ein Konto, dessen Apple-Kennung in der Liste steht) nur `t`/`f` aus und ergibt `t`; (c) die Ablehnung eines fremden Kontos selbst ist durch die B2b-Tests `anmeldung.test.ts` › „tuer app: fremdes konto wird abgewiesen, nichts gespeichert“ und › „tuer web: fremdes konto wird abgewiesen, nichts gespeichert“ belegt (automatisierter Test, kein Live-Nachweis: ein zweites Apple-Konto steht live nicht zur Verfügung).
- **L-AC-8b (nur im Fallback):** Given L-AC-1d ergab nicht `gleich`/`1` oder Hennings Anmeldung wurde abgewiesen, der Dienst läuft ohne `ALLOWED_APPLE_SUBS` / When Henning sich in Kontakt 2 als erstes Konto anmeldet und Claude danach die Liste setzt und neu ausrollt / Then liegen zwischen der Anlagezeit des einzigen Kontos (Zeitstempel-Spalte der Kontentabelle, im Beleg benannt) und der Erstellzeit des neuen `habits-server`-Containers höchstens 15 Minuten, zwischen der Erstellzeit des ersten und des neuen `habits-server`-Containers höchstens 60 Minuten, und die SQL-Prüfung aus L-AC-8 (b) ergibt `t`.
- L-AC-9: Given der Konnektor ist in Hennings Claude-Konto verbunden / When Claude `overview` und `catalog` liest und ein Beispiel über `exercise_define` liefert / Then `delivery_status` meldet „waiting“; Beleg als Textdatei unter `DOCS/artifacts/feature-56-dienst-betrieb/` (Werkzeugaufrufe und Antworten ohne Token), dazu eine Kurzfassung mit Link auf den Beleg als Kommentar im Issue #56.
- L-AC-10: Given L-AC-2, L-AC-3 und L-AC-4 sind belegt (die öffentlich erreichbaren Pfade und Ports per `curl` und `nmap`/`check-external-exposure.sh` ermittelt) / When Teil B eingebaut ist / Then `security/expected-exposure.json` enthält habits.henemm.com, `bash scripts/check-external-exposure.sh` endet mit Exit 0 und `python3 -m pytest tests/test_external_scan.py -q` ist grün.
- **L-AC-11:** Given das Prune-Skript ist auf dem Heimserver / When `grep -n habits` im Prune-Skript auf dem Heimserver und `diff` gegen `scripts/restic-prune-heimserver.sh` aus henemm-infra `main` / Then die Dateien sind gleich, das Skript enthält `HH_DAYS=28` (wie `LE_DAYS=28`) und behandelt Snapshots mit Tag `habits` (Zeilen per `grep -n` im Beleg).

## Definition of Done

- [ ] Alle Acceptance Criteria oben erfüllt und mit Prüfbefehl belegt.
- [ ] Betriebsvorlage in henemm-infra auf aktuellem Stand übernommen, Tests grün, Runbook aktualisiert.
- [ ] Dienst läuft unter https://habits.henemm.com, Sicherung und Gesundheitsprüfung nachweislich aktiv.
- [ ] Ende-zu-Ende-Prüfung bestanden und im Issue #56 dokumentiert; Issue #56 geschlossen.

### Definition of Done, Abschnitt 2

- [ ] Alle L-ACs (L-AC-1b, 1c, 1d, 2 bis 11; L-AC-8b nur im Fallback) sind mit Textbeleg unter `DOCS/artifacts/feature-56-dienst-betrieb/` belegt, ohne Geheimniswerte.
- [ ] henemm-infra-Tests für Postgres 18.7 grün und gemergt; Runbook auf neuen Schlüssel, `down` statt `stop` und Tür vor dem ersten Start aktualisiert.
- [ ] Issue #56 wird erst geschlossen, wenn alle L-ACs belegt sind.
- [ ] Spec `status` wird am Ende auf `active` gesetzt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Betrieb nach bestehendem Muster (Loose Ends); keine neue Architektur. Die frühere Betriebsentscheidung „Apple-Schlüssel mitbenutzen“ ist am 2026-11-28 durch die Analyse zu Abschnitt 2 ersetzt: neuer Schlüssel mit Primary App ID = Meditationstimer-App.

## Changelog

- 2026-11-28: Initial spec created
- 2026-11-28: Abnahme in Abschnitt 1 (Einbau) und Abschnitt 2 (Inbetriebnahme, Live-Nachweise) geteilt, PO-Entscheidung
- 2026-11-28: Abschnitt 2 (Workflow feature-56-dienst-betrieb) ergänzt: neuer SiwA-Schlüssel statt Mitbenutzung des Loose-Ends-Schlüssels (Begründung: Services ID und Schlüssel brauchen dieselbe Primary App ID), zwei PO-Kontakte statt eines Termins, kein früher Container und `docker compose down` statt `stop` (ein vorhandener `habits-db` löst den Monitor-Alarm aus), Tür (`ALLOWED_APPLE_SUBS`) vorab vor dem ersten Start, Postgres 18.7 statt 18.6, Prune-Skript im Ablauf; neue L-AC-1b, L-AC-1c, L-AC-11, L-AC-8 präzisiert, Belege je L-AC als Textdatei
