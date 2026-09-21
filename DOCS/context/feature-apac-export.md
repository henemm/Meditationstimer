# Context: feature-apac-export

## Request Summary

Ein Kommandozeilen-Hilfsprogramm soll die vierkanalige Raumspur (APAC, Ambisonics ACN/SN3D)
aus iPhone-Aufnahmen auslesen, damit daraus eine breitere Stereofassung für die
Hintergrund-Sounds der App gewonnen werden kann. Reines Entwickler-Werkzeug — die App
selbst wird nicht verändert.

## Related Files

| Datei | Relevanz |
|-------|----------|
| `Scripts/IconFinal.swift` | Vorbild: einzelnes Swift-Skript mit `#!/usr/bin/env swift`, ohne Xcode-Target |
| `Scripts/IconDirections.swift`, `IconSizes.swift`, `IconVariants.swift` | dieselbe Konvention, bestätigen das Muster |
| `Scripts/run-uitests.sh` | Vorbild für ein begleitendes Prüfskript |
| `Meditationstimer iOS/Media/waves.caf` | Zielklang-Referenz der Hintergrund-Sounds |
| `Meditationstimer iOS/Media/spring.caf`, `fire.caf` | weitere Bestands-Hintergrundsounds |
| `docs/artifacts/feature-apac-export/analysis.md` | Analyse inkl. vier belegt gescheiterter Alternativwege |

**Nicht betroffen:** `Meditationstimer.xcodeproj` wird ausdrücklich nicht angefasst.
Kein App-Code, keine Services, keine Views.

## Existing Patterns

- **Werkzeuge unter `Scripts/`** sind einzelne Dateien, ausführbar über die Shebang-Zeile
  `#!/usr/bin/env swift` — kein SwiftPM-Package, kein Xcode-Target, keine Projektdatei-Änderung.
  Vier bestehende Swift-Skripte folgen diesem Muster ausnahmslos.
- **Prüfskripte** sind Shell-Skripte unter `Scripts/` (`run-uitests.sh`, `prepare-simulator.sh`).
- **Deutschsprachige Kommentare** im Projektcode.

## Dependencies

- **Upstream:** AVFoundation (`AVURLAsset`, `AVAssetReader`, `AVAssetReaderTrackOutput`),
  CoreMedia (`CMAudioFormatDescription`), CoreAudioTypes (Kanalanordnungs-Konstanten).
  Systemseitig vorhanden ab macOS 26 — der APAC-Decoder ist Teil des Systems.
- **Downstream:** `ffmpeg` übernimmt die Umrechnung Ambisonics → Stereo aus den Rohdaten.
  Nichts im App-Code hängt von diesem Werkzeug ab.

## Existing Specs

Keine bestehende Spezifikation berührt dieses Werkzeug — es ist Entwickler-Werkzeug,
kein App-Verhalten.

## Risks & Considerations

1. **Stille Falschdekodierung.** Wird die Kanalanordnung
   (`kAudioChannelLayoutTag_HOA_ACN_SN3D`) falsch gesetzt, liefert AVFoundation ohne
   Fehlermeldung falsch sortierte oder heruntergemischte Kanäle. Der Wert muss aus den
   Apple-Headern verifiziert werden, nicht geraten. **Grösstes Risiko.**
2. **Top-Level `await` im Shebang-Modus.** Die modernen AVFoundation-Ladefunktionen sind
   asynchron. Ob der Swift-Interpreter das auf oberster Ebene annimmt, ist vor der
   Umsetzung zu prüfen — sonst wird ein Wartesemaphor oder eine Übersetzung mit `swiftc` nötig.
3. **Prüfbarkeit ohne Gehör.** Der Nachweis muss regelbasiert erfolgen: Byte-Anzahl gegen
   `Dauer × 48000 × 4 × 4` rechnen, und die vier Kanäle auf Unterschiedlichkeit prüfen —
   sonst bliebe unbemerkt, dass in Wahrheit die Stereospur gelesen wurde.
4. **Testdatei.** Eine echte Aufnahme mit Raumspur ist nötig; synthetisch nicht erzeugbar.
   Ob sie ins Repository gehört, ist eine offene Entscheidung (Dateigrösse!).
5. **Nutzen hängt am Abspielweg.** Über Kopfhörer wirkt Raumklang deutlich, über den
   iPhone-Lautsprecher kaum. Das entscheidet, ob sich das Werkzeug überhaupt lohnt.
6. **Umfang** liegt bei etwa 250–280 Zeilen und damit an der Projektgrenze von ±250.

---

## Analysis

### Type

**Feature** — neues Entwickler-Werkzeug, kein App-Verhalten betroffen.

### Affected Files (with changes)

| Datei | Change Type | Beschreibung |
|-------|-------------|--------------|
| `Scripts/apac-export.swift` | CREATE | Das Werkzeug selbst, Shebang-Skript nach Vorbild `Scripts/IconFinal.swift` |
| `Scripts/test-apac-export.sh` | CREATE | Prüfskript nach Vorbild `Scripts/run-uitests.sh` |
| `openspec/changes/apac-export-cli/tasks.md` | MODIFY | Bestehende Aufgabenliste abhaken |
| `docs/context/feature-apac-export.md` | MODIFY | Diese Datei, um Entscheidungen ergänzen |

Nicht betroffen: `Meditationstimer.xcodeproj`, App-Code, `Services/`, Views, CI.
Nichts im Projekt ruft `Scripts/`-Werkzeuge auf — weder Build-Phasen noch `.github/workflows/`.

### Scope Assessment

- **Dateien:** 2 neu, 2 geändert
- **Geschätzte Zeilen:** +190 bis +240 (Swift ~150–180, Shell ~40–60)
- **Risk Level:** MEDIUM — nicht wegen Umfang, sondern weil Fehler hier **still** bleiben

Die ursprüngliche Schätzung lag bei 250–280 Zeilen und damit über der Grenze. Durch Kürzung
des Prüfskripts auf Byte-Zahl-Prüfung plus Ausgabe des Quell-Kanallayouts bleibt der Umfang
innerhalb von ±250.

### Technical Approach

**Spurauswahl ausschliesslich über die Format-Kennung** `kAudioFormatAPAC` (FourCC `'apac'`,
verifiziert in `CoreAudioBaseTypes.h:433`), ermittelt über `CMFormatDescriptionGetMediaSubType`.
Ausdrücklich **nicht** über die Kanalzahl — vier Kanäle sind kein eindeutiges Merkmal, auch
Quad-AAC oder 4.0-Surround hätten vier. Ein Index-Argument bleibt höchstens Notausstieg.

**Erster Baustein ist eine reine Sondierung ohne Dekodierung:** alle Tonspuren auflisten mit
Format-Kennung, Kanalzahl und Kanallayout. Unter 30 Zeilen, und damit liegt der Nachweis der
Spurauswahl vor, bevor ein einziges Byte dekodiert wird.

**Härteste Absicherung:** Das Kanallayout der **Quellspur** wird über
`CMAudioFormatDescriptionGetChannelLayout` ausgelesen und gegen
`kAudioChannelLayoutTag_HOA_ACN_SN3D | 4` geprüft — Abbruch mit klarer Meldung, wenn es nicht
passt. Das ist der billigste und direkteste Beweis, dass die Raumspur und nicht die Stereospur
gelesen wurde, denn die Stereospur trägt nachweislich ein anderes Layout.

Verifizierte Grundlagen:
- `kAudioChannelLayoutTag_HOA_ACN_SN3D = (190U<<16) | 0`, laut Apples Kopfdatei *„needs to be
  ORed with the actual number of channels"* → für First Order Ambisonics `| 4`
- `kAudioFormatAPAC = 'apac'` (`CoreAudioBaseTypes.h:433`)
- Top-Level `await` funktioniert im Swift-Skriptmodus — durch Probelauf belegt, kein `swiftc`,
  kein Semaphor, kein `MainActor.assumeIsolated` nötig

### Stille Fehlerquellen (das eigentliche Risiko)

1. **Falsches Kanallayout** → falsch sortierte Kanäle, ohne Fehlermeldung
2. **Automatischer Raumklang-Downmix:** AVFoundation rechnet Ambisonics in manchen Pfaden
   selbsttätig auf Kopfhörer-Stereo herunter. Das Ergebnis wäre vierkanalig und plausibel gross,
   inhaltlich aber bereits falsch. Weder Byte-Zahl noch Kanalzahl würden das bemerken.
   → nur reines PCM anfordern, keine Raumklang-Optionen setzen
3. **Puffergrössen:** `copyNextSampleBuffer()` liefert variable Grössen — keine feste Blockgrösse
   annehmen, sonst gehen am Ende stillschweigend Abtastwerte verloren
4. **Abtastrate:** Die Byte-Zahl-Prüfung muss aus der tatsächlichen Zielabtastrate rechnen,
   nicht aus einer fest eingetragenen 48000
5. **Datei ohne Raumspur:** klarer Abbruch mit Rückgabewert ungleich 0 — keine leere Ausgabedatei

### Nachweis ohne Gehör — Rangfolge der Aussagekraft

| Prüfung | Fängt sie einen echten Fehler? |
|---------|-------------------------------|
| Kanallayout der Quellspur | **Ja, am direktesten** — beweist die Spurauswahl strukturell |
| Korrelation der vier Kanäle | Ja, prüft als Einzige den Inhalt; braucht eine Aufnahme mit echter Rauminformation |
| Byte-Anzahl | Nur grobe Strukturfehler; unterscheidet nicht Raumspur von aufgeblähter Stereospur |
| Rückverpacken + `afinfo` | Nur wenn die Kopfwerte aus der echten Dekodier-Ausgabe stammen — sonst zirkulär |

Erstfassung: Kanallayout-Prüfung (hart, im Werkzeug) + Byte-Zahl-Prüfung (im Prüfskript).
Korrelationsprüfung als benannter Folgeschritt, sobald eine räumliche Testaufnahme vorliegt.

### Reihenfolge

1. Sondierung: Tonspuren auflisten (Format, Kanäle, Layout) — früh prüfbar
2. Kanallayout-Prüfung als harte Zusicherung
3. Dekodierpfad, streamend in die Ausgabe schreiben
4. Byte-Zahl-Prüfung im Prüfskript
5. Fehlerfall „keine Raumspur" testen
6. *(Folgeschritt)* Korrelationsprüfung

### Entscheidungen (Henning, 2026-09-21)

- [x] **Abspielweg:** Die Nutzer hören **mit Kopfhörern**. Damit wirkt Raumklang voll, das
      Werkzeug lohnt sich. Die Stereo-Umrechnung darf auf Kopfhörer hin ausgelegt werden.
- [x] **Testaufnahme kommt ins Repository.** Damit läuft die Prüfung auf jedem Rechner.

      **Wichtige Einschränkung dabei:** Die Testdatei darf **nicht zugeschnitten** werden.
      `ffmpeg` kann APAC nicht einmal umverpacken (`Could not find tag for codec none`) —
      jeder Schnitt würde genau die Raumspur verlieren, die bewiesen werden soll.
      Es muss also eine vollständige, unveränderte Originaldatei sein.

      **Kandidat:** `Port-Cros National Park.qta` — 986 KB, 13,8 s, enthält beide Spuren.
      Die kleinste vorhandene Datei mit Raumspur.

### Offen für die Spec

- [x] Zielpfad der Testdatei im Repository festlegen → `Scripts/Fixtures/` (siehe unten)
- [x] Ob die Korrelationsprüfung mit dieser Aufnahme aussagekräftig ist — unbewiesen,
      daher verschoben (siehe unten)

### Entscheidungen aus Spec und Umsetzung (2026-09-21)

- **Fixture-Ablage:** `Scripts/Fixtures/spatial-sample.qta` (unveränderte Kopie von
  `Port-Cros National Park.qta`, 986 KB). Das Fixture gehört zum Shell-Prüfskript unter
  `Scripts/`, nicht zu XCTest — `Tests/` enthält Quellcode, keine Testdaten für Shell-Skripte.
- **Korrelationsprüfung verschoben:** Ob die Aufnahme hörbare Rauminformation trägt, ist
  unbewiesen; ohne diesen Nachweis belegt die Prüfung weder Erfolg noch Misserfolg. Ersetzt
  durch die harte Kanallayout-Zusicherung im Werkzeug (`HOA_ACN_SN3D | 4`, sonst Abbruch).
  Rückverpacken + `afinfo`-Gegenprüfung entfällt ebenfalls (zirkulär). Beleg im Artefakt:
  RMS der vier dekodierten Kanäle ist unterschiedlich (0,0085 / 0,0041 / 0,0045 / 0,0049).
- **Test-Hook `APAC_EXPORT_EXPECT_LAYOUT_TAG`:** Umgebungsvariable überschreibt den erwarteten
  Layout-Tag, damit das Prüfskript den Abbruchpfad ohne zweites Binär-Fixture nachweist
  (`ffmpeg` kann keine APAC-Spur synthetisieren). Kein Nutzerfeature.
- **Präsentationsdauer statt Mediendauer:** Die APAC-Spur trägt eine Edit-Liste (`elst`,
  13,845 s), das Medium ist 13,909 s lang (3088 Frames = 49.408 Byte mehr, über der Toleranz).
  `AVAssetReader` liefert per Design die editierte Präsentation — in allen Modi, auch
  Composition und Passthrough. Das Prüfskript rechnet daher mit `ffprobe format=duration`
  (13,845 s), wie in der Spec („tatsächliche AVAsset-Dauer"); Ergebnis: 0 Byte Abweichung.
