---
entity_id: feature-51-s3-kennzeichen
type: feature
created: 2026-11-22
updated: 2026-11-22
status: draft
workflow: feature-51-s3-kennzeichen
issue: 51
epic: 44
parent: claude-annahme
---

# Schnitt 3: Kennzeichen „von Claude“, Herkunft in den Info-Ansichten, Texte gelieferter Übungen (#51)

## Approval

- [ ] Approved

Freigabe dieser Rundenspec durch den PO.

## Purpose

Schnitt 3 der Elternspec `openspec/specs/features/claude-annahme.md` (Verhalten 7): Was Claude geliefert hat, ist in der App erkennbar. Gelieferte Programme und Atemübungen tragen in der Liste eine kleine Kapsel „von Claude“ (bei Bearbeitung durch Henning „von Claude · angepasst“). Die Info-Ansicht zeigt zusätzlich, wann geliefert wurde, aus welchem Paket und warum. Gelieferte Übungen (`claude.*`) zeigen im Info-Blatt ihre Texte, statt „Übungsinformationen nicht verfügbar“.

Sichtbar für Henning: ein Zeichen an gelieferten Bausteinen, ein Abschnitt „Von Claude“ in deren Info-Ansicht, und dass das Antippen der Info zu einer gelieferten Übung schon beim ersten Mal Texte zeigt.

## Source

- Kontext und Analyse: `DOCS/context/feature-51-s3-kennzeichen.md` (Abschnitt „Analysis“)
- Elternspec: `openspec/specs/features/claude-annahme.md`, Verhalten 7 und Schnitt 3
- Konzept: `DOCS/konzept-claude-verbindung.md` Z. 204 (Zeichen + Detail), Z. 20 (am Platz, gekennzeichnet)
- Entwurf (PO-Freigabe 2026-11-22): Artefakt https://claude.ai/artifact/WuKWhnEjMVANcCUvHDwZis, Quellen und Screenshots in `DOCS/artifacts/feature-51-s3-kennzeichen/`
- Vorgängerrunden: `DOCS/specs/features/feature-51-s2b-speichern.md`, `DOCS/specs/features/feature-51-s2b2-editor.md`

## PO-Entscheidungen (2026-11-22, verbindlich)

1. Das Zeichen ist eine **Kapsel mit Text „von Claude“** unter dem Namen in der Listenzeile.
2. Bei `modifiedAt != nil` lautet sie **„von Claude · angepasst“**.
3. **Kein Gesundheitshinweis**, weder bei Programmen noch bei Atemübungen („Das hat ja der User mit Claude für sich generiert. Ich finde den Hinweis übertrieben.“). Der Satz in Konzept Z. 307 (Hinweis „von Claude zusammengestellt, kein medizinischer Rat“) gilt für die App-Anzeige damit nicht.

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine neue; gilt die ADR der Elternspec. Diese Runde präzisiert nur, wo `claude.*`-Übungen aufgelöst werden (siehe unten).

**Elternspec (Schnitt 3):** „`claude.*` in `ExerciseDatabase.info(forId:)` auflösen.“

**Präzisierung:** `claude.*` wird **nicht** in `ExerciseDatabase.info(forId:)` aufgelöst. Stattdessen:

- `ClaudeStore` bekommt eine öffentliche Lesefunktion `storedExercise(id:defaults:)`, die über das private `loadState` die gelieferte Übung aus `claudeState.exercises` holt und auf `ExerciseInfo` abbildet.
- `ExerciseDetailSheet` bekommt einen Zweig: Kennung beginnt mit `claude.` → `ClaudeStore`, sonst `ExerciseDatabase.info(forId:)` wie bisher.

**Begründung:** `ExerciseDatabase.info(forId:)` ist eine reine, statische Katalogfunktion. Drei Aufrufer setzen „nur Katalog“ voraus (`WorkoutProgramsView.swift:292`, `:1675` und `ClaudeApply.swift:104`, `resolveStepName`). Würde `claude.*` dort aufgelöst, änderte sich deren Verhalten (Anwenden von Lieferungen, Schrittnamen, Bearbeiten). Der einzige Verbraucher, der die Texte braucht, ist das Info-Blatt; dort lässt sich der Zweig lokal halten.

**Platzierung der Views:** Die Lesefunktion und die reine Funktion für den Kapseltext liegen in `ClaudeStore.swift` (importiert nur `Foundation`, bleibt so). Die zwei kleinen SwiftUI-Views `ClaudeOriginBadge` und `ClaudeOriginSection` liegen in `ExerciseDetailSheet.swift` (bereits SwiftUI, von beiden Tabs erreichbar). Das weicht von der Analyse-Tabelle ab, die die Views in `ClaudeStore.swift` vorsah; Grund: `ClaudeStore.swift` bleibt ohne UI-Import testbar.

## Scope

App-Code (5 Dateien, geschätzt +150 bis +200 / −10 Zeilen; Grenze ±250 gilt nur für App-Code, Tests zählen nicht):

- `Meditationstimer iOS/Models/ClaudeStore.swift` (MODIFY: `storedExercise(id:defaults:)`, Abbildung auf `ExerciseInfo` mit Kategorie über `mapCategory` und Rückfall, reine Funktion `badgeText(modifiedAt:)` für den Kapseltext)
- `Meditationstimer iOS/Views/ExerciseDetailSheet.swift` (MODIFY: Zweig `claude.*`, Zeile „Von Claude geliefert am <Datum>“, neue Views `ClaudeOriginBadge`, `ClaudeOriginSection`)
- `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` (MODIFY: `WorkoutSetRow` ab Z. 1238 Kapsel + Info-Knopf-Bedingung + Kennungen; `PresetInfoSheet` ab Z. 1330 Abschnitt „Von Claude“ und „Empfohlene Anwendung“ ausblenden; `phaseRow` ab Z. 1444 und das `.sheet` in Z. 1434 auf `.sheet(item:)` mit `phase.exerciseId`)
- `Meditationstimer iOS/Tabs/AtemView.swift` (MODIFY: `Row` ab Z. 170 Kapsel + Info-Knopf-Bedingung + Kennungen; `PresetInfoSheet` ab Z. 260 Abschnitt „Von Claude“ und „Empfohlene Anwendung“ ausblenden)
- `Meditationstimer iOS/Localizable.xcstrings` (MODIFY: DE/EN-Texte)

Tests (zählen nicht zum Budget): `LeanHealthTimerTests/ClaudeKennzeichenTests.swift` (neu), `LeanHealthTimerUITests/ClaudeKennzeichenUITests.swift` (neu).

Unverändert: `ClaudeApply.swift` (Quelltext-Wächter `testApplyDateiIstFoundationOnlyUndOhneSeiteneffekte`), `ExerciseDatabase.swift`, `project.pbxproj` (neue Testdateien werden vom Test-Target erfasst; falls nicht, nur dieser Eintrag).

## Nicht in Scope

- #91 (Kategorie im Übungs-Info deutsch statt englisch): die Kategorie zeigt weiter `ExerciseCategory.rawValue` wie im Katalog.
- Watch und Widget (kompilieren `Meditationstimer iOS` nicht mit; Build-Wächter bleibt).
- Kennzeichnung weiterer Arten (Erinnerung, Challenge, Tracker; B4b bis B6b).
- Gesundheitshinweis (PO-Entscheidung 3).
- Abschrift an Claude (#57), Änderung der Lieferlogik oder `ClaudeApply.swift`.
- Kennzeichen an einzelnen Schritten (Zeilen) innerhalb eines Programms.

## Dependencies

| Abhängigkeit | Art | Hinweis |
|---|---|---|
| `ClaudeOrigin` (`itemId`, `revision`, `why`, `packageId`, `packageName`, `deliveredAt`) auf `WorkoutSet.claude` / `AtemView.Preset.claude` | Upstream (Bestand) | `deliveredAt` ist `createdAt` der Lieferung |
| `WorkoutSet.modifiedAt`, `Preset.modifiedAt` | Upstream (2b-2) | Quelle für „angepasst“ |
| `ClaudeStoredExercise` in `claudeState.exercises` | Upstream (2a/2b-1) | Felder `name`, `category` (englisch), `effect`, `instructions`, `notes`, `claude` |
| `mapCategory(_:)` (`ClaudeApply.swift:96`) | Upstream, nur lesen | englisch → `ExerciseCategory` |
| `ExerciseDatabase.displayName` | Bestand | löst `claude.*` schon über den gespeicherten Namen |
| DEBUG-Einstieg `uitest-claude-apply` + `UITEST_CLAUDE_DELIVERY` (`Meditationstimer_iOSApp.swift`) | Test-Hebel (Bestand) | wendet beim Start eine Lieferung an |
| #57, B4b bis B6b | Downstream | |

## Befund (Ist-Stand, am Code gelesen 2026-11-22)

1. `WorkoutSetRow` (`WorkoutProgramsView.swift:1238`) und `AtemView.Row` (`AtemView.swift:170`) sind baugleich; der Info-Knopf erscheint nur bei `description != nil` (Z. 1279 bzw. 210). Eine gelieferte Atemübung ohne `description` (`breath-minimal.json`) hat dadurch keinen Weg zu Datum, Paket und Warum.
2. Beide `PresetInfoSheet` zeigen „Empfohlene Anwendung“ mit einem Standardtext („Regular execution for best results.“ bzw. „Regular practice for best results.“); bei Claude-Bausteinen ist das inhaltsleer.
3. `PresetInfoSheet.phaseRow` (Z. 1444) setzt nur `selectedExerciseName` und `showExerciseSheet = true`; das Blatt (Z. 1434) löst die Kennung über `ExerciseDatabase.exerciseId(forName:)` auf. Für `claude.*` trifft das nie, und beim ersten Tippen kann der Name noch nicht gesetzt sein, weil `.sheet(isPresented:)` mit getrenntem Name-State arbeitet (offen als #90).
4. `ExerciseDetailSheet` kennt nur `ExerciseDatabase.info(forId:)`; für `claude.*` erscheint „Übungsinformationen nicht verfügbar“ (Z. 100).
5. Atem-Zeilen haben keine UI-Kennungen; Programm-Zeilen kennen `.start` und `.edit`.

## Festlegungen (Tech-Lead)

Verbindlich ist das beschriebene Verhalten; ein neuer Name darf bei der Umsetzung nur mit Begründung im RED-Bericht abweichen.

1. **Lesefunktion:** `ClaudeStore.storedExercise(id: String, defaults: UserDefaults = .standard) -> ExerciseInfo?`. Gibt für eine Kennung mit Präfix `claude.`, die in `claudeState.exercises` als `claude.itemId` steht, ein `ExerciseInfo` (`id`, `name`, `category`, `effect`, `instructions`, `notes`) zurück, sonst `nil` (auch für `builtin.*`, `own.*`, unbekannte Kennungen). Kategorie über `mapCategory`; bei `nil` Rückfall auf `.fullBody` (gespeicherte Übungen sind bei Annahme geprüft, Regel 12; der Rückfall verhindert nur „nicht verfügbar“ wegen der Kategorie). Die Herkunft (`ClaudeOrigin`) für die Zeile „Von Claude geliefert am“ liefert eine zweite kleine Lesefunktion (`ClaudeStore.storedExerciseOrigin(id:defaults:) -> ClaudeOrigin?`); der Name ist frei, das Verhalten ist verbindlich.
2. **Kapseltext (rein):** `ClaudeStore.badgeText(modifiedAt: Date?) -> String`: `modifiedAt == nil` → „von Claude“, sonst „von Claude · angepasst“ (lokalisiert). Keine Uhr, kein Zugriff auf `UserDefaults`.
3. **`ClaudeOriginBadge(modifiedAt:)`:** kleine Kapsel (Text aus `badgeText`), in Workout- und Atem-Zeile unter dem Namen; Kennung je Zeile (siehe UI-Kennungen). Wird nur gerendert, wenn `claude != nil`.
4. **`ClaudeOriginSection(origin:)`:** Abschnitt „Von Claude“ am Ende der Info-Ansicht (beide Tabs): „Geliefert am <Datum>“; darunter „Paket „<packageName>““ nur bei `packageName != nil`; darunter das „Warum“ (`origin.why`, Überschrift „Warum“). Das Datum wird mit `Date.FormatStyle` (`date: .numeric, time: .none`) in der Gerätesprache formatiert (DE `13.11.2026`, EN `11/13/2026`).
5. **Info-Knopf:** erscheint, wenn `claude != nil` **oder** `description != nil` (und `showInfo` gesetzt). Bei `claude != nil` immer, auch ohne `description`.
6. **„Empfohlene Anwendung“** entfällt bei `claude != nil` (Bedingung am Feld, nicht am Text). Bei eingebauten und eigenen Bausteinen bleibt sie unverändert.
7. **Übungs-Info (`ExerciseDetailSheet`):** Kennung (`exerciseId ?? ExerciseDatabase.exerciseId(forName:)`) mit Präfix `claude.` → `ClaudeStore.storedExercise`, sonst Katalog. Zusätzlich unter den Abschnitten die Zeile „Von Claude geliefert am <Datum>“ (nur bei `claude.*`). Findet sich zu einer `claude.*`-Kennung nichts im Zustand (zurückgenommen), bleibt der bestehende Fallback „nicht verfügbar“.
8. **#90 mitlösen:** `PresetInfoSheet` ersetzt `showExerciseSheet` + `selectedExerciseName` durch einen `@State` auf ein `Identifiable` (Name + `phase.exerciseId`) und `.sheet(item:)`; `phaseRow` setzt dieses Element mit `phase.exerciseId`. Der bestehende Hilfstyp `ExerciseSheetWrapper` (Z. 1473) darf erweitert oder ersetzt werden. Begründung: dieselben Zeilen, ohne die Änderung hätte die Claude-Übung beim ersten Tippen kein Blatt.
9. **Lokalisierung (DE → EN):** „von Claude“ → „from Claude“; „von Claude · angepasst“ → „from Claude · edited“; „Von Claude“ → „From Claude“; „Geliefert am %@“ → „Delivered on %@“; „Paket „%@““ → „Package “%@”“; „Warum“ → „Why“; „Von Claude geliefert am %@“ → „Delivered by Claude on %@“. Einträge mit `"extractionState": "manual"` und `"state": "translated"` (Lehre aus Bug 38: Schlüssel ohne Übersetzung erscheinen im Debug-Build in Großbuchstaben).
10. **Keine Änderung** an `ExerciseDatabase.info(forId:)`, `resolveStepName`, `apply`, Editoren oder Speicherformat.

## UI-Kennungen (neu)

| Kennung | Element |
|---|---|
| `atem.row.<Name>.info` | Info-Knopf der Atem-Zeile |
| `atem.row.<Name>.claudeBadge` | Kapsel der Atem-Zeile |
| `workout.programRow.<Name>.info` | Info-Knopf der Programm-Zeile |
| `workout.programRow.<Name>.claudeBadge` | Kapsel der Programm-Zeile |

Zusätzlich im Info-Abschnitt `claudeOrigin.deliveredAt`, `claudeOrigin.package`, `claudeOrigin.why` (Texte) und im Übungs-Info `exerciseDetail.claudeOrigin`. `<Name>` ist der Anzeigename des Bausteins, wie bei `.start`/`.edit`.

## Expected Behavior

- Input: Henning öffnet Workout- oder Meditation-Tab mit gelieferten Bausteinen, tippt die Info eines Bausteins, dann die Info einer Übung im Programm.
- Output: Gelieferte Bausteine tragen die Kapsel; die Info zeigt Abschnitt „Von Claude“; die Übungs-Info zeigt bei gelieferten Übungen Name, Kategorie, Wirkung, Ausführung (+ Hinweise) und Lieferdatum.
- Side effects: Keine. Rein lesend, kein Schreiben in `UserDefaults`, kein neues Speicherformat, kein Eingriff in Anwenden oder Editieren.

## Acceptance Criteria

Alle als Given/When/Then; „Unit“ = `LeanHealthTimerTests/ClaudeKennzeichenTests.swift`, „UI“ = `LeanHealthTimerUITests/ClaudeKennzeichenUITests.swift`.

- **AC-1 (Unit): Lesefunktion löst gelieferte Übung auf.** Given ein `claudeState` mit einer `ClaudeStoredExercise` (`claude.vierfuessler-diagonal`, Kategorie `core`, Wirkung, Ausführung, `notes == nil`), When `storedExercise(id: "claude.vierfuessler-diagonal", defaults:)`, Then liefert sie ein `ExerciseInfo` mit gespeichertem Namen, `category == .core`, Wirkung und Ausführung unverändert. Test: `testStoredExerciseResolvesClaudeIdFromState`.
- **AC-2 (Unit): Unbekannt oder Katalog liefert nil.** Given derselbe Zustand, When `storedExercise` mit `builtin.planke`, `own.mein-schritt`, `claude.gibt-es-nicht` und einem leeren `claudeState`, Then ist das Ergebnis jeweils `nil`. Test: `testStoredExerciseReturnsNilForUnknownOrBuiltinId`.
- **AC-3 (Unit): Abbildung mit Hinweisen und Kategorie-Rückfall.** Given eine gespeicherte Übung mit `notes == "Langsam"` und eine mit unbekannter Kategorie (`"unknown"`), When `storedExercise`, Then trägt die erste `notes == "Langsam"`, die zweite ein `ExerciseInfo` mit `category == .fullBody` (nicht `nil`). Test: `testExerciseInfoMapsCategoryEffectInstructions`.
- **AC-4 (Unit): Kapseltext ohne Bearbeitung.** Given `modifiedAt == nil`, When `badgeText`, Then „von Claude“ (Gerätesprache DE). Test: `testBadgeTextPlainWhenNotModified`.
- **AC-5 (Unit): Kapseltext mit Bearbeitung.** Given `modifiedAt != nil`, When `badgeText`, Then „von Claude · angepasst“. Test: `testBadgeTextShowsAngepasstWhenModified`.
- **AC-6 (UI): Gelieferte Programm-Zeile trägt die Kapsel.** Given ein Start mit `enable-testing`, `uitest-claude-apply` und einer Lieferung in der Form von `package-mixed.json` (Programm mit eindeutigem Testnamen, Paketname, `why`), When der Workout-Tab geöffnet wird, Then existiert `workout.programRow.<Name>.claudeBadge` mit Text „von Claude“, und eingebaute Programme (z. B. „Tabata Classic“) haben **keine** Kapsel. Tests: `testWorkoutRowShowsClaudeBadgeAndInfoShowsPackageAndWhy` (Teil Kapsel), `testBuiltinProgramHasNoClaudeBadge`.
- **AC-7 (UI): Info-Ansicht des Programms zeigt Herkunft.** Given AC-6, When `workout.programRow.<Name>.info` getippt wird, Then zeigt das Blatt den Abschnitt „Von Claude“ mit „Geliefert am“ und Datum, „Paket“ mit dem Paketnamen und das „Warum“ aus der Lieferung, und es gibt keinen Abschnitt „Empfohlene Anwendung“ und keinen Gesundheitshinweis. Test: `testWorkoutRowShowsClaudeBadgeAndInfoShowsPackageAndWhy`.
- **AC-8 (UI): Gelieferte Atemübung trägt Kapsel und Info.** Given ein Start mit einer Atemübung in der Form von `package-mixed.json` (mit `description`), When der Meditation-Tab geöffnet und `atem.row.<Name>.info` getippt wird, Then existiert `atem.row.<Name>.claudeBadge` („von Claude“), und das Blatt zeigt Abschnitt „Von Claude“ mit Datum, Paket und Warum, ohne „Empfohlene Anwendung“. Test: `testBreathRowShowsClaudeBadgeAndInfo`.
- **AC-9 (UI): Info-Knopf auch ohne Beschreibung.** Given eine Lieferung in der Form von `breath-minimal.json` (Atemübung ohne `description`, ohne Paket), When der Meditation-Tab geöffnet wird, Then existiert `atem.row.<Name>.info`; nach dem Tippen zeigt das Blatt „Geliefert am“ und das Warum, aber keine Zeile „Paket“. Test: `testBreathMinimalDeliveryStillHasInfoButton`.
- **AC-10 (UI): Gelieferte Übung zeigt ihre Texte beim ersten Tippen.** Given eine Lieferung mit Übung (`claude.*`, Kategorie `core`, Wirkung, Ausführung) und einem Programm, dessen Schritt diese Übung nutzt, When die Info des Programms und darin gleich beim **ersten** Antippen die Übungs-Info der Schritt-Zeile getippt wird, Then zeigt das Blatt `exerciseDetail.effect` und `exerciseDetail.instructions` mit den gelieferten Texten, die Kategorie, die Zeile „Von Claude geliefert am“ mit Datum, und nicht „Übungsinformationen nicht verfügbar“. Deckt #90 (Erst-Tipp). Test: `testClaudeExerciseInfoShowsTextsOnFirstTap`.
- **AC-11 (UI): „angepasst“ nach Bearbeitung.** Given ein gelieferte Programm, das Henning im Editor umbenennt und speichert (Weg wie `ClaudeSpeichernUITests/testBearbeitetesClaudeProgrammBleibtBeiNeuerRevision`: `openProgramEditor`, Namensfeld ändern, `workout.setEditor.save`), When der Workout-Tab wieder sichtbar ist, Then trägt `workout.programRow.<NeuerName>.claudeBadge` den Text „von Claude · angepasst“, und vor dem Bearbeiten stand dort „von Claude“. Der Teardown löscht das bearbeitete Programm über den Editor (Muster `editedProgramNames`). Test: `testEditedClaudeProgramShowsAngepasst`.
- **AC-12 (Unit + UI): Katalogübungen und eigene Bausteine bleiben unverändert.** Given ein eingebautes oder eigenes Programm bzw. eine eingebaute Atemübung (`claude == nil`), Then gibt es weder Kapsel noch Abschnitt „Von Claude“, der Info-Knopf folgt weiter `description != nil`, „Empfohlene Anwendung“ erscheint wie bisher, und die Übungs-Info einer Katalogübung (`builtin.*`) zeigt wie bisher ihre Katalogtexte ohne Zeile „Von Claude geliefert am“. Nachweis: `testBuiltinProgramHasNoClaudeBadge` (UI) und `testStoredExerciseReturnsNilForUnknownOrBuiltinId` (Unit).
- **AC-13 (UI): Englische Texte.** Given der Start mit `-AppleLanguages (en)` und einer Lieferung wie in AC-6, When Kapsel und Info-Abschnitt gezeigt werden, Then lauten die Texte „from Claude“, „From Claude“ und „Delivered on 11/13/2026“ (Festlegung 9), ohne deutsche Texte und ohne Großbuchstaben-Schlüssel. Test: `testClaudeBadgeIsLocalizedInEnglish`.
- **AC-14 (jede Runde): Reinheit, Build, Budget.** Given der Diff der Runde, Then ist `ClaudeApply.swift` unverändert und `testApplyDateiIstFoundationOnlyUndOhneSeiteneffekte` grün; `ClaudeStore.swift` importiert nur `Foundation`; iOS, Watch und Widget bauen; der Produktiv-Diff (App-Code ohne Tests, Löschzeilen mitgezählt) liegt bei höchstens 250 Zeilen, keine Funktion über 50 Zeilen; Protokoll `Executed N tests` mit N ≥ 1; die bestehenden Tests (`ClaudeStoreTests`, `ClaudeSpeichernUITests`, `ClaudeFelderUITests`) bleiben grün.

## Herstellung der UI-Testlagen

- **Lieferung:** DEBUG-Startargument `uitest-claude-apply` plus Umgebungsvariable `UITEST_CLAUDE_DELIVERY` (JSON-Text), Muster `launch(delivery:)` aus `ClaudeSpeichernUITests.swift`. Die Test-JSONs folgen der Form von `Contracts/deliveries/valid/package-mixed.json` (Übung + Programm + Atemübung + `package` + `why`) und `breath-minimal.json` (Atemübung ohne `description`, ohne `package`). Die Beispieldateien sind Verträge mit Hüllfeld `delivery`; die UI-Tests bauen den JSON-Text inline mit eindeutigen Namen und eigener `packageId` (wie `deliveryJSON` dort), weil die App im Simulator keinen Zugriff auf das Repo hat und Programme in `UserDefaults` zwischen Läufen bestehen bleiben. Die Unit-Tests dürfen die Contract-Dateien lesen.
- **Aufräumen:** Rücknahme per Paket (`withdrawalJSON(packageId:)`) im Teardown; von Henning geänderte Programme (AC-11) werden im Editor gelöscht, weil die Rücknahme sie mit `CHANGED_ON_IPHONE` ablehnt (Muster `editedProgramNames` aus `ClaudeSpeichernUITests`).
- **„angepasst“ (AC-11):** Es gibt keinen Testeinstieg, der `modifiedAt` setzt; der Weg ist der echte: gelieferte Programm im Editor ändern und speichern (2b-2 setzt `modifiedAt` über `ClaudeStore.savingEdit`). Das beweist zugleich die Kette Lieferung → Bearbeitung → Kennzeichen.
- **Tabs** haben keine Kennung: positionsbasiert (`openTab(0)` Meditation, `openTab(1)` Workout), nach jedem Neustart erneut.
- **Datum:** die Lieferungen tragen `createdAt` `2026-11-13T10:15:00Z`; der Test prüft die Anzeige `13.11.2026` (DE), in allen realen Zeitzonen derselbe Kalendertag.

## Alternativen (verworfen)

- **A – `claude.*` direkt in `ExerciseDatabase.info(forId:)`** (Elternspec wörtlich): verändert drei Katalog-Aufrufer, die „nur Katalog“ voraussetzen. Verworfen.
- **B – Nur Funkel-Symbol hinter dem Namen, kein Text:** weniger Platz, aber „angepasst“ nicht darstellbar und ohne Text für Henning unklar. Im Entwurf als Alternative gezeigt, vom PO nicht gewählt.
- **C – Herkunft als Karte oben in der Info statt Abschnitt unten:** drängt Name und Struktur nach unten. Verworfen.
- **D – #90 getrennt lassen:** der UI-Test auf die Claude-Übungs-Info müsste um den Erst-Tipp-Fehler herumgebaut werden, und gelieferte Übungen hätten beim ersten Tippen kein Blatt. Verworfen, gehört zum Feature.
- **E – Gesundheitshinweis (Konzept Z. 307):** vom PO verworfen.

## Risiken

- **Zentrale Stelle ist die Übungs-Auflösung im Programm-Info-Blatt:** der Wechsel auf `.sheet(item:)` ändert das Verhalten für alle Programme. Absicherung: AC-10 (Erst-Tipp bei `claude.*`) und AC-12 (Katalogübung unverändert); ein Bestandsdurchlauf der bestehenden Übungs-Info-Tests (`exerciseDetail.effect`).
- **Datumsanzeige und Zeitzone:** `createdAt` ist UTC; um 10:15 UTC liegt der Tag in allen realen Zeitzonen gleich. Test prüft die Gerätesprache, nicht die Zone.
- **Lokalisierung:** Fehlende Übersetzung erscheint im Debug-Build in Großbuchstaben (Bug 38); AC-13 prüft darauf.
- **Namensbasierte Kennungen:** `<Name>` muss in den UI-Tests wie bei `.start`/`.edit` funktionieren; Testnamen sind eindeutig und ASCII.
- **Layout:** Die Kapsel verlängert die Zeile um eine Höhe; `minHeight: 140` bleibt, bei langen Namen und großer Schrift muss die Zeile mitwachsen. Prüfung im Simulator mit Screenshot (Dunkel und Hell).
- **Überlagerungen im Zugänglichkeitsbaum:** verdeckte Knöpfe bleiben im Baum (Lehre aus Cluster D); Tests prüfen `isHittable` und das tatsächlich sichtbare Blatt, nicht nur `exists`.
- **Budget:** geschätzt +150 bis +200 Zeilen App-Code; bei Überschreitung von 250 STOP und Schnitt in zwei Runden (Kapsel + Info-Ansichten / Übungs-Info + #90).
- **Watch/Widget:** kompilieren `Meditationstimer iOS` nicht; Build-Wächter bleibt in der Abschlussprüfung.

## Test Plan

- [ ] Unit (neue Datei `LeanHealthTimerTests/ClaudeKennzeichenTests.swift`): AC-1 bis AC-5 und der Unit-Anteil von AC-12
- [ ] UI (neue Datei `LeanHealthTimerUITests/ClaudeKennzeichenUITests.swift`): AC-6 bis AC-13; Aufruf `./Scripts/run-uitests.sh ClaudeKennzeichenUITests/<Methode>` (immer mit Klasse); Nachweis nur mit `Executed N tests`, N ≥ 1
- [ ] Bestand: vollständige Unit-Suite, `ClaudeApplyTests`-Quelltextwächter, `ClaudeSpeichernUITests`, `ClaudeFelderUITests`
- [ ] RED-Beleg: Die neuen Tests scheitern zuerst, weil Lesefunktion, `badgeText`, Kapsel, Abschnitt und Kennungen fehlen und die Claude-Übungs-Info „nicht verfügbar“ zeigt
- [ ] Durchlauf als Nutzer im Simulator vor Übergabe: Paket liefern, Kapsel sehen, Info öffnen, Übungs-Info beim ersten Tippen, Programm bearbeiten und „angepasst“ sehen, Screenshots Dunkel und Hell (kein Gerät von Henning)

## Definition of Done

- [ ] Build grün für iOS, Watch und Widget
- [ ] ACs AC-1 bis AC-14 nachgewiesen, im Protokoll `Executed N tests` mit N ≥ 1
- [ ] Vollständige Unit-Suite und die genannten UI-Tests grün
- [ ] Produktiv-Diff ≤ 250 Zeilen, Funktionen ≤ 50 Zeilen
- [ ] Adversary-Prüfung: Verdict VERIFIED
- [ ] `openspec/specs/features/claude-annahme.md` nachgezogen: Schnitt 3 erledigt (inkl. Präzisierung zu `ExerciseDatabase.info(forId:)`), #57 offen; #90 geschlossen
- [ ] Änderungen am Gerät von Henning: keine, kein Start auf seinen Geräten

## Changelog

- 2026-11-22: Angelegt als Rundenspec Schnitt 3 aus Analyse und Entwurf (PO-Entscheidungen: Kapsel „von Claude“, „angepasst“ bei Bearbeitung, kein Gesundheitshinweis). Präzisierung zur Elternspec: `claude.*` über `ClaudeStore` + Zweig im Sheet, nicht in `ExerciseDatabase.info(forId:)`. #90 mitgelöst.
