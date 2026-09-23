# Context: bug-25d-hintergrund-meditation

Workflow-Typ: Full Process · Phase 1 (Context Generation) · erstellt 2026-09-22
Quelle: Issue #25, Cluster D — die zwei roten Tests in `BackgroundMeditationUITests.swift`

## Request Summary

Aus der Bestandsaufnahme #25 (18 von 88 UI-Tests rot) wurde Cluster D als erster Workflow
gewählt: Zwei Tests behaupten, eine laufende Sitzung überlebe den Wechsel in den App-Hintergrund
nicht. Zu klären ist, welcher der beiden Tests eine echte Regression zeigt und welcher nur
veraltete Erwartungen prüft.

## Befund aus dem Original-Lauf (wichtigste Korrektur zum Issue-Text)

Das `.xcresult`-Bündel des Laufs vom 2026-09-22 11:41 existiert noch
(`~/Library/Developer/Xcode/DerivedData/Meditationstimer-…/Logs/Test/Test-Lean Health Timer-2026.09.22_11-41-03-+0200.xcresult`).
Kopien der ausgewerteten Teile liegen unter `docs/artifacts/bug-25d-hintergrund-meditation/`.

**Die Suite hat 88 Tests, nicht 68.** Die Aufteilung lautet:

| Ergebnis | Anzahl |
|---|---|
| Passed | 50 |
| Failed | 18 |
| **Skipped** | **20** |

Die 20 übersprungenen Tests fehlen in #25 vollständig. Sie sind nicht im Schema deaktiviert —
sie überspringen sich per `XCTSkip` selbst, wenn ihre Vorbedingung scheitert. Darunter sind
`test_freeMeditation_backgroundForeground_sessionStillRunning` und
`test_freeWorkout_backgroundForeground_sessionStillRunning`, also genau die zwei Tests, die
freie Meditation und freies Workout im Hintergrund prüfen sollten.

**`test_backgroundForeground_sessionStillRunning` reproduziert den Fehler.** `run-uitests.sh`
läuft mit `-retry-tests-on-failure -test-iterations 3`; das Protokoll zeigt drei Durchläufe:

| Durchlauf | Abbruchstelle | Meldung |
|---|---|---|
| 1 | Zeile 186 | `Session konnte nicht gestartet werden` — der Health-Zugriff-Dialog fing den Tap auf den Start-Button ab (Muster aus #24) |
| 2 | Zeile 215 | `BUG AKTIV: Session wurde beim Hintergrund-Wechsel beendet` |
| 3 | Zeile 215 | dieselbe Meldung |

Die Zusammenfassung des Bündels meldet nur den Text aus Durchlauf 1 — daher die irreführende
Doppelnennung „:186 / :215" in #25. In zwei von drei Durchläufen startet die Sitzung sauber,
der Home-Knopf wird gedrückt, die App wird reaktiviert — und der Start-Knopf ist wieder da.
Das ist eine belastbare Reproduktion.

## Related Files

| Datei | Relevanz |
|---|---|
| `LeanHealthTimerUITests/BackgroundMeditationUITests.swift` | 342 Zeilen, 5 Tests. Enthält beide roten und beide übersprungenen Tests |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | Zeilen 681–682 und 807–816: der scenePhase-Guard aus #7, unverändert seit 2026-04-22 |
| `Meditationstimer iOS/Tabs/MeditationTab.swift` | Der tatsächlich benutzte Meditations-Tab. Zeilen 69–79: die sechs Atem-Voreinstellungen. Kein scenePhase-Bezug im ganzen File |
| `Meditationstimer iOS/Tabs/AtemView.swift` | `SessionCard` der Atemübung. Zeile 567 Kommentar: „scenePhase-Automatik entfernt – führte zu unerwünschten Beendigungen beim App-Wechsel" |
| `Meditationstimer iOS/Tabs/WorkoutTab.swift` | Freies Workout, kein scenePhase-Bezug |
| `Meditationstimer iOS/Tabs/OffenView.swift`, `Tabs/WorkoutsView.swift` | Toter Code — in `ContentView` nicht instanziiert, nur in `#Preview` |
| `Services/TwoPhaseTimerEngine.swift` | Rechnet aus absoluten `Date`-Werten, ist also hintergrundfest. Timer dient nur der Bildschirmaktualisierung |
| `Meditationstimer iOS/BackgroundAudioKeeper.swift` | Stiller Dauerton, hält die Audio-Sitzung wach; genutzt von `MeditationTab` |
| `Meditationstimer iOS/LiveActivityController.swift` | Dynamic Island / Live Activity, gemeinsames Objekt mit `ownerId`-Konflikterkennung |

## Der Stand der beiden roten Tests

### Test 1 — `test_backgroundForeground_sessionStillRunning` (Zeile 183)

Prüft **nicht** Meditation, sondern das **geführte Workout**: Workout-Tab → erste Karte →
Start → Home → zurück → Start-Knopf darf nicht wieder da sein. Der Hintergrund-Wechsel steht
inline im Test (Zeilen 196–208), nicht im gemeinsamen Hilfsblock. Bei Startfehler bricht er
hart ab statt zu überspringen — deshalb ist er der einzige der vier, der überhaupt sichtbar rot
werden kann.

### Test 2 — `test_breathingExercise_backgroundForeground_sessionStillRunning` (Zeile 277)

Scheitert im Hilfsblock `startBreathingExercise()` (Zeile 149, `XCTFail("Kein Atem-Preset
gefunden")`), bevor irgendein Hintergrund-Wechsel stattfindet. Der Block sucht nach den
Beschriftungen `"4-7-8"`, `"Box"` und `"Wim Hof"`. Die App kennt aber sechs ganz andere Namen:
`"Box Breathing"`, `"Calming Breath"`, `"Coherent Breathing"`, `"Deep Calm"`,
`"Relaxing Breath"`, `"Rhythmic Breath"` (`MeditationTab.swift:69–79`, hartkodierte englische
Literale, laufen über `Text(preset.name)` ohne Katalog-Nachschlag, also in jeder Sprache gleich).
`app.buttons["Box"]` findet `"Box Breathing"` nicht. Dieser Test konnte nie grün sein.

Zusätzlich: Der Hilfsblock ruft `XCTFail` und gibt dann `false` zurück, worauf der Test
`XCTSkip` wirft. `XCTFail` hat den Lauf zu diesem Zeitpunkt aber schon als gescheitert markiert —
der Test ist rot *und* übersprungen.

## Existing Patterns

- **Der Guard aus #7:** `@Environment(\.scenePhase)` → `.onChange` setzt `isInBackground` →
  `.onDisappear` prüft `guard !isInBackground`. Existiert **nur** in `WorkoutProgramsView`.
- **Die anderen drei Timer-Ansichten** haben den Guard bewusst *nicht*: In `AtemView` und
  `WorkoutsView` steht derselbe Kommentar, die scenePhase-Automatik sei entfernt worden, weil sie
  zu unerwünschten Beendigungen führte. Ihre `.onDisappear` beenden nur Töne und Bildschirmsperre.
- **Keine `accessibilityIdentifier`** in irgendeiner Timer-Ansicht. Tests greifen über
  `accessibilityLabel` („Start", „Pause") und über Tab-Beschriftungen zu — die Falle aus #21/#27.
- **Hintergrund-Audio** wird an vier Stellen unabhängig voneinander konfiguriert
  (`BackgroundAudioKeeper`, `WorkoutSoundPlayer`, `AtemView`, `WorkoutProgramsView`).

## Vorgeschichte: Bug #7

`530ebd5` (2026-04-22) baute den Guard ein, Tests liefen danach grün — unter **Xcode 26.0.1**.
Am selben Abend, **nach** dem Abschluss des Workflows (21:48, `a081b24`), wurden drei weitere
Tests nachgeschoben, darunter der Atem-Test. Für diese drei gibt es keinen Beleg, dass sie je
grün liefen. Seither wurde **keine einzige App-Quelldatei geändert** — nur Tests, CI, Skripte,
Doku. Heute läuft die Suite unter **Xcode 27.0 / iOS 26.5**.

Der Abschluss von #7 trug das Adversary-Urteil `AMBIGUOUS`. Zwei Findings wurden als Issues
ausgelagert und sind offen:

- **#13** — „scenePhase-Guard ist timing-abhängig": Feuert SwiftUI `onDisappear` vor dem
  scenePhase-Update, greift der Guard nicht. Die Reihenfolge ist undokumentiert.
- **#14** — Zombie-Sitzung bei Deep-Link während Hintergrund.

## Offene verwandte Issues

| Issue | Inhalt | Bezug |
|---|---|---|
| **#15** | „Meditation stirbt im Hintergrund" — Sitzung endet, Dynamic Island wird zum Zombie ohne Bezug zur Oberfläche | Der eigentliche Produktfehler, von #7 nie abgedeckt. Von keinem laufenden Test geprüft |
| **#13** | scenePhase-Guard timing-abhängig | Sagt genau das Verhalten voraus, das der Test jetzt zeigt |
| **#14** | Zombie-Sitzung bei Deep-Link | Betrifft dieselbe Stelle |
| **#24** | Health-Dialog blockiert beim ersten Start | Erklärt Durchlauf 1 des roten Tests |
| **#27** | >90 Tab-Zugriffe über sichtbare Beschriftung | Betrifft auch `BackgroundMeditationUITests` |
| **#2** (geschlossen) | „17 geskippte UI Tests reparieren" | Dasselbe Muster wie die heutigen 20 Skips |

## Recherche zur Plattform

Zur Umgebungsänderung Xcode 26.0.1 → 27.0 und iOS 18.5 → 26.5:

- iOS 26 verwaltet Prozess-Lebenszyklen strenger; Hintergrund-Absichten, die nur
  testmanagerd-Zusicherungen halten, werden bereits nach ~1,2 s eingesammelt
  ([pymobiledevice3 #1666](https://github.com/doronz88/pymobiledevice3/issues/1666)).
- `XCUIApplication.state` meldet unter iOS 26.2 teils `runningForeground` für die falsche App
  ([callstack/agent-device #2696](https://github.com/callstack/agent-device/issues/2696)).
- Entwickler berichten, dass UI-Tests, die unter Xcode 26.0 fehlerfrei liefen, ab Xcode 26.1/26.2
  auf iOS 26 fehlschlagen ([Apple Forum 812307](https://developer.apple.com/forums/thread/812307)).
- Hintergrund-Audio hält eine App nur wach, wenn `UIBackgroundModes: audio` gesetzt ist und
  tatsächlich Samples fließen ([Apple Forum 746319](https://developer.apple.com/forums/thread/746319)).

Das heißt: Eine Änderung des Testverhaltens allein durch die neue Umgebung ist plausibel und muss
in der Analyse von einer echten App-Regression getrennt werden.

## Dependencies

- **Upstream:** SwiftUI-Lebenszyklus (`scenePhase`, `onDisappear`), ActivityKit, AVAudioSession,
  HealthKit-Berechtigung
- **Downstream:** HealthKit-Einträge (falsche Dauer bei vorzeitigem Ende), Streaks,
  Live Activity, Bildschirmsperre, Watch-Abgleich

## Existing Specs

- `openspec/specs/bug-7-background-meditation.md` — Spec zu #7, inklusive ausdrücklicher
  Abgrenzung: „Background-Recovery für alle 4 Views" war ausdrücklich nicht im Umfang
- `docs/artifacts/bug-background-meditation/analysis.md` — Analyse zu #7 mit der Prüfung aller
  vier Timer-Ansichten

## Risks & Considerations

1. **Zwei verschiedene Probleme in einem Cluster.** Test 1 zeigt Verhalten der App, Test 2 zeigt
   falsche Erwartungen im Test. Ein gemeinsamer Fix gibt es nicht.
2. **Die Reproduktion ist noch nicht selbst gefahren.** Der Befund stammt aus einem Protokoll vom
   Vormittag, nicht aus einem eigenen Lauf. Vor jeder Ursachenaussage muss der Fehler in dieser
   Sitzung eigenhändig ausgelöst werden.
3. **Der Health-Dialog verfälscht den ersten Durchlauf** (#24). Jede Messung muss entweder den
   Dialog vorab abräumen oder die erste Iteration verwerfen.
4. **Zwanzig stille Skips.** Solange Tests sich bei Startfehlern selbst überspringen, behauptet
   die Suite Grün, wo nichts geprüft wurde. Das betrifft auch die beiden Geschwistertests dieses
   Clusters und ist der Grund, warum #15 nie auffiel.
5. **#15 ist der eigentliche Produktfehler und bleibt unberührt,** wenn dieser Workflow nur die
   zwei Tests repariert. Die Abgrenzung gehört in die Spec.
6. **Der Guard sitzt nur an einer von vier Stellen.** Ob das Absicht ist (die Kommentare in
   `AtemView` und `WorkoutsView` sprechen dafür) oder Lücke, muss die Analyse klären.
7. **Umfangsgrenze.** Alle vier Ansichten hintergrundfest zu machen sprengt 4–5 Dateien und
   ±250 LoC. Falls die Analyse dorthin führt, muss vorher aufgeteilt werden.

---

# Analysis

**Erstellt:** 2026-09-22, Phase 2 (`/20-analyse #25`)

## Type

**Bug** — echte Produktregression in der App, nicht nur veraltete Testerwartung.
Der Cluster enthält zusätzlich reine Testschulden; die werden abgetrennt (siehe „Abgrenzung").

## Reproduktion (in dieser Sitzung selbst gefahren)

Lauf vom 2026-09-22, `./Scripts/run-uitests.sh "BackgroundMeditationUITests/test_backgroundForeground_sessionStillRunning"`,
iPhone 17 Pro / iOS 26.5 / Xcode 27.0:

| Durchlauf | Dauer | Ergebnis |
|---|---|---|
| 1 | 43,4 s | FAILED, Zeile 215 |
| 2 | 33,5 s | FAILED, Zeile 215 |
| 3 | 35,2 s | FAILED, Zeile 215 |

Alle drei mit identischer Meldung: „BUG AKTIV: Session wurde beim Hintergrund-Wechsel beendet."
Der Health-Dialog (#24) hat diesmal **keinen** Durchlauf gestört — anders als im Vormittagslauf.

**Korrektur zu Issue #13:** Der Fehler ist **deterministisch, nicht timing-abhängig.**
3 von 3 heute, 2 von 2 am Vormittag (der dritte kam nie bis zur Prüfung). Die
Wettrennen-Hypothese aus #13 ist damit als Erklärung überholt — unter iOS 26.5 feuert
`onDisappear` schlicht immer vor dem scenePhase-Update.

## Root Cause

Die Workout-Sitzung ist an den **Lebenszyklus der Bildschirmansicht** gekoppelt.
SwiftUI baut Ansichten ab, sobald die App in den Hintergrund geht, und ruft dabei
`onDisappear` — das ist dokumentiertes Verhalten, kein Fehler von SwiftUI.

`Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:807-817`:

```
.onChange(of: scenePhase) { _, newPhase in
    isInBackground = (newPhase == .background)
}
.onDisappear {
    // Kommentar Zeile 812 behauptet: "onChange fires before onDisappear"
    guard !isInBackground else { return }
    Task { await endSession(manual: true) }
}
```

Der Kommentar in Zeile 812 formuliert eine **Annahme über die Ausführungsreihenfolge
zweier SwiftUI-Callbacks**, die Apple nirgends zusichert und die der Code auch nicht
erzwingt: kein direktes Lesen von `scenePhase` im `onDisappear`, kein Abgleich mit
`UIApplication.shared.applicationState`, kein Debounce.

Greift der Guard nicht, läuft `endSession(manual: true)` (Zeilen 941-1004): Live Activity
beenden, HealthKit-Eintrag schreiben, dann `close()` (1003) → `runningSet = nil` in der
Elternview (Zeile 479) → Start-Knopf wieder sichtbar.

**Warum es früher grün war:** Seit Commit `530ebd5` (2026-04-22, Bug #7) wurde keine
einzige App-Quelldatei geändert. Damals Xcode 26.0.1 / iOS 18.5, heute Xcode 27.0 / iOS 26.5.
Nicht die App hat sich geändert, sondern die Reihenfolge, in der das Betriebssystem die
beiden Callbacks auslöst. Der Guard war immer eine Wette; sie ging bis iOS 18.5 auf.

## Der entscheidende Zusatzbefund

**Der `onDisappear`-Aufruf von `endSession` ist redundant.** Es gibt in dieser Ansicht
keinen weiteren Weg wegzunavigieren, den er abfangen müsste:

- Die Session-Card ist ein ZStack-Overlay — kein `NavigationLink`, keine Push-Navigation,
  keine Zurück-Wisch-Geste.
- Die Tab-Leiste wird während der laufenden Sitzung ausgeblendet (`WorkoutProgramsView.swift:568`).
- `runningSet` wird ausschließlich über `close()` geleert, und `close()` wird nur aus
  `endSession()` selbst oder dem Effort-Sheet gerufen.
- Beide regulären Enden rufen `endSession` bereits direkt: der Abbruch-Knopf (Zeilen 766-771)
  und der natürliche Abschluss über `onSessionEnd` (Zeile 729).

Der Block kann also ersatzlos entfallen, ohne dass ein Aufräumpfad verloren geht.

## Präzedenzfall im eigenen Code

`Meditationstimer iOS/Tabs/WorkoutsView.swift:66` und `Meditationstimer iOS/Tabs/AtemView.swift:567`
tragen wortwörtlich denselben Kommentar:

> „scenePhase-Automatik entfernt – führte zu unerwünschten Beendigungen beim App-Wechsel"

Dort wurde genau dieses Problem schon einmal erlebt und durch **ersatzlose Streichung**
gelöst, nicht durch einen Guard. `WorkoutsView.onDisappear` (Zeilen 301-306) räumt nur Töne,
Timer und Bildschirmsperre auf und ruft kein `endSession`. Für diese beiden Ansichten ist
kein Hintergrund-Fehler gemeldet.

## Recherche (Quellen)

- [Apple Developer Forums 748576](https://developer.apple.com/forums/thread/748576) — „when app
  goes to background, viewWillDisappear is getting called… it destroys the view when app goes to
  background and recreate it when app comes to foreground". SwiftUI-Views werden beim
  Hintergrund-Wechsel abgebaut; `onDisappear` feuert dabei.
- [Jesse Squires, SwiftUI app lifecycle: issues with ScenePhase](https://www.jessesquires.com/blog/2024/06/29/swiftui-scene-phase/)
  — dokumentierte Unzuverlässigkeiten von `scenePhase`.
- [Hacking with Swift — scenePhase](https://www.hackingwithswift.com/quick-start/swiftui/how-to-detect-when-your-app-moves-to-the-background-or-foreground-with-scenephase)
- Apple, WWDC 2020: „the lifecycle of a view is separate from the lifecycle of the structure
  that defines it." Sitzungs-Lebensdauer gehört nicht an den View-Lebenszyklus.
- [Stack Overflow 62932310](https://stackoverflow.com/questions/62932310/xcuitest-to-background-the-app-is-returning-the-wrong-xcuiapplication-state)
  — Hintergrund-Wechsel im UI-Test ist asynchron; `app.wait(for:timeout:)` statt fester Wartezeiten.

## Geprüfte Alternativen

| # | Ansatz | Umfang | Bewertung |
|---|---|---|---|
| **A** | Guard härten: `scenePhase` direkt im `onDisappear` lesen oder `applicationState` prüfen | 1 Datei, ~5-10 LoC | **Abgelehnt.** Dieselbe Wette auf undokumentiertes Verhalten, nur neu parametrisiert. Ist zwischen iOS 18.5 und 26.5 schon einmal still gebrochen — kann bei der nächsten Version wieder brechen. |
| **B** | Kopplung auflösen: `onChange(of: scenePhase)`, `isInBackground` und den `onDisappear`-Block ersatzlos entfernen | 1 Datei, ~10-12 LoC **entfernt**, keine neue Logik | **Empfohlen.** Behebt die Ursache, führt keinen neuen Code ein, folgt dem im Projekt bereits etablierten Muster. |
| **C** | Sitzung in ein vom View unabhängiges Modell/Service ziehen | 2-3 Dateien, 300-500+ LoC | **Abgelehnt für diesen Fix.** Architektonisch der Idealzustand, sprengt die Umfangsgrenze (4-5 Dateien / ±250 LoC) klar. Hat entgegen erster Annahme **kein** erprobtes Vorbild im Projekt: Die Meditation nutzt `BackgroundAudioKeeper` als Prozess-Überlebens-Trick, nicht als Architektur-Entkopplung — und #15 zeigt, dass das dort gerade nicht zuverlässig funktioniert. Gehört als eigenes Architektur-Vorhaben in ein separates Ticket. |
| **D** | Nur die Testerwartung ändern | 1 Testdatei | **Abgelehnt.** Die Reproduktion ist deterministisch und bildet alltägliches Nutzerverhalten ab (Home-Knopf während eines Workouts). Das würde nur das CI-Signal verfälschen und das Produktverhalten unangetastet lassen. |

## Empfehlung

**Alternative B.** Den Block `onChange(of: scenePhase)` / `isInBackground` / `onDisappear →
endSession` in `WorkoutProgramSessionCard` ersatzlos entfernen.

Gekippt wird damit die Entscheidung aus **Bug #7**, die genau diesen Guard eingeführt hat.
Das Adversary-Urteil von #7 lautete seinerzeit `AMBIGUOUS` — der Zweifel war also schon
damals protokolliert und ist jetzt belegt. **Issue #13 wird damit gegenstandslos**, nicht
nur „vermutlich behoben": Ohne Guard gibt es kein Reihenfolge-Problem mehr.

## Affected Files

| Datei | Change Type | Beschreibung |
|---|---|---|
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | MODIFY | Zeilen 681-682 und 807-817: Guard-Konstrukt ersatzlos entfernen |
| `openspec/specs/bug-7-background-meditation.md` | MODIFY | Entscheidung revidieren, Abgrenzung zu #13/#14/#15 ergänzen |
| `LeanHealthTimerUITests/BackgroundMeditationUITests.swift` | UNCHANGED | `test_backgroundForeground_sessionStillRunning` ist bereits der RED-Test und dient als Akzeptanzkriterium; `test_explicitStop_endsSession` sichert den expliziten Stop-Pfad ab |

## Scope Assessment

- **Dateien:** 2 (eine Quelldatei, eine Spec)
- **Geschätzte LoC:** +0 / −12
- **Risiko: NIEDRIG** — es wird ausschließlich Code entfernt, kein neuer eingeführt. Der
  entfernte Pfad ist nachweislich redundant. Das Muster ist im Projekt an zwei anderen
  Stellen bereits so gelebt.

## Abgrenzung — was dieser Fix NICHT behandelt

- **#15 „Meditation stirbt im Hintergrund"** — andere Ansicht, anderer Mechanismus. Bleibt offen.
- **#14 „Zombie-Sitzung bei Deep-Link"** — bleibt offen, wird durch den Fix weder gelöst noch verschärft.
- **Freies Workout und Atemübung** — dort existiert der Fehler nicht, weil die automatische
  Beendigung dort bereits fehlt.
- **Testschulden der Klasse** (falsche Atem-Preset-Namen, fehlendes Springboard-Handling für
  den nativen HealthKit-Dialog) — eigenes Ticket.
- **Fehlende Hintergrund-Audio-Absicherung des geführten Workouts** — eigenes Ticket.

Die Spec muss diese Abgrenzung ausdrücklich führen, damit niemand aus ihr ableitet, das
Hintergrund-Problem sei app-weit gelöst.

## Nebenbefund: Das Testskript meldet Grün bei null Tests

Beim ersten Reproduktionsversuch lief `./Scripts/run-uitests.sh "BackgroundMeditationUITests"`
durch und meldete „✅ ALLE TESTS BESTANDEN" — **ohne einen einzigen Test auszuführen.**

Ursache: `Scripts/run-uitests.sh` Zeilen 120-126. Enthält das Argument keinen `/`, wird die
Default-Klasse davorgehängt. Aus `BackgroundMeditationUITests` wurde der Filter
`-only-testing:LeanHealthTimerUITests/LeanHealthTimerUITests/BackgroundMeditationUITests`,
also „Klasse `LeanHealthTimerUITests`, Methode `BackgroundMeditationUITests`". Die gibt es
nicht. `xcodebuild` meldet für null ausgeführte Tests `** TEST SUCCEEDED **`.

Das ist dasselbe Muster wie die 20 stillen Skips: Das Werkzeug beruhigt, ohne geprüft zu
haben. Besonders heikel im Hinblick auf **#20** (Merge nur bei grüner CI). Eigenes Ticket.

## Offene Fragen

- [ ] Keine, die die Umsetzung blockieren. Die Reproduktion steht, die Ursache ist belegt,
      der Weg ist entschieden.
