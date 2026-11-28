---
entity_id: habits-dienst-betrieb
type: feature
created: 2026-11-28
updated: 2026-11-28
status: draft
workflow: feat-56-habits-dienst-betrieb
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
| henemm-infra `habits/docker-compose.yml` | CREATE | habits-db (postgres:18.6), habits-server auf 127.0.0.1:8781 |
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

**Reihenfolge**

1. Claude: Vorlage auf aktuelles henemm-infra-`main` neu aufsetzen (nur Habits-Einfügungen), `HH_COMMIT` setzen, Tests grün, übernehmen.
2. Claude: `habits/secrets/` anlegen (700/600). Erzeugte Werte (DB-Passwort, `APPLE_TOKEN_KEY` = base64 32 Byte, Cookie-Schlüssel ≥ 32 Zeichen); Apple-Werte zunächst gültig geformte Platzhalter (EC P-256). Image bauen, lokale Probe nur kurz, danach Container wieder stoppen.
3. PO, gebündelt in einem angekündigten Termin (siehe unten).
4. Claude: nginx und certbot einrichten, erst dann Dienst dauerhaft starten, ausrollen, Außenprüfung, echte Apple-Werte eintragen, erneut ausrollen.
5. PO: Konnektor in Claude anlegen, einmal mit Apple anmelden.
6. Claude: Tür schließen (`ALLOWED_APPLE_SUBS` auf Hennings Konto), erneut ausrollen; Restore-Test einmal; Teil B `security/expected-exposure.json`; Ende-zu-Ende-Prüfung.

**Monitor-Falle:** `monitor.sh` alarmiert, sobald `habits-db` existiert und die öffentliche `/health` nicht 200 liefert. Der Dienst darf deshalb erst dauerhaft laufen, wenn DNS und Zertifikat stehen.

**Sicherung der Geheimnisse:** `backup.sh` sammelt Umgebungsdateien nur per `find … -name '*.env'` bis Tiefe 3 unter `/home/hem/henemm-infra`. `habits/secrets/` (Tiefe 2) wird nur erfasst, wenn die Dateien auf `.env` enden; `db-password` und ähnliche Dateien nicht. Vor dem Einbau prüfen, was erfasst wird; fehlt etwas, `habits/secrets` explizit in die Liste der gesicherten Dateien aufnehmen (restic-verschlüsselt, off-site). Ohne gesichertes `APPLE_TOKEN_KEY` sind die verschlüsselt gespeicherten Apple-Token nach Serververlust unbrauchbar; das Runbook nennt Ort und Wiederherstellung (ohne Werte).

**PO-Termin (einmal angekündigt, gebündelt)**

1. Namecheap: A-Eintrag `habits.henemm.com` auf 178.104.143.19.
2. Apple-Portal: Sign in with Apple an App-ID `henemm.Meditationstimer-iOS` aktivieren; Services ID `henemm.habits.web` mit Domain `habits.henemm.com` und Rücksprung `https://habits.henemm.com/oauth/apple/return`; Key-ID des vorhandenen Loose-Ends-SiwA-Schlüssels mitbenutzen (Empfehlung, gleiche Team-ID; liegt er nicht auf dem Server, neuen Schlüssel anlegen und .p8 übergeben).
3. Claude-App: Konnektor mit Adresse `https://habits.henemm.com/mcp` anlegen und einmal mit Apple anmelden.

Werte (Schlüssel, Token, IDs aus secrets) gehen nie in Spec, Issue oder Nachrichten.

**Ende-zu-Ende-Prüfung:** In einem echten Claude-Gespräch über Hennings Konto mit dem Konnektor: `overview` und `catalog` lesen, Beispiel über `exercise_define` liefern, danach `delivery_status = waiting`.

**Rückrollweg**

- Dienst: `docker compose -f habits/docker-compose.yml down` (Daten bleiben im Volume); zurück auf früheren `HH_COMMIT` setzen und neu ausrollen.
- nginx: Site-Datei aus `sites-enabled` entfernen, `nginx -t`, Reload; andere Seiten bleiben unberührt.
- Sicherung/Monitor: die Habits-Einfügungen in `backup.sh`, `monitor.sh`, Prune-Skript per Revert des henemm-infra-Eintrags zurücknehmen; vorher Container stoppen, sonst Monitor-Alarm.
- Tür: `ALLOWED_APPLE_SUBS` nie leeren, sondern bei Zurückrollen den Dienst stoppen.
- Apple/DNS: nur bei endgültigem Abbau durch den PO entfernen.

### Drosselung je Bereich (Issue-Umfang)
Die Vorlage bringt in `nginx/habits.henemm.com.conf` fünf eigene Drosselungszonen `habits_*` mit (je Bereich: Gesundheit, Claude-Zugang /mcp, Anmeldung/OAuth samt Discovery, App-Anmeldung /auth, App-Abgleich /app), gleiche Bauart wie Loose Ends. Sie werden unverändert übernommen; das Netz von Anthropic (160.79.104.0/21) wird dabei nicht gesperrt.

## Test Plan

### Automated Tests (TDD RED)

Die 60 Habits-Tests der Vorlage in `henemm-infra/tests/test_*habits*.py` sind die automatisierten Tests. RED-Nachweis: Tests laufen gegen aktuelles henemm-infra-`main` ohne den Einbau und schlagen fehl (Dateien/Einfügungen fehlen).

- [ ] Test 1: GIVEN aktuelles `main` ohne Habits-Einbau WHEN `pytest tests -k habits` THEN rot (RED-Nachweis).
- [ ] Test 2: GIVEN eingebauter Stand WHEN `pytest tests` THEN alle grün, 60 Habits-Tests, keine Regression in bestehenden Tests zu backup.sh/monitor.sh.
- [ ] Test 3: GIVEN `deploy-habits.sh` WHEN Pflichtnamen fehlen oder falsch geformt sind THEN Abbruch vor dem Start.
- [ ] Test 4: GIVEN `monitor.sh` ohne `habits-db` WHEN Lauf THEN kein Habits-Alarm.

## Acceptance Criteria

- **AC-1:** Given der Einbau in henemm-infra ist auf aktuellem Stand übernommen / When `cd /home/hem/henemm-infra && python3 -m pytest tests` läuft / Then alle Tests grün, darin die 60 Habits-Tests, und `HH_COMMIT` in `scripts/deploy-habits.sh` ist `d7705c320e6a47d9971991635c67960f1b98e745`.
- **AC-2:** Given der Dienst ist ausgerollt / When `curl -s -w '%{http_code}' https://habits.henemm.com/health` / Then Antwort 200 und der Inhalt enthält `"migrated":true`.
- **AC-3:** Given keine Anmeldung / When `curl -si -X POST https://habits.henemm.com/mcp` / Then 401 mit Header `WWW-Authenticate`.
- **AC-4:** Given die nginx-Konfiguration ist live / When `sudo nginx -T | grep habits_` und eine Anfragenserie auf `/health` über die Grenze / Then eigene Zonen `habits_*` je Bereich (Gesundheit, /mcp, OAuth samt Discovery, /auth, /app) sind aktiv und die Serie wird ab der Grenze abgewiesen (429 oder 503); das Netz 160.79.104.0/21 ist nicht gesperrt.
- **AC-5:** Given der Dienst läuft / When ein `backup.sh`-Lauf erfolgt / Then er endet erfolgreich, `restic snapshots --tag habits` zeigt einen neuen Snapshot und `habits/secrets` (inkl. Wert für `APPLE_TOKEN_KEY`) ist in der Sicherung enthalten (Prüfung per `restic ls`, nur Dateinamen).
- **AC-6:** Given ein aktueller Habits-Snapshot / When `sudo bash scripts/restore-test-habits.sh` / Then Exit-Code 0.
- **AC-7:** Given der Dienst läuft / When `bash scripts/monitor.sh` / Then für habits kein Fehler; das BetterStack-Kontingent bleibt bei 7/10.
- **AC-8:** Given `ALLOWED_APPLE_SUBS` ist mit Hennings Konto gesetzt und neu ausgerollt / When sich ein anderes Konto anmelden will / Then wird es abgelehnt (in Code-Test von B2b belegt und Einstellung live per Namensprüfung bestätigt).
- **AC-9:** Given der Konnektor ist in Hennings Claude-Konto verbunden / When Claude `overview` und `catalog` liest und ein Beispiel über `exercise_define` liefert / Then `delivery_status` meldet „waiting“; die Ausgabe ist im Issue #56 dokumentiert.
- **AC-10:** Given alle Werte sind per `curl` bestätigt / When Teil B eingebaut ist / Then `security/expected-exposure.json` enthält habits.henemm.com und der Security-Abgleich bleibt grün.
- **AC-11:** Given der Einbau-Stand / When `git grep` nach Geheimniswerten im Einbau sucht / Then keine Geheimniswerte in Repo, Issue oder Nachrichten.

## Definition of Done

- [ ] Alle Acceptance Criteria oben erfüllt und mit Prüfbefehl belegt.
- [ ] Betriebsvorlage in henemm-infra auf aktuellem Stand übernommen, Tests grün, Runbook aktualisiert.
- [ ] Dienst läuft unter https://habits.henemm.com, Sicherung und Gesundheitsprüfung nachweislich aktiv.
- [ ] Ende-zu-Ende-Prüfung bestanden und im Issue #56 dokumentiert; Issue #56 geschlossen.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Betrieb nach bestehendem Muster (Loose Ends); keine neue Architektur. Entscheidung Apple-Schlüssel mitbenutzen ist eine Betriebsentscheidung, im Issue vermerkt.

## Changelog

- 2026-11-28: Initial spec created
