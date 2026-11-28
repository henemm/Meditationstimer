# Kontext: feat-56-habits-dienst-betrieb (Issue #56, B2c)

## Auftrag
Dienst der Claude-Verbindung (`server/`, Node 26/TypeScript, Postgres, MCP Streamable HTTP, OAuth 2.1 + Sign in with Apple)
auf dem Produktivserver in Betrieb nehmen. Betriebsvorlage aus henemm/henemm-infra PR #454 übernehmen.
Fertig, wenn: Dienst unter eigener Adresse, Sicherung und Gesundheitsprüfung nachweislich aktiv, Ende-zu-Ende-Prüfung
(Claude liest Katalog, liefert Beispiel, `delivery_status` = wartet) bestanden.
Abhängigkeiten B2a (#54) und B2b (#55): geschlossen. Folge-Issue #57 (App-Abgleich, Mac).

## Betroffene Dateien
- **Dieses Repo:** keine Codeänderung erwartet. `server/Dockerfile` (Build-Kontext Repo-Wurzel), `server/src/*`,
  `server/migrations/001–009`. Doku: `DOCS/konzept-claude-verbindung.md` §11, `DOCS/claude-anmeldung-pruefliste.md` (Nr. 1, 14–16, 27, 30).
- **henemm-infra, PR #454** (Zweig `claude/friendly-dirac-b5tg6a`, vom 13.11., mischt sich konfliktfrei auf aktuellen Stand,
  obwohl `backup.sh`/`monitor.sh` seitdem 12× geändert wurden → Tests nach Nachziehen erneut laufen lassen):
  `habits/docker-compose.yml` (habits-db postgres:18.6, habits-server 127.0.0.1:8781), `nginx/habits.henemm.com.conf`,
  `scripts/deploy-habits.sh` (fester `HH_COMMIT`), `scripts/backup-habits-snapshot.sh`, `scripts/restore-test-habits.sh`,
  Einfügungen `scripts/backup.sh`, `scripts/monitor.sh`, `scripts/restic-prune-heimserver.sh`, Tests `tests/test_*habits*.py`,
  `docs/habits-runbook.md` (Schritte 1–10), `docs/habits-einbau.md` (Teil B: `security/expected-exposure.json`).

## Bestehende Muster
Loose Ends läuft genauso: `henemm-infra/loose-ends/` mit Compose-Datei und `secrets/` (700/600, `db-password`,
Server-Umgebungsdatei). Container `loose-ends-server`/`loose-ends-db` laufen. Sudo ohne Passwort und Docker verfügbar.

## Was nur Henning kann (externe Konten ohne Zugang für Claude)
1. **DNS:** A-Eintrag `habits.henemm.com` → 178.104.143.19 bei Namecheap (kein API-Zugang, siehe henemm-infra docs/mail.md).
   Stand 28.11.: löst nicht auf.
2. **Apple-Developer-Portal:** Sign in with Apple für App-ID `henemm.Meditationstimer-iOS`, Services ID (z. B.
   `henemm.habits.web`, Domain + Rücksprung `https://habits.henemm.com/oauth/apple/return`), Schlüssel (.p8 + Key-ID; ggf. den
   Loose-Ends-Schlüssel mitbenutzen). Services IDs lassen sich nicht per App-Store-Connect-API anlegen.
3. **Konnektor in Claude** hinzufügen und mit Apple anmelden (Runbook Schritt 8).
Diese drei in einem einzigen angekündigten Termin bündeln (Issue: „genau ein Schritt, vorher ankündigen“).

## Risiken
- Geheimnisse: nie Werte in Repo/Issue/Nachricht; Secrets-Guard-Hook blockiert Lesen der Umgebungsdateien.
- Tür: ohne `ALLOWED_APPLE_SUBS` kommt nur das erste Konto herein → direkt nach Hennings Anmeldung schließen (Runbook 7).
- Backup-Fenster 02:45–03:30 meiden (Deploy-Skript bricht ab).
- BetterStack-Kontingent 7/10; private Projekte höchstens ein Uptime-Monitor, sonst Teil-Check in `monitor.sh` (Vorlage macht das).
- nginx: keine Sperre vor `/.well-known/*`, Netz 160.79.104.0/21 (Anthropic) nicht sperren.
- Ende-zu-Ende-Prüfung braucht ein echtes Claude-Gespräch über Hennings Konto mit dem Konnektor.

## Analysis

**Type:** Feature (Betrieb/Inbetriebnahme), Ort Server.

### Ergebnis des Abgleichs Vorlage ↔ Dienst (Stand origin/main d7705c3)
- Umgebungsnamen: Code liest genau die zehn Pflichtnamen aus Runbook Schritt 4 (+ optional `ALLOWED_APPLE_SUBS`); deploy-habits.sh prüft dieselben zehn. Formatregeln: Apple-Schlüssel EC P-256, `APPLE_TOKEN_KEY` base64 32 Byte, Cookie-Keys ≥ 32 Zeichen, `PUBLIC_URL` ohne Pfad/Schrägstrich, Web-Client-ID ≠ App-ID.
- nginx-Erlaubnisliste deckt alle Routen ab (/health, /mcp, Discovery, /oauth/*, /auth/*, /app/*). Suffix-Discovery-Pfade liefern 404 wie bei Loose Ends (funktioniert dort).
- Dockerfile-COPY-Pfade passen zum aktuellen Stand; keine Anpassung nötig.
- /health liefert 200 nur bei migrated + DB + kein Fehlerfenster; passt zu Deploy-Skript und monitor.sh.
- **HH_COMMIT veraltet** (a29c74d vom 13.11.) → auf d7705c320e6a47d9971991635c67960f1b98e745 setzen (voller SHA nötig).
- **PR-Zweig veraltet:** enthält in monitor.sh Altstände (entfernt mailadmin/tailscale/gregor-Einträge, ergänzt wireguard). Nicht übernehmen wie er ist: auf aktuelles main neu aufsetzen, nur Habits-Einfügungen behalten.
- **Monitor-Falle:** monitor.sh alarmiert, sobald `habits-db` existiert und die öffentliche /health nicht 200 liefert → DNS + Zertifikat müssen stehen, bevor der Dienst dauerhaft läuft (lokale Probe vorher nur kurz, Container danach wieder stoppen, oder erst nach DNS starten).
- `APPLE_TOKEN_KEY` verschlüsselt gespeicherte Apple-Token: Wert muss gesichert werden (Runbook-Ergänzung), sonst nach Serververlust unbrauchbar. Wird ohnehin im restic-Backup von henemm-infra/habits/secrets mitgesichert? → in Spec prüfen.

### Affected Files
- henemm-infra (neu aufgesetzter Zweig aus PR #454): CREATE habits/docker-compose.yml, habits/.gitignore, nginx/habits.henemm.com.conf, scripts/deploy-habits.sh (HH_COMMIT neu), scripts/backup-habits-snapshot.sh, scripts/restore-test-habits.sh, tests/test_*habits*.py, docs/habits-runbook.md, docs/habits-einbau.md; MODIFY scripts/backup.sh, scripts/monitor.sh, scripts/restic-prune-heimserver.sh, docs/backup-offsite.md, docs/backup-restore.md; später MODIFY security/expected-exposure.json (Teil B).
- Server live: /etc/nginx/sites-available/habits.henemm.com, Zertifikat, henemm-infra/habits/secrets/ (nicht versioniert), Prune-Skript auf Heimserver.
- Dieses Repo: keine Codeänderung; Doku-Vermerk im Issue.

### Scope / Risiko
Mittel–hoch: Produktivserver, nginx-Reload (betrifft alle Seiten, abgesichert durch `nginx -t`), neue Sicherungskette. Dienst selbst isoliert (eigene Container, eigene DB, nur 127.0.0.1).

### Technischer Ansatz (Reihenfolge)
1. Claude: Vorlage auf aktuelles henemm-infra-main neu aufsetzen, HH_COMMIT setzen, Tests grün, übernehmen.
2. Claude: secrets anlegen (erzeugte Werte; Apple-Werte zunächst gültig geformte Platzhalter), Image bauen, lokale Probe.
3. PO (gebündelt, ein Termin, angekündigt): DNS-A-Eintrag, Apple-Portal (Sign in with Apple an App-ID, Services ID mit Rücksprung-URL, Schlüssel bzw. Key-ID des vorhandenen Loose-Ends-Schlüssels).
4. Claude: nginx + certbot, Ausrollen, Außenprüfung (/health 200, /mcp 401 mit WWW-Authenticate), echte Apple-Werte eintragen.
5. PO: Konnektor in Claude anlegen, einmal mit Apple anmelden.
6. Claude: Tür schließen (ALLOWED_APPLE_SUBS), erneut ausrollen; Restore-Test; Teil B expected-exposure; Ende-zu-Ende-Prüfung.

### Open Questions
- Apple-Schlüssel: vorhandenen Loose-Ends-Schlüssel (Team-weit gültig) mitbenutzen vs. neuen anlegen → Empfehlung mitbenutzen (weniger Handarbeit für PO, gleiche Team-ID). Technische Entscheidung, kein PO-Thema, außer der Schlüssel liegt nicht auf dem Server.
- Ende-zu-Ende-Prüfung: aus einem Claude-Gespräch mit dem Konnektor; kann eine Cloud-/Desktop-Sitzung von Henning sein oder per MCP-Client mit Token. Wird in der Spec festgelegt.
