# Context: feature-57-s2-serviceclient (#57 Schnitt 2)

## Request Summary
Zweiter Schnitt der Claude-Verbindung: der Gesprächspartner zum Dienst (`ServiceClient` mit Transport-Naht),
der Anmeldezustand (`AccountState`), ein Sitzungsspeicher im Arbeitsspeicher (`InMemorySessionStore`) und das
Entitlement Sign in with Apple. Weiterhin nichts in der App verdrahtet (Verdrahtung: Schnitt 4/5).

## Portalstand #56 (vorab geprüft, 2026-11-23)
- #56 offen. Betriebsvorlage henemm/henemm-infra#454 offen („erst bei der Inbetriebnahme übernehmen“).
- Runbook `docs/habits-runbook.md` Schritt 2.1 „App-ID `henemm.Meditationstimer-iOS`: Fähigkeit Sign in with Apple
  einschalten“ ist damit **noch nicht ausgeführt**; kein Beleg für die Fähigkeit im Portal.
- Lokal gibt es kein Provisioning-Profil der App (weder `~/Library/Developer/Xcode/UserData/Provisioning Profiles`
  noch `~/Library/MobileDevice/Provisioning Profiles`), also auch keins mit `com.apple.developer.applesignin`.
- Projekt: `CODE_SIGN_STYLE = Automatic`, Team `XK87E2B3VR`; eine Entitlements-Datei für Debug und Release
  (`Meditationstimer iOS/Meditationstimer iOS.entitlements`, heute nur HealthKit).
- Folge: Für Simulator und Tests ist das Portal unerheblich (Simulator-Apps tragen Entitlements im
  `__entitlements`-Abschnitt, ohne Profilprüfung). Für Gerätebauten braucht das Profil die Fähigkeit; bei automatischer
  Signierung legt Xcode App-IDs/Profile selbst an, Fähigkeiten müssen aber der App-ID zugeordnet sein
  (Apple „Provisioning with managed capabilities“). Fehlt sie, meldet Xcode „Provisioning profile … doesn't include the
  com.apple.developer.applesignin entitlement“ — betrifft Hennings Gerätebauten aus Xcode, nicht die CI.

## Related Files
| Datei | Relevanz |
|-------|----------|
| `Meditationstimer iOS/Claude/SessionStore.swift` | Protokoll `SessionStoring`, `SessionStoreError` (ohne `.injected`) — hier kommt `InMemorySessionStore` dazu |
| `Meditationstimer iOS/Claude/KeychainSessionStore.swift` | Schlüsselbund-Speicher (Schnitt 1); Merkpunkt: `save("")` speichert leer, `load()` → `corruptData` |
| `Meditationstimer iOS/Claude/Nonce.swift` | `Nonce()` mit `raw`/`hashed` — von `AccountState.beginSignIn` gebraucht |
| `Meditationstimer iOS/Claude/ClaudeWiring.swift` | Schalter und `serviceURL` — Basis-URL für `ServiceClient` (Verdrahtung später) |
| `Meditationstimer iOS/Claude/DeviceIdentity.swift` | Geräte-UUID; erst für Abholen (Schnitt 4) gebraucht |
| `Meditationstimer iOS/Meditationstimer iOS.entitlements` | + `com.apple.developer.applesignin` = [Default] |
| `LeanHealthTimerTests/ClaudeVerbindungBausteineTests.swift` | Schnitt-1-Tests, Muster für Attrappen |
| `server/src/auth.ts:70-148` | `/auth/apple` → 200 `{sessionToken}`, 400/401/503; `/auth/logout`, `/auth/delete` → 204/401 |
| `openspec/specs/features/claude-verbindung-app.md` | Elternspec, Schnitt 2 Zeile 49 |

## Vorbild (Loose Ends, nur lesen)
- `~/Developer/loose-ends/LooseEnds/Claude/ServiceClient.swift` (170 Z.): `HTTPTransport`, `URLSessionTransport`
  (ephemeral), `ServiceError`, Routen auth + transcript/orders/device. Für Schnitt 2 nur Auth-Routen übernehmen;
  Abschrift (Schnitt 3) und Lieferungen (Schnitt 4, hier `/app/deliveries/*` statt `/app/orders/*`) kommen später,
  `putDevice`/Push entfällt (kein Push im Konzept).
- `~/Developer/loose-ends/LooseEnds/Claude/AccountState.swift` (171 Z.): `@MainActor @Observable`, Status
  signedOut/signingIn/signedIn/deleting/notAllowed/retryLater, `withSession` (erst Schnitt 4 nötig).
- `~/Developer/loose-ends/LooseEnds/Claude/SessionStore.swift:19-63`: `InMemorySessionStore` mit `Mutex` (iOS 18,
  passt zu Ziel iOS 18.5) und `failNext`.
- Tests: `LooseEndsTests/ServiceClientTests.swift` (318), `AccountStateTests.swift` (444).

## Existing Patterns
- Bausteine in `Meditationstimer iOS/Claude/`, Kommentare deutsch, Fehler tragen nie Token/Nonce.
- Systemnaht per Protokoll + Attrappe (Schnitt 1: `KeychainOperations`); hier `HTTPTransport`.
- Projekt nutzt synchronisierte Ordner: Schnitt 1 kam ohne pbxproj-Änderung aus.

## Dependencies
- Upstream: `Nonce`, `SessionStoring`, Foundation/Observation/OSLog/Synchronization.
- Downstream: noch keine (Abgleich Schnitt 4, Einstellungsseite Schnitt 5).

## Risks & Considerations
- **Zeilengrenze:** Vorbild 1:1 ≈ 300+ Zeilen App-Code (Client ~95 nur Auth, AccountState ~170, InMemory ~45).
  Kürzen durch Weglassen von `withSession` (gehört zu Schnitt 4) und der Nicht-Auth-Routen; Analyse muss die Zahl belegen.
- **Leerer Token** (Merkpunkt Schnitt 1): `AccountState` muss leeres `sessionToken` abweisen — schon im Client
  (`!token.isEmpty` → `invalidResponse`, wie Vorbild) und/oder im Store.
- **Entitlement in Release:** eine Datei für beide Konfigurationen → Fähigkeit auch im Store-Bau (Analyse Zeile 146).
  Gerätebauten aus Xcode brauchen die Fähigkeit im Portal (siehe oben). CI (Ad-hoc, Simulator) prüfen: App startet
  weiter, `otool … __entitlements` = 1.
- **`SessionStoreError.injected`** nur für die Attrappe: entweder Fall ergänzen oder eigenen Testfehler nutzen.
- Logger-Subsystem anpassen (nicht `com.henning.looseends`).

## Analysis

### Type
Feature (#57 Schnitt 2, Übernahme aus Loose Ends, nichts verdrahtet)

### Befunde (2026-11-23)
- Vorbild-API passt 1:1: `SessionStoring` (load/save/clear) und `Nonce` (raw/hashed) gleich; `SessionStoreError.injected` fehlt im Ziel.
- `Mutex` (Synchronization) mit iOS 18.5 und SWIFT_VERSION 5.0: Probe-Typprüfung `swiftc -swift-version 5 -target arm64-apple-ios18.5-simulator` OK.
- Synchronisierte Ordner: neue Dateien in `Meditationstimer iOS/Claude/` und `LeanHealthTimerTests/` ohne pbxproj-Änderung;
  Claude/ gelangt nicht in Watch/Widget (Exception-Sets pbxproj:122-144 inaktiv, nicht anfassen).
- Logger-Subsystem im Repo: `com.henemm.Meditationstimer` (SmartReminderEngine.swift:20) → Kategorie `account`.
- Server-Vertrag `server/src/auth.ts` (Logik :65-141, Routen :146-148): `/auth/apple` POST JSON {identityToken, nonce, code}
  → 200 {sessionToken} | 400 | 401 (leer, ohne Grund) | 503 | 405/413/415. `/auth/logout` Bearer → 204 (auch unbekannter
  Token), ohne Bearer 401. `/auth/delete` Bearer → 204 | 401 (unbekannt/parallel). Alle Ablehnungen leer, no-store.
  Folge: 401 bei Anmeldung = „nicht zugelassen“ in der App (Vorbild `signInStatus` :157 macht genau das); kein Grund unterscheidbar.
- Elternspec nennt `/auth/logout` nicht (nur „Abmelden“); Spec von Schnitt 2 ergänzt das.

### Zeilenbudget (Code-Zeilen ohne Kommentare/Leerzeilen, gemessen)
| Datei | Vorbild gesamt / Code | Schnitt 2 Schätzung (mit knappen deutschen Kommentaren) |
|---|---|---|
| ServiceClient.swift | 170 / 131 | ~85 Code → ~100 |
| AccountState.swift | 171 / 139 | ~127 Code → ~145 |
| InMemorySessionStore | 45 / ~40 | ~45 |
| SessionStore.swift `.injected` | – | +1 |
| **Summe** | | **~290** (Kalibrierfaktor 1,5 aus #51 nicht eingerechnet) |
→ über 250. Nach PO-Regel (#48, Memory „Runde je Schnitt“) wird nicht die Grenze angehoben, sondern geteilt.

### Entscheidung Schnitt (technisch, Claude)
- **Runde 2a (dieser Workflow):** `ServiceClient.swift` (nur Auth-Routen apple/logout/delete; `HTTPTransport`,
  `URLSessionTransport` ephemeral, `ServiceError` ohne `.refused`/`.tooManyRequests`, leerer `sessionToken` → `invalidResponse`),
  `InMemorySessionStore.swift` (App-Ziel, Mutex, `failNext`; für Tests und später den UI-Test-Stand-in von Schnitt 5),
  `SessionStore.swift` + `.injected`. ≈ 150 Zeilen, 3 Dateien.
- **Runde 2b (eigener Workflow, dieselbe Spec):** `AccountState.swift` ohne `withSession` (Schnitt 4). ≈ 145 Zeilen.
  Hängt an 2a (ServiceClient, InMemorySessionStore für Tests).
- **Entitlement Sign in with Apple NICHT in Schnitt 2**, sondern mit der Verdrahtung (Schnitt 4) zusammen mit dem
  Portal-Schritt aus #56. Grund: eine Entitlements-Datei für Debug und Release; ohne Portal-Fähigkeit scheitern Gerätebauten
  aus Xcode/Archive („Provisioning profile doesn't include the com.apple.developer.applesignin entitlement“), ohne dass Code
  es nutzt. CI (ad hoc, Simulator) wäre nicht betroffen. Quellen: Apple „Provisioning with capabilities“
  (developer.apple.com/help/account/reference/provisioning-with-managed-capabilities), Forum thread 811382.
  Elternspec Zeile 49 und Schnitt-4-Zeile in /30-write-spec anpassen.

### Affected Files (Runde 2a)
| File | Change Type | Description |
|------|-------------|-------------|
| Meditationstimer iOS/Claude/ServiceClient.swift | CREATE | Transport-Naht, Auth-Routen, ServiceError |
| Meditationstimer iOS/Claude/InMemorySessionStore.swift | CREATE | Speicher-Attrappe mit failNext |
| Meditationstimer iOS/Claude/SessionStore.swift | MODIFY | + `SessionStoreError.injected` |
| LeanHealthTimerTests/ServiceClientTests.swift | CREATE | Pfade, Körper, Bearer, Statuscodes, leerer Token, Fehler ohne Token |
| LeanHealthTimerTests/InMemorySessionStoreTests (in ServiceClientTests oder eigene Datei) | CREATE | failNext, save/load/clear |

### Scope Assessment
- Runde 2a: 3 App-Dateien, ~+150 LoC App-Code; Tests extra. Risk: LOW (nichts verdrahtet, keine Entitlement-/Plist-/AppStorage-Änderung).

### Technical Approach
Übernahme aus Loose Ends mit Kürzung auf Auth-Routen, Kommentare deutsch und knapp, Fehler tragen nie Token/Nonce/Körper.
Alternative (verworfen): alles in einer Runde mit angehobener Grenze — widerspricht PO-Regel #48. Alternative (verworfen):
Entitlement jetzt eintragen — Nebeneffekt auf Hennings Gerätebauten ohne Nutzen.

### Dependencies
Upstream: `SessionStoring`, Foundation, Synchronization. Downstream: Runde 2b (AccountState), Schnitt 4 (Abgleich).

### Open Questions
- keine PO-Fragen (Schnitt- und Entitlement-Entscheidung sind technisch und folgen bestehenden Regeln).
