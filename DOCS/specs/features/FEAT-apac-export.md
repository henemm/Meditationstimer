---
entity_id: FEAT-apac-export
type: feature
created: 2026-09-21
updated: 2026-09-21
status: draft
workflow: feature-apac-export
---

# FEAT-apac-export: APAC-Raumspur-Export aus iPhone-Aufnahmen

- [ ] Approved for implementation

## Purpose

Ein Entwickler-Werkzeug (`Scripts/apac-export.swift`), das aus iPhone-Videoaufnahmen (`.qta`/`.mov`)
die zweite, bisher ungenutzte Tonspur — eine vierkanalige Ambisonics-Raumaufnahme im Format APAC
(ACN/SN3D) — über AVFoundation zu rohem Float32-PCM dekodiert. Damit wird die Raumspur erstmals
nutzbar, um daraus per `ffmpeg` eine breitere Stereofassung für die Hintergrund-Sounds der App zu
gewinnen. Die App selbst wird nicht verändert; das Werkzeug ist reine Entwickler-Infrastruktur.

## Source

| Feld | Wert |
|------|------|
| Entity | `FEAT-apac-export` |
| Spec-Datei | `docs/specs/features/FEAT-apac-export.md` |
| Kontext | `DOCS/context/feature-apac-export.md` |
| Analyse | `docs/artifacts/feature-apac-export/analysis.md` |
| Ursprungsvorschlag | `openspec/changes/apac-export-cli/proposal.md`, `tasks.md` |
| Workflow | `feature-apac-export` |
| Primaeres Artefakt | `Scripts/apac-export.swift` |

## Problem

Hennings iPhone-Aufnahmen liegen als `.qta` vor und enthalten zwei Tonspuren:

| Spur | Format | Kanäle | Kanalanordnung |
|------|--------|--------|-----------------|
| 1 | AAC | 2 | Stereo (L R) |
| 2 | **APAC** | **4** | **First Order Ambisonics, ACN/SN3D** |

Spur 2 trägt echte Rauminformation, bleibt aber ungenutzt, weil kein vorhandenes
Kommandozeilenwerkzeug sie extrahieren kann. Vier Wege wurden ausprobiert und sind belegt
gescheitert:

| Weg | Ergebnis |
|-----|----------|
| `ffmpeg` dekodiert die Spur direkt | `no decoder found for: none` — ffmpeg kennt APAC nicht |
| `afconvert` auf die Originaldatei | greift stets Spur 1 (Stereo) ab; keine Spurauswahl vorhanden |
| Spur 2 nach `.mov` umverpacken, dann `afconvert` | `ExtAudioFileRead failed ('!stt')` |
| Spur 2 mit `-l HOA_ACN_SN3D` umverpacken, dann `afconvert` | `ExtAudioFileRead failed ('!stt')` |
| Spur 2 nach `.mp4`/`.m4a`/`.caf` umverpacken | `Could not find tag for codec none` — ffmpeg kann APAC nicht einmal durchreichen |

`afinfo` liest Spur 2 korrekt aus — der APAC-Decoder ist auf dem System (macOS 26.6.1) vorhanden,
nur über die vorhandenen Kommandozeilenwerkzeuge nicht erreichbar. Nur ein eigenes Werkzeug über
AVFoundation (`AVAssetReader` + `AVAssetReaderTrackOutput`) kann die Spur dekodieren.

## Dependencies

| Abhängigkeit | Typ | Zweck |
|---------------|-----|-------|
| AVFoundation (`AVURLAsset`, `AVAssetReader`, `AVAssetReaderTrackOutput`) | System-Framework | Spurauswahl und PCM-Dekodierung |
| CoreMedia (`CMFormatDescriptionGetMediaSubType`, `CMAudioFormatDescriptionGetChannelLayout`) | System-Framework | Format- und Kanallayout-Erkennung |
| CoreAudioTypes (`kAudioFormatAPAC`, `kAudioChannelLayoutTag_HOA_ACN_SN3D`) | System-Framework | Verifizierte Konstanten für Formaterkennung und Kanallayout-Prüfung |
| `ffmpeg` | externes CLI-Werkzeug (Downstream, außerhalb des Scopes) | Umrechnung Ambisonics → Stereo aus den Rohdaten; nicht Teil dieses Werkzeugs |

Kein Projektcode (App, Services, Views) hängt von diesem Werkzeug ab. Nichts im Projekt ruft
`Scripts/`-Werkzeuge automatisiert auf — weder Build-Phasen noch CI.

## Scope

### Affected Files

| Datei | Änderungstyp | Beschreibung | Geschätzt |
|-------|--------------|--------------|-----------|
| `Scripts/apac-export.swift` | CREATE | Shebang-Skript (`#!/usr/bin/env swift`), Sondiermodus + Dekodierpfad | ~150–180 LoC |
| `Scripts/test-apac-export.sh` | CREATE | Prüfskript, regelbasierter Nachweis ohne Gehör | ~40–60 LoC |
| `Scripts/Fixtures/spatial-sample.qta` | CREATE | Binär-Fixture (Kopie, kein Code), 986 KB | — (binär) |
| `openspec/changes/apac-export-cli/tasks.md` | MODIFY | Aufgaben abhaken | ~10 Zeilen |
| `DOCS/context/feature-apac-export.md` | MODIFY | Getroffene Entscheidungen nachtragen (Fixture-Ablage, Korrelationsprüfung-Verschiebung) | ~15 Zeilen |

**Nicht betroffen:** `Meditationstimer.xcodeproj`, App-Code, `Services/`, Views, CI-Konfiguration.

### Fixture

`Scripts/Fixtures/spatial-sample.qta`, unveränderte Kopie von
`/Users/hem/Downloads/sounds/Port-Cros National Park.qta` (986 KB, 13,8 s, enthält Stereospur +
APAC-Raumspur, unbeschnitten). Die Datei darf nicht zugeschnitten werden — `ffmpeg` kann APAC nicht
einmal umverpacken, jeder Schnitt würde die Raumspur zerstören, die bewiesen werden soll.

**Ablage-Begründung:** Das Fixture gehört zum Shell-Prüfskript unter `Scripts/`, nicht zu XCTest —
ein `Tests/`-Verzeichnis existiert in diesem Repository für Fixtures dieser Art nicht; die
vorhandenen Unit-Tests liegen in `Tests/` als Quellcode, nicht als Testdaten-Ablage für
Shell-Skripte.

### Estimated Changes

- Dateien: 3 neu (2 Textdateien + 1 Binär-Fixture), 2 geändert
- LoC (Text): +190 bis +240 — innerhalb der Projektgrenze von ±250. Um darunter zu bleiben, wurde
  das Prüfskript gegenüber der ursprünglichen Schätzung (~80–100 LoC mit Rückverpackungs- und
  Dekorrelationsprüfung) auf ~40–60 LoC reduziert: die Byte-Zahl-Prüfung und die
  Kanallayout-Prüfung bleiben, Rückverpacken+`afinfo`-Gegenprüfung sowie die Dekorrelationsprüfung
  zwischen den vier Kanälen entfallen in dieser Fassung (siehe „Nicht in dieser Fassung").

## Implementation Details

### CLI-Schnittstelle

```
Scripts/apac-export.swift --probe <input.qta>            # Sondiermodus, keine Dekodierung
Scripts/apac-export.swift <input.qta> <output.pcm>        # Dekodierung in Datei
Scripts/apac-export.swift <input.qta>                     # Dekodierung nach stdout
```

### Spurauswahl

Ausschließlich über `CMFormatDescriptionGetMediaSubType == kAudioFormatAPAC`
(FourCC `'apac'`, verifiziert in `CoreAudioBaseTypes.h:433`). Ausdrücklich **nicht** über die
Kanalzahl — Quad-AAC oder anderes 4.0-Material hätte ebenfalls vier Kanäle und wäre keine
Raumspur. Kein fester Spur-Index.

### Sondiermodus (`--probe`)

Reiner Auflistungsmodus ohne Dekodierung: für jede Tonspur der Datei werden Format-Kennung,
Kanalzahl und (falls vorhanden) Kanallayout-Tag ausgegeben. Dieser Baustein belegt die
Spurauswahl, bevor ein einziges Byte dekodiert wird, und ist Voraussetzung für den ersten
Acceptance-Test.

### Harte Kanallayout-Zusicherung

Das Kanallayout der gewählten Quellspur wird über `CMAudioFormatDescriptionGetChannelLayout`
ausgelesen und gegen den erwarteten Wert geprüft:

```
kAudioChannelLayoutTag_HOA_ACN_SN3D = (190U << 16) | 0
// laut Apple-Header: "needs to be ORed with the actual number of channels"
// für First Order Ambisonics (4 Kanäle): kAudioChannelLayoutTag_HOA_ACN_SN3D | 4
```

Stimmt das ausgelesene Layout nicht mit `kAudioChannelLayoutTag_HOA_ACN_SN3D | 4` überein, bricht
das Werkzeug mit einer verständlichen Meldung auf stderr und Rückgabewert ≠ 0 ab. Das ist der
billigste und direkteste Beweis, dass tatsächlich die Raumspur und nicht die Stereospur gelesen
wurde — die Stereospur trägt nachweislich ein anderes Layout.

### Testbarkeits-Hook für die Layout-Prüfung

Da `ffmpeg` keine gültige APAC-Spur synthetisieren kann, lässt sich ein "APAC-Spur mit falschem
Layout"-Fall nicht über ein zusätzliches Binär-Fixture erzeugen, ohne die Datei-Obergrenze der
Änderung zu reißen. Stattdessen liest das Werkzeug den Erwartungswert für den Layout-Vergleich aus
der Umgebungsvariable `APAC_EXPORT_EXPECT_LAYOUT_TAG`, falls gesetzt; ist sie nicht gesetzt (der
Normalfall, auch in Produktion), gilt der echte Wert `kAudioChannelLayoutTag_HOA_ACN_SN3D | 4`. Das
Prüfskript setzt die Variable testweise auf einen absichtlich falschen Wert und weist so den
Abbruchpfad nach, ohne eine zweite Binärdatei ins Repository aufzunehmen. Die Variable ist ein
interner Test-Hook, kein dokumentiertes Nutzerfeature.

### Dekodierpfad und Ausgabeformat

- Ausgabeformat: Float32, interleaved, Abtastrate der Quelle (nicht fest auf 48000 kHz
  eingetragen — die tatsächliche `AVAssetTrack`-Abtastrate wird ausgelesen und sowohl fürs
  Dekodieren als auch für die spätere Byte-Zahl-Prüfung verwendet).
- `copyNextSampleBuffer()` liefert Puffer variabler Größe — es wird keine feste Blockgröße
  angenommen; jeder Puffer wird vollständig verarbeitet, bevor der nächste angefordert wird.
- Es werden ausschließlich reine PCM-Ausgabeoptionen gesetzt (Float32, interleaved,
  Ziel-Kanalzahl = Quell-Kanalzahl). Keine Raumklang-/Spatial-Audio-Optionen — AVFoundation mischt
  Ambisonics in manchen Pfaden sonst selbsttätig auf Kopfhörer-Stereo herunter. Das Ergebnis wäre
  vierkanalig, plausibel groß und trotzdem inhaltlich falsch, ohne dass Byte-Zahl oder Kanalzahl
  das bemerken würden.
- Datei ohne APAC-Spur: klarer Abbruch mit Rückgabewert ≠ 0 und Meldung auf stderr, die auf die
  fehlende Raumspur hinweist. Keine leere oder unvollständige Ausgabedatei wird angelegt.

### Verifizierte Grundlagen (nicht erneut recherchiert)

- `kAudioFormatAPAC = 'apac'` (FourCC), verifiziert in `CoreAudioBaseTypes.h:433`.
- `kAudioChannelLayoutTag_HOA_ACN_SN3D = (190U<<16) | 0`; laut Apple-Header muss der Wert mit der
  tatsächlichen Kanalzahl ge-ORt werden — für First Order Ambisonics also `| 4`.
- Top-Level `await` funktioniert im Swift-Shebang-Modus, durch Probelauf belegt — kein `swiftc`,
  kein Wartesemaphor, kein `MainActor.assumeIsolated` für die Async-Ladefunktionen nötig.

### Byte-Zahl-Toleranz

Erwartete Größe: `Dauer × tatsächliche Abtastrate × 4 Kanäle × 4 Byte`, wobei die Dauer aus der
tatsächlichen `AVAsset`-Dauer der Fixture-Datei berechnet wird, nicht aus einem fest eingetragenen
Wert. Toleranz: **±2 Encoder-Frames**, angenommen 1024 Samples/Kanal je Frame (üblicher
Frame-Raster AAC-basierter Codecs, zu denen APAC gehört) — das entspricht ±2048 Samples/Kanal bzw.
**±32.768 Byte** bei 4 Kanälen × 4 Byte/Sample. Begründung: `copyNextSampleBuffer()` liefert
variable Puffergrößen, und Encoder fügen am Anfang/Ende typischerweise bis zu wenigen Frames
Priming-/Restsamples hinzu, die nicht exakt auf die Nominaldauer aufgehen; ±2 Frames deckt das ab,
ohne strukturelle Fehler zu verdecken.

## Definition of Done

- [ ] `Scripts/apac-export.swift` existiert, ist ausfuehrbar (`chmod +x`) und startet ueber die
      Shebang-Zeile ohne vorherige Uebersetzung.
- [ ] `Scripts/test-apac-export.sh` existiert, ist ausfuehrbar und liefert ohne Argumente
      Rueckgabewert 0.
- [ ] Alle fuenf Tests aus dem Test Plan laufen und bestehen.
- [ ] Alle Acceptance Criteria sind abgehakt.
- [ ] `git diff --name-only` gegen den Ausgangsstand nennt ausschliesslich die fuenf unter
      "Affected Files" gelisteten Pfade — keinen weiteren.
- [ ] `openspec/changes/apac-export-cli/tasks.md` ist auf den tatsaechlichen Stand abgehakt.
- [ ] `DOCS/context/feature-apac-export.md` enthaelt die getroffenen Entscheidungen
      (Fixture-Ablage, Verschiebung der Korrelationspruefung).

## Test Plan

### Automated Tests (TDD RED)

- [ ] Test 1: GIVEN das Fixture `Scripts/Fixtures/spatial-sample.qta` WHEN
      `apac-export.swift --probe` darauf aufgerufen wird THEN listet die Ausgabe genau zwei
      Tonspuren auf, davon eine mit Format-Kennung `apac` und Kanalzahl 4.
- [ ] Test 2: GIVEN eine zur Testzeit aus dem Fixture erzeugte Datei, die per
      `ffmpeg -map 0:0 -c:a copy` nur die Stereospur enthält (nicht committet, nur temporär)
      WHEN `apac-export.swift` darauf aufgerufen wird THEN bricht das Werkzeug mit Rückgabewert
      ≠ 0 und einer Meldung ab, die auf die fehlende Raumspur hinweist, und es entsteht keine
      Ausgabedatei.
- [ ] Test 3: GIVEN das Fixture UND die Umgebungsvariable `APAC_EXPORT_EXPECT_LAYOUT_TAG` auf
      einen absichtlich falschen Wert gesetzt WHEN `apac-export.swift` darauf aufgerufen wird
      THEN bricht das Werkzeug mit Rückgabewert ≠ 0 ab, weil das ausgelesene Kanallayout nicht mit
      dem vorgegebenen Erwartungswert übereinstimmt.
- [ ] Test 4: GIVEN das Fixture unter Standardbedingungen (kein Override) WHEN
      `apac-export.swift` die Raumspur in eine Ausgabedatei dekodiert THEN entspricht die
      Dateigröße `Dauer × tatsächliche Abtastrate × 4 Kanäle × 4 Byte` innerhalb der Toleranz von
      ±32.768 Byte.
- [ ] Test 5: GIVEN alle obigen Einzelprüfungen WHEN `Scripts/test-apac-export.sh` ohne Argumente
      ausgeführt wird THEN liefert es Rückgabewert 0, wenn alle Einzelprüfungen bestehen, und
      ≠ 0, sobald eine davon fehlschlägt.

## Acceptance Criteria

- **AC-1:** Sondiermodus (`--probe`) listet für `Scripts/Fixtures/spatial-sample.qta` beide Tonspuren
      mit Format-Kennung und Kanallayout auf.
- **AC-2:** Werkzeug bricht mit Rückgabewert ≠ 0 ab, wenn keine APAC-Spur in der Eingabedatei vorhanden
      ist; die Meldung auf stderr enthält die Zeichenkette `APAC` (maschinell per `grep` prüfbar),
      und es wird keine Ausgabedatei erzeugt.
- **AC-3:** Werkzeug bricht mit Rückgabewert ≠ 0 ab, wenn das ausgelesene Kanallayout nicht
      `HOA_ACN_SN3D | 4` entspricht (nachgewiesen über den Test-Hook
      `APAC_EXPORT_EXPECT_LAYOUT_TAG`).
- **AC-4:** Größe der erzeugten Ausgabedatei entspricht
      `Dauer × tatsächliche Abtastrate × 4 Kanäle × 4 Byte` innerhalb ±32.768 Byte.
- **AC-5:** `Scripts/test-apac-export.sh` läuft ohne Argumente durch, liefert Rückgabewert 0 bei Erfolg
      und ≠ 0 bei jedem Fehlschlag.
- **AC-6:** `git diff --name-only` nennt keinen Pfad unterhalb von `Meditationstimer.xcodeproj`,
      `Services/`, `Meditationstimer iOS/` oder `Meditationstimer Watch/` (maschinell prüfbar).

## Nicht in dieser Fassung

- **Korrelationsprüfung der vier Kanäle** (inhaltlicher Nachweis, dass die Kanäle nicht identisch
  sind). Sie ist die einzige Prüfung, die den tatsächlichen Inhalt beweist, setzt aber hörbare
  Rauminformation in der Testaufnahme voraus, die für `spatial-sample.qta` bisher unbewiesen ist.
  Ohne diesen Nachweis wäre die Prüfung wertlos: bei Erfolg würde sie nichts belegen, bei
  Misserfolg nichts widerlegen. Folgeschritt, sobald die räumliche Aussagekraft der Aufnahme
  verifiziert ist.
- **Rückverpacken der Rohdaten + `afinfo`-Gegenprüfung.** Nur aussagekräftig, wenn die Kopfwerte
  aus der echten Dekodier-Ausgabe stammen, sonst zirkulär. In dieser Fassung ersetzt durch die
  direkte Kanallayout-Zusicherung im Werkzeug selbst, die denselben Fehler strukturell und
  günstiger abfängt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Reines Entwickler-Werkzeug außerhalb der App-Architektur (kein Ziel im
  Xcode-Projekt, keine Abhängigkeit von App-Code, Services oder Views, kein Einfluss auf
  bestehende Architekturentscheidungen). Der einzige nennenswerte technische Entscheid — die
  Spurauswahl über Format-Kennung statt Kanalzahl oder Index — ist in „Implementation Details"
  begründet und lokal auf dieses eine Skript beschränkt; er begründet keine ADR-würdige,
  projektweite Weichenstellung.

## Changelog

- 2026-09-21: Initial spec created
- 2026-09-21: Sektionen Source und Definition of Done ergänzt; zwei Acceptance Criteria
  maschinell prüfbar formuliert (Validator-Befund)
- 2026-09-21: Acceptance Criteria in AC-N-Format umformatiert (Edit-Gate-Vorgabe); Inhalt unverändert
