# Adversary-Dialog feature-57-s5-einstellungen (#57 Schnitt 5a)

Prüfer: implementation-validator, 2026-11-26. Nur Spec und Code gelesen, Code nicht geändert.

## Testläufe (selbst ausgeführt)

- Unit gezielt (ClaudeEinstellungenTests, AccountStateTests, ClaudeSyncTests, ohne Parallelität): `Executed 50 tests, with 0 failures`, `** TEST SUCCEEDED **`.
- UI einzeln über `./Scripts/run-uitests.sh ClaudeEinstellungenUITests/<methode>`: alle 6 Tests `passed` (AC-9 bis AC-14), 0 failed.
- Entitlement: im frisch gebauten Debug-Simulator-Binary stehen `com.apple.developer.applesignin` und `com.apple.developer.healthkit` (`strings -a` auf die Ausführungsdatei).
- Builds (selbst): Scheme `Meditationstimer Watch App` (watchOS Simulator) `** BUILD SUCCEEDED **`; Scheme `MeditationstimerWidgetExtension` (iPhone 17 Pro, iOS 27.2) `** BUILD SUCCEEDED **`; iOS-Scheme wird von den Testläufen gebaut.
- Volle Suiten (vorhandene Belege): `test-green-output.txt` Executed 471 tests, 0 failures; `test-green-ui-suite.txt` 98 Test Cases passed, rot nur die 2 Altfehler BackgroundMeditationUITests (#30, nicht diesem Schnitt anzulasten); `testNoAlcButtonShowsFeedbackAfterTap` Iteration 1 rot, Iteration 2 grün (Wiederholung der Suite, kein Bezug zu diesem Schnitt).
- Simulator-Bildschirmaufnahme: nicht erstellt; Simulator-Screenshots folgen im Durchlauf von /60-validate.

### Runde 1

Checkliste (jeder Punkt bewiesen):

- [x] R1 Zeile/Gruppe nur mit Konto, Wert Angemeldet/Nicht angemeldet. Beleg: `if let claudeAccount`, Wert über `isSignedIn`; UI AC-9 grün.
Code reference: Meditationstimer iOS/SettingsSheet.swift:203-217
- [x] R2 nicht angemeldet: Erklärtext, Anmeldeknopf, Hinweis; kein Abgleich, kein Abmelden; Texte im Katalog DE/EN.
Code reference: Meditationstimer iOS/Claude/ClaudeSettingsView.swift:48-55
- [x] R2 angemeldet: Status, Letzter Abgleich, Abmelden, Trennen (rot), Hinweis; Navigationstitel „Claude“.
Code reference: Meditationstimer iOS/Claude/ClaudeSettingsView.swift:21
- [x] R3 Stand-in nur DEBUG und `enable-testing`; echter Knopf mit `requestedScopes = []` und Nonce; Erfolg ohne Token/Code ruft `cancelSignIn`, Fehler und Abbruch still.
Code reference: Meditationstimer iOS/Claude/ClaudeWiring.swift:56-62
- [x] R4 `isBusy` deaktiviert alle Knöpfe, ProgressView mit Text; Unit `testHinweisUndBeschaeftigtJeStatus` grün.
Code reference: Meditationstimer iOS/Claude/ClaudeSettingsView.swift:71
- [x] R5 Hinweise nur bei notAllowed, retryLater, lastProblem; UI AC-13/14 grün.
Code reference: Meditationstimer iOS/Claude/ClaudeSettingsView.swift:129-134
- [x] R6 Letzter Abgleich aus `ClaudeSync.lastSnapshotKey`, beim Erscheinen und bei Statuswechsel; Unit AC-7 grün.
Code reference: Meditationstimer iOS/Claude/ClaudeSettingsView.swift:121-123
- [x] R7 Abmelden führt in „nicht angemeldet“; UI AC-11 grün.
Code reference: Meditationstimer iOS/Claude/ClaudeSettingsView.swift:63
- [x] R8 Rückfrage; Abbrechen ändert nichts, Bestätigen trennt; UI AC-12 grün (Abbrechen über Tippen neben die Blase, laut Known Limitation).
Code reference: Meditationstimer iOS/Claude/ClaudeSettingsView.swift:25-37
- [x] R9 `onSessionEnded` genau einmal je Sitzungsende: signOut ohne Token (Z.77), signOut (Z.87), delete Erfolg (Z.108), dropSession leerer Speicher (Z.135) und gleicher Token (Z.140).
Code reference: Meditationstimer iOS/Claude/AccountState.swift:77-140
- [x] R9 kein Rückruf bei Anmeldefehler, deleteAccount-Fehler und veralteter 401 (`guard stored == token else { return .signedIn }` vor dem Aufruf).
Code reference: Meditationstimer iOS/Claude/AccountState.swift:138
- [x] R9 nur `claudeLastSnapshotAt` gelöscht, `claudeState` bleibt; Rückruf kommt aus `makeAccount`.
Code reference: Meditationstimer iOS/Claude/ClaudeWiring.swift:51
- [x] R10 eine Instanz (einziges `AccountState(`), ClaudeSync daraus und unter `isSilent` nil, Stand-in nur in `#if DEBUG`, nil bei ausgeschaltetem Schalter.
Code reference: Meditationstimer iOS/Meditationstimer_iOSApp.swift:39-50
- [x] R11 Entitlement `com.apple.developer.applesignin` mit `Default`, HealthKit bleibt (Binary-Prüfung oben, AC-15).
- [x] R12 Kopfkommentare aktualisiert (AccountState.swift:10-12, ClaudeWiring.swift:3).
- [x] Nie Token oder Nonce in Log oder Anzeige: die Seite enthält kein Logging, Stand-in-Token sind feste Testwerte, der Logger in AccountState nennt nur Fehlerfallnamen.
- [x] Lokalisierung: alle 18 Schlüssel der Spec-Tabelle (inkl. „Not yet“ und „Cancel“) vorhanden, DE und EN `translated`, `extractionState manual` (Skriptprüfung über den Katalog).
- [x] AC-1 bis AC-8 (Unit): 12 Tests in ClaudeEinstellungenTests grün, 50 von 50 im Zielaufruf.
- [x] AC-9 bis AC-14 (UI): 6 Einzelläufe grün.
- [x] AC-15 Entitlement im gebauten Debug-Binary nachgewiesen.
- [x] AC-16 Umfang: `git diff --numstat` Swift gesamt 234 Zeilen (12+2, 136 neu, 48+1, 10+8, 17), Grenze 250; längste Funktion `makeAccount` etwa 16 Zeilen; keine Dateien außerhalb des Scopes.
- [x] AC-16 Build Watch und Widget grün (selbst gebaut, siehe oben); volle Unit-Suite 471/0 und UI-Suite 98 passed, rot nur Altfehler #30 (vorhandene Belege).

### Runde 2

Nachbohren an Kanten:

- [x] Veraltete 401 bei delete und sync: `dropSession` gibt `.signedIn` ohne Rückruf zurück; kein Fehler.
- [x] 401 bei leerem Speicher: Rückruf wird gerufen (Spec: „schon leer war“); konform.
- [x] Doppelter Rückruf nicht möglich: `signOut` ruft vor dem Netzaufruf genau einmal, ein späteres Logout-Scheitern ruft nichts.
- [x] `isBusy` bei `.deleting`: die ganze signedIn-Section ist deaktiviert, der Dialog nicht mehr auslösbar.
- [x] Release-Pfad: `makeAccount` ohne `#if DEBUG`-Zweig nutzt immer Keychain und echten Client; höchstens Compiler-Warnung zu ungeänderten `var`, kein Fehler.
- [x] `lastSync` wird ohne Statuswechsel nicht neu gelesen; entspricht R6 (beim Erscheinen und bei Statuswechsel).

## Findings

```json
[
  {
    "title": "Apple-Dialog erscheint auch, wenn beginSignIn fehlschlägt",
    "severity": "low",
    "impact": "R3 verlangt Knopf ohne Wirkung; tatsächlich öffnet sich der Apple-Dialog ohne Nonce, ein Erfolg wird von completeSignIn still verworfen. Kein Zustandsfehler, praktisch nicht erreichbar, da der Knopf nur in zulässigen Zuständen steht.",
    "proof": "Meditationstimer iOS/Claude/ClaudeSettingsView.swift:105 — request.nonce = try? account.beginSignIn()"
  },
  {
    "title": "deleteAccount ohne Token ruft onSessionEnded nicht",
    "severity": "info",
    "impact": "Zustand signedIn ohne Token (nur bei Speicherfehler) lässt lastSnapshotAt stehen; spec-konform, Fehlerrichtung unkritisch.",
    "proof": "Meditationstimer iOS/Claude/AccountState.swift:97-100"
  }
]
```

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:879db88e603e3999482b83ebcccc8ec4bbecfbe56b5b4ce6ef95b477fe19954c  Meditationstimer iOS/Claude/AccountState.swift
- sha256:43ecf888383369122d5cb67f114dd1cbbb0712eafaa5c2530cb8b4d7aeb3dfd2  Meditationstimer iOS/Claude/ClaudeSettingsView.swift
- sha256:ea8c0cb4913d8a62e8db01eb68d6884119e347addc898eca2068b7dec7cf0187  Meditationstimer iOS/Claude/ClaudeWiring.swift
- sha256:eff904ae9c64fc9af3f9b6a5432027c46a326afe31cfc89916274527ef9067fa  Meditationstimer iOS/Meditationstimer_iOSApp.swift
- sha256:2d0e90f3caec597f26d0d35f5dac7c3fa2ddf74be2507a2ce1de2e087617c7da  Meditationstimer iOS/SettingsSheet.swift

## Prüfbasis

- base: 72175ba90d31b14f766b4643625df58053e12347
- blob:bde958f0360cc4b2d47d39916dcff04b2823939a  Meditationstimer iOS/Claude/AccountState.swift
- blob:33571fe276a2c687f95be91415154f090da3b869  Meditationstimer iOS/Claude/ClaudeSettingsView.swift
- blob:9e2749f2d1422721096b18a8b219b49024021478  Meditationstimer iOS/Claude/ClaudeWiring.swift
- blob:bd3c4ac8b6e463003826538abec5407f48a2d703  Meditationstimer iOS/Meditationstimer_iOSApp.swift
- blob:1e7d36370ff7d393a27def518049dcb32d68e9a1  Meditationstimer iOS/SettingsSheet.swift
