# Spec: Smarte Erinnerung mit Ziel von Claude (B4a)

**Issue:** #60 (Teil von Epic #44) · **Konzept:** `DOCS/konzept-claude-verbindung.md` Abschnitte 6.6, 16 (Annahme 3, bestätigt 13.11.)
**Baut auf:** Lieferformat (`claude-lieferformat.md`), Dienst (`claude-dienst.md`), Rückblick (`claude-rueckblick.md`) · **App-Seite:** B4b (#61)
**Stand:** 13.11.2026

## 1. Zweck

Claude legt smarte Erinnerungen mit den Möglichkeiten an, die die App heute hat (`Meditationstimer iOS/Models/SmartReminder.swift`,
Editor in `SmartRemindersView.swift`). Neu: Eine Erinnerung kann auf einen bestimmten Baustein zeigen („Montag 18 Uhr, falls heute
noch kein Workout: Rücken A“); Antippen öffnet ihn (App-Seite B4b). Höchstens sechs Claude-Erinnerungen sind gleichzeitig aktiv.

## 2. Lieferformat: neue Art `reminder`

**Formatfassung:** Die Art kommt in Fassung `hhhaven.delivery/1` hinzu. Begründung: Es gibt noch keine App, die Fassung 1 annimmt
(B1a steht aus); bis dahin wird Fassung 1 erweitert statt vervielfacht. Mit dem ersten App-Release, das Lieferungen annimmt, wird
Fassung 1 eingefroren; danach kommen neue Arten nur mit neuer Fassung. (`claude-lieferformat.md` Abschnitt 1 entsprechend ergänzt.)

| Feld | Pflicht | Regel |
|---|---|---|
| `kind`, `itemId`, `revision` | ja | wie bei allen Bausteinen |
| `title` | ja | einzeilig 1–40 |
| `message` | ja | mehrzeilig 1–200 (Text der Mitteilung) |
| `time` | ja | Uhrzeit `hh:mm`, 00:00–23:59, Ortszeit des Geräts; sonst `INVALID_TIME` |
| `weekdays` | ja | Liste 1–7 verschiedener Werte aus `monday` … `sunday` (wie `Weekday` in der App); falscher Wert `VALUE_NOT_ALLOWED` am Eintrag, doppelter Wert `DUPLICATE_VALUE` am zweiten Vorkommen, leere Liste `LIST_SIZE` (mehr als sieben geht nur mit Dublette) |
| `lookbackHours` | ja | ganze Zahl 1–24: nur erinnern, wenn in so vielen Stunden davor nichts passiert ist (wie „Look-back Period“) |
| `target` | ja | Objekt, siehe unten |

`target` (Objekt; Fehler an den Feldern wie überall):

| `type` | weitere Felder | Bedingung („ist etwas passiert?“) wie in der App |
|---|---|---|
| `meditation` | – | Achtsamkeit in Apple Health |
| `workout` | `programId?` (Programm, Muster `builtin|own|claude.*`) | Workout in Apple Health; Antippen öffnet das Programm |
| `breath` | `breathId` (Atemübung) | Achtsamkeit in Apple Health; Antippen öffnet die Atemübung |
| `noalc` | – | Eintrag NoAlc |

Unbekannter `type`: `VALUE_NOT_ALLOWED` an `/…/target/type`. Felder, die zum `type` nicht passen: `FIELD_UNKNOWN`.
Bezüge: `programId` muss auf ein Programm, `breathId` auf eine Atemübung zeigen — in derselben Lieferung oder im Prüfkontext;
sonst `TARGET_UNKNOWN`. Der Prüfkontext wird dazu erweitert: `knownPrograms: string[]`, `knownBreaths: string[]` (Kennungen).
Eingebaute Programme: Kennungen aus der Abschrift (der Katalog der eingebauten Programme ist nicht Teil von B0).

Neue Fehlercodes: `INVALID_TIME`, `DUPLICATE_VALUE`, `TARGET_UNKNOWN`, `REMINDER_LIMIT`. Ein `programId`, das auf eine Atemübung zeigt (oder umgekehrt), ist `TARGET_UNKNOWN`.
`REMINDER_LIMIT`: mehr als sechs Erinnerungen in einer Lieferung, am Feld `items` (Pfad `/items`). Die Grenze über mehrere Lieferungen
prüft der Dienst (Abschnitt 4), die App beim Anwenden (B4b).

Festlegungen: `REMINDER_LIMIT` zählt alle Einträge mit `kind: "reminder"`, auch fehlerhafte. Bei `weekdays` gilt Vorrang Typ, dann
erlaubter Wert, dann Dublette; ein unerlaubter Wert zählt nicht für Dubletten. Als Ziel aus derselben Lieferung zählen nur Programme bzw.
Atemübungen mit musterkonformer Kennung (auch wenn sie sonst Fehler haben). Ein `knownPrograms`/`knownBreaths`, das keine Liste ist,
wird wie fehlend behandelt.

Beispielsatz: gültige und ungültige Erinnerungen unter `Contracts/deliveries/{valid,invalid}/reminder-*.json`, jeder neue Code und
jede neue Grenze an beiden Rändern.

## 3. Abschrift: Erinnerungen

Fassung 2 erhält das **optionale** Feld `reminders` (höchstens 50): alle smarten Erinnerungen der App mit `id` (`builtin|own|claude.*`),
`title`, `message`, `time`, `weekdays`, `lookbackHours`, `enabled` (bool), `target` und `origin`; bei `origin: "claude"` zusätzlich
`revision`, `state`, `packageId?`, `packageName?`, `why?`, `deliveredAt?` wie bei den übrigen Bausteinen. `target` in der Abschrift
kennt zusätzlich `{type: "tracker", name}` für Hennings eigene Tracker-Erinnerungen (nur Name des Trackers, keine Einträge).
Die Datenbank-Wand erlaubt `reminders` als obersten Schlüssel nur in Fassung 2.

## 4. Dienst

- Werkzeug `reminder_create {title, message, time, weekdays, lookbackHours, target, why, package?}` wie die übrigen Lieferwerkzeuge
  (Kontosperre, Dienstfelder, Prüfer, eine Lieferung je Aufruf).
- **Obergrenze sechs:** aktiv = Claude-Erinnerungen der Abschrift mit `state: "active"` und `enabled: true`, plus Erinnerungen aus
  Lieferungen in `waiting`/`claimed`/`accepted`, die noch nicht in der Abschrift stehen, minus solche mit wartender Rücknahme. Ist das
  Ergebnis mit der neuen schon sechs, Ablehnung mit Ausweg („Höchstens sechs Erinnerungen von Claude gleichzeitig; ziehe eine mit
  item_withdraw zurück oder ändere eine bestehende mit item_update“). `item_update` einer Erinnerung zählt nicht doppelt.
- Prüfkontext für Bezüge: `knownPrograms`/`knownBreaths` aus Abschrift plus Lieferungen (wie `knownExercises`).
- `item_update`/`item_withdraw` gelten auch für Erinnerungen; `catalog` kennt `kind: "reminder"` (Einträge `{id, name: title, origin,
  time, weekdays, target}`), `show` zeigt sie, `forms` enthält den Bauplan, `overview` zählt sie je Herkunft und nennt `activeClaudeReminders`.
- Server-Anweisung: „Höchstens sechs Erinnerungen von Claude gleichzeitig; Erinnerungen laden ein und mahnen nicht.“
- Festlegungen: `overview` liefert `counts.reminder = {builtin, own, claude}` und oben `activeClaudeReminders`. Für die Obergrenze zählt
  jede Kennung höchstens einmal (eine wartende neue Fassung einer Erinnerung, die schon in der Abschrift steht, zählt nicht zusätzlich).
  `package` landet wie bei allen Bausteinen im Umschlag.

## 5. Fertig, wenn

Prüfer (Contracts) und Dienst beurteilen den erweiterten Beispielsatz gleich; Abschrift-Beispiele mit und ohne `reminders`; Dienst-Tests
für `reminder_create`, Obergrenze (genau sechs erlaubt, siebte abgelehnt; zurückgezogene und abgeschaltete zählen nicht), Bezüge,
Lese-Werkzeuge; alle Tests grün.
