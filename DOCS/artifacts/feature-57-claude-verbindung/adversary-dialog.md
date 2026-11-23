# Adversary-Dialog #57 Schnitt 1

Lauf: Unit-Suite `LeanHealthTimerTests`, TEST SUCCEEDED, 366 Zeilen `Test case ... passed`, 0 failed; davon 22 in `ClaudeVerbindungBausteineTests`.
Hinweis: Unter Xcode 27 gibt es keine Zeile `Executed N tests`; Ersatz: Zahl der `passed`-Zeilen.

## Runde 1: Spec-Punkte

- [x] Regel 1 / AC-1..4 Schalter: ClaudeWiring.swift:14-20, Typpruefung CFGetTypeID == CFBooleanGetTypeID; Tests gruen.
- [x] Regel 2 / AC-5..7 Dienstadresse: ClaudeWiring.swift:23-35; Tests gruen.
- [x] Regel 3 / AC-8, AC-9 Nonce: Nonce.swift:14-22 (32 Bytes, throw bei Status != success, kein Fallback), hash :30-32; Tests gruen.
- [x] Regel 4 / AC-10..14 Sitzung: KeychainSessionStore.swift:66-92. add, bei Duplikat nur update(base, [kSecValueData]), kein delete, kein Retry; load: notFound -> nil, leere/nil/Nicht-UTF8 -> corruptData; clear: notFound ok; -34018 -> keychain(status). Fehler-Enums tragen nur OSStatus, nie das Token.
- [x] Regel 5 / AC-15..17 Geraete-UUID: DeviceIdentity.swift:21-32. Nur notFound legt an; Duplikat -> erneut lesen, kein update; zweiter Lesefehler -> keychain(again); corruptData ohne add/update/delete.
- [x] Kennungen/Attribute: KeychainEntry (KeychainSessionStore.swift:30-52): GenericPassword, Service/Account laut Spec, kSecUseDataProtectionKeychain true, AfterFirstUnlockThisDeviceOnly nur beim Anlegen, kein kSecAttrSynchronizable.
- [x] AC-18: `git status --short` zeigt nur neue untracked Dateien (Claude/ plus Workflow-Hilfsdateien), `git diff --stat` leer, also keine bestehende Datei geaendert. Grep nach allen neuen Typnamen ausserhalb `Meditationstimer iOS/Claude/` und der Testdatei: 0 Treffer. Keine Namenskollisionen (Grep auf Typdeklarationen). Zeilen: 36+33+14+93+40 = 216 (<= 250); laengste Funktion `current()` 12 Zeilen.
- [x] AC-18 Teilpunkt Build iOS/Watch/Widget: Adversary baute nur „Lean Health Timer“ (grün). Nachgereicht durch den Orchestrator am 2026-11-23: Scheme „Meditationstimer Watch App“ (generic/platform=watchOS Simulator) `** BUILD SUCCEEDED **`, Scheme „MeditationstimerWidgetExtension“ (generic/platform=iOS Simulator) `** BUILD SUCCEEDED **`. Der Durchlauf im Simulator mit Screenshot ist laut DoD Teil von /60-validate und nicht Gegenstand dieses Dialogs.

## Runde 2: Grenzfaelle ohne Testabdeckung (Scratch-Programm mit swiftc, ClaudeWiring.swift + Nonce.swift)

- [x] `https://` -> Vorgabe; `https:///path` -> Vorgabe; leer, " https://x.org", "https://x.org\n", "https://a b.com" -> Vorgabe.
- [x] `http://localhost.evil.com`, `http://127.0.0.1.evil` -> Vorgabe (auch mit allowsLocalHTTP true).
- [x] `http://localhost@evil.com` -> Vorgabe (Host ist evil.com).
- [x] `HTTPS://Dienst.example.org` -> uebernommen (Schema case-insensitiv), `http://LOCALHOST:3000` nur mit allowsLocalHTTP.
- [x] Schalter: Int 1, NSNumber(1), "YES", false -> aus; Bool true, NSNumber(bool), kCFBooleanTrue -> an; info nil -> aus; `--enable-testing` (mit Praefix) -> aus, nur exakt `enable-testing`.
- [x] Nonce real: 43 Zeichen, hashed 64 Zeichen.
- [x] Keine `kSecAttrSynchronizable`, kein delete in save/current, update-Abfrage ohne Accessible/ValueData-Reste (`Self.entry.base`).

## Findings

```json
[
  {"id":"F-1","severity":"LOW","category":"edge_case",
   "description":"save(\"\") speichert leeren Token; load() wirft danach corruptData. Spec verlangt das Verhalten fuer load, nicht fuer save; Aufrufer (Schnitt 2) darf keinen leeren Token speichern.",
   "evidence":"KeychainSessionStore.swift:66-71 (kein Leer-Check) vs. :77 (!data.isEmpty)",
   "remediation":"In Schnitt 2 leeren Token vor save abweisen."},
  {"id":"F-2","severity":"LOW","category":"edge_case",
   "description":"serviceURL akzeptiert http://evil.com@localhost (Userinfo, Host ist localhost); verbindet tatsaechlich nur zu localhost, nur im Debug. Beobachtung, kein Fehler.",
   "evidence":"Scratch-Lauf: http://evil.com@localhost -> uebernommen bei allowsLocalHTTP true",
   "remediation":"Keine noetig."}
]
```

VERDICT: VERIFIED

## Code-Referenzen

Code reference: `Meditationstimer iOS/Claude/ClaudeWiring.swift`
Code reference: `Meditationstimer iOS/Claude/Nonce.swift`
Code reference: `Meditationstimer iOS/Claude/SessionStore.swift`
Code reference: `Meditationstimer iOS/Claude/KeychainSessionStore.swift`
Code reference: `Meditationstimer iOS/Claude/DeviceIdentity.swift`
Code reference: `LeanHealthTimerTests/ClaudeVerbindungBausteineTests.swift`

## Geprüfte Dateien

- sha256:3acd6f47e463554f25dc8fc71b16d080a9a60bbe39882d3739975b6a8a1dd961  LeanHealthTimerTests/ClaudeVerbindungBausteineTests.swift
- sha256:467620c08c08fd9cfd492d732b68d59b3a61ceb79956b8c92e1cffcc4b3c8a1c  Meditationstimer iOS/Claude/ClaudeWiring.swift
- sha256:ffb20b55018963b58ca3ebd90e4b6e7389487b542070906990782bacf5f5f984  Meditationstimer iOS/Claude/DeviceIdentity.swift
- sha256:0d0775223c6e18bf145c773fda7e016db0d5f4be4845ea4549dbc89f157f7642  Meditationstimer iOS/Claude/KeychainSessionStore.swift
- sha256:8a60cc68c5804fcbf35ae1bcc377afeac8550246eee73c6af0d6178cdfc089fb  Meditationstimer iOS/Claude/Nonce.swift
- sha256:9ef341ccbf8f6128ebf71eb52035d13e387ea3a42a319823e87a800f57f0f53d  Meditationstimer iOS/Claude/SessionStore.swift

## Prüfbasis

- base: ae334e3afad8708dcd8dfb0aa028873dba28f99d
- blob:407f7bb276b9752fc3e1388edc2e65069c124d25  LeanHealthTimerTests/ClaudeVerbindungBausteineTests.swift
- blob:ff7c4e9dff0d02963f91b691ffdbcc47e31471a3  Meditationstimer iOS/Claude/ClaudeWiring.swift
- blob:33287acaa0aa9e9ea744ef6d8df688224e81ddf1  Meditationstimer iOS/Claude/DeviceIdentity.swift
- blob:90a25ac8664439cb6c3efb37bee1904119ab1b30  Meditationstimer iOS/Claude/KeychainSessionStore.swift
- blob:9d9eb8164eb3ddf8b8aa3d1b0773a8ce73a9c10d  Meditationstimer iOS/Claude/Nonce.swift
- blob:5fa19ab22a4bdb75fd981cae98b6b8d9e13af7cf  Meditationstimer iOS/Claude/SessionStore.swift
