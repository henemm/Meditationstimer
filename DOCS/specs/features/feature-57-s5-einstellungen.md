---
entity_id: feature-57-s5-einstellungen
type: feature
created: 2026-11-25
updated: 2026-11-25
status: draft
workflow: feature-57-s5-einstellungen
issue: 57
epic: 44
parent: claude-verbindung-app
---

# Schnitt 5a: Einstellungsseite „Claude-Verbindung“, Grundgerüst (#57)

## Approval

- [ ] Approved

Freigabe dieser Rundenspec durch den PO. Der Entwurf (eigene Seite) ist am 2026-11-25 freigegeben.

## Purpose

Schnitt 5a gibt der Claude-Verbindung erstmals ein Gesicht: Eine eigene Seite „Claude-Verbindung“ in den Einstellungen, auf der man sich mit Apple anmeldet und abmeldet, den Zeitpunkt des letzten Abgleichs sieht und die Verbindung mit Rückfrage trennt. Damit gibt es erstmals eine Sitzung, und der Abgleich aus Schnitt 4 wird auf einem Debug-Bau mit Anmeldung wirksam. Dazu gehören die Verdrahtung einer einzigen `AccountState`-Instanz, das Löschen von `lastSnapshotAt`, sobald eine Sitzung endet, und das Entitlement Sign in with Apple.

Sichtbar für Henning: In Debug-Bauten (und nur dort, solange `HHClaudeEnabled` nicht gesetzt ist) erscheint in den Einstellungen eine Gruppe „Claude“ mit der Zeile „Claude-Verbindung“. Die App-Store-Version zeigt nichts davon.

**Schnitt 5b** (Folgerunde, nicht Teil dieser Spec): Liste der letzten Lieferungen mit Ergebnis (aus `ClaudeStore.readState().log`) und „Was Claude sieht“ als Klartext (reine Funktion, Zählung aus `TranscriptBuilder.readCurrent`). 5a baut die Seite so, dass 5b nur Abschnitte in `ClaudeSettingsView.swift` ergänzt, ohne neue Verdrahtung.

## Source

- Kontext und Analyse: `DOCS/context/feature-57-s5-einstellungen.md` (verbindlich: Recherche, Befunde, Technical Approach, Alternativen)
- Elternspec: `openspec/specs/features/claude-verbindung-app.md`, Verhalten 2, 4, 5 und Schnitt 5
- Entwurf (PO-freigegeben 2026-11-25, eigene Seite): `DOCS/artifacts/feature-57-s5-einstellungen/index.html`, veröffentlicht unter https://claude.ai/artifact/UQYnVpsfnS518CETVB7QPA
- Vorgänger: `DOCS/specs/features/feature-57-s2b-accountstate.md`, `feature-57-s4-abgleich.md` (Abweichung 1 und 3: Entitlement und `lastSnapshotAt` löschen wandern hierher)
- Vorbild (nur gelesen): Loose Ends `AccountWiring.forApp`, `AccountSection.appleButton`, `UITestTransport`
- Recherche (Apple-Foren, developer.apple.com/forums/thread/703999, /806687, /837902): Der Apple-Anmeldedialog läuft im Simulator unter XCUITest nicht verlässlich; daher Stand-in-Knopf gegen eine Transport-Attrappe. Entitlement: developer.apple.com/documentation/xcode/configuring-sign-in-with-apple.

## Scope

App-Code (Grenze 250 Zeilen gilt nur für App-Code; Tests und Löschen toten Codes zählen nicht):

| Datei | Änderung | Inhalt | ca. Zeilen |
|---|---|---|---|
| `Meditationstimer iOS/Claude/ClaudeSettingsView.swift` | neu | Seite, `EnvironmentKey` für `AccountState?`, reine Funktionen `lastSyncText`, `hint`, `isBusy` | 130 |
| `Meditationstimer iOS/Claude/ClaudeWiring.swift` | ändern | `makeAccount(info:arguments:defaults:debugBuild:)`, `usesStandIn(arguments:)`, `UITestTransport` (nur DEBUG); Kopfkommentar Zeile 3 | +50 |
| `Meditationstimer iOS/Claude/AccountState.swift` | ändern | `onSessionEnded` (Abmelden, Trennen, 401); Kopfkommentar Zeile 11 | +10 |
| `Meditationstimer iOS/Meditationstimer_iOSApp.swift` | ändern | ein `AccountState?` halten, `claudeSync` daraus (unter Tests nil), Environment | +25 |
| `Meditationstimer iOS/SettingsSheet.swift` | ändern | Gruppe „Claude“ mit Link, nur bei vorhandenem Konto | +10 |

Summe App-Code etwa 225 bis 235 Zeilen (Schätzung der Analyse: 230), Grenze 250, jede Funktion höchstens 50 Zeilen. Zusätzlich, nicht zum Zeilenbudget und ohne Logik: `Meditationstimer iOS/Meditationstimer iOS.entitlements` (+2 Zeilen) und `Meditationstimer iOS/Localizable.xcstrings` (Texte DE/EN). Das sind 5 Swift-Dateien plus 2 Konfigurationsdateien; die 4-bis-5-Dateien-Grenze gilt für Code, beide Zusatzdateien enthalten keinen. `Meditationstimer iOS/` und `LeanHealthTimerTests/` sind synchronisierte Gruppen; kein Eingriff in `project.pbxproj`. Watch und Widget bekommen nichts.

Nicht zum Budget (Tests):

| Datei | Änderung |
|---|---|
| `LeanHealthTimerTests/ClaudeEinstellungenTests.swift` | neu, XCTest, `@testable import Lean_Health_Timer`, deutsche `testXyz`-Namen, `@MainActor` |
| `LeanHealthTimerUITests/ClaudeEinstellungenUITests.swift` | neu; Vorbild `ClaudeSpeichernUITests.swift` (Start, Zugriff auf Einstellungen über `app.buttons["gearshape"]`) |

Überschreitet das Budget während der Umsetzung 250 Zeilen: STOP, Grenze nicht anheben, Rückfrage mit Schätzung. Rückfall: Abmelden/Trennen-Teil der Seite auf eine eigene Runde verschieben.

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine neue; Entscheidungen aus der Analyse, hier festgeschrieben.

- **Eigene Seite statt Zeilen direkt in den Einstellungen** (PO 2026-11-25): Die Lieferliste und „Was Claude sieht“ (5b) brauchen Platz.
- **Eine `AccountState`-Instanz im App-Struct**, per Environment (`AccountState?`) zur Seite. Konto und Abgleich werden getrennt gebaut: Unter Tests gibt es ein Konto (Stand-in), aber keinen Abgleich. Nur eine gemeinsame Instanz sieht den 401-Abwurf des Abgleichs auf der Seite.
- **`lastSnapshotAt` löscht ein Rückruf in `AccountState` (Variante A):** `var onSessionEnded: (() -> Void)?` wird von der Verdrahtung auf `defaults.removeObject(forKey: ClaudeSync.lastSnapshotKey)` gesetzt und läuft, wenn die Sitzung lokal endet: `signOut`, erfolgreiches `deleteAccount`, 401 (`dropSession`, auch aus `deleteAccount`).
- **Zwei Knöpfe, kein dritter:** „Abmelden“ = `signOut()`, „Verbindung trennen“ = `deleteAccount()` (`POST /auth/delete`) mit Rückfrage; Geliefertes bleibt in der App (Elternspec Verhalten 4).
- **Stand-in nur in DEBUG unter `enable-testing`:** Statt Apples Knopf ein eigener Knopf, der `beginSignIn()` und `completeSignIn(identityToken:code:)` mit festen Testwerten gegen `UITestTransport` und `InMemorySessionStore` ruft. Der Ausgang kommt aus den Startargumenten: ohne Zusatz zugelassen, `uitest-claude-not-allowed` ergibt 401, `uitest-claude-retry-later` ergibt 503.

Alternativen, verworfen:
- **B: Löschen in der View nach Abmelden/Trennen:** einfacher, lässt aber den 401-Abwurf aus (Abgleich meldet ab, die View erfährt es nicht).
- **C: Löschen beim nächsten Abgleich ohne Sitzung:** verzögert; die Anzeige zeigte bis dahin den alten Wert, ein Konto-Wechsel in der Zwischenzeit erbte ihn.
- **Zeilen direkt in den Einstellungen (wie Loose Ends):** kürzer, aber ohne Platz für 5b; vom PO verworfen.
- **Echter Apple-Dialog im UI-Test:** unter XCUITest im Simulator unzuverlässig (Foren-Threads oben).

## Abweichungen

1. **Elternspec nennt `ClaudeSyncTrigger` (Verhalten 3), der nicht existiert.** Schnitt 4 entschied sich bewusst gegen den Typ (Auslöser `.task` und `scenePhase` im App-Struct). Dieser Schnitt zieht die Elternspec nach (Doku-Aufgabe, kein Code): Verhalten 3 nennt `ClaudeSync` und die Auslöser im App-Struct; Schnitt 5 wird in 5a/5b geteilt; Schnitt-5-Zeile verweist auf diese Spec.
2. **Teilung 5a/5b** gegenüber der Elternspec (ein Schnitt), weil Seite, Verdrahtung, Stand-in, Lieferliste und Klartext zusammen etwa 320 Zeilen ergäben (Zeilengrenze 250).
3. **Entitlement ohne vorherigen Portal-Schritt.** Siehe Risiken: Gerätebauten brauchen die Fähigkeit an der App-ID (#56); der Simulator nicht.

## Nicht in Scope

- Liste der letzten Lieferungen, „Was Claude sieht“, Fußnoten zu Lieferungen (Schnitt 5b).
- Echte Apple-Anmeldung und Ende-zu-Ende gegen den Dienst: nur auf dem Gerät, abhängig von #56 (Portal-Schritt, Dienst in Betrieb), nicht Teil der Abnahme dieses Schnitts. Kein Start auf Hennings Geräten ohne sein ausdrückliches „jetzt ist ein Test möglich“.
- Neue Auslöser des Abgleichs, Änderungen am Dienst, an `ServiceClient`, `ClaudeSync`, `ClaudeStore`, `TranscriptBuilder`, Schema, Watch, Widget, `project.pbxproj`, Info.plist.
- Die Debug-Haken `uitest-claude-apply` bleiben unberührt.
- Keine neuen `@AppStorage`-Schlüssel, keine Audio-Dateien.

## Dependencies

| Abhängigkeit | Art | Hinweis |
|---|---|---|
| `AccountState` (`status`, `lastProblem`, `beginSignIn`, `completeSignIn`, `signOut`, `deleteAccount`, `dropSession`) | Upstream (2b, 4) | `Status`: `signedOut, signingIn, signedIn, deleting, notAllowed, retryLater` |
| `ServiceClient`, `HTTPTransport`, `ServiceError` | Upstream (2a) | Stand-in-Transport implementiert `HTTPTransport` |
| `InMemorySessionStore`, `KeychainSessionStore`, `SessionStoring` | Upstream (1, 2a) | Test / App |
| `ClaudeWiring.isEnabled`, `serviceURL` | Upstream (1) | `isEnabled` ist unter `enable-testing` wahr |
| `ClaudeSync.lastSnapshotKey` (`claudeLastSnapshotAt`), `ClaudeSync.isSilent` | Upstream (4) | Schlüssel und Wächter bleiben, nur Löschen kommt neu |
| `AuthenticationServices` (`SignInWithAppleButton`) | System | erster Einsatz in der App |
| #56 (Portal, Dienst in Betrieb) | extern | nur für die Prüfung auf dem Gerät |
| Schnitt 5b | Downstream | ergänzt Abschnitte der Seite |

## Expected Behavior

- Input: Tippen auf „Claude-Verbindung“ in den Einstellungen; Anmelden, Abmelden, Verbindung trennen; Zustand von `AccountState`.
- Output: Seite im Zustand des Kontos; Zeile in den Einstellungen mit Stand „Angemeldet“ oder „Nicht angemeldet“.
- Side effects: Anfragen `POST /auth/apple`, `/auth/logout`, `/auth/delete` (nur mit echtem Transport, nicht unter `enable-testing`); Sitzung im Schlüsselbund; Schlüssel `claudeLastSnapshotAt` in `UserDefaults` wird bei Sitzungsende gelöscht. Nie Token, Nonce oder Körper in Anzeige oder Log.

### Regeln

**R1. Sichtbarkeit.** Die Gruppe „Claude“ steht in `SettingsSheet` unmittelbar vor der Gruppe „System-Einstellungen öffnen“. Die Zeile erscheint nur, wenn das Environment ein Konto liefert (`AccountState?` nicht nil); ohne Konto, also bei ausgeschaltetem Schalter (Store-Version), fehlt die ganze Gruppe samt Überschrift. Zeile: Titel „Claude-Verbindung“, rechts „Angemeldet“ (Status `signedIn` oder `deleting`) sonst „Nicht angemeldet“. Fußnote der Gruppe: „Claude kann dir Übungen und Programme in die App liefern.“

**R2. Seite, Reihenfolge der Elemente (Entwurf).**
- Nicht angemeldet (`signedOut`, `notAllowed`, `retryLater`, `signingIn`): Erklärtext „Melde dich mit Apple an, dann kann Claude dir Übungen und Programme liefern. Ohne Anmeldung verlässt nichts dieses iPhone.“, darunter der Anmeldeknopf (R3), darunter der Hinweis nach R5. Kein „Letzter Abgleich“, kein Abmelden.
- Angemeldet (`signedIn`, `deleting`): Gruppe mit „Angemeldet mit Apple“ (Wert „Dieses iPhone“) und „Letzter Abgleich“ (Wert nach R6); darunter getrennt „Abmelden“ und „Verbindung trennen …“ (rot). Bei `lastProblem == .retryLater` (Trennen scheiterte) der Hinweis nach R5.
- Navigationstitel „Claude“, Rückknopf zu den Einstellungen.

**R3. Anmelden.** Echter Weg: `SignInWithAppleButton` ohne Scopes. `onRequest`: `request.requestedScopes = []`, `request.nonce = try account.beginSignIn()` (der gehashte Wert); schlägt `beginSignIn` fehl, bleibt der Knopf ohne Wirkung. `onCompletion` mit Erfolg: `identityToken` und `authorizationCode` aus `ASAuthorizationAppleIDCredential` als Text, dann `await account.completeSignIn(identityToken:code:)`; fehlen sie, `account.cancelSignIn()`. `onCompletion` mit Fehler (auch Abbruch durch den Nutzer): `account.cancelSignIn()`, keine Meldung. Stand-in (nur wenn `ClaudeWiring.usesStandIn(arguments:)`, also DEBUG und `enable-testing`): ein normaler Knopf „Mit Apple anmelden (Test)“, der `beginSignIn()` und `completeSignIn(identityToken: "uitest-token", code: "uitest-code")` ruft. Der Knopf ist in `signingIn` und `deleting` deaktiviert; in `signedOut`, `notAllowed`, `retryLater` aktiv (erneuter Versuch möglich).

**R4. Fortschritt.** Solange `status == .signingIn` oder `.deleting`, zeigt die Seite einen `ProgressView` mit Text „Anmeldung läuft …“ beziehungsweise „Verbindung wird getrennt …“, und alle Knöpfe sind deaktiviert (`isBusy`).

**R5. Hinweise.** `notAllowed`: „Dieses Apple-Konto ist nicht zugelassen.“ `retryLater` (Status oder `lastProblem == .retryLater`): „Dienst gerade nicht erreichbar, später erneut.“ Sonst kein Hinweis. Reine Funktion `hint(status:lastProblem:) -> String?`.

**R6. Letzter Abgleich.** Wert aus `UserDefaults.standard` unter `ClaudeSync.lastSnapshotKey` (`claudeLastSnapshotAt`, `Date`), gelesen beim Erscheinen der Seite und bei jedem Statuswechsel. Ohne Wert „Noch nicht“, sonst `date.formatted(date: .abbreviated, time: .shortened)`. Reine Funktion `lastSyncText(_ date: Date?) -> String`.

**R7. Abmelden.** Knopf „Abmelden“ ruft `await account.signOut()`; danach zeigt die Seite den Zustand „nicht angemeldet“.

**R8. Verbindung trennen.** Knopf „Verbindung trennen …“ zeigt eine Rückfrage (`confirmationDialog`): Titel „Verbindung trennen?“, Text „Claude sieht danach nichts mehr von dieser App. Was Claude schon geliefert hat, bleibt auf dem iPhone.“, Knöpfe „Verbindung trennen“ (destruktiv) und „Abbrechen“. Erst „Verbindung trennen“ ruft `await account.deleteAccount()`; „Abbrechen“ tut nichts und ändert keinen Zustand.

**R9. Sitzungsende löscht `lastSnapshotAt`.** `AccountState.onSessionEnded` wird genau einmal aufgerufen, wenn eine Sitzung lokal endet: in `signOut` nach dem lokalen Löschen (auch ohne gespeichertes Token), in `deleteAccount` nach Erfolg, in `dropSession`, wenn der Speicher geleert wurde oder schon leer war (401). Nicht aufgerufen: Anmeldefehler, `deleteAccount`-Fehler (500, Abbruch), veraltete 401 (anderer Token im Speicher, Sitzung bleibt). Die Verdrahtung (`makeAccount`) setzt den Rückruf auf `defaults.removeObject(forKey: ClaudeSync.lastSnapshotKey)`; `claudeState` und alle anderen Schlüssel bleiben unberührt. Folge: Nach einem Kontowechsel gilt wieder „erster Lauf“ (Regel 8 des Annahme-Kerns, Fehlerrichtung „zu vorsichtig“, Schnitt 4 Abweichung 4).

**R10. Verdrahtung.** `ClaudeWiring.makeAccount(info:arguments:defaults:debugBuild:) -> AccountState?`: nil, wenn `isEnabled` falsch ist; unter `enable-testing` im Debug-Bau (nur `#if DEBUG`) Konto mit `ServiceClient(transport: UITestTransport(...))` und `InMemorySessionStore`; sonst `ServiceClient(baseURL: serviceURL(info:))` mit `KeychainSessionStore`. Der App-Struct hält dieses Konto, reicht es per Environment an `ContentView` und baut `ClaudeSync` nur aus ihm, wenn `ClaudeSync.isSilent` falsch ist (unter Tests also nil). Der Abgleich läuft weiter nur mit Sitzung.

**R11. Entitlement.** `Meditationstimer iOS.entitlements` erhält `com.apple.developer.applesignin` mit Array `["Default"]`; HealthKit bleibt.

**R12. Kopfkommentare.** `AccountState.swift` Zeile 11 („Nothing in the app calls it yet“) und `ClaudeWiring.swift` Zeile 3 („Nichts in der App ruft das bisher auf“) werden auf den Ist-Stand gebracht.

### Accessibility-Kennungen

| Kennung | Element |
|---|---|
| `claudeSettings.link` | Zeile „Claude-Verbindung“ in den Einstellungen |
| `claudeSettings.signInStandIn` | Stand-in-Anmeldeknopf (nur DEBUG, `enable-testing`) |
| `claudeSettings.appleButton` | echter Apple-Knopf |
| `claudeSettings.progress` | Fortschrittsanzeige |
| `claudeSettings.status` | Zeile „Angemeldet mit Apple“ |
| `claudeSettings.lastSync` | Zeile „Letzter Abgleich“ |
| `claudeSettings.hint` | Hinweistext (R5) |
| `claudeSettings.signOut` | Knopf „Abmelden“ |
| `claudeSettings.disconnect` | Knopf „Verbindung trennen …“ |
| `claudeSettings.disconnectConfirm` | Bestätigen in der Rückfrage |
| `claudeSettings.disconnectCancel` | Abbrechen in der Rückfrage |

### Texte (Localizable.xcstrings, Schlüssel englisch wie im Bestand, DE und EN jeweils `translated`, `extractionState` `manual`)

| Schlüssel (EN) | DE |
|---|---|
| Claude | Claude |
| Claude connection | Claude-Verbindung |
| Signed in | Angemeldet |
| Not signed in | Nicht angemeldet |
| Claude can deliver exercises and programs to this app. | Claude kann dir Übungen und Programme in die App liefern. |
| Sign in with Apple and Claude can deliver exercises and programs to you. Without signing in, nothing leaves this iPhone. | Melde dich mit Apple an, dann kann Claude dir Übungen und Programme liefern. Ohne Anmeldung verlässt nichts dieses iPhone. |
| Signed in with Apple | Angemeldet mit Apple |
| This iPhone | Dieses iPhone |
| Last sync | Letzter Abgleich |
| Not yet | Noch nicht |
| Sign out | Abmelden |
| Disconnect … | Verbindung trennen … |
| Disconnect? | Verbindung trennen? |
| Claude will no longer see anything from this app. What Claude has already delivered stays on this iPhone. | Claude sieht danach nichts mehr von dieser App. Was Claude schon geliefert hat, bleibt auf dem iPhone. |
| Disconnect | Verbindung trennen |
| Cancel | Abbrechen |
| Signing in … | Anmeldung läuft … |
| Disconnecting … | Verbindung wird getrennt … |
| This Apple account is not allowed. | Dieses Apple-Konto ist nicht zugelassen. |
| Service currently unreachable, try again later. | Dienst gerade nicht erreichbar, später erneut. |

Der Stand-in-Knopf „Mit Apple anmelden (Test)“ ist ein DEBUG-Text ohne Übersetzung und kommt nicht in den Katalog.

## Acceptance Criteria

„Unit“ = `LeanHealthTimerTests/ClaudeEinstellungenTests.swift` (Hilfsmittel: isolierte `UserDefaults`-Suite je Test, `InMemorySessionStore`, Transport-Attrappe als `actor` wie in `ClaudeSyncTests.swift`). „UI“ = `LeanHealthTimerUITests/ClaudeEinstellungenUITests.swift`, Start mit `enable-testing`, Einstellungen über `app.buttons["gearshape"]`, Prüfung über die Kennungen oben; alle Prüfungen am Zustand, den der Nutzer sieht (kein bloßes „Knopf existiert“).

- **AC-1 (Unit): Verdrahtung des Kontos.** Given `makeAccount` mit `info: nil`, `arguments: []`, `debugBuild: false`, Then Ergebnis nil (Store-Version, kein Konto, keine Zeile). Given `arguments: ["enable-testing"]`, Then nicht nil, `status == .signedOut`, und `ClaudeSync.isSilent` für dieselben Argumente wahr (Konto ja, Abgleich nein). Given Stand-in, When `beginSignIn()` und `completeSignIn`, Then `status == .signedIn`, ohne dass ein echtes Netz benutzt wird. Tests: `testMakeAccountNilBeiAusgeschaltetemSchalter`, `testMakeAccountUnterEnableTestingHatKontoAberKeinenAbgleich`.
- **AC-2 (Unit): Stand-in-Ausgänge.** Given Startargument `uitest-claude-not-allowed`, Then endet `completeSignIn` mit `.notAllowed`; Given `uitest-claude-retry-later`, Then mit `.retryLater`; Given beide fehlen, Then `.signedIn` mit gespeichertem Token. Test: `testStandInAusgaengeZugelassenNichtZugelassenSpaeter`.
- **AC-3 (Unit): Abmelden löscht `lastSnapshotAt`.** Given Konto aus `makeAccount` mit eigener Suite, gesetztem `claudeLastSnapshotAt` und `claudeState`-Inhalt, signedIn, When `signOut()`, Then ist `claudeLastSnapshotAt` nil, `claudeState` unverändert, `onSessionEnded` genau einmal gelaufen. Test: `testAbmeldenLoeschtLastSnapshotAt`.
- **AC-4 (Unit): Trennen löscht `lastSnapshotAt`.** Given dasselbe, When `deleteAccount()` (204), Then ist der Schlüssel gelöscht, Rückruf einmal. Given `deleteAccount()` scheitert mit 500 oder Abbruch, Then bleibt der Schlüssel erhalten und der Rückruf ruht. Tests: `testTrennenLoeschtLastSnapshotAt`, `testTrennenFehlerLoeschtNichts`.
- **AC-5 (Unit): 401 löscht `lastSnapshotAt`, veraltete nicht.** Given 401 aus `withSession` (Abgleich) oder aus `deleteAccount`, Then ist der Schlüssel gelöscht, Status `signedOut`. Given 401 mit inzwischen anderem Token im Speicher („T2“), Then bleibt der Schlüssel erhalten, „T2“ bleibt gespeichert, Rückruf ruht. Given Anmeldefehler (401/503 bei `completeSignIn`), Then ruht der Rückruf. Tests: `testUnauthorizedLoeschtLastSnapshotAt`, `testVeraltete401LoeschtKeinenSchluessel`, `testAnmeldefehlerLoeschtNichts`.
- **AC-6 (Unit): Ohne Rückruf unverändert.** Given ein `AccountState` ohne gesetzten `onSessionEnded`, Then verhalten sich Abmelden, Trennen und 401 wie in Schnitt 2b/4 (Status, Speicher). Die bestehenden Tests `AccountStateTests` und `ClaudeSyncTests` bleiben unverändert grün. Test: `testOhneRueckrufVerhaeltSichWieBisher`.
- **AC-7 (Unit): Zeit-Text.** Given `lastSyncText(nil)`, Then der lokalisierte Text „Noch nicht“; Given ein `Date`, Then ein nicht leerer Text, der nicht „Noch nicht“ ist und die Jahreszahl oder den Tag des Datums enthält. Test: `testLetzterAbgleichTextNochNichtUndDatum`.
- **AC-8 (Unit): Hinweise und Beschäftigt.** Given `hint`: `notAllowed` ergibt den Text „nicht zugelassen“; `retryLater` ergibt „später erneut“; `signedIn` mit `lastProblem == .retryLater` ergibt „später erneut“; `signedOut` und `signedIn` ohne Problem ergeben nil. Given `isBusy`: wahr bei `signingIn` und `deleting`, falsch sonst. Test: `testHinweisUndBeschaeftigtJeStatus`.
- **AC-9 (UI): Zeile sichtbar, Stand „Nicht angemeldet“.** Given Start mit `enable-testing`, When Einstellungen öffnen, Then steht `claudeSettings.link` mit dem Wert „Nicht angemeldet“ in der Gruppe „Claude“ oberhalb von „System-Einstellungen öffnen“ (Positionsvergleich der Rahmen). Test: `testZeileClaudeVerbindungSichtbarNichtAngemeldet`.
- **AC-10 (UI): Anmelden führt zu „angemeldet“.** Given Seite offen, When `claudeSettings.signInStandIn` tippen, Then erscheinen `claudeSettings.status`, `claudeSettings.signOut` und `claudeSettings.disconnect`, der Stand-in-Knopf ist weg, `claudeSettings.lastSync` zeigt „Noch nicht“; zurück in den Einstellungen steht am Link „Angemeldet“. Test: `testAnmeldenMitStandInZeigtAngemeldetUndNochNichtAbgeglichen`.
- **AC-11 (UI): Abmelden.** Given angemeldet, When `claudeSettings.signOut`, Then ist der Stand-in-Knopf wieder da, `claudeSettings.status` und `claudeSettings.signOut` sind weg, der Link der Einstellungen zeigt „Nicht angemeldet“. Test: `testAbmeldenZeigtWiederNichtAngemeldet`.
- **AC-12 (UI): Trennen mit Rückfrage, Abbrechen und Bestätigen.** Given angemeldet, When `claudeSettings.disconnect`, Then erscheint die Rückfrage mit „Verbindung trennen?“, und es ist noch nichts getrennt (Seite zeigt weiter angemeldet). When `claudeSettings.disconnectCancel`, Then bleibt alles angemeldet. When erneut `disconnect` und `claudeSettings.disconnectConfirm`, Then wechselt die Seite zu „nicht angemeldet“. Test: `testTrennenFragtNachAbbrechenBehaeltBestaetigenTrennt`.
- **AC-13 (UI): Hinweis 401.** Given Start mit `uitest-claude-not-allowed`, When Stand-in-Anmeldung, Then steht `claudeSettings.hint` mit „nicht zugelassen“, der Nutzer bleibt auf der Seite „nicht angemeldet“, und der Stand-in-Knopf ist wieder bedienbar. Test: `testNichtZugelassenZeigtHinweisUndErlaubtNeuenVersuch`.
- **AC-14 (UI): Hinweis 503.** Given Start mit `uitest-claude-retry-later`, When Stand-in-Anmeldung, Then steht `claudeSettings.hint` mit „später erneut“, weiter „nicht angemeldet“, Knopf bedienbar. Test: `testSpaeterErneutZeigtHinweis`.
- **AC-15 (Unit/Nachweis): Entitlement.** Given der Debug-Bau für den Simulator, Then enthält `codesign -d --entitlements :-` auf die gebaute App `com.apple.developer.applesignin` mit `Default` und weiterhin `com.apple.developer.healthkit`. Nachweis als Befehl mit Ausgabe im Validierungsbericht.
- **AC-16 (jede Runde): Umfang, Build, Regression.** Given der Diff, Then enthält er genau: die fünf App-Dateien der Tabelle, Entitlements, `Localizable.xcstrings`, die zwei Testdateien, die Elternspec (Abweichung 1) und die Workflow-Dokumente; `git diff --numstat origin/main...HEAD -- "Meditationstimer iOS"` Swift-Zeilen höchstens 250 (Zielwert 225 bis 235), keine Funktion über 50 Zeilen; iOS, Watch und Widget bauen; vollständige Unit-Suite und UI-Suite grün (`Executed N tests`, N ≥ 1; UI-Tests nur als `Klasse/Methode` oder komplette Suite über `./Scripts/run-uitests.sh`); die Kennungen der Tabelle stehen im Code. Der Katalog enthält alle Texte der Tabelle mit DE und EN `translated`; im Debug-Bau erscheint keiner der Texte in Großbuchstaben (Lehre Bug 38).

## Test Plan

- [ ] Unit (`ClaudeEinstellungenTests.swift`): AC-1 bis AC-8. GIVEN Attrappe, `InMemorySessionStore`, isolierte Suite WHEN Anmelden, Abmelden, Trennen, 401 THEN Status und Schlüssel `claudeLastSnapshotAt` wie beschrieben; die Tests prüfen den echten Rückruf der Verdrahtung, nicht einen von Hand gesetzten Zustand (Lehre #136)
- [ ] UI (`ClaudeEinstellungenUITests.swift`): AC-9 bis AC-14 mit der Suite per `./Scripts/run-uitests.sh Klasse/testMethode`; Zustandsprüfungen, die den Nutzen belegen (angemeldet erscheint, Abbrechen ändert nichts, Hinweise erscheinen und der Neuversuch bleibt möglich)
- [ ] RED-Beleg: Tests scheitern zuerst am Übersetzungsfehler (`makeAccount`, `onSessionEnded`, `ClaudeSettingsView` unbekannt) beziehungsweise an fehlenden Kennungen; danach Implementierung
- [ ] Entitlement-Nachweis AC-15 und Diff-Prüfung AC-16
- [ ] Bestand: vollständige Unit-Suite und UI-Suite grün
- [ ] Durchlauf im Simulator „App benutzen“: Debug-Bau `iPhone 17 Pro` (iOS 27.2) mit `enable-testing`: Einstellungen, Seite, Anmelden (Stand-in), Abmelden, Trennen mit Abbrechen und Bestätigen, Screenshots dunkel und hell gegen den Entwurf; ein zweiter Lauf ohne `enable-testing` zeigt die Zeile ebenfalls (Debug-Bau), der Apple-Knopf erscheint, die Anmeldung wird nicht ausgelöst. Kein Gerät von Henning.

## Risiken

- **Gerätebau-Profil.** Mit automatischer Signatur (`CODE_SIGN_STYLE = Automatic`, Team XK87E2B3VR) schaltet Xcode die Fähigkeit Sign in with Apple an der App-ID selbst frei (Apple-Doku oben; nötig ist die Rolle Account Holder oder Admin). Ist sie nicht eingeschaltet (Stand 23.11., #56), scheitern Gerätebauten am Profil, bis der Portal-Schritt erledigt ist. Der Simulator ist unkritisch. Gegenmaßnahme: Portal-Schritt in #56 benennen; falls beim Gerätebau das Profil abweicht, Entitlement-Zeile zurücknehmen statt Signatur-Einstellungen zu ändern. Keine Aktion auf Hennings Geräten ohne sein Wort.
- **Erster Netzverkehr mit Sitzung.** Sobald jemand auf einem Debug-Bau mit echtem Transport angemeldet ist, läuft der Abgleich (Schnitt 4) mit echten Daten. Unter Tests nie (Stand-in plus stummer Wächter).
- **Zeilenbudget.** Geschätzt 225 bis 235 von 250; Rückfall siehe Scope.
- **Bestätigungsdialog und Kennungen.** Knöpfe in `confirmationDialog` haben unter XCUITest nicht immer ihre Kennung; zeigt sich das im RED-Lauf, nimmt der Test den Knopf über den sichtbaren Text („Verbindung trennen“, „Abbrechen“), die Kennungen bleiben im Code.
- **Unit-Test-Host.** `makeAccount` legt unter dem XCTest-Host (ohne `enable-testing`) im Debug-Bau ein echtes Konto an (liest nur den Schlüsselbund, sendet nichts); der Abgleich bleibt dort über `ClaudeSync.isSilent` stumm.
- **`lastSnapshotAt` löschen.** Nach Abmelden gilt jede von Henning geänderte Programm- oder Atemübung wieder als blockiert (erster Lauf, Regel 8); gewollt, Fehlerrichtung „zu vorsichtig“.
- **Release mit `enable-testing`.** Das Stand-in ist nur im Debug-Bau enthalten; in Release erzeugt `makeAccount` immer das echte Konto, und nur bei `HHClaudeEnabled` überhaupt eines.

## Known Limitations

- **Rückfrage ohne sichtbares „Abbrechen“ (PO-Wahl 2026-11-25).** Seit iOS 26 erscheint `confirmationDialog` (R8) als Sprechblase am Knopf; das System blendet den Knopf mit Rolle `.cancel` aus, Abbrechen geschieht durch Tippen neben die Blase (`PopoverDismissRegion`). Der PO hat diese Apple-Darstellung gewählt, statt auf ein `.alert` mit sichtbarem „Abbrechen“ auszuweichen. Der `.cancel`-Knopf mit Kennung `claudeSettings.disconnectCancel` bleibt im Code. AC-12 bricht daher über Tippen neben die Blase ab (oder `disconnectCancel`, falls vorhanden). Quellen: hackingwithswift.com/forums/swiftui/confirmationdialog-and-cancel/30885, developer.apple.com/forums/thread/802906.
- **Testkorrekturen vor GREEN.** Der Einstellungs-Helfer der UI-Tests scrollt vor der Zeilenprüfung (das `Form` lädt Zellen außerhalb des Bildschirms erst beim Scrollen); AC-9 sucht „System‑Einstellungen“ mit dem geschützten Bindestrich U+2011 des bestehenden Katalogtexts.

## Definition of Done

- [ ] ACs AC-1 bis AC-16 nachgewiesen, im Protokoll `Executed N tests` mit N ≥ 1
- [ ] Vollständige Unit-Suite und UI-Suite grün; Build grün für iOS (Simulator `iPhone 17 Pro`, iOS 27.2), Watch und Widget
- [ ] Zeilenzählung: App-Code ≤ 250, Funktionen ≤ 50 Zeilen
- [ ] Durchlauf im Simulator mit Screenshots (dunkel, hell)
- [ ] Adversary-Prüfung: Verdict VERIFIED
- [ ] Elternspec nachgezogen: Verhalten 3 ohne `ClaudeSyncTrigger`, Schnitt 5 geteilt in 5a (erledigt) und 5b (offen)
- [ ] Folge-Issue/Teil für Schnitt 5b vorhanden (Lieferliste, „Was Claude sieht“)
- [ ] Echte Anmeldung auf dem Gerät: ausdrücklich nicht Teil dieser Abnahme; wartet auf #56 und Hennings „jetzt ist ein Test möglich“
- [ ] Änderungen am Gerät von Henning: keine

## Changelog

- 2026-11-25 (GREEN): Testkorrekturen vor GREEN: Einstellungs-Helfer scrollt vor der Zeilenprüfung (Form lädt Zellen träge), AC-9 findet „System‑Einstellungen“ mit geschütztem Bindestrich (U+2011), AC-12 bricht über Tippen neben die Sprechblase ab (PO-Wahl Apple-Darstellung, Quellen: hackingwithswift.com/forums/swiftui/confirmationdialog-and-cancel/30885, developer.apple.com/forums/thread/802906).
- 2026-11-25: Angelegt als Schnittspec für #57 Schnitt 5a (Grundgerüst der Einstellungsseite). Entscheidungen aus der Analyse übernommen: eigene Seite (PO 2026-11-25), eine `AccountState`-Instanz per Environment, Stand-in gegen `UITestTransport`, `lastSnapshotAt` per Rückruf (Variante A), Entitlement. Teilung 5a/5b; Abweichung zur Elternspec (`ClaudeSyncTrigger` existiert nicht).
