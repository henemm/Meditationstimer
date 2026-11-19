# Context: fix-25c-tracker-anlage (#25, Runde 25c — Cluster C)

## Request Summary
Die zwei UI-Tests aus Cluster C von #25 sind seit Februar rot. Sie sollen grün werden und dabei weiterhin das
prüfen, wofür sie gebaut wurden: Eine Gewohnheit aus einer Vorlage erscheint nach dem Anlegen in der Liste
(C1) und übersteht einen Neustart der App (C2).

## Reproduktion (2026-11-18, iPhone 17 Pro, iOS 27.2, Stand 5a5ca62)
Skript `run-uitests.sh` mit `SIMULATOR_OS=27.2` (Kopie im Scratchpad, weil iOS 26.5 nicht mehr installiert
ist — eigenes Ticket #74/#77, nicht Teil dieser Runde).

| Test | Ergebnis | Stelle |
|------|----------|--------|
| `testPresetTapCreatesVisibleTracker` | rot, 3/3 Wiederholungen | `:313` „Add Tracker button should exist" |
| `testTrackerCreationFromPresetPersistsAfterRestart` | rot | `:396` „Doomscrolling tracker should persist after app restart" |

C2 kommt bis `:382` durch: Anlegen und Anzeigen funktionieren, nur der Teil nach dem Neustart scheitert.

## Ursachen (belegt)
- **C1 — Testschuld, Sprache:** Der Test startet mit `-AppleLanguages (de)`, sucht aber
  `app.buttons["Add Tracker"]`. XCUITest vergleicht den Schlüssel mit Kennung oder Beschriftung; die
  Beschriftung lautet auf Deutsch „Tracker hinzufügen" (`Localizable.xcstrings:868`), die Kennung
  `addTrackerButton` (`TrackerTab.swift:157`). Kein Treffer → rot. Die App ist richtig.
- **C2 — Testschuld, Testmodus:** `enable-testing` schaltet seit `68c4f9f` (2026-01-17, „SwiftData in-memory
  config for UI tests prevents crashes") den Speicher auf „nur im Arbeitsspeicher"
  (`Meditationstimer_iOSApp.swift:32-43`). Der Test kam acht Tage später (`e7f467e`, 2026-01-25) und startet
  die App beim zweiten Mal mit demselben Argument neu — ein frischer, leerer Speicher. Er konnte in dieser
  Form nie grün sein. Ob die App wirklich speichert (`AddTrackerSheet.swift:107-111`:
  `createFromPreset` → `modelContext.save()` → `dismiss()`), prüft er dadurch gar nicht.

## Related Files
| File | Relevance |
|------|-----------|
| `LeanHealthTimerUITests/LeanHealthTimerUITests.swift:293-397` | Die beiden Tests |
| `Meditationstimer iOS/Meditationstimer_iOSApp.swift:31-50` | Speicherwahl unter `enable-testing` (einzige Stelle, die Startargumente liest) |
| `Meditationstimer iOS/Tabs/TrackerTab.swift:140-158` | „Tracker hinzufügen"-Karte, Kennung `addTrackerButton` |
| `Meditationstimer iOS/Tracker/AddTrackerSheet.swift:107-111` | Anlegen aus Vorlage, Speichern, Schließen |

## Existing Patterns
- Andere Tests (`:770`, `:821`, `:3078`) nutzen ebenfalls `app.buttons["Add Tracker"]`, aber in englischer
  Sprache — dort trifft die Beschriftung. Sprachunabhängig ist nur die Kennung `addTrackerButton`.
- Runde 25b: Testschuld wird im Test behoben, App bleibt unverändert, wenn sie richtig arbeitet.
- `enable-testing` ist nur in DEBUG wirksam (`#if DEBUG`).

## Recherche
- Kein Apple-Muster für „Speicher bleibt über Neustart im UI-Test"; verbreitet ist nur das Gegenteil
  (In-Memory für saubere Läufe). Vorschlag aus der Praxis: Startargument wählt eine eigene Speicherdatei
  (`ModelConfiguration(url:)`), ein zweites Argument löscht sie beim Start. Der Testprozess selbst kann die
  Datei nicht löschen (eigene Sandbox), deshalb muss das Zurücksetzen in der App per Argument passieren.
- Quellen: Apple-Forum „SwiftData in-memory ModelContainer causes DefaultStore validation errors"
  (developer.apple.com/forums/thread/825727), Hacking with Swift „How to write UI tests for your SwiftData
  code", Apple-Doku `ModelConfiguration.isStoredInMemoryOnly`.

## Lösungsrichtung (Analyse, in einem Durchgang)
- **C1:** Knopf über die Kennung `addTrackerButton` ansprechen. Nur Test.
- **C2, Empfehlung:** Neues DEBUG-Startargument (z. B. `uitest-disk-store`) wählt eine eigene Datei
  (getrennt vom normalen Speicher des Simulators), `uitest-reset-store` löscht sie vor dem Öffnen. Test: erster
  Start mit beiden, Neustart nur mit `uitest-disk-store`. Prüft die echte Kette Vorlage → Speichern → Neustart.
  2 Dateien (App-Start + Test), ca. 25 Zeilen.
- **C2, Alternative:** Neustart-Teil streichen und Speichern per Unit-Test mit Datei-Container prüfen
  (`createFromPreset` → `save` → Container neu öffnen). Kein App-Code, aber prüft nicht, dass das Blatt
  `save()` aufruft — genau das war der ursprüngliche Fehler.
- **C2, verworfen:** `enable-testing` generell auf Datei umstellen — kippt `68c4f9f` (Abstürze, Wechselwirkung
  zwischen Tests).

## Risks & Considerations
- App-Start ist kritischer Pfad: Änderung strikt unter `#if DEBUG`, Normalstart unverändert.
- Eigene Datei, damit Daten des normalen Simulator-Speichers nie berührt werden.
- Doomscrolling darf im Test-Speicher nicht schon vorhanden sein → Zurücksetzen beim ersten Start Pflicht.

## Analysis

### Type
Bug (Testschuld in beiden Fällen; App-Logik zum Speichern bleibt unverändert, nur ein DEBUG-Testschalter kommt dazu)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LeanHealthTimerUITests/LeanHealthTimerUITests.swift` | MODIFY | C1: `app.buttons["addTrackerButton"]` statt `"Add Tracker"`. C2: ebenso; erster Start mit `enable-testing`, `uitest-disk-store`, `uitest-reset-store`; Neustart nur mit `enable-testing`, `uitest-disk-store` |
| `Meditationstimer iOS/Meditationstimer_iOSApp.swift` | MODIFY | Container-Aufbau in eigene Funktion `makeModelContainer()`; unter `#if DEBUG`: `uitest-disk-store` → `ModelConfiguration(url:)` auf `Application Support/uitest.store` (Verzeichnis anlegen); `uitest-reset-store` → Hauptdatei, `-wal`, `-shm` vorher löschen. `uitest-disk-store` hat Vorrang vor In-Memory. |

### Scope Assessment
- Files: 2
- Estimated LoC: +~35/-~8
- Risk Level: LOW — alles Neue unter `#if DEBUG`; Normalstart und Release unverändert; die ~45 anderen UI-Tests starten nur mit `enable-testing` und bleiben In-Memory.

### Technical Approach
Empfehlung (Plan-Bewertung, Belege im Code geprüft):
- C1 nur Test: Kennung statt sprachabhängiger Beschriftung.
- C2: zwei neue DEBUG-Startargumente, eigene Datei `uitest.store` getrennt vom normalen `default.store`. Beim Löschen
  `-wal`/`-shm` mit entfernen (SwiftData = SQLite im WAL-Modus; eine alte `-wal` könnte alte Daten zurückspielen).
- In Release darf `schema` nicht als ungenutzt warnen → Funktion so schneiden, dass DEBUG-Zweig vorne abzweigt.
- Reihenfolge: C1 → App-Start → C2 → Gesamtlauf der UI-Suite.

Variantenvergleich:
| Kriterium | Startargumente (Empfehlung) | Unit-Test statt Neustart |
|---|---|---|
| Prüft Vorlage → `save()` → Neustart in der echten App | ja | nein |
| Erkennt fehlendes `save()` im Blatt (`AddTrackerSheet.swift:107-111`) | ja | nein (genau der Ursprungsfehler) |
| App-Code | ~25 Zeilen, nur DEBUG | keiner |
| Wartung | Dateizustand, Reset nötig | gering |

### Dependencies
- Einzige Stelle mit Startargumenten und echtem Container: `Meditationstimer_iOSApp.swift:31-50` (übrige `ModelConfiguration`-Treffer sind Previews).
- Seed `createDefaultTrackersIfNeeded` (`Services/TrackerModels.swift:893`) legt nur bei leerem Speicher NoAlc und Mood an; Doomscrolling ist nur Vorlage (`TrackerModels.swift:583`). Reset beim ersten Start ist Pflicht, sonst würde ein Rest aus früheren Läufen den Test falsch grün machen.
- Kein Widget-/Watch-/App-Group-Zugriff auf den Speicher.

### Open Questions
- keine (reine Testschuld, keine Produktentscheidung)

## Befund aus TDD RED (2026-11-18)

- C2 (`testTrackerCreationFromPresetPersistsAfterRestart`) mit `uitest-disk-store`/`uitest-reset-store` und
  `addTrackerButton`: rot an `:400` (Prüfung nach Neustart), 3/3. Erwartetes RED, App liest die Argumente noch nicht.
  Beleg: `docs/artifacts/fix-25c-tracker-anlage/test-red-c2.txt`.
- C1 (`testPresetTapCreatesVisibleTracker`) mit `addTrackerButton`: kommt jetzt über `:313` hinaus und ist rot an
  `:328` („Dankbarkeit tracker should appear“), 3/3. Beleg: `test-red-c1.txt`, UI-Hierarchie beim Fehlschlag.
  **Ursache:** Der Tracker wird angelegt, die Liste zeigt ihn aber als „Gratitude“, obwohl die App auf Deutsch läuft.
  `TrackerRow.swift:88/169` zeigt `Text(tracker.name)` wörtlich (String, keine Übersetzung); gespeichert wird der
  englische Schlüssel (`TrackerModels.swift:559`), der zugleich als Logik-Schlüssel dient (`TrackerRow.swift:35`).
  Übersetzungen „Gratitude“→„Dankbarkeit“ und „Mood“→„Stimmung“ stehen im String-Katalog, werden in der Liste aber
  nie benutzt. Gleiches Bild bei „Mood“ und den Stufen „Awful/Bad/Okay/Good/Great“.
  Widerspricht der Analyse („Die App ist richtig“) → PO-Entscheidung nötig, bevor C1 weitergeht.
