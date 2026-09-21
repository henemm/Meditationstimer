# Tasks: apac-export CLI

## 0. Billige Alternative widerlegen/bestätigen (vor jeglichem Code)

- [x] `ffmpeg -map 0:1 -c:a copy isolated.mov` auf Test-Datei ausführen (Analyse, siehe Spec „Problem“)
- [x] `afconvert isolated.mov out.wav -d 0` auf das Ergebnis anwenden → `!stt`
- [ ] ~~Bei Erfolg: eigenes Werkzeug entfällt, dieses Proposal wird verworfen~~ (kein Erfolg, entfällt)
- [x] Bei `!stt`-Fehler (wie bereits bei der isolierten Spur beobachtet): eigenes
      Werkzeug bestätigt nötig, weiter mit Schritt 1

## 1. Recherche AVChannelLayoutKey (vor Implementierung)

- [x] `kAudioChannelLayoutTag_HOA_ACN_SN3D` Wert und Bit-Encoding aus
      Apple-Header/-Doku verifizieren (nicht raten) → `(190<<16) | 4` = 12451844
- [ ] ~~Prüfen, wie `AudioChannelLayout`-Struct korrekt als `NSData` für
      `AVChannelLayoutKey` verpackt wird~~ (entfällt: Layout wird aus der Quellspur gelesen
      und geprüft, nicht als Ausgabeoption gesetzt — Spec „Dekodierpfad“)

## 2. Werkzeug implementieren

- [x] `Scripts/apac-export.swift` mit Shebang, konsistent zu bestehenden
      Scripts/-Konventionen
- [x] Track-Auswahl über Format-ID `kAudioFormatAPAC` (laut Spec ausschliesslich Format-ID,
      nicht Kanalzahl, nicht Index); Kanallayout `HOA_ACN_SN3D | 4` wird hart geprüft
- [x] `AVAssetReader` + `AVAssetReaderTrackOutput`, Float32/interleaved/Quellrate als
      Ausgabeformat (reine PCM-Optionen, kein `AVChannelLayoutKey`, siehe Schritt 1)
- [x] Ausgabe wahlweise in Datei (Pfad als Argument) oder nach stdout
- [x] Fehlerbehandlung: klare Meldung, wenn keine passende Spur gefunden wird

## 3. Testbarkeit nachweisen

- [x] `Scripts/test-apac-export.sh` (MVP): Byte-Zahl-Check gegen erwartete Größe
      (Präsentationsdauer × Quellrate × 4 Kanäle × 4 Byte, ±32768) plus Sondiermodus-,
      Fehlerfall- und Layout-Override-Test
- [ ] Re-Wrap der Rohdaten in Container (per `afconvert`/manueller WAV-Header) +
      `afinfo`-Check auf "4 ch" und Ambisonics-Kanallayout
- [ ] Dekorrelations-Check: Kanäle 2-4 dürfen nicht identisch zur Stereospur (Kanal 1)
      sein, um "wirklich 4-kanalige Raumspur, nicht Stereo" zu belegen
- [x] Test-Fixture-Frage mit Henning klären (siehe proposal.md) → `Scripts/Fixtures/spatial-sample.qta`

## 4. Dokumentation (optional, kein Architektur-Umbau)

- [ ] Ein Zeile in Scripts/-Übersicht (falls vorhanden) ergänzen, dass
      `apac-export.swift` existiert
