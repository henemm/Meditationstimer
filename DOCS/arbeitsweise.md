# Arbeitsweise und feste Projektregeln

Gilt für jede Sitzung, auch Cloud-Sitzungen, die nur dieses Repo sehen. Kurzfassung steht in `/CLAUDE.md`.
Quelle: Vorgaben des Product Owners Henning (Stand 2026-11-08).

## Rollen

- Henning ist PO: definiert WAS und WARUM (Scope, Ziele, Prioritäten, Akzeptanzkriterien). Kein Programmierer.
- Claude ist Tech Lead und Entwickler: WIE und WOMIT. Git, PRs, CI, Merge, Deploy, Issues erledigt Claude selbst und ohne Rückfrage.
- Rückfragen an Henning nur zu Produktthemen, immer per `AskUserQuestion` mit einer Empfehlung zuerst, und mit Kontext in Alltagssprache
  (worum geht es, was ändert sich für ihn sichtbar, was soll er entscheiden). Technik, Git, Hooks klärt Claude.
- Nachrichten an Henning: Ergebnis statt Denkweg, kein Git-Vokabular, keine Befehle zum Eintippen.
- Äußert Henning eine Präferenz, wird sie in derselben Antwort dauerhaft im Repo festgehalten.

## Einfachheit (PO-Vorgabe 13.11.2026)

- Immer den einfachen Weg wählen; nichts komplizierter machen, als es ist. Bewährtes übernehmen statt neu erfinden (z. B. Loose Ends).
- Beim Problem bleiben: erst klären, was erreicht werden soll, bevor Detailfragen gestellt werden. Rechte (was Claude darf) und
  Ort der Wahrheit (wer führt) sind getrennte Fragen.

## Vorgehen bei Fehlern und Änderungen

1. Zuerst im Internet recherchieren: wörtliche Fehlermeldung, Stand der Apple-Schnittstelle in der Zielversion, WWDC/Doku, Fallberichte.
   Keine Vermutung vor der Suche; Quellen in der Mitteilung nennen.
2. Fehler reproduzieren, auf demselben Weg wie Henning (Xcode, Simulator). Ohne Reproduktion wird nicht korrigiert.
3. Root Cause mit konkreten Stellen belegen; bei Verschlechterung zuerst fragen, ob es früher funktionierte und seit welchem Stand.
4. Erst dann fixen und den Fix am reproduzierten Fall beweisen.
5. Scope pro Änderung: höchstens 4-5 Dateien und etwa 250 Zeilen; bei Überschreitung vorher aufteilen. Kein Drive-by-Refactoring.
6. Zu jeder Alternative nennen, was dafür gekippt würde; Regeln/RegEx vor Sprachmodell, wo deterministisch lösbar.

## Tests

- Keine manuellen Tests für Henning, alles automatisiert; UI-Änderungen brauchen UI-Tests, vor der Implementierung geschrieben (TDD RED, dann GREEN).
- Zugesagte Tests (z. B. „alle vier Timer-Views") werden vor dem Commit vollständig gelaufen, nicht nur ein Teil.
- Testlauf zählt nur mit `Executed N tests`, N >= 1; Einzeltests immer als `Klasse/Methode` (siehe `/CLAUDE.md`).
- Zeigt ein Screenshot einen Fehler, gilt der Screenshot, nicht die Aussage „der Code ist korrekt".

## Hennings Geräte

Nie ungefragt etwas auf seinen Geräten starten, installieren oder abfragen. Es gibt keine Dauererlaubnis; eine Ankündigung ist keine Frage.
Braucht die Arbeit das Gerät: anhalten, per `AskUserQuestion` sagen, was laufen würde, und auf das wörtliche „jetzt ist ein Test möglich" warten
(gilt dann nur für diesen einen Durchgang). Simulator und CI sind frei.

## Workflow und Hooks

- Einstieg jeder Aufgabe: `/00-intake`. Die Hooks des Plugins `agent-os-openspec` erzwingen die Phasen.
- Checkpoint-Keywords kommen vom Hook aus Hennings getippter Freigabe. Nie manuell setzen, nie umgehen; blockiert ein Hook, den Hook-Fehler beheben
  oder melden.
- Nie in ein Projekt-Unterverzeichnis `cd`en; immer absolute Pfade benutzen (ein dauerhaftes Arbeitsverzeichnis dort sperrte früher alle Werkzeuge).
- Pfade mit Leerzeichen in Anführungszeichen setzen, nie mit Backslash escapen.
- Nach `workflow.py complete` zeigt eine alte Umgebungsvariable evtl. „FATAL"; das ist kein Defekt, ein neuer Workflow löst es.

## Lokalisierung und Fallen

- `Localizable.xcstrings`: Schlüssel ohne Übersetzung erscheinen im Debug-Build in Großbuchstaben. Immer DE und EN eintragen
  (`extractionState: manual`, `state: translated`); `.textCase(nil)` hilft nicht.
- `DayAssignment.cutoffHour(18)` verschiebt Mitternachts-Zeitstempel einen Tag zurück; wer es umgeht, übergibt `assignedDay:` oder nimmt 12:00.
- HealthKit schreibt asynchron: Benachrichtigungen erst nach dem Completion-Handler senden.
- CI: Ad-hoc-Signatur statt `CODE_SIGNING_ALLOWED=NO` (sonst SIGABRT durch HealthKit-Entitlements); UI-Tests laufen nur lokal, nicht auf dem Runner.
- UI-Tests: Tab-Knöpfe haben keine Kennung (positionsbasiert ansprechen); verdeckte Elemente bleiben im Accessibility-Baum, `exists` sagt nichts über Sichtbarkeit.
- Lange UI-Läufe (> 10 min) im Hintergrund starten und überwachen; nie zwei Simulatoren gleichzeitig.

## Hintergrund-Klänge

Claudes Auftrag ist ausschließlich die Klangoptimierung. Auswahl, Endlosschleifen und Einbau in die App macht Henning. Offene technische Punkte
werden genannt, aber nicht als eigener nächster Schritt vorgeschlagen.

## Auslieferung

Branch, Commit (Conventional Commits), PR mit `Closes #N`, CI (`ios-tests.yml`) abwarten, Merge-Commit auf `main`, Issue schließen: alles Claude.
Rote CI wird nie überbrückt.
