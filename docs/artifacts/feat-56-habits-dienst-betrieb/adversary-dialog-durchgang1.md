# Adversary Dialog — feat-56-habits-dienst-betrieb
Spec: docs/specs/infra/habits-dienst-betrieb.md
Datum: 2026-11-28 06:50

## Checkliste
- [x] **AC-1:** Given der Einbau in henemm-infra ist auf aktuellem Stand übernommen / When `cd /home/hem/henemm-infra && python3 -m pytest tests` läuft / Then alle Tests grün, darin die 60 Habits-Tests, und `HH_COMMIT` in `scripts/deploy-habits.sh` ist `d7705c320e6a47d9971991635c67960f1b98e745`.
- [ ] (Live-Nachweis offen, Phase 7) **AC-2:** Given der Dienst ist ausgerollt / When `curl -s -w '%{http_code}' https://habits.henemm.com/health` / Then Antwort 200 und der Inhalt enthält `"migrated":true`.
- [ ] (Live-Nachweis offen, Phase 7) **AC-3:** Given keine Anmeldung / When `curl -si -X POST https://habits.henemm.com/mcp` / Then 401 mit Header `WWW-Authenticate`.
- [ ] (Live-Nachweis offen, Phase 7) **AC-4:** Given die nginx-Konfiguration ist live / When `sudo nginx -T | grep habits_` und eine Anfragenserie auf `/health` über die Grenze / Then eigene Zonen `habits_*` je Bereich (Gesundheit, /mcp, OAuth samt Discovery, /auth, /app) sind aktiv und die Serie wird ab der Grenze abgewiesen (429 oder 503); das Netz 160.79.104.0/21 ist nicht gesperrt.
- [ ] (Repo-Teil belegt, Live-Teil offen, Phase 7) **AC-5:** Given der Dienst läuft / When ein `backup.sh`-Lauf erfolgt / Then er endet erfolgreich, `restic snapshots --tag habits` zeigt einen neuen Snapshot und `habits/secrets` (inkl. Wert für `APPLE_TOKEN_KEY`) ist in der Sicherung enthalten (Prüfung per `restic ls`, nur Dateinamen).
- [ ] (Live-Nachweis offen, Phase 7) **AC-6:** Given ein aktueller Habits-Snapshot / When `sudo bash scripts/restore-test-habits.sh` / Then Exit-Code 0.
- [ ] (Live-Nachweis offen, Phase 7) **AC-7:** Given der Dienst läuft / When `bash scripts/monitor.sh` / Then für habits kein Fehler; das BetterStack-Kontingent bleibt bei 7/10.
- [ ] (Live-Nachweis offen, Phase 7) **AC-8:** Given `ALLOWED_APPLE_SUBS` ist mit Hennings Konto gesetzt und neu ausgerollt / When sich ein anderes Konto anmelden will / Then wird es abgelehnt (in Code-Test von B2b belegt und Einstellung live per Namensprüfung bestätigt).
- [ ] (Live-Nachweis offen, Phase 7) **AC-9:** Given der Konnektor ist in Hennings Claude-Konto verbunden / When Claude `overview` und `catalog` liest und ein Beispiel über `exercise_define` liefert / Then `delivery_status` meldet „waiting“; die Ausgabe ist im Issue #56 dokumentiert.
- [ ] (Live-Nachweis offen, Phase 7) **AC-10:** Given alle Werte sind per `curl` bestätigt / When Teil B eingebaut ist / Then `security/expected-exposure.json` enthält habits.henemm.com und der Security-Abgleich bleibt grün.
- [x] **AC-11:** Given der Einbau-Stand / When `git grep` nach Geheimniswerten im Einbau sucht / Then keine Geheimniswerte in Repo, Issue oder Nachrichten.

## Dialog

### Runde 1
**Adversary:** Diff gegen origin/main: backup.sh +55, monitor.sh +8, restic-prune-heimserver.sh +8, nur Habits-Einfuegungen, nichts entfernt (keine Altstaende mailadmin/tailscale/gregor/wireguard). Volltestlauf selbst: 1042 passed, 6 skipped (170 s), Output adversary-test-output.txt; `-k habits`: 84 passed (>= 60 der Spec), dort keine Skips.
1. backup.sh: SECRET_FILES erhaelt den ganzen Ordner habits/secrets (Zeile 230), restic bekommt ihn in Zeile 280, also auch db-password und die Server-Umgebungsdatei mit APPLE_TOKEN_KEY. Ordner fehlt: `[ -d ]` ueberspringt, Backup bricht nicht. Dump-, restic- oder Restore-Fehler: exit 1 vor dem Ping.
2. monitor.sh: Block nur bei `docker inspect habits-db` (Zeile 93); ohne Container kein Eintrag; kein BetterStack-Aufruf.
3. deploy-habits.sh: zehn Pflichtnamen per grep -q (kein Wert in der Ausgabe), Backup-Fenster 02:45-03:30; HH_COMMIT exakt d7705c320e6a47d9971991635c67960f1b98e745.
4. nginx: Zonen habits_health/oauth/mcp/auth/app, Discovery ohne Vorgaengersperre, kein deny/allow; 160.79.104.0/21 nur im Kommentar.
5. AC-11: Suche nach PEM-Bloecken, AKIA/ghp_/JWT-Mustern und NAME=langerWert: keine Treffer; nur oeffentliche Heartbeat-URLs (schon in main, nicht im Diff), Pfade, oeffentlicher Commit-SHA. habits/secrets ist gitignored und nicht versioniert.
6. test_restic_prune_heimserver.py: calls() blendet nur Aufrufe mit `--tag habits` aus, der keep-within-Assert nimmt sie aus. Loose-Ends-Pruefung bleibt voll; Habits-Regel hat eigene Tests (test_restic_prune_habits.py). Pruefkraft nicht wesentlich geschwaecht.
**Implementierer:** (nicht beteiligt, Kontext-Isolation)

### Runde 2
**Adversary:**
- F001: backup.sh Zeile 264: schlaegt `sudo -n docker ps` fehl, ist HH_ACTIVE=0, die Habits-Sicherung entfaellt still, Heartbeat gruen. Loose Ends bricht dort hart ab. Kein Test dafuer; monitor.sh meldet keine veraltete Habits-Sicherung. MEDIUM.
- F002: docs/habits-einbau.md Zeile 44 nennt HH_COMMIT a29c74d8..., Skript d7705c3; "drei Einfuegungen" statt vier. LOW.
- F003: deploy-habits.sh prueft nur Vorhandensein/Nichtleere der Namen, nicht die Form (Spec-Test 3 sagt "falsch geformt"). LOW.
- Prune: `forget --tag habits --keep-within 28d` betrifft nur Tag habits; Allgemeinregel (daily/weekly) beruehrt Habits nicht.
**Implementierer:** (nicht beteiligt)

## Herkunft der Vorbedingungen

Kein Sprachprofil konfiguriert (`precondition_origins.default_lang`); keine Tabelle angehaengt, keine verdaechtigen Zeilen.

## Findings
Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: /home/hem/henemm-infra-wt-habits56/scripts/backup.sh:264
  Description: HH_ACTIVE wird nur 1, wenn `sudo -n docker ps` habits-db als laufend meldet; Abfragefehler wird per 2>/dev/null verschluckt, Sicherung entfaellt, Heartbeat wird gepingt.
  Spec requirement: AC-5 — Sicherung erfolgreich, Snapshot mit Tag habits
  Conflict: Stiller Ausfall der Habits-Sicherung bei gruenem Heartbeat moeglich.
  Remediation: Bei Fehler von docker ps hart abbrechen oder Teil-Check auf Alter des letzten Habits-Snapshots in monitor.sh.

Finding:
  ID: F002
  Severity: LOW
  Category: spec_violation
  Code reference: /home/hem/henemm-infra-wt-habits56/docs/habits-einbau.md:44
  Description: Einbauanleitung nennt HH_COMMIT a29c74d8..., Skript und Spec d7705c32...; "drei Einfuegungen" statt vier.
  Spec requirement: AC-1 — HH_COMMIT d7705c32...
  Conflict: Doku widerspricht dem Stand (Skript korrekt).
  Remediation: Doku korrigieren.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: /home/hem/henemm-infra-wt-habits56/scripts/deploy-habits.sh:41
  Description: Pflichtnamen nur auf Vorhandensein/Nichtleere geprueft, nicht auf Form.
  Spec requirement: Test 3 — fehlen oder falsch geformt -> Abbruch
  Conflict: Falsch geformter Wert faellt erst beim Start auf (Stapel bleibt dann wie er ist).
  Remediation: Optional Formpruefung.

## Confirmations
Confirmation:
  AC: AC-1
  Code reference: /home/hem/henemm-infra-wt-habits56/scripts/deploy-habits.sh:17
  Evidence: HH_COMMIT exakt d7705c320e6a47d9971991635c67960f1b98e745; Volltest 1042 passed, 6 skipped (nicht Habits), -k habits 84 passed.
  Status: CONFIRMED
Confirmation:
  AC: AC-11
  Code reference: /home/hem/henemm-infra-wt-habits56/habits/.gitignore:1
  Evidence: secrets/ ignoriert, nur .gitignore und Compose unter habits/ versioniert, Mustersuchen ohne Treffer.
  Status: CONFIRMED

Weitere gepruefte Dateien (Repo ermoeglicht Live-Nachweis, Live offen Phase 7):
Code reference: /home/hem/henemm-infra-wt-habits56/scripts/backup.sh:230
Code reference: /home/hem/henemm-infra-wt-habits56/scripts/monitor.sh:93
Code reference: /home/hem/henemm-infra-wt-habits56/scripts/restic-prune-heimserver.sh:124
Code reference: /home/hem/henemm-infra-wt-habits56/nginx/habits.henemm.com.conf:18
Code reference: /home/hem/henemm-infra-wt-habits56/habits/docker-compose.yml:52
Code reference: /home/hem/henemm-infra-wt-habits56/scripts/backup-habits-snapshot.sh:37
Code reference: /home/hem/henemm-infra-wt-habits56/scripts/restore-test-habits.sh:1
Code reference: /home/hem/henemm-infra-wt-habits56/docs/habits-runbook.md:91
Code reference: /home/hem/henemm-infra-wt-habits56/docs/backup-offsite.md:1
Code reference: /home/hem/henemm-infra-wt-habits56/docs/backup-restore.md:1
Code reference: /home/hem/henemm-infra-wt-habits56/tests/test_restic_prune_heimserver.py:74
Code reference: /home/hem/henemm-infra-wt-habits56/tests/test_habits_betrieb_56.py:29
Code reference: /home/hem/henemm-infra-wt-habits56/tests/test_backup_habits.py:1
Code reference: /home/hem/henemm-infra-wt-habits56/tests/test_habits_konfiguration.py:1
Code reference: /home/hem/henemm-infra-wt-habits56/tests/test_monitor_habits.py:1
Code reference: /home/hem/henemm-infra-wt-habits56/tests/test_restic_prune_habits.py:1
Code reference: /home/hem/henemm-infra-wt-habits56/tests/test_restore_test_habits.py:1

## Verdict
VERIFIED
Repo-Anteil korrekt und vollstaendig, keine Regression (1042 passed, 6 skipped, 0 failed). Live-ACs (AC-2,3,4,6,7,8,9,10 und Live-Teil AC-5): Live-Nachweis offen (Phase 7). F001 (MEDIUM), F002/F003 (LOW) zur Behebung empfohlen, nicht blockierend.

## Geprüfte Dateien

- sha256:29be4c29c5b0ebc339720a6175b363c66c5c588f8b593491ae4f848cb2ad8564  /home/hem/henemm-infra-wt-habits56/docs/backup-offsite.md
- sha256:f41956e798f21635879f316c15f3c0a8456c531e3eaa0bb56285fa441a23d851  /home/hem/henemm-infra-wt-habits56/docs/backup-restore.md
- sha256:7b432f4df9901991d897c1119fbb92af17f719e25a35484be245ac6139d312cb  /home/hem/henemm-infra-wt-habits56/docs/habits-einbau.md
- sha256:9f21146a18e9021f33fa08254c6c8fbc7128ea020367cd5988c3d10c9076fd12  /home/hem/henemm-infra-wt-habits56/docs/habits-runbook.md
- sha256:71c1a23e67706c2468b62fd8935e96b5c0b6b3e5eca3cccbc48e7191c7677ccd  /home/hem/henemm-infra-wt-habits56/habits/.gitignore
- sha256:e74452b7d6cea1aae687f974c98df6967dec22b85a317429fcdd00fb4496fb0e  /home/hem/henemm-infra-wt-habits56/habits/docker-compose.yml
- sha256:0b9462d2b17ee2ba5afac12f3ba86707c89d911cf71b3ca82d817ffd99378ec1  /home/hem/henemm-infra-wt-habits56/nginx/habits.henemm.com.conf
- sha256:abaae7a59d4514d80305760531d49bce781ea7347ad6d5ba4ea456b7c2db1153  /home/hem/henemm-infra-wt-habits56/scripts/backup-habits-snapshot.sh
- sha256:79d21cbe17bc9ae7db31dbc9e8dc33c8ba9ac2505c150bcffe3d28fc93a20b56  /home/hem/henemm-infra-wt-habits56/scripts/backup.sh
- sha256:36420961d0e5843b076e505fc8ed10932000cdc81c8b121bab16902693db104b  /home/hem/henemm-infra-wt-habits56/scripts/deploy-habits.sh
- sha256:02685ebaecac3fd9c11a0dc94e437ad95ecc7307e393a59975dba670e6c4c61a  /home/hem/henemm-infra-wt-habits56/scripts/monitor.sh
- sha256:92bf111ffeeaecda9fdc8492583867d3cefce81448e1867c02e269a06f1a78ad  /home/hem/henemm-infra-wt-habits56/scripts/restic-prune-heimserver.sh
- sha256:f8aed453849674fb3d0b6ecba2734c7c4212e3b67aeac94a638440c93571fac6  /home/hem/henemm-infra-wt-habits56/scripts/restore-test-habits.sh
- sha256:98e6bdb67b46a1c8b5533885ddb540ea14cb91d470a19b34cfcd65c0aa3737c0  /home/hem/henemm-infra-wt-habits56/tests/test_backup_habits.py
- sha256:b50ad3ace14768731c4c447505efd18fafc1a221c85cc9a2ad08aedc2c4f1a39  /home/hem/henemm-infra-wt-habits56/tests/test_habits_betrieb_56.py
- sha256:85e9bf62439204a3c68a519d0155b9d0e5bc023d0293dbe7f54774adec1f97d3  /home/hem/henemm-infra-wt-habits56/tests/test_habits_konfiguration.py
- sha256:d86a6556d4286166a67370a02a629edf69e048167d33df92e3fad7a175e57956  /home/hem/henemm-infra-wt-habits56/tests/test_monitor_habits.py
- sha256:d64dc6da0cd059b256ae4dae2e8f4bdcca5407f2bd3d9dbdb306759ccac0017d  /home/hem/henemm-infra-wt-habits56/tests/test_restic_prune_habits.py
- sha256:4b37d0e0ec83332ade454a1e4cf60f4591bcfa4a9d5e2c866f3c975da957190d  /home/hem/henemm-infra-wt-habits56/tests/test_restic_prune_heimserver.py
- sha256:e979d47c525a5dfcfd762a25e9ffd367667cd1aab35af3c25cd66e90902ae510  /home/hem/henemm-infra-wt-habits56/tests/test_restore_test_habits.py
