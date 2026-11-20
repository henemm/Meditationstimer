---
entity_id: feature-51-s2-bausteine-anwenden
type: feature
created: 2026-11-20
updated: 2026-11-20
status: draft
workflow: feature-51-s2-bausteine-anwenden
issue: 51
epic: 44
---

# Claude-Lieferung anwenden: reine Anwende-Logik (B1a, #51, Schnitt 2a in drei Runden 2a-1 bis 2a-3)

## Approval

- [ ] Approved

Diese Freigabe gilt für alle drei Runden 2a-1, 2a-2 und 2a-3. Jede Runde ist eine eigene Workflow-Runde mit eigenem Test-Checkpoint und eigener Validierung; umgesetzt wird zuerst 2a-1.

## Purpose

Eine bereits gelesene Lieferung von Claude (`ClaudeDelivery`, Schnitt 1) wird in einer reinen Funktion auf einen übergebenen Zustand angewendet: Programme, Atemübungen und Übungen werden angelegt oder ersetzt, Rücknahmen entfernen, dieselbe Lieferung wirkt nur einmal, und eine Lieferung gilt ganz oder gar nicht. Das ist der testbare Kern des Anwendens; Speichern und Oberfläche folgen in 2b und Schnitt 3.

**Für Henning noch unsichtbar:** `apply` hat in keiner der drei Runden einen Aufrufer, schreibt nirgends hin und liest nirgends. Henning sieht erst ab Schnitt 3 etwas (Zeichen „von Claude“, Info mit Datum, Paket und Warum).

## Source

- **Issue:** #51, Epic #44
- **Analyse (maßgeblich, Entscheidungen 1–8, Zuschnitt 2a/2b):** `DOCS/context/feature-51-s2-bausteine-anwenden.md`
- **Übergeordnete Spec:** `openspec/specs/features/claude-annahme.md` (Verhalten 2–6)
- **Format:** `openspec/specs/integrations/claude-lieferformat.md` §2–3, §7
- **Vorgänger:** `DOCS/specs/features/feature-51-lieferung-annehmen.md` (Schnitt 1)
- **Testmuster:** `LeanHealthTimerTests/ClaudeDeliveryDecodingTests.swift` (Beispielsatz per `#filePath`)

## Dependencies

| Abhängigkeit | Art | Zweck |
|---|---|---|
| `ClaudeDelivery`, `ClaudeItem` und Positionstypen | Upstream | Eingabe von `apply` (nur lesend) |
| `ExerciseDatabase.info(forId:)` | Upstream | `builtin.*` zu deutschem Namen (nur lesend) |
| `ExerciseCategory` (deutsche Rohwerte) | Upstream | Ziel der Kategorie-Abbildung (ab 2a-2) |
| `WorkoutPhase` | Upstream, unverändert | Phasen der angelegten Programme (nur erzeugt, Typ bleibt wie nach #48) |
| `WorkoutSet`, `AtemView.Preset` | Upstream, geändert (2a-1) | Ziel der Programme und Atemübungen; beide bekommen zwei optionale Felder |
| Schnitt 2b, Schnitt 3, #57 (Abgleich, besitzt `lastSnapshotAt`), #59 | Downstream | rufen `apply` später auf |
| Watch, Widget | Berührung nur durch Kompilierung | Der Ordner `Meditationstimer iOS` ist laut `project.pbxproj` (Zeilen 121–145) für Watch und Widget synchronisiert, ausgenommen nur zwei Dateien je Ziel. Die neue Datei wird dort mit übersetzt: nur `Foundation` importieren, Watch- und Widget-Build sind in jeder Runde Teil der Definition of Done |

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue. Die acht Entscheidungen der Analyse (2026-11-20) gelten; für 2a relevant sind 1, 2, 3, 4, 5, 6, 7.
- **Entscheidung 7 in der Auslegung dieser Spec (Tech Lead, 2026-11-20, keine Abweichung von den Bezugsdokumenten):** „Ganz oder gar nicht“ und „jede Ablehnung lässt den Zustand unverändert“ gelten für die **Bausteine** (Programme, Atemübungen, Übungen), nicht für das Gedächtnis. Das Gedächtnis merkt jedes Ergebnis, auch `rejected`. So sagen es `claude-annahme.md` Verhalten 3 („die `deliveryId`s der letzten 50 Lieferungen mit Ergebnis“) und `claude-lieferformat.md` §7 („das Ergebnis der ersten Verarbeitung gilt“).
- **Rationale:** Reine Funktion mit explizitem Zustand statt Zugriff auf `UserDefaults`: ganz oder gar nicht ist dann trivial (bei Ablehnung bleiben die Bausteine des Eingabezustands erhalten), jede Regel ist ohne Gerät prüfbar.
- **Abweichung von `claude-annahme.md` Verhalten 2 (ausdrücklich):** Dort heißt es „Übungen in den Übungskatalog“. Gelieferte Übungen liegen stattdessen im eigenen Speicher `claudeState` (`state.exercises`, Schlüssel erst in 2b). Grund: Es gibt keinen Laufzeit-Katalog (`ExerciseDatabase` ist statisch, `info(forId:)` kennt nur `builtin.*`), und Henning kann Übungen nicht bearbeiten, also braucht es weder Eintrag in einer Liste noch `modifiedAt` (Analyse Entscheidung 1 und 4). Programme und Atemübungen folgen dem Wortlaut (bestehende Listen). `claude-annahme.md` wird in 2a-3 entsprechend nachgezogen (Definition of Done).
- **Alternative (verworfen):** eigener Gesamtspeicher für alles Geliefertes (frühere Analyse 5.1). Widerspricht „Übernehmen in die bestehenden Listen“ für Programme und Atemübungen: Henning müsste Geliefertes erst kopieren. Gekippt wird keine ADR.
- **Alternative (verworfen):** Ablehnungen nicht merken, damit eine Wiederholung nach neuer Abschrift neu bewertet wird. Widerspricht den zwei Bezugsdokumenten; Claude liefert nach einer Ablehnung ohnehin mit neuer `deliveryId`.
- **Alternative (verworfen):** Rücknahme mit Wiederherstellen (Lieferformat §3.4 alt). PO 13.11.: kein Papierkorb; §3.4 ist bereits korrigiert.
- **Alternative (verworfen):** 2a in einer Runde. Kalibriert (siehe Zuschnitt) käme der App-Code auf rund 350 Zeilen und überschritte die Grenze; deshalb drei Runden.

## Zuschnitt in drei Runden

**Grenze (PO-Entscheidung Henning, 2026-11-20, auf Nachfrage):** Je Runde höchstens **250 Zeilen App-Code** (Produktiv-Diff, Löschzeilen mitgezählt), keine Funktion über 50 Zeilen. **Testcode zählt nicht gegen das Budget, wird aber voll geprüft** (alle Tests laufen, RED zuerst, GREEN am Ende). Beleg: Schnitt 1 wurde mit 169 Zeilen App-Code (`ClaudeDelivery.swift`) und rund 267 Zeilen Test so freigegeben. Die Grenze wird nicht angehoben und keine Konfiguration geändert.

**Kalibrierung an Schnitt 1:** Die naive Schätzung von Schnitt 1 lag bei App rund 110 und Test rund 140 Zeilen; tatsächlich 169 und rund 267. Faktor also rund 1,5 (App) und rund 1,9 (Test).

**Herleitung der naiven App-Schätzung 2a-1** aus der Funktionsliste (Zeilen, naiv): `ClaudeOrigin` 8, `ClaudeApplyState` + `ClaudeApplyLogEntry` + `ClaudeApplyResult` 14, `apply` 30, `applyProgram` 28, `applyBreath` 20, `resolveStepName` 8, `isBlockedByIphone` 8, Ablehnungs- und Gedächtnis-Helfer 18, neue Felder samt `init`-Parametern an `WorkoutSet` und `Preset` 12. Summe rund 146, Spanne 130–150. Kalibriert (×1,5): rund 195–225, Mittelwert rund 210.

| Runde | Inhalt | App naiv | App kalibriert (×1,5) | Puffer zu 250 | Test naiv | Test kalibriert (×1,9, zählt nicht) |
|---|---|---|---|---|---|---|
| **2a-1** | Felder `claude`/`modifiedAt` an `WorkoutSet` und `Preset`, `ClaudeOrigin`, `ClaudeApplyState` (ohne Übungen), `ClaudeApplyResult`, Gedächtnis, `apply` für Programme (nur `builtin.*`) und Atemübungen: Anlegen, Ersetzen, ohne Wirkung, Idempotenz, Gedächtnis 50, ganz oder gar nicht, `CHANGED_ON_IPHONE`, gelöscht + höhere Fassung, Alt-JSON | ~140 (130–150) | ~210 (195–225) | ~40 (25–55, also 10–22 %) | ~130 | ~245 |
| **2a-2** | Übungen (`ClaudeStoredExercise`, `state.exercises`), Kategorie-Abbildung, Namensauflösung `own.*`/`claude.*`, `EXERCISE_UNKNOWN`, `CATEGORY_UNKNOWN` | ~65 | ~98 | ~152 (61 %) | ~85 | ~160 |
| **2a-3** | Rücknahme einzeln und als Paket (inkl. Übungen, Rücknahme einer Übung immer erlaubt), „alle lesbaren Beispiele“ mit Mindestanzahl-Prüfung, Codable-Round-Trip, Reinheits-Test | ~30 | ~45 | ~205 (82 %) | ~110 | ~210 |

**Ehrliche Einschätzung:** 2a-1 ist die knappste Runde. Der Puffer liegt im Mittel bei rund 16 % und im ungünstigen Fall (225) bei rund 10 %, also unter der Zielmarke von 20 %. Die zwei anderen Runden haben reichlich Puffer. Bei der Dreiteilung bleibt es trotzdem: Ein Zweiteiler (2a-1 plus 2a-2 zusammen kalibriert rund 308) wäre über der Grenze, und 2a-1 verkleinern geht nur über die Rückfallregel. Summe App kalibriert rund 353 Zeilen, daher mehr als eine Runde nötig.

**Rückfallregel (bedingt, greift bei mehr als 250 App-Zeilen, gemessen vor der Validierung):** Reißt 2a-1 die 250, wandert die **Atemübung** (`breath`: Anlegen, Ersetzen, jeweiliger Anteil an AC-1a, AC-6a, AC-7, AC-8a; rund 30 kalibrierte Zeilen) nach 2a-2; in 2a-1 lehnt `breath` dann wie `exercise` ab (`KIND_NOT_SUPPORTED`, siehe Zwischenverhalten). Reißt 2a-2, wandert die Kategorie-Abbildung samt AC-16 nach 2a-3. Die Grenze wird nicht angehoben. In der Zuordnung sind die betroffenen Teile als „bedingt“ gekennzeichnet.

### Verhalten für noch nicht umgesetzte Arten (Zwischenstand, ohne neue Codes)

Eine Lieferung gilt ganz oder gar nicht. Deshalb darf eine noch nicht unterstützte Position weder stillschweigend übersprungen noch als „angewendet“ gemeldet werden. Sie lehnt die **ganze** Lieferung ab, mit einem Code, den es schon gibt: `KIND_NOT_SUPPORTED` (`claude-annahme.md` Verhalten 1: „eine Art, die die App noch nicht kann“). Der Grund-Text „Diese Art von Baustein kann die App noch nicht annehmen.“ ist **neu formuliert** (steht in keinem Bezugsdokument). Bausteine unverändert, die Ablehnung steht wie jede andere im Gedächtnis (Regel 4).

| Position | 2a-1 | 2a-2 | 2a-3 |
|---|---|---|---|
| `program` mit `builtin.*`-Schritten | angewendet | angewendet | angewendet |
| `breath` | angewendet (bedingt, siehe Rückfallregel) | angewendet | angewendet |
| `program` mit `own.*`/`claude.*`-Schritt | `EXERCISE_UNKNOWN` (nicht auflösbar, Bausteine unverändert) | aufgelöst nach Regel 10 | aufgelöst |
| `exercise` | `KIND_NOT_SUPPORTED` | angewendet | angewendet |
| `withdrawal` | `KIND_NOT_SUPPORTED` | `KIND_NOT_SUPPORTED` | angewendet |

**Zwischen-Tests, Löschung im RED-Schritt:** Die zwei Zwischen-Tests `testUebungslieferungNochNichtUnterstuetzt` (2a-1, gelöscht in 2a-2) und `testRuecknahmeNochNichtUnterstuetzt` (2a-1, gelöscht in 2a-3) sind befristet. Der QA-Writer löscht sie im RED-Schritt (`phase4_tdd_red`) der Runde, die das neue Verhalten einführt (2a-2 bzw. 2a-3), zusammen mit dem Schreiben der neuen Tests. Der RED-Lauf dieser Runde enthält den Test dann nicht mehr; im GREEN-Schritt existiert er nicht, es wird also kein Test im GREEN umgeschrieben oder entfernt. Die Namen sind neutral gehalten, damit sie nicht an eine Rundennummer gebunden sind.

## Scope

### Affected Files je Runde

**2a-1 (4 Dateien):**

| Datei | Änderung | Inhalt |
|---|---|---|
| `Meditationstimer iOS/Models/ClaudeApply.swift` | CREATE | `ClaudeOrigin`, `ClaudeApplyState`, `ClaudeApplyLogEntry`, `ClaudeApplyResult` und die Funktionen unten (nur `Foundation`) |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | MODIFY | `WorkoutSet` + `claude: ClaudeOrigin?`, `modifiedAt: Date?` |
| `Meditationstimer iOS/Tabs/AtemView.swift` | MODIFY | `Preset` + `claude: ClaudeOrigin?`, `modifiedAt: Date?` |
| `LeanHealthTimerTests/ClaudeApplyTests.swift` | CREATE | Tests der Runde 2a-1 |

**Funktionsaufteilung in `ClaudeApply.swift`** (jede Funktion höchstens 50 Zeilen, `apply` selbst nur Orchestrierung):

| Funktion | Runde | Aufgabe |
|---|---|---|
| `apply(_:to:lastSnapshotAt:now:)` | 2a-1 | Idempotenz-Prüfung, Positionen der Reihe nach auf Arbeitskopie, Ergebnis bilden, Gedächtnis anhängen und kürzen |
| `applyProgram` | 2a-1 | Programm anlegen oder ersetzen, Schritte auflösen |
| `applyBreath` | 2a-1 | Atemübung anlegen oder ersetzen |
| `resolveStepName` | 2a-1 (`builtin.*`), erweitert 2a-2 | Name zur `exerciseId` oder `EXERCISE_UNKNOWN` |
| `isBlockedByIphone` | 2a-1 | Regel 8: `modifiedAt` gegen `lastSnapshotAt` |
| `applyExercise`, `mapCategory` | 2a-2 | Übung anlegen oder ersetzen, Kategorie englisch → `ExerciseCategory` |
| `applyWithdrawal` | 2a-3 | Rücknahme per `itemId` oder `packageId` |

**2a-2 (2 Dateien):** `Meditationstimer iOS/Models/ClaudeApply.swift` (MODIFY: `ClaudeStoredExercise`, `exercises` im Zustand, `applyExercise`, `mapCategory`, Erweiterung `resolveStepName`), `LeanHealthTimerTests/ClaudeApplyTests.swift` (MODIFY).

**2a-3 (2 Dateien):** `Meditationstimer iOS/Models/ClaudeApply.swift` (MODIFY: `applyWithdrawal`), `LeanHealthTimerTests/ClaudeApplyTests.swift` (MODIFY). Neue Typen braucht 2a-3 nicht.

`project.pbxproj`: nicht erwartet (beide Ordner sind synchronisiert, wie in Schnitt 1); wird es wider Erwarten nötig, ist es eine weitere Datei der Runde und im Bericht zu nennen.

### Nicht in Scope (gehört zu Schnitt 2b)

- Laden und Schreiben der Keys `workoutProgramSets`, `atemPresets`, `claudeState` (`UserDefaults`), Schreibreihenfolge Listen zuerst, `claudeState` zuletzt
- Sicherung unlesbarer `atemPresets` (parametrisiertes `backUpUnreadable`); Ablehnung „Liste unlesbar“ samt zugehörigem Code. **Hinweis für 2b:** Die einzige Ausnahme von Regel 4 ist eine unlesbare Liste; sie wird vorübergehend **nicht** ins Gedächtnis geschrieben (Analyse Entscheidung 8), damit die Lieferung nach Reparatur der Liste erneut angewendet werden kann. In 2a kommt dieser Fall nicht vor.
- Neu-Laden offener Tabs per Benachrichtigung
- `modifiedAt` beim Speichern im Editor setzen (nur bei echter Inhaltsänderung)
- Auflösung von `claude.*` in `ExerciseDatabase.info(forId:)` und `displayName` (Laufzeit-Katalog)
- Aufrufer von `apply` jeder Art, `lastSnapshotAt` aus dem Dienst (#57)
- Befunde aus der Analyse (Schritt-Editor macht aus `claude.x` ein `own.*`, Info-Sheet leitet Kennung aus Namen ab, `migratingPresets` und Claude-Programme): 2b bzw. Schnitt 3

### Nicht in Scope (Schnitt 3)

Jede Oberfläche, Kennzeichen „von Claude“, Info-Ansicht, Texte und Lokalisierung, UI-Test. Kein Wiederherstellen.

## Expected Behavior

### Signatur (Ausschnitt, genaue Form bestimmt der Developer)

```swift
struct ClaudeOrigin: Codable, Hashable {                       // 2a-1
    var itemId: String; var revision: Int; var why: String
    var packageId: String?; var packageName: String?; var deliveredAt: Date
}
struct ClaudeApplyState: Codable, Equatable {
    var sets: [WorkoutSet]; var presets: [AtemView.Preset]
    var exercises: [ClaudeStoredExercise]                      // ab 2a-2
    var log: [ClaudeApplyLogEntry]                             // neueste zuletzt, höchstens 50
}
struct ClaudeApplyLogEntry: Codable, Equatable { var deliveryId: String; var result: ClaudeApplyResult; var at: Date }
enum ClaudeApplyResult: Codable, Equatable { case applied; case noEffect; case rejected(code: String, reason: String) }
struct ClaudeStoredExercise: Codable, Equatable {              // ab 2a-2, englische Kategorie wie im Lieferformat
    var claude: ClaudeOrigin
    var name: String; var nameEn: String?; var category: String
    var effect: String; var instructions: String; var notes: String?
}

func apply(_ delivery: ClaudeDelivery, to state: ClaudeApplyState,
           lastSnapshotAt: Date?, now: Date) -> (ClaudeApplyState, ClaudeApplyResult)
```

`WorkoutSet` und `Preset` bekommen `var claude: ClaudeOrigin?` und `var modifiedAt: Date?`; der bestehende `init` behält seine Aufrufform (neue Parameter mit Standardwert `nil`). Synthetisiertes Codable bleibt (optionale Felder werden bei fehlendem Schlüssel `nil`).

### Regeln (Runde in Klammern, wo nicht 2a-1)

1. **Reihenfolge und Arbeitskopie:** Die Positionen werden der Reihe nach auf einer Kopie des Zustands angewendet; spätere Positionen sehen frühere (ein Programm darf ab 2a-2 auf eine Übung derselben Lieferung zeigen). Die Bausteine der Kopie werden nur übernommen, wenn keine Position abgelehnt hat.
2. **Idempotenz:** Steht die `deliveryId` im Gedächtnis (`log`), wird nichts angewendet: Rückgabe ist der unveränderte Zustand und das gemerkte Ergebnis. Das gilt für `applied`, `noEffect` und `rejected`.
3. **Gedächtnis:** Nach jeder Anwendung mit einem Ergebnis, auch `rejected`, wird ein Eintrag (`deliveryId`, Ergebnis, `now`) angehängt; sind es mehr als 50, fallen die ältesten weg.
4. **Ablehnung und Gedächtnis:** Eine Ablehnung lässt die **Bausteine** (Programme, Atemübungen, Übungen) unverändert; „ganz oder gar nicht“ bezieht sich auf sie, nicht auf das Gedächtnis. Das Gedächtnis merkt auch die Ablehnung (`rejected(code, reason)`); eine wiederholte abgelehnte `deliveryId` liefert das gemerkte `rejected` und ändert nichts. Einzige Ausnahme (erst 2b, unlesbare Liste): nicht gemerkt, siehe „Nicht in Scope (2b)“.
5. **Ergebnis der ganzen Lieferung:** abgelehnt, sobald eine Position ablehnt; sonst `applied`, wenn mindestens eine Position etwas geändert hat; sonst `noEffect`.
6. **Neu anlegen:** Unbekannte `itemId` → Baustein neu anlegen. Programm → `WorkoutSet` (`emoji` = `symbol`, `repetitions` = `rounds`, Phasen mit `exerciseId`, aufgelöstem Namen, `workDuration`, `restDuration`, `hint`), Atemübung → `Preset` (`emoji` = `symbol`, `repetitions` = `rounds`, vier Atemzeiten), Übung → `ClaudeStoredExercise` (2a-2). `claude` = `ClaudeOrigin` mit `itemId`, `revision`, `why` und Paket der Lieferung, `deliveredAt` = `createdAt` der Lieferung; `modifiedAt` = `nil`.
7. **Ersetzen:** Höhere `revision` als die gespeicherte (`claude.revision`) ersetzt den Inhalt, behält die lokale UUID, setzt `modifiedAt` = `nil` und übernimmt `revision`, `why`, Paket und `deliveredAt` neu. Gleiche oder niedrigere `revision`: ohne Wirkung.
8. **Das iPhone gewinnt:** Ersetzen (2a-1) und Rücknahme (2a-3) eines Programms oder einer Atemübung mit gesetztem `modifiedAt` werden abgelehnt (`CHANGED_ON_IPHONE`), wenn `lastSnapshotAt` `nil` ist oder `modifiedAt > lastSnapshotAt`. `modifiedAt ≤ lastSnapshotAt` und `modifiedAt == nil` blockieren nicht. Die Prüfung gilt nur, wenn die Position sonst etwas ändern würde (eine gleiche oder niedrigere `revision` wird nie abgelehnt). Übungen haben kein `modifiedAt` und werden nie so abgelehnt.
9. **Rücknahme (2a-3):** `itemId` entfernt den Baustein aus Liste bzw. Übungen; `packageId` entfernt alle Bausteine (Programme, Atemübungen, Übungen) mit diesem Paket. Nichts wiederherstellbar. Unbekannte Kennung: ohne Wirkung. Bei Paket-Rücknahme genügt ein veränderter Baustein, um die ganze Lieferung abzulehnen (Regel 8). Rücknahme einer Übung ist immer erlaubt; Programmphasen, die sie nutzen, bleiben unberührt (Name bleibt in der Phase gespeichert).
10. **Namensauflösung im Programmschritt (`exerciseId`):** `builtin.*` → deutscher Name aus `ExerciseDatabase.info(forId:)` (2a-1); `claude.*` → Name der Übung derselben Lieferung, sonst aus `state.exercises` (2a-2); `own.*` → Name aus einer vorhandenen Phase eines Programms im Zustand mit gleicher `exerciseId` (2a-2). Nicht auflösbar (auch unbekannte `builtin.*`): die ganze Lieferung wird abgelehnt, `EXERCISE_UNKNOWN`. In 2a-1 gilt jede nicht-`builtin`-Kennung als nicht auflösbar.
11. **Von Henning gelöscht:** Ein Baustein, der nicht mehr im Zustand steht, wird bei jeder `revision` neu angelegt (Regel 6). Die Abschrift zeigte die Löschung; Claude liefert also bewusst neu.
12. **Kategorie (2a-2):** Die englische Kategorie der Lieferung (`strength` … `cooldown`) wird über den Fallnamen auf `ExerciseCategory` abgebildet (z. B. `upperBody` → `.upperBody` mit Rohwert „Oberkörper“). Gespeichert wird der englische Text. Ein unbekannter Wert (vom Dienst nicht zu erwarten) lehnt die Lieferung ab mit `CATEGORY_UNKNOWN`.
13. **Reinheit:** Keine Datei, kein `UserDefaults`, keine Benachrichtigung, keine Uhr (Zeit nur über `now`), kein Zufall außer neuen UUIDs für neue Bausteine und Phasen.
14. **Welcher Code bei mehreren Ablehnungen:** Die erste ablehnende Position in Listenreihenfolge der Lieferung bestimmt Code und Grund. Spätere Positionen werden dann nicht mehr bewertet.

### Ergebniscodes (aus den Bezugsdokumenten, nichts erfunden)

| Code | Herkunft | Wann |
|---|---|---|
| `CHANGED_ON_IPHONE` | `claude-annahme.md` Verhalten 4, Grund dort: „Henning hat den Baustein inzwischen geändert; bitte neu lesen“ (Grund-Text wörtlich übernommen) | Regel 8 |
| `EXERCISE_UNKNOWN` | `claude-lieferformat.md` §3.2, §5 | Regel 10 |
| `CATEGORY_UNKNOWN` | `claude-lieferformat.md` §3.1, §5 (Prüfer-Code, hier für denselben Sachverhalt wiederverwendet) | Regel 12 (2a-2) |
| `KIND_NOT_SUPPORTED` | `claude-annahme.md` Verhalten 1; in `read` für reminder/challenge/tracker, hier zusätzlich für Arten, die erst eine spätere Runde anwendet | Zwischenstand 2a-1 (Übung, Rücknahme) und 2a-2 (Rücknahme), siehe Tabelle |
| `APP_CANNOT_READ` | `claude-annahme.md` Verhalten 1 | wird nur von `ClaudeDelivery.read` geworfen, nicht von `apply` |

**Grund-Texte:** Nur der Text zu `CHANGED_ON_IPHONE` stammt aus einem Bezugsdokument. Die Grund-Texte zu `EXERCISE_UNKNOWN`, `CATEGORY_UNKNOWN` und `KIND_NOT_SUPPORTED` in `apply` sind in dieser Spec **neu formuliert** (kurz, deutsch, mit dem Ausweg wie in Konzept 4); der Developer legt den Wortlaut fest, die Tests prüfen Code und „Grund nicht leer“, nicht den Wortlaut.

### Offene Lücken (zur Freigabe, keine PO-Frage)

1. **Ergebnis-Code-Liste fehlt in `claude-lieferformat.md`:** Die dortige Liste (§5) enthält nur Prüfer-Codes; `CHANGED_ON_IPHONE` steht nur in `claude-annahme.md`, ebenso fehlen die Namen der Ergebniszustände `applied`/`noEffect`/`rejected` (kommen aus der Analyse Entscheidung 7). Vorschlag: nur in der Spec führen; Ergänzung der Dokumente übernimmt der Dienst-Schnitt (#57), wenn das Ergebnis dorthin zurückgemeldet wird.
2. **Kein Code für „Liste unlesbar“** und für Fehler beim Schreiben: gehört zu 2b und wird dort festgelegt. (Die frühere Lücke „Abgelehnt wird nicht gemerkt“ ist aufgelöst: Das Gedächtnis merkt jedes Ergebnis, siehe ADR und Regel 4.)
3. **`deliveredAt`:** Das Format kennt nur `createdAt`; 2a setzt `deliveredAt` = `createdAt`. Soll es der Zeitpunkt der App-Übernahme sein, wäre es `now`; Schnitt 3 entscheidet, ob das genügt.
4. **`KIND_NOT_SUPPORTED` im Zwischenstand:** Der Code ist für „App kann die Art noch nicht“ gedacht und passt dem Wortlaut nach; nach 2a-3 kommt er in `apply` nicht mehr vor (nur noch aus `read`).

## Acceptance Criteria

Alle Tests liegen in `LeanHealthTimerTests/ClaudeApplyTests.swift` (Klasse `ClaudeApplyTests`); Namen sind Vorgaben für QA und dürfen nur in der Schreibweise abweichen. Tests dürfen frei in mehrere Tests aufgeteilt werden (kein Konsolidierungszwang, da Tests nicht gegen das Budget zählen). „Leerer Zustand“ = alle Listen leer, `lastSnapshotAt: nil`, feste `now`. **„Zustand unverändert“ bei einer Ablehnung bedeutet: Bausteine (Listen, Übungen) unverändert; das Gedächtnis enthält zusätzlich den Eintrag mit der Ablehnung (Regel 4).** Jede AC gehört genau einer Runde (in Klammern); AC-19 gilt in jeder Runde. „Bedingt“ = wandert bei Rückfall (siehe Zuschnitt).

### Runde 2a-1

- **AC-1a (2a-1): Anlegen Programm und Atemübung.** Given `Contracts/deliveries/valid/program-builtin.json` bzw. `Contracts/deliveries/valid/breath.json` gelesen und leerer Zustand, When `apply`, Then Ergebnis `applied`; Programm: ein `WorkoutSet` mit Name, `emoji` = `symbol`, `repetitions` = `rounds`, je Schritt eine Phase mit `exerciseId`, Dauern, `hint`, Katalognamen, `claude` gefüllt, `modifiedAt` = `nil`; Atemübung (bedingt): ein `Preset` mit allen vier Zeiten, `repetitions`, `emoji`, `claude` gefüllt; Gedächtnis hat genau diese `deliveryId`. Tests: `testAnlegenProgrammMitBuiltinAusBeispielsatz`, `testAnlegenAtemuebungAusBeispielsatz` (bedingt).
- **AC-3 (2a-1): Idempotenz.** Given eine angewendete Lieferung, When dieselbe `deliveryId` erneut angewendet wird (auch mit anderem `lastSnapshotAt` und späterem `now`), Then Zustand identisch zum Zustand nach der ersten Anwendung, Ergebnis gleich dem gemerkten, keine Doppelung. Test: `testZweiteAnwendungLiefertGemerktesErgebnisUndAendertNichts`.
- **AC-4 (2a-1): Gedächtnis höchstens 50.** Given 50 angewendete Lieferungen, When eine 51. angewendet wird, Then 50 Einträge, die erste `deliveryId` ist weg, die 51. ist der neueste Eintrag; die erste, erneut angewendet, wird wieder bewertet statt gemerkt. Test: `testGedaechtnisBehaelt50UndVerwirftAelteste`.
- **AC-5 (2a-1): Ganz oder gar nicht, Ablehnung wird gemerkt.** Given eine Lieferung mit einer anwendbaren Atemübung und einem Programm mit unbekanntem `builtin.*`-Verweis, When `apply`, Then `rejected` mit `EXERCISE_UNKNOWN`; Listen unverändert (die Atemübung ist nicht angelegt); das Gedächtnis enthält genau einen neuen Eintrag mit dieser `deliveryId` und dem `rejected`-Ergebnis. Dasselbe mit `CHANGED_ON_IPHONE` an zweiter Position nach einer anwendbaren ersten. Given dieselbe abgelehnte Lieferung erneut (auch mit anderem `lastSnapshotAt`), Then das gemerkte `rejected` mit gleichem Code, Zustand identisch zum Zustand nach der ersten Ablehnung. Tests: `testAblehnungLaesstBausteineUnveraendertUnbekannterBuiltinVerweis`, `testAblehnungLaesstBausteineUnveraendertChangedOnIphone`, `testZweiteAnwendungEinerAbgelehntenLieferungLiefertGemerktesRejected`.
- **AC-6a (2a-1): Höhere Revision ersetzt Programm und Atemübung.** Given Baustein (Programm und Atemübung) in `revision` 1 ohne `modifiedAt`, When Lieferung mit `revision` 2, Then gleiche lokale UUID, neuer Inhalt, `modifiedAt` = `nil`, `claude.revision` = 2, `why`, Paket und `deliveredAt` neu, Anzahl der Einträge unverändert, Ergebnis `applied`. Test: `testHoehereRevisionErsetztMitGleicherUUID` (Atem-Anteil bedingt).
- **AC-7 (2a-1): Gleiche oder niedrigere Revision.** Given Baustein in `revision` 2, When Lieferung mit `revision` 2 bzw. 1, Then Bausteine unverändert, Ergebnis `noEffect`, das Ergebnis wird gemerkt (zweite Anwendung liefert `noEffect` ohne Neubewertung); auch dann `noEffect` statt Ablehnung, wenn der Baustein `modifiedAt` gesetzt hat. Test: `testGleicheOderNiedrigereRevisionOhneWirkungUndWirdGemerkt`.
- **AC-8a (2a-1): `CHANGED_ON_IPHONE` beim Ersetzen.** Given Programm oder Atemübung (Atemübung bedingt) mit `modifiedAt` und Lieferung mit höherer `revision`, Then abgelehnt mit `CHANGED_ON_IPHONE`, Bausteine unverändert, wenn `modifiedAt > lastSnapshotAt` oder `lastSnapshotAt` = `nil`; ersetzt, wenn `modifiedAt ≤ lastSnapshotAt` (inklusive gleichem Zeitpunkt) und wenn `modifiedAt` = `nil` (auch bei `lastSnapshotAt` = `nil`). Tests: `testChangedOnIphoneBeiModifiedAtNachAbschriftOderAbschriftNil`, `testModifiedAtVorOderGleichAbschriftOderNilBlockiertNicht`.
- **AC-13a (2a-1): Namensauflösung in 2a-1.** Given Schritt mit `builtin.*` (Beispiel `program-builtin.json`), Then Phasenname = deutscher Katalogname. Given ein Programm mit `own.*`- oder `claude.*`-Schritt (auch wenn der Zustand eine passende Phase hätte), Then `rejected` mit `EXERCISE_UNKNOWN`, Bausteine unverändert (Zwischenstand, ab 2a-2 aufgelöst). Tests: `testBuiltinVerweisNutztKatalogNamen`, `testProgrammMitOwnOderClaudeVerweisLehntMitExerciseUnknownAb`.
- **AC-14 (2a-1): Von Henning gelöscht, höhere Fassung neu.** Given ein früher gelieferter Baustein (`revision` 1) wurde aus den Listen entfernt, aber das Gedächtnis kennt die erste Lieferung, When Lieferung mit gleicher `itemId` und `revision` 2 (neue `deliveryId`), Then Baustein wird neu angelegt (neue UUID, `modifiedAt` = `nil`), Ergebnis `applied`. Test: `testGeloeschterBausteinWirdBeiHoehererFassungNeuAngelegt`.
- **AC-15 (2a-1): Alt-JSON bleibt lesbar.** Given gespeicherte JSON-Arrays von `WorkoutSet` und `Preset` im Stand vor dieser Runde (ohne `claude` und `modifiedAt`), When dekodiert, Then Erfolg, beide Felder `nil`, alle übrigen Felder gleich; ein Round-Trip mit gesetzten Feldern bleibt gleich. Test: `testAltJsonWorkoutSetUndPresetLiestSichOhneNeueFelderUndRoundTrip`.
- **AC-20 (2a-1): Noch nicht angewendete Arten (Zwischenstand).** Given eine Lieferung mit einer `exercise`-Position neben einer anwendbaren Atemübung (bzw. mit einer `withdrawal`-Position), When `apply`, Then `rejected` mit `KIND_NOT_SUPPORTED` und nichtleerem Grund, Bausteine unverändert, Ablehnung im Gedächtnis. Tests (befristet, Löschung im RED-Schritt der Runde, die das neue Verhalten einführt): `testUebungslieferungNochNichtUnterstuetzt` (gelöscht in 2a-2), `testRuecknahmeNochNichtUnterstuetzt` (gelöscht in 2a-3).
- **AC-22 (2a-1): Erste ablehnende Position bestimmt den Code.** Given eine Lieferung mit zwei ablehnenden Positionen (Programm mit unbekanntem `builtin.*`-Verweis an erster, Ersetzen eines nach der Abschrift geänderten Bausteins an zweiter Stelle), Then `EXERCISE_UNKNOWN`; in umgekehrter Reihenfolge `CHANGED_ON_IPHONE`; Bausteine beide Male unverändert. Test: `testErsteAblehnendePositionBestimmtDenCode`.
- **AC-21 (2a-1): Start-Nachweis als echter Aktualisierungsweg, objektiv.** Der Ausgangszustand entsteht nicht per Testaufbau, sondern so, wie Henning ihn bekommt: im Simulator (iPhone 17 Pro, iOS 27.2) zuerst den Stand von `main` installieren und starten (legt die Vorgaben im Alt-Format ab), die gespeicherten Programme und Atemübungen aus dem App-Container des Simulators sichern, dann den neuen Stand darüber installieren (ohne Deinstallation) und starten und erneut sichern. Bestanden, wenn **Anzahl, Namen und alle Felder** der Programme und Atemübungen vor und nach dem Update gleich sind (Vergleich der gespeicherten Daten; Screenshots von Workout- und Atem-Tab dazu als Beleg). Beides als Artefakt registriert. Nur 2a-1: 2a-2 und 2a-3 ändern keine gespeicherten Typen.

### Runde 2a-2

- **AC-1b (2a-2): Anlegen Übung mit Programm.** Given `Contracts/deliveries/valid/exercise-and-program.json` gelesen und leerer Zustand, When `apply`, Then Ergebnis `applied`; eine Übung im Zustand (Name, englische Kategorie, `claude.itemId`, `revision`, `why`), ein `WorkoutSet` mit Phasen, deren Namen aus der Übung derselben Lieferung stammen; Gedächtnis hat die `deliveryId`. Test: `testAnlegenUebungUndProgrammAusBeispielsatz`.
- **AC-6b (2a-2): Höhere Revision ersetzt Übung, gleiche oder niedrigere nicht.** Given Übung in `revision` 1, When `revision` 2, Then Inhalt ersetzt, `claude.revision` = 2, Anzahl gleich, `applied`. Given Übung in `revision` 2, When Lieferung mit `revision` 2 bzw. 1, Then Bausteine unverändert, `noEffect`. Tests: `testHoehereRevisionErsetztUebung`, `testUebungGleicheOderNiedrigereRevisionOhneWirkung`.
- **AC-12 (2a-2): `own.*`-Verweis.** Given ein Programm im Zustand mit Phase (`exerciseId` `own.x`, Name „Eigene“), When geliefertes Programm mit Schritt `own.x`, Then neue Phase trägt den Namen „Eigene“. Ohne passende Phase im Zustand: `rejected` mit `EXERCISE_UNKNOWN`, Bausteine unverändert. Beleg über `own-exercise-reference.json`. Tests: `testOwnVerweisLoestNamenAusVorhandenerPhaseAuf`, `testOwnVerweisOhnePhaseLehntMitExerciseUnknownAb`.
- **AC-13b (2a-2): `claude.*`-Verweis.** Given Schritt mit `claude.*`, Then Name aus der Übung derselben Lieferung, sonst aus `state.exercises`; in keinem von beiden: `EXERCISE_UNKNOWN`, Bausteine unverändert. Tests: `testClaudeVerweisNutztLieferungOderZustand`, `testClaudeVerweisUnbekanntLehntAb`. (Der 2a-1-Test `testProgrammMitOwnOderClaudeVerweisLehntMitExerciseUnknownAb` wird in 2a-2 im RED-Schritt gelöscht, weil das Verhalten sich bewusst ändert; er ist wie die Zwischen-Tests befristet.)
- **AC-16 (2a-2): Kategorie (bedingt).** Given jede der neun englischen Kategorien, When abgebildet, Then der jeweilige `ExerciseCategory`-Fall mit deutschem Rohwert (z. B. `strength` → „Kraft“, `cooldown` → „Cool-Down“); `ClaudeStoredExercise` speichert den englischen Text; ein unbekannter Wert lehnt die Lieferung ab (`CATEGORY_UNKNOWN`, Bausteine unverändert). Tests: `testAlleNeunKategorienWerdenAbgebildet`, `testUnbekannteKategorieLehntMitCategoryUnknownAb`.

### Runde 2a-3

- **AC-2 (2a-3): Alle lesbaren Beispiele mit Mindestanzahl.** Given jede lesbare Datei aus `valid/` und ein Zustand, der aus `context.knownExercises` der Datei vorbelegt ist, nämlich **`claude.*`-Kennungen als `ClaudeStoredExercise` in `state.exercises`** (Name aus dem Prüfkontext, übrige Felder feste Testwerte, z. B. `update-with-context.json` mit `claude.vierfuessler-diagonal`) und **nur `own.*`-Kennungen als je eine Phase** mit dieser `exerciseId` und diesem Namen (konsistent mit Regel 10 und AC-13b), When `apply`, Then kein Absturz, Ergebnis `applied` oder `noEffect`, nie `rejected` (insbesondere kein `KIND_NOT_SUPPORTED` mehr). Test: `testAlleLesbarenBeispieleLassenSichAnwenden`. Mindestanzahl wie in Schnitt 1 erzwungen: mindestens 51 Dateien in `valid/`, davon mindestens 32 lesbare. Test: `testApplyBeispielsatzMindestanzahl`.
- **AC-8b (2a-3): `CHANGED_ON_IPHONE` bei Einzel-Rücknahme.** Given ein Programm (bzw. eine Atemübung) mit `modifiedAt` und Rücknahme per `itemId`, Then abgelehnt mit `CHANGED_ON_IPHONE`, Bausteine unverändert, wenn `modifiedAt > lastSnapshotAt` oder `lastSnapshotAt` = `nil`; ohne `modifiedAt` oder bei `modifiedAt ≤ lastSnapshotAt` wird entfernt. Test: `testRuecknahmeEinzelnGeaendertesProgrammAbgelehnt` (deckt beide Arten und beide Seiten der Grenze).
- **AC-9 (2a-3): Rücknahme einzeln.** Given zwei gelieferte Bausteine, When `withdrawal` mit `itemId` des einen, Then dieser ist aus Liste bzw. Übungen entfernt, der andere bleibt, Ergebnis `applied`. Unbekannte `itemId`: `noEffect`. Tests: `testRuecknahmeEinzelnEntferntBaustein`, `testRuecknahmeUnbekannterKennungOhneWirkung`.
- **AC-10 (2a-3): Rücknahme als Paket.** Given Programm, Atemübung und Übung eines Pakets plus ein Baustein ohne Paket (z. B. aus `package-with-withdrawal.json` aufgebaut), When `withdrawal` mit `packageId`, Then alle Bausteine des Pakets weg, der Rest bleibt. Ist einer der Paket-Bausteine nach der Abschrift geändert, wird die ganze Lieferung abgelehnt (`CHANGED_ON_IPHONE`), Bausteine unverändert. Tests: `testRuecknahmePaketEntferntAlleBausteine`, `testRuecknahmePaketMitGeaendertemBausteinAbgelehnt`.
- **AC-11 (2a-3): Rücknahme einer Übung.** Given eine gelieferte Übung und ein bleibendes Programm, dessen Phase auf sie zeigt, When Rücknahme der Übung, Then Übung entfernt (immer erlaubt, auch bei `lastSnapshotAt` = `nil`), das Programm und seine Phasen (Name, `exerciseId`) unverändert. Test: `testRuecknahmeUebungLaesstProgrammphasenStehen`.
- **AC-17 (2a-3): Ergebnis und Zustand Codable.** Given `ClaudeApplyResult` (alle drei Fälle) und ein `ClaudeApplyState` mit Übung, Programm, Atemübung und Gedächtnis (auch ein `rejected`-Eintrag), When kodiert und dekodiert, Then gleich. Test: `testResultUndStateRoundTrip`.
- **AC-18 (2a-3): Reinheit und Abgrenzung.** `ClaudeApply.swift` importiert nur `Foundation` und enthält weder `UserDefaults` noch `NotificationCenter` noch `Date()`. Test: `testApplyDateiIstFoundationOnlyUndOhneSeiteneffekte` (liest die Quelldatei per `#filePath`-Pfad relativ zum Repo, wie `testModellImportiertNurFoundation` in Schnitt 1). In jeder Runde zusätzlich Nachweis in der Adversary-Prüfung per Durchsicht des Diffs: nur die Dateien der Runde plus Specs/Docs, keine Änderung an `WorkoutTab.swift`, `MeditationTab.swift`, `ExerciseDatabase.swift`, `project.pbxproj`.

### Jede Runde

- **AC-19: Bestand bleibt grün und App-Budget eingehalten.** Die vollständige Unit-Suite `LeanHealthTimerTests` läuft grün (bisher 274 Tests, neue kommen hinzu); iOS, Watch und Widget bauen; der **Produktiv-Diff der Runde** (App-Code ohne Tests, Löschzeilen mitgezählt) liegt bei höchstens 250 Zeilen und keine Funktion über 50 Zeilen. Testzeilen zählen nicht. Nachweis: Protokoll `Executed N tests` mit N ≥ 1, Build aller drei Ziele, Zeilenzahl des Produktiv-Diffs im Validierungsbericht.

## Test Plan

- [ ] Unit Test je Runde: die dieser Runde zugeordneten ACs in `ClaudeApplyTests`
- [ ] **RED-Beleg 2a-1:** Übersetzungsfehler der Testdatei, weil `ClaudeApplyState`, `ClaudeApplyResult`, `ClaudeOrigin`, `apply` und die zwei neuen Felder an `WorkoutSet`/`Preset` fehlen (wie Schnitt 1). Kein Gerüst im Produktivcode vor dem RED-Lauf: das Edit-Gate erlaubt in `phase4_tdd_red` nur Testdateien und wird nicht umgangen. Dass die Assertions zur Laufzeit greifen, belegt der GREEN-Lauf (jeder Test mit Assertion zum erwarteten Wert, kein Test ohne Prüfung).
- [ ] **RED-Beleg 2a-2:** Übersetzungsfehler der Testdatei, weil der Typ `ClaudeStoredExercise` und das Feld `exercises` in `ClaudeApplyState` fehlen. Kein Gerüst.
- [ ] **RED-Beleg 2a-3:** 2a-3 braucht keine neuen Typen; die Testdatei übersetzt, und die Rücknahme-Tests (AC-2, 8b, 9, 10, 11) scheitern zur Laufzeit, weil `apply` für `withdrawal` noch `KIND_NOT_SUPPORTED` liefert. Tests, die auf dem Bestand schon grün sind (Round-Trip, Reinheit, Mindestanzahl), sind Absicherungen ohne eigenen RED-Beleg und im RED-Bericht als solche genannt. Kein Gerüst.
- [ ] Unit Test je Runde: vollständige Unit-Suite `LeanHealthTimerTests` grün, `Executed N tests` mit N ≥ 1 (AC-19)
- [ ] UI Test: keiner. Begründung: `apply` hat keinen Aufrufer, nichts ist sichtbar oder bedienbar; Henning sieht erst ab Schnitt 3 etwas. UI-Tests folgen dort (Zeichen „von Claude“, Warum in der Info-Ansicht).
- [ ] Nachweis App-Durchlauf (nur 2a-1, AC-21): Aktualisierungsweg im Simulator, erst Stand von `main`, dann neuer Stand darüber, gespeicherte Programme und Atemübungen vor und nach gleich (Anzahl, Namen, alle Felder), Screenshots als Artefakt; dazu in jeder Runde Build für iOS, Watch und Widget

### Geplante Tests je Runde (Klasse `ClaudeApplyTests`)

**2a-1 (18 Tests):** `testAnlegenProgrammMitBuiltinAusBeispielsatz`, `testAnlegenAtemuebungAusBeispielsatz` (bedingt),
`testZweiteAnwendungLiefertGemerktesErgebnisUndAendertNichts`, `testGedaechtnisBehaelt50UndVerwirftAelteste`,
`testAblehnungLaesstBausteineUnveraendertUnbekannterBuiltinVerweis`, `testAblehnungLaesstBausteineUnveraendertChangedOnIphone`,
`testZweiteAnwendungEinerAbgelehntenLieferungLiefertGemerktesRejected`,
`testHoehereRevisionErsetztMitGleicherUUID`, `testGleicheOderNiedrigereRevisionOhneWirkungUndWirdGemerkt`,
`testChangedOnIphoneBeiModifiedAtNachAbschriftOderAbschriftNil`, `testModifiedAtVorOderGleichAbschriftOderNilBlockiertNicht`,
`testBuiltinVerweisNutztKatalogNamen`, `testProgrammMitOwnOderClaudeVerweisLehntMitExerciseUnknownAb`,
`testGeloeschterBausteinWirdBeiHoehererFassungNeuAngelegt`,
`testAltJsonWorkoutSetUndPresetLiestSichOhneNeueFelderUndRoundTrip`, `testErsteAblehnendePositionBestimmtDenCode`,
`testUebungslieferungNochNichtUnterstuetzt`, `testRuecknahmeNochNichtUnterstuetzt`.

**2a-2 (9 neue Tests, 2 entfallen):** `testAnlegenUebungUndProgrammAusBeispielsatz`, `testHoehereRevisionErsetztUebung`,
`testUebungGleicheOderNiedrigereRevisionOhneWirkung`, `testOwnVerweisLoestNamenAusVorhandenerPhaseAuf`,
`testOwnVerweisOhnePhaseLehntMitExerciseUnknownAb`, `testClaudeVerweisNutztLieferungOderZustand`, `testClaudeVerweisUnbekanntLehntAb`,
`testAlleNeunKategorienWerdenAbgebildet` (bedingt), `testUnbekannteKategorieLehntMitCategoryUnknownAb` (bedingt);
im RED-Schritt gelöscht: `testUebungslieferungNochNichtUnterstuetzt`, `testProgrammMitOwnOderClaudeVerweisLehntMitExerciseUnknownAb`.

**2a-3 (10 neue Tests, 1 entfällt):** `testAlleLesbarenBeispieleLassenSichAnwenden`, `testApplyBeispielsatzMindestanzahl`,
`testRuecknahmeEinzelnGeaendertesProgrammAbgelehnt`, `testRuecknahmeEinzelnEntferntBaustein`, `testRuecknahmeUnbekannterKennungOhneWirkung`,
`testRuecknahmePaketEntferntAlleBausteine`, `testRuecknahmePaketMitGeaendertemBausteinAbgelehnt`, `testRuecknahmeUebungLaesstProgrammphasenStehen`,
`testResultUndStateRoundTrip`, `testApplyDateiIstFoundationOnlyUndOhneSeiteneffekte`;
im RED-Schritt gelöscht: `testRuecknahmeNochNichtUnterstuetzt`.

Zuordnung vollständig: AC-1a, 3, 4, 5, 6a, 7, 8a, 13a, 14, 15, 20, 21, 22 → 2a-1 (Atem-Anteile in AC-1a, 6a, 8a bedingt); AC-1b, 6b, 12, 13b, 16 → 2a-2 (AC-16 bedingt); AC-2, 8b, 9, 10, 11, 17, 18 → 2a-3; AC-19 → jede Runde. Jeder geplante Test steht genau einmal bei der Runde, die ihn einführt.

## Definition of Done (je Runde)

- [ ] Build grün für iOS, Watch und Widget
- [ ] ACs der Runde als Unit-Tests grün, im Protokoll `Executed N tests` mit N ≥ 1
- [ ] Vollständige Unit-Suite grün; Produktiv-Diff der Runde ≤ 250 Zeilen, Funktionen ≤ 50 Zeilen (AC-19)
- [ ] Adversary-Prüfung: Verdict VERIFIED, Diff-Durchsicht (AC-18) bestätigt
- [ ] Nur 2a-1: Start-Nachweis (AC-21) als Artefakt registriert
- [ ] Nur 2a-3: `openspec/specs/features/claude-annahme.md`: Schnitt 2 in 2a (erledigt) und 2b (offen) geteilt, Verweis auf diese Spec; Verhalten 2 um die Abweichung „Übungen in `claudeState` statt Übungskatalog“ ergänzt

## Risiken

- Niedrig: neuer, nicht aufgerufener Code; die zwei neuen Felder sind optional und ändern nur die synthetisierte Gleichheit (`Hashable`) von `WorkoutSet` und `Preset`. Alt-JSON-Test (AC-15) und Start-Nachweis (AC-21) decken das Lesen ab. Prüfen, dass bestehende Tests, die Sets oder Presets vergleichen, unverändert grün bleiben.
- App-Budget 2a-1 ist die knappste Runde (kalibriert rund 210 von 250, Spanne 195–225, Puffer 10–22 %, im Mittel rund 16 %). Gegenmaßnahme: Rückfallregel (Atemübung nach 2a-2) bei mehr als 250 App-Zeilen. Die Grenze wird nicht angehoben, keine Konfigurationsänderung.
- Kalibrierfaktor stammt aus nur einer Runde (Schnitt 1); Messwert vor der Validierung jeder Runde nehmen und bei Ausreißer die Rückfallregel anwenden.
- RED-Beleg 2a-1 und 2a-2 sind Übersetzungsfehler (wie Schnitt 1), kein Laufzeitfehlschlag; ausgeglichen dadurch, dass der Adversary jeden Test auf eine echte Assertion zum erwarteten Wert prüft.
- Watch-/Widget-Build: Die neue Datei hängt von `WorkoutSet` (Tabs) und `AtemView.Preset` ab; die Analyse nahm an, Watch und Widget teilten diese Dateien nicht, die Ausnahmelisten im Projekt sprechen für eine Synchronisierung des ganzen Ordners. Der Build aller Ziele (DoD) entscheidet; scheitert er, bleibt die Datei nur im iOS-Ziel (Ausnahme in der Projektdatei, dann eine weitere Datei).
- Neue UUIDs machen Tests, die ganze Zustände vergleichen, empfindlich: Tests vergleichen Felder, nicht UUIDs, außer wo AC es verlangt (Ersetzen behält UUID).
- Zeit nur über Parameter: Tests dürfen keine Echtzeit verwenden.

## Changelog

- 2026-11-20: Initial spec created (Schnitt 2a von 3, #51)
- 2026-11-20: Überarbeitet nach Validierung INVALID (Zeilengrenze): Schnitt 2a in drei Runden 2a-1 bis 2a-3 geteilt, jede AC und jeder Test genau einer Runde zugeordnet; Zwischenverhalten für noch nicht angewendete Arten festgelegt; AC-8b, `CATEGORY_UNKNOWN`, Start-Nachweis als Aktualisierungsweg, Mindestanzahl-Test zu AC-2
- 2026-11-20: Zweite Überarbeitung nach PO-Entscheidung (Henning, 2026-11-20): Grenze 250 Zeilen gilt je Runde nur für App-Code, Tests zählen nicht, werden aber voll geprüft; Schätzung an Schnitt 1 kalibriert (App ×1,5, Test ×1,9); Rückfallregel als „bedingt“ gekennzeichnet; Konsolidierungszwang der Tests entfällt, Lücken geschlossen; Zwischen-Tests neutral benannt und im RED-Schritt gelöscht; Testanzahl 2a-3 korrigiert; Regel 14 und AC-22 (erste ablehnende Position bestimmt den Code); ADR nennt die Abweichung von `claude-annahme.md` Verhalten 2 (Übungen in `claudeState`); Grund-Texte als neu formuliert gekennzeichnet; AC-21 objektiv; Funktionsaufteilung von `apply` in der Dateiplanung
- 2026-11-20: Dritte Überarbeitung nach vierter Validierung: Gedächtnis an `claude-annahme.md` Verhalten 3 und `claude-lieferformat.md` §7 angeglichen (merkt jedes Ergebnis, auch `rejected`; „ganz oder gar nicht“ gilt für die Bausteine; Ausnahme unlesbare Liste erst 2b), Regeln 2–4, AC-3/5 und Test `testZweiteAnwendungEinerAbgelehntenLieferungLiefertGemerktesRejected` angepasst, frühere offene Lücke „Abgelehnt wird nicht gemerkt“ aufgelöst, ADR und Entscheidung-7-Verweis angepasst; AC-2 legt fest: `claude.*` aus dem Prüfkontext als `ClaudeStoredExercise`, nur `own.*` als Phase; RED-Aussagen vereinheitlicht (kein Gerüst in irgendeiner Runde; RED 2a-1 und 2a-2 Übersetzungsfehler, RED 2a-3 Laufzeitfehlschlag, keine neuen Typen in 2a-3); `WorkoutPhase` als unverändert; `breath` in 2a-1 als „bedingt“; naive Schätzung 2a-1 aus der Funktionsliste hergeleitet (130–150 naiv, kalibriert 195–225, Puffer ehrlich 10–22 %, Rückfallregel bei mehr als 250); „einführende Runde“ präzisiert
