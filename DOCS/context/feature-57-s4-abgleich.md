# Context: feature-57-s4-abgleich (#57 Schnitt 4)

## Request Summary
Schnitt 4 von #57: Die App gleicht sich mit dem Dienst ab — Lieferungen abholen, mit dem Annahme-Kern (#51) anwenden, Ergebnis
melden, danach die Abschrift Fassung 1 senden; ausgelöst beim Start und beim Wechsel in den Vordergrund, nur mit Sitzung,
unter Tests stumm. Dazu `AccountState.withSession`, Entitlement Sign in with Apple und zwei Kosmetik-Korrekturen
(Kopfkommentar `TranscriptBuilderTests.swift` „TDD RED“, verirrter Punkt in `AccountState.swift` Zeile 10).

Elternspec: `openspec/specs/features/claude-verbindung-app.md` (Verhalten 3, Schnitt 4). Vorbild: Loose Ends
`~/Developer/loose-ends/LooseEnds/Claude/ClaudeSync.swift` (160 Z.) und `ClaudeSyncTrigger.swift` (178 Z.), Tests
`LooseEndsTests/ClaudeSync*Tests.swift` (nur lesen).

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Claude/ServiceClient.swift` (97 Z.) | Nur Auth-Routen. Neu: `claimDelivery`, `reportResult`, `sendTranscript`; `ServiceError` kennt kein 409/429 (LE: `.refused`, `.tooManyRequests`) |
| `Meditationstimer iOS/Claude/AccountState.swift` (157 Z.) | Kein `withSession`; LE-Vorlage `AccountState.swift:117-126` (9 Z.). `dropSession` existiert. Z. 10 beginnt mit `///.` (Kosmetik) |
| `Meditationstimer iOS/Claude/DeviceIdentity.swift` | `current() throws -> UUID` für Kopf `X-Device` |
| `Meditationstimer iOS/Claude/ClaudeWiring.swift` | `isEnabled(...)`, `serviceURL(...)` — bisher von nichts aufgerufen |
| `Meditationstimer iOS/Claude/KeychainSessionStore.swift`, `InMemorySessionStore.swift` | Sitzungsspeicher App / Tests |
| `Meditationstimer iOS/Models/ClaudeDelivery.swift` | `ClaudeDelivery.read(_:) throws(ClaudeDeliveryError)` (Z. 59), Fehler mit `code`/`reason` |
| `Meditationstimer iOS/Models/ClaudeStore.swift` | Einstieg `ClaudeStore.apply(_:in:lastSnapshotAt:now:center:) -> ClaudeApplyResult` (Z. 115); Log in `claudeState` (max 50) |
| `Meditationstimer iOS/Models/ClaudeApply.swift` | `ClaudeApplyResult { applied, noEffect, rejected(code, reason) }`; Regel 8 `isBlockedByIphone` (Z. 86): `lastSnapshotAt == nil` ⇒ jede von Henning geänderte Programm-/Atemübung gilt als blockiert |
| `Meditationstimer iOS/Models/TranscriptBuilder.swift` | `readCurrent(defaults:) -> TranscriptInput` (mit `unreadable`), `build(...now:) -> Data` |
| `Meditationstimer iOS/Meditationstimer_iOSApp.swift` (260 Z.) | `@main`; `scenePhase` deklariert (Z. 17), aber ungenutzt; `.task`-Muster Z. 81/83; Testerkennung `enable-testing` (Z. 62) |
| `Meditationstimer iOS/Meditationstimer iOS.entitlements` | nur HealthKit |
| `LeanHealthTimerTests/ServiceClientTests.swift` | `actor FakeTransport: HTTPTransport` (Z. 18), Antwortfolgen, zeichnet Requests auf |
| `LeanHealthTimerTests/AccountStateTests.swift` | eigener `private actor Wire: HTTPTransport` |
| `LeanHealthTimerTests/TranscriptBuilderTests.swift` | Kopfkommentar Z. 1-14 spricht von „TDD RED“ (Kosmetik) |
| `server/src/app-routes.ts`, `deliveries.ts`, `transcripts.ts` | Dienstvertrag (unten) |

## Dienstvertrag (server/src, maßgeblich)
- Alle drei Routen: POST, `Authorization: Bearer`, `Content-Type: application/json` Pflicht (sonst 415), ≤ 256 KB (413),
  ohne Konto 401, Antworten ohne Körper bei Ablehnung, `cache-control: no-store`.
- `POST /app/deliveries/claim`: Kopf `X-Device` (UUID, sonst 400); Körper egal (leer erlaubt, Content-Type trotzdem json).
  204 = nichts offen; 200 `{deliveryId, delivery}`. Älteste wartende oder seit 10 min verwaiste Lieferung ⇒ dieselbe Lieferung
  kann zweimal kommen (der Annahme-Kern ist über das Log idempotent).
- `POST /app/deliveries/result`: `X-Device`; Körper `{deliveryId, outcome: "accepted"|"rejected", errors?}`, `errors` nur bei
  rejected, 1–100 × `{code 1–100, path 0–300, message 1–300}`, keine weiteren Schlüssel. 204 ok, 409 = fremd/beantwortet/unbekannt
  (LE: verwerfen und weiter).
- `POST /app/transcript`: Abschrift-JSON, 204 (auch bei älterer), 400 bei ungültig. Kein `X-Device` nötig.
- Kein JSON-Schema für den Ergebnis-Körper in `Contracts/`; Form nur in `app-routes.ts checkResultBody`.

## Existing Patterns
- LE `ClaudeSync`: `@MainActor final class`, `Ending { notSignedIn, busy, done, limitReached, stopped(Stop) }`, `maxOrdersPerPass = 15`,
  Sperre gegen Doppellauf, Geräte-UUID einmal je Durchlauf, jeder Aufruf über `account.withSession`, nur Fallnamen im Log.
- LE `ClaudeSyncTrigger`: Aktionen injiziert (fehlend = stumm), `forApp(account:container:silent:)` → nil ohne Konto,
  stumm unter Tests; hört auf `didBecomeActive` statt `scenePhase`; Senden serialisiert („sendAgain“), Abholsperre, Entprellung.
- LE ruft erst Senden, dann Abholen; **unsere Elternspec verlangt Abholen → Melden → Abschrift** (Abschrift spiegelt dann das Angewendete).
- Projekt: Tests in XCTest, Transport-Attrappen als `actor`; Testerkennung über Startargument `enable-testing`.

## Dependencies
- Upstream: ServiceClient, AccountState, DeviceIdentity, KeychainSessionStore, ClaudeWiring (Schnitt 1/2), ClaudeStore/ClaudeApply (#51),
  TranscriptBuilder (Schnitt 3), Foundation/UIKit-Notification.
- Downstream: Schnitt 5 (Einstellungsseite: letzter Abgleich, Lieferungsliste, Anmelden) liest Zustand aus Abgleich/AccountState.

## Existing Specs
- `openspec/specs/features/claude-verbindung-app.md` (Eltern), `DOCS/specs/features/feature-57-s{1,2,2b,3}-*.md`
- `DOCS/specs/features/feature-51-s2-bausteine-anwenden.md` Z. 44/133: „#57 (Abgleich, besitzt `lastSnapshotAt`)“
- `openspec/specs/integrations/claude-dienst.md`

## Risks & Considerations
1. **`lastSnapshotAt` gibt es nirgends.** Der Dienst liefert ihn nicht (Claim-Antwort ohne Abschrift-Zeit). Ohne ihn lehnt Regel 8
   jede Änderung an einem von Henning geänderten Programm/einer Atemübung ab. Der Abgleich muss ihn besitzen: Zeitpunkt
   (`generatedAt`) der zuletzt erfolgreich (204) gesendeten Abschrift, lokal gespeichert.
2. **Zeilengrenze:** LE-Vorlage allein ~340 Z. (Sync + Trigger) + Routen (~50) + `withSession` (~10) + App-Einhängung. Deutlich
   über 250 ⇒ zwei Runden nötig (Vorschlag: 4a Routen + `withSession` + Abgleich-Ablauf; 4b Auslöser + App-Start + Entitlement).
3. **Entitlement Sign in with Apple:** Portal-Fähigkeit an der App-ID ist laut #56/Runbook 2.1 nicht eingeschaltet (Stand 23.11.).
   Mit Eintrag in der Entitlements-Datei scheitern Gerätebauten aus Xcode, bis das Portal nachzieht. Für den Abgleich selbst nicht
   nötig (die Anmeldung kommt erst mit der Einstellungsseite, Schnitt 5) ⇒ in der Analyse klären, ob es nach Schnitt 5 wandert.
4. **Reihenfolge/Fehler:** Jeder Fehler beendet den Durchlauf still; 401 meldet ab (über `withSession`); 409 beim Melden verwerfen.
   429/409 fehlen in `ServiceError`.
5. **Mapping Ergebnis:** `.applied`/`.noEffect` → `accepted`; `.rejected(code, reason)` → `rejected` mit `errors:[{code, path:"", message:reason}]`;
   unlesbare Lieferung (`ClaudeDeliveryError`) → `rejected` mit deren code/reason; Grenzen (100/300 Zeichen) einhalten.
6. **Abschrift bei unlesbarem Bestand** (`TranscriptInput.unreadable`): nicht senden (sonst sähe Claude eine leere Welt).
7. **Unter Tests stumm:** `enable-testing` darf keinen Netzverkehr auslösen (UI-Tests, Simulator).
8. Issue nennt zusätzlich „kurz nach eigenen Änderungen“ und „gelegentlich im Hintergrund“; Elternspec nur Start + Vordergrund.
   Einfach-Regel: Start + Vordergrund; die anderen beiden als Abweichung festhalten.

## Analysis

### Type
Feature (Schnitt 4 von #57, Elternspec `openspec/specs/features/claude-verbindung-app.md`)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Claude/ServiceClient.swift` | MODIFY | `claimDelivery(token:device:)` (Körper `{}`, `X-Device`, 204 → nil, 200 → `(deliveryId, Data)` per `JSONSerialization`), `reportResult(...)`, `sendTranscript(token:data:)`; ~+35 Z. Kein neuer `ServiceError`-Fall: 409/429 = `.rejected(Int)` |
| `Meditationstimer iOS/Claude/AccountState.swift` | MODIFY | `withSession` (LE `AccountState.swift:117-126`, nutzt vorhandenes `dropSession`), ~+10 Z.; Kosmetik Z. 10 (`///.`) |
| `Meditationstimer iOS/Claude/ClaudeSync.swift` | CREATE | `@MainActor final class ClaudeSync`, Sperre `running`, Ending-Enum (notSignedIn, busy, done, stopped), ≤ 15 Lieferungen, Ergebnis-Abbildung mit Kürzung, Abschrift, `lastSnapshotAt`; ~110 Z. |
| `Meditationstimer iOS/Meditationstimer_iOSApp.swift` | MODIFY | `.task` + `.onChange(of: scenePhase)` → `sync?.run()`; `sync` nur ohne `enable-testing`/XCTest-Host und mit `ClaudeWiring.isEnabled`; ~15 Z. |
| `LeanHealthTimerTests/ClaudeSyncTests.swift` | CREATE | Abgleich mit Transport-Attrappe (zählt nicht zur Zeilengrenze) |
| `LeanHealthTimerTests/TranscriptBuilderTests.swift` | MODIFY | Kosmetik Kopfkommentar „TDD RED“ |

### Scope Assessment
- App-Dateien: 4 (1 neu), Testdateien: 1–2
- Geschätzt: +170–190 Z. App-Code, Risiko MITTEL (erster echter Netzverkehr der App, Annahme-Kern wird erstmals live aufgerufen)
- Rückfall, falls `ClaudeSync` > ~130 Z.: 4a (ServiceClient, withSession, ClaudeSync, unverdrahtet) / 4b (App-Einhängung)

### Technical Approach (Entscheidungen)
1. **Ablauf:** Abholen → Anwenden (`ClaudeStore.apply`, ClaudeStore.swift:115) → Melden, höchstens 15; danach einmal Abschrift.
   Jeder Fehler beendet still; 401 meldet über `withSession` ab; 409 beim Melden verwerfen und weiter; Geräte-UUID einmal je Durchlauf.
2. **Ergebnis-Körper** (`server/src/app-routes.ts` `checkResultBody`): `.applied`/`.noEffect` → `{deliveryId, outcome:"accepted"}`;
   `.rejected(code, reason)` und `ClaudeDeliveryError(code, reason)` → `outcome:"rejected", errors:[{code, path:"", message}]`;
   code ≤ 100, message ≤ 300 Zeichen, beide mindestens 1 (Ersatzwert bei leer). deliveryId aus dem Umschlag.
3. **`lastSnapshotAt`:** eigener UserDefaults-Schlüssel (nicht `claudeState`, um #51-Datei und Decode-Kompatibilität nicht anzufassen).
   Gesetzt erst nach 204 der Abschrift, auf dasselbe `now`, das in `build(now:)` ging (vor `readCurrent` erfasst). Erster Lauf: `nil`.
   **Nicht** „Abschrift zuerst“: das rückte den Wert vor und hebelte Regel 8 (ClaudeApply.swift:86) aus. `nil` blockiert nur Bausteine
   mit `modifiedAt != nil` — konservativ und richtig. Restunschärfe (Dienst kennt die Basis der Lieferung nicht) in der Spec nennen.
4. **Abschrift bei `unreadable`:** nicht senden, `lastSnapshotAt` bleibt.
5. **Stumm unter Tests:** `ClaudeWiring.isEnabled` ist unter `enable-testing` **wahr** (ClaudeWiring.swift:14) → eigener Wächter
   in der App: kein `enable-testing` und kein `XCTestConfigurationFilePath` (Unit-Tests starten die App als Host).
6. **Auslöser = Alternative A:** kein eigener Trigger-Typ (LE `ClaudeSyncTrigger` 178 Z.), sondern `.task` + `scenePhase == .active`
   in der App; die Sperre in `ClaudeSync` fängt Doppelläufe (mehrere Fenster, `.active` nach Systemdialogen). Entprellung/`sendAgain`
   entfallen, weil nur Start und Vordergrund auslösen.
7. **Entitlement Sign in with Apple → Schnitt 5** (Abweichung von Elternspec Schnitt 4): Erst die Einstellungsseite meldet an; der Abgleich
   braucht es nicht. Recherche: Mit automatischer Signatur (Projekt: `CODE_SIGN_STYLE = Automatic`, Team XK87E2B3VR) schaltet Xcode die
   Fähigkeit an der App-ID selbst frei (Apple: developer.apple.com/documentation/xcode/configuring-sign-in-with-apple; Rolle Account Holder/Admin
   nötig, developer.apple.com/help/account/capabilities/about-sign-in-with-apple). Restrisiko Profil-Abgleich (Forum 793244) → gehört dorthin,
   wo die Anmeldung erstmals gebraucht wird.

### Tests (Unit, Transport-Attrappe nach `ServiceClientTests.swift:18`)
Pfad-Reihenfolge claim → result → claim(204) → transcript; 16. claim wird nicht gesendet; 409 verworfen und weiter; 401 meldet ab;
500 beendet still ohne Abschrift; Ergebnis-Körper je Fall inkl. Kürzung; unlesbare Lieferung → rejected; `lastSnapshotAt` erst nach 204,
nicht bei Fehler; `unreadable` → keine Abschrift; ohne Sitzung kein Verkehr; Doppellauf → busy; Anwenden ok + Melden scheitert →
zweiter Durchlauf mit derselben Lieferung bleibt idempotent. Kein UI-Test (keine sichtbare Änderung; Einstellungsseite = Schnitt 5).

### Alternatives (verworfen)
- B: LE-Trigger als eigener Typ (`didBecomeActive`, injizierte Aktionen) — besser isoliert testbar, aber +35–60 Z. und 5. Datei; ohne
  Nutzen, solange nur zwei Auslöser existieren.
- Abschrift vor dem Abholen — siehe Punkt 3, semantisch falsch.

### Abweichungen / Notizen für Spec
- Issue nennt auch „kurz nach eigenen Änderungen“ und „gelegentlich im Hintergrund“; Elternspec (freigegeben) nur Start + Vordergrund → bleibt so.
- Abmelden/Trennen soll `lastSnapshotAt` löschen → Schnitt 5 (Kontowechsel).
- Debug-Bau mit Sitzung spricht mit dem echten Dienst (gewollt).
- Debug-Hooks `uitest-claude-apply` (App Z. 103/110) bleiben unberührt.

### Open Questions
- keine PO-Fragen (alles technisch bzw. durch Elternspec entschieden)
