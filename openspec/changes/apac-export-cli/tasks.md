# Tasks: apac-export CLI

## 0. Billige Alternative widerlegen/bestätigen (vor jeglichem Code)

- [ ] `ffmpeg -map 0:1 -c:a copy isolated.mov` auf Test-Datei ausführen
- [ ] `afconvert isolated.mov out.wav -d 0` auf das Ergebnis anwenden
- [ ] Bei Erfolg: eigenes Werkzeug entfällt, dieses Proposal wird verworfen
- [ ] Bei `!stt`-Fehler (wie bereits bei der isolierten Spur beobachtet): eigenes
      Werkzeug bestätigt nötig, weiter mit Schritt 1

## 1. Recherche AVChannelLayoutKey (vor Implementierung)

- [ ] `kAudioChannelLayoutTag_HOA_ACN_SN3D` Wert und Bit-Encoding aus
      Apple-Header/-Doku verifizieren (nicht raten)
- [ ] Prüfen, wie `AudioChannelLayout`-Struct korrekt als `NSData` für
      `AVChannelLayoutKey` verpackt wird

## 2. Werkzeug implementieren

- [ ] `Scripts/apac-export.swift` mit Shebang, konsistent zu bestehenden
      Scripts/-Konventionen
- [ ] Track-Auswahl über Format-ID `kAudioFormatAPAC` + Kanalzahl (nicht hart codierter
      Index)
- [ ] `AVAssetReader` + `AVAssetReaderTrackOutput` mit korrektem
      `AVChannelLayoutKey`, Float32/48kHz/interleaved als Ausgabeformat
- [ ] Ausgabe wahlweise in Datei (Pfad als Argument) oder nach stdout
- [ ] Fehlerbehandlung: klare Meldung, wenn keine passende Spur gefunden wird

## 3. Testbarkeit nachweisen

- [ ] `Scripts/test-apac-export.sh` (MVP): Byte-Zahl-Check gegen erwartete Größe
      (Dauer × 48000 × 4 Kanäle × 4 Byte)
- [ ] Re-Wrap der Rohdaten in Container (per `afconvert`/manueller WAV-Header) +
      `afinfo`-Check auf "4 ch" und Ambisonics-Kanallayout
- [ ] Dekorrelations-Check: Kanäle 2-4 dürfen nicht identisch zur Stereospur (Kanal 1)
      sein, um "wirklich 4-kanalige Raumspur, nicht Stereo" zu belegen
- [ ] Test-Fixture-Frage mit Henning klären (siehe proposal.md)

## 4. Dokumentation (optional, kein Architektur-Umbau)

- [ ] Ein Zeile in Scripts/-Übersicht (falls vorhanden) ergänzen, dass
      `apac-export.swift` existiert
