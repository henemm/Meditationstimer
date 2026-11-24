---
entity_id: feature-57-s4-abgleich
type: feature
created: 2026-11-24
updated: 2026-11-24
status: draft
workflow: feature-57-s4-abgleich
issue: 57
epic: 44
parent: claude-verbindung-app
---

# Schnitt 4: Abgleich mit dem Dienst (#57)

## Approval

- [ ] Approved

Freigabe dieser Schnittspec durch den PO.

## Purpose

Schnitt 4 lässt die App erstmals mit dem Claude-Dienst sprechen: Beim Start und beim Wechsel in den Vordergrund holt sie die wartenden Lieferungen von Claude ab, wendet sie mit dem Annahme-Kern (#51) an, meldet je Lieferung das Ergebnis und sendet danach einmal die Abschrift (Fassung 1, Schnitt 3), die dann das Angewendete spiegelt. Das geschieht nur mit Sitzung, still bei Fehlern und nie unter Tests. Dazu gehören die drei Routen im `ServiceClient`, `AccountState.withSession` (401 meldet ab) und der Zeitpunkt `lastSnapshotAt`, den der Annahme-Kern braucht, um Änderungen an von Henning veränderten Bausteinen abzulehnen.

Sichtbar für Henning: nichts. Es gibt noch keine Anmeldung in der App (Einstellungsseite = Schnitt 5), also hat keine Installation eine Sitzung, und der Abgleich endet mit „nicht angemeldet“, ohne Netzverkehr. Der Wert des Schnitts: Ablauf, Fehlerbehandlung und Ergebnis-Abbildung sind durch Tests festgelegt, bevor die Anmeldung die erste Sitzung erzeugt.

## Source

- Kontext und Analyse: `DOCS/context/feature-57-s4-abgleich.md` (Abschnitt „Analysis“, verbindlich: Dienstvertrag, Technical Approach 1 bis 7, Tests, Abweichungen)
- Elternspec: `openspec/specs/features/claude-verbindung-app.md`, Verhalten 3 (Abgleich) und Schnitt 4
- Dienstvertrag: `server/src/app-routes.ts` (`checkResultBody`), `deliveries.ts`, `transcripts.ts`; `openspec/specs/integrations/claude-dienst.md`
- Vorbild (nur gelesen): Loose Ends `LooseEnds/Claude/ClaudeSync.swift`, `AccountState.swift:117-126` (`withSession`)
- Vorgänger: `DOCS/specs/features/feature-57-s2-serviceclient.md`, `feature-57-s2b-accountstate.md`, `feature-57-s3-abschrift.md`; `DOCS/specs/features/feature-51-s2-bausteine-anwenden.md` („#57 besitzt `lastSnapshotAt`“)

## Scope

App-Code (Grenze 250 Zeilen gilt nur für App-Code; Tests zählen nicht):

| Datei | Änderung | Inhalt | ca. Zeilen |
|---|---|---|---|
| `Meditationstimer iOS/Claude/ServiceClient.swift` | ändern | `claimDelivery(token:device:)`, `reportResult(token:device:body:)`, `sendTranscript(token:data:)` | +35 |
| `Meditationstimer iOS/Claude/AccountState.swift` | ändern | `withSession` (nutzt vorhandenes `dropSession`); Kosmetik Zeile 10 (`///.`) | +10 |
| `Meditationstimer iOS/Claude/ClaudeSync.swift` | neu | `@MainActor final class ClaudeSync`, `Ending`, Ablauf, Ergebnis-Abbildung, `lastSnapshotAt`, Wächter `isSilent` | 105 bis 125 |
| `Meditationstimer iOS/Meditationstimer_iOSApp.swift` | ändern | `ClaudeSync` anlegen, `.task` und `.onChange(of: scenePhase)` rufen `run()` | +15 |

Summe App-Code 165 bis 185 Zeilen (Schätzung der Analyse: +170 bis 190), Funktionen je höchstens 50 Zeilen.

Nicht zum Budget:

| Datei | Änderung |
|---|---|
| `LeanHealthTimerTests/ClaudeSyncTests.swift` | neu, XCTest, `@testable import Lean_Health_Timer`, deutsche `testXyz`-Namen, `@MainActor` |
| `LeanHealthTimerTests/TranscriptBuilderTests.swift` | ändern: Kopfkommentar Zeilen 1 bis 14 spricht von „TDD RED“, wird auf den Ist-Stand gebracht (Kosmetik, kein Testcode) |

Dazu eine Zeile in der Elternspec (Stand Schnitt 4, kein Code). Betroffen sind 6 Dateien (4 App-Code, 2 Tests); die Grenze von 4 bis 5 Dateien wird nur durch den Kosmetik-Kopfkommentar einer Testdatei überschritten, der keine Logik enthält. `Meditationstimer iOS/` und `LeanHealthTimerTests/` sind synchronisierte Gruppen; kein Eingriff in `project.pbxproj`. Watch und Widget bekommen nichts.

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine neue; die Entscheidungen stehen in der Analyse und sind hier festgeschrieben.

- **Reihenfolge Abholen → Anwenden → Melden, danach Abschrift** (Elternspec). Loose Ends sendet zuerst; hier spiegelt die Abschrift das Angewendete.
- **Jeder Fehler beendet den Durchlauf still.** Kein Wiederholen im selben Durchlauf, keine Fehlermeldung an den Nutzer. Der nächste Auslöser (nächster Vordergrund) ist die Wiederholung.
- **409 beim Melden verwerfen:** Der Dienst kennt die Lieferung nicht mehr, hat sie anders beantwortet oder sie gehört nicht zu diesem Gerät. Weitermachen ist richtig; erneutes Melden hülfe nie.
- **Kein neuer `ServiceError`-Fall.** 409 und 429 erscheinen als `.rejected(Int)` (Statuscode steht drin); `ClaudeSync` unterscheidet nur 401 (`unauthorized`) von allem anderen und 409 beim Melden.
- **`lastSnapshotAt` im Abgleich, eigener UserDefaults-Schlüssel** (nicht in `claudeState`, damit Datei und Decode-Kompatibilität aus #51 unberührt bleiben).
- **Auslöser ohne eigenen Typ:** `.task` und `scenePhase == .active` in der App; die Sperre in `ClaudeSync` fängt Doppelläufe.

Alternativen, verworfen:
- **Eigener Trigger-Typ wie Loose Ends (`ClaudeSyncTrigger`, 178 Zeilen):** Injizierte Aktionen, Entprellung und „sendAgain“ sind besser isoliert testbar, kosten aber +35 bis 60 Zeilen und eine fünfte App-Datei. Nutzen erst, wenn es mehr als die zwei Auslöser (Start, Vordergrund) gibt, etwa „nach eigenen Änderungen“ oder Hintergrund. Kippt keine ADR; wird bei Bedarf als eigener Schnitt nachgezogen.
- **Abschrift vor dem Abholen (Reihenfolge wie Loose Ends):** Die Abschrift bildete dann den Stand vor den neuen Lieferungen ab, Claude sähe das Angewendete erst im nächsten Durchlauf. Schlimmer: `lastSnapshotAt` rückte vor die gerade angewendeten Änderungen und hebelte Regel 8 (`ClaudeApply.swift:86`, `isBlockedByIphone`) aus. Semantisch falsch.
- **`lastSnapshotAt` aus der Antwort des Dienstes:** Die Claim-Antwort trägt keinen Abschrift-Zeitpunkt.
- **`lastSnapshotAt` in `claudeState`:** Änderte das Dateiformat aus #51 für einen Wert, der dem Abgleich gehört.
- **Entitlement Sign in with Apple jetzt (Elternspec Schnitt 4):** siehe Abweichungen.

## Abweichungen

1. **Entitlement Sign in with Apple wandert nach Schnitt 5** (Elternspec nennt es für Schnitt 4). Begründung: Der Abgleich braucht es nicht; die Anmeldung erscheint erst mit der Einstellungsseite. Die Fähigkeit an der App-ID ist laut #56 und Runbook 2.1 (Stand 23.11.) im Portal nicht eingeschaltet; ein Eintrag in `Meditationstimer iOS.entitlements` ließe Gerätebauten aus Xcode scheitern, bis das Portal nachzieht. Recherche: Mit automatischer Signatur (Projekt: `CODE_SIGN_STYLE = Automatic`, Team XK87E2B3VR) schaltet Xcode die Fähigkeit an der App-ID selbst frei (developer.apple.com/documentation/xcode/configuring-sign-in-with-apple; nötig ist die Rolle Account Holder oder Admin, developer.apple.com/help/account/capabilities/about-sign-in-with-apple). Restrisiko Profil-Abgleich (Apple-Forum, Thread 793244) gehört dorthin, wo die Anmeldung erstmals gebraucht wird. Die Elternspec wird entsprechend angepasst (Schnitt 5 statt 4).
2. **Auslöser nur Start und Vordergrund.** Das Issue nennt zusätzlich „kurz nach eigenen Änderungen“ und „gelegentlich im Hintergrund“; die freigegebene Elternspec nennt nur Start und Vordergrund. Es bleibt bei der Elternspec (einfach vor vollständig, PO 13.11.2026). Die beiden anderen Auslöser sind nicht verworfen, sondern nicht Teil dieses Schnitts.
3. **`lastSnapshotAt` wird bei Abmelden und Konto löschen nicht gelöscht.** Das gehört zum Kontowechsel und wandert nach Schnitt 5 (dort erstmals auslösbar). Bis dahin gibt es keine Sitzung, also nichts zu löschen.
4. **Restunschärfe `lastSnapshotAt`.** Der Dienst kennt nicht, auf welche Abschrift sich Claude bei einer Lieferung stützte. `lastSnapshotAt` ist der Zeitpunkt der zuletzt erfolgreich gesendeten Abschrift. Hat Henning etwas geändert, nachdem diese Abschrift entstand, und Claude liefert auf Grundlage einer noch älteren Abschrift, gilt die Änderung als „nach der Abschrift“ und wird richtig blockiert; hat Claude dagegen eine neuere Abschrift gesehen als die zuletzt gesendete (nur denkbar, wenn ein Senden scheiterte, aber der Dienst sie doch speicherte), wird zu viel blockiert. Fehlerrichtung ist immer „zu vorsichtig“. Solange `lastSnapshotAt` fehlt (erster Lauf), gilt jede von Henning geänderte Programm- oder Atemübung als blockiert (Regel 8); das ist gewollt.

## Nicht in Scope

- Anmeldung, Einstellungsseite, Anzeige von letztem Abgleich oder Lieferungsliste, Texte DE/EN, Entitlement (Schnitt 5).
- Auslöser „nach eigenen Änderungen“ und „Hintergrund“ (Abweichung 2); Wiederholung innerhalb eines Durchlaufs; Entprellung.
- Löschen von `lastSnapshotAt` bei Abmelden (Abweichung 3).
- Änderungen am Dienst, an `ClaudeStore`, `ClaudeApply`, `ClaudeDelivery`, `TranscriptBuilder`, Schema, Watch, Widget, `project.pbxproj`, Info.plist, Entitlements.
- Die Debug-Haken `uitest-claude-apply` in `Meditationstimer_iOSApp.swift` bleiben unberührt.
- Ein Debug-Bau mit Sitzung spricht mit dem echten Dienst (gewollt); Tests nie.

## Dependencies

| Abhängigkeit | Art | Hinweis |
|---|---|---|
| `ServiceClient`, `HTTPTransport`, `ServiceError` (`unauthorized`, `unavailable`, `rejected(Int)`, `invalidResponse`) | Upstream (2a) | `init(baseURL:transport:)`; Tests mit `actor FakeTransport` nach `ServiceClientTests.swift:18` |
| `AccountState` (`dropSession`, `storedToken`, `status`) | Upstream (2b) | `withSession` kommt neu |
| `DeviceIdentity.current() throws -> UUID` | Upstream (1) | für `X-Device` |
| `KeychainSessionStore`, `InMemorySessionStore` | Upstream (1, 2a) | App / Tests |
| `ClaudeWiring.isEnabled(info:arguments:)`, `serviceURL(info:)` | Upstream (1) | `isEnabled` ist unter `enable-testing` wahr (`ClaudeWiring.swift:14`), daher eigener Wächter |
| `ClaudeDelivery.read(_:) throws(ClaudeDeliveryError)` | Upstream (#51) | Fehler tragen `code` und `reason` |
| `ClaudeStore.apply(_:in:lastSnapshotAt:now:center:) -> ClaudeApplyResult` | Upstream (#51) | `ClaudeStore.swift:115`; Ergebnis `applied`, `noEffect`, `rejected(code, reason)`; Log in `claudeState` |
| `TranscriptBuilder.readCurrent(defaults:) -> TranscriptInput`, `build(...now:) -> Data` | Upstream (3) | `unreadable` |
| Schnitt 5 (Anmeldung, Anzeige, `lastSnapshotAt` löschen, Entitlement) | Downstream | |

## Expected Behavior

- Input: `ClaudeSync.run()` (`async`, `@MainActor`) mit `AccountState`, `ServiceClient`, `UserDefaults`, Geräte-Kennung (Funktion `() throws -> UUID`) und Uhr als Abhängigkeiten (der Annahme-Kern und die Abschrift arbeiten allein auf `UserDefaults`, kein SwiftData), in Tests ersetzbar.
- Output: `Ending`: `notSignedIn` (keine Sitzung, kein Netzverkehr), `busy` (anderer Durchlauf läuft), `done` (Ablauf ordnungsgemäß beendet, mit oder ohne Abschrift), `stopped` (Fehler, still beendet).
- Side effects: Anfragen an den Dienst; Einträge im Log von `claudeState` und Änderungen an Bausteinen durch `ClaudeStore.apply`; Schlüssel `lastSnapshotAt` in `UserDefaults`; bei 401 Abmelden über `withSession`; Logzeilen nur mit Fall- und Typnamen, nie Token oder Körper.

### Ablauf eines Durchlaufs

1. Ohne laufenden Durchlauf, sonst `busy`. Ohne Sitzung `notSignedIn`, ohne Anfrage.
2. Geräte-UUID einmal lesen (`X-Device`).
3. Schleife, höchstens 15 Lieferungen: `POST /app/deliveries/claim` (204 = nichts offen, Schleife endet; 200 = `{deliveryId, delivery}`); Lieferung mit `ClaudeDelivery.read` lesen; Anwenden mit `ClaudeStore.apply` (mit `lastSnapshotAt`); `POST /app/deliveries/result` mit dem Ergebnis-Körper; bei 204 oder 409 weiter.
4. Danach genau einmal die Abschrift: `now` erfassen, `readCurrent`, `build(now:)`, `POST /app/transcript`; bei 204 `lastSnapshotAt = now`.
5. Jeder andere Fehler beendet den Durchlauf still (`stopped`), ohne Abschrift; 401 meldet zuerst über `withSession` ab.

### Regeln

**R1. Reihenfolge und Höchstzahl.** Pfadfolge je Durchlauf: `claim`, `result` (je Lieferung), danach `claim` mit 204, danach einmal `transcript`. Höchstens 15 Lieferungen je Durchlauf; nach der 15. wird kein 16. `claim` gesendet, die Abschrift folgt trotzdem.

**R2. Fehler.** 204 beim Abholen: Schleife endet, Abschrift folgt. 409 beim Melden: verwerfen, nächste Lieferung. 401 bei jeder der drei Routen: `withSession` räumt die Sitzung (`dropSession`), Durchlauf endet, keine weitere Anfrage, keine Abschrift. Alles andere (500, 400, 413, 415, 429, Offline, ungültige Antwort, Abbruch, Fehler beim Lesen der Geräte-UUID): Durchlauf endet still, keine Abschrift, `lastSnapshotAt` unverändert.

**R3. Ergebnis-Körper** (Form nur in `server/src/app-routes.ts checkResultBody`; keine weiteren Schlüssel). `ClaudeApplyResult.applied` und `.noEffect` ergeben `{deliveryId, outcome: "accepted"}`. `.rejected(code, reason)` und eine nicht lesbare Lieferung (`ClaudeDeliveryError` mit `code`, `reason`) ergeben `{deliveryId, outcome: "rejected", errors: [{code, path: "", message}]}` mit genau einem Fehler. `code` und `message` sind Texte (der Dienst prüft `sizedText`: Länge in UTF-16-Einheiten wie JavaScript `length`). `code` wird auf höchstens 100, `message` auf höchstens 300 UTF-16-Einheiten gekürzt, nur an Zeichengrenzen (nie ein halbes Surrogatpaar oder ein zerteiltes Emoji); ist einer leer, steht ein fester, nicht leerer Ersatzwert (`code`: `unknown`, `message`: `no reason given`). `path` ist immer `""`. `deliveryId` kommt aus dem Umschlag der Antwort, auch bei unlesbarer Lieferung.

**R4. `X-Device`.** Die Geräte-UUID wird je Durchlauf einmal gelesen und trägt `claim` und `result`; `transcript` braucht sie nicht.

**R5. `lastSnapshotAt`.** Eigener `UserDefaults`-Schlüssel (nicht `claudeState`). Erster Lauf: `nil`. Wird erst nach 204 der Abschrift gesetzt, und zwar auf dasselbe `now`, das vor `readCurrent` erfasst wurde und in `build(now:)` ging. Bei jedem Fehler (R2) und bei keiner Abschrift (R6) bleibt er unverändert. Jeder `ClaudeStore.apply`-Aufruf bekommt den bei Durchlaufbeginn gelesenen Wert; er ändert sich im Durchlauf nicht.

**R6. Unlesbarer Bestand.** Ist `TranscriptInput.unreadable` wahr, wird keine Abschrift gesendet (sonst sähe Claude eine leere Welt); der Durchlauf endet `done`, `lastSnapshotAt` bleibt.

**R7. `withSession`.** Wie Loose Ends (`AccountState.swift:117-126`): führt eine Aktion mit dem gespeicherten Token aus; ohne Token oder bei `signedOut` keine Aktion; bei `ServiceError.unauthorized` wird `dropSession` mit genau diesem Token aufgerufen (löscht keine neuere Sitzung) und der Fehler weitergereicht oder in `stopped` übersetzt.

**R8. `ServiceClient`.** `claimDelivery` sendet POST, `Authorization: Bearer`, `Content-Type: application/json`, `X-Device`, Körper `{}`; 204 liefert `nil`, 200 liefert `(deliveryId, delivery als Data)` (Lieferung roh per `JSONSerialization`, nicht dekodiert). `reportResult` sendet den Körper aus R3, `X-Device`; 204 ist Erfolg, 409 wird als `.rejected(409)` geworfen. `sendTranscript` sendet die Bytes von `build` mit `Content-Type: application/json`; 204 ist Erfolg. 401 wird `.unauthorized`, 503 `.unavailable`, sonstige Statuscodes `.rejected(Int)`, unlesbare 200 `.invalidResponse`.

**R9. Auslöser.** Die App legt `ClaudeSync` nur an, wenn `ClaudeWiring.isEnabled` wahr ist und weder das Startargument `enable-testing` noch die Umgebungsvariable `XCTestConfigurationFilePath` gesetzt ist (Unit-Tests starten die App als Host). Ausgelöst wird in `.task` beim Start und bei `scenePhase == .active`. Die Sperre in `ClaudeSync` (R10) fängt Doppelläufe.

**R10. Sperre und Idempotenz.** Ein zweiter `run()` während eines laufenden Durchlaufs endet sofort mit `busy` und sendet nichts. Kam eine Lieferung an, wurde angewendet, aber das Melden scheiterte, liefert der Dienst dieselbe Lieferung beim nächsten Durchlauf erneut (er wiederholt Lieferungen, die seit 10 Minuten unbeantwortet sind); der Annahme-Kern ist über das Log idempotent, das Ergebnis bleibt dasselbe, der Zustand wird nicht doppelt verändert.

**R11. Kosmetik.** `AccountState.swift` Zeile 10: `///.` wird zu einem gültigen Kommentar. `TranscriptBuilderTests.swift`: Kopfkommentar nennt keinen RED-Stand mehr, sondern den Ist-Stand.

## Acceptance Criteria

„Unit“ = `LeanHealthTimerTests/ClaudeSyncTests.swift`. Hilfsmittel: eine Transport-Attrappe als `actor` nach `ServiceClientTests.swift:18` (Antwortfolgen je Pfad, zeichnet jede Anfrage auf: Pfad, Köpfe, Körper), `InMemorySessionStore` mit Token, eine isolierte `UserDefaults`-Suite (UUID), eine zählende Geräte-Kennung, eine Uhr der Attrappe. Der Test, der die Abschrift prüft, vergleicht mit `TranscriptBuilder.build` desselben Bestands und desselben `now`.

- **AC-1 (Unit): Reihenfolge.** Given zwei wartende Lieferungen (claim 200, 200, 204), When `run()`, Then lautet die aufgezeichnete Pfadfolge `claim, result, claim, result, claim, transcript`, `Ending == .done`, jedes `result` trägt die `deliveryId` der vorangehenden `claim`-Antwort, und die Lieferungen sind im `claudeState`-Log verzeichnet, bevor die Abschrift gebaut wird (Abschrift enthält beide Lieferergebnisse). Test: `testAblaufReihenfolgeClaimResultClaimTranscript`.
- **AC-2 (Unit): Höchstens 15 Lieferungen.** Given der Dienst liefert unbegrenzt (immer 200 mit neuer `deliveryId`), When `run()`, Then genau 15 `claim` und 15 `result`, kein 16. `claim`, danach genau ein `transcript`, `Ending == .done`. Test: `testHoechstens15LieferungenDanachAbschrift`.
- **AC-3 (Unit): 204 beim Abholen beendet die Schleife.** Given erste `claim`-Antwort 204, When `run()`, Then die Pfadfolge ist `claim, transcript`, kein `result`, `Ending == .done`. Test: `testNichtsOffenBeendetSchleifeUndSendetAbschrift`.
- **AC-4 (Unit): 409 beim Melden wird verworfen.** Given zwei Lieferungen, die erste `result`-Antwort ist 409, When `run()`, Then folgt trotzdem `claim` (zweite Lieferung), `result` (204) und am Ende `transcript`; `Ending == .done`; kein erneutes Melden der ersten Lieferung. Test: `testKonflikt409BeimMeldenWirdVerworfen`.
- **AC-5 (Unit): 401 meldet über `withSession` ab.** Given 401 bei `claim` (Fall a), bei `result` (Fall b) und bei `transcript` (Fall c), When `run()`, Then danach `store.token == nil`, `account.status == .signedOut`, keine weitere Anfrage nach der 401, im Fall a und b keine Abschrift, `Ending == .stopped`. Given der Speicher hält bei der 401 inzwischen einen anderen Token „T2“, Then bleibt „T2“ erhalten (`dropSession`-Regel). Tests: `testUnauthorizedMeldetAbUeberWithSession` (a bis c), `testVeraltete401LoeschtKeineNeuereSitzung`.
- **AC-6 (Unit): Sonstiger Fehler beendet still ohne Abschrift.** Given 500 bei `claim`, 500 bei `result`, 400 bei `transcript`, Offline (`URLError`) und `CancellationError`, When `run()`, Then endet der Durchlauf mit `.stopped`, ohne Wiederholung (genau die Anfragen bis zum Fehler), ohne Abschrift (außer beim Fehler der Abschrift selbst), der Sitzungsspeicher bleibt unverändert (`store.token` gleich, `status == .signedIn`), `lastSnapshotAt` unverändert. Test: `testSonstigerFehlerBeendetStillOhneAbschrift`.
- **AC-7 (Unit): Ergebnis-Körper `accepted`.** Given Lieferungen, die `applied` und `noEffect` ergeben, Then ist der Körper je `result` genau `{deliveryId, outcome: "accepted"}` (Schlüsselmenge genau `deliveryId`, `outcome`; kein `errors`). Test: `testErgebnisKoerperAcceptedFuerAppliedUndNoEffect`.
- **AC-8 (Unit): Ergebnis-Körper `rejected`.** Given (a) eine Lieferung, die der Annahme-Kern mit `.rejected(code, reason)` ablehnt, (b) eine Lieferung, deren Umschlag nicht lesbar ist (`ClaudeDeliveryError`), Then ist der Körper `{deliveryId, outcome: "rejected", errors: [{code, path: "", message}]}` mit genau einem Fehler, `code` und `message` aus Ablehnung beziehungsweise Fehler, Schlüsselmenge des Fehlers genau `code`, `path`, `message`; `deliveryId` stammt im Fall (b) aus dem Umschlag der Antwort. Test: `testErgebnisKoerperRejectedMitFehlerliste`.
- **AC-9 (Unit): Grenzen des Fehlers.** Given `code` mit 100 und 101 ASCII-Zeichen, Then stehen 100 und 100 UTF-16-Einheiten im Körper; Given `code` leer, Then steht `unknown`. Given `message` mit 300 und 301 ASCII-Zeichen, Then 300 und 300; Given `message` aus 299 ASCII-Zeichen plus einem Emoji außerhalb der Grundebene (2 UTF-16-Einheiten), Then ist die Meldung höchstens 300 UTF-16-Einheiten lang, endet nicht mit einem halben Surrogatpaar und ist gültiges UTF-8-JSON; Given `message` leer, Then steht `no reason given`; Given sehr lange Meldung, Then bleibt der Körper unter 256 KB. Geprüft über die reine Funktion `ClaudeSync.resultBody(deliveryId:result:)`. Test: `testErgebnisKoerperGrenzenKlemmenKuerzenErsatzwert`.
- **AC-10 (Unit): `X-Device` einmal je Durchlauf.** Given zwei Lieferungen, When `run()`, Then tragen alle `claim`- und `result`-Anfragen denselben `X-Device`-Wert (UUID, gleich `DeviceIdentity.current()`), und `DeviceIdentity.current()` wird je Durchlauf einmal gelesen (Zähler in der Attrappe oder Zählung der Schlüsselbund-Zugriffe); ein zweiter Durchlauf liest erneut. Given Lesefehler der Geräte-UUID, Then `.stopped` ohne Anfrage. Test: `testGeraeteKennungEinmalJeDurchlauf`.
- **AC-11 (Unit): `lastSnapshotAt` nach 204 der Abschrift.** Given erster Lauf (`nil`) und Abschrift 204, Then wird der eigene Schlüssel auf genau das `now` gesetzt, das in `generatedAt` der gesendeten Abschrift steht (auf die Sekunde, ISO-8601) und das vor `readCurrent` erfasst wurde (Uhr der Attrappe liefert bei jedem Aufruf einen späteren Wert; verwendet wird der erste); der Wert steht nicht in `claudeState`. Given Abschrift 400, 500 oder Offline, Then bleibt der Schlüssel unverändert (leer beim ersten Lauf, alter Wert bei späterem Lauf). Test: `testLastSnapshotAtErstNachAbschrift204Gesetzt`, `testLastSnapshotAtBeiFehlerUnveraendert`.
- **AC-12 (Unit): `lastSnapshotAt` geht an `ClaudeStore.apply`.** Given ein Programm mit `modifiedAt` (von Henning geändert) und eine Lieferung, die es ändern will, Then lehnt der Annahme-Kern im ersten Lauf (`lastSnapshotAt == nil`) ab (`rejected`), und nach einem Durchlauf mit Abschrift 204 und `lastSnapshotAt` später als `modifiedAt` nimmt er dieselbe Änderung im nächsten Durchlauf an. Der Wert wird je Durchlauf einmal gelesen. Test: `testLastSnapshotAtWirdAnApplyUebergeben`.
- **AC-13 (Unit): Unlesbarer Bestand, keine Abschrift.** Given `claudeState` mit Müllbytes (`unreadable == true`), When `run()`, Then wird kein `transcript` gesendet, `lastSnapshotAt` bleibt unverändert, der Durchlauf endet `.done`. Test: `testUnlesbarerBestandSendetKeineAbschrift`.
- **AC-14 (Unit): Ohne Sitzung kein Netzverkehr.** Given leerer Sitzungsspeicher oder Lesefehler (`failNext(load: true)`), When `run()`, Then `Ending == .notSignedIn`, null Anfragen, `lastSnapshotAt` unverändert. Test: `testOhneSitzungKeinNetzverkehr`.
- **AC-15 (Unit): Doppellauf.** Given ein laufender Durchlauf (Haken in der ersten Antwort ruft `run()` erneut), Then liefert der zweite `.busy` und sendet nichts; der erste endet `.done`; danach ist ein neuer Durchlauf wieder möglich. Test: `testDoppellaufLiefertBusy`.
- **AC-16 (Unit): Idempotenz bei gleicher Lieferung.** Given eine Lieferung wird angewendet, `result` scheitert mit 500 (`.stopped`), und der Dienst liefert im zweiten Durchlauf dieselbe Lieferung erneut, Then ändert der zweite Durchlauf den Bestand nicht ein zweites Mal (Bausteine und Log unverändert, Log ohne doppelten Eintrag), meldet dasselbe Ergebnis (gleicher Körper) und schließt mit Abschrift. Test: `testZweiterDurchlaufMitGleicherLieferungIstIdempotent`.
- **AC-17 (Unit): `withSession`.** Given angemeldet, Then bekommt die Aktion den Token; Given abgemeldet oder Lesefehler, Then läuft die Aktion nicht; Given 401 aus der Aktion, Then `store.token == nil` und `status == .signedOut` (veraltete 401 löscht keine neuere Sitzung, vgl. AC-5); Given anderer Fehler, Then Sitzung unverändert. Test: `testWithSessionTokenOhneSitzungUnd401`.
- **AC-18 (Unit): `ServiceClient`-Routen.** Given die Attrappe, Then senden `claimDelivery`, `reportResult`, `sendTranscript` je POST an `/app/deliveries/claim`, `/app/deliveries/result`, `/app/transcript` mit `Authorization: Bearer <Token>` und `Content-Type: application/json`; `claim` und `result` mit `X-Device` (UUID-Schreibweise), `claim` mit Körper `{}`; `claimDelivery` liefert bei 204 `nil` und bei 200 `(deliveryId, delivery-Bytes)`; 401, 503, 409, 500, unlesbare 200 ergeben `unauthorized`, `unavailable`, `rejected(409)`, `rejected(500)`, `invalidResponse`; kein Fehler enthält Token oder Körper. Test: `testServiceClientLieferungsRouten`.
- **AC-19 (Unit): Wächter und Auslöser.** Given die Funktion `ClaudeSync.isSilent(arguments:environment:)`, Then ist sie wahr bei Startargument `enable-testing` und bei gesetztem `XCTestConfigurationFilePath`, falsch sonst; Given die App im Test-Host (Unit-Suite läuft), Then löst der Start keinen Verkehr aus (die Attrappen-Zähler der App-Instanz bleiben bei 0; geprüft über die Wächterfunktion, nicht über echtes Netz). Test: `testWaechterIstStummUnterTests`.
- **AC-20 (jede Runde): Umfang, Verdrahtung, Build.** Given der Diff des Schnitts, Then enthält er genau: `ServiceClient.swift`, `AccountState.swift`, `ClaudeSync.swift` (neu), `Meditationstimer_iOSApp.swift`, `ClaudeSyncTests.swift` (neu), `TranscriptBuilderTests.swift` (nur Kopfkommentar), die Zeile in der Elternspec sowie die Workflow-Dokumente dieses Schnitts; keine weitere bestehende App-Datei ist geändert (insbesondere nicht `ClaudeStore.swift`, `ClaudeApply.swift`, `TranscriptBuilder.swift`, Entitlements, `project.pbxproj`, Info.plist); `Meditationstimer_iOSApp.swift` unterscheidet sich nur um die Einhängung (kein Eingriff in die Haken `uitest-claude-apply`); das Entitlement Sign in with Apple ist nicht eingetragen; iOS, Watch und Widget bauen; Produktiv-Diff höchstens 250 Zeilen (Zielwert 165 bis 185), keine Funktion über 50 Zeilen; die bestehende Unit-Suite und die UI-Suite bleiben grün; im Protokoll steht `Executed N tests` mit N ≥ 1. Nachweis, je als Befehl mit Ausgabe im Validierungsbericht: (1) `git diff --name-only origin/main...HEAD` gleich der Liste; (2) `git diff --numstat origin/main...HEAD -- "Meditationstimer iOS"` ≤ 250; (3) Build iOS, Watch, Widget; (4) Unit-Suite; (5) UI-Suite (Regression, unter `enable-testing` darf kein Abgleich laufen).

## Tests

Neue Datei `LeanHealthTimerTests/ClaudeSyncTests.swift` (Klasse `ClaudeSyncTests`, `@MainActor`, AC-1 bis AC-19; Testnamen stehen bei den Kriterien). Eigene Transport-Attrappe als `actor` (nicht `FakeTransport` aus `ServiceClientTests.swift` importieren, damit die Testdateien unabhängig bleiben), Antworten nach Pfad. Der Annahme-Kern läuft echt (isolierte `UserDefaults`-Suite), nicht gespielt; nur das Netz ist ersetzt. Dadurch prüft AC-1 und AC-12, dass die Kette Abholen → Anwenden → Melden → Abschrift wirklich schließt und der Annahme-Kern Material mit dem Wert aus `lastSnapshotAt` bekommt (Lehre aus #136: Tests, die ihren Ausgangszustand von Hand setzen, prüfen den halben Weg).

Kein UI-Test in diesem Schnitt, und das ist Absicht: Es ändert sich nichts Sichtbares. Kein Bildschirm, keine Kennung, kein Ablauf; ohne Anmeldung (erst Schnitt 5) hat keine Installation eine Sitzung, und unter `enable-testing` ist der Abgleich stumm. Der erste UI-Test der Verbindung entsteht in Schnitt 5 mit der Einstellungsseite.

Durchlauf-Nachweis („App benutzen“): Start der App im Simulator `iPhone 17 Pro` (iOS 27.2) ohne Veränderung. Zwei Läufe: (1) mit `enable-testing`: Tabs und Einstellungen öffnen, in den Hintergrund und zurück wechseln, kein Netzverkehr, derselbe Stand wie zuvor; (2) ohne `enable-testing` (Debug-Bau, ohne Sitzung): App starten und in den Vordergrund holen, Tabs und Einstellungen öffnen; erwartet: kein Absturz, kein Systemdialog, Programme und Atemübungen unverändert; im Protokoll des Simulators erscheint, dass der Abgleich ohne Sitzung endet (Fallname `notSignedIn`), und es gibt keine Anfrage an den Dienst. Screenshot der Einstellungen als Beleg. Kein Gerät von Henning.

## Test Plan

- [ ] Unit (`ClaudeSyncTests.swift`): AC-1 bis AC-19. GIVEN Transport-Attrappe, `InMemorySessionStore`, isolierte Suite WHEN `run()` THEN Pfadfolge, Körper, Köpfe, Sitzungsspeicher, `lastSnapshotAt` und Bestand wie beschrieben
- [ ] RED-Beleg: Die Tests scheitern zuerst am Übersetzungsfehler „cannot find `ClaudeSync`“ beziehungsweise „value of type `ServiceClient` has no member `claimDelivery`“; danach legt der Developer die Implementierung an
- [ ] Bestand: vollständige Unit-Suite grün (Aufruf wie in `CLAUDE.md`, Nachweis nur mit `Executed N tests`, N ≥ 1)
- [ ] UI-Suite (Regression): `./Scripts/run-uitests.sh` grün; Abgleich unter `enable-testing` stumm
- [ ] Build grün für iOS, Watch und Widget
- [ ] Diff-Prüfung und Zeilenzählung AC-20: Produktiv-Diff höchstens 250, Zielwert 165 bis 185
- [ ] Durchlauf im Simulator: beide Läufe wie oben, Screenshot
- [ ] Kein neuer UI-Test (begründet oben)

## Risiken

- **Zeilenbudget.** Zielwert 165 bis 185, Grenze 250; die LE-Vorlage allein hat 340 Zeilen (Sync plus Trigger). Rückfall, falls `ClaudeSync` über etwa 130 Zeilen wächst oder das Gesamtbudget eng wird: Schnitt 4a (`ServiceClient`-Routen, `withSession`, `ClaudeSync`, unverdrahtet, mit allen Unit-Tests) und Schnitt 4b (App-Einhängung `.task` und `scenePhase`, Wächter, Elternspec-Zeile). Bei Überschreitung: STOP, Grenze nicht anheben, Rückfrage mit Schätzung.
- **Erster echter Netzverkehr der App.** Der Annahme-Kern wird erstmals live aufgerufen. Gegenmaßnahmen: Abgleich ohne Sitzung inaktiv (kein Nutzer hat eine bis Schnitt 5), stumm unter Tests, echter Annahme-Kern in den Unit-Tests, Fehler beenden still.
- **Wechselnde Kennungen der Vorgaben (aus Schnitt 3, R14).** Nie gespeicherte Programme und Atemübungen bekommen je App-Start neue UUIDs, ihre `own.<uuid>`-Kennung in der Abschrift ist daher nur innerhalb eines Laufs stabil; Claude sähe bei jedem Abgleich scheinbar neue Bausteine. Schnitt 3 überließ die Lösung (zum Beispiel einmal speichern) diesem Schnitt. Dieser Schnitt löst es nicht: `readCurrent` ist absichtlich ohne Seiteneffekt, ein Speichern der Vorgaben im Abgleich wäre eine Verhaltensänderung außerhalb des Tickets, und ohne Anmeldung (Schnitt 5) sendet kein Nutzer eine Abschrift. Die Lösung ist vor Schnitt 5 nötig und wird als eigenes Issue #117 geführt (Entscheidung des Tech Leads, kein PO-Thema).
- **`ClaudeWiring.isEnabled` ist unter `enable-testing` wahr.** Deshalb der eigene Wächter (R9, AC-19); Test-Host-Start (Unit-Tests) wird über `XCTestConfigurationFilePath` erkannt.
- **Abschrift über 256 KiB.** Der Dienst antwortet 413; das ist ein sonstiger Fehler, der Durchlauf endet still, `lastSnapshotAt` bleibt. Praktisch nur mit mehreren hundert langen Claude-Übungen erreichbar.
- **`lastSnapshotAt`-Unschärfe und fehlendes Löschen.** Abweichungen 3 und 4; Fehlerrichtung ist „zu vorsichtig“.
- **`withSession` und Nebenläufigkeit.** `@MainActor`, Aktion `async`; die 401 während einer laufenden Aktion darf keine neuere Sitzung löschen (AC-5, AC-17). Projekt mit `SWIFT_VERSION 5.0` und Xcode 27; Haken-Closures der Attrappen brauchen `@MainActor @Sendable`.
- **Watch und Widget.** Kompilieren `Meditationstimer iOS` nicht; der Build-Wächter bleibt in der Abschlussprüfung.

## Definition of Done

- [ ] ACs AC-1 bis AC-20 nachgewiesen, im Protokoll `Executed N tests` mit N ≥ 1
- [ ] Vollständige Unit-Suite und UI-Suite grün
- [ ] Build grün für iOS (Simulator `iPhone 17 Pro`, iOS 27.2), Watch und Widget
- [ ] Zeilenzählung: Produktiv-Diff ≤ 250 Zeilen, Funktionen ≤ 50 Zeilen, keine weitere bestehende App-Datei geändert
- [ ] Durchlauf im Simulator (beide Läufe) mit Screenshot
- [ ] Adversary-Prüfung: Verdict VERIFIED
- [ ] Elternspec `openspec/specs/features/claude-verbindung-app.md`: Schnitt-4-Zeile „Erledigt“, Entitlement bei Schnitt 5
- [x] Folge-Issue für wechselnde Kennungen der Vorgaben angelegt (#117)
- [ ] Änderungen am Gerät von Henning: keine, kein Start auf seinen Geräten

## Changelog

- 2026-11-24: Angelegt als Schnittspec für #57 Schnitt 4 (Abgleich). Entscheidungen aus der Analyse übernommen: Reihenfolge Abholen → Anwenden → Melden → Abschrift, `lastSnapshotAt` im Abgleich, Auslöser ohne eigenen Typ, stumm unter Tests. Abweichungen von Elternspec und Issue festgehalten (Entitlement nach Schnitt 5, nur Start und Vordergrund, `lastSnapshotAt` löschen nach Schnitt 5).
- 2026-11-24 (Phase TDD RED): Korrektur nach Abgleich mit `server/src/app-routes.ts:96-102`: `code` ist ein Text (1 bis 100), keine Zahl; Längen zählt der Dienst in UTF-16-Einheiten, nicht in Unicode-Skalaren (sonst lehnte er Meldungen mit Emoji mit 400 ab und die Lieferung bliebe hängen). R3 und AC-9 angepasst; SwiftData aus „Expected Behavior“ gestrichen (Annahme-Kern und Abschrift arbeiten auf `UserDefaults`).
