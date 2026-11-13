# Konzept: Claude-Verbindung für Healthy Habits Haven

**Stand:** 13.11.2026 · **Status:** Konzept, noch keine Umsetzung · **Grundlage:** vier Fragerunden mit dem PO, Auswertung von Healthy Habits, Loose Ends und Frieda reist, Recherche zum Stand der Technik

---

## 1. Worum es geht

Healthy Habits bekommt einen Eingang für Claude. Im Gespräch in der Claude-App entstehen Workouts, Atemübungen, Gewohnheiten, Challenges und Erinnerungen, und Claude trägt sie selbst in Healthy Habits ein. Damit Claude gut plant, darf es außerdem lesen, welche Bausteine es in der App gibt und was tatsächlich gemacht wurde.

Das Denken bleibt bei Claude, die Regeln und das Abspielen bleiben in der App. Die App bleibt ohne Verbindung vollständig benutzbar.

## 2. Entscheidungen des PO (12.11.2026)

| Frage | Entscheidung |
|---|---|
| Für wen | Zuerst nur für Henning. In der Store-Version unsichtbar, Öffnung für andere ist ein späterer eigener Schritt. |
| Was Claude liest | Bausteine und Verlauf (absolvierte Einheiten, Serien, Challenge-Fortschritt). Keine einzelnen Tracker-Einträge wie Alkohol oder Stimmung. |
| Impuls-Notizen | Claude darf die Notizen zu seinen Impulsen lesen und darauf aufbauen. |
| Wie Lieferungen ankommen | Direkt an ihrem Platz, gekennzeichnet als „von Claude", jederzeit zurücknehmbar. Bestätigt wird im Gespräch. |
| Challenges | Im Kern Achtsamkeits-Impulse („Achte heute einmal bewusst darauf …", „Blicke auf den Tag zurück und frage dich …"). Dazu Zeitraum-Challenge, Tagesaufgaben, Stufenplan und dauerhafte Gewohnheit. |
| Trainingsform | Übungen laufen weiter nach Zeit, können aber einen kurzen Hinweis tragen, der angezeigt und angesagt wird. |
| Tagesbindung | Kein eigener Kalender. Claude nutzt die vorhandenen smarten Erinnerungen. |
| Gesundheitliche Anforderungen | Bleiben bei Claude. App und Dienst speichern davon nichts. |
| Was Claude ändern darf | Nur eigene Lieferungen. Eigene und mitgelieferte Inhalte kann es lesen und als Kopie abwandeln. |
| Atemübungen | Gleich mit dabei. |
| Gesprochene Meditation | Zurückgestellt (siehe 6.8). |
| Übergabeweg (13.11.2026) | Lieferungen kommen ausschließlich über die Claude-Verbindung (MCP-Konnektor, Stufe 1). Keine Zwischenlösung per Link, Datei oder Zwischenablage; die Brücke B1b/B1c entfällt. Grund der Rückfrage: Ein Link aus der Claude-App in die App war nicht belegbar, Kopieren und Einfügen wäre Handarbeit gewesen. |

**Nachtrag 13.11.2026**

| Frage | Entscheidung |
|---|---|
| Rückmeldung nach dem Training | Ja. Nach einer Einheit kurz „zu leicht / passt / zu schwer“, optional ein Satz. Claude darf sie lesen. |
| Ausgelassene Challenge-Tage | Henning entscheidet je Tag: nachholen, Challenge um einen Tag verlängern oder so lassen. |
| Annahmen aus Abschnitt 16 | Alle fünf bestätigt. |
| Challenges im Kalender | Zeitlich begrenzte Challenges stehen als Leiste über dem Kalender (Idee 3), nicht in den Tageskreisen. Weitere Kalender-Fragen siehe 9.1. |
| Neue Gewohnheiten gleichzeitig (13.11.2026) | Claude stößt von sich aus höchstens **zwei** neue Gewohnheiten bzw. laufende Stufenpläne gleichzeitig an; die nächste erst, wenn eine davon sitzt oder endet. Wünscht Henning ausdrücklich mehr, weist Claude einmal auf die Grenze hin und folgt dann seinem Wunsch. Beobachtende Gewohnheiten zählen nicht mit. Gilt ab B6a (#64) als Grundregel in der Server-Anweisung. |

## 3. Ausgangslage

| Bereich | Heute | Folge für die Verbindung |
|---|---|---|
| Workout-Programme | 10 mitgelieferte, eigene anlegbar. Ein Programm ist eine Folge von Übungen mit eigener Arbeits- und Pausenzeit, mal Runden. | Lässt sich fast unverändert beliefern. |
| Übungen | 43 fest eingebaute mit Wirkung und Anleitung. Ein Programm verweist nur über den Namen darauf. Eine zweite, abweichende Vorschlagsliste existiert daneben. | Übungen müssen zu Daten werden und eine feste Kennung bekommen. |
| Atemübungen | Vorlagen mit Ein, Halten, Aus, Halten, Wiederholungen. Eigene anlegbar. | Lässt sich fast unverändert beliefern. |
| Meditation | Timer mit zwei Phasen, Gongs, Hintergrundklang. Keine gespeicherten Vorlagen, keine Sprache, kein Abspielen fremder Tondateien. | Geführte Meditation wäre ein neuer Baustein. |
| Tracker | Frei kombinierbar: gut oder Saboteur, fünf Erfassungsarten, Stufen, Tagesziel, Joker, Tageswechsel-Uhrzeit. | Guter Baukasten, direkt belieferbar. |
| Challenges, Impulse | Gibt es nicht. Kein Zeitraum, kein Start, kein Ende. | Neuer Baustein. |
| Smarte Erinnerungen | Uhrzeit, Wochentage, Bedingung „nur wenn noch nichts passiert ist", bezogen auf Meditation, Workout, NoAlc oder einen Tracker. | Belieferbar. Neu: Bezug auf ein bestimmtes Programm. |
| Verlauf | Einheiten stehen nur in Apple Health. Welches Programm gelaufen ist, merkt sich die App nicht. | Kleines eigenes Tagebuch der Einheiten nötig. |
| Technik | Alles auf dem Gerät. Kein Konto, kein Netzwerk, keine Datenübertragung. Datenschutztext: „Alle Ihre Daten bleiben auf Ihrem Gerät." | Die Verbindung ist die erste Datenübertragung der App. |

## 4. Was aus Frieda reist und Loose Ends übernommen wird

| Lehre | Herkunft | Anwendung hier |
|---|---|---|
| Keine KI im eigenen Dienst. Claude denkt, der Dienst prüft Regeln. | Frieda (Grundsatzentscheidung 1; ein zweiter KI-Lauf auf dem Server wurde dort wieder abgeschaltet) | Der Dienst nimmt an, prüft, reicht weiter. Keine KI-Kosten im Betrieb. |
| Ablehnungen nennen den Ausweg. | Frieda | Jede Ablehnung sagt, was falsch ist und wie es richtig geht. |
| Nichts wird gelöscht. | Frieda | Claude kann nur zurückziehen. Zurückgezogenes bleibt wiederherstellbar, Einträge bleiben erhalten. |
| Claude sagt erst „ist da", wenn es stimmt. | Frieda (Stand-Nummer) und Loose Ends (Auftragsstatus) | Jede Lieferung bekommt eine Nummer. Erst wenn die App sie bestätigt hat, darf Claude „ist in der App" sagen. |
| Kurze Grundregeln für Claude, Namen statt Kennungen, erst bestätigen lassen. | Frieda | Siehe Abschnitt 10. |
| Wenige Werkzeuge mit klarer Form. | Frieda (Entscheidung 7: Sonderwerkzeuge zusammengelegt, weil viele Sonderfelder mehr Ablehnungen erzeugten) | Etwa 15 Werkzeuge. |
| Rückkanal und Meldungen zuerst. | Frieda | Der Einstieg zeigt zuerst, was Aufmerksamkeit braucht (abgelehnte Lieferung, endende Challenge, veralteter Stand). |
| Das Gerät bleibt die Wahrheit, der Dienst hält nur eine Abschrift und eine Warteschlange. | Loose Ends (Entscheidung 21) | Genauso. Die App holt Lieferungen ab und führt sie selbst aus. |
| Die App holt ab, kein Verlass auf Weckrufe. | Loose Ends | Abgleich beim Öffnen der App. Ein Weckruf ist später nur ein Beschleuniger. |
| Anmeldung nicht selbst erfinden. | Loose Ends | Gleiche erprobte Bausteine: Anmeldung mit Apple, geprüfte Standardbibliothek für die Claude-Anmeldung. |
| Tür gegen Fremde von Anfang an. | Loose Ends (Sicherheitsbefund) | Nur Hennings Apple-Konto wird zugelassen, getestet vor dem ersten Einsatz. |
| Bekannte Eigenheiten der Claude-Anmeldung. | Loose Ends | Liste liegt vor und wird als Prüfliste übernommen. |
| Der große Aufwand steckt in Anmeldung und Betrieb, nicht in den Werkzeugen. | Loose Ends | Stufe 1 ist die größte. Deshalb wird dort wiederverwendet statt neu gebaut. |
| Doppelte Erfassung bei wiederholter Zustellung. | Loose Ends (bekannte Lücke) | Wird hier von Anfang an ausgeschlossen: jede Lieferung trägt eine feste Kennung, zweimal Anwenden ändert nichts. |

**Bewusst nicht übernommen:** Friedas offenes Schema, in dem Claude neue Arten und Merkmale selbst definiert. Eine Reise ist eine Sammlung von Angaben, die nur angezeigt werden. Ein Workout oder eine Challenge muss die App ablaufen lassen können. Deshalb gibt es hier feste Bausteine, die Claude frei kombiniert, und einen Wunschweg für fehlende Bausteine (Abschnitt 5).

## 5. Grundprinzip

1. **Baukasten statt Freitext.** Die App kennt eine kleine Zahl von Bausteinen. Claude kombiniert sie frei, kann aber kein neues Verhalten erfinden.
2. **Flexibel durch Kombination.** Ein Programm besteht aus Übungen, eine Challenge aus Stufen und Impulsen, eine Erinnerung zeigt auf einen beliebigen Baustein, ein Paket fasst alles zusammen.
3. **Fehlende Bausteine werden sichtbar.** Kann Claude einen Wunsch nicht ausdrücken, meldet es einen Bausteinwunsch. Daraus wird eine Aufgabe für die Weiterentwicklung der App.
4. **Claude liefert, es handelt nicht.** Claude startet keine Einheit, trägt nichts in Tracker ein und schreibt nichts in Apple Health. Das Eintragen bleibt bei Henning, weil das Loggen selbst die Achtsamkeitsübung ist (Produktvision).
5. **Eigenes bleibt unberührt.** Claude ändert nur, was es geliefert hat.
6. **Ohne Verbindung fehlt nichts.** Geliefertes liegt auf dem Gerät und läuft ohne Netz.

## 6. Der Baukasten

Jede Lieferung trägt zusätzlich: Herkunft „Claude", Datum, ein kurzes „Warum" (ein bis zwei Sätze, in der App lesbar) und optional den Namen eines Pakets.

### 6.1 Übung

| Feld | Inhalt |
|---|---|
| Name | In Hennings Sprache, optional zusätzlich englisch |
| Kategorie | Eine der neun vorhandenen (Kraft, Dehnung, Core, Cardio, Beine, Oberkörper, Ganzkörper, Aufwärmen, Cool-Down) |
| Wirkung | Was trainiert oder gedehnt wird |
| Anleitung | Ausführung und worauf zu achten ist |
| Anmerkung | Optional, etwa Varianten |

Regeln: Claude nutzt zuerst vorhandene Übungen und legt nur an, was fehlt. Eine neue Übung ohne Wirkung und Anleitung wird abgelehnt, damit der Info-Knopf im Training nie leer ist. Ähnlich klingende Namen führen zu einer Rückfrage statt zu einer Dublette.

Neu in der App: Die 43 eingebauten Übungen und die gelieferten bilden einen gemeinsamen Katalog mit festen Kennungen. Die zweite Vorschlagsliste geht darin auf.

### 6.2 Workout-Programm

| Feld | Inhalt | Grenzen (wie heute) |
|---|---|---|
| Name, Symbol, Beschreibung | Wie bei eigenen Programmen | |
| Übungsfolge | Je Schritt: Übung, Arbeitszeit, Pause, optional Hinweis | 1 bis 600 s Arbeit, 0 bis 600 s Pause |
| Runden | Wie oft die Folge läuft | 1 bis 99 |

Neu ist nur der **Hinweis** je Schritt („12 Wiederholungen, langsam", „Knie hinter den Zehen"). Er steht unter dem Übungsnamen und wird nach dem Namen angesagt, wenn Ansagen eingeschaltet sind. Der Trainingsablauf selbst ändert sich nicht.

### 6.3 Atemübung

Name, Symbol, Beschreibung, Einatmen, Halten, Ausatmen, Halten (Sekunden), Wiederholungen. Entspricht den heutigen Vorlagen.

### 6.4 Gewohnheit (Tracker)

Claude kann einen Tracker mit denselben Möglichkeiten anlegen, die der Bildschirm „Eigener Tracker" bietet: Name, Symbol, gut oder Saboteur, Erfassungsart (Zähler, Ja/Nein, Wahrnehmen, Vermeiden, Stufen), Tagesziel, zwei bis fünf Stufen mit Wirkung auf die Serie, Joker-Regel, Tageswechsel-Uhrzeit.

Nicht durch Claude: Kopplung an Apple Health und Änderungen an vorhandenen Trackern wie NoAlc.

### 6.5 Impuls und Challenge

**Impuls** ist der neue Kernbaustein:

| Feld | Inhalt |
|---|---|
| Text | Die Einladung, etwa „Achte heute einmal bewusst darauf, wann du zum Handy greifst." |
| Moment | „Tagsüber" (Aufmerksamkeit) oder „Abends" (Rückblick) |
| Nachfrage | Optional eine Frage, die beim Abschließen erscheint, etwa „Was ist dir aufgefallen?" |
| Antwort | Abhaken, auf Wunsch mit Notiz |

**Challenge** ist ein Rahmen auf Zeit:

| Feld | Inhalt |
|---|---|
| Titel, Symbol, Warum | |
| Start und Dauer | Start frühestens heute, Dauer in Tagen |
| Stufen | Eine oder mehrere Stufen nacheinander, jede mit eigener Dauer und eigenem Tagesinhalt |
| Tagesinhalt einer Stufe | Entweder eine Folge von Impulsen (ein Impuls je Tag) oder ein Tagesziel auf einem Tracker |

Damit decken dieselben zwei Bausteine alle gewünschten Formen ab:

| Wunsch | Zusammensetzung |
|---|---|
| Tägliche Impulse | Challenge mit einer Stufe und einer Impulsfolge |
| Tagesaufgaben | Dasselbe, mit konkreten Aufgaben als Impulstext |
| Zeitraum-Challenge („14 Tage täglich 10 Minuten meditieren") | Challenge mit einer Stufe und einem Tagesziel |
| Stufenplan | Challenge mit mehreren Stufen, deren Ziel oder Impulse sich steigern |
| Dauerhafte Gewohnheit | Tracker ohne Challenge (6.4) |
| Dauerhafte Abendfrage | Tracker in der Art „Wahrnehmen" mit Notiz, dazu eine smarte Erinnerung |

In der App: Der Tracker-Reiter zeigt oben „Heute" mit dem Impuls des Tages und „Tag 5 von 14". Antippen schließt ab, auf Wunsch mit Notiz. Ausgelassene Tage werden neutral gezeigt, ohne Bewertung und ohne Abbruch der Challenge; das folgt dem Grundsatz „Wahrnehmen vor Handeln, kein Urteilen" der Produktvision. Am Ende steht ein ruhiger Abschluss, und Claude kann im nächsten Gespräch darauf aufbauen.

Technisch werden Antworten wie Tracker-Einträge abgelegt. Dadurch funktionieren Kalender und smarte Erinnerungen ohne Sonderweg.

### 6.6 Smarte Erinnerung

Claude kann Erinnerungen mit den heutigen Möglichkeiten anlegen: Titel, Text, Uhrzeit, Wochentage, Bedingung „nur wenn in den letzten X Stunden nichts passiert ist", bezogen auf Meditation, Workout oder einen Tracker bzw. eine Challenge.

Neu: Eine Erinnerung kann auf einen bestimmten Baustein zeigen. „Montag 18 Uhr, falls heute noch kein Workout: Rücken A" öffnet beim Antippen genau dieses Programm. So entsteht die Tagesbindung ohne eigenen Kalender.

Grenze: Höchstens eine kleine Zahl gleichzeitig aktiver Claude-Erinnerungen (Vorschlag: sechs), damit keine Mitteilungsflut entsteht.

### 6.7 Paket

Ein Name, unter dem mehrere Lieferungen zusammengehören, etwa „Rücken November": zwei Programme, eine neue Übung, zwei Erinnerungen. Die App zeigt das Paket als Gruppe und kann es als Ganzes zurücknehmen.

### 6.8 Später: gesprochene Meditation

Zurückgestellt, aber im Baukasten vorgesehen als Folge von Sprechabschnitten und Pausen mit Dauer, dazu Gong und Hintergrundklang wie heute. Recherchestand:

- Die Claude-App übergibt über eine Verbindung nur Text. Hinweise auf eine fertige Tondatei aus der Claude-App habe ich nicht gefunden.
- Weg A, Stimme des iPhones: kostenlos, ohne Netz, Text bleibt auf dem Gerät. Die guten Stimmen muss man in den iPhone-Einstellungen einmal laden (je über 100 MB). Klingt erkennbar künstlicher.
- Weg B, Sprachdienst: klingt natürlich, kostet je Meditation und gibt den Text an einen weiteren Anbieter.
- Die „Eigene Stimme" des iPhones ist für Sprachhilfen gedacht und im Hintergrund unzuverlässig; sie scheidet aus.

Weil der Baustein nur Text und Pausen enthält, bleibt die Wahl der Stimme bis zu dieser Stufe offen.

## 7. Was Claude lesen kann

| Claude sieht | Claude sieht nicht |
|---|---|
| Alle Bausteine mit Herkunft (mitgeliefert, eigene, von Claude) | Einzelne Tracker-Einträge: Alkohol, Stimmung, Gefühle, Dankbarkeit, Saboteure |
| Einheiten der letzten 90 Tage: Datum, Art, welches Programm, Dauer, zu Ende geführt oder abgebrochen | Rohdaten aus Apple Health, Puls |
| Serien für Meditation und Workout | Notizen in eigenen Trackern |
| Challenge-Fortschritt und Notizen zu Claudes Impulsen | Gesundheitliche Anforderungen (liegen bei Claude selbst) |
| Rückmeldung nach dem Training (zu leicht / passt / zu schwer, optional ein Satz) | |
| Stand der Lieferungen und Zeitpunkt des letzten Abgleichs | |

Neu in der App: ein kleines Tagebuch der Einheiten, das festhält, welches Programm wann wie lange lief. Es speist den Rückblick und ersetzt den Umweg über Apple Health (verwandt mit der offenen Aufgabe #35).

## 8. Drei Beispiele

**Workout.** Henning: „Stell mir für meinen Rücken zwei kurze Einheiten zusammen, ohne Sprünge." Claude liest die Übungen, schlägt „Rücken A" und „Rücken B" vor, nennt zwei neue Übungen samt Anleitung und fragt nach. Nach dem Ja liefert es als Paket „Rücken November" und sagt: „Liegt bereit und erscheint beim nächsten Öffnen von Healthy Habits." Beim Öffnen stehen beide Programme im Workout-Reiter, markiert als „von Claude", mit dem Warum.

**Challenge.** Henning: „Ich möchte eine Woche lang bewusster essen." Claude schlägt sieben Impulse vor, einen je Tag, abends mit der Nachfrage „Was hast du bemerkt?", dazu eine Erinnerung um 20 Uhr, falls noch offen. Nach einer Woche liest Claude die Notizen und schlägt die nächste Stufe vor.

**Anpassen.** Zwei Wochen später: „Rücken A ist zu lang." Claude sieht im Verlauf drei Abbrüche nach etwa zwölf Minuten, kürzt das Programm und liefert die neue Fassung. Hat Henning das Programm inzwischen selbst geändert, lehnt der Dienst ab, und Claude liest erst neu, statt Hennings Änderung zu überschreiben.

## 9. In der App sichtbar

- **Kennzeichnung:** Geliefertes trägt ein kleines Zeichen „von Claude". In der Detailansicht stehen Datum, Paket und Warum.
- **Zurücknehmen:** Einzeln oder als Paket. Zurückgenommenes verschwindet aus den Listen, bleibt wiederherstellbar; Einträge und Verlauf bleiben erhalten.
- **Selbst ändern:** Henning kann Geliefertes bearbeiten wie Eigenes. Es gilt dann als angepasst; Claude überschreibt es nicht blind.
- **Einstellungen:** Abschnitt „Claude-Verbindung" mit Anmelden, Zeitpunkt des letzten Abgleichs, Liste der Lieferungen samt Stand, „Was Claude sieht" als Klartext und „Verbindung trennen" (löscht alles beim Dienst).
- **Abgelehntes:** Was die App nicht annehmen konnte, steht mit Grund in der Liste und geht als Meldung an Claude zurück.

### 9.1 Kalender (Reiter Erfolge)

Entwürfe: Artefakt „Challenges im Kalender“ (https://claude.ai/artifact/W4pXWkVtaFxeGfKMQgHAsP).

**Zweck (PO, 13.11.):** vor allem Ansporn, gelegentlich Rückblick („guck mal, wie gut ich bin“). Ein Tag soll sowohl zeigen, was getan wurde (Aufbauen), als auch, was bemerkt wurde (Beobachten).

**Entschieden:**

| Teil | Entscheidung |
|---|---|
| Äußere Ringe | Meditation und Workout bleiben wie heute, entsprechend den Reitern. |
| Zeitlich begrenzte Challenges | Leiste über dem Kalender: je Challenge Titel, „Tag 5 von 14“ und ein Punkt je Tag (abgeschlossen, ausgelassen neutral, heute, kommt noch). Antippen hebt den Zeitraum im Kalender hervor. Sie zählen nicht in den inneren Kreis: Er bliebe sonst nicht stabil, und eine Challenge mit Tagesziel auf einem Tracker zählt über diesen Tracker ohnehin schon mit. |
| Innerer Kreis | Fasst alle dauerhaft laufenden Gewohnheiten zusammen, statt fest NoAlc zu zeigen. Die Qualität bleibt sichtbar (PO). Grundlage ist die gemeinsame Tagesbewertung, die jeder Tracker schon hat: gelungen, braucht Joker, bricht Serie, nichts eingetragen. Dass NoAlc in der Summe an Gewicht verliert, ist ausdrücklich in Ordnung; Einzelheiten zeigt das Antippen des Tages. |
| Tagesansicht | Zeigt jede Gewohnheit mit ihrem Eintrag und öffnet sich an jedem Tag mit Einträgen. Heute zeigt sie nur Meditation, Workout und NoAlc und öffnet sich nur an Tagen mit diesen dreien. |

**Stand der Diskussion, noch nicht entschieden:**

- Vorschlag: Füllung des inneren Kreises = Anteil der Gewohnheiten, die eingetragen wurden (Ansporn, ein schlechter Tag schließt den Kreis trotzdem); Farbe = Anteil „gelungen“ in den gewohnten Stufen kräftig grün, hellgrün, grau. Damit unterscheidet sich „schlechter Tag, aber hingeschaut“ von „nicht hingeschaut“.
- Vermeiden-Tracker: „nichts eingetragen“ bedeutet dort zugleich „gelungen“; die App kann Vermieden und Vergessen nicht unterscheiden. Für die Füllung bräuchte es ein ausdrückliches „heute nicht passiert“.
- Ob alle dauerhaften Gewohnheiten in den Kreis zählen oder nur ausgewählte (Schalter „Im Kalender zeigen“ existiert am Tracker, wird vom Kalender bisher nicht ausgewertet).
- Grenze der Lesbarkeit: etwa drei, höchstens vier Angaben je Tagesfeld (Kurzzeitgedächtnis, Luck & Vogel 1997, Cowan 2001). Heute sind es drei plus der Punkt für „heute“.

**Aufbauen und Beobachten (Diskussion 13.11., noch keine Entscheidung):**

- Aufbauen heißt, ein neues Verhalten zu wiederholen, bis es von selbst läuft: im Mittel etwa 66 Tage, 18 bis 254 je nach Person und Verhalten; ein einzelner ausgelassener Tag schadet kaum (Lally u. a. 2010). Mehrere Ziele gleichzeitig zu planen hilft weniger als eines (Dalton & Spiller 2012, ein gegen sechs Ziele).
- Beobachten heißt, wahrzunehmen und festzuhalten. Schon das verbessert die Zielerreichung, besonders schriftlich (Harkin u. a. 2016, 138 Studien). Die Grenze ist eher der tägliche Aufwand fürs Eintragen als die Willenskraft.
- Daraus folgt: viele dauerhafte Gewohnheiten parallel sind sinnvoll, solange nur wenige gleichzeitig neu aufgebaut werden. Entschieden 13.11.2026: höchstens zwei gleichzeitig neu anstoßen (Abschnitt 2, Nachtrag).

## 10. Claudes Werkzeuge

Englische Namen, deutsche Beschreibungen, wie in beiden Vorbildern.

| Gruppe | Werkzeug | Zweck |
|---|---|---|
| Lesen | `overview` | Einstieg: Meldungen zuerst, dann laufende Challenges, Bestand in Zahlen, Alter des Stands |
| | `catalog` | Bausteine einer Art auflisten oder suchen |
| | `show` | Einen Baustein vollständig zeigen |
| | `history` | Verlauf: Einheiten, Serien, Challenge-Fortschritt, Impuls-Notizen |
| | `forms` | Bauplan: Felder, Grenzen und erlaubte Werte je Baustein |
| | `delivery_status` | Ist eine Lieferung in der App angekommen, angenommen oder abgelehnt? |
| Liefern | `exercise_define` | Neue Übung |
| | `program_create` | Workout-Programm |
| | `breath_create` | Atemübung |
| | `tracker_create` | Gewohnheit |
| | `challenge_create` | Challenge mit Stufen und Impulsen |
| | `reminder_create` | Smarte Erinnerung |
| | `item_update` | Eigene Lieferung ändern (mit dem zuletzt gelesenen Stand) |
| | `item_withdraw` | Eigene Lieferung oder ganzes Paket zurückziehen |
| Rückkanal | `wish_report` | Bausteinwunsch melden, wenn etwas nicht ausdrückbar ist |

Grundregeln, die der Dienst Claude zu Beginn jedes Gesprächs mitgibt:

1. Beginne mit `overview` und nenne Meldungen zuerst.
2. Lies vor dem ersten Liefern den Bauplan und den Katalog. Nutze Vorhandenes, bevor du Neues anlegst.
3. Lass dir vor jedem Liefern bestätigen, was genau du lieferst.
4. Sage „liegt bereit", solange die App nicht bestätigt hat, und „ist in der App" erst danach.
5. Nenne Namen, keine Kennungen.
6. Du löschst nie. Du ziehst nur eigene Lieferungen zurück und sagst, wie es zurückgeht.
7. Hennings eigene und die mitgelieferten Inhalte änderst du nicht. Biete eine Kopie an.
8. Lehnt der Dienst ab, gib den Grund weiter und korrigiere.
9. Du startest nichts und trägst nichts ein. Das Eintragen ist Hennings Übung.
10. Impulse laden ein und bewerten nicht. Kein Leistungsdruck, keine Schuld.
11. Trainings sind Vorschläge und kein medizinischer Rat. Halte dich an genannte Einschränkungen und frage im Zweifel nach.

## 11. Technischer Aufbau

**Weg einer Lieferung**

1. Claude ruft ein Liefer-Werkzeug auf.
2. Der Dienst prüft sofort Form, Grenzen und Bezüge (gibt es die Übung, gehört der Baustein Claude). Bei Fehlern gibt es eine Ablehnung mit Ausweg, und nichts wird gespeichert.
3. Bei Erfolg bekommt die Lieferung eine Nummer und wartet beim Dienst.
4. Die App gleicht ab: beim Start, beim Wechsel in den Vordergrund, kurz nach eigenen Änderungen und gelegentlich im Hintergrund.
5. Die App prüft erneut, wendet an und meldet das Ergebnis zurück. Danach schickt sie eine frische Abschrift (Bausteine und Verlauf).
6. `delivery_status` zeigt Claude den Stand: wartet, angenommen, abgelehnt mit Grund, zurückgezogen.

**Bestandteile**

| Teil | Aufbau |
|---|---|
| Dienst | Kleines eigenes Programm auf dem vorhandenen Server, auf dem auch der Loose-Ends-Dienst läuft, mit eigener Adresse und eigener Datenbank. Gleiche Bauart wie dort (Node/TypeScript, Postgres, MCP über Streamable HTTP ohne Sitzungszustand). Ob der Code geteilt oder übernommen wird, klärt der erste technische Schritt von Stufe 1. |
| Anmeldung der App | Anmeldung mit Apple, Sitzung im Schlüsselbund des Geräts. |
| Anmeldung von Claude | OAuth 2.1 über dieselbe geprüfte Bibliothek wie bei Loose Ends, Anmeldeseite mit Apple, eigene Zustimmungsseite. Dasselbe Apple-Konto verbindet App und Claude. |
| Tür | Liste zugelassener Apple-Konten, zunächst nur Henning. |
| Was der Dienst speichert | Konto, die jeweils letzte Abschrift, die Lieferungen mit Verlauf, Bausteinwünsche. Sonst nichts. |
| Betrieb | Wie Loose Ends: nächtliche Sicherung außer Haus, Gesundheitsprüfung, Alarm nur bei Ausfall, Drosselung je Bereich. |
| Regeln an zwei Stellen | Dienst und App prüfen beide. Gegen Auseinanderlaufen dient ein gemeinsamer Satz Beispiel-Lieferungen, den beide Seiten in ihren automatischen Tests gleich beurteilen müssen. |
| Schalter | Die Verbindung ist in der Store-Version ausgeschaltet und unsichtbar, wie bei Loose Ends. |

**Neu in der App:** Netzwerkcode und Anmeldung (bisher keins von beiden), feste Kennungen für Übungen und Programme, Herkunftsangaben, Tagebuch der Einheiten, die Bausteine Impuls und Challenge, Hinweis je Übung, Erinnerung mit Ziel. Die Tracker-Datenbank bekommt dafür erstmals eine neue Fassung; die Umstellung bestehender Daten wird mit automatischen Tests abgesichert.

## 12. Datenschutz und Sicherheit

- **Erste Datenübertragung der App.** Solange die Verbindung nur für Henning und in der Store-Version aus ist, bleibt der öffentliche Datenschutztext richtig. Vor jeder Öffnung für andere braucht es einen eigenen Abschnitt, eine ausdrückliche Zustimmung und Kontolöschung in der App.
- **Sparsamkeit.** Übertragen wird nur, was Abschnitt 7 nennt. Der Dienst hält nur die letzte Abschrift.
- **Apple Health.** Der Rückblick speist sich aus dem eigenen Tagebuch der App und nicht aus Apple Health. Die Serien-Zahlen stammen heute aus Health-Minuten; vor einer Öffnung für andere ist zu prüfen, ob sie anders berechnet oder weggelassen werden.
- **Trennen.** „Verbindung trennen" löscht Konto, Abschrift und Lieferungen beim Dienst. Geliefertes bleibt auf dem Gerät.
- **Claude kann wenig Schaden anrichten.** Es kann nur Bausteine liefern, nichts starten, nichts eintragen, nichts löschen, Eigenes nicht ändern. Längen- und Mengengrenzen gelten für alles, was angezeigt oder vorgelesen wird.
- **Gesundheit.** Gelieferte Trainings tragen den Hinweis, dass sie von Claude zusammengestellt und kein medizinischer Rat sind.

## 13. Stufenplan

Jede Stufe endet mit etwas Benutzbarem und läuft durch den normalen Ablauf mit Freigaben.

| Stufe | Inhalt | Ergebnis für Henning | Größe |
|---|---|---|---|
| 0 Fundament | Bausteine Übung, Programm (mit Hinweis), Atemübung als prüfbare Formate. Annehmen, Kennzeichnen, Zurücknehmen in der App. Feste Kennungen, gemeinsamer Übungskatalog. Alles ohne Netz, getestet mit Beispiel-Lieferungen. | Hinweise in Programmen nutzbar, Übungskatalog bereinigt | mittel |
| 1 Verbindung | Dienst, Anmeldung, Tür, Abgleich. Werkzeuge zum Lesen der Bausteine und zum Liefern von Übung, Programm, Atemübung. Einstellungsseite. | Claude stellt Workouts und Atemübungen zusammen, sie erscheinen in der App | groß |
| 2 Rückblick | Tagebuch der Einheiten, Rückmeldung nach dem Training, Werkzeug `history` | Claude passt Programme an den tatsächlichen Verlauf an | klein bis mittel |
| 3 Erinnerungen | `reminder_create`, Erinnerung mit Ziel | „Montag und Donnerstag Rücken A" | klein |
| 4 Gewohnheiten und Challenges | `tracker_create`, Bausteine Impuls und Challenge, Ansicht „Heute", Notizen im Rückblick, Kalender nach 9.1 | Tägliche Impulse, Zeitraum-Challenges, Stufenpläne | groß |
| 5 Gesprochene Meditation | Baustein, Entscheidung über die Stimme | Geführte Meditationen aus dem Gespräch | mittel bis groß |
| 6 Öffnung | Datenschutz, Zustimmung, Kontolöschung, Store-Prüfung, Betrieb für Fremde, Watch und Widget | Andere können ihre App verbinden | groß |

Die Reihenfolge von 2 bis 4 ist tauschbar. Stufe 4 braucht den Rückweg aus Stufe 2 für die Notizen.

**Schnitt für die Umsetzung (13.11.2026):** Die Stufen sind in kleinere Scheiben in zwei Spuren zerlegt, damit regelmäßig etwas Spürbares ankommt: Spur A verbessert die App auch ohne Claude (Tagesansicht, Hinweis je Übung, Tagebuch mit Rückmeldung, Kalender), Spur B bringt Claude, zuerst über eine Brücke per Link oder Datei, dann über den Dienst. Jede Aufgabe trägt im Titel, ob sie in der Cloud, nur am Mac (Xcode) oder nur mit Serverzugang machbar ist. Reihenfolge und Aufgaben: Epic #44 mit den Unteraufgaben #46 bis #65.

## 14. Risiken

| Risiko | Umgang |
|---|---|
| Lieferung wird erst beim Öffnen der App sichtbar | Claude sagt das ehrlich („liegt bereit"). Weckruf später als Beschleuniger. |
| Eigenheiten der Claude-Anmeldung | Prüfliste aus Loose Ends, dort bereits durchlaufen |
| Regeln im Dienst und in der App laufen auseinander | Gemeinsame Beispiel-Lieferungen in beiden Testläufen |
| Umstellung der Tracker-Datenbank gefährdet vorhandene Einträge | Eigener kleiner Schritt mit Tests auf echten Altbeständen, vor allen neuen Bausteinen |
| Zu viele Mitteilungen durch Claude-Erinnerungen | Obergrenze, Kennzeichnung, Zurücknehmen als Paket |
| Sitzungslogik steckt heute in der Bildschirmansicht (#35) | Tagebuch der Einheiten setzt die Bereinigung voraus oder zieht sie mit |
| Zwei Dienste gleicher Bauart müssen gepflegt werden | In Stufe 1 entscheiden, ob gemeinsamer Kern sinnvoll ist |
| Spätere Öffnung: Haftung bei Trainings, Store-Regeln zu Gesundheitsdaten | Hinweis, sparsame Daten, Prüfung vor Stufe 6 |

## 15. Verworfene Wege

| Weg | Warum nicht |
|---|---|
| Nur iCloud statt eigenem Dienst | Ein Dienst kommt an den privaten iCloud-Bereich einer Person nur mit einem Schlüssel, der höchstens zwei Wochen hält; bei Loose Ends geprüft und verworfen. Healthy Habits nutzt iCloud bisher zudem gar nicht. |
| Datei oder Link, den man in der App öffnet | Kein Rückblick, jedes Mal Handarbeit, keine echte Verbindung. Der Annahme-Kern aus Stufe 0 ist aber derselbe. |
| Kurzbefehle und App-Aktionen | Die Claude-App kann Aktionen anderer Apps nicht auslösen. |
| Verbindung direkt auf dem iPhone ohne Dienst | Claude erreicht Verbindungen nur über eine öffentlich erreichbare Adresse. |
| Offenes Schema wie bei Frieda | Siehe Abschnitt 4: Die App muss Bausteine abspielen können. |
| Dienst als Wahrheit wie bei Frieda | Die Daten gehören aufs Gerät und nach Apple Health. Der Dienst hält nur Abschrift und Warteschlange. |
| Echte Wiederholungen, eigener Trainingskalender, Gesundheitsprofil in der App | Vom PO in den Fragerunden anders entschieden. |

## 16. Annahmen und offene Produktfragen

Vom PO am 13.11.2026 bestätigt:

1. Der Rückblick reicht 90 Tage zurück.
2. Bei einer Zeitraum-Challenge auf einem vorhandenen Tracker wie NoAlc sieht Claude nur die Summe („18 von 30 Tagen“), nicht die einzelnen Tage.
3. Höchstens sechs gleichzeitig aktive Claude-Erinnerungen.
4. Eine Challenge dauert höchstens 90 Tage.
5. Neue Übungen kommen in Hennings Sprache; Englisch ist freiwillig, solange nur Henning die Verbindung nutzt.

Erledigt: Rückmeldung nach dem Training (ja) und ausgelassene Challenge-Tage (Henning entscheidet je Tag), siehe Abschnitt 2. Die Stimme der gesprochenen Meditation entfällt als Frage, solange Stufe 5 zurückgestellt ist.

Noch offen: die Punkte unter „Stand der Diskussion“ in 9.1 und die Grundregel zum gleichzeitigen Aufbauen.

## 17. Quellen

- Loose Ends: `docs/project/00-entscheidungen.md` (Entscheidung 21), `docs/context/spike-613-backend-weg-b.md`, `docs/context/feat-621-mcp-anmeldung.md`, `docs/reference/claude-abschrift-vertrag.md`, `server/src/mcp.ts`
- Frieda reist: `docs/adr/0001-kern.md`, `0005`, `0007`, `0009`, `docs/konnektor.md`, `docs/ontologie.md`, `docs/betrieb.md`
- Healthy Habits: `openspec/specs/app-vision.md`, `openspec/specs/features/workouts.md`, `smart-reminders.md`, `generic-tracker-system.md`, `Services/TrackerModels.swift`, `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift`
- Eigene Verbindungen für Claude: https://support.claude.com/en/articles/11503834 , https://claude.com/docs/connectors/building.md
- iCloud-Zugriff von Diensten: https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitWebServicesReference/SettingUpWebServices.html
- Gewohnheitsforschung: Lally u. a. 2010 (https://www.ucl.ac.uk/news/2009/aug/how-long-does-it-take-form-habit), Dalton & Spiller 2012 (https://ideas.repec.org/a/oup/jconrs/doi10.1086-664500.html), Harkin u. a. 2016 (https://eprints.whiterose.ac.uk/87431)
- Stimmen des iPhones: https://developer.apple.com/videos/play/wwdc2023/10033/ , https://developer.apple.com/forums/thread/736148
