# Context: chore-131-tests-stumm (#131)

## Request Summary

UI-Tests laufen im Simulator auf Hennings Mac und spielen Gongs, Ansagen und Klänge hörbar ab.
Ziel: Startet die App mit dem Launch-Argument `enable-testing` (setzen alle UI-Tests), spielt jede
Klangquelle mit Lautstärke 0. Audio-Sitzung und Wiedergabe bleiben aktiv (Hintergrund-Tests behalten
ihre Aussage). Ohne `enable-testing` unverändert hörbar.

Recherche (Issue): Kein Schalter in `xcodebuild`/`simctl` zum Stummschalten des Simulators; Mac stumm
schalten scheidet aus (trifft Hennings eigene Wiedergabe).

## Related Files (Erkundung 2026-11-27, Explore-Agent)

Nur `AVAudioPlayer` und `AVSpeechSynthesizer`; kein AVAudioEngine/AVPlayer/SystemSound in der App.

| Datei | Klangstellen | Lautstärke heute |
|---|---|---|
| `Services/GongPlayer.swift` | AVAudioPlayer :68, play :71 | nie gesetzt |
| `Services/AmbientSoundPlayer.swift` | Player A :125, B :131, Crossfade :286-304; `targetVolume`, `setVolume(percent:)` :89-96, Fades :191-240 | einzige echte Lautstärkesteuerung |
| `Meditationstimer iOS/WorkoutSoundPlayer.swift` | AVAudioPlayer :100/play :103; Sprachausgabe AVSpeechSynthesizer :38, speak :133-139 | nie gesetzt |
| `Meditationstimer iOS/BackgroundAudioKeeper.swift` | AVAudioPlayer :30, volume=0.0 :32 | **bereits stumm → keine Änderung** |
| `Meditationstimer iOS/Tabs/AtemView.swift` | eigene verschachtelte `GongPlayer`-Klasse :125, AVAudioPlayer :145, play :148 | nie gesetzt |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | `fileprivate SoundPlayer` :54, AVAudioPlayer :107/play :110, Sprachausgabe :135-144 | nie gesetzt |

Duration-Proben (WorkoutSoundPlayer :122, WorkoutProgramsView :165) spielen nicht ab.

## Target-Zugehörigkeit

- `Services/GongPlayer.swift`: iOS-App **und** Watch-App. `Services/AmbientSoundPlayer.swift`: nur iOS.
- `Meditationstimer iOS/` ist synchronisierte Gruppe, nur iOS-App.
- Ein Helfer, den GongPlayer nutzt, muss auch auf watchOS kompilieren. Eine neue Datei unter `Services/`
  bräuchte pbxproj-Einträge für zwei Targets → besser Helfer in einer bestehenden, beiden Targets
  zugehörigen Datei (z. B. `Services/GongPlayer.swift`) ablegen.

## Existing Patterns (enable-testing-Erkennung)

Kein zentraler Helfer, dreifach dupliziert:
- `Meditationstimer_iOSApp.swift:75` `args.contains("enable-testing")` (nur `#if DEBUG`)
- `Claude/ClaudeSync.swift:34` `enable-testing` **oder** `XCTestConfigurationFilePath` (isSilent)
- `Claude/ClaudeWiring.swift:15, :58`
Tests der Erkennung: `ClaudeSyncTests.swift:839`, `ClaudeVerbindungBausteineTests.swift:160`,
`ClaudeEinstellungenTests.swift:120` → Muster: Entscheidung als reine Funktion über `arguments` testen.

Achtung: `XCTestConfigurationFilePath` darf hier NICHT zählen, sonst wären Unit-Tests stumm, die
die Lautstärke-Entscheidung für den Normalfall prüfen — Lautstärkeentscheidung nur an `enable-testing`.

## Dependencies / Dependents

- Kein gemeinsamer Abspielpunkt: Stummschalten muss an jeder Erzeugungsstelle greifen
  (5 Dateien: GongPlayer, AmbientSoundPlayer, WorkoutSoundPlayer, AtemView, WorkoutProgramsView).
- AmbientSoundPlayer: Fades/Crossfade setzen `volume` laufend neu → Stummschaltung muss im
  Zielwert (`targetVolume`/Fade-Ziel) greifen, nicht nur beim Erzeugen.
- Sprachausgabe: `AVSpeechUtterance.volume = 0` (Wertebereich 0…1).

## Existing Specs / Tests

- Unit-Target `LeanHealthTimerTests`, UI-Target `LeanHealthTimerUITests`.
- Keine Tests, die die App-Player instanziieren oder Lautstärke prüfen.

## Risks

- Scope: 5 App-Dateien = Obergrenze der Scoping-Limits; App-Code ca. 25–40 LoC (inkl. Injektionspunkte, Debug-Log).
- Fade-Logik im AmbientSoundPlayer überschreibt eine nur beim Erzeugen gesetzte 0.
- Watch-Target muss weiter kompilieren (GongPlayer).
- „Kein Ton“ ist im UI-Test nicht direkt messbar → Nachweis über Unit-Test der Entscheidung +
  Prüfung der gesetzten Lautstärken; UI-Suite muss ohne neue Rotmeldung bleiben.
- Alternative zum Vorschlag: Wiedergabe im Testmodus ganz abschalten (kein `play()`) — verworfen,
  weil Hintergrund-Tests auf laufende Audio-Sitzung angewiesen sind.

## Analysis

**Type:** Feature (Entwickler-Komfort, kein sichtbares Nutzerverhalten)

### Affected Files (Change Type)

| Datei | Change | LoC ca. |
|---|---|---|
| `Services/GongPlayer.swift` | MODIFY: neuer Helfer `enum AudioTestMode { static func volumeFactor(arguments: [String] = ProcessInfo.processInfo.arguments) -> Float }` am Dateiende (iOS + Watch, nur Foundation, kein pbxproj-Eintrag); `p.volume = …` vor `play()`; Faktor injizierbar für Unit-Test | ~15 |
| `Services/AmbientSoundPlayer.swift` | MODIFY: `targetVolume` trägt den Faktor (:69 Initialwert, :91 `setVolume`) → Fades/Crossfade (:196, :206, :303-304) folgen automatisch; `fadeOut` startet von `player.volume` | 2 |
| `Meditationstimer iOS/WorkoutSoundPlayer.swift` | MODIFY: Player-Lautstärke (:100) + `utterance.volume` (:133-139) | 3 |
| `Meditationstimer iOS/Tabs/AtemView.swift` | MODIFY: verschachtelter GongPlayer (:145) | 2 |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | MODIFY: SoundPlayer (:107) + `utterance.volume` (:135-144) | 3 |
| `Meditationstimer iOS/BackgroundAudioKeeper.swift` | keine Änderung (bereits volume 0, :32) | 0 |
| `LeanHealthTimerTests/…` | CREATE: Unit-Tests der Entscheidung + GongPlayer-Lautstärke | Test |

### Scope / Risk

5 App-Dateien (Grenze), ca. 25–40 LoC App-Code. Risiko niedrig: nur Lautstärkewerte, Abspielen, Dauer
und Audio-Sitzung unverändert. Kein Code wartet auf Audio-Delegates (kein `didFinish`); Gong-Abschlüsse
laufen über `p.duration` + `asyncAfter`.

### Technical Approach (Empfehlung A)

Entscheidung **nur** an `enable-testing` (nicht `XCTestConfigurationFilePath`, sonst Unit-Tests stumm und
Normalfall unprüfbar). Faktor als Float (0 oder 1), Aufrufstellen multiplizieren statt verzweigen.
Bestehende Erkennungen (App:75, ClaudeSync:34, ClaudeWiring:15/58) nicht anfassen (kein Drive-by).
Abschluss-Prüfung: jede `AVAudioPlayer(contentsOf:)` mit `play()` und jede `AVSpeechUtterance(` im App-Code
hat eine Lautstärkezuweisung mit Faktor (grep-Wächter).

| Variante | Dateien | LoC | Sitzung + play() bleiben | Risiko |
|---|---|---|---|---|
| **A: Helfer + Lautstärke je Stelle** | 5 | ~25 | ja | niedrig; Vollständigkeit per grep |
| B: im Testmodus nicht abspielen | 5 | ~25 | nein (Dauer/Abschlüsse ändern sich) | mittel, verfehlt DoD |
| C: gemeinsamer Mixer/zentraler Player | 5+ | 150+ | ja | hoch, Umbau + pbxproj |

### Dependencies

Watch-Target kompiliert `Services/GongPlayer.swift` → Helfer ohne iOS-only-API.
Unit-Tests per `@testable import`; GongPlayer-Lautstärketest braucht einen gebündelten Klang im
Test-Host (Bundle.main = App); Fallback: Test mit erzeugter Mini-WAV.

### Open Questions

Keine PO-Fragen. Unverifiziert: Sprachausgabe mit Lautstärke 0 dauert gleich lang — ohne Belang, da
kein Code auf ihr Ende wartet.
