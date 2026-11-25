# Context: feature-57-s5-einstellungen (#57 Schnitt 5)

## Request Summary
Schnitt 5 der Claude-Verbindung: Einstellungsseite „Claude-Verbindung“ (Anmelden mit Apple / Abmelden, letzter Abgleich,
Liste der letzten Lieferungen mit Ergebnis, „Was Claude sieht“ als Klartext, „Verbindung trennen“ mit Rückfrage), dazu
Entitlement Sign in with Apple und das Löschen von `lastSnapshotAt` bei Abmelden und Konto löschen. In der Store-Version
unsichtbar (Schalter). Elternspec `openspec/specs/features/claude-verbindung-app.md` Verhalten 2, 4, 5 und Schnitt 5.

Voraussetzungen erfüllt: Schnitte 1–4 gemergt (Stand origin/main 72175ba), #117 (feste Kennungen der Vorgaben) geschlossen.
#56 (Dienst in Betrieb) offen — betrifft nur die Ende-zu-Ende-Prüfung, nicht diesen Schnitt.

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Claude/AccountState.swift` | `@MainActor @Observable`; Status `signedOut, signingIn, signedIn, deleting, notAllowed, retryLater` (:13), `lastProblem` (:15), `beginSignIn() throws -> String` (gehashter Nonce, :33), `completeSignIn(identityToken:code:)` (:43), `cancelSignIn()` (:63), `signOut()` (:70), `deleteAccount()` (:91), `withSession` (:115). Kopfkommentar veraltet („Nothing in the app calls it yet“). |
| `Meditationstimer iOS/Claude/ClaudeSync.swift` | Abgleich; `lastSnapshotAt` in UserDefaults „claudeLastSnapshotAt“ (:10, Lesen :30, Schreiben :67). Hält AccountState und Defaults privat. |
| `Meditationstimer iOS/Claude/ClaudeWiring.swift` | Schalter `isEnabled(info:arguments:)` (:14), `serviceURL(info:)` (:23). Kommentar :3 veraltet. |
| `Meditationstimer iOS/Claude/ServiceClient.swift` | `HTTPTransport` (:4, Attrappe möglich), `ServiceError` (:20), `signIn`/`logout`/`deleteAccount`. |
| `Meditationstimer iOS/Claude/KeychainSessionStore.swift`, `InMemorySessionStore.swift`, `SessionStore.swift`, `Nonce.swift`, `DeviceIdentity.swift` | Bausteine Schnitt 1/2. |
| `Meditationstimer iOS/Models/ClaudeStore.swift`, `ClaudeApply.swift` | Lieferergebnisse: `claudeState.log: [ClaudeApplyLogEntry]` (deliveryId/result/at, ≤ 50), Lesen `ClaudeStore.readState(from:)` (:86), Notification `.claudeStoreDidChange` (:12). |
| `Meditationstimer iOS/Models/TranscriptBuilder.swift` | Abschrift Fassung 1 (`readCurrent` :29, `build` :50, `deliveries(_:)` :120) — Quelle für „Was Claude sieht“; Klartextfassung existiert nicht. |
| `Meditationstimer iOS/Meditationstimer_iOSApp.swift` | `let claudeSync: ClaudeSync?` (:30), `makeClaudeSync()` (:43–50) erzeugt ServiceClient, AccountState, ClaudeSync lokal; Auslöser `.task` (:95), `scenePhase` (:96). UI-Test-Hooks `uitest-claude-apply` (:108–115, nur DEBUG). |
| `Meditationstimer iOS/SettingsSheet.swift` | `Form` mit Sections (:41); Vorbild-Link SmartReminders (:190–195); neuer Link vor „Open System Settings“ (:203). Keine Accessibility-Kennungen. Als fullScreenCover aus MeditationTab (:158) und WorkoutTab (:130). |
| `Meditationstimer iOS/Meditationstimer iOS.entitlements` | Nur HealthKit; Sign in with Apple fehlt. `CODE_SIGN_STYLE = Automatic` (pbxproj 937, 975). |
| `Meditationstimer iOS/Localizable.xcstrings` | App-Texte; Claude-Schlüssel oben (z. B. „von Claude“), Format `extractionState manual`, DE+EN `translated`. |
| `LeanHealthTimerUITests/ClaudeSpeichernUITests.swift`, `ClaudeKennzeichenUITests.swift` | Vorbild für Claude-UI-Tests (launch, openTab positionsbasiert, element). Einstellungen über `app.buttons["gearshape"]` (LeanHealthTimerUITests.swift:1406–1418). |

## Existing Patterns
- Geteilte Objekte der App als `@StateObject` im App-Struct; Claude-Objekte bisher nur lokal in `makeClaudeSync()` — für die Seite muss `AccountState` (und Sync-Zustand) in die View gelangen (Environment).
- Accessibility-Kennungen camelCase mit Punkt-Namespace (`exerciseDetail.claudeOrigin`, `claudeOrigin.why`).
- Texte über `NSLocalizedString(key, comment:)`; DE ist Primärsprache.
- UI-Test-Zustände über Startargumente (`enable-testing`, `uitest-claude-apply` + Umgebungsvariablen, nur DEBUG).
- Unit-Tests mit `HTTPTransport`-Attrappe und `InMemorySessionStore`.

## Dependencies
- Upstream: AuthenticationServices (`ASAuthorizationAppleIDProvider`, `SignInWithAppleButton`) — erster Einsatz in der App; Nonce, AccountState, ServiceClient, ClaudeStore, TranscriptBuilder.
- Downstream: Abgleich (ClaudeSync) wird erstmals mit Sitzung aktiv, sobald jemand angemeldet ist → erster echter Netzverkehr mit Daten.

## Existing Specs
- `openspec/specs/features/claude-verbindung-app.md` — Elternspec (Schnitt 5)
- `docs/specs/features/feature-57-s2b-accountstate.md`, `feature-57-s4-abgleich.md` — Downstream-Hinweise auf Schnitt 5
- `openspec/specs/integrations/claude-dienst.md`, `claude-anmeldung.md` — Dienst-Routen

## Risks & Considerations
- **Kein Stand-in für den Apple-Dialog.** UI-Test braucht einen Testweg (z. B. Startargument, das `completeSignIn` mit Attrappen-Transport auslöst), sonst ist die Anmeldung nicht automatisiert prüfbar.
- **Entitlement:** Mit automatischer Signatur schaltet Xcode die Fähigkeit an der App-ID frei (Recherche in Schnitt-4-Spec, Apple-Doku). Restrisiko Profilabgleich bei Gerätebauten; Simulator unkritisch.
- **`lastSnapshotAt` löschen:** AccountState hat keinen Zugriff auf die Defaults; Löschen muss injiziert oder über ClaudeSync laufen.
- **Zeilenbudget:** Seite + Environment-Verdrahtung + Apple-Anbindung + Klartext „Was Claude sieht“ + Texte (xcstrings zählt nicht als Swift, aber App-Datei) überschreiten vermutlich 250 Zeilen → Schnitt 5 in zwei Runden teilen (5a Seite + Anmeldung, 5b Lieferliste/„Was Claude sieht“/Trennen) prüfen.
- **Store-Version:** Link nur bei eingeschaltetem Schalter; im Release unsichtbar — UI-Test kann nur Debug prüfen, Release über Unit-Test des Schalters (Schnitt 1).
- **Sichtbare Änderung:** Entwurf vor Spec Pflicht (Artefakt unter `docs/artifacts/feature-57-s5-einstellungen/`).
- Spec nennt `ClaudeSyncTrigger`, der im Code nicht existiert (Auslöser direkt im App-Struct) — Elternspec nachziehen.

## Analysis

### Type
Feature (#57 Schnitt 5, Teil von Epic #44)

### Recherche
- Apple-Anmeldedialog läuft im Simulator unter XCUITest nicht verlässlich (Apple-Foren: developer.apple.com/forums/thread/703999,
  /806687 „iOS 26.1 simulator prompting Apple ID login during XCUITest“, /837902). Folge: UI-Tests nutzen einen Stand-in-Knopf
  gegen eine Transport-Attrappe, genau wie Loose Ends (`AccountSection.appleButton`, `UITestTransport`). Echte Anmeldung nur auf
  dem Gerät, nach #56 und nur auf Hennings Wort.
- Entitlement `com.apple.developer.applesignin = ["Default"]`; bei automatischer Signatur muss die Fähigkeit an der App-ID aktiv
  sein (Portal-Schritt #56), sonst scheitern Gerätebauten am Profil. Simulator unkritisch.

### Befunde aus dem Code
- Unter `enable-testing` (alle UI-Tests) ist heute `claudeSync` nil, und `AccountState` existiert nur lokal in `makeClaudeSync()`.
  Die Seite braucht unter UI-Tests trotzdem einen `AccountState` (Stand-in-Transport + `InMemorySessionStore`), der Abgleich
  muss stumm bleiben → Konto und Abgleich getrennt bauen, **eine** Instanz teilen (sonst sieht die Seite einen 401-Abwurf nicht).
- „Verbindung trennen“ = `deleteAccount()` (`POST /auth/delete`), „Abmelden“ = `signOut()`. Zwei Knöpfe, kein dritter
  „Konto löschen“ (Elternspec Verhalten 4).
- Lieferprotokoll trägt nur `deliveryId`, Ergebnis, Zeitpunkt — die Liste zeigt Datum + Übernommen/Abgelehnt (+ Grund).
- „Was Claude sieht“: Regelweg, Zählung aus `TranscriptBuilder.readCurrent` (Übungen gesamt/davon Claude, Programme,
  Atemübungen, Lieferergebnisse) + fester Satz, was nicht übertragen wird. Kein Modell.
- `ClaudeSyncTrigger` existiert nicht (Auslöser sitzen im App-Struct) → Elternspec Verhalten 3 nachziehen.

### Affected Files (with changes)
Schnitt 5a (diese Runde):
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Claude/ClaudeWiring.swift` | MODIFY | `makeAccount(info:arguments:)` (nil bei Schalter aus; Stand-in unter `enable-testing`), `UITestTransport` |
| `Meditationstimer iOS/Claude/AccountState.swift` | MODIFY | Rückruf `onSessionEnded` (Abmelden, Trennen, 401) → `lastSnapshotAt` löschen; Kopfkommentar |
| `Meditationstimer iOS/Meditationstimer_iOSApp.swift` | MODIFY | ein `AccountState?` halten, `claudeSync` daraus (unter Tests nil), Environment |
| `Meditationstimer iOS/Claude/ClaudeSettingsView.swift` | CREATE | Seite: Anmelden (Apple-Knopf / Stand-in), Fortschritt, Hinweise 401/503, letzter Abgleich, Abmelden, Trennen mit Rückfrage |
| `Meditationstimer iOS/SettingsSheet.swift` | MODIFY | Gruppe „Claude“ mit Link (nur wenn Konto vorhanden) |
| `Meditationstimer iOS/Meditationstimer iOS.entitlements` | MODIFY | Sign in with Apple (Konfiguration) |
| `Meditationstimer iOS/Localizable.xcstrings` | MODIFY | DE/EN-Texte (zählt nicht) |
| `Tests/…`, `LeanHealthTimerUITests/ClaudeEinstellungenUITests.swift` | CREATE | Unit (Wiring, Rückruf, Zeit-Text), UI (Link sichtbar, Anmelden/Abmelden/Trennen, 401/503-Hinweis) |

Schnitt 5b (Folgerunde, keine neue Verdrahtung): Lieferliste aus `ClaudeStore.readState().log`, „Was Claude sieht“ als
Klartext (reine Funktion + Unit-Test), beides in `ClaudeSettingsView.swift`.

### Scope Assessment
- 5a: 5 Swift-Dateien + Entitlement + xcstrings, ca. +230 Zeilen App-Code (Seite ~130, Wiring ~50, App ~15, AccountState ~10,
  Settings ~8, Trennen ~20). 5b: ca. +90–110.
- Gesamt ~320 > 250 → **Teilung 5a/5b nötig.**
- Risk Level: MEDIUM — erster echter Netzverkehr mit Sitzung, erstes Entitlement für Apple-Anmeldung (Gerätebau-Profil).

### Technical Approach
Wie Loose Ends (`AccountWiring.forApp`, `AccountSection`): eine `AccountState`-Instanz im App-Struct, per `EnvironmentKey`
(`AccountState?`) zur Seite; Link nur bei vorhandenem Konto (= Schalter an). Unter `enable-testing` Stand-in-Transport mit
Ausgängen über Startargumente (zugelassen / `uitest-claude-not-allowed` / `uitest-claude-retry-later`), Abgleich bleibt nil.
`lastSnapshotAt` löscht ein Rückruf in `AccountState` (Variante A; deckt auch 401 ab). Letzter Abgleich: Wert aus Defaults,
gelesen beim Erscheinen und bei Statuswechsel, „Noch nicht“ ohne Wert.

Alternativen:
- Löschen von `lastSnapshotAt` in der View nach Abmelden/Trennen (B): einfacher, lässt aber den 401-Abwurf aus — verworfen.
- Löschen beim nächsten Abgleich ohne Sitzung (C): verzögert, Anzeige zeigt alten Wert — verworfen.
- UI ohne eigene Seite, Zeilen direkt in den Einstellungen (wie Loose Ends): kürzer, aber keine Platz für Lieferliste und
  „Was Claude sieht“ — Entscheidung beim PO (Entwurf).

### Entwurf
`DOCS/artifacts/feature-57-s5-einstellungen/index.html`, veröffentlicht: https://claude.ai/artifact/UQYnVpsfnS518CETVB7QPA
(Heute-Screenshot dunkel, Entwurf Einstieg, Seite angemeldet dunkel/hell, nicht angemeldet, Rückfrage Trennen, Alternative inline).

### Open Questions
- [x] PO 2026-11-25: Entwurf freigegeben — **eigene Seite** hinter der Zeile „Claude-Verbindung“ (Gruppe „Claude“ vor „System-Einstellungen öffnen“).
