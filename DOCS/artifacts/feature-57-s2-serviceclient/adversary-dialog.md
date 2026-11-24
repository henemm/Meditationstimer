# Adversary-Protokoll feature-57-s2-serviceclient (#57, Runde 2a)

Testlauf: Unit-Suite 384 `Test case ... passed`, 0 failed, `** TEST SUCCEEDED **`; davon 19 aus ServiceClientTests und InMemorySessionStoreTests (Ausgabe im Scratchpad, adv_test.txt).

## Runde 1: Code gegen Spec

- [x] Regel 1 Anmelden: ServiceClient.swift:38-50, 62-69 (POST, Content-Type/Accept JSON, genau 3 Schlüssel, reloadIgnoringLocalCacheData, 15 s); Probe: Körper `{"identityToken":"a\"b\\c","nonce":"n","code":"c"}`
Code reference: Meditationstimer iOS/Claude/ServiceClient.swift:38
- [x] Regel 2 Abmelden/Löschen: ServiceClient.swift:53-60, 71-75 (Bearer, kein Körper, Erfolg nur 204)
- [x] Regel 3 Statuscodes: ServiceClient.swift:90-95; Probe: logout mit 200/201/202/203/205/299/302/404 -> rejected(n), 401 unauthorized, 503 unavailable
- [x] Regel 4 Ungültige Antwort: ServiceClient.swift:45-48 (try? JSON, Objekt-Cast, String, !isEmpty, sonst invalidResponse)
- [x] Regel 5 Transportfehler: ServiceClient.swift:85-89 (URLError.cancelled -> CancellationError, anderer URLError -> unavailable, sonst durchgereicht); URLSessionTransport Zeile 14 wirft invalidResponse bei Nicht-HTTP
- [x] Regel 6 Keine Geheimnisse: ServiceError nur 4 Fälle ohne Nutzlast (Zeile 20-25); Probe: localizedDescription "The operation couldn't be completed. (probe.ServiceError error 0.)", String(reflecting:) nur Fallname; kein Logging im Code
- [x] Regel 7 Transport: `URLSession(configuration: .ephemeral)` Zeile 10, `session` internal; init Zeile 32-35 sendet nichts
- [x] Regel 8 Speicher: InMemorySessionStore.swift:6-48, Mutex (Synchronization), load/save/clear nach Vertrag, `token` ohne Fehlerpfad (Zeile 18)
- [x] Regel 9 failNext: Zeile 21-27 (je Art eigenes Flag), Fehlerpfad setzt Flag zurück und ändert token nicht (Zeile 31, 38, 45)
Code reference: Meditationstimer iOS/Claude/InMemorySessionStore.swift:21
Code reference: Meditationstimer iOS/Claude/SessionStore.swift:15
- [x] AC-1: testAnmeldungSendetPfadMethodeKoepfeUndKoerper passed; Code Zeile 38-44, 62-69
Code reference: LeanHealthTimerTests/ServiceClientTests.swift:72
- [x] AC-2: testAnmeldungLiefertSitzungstoken passed; Zeile 45-49
- [x] AC-3: testAbmeldenSendetBearerOhneKoerper und testKontoLoeschenSendetBearerOhneKoerper passed; Zeile 53-75
- [x] AC-4: testStatuscodesWerdenAufServiceErrorAbgebildet und testAbmeldenUndLoeschenBildenStatuscodesAb passed; Probe bestätigt zusätzlich 201-205, 299, 302, 404 -> rejected
- [x] AC-5: testAnmeldung401IstUnauthorizedUndVonAnderenFehlernUnterscheidbar passed; Zeile 92
- [x] AC-6: testAnmeldungLeererOderFehlenderTokenIstInvalidResponse passed; Zeile 45-48
- [x] AC-7: testTransportFehlerWerdenAbgebildet passed; Zeile 85-89
- [x] AC-8: testFehlerEnthaltenNieTokenNonceCodeOderKoerper passed; Probe bestätigt Fehlerbeschreibungen ohne Nutzlast
- [x] AC-9: testAnlegenSendetNichts passed; init Zeile 32-35
- [x] AC-10: testURLSessionTransportIstEphemeral passed (Lesart der Spec: diskCapacity 0, Cookie- und Zugangsspeicher nicht `.shared`)
- [x] AC-11: testSpeicherSpeichernLesenLoeschen und testSpeicherStartetMitToken passed
- [x] AC-12: testFailNextSaveWirftEinmalUndAendertNichts, testFailNextLoadWirftEinmal, testFailNextClearWirftEinmalUndBehaeltToken passed
Code reference: LeanHealthTimerTests/InMemorySessionStoreTests.swift:39
- [x] AC-13: testFailNextMarkierungenSindUnabhaengig und testSpeicherNebenlaeufigerZugriff passed; Mutex, final class ohne @unchecked
- [x] AC-14: Diff = ServiceClient.swift 97 + InMemorySessionStore.swift 49 + SessionStore.swift 2 = 148 Zeilen (Grenze 250); längste Funktion `send` ca. 16 Zeilen; Quelltextsuche (grep über alle .swift außerhalb der Tests): kein Aufrufer; git status: keine weitere App-Datei geändert (nur Spec und .claude-Werkzeugzustand); `Executed`-Ersatz: 384 passed-Zeilen. Offen/nicht geprüft: Build Watch/Widget und Simulator-Durchlauf (nicht Teil des Auftrags)

## Runde 2: Tests und Nachbohren

- Unit-Suite komplett gelaufen: 384 passed, 0 failed, TEST SUCCEEDED.
- Wegwerf-Probe (swiftc im Scratchpad) zu baseURL: `https://x.test`, `https://x.test/`, `/api`, `/api/` ergeben je genau einen Schrägstrich vor `auth/...`; nur `https://x.test//` ergibt `//auth/logout`.
- Statuscodes 2xx außer Erfolgscode, 302, 404 -> `rejected(n)`, bestätigt.
- Sendable echt: kein `@unchecked` in beiden Dateien.
- Kein URLError nach außen: ServiceClient.send bildet jeden URLError ab; Erfolgs- und Fehlerpfade tragen keine URL.

## Findings

{id: F-1, severity: LOW, category: edge_case, description: "baseURL mit doppeltem Schrägstrich am Ende wird nicht normalisiert", evidence: "Probe: https://x.test// -> https://x.test//auth/logout (ServiceClient.swift:64 baseURL.appending(path:))", remediation: "Keine nötig; baseURL kommt aus fester Konfiguration"}

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:41d25a910c5f3a8e2dd1e6e79acc4800c57b7b23d1d38606fe2517888161ae53  LeanHealthTimerTests/InMemorySessionStoreTests.swift
- sha256:0bfde026814215bab1e810ca91da1d46e71eef252ba8aac8f0274fdbba329316  LeanHealthTimerTests/ServiceClientTests.swift
- sha256:640fcebd5646c22fdcc958511b911c81a5245e429d64bb28ab41bae8bcf81358  Meditationstimer iOS/Claude/InMemorySessionStore.swift
- sha256:d228de928c6914cdab3bd5809b8ecef11bc31b66a6cce2d7e1bd4e4af3358767  Meditationstimer iOS/Claude/ServiceClient.swift
- sha256:b9a434f861846cf59407e6c397f4b9d3eb9405fa739a381ad517b667329ddc58  Meditationstimer iOS/Claude/SessionStore.swift

## Prüfbasis

- base: 5172be41897e0bd7fd0126cf3d2e9db876bb8719
- blob:a18e462228d34898eb68ab868662579408432d46  LeanHealthTimerTests/InMemorySessionStoreTests.swift
- blob:84168f332012176ae2f9204b6da84fe39f7c05c4  LeanHealthTimerTests/ServiceClientTests.swift
- blob:ecb3fb91904510e30cefb258b8c635a98de296bc  Meditationstimer iOS/Claude/InMemorySessionStore.swift
- blob:db00312e035f6b8e80ca32b75ccf730f2ae4d8e9  Meditationstimer iOS/Claude/ServiceClient.swift
- blob:0447284deb9a16fd37e4ae1473a57f2abaf6d578  Meditationstimer iOS/Claude/SessionStore.swift
