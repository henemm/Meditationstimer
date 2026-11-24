---
entity_id: feature-57-s2b-accountstate
type: feature
created: 2026-11-24
updated: 2026-11-24
status: draft
workflow: feature-57-s2b-accountstate
issue: 57
epic: 44
parent: claude-verbindung-app
---

# Schnitt 2, Runde 2b: AccountState der Claude-Verbindung (#57)

## Approval

- [ ] Approved

Freigabe dieser Rundenspec durch den PO.

## Purpose

Runde 2b liefert die Zustandsmaschine `AccountState`: ob dieses Gerät beim Claude-Dienst angemeldet ist und wie Anmelden, Abmelden und Konto löschen ablaufen. Sie setzt `ServiceClient` und `InMemorySessionStore` aus Runde 2a ein und löst Regel 3 der Runde 2a ein: Die Übersetzung von 401 und 503 in einen Anmeldestatus. Übernommen wird `AccountState` 1:1 aus Loose Ends, ohne `withSession` (das kommt mit Schnitt 4, erster Nutzer ist der Abgleich).

Sichtbar für Henning: nichts. Keine Datei der App ruft `AccountState` auf, kein Netzwerkverkehr ändert sich, kein Bildschirm ändert sich. Der Wert der Runde: Die Regeln „lokal zuerst abmelden“, „veraltete 401 löscht keine neuere Sitzung“ und „keine Geheimnisse im Zustand“ sind durch Tests festgelegt, bevor die Einstellungsseite (Schnitt 5) den Zustand anzeigt.

## Source

- Kontext und Analyse: `DOCS/context/feature-57-s2b-accountstate.md` (verbindlich: Technical Approach, Risks, Alternativen)
- Elternspec: `openspec/specs/features/claude-verbindung-app.md`, Schnitt 2 und Schnitt 4
- Vorrunde: `DOCS/specs/features/feature-57-s2-serviceclient.md` (Regel 3: Übersetzung 401/503 macht 2b)
- Vorbild (nur gelesen): `~/Developer/loose-ends/LooseEnds/Claude/AccountState.swift` (171 Z.), Tests `~/Developer/loose-ends/LooseEndsTests/AccountStateTests.swift` (Z. 1 bis 308; die `session:`-Gruppe ab Z. 310 entfällt)

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine neue; Leitlinie der Elternspec „Wie Loose Ends, so einfach wie möglich“ (PO 13.11.2026).

- **Übernahme 1:1, nur `withSession` entfällt.** `dropSession` bleibt, weil `deleteAccount` es bei 401 braucht.
- **`signingIn` und `deleting` sind die Sperre gegen Doppelaufrufe.** Alles läuft auf dem Main-Actor, ein zweiter Aufruf trifft auf den Zwischenzustand und tut nichts.
- **Geheimnisse:** Weder Zustand, Fehler noch Logzeile nennen Token oder Nonce; Logs enthalten nur Fall- und Typnamen (`privacy: .public` nur dafür). Logger-Subsystem `com.henemm.Meditationstimer`, Kategorie `account`.

Alternativen, verworfen:
- **2b mit Schnitt 5 zusammenlegen** (Zustand erst bauen, wenn die Seite ihn anzeigt): kein unverdrahteter Code, aber Schnitt 5 sprengte mit Seite, Texten und UI-Test die Zeilengrenze und kippte die Schnittfolge der Elternspec.
- **`withSession` jetzt mitnehmen:** ca. +15 Zeilen, aber bis Schnitt 4 ohne Nutzer; die Elternspec legt es bewusst nach Schnitt 4.
- **Ohne Zustandsmaschine, Seite ruft `ServiceClient` und Speicher direkt:** Die Regeln (lokal zuerst, veraltete 401, Sperre) verteilten sich auf die Oberfläche und wären nur per UI-Test prüfbar; verworfen.

## Scope

App-Code (1 neue Datei, ca. 125 bis 140 Zeilen; Grenze 250 gilt nur für App-Code, Tests zählen nicht):

| Datei | Änderung | Inhalt | ca. Zeilen |
|---|---|---|---|
| `Meditationstimer iOS/Claude/AccountState.swift` | neu | `AccountError`, `AccountState` (`Status`, `Problem`, `beginSignIn`, `completeSignIn`, `cancelSignIn`, `signOut`, `deleteAccount`, `dropSession`, `clearStore`, `storedToken`, `signInStatus`, `caseName`) | 125 bis 140 |

Tests (zählen nicht zum Budget): `LeanHealthTimerTests/AccountStateTests.swift` (neu, XCTest, `@testable import Lean_Health_Timer`, deutsche `testXyz`-Namen, `@MainActor`).

Doku: `openspec/specs/features/claude-verbindung-app.md`, Schnitt-2-Zeile nach Abschluss auf „Erledigt“ (Runde 2a und 2b).

Der Ordner `Claude/` und `LeanHealthTimerTests/` liegen in synchronisierten Gruppen; kein Eingriff in `project.pbxproj`. Watch und Widget bekommen nichts.

## Nicht in Scope

- `withSession` (Schnitt 4, erster Nutzer ist der Abgleich).
- Jede Oberfläche: Einstellungsseite, Texte DE/EN, Apple-Anmeldedialog (`AuthenticationServices`), Knöpfe (Schnitt 5).
- Entitlement Sign in with Apple und Portal-Schritt #56 (Schnitt 4).
- Verdrahtung in der App (`Meditationstimer_iOSApp.swift`, `SettingsSheet.swift`).
- Änderungen an `ServiceClient`, `SessionStore`, `InMemorySessionStore`, `Nonce`, `project.pbxproj`, `Info.plist`, `AppStorage`-Schlüsseln.
- Netzwerkzugriff gegen den echten Dienst: Tests laufen nur über eine Transport-Attrappe.

## Dependencies

| Abhängigkeit | Art | Hinweis |
|---|---|---|
| `ServiceClient.signIn(identityToken:nonce:code:)`, `logout(sessionToken:)`, `deleteAccount(sessionToken:)` | Upstream (2a) | alle `async throws`; `init(baseURL:transport:)` |
| `ServiceError` (`unauthorized`, `unavailable`, `rejected(Int)`, `invalidResponse`) | Upstream (2a) | `Equatable`; `CancellationError` kommt bei `URLError.cancelled` |
| `HTTPTransport` (`send(_:) async throws -> (Data, HTTPURLResponse)`) | Upstream (2a) | Test-Attrappe |
| `SessionStoring` (`load() throws -> String?`, `save(_:)`, `clear()`) | Upstream (1) | `any SessionStoring` |
| `InMemorySessionStore(token:)`, `token`, `failNext(load:save:clear:)` | Upstream (2a), Tests | wirft `SessionStoreError.injected` |
| `Nonce()` (`throws`), `raw`, `hashed`, `Nonce.hash(_:)` | Upstream (1) | `hashed` ist SHA-256 in 64 Hexzeichen, `raw` 43 Zeichen |
| Foundation, Observation, OSLog | Frameworks | iOS 18.5: `@Observable` verfügbar |
| Schnitt 4 (`withSession`, Abgleich), Schnitt 5 (Einstellungsseite liest `status`, `lastProblem`) | Downstream | |

## Expected Behavior

- Input: `AccountState(client:store:)`; Aufrufe `beginSignIn()`, `completeSignIn(identityToken:code:)`, `cancelSignIn()`, `signOut()`, `deleteAccount()`. In Tests über eine Transport-Attrappe und `InMemorySessionStore`.
- Output: Zustand `status` (`signedOut`, `signingIn`, `signedIn`, `deleting`, `notAllowed`, `retryLater`) und `lastProblem` (`nil` oder `.retryLater`); `beginSignIn` liefert die gehashte Nonce für Apples Anfrage; `AccountError.notPossibleNow`, wenn der Zustand den Aufruf nicht erlaubt.
- Side effects: Sitzungstoken im übergebenen Speicher (speichern, löschen), Anfragen an den `ServiceClient`, Logzeilen mit Fall- und Typnamen. In der App: keine, nichts ruft die Klasse auf.

Regeln:

1. **Start.** `init` liest den Speicher einmal und sendet nichts. Token vorhanden: `signedIn`; keiner oder Lesefehler: `signedOut`. `lastProblem` ist `nil`.
2. **`beginSignIn`.** Nur aus `signedOut`, `notAllowed`, `retryLater`, sonst wirft es `AccountError.notPossibleNow` und ändert nichts. Es erzeugt eine frische `Nonce`, setzt `signingIn` und `lastProblem = nil` und liefert `hashed`. Schlägt `Nonce()` fehl, wirft es den Fehler und der Zustand bleibt.
3. **`completeSignIn`.** Nur in `signingIn` mit offener Nonce, sonst ohne Wirkung und ohne Anfrage. Die Nonce wird vor der Anfrage verbraucht (einmalig). Gesendet wird die rohe Nonce, die zur gelieferten gehashten gehört.
4. **Fehlerabbildung bei der Anmeldung** (löst Regel 3 der Runde 2a ein): `unauthorized` ergibt `notAllowed`, `unavailable` ergibt `retryLater`, `CancellationError` ergibt `signedOut`, alles andere (`rejected`, `invalidResponse`, andere Fehler) ergibt `signedOut` mit einer Logzeile. Der Speicher bleibt in allen Fällen leer.
5. **Speichern vor Anmeldung.** Erfolg: Token zuerst in den Speicher, danach `signedIn`. Scheitert `save`, ist der Zustand `signedOut` (Logzeile mit Typname) und der Speicher unverändert.
6. **`cancelSignIn`.** Nur in `signingIn` mit noch offener Nonce (Anfrage nicht gestartet): setzt `signedOut`, verwirft die Nonce. In jedem anderen Zustand ohne Wirkung; läuft die Anfrage schon, bleibt `signingIn`.
7. **`signOut`.** Nicht in `signingIn` und `deleting` (ohne Wirkung). Ohne lesbaren Token: `signedOut`, keine Anfrage. Sonst zuerst lokal räumen (`clear`, ein Fehler wird nur geloggt), `signedOut`, `lastProblem = nil`, danach `logout` beim Dienst mit dem alten Token; die Antwort des Dienstes (auch 401, 503, Abbruch) ändert nichts.
8. **`deleteAccount`.** Nur aus `signedIn`, sonst ohne Wirkung und ohne Anfrage. Ohne lesbaren Token: `signedOut`, keine Anfrage. Sonst `deleting`, `lastProblem = nil`, Anfrage mit Bearer-Token. Erfolg: Speicher leeren, `signedOut`. `unauthorized`: `dropSession` (siehe 9). `CancellationError`: zurück auf `signedIn`, kein Problem. Jeder andere Fehler (`unavailable`, `rejected`, `invalidResponse`, Transport): `signedIn` mit `lastProblem = .retryLater`, Token bleibt, ein zweiter Versuch ist möglich.
9. **`dropSession` (veraltete 401).** Der Dienst kennt die Sitzung nicht mehr: Speicher nur leeren, wenn er noch genau diesen Token hält (Ergebnis `signedOut`); hält er einen anderen, bleibt er unberührt und das Ergebnis ist `signedIn`; ist er leer, `signedOut`.
10. **Sperre gegen Doppelaufrufe.** Während einer laufenden Anmeldung oder eines laufenden Löschens tun `beginSignIn` (wirft `notPossibleNow`), `completeSignIn`, `deleteAccount` und `signOut` nichts und senden nichts. Es entsteht genau eine Anfrage.
11. **Keine Geheimnisse.** `status`, `lastProblem`, geworfene `AccountError` und Logzeilen enthalten weder Sitzungstoken noch rohe oder gehashte Nonce, `identityToken` oder `code`. Logs nennen nur `String(describing:)` von `ServiceError`-Fällen (mit Statuscode) oder den Typnamen anderer Fehler.
12. **Nebenläufigkeit.** `@MainActor @Observable final class`; `client`, `store`, `nonce` sind `@ObservationIgnored`; `status` und `lastProblem` sind `private(set)`.

## Acceptance Criteria

„Unit“ = `LeanHealthTimerTests/AccountStateTests.swift`. Hilfsmittel der Tests: eine Transport-Attrappe `Wire` (Actor, `HTTPTransport`) mit Antwortliste (`status(Int)`, `token(String)`, `offline`, `invalid`, `cancel`, `hang`), die jede `URLRequest` aufzeichnet und einen Haken `onFirst` vor der ersten Antwort kennt; `make(replies, token:)` baut `AccountState` mit `ServiceClient(baseURL:transport:)` und `InMemorySessionStore`. Die Attrappe `FakeTransport` aus `ServiceClientTests.swift` wird nicht wiederverwendet, damit die Testdateien unabhängig bleiben.

- **AC-1 (Unit): Start liest einmal und sendet nichts.** Given Speicher mit Token „T1“, When `AccountState` angelegt, Then `status == .signedIn`, `lastProblem == nil`, null Anfragen. Given leerer Speicher oder `failNext(load: true)` bei vorhandenem Token, Then `status == .signedOut`, null Anfragen. Tests: `testStartMitTokenIstAngemeldet`, `testStartOhneTokenOderBeiLesefehlerIstAbgemeldet`.
- **AC-2 (Unit): `beginSignIn` nur aus erlaubten Zuständen.** Given `signedOut`, `notAllowed` (nach 401) oder `retryLater` (nach 503), When `beginSignIn()`, Then `status == .signingIn` und die Rückgabe ist 64 Hexzeichen in Kleinbuchstaben. Given `signingIn`, `signedIn` oder `deleting` (Haken während `deleteAccount`), When `beginSignIn()`, Then wirft es `AccountError.notPossibleNow` und der Status bleibt. Test: `testBeginSignInNurAusErlaubtenZustaenden`.
- **AC-3 (Unit): Der Körper trägt die rohe Nonce zum Hash.** Given `beginSignIn()` lieferte `hashed`, When `completeSignIn(identityToken: "id-token", code: "auth-code")`, Then genau eine Anfrage an `/auth/apple`, Körper mit genau den Schlüsseln `identityToken`, `nonce`, `code`, die Werte stimmen, `nonce` hat 43 Zeichen und `Nonce.hash(nonce) == hashed`; eine zweite `AccountState` liefert ein anderes `hashed`. Test: `testKoerperTraegtRoheNonceZumHash`.
- **AC-4 (Unit): `completeSignIn` ohne offene Nonce und Nonce nur einmal.** Given `signedOut` oder `signedIn` ohne `beginSignIn`, When `completeSignIn`, Then Status unverändert, null Anfragen. Given nach `beginSignIn` und erstem `completeSignIn` (Antwort Token, 401 oder Abbruch), When ein zweites `completeSignIn`, Then insgesamt genau eine Anfrage und der Status bleibt der des ersten Aufrufs. Test: `testCompleteSignInBrauchtOffeneNonceUndVerbrauchtSie`.
- **AC-5 (Unit): Erfolgreiche Anmeldung speichert zuerst.** Given Antwort `{"sessionToken":"T1"}`, When Anmeldung, Then `store.token == "T1"`, `status == .signedIn`, `lastProblem == nil`. Given `failNext(save: true)`, Then `status == .signedOut` und `store.token == nil`. Tests: `testAnmeldenSpeichertUndIstAngemeldet`, `testSpeicherfehlerBeiAnmeldungErgibtAbgemeldet`.
- **AC-6 (Unit): Fehlerabbildung bei der Anmeldung.** Given Antworten 401, 503, offline (`URLError`), 400, 500, leerer Token (`{"sessionToken":""}`), Abbruch (`CancellationError`), When Anmeldung, Then `status` ist jeweils `.notAllowed`, `.retryLater`, `.retryLater`, `.signedOut`, `.signedOut`, `.signedOut`, `.signedOut`; `store.token == nil`; bei Abbruch ist `lastProblem == nil`. Test: `testAnmeldenFehlerabbildung`.
- **AC-7 (Unit): `cancelSignIn`.** Given `beginSignIn()` ohne `completeSignIn`, When `cancelSignIn()`, Then `signedOut`; ein folgendes `completeSignIn` sendet nichts. Given `signedIn`, Then `cancelSignIn()` ändert nichts. Given eine laufende Anmeldung (Haken in der ersten Antwort ruft `cancelSignIn()`), Then bleibt der Status währenddessen `.signingIn` und endet `signedIn` mit gespeichertem Token. Test: `testCancelSignInNurVorDerAnfrage`.
- **AC-8 (Unit): `signOut` räumt lokal zuerst.** Given `signedIn` mit „T1“ und Dienstantwort 204, 401, 503 oder Abbruch, When `signOut()`, Then ist beim Eintreffen der Anfrage (Haken) der Speicher schon leer und `status == .signedOut`; genau eine Anfrage an `/auth/logout` mit `Authorization: Bearer T1`; am Ende `signedOut`, `lastProblem == nil`. Test: `testSignOutRaeumtLokalZuerstUndDienstAntwortAendertNichts`.
- **AC-9 (Unit): `signOut` ohne Token und bei Löschfehler.** Given leerer Speicher oder `failNext(load: true)`, When `signOut()`, Then `signedOut`, null Anfragen. Given `failNext(clear: true)` mit Token, Then `signedOut` und trotzdem eine Anfrage an `/auth/logout`. Test: `testSignOutOhneTokenUndBeiLoeschfehler`.
- **AC-10 (Unit): Konto löschen nur aus `signedIn`, Erfolg.** Given `signedIn` mit „T1“ und Antwort 204, When `deleteAccount()`, Then genau eine Anfrage an `/auth/delete` mit `Bearer T1`, `store.token == nil`, `signedOut`, `lastProblem == nil`. Given `signedOut`, `notAllowed`, `retryLater` oder `signingIn`, Then keine Anfrage über die Anmeldung hinaus und der Status bleibt. Given `signedIn`, aber Speicher ist leer oder `failNext(load: true)`, Then `signedOut` ohne Anfrage. Test: `testKontoLoeschenNurAusAngemeldetUndErfolg`.
- **AC-11 (Unit): Fehlerabbildung beim Löschen.** Given `signedIn` und Antwort 401, 503, offline, 500, `invalidResponse`, Abbruch, When `deleteAccount()`, Then: 401 ergibt `signedOut`, Speicher leer, `lastProblem == nil`; 503, offline, 500 und `invalidResponse` ergeben `signedIn`, Token bleibt, `lastProblem == .retryLater`; Abbruch ergibt `signedIn`, Token bleibt, `lastProblem == nil`. Bei den `signedIn`-Fällen führt ein zweites `deleteAccount()` (Antwort 204) zu `signedOut`, `lastProblem == nil`, leerem Speicher. Test: `testKontoLoeschenFehlerabbildung`.
- **AC-12 (Unit): Veraltete 401 löscht keine neuere Sitzung.** Given `signedIn` mit „T1“, die erste Antwort ist 401, und der Haken speichert vorher „T2“, When `deleteAccount()`, Then `store.token == "T2"` und `status == .signedIn`. Test: `testVeraltete401LoeschtKeineNeueSitzung`.
- **AC-13 (Unit): Doppelaufrufe während der Anfrage.** Given eine laufende Anmeldung (Haken ruft `completeSignIn`, `signOut` und `beginSignIn`), Then bleibt es bei einer Anfrage, `beginSignIn` wirft `notPossibleNow`, am Ende `signedIn` mit „T1“. Given ein laufendes Löschen (Haken ruft `deleteAccount`, `signOut`, `beginSignIn`), Then eine Anfrage, `status == .deleting` im Haken, `beginSignIn` wirft, am Ende `signedOut` mit leerem Speicher. Test: `testDoppelaufruefeWaehrendAnfrageSindWirkungslos`.
- **AC-14 (Unit): Keine Geheimnisse im Zustand.** Given Sitzungstoken, `identityToken` und `code` enthalten die Marke „SECRET-TOKEN“, die Antworten sind Token, 503, 401, When Anmeldung, zweites `beginSignIn` (Fehler abfangen) und zwei Löschversuche, Then enthalten `String(describing:)` von `status`, `lastProblem` und dem geworfenen Fehler weder die Marke noch die rohe noch die gehashte Nonce. Test: `testZustandEnthaeltWederTokenNochNonce`.
- **AC-15 (jede Runde): Nichts verdrahtet, Build, Budget.** Given der Diff der Runde, Then enthält er genau die neue App-Datei `AccountState.swift`, die neue Testdatei und die Zeile in der Elternspec; keine weitere bestehende App-Datei ist geändert (insbesondere nicht `ServiceClient.swift`, `SessionStore.swift`, `Meditationstimer_iOSApp.swift`, `SettingsSheet.swift`, Info.plist, Entitlements, `project.pbxproj`); außerhalb der Tests ruft nichts `AccountState` auf (Suche im Quelltext); `withSession` kommt im Quelltext nicht vor und `AuthenticationServices` wird nicht importiert; iOS, Watch und Widget bauen; Produktiv-Diff höchstens 250 Zeilen (Zielwert 125 bis 140), keine Funktion über 50 Zeilen; die bestehende Unit-Suite bleibt grün; im Protokoll steht `Executed N tests` mit N ≥ 1. Nachweis: Diff-Prüfung, Quelltextsuche, Build, Unit-Suite.

## Tests

Neue Datei `LeanHealthTimerTests/AccountStateTests.swift` (AC-1 bis AC-14); Testnamen stehen bei den Kriterien. Fälle des Vorbilds Z. 53 bis 308 ohne `session:`-Gruppe, übertragen von Swift Testing nach XCTest (`XCTAssertEqual` statt `#expect`, `XCTAssertThrowsError` statt `#expect(throws:)`, Argumentlisten als Schleifen mit aussagekräftiger Meldung). Die Testklasse ist `@MainActor`.

Kein UI-Test in dieser Runde, und das ist Absicht: Es wird nichts sichtbar. Kein Bildschirm, keine Kennung, kein Ablauf ändert sich, und kein Code der App ruft die Klasse auf. Der erste UI-Test der Verbindung entsteht in Schnitt 5 mit der Einstellungsseite.

Durchlauf-Nachweis („App benutzen“): Da nichts verdrahtet ist, besteht er aus dem Start der App im Simulator `iPhone 17 Pro` (iOS 27.2) ohne Veränderung (Regression): bauen, installieren, starten, Meditation-, Workout- und Tracker-Tab öffnen, Einstellungen über das Zahnrad öffnen. Erwartet: derselbe Stand wie vor der Runde, kein Eintrag „Claude-Verbindung“, kein Absturz, kein Systemdialog. Screenshot der Einstellungen als Beleg. Kein Gerät von Henning.

## Test Plan

- [ ] Unit (`AccountStateTests.swift`): AC-1 bis AC-14. GIVEN `Wire`-Attrappe mit fester Antwortliste und `InMemorySessionStore` WHEN Anmelden, Abbrechen, Abmelden, Löschen THEN Status, Problem, Speicher und aufgezeichnete Anfragen wie beschrieben
- [ ] RED-Beleg: Die Tests scheitern zuerst, weil `AccountState` und `AccountError` fehlen (Übersetzungsfehler „cannot find …“ im Testziel); danach legt der Developer `AccountState.swift` an
- [ ] Bestand: vollständige Unit-Suite grün (Aufruf wie in `CLAUDE.md`, Nachweis nur mit `Executed N tests`, N ≥ 1)
- [ ] Build grün für iOS, Watch und Widget
- [ ] Diff-Prüfung und Quelltextsuche AC-15: nur die genannten Dateien; niemand außer den Tests ruft `AccountState` auf; kein `withSession`
- [ ] Zeilenzählung des Produktiv-Diffs (ohne Tests): höchstens 250, Zielwert 125 bis 140
- [ ] Durchlauf im Simulator: App starten, Tabs und Einstellungen öffnen, unverändert; Screenshot
- [ ] Kein UI-Test (begründet oben)

## Risiken

- **Toter Code bis Schnitt 4 und 5.** Bewusst so in der Elternspec geschnitten (2a ebenfalls unverdrahtet); AC-15 prüft, dass nichts die Klasse aufruft.
- **`dropSession` ohne `withSession`.** Bleibt, weil `deleteAccount` es bei 401 braucht; AC-12 deckt die veraltete 401 ab.
- **Geheimnisse in Logs.** Nur Fall- und Typnamen mit `privacy: .public`; `ServiceError` trägt nach Spec 2a nie Token, Nonce oder Körper. AC-14 prüft den Zustand; Logzeilen werden im Review gegen die Regel geprüft.
- **Swift-Modus und Observation.** Projekt mit `SWIFT_VERSION 5.0` und Xcode 27: `@MainActor @Observable` ohne Sendable-Fehler übersetzen; Haken-Closures der Test-Attrappe brauchen `@MainActor @Sendable`. Fällt der Bau durch, wird die Anpassung im RED-Bericht begründet, ohne den Umfang zu ändern.
- **Test-Übertragung von Swift Testing nach XCTest.** Parametrisierte Tests werden Schleifen; ein Fehlschlag muss den Fall in der Meldung nennen, sonst ist die Ursache nicht erkennbar.
- **Namenskollision.** `AccountState` und `AccountError` sind allgemein; vor dem Anlegen im Ziel `Lean Health Timer` nach gleichnamigen Typen suchen. Bei Treffer Name mit Begründung im RED-Bericht ändern.
- **Zeilenbudget.** Zielwert 125 bis 140, Grenze 250. Bei Überschreitung: STOP, Grenze nicht anheben, Rückfrage mit Schätzung.
- **Watch und Widget.** Kompilieren `Meditationstimer iOS` nicht; der Build-Wächter bleibt in der Abschlussprüfung.

## Definition of Done

- [ ] ACs AC-1 bis AC-15 nachgewiesen, im Protokoll `Executed N tests` mit N ≥ 1
- [ ] Vollständige Unit-Suite grün
- [ ] Build grün für iOS (Simulator `iPhone 17 Pro`, iOS 27.2), Watch und Widget
- [ ] Zeilenzählung: Produktiv-Diff ≤ 250 Zeilen, Funktionen ≤ 50 Zeilen, keine bestehende App-Datei geändert
- [ ] Durchlauf im Simulator (Regression) mit Screenshot
- [ ] Adversary-Prüfung: Verdict VERIFIED
- [ ] Elternspec `openspec/specs/features/claude-verbindung-app.md`: Schnitt-2-Zeile „Erledigt“
- [ ] Änderungen am Gerät von Henning: keine, kein Start auf seinen Geräten

## Changelog

- 2026-11-24: Angelegt als Rundenspec für Schnitt 2, Runde 2b (`AccountState` ohne `withSession`, 1:1 aus Loose Ends). Löst Regel 3 der Runde 2a ein (401 bei Anmeldung wird `notAllowed`, 503 wird `retryLater`).
