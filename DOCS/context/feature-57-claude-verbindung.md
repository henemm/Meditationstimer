# Context: feature-57-claude-verbindung (#57, Epic #44, B2d)

## Request Summary
Die App meldet sich mit Apple beim Claude-Dienst an, gleicht Lieferungen selbst ab (abholen → mit #51 anwenden → Ergebnis
melden → Abschrift senden) und zeigt in den Einstellungen eine Seite „Claude-Verbindung“. In der Store-Version aus und unsichtbar.

## Stand der Spezifikation
`openspec/specs/features/claude-verbindung-app.md` (13.11.2026) beschreibt Verhalten, Tests und **fünf Schnitte**:
1. Schalter, Nonce, Schlüsselbund, Geräte-UUID (übernommen aus Loose Ends)
2. `ServiceClient` und `AccountState`
3. Abschrift Fassung 1 + Goldendateien + CI-Schritt
4. Abgleich und Auslöser, in den App-Start eingehängt
5. Einstellungsseite mit Texten DE/EN und UI-Test

Nach Projektregel „Runde je Schnitt“ bekommt jeder Schnitt eine eigene Workflow-Runde. **Diese Runde = Schnitt 1.**

## Dienst-Schnittstelle (server/src, fertig mit #54/#55; Betrieb #56 offen)
- `POST /auth/apple {identityToken, nonce, code}` → 200 `{sessionToken}`; 401 nicht zugelassen/ungültig; 503 Apple/Konfig fehlt.
  Nonce: Apple bekommt SHA-256, der Dienst den Rohwert (`server/src/auth.ts:64-81`).
- `POST /auth/logout`, `POST /auth/delete` mit `Authorization: Bearer <token>` → 204.
- `POST /app/deliveries/claim` (Bearer, `X-Device: <UUID>`, JSON) → 200 `{deliveryId, delivery}` / 204 nichts offen.
- `POST /app/deliveries/result {deliveryId, outcome: accepted|rejected, errors?[{code,path,message}]}` → 204 / 409.
- `POST /app/transcript` (Fassung 1: version, generatedAt, exercises/programs/breaths [{id}], deliveries[{deliveryId,outcome}]) → 204.
- Tür: `ALLOWED_APPLE_SUBS`; Audience `APPLE_CLIENT_IDS` muss `henemm.Meditationstimer-iOS` enthalten.

## Related Files (App)
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Models/ClaudeDelivery.swift:59` | `ClaudeDelivery.read(_:)` – liest das Lieferdokument (nicht die Claim-Hülle) |
| `Meditationstimer iOS/Models/ClaudeApply.swift:52` | reiner Annahme-Kern, Ergebnis `applied/noEffect/rejected(code,reason)` |
| `Meditationstimer iOS/Models/ClaudeStore.swift:108` | `ClaudeStore.apply(...)` mit `lastSnapshotAt` (heute überall `nil`; #57 muss Zeitpunkt der letzten Abschrift liefern) |
| `Meditationstimer iOS/Meditationstimer_iOSApp.swift:17,42-60,96-111` | `scenePhase` deklariert, ungenutzt; DEBUG-Startargumente; UI-Test-Haken `uitest-claude-apply` („bis #57“) |
| `Meditationstimer iOS/SettingsSheet.swift:190-208` | Form-Abschnitte; Link „Claude-Verbindung“ passt nach Smart Reminders |
| `Meditationstimer iOS/Meditationstimer iOS.entitlements` | nur HealthKit; Sign in with Apple fehlt |
| `Meditationstimer-iOS-Info.plist` | kein `HHClaudeEnabled`/`HHServiceURL`; BGTask-Kennung nur für Smart Reminders |

Bisher **kein** Netzwerkcode, kein Schlüsselbund, kein `AuthenticationServices` in der App. Brücke (#53) ohne `onOpenURL`-Weg
für Lieferungen; einziger Aufrufer von `ClaudeStore.apply` ist der DEBUG-Haken.

## Vorbild Loose Ends (`/Users/hem/Developer/loose-ends/LooseEnds/Claude/`, nur lesen)
| Datei | Zeilen | Schnitt |
|---|---|---|
| `AccountWiring.swift` (Schalter `LEAccountEnabled`, `LEServiceURL`, Debug-Dienst) | 132 | 1 (nur Schalter/Adresse) |
| `Nonce.swift` | 34 | 1 |
| `SessionStore.swift`, `KeychainSessionStore.swift` | 63 + 99 | 1 |
| `DeviceIdentity.swift` | 66 | 1 |
| `ServiceClient.swift`, `AccountState.swift` | 170 + 171 | 2 |
| `ClaudeSync.swift`, `ClaudeSyncTrigger.swift` | 160 + 178 | 4 |
| `DeviceRegistration.swift`, `PushWakeUp.swift` | – | nicht übernommen (kein Push in HHHaven) |

Schalter-Muster LE: an unter `--ui-testing` oder Debug-Dienst, sonst nur wenn Info-Wert ein echtes Bool `true` ist.
HHHaven nutzt als Test-Argument `enable-testing` (nicht `--ui-testing`).

## Existing Specs
- `openspec/specs/features/claude-verbindung-app.md` (diese Aufgabe), `features/claude-annahme.md` (#51)
- `openspec/specs/integrations/claude-dienst.md` §5, `claude-anmeldung.md`, `claude-lieferformat.md`, `claude-rueckblick.md` (#59)
- `DOCS/context/analyse-51-57-claude-app.md`, `DOCS/claude-anmeldung-pruefliste.md`

## Recherche (2026-11-23)
- Sign in with Apple: Ablauf unverändert (Nonce gehasht an Apple, Identity-Token an Server; Server prüft Signatur, iss, aud, nonce).
  Einzelne Forenberichte zu Fehlschlägen unter iOS 26.x betreffen Apples Team-Registrierung, nicht App-Code.
  https://developer.apple.com/documentation/signinwithapple/verifying-a-user · https://developer.apple.com/forums/thread/839965
- Hintergrund: `BGAppRefreshTask` max. 30 s, Zeitpunkt bestimmt das System; SwiftUI `.backgroundTask(.appRefresh)` steht im
  Index unter „Deprecated symbols“ → vor Einsatz prüfen. Spec sieht für #57 nur Start + Vordergrund vor.
  https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app.md

## Risks & Considerations
- Erster Netzwerkcode: Sitzungstoken nie im Klartext speichern/loggen; Keychain im Simulator/Tests per Attrappe.
- Schalter muss im Release wirklich aus sein (Info-Wert per Build-Einstellung je Konfiguration).
- Entitlement Sign in with Apple braucht Eintrag im Developer-Portal (Runbook Schritt 2, henemm-infra) – Signatur im Simulator prüfen
  (Memory: Ad-hoc-Signatur, HealthKit-Entitlements in CI).
- Issue nennt „gelegentlich im Hintergrund“ und „kurz nach eigenen Änderungen“, die Spec nur Start + Vordergrund → in Analyse klären.
- Ende-zu-Ende mit echtem Dienst erst nach #56.

## Analysis (2026-11-23, Schnitt 1)

### Type
Feature (Schnitt 1 von 5) — reine Bausteine ohne sichtbare Änderung; nichts in der App ruft sie in dieser Runde auf.

Vorgehen: Betroffene Dateien, Specs und Abhängigkeiten waren in /10-context bereits vollständig erhoben (siehe oben);
die Analyse wurde direkt am Vorbild (Loose Ends, 5 Dateien gelesen) und am Projekt (pbxproj, Info.plist, Entitlements,
Testimporte) gemacht, ohne zusätzliche Explore-Agenten.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Claude/ClaudeWiring.swift` | CREATE | `isEnabled(info:arguments:debugBuild:)`, `serviceURL(info:allowsLocalHTTP:)`, Vorgabe `https://habits.henemm.com` (~40) |
| `Meditationstimer iOS/Claude/Nonce.swift` | CREATE | 1:1 aus LE: 32 Zufallsbytes base64url, `hashed` = SHA-256 hex (~34) |
| `Meditationstimer iOS/Claude/SessionStore.swift` | CREATE | Protokoll `SessionStoring` + `SessionStoreError` (~20) |
| `Meditationstimer iOS/Claude/KeychainSessionStore.swift` | CREATE | `KeychainOperations`, `SystemKeychain`, `KeychainEntry` (gemeinsame Abfragen), `KeychainSessionStore` (~95) |
| `Meditationstimer iOS/Claude/DeviceIdentity.swift` | CREATE | Geräte-UUID, nutzt `KeychainEntry` mit eigenem Account (~45) |
| `LeanHealthTimerTests/ClaudeVerbindungBausteineTests.swift` | CREATE | Unit-Tests mit Schlüsselbund-Attrappe (zählt nicht ins Limit) |

Neuer Ordner `Claude/` liegt in der synchronisierten Gruppe des iOS-Ziels (automatisch Mitglied, kein pbxproj-Eingriff);
Watch und Widget bekommen nichts. Tests per `@testable import Lean_Health_Timer`.

### Scope Assessment
- App-Dateien: 5 neu, 0 geändert
- Estimated LoC: +~235 App / -0 (Tests extra)
- Risk Level: LOW — nur neue, unverdrahtete Typen; keine Datei der App geändert, Info.plist und Entitlements unverändert.

### Technical Approach
1. **Schalter ohne Info.plist-Eintrag:** an, wenn Debug-Bau (`#if DEBUG`) oder Startargument `enable-testing`; sonst nur, wenn
   `HHClaudeEnabled` im Info-Dictionary ein echtes Bool `true` ist (LE-Prüfung mit `CFBooleanGetTypeID`). Release ohne Eintrag ⇒ aus.
   Alternative verworfen: Info-Wert per Build-Variable je Konfiguration — Substitution liefert einen String, kein Bool, und
   verdoppelt die Wahrheit (Code + pbxproj).
2. **Dienstadresse:** `HHServiceURL` nur https mit Host; http nur `localhost`/`127.0.0.1` im Debug-Bau; sonst Vorgabe.
   Der LE-Debug-Weg (`-LEDebugService`) und `forApp`/`UITestTransport` gehören zu Schnitt 2 (brauchen `ServiceClient`/`AccountState`).
3. **Nonce, Sitzungsspeicher, Geräte-UUID** wie LE, umbenannt; Schlüsselbund-Kennungen `henemm.Meditationstimer-iOS.claude.session`
   und `henemm.Meditationstimer-iOS.claude.device`; `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, nie synchronisiert.
   Jeder Status außer Erfolg/„nicht gefunden“ ist Fehler (auch -34018), nie still „abgemeldet“. Fehler tragen nie den Token.
4. **Abweichung vom Vorbild zur Zeilenersparnis:** `InMemorySessionStore` wandert nach Schnitt 2 (erster Nutzer: Verdrahtung
   unter Tests); Sitzung und Geräte-UUID teilen eine Abfrage-Hilfe statt zweier Kopien.
5. **Entitlement Sign in with Apple nicht in diesem Schnitt:** Ohne Eintrag im Developer-Portal (Runbook #56, offen) bricht die
   Signatur für Gerätebauten. Kommt mit Schnitt 2 (erster `ASAuthorization`-Aufruf), nach Prüfung des Portalstands.

### Dependencies
- Frameworks: Foundation, Security, CryptoKit, Synchronization (nur falls nötig; Ziel iOS 18.5 erlaubt `Mutex`).
- Keine Abhängigkeit auf #51-Code; nichts hängt in dieser Runde davon ab.

### Tests (für /40-tdd-red)
- Schalter: Release ohne Eintrag aus; Debug an; `enable-testing` an; Info-Wert String "YES"/Zahl 1 zählt als aus; Bool true an.
- Adresse: fehlend/kaputt/http fremd ⇒ Vorgabe; https übernommen; http localhost nur mit Debug.
- Nonce: 43 Zeichen base64url, zwei Werte verschieden, `hash` gegen bekannten SHA-256-Vektor.
- Sitzung: speichern/lesen/löschen über Attrappe; Duplikat ⇒ Update nur des Werts; nicht gefunden ⇒ nil; -34018 ⇒ Fehler;
  leere/kaputte Daten ⇒ `corruptData`; Fehlerbeschreibung enthält den Token nie.
- Geräte-UUID: erzeugt einmal, liest danach dieselbe; Duplikat beim Anlegen ⇒ erneutes Lesen; kaputte Daten ⇒ Fehler, nie ersetzt.

### Open Questions
- keine für Schnitt 1. Für Schnitt 4 offen: Issue nennt zusätzlich „kurz nach eigenen Änderungen“ und „gelegentlich im
  Hintergrund“, Spec nur Start + Vordergrund — dort klären.
