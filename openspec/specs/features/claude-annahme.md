# Spec: App nimmt Lieferungen von Claude an (B1a, #51)

**Epic:** #44 · **Analyse:** `DOCS/context/analyse-51-57-claude-app.md` · **Format:** `openspec/specs/integrations/claude-lieferformat.md`
**Stand:** 13.11.2026 · **Umsetzung:** am Mac (Swift), hier nur Spezifikation

## Leitlinie (PO 13.11.2026)

Einfach und wie Loose Ends: Das iPhone ist die Wahrheit, der Dienst hält eine Kopie und eine Warteschlange. **Der Dienst prüft jede
Lieferung** mit dem Referenz-Prüfer (B0); die App liest sie nur sauber ein und übernimmt sie. Kein zweiter Prüfer in Swift.
(Das ersetzt die frühere Absicht „Regeln an zwei Stellen“, Konzept 11: Die Lieferung kommt nur vom eigenen, angemeldeten Dienst.)

## Verhalten

1. **Einlesen:** Die App dekodiert eine Lieferung mit `Codable` in ihre Typen (Übung, Programm, Atemübung, Rücknahme). Was sich nicht
   dekodieren lässt oder eine Art hat, die die App noch nicht kann (`reminder`, `challenge`, `tracker` bis B4b–B6b), wird **ganz**
   abgelehnt: Ergebnis `rejected` mit Code `APP_CANNOT_READ` bzw. `KIND_NOT_SUPPORTED` und einem kurzen deutschen Grund.
2. **Übernehmen in die bestehenden Listen:** Programme in die Workout-Liste, Atemübungen in die Atem-Liste, Übungen in den Übungskatalog.
   Geliefertes trägt zusätzliche, optionale Felder: `claudeId` (`claude.*`), `revision`, `why`, `packageId`, `packageName`,
   `deliveredAt`, `modifiedAt` (letzte Änderung durch Henning). Alte gespeicherte Daten lesen sich unverändert (alle Felder optional).
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

- Übungen haben eine Kennung: `builtin.*` aus `Contracts/catalog/builtin-exercises.json` (Name ↔ Kennung), gelieferte `claude.*`.
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

1. Modell-Felder (optional) + Einlesen mit `Codable` + Gleichlauf-Test über die gültigen Beispiele.
2. Anwenden (ganz oder gar nicht, Gedächtnis der `deliveryId`s, Fassungen, „iPhone gewinnt“, Rücknahme) mit Unit-Tests.
3. Kennzeichen und Info-Ansicht, DE/EN-Texte, UI-Test.
