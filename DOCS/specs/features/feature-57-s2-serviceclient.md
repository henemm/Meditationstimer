---
entity_id: feature-57-s2-serviceclient
type: feature
created: 2026-11-23
updated: 2026-11-23
status: draft
workflow: feature-57-s2-serviceclient
issue: 57
epic: 44
parent: claude-verbindung-app
---

# Schnitt 2, Runde 2a: ServiceClient (Auth-Routen) und InMemorySessionStore der Claude-Verbindung (#57)

## Approval

- [ ] Approved

Freigabe dieser Rundenspec durch den PO.

## Purpose

Schnitt 2 der Elternspec `openspec/specs/features/claude-verbindung-app.md` wird wegen der Zeilengrenze in zwei Runden geteilt. Runde 2a (diese Spec) liefert den Gesprächspartner zum Claude-Dienst und einen Sitzungsspeicher im Arbeitsspeicher: den `ServiceClient` mit den drei Anmelde-Routen (anmelden, abmelden, Konto löschen) hinter einer austauschbaren Transport-Naht, und den `InMemorySessionStore`, der in Tests und später im UI-Test-Stand-in den Schlüsselbund ersetzt.

Sichtbar für Henning: nichts. Keine Datei der App ruft die neuen Typen auf, es geht kein Netzwerkverkehr hinaus, kein Bildschirm ändert sich. Der Wert der Runde liegt darin, dass der Vertrag mit dem Server (Pfade, Körper, Bearer-Kopf, Statuscodes) und die Regel „kein Token in Fehlern“ vor der Verdrahtung durch Tests festgelegt sind. Runde 2b (`AccountState`, eigener Workflow, dieselbe Spec-Reihe) baut darauf auf.

## Source

- Kontext und Analyse: `DOCS/context/feature-57-s2-serviceclient.md` (Abschnitt „Analysis“, verbindlich: Schnittentscheidung 2a/2b, Server-Vertrag, Zeilenbudget, Affected Files)
- Elternspec: `openspec/specs/features/claude-verbindung-app.md`, Schnitt 2 und Schnitt 4. Die Elternspec wird vom Orchestrator an die Teilung angepasst (Schnitt-2-Zeile: Runde 2a/2b, Entitlement nicht mehr dabei; Schnitt-4-Zeile: Entitlement samt Portal-Schritt).
- Server-Vertrag: `server/src/auth.ts` (Routen Zeile 146 bis 148, Logik Zeile 65 bis 141)
- Vorbild (nur gelesen): `/Users/hem/Developer/loose-ends/LooseEnds/Claude/ServiceClient.swift`, `SessionStore.swift` Zeile 19 bis 63, Tests `LooseEndsTests/ServiceClientTests.swift`
- Vorgänger: `DOCS/specs/features/feature-57-s1-bausteine.md` (`SessionStoring`, `Nonce`, `ClaudeWiring`, Schlüsselbund)

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine neue; die Runde folgt der Leitlinie der Elternspec („Wie Loose Ends, so einfach wie möglich“, PO 13.11.2026) und der PO-Regel zur Zeilengrenze (#48). Festgehalten werden zwei Entscheidungen dieser Runde.

### Entscheidung 1: Schnitt 2 in 2a und 2b teilen, Grenze nicht anheben

Das Vorbild 1:1 hätte rund 290 Zeilen App-Code ergeben (Client ~100, `AccountState` ~145, `InMemorySessionStore` ~45, `.injected` +1) und damit die Grenze von 250 überschritten. Gewählt: teilen. Runde 2a (diese Spec) ca. 150 Zeilen in 3 Dateien, Runde 2b `AccountState` ohne `withSession` ca. 145 Zeilen, jeweils eigener Workflow, dieselbe Spec-Reihe. 2b hängt an 2a (`ServiceClient`, `InMemorySessionStore` für ihre Tests).

Verworfen:
- Grenze für Schnitt 2 auf ca. 300 anheben: widerspricht der PO-Regel „je Schnitt eigene Runde, Zeilengrenze nie selbst anheben“ (#48).
- `AccountState` vor `ServiceClient` bauen: bräuchte eine Platzhalter-Naht und doppelte Arbeit.
- `withSession` ins Schnitt 2 ziehen, um die Teile gleich zu schneiden: gehört zum ersten Nutzer (Abgleich, Schnitt 4) und wäre bis dahin toter Code.

### Entscheidung 2: Entitlement Sign in with Apple wandert zu Schnitt 4

In der Elternspec stand das Entitlement bei Schnitt 2. Es kommt stattdessen mit der Verdrahtung (Schnitt 4), zusammen mit dem Portal-Schritt aus #56 (Fähigkeit „Sign in with Apple“ an der App-ID `henemm.Meditationstimer-iOS`).

Begründung: Das Projekt hat eine Entitlements-Datei für Debug und Release (`Meditationstimer iOS/Meditationstimer iOS.entitlements`, heute nur HealthKit), Signierung automatisch, Team `XK87E2B3VR`. Die Fähigkeit ist laut Stand vom 2026-11-23 im Portal nicht gesetzt (#56 und henemm/henemm-infra#454 offen, Runbook Schritt 2.1 nicht ausgeführt, kein lokales Provisioning-Profil mit `com.apple.developer.applesignin`). Ein Eintrag in der Datei ohne Portal-Fähigkeit lässt Gerätebauten aus Xcode und Archive scheitern („Provisioning profile … doesn't include the com.apple.developer.applesignin entitlement“), obwohl noch kein Code das Entitlement nutzt. Simulator und CI (Ad-hoc) wären nicht betroffen, Hennings Gerätebauten aber schon. Quellen: Apple, „Provisioning with managed capabilities“ (developer.apple.com/help/account/reference/provisioning-with-managed-capabilities); Apple-Entwicklerforum, Thread 811382.

Verworfen:
- Entitlement jetzt eintragen: Nebeneffekt auf Gerätebauten ohne jeden Nutzen in dieser Runde.
- Eigene Entitlements-Datei nur für Simulator/Debug: zusätzliche Build-Konfiguration für einen Zwischenstand, widerspricht „einfach statt kompliziert“.
- Portal-Schritt vorziehen: Betriebsaufgabe von #56 beim Inbetriebnehmen, nicht Teil dieser Runde.

## Scope

App-Code (2 neue Dateien, 1 geänderte; ca. +150 Zeilen, Grenze 250 gilt nur für App-Code, Tests zählen nicht):

| Datei | Änderung | Inhalt | ca. Zeilen |
|---|---|---|---|
| `Meditationstimer iOS/Claude/ServiceClient.swift` | neu | `HTTPTransport`, `URLSessionTransport` (ephemeral), `ServiceError`, `ServiceClient` mit `signIn`, `logout`, `deleteAccount` | 100 |
| `Meditationstimer iOS/Claude/InMemorySessionStore.swift` | neu | `SessionStoring` im Arbeitsspeicher, `Mutex` (Synchronization), `failNext` | 45 |
| `Meditationstimer iOS/Claude/SessionStore.swift` | geändert | `SessionStoreError` bekommt den Fall `injected` | +1 |

Tests (zählen nicht zum Budget): `LeanHealthTimerTests/ServiceClientTests.swift` (neu, mit Transport-Attrappe) und `LeanHealthTimerTests/InMemorySessionStoreTests.swift` (neu), beide `@testable import Lean_Health_Timer`, Stil wie `ClaudeVerbindungBausteineTests.swift`.

Der Ordner `Claude/` und `LeanHealthTimerTests/` liegen in synchronisierten Gruppen; kein Eingriff in `project.pbxproj`. Watch und Widget bekommen nichts.

Unverändert: alle übrigen Dateien der App, `Meditationstimer-iOS-Info.plist`, `Meditationstimer iOS.entitlements`, `project.pbxproj`, alle `@AppStorage`-Schlüssel.

## Nicht in Scope

- `AccountState` (Runde 2b, eigener Workflow, dieselbe Spec-Reihe).
- `withSession` (Schnitt 4, erster Nutzer ist der Abgleich).
- Abschrift-Route und Lieferungen-Routen `/app/deliveries/*` (Schnitt 3 und 4). Im `ServiceClient` stehen deshalb weder `putTranscript` noch `claim` noch `putResult`, auch nicht als Rumpf.
- `putDevice` und Push: entfallen, kein Push im Konzept von HHHaven. Daher auch kein `ServiceError.refused` (409) und kein `.tooManyRequests` (429).
- Entitlement Sign in with Apple: Schnitt 4, zusammen mit dem Portal-Schritt aus #56 (siehe ADR, Entscheidung 2).
- Jede Verdrahtung in der App (`Meditationstimer_iOSApp.swift`, `SettingsSheet.swift`), Einstellungsseite und Texte DE/EN (Schnitt 5).
- `project.pbxproj`, `Info.plist`, `AppStorage`-Schlüssel.
- Netzwerkzugriff gegen den echten Dienst: die Tests laufen nur über die Transport-Attrappe.

## Dependencies

| Abhängigkeit | Art | Hinweis |
|---|---|---|
| `SessionStoring`, `SessionStoreError` (Schnitt 1) | Upstream | `InMemorySessionStore` erfüllt das Protokoll; `.injected` wird ergänzt |
| Foundation, Synchronization | Frameworks | `Mutex` mit Ziel iOS 18.5 und `SWIFT_VERSION 5.0` per Probe-Typprüfung bestätigt (`swiftc -swift-version 5 -target arm64-apple-ios18.5-simulator`) |
| `server/src/auth.ts` | Vertrag | Gegenseite der drei Routen, nicht verändert |
| `Nonce`, `ClaudeWiring` (Schnitt 1) | keine in dieser Runde | `ServiceClient` bekommt `baseURL` von außen und kennt `ClaudeWiring` nicht |
| Runde 2b, Schnitt 4, Schnitt 5 | Downstream | `AccountState` nutzt `ServiceClient` und in Tests `InMemorySessionStore` |
| Dienst (#54/#55, Betrieb #56 offen) | keine | Kein Aufruf in dieser Runde |

## Expected Behavior

- Input: Die Typen werden nur von den Unit-Tests aufgerufen, mit einer Transport-Attrappe, die Aufrufe aufzeichnet und feste Antworten oder Fehler liefert.
- Output: Werte oder `ServiceError` beziehungsweise `SessionStoreError` nach den Regeln unten.
- Side effects: Keine in der App. `URLSessionTransport` wird in den Tests nie benutzt; es geht kein Netzwerkverkehr hinaus, auf Hennings Geräten läuft nichts.

Regeln:

1. **Anmelden.** `signIn(identityToken:nonce:code:)` sendet `POST <baseURL>/auth/apple` mit `Content-Type: application/json` und `Accept: application/json` und einem JSON-Objekt mit genau den drei Schlüsseln `identityToken`, `nonce` (der Rohwert) und `code`. Antwort 200 mit `{"sessionToken": "<nicht leer>"}` liefert den Token. Anfrage ohne Zwischenspeicher (`reloadIgnoringLocalCacheData`), Zeitlimit 15 Sekunden.
2. **Abmelden und Konto löschen.** `logout(sessionToken:)` sendet `POST <baseURL>/auth/logout`, `deleteAccount(sessionToken:)` sendet `POST <baseURL>/auth/delete`, beide mit `Authorization: Bearer <Token>` und ohne Körper. Erfolg ist jeweils nur 204.
3. **Statuscodes.** Ein Status außerhalb der Erfolgsmenge der Route wird abgebildet: 401 auf `ServiceError.unauthorized`, 503 auf `ServiceError.unavailable`, jeder andere (auch 400, 405, 413, 415, 500) auf `ServiceError.rejected(Statuscode)`. Bei der Anmeldung heißt 401 für die App „nicht zugelassen“: der Server nennt keinen Grund (leere Antwort, `no-store`), die App kann nur `unauthorized` von `unavailable` und `rejected` unterscheiden; die Übersetzung in einen Anmeldestatus macht Runde 2b.
4. **Ungültige Antwort.** Bei der Anmeldung führt ein 200 mit kaputtem JSON, ohne Objekt, ohne Schlüssel `sessionToken`, mit Nicht-String oder mit leerem String zu `ServiceError.invalidResponse`. Ein leerer Token wird nie als Sitzung zurückgegeben (Merkpunkt aus Schnitt 1: `save("")` würde im Schlüsselbund leer speichern und `load()` wäre `corruptData`).
5. **Transportfehler.** Ein `URLError` mit Code `.cancelled` wird zu `CancellationError`, jeder andere `URLError` zu `ServiceError.unavailable`; ein anderer Fehler der Naht läuft unverändert durch. Eine Antwort, die kein `HTTPURLResponse` ist, wirft in `URLSessionTransport` `ServiceError.invalidResponse`.
6. **Nichts Geheimes in Fehlern und Logs.** `ServiceError` hat nur die Fälle `unauthorized`, `unavailable`, `rejected(Int)`, `invalidResponse`; kein Fall trägt Token, Nonce, `identityToken`, `code`, URL oder Antwortkörper. `String(describing:)` und `localizedDescription` jedes Fehlers enthalten sie nie. Der Client schreibt nichts in Logs.
7. **Transport.** `URLSessionTransport` benutzt eine `ephemeral`-Sitzung (keine Cookies, kein Cache, keine gespeicherten Zugangsdaten). Die Sitzung liegt in der Eigenschaft `session` (Zugriff `internal`, nicht `private`), damit der Test die Konfiguration lesen kann. Eine Instanz von `ServiceClient` anlegen sendet nichts.
8. **Speicher im Arbeitsspeicher.** `InMemorySessionStore(token:)` startet leer oder mit einem Token. `load`, `save`, `clear` folgen dem Vertrag von `SessionStoring` (`clear` ohne Eintrag ist kein Fehler, `load` ohne Eintrag liefert `nil`). `token` liest den Stand ohne Fehlerpfad. Zugriff über `Mutex`, damit der Typ `Sendable` ist.
9. **Fehler einspeisen.** `failNext(load:save:clear:)` merkt je Aufruf einmalig vor; der nächste Aufruf der benannten Art wirft `SessionStoreError.injected` und ändert den Stand nicht, danach läuft der Speicher wieder fehlerfrei. Die Markierungen sind unabhängig voneinander.

## Acceptance Criteria

Alle als Given/When/Then; „Unit“ = `LeanHealthTimerTests/ServiceClientTests.swift`, „Unit-Speicher“ = `LeanHealthTimerTests/InMemorySessionStoreTests.swift`. Die Transport-Attrappe `FakeTransport` erfüllt `HTTPTransport`, zeichnet jede `URLRequest` auf und liefert je Aufruf feste Daten und einen festen Statuscode oder wirft einen vorgegebenen Fehler.

- **AC-1 (Unit): Anmeldung sendet Pfad, Methode, Köpfe und Körper.** Given `FakeTransport` antwortet 200 mit `{"sessionToken":"tok-1"}`, When `signIn(identityToken: "idt", nonce: "roh", code: "cde")`, Then genau eine Anfrage: Methode `POST`, URL `<baseURL>/auth/apple`, `Content-Type` und `Accept` gleich `application/json`, Zwischenspeicher `reloadIgnoringLocalCacheData`, Zeitlimit 15; der Körper dekodiert zu einem Objekt mit genau den Schlüsseln `identityToken`, `nonce`, `code` und den gegebenen Werten. Test: `testAnmeldungSendetPfadMethodeKoepfeUndKoerper`.
- **AC-2 (Unit): Anmeldung liefert den Sitzungstoken.** Given 200 mit `{"sessionToken":"tok-1"}`, When `signIn`, Then Rückgabe `"tok-1"`. Test: `testAnmeldungLiefertSitzungstoken`.
- **AC-3 (Unit): Abmelden und Löschen senden Bearer ohne Körper.** Given 204, When `logout(sessionToken: "tok-1")` und `deleteAccount(sessionToken: "tok-1")`, Then die Anfragen gehen mit `POST` an `<baseURL>/auth/logout` beziehungsweise `<baseURL>/auth/delete`, `Authorization` ist `Bearer tok-1`, es gibt keinen Körper, und beide Aufrufe werfen nicht. Tests: `testAbmeldenSendetBearerOhneKoerper`, `testKontoLoeschenSendetBearerOhneKoerper`.
- **AC-4 (Unit): Statuscodes werden abgebildet.** Given Antworten mit 401, 503, 400, 405, 413, 415, 500, When `signIn`, Then `ServiceError.unauthorized`, `.unavailable`, `.rejected(400)`, `.rejected(405)`, `.rejected(413)`, `.rejected(415)`, `.rejected(500)`; dieselbe Abbildung für `logout` und `deleteAccount`; ein 200 bei `logout` (nicht 204) ist `.rejected(200)`. Tests: `testStatuscodesWerdenAufServiceErrorAbgebildet`, `testAbmeldenUndLoeschenBildenStatuscodesAb`.
- **AC-5 (Unit): 401 bei der Anmeldung ist als „nicht zugelassen“ unterscheidbar.** Given 401 mit leerem Körper bei `signIn`, Then genau `ServiceError.unauthorized`, und dieser Fall ist verschieden von `.unavailable` und `.rejected(_)`. Test: `testAnmeldung401IstUnauthorizedUndVonAnderenFehlernUnterscheidbar`.
- **AC-6 (Unit): Leere oder kaputte Antwort ist ungültig.** Given 200 mit Körper (a) `{"sessionToken":""}`, (b) `{}`, (c) `{"sessionToken":5}`, (d) `[]`, (e) kein JSON, (f) leerer Körper, When `signIn`, Then jeweils `ServiceError.invalidResponse`, nie ein leerer Token. Test: `testAnmeldungLeererOderFehlenderTokenIstInvalidResponse`.
- **AC-7 (Unit): Transportfehler.** Given die Naht wirft `URLError(.notConnectedToInternet)`, Then `ServiceError.unavailable`; wirft sie `URLError(.cancelled)`, Then `CancellationError`; wirft sie einen eigenen anderen Fehler, Then kommt genau dieser Fehler unverändert an. Test: `testTransportFehlerWerdenAbgebildet`.
- **AC-8 (Unit): Fehler tragen nie Geheimnisse.** Given Anmeldung mit `identityToken` „geheim-idt-111“, `nonce` „geheim-nonce-222“, `code` „geheim-code-333“, Sitzungstoken „geheim-tok-444“ und eine Fehlerantwort mit Körper „geheim-body-555“ bei 400, 401, 503 und 200 ohne Token, When die Aufrufe scheitern, Then enthalten weder `String(describing: error)` noch `error.localizedDescription` noch `String(reflecting: error)` eine der fünf Zeichenfolgen. Test: `testFehlerEnthaltenNieTokenNonceCodeOderKoerper`.
- **AC-9 (Unit): Anlegen sendet nichts.** Given ein neu angelegter `ServiceClient` mit `FakeTransport`, Then hat die Attrappe null Aufrufe. Test: `testAnlegenSendetNichts`.
- **AC-10 (Unit): Echter Transport ist ephemeral.** Given eine Instanz `URLSessionTransport`, Then ist die Sitzungskonfiguration ohne `urlCache` und ohne `httpCookieStorage` und ohne `urlCredentialStorage` (Kennzeichen von `.ephemeral`); der Test liest dazu `URLSessionTransport().session.configuration`, ohne eine Anfrage zu senden. Test: `testURLSessionTransportIstEphemeral`.
- **AC-11 (Unit-Speicher): Speichern, Lesen, Löschen.** Given `InMemorySessionStore()`, When `load()`, `save("tok-1")`, `load()`, `clear()`, `load()`, `clear()`, Then `nil`, dann `"tok-1"`, dann `nil`; das zweite `clear` wirft nicht. `InMemorySessionStore(token: "start")` liefert beim ersten `load()` „start“, und `token` zeigt denselben Stand. Tests: `testSpeicherSpeichernLesenLoeschen`, `testSpeicherStartetMitToken`.
- **AC-12 (Unit-Speicher): `failNext` wirft genau einmal.** Given `failNext(save: true)`, When `save("a")`, `save("b")`, Then der erste Aufruf wirft `SessionStoreError.injected` und ändert nichts (`token` bleibt `nil`), der zweite gelingt (`token` ist „b“). Entsprechend für `failNext(load: true)` und `failNext(clear: true)` (bei `clear` bleibt der Token nach dem Fehler erhalten). Tests: `testFailNextSaveWirftEinmalUndAendertNichts`, `testFailNextLoadWirftEinmal`, `testFailNextClearWirftEinmalUndBehaeltToken`.
- **AC-13 (Unit-Speicher): Markierungen sind unabhängig und nebenläufig sicher.** Given `failNext(load: true)`, Then wirft `save` und `clear` nicht und `load` einmal; gleichzeitig 100 `save`-Aufrufe aus parallelen Aufgaben enden ohne Absturz mit einem der gespeicherten Werte (Prüfung der `Mutex`-Nutzung, `Sendable`). Tests: `testFailNextMarkierungenSindUnabhaengig`, `testSpeicherNebenlaeufigerZugriff`.
- **AC-14 (jede Runde): Nichts verdrahtet, Build, Budget.** Given der Diff der Runde, Then enthält er genau die zwei neuen App-Dateien, die Änderung in `SessionStore.swift` (nur der neue Fall `injected`) und die zwei neuen Testdateien; keine weitere bestehende Datei ist geändert (insbesondere nicht `Meditationstimer_iOSApp.swift`, `SettingsSheet.swift`, Info.plist, Entitlements, `project.pbxproj`); außerhalb der Tests ruft nichts `ServiceClient`, `URLSessionTransport` oder `InMemorySessionStore` auf (Suche im Quelltext); iOS, Watch und Widget bauen; der Produktiv-Diff liegt bei höchstens 250 Zeilen (Zielwert 150) und keine Funktion über 50 Zeilen; die bestehende Unit-Suite bleibt grün; im Protokoll steht `Executed N tests` mit N ≥ 1. Nachweis: Diff-Prüfung, Build, Unit-Suite.

## Tests

Neue Testdateien `LeanHealthTimerTests/ServiceClientTests.swift` (AC-1 bis AC-10) und `LeanHealthTimerTests/InMemorySessionStoreTests.swift` (AC-11 bis AC-13); die Testnamen stehen bei den Kriterien. Zusätzlich die Attrappe `FakeTransport` (in `ServiceClientTests.swift`).

Kein UI-Test in dieser Runde, und das ist Absicht: Es wird nichts sichtbar. Kein Bildschirm, keine Kennung, kein Ablauf ändert sich, und kein Code der App ruft die Bausteine auf; ein UI-Test hätte nichts zu prüfen außer dem, was die bestehende Suite ohnehin abdeckt. Die Regel „UI-Tests Pflicht für jedes Feature“ greift hier nicht, weil die Runde keine UI berührt; der erste UI-Test der Verbindung entsteht in Schnitt 5 mit der Einstellungsseite.

Durchlauf-Nachweis („App benutzen“): Da nichts verdrahtet ist, besteht er aus dem Start der App im Simulator `iPhone 17 Pro` (iOS 27.2) ohne Veränderung (Regression). Mit dem Stand der Runde wird die App gebaut, installiert und gestartet; Meditation-, Workout- und Tracker-Tab werden geöffnet und die Einstellungen über das Zahnrad geöffnet. Erwartet: derselbe Stand wie vor der Runde, kein Eintrag „Claude-Verbindung“, kein Absturz, kein Systemdialog. Screenshot der Einstellungen als Beleg. Kein Gerät von Henning.

## Test Plan

- [ ] Unit (`ServiceClientTests.swift`): AC-1 bis AC-10. GIVEN `FakeTransport` mit fester Antwort WHEN `signIn`, `logout` oder `deleteAccount` THEN Anfrage und Ergebnis wie beschrieben
- [ ] Unit (`InMemorySessionStoreTests.swift`): AC-11 bis AC-13. GIVEN `InMemorySessionStore` WHEN `save`, `load`, `clear` mit und ohne `failNext` THEN Stand und Fehler wie beschrieben
- [ ] RED-Beleg: Die Tests scheitern zuerst, weil die Typen fehlen (Übersetzungsfehler „cannot find …“ im Testziel); danach legt der Developer die zwei Dateien an und ergänzt `.injected`
- [ ] Bestand: vollständige Unit-Suite grün (Aufruf wie in `CLAUDE.md`, Nachweis nur mit `Executed N tests`, N ≥ 1)
- [ ] Build grün für iOS, Watch und Widget
- [ ] Diff-Prüfung AC-14: nur die genannten Dateien; Suche im Quelltext, dass außerhalb der Tests niemand die Typen aufruft
- [ ] Zeilenzählung des Produktiv-Diffs (ohne Tests): höchstens 250, Zielwert 150
- [ ] Durchlauf im Simulator: App starten, Tabs und Einstellungen öffnen, unverändert; Screenshot
- [ ] Kein UI-Test (begründet oben)

## Risiken

- **Tote Typen im Release.** Unverdrahtete interne Typen erzeugen keine Warnung und keine Verhaltensänderung. Risiko gering; AC-14 prüft, dass nichts sie aufruft.
- **`Mutex` und Swift-Modus.** `Mutex` braucht iOS 18; Ziel ist iOS 18.5. Die Probe-Typprüfung mit `-swift-version 5` war erfolgreich. Fällt der Bau wider Erwarten durch, wird `OSAllocatedUnfairLock` (ab iOS 16) als gleichwertige Alternative im RED-Bericht begründet eingesetzt, ohne den Umfang zu ändern.
- **Server-Vertrag ändert sich.** Der Client folgt `server/src/auth.ts` (Stand dieses Repos). Eine spätere Änderung am Server muss im selben Zug die Tests dieser Runde anpassen; die Tests dokumentieren den Vertrag.
- **401 ohne Grund.** Der Server unterscheidet Ablehnung, abgelaufenen Code und Namensabweichung nicht nach außen. Die App kann nur „nicht zugelassen“ melden; das ist gewollt und kein Mangel des Clients.
- **Zeilenbudget.** Zielwert 150, Grenze 250. Bei Überschreitung: STOP, Zeilen nicht anheben, Rückfrage mit Schätzung.
- **Namenskollisionen.** `HTTPTransport`, `ServiceError`, `ServiceClient` sind allgemein; vor dem Anlegen wird im Ziel `Lean Health Timer` nach gleichnamigen Typen gesucht. Bei Treffer Name mit Begründung im RED-Bericht ändern.
- **Watch und Widget.** Kompilieren `Meditationstimer iOS` nicht; der Build-Wächter bleibt in der Abschlussprüfung.
- **Entitlement fehlt bis Schnitt 4.** Bewusst. Wer in Schnitt 4 die Verdrahtung beginnt, muss zuerst den Portal-Schritt aus #56 prüfen; das steht im Schnitt-4-Eintrag der Elternspec.

## Definition of Done

- [ ] ACs AC-1 bis AC-14 nachgewiesen, im Protokoll `Executed N tests` mit N ≥ 1
- [ ] Vollständige Unit-Suite grün
- [ ] Build grün für iOS (Simulator `iPhone 17 Pro`, iOS 27.2), Watch und Widget
- [ ] Zeilenzählung: Produktiv-Diff ≤ 250 Zeilen (Zielwert 150), Funktionen ≤ 50 Zeilen, außer `SessionStore.swift` keine bestehende Datei geändert
- [ ] Durchlauf im Simulator (Regression) mit Screenshot
- [ ] Adversary-Prüfung: Verdict VERIFIED
- [ ] Elternspec `openspec/specs/features/claude-verbindung-app.md` angepasst: Schnitt 2 in Runde 2a und 2b geteilt, Entitlement bei Schnitt 4 mit Portal-Schritt (wird vom Orchestrator ausgeführt)
- [ ] Änderungen am Gerät von Henning: keine, kein Start auf seinen Geräten

## Changelog

- 2026-11-23: Angelegt als Rundenspec für Schnitt 2, Runde 2a (`ServiceClient` mit Auth-Routen, `InMemorySessionStore`, `SessionStoreError.injected`). Schnitt 2 wegen der Zeilengrenze in 2a und 2b geteilt (PO-Regel #48); Entitlement Sign in with Apple von Schnitt 2 nach Schnitt 4 verschoben (Portal #56 offen, eine Entitlements-Datei für alle Konfigurationen).
