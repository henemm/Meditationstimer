# Spec: Einfache Impuls-Challenge von Claude (B5a)

**Issue:** #62 (Teil von Epic #44) · **Konzept:** `DOCS/konzept-claude-verbindung.md` Abschnitte 2 (inkl. Nachtrag 13.11.), 6.5, 7, 10
**Baut auf:** Lieferformat (B0, erweitert wie in B4a), Dienst (B2a), Rückblick (B3a) · **App-Seite:** B5b (#63) · **Danach:** B6a (#64)
**Stand:** 13.11.2026

## 1. Zweck

Claude liefert eine Challenge auf Zeit mit **einer** Stufe, deren Tagesinhalt eine Folge von Achtsamkeits-Impulsen ist (ein Impuls je
Tag). Die App zeigt sie im Tracker-Reiter unter „Heute“ und als Leiste über dem Kalender (B5b). Claude liest den Fortschritt und die
Notizen zu seinen Impulsen und baut im nächsten Gespräch darauf auf (PO-Entscheidung „Impuls-Notizen“). Mehrere Stufen und Tagesziele
auf Trackern folgen in B6a; das Format ist dafür schon als Liste von Stufen angelegt.

## 2. Lieferformat: neue Art `challenge`

Erweiterung von Fassung 1 wie in B4a begründet (noch keine App nimmt Fassung 1 an).

| Feld | Pflicht | Regel |
|---|---|---|
| `kind`, `itemId`, `revision` | ja | wie bei allen Bausteinen |
| `title` | ja | einzeilig 1–40 |
| `symbol` | ja | Symbol wie bei Programmen |
| `description` | nein | mehrzeilig 1–500 |
| `startDate` | ja | Datum `JJJJ-MM-TT` (Kalendertag des Geräts), echtes Kalenderdatum, sonst `INVALID_DATE`. Frühestens der Tag vor dem UTC-Tag von `createdAt` (Zeitzonen-Spielraum), sonst `START_IN_PAST`; höchstens 30 Tage danach, sonst `OUT_OF_RANGE`. |
| `stages` | ja | Liste mit genau **einer** Stufe (B5a; sonst `LIST_SIZE`). **Ab B6a 1–6 Stufen und Ziel-Stufen, siehe `claude-gewohnheit-stufenplan.md`.** |

Stufe:

| Feld | Pflicht | Regel |
|---|---|---|
| `days` | ja | ganze Zahl 1–90 |
| `content` | ja | Objekt mit `type: "impulses"` und `impulses` (Liste); andere `type` → `VALUE_NOT_ALLOWED` (Tracker-Ziel kommt mit B6a) |
| `content.impulses` | ja | genau `days` Einträge (einer je Tag, in Tagesreihenfolge); andere Anzahl → `IMPULSE_COUNT` an der Liste |

Impuls:

| Feld | Pflicht | Regel |
|---|---|---|
| `text` | ja | mehrzeilig 1–300: die Einladung („Achte heute einmal bewusst darauf …“) |
| `moment` | ja | `day` (tagsüber, Aufmerksamkeit) oder `evening` (abends, Rückblick); sonst `VALUE_NOT_ALLOWED` |
| `question` | nein | einzeilig 1–120: Nachfrage beim Abschließen („Was ist dir aufgefallen?“) |

Gesamtdauer (Summe `days`) höchstens 90 (bestätigte Annahme 4), sonst `TOTAL_TOO_LONG` am Baustein.
`IMPULSE_COUNT` und `TOTAL_TOO_LONG` werden nur geprüft, wenn die beteiligten `days` für sich gültig sind (keine Folgefehler).
`START_IN_PAST`/Obergrenze nur, wenn `startDate` ein echtes Datum und `createdAt` gültig ist.
Neue Fehlercodes: `START_IN_PAST`, `IMPULSE_COUNT`. Beispielsatz: `Contracts/deliveries/{valid,invalid}/challenge-*.json`.

## 3. Abschrift: Challenges

Fassung 2 erhält das optionale Feld `challenges` (höchstens 20): Challenges von Claude mit allen Feldern aus Abschnitt 2 (ohne `kind`),
`origin: "claude"` und den Claude-Feldern (`revision`, `state`, `packageId?`, `packageName?`, `why?`, `deliveredAt?`), dazu `progress`:

```json
"progress": {
  "days": [ { "date": "2026-11-14", "status": "done", "note": "Viermal zum Handy gegriffen, bevor ich wach war." },
            { "date": "2026-11-15", "status": "skipped" },
            { "date": "2026-11-16", "status": "open" } ],
  "extendedBy": 1
}
```

- `days`: je vergangenem Tag und heute ein Eintrag (höchstens Gesamtdauer + `extendedBy`), `date` echtes Datum, aufsteigend ohne Lücke ab
  `startDate`; `status` `done`, `skipped` (ausgelassen, neutral), `open` (heute, noch nicht abgeschlossen), `made_up` (nachgeholt).
- `note`: nur bei `done`/`made_up`, einzeilig 1–300 — die Notiz zum **Impuls von Claude** (Konzept 7: erlaubt). Sonst keine Notizen.
- `extendedBy`: ganze Zahl 0–90, Tage, um die Henning die Challenge verlängert hat (PO-Entscheidung: je ausgelassenem Tag nachholen,
  verlängern oder so lassen).
- Die Datenbank-Wand erlaubt `challenges` als obersten Schlüssel nur in Fassung 2.

## 4. Dienst

- Werkzeug `challenge_create {title, symbol, description?, startDate, stages, why, package?}` wie die übrigen Lieferwerkzeuge.
- `history` gibt zusätzlich `challenges` aus: je Challenge, deren Zeitraum den Abfragezeitraum berührt,
  `{id, title, startDate, totalDays, extendedBy, day (aktueller Tag, 1-basiert, höchstens totalDays + extendedBy), counts: {done, made_up,
  skipped, open}, notes: [{date, impulse (Text des Impulses dieses Tages), note}]}`. Notizen nur aus `progress.days[].note`.
- `catalog {kind: "challenge"}`, `show`, `forms`, `overview` (Meldung `challenge_ending`, wenn eine aktive Challenge in höchstens zwei
  Tagen endet, mit Kennung; Zählung `counts.challenge`), `item_update`/`item_withdraw` gelten auch für Challenges.
- Server-Anweisung, Grundregel 10 wörtlich („Impulse laden ein und bewerten nicht. Kein Leistungsdruck, keine Schuld.“) und zusätzlich:
  „Ausgelassene Tage sind neutral; frag nach, statt zu bewerten.“

Festlegungen: Letzter Tag = `startDate + Summe(days) + extendedBy − 1`. `challenge_ending` für Challenges mit `state: "active"`, deren
letzter Tag heute, morgen oder übermorgen (UTC-Tage von `generatedAt`) ist; die Meldung trägt `itemId`. `counts.challenge = {builtin,
own, claude}`. `catalog`-Zeile: `{id, name (= title), origin, startDate, totalDays}`. `notes` nach Datum aufsteigend. Ohne Challenges ist
`history.challenges` eine leere Liste; abgelaufene Challenges erscheinen, wenn ihr Zeitraum den Abfragezeitraum berührt. `item_update`
erwartet in `fields` alle Felder wie `challenge_create` ohne `why` und `package`.
`day` ist vor dem Start 0. Ein Tag mit Notiz ohne zugehörigen Impuls (Verlängerungstag) erscheint in `notes` ohne `impulse`.

## 5. Fertig, wenn

Prüfer und Dienst beurteilen den erweiterten Beispielsatz gleich; Abschrift-Beispiele mit Challenges (gültig, ungültig: Notiz an
`skipped`, Lücke in den Tagen, Zusatzfelder); Dienst-Tests für `challenge_create`, `history.challenges`, Lesewerkzeuge, Meldung
`challenge_ending`; alle Tests grün.
