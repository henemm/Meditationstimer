# Analyse #51 (B1a) und #57 (B2d): App-Seite der Claude-Verbindung

Stand: 13.11.2026 · Phase 2 (nur lesen) · Epic #44 · Grundlage für die Spezifikation, Umsetzung später am Mac.
Hinweis: GitHub-Issues #48/#51/#57 waren aus der Cloud-Sitzung nicht lesbar; der Inhalt von A2 (#48) ist aus
`claude-lieferformat.md` Zeile 18 und `konzept-claude-verbindung.md` 6.1/6.2 abgeleitet, nicht aus dem Issue.

## 1. Kernbefunde (das Wichtigste zuerst)

1. **Die App hat heute nichts davon:** kein Netzwerkcode, kein Schlüsselbund, kein Sign in with Apple
   (Entitlements nur HealthKit, `Meditationstimer iOS/Meditationstimer iOS.entitlements:5-6`), keine Kennungen, keine Herkunft, keinen Hinweis je Schritt.
2. **A2 (#48) ist im Code nicht angefangen.** Details in Abschnitt 4. Ohne A2 lässt sich #51 nur als reiner Kern bauen
   (prüfen, anwenden, festhalten), nicht als sichtbare Funktion im Training.
3. **Speicherung ist doppelt und fehleranfällig:** Programme und Atemübungen liegen als JSON in `UserDefaults`, jeweils von
   zwei Ansichten unabhängig gelesen und komplett zurückgeschrieben (verlorene Änderungen möglich, wenn von außen geschrieben wird).
   Empfehlung: Claude-Bausteine kommen in einen **eigenen Speicher** und werden in den Listen nur zusammengeführt (Abschnitt 5.1).
4. **Abschrift:** Fassung 2 verlangt `history` als Pflichtfeld (`Contracts/transcript/transcript-v2.schema.json:8-16`); das Tagebuch der
   Einheiten (B3b, #59) gibt es nicht. Empfehlung: #57 sendet **Fassung 1** (der Dienst nimmt sie an, `claude-rueckblick.md:46`), Fassung 2 folgt mit #59.
5. **Testbeispiele:** Am einfachsten über `#filePath` aus `Contracts/` lesen (Vorbild Loose Ends, `LooseEndsTests/TranscriptCodecTests.swift:302`), ohne Projektänderung.
6. **Schalter „nur Entwickler/TestFlight“:** Vorbild Loose Ends ist ein Info.plist-Schlüssel (`LEAccountEnabled`, Standard aus), den nur der
   TestFlight-Bau einschaltet. In diesem Repo gibt es **keine** TestFlight-Pipeline und kein Konzept für Build-Varianten (Abschnitt 3.7).

## 2. Ist-Zustand je Bereich

| Bereich | Stand | Fundstellen |
|---|---|---|
| Workout-Programme (Modell) | `WorkoutSet` (UUID, Name, Emoji, `phases`, `repetitions`, `description?`) und `WorkoutPhase` (UUID, `name`, `workDuration` 1-600, `restDuration` 0-600), beide `Codable`. Übung wird **nur über den Namen** referenziert. Kein Feld für Hinweis, Herkunft, Kennung. | `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:166-216` |
| Workout-Programme (Speicherung) | `UserDefaults`-Schlüssel `workoutProgramSets` (JSON). **Zwei unabhängige Kopien** der Lade-/Speicherlogik: live in `WorkoutTab`, tot-ähnlich in `WorkoutProgramsView` (die View selbst wird nirgends instanziiert; nur ihre Unterstrukturen `SetEditorView`, `PresetInfoSheet`, `WorkoutProgramSessionCard` werden von `WorkoutTab` benutzt). Laden bei jedem `onAppear`, Speichern schreibt das ganze Array. | `Tabs/WorkoutTab.swift:44,165-166,362-395,142-164,242`; `Tabs/WorkoutProgramsView.swift:483,610-654` |
| Mitgelieferte Programme | `defaultWorkoutSets` ist `private let` **je Datei**: `WorkoutProgramsView` hat 10, `WorkoutTab` (live) nur 4 (Tabata Classic, Core Circuit, Full Body Burn, Quick Burn). Konzept und Doku sagen „10". Frische Installation sieht also 4. Die UUIDs der Vorgaben werden **bei jedem Prozessstart neu gewürfelt**; Identität der Vorgaben ist nur der Name (`migrateSets` gleicht per Name ab). | `Tabs/WorkoutTab.swift:813-866`; `Tabs/WorkoutProgramsView.swift:306-468,621-648` |
| Atemübungen | Live-Modell ist `AtemView.Preset` (UUID, Name, Emoji, 4 Zeiten, `repetitions`, `description?`, `Codable`). `UserDefaults`-Schlüssel `atemPresets`. Wieder zwei Kopien: `AtemView` (Liste nur als Typen-Lieferant) und `MeditationTab` (live), mit je eigener Liste der 6 Vorgaben. `Models/BreathPreset.swift` ist ungenutzt. | `Tabs/AtemView.swift:58-90,178-191,203-252`; `Tabs/MeditationTab.swift:26-29,69-82,462-495,171-191` |
| Übungsdatenbank | 43 `ExerciseInfo` (Name, Kategorie, Wirkung, Anleitung, `notes?`), **Schlüssel ist der deutsche Name**, keine Kennung. Bilaterale Übungen: Fallback entfernt Suffix „ links/rechts/Left/Right". `ExerciseCategory` hat **deutsche Rohwerte** („Kraft" …), das Lieferformat verlangt `strength` … | `Services/ExerciseDatabase.swift:14-41,44`; `Models/ExerciseInfo.swift:11-61`; Abruf nur über Name: `Views/ExerciseDetailSheet.swift:15-20` |
| Vorschlagsliste im Editor | Zweite, **abweichende** Liste: 60+ **englische** Namen, `private`, im Phasen-Editor als Auswahl. Viele treffen die Datenbank nicht („Plank" gegenüber „Planke"), die Info-Ansicht findet dann nichts. Freitext möglich (`isCustom`). | `Tabs/WorkoutProgramsView.swift:221-302,1912-2025` (Editor), `1930,1955` |
| Ansage/Anzeige im Training | `speakExerciseNames` (`@AppStorage`) sagt den Namen an, sonst nichts. Kein Platz für Hinweis. | `Tabs/WorkoutProgramsView.swift:687,930,1441`; Einstellung `SettingsSheet.swift:164-166` |
| Smarte Erinnerungen | `SmartReminder` (UUID, Titel, Text, `hoursInactive`, `triggerTime: Date`, `selectedDays`, `activityType` mindfulness/workout/noalc, optional `trackerID`/`trackerName`). Singleton `SmartReminderEngine.shared`, `@AppStorage("smartReminders")`, Planung über `UNNotificationRequest`, BG-Task-Kennung in Info.plist. Kein Ziel auf Programm/Atemübung, keine Herkunft. **Nicht Teil von #51/#57** (B4b, #61). | `Models/SmartReminder.swift:38-60`; `SmartReminderEngine.swift:17-64,322-412`; `Meditationstimer-iOS-Info.plist:5-8` |
| Tracker | SwiftData (`@Model Tracker`, `TrackerLog`), Container nur mit diesen zwei Typen, **kein VersionedSchema/Migrationsplan**; Container-Anlage in `App.init`, bei `enable-testing` im Speicher. **Nicht Teil von #51/#57** (B5b/B6b). | `Services/TrackerModels.swift:199-243,439-453`; `Meditationstimer_iOSApp.swift:32-50` |
| Streaks | `StreakManager` (`@Published`, nur `currentStreakDays`, kein „längste"). Relevant erst für Abschrift Fassung 2. | `Meditationstimer iOS/StreakManager.swift:12,54-55` |
| Persistenz gesamt | `UserDefaults`/`@AppStorage` für Programme, Atemübungen, Erinnerungen, Einstellungen; SwiftData nur für Tracker; HealthKit für Verlauf. Keine Dateien in Application Support. | siehe oben |
| Netzwerk/Keychain/Sign in | **Nichts vorhanden.** Keine Treffer für `URLSession`, `Security`/`SecItem`, `AuthenticationServices` im App-Code. Keine `PrivacyInfo.xcprivacy`. | Suche über `Meditationstimer iOS/`, `Services/` |
| Entitlements | Nur `com.apple.developer.healthkit`. **Eine** Datei für Debug und Release. Sign in with Apple fehlt. | `Meditationstimer iOS/Meditationstimer iOS.entitlements`; `Meditationstimer.xcodeproj/project.pbxproj:932,970` |
| Build-Konfigurationen | Nur `Debug` und `Release`; Kennzeichen `DEBUG` (`SWIFT_ACTIVE_COMPILATION_CONDITIONS`). Kein TestFlight-Kennzeichen, keine `.xcconfig`. Bundle-ID **`henemm.Meditationstimer-iOS`**, Team `XK87E2B3VR`, Version 3.2.0, iOS 18.5. Info.plist: Datei `Meditationstimer-iOS-Info.plist` plus generierte Schlüssel. | `project.pbxproj:721,778,932-1002` |
| Projektaufbau | `Meditationstimer iOS/`, `LeanHealthTimerTests/`, `LeanHealthTimerUITests/` sind **synchronisierte Gruppen** (neue Dateien werden automatisch Mitglied). Das Verzeichnis `Services/` im Repo-Wurzelordner ist dagegen eine **klassische Gruppe mit Einzeldateien**: neue Dateien dort brauchen Projektänderung am Mac und Zielzuordnung (Watch/Widget teilen einzelne Dateien). Gruppe `Tests/` ist synchronisiert, aber leer (CLAUDE.md nennt sie fälschlich als Testort). | `project.pbxproj:146-184,294-311` |
| Testziele | `LeanHealthTimerTests` (XCTest, `@testable import Lean_Health_Timer`, **Host-App** über `TEST_HOST`, `SWIFT_APPROACHABLE_CONCURRENCY=YES`), `LeanHealthTimerUITests` (Start mit `enable-testing`). CI führt nur Unit-Tests aus (`ios-tests.yml:43-50`), Xcode **26.6** (nicht 27 wie CLAUDE.md). | `project.pbxproj:361-383,881-925`; `.github/workflows/ios-tests.yml:19` |
| Testressourcen | Das Testziel hat eine Resources-Phase und die synchronisierte Gruppe `LeanHealthTimerTests/`: Dateien **dort** landen automatisch im Test-Bundle. `Contracts/` liegt außerhalb und enthält `node_modules` (tausende Dateien), taugt also nicht als synchronisierte Gruppe. | `project.pbxproj:361-383` |
| Swift-Concurrency-Stil | `SWIFT_VERSION = 5.0` in allen Zielen (Swift-5-Modus, kein strenges Checking). Muster: `ObservableObject`/`@Published`/`@StateObject`/`@EnvironmentObject` (nur 8 `@Observable`/`ObservableObject`-Typen in Services, Rest in Views), Singletons (`SmartReminderEngine.shared`, `TrackerManager.shared`), `Task { await … }` aus Views, `@MainActor` vereinzelt, `nonisolated` nur am Notification-Delegate. Kein Strict Concurrency, kein `actor` eigener Bauart. | `Meditationstimer_iOSApp.swift:84-97,133-155`; `ContentView.swift:118-127` |
| Einstellungsseite | `SettingsSheet` ist ein `Form` mit `Section`s; `NavigationLink` zu `SmartRemindersView` liegt bei Zeile 195. Natürlicher Platz für „Claude-Verbindung". | `SettingsSheet.swift:164-203` |

### Zum Loose-Ends-Vorbild (`/home/user/henemm/loose-ends/LooseEnds/`)

| Baustein | Datei | Übernehmbar? |
|---|---|---|
| Schalter | `Claude/AccountWiring.swift:11-52` (Info-Schlüssel `LEAccountEnabled` muss echtes Bool sein, Standard aus; `--ui-testing` schaltet ein; `LEServiceURL` nur https, http nur `localhost` im Debug-Bau); Einschalten im Archiv per `plutil -replace … -bool YES` nur im TestFlight-Workflow (`.github/workflows/testflight.yml:34-38,118`) | Muster ja, Namen `HH…` |
| Anmeldung | `Claude/Nonce.swift` (32 Zufallsbytes base64url; Apple bekommt SHA-256-Hex, der Dienst den Rohwert, passt zu `server/src/apple.ts:69-78`), `Claude/AccountState.swift` (Zustände signedOut/signingIn/signedIn/deleting/notAllowed/retryLater, Sperre gegen Doppelstart), `Views/AccountSection.swift` (Apple-Knopf ohne Scopes, Stand-in-Knopf unter Test) | ja, fast unverändert |
| Sitzung | `Claude/KeychainSessionStore.swift` (Generic Password, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, Data-Protection-Keychain, Protokoll `KeychainOperations` für Tests), `Claude/DeviceIdentity.swift` (Geräte-UUID in eigenem Schlüsselbundeintrag für `X-Device`) | ja |
| Dienstzugriff | `Claude/ServiceClient.swift` (`HTTPTransport`-Protokoll, ephemere URLSession, 15 s, Statuszuordnung 401/409/429/503, nie Token oder Körper in Fehlern) | ja, Pfade `app/deliveries/claim`, `app/deliveries/result` statt `orders` |
| Abgleich | `Claude/ClaudeSync.swift` (Sperren `sending`/`pulling`, Höchstzahl je Durchlauf 15, jeder Fehler beendet den Durchlauf), `Claude/ClaudeSyncTrigger.swift` (Start und `didBecomeActive`, stumm unter Tests) | Muster ja, Reihenfolge hier anders (Abschnitt 5.2) |
| Entitlements | `LooseEnds.entitlements:7-9` (`com.apple.developer.applesignin` = Default), `…network.client` nur macOS | ja |

## 3. Betroffene Dateien (voraussichtlich)

**Neu** (alle in `Meditationstimer iOS/Claude/`, synchronisierte Gruppe, kein Projekteintrag nötig; Tests in `LeanHealthTimerTests/`):
Lieferung: `ClaudeJSON.swift`, `DeliveryRules.swift`, `DeliveryValidator.swift` (+ `…Extras.swift` für reminder/tracker/challenge), `ClaudeLibrary.swift` (Modell und Speicher), `DeliveryApplier.swift`, `ClaudeBadge.swift`/`ClaudeDetailSheet.swift`.
Verbindung: `ClaudeFeature.swift` (Schalter), `Nonce.swift`, `SessionStore.swift`, `DeviceIdentity.swift`, `ServiceClient.swift`, `AccountState.swift`, `TranscriptBuilder.swift`, `ClaudeSync.swift`, `ClaudeSyncTrigger.swift`, `ClaudeConnectionView.swift`.

**Geändert:** `Tabs/WorkoutTab.swift`, `Tabs/MeditationTab.swift` (Listen zusammenführen, Bearbeiten/Löschen umleiten), `Services/ExerciseDatabase.swift` bzw. `Models/ExerciseInfo.swift` (A2: Kennung, Claude-Übungen auffindbar), `Tabs/WorkoutProgramsView.swift` (A2: Hinweis im Schritt-Editor, Anzeige, Ansage; enthält die genutzten Unterviews), `Meditationstimer_iOSApp.swift` (Sync starten), `SettingsSheet.swift` (Link), `Localizable.xcstrings`, `Meditationstimer iOS.entitlements`, `project.pbxproj`/Info-Plist (nur am Mac).

## 4. Lücken und Voraussetzungen, insbesondere A2 (#48)

Was für #51 **fehlt**, weil A2 noch nicht da ist:

| # | Lücke | Folge für #51/#57 | Vorschlag |
|---|---|---|---|
| A2-1 | `ExerciseInfo` hat keine Kennung; Katalog nur als `Contracts/catalog/builtin-exercises.json` (43 Einträge, Anzahl passt zu `ExerciseDatabase`) | Programmschritte aus Lieferungen (`builtin.*`) lassen sich nicht auf die App-Übung abbilden, Abschrift kann keine IDs ausgeben | `id` in `ExerciseInfo`, Test „Katalog-Gleichlauf" (gleiche Menge id/Name/Kategorie wie JSON, über `#filePath`); Kategorie-Abbildung `ExerciseCategory` ↔ Wertename (`strength`…) |
| A2-2 | `WorkoutPhase` kennt nur den Namen | Auflösung in beide Richtungen nötig: Kennung → Anzeigename (builtin: Katalogname, `claude.*`: gelieferter Name) und Name → Kennung (exakt, dann Suffixregel „links/rechts" wie `ExerciseDatabase.swift:21-29`, z. B. „Beinpendel links" → `builtin.beinpendel`) | Neues optionales Feld `exerciseId` am Schritt ist **nicht nötig**, wenn die Abbildung rein berechnet wird (kein Datenumbau) |
| A2-3 | Freitext- und englische Vorschlagsnamen ohne Katalogtreffer | Für die Abschrift braucht jede Übung eine `own.*`-Kennung | Deterministisch aus dem normalisierten Namen ableiten (`own.` + 16 Hex SHA-256), damit **keine Migration und kein neuer Speicher** nötig ist; Umbenennen ergibt eine neue Kennung (hinnehmbar) |
| A2-4 | Hinweis je Schritt fehlt in Modell, Editor, Anzeige, Ansage | #51 muss den Hinweis mindestens **speichern**; Anzeige/Ansage ist A2 | `WorkoutPhase.hint: String?` (Optional, alte JSONs dekodieren unverändert); Editor/Anzeige/Ansage bleiben A2 |
| A2-5 | Keine Kennungen für mitgelieferte Programme und Atemübungen; Vorgabelisten doppelt und abweichend (4 gegenüber 10 Programme) | Abschrift `origin: builtin` braucht feste Kennungen; die Spec sagt ausdrücklich, der Katalog der eingebauten Programme sei nicht Teil von B0 (`claude-erinnerung.md:41`) | Kleine feste Tabelle Name → `builtin.<slug>` (10 Programme, 6 Atemübungen) in einer Datei; vorher klären, ob die Vorgaben vereinheitlicht werden (eine Liste statt zwei) |
| A2-6 | Eigene Programme/Atemübungen | `own.<uuid>` aus der gespeicherten `id` (stabil, bereits in den JSONs) | keine Migration |
| A2-7 | `ExerciseDetailSheet` sucht nur in der festen Datenbank | Claude-Übungen (mit Wirkung/Anleitung) müssten im Info-Knopf erscheinen | `ExerciseDatabase.info(for:)` um Claude-Übungen (Name) ergänzen oder Sheet bekommt Quelle injiziert |

Was **nicht** vorausgesetzt ist: Tagebuch (B3b), Erinnerung mit Ziel (B4b), Challenges (B5b/B6b), Tracker.

## 5. Vorschläge

### 5.1 Entwurf #51 (Annahme-Kern)

- **Eigener Speicher** `ClaudeLibrary` (eine JSON-Datei in Application Support, atomar geschrieben) mit: Claude-Übungen, -Programmen, -Atemübungen (je Inhalt, `revision`, `state` active/adapted/withdrawn, `deliveredAt`, `why`, `packageId`/`packageName`, Originalinhalt zum Erkennen von „angepasst"), dem **Ledger** der Lieferungen (`deliveryId` → Ergebnis, Fehler, Datum; Abschrift braucht die letzten 50). Gründe: (a) Henning-Daten in `UserDefaults` bleiben unangetastet, keine Migration; (b) „ganz oder gar nicht" und Idempotenz in **einem** Schreibvorgang; (c) kein „verlorene Änderung"-Risiko durch die zwei Tabs, die ihr Array komplett zurückschreiben; (d) Prüfen/Anwenden ohne UI testbar.
  Preis: `WorkoutTab` und `MeditationTab` führen zwei Quellen zusammen, und Bearbeiten/Löschen eines Claude-Bausteins wird dort umgeleitet.
- **Reiner Kern** `DeliveryApplier.apply(delivery, to: snapshot, context) -> (snapshot', Outcome)`: Reihenfolge Ledger-Treffer (gespeichertes Ergebnis gilt, nichts ändern) → Prüfer → Anwenden auf Kopie → atomar speichern → Ergebnis ins Ledger. Regeln aus `claude-lieferformat.md` §7; zusätzlich festzulegen (Vorschlag):
  - `revision` ≤ gespeichert: Eintrag ohne Wirkung, Lieferung insgesamt `accepted`.
  - Höhere Fassung bei `adapted`: **ganze Lieferung** `rejected`, Code z. B. `ITEM_ADAPTED` (lokaler App-Code; der Dienst nimmt jeden Code 1-100 Zeichen, `server/src/app-routes.ts:99-102`).
  - Rücknahme per `itemId`/`packageId`: Zustand `withdrawn`, nie löschen; unbekannte Kennung: ohne Wirkung, `accepted`; bei `adapted`-Baustein siehe Produktfrage 2.
  - Wiederherstellen (lokal durch Henning): `withdrawn` → `active`.
  - Arten `reminder`/`challenge`/`tracker`: der Prüfer muss sie **voll beurteilen** (der gemeinsame Beispielsatz mischt alle Arten, `Contracts/validator/src/reminder.ts`, `challenge.ts`, `tracker.ts`), das Anwenden folgt erst mit B4b/B5b/B6b; bis dahin `rejected` mit Code `KIND_NOT_SUPPORTED` und klarer Meldung „App zu alt".
- **Prüfer in Swift:** Port von `Contracts/validator/src/*.ts` (831 Zeilen TS, schätzungsweise 600-700 Zeilen Swift). Fallstricke aus der Spec: Länge in Unicode-Skalaren (`unicodeScalars.count`), Kleinschreibung je Skalar (`String(scalar).lowercased()`), Wahrheitswerte als `NSNumber` erkennen (`CFGetTypeID == CFBooleanGetTypeID`, Spec §4), Zahlen `12.0`/`1.2e1` ganzzahlig, `-0`, Beträge über 10⁹ vor der Ganzzahlprüfung, Zeichenverbotsliste, Kalenderprüfung. `JSONSerialization` verhält sich bei sehr großen/unendlichen Zahlen und doppelten Schlüsseln anders als `JSON.parse`; der Parity-Test über **alle** Beispiele deckt das auf, sonst eigener kleiner JSON-Leser.
- **Gleichlauf-Test:** über `#filePath` → Repo-Wurzel → `Contracts/deliveries/{valid,invalid}/*.json` (je Datei `context`, `delivery`, `expected`); gleiche Beurteilung = gleiches `valid` und gleiche **Menge** (code, path) (`claude-lieferformat.md` §6). Der Test muss eine **Mindestzahl** Dateien erzwingen (sonst grünes Nichts, vgl. CLAUDE.md „Executed N ≥ 1"). Alternative Ordnerreferenz im Testziel nur falls `#filePath` nicht trägt; CI baut und testet im selben Lauf (`ios-tests.yml:31-50`), daher trägt der Pfad.
- **Kennzeichnung/Detail/Zurücknehmen:** Zeichen „von Claude" an Zeile in Workout- und Atem-Liste, Detail mit Datum, Paket, Warum (`konzept` §9), Liste „Zurückgenommen" mit Wiederherstellen, Zurücknehmen einzeln/als Paket durch Henning; Bearbeiten im bestehenden Editor, beim Speichern mit geändertem Inhalt → `adapted`.

### 5.2 Entwurf #57 (Verbindung)

- **Ablauf je Durchlauf (Start und `didBecomeActive`, ohne Sitzung passiert nichts):** (1) abholen → anwenden → Ergebnis melden, wiederholen bis 204 oder Höchstzahl; (2) danach frische Abschrift senden (`konzept` §11 Schritt 5). Anders als Loose Ends (erst senden, dann abholen). Jeder Fehler beendet den Durchlauf; 401 → Sitzung gilt als abgelaufen; 409 beim Ergebnis → Lieferung wird vom Dienst neu vergeben, lokal Ledger behalten.
- **Abschrift Fassung 1** aus `ClaudeLibrary` + `UserDefaults`-Listen + Katalog: Übungen (builtin nur Kennung/Name/Kategorie; own ohne Texte; claude mit Wirkung/Anleitung), Programme, Atemübungen, `deliveries` (letzte 50). Kein Feld außerhalb der Liste (Datenschutzgrenze, `claude-dienst.md` §4).
  Prüfung ohne Swift-Schema-Prüfer: Test erzeugt Abschriften aus festen Beständen, vergleicht mit eingecheckten Goldendateien (z. B. `Contracts/transcript/app-generated/*.json`), und der Contracts-CI-Job (`contracts.yml`, Ajv ist dort schon vorhanden) validiert diese Dateien gegen `transcript-v1.schema.json`. So gilt „die App erzeugt nur Abschriften, die die Beispiele bestehen" mit einer einzigen Regelquelle.
- **Anmeldung:** `POST /auth/apple` mit `identityToken`, rohem `nonce`, `code` (`server/src/auth.ts:54-61,65-81`); Apple bekommt den SHA-256-Hex-Wert, keine Scopes. Antwort `{sessionToken}`, im Schlüsselbund. Antworten: 401 (nicht zugelassen/ungültig), 503 (Apple/Schlüssel nicht erreichbar), später `/auth/logout`, `/auth/delete` (204).
- **Einstellungsseite** (`konzept` §9): Anmelden, letzter Abgleich (Zeitpunkt aus dem Ledger/`AccountState`), Liste der Lieferungen mit Ergebnis und Fehlertext, „Was Claude sieht" als Klartext (**aus derselben Feldliste wie der `TranscriptBuilder` erzeugt**, damit Text und Wirklichkeit nicht auseinanderlaufen), „Verbindung trennen" mit Rückfrage (`/auth/delete`, Geliefertes bleibt auf dem Gerät). Eintrag in `SettingsSheet` nur bei eingeschaltetem Schalter.
- **Schalter:** wie Loose Ends: `HHClaudeEnabled` (Bool, Standard NEIN) in `Meditationstimer-iOS-Info.plist`, JA unter `#if DEBUG` bzw. Testlauf, im TestFlight-Archiv per Skriptschritt. Abweichung vom Vorbild: dort zusätzlich `LEServiceURL`; hier `HHServiceURL` mit https-Pflicht (http nur `localhost` im Debug).
- **UI-Tests:** Apple-Dialog läuft im Simulator unzuverlässig (Erfahrung Loose Ends, `AccountSection.swift:145-173`): unter `enable-testing` ein Stand-in-Knopf und ein `HTTPTransport`-Stand-in (`UITestTransport`). **Echte Anmeldung gegen den Dienst** erst nach Bereitstellung (B2c) und auf Hennings ausdrückliches „jetzt ist ein Test möglich".

### 5.3 Schnitte und Reihenfolge

Jeder Schnitt ≤ 4-5 Dateien und ≈ 250 Zeilen (`DOCS/arbeitsweise.md:22`); Test-Dateien zählen mit. Alles Swift entsteht und wird am Mac gebaut/getestet (Cloud kann kein Xcode); in der Cloud sind nur Spezifikation und Gerüstplanung sinnvoll.

**Voraussetzung A2 (#48), von uns hier nur als Eingang zu #51 beschrieben:**
- A2a: Kennung und Katalog-Gleichlauf (`ExerciseInfo.swift`, `ExerciseDatabase.swift`, 1 Test, ≈ 150 Z.). Abbildung Name → Kennung inkl. Suffixregel, Kategorie-Abbildung.
- A2b: Hinweis je Schritt (`WorkoutPhase.hint`, Editor, Anzeige, Ansage in `WorkoutProgramsView.swift`, Strings, UI-Test; ≈ 200 Z.). Für #51 reicht vorher das bloße Feld.
- A2c: eingebaute Programm-/Atemübungs-Kennungen, Vorgabelisten vereinheitlichen (`WorkoutTab`, `WorkoutProgramsView`, `MeditationTab`, `AtemView`, Tabelle; ≈ 150 Z.).

**#51 (B1a):**
| Schnitt | Inhalt | Dateien (≈ Zeilen) | Voraussetzung |
|---|---|---|---|
| 51-1 | `ClaudeJSON` (Wertbaum mit Bool/Zahl-Unterscheidung), Regeln (Text, Zahl, Symbol, ID, Datum, Normalisierung) und Test-Harness für den Beispielsatz, vorerst mit Ausweisung der noch nicht abgedeckten Arten | 3 + 1 Test (≈ 250) | – |
| 51-2 | Hülle, Übung/Programm/Atemübung/Rücknahme, Katalog laden, Gleichlauf auf allen Beispielen dieser Arten | 2 + Test (≈ 250) | 51-1, A2a |
| 51-3 | `reminder`, `tracker`, `challenge` im Prüfer; **voller** Gleichlauf über alle Beispiele | 3 + Test (≈ 300, ggf. zwei Schnitte) | 51-2 |
| 51-4 | `ClaudeLibrary` (Modell, atomarer Speicher, Ledger) und `DeliveryApplier` (Idempotenz, Fassungen, angepasst, Rücknahme einzeln/Paket, Wiederherstellen, ganz oder gar nicht) mit Tests | 2 + 1-2 Test (≈ 250) | 51-2, A2c |
| 51-5 | Listen zusammenführen, Starten, Bearbeiten → „angepasst", Löschen → „zurückgenommen" in `WorkoutTab`/`MeditationTab`; Info-Knopf für Claude-Übungen | 4 (≈ 200) | 51-4 |
| 51-6 | Kennzeichen, Detailansicht (Datum, Paket, Warum), Zurücknehmen/Wiederherstellen, DE/EN-Texte, UI-Test | 3 + xcstrings (≈ 250) | 51-5 |

**#57 (B2d)** (51-x und 57-1/57-2 sind unabhängig und können parallel laufen):
| Schnitt | Inhalt | Dateien (≈ Zeilen) | Voraussetzung |
|---|---|---|---|
| 57-1 | Schalter, Nonce, `SessionStore` + Schlüsselbund + Geräte-ID, Tests mit Schlüsselbund-Attrappe; Entitlement + Info-Plist-Schlüssel (am Mac) | 4 + Test (≈ 250) | – |
| 57-2 | `ServiceClient` (Transport-Protokoll, alle fünf Pfade) + `AccountState` (Zustände, Anmelden/Abmelden/Löschen), Tests mit Transport-Attrappe | 2 + Test (≈ 250) | 57-1 |
| 57-3 | `TranscriptBuilder` Fassung 1, Goldendateien, CI-Schritt in `contracts.yml` | 1 + Test + Dateien (≈ 200) | 51-4, A2a, A2c |
| 57-4 | `ClaudeSync` (Abholen → Anwenden → Melden → Abschrift) + Trigger (Start, `didBecomeActive`, stumm unter Test) + Einhängen in `Meditationstimer_iOSApp` | 3 + Test (≈ 250) | 57-2, 57-3, 51-4 |
| 57-5 | `ClaudeConnectionView` (Anmelden, letzter Abgleich, Lieferliste, „Was Claude sieht", Trennen mit Rückfrage), Link in `SettingsSheet`, Texte, UI-Test mit Stand-in | 3 + xcstrings (≈ 250) | 57-2, 57-4 |

Empfohlene Gesamtreihenfolge: **A2a → 51-1 → 51-2 → 51-3 → A2c → 51-4 → 57-1 → 57-2 → 51-5 → 57-3 → 57-4 → 51-6 → 57-5**, dann A2b und Fassung 2 (mit #59) nachziehen.

## 6. Risiken

| Risiko | Einschätzung / Gegenmaßnahme |
|---|---|
| **Datenmigration** | Mit eigenem Speicher bleiben `workoutProgramSets` und `atemPresets` unberührt. Einzige Formatänderung: optionales `hint` am Schritt (Optional, alte Daten dekodieren). SwiftData/Tracker wird in #51/#57 nicht angefasst (hat kein Migrationsplan; das ist erst B5b/B6b-Risiko). Vorsicht: UUIDs der Vorgaben ändern sich bei jedem Start (`WorkoutTab.swift:813`), Identität nur über Namen: nie auf deren UUID verlassen. |
| Vorgaben 4 gegenüber 10 | Abschrift und Katalogkennungen hängen daran; Entscheidung in A2c nötig (technisch, siehe Frage T3). |
| **Doppelte Speicherlogik** | Bearbeiten/Löschen von Claude-Bausteinen muss in **beiden** Live-Tabs umgeleitet werden. Tote Kopie `WorkoutProgramsView.loadSets` nicht anfassen, aber auch nicht erweitern (kein Drive-by-Refactoring). |
| **Swift-Concurrency** | Projekt im Swift-5-Modus (`SWIFT_VERSION = 5.0`), CI mit Xcode 26.6, CLAUDE.md nennt Xcode 27/Swift 6.4. Neuer Code soll auch im Swift-6-Modus warnungsfrei sein: Wertetypen `Sendable`, Dienstzugriff über Protokolle, `@MainActor` für `AccountState`/`ClaudeSync`/Trigger, `async/await`, kein GCD. `@Observable` (iOS 18.5 ok) statt `ObservableObject` für neue Zustandsklassen: begründet durch Übernahme des Vorbilds, im Projekt bisher kaum benutzt (bewusst gemischt). Auf beiden Xcode-Versionen bauen. |
| Host-App-Tests | Unit-Tests starten die komplette App (`TEST_HOST`): der Sync-Trigger darf unter Test **nie** echte Aufrufe machen (Loose-Ends-Regel „stumm unter Test"), auch nicht der Schlüsselbund-Zugriff beim App-Start. |
| **Sign in with Apple** | Entitlement `com.apple.developer.applesignin` und Fähigkeit im Apple-Developer-Portal für die App-ID **`henemm.Meditationstimer-iOS`** (Team `XK87E2B3VR`) sind Mac/Portal-Arbeit. Der Dienst prüft das Token gegen `APPLE_CLIENT_IDS`: dort muss genau diese Bundle-ID stehen; die Testwerte im Dienst (`de.hhhaven.app` u. a., `server/test/apple-jwks.test.ts:203`) sind Platzhalter. Eine einzige Entitlements-Datei für Debug **und** Release: die Fähigkeit steckt damit auch in Store-Bauten (unsichtbar im UI, aber eingetragen); bei Bedarf zweite Datei je Konfiguration. CI baut mit Ad-hoc-Signatur und legt Entitlements ein (`ios-tests.yml:27-38`): prüfen, dass das Simulator-Build mit der neuen Fähigkeit weiter startet. |
| **Store-Version unsichtbar** | Schalter ist Laufzeit-Info-Plist-Wert, der Code ist aber in jeder Version enthalten. Es gibt keinen TestFlight-Workflow im Repo (`.github/workflows` hat nur `contracts`, `ios-tests`, `server`; `ExportOptions.plist` und `STABLE_VERSIONS.md` legen manuelle Archivierung nahe). Ohne definierten Weg, den Schalter nur im TestFlight-Archiv zu setzen, bleibt die Verbindung dort unsichtbar oder in Store-Bauten sichtbar. Test, der belegt, dass der Standard „aus" ist (wie `AccountSectionTests`), ist Pflicht. Ohne `PrivacyInfo.xcprivacy` im Repo: `URLSession`/Schlüsselbund-Nutzung für die Store-Prüfung bedenken (die Datei fehlt schon heute, `UserDefaults` ist ein deklarationspflichtiger Grund). |
| Prüfer-Gleichlauf | Zwei Implementierungen derselben Regeln. Gegenmittel ist nur der Beispielsatz; neue Beispiele im Contracts-Verzeichnis lassen die App-Tests rot werden (gewollt). Unicode-Randfälle (kontextabhängige Kleinschreibung, Ersatzzeichen, JSON-Zahlen) zuerst testen. Spec-Änderungen an Fassung 1 sind bis zum ersten annehmenden Release erlaubt (`claude-lieferformat.md:39-40`): **App-Port darf nicht hinter der Spec herlaufen**. |
| Lieferung vor App-Unterstützung | Dienst kann bereits `reminder_create` u. ä. liefern (B4a/B5a/B6a umgesetzt), die App nimmt diese Arten erst später an: lokal `rejected` mit klarem Grund; Claude muss danach neu liefern. |
| Zeit und Datum | `createdAt`/`startDate` sind UTC bzw. Geräte-Kalendertag; Prüfer arbeitet mit UTC-Tagen; App-Prüfer darf **keine** lokale Zeitzone einbringen (nur `createdAt` und `keepStartDate`). |
| Netzfehler/Wiederholung | Dienst gibt abgeholte, aber nach 10 min nicht beantwortete Lieferungen wieder frei (`claude-dienst.md:91`): Ledger muss „schon angewendet" erkennen, ohne dass das Ergebnis verloren geht (zweite Meldung ergäbe 409 → akzeptieren). |
| Speicher | Abschrift ≤ 256 KiB (`app-routes.ts:10`) und ≤ 500 Übungen/200 Programme/200 Atemübungen: Obergrenzen in `TranscriptBuilder` kürzen/ablehnen statt 400 zu provozieren. |

## 7. Offene Fragen

### Echte Produktentscheidungen (an Henning, mit Empfehlung)

1. **Löschen eines Claude-Bausteins durch Henning:** Das Konzept sagt „nichts wird gelöscht" für Claude, regelt aber Hennings Löschen nicht. Empfehlung: Löschen verschiebt in „Zurückgenommen" (wiederherstellbar), dort gibt es ein endgültiges Löschen. Alternative: sofort weg.
2. **Claude nimmt etwas zurück, das Henning schon angepasst hat:** Empfehlung: Rücknahme wird **abgelehnt** (Grundregel 7, „überschreibt es nicht blind"); Claude bekommt den Grund. Alternative: wird angewendet und ist wiederherstellbar.
3. **Wann zählt die Formatfassung 1 als eingefroren?** Spec: „mit dem ersten App-Release, das Lieferungen annimmt". Empfehlung: erst mit der ersten **Store**-Version, die die Verbindung enthält, nicht schon mit einem TestFlight-Bau für Henning (bis dahin darf der Dienst die Art ändern, App und Dienst werden gemeinsam aktualisiert). Wirkung: bis dahin drohen keine Altlast-Formate.

### Technische Fragen (Tech Lead entscheidet, Stand: Vorschlag oben)

- T1: **Abschrift Fassung 1 oder 2** für #57? Vorschlag Fassung 1 (Pflichtfeld `history`, Tagebuch fehlt, Fassung 2 mit leerer Liste würde „nichts passiert" behaupten). Wenn #59 vorher fertig ist, direkt Fassung 2.
- T2: Dienstadresse und `APPLE_CLIENT_IDS` (Bundle-ID `henemm.Meditationstimer-iOS`) hängen an B2c; bis dahin Platzhalter im Info-Plist, Tests über Stand-in/localhost.
- T3: Vorgabelisten vereinheitlichen (4 gegenüber 10 Programme, 6 Atemübungen doppelt)? Vorschlag: eine geteilte Liste in A2c, keine Änderung am sichtbaren Bestand bestehender Nutzer.
- T4: Wie entsteht der TestFlight-Bau mit eingeschaltetem Schalter (Pipeline fehlt im Repo)? Muss vor 57-5 geklärt sein; Vorschlag: eigener Archiv-Schritt wie Loose Ends, Standard im Code „aus".
- T5: `@Observable` gegenüber `ObservableObject` (siehe Risiken), Dateiort `Meditationstimer iOS/Claude/` (synchronisiert) gegenüber `Services/` (Projektänderung).
- T6: „angepasst" nur bei echter Inhaltsänderung (Vorschlag), nicht bei jedem Speichern.
- T7: Löschen eines Übungseintrags (Claude-Übung), die von Programmen benutzt wird: Name bleibt auflösbar, nur in Auswahllisten ausgeblendet.

## 8. Abweichungen zwischen Doku und Code (zur Korrektur)

- CLAUDE.md nennt `Tests/` (66 Tests) als Testort: tatsächlich liegen die Tests in `LeanHealthTimerTests/`; `Tests/` ist eine leere synchronisierte Gruppe.
- CLAUDE.md/Konzept: „10 mitgelieferte Programme", live (`WorkoutTab`) sind es 4 bei frischer Installation.
- CLAUDE.md: Xcode 27/Swift 6.4; CI wählt Xcode 26.6, alle Ziele im Swift-5-Modus.
- `Models/BreathPreset.swift` ist ungenutzt; das Live-Modell steckt in `AtemView.Preset`.
- Konzept §3: „eine zweite, abweichende Vorschlagsliste": bestätigt (englisch, 60+ gegenüber 43 deutschen, `WorkoutProgramsView.swift:221`).
