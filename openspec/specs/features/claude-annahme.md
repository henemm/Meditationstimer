# Spec: App nimmt Lieferungen von Claude an (B1a, #51)

**Epic:** #44 · **Analyse:** `DOCS/context/analyse-51-57-claude-app.md` · **Format:** `openspec/specs/integrations/claude-lieferformat.md`
**Stand:** 21.11.2026 · **Umsetzung:** am Mac (Swift), hier nur Spezifikation
**Runden-Spec Schnitt 1:** `docs/specs/features/feature-51-lieferung-annehmen.md` · **Elternspec Schnitt 2:** `DOCS/specs/features/feature-51-s2-bausteine-anwenden.md`

## Leitlinie (PO 13.11.2026)

Einfach und wie Loose Ends: Das iPhone ist die Wahrheit, der Dienst hält eine Kopie und eine Warteschlange. **Der Dienst prüft jede
Lieferung** mit dem Referenz-Prüfer (B0); die App liest sie nur sauber ein und übernimmt sie. Kein zweiter Prüfer in Swift.
(Das ersetzt die frühere Absicht „Regeln an zwei Stellen“, Konzept 11: Die Lieferung kommt nur vom eigenen, angemeldeten Dienst.)

## Verhalten

1. **Einlesen:** Die App dekodiert eine Lieferung mit `Codable` in ihre Typen (Übung, Programm, Atemübung, Rücknahme). Was sich nicht
   dekodieren lässt oder eine Art hat, die die App noch nicht kann (`reminder`, `challenge`, `tracker` bis B4b–B6b), wird **ganz**
   abgelehnt: Ergebnis `rejected` mit Code `APP_CANNOT_READ` bzw. `KIND_NOT_SUPPORTED` und einem kurzen deutschen Grund.
2. **Übernehmen in die bestehenden Listen:** Programme in die Workout-Liste, Atemübungen in die Atem-Liste, Übungen in den Übungskatalog.
   Geliefertes trägt zusätzliche, optionale Felder: `itemId` (`claude.*`, Schema-Name), `revision`, `why`, `packageId`, `packageName`,
   `deliveredAt`, `modifiedAt` (letzte Änderung durch Henning). Alte gespeicherte Daten lesen sich unverändert (alle Felder optional).
   **Abweichung (Schnitt 2a):** Gelieferte Übungen liegen nicht im Übungskatalog, sondern im eigenen Speicher `claudeState`
   (`state.exercises` als `ClaudeStoredExercise`, seit 2b-1 unter dem Schlüssel `claudeState`); der eingebaute Katalog bleibt unverändert.
3. **Ganz oder gar nicht, nur einmal:** Eine Lieferung wird vollständig angewendet oder gar nicht. Die App merkt sich die
   `deliveryId`s der letzten 50 Lieferungen mit Ergebnis; dieselbe Lieferung ein zweites Mal ändert nichts und liefert das gemerkte Ergebnis.
4. **Änderung durch Claude** (höhere `revision`) ersetzt den Baustein. **Das iPhone gewinnt:** Hat Henning den Baustein geändert,
   nachdem die App zuletzt ihre Abschrift geschickt hat (`modifiedAt` > Zeitpunkt der letzten Abschrift), wird die Lieferung abgelehnt
   (`CHANGED_ON_IPHONE`, Grund „Henning hat den Baustein inzwischen geändert; bitte neu lesen“). Gleiche oder niedrigere `revision`: ohne Wirkung.
5. **Rücknahme durch Claude** (`withdrawal` mit `itemId` oder `packageId`) entfernt den Baustein bzw. alle Bausteine des Pakets aus den
   Listen, mit derselben Regel „das iPhone gewinnt“. Unbekannte Kennung: ohne Wirkung.
6. **Henning bearbeitet oder löscht** einen gelieferten Baustein wie jeden anderen (PO 13.11.: Löschen wie bei allen Bausteinen, kein
   Papierkorb). Bearbeiten setzt `modifiedAt`.
7. **Kennzeichen:** Gelieferte Programme und Atemübungen tragen in der Liste ein kleines Zeichen „von Claude“; die bestehende
   Info-Ansicht zeigt zusätzlich Datum, Paket und Warum.
8. **Keine verlorenen Änderungen:** Workout- und Atem-Liste werden heute von je zwei Ansichten geladen und ganz zurückgeschrieben
   (Analyse Abschnitt 2). Nach dem Anwenden lädt jede offene Liste neu (Benachrichtigung), bevor sie wieder speichert.
9. **Absolvierte Einheiten** bleiben in Apple Health, unabhängig davon, ob ein Baustein später geändert oder entfernt wird.

## Voraussetzung aus A2 (#48), nur das Nötigste

- Übungen haben eine Kennung: `builtin.*` aus `Contracts/catalog/builtin-exercises.json` (Name ↔ Kennung), gelieferte `claude.*`, eigene `own.<slug>`. Das Feld heißt in der Lieferung `itemId` (Schema); der frühere Arbeitsname `claudeId` entfällt.
- Programmschritte können eine Übung per Kennung auflösen und tragen ein optionales `hint`. Anzeige und Ansage des Hinweises sind A2.

## Tests (am Mac, zuerst rot)

- Jede gültige Beispieldatei der Arten Übung/Programm/Atemübung/Rücknahme aus `Contracts/deliveries/valid/` (gelesen über
  `#filePath`, Mindestanzahl erzwungen) wird angenommen und erscheint richtig in den Listen.
- Arten `reminder`/`challenge`/`tracker` → `KIND_NOT_SUPPORTED`; kaputtes JSON → `APP_CANNOT_READ`; nichts geändert.
- Zweimal dieselbe Lieferung: gleiches Ergebnis, keine Doppelung. Ganz oder gar nicht bei einer fehlerhaften zweiten Position.
- Höhere Fassung ersetzt; nach Bearbeitung durch Henning nach der letzten Abschrift → `CHANGED_ON_IPHONE`; davor → ersetzt.
- Rücknahme einzeln und als Paket; alte gespeicherte Listen lesen sich weiter.
- UI-Test: Zeichen „von Claude“ und Warum in der Info-Ansicht.

## Schnitte (je ≤ 4–5 Dateien, ~250 Zeilen)

1. **Lese-Modell und Gleichlauf-Test** (Spec: `docs/specs/features/feature-51-lieferung-annehmen.md`): reines Foundation-Modell
   `Meditationstimer iOS/Models/ClaudeDelivery.swift` mit Einstieg `read(Data)` (Fehler `APP_CANNOT_READ` / `KIND_NOT_SUPPORTED`) und
   Gleichlauf-Test über die gültigen Beispiele. Die optionalen Modell-Felder an `WorkoutSet`, `WorkoutPhase`, `AtemView.Preset`
   und `ExerciseInfo` kommen **erst in Schnitt 2**, weil ihre Form vom Speicherort abhängt. Für Henning noch unsichtbar.
2. Anwenden, geteilt in 2a und 2b (Elternspec: `DOCS/specs/features/feature-51-s2-bausteine-anwenden.md`):
   - **2a, erledigt (Runden 2a-1 bis 2a-3, 21.11.2026):** reine Funktion `apply` in `Meditationstimer iOS/Models/ClaudeApply.swift`
     mit Modell-Feldern an den App-Typen, ganz oder gar nicht, Gedächtnis der `deliveryId`s, Fassungen, „iPhone gewinnt“ und
     Rücknahme einzeln und als Paket (erst Treffermenge, dann Sperrprüfung, dann entfernen); Unit-Tests über alle lesbaren Beispiele.
     `apply` hat noch keinen Aufrufer.
   - **2b-1, erledigt (21.11.2026, Spec `DOCS/specs/features/feature-51-s2b-speichern.md`):** `ClaudeStore.apply` in
     `Meditationstimer iOS/Models/ClaudeStore.swift` als Hülle um `apply`: Listen unter `workoutProgramSets`/`atemPresets`,
     Gedächtnis (`exercises`, `log`) unter `claudeState`, zuletzt geschrieben; fehlende Listen ergeben die Vorgaben, unlesbare
     werden gesichert (`…Backup.<Sekunden>`) und führen zu `LIST_UNREADABLE`; Benachrichtigung `claudeStoreDidChange` lädt
     Workout- und Meditation-Tab neu. DEBUG-Testeinstieg `uitest-claude-apply` bis #57. Noch kein Aufrufer im Betrieb.
   - **2b-2, erledigt (22.11.2026, Spec `DOCS/specs/features/feature-51-s2b2-editor.md`):** Editoren für Programm und
     Atemübung speichern über `ClaudeStore.savingEdit` und setzen `modifiedAt` nur bei echter Änderung (neu Angelegtes wird
     auch unverändert übernommen); der Schritt-Editor behält die `claude.*`-Kennung bei unverändertem Übungsnamen
     (`applyKeepingClaudeId`). Damit lehnt das iPhone neue Revisionen für von Henning Bearbeitetes ab. Schnitt 2b ist
     vollständig; offen sind Schnitt 3 und #57.
3. Kennzeichen und Info-Ansicht, DE/EN-Texte, UI-Test (vorher Entwurf zum Ansehen). Aus 2b hierher verschoben:
   `claude.*` in `ExerciseDatabase.info(forId:)` auflösen (einziger Verbraucher ist das Info-Blatt).
