# Hilfsprogramm: apac-export CLI

## Was

Ein eigenständiges Kommandozeilen-Werkzeug, das aus einer `.qta`/`.mov`-Datei vom iPhone
die zweite Tonspur (APAC, 4 Kanäle, HOA/ACN-SN3D) via AVFoundation zu linearem PCM
(Float32, 48 kHz, interleaved) dekodiert und roh in eine Datei oder nach stdout schreibt.
Die Weiterverarbeitung (Ambisonics → Stereo) übernimmt anschließend ffmpeg außerhalb
dieses Werkzeugs.

## Warum

- `ffmpeg` kann APAC nicht dekodieren ("no decoder found")
- `afconvert` hat keine Spurauswahl und scheitert auf der isolierten Spur mit `!stt`
- macOS besitzt einen funktionierenden APAC-Decoder (verifiziert via `afinfo`), erreichbar
  über AVFoundation (`AVAssetReader` + `AVAssetReaderTrackOutput`)
- Ohne dieses Werkzeug ist die Raumklang-Spur aus iPhone-Aufnahmen nicht nutzbar

## Bauweise

Einzelne Swift-Datei `Scripts/apac-export.swift`, ausgeführt via `#!/usr/bin/env swift`
Shebang — konsistent mit den bestehenden Werkzeugen `Scripts/IconFinal.swift`,
`IconSizes.swift`, `IconVariants.swift`, `IconDirections.swift` (alle Einzeldatei-Skripte,
kein Xcode-Target, kein SwiftPM-Package). Kein neuer Build-Mechanismus, keine
`Package.swift`, **keine Änderung an `Meditationstimer.xcodeproj`** — das Skript läuft
standalone, genau wie die bestehenden Icon-Skripte.

Test-Begleiter `Scripts/test-apac-export.sh`, konsistent mit `Scripts/run-uitests.sh`
(Shell-Orchestrierung, explizite Exit-Codes, `afinfo`/`afconvert` als bereits verifizierte
System-Werkzeuge zur Verifikation der Ausgabe).

## Vor der Implementierung zu klären (billige Alternative zuerst)

Bevor der eigene AVFoundation-Code geschrieben wird: kurzer Test (2 Befehle, keine
Programmierung), ob ein reiner Remux/Stream-Copy der APAC-Spur (`ffmpeg -map 0:1
-c:a copy isolated.mov`) gefolgt von `afconvert isolated.mov out.wav -d 0` funktioniert.
Der bisher verifizierte `!stt`-Fehler von `afconvert` bezog sich auf "die isolierte Spur" —
wie genau isoliert wurde, ist nicht dokumentiert. Schlägt der Remux-Weg ebenfalls fehl, ist
das eigene Werkzeug bestätigt nötig.

## Scope

| Datei | Änderung | Geschätzt |
|-------|----------|-----------|
| `Scripts/apac-export.swift` | Neu: Track-Erkennung (Format-ID `kAudioFormatAPAC`, 4 Kanäle), `AVAssetReaderTrackOutput` mit `AVChannelLayoutKey` (HOA ACN/SN3D), Ausgabe in Datei/stdout | ~150-200 LoC |
| `Scripts/test-apac-export.sh` | Neu: Byte-Zahl-Check (Dauer × 48000 × 4 Kanäle × 4 Byte), Re-Wrap + `afinfo`-Kanalcheck, Dekorrelations-Check zwischen Kanälen | ~80-100 LoC |

**Geschätzt:** ~250-280 LoC, 2 Dateien. Leicht über dem ±250-LoC-Richtwert, aber
vertretbar: beide Dateien decken exakt ein Thema ab (Werkzeug + sein Beweis), kein
Drive-by-Scope. Bei strikter Einhaltung: Test-Skript auf den Byte-Zahl-Check
reduzieren (~30 LoC statt ~90) als MVP, `afinfo`-Rewrap und Dekorrelations-Check
als Folgeschritt.

## Risiken

1. **AVChannelLayoutKey für HOA ACN/SN3D** — größtes technisches Risiko. Der
   `AudioChannelLayoutTag` muss vor der Implementierung anhand der Apple-Header
   (`CoreAudioTypes.h`, `kAudioChannelLayoutTag_HOA_ACN_SN3D`) verifiziert werden,
   nicht erraten.
2. **Track-Auswahl robust statt hart codiert** — Auswahl über Format-Beschreibung
   (Format-ID + Kanalzahl), nicht über festen Index 2, damit das Werkzeug auch bei
   abweichender Spurreihenfolge funktioniert.
3. **Stille Fehldekodierung** — AVFoundation könnte ohne Crash falsch downmixen/
   umsortieren, wenn `AVChannelLayoutKey` nicht exakt stimmt. Deshalb sind die
   strukturellen Checks im Test-Skript der eigentliche Beweis, nicht nur "kein Absturz".
4. **Test-Fixture** — ein echtes iPhone-Spatial-Audio-Sample wird benötigt, kann nicht
   synthetisch erzeugt werden (offene Frage an Henning, siehe unten).

## Offene Frage

Gibt es eine kurze (wenige Sekunden) echte iPhone-Aufnahme mit Raumklang-Spur, die als
Test-Fixture ins Repo aufgenommen werden darf (oder soll sie lokal/ungetrackt bleiben)?
