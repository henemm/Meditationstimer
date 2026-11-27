---
entity_id: fix-122-programm-freigabe
type: bugfix
created: 2026-11-27
updated: 2026-11-27
status: draft
workflow: fix-122-programm-freigabe
---

# Fix 122: Workout-Programm prüft die Health-Schreibfreigabe und meldet Schreibfehler (#122)

## Approval

- [ ] Approved

## Purpose

Ein geführtes Workout-Programm startet heute ohne Prüfung der Health-Schreibfreigabe. Fehlt sie, entsteht kein Health-Eintrag
und keine Serie, ohne dass die App es sagt. Künftig fragt die App vor dem Start (nie gefragt), weist bei verweigerter
Freigabe mit Rückfrage hin (Programm bleibt startbar) und meldet einen Schreibfehler nach dem Ende, statt ihn zu
verschlucken.

## Source

| Feld | Wert |
|------|------|
| Entity | `fix-122-programm-freigabe` |
| Spec-Datei | `DOCS/specs/bugfix/fix-122-programm-freigabe.md` |
| Kontext & Analyse | `DOCS/context/fix-122-programm-freigabe.md` (Abschnitte "Analysis", "Varianten", "PO-Entscheidung" maßgeblich) |
| Entwurf | `docs/artifacts/fix-122-programm-freigabe/` (vom PO am 2026-11-27 freigegeben) |
| Gewählte Variante | V2: `authorizationStatus(for: .workoutType())`, nur Programm-Weg |
| Folge-Ticket | #129 (freies Workout, Meditation, `logWorkoutsAsMindfulness`) |

## Root Cause

Reproduziert am 2026-11-26 im Simulator: frischer Simulator, nur Achtsamkeit freigegeben, Tabata Classic gespielt, danach
0 Workouts, healthd meldet `HKWorkoutBuilder ... Active -> Discarded`. Mit voller Freigabe entsteht 1 Workout.

1. Der Programmstart (`WorkoutTab.swift` ca. Z. 95, `play: { runningSet = set }`) prüft nichts. Das freie Workout
   (`startFreeWorkout()`, Z. 351-362) fragt dagegen vorher.
2. `WorkoutProgramsView.swift` kennt weder `requestAuthorization()` noch `isAuthorized()`.
3. Schreibfehler werden verschluckt: der `catch` in `logSession()` (ca. Z. 744) tut nur `print` und liefert `false`, die
   Karte schließt ohne Hinweis.
4. `isAuthorized()` (`getRequestStatusForAuthorization == .unnecessary`) heißt nur "schon gefragt", nicht "Schreiben erlaubt".
   Verweigerung bleibt damit unerkannt. Verlässlich für Schreibtypen ist
   `HKHealthStore.authorizationStatus(for: .workoutType())` mit `.notDetermined`, `.sharingDenied`, `.sharingAuthorized`
   (Apple-Doku; Quellen im Kontextdokument).

Betroffene Fälle: (a) nie gefragt, (b) verweigert, (c) später entzogen, (d) Schreibfehler nach der Sitzung.

## Affected Files

- `Services/HealthKitManager.swift` (MODIFY, ca. +10 Z.: `workoutShareStatus()`, dünner Wrapper um
  `authorizationStatus(for: .workoutType())`; dort oder in eigener kleiner Datei die reine Entscheidungsfunktion, ca. +15 Z.)
- `Meditationstimer iOS/Tabs/WorkoutTab.swift` (MODIFY, ca. +50-60 Z.: Prüfung im `play`-Closure, Rückfrage (b)/(c),
  Anbindung an den bestehenden "Health Access"-Alert)
- `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` (MODIFY, ca. +30-40 Z.: Fehler-Alert, Karte schließt nach Bestätigung)
- `Meditationstimer iOS/Localizable.xcstrings` (MODIFY, ca. +20-30 JSON-Z.: neue Texte DE und EN)

Geplant ca. 125-155 Z. App-Code in 4 Dateien (Grenze 250; Tests zählen nicht). Jede neue Funktion unter 50 Z.
`isAuthorized()` bleibt unverändert (Meditation und CalendarView hängen daran).

## Expected Behavior

### Entscheidungsfunktion (rein, ohne HealthKit)

| Status | Aktion |
|--------|--------|
| `.notDetermined` | `.askPermission` |
| `.sharingDenied` | `.showSettingsHint` |
| `.sharingAuthorized` | `.start` |

### Ablauf beim Tippen auf "Start" eines Programms

1. **Fall (a), nie gefragt:** der bestehende Alert wie beim freien Workout (`WorkoutTab.swift` Z. 174-191), Titel
   "Health Access" / "Health-Zugang", Buttons "Cancel"/"Abbrechen" und "Allow"/"Erlauben". "Erlauben" ruft
   `requestAuthorization()` auf und startet danach das Programm. "Abbrechen": kein Start.
2. **Fall (b)/(c), verweigert:** Rückfrage vor dem Start, **ohne** `requestAuthorization()` (es würde kein Blatt zeigen).
   - Titel: "Training wird nicht gespeichert"
   - Text: "Health darf von dieser App keine Trainings annehmen. Das kannst du in den Einstellungen ändern."
   - Buttons: "Einstellungen" (öffnet `UIApplication.openSettingsURLString`, kein Start) und "Trotzdem starten"
     (Programm startet). Das Programm wird nie gesperrt.
3. **Erlaubt:** Start ohne Dialog.
4. **Schreibfehler nach dem Ende** (`logSession()`): beide Zweige lösen den Hinweis aus, der `catch` und
   ein `nil`-Ergebnis von `logWorkout` bei einem Fehler (ob `logWorkout` bei Verweigerung wirft oder `nil` liefert, wird in
   der Implementierung geprüft und beide Wege werden abgedeckt). **Nicht** bei der Mindestdauer-Überspringung
   (`WorkoutSessionLog.write` -> `.skipped`).
   - Titel: "Nicht in Health gespeichert"
   - Text: "Dieses Training konnte nicht in Apple Health gespeichert werden und zählt daher nicht für deine Serie."
   - Buttons: "Einstellungen" (öffnet die App-Einstellungen) und "OK". Die Karte schließt erst nach Bestätigung.

### Texte EN (Übersetzung)

| DE | EN |
|----|----|
| Training wird nicht gespeichert | Workout won't be saved |
| Health darf von dieser App keine Trainings annehmen. Das kannst du in den Einstellungen ändern. | Health doesn't allow this app to save workouts. You can change this in Settings. |
| Einstellungen | Settings |
| Trotzdem starten | Start Anyway |
| Nicht in Health gespeichert | Not Saved to Health |
| Dieses Training konnte nicht in Apple Health gespeichert werden und zählt daher nicht für deine Serie. | This workout couldn't be saved to Apple Health and won't count toward your streak. |
| OK | OK |

Alle neuen Schlüssel in `Localizable.xcstrings` mit DE und EN, `"extractionState": "manual"` und `"state": "translated"`,
sonst erscheinen sie im Debug-Build in Großbuchstaben. Vorhandene Schlüssel ("Health Access", "Allow", "Cancel", "OK"
falls vorhanden) werden wiederverwendet, nicht doppelt angelegt.

## Out of Scope

- Freies Workout, Meditation und `logWorkoutsAsMindfulness` (Folge-Ticket #129): gleiche (b)/(c)-Lücke dort bleibt
  vorerst bestehen.
- Änderung von `isAuthorized()` oder `requestAuthorization()`; Typenmenge-Abweichung (effortScore) bleibt.
- Eigene Rechteverwaltung, Sperren des Programms bei Verweigerung, Hinweiszeile im laufenden Training (verworfen).
- Hinweis bei Mindestdauer-Überspringung oder bei fehlender Freigabe, die erst mitten in der Sitzung entzogen wird, über den
  Schreibfehler-Hinweis hinaus.

## Acceptance Criteria

- **AC-1 (Entscheidung):** Given die Entscheidungsfunktion / When sie `.notDetermined`, `.sharingDenied`,
  `.sharingAuthorized` bekommt / Then liefert sie `.askPermission`, `.showSettingsHint`, `.start`.
- **AC-2 (a, nie gefragt):** Given Simulator-Health-Zustand zurückgesetzt (Workout nicht entschieden) / When "Start" bei
  einem Programm getippt wird / Then erscheint der Alert "Health Access"; "Allow" -> Health-Blatt -> danach läuft das
  Programm (Countdown, Runde sichtbar). "Cancel": das Programm startet nicht.
- **AC-3 (b, verweigert, Trotzdem starten):** Given Workout-Schreiben verweigert / When "Start" getippt wird / Then
  erscheint "Training wird nicht gespeichert" mit "Einstellungen" und "Trotzdem starten"; es erscheint **kein**
  "Health Access"-Alert und kein System-Blatt; "Trotzdem starten" startet das Programm (läuft nachweislich).
- **AC-4 (b, Einstellungen):** Given dieselbe Rückfrage / When "Einstellungen" getippt wird / Then wird
  `UIApplication.openSettingsURLString` geöffnet und das Programm startet **nicht**.
- **AC-5 (erlaubt):** Given Workout-Schreiben erlaubt / When "Start" getippt wird / Then startet das Programm ohne Dialog.
- **AC-6 (Schreibfehler):** Given ein Programm endet und das Schreiben nach Health schlägt fehl (Logger wirft oder liefert
  `nil` bei Fehler) / When die Sitzung ausgewertet wird / Then erscheint "Nicht in Health gespeichert" mit
  "Einstellungen" und "OK", und die Karte schließt erst nach Bestätigung.
- **AC-7 (kein falscher Alarm):** Given die Sitzung ist kürzer als die Mindestdauer (`.skipped`) oder das Schreiben gelingt /
  When die Sitzung endet / Then erscheint **kein** Fehler-Hinweis.
- **AC-8 (Lokalisierung):** Given `Localizable.xcstrings` / When sie geladen wird / Then ist sie gültiges JSON und jeder neue
  Schlüssel hat DE und EN mit `extractionState: manual` und `state: translated`; im Debug-Build ohne Großbuchstaben.
- **AC-9 (Bestandstests):** Given die bestehenden Tests mit Programmstart (`WorkoutHintUITests` `startPreset()`,
  `WorkoutCountdownUITests` Z. 109, `BackgroundMeditationUITests` `startFirstWorkoutSession()`, `LeanHealthTimerUITests`
  Z. 2029) / When sie laufen / Then sind sie grün, weil sie den optionalen Alert bedienen, ohne ihre eigene Aussage zu
  verlieren.
- **AC-10 (Simulator-Durchlauf, Pflicht):** Given die App im Simulator (iPhone 17 Pro, iOS 27.2) mit dem Stand dieser
  Änderung / When Fall (a), Fall (b) mit "Trotzdem starten" und "Einstellungen", und der Schreibfehler real durchgespielt
  werden / Then verhält sich jeder Fall wie oben; Screenshots und Health-Eintragsstand (Workout vorhanden bzw. nicht) als Beleg.

## Test Plan

Nur Simulator, keine Geräte des PO. UI-Läufe über `Scripts/run-uitests.sh`, Einzeltests nur als `Klasse/Methode`;
ein Lauf zählt nur mit `Executed N tests` und N >= 1.

**Unit (Tests/, `LeanHealthTimerTests`):**

- [ ] Entscheidungsfunktion: drei Zustände -> drei Aktionen (AC-1), vorher ROT.
- [ ] Schreibweg mit Mock-Logger (bestehendes Muster `WorkoutSessionClockTests`, Mock mit `wirft`): wirft -> Fehler-Hinweis
      wird angefordert; `nil` bei Fehler -> ebenso; `.skipped` und Erfolg -> kein Hinweis (AC-6, AC-7). Die Entscheidung
      "Hinweis ja/nein" liegt dafür in einer reinen, testbaren Funktion.

**UI (`LeanHealthTimerUITests`):**

- [ ] Bestehende Programmstart-Tests (AC-9) bedienen den optionalen Alert per `waitForExistence` und "Allow" bzw.
      "Trotzdem starten", je nach Simulator-Zustand.
- [ ] Neu (a): vor dem Lauf `xcrun simctl privacy <udid> reset health <Bundle-ID der App>`; Start -> "Health Access" sichtbar
      -> "Allow" -> `HealthSheetHelper`-Blatt bedient -> Programm läuft (Countdown/Runde sichtbar). Zweiter Test: "Cancel"
      -> Programm läuft nicht.
- [ ] Neu (b): Zustand verweigert herstellen, indem der Test im Health-Blatt "Nicht erlauben" wählt; danach Start ->
      Rückfrage sichtbar, "Health Access" **nicht** sichtbar; "Trotzdem starten" -> Programm läuft; getrennt "Einstellungen"
      -> Programm läuft nicht (Beweis über fehlenden Countdown/Rundenzähler).
- [ ] Machbarkeit des Reset: `run-uitests.sh` hat bisher kein `privacy reset`. Der Reset wird dort als Vorbereitungsschritt
      ergänzt oder die (a)/(b)-Tests laufen über einen eigenen Aufruf; die Abhängigkeit vom Simulator-Zustand ist im
      Testcode dokumentiert. Reihenfolge: (a) und (b) hängen am Zustand "nie gefragt", jeder Test stellt ihn selbst her.

**Nur per Unit-Test und Simulator-Durchlauf prüfbar (ehrlich benannt):**

- [ ] Schreibfehler real (AC-6): ein Programm im Simulator bis zum Ende zu spielen und das Schreiben scheitern zu lassen ist
      im UI-Test nur machbar, wenn sich eine kurze, über die Mindestdauer hinausgehende Sitzung herstellen lässt. Ist das
      nicht verlässlich, ist der Logik-Beweis der Unit-Test (Mock-Logger), und die Alert-Anzeige belegt der
      Simulator-Durchlauf (AC-10) im Zustand "verweigert" mit Screenshot. Wird ein UI-Test dafür gebaut, prüft er, dass der
      Alert erscheint und die Karte erst nach "OK" schließt.
- [ ] Öffnen der Systemeinstellungen (AC-4/AC-6) kann im UI-Test nur indirekt belegt werden (Programm startet nicht, App
      wechselt in den Hintergrund); die aufgerufene URL ist über die Entscheidungsfunktion/Aktion abgesichert.

**Durchlauf:**

- [ ] Simulator-Durchlauf (a), (b), Schreibfehler (AC-10), Screenshots und Health-Stand als Beleg.
- [ ] Build iOS grün; komplette Unit-Suite grün; UI-Suite ohne neue Rotmeldung gegen `main`.

## Risiken

- Bestehende Programm-UI-Tests starten bisher ohne Alert; bei Simulator-Zustand "nie gefragt" blockiert der neue Alert sie.
  Gegenmaßnahme: optionale Alert-Bedienung (AC-9).
- Fall (b)/(c): `requestAuthorization()` darf hier nicht aufgerufen werden (kein Blatt, keine Wirkung).
- Einstellungen öffnen ist nur die App-Einstellungsseite (offizieller Weg); `x-apple-health://` und `App-Prefs:` sind
  undokumentiert bzw. privat und werden nicht benutzt.
- Zwei Alerts am selben Ort (Health Access, Rückfrage) müssen sich nicht überschneiden: nur einer je Start, Entscheidung
  über die reine Funktion.

## Scope

- Dateien: 4 (alle MODIFY), plus Tests, Spec, Kontext
- LoC: ca. 125-155 App-Code
- Risiko: mittel

## Dependencies

| Abhängigkeit | Art | Bedeutung |
|--------------|-----|-----------|
| #129 | Ticket | Folgearbeit: freies Workout, Meditation, Achtsamkeits-Einstellung |
| `WorkoutSessionLog.write`, `WorkoutLogging` | Code | reicht Fehler durch, `logger` ist ersetzbar (Test) |
| `HealthSheetHelper` | Testhilfe | bedient das System-Blatt im UI-Test |
| `StreakManager` | Code | liest Health neu; kein Eintrag, keine Serie |

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine. Alternative V1 (`isAuthorized()` plus bestehender Alert) deckt nur Fall (a) ab; V3 (mit freiem Workout)
sprengt den Ticketrahmen und ist #129. Alternative "Hinweiszeile im laufenden Training" statt Rückfrage vom PO am 2026-11-27
verworfen.

## Definition of Done

- [ ] Entscheidungsfunktion mit Unit-Tests (AC-1)
- [ ] Programmstart in den Fällen (a), (b)/(c), erlaubt wie beschrieben (AC-2 bis AC-5)
- [ ] Schreibfehler-Hinweis, kein falscher Alarm (AC-6, AC-7)
- [ ] Lokalisierung DE/EN (AC-8)
- [ ] Bestehende und neue UI-Tests grün (AC-9)
- [ ] Simulator-Durchlauf belegt (AC-10)
- [ ] #122 kommentiert, #129 verweist auf diese Arbeit

## Changelog

- 2026-11-27: Initial spec created
