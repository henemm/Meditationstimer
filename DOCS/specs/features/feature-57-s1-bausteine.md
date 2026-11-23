---
entity_id: feature-57-s1-bausteine
type: feature
created: 2026-11-23
updated: 2026-11-23
status: draft
workflow: feature-57-claude-verbindung
issue: 57
epic: 44
parent: claude-verbindung-app
---

# Schnitt 1: Bausteine der Claude-Verbindung – Schalter, Nonce, Schlüsselbund, Geräte-UUID (#57)

## Approval

- [ ] Approved

Freigabe dieser Rundenspec durch den PO.

## Purpose

Schnitt 1 von 5 der Elternspec `openspec/specs/features/claude-verbindung-app.md` (Verhalten 1, Verhalten 2 teilweise): Die kleinen, rein technischen Bausteine, auf denen die Anmeldung und der Abgleich mit dem Claude-Dienst später aufbauen, werden aus Loose Ends übernommen und für diese App angepasst. Das sind der Schalter samt Dienstadresse, die Nonce für Sign in with Apple, der Ablageort der Sitzung im Schlüsselbund und die Geräte-UUID.

Sichtbar für Henning: nichts. Keine Datei der App ruft die neuen Typen auf, es gibt keinen Netzwerkzugriff, keine Anzeige und keine Verhaltensänderung. Der Wert der Runde liegt darin, dass die sicherheitsrelevanten Regeln (Sitzung nie im Klartext, kein stilles „abgemeldet“ bei Schlüsselbundfehlern, Release ohne Verbindung) schon vor der Verdrahtung durch Tests festgelegt sind.

## Source

- Kontext und Analyse: `DOCS/context/feature-57-claude-verbindung.md` (Abschnitt „Analysis (2026-11-23, Schnitt 1)“, verbindlich)
- Elternspec: `openspec/specs/features/claude-verbindung-app.md`, Verhalten 1 und 2, Schnitt 1
- Dienst und Anmeldung: `openspec/specs/integrations/claude-dienst.md` §5, `claude-anmeldung.md`
- Vorbild (nur gelesen): `/Users/hem/Developer/loose-ends/LooseEnds/Claude/` – `AccountWiring.swift`, `Nonce.swift`, `SessionStore.swift`, `KeychainSessionStore.swift`, `DeviceIdentity.swift`
- Formatvorbild: `docs/specs/features/feature-51-s3-kennzeichen.md`

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine neue; die Runde übernimmt die Leitlinie der Elternspec („Wie Loose Ends, so einfach wie möglich“, PO 13.11.2026). Festgehalten werden nur die Abweichungen vom Vorbild.

Abweichungen von Loose Ends (alle zur Zeilenersparnis oder weil HHHaven anders aufgebaut ist):

1. **Schalter ohne Info-Plist-Eintrag.** Er ist an im Debug-Bau und beim Startargument `enable-testing` (HHHaven nutzt dieses Argument, nicht `--ui-testing`), sonst nur bei einem echten Bool `true` unter `HHClaudeEnabled`. Ein Release-Bau ohne Eintrag ist aus. Verworfen: Info-Wert per Build-Variable je Konfiguration; die Ersetzung liefert einen String statt eines Bool und hielte die Wahrheit doppelt (Code und Projektdatei).
2. **Der Debug-Dienst-Weg von Loose Ends** (`-LEDebugService`), `forApp` und `UITestTransport` entfallen hier; sie brauchen `ServiceClient` und `AccountState` und gehören zu Schnitt 2.
3. **`InMemorySessionStore` wandert nach Schnitt 2.** Erster Nutzer ist die Verdrahtung unter Tests; in dieser Runde würde er toter Code sein. Dadurch entfällt auch der Import von `Synchronization` in dieser Runde.
4. **Gemeinsame Abfrage-Hilfe `KeychainEntry`** statt zweier Kopien der Abfragen: Sitzung und Geräte-UUID bilden ihre Abfragen (Basis, Lesen, Anlegen) über denselben Typ mit je eigener Kennung.
5. **Sign in with Apple als Entitlement kommt nicht in diesem Schnitt.** Ohne Eintrag im Developer-Portal (Runbook #56, offen) bräche die Signatur für Gerätebauten. Es kommt mit Schnitt 2 (erster `ASAuthorization`-Aufruf), nach Prüfung des Portalstands.

Schlüsselbund-Kennungen (verbindlich):

| Eintrag | Service | Account |
|---|---|---|
| Sitzung | `henemm.Meditationstimer-iOS.claude.session` | `session` |
| Geräte-UUID | `henemm.Meditationstimer-iOS.claude.device` | `device` |

Beide: generisches Passwort (`kSecClassGenericPassword`), `kSecUseDataProtectionKeychain: true`, Zugriffsklasse `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, nie synchronisiert (kein `kSecAttrSynchronizable`).

## Scope

App-Code (5 neue Dateien, 0 geänderte; geschätzt +234 Zeilen, Grenze 250 gilt nur für App-Code, Tests zählen nicht):

| Datei | Änderung | Inhalt | ca. Zeilen |
|---|---|---|---|
| `Meditationstimer iOS/Claude/ClaudeWiring.swift` | neu | `ClaudeWiring.isEnabled(info:arguments:debugBuild:)`, `ClaudeWiring.serviceURL(info:allowsLocalHTTP:)`, Vorgabe `https://habits.henemm.com` | 40 |
| `Meditationstimer iOS/Claude/Nonce.swift` | neu | 1:1 aus Loose Ends: `Nonce`, `NonceError`, `raw`, `hashed`, `hash(_:)` | 34 |
| `Meditationstimer iOS/Claude/SessionStore.swift` | neu | Protokoll `SessionStoring`, `SessionStoreError` | 20 |
| `Meditationstimer iOS/Claude/KeychainSessionStore.swift` | neu | `KeychainOperations`, `SystemKeychain`, `KeychainEntry`, `KeychainSessionStore` | 95 |
| `Meditationstimer iOS/Claude/DeviceIdentity.swift` | neu | `DeviceIdentity`, `DeviceIdentityError`, nutzt `KeychainEntry` mit eigener Kennung | 45 |

Test (zählt nicht zum Budget): `LeanHealthTimerTests/ClaudeVerbindungBausteineTests.swift` (neu, mit Schlüsselbund-Attrappe über `KeychainOperations`; `@testable import Lean_Health_Timer`).

Der neue Ordner `Claude/` liegt in der synchronisierten Gruppe des iOS-Ziels und ist damit automatisch Mitglied; kein Eingriff in `project.pbxproj` nötig. Watch und Widget bekommen nichts.

Unverändert: alle bestehenden Dateien der App, `Meditationstimer-iOS-Info.plist` (kein `HHClaudeEnabled`, kein `HHServiceURL`), `Meditationstimer iOS.entitlements`, `project.pbxproj`.

## Nicht in Scope

- `InMemorySessionStore`, `ServiceClient`, `AccountState`, Debug-Dienst-Weg, Entitlement Sign in with Apple (Schnitt 2).
- Abschrift Fassung 1, Goldendateien, CI-Schritt (Schnitt 3).
- Abgleich und Auslöser, Einhängen in den App-Start (Schnitt 4). Dort offen: Issue nennt zusätzlich „kurz nach eigenen Änderungen“ und „gelegentlich im Hintergrund“, die Elternspec nur Start und Vordergrund.
- Einstellungsseite, Texte DE/EN, UI-Test (Schnitt 5).
- Jede Verdrahtung: weder `Meditationstimer_iOSApp.swift` noch `SettingsSheet.swift` werden angefasst.
- Netzwerkzugriff, Sign-in-Dialog, Push (nicht übernommen, kein Push in HHHaven).

## Dependencies

| Abhängigkeit | Art | Hinweis |
|---|---|---|
| Foundation, Security, CryptoKit | Frameworks | Alle im iOS-Ziel verfügbar; `Synchronization` wird in dieser Runde nicht gebraucht |
| #51-Code (`ClaudeStore`, `ClaudeApply`) | keine | Nichts in dieser Runde berührt oder nutzt ihn |
| Schnitt 2 bis 5 | Downstream | Nutzen `ClaudeWiring`, `Nonce`, `SessionStoring`, `KeychainSessionStore`, `DeviceIdentity` |
| Dienst (#54/#55, Betrieb #56 offen) | keine | Kein Aufruf in dieser Runde |

## Expected Behavior

- Input: Die Typen werden nur von den Unit-Tests aufgerufen, mit selbst gebauten Eingaben (Info-Wörterbuch, Argumentliste, Attrappe für den Schlüsselbund).
- Output: Reine Werte beziehungsweise Fehler nach den Regeln unten.
- Side effects: Keine in der App. Die echte `SystemKeychain` wird in den Tests nie benutzt (Attrappe); auf Hennings Geräten läuft nichts.

Regeln:

1. **Schalter.** `isEnabled` ist wahr, wenn `debugBuild` wahr ist, oder `arguments` den Eintrag `enable-testing` enthält, oder der Wert unter `HHClaudeEnabled` ein echtes Bool `true` ist (Typprüfung mit `CFBooleanGetTypeID`; String „YES“, Zahl 1 und alles andere zählt als aus). Sonst falsch. Vorgabe ohne Eintrag: aus.
2. **Dienstadresse.** `serviceURL` liefert die URL aus `HHServiceURL`, wenn sie https mit nicht leerem Host hat, oder http mit Host `localhost` oder `127.0.0.1` und `allowsLocalHTTP == true`. In allen anderen Fällen (fehlt, kein String, nicht parsbar, http fremd, http lokal ohne Debug, anderes Schema, leerer Host) die Vorgabe `https://habits.henemm.com`.
3. **Nonce.** 32 Zufallsbytes, base64url ohne Auffüllung (43 Zeichen, nur `A-Z a-z 0-9 - _`); `hashed` ist SHA-256 des UTF-8-Rohwerts als kleingeschriebenes Hex (64 Zeichen). Eine versagende Zufallsquelle wirft `NonceError.randomUnavailable`, nie ein schwächerer Wert.
4. **Sitzungsspeicher.** `save` legt an; bei Duplikat wird nur der Wert aktualisiert (nie vorher gelöscht), ein Update ohne Treffer ist Fehler ohne zweiten Versuch. `load` liefert `nil` bei „nicht gefunden“, den Token bei Erfolg. `clear` ist bei „nicht gefunden“ kein Fehler. Jeder andere Status, auch -34018 (fehlendes Entitlement), ist `SessionStoreError.keychain(status)`, nie still „abgemeldet“. Leere oder keine UTF-8-Daten ergeben `SessionStoreError.corruptData`. Kein Fehler und keine Fehlerbeschreibung enthält je den Token.
5. **Geräte-UUID.** `current()` liest zuerst. Erfolg: dieselbe UUID. „Nicht gefunden“: neue UUID anlegen und zurückgeben. Duplikat beim Anlegen (ein zweiter Aufrufer war schneller): erneut lesen, nie aktualisieren. Jeder andere Status, auch beim zweiten Lesen, ist `DeviceIdentityError.keychain(status)`. Daten, die keine UTF-8-UUID sind, ergeben `DeviceIdentityError.corruptData` und werden nie ersetzt.

## Acceptance Criteria

Alle als Given/When/Then; „Unit“ = `LeanHealthTimerTests/ClaudeVerbindungBausteineTests.swift`. Die Schlüsselbund-Tests laufen über eine Attrappe, die `KeychainOperations` erfüllt, Aufrufe aufzeichnet und feste Status liefern kann.

- **AC-1 (Unit): Schalter ohne Eintrag.** Given leeres Info-Wörterbuch, keine Argumente, `debugBuild: false`, When `isEnabled`, Then `false`. Test: `testSchalterReleaseOhneEintragIstAus`.
- **AC-2 (Unit): Debug-Bau schaltet ein.** Given `debugBuild: true`, leeres Info-Wörterbuch, keine Argumente, When `isEnabled`, Then `true`. Test: `testSchalterDebugBauIstAn`.
- **AC-3 (Unit): Testargument schaltet ein.** Given Argumente mit `enable-testing`, `debugBuild: false`, leeres Info-Wörterbuch, When `isEnabled`, Then `true`; mit anderen Argumenten (z. B. `uitest-disk-store`) bleibt es `false`. Test: `testSchalterStartargumentEnableTestingIstAn`.
- **AC-4 (Unit): Nur ein echtes Bool zählt.** Given `debugBuild: false`, keine Argumente und `HHClaudeEnabled` als Bool `true`, Then `true`; als Bool `false`, String „YES“, String „true“, Zahl 1 oder Zahl 0 jeweils `false`. Test: `testSchalterInfoWertNurEchtesBoolTrueSchaltetEin`.
- **AC-5 (Unit): Dienstadresse Vorgabe.** Given Info ohne `HHServiceURL`, mit leerem String, mit Nicht-String (Zahl), mit nicht parsbarem Text, mit `ftp://x.example`, mit `https://` ohne Host, Then jeweils `https://habits.henemm.com`. Test: `testDienstadresseFehlendOderKaputtFaelltAufVorgabe`.
- **AC-6 (Unit): https wird übernommen.** Given `HHServiceURL = https://dienst.example.org`, Then genau diese URL, unabhängig von `allowsLocalHTTP`. Test: `testDienstadresseHttpsWirdUebernommen`.
- **AC-7 (Unit): http nur lokal und nur im Debug.** Given `http://localhost:3000` und `http://127.0.0.1:3000`: mit `allowsLocalHTTP: true` werden sie übernommen, mit `false` greift die Vorgabe; `http://fremd.example.org` ergibt auch mit `allowsLocalHTTP: true` die Vorgabe. Test: `testDienstadresseHttpNurLocalhostImDebug`.
- **AC-8 (Unit): Nonce Form und Einmaligkeit.** Given zwei erzeugte Nonces, Then hat jeder `raw` genau 43 Zeichen aus `A-Za-z0-9-_` ohne `=`, `+`, `/`, und beide Werte sind verschieden. Test: `testNonceHatDreiundvierzigZeichenBase64UrlUndIstEinmalig`.
- **AC-9 (Unit): Nonce-Hash gegen bekannten Vektor.** Given `Nonce(raw: "abc")`, Then `hashed == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"` (SHA-256-Testvektor); `Nonce.hash("")` ergibt `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`; die Länge ist 64, nur Kleinbuchstaben und Ziffern. Test: `testNonceHashEntsprichtSha256Vektor`.
- **AC-10 (Unit): Sitzung speichern, lesen, löschen.** Given Attrappe, When `save("tok-1")`, `load()`, `clear()`, `load()`, Then die erste Abfrage liefert `"tok-1"`, nach `clear` ist `load()` gleich `nil`. Der Anlegen-Aufruf trägt Service `henemm.Meditationstimer-iOS.claude.session`, Account `session`, die Zugriffsklasse `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, `kSecUseDataProtectionKeychain == true` und kein `kSecAttrSynchronizable`. Tests: `testSitzungSpeichernLesenLoeschen`, `testSitzungAbfragenTragenKennungenUndZugriffsklasse`.
- **AC-11 (Unit): Duplikat aktualisiert nur den Wert.** Given die Attrappe antwortet auf `add` mit `errSecDuplicateItem`, When `save("neu")`, Then genau ein `update`-Aufruf mit nur `kSecValueData` als geänderter Eigenschaft, kein `delete`; antwortet `update` mit `errSecItemNotFound`, Then wirft `save` `SessionStoreError.keychain(errSecItemNotFound)` ohne weiteren Versuch. Tests: `testSitzungDuplikatAktualisiertNurDenWert`, `testSitzungUpdateOhneTrefferIstFehler`.
- **AC-12 (Unit): „Nicht gefunden“ ist kein Fehler, alles andere schon.** Given `copyMatching` liefert `errSecItemNotFound`, Then `load()` gleich `nil`; `delete` liefert `errSecItemNotFound`, Then `clear()` wirft nicht; liefern Aufrufe `-34018`, Then wirft `load`, `save` und `clear` jeweils `SessionStoreError.keychain(-34018)`, nie `nil`. Tests: `testSitzungNichtGefundenIstNilUndKeinFehler`, `testSitzungStatusMinus34018IstFehlerNieStillAbgemeldet`.
- **AC-13 (Unit): Kaputte Daten sind Fehler.** Given `copyMatching` liefert Erfolg mit leeren Daten, mit `nil`-Daten und mit Bytes, die kein UTF-8 sind, Then wirft `load()` jeweils `SessionStoreError.corruptData`; die Daten werden nicht überschrieben (kein `add`, kein `update`, kein `delete`). Test: `testSitzungLeereOderKaputteDatenSindCorruptData`.
- **AC-14 (Unit): Fehler tragen nie den Token.** Given `save("geheimes-token-123")` scheitert mit verschiedenen Status, Then enthalten `String(describing: error)` und `error.localizedDescription` den Token nicht. Test: `testSitzungFehlerBeschreibungEnthaeltTokenNie`.
- **AC-15 (Unit): Geräte-UUID wird einmal erzeugt.** Given Attrappe ohne Eintrag, When `current()` zweimal, Then erster Aufruf legt genau einen Eintrag an (Service `henemm.Meditationstimer-iOS.claude.device`, Account `device`, Zugriffsklasse wie oben, Datenschutz-Schlüsselbund) und liefert eine UUID; der zweite liest dieselbe, ohne erneut anzulegen. Tests: `testGeraeteUuidWirdEinmalErzeugtUndWiedergelesen`, `testGeraeteUuidAbfragenTragenKennungenUndZugriffsklasse`.
- **AC-16 (Unit): Duplikat beim Anlegen liest erneut.** Given `copyMatching` liefert zuerst „nicht gefunden“, `add` liefert `errSecDuplicateItem`, das zweite Lesen liefert eine gespeicherte UUID, Then gibt `current()` diese gespeicherte UUID zurück, nicht die frisch erzeugte, und es gibt keinen `update`-Aufruf. Test: `testGeraeteUuidDuplikatBeimAnlegenLiestErneut`.
- **AC-17 (Unit): Fehlerstatus und kaputte Daten bei der Geräte-UUID.** Given `copyMatching` liefert `-34018`, Then wirft `current()` `DeviceIdentityError.keychain(-34018)` und legt nichts an; liefert es Erfolg mit Daten, die keine UUID sind, Then `DeviceIdentityError.corruptData`, und es folgt weder `add` noch `update` noch `delete` (nie ersetzt); liefert das zweite Lesen nach Duplikat einen Fehlerstatus, Then `DeviceIdentityError.keychain(status)`. Tests: `testGeraeteUuidStatusFehlerWirdGeworfenNichtAngelegt`, `testGeraeteUuidKaputteDatenSindFehlerUndWerdenNieErsetzt`.
- **AC-18 (jede Runde): Nichts verdrahtet, Build, Budget.** Given der Diff der Runde, Then sind genau die 5 neuen Dateien unter `Meditationstimer iOS/Claude/` und die neue Testdatei enthalten und keine bestehende Datei geändert (insbesondere nicht `Meditationstimer_iOSApp.swift`, `SettingsSheet.swift`, Info.plist, Entitlements, `project.pbxproj`); außerhalb der Tests ruft nichts die neuen Typen auf (Suche im Quelltext); iOS, Watch und Widget bauen; der Produktiv-Diff liegt bei höchstens 250 Zeilen und keine Funktion über 50 Zeilen; bestehende Unit-Suite bleibt grün; Protokoll `Executed N tests` mit N ≥ 1. Nachweis: Diff-Prüfung, Build, Unit-Suite.

## Tests

Neue Testdatei `LeanHealthTimerTests/ClaudeVerbindungBausteineTests.swift`; die Testnamen stehen bei den Kriterien. Zusätzlich die Attrappe `FakeKeychain` (in derselben Datei), die `KeychainOperations` erfüllt, jeden Aufruf mit seinen Attributen aufzeichnet und je Aufruf einen festen Status und feste Daten liefern kann.

Kein UI-Test in diesem Schnitt, und das ist Absicht: Es wird nichts sichtbar. Kein Bildschirm, keine Kennung, kein Ablauf ändert sich, und kein Code der App ruft die Bausteine auf; ein UI-Test hätte nichts zu prüfen außer dem, was die bestehende Suite ohnehin abdeckt. Die Regel „UI-Tests Pflicht für jedes Feature“ greift hier nicht, weil die Runde keine UI berührt; der erste UI-Test der Verbindung entsteht in Schnitt 5 mit der Einstellungsseite.

Durchlauf-Nachweis („App benutzen“): Da nichts verdrahtet ist, besteht er aus dem Start der App im Simulator ohne Veränderung (Regression). Mit dem Stand der Runde wird die App im Simulator gebaut, installiert und gestartet; Meditation-, Workout- und Tracker-Tab werden geöffnet und die Einstellungen über das Zahnrad geöffnet. Erwartet: derselbe Stand wie vor der Runde, kein Eintrag „Claude-Verbindung“, kein Absturz, kein Systemdialog. Ein Screenshot der Einstellungen wird als Beleg abgelegt. Kein Gerät von Henning (Simulator `iPhone 17 Pro`, iOS 27.2).

## Test Plan

- [ ] Unit (neue Datei `LeanHealthTimerTests/ClaudeVerbindungBausteineTests.swift`): AC-1 bis AC-17
- [ ] RED-Beleg: Die Tests scheitern zuerst, weil die Typen fehlen (Übersetzungsfehler „cannot find …“ im Testziel); danach legt der Developer die 5 Dateien an
- [ ] Bestand: vollständige Unit-Suite grün (Aufruf wie in `CLAUDE.md`, Nachweis nur mit `Executed N tests`, N ≥ 1)
- [ ] Build grün für iOS, Watch und Widget
- [ ] Diff-Prüfung AC-18: nur die 5 neuen App-Dateien und die Testdatei; Suche im Quelltext, dass außerhalb der Tests niemand die Typen aufruft
- [ ] Durchlauf im Simulator: App starten, Tabs und Einstellungen öffnen, unverändert; Screenshot der Einstellungen
- [ ] Kein UI-Test (begründet oben)

## Risiken

- **Tote Typen im Release.** Unverdrahtete Typen werden vom Compiler nicht gemeldet, solange sie intern sind; es gibt keine Warnung und keine Verhaltensänderung. Risiko gering; AC-18 prüft, dass nichts sie aufruft.
- **Schlüsselbund im Simulator und in Tests.** Die echte `SystemKeychain` braucht ein Entitlement und kann im Test ohne App-Host den Status -34018 liefern; deshalb benutzen alle Tests die Attrappe, und die echte Klasse enthält nur die vier `SecItem*`-Aufrufe ohne Logik.
- **Falsche Schalterlogik hätte später Folgen.** Ein Release-Bau mit eingeschalteter Verbindung wäre ein Datenschutzfehler (Elternspec, Verhalten 1). AC-1 und AC-4 sichern die Vorgabe „aus“ und die Typprüfung des Bool ab; Schnitt 5 prüft zusätzlich, dass die Einstellungsseite im Release nicht erscheint.
- **Budget.** Geschätzt +234 Zeilen App-Code, 16 unter der Grenze. Die Zeilenersparnis kommt aus `KeychainEntry` und dem Weglassen von `InMemorySessionStore`. Bei Überschreitung von 250: STOP, Zeilen nicht anheben; `DeviceIdentity` mit `KeychainEntry` in einen eigenen Schnitt 1b verschieben.
- **Namenskollisionen.** `Nonce`, `SessionStoring`, `DeviceIdentity` sind allgemein; vor dem Anlegen wird im Ziel `Lean Health Timer` nach gleichnamigen Typen gesucht. Bei Treffer Name mit Begründung im RED-Bericht ändern.
- **Watch und Widget.** Kompilieren `Meditationstimer iOS` nicht; Build-Wächter bleibt in der Abschlussprüfung.

## Definition of Done

- [ ] ACs AC-1 bis AC-18 nachgewiesen, im Protokoll `Executed N tests` mit N ≥ 1
- [ ] Vollständige Unit-Suite grün
- [ ] Build grün für iOS, Watch und Widget
- [ ] Produktiv-Diff ≤ 250 Zeilen, Funktionen ≤ 50 Zeilen, keine bestehende Datei geändert
- [ ] Durchlauf im Simulator (Regression) mit Screenshot
- [ ] Adversary-Prüfung: Verdict VERIFIED
- [ ] `openspec/specs/features/claude-verbindung-app.md` nachgezogen: Schnitt 1 erledigt, Abweichungen (InMemorySessionStore nach Schnitt 2, Entitlement nach Schnitt 2, Schalter ohne Info-Plist-Eintrag) vermerkt
- [ ] Änderungen am Gerät von Henning: keine, kein Start auf seinen Geräten

## Changelog

- 2026-11-23: Angelegt als Rundenspec Schnitt 1 aus der Analyse (Schalter, Nonce, Sitzungsspeicher, Geräte-UUID, übernommen aus Loose Ends). Abweichungen vom Vorbild: kein Info-Plist-Eintrag, `InMemorySessionStore` und Entitlement in Schnitt 2, gemeinsame Abfrage-Hilfe `KeychainEntry`.
