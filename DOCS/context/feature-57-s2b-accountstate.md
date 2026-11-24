# Context: feature-57-s2b-accountstate

## Request Summary
#57 Schnitt 2, Runde 2b: den Anmeldezustand der Claude-Verbindung (`AccountState`) aus Loose Ends übernehmen, ohne
`withSession` (kommt mit Schnitt 4). Nichts wird verdrahtet; kein Bildschirm, kein Netzwerkverkehr ändert sich.

## Related Files
| File | Relevance |
|------|-----------|
| `openspec/specs/features/claude-verbindung-app.md` | Elternspec, Schnitt 2 (Runde 2b) und Schnitt 4 (`withSession`) |
| `DOCS/specs/features/feature-57-s2-serviceclient.md` | Runde 2a, Regel 3: Übersetzung 401/503 in einen Anmeldestatus macht 2b |
| `DOCS/context/feature-57-s2-serviceclient.md` | Schnittentscheidung 2a/2b, Zeilenbudget (~145 Z.) |
| `Meditationstimer iOS/Claude/ServiceClient.swift` | Upstream: `signIn`, `logout`, `deleteAccount`, `ServiceError` (unauthorized, unavailable, rejected, invalidResponse), `HTTPTransport` |
| `Meditationstimer iOS/Claude/SessionStore.swift` | Upstream: `SessionStoring` (load/save/clear), `SessionStoreError.injected` |
| `Meditationstimer iOS/Claude/InMemorySessionStore.swift` | Tests: Speicher mit `failNext(load:save:clear:)` |
| `Meditationstimer iOS/Claude/Nonce.swift` | Upstream: `Nonce()` mit `raw`/`hashed` |
| `LeanHealthTimerTests/ServiceClientTests.swift` | Testmuster im Projekt: XCTest, `@testable import Lean_Health_Timer`, `FakeTransport` |
| **neu** `Meditationstimer iOS/Claude/AccountState.swift` | einzige App-Datei der Runde |
| **neu** `LeanHealthTimerTests/AccountStateTests.swift` | Tests der Runde |

## Vorbild (Loose Ends, nur lesen)
- `~/Developer/loose-ends/LooseEnds/Claude/AccountState.swift` (171 Z.): `@MainActor @Observable`, `Status`
  (signedOut, signingIn, signedIn, deleting, notAllowed, retryLater), `Problem.retryLater`, `AccountError.notPossibleNow`;
  `beginSignIn` → gehashte Nonce, `completeSignIn`, `cancelSignIn`, `signOut` (lokal zuerst, Dienst-Antwort ändert
  nichts), `deleteAccount` (401 räumt nur denselben Token), `withSession` (entfällt hier), `dropSession`, `clearStore`,
  `storedToken`, `signInStatus`, `caseName`.
- `~/Developer/loose-ends/LooseEndsTests/AccountStateTests.swift` (444 Z., Swift Testing): Fälle Start mit/ohne Token,
  erlaubte Zustände für `beginSignIn`, rohe Nonce im Körper zum Hash, Nonce einmalig, Speichern/Speicherfehler,
  Fehlerabbildung, `cancelSignIn`, `signOut` lokal zuerst, Löschen und Fehlerabbildung, veraltete 401, Doppelaufrufe,
  keine Geheimnisse im Zustand; `session:`-Fälle (Z. 316 ff.) entfallen mit `withSession`.

## Existing Patterns
- Claude-Bausteine liegen in `Meditationstimer iOS/Claude/`; das Projekt nutzt synchronisierte Ordner
  (`PBXFileSystemSynchronizedRootGroup`), neue Dateien brauchen keinen Eintrag in `project.pbxproj` (2a: genauso).
- Kommentare deutsch und knapp; Logger-Subsystem im Projekt `com.henemm.Meditationstimer` (nicht `com.henning.looseends`).
- Unit-Tests im Projekt: XCTest (nicht Swift Testing), Testnamen deutsch `testXyz`.
- Deployment-Ziel iOS 18.5: `@Observable` und `Mutex` verfügbar.

## Dependencies
- Upstream: `ServiceClient`, `ServiceError`, `SessionStoring`, `Nonce`, Foundation, Observation, OSLog.
- Downstream: Schnitt 4 (`withSession`, Abgleich), Schnitt 5 (Einstellungsseite liest `status`, `lastProblem`).

## Risks & Considerations
- **Toter Code bis Schnitt 4/5:** bewusst so in der Elternspec geschnitten (2a ebenfalls unverdrahtet).
- **`dropSession` bleibt** trotz fehlendem `withSession`: `deleteAccount` braucht es bei 401 (veraltete 401 darf eine
  neuere Sitzung nicht löschen).
- **Geheimnisse:** weder Zustand, Fehler noch Logzeile nennen Token oder Nonce; Logs nur Fall-/Typnamen, `privacy: .public`
  nur für diese.
- **Kein Entitlement nötig:** `AccountState` nutzt kein `AuthenticationServices`; der Apple-Dialog kommt mit Schnitt 5,
  das Entitlement mit Schnitt 4.
- **Nebenläufigkeit:** `@MainActor`; `signingIn`/`deleting` sind zugleich die Sperre gegen Doppelaufrufe.

## Analysis

### Type
Feature (#57 Schnitt 2 Runde 2b, Übernahme aus Loose Ends, nichts verdrahtet). Summe 2 → Kontext und Analyse in einem Durchgang.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Claude/AccountState.swift` | CREATE | Vorbild ohne `withSession`, Logger-Subsystem angepasst, Kommentare deutsch; ≈ 125–140 Zeilen |
| `LeanHealthTimerTests/AccountStateTests.swift` | CREATE | Vorbild-Fälle ohne `session:`-Gruppe, nach XCTest übertragen; zählt nicht zur 250er-Grenze |
| `openspec/specs/features/claude-verbindung-app.md` | MODIFY | Schnitt-2-Zeile „Erledigt“ nach Abschluss (Doku) |

### Scope Assessment
- App-Code: 1 Datei, ≈ 135 Zeilen (Grenze 250).
- Risk Level: LOW (unverdrahtet, keine Berechtigung, keine AppStorage-Schlüssel, kein Netzwerk).

### Technical Approach
1:1-Übernahme der Zustandsmaschine; einzige inhaltliche Kürzung `withSession`. Die 2a-Regel 3 wird hier eingelöst:
401 bei der Anmeldung → `notAllowed`, 503 → `retryLater`, Abbruch → `signedOut`, alles andere (`rejected`,
`invalidResponse`, Transportfehler) → `signedOut` mit Logzeile. `signOut` räumt lokal zuerst; die Antwort des Dienstes
ändert den Zustand nicht. `deleteAccount` nur aus `signedIn`; Erfolg → abgemeldet, 401 → `dropSession`, Abbruch →
bleibt angemeldet ohne Problem, sonst angemeldet mit `lastProblem = .retryLater`.

### Alternativen
- **2b mit Schnitt 5 zusammenlegen** (Zustand erst bauen, wenn die Seite ihn anzeigt): kein unverdrahteter Code, aber
  Schnitt 5 würde mit Seite, Texten und UI-Test die Zeilengrenze sprengen; kippt die Schnittfolge der Elternspec.
- **`withSession` doch jetzt mitnehmen** (Vorbild vollständig): ≈ +15 Zeilen, aber bis Schnitt 4 ohne Nutzer; die
  Elternspec hat es bewusst nach Schnitt 4 gelegt. Empfehlung: wie Elternspec, ohne `withSession`.

### Open Questions
- keine PO-Frage (rein technische Übernahme, kein sichtbarer Effekt).
