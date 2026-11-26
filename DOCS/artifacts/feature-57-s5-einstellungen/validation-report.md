# Validation Report: feature-57-s5-einstellungen (#57 Schnitt 5a)

Stand: 2026-11-26, Commit 12391a3 (Implementierung) plus Belege.

## Test Results
- Unit (komplett, LeanHealthTimerTests): Executed 471 tests, 0 failures (`test-green-output.txt`).
- Gezielt (ClaudeEinstellungen, AccountState, ClaudeSync): Executed 50 tests, 0 failures (`adversary-test-output.txt`).
- UI-Klasse ClaudeEinstellungenUITests: 6/6 passed, einzeln als Klasse/Methode.
- UI-Suite komplett (`test-green-ui-suite.txt`): 98 verschiedene Tests passed, 19 übersprungen (XCTSkip im Testcode, wie bisher). Rot sind nur die 2 Altfehler `BackgroundMeditationUITests` (#30), schon in der Validierung von Schnitt 4 rot. `testNoAlcButtonShowsFeedbackAfterTap` war in Iteration 1 rot, in Iteration 2 grün (flaky, kein Bezug zu diesem Schnitt).
- Builds: iOS, Watch („Meditationstimer Watch App“) und Widget („MeditationstimerWidgetExtension“) BUILD SUCCEEDED.

## Spec Compliance
- AC-1 bis AC-16: 16/16 erfüllt. Belege im Adversary-Protokoll `adversary-dialog.md`: 28 Punkte bewiesen, 2 Runden, VERDICT VERIFIED.
- AC-12 mit PO-Wahl (2026-11-25): Die Rückfrage ist Apples Sprechblase ohne sichtbares „Abbrechen“; abgebrochen wird durch Tippen daneben (Spec, Known Limitations).
- AC-15: Das Entitlement `com.apple.developer.applesignin` = Default und `healthkit` stehen im gebauten Binary (`entitlements.txt`).

## Durchlauf im Simulator (App benutzt)
- Durchlauf `walk/walk.md` mit 14 Bildschirmfotos in Hell und Dunkel:
  - Lauf A (`enable-testing`): Einstellungen → Seite → Anmelden (Stand-in) → Rückfrage öffnen → Abbrechen → Abmelden. Alle Schritte OK.
  - Lauf B (Debug ohne Testmodus): Die Zeile erscheint, die Seite zeigt Apples echten Anmeldeknopf (nicht getippt).
- Keine Großbuchstaben, keine abgeschnittenen Texte, Kontrast in beiden Darstellungen gut.

## Regression Check
- Keine Regressionen (siehe UI-Suite oben).

## Scope Check
- App-Swift-Dateien: 5 (ClaudeSettingsView neu, ClaudeWiring, AccountState, App-Struct, SettingsSheet). Dazu Entitlements und Katalog ohne Logik.
- Swift-Zeilen: +223 / −11 = 234 (Grenze 250). Längste Funktion etwa 20 Zeilen.
- Außerhalb des Scopes: keine. Die Elternspec wurde nachgezogen (Abweichung 1).

## Findings (gering, ohne Auswirkung)
- R3: `try? beginSignIn()` öffnet den Apple-Dialog auch, wenn die Vorbereitung scheitert. Die Anmeldung wird danach still verworfen, die Wirkung ist also gleich.
- `deleteAccount` ohne gespeichertes Token ruft `onSessionEnded` nicht auf. Das ist spec-konform (R9 nennt nur den Erfolg).

## Offen (nicht Teil von 5a)
- Schnitt 5b (Liste der Lieferungen, „Was Claude sieht“) bleibt Teil von #57.
- Die echte Anmeldung auf dem Gerät wartet auf #56 und Hennings Freigabe.

### Result: PASS
