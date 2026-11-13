# Spec: Rückblick für Claude – Abschrift Fassung 2 und Werkzeug `history` (B3a)

**Issue:** #58 (Teil von Epic #44) · **Konzept:** `DOCS/konzept-claude-verbindung.md` Abschnitte 2 (Nachtrag 13.11.), 7, 10
**Baut auf:** `openspec/specs/integrations/claude-dienst.md` (Abschrift Fassung 1, Abschnitt 4) · **App-Seite:** B3b (#59)
**Stand:** 13.11.2026

## 1. Zweck

Claude soll Programme an den tatsächlichen Verlauf anpassen können (Konzept 8, Beispiel „Anpassen“). Dafür schickt die App in der
Abschrift zusätzlich ihr Tagebuch der Einheiten der letzten 90 Tage, die Rückmeldung nach dem Training und die Serien.

## 2. Abschrift Fassung 2

Fassung 2 = Fassung 1 mit `version: 2` und einem zusätzlichen Pflichtfeld `history`:

```json
"history": {
  "sessions": [
    { "startedAt": "2026-11-12T17:05:00Z", "kind": "workout", "programId": "claude.ruecken-a-7hq2mz",
      "durationSeconds": 720, "completed": false,
      "feedback": { "rating": "too_hard", "note": "Nach der Planke war Schluss." } },
    { "startedAt": "2026-11-12T06:30:00Z", "kind": "meditation", "durationSeconds": 900, "completed": true },
    { "startedAt": "2026-11-11T21:00:00Z", "kind": "breath", "programId": "own.…", "durationSeconds": 160, "completed": true }
  ],
  "streaks": { "meditation": { "current": 4, "longest": 21 }, "workout": { "current": 0, "longest": 9 } }
}
```

| Feld | Regel |
|---|---|
| `sessions` | höchstens 1 000 Einträge; nur Einheiten mit `startedAt` höchstens 90 Tage vor `generatedAt` und nicht nach `generatedAt` |
| `startedAt` | UTC-Zeitpunkt wie `generatedAt` |
| `kind` | `meditation`, `workout` oder `breath` |
| `programId` | bei `workout` Pflicht (Kennung eines Programms), bei `breath` Pflicht (Kennung einer Atemübung), bei `meditation` verboten; Muster wie im Lieferformat (`builtin.*`, `own.*`, `claude.*`) |
| `durationSeconds` | ganze Zahl 0–86 400 (tatsächlich gelaufen) |
| `completed` | `true` = zu Ende geführt, `false` = abgebrochen |
| `feedback` | nur bei `workout`, optional: `rating` `too_easy`/`right`/`too_hard`, optional `note` einzeilig 1–200 Zeichen (Textregeln des Lieferformats) |
| `streaks` | Pflicht; `meditation` und `workout` je `{current, longest}`, ganze Zahlen 0–10 000, `current ≤ longest` |

**Datenschutzgrenze (Konzept 7):** Keine weiteren Felder, auf keiner Ebene. Insbesondere kein Puls, keine Kalorien, keine
Herzfrequenz, keine Tracker-Einträge (Alkohol, Stimmung, Gefühle, Dankbarkeit, Saboteure), keine Notizen außer der Rückmeldungs-Notiz,
keine Rohdaten aus Apple Health. Der Dienst prüft das im Schema **und** in der Datenbank (CHECK: oberste Schlüssel; in Fassung 2 ist
`history` zusätzlich erlaubt).

**Verträge:** `Contracts/transcript/transcript-v2.schema.json` mit Beispielen `Contracts/transcript/v2/{valid,invalid}/*.json`
(gleiche Form wie Fassung 1: `expected.accepted`, `schemaRejects`). Der Dienst nimmt Fassung 1 und Fassung 2 an (die App kann älter
sein); was nur das Schema nicht prüfen kann (Zeitfenster 90 Tage, Kennung von `programId` existiert in `programs` bzw. `breaths`,
`current ≤ longest`), prüft der Dienst zusätzlich.

## 3. Werkzeug `history`

Eingabe: `from?`, `to?` (Datum `JJJJ-MM-TT`, UTC-Tage, beide einschließlich; Vorgabe: letzte 30 Tage bis `generatedAt`), `kind?`,
`programId?`. Lesewerkzeug (`readOnlyHint: true`), ohne Konto „kein Konto“.

Antwort (JSON):

```json
{
  "generatedAt": "…", "range": { "from": "2026-10-14", "to": "2026-11-13" },
  "count": 12,
  "sessions": [ { "startedAt": "…", "kind": "workout", "programId": "…", "programName": "Rücken A", "durationSeconds": 720,
                  "completed": false, "feedback": { "rating": "too_hard", "note": "…" } } ],
  "summary": {
    "byKind": { "meditation": { "count": 5, "completed": 5, "minutes": 75 }, "workout": { … }, "breath": { … } },
    "byProgram": [ { "programId": "…", "name": "Rücken A", "kind": "workout", "count": 4, "completed": 1, "aborted": 3,
                     "averageMinutes": 11.5, "feedback": { "too_easy": 0, "right": 1, "too_hard": 2 } } ]
  },
  "streaks": { "meditation": { "current": 4, "longest": 21 }, "workout": { "current": 0, "longest": 9 } }
}
```

- `sessions`: im Zeitraum und Filter, neueste zuerst, höchstens 200 (`count` = alle Treffer). `programName` aus der Abschrift
  (fehlt der Baustein dort, z. B. gelöscht: ohne `programName`).
- `minutes` und `averageMinutes`: aus `durationSeconds`, auf eine Nachkommastelle gerundet; `byProgram` nach `count` absteigend, dann Name.
- Ohne Abschrift: Ablehnung „noch keine Abschrift“. Abschrift in Fassung 1: Ablehnung „Die App schickt noch keinen Verlauf; bitte
  Healthy Habits aktualisieren und öffnen“.
- Ungültige Eingaben (Datum, `from` nach `to`, Zeitraum über 90 Tage, unbekannte `kind`): Ablehnung mit Ausweg.
- Die Antwort enthält nichts, was nicht in `history` und den Namen der Bausteine steht.

`overview` meldet zusätzlich `history_missing`, wenn die Abschrift Fassung 1 ist (Meldung nach den bisherigen).
Die Server-Anweisung nennt `history` bei den Lesewerkzeugen. Die Zustimmungsseite (B2b) nennt zusätzlich „deinen Verlauf der
letzten 90 Tage lesen: Einheiten, Dauer, Rückmeldung nach dem Training und Serien“.

## 4. Fertig, wenn

Schema Fassung 2 und Beispiele im Repo; Dienst nimmt Fassung 1 und 2 an und lehnt Fassung 2 mit verbotenen Feldern auf jeder Ebene ab
(Test je Ebene: oberste, `history`, Einheit, Rückmeldung, Serie); `history` mit Tests für Filter, Zeitraum, Zusammenfassung, Grenzen,
Konten-Trennung; alle Tests grün.
