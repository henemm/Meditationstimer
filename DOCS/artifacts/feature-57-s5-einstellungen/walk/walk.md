# Nutzungs-Durchlauf #57 Schnitt 5a (Claude-Verbindung)

Stand: Commit 12391a3, 2026-11-26 08:18 MEZ, Simulator iPhone 17 Pro, iOS 27.2, Sprache de_DE.
Treiber: `WalkClaudeUITests.swift.txt` (Wegwerf-Kopie, nicht Teil der Suite).

## Lauf A (enable-testing), hell (`hell-*`) und dunkel (`dunkel-*`)

| Schritt | Bild | Ergebnis |
|---|---|---|
| a) Einstellungen, Gruppe „Claude" | `*-1-einstellungen-gruppe-claude.png` | OK. Kopf „Claude" vor „System-Einstellungen öffnen", Zeile „Claude-Verbindung" Wert „Nicht angemeldet", Fußnote „Claude kann dir Übungen und Programme in die App liefern." |
| b) Seite, nicht angemeldet | `*-2-seite-nicht-angemeldet.png` | OK. Erklärtext, Stand-in-Knopf „Mit Apple anmelden (Test)". |
| c) Stand-in getippt | `*-3-seite-angemeldet.png` | OK. „Angemeldet mit Apple / Dieses iPhone", „Letzter Abgleich / Noch nicht", „Abmelden", „Verbindung trennen …" in Rot. |
| d) „Verbindung trennen …" | `*-4-rueckfrage-offen.png` | OK. Sprechblase „Verbindung trennen?" mit Erklärung und rotem Knopf „Verbindung trennen". Kein sichtbarer „Abbrechen"-Knopf (iOS-Popover; Abbruch durch Tippen daneben). |
| e) Daneben tippen | `*-5-nach-abbruch-angemeldet.png` | OK. Blase weg, Seite bleibt angemeldet. |
| f) Abmelden | `*-6-nach-abmelden.png` | OK. Zurück im Zustand nicht angemeldet. |

## Lauf B (ohne enable-testing, hell)

`hell-B-1-einstellungen-gruppe-claude.png`, `hell-B-2-seite-apple-knopf.png`: Zeile erscheint, Seite zeigt Apples echten schwarzen Knopf „Mit Apple anmelden" (nicht getippt). OK.

## Abweichungen / Auffälligkeiten

- Keine Großbuchstaben, keine abgeschnittenen Texte, Kontrast in Hell und Dunkel gut lesbar.
- Nicht durchlaufen (laut Auftrag nicht Teil): Rücksprung in die Einstellungen im angemeldeten Zustand (Wert „Angemeldet" der Zeile) wurde nicht fotografiert.
- Stand-in-Knopf trägt festen Text „(Test)", nur mit enable-testing sichtbar.
- Entwurf-Mockup nicht Pixel-für-Pixel verglichen; inhaltlich keine Abweichung bemerkt.

## passed-Zeilen

```
Test Case '-[LeanHealthTimerUITests.WalkClaudeUITests testLaufA]' passed (57.180 seconds).   (hell)
Test Case '-[LeanHealthTimerUITests.WalkClaudeUITests testLaufA]' passed (55.188 seconds).   (dunkel)
Test Case '-[LeanHealthTimerUITests.WalkClaudeUITests testLaufB]' passed (38.606 seconds).   (Lauf B)
```
