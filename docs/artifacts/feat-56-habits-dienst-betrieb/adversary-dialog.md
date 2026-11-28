# Adversary Dialog — feat-56-habits-dienst-betrieb
Spec: docs/specs/infra/habits-dienst-betrieb.md
Datum: 2026-11-28 07:02

## Checkliste
- [x] **AC-1:** Given der Einbau in henemm-infra ist auf aktuellem Stand übernommen / When `cd /home/hem/henemm-infra && python3 -m pytest tests` läuft / Then alle Tests grün, darin die 60 Habits-Tests, und `HH_COMMIT` in `scripts/deploy-habits.sh` ist `d7705c320e6a47d9971991635c67960f1b98e745`.
- [x] **AC-5a:** Given der Einbau-Stand / When `scripts/backup.sh` gelesen und `tests/test_habits_betrieb_56.py::test_backup_sichert_habits_secrets_vollstaendig` sowie `tests/test_backup_habits.py` laufen / Then `habits/secrets` (auch `db-password`) geht in den restic-Aufruf, ein fehlender Ordner bricht die Sicherung nicht, eine scheiternde Docker-Abfrage nach `habits-db` bricht ohne Heartbeat ab. (Beleg Runde 1/2: backup.sh SECRET_FILES-Aufnahme und restic-Aufruf, F001-Fix mit Abbruch exit 1, Test test_backup_sh_bricht_ab_wenn_docker_abfrage_scheitert; Volllauf 1043 passed)
- [x] **AC-11:** Given der Einbau-Stand / When `git grep` nach Geheimniswerten im Einbau sucht / Then keine Geheimniswerte in Repo, Issue oder Nachrichten.

## Dialog

### Runde 1
**Adversary:** Volllauf selbst: `pytest tests` = 1043 passed, 6 skipped (nur test_smtp_*, MAIL_USER fehlt, ohne Bezug), 0 failed; 6 Habits-Dateien allein 85 passed. HH_COMMIT = d7705c32... voller SHA bestaetigt. F001-Fix: Diff gegen origin/main fuer backup.sh/monitor.sh/restic-prune-heimserver.sh enthaelt 0 Loeschzeilen, nur Habits-Einfuegungen (62/8/8). Der Fix bricht mit exit 1 ohne Ping, wenn eine der beiden docker-ps-Abfragen scheitert.
Neuer Test test_backup_sh_bricht_ab_wenn_docker_abfrage_scheitert: kein reiner Text-Test, sondern fuehrt den echten Ausschnitt aus backup.sh (zwischen HH_SNAPSHOT_DIR und dem restic-Block) mit set -e und Attrappen fuer sudo (scheitert), restic, curl aus; prueft Exit != 0, Meldung, und dass weder restic noch curl (Heartbeat) aufgerufen wurden. Die alte Fassung (Abfrage scheitert -> still HH_ACTIVE=0) wuerde Exit 0 und curl-Aufruf liefern, der Test faengt sie also. Schwaeche: sudo scheitert fuer beide Abfragen gleich; der Fall "erste Abfrage ok, zweite scheitert" ist nicht einzeln belegt (Code deckt ihn per ||). Der WARNUNG-Zweig (Container existiert, laeuft nicht) ist nur textuell, nicht verhaltensgetestet.
F002: habits-einbau.md nennt HH_COMMIT d7705c32... (Zeile 43) = Skript; keine falschen Einfuegungszahlen mehr gefunden (nur "vier Einfuegungen" backup.sh, 2a-2d, stimmt mit dem Diff). Doku-Snippet 2a stimmt wortgleich mit backup.sh ueberein.
AC-11: Suche nach PEM, ghp_/github_pat_, eyJ, AKIA, NAME=24+ Zeichen im gesamten Diff: keine Treffer; nur Pfadangaben und PASSWORD_FILE-Verweise; habits/.gitignore sperrt secrets/; keine secrets-Datei versioniert.
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** Zweiter Blick auf Randfaelle. (a) prune: `forget --tag habits --keep-within 28d` laeuft auch bei --loose-ends-only und dry-run (N-Array), allgemeine Regel bleibt auf daily/weekly beschraenkt, Habits-Snapshot (offsite+habits ohne daily) wird von ihr nie erfasst; Test test_restic_prune_heimserver.py nur um den Habits-Filter erweitert, keine Abschwaechung. (b) monitor.sh: Habits-Check nur bei vorhandenem Container habits-db (docker inspect), sonst kein Alarm. (c) SECRET_FILES: Ordner habits/secrets nur wenn vorhanden, wird an restic uebergeben (backup.sh:287), db-password wird damit erfasst. (d) Spec-Test 3 / deploy-habits.sh: Pflichtnamen nur auf vorhanden/nicht leer (grep '^VAR=.'). Die akzeptierte Begruendung traegt im Kern (Platzhalter sind gueltig geformt, Dienst prueft beim Start, wait_for_health bricht mit exit 1), aber: `docker compose up -d` ersetzt den laufenden Container vor der Gesundheitspruefung; bei falsch geformtem Wert steht der Dienst bis zum Rueckrollen (Runbook) rot. Fuer die Erstinbetriebnahme folgenlos (kein Altbestand), spaeter nur Betriebsrisiko: LOW. Kein Blocker. (e) Live-Anteile (AC-2..AC-10, Live-AC-5) nur auf Ermoeglichung geprueft: nginx hat die 5 Zonen habits_*, kein deny/Sperre fuer 160.79.104.0/21, Compose bindet 127.0.0.1:8781, secrets-Datei db-password via Docker-Secret.
**Implementierer:** (nicht beteiligt, Kontextisolation)


## Findings und Bestaetigungen

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: /home/hem/henemm-infra-wt-habits56/scripts/deploy-habits.sh:40
  Description: Pflichtnamen werden nur auf Praesenz/nicht leer geprueft; compose up -d ersetzt den laufenden Container vor der Gesundheitspruefung.
  Spec requirement: Test 3 — falsch geformte Pflichtnamen -> Abbruch vor dem Start
  Conflict: Abbruch erst nach dem Start (wait_for_health); vom PO bewusst akzeptiert, Begruendung traegt fuer die Erstinbetriebnahme.
  Remediation: Optional spaeter Formpruefung oder Rollback auf vorheriges Image.

Confirmation:
  AC: AC-1
  Code reference: /home/hem/henemm-infra-wt-habits56/scripts/deploy-habits.sh:17
  Evidence: 1043 passed, 6 skipped (unrelated), HH_COMMIT korrekt.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: /home/hem/henemm-infra-wt-habits56/habits/.gitignore:1
  Evidence: Geheimnissuche ohne Treffer, secrets/ ignoriert.
  Status: CONFIRMED

Live-Nachweis offen (Phase 7): AC-2, AC-3, AC-4, AC-5 (Live-Teil), AC-6, AC-7, AC-8, AC-9, AC-10 — Repo-Stand ermoeglicht sie (nginx-Zonen, Backup-/Monitor-/Restore-Einfuegungen, Compose vorhanden), nicht als bestanden gewertet.

Geprueft (je Datei):
  Code reference: /home/hem/henemm-infra-wt-habits56/scripts/backup.sh:266 — F001-Fix: docker-Abfrage scheitert -> exit 1 ohne Ping
  Code reference: /home/hem/henemm-infra-wt-habits56/scripts/monitor.sh:90 — nur Habits-Einfuegung, Check an habits-db gebunden
  Code reference: /home/hem/henemm-infra-wt-habits56/scripts/restic-prune-heimserver.sh:119 — Tag habits 28d, allgemeine Regel unveraendert
  Code reference: /home/hem/henemm-infra-wt-habits56/scripts/deploy-habits.sh:17 — HH_COMMIT voller SHA; Pflichtnamen nur Praesenz (Zeile 40)
  Code reference: /home/hem/henemm-infra-wt-habits56/scripts/backup-habits-snapshot.sh:20 — Dump mit Plausibilitaetspruefung
  Code reference: /home/hem/henemm-infra-wt-habits56/scripts/restore-test-habits.sh:1 — Rueckspielprobe, Live-Nachweis offen (Phase 7)
  Code reference: /home/hem/henemm-infra-wt-habits56/habits/docker-compose.yml:54 — 127.0.0.1:8781, Secrets per Datei
  Code reference: /home/hem/henemm-infra-wt-habits56/habits/.gitignore:1 — secrets/ ignoriert
  Code reference: /home/hem/henemm-infra-wt-habits56/nginx/habits.henemm.com.conf:18 — fuenf Zonen habits_*, keine Sperre
  Code reference: /home/hem/henemm-infra-wt-habits56/tests/test_backup_habits.py:231 — neuer Verhaltenstest F001
  Code reference: /home/hem/henemm-infra-wt-habits56/tests/test_habits_betrieb_56.py:1 — Habits-Tests
  Code reference: /home/hem/henemm-infra-wt-habits56/tests/test_habits_konfiguration.py:1 — Habits-Tests
  Code reference: /home/hem/henemm-infra-wt-habits56/tests/test_monitor_habits.py:1 — Habits-Tests
  Code reference: /home/hem/henemm-infra-wt-habits56/tests/test_restic_prune_habits.py:1 — Habits-Tests
  Code reference: /home/hem/henemm-infra-wt-habits56/tests/test_restic_prune_heimserver.py:74 — Filter fuer --tag habits, keine Abschwaechung
  Code reference: /home/hem/henemm-infra-wt-habits56/tests/test_restore_test_habits.py:1 — Habits-Tests
  Code reference: /home/hem/henemm-infra-wt-habits56/docs/habits-runbook.md:111 — Rueckroll-/Betriebsschritte
  Code reference: /home/hem/henemm-infra-wt-habits56/docs/habits-einbau.md:43 — HH_COMMIT aktuell, Snippet 2a gleich backup.sh
  Code reference: /home/hem/henemm-infra-wt-habits56/docs/backup-offsite.md:144 — Habits-Abschnitt
  Code reference: /home/hem/henemm-infra-wt-habits56/docs/backup-restore.md:15 — Tabellenzeile Habits

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
VERDICT: VERIFIED
(Abschnitt 1 laut Spec nach PO-Entscheidung 2026-11-28: AC-1, AC-5a, AC-11 bewiesen; keine Regression; F001/F002 behoben; F003 LOW nicht blockierend, Folge-Issue. Live-Nachweise L-AC-2..L-AC-10 gehören zu Abschnitt 2, eigener Workflow.)

## Geprüfte Dateien

- sha256:29be4c29c5b0ebc339720a6175b363c66c5c588f8b593491ae4f848cb2ad8564  /home/hem/henemm-infra-wt-habits56/docs/backup-offsite.md
- sha256:f41956e798f21635879f316c15f3c0a8456c531e3eaa0bb56285fa441a23d851  /home/hem/henemm-infra-wt-habits56/docs/backup-restore.md
- sha256:5893340fcae71985114178651d7f5ca5162e65cf8d3cf963a72cf455a8c9c2f1  /home/hem/henemm-infra-wt-habits56/docs/habits-einbau.md
- sha256:9f21146a18e9021f33fa08254c6c8fbc7128ea020367cd5988c3d10c9076fd12  /home/hem/henemm-infra-wt-habits56/docs/habits-runbook.md
- sha256:71c1a23e67706c2468b62fd8935e96b5c0b6b3e5eca3cccbc48e7191c7677ccd  /home/hem/henemm-infra-wt-habits56/habits/.gitignore
- sha256:e74452b7d6cea1aae687f974c98df6967dec22b85a317429fcdd00fb4496fb0e  /home/hem/henemm-infra-wt-habits56/habits/docker-compose.yml
- sha256:0b9462d2b17ee2ba5afac12f3ba86707c89d911cf71b3ca82d817ffd99378ec1  /home/hem/henemm-infra-wt-habits56/nginx/habits.henemm.com.conf
- sha256:abaae7a59d4514d80305760531d49bce781ea7347ad6d5ba4ea456b7c2db1153  /home/hem/henemm-infra-wt-habits56/scripts/backup-habits-snapshot.sh
- sha256:3e6cbb802ac883da0f24fed91c6372a7e513632fbb56162cadfb013b329c363c  /home/hem/henemm-infra-wt-habits56/scripts/backup.sh
- sha256:36420961d0e5843b076e505fc8ed10932000cdc81c8b121bab16902693db104b  /home/hem/henemm-infra-wt-habits56/scripts/deploy-habits.sh
- sha256:02685ebaecac3fd9c11a0dc94e437ad95ecc7307e393a59975dba670e6c4c61a  /home/hem/henemm-infra-wt-habits56/scripts/monitor.sh
- sha256:92bf111ffeeaecda9fdc8492583867d3cefce81448e1867c02e269a06f1a78ad  /home/hem/henemm-infra-wt-habits56/scripts/restic-prune-heimserver.sh
- sha256:f8aed453849674fb3d0b6ecba2734c7c4212e3b67aeac94a638440c93571fac6  /home/hem/henemm-infra-wt-habits56/scripts/restore-test-habits.sh
- sha256:342cfda915923906ddab117f85219c9dbac7db5191ee5ced1b6b8a43f1125536  /home/hem/henemm-infra-wt-habits56/tests/test_backup_habits.py
- sha256:b50ad3ace14768731c4c447505efd18fafc1a221c85cc9a2ad08aedc2c4f1a39  /home/hem/henemm-infra-wt-habits56/tests/test_habits_betrieb_56.py
- sha256:85e9bf62439204a3c68a519d0155b9d0e5bc023d0293dbe7f54774adec1f97d3  /home/hem/henemm-infra-wt-habits56/tests/test_habits_konfiguration.py
- sha256:d86a6556d4286166a67370a02a629edf69e048167d33df92e3fad7a175e57956  /home/hem/henemm-infra-wt-habits56/tests/test_monitor_habits.py
- sha256:d64dc6da0cd059b256ae4dae2e8f4bdcca5407f2bd3d9dbdb306759ccac0017d  /home/hem/henemm-infra-wt-habits56/tests/test_restic_prune_habits.py
- sha256:4b37d0e0ec83332ade454a1e4cf60f4591bcfa4a9d5e2c866f3c975da957190d  /home/hem/henemm-infra-wt-habits56/tests/test_restic_prune_heimserver.py
- sha256:e979d47c525a5dfcfd762a25e9ffd367667cd1aab35af3c25cd66e90902ae510  /home/hem/henemm-infra-wt-habits56/tests/test_restore_test_habits.py

## Geprüfte Dateien

- sha256:29be4c29c5b0ebc339720a6175b363c66c5c588f8b593491ae4f848cb2ad8564  /home/hem/henemm-infra-wt-habits56/docs/backup-offsite.md
- sha256:f41956e798f21635879f316c15f3c0a8456c531e3eaa0bb56285fa441a23d851  /home/hem/henemm-infra-wt-habits56/docs/backup-restore.md
- sha256:5893340fcae71985114178651d7f5ca5162e65cf8d3cf963a72cf455a8c9c2f1  /home/hem/henemm-infra-wt-habits56/docs/habits-einbau.md
- sha256:9f21146a18e9021f33fa08254c6c8fbc7128ea020367cd5988c3d10c9076fd12  /home/hem/henemm-infra-wt-habits56/docs/habits-runbook.md
- sha256:71c1a23e67706c2468b62fd8935e96b5c0b6b3e5eca3cccbc48e7191c7677ccd  /home/hem/henemm-infra-wt-habits56/habits/.gitignore
- sha256:e74452b7d6cea1aae687f974c98df6967dec22b85a317429fcdd00fb4496fb0e  /home/hem/henemm-infra-wt-habits56/habits/docker-compose.yml
- sha256:0b9462d2b17ee2ba5afac12f3ba86707c89d911cf71b3ca82d817ffd99378ec1  /home/hem/henemm-infra-wt-habits56/nginx/habits.henemm.com.conf
- sha256:abaae7a59d4514d80305760531d49bce781ea7347ad6d5ba4ea456b7c2db1153  /home/hem/henemm-infra-wt-habits56/scripts/backup-habits-snapshot.sh
- sha256:3e6cbb802ac883da0f24fed91c6372a7e513632fbb56162cadfb013b329c363c  /home/hem/henemm-infra-wt-habits56/scripts/backup.sh
- sha256:36420961d0e5843b076e505fc8ed10932000cdc81c8b121bab16902693db104b  /home/hem/henemm-infra-wt-habits56/scripts/deploy-habits.sh
- sha256:02685ebaecac3fd9c11a0dc94e437ad95ecc7307e393a59975dba670e6c4c61a  /home/hem/henemm-infra-wt-habits56/scripts/monitor.sh
- sha256:92bf111ffeeaecda9fdc8492583867d3cefce81448e1867c02e269a06f1a78ad  /home/hem/henemm-infra-wt-habits56/scripts/restic-prune-heimserver.sh
- sha256:f8aed453849674fb3d0b6ecba2734c7c4212e3b67aeac94a638440c93571fac6  /home/hem/henemm-infra-wt-habits56/scripts/restore-test-habits.sh
- sha256:342cfda915923906ddab117f85219c9dbac7db5191ee5ced1b6b8a43f1125536  /home/hem/henemm-infra-wt-habits56/tests/test_backup_habits.py
- sha256:b50ad3ace14768731c4c447505efd18fafc1a221c85cc9a2ad08aedc2c4f1a39  /home/hem/henemm-infra-wt-habits56/tests/test_habits_betrieb_56.py
- sha256:85e9bf62439204a3c68a519d0155b9d0e5bc023d0293dbe7f54774adec1f97d3  /home/hem/henemm-infra-wt-habits56/tests/test_habits_konfiguration.py
- sha256:d86a6556d4286166a67370a02a629edf69e048167d33df92e3fad7a175e57956  /home/hem/henemm-infra-wt-habits56/tests/test_monitor_habits.py
- sha256:d64dc6da0cd059b256ae4dae2e8f4bdcca5407f2bd3d9dbdb306759ccac0017d  /home/hem/henemm-infra-wt-habits56/tests/test_restic_prune_habits.py
- sha256:4b37d0e0ec83332ade454a1e4cf60f4591bcfa4a9d5e2c866f3c975da957190d  /home/hem/henemm-infra-wt-habits56/tests/test_restic_prune_heimserver.py
- sha256:e979d47c525a5dfcfd762a25e9ffd367667cd1aab35af3c25cd66e90902ae510  /home/hem/henemm-infra-wt-habits56/tests/test_restore_test_habits.py

## Geprüfte Dateien

- sha256:29be4c29c5b0ebc339720a6175b363c66c5c588f8b593491ae4f848cb2ad8564  /home/hem/henemm-infra-wt-habits56/docs/backup-offsite.md
- sha256:f41956e798f21635879f316c15f3c0a8456c531e3eaa0bb56285fa441a23d851  /home/hem/henemm-infra-wt-habits56/docs/backup-restore.md
- sha256:5893340fcae71985114178651d7f5ca5162e65cf8d3cf963a72cf455a8c9c2f1  /home/hem/henemm-infra-wt-habits56/docs/habits-einbau.md
- sha256:9f21146a18e9021f33fa08254c6c8fbc7128ea020367cd5988c3d10c9076fd12  /home/hem/henemm-infra-wt-habits56/docs/habits-runbook.md
- sha256:71c1a23e67706c2468b62fd8935e96b5c0b6b3e5eca3cccbc48e7191c7677ccd  /home/hem/henemm-infra-wt-habits56/habits/.gitignore
- sha256:e74452b7d6cea1aae687f974c98df6967dec22b85a317429fcdd00fb4496fb0e  /home/hem/henemm-infra-wt-habits56/habits/docker-compose.yml
- sha256:0b9462d2b17ee2ba5afac12f3ba86707c89d911cf71b3ca82d817ffd99378ec1  /home/hem/henemm-infra-wt-habits56/nginx/habits.henemm.com.conf
- sha256:abaae7a59d4514d80305760531d49bce781ea7347ad6d5ba4ea456b7c2db1153  /home/hem/henemm-infra-wt-habits56/scripts/backup-habits-snapshot.sh
- sha256:3e6cbb802ac883da0f24fed91c6372a7e513632fbb56162cadfb013b329c363c  /home/hem/henemm-infra-wt-habits56/scripts/backup.sh
- sha256:36420961d0e5843b076e505fc8ed10932000cdc81c8b121bab16902693db104b  /home/hem/henemm-infra-wt-habits56/scripts/deploy-habits.sh
- sha256:02685ebaecac3fd9c11a0dc94e437ad95ecc7307e393a59975dba670e6c4c61a  /home/hem/henemm-infra-wt-habits56/scripts/monitor.sh
- sha256:92bf111ffeeaecda9fdc8492583867d3cefce81448e1867c02e269a06f1a78ad  /home/hem/henemm-infra-wt-habits56/scripts/restic-prune-heimserver.sh
- sha256:f8aed453849674fb3d0b6ecba2734c7c4212e3b67aeac94a638440c93571fac6  /home/hem/henemm-infra-wt-habits56/scripts/restore-test-habits.sh
- sha256:342cfda915923906ddab117f85219c9dbac7db5191ee5ced1b6b8a43f1125536  /home/hem/henemm-infra-wt-habits56/tests/test_backup_habits.py
- sha256:b50ad3ace14768731c4c447505efd18fafc1a221c85cc9a2ad08aedc2c4f1a39  /home/hem/henemm-infra-wt-habits56/tests/test_habits_betrieb_56.py
- sha256:85e9bf62439204a3c68a519d0155b9d0e5bc023d0293dbe7f54774adec1f97d3  /home/hem/henemm-infra-wt-habits56/tests/test_habits_konfiguration.py
- sha256:d86a6556d4286166a67370a02a629edf69e048167d33df92e3fad7a175e57956  /home/hem/henemm-infra-wt-habits56/tests/test_monitor_habits.py
- sha256:d64dc6da0cd059b256ae4dae2e8f4bdcca5407f2bd3d9dbdb306759ccac0017d  /home/hem/henemm-infra-wt-habits56/tests/test_restic_prune_habits.py
- sha256:4b37d0e0ec83332ade454a1e4cf60f4591bcfa4a9d5e2c866f3c975da957190d  /home/hem/henemm-infra-wt-habits56/tests/test_restic_prune_heimserver.py
- sha256:e979d47c525a5dfcfd762a25e9ffd367667cd1aab35af3c25cd66e90902ae510  /home/hem/henemm-infra-wt-habits56/tests/test_restore_test_habits.py
