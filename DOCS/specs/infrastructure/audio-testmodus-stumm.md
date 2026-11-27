---
entity_id: audio-testmodus-stumm
type: feature
created: 2026-11-27
updated: 2026-11-27
status: draft
issue: 131
workflow: chore-131-tests-stumm
---

# Audio im Testmodus stumm

## Approval

- [ ] Approved

## Purpose

UI-Tests spielen im Simulator auf dem Entwicklungsrechner Gongs, Ansagen und Hintergrundklänge hörbar ab. Startet die App mit dem Launch-Argument `enable-testing` (setzen alle UI-Tests), soll jede Klangquelle mit Lautstärke 0 laufen. Audio-Sitzung, `play()` und Dauern bleiben unverändert, damit die Hintergrund-Tests ihre Aussage behalten. Ohne `enable-testing` bleibt alles hörbar wie bisher.

## Source

- Helfer: `Services/GongPlayer.swift` · `AudioTestMode` (`volumeFactor(arguments:)`, `logVolume(_:_:)`)
- Klangstellen: `Services/GongPlayer.swift` · `GongPlayer`; `Services/AmbientSoundPlayer.swift` · `AmbientSoundPlayer`; `Meditationstimer iOS/WorkoutSoundPlayer.swift` · `WorkoutSoundPlayer`; `Meditationstimer iOS/Tabs/AtemView.swift` · verschachtelter `GongPlayer`; `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` · `SoundPlayer`
- Unverändert: `Meditationstimer iOS/BackgroundAudioKeeper.swift` (setzt bereits `volume = 0.0`)

## Scope

Genau 5 App-Dateien MODIFY. App-Code ca. 25–40 LoC inklusive Injektionspunkte und Debug-Logzeilen (Testcode zählt nicht mit). Dazu neue Unit-Test-Dateien in `LeanHealthTimerTests`.

## Affected Files

- `Services/GongPlayer.swift` (Helfer `AudioTestMode` am Dateiende, injizierbarer Faktor, Lautstärke vor `play()`)
- `Services/AmbientSoundPlayer.swift` (injizierbarer Faktor, `targetVolume`, `setVolume(percent:)`, lesender Zugriff)
- `Meditationstimer iOS/WorkoutSoundPlayer.swift` (AVAudioPlayer + AVSpeechUtterance)
- `Meditationstimer iOS/Tabs/AtemView.swift` (verschachtelter GongPlayer)
- `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` (SoundPlayer + AVSpeechUtterance)
- Neu (Test): `LeanHealthTimerTests/AudioTestModeTests.swift`, `LeanHealthTimerTests/AudioTestModeCoverageTests.swift`

## Expected Behavior

### Helfer

Am Ende von `Services/GongPlayer.swift` (kompiliert in iOS und Watch, nur Foundation und `os`, kein pbxproj-Eintrag nötig):

```swift
enum AudioTestMode {
    static func volumeFactor(arguments: [String] = ProcessInfo.processInfo.arguments) -> Float
    static func logVolume(_ site: String, _ volume: Float)   // nur #if DEBUG, sonst leer
}
```

- `volumeFactor` liefert `0`, wenn `arguments` genau den Eintrag `"enable-testing"` enthält, sonst `1`.
- Berücksichtigt `XCTestConfigurationFilePath` bewusst NICHT. Sonst wären Unit-Tests stumm, die den Normalfall prüfen.
- Die drei bestehenden `enable-testing`-Erkennungen (`Meditationstimer_iOSApp.swift`, `Claude/ClaudeSync.swift`, `Claude/ClaudeWiring.swift`) bleiben unangetastet (kein Drive-by).
- `logVolume` schreibt unter `#if DEBUG` eine Zeile per `Logger(subsystem: Bundle.main.bundleIdentifier ?? "app", category: "AudioTestMode")` mit Stellenname und gesetzter Lautstärke. Im Release-Build ist die Funktion leer.

### Je Klangstelle

- `AVAudioPlayer.volume` wird vor `play()` auf `AudioTestMode.volumeFactor()` (bzw. den injizierten Faktor) gesetzt, danach genau ein Aufruf `AudioTestMode.logVolume("<Stelle>", p.volume)`.
- `AVSpeechUtterance.volume` wird mit dem Faktor multipliziert (Wertebereich 0…1), danach ein `logVolume`-Aufruf.
- `GongPlayer` und `AmbientSoundPlayer` erhalten den Faktor injizierbar (Initialisierer-Parameter `volumeFactor: Float = AudioTestMode.volumeFactor()`).
- `AmbientSoundPlayer`: Der Faktor wirkt im Zielwert `targetVolume` (Initialwert und `setVolume(percent:)`). Fade-in, Fade-out und Crossfade (Player A/B) folgen daraus. Für `@testable`-Tests gibt es einen lesenden internen Zugriff auf die tatsächliche `volume` beider Player (z. B. `internal var currentVolumes: (a: Float, b: Float)`).
- `play()`, Audio-Sitzung und Dauern (`p.duration`, `asyncAfter`-Abschlüsse) bleiben unverändert. Kein Code wartet auf Audio-Delegates.

## Acceptance Criteria

- AC-1: Given Argumente `["App", "enable-testing"]`, When `AudioTestMode.volumeFactor(arguments:)` aufgerufen wird, Then ist das Ergebnis `0`.
- AC-2: Given Argumente ohne `enable-testing` (leer, `["App"]`, `["App", "-AppleLanguages", "(de)"]`), When `volumeFactor(arguments:)` aufgerufen wird, Then ist das Ergebnis `1`. Ein Argument, das `enable-testing` nur als Teilstring enthält (z. B. `"enable-testing-x"`), liefert ebenfalls `1`.
- AC-3: Given ein `GongPlayer` mit injiziertem Faktor 0, When er einen Gong abspielt, Then ist `volume` des zugrunde liegenden AVAudioPlayer 0 und `play()` wurde aufgerufen. Bei Faktor 1 ist `volume` 1.
- AC-4: Given `AmbientSoundPlayer` mit injiziertem Faktor 0, When `setVolume(percent: 100)`, Fade-in und (wo synchron auslösbar) der Crossfade laufen, Then ist die tatsächliche `volume` beider Player (über den lesenden Zugriff) nie größer als 0. Bei zeitgesteuerten Fades wird der Endwert nach dem Abwarten innerhalb einer Zeitgrenze geprüft. Bei Faktor 1 erreicht die tatsächliche Lautstärke nach `setVolume(percent: 50)` den Wert 0,5 (Normalmodus unverändert).
- AC-5: Given Normalmodus (Faktor 1), When irgendeine Klangquelle spielt, Then ist das Verhalten gegenüber dem Stand vor der Änderung identisch.
- AC-6: Given die fünf App-Quelldateien, When der automatische Vollständigkeitstest sie liest, Then hat jede `AVSpeechUtterance(`-Stelle innerhalb weniger Zeilen eine Lautstärkezuweisung mit `AudioTestMode`/Faktor.
- AC-7: Given die fünf App-Quelldateien (inkl. Atem- und Workout-Player), When der Vollständigkeitstest sie liest, Then hat jede `AVAudioPlayer(contentsOf:`-Stelle, deren Player abgespielt wird, innerhalb weniger Zeilen eine Lautstärkezuweisung mit `AudioTestMode`/Faktor.
- AC-8: Given der Vollständigkeitstest, When er auf einen eingebetteten Beispieltext ohne Lautstärkezuweisung angewendet wird, Then meldet er einen Fehler (Negativfall; der Test ist nicht leer grün). Ein Beispieltext mit Zuweisung wird akzeptiert.
- AC-9: Given die Änderung, When das Watch-Target gebaut wird, Then kompiliert es fehlerfrei (Helfer nur Foundation und `os`).
- AC-10: Given die komplette UI-Suite (`./Scripts/run-uitests.sh`), When sie nach der Änderung läuft, Then gibt es keine neuen Fehlschläge gegenüber dem Stand davor; Hintergrund-Tests behalten ihre Aussage.
- AC-11: Given die App im Simulator mit `enable-testing` im Debug-Build, When Gong in Meditation, Atem und Workout ausgelöst werden, Then steht im Log (Kategorie „AudioTestMode“) je Abspielstelle genau eine Zeile mit Lautstärke 0.

### Regel für den Vollständigkeitstest

- Prüfumfang: genau die fünf Dateien aus „Affected Files“ (App-Code), gelesen über einen Pfad relativ zu `#filePath` des Tests.
- Eine `AVAudioPlayer(contentsOf:`-Stelle zählt als abspielend, wenn derselbe Player-Name in der Datei später mit `.play()` oder `play()` aufgerufen wird. Reine Duration-Proben (Player nur für `.duration` erzeugt, kein `play()` auf demselben Namen) sind ausgenommen. Dieselbe Regel gilt für `WorkoutSoundPlayer` und `WorkoutProgramsView`.
- Jede zählende Stelle und jede `AVSpeechUtterance(`-Stelle braucht innerhalb der folgenden 8 Zeilen eine Zeile mit `.volume` und `AudioTestMode` bzw. dem Faktor-Namen (`volumeFactor`).
- `BackgroundAudioKeeper` ist nicht im Prüfumfang (bereits `volume = 0.0`).

## Test Plan

Unit-Tests `LeanHealthTimerTests/AudioTestModeTests.swift`:

- [ ] `testVolumeFactorIsZeroWithEnableTesting` (AC-1)
- [ ] `testVolumeFactorIsOneWithoutEnableTesting` (AC-2)
- [ ] `testVolumeFactorIsOneWithUnrelatedArguments` (AC-2, `-AppleLanguages`, Teilstring)
- [ ] `testGongPlayerVolumeZeroWithFactorZero` (AC-3)
- [ ] `testGongPlayerVolumeOneWithFactorOne` (AC-3)
- [ ] `testAmbientActualVolumeNeverAboveZeroWithFactorZero` (AC-4: `setVolume(percent: 100)`, Fade-in, Crossfade soweit synchron auslösbar; sonst Endwert nach Abwarten mit Zeitgrenze)
- [ ] `testAmbientActualVolumeReachesHalfWithFactorOne` (AC-4, Normalfall)

Für GongPlayer/AmbientSoundPlayer wird ein gebündelter Klang genutzt; ist keiner im Test-Host erreichbar, erzeugt der Test eine Mini-WAV.

Unit-Tests `LeanHealthTimerTests/AudioTestModeCoverageTests.swift`:

- [ ] `testAllPlayingAudioPlayersHaveFactorVolume` (AC-7)
- [ ] `testAllSpeechUtterancesHaveFactorVolume` (AC-6)
- [ ] `testCoverageCheckDetectsMissingAssignment` (AC-8, Negativfall mit eingebettetem Beispieltext)
- [ ] `testCoverageCheckAcceptsAssignment` (AC-8, Positivfall)

Ausführung:

- Unit: `xcodebuild test -project Meditationstimer.xcodeproj -scheme "Lean Health Timer" -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:LeanHealthTimerTests`
- UI: `./Scripts/run-uitests.sh` (Einzeltest immer als `Klasse/Methode`)
- Bestanden nur, wenn im Protokoll `Executed N tests` mit N ≥ 1 steht; `TEST SUCCEEDED` allein beweist nichts.
- Watch-Build: Scheme der Watch-App bauen (AC-9).

Nutzer-Durchlauf im Simulator (Pflicht vor Übergabe, kein Hörtest nötig, nur Simulator):

- [ ] Debug-Build installieren, App starten mit `xcrun simctl launch <Simulator> <BundleID> enable-testing`.
- [ ] Gong in Meditation, Atem und Workout auslösen, Hintergrundklang starten.
- [ ] Log lesen: `xcrun simctl spawn <Simulator> log show --last 5m --predicate 'category == "AudioTestMode"'`. Erwartet: je Abspielstelle eine Zeile mit Lautstärke 0 (AC-11).
- [ ] Gegenprobe ohne `enable-testing`: Zeilen zeigen Lautstärke 1 (bzw. die eingestellte Ambient-Lautstärke).

## Dependencies

| Abhängigkeit | Art | Hinweis |
|---|---|---|
| `Services/GongPlayer.swift` ist in iOS- und Watch-Target | Build | Helfer nur Foundation und `os`, kein pbxproj-Eintrag |
| `Services/AmbientSoundPlayer.swift` | nur iOS | Faktor im Zielwert, Fades folgen |
| `BackgroundAudioKeeper` | keine Änderung | bereits `volume = 0.0` |
| UI-Tests setzen `enable-testing` | Laufzeit | Auslöser der Stummschaltung |
| Bestehende Erkennungen (`Meditationstimer_iOSApp.swift:75`, `ClaudeSync.swift:34`, `ClaudeWiring.swift:15/58`) | unberührt | kein Drive-by |
| Gebündelter Klang im Test-Host | Test | Fallback: erzeugte Mini-WAV |
| `Logger`/`os` | Debug-Log | nur `#if DEBUG` |

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine (lokale Entscheidung ohne Architekturwirkung, nur Lautstärkewerte im Testmodus)

- **A (gewählt): Helfer plus Lautstärke je Stelle.** 5 Dateien, Sitzung und `play()` bleiben, niedriges Risiko. Die Vollständigkeit sichert ein automatischer Test (`AudioTestModeCoverageTests`).
- **B (verworfen): im Testmodus nicht abspielen.** Dauern und Abschlüsse ändern sich, Hintergrund-Tests mit laufender Audio-Sitzung verlören ihre Aussage.
- **C (verworfen): gemeinsamer Mixer bzw. zentraler Player.** Umbau von über 5 Dateien, 150+ LoC, pbxproj-Änderungen, hohes Risiko für ein reines Entwickler-Komfortthema. Als eigener Umbau später denkbar; er würde das Vollständigkeitsrisiko beseitigen.

## Definition of Done

- [ ] Die 5 App-Dateien sind geändert, `BackgroundAudioKeeper` und die drei bestehenden Erkennungen unverändert.
- [ ] App-Code im Rahmen von ca. 25–40 LoC (Limit ±250 eingehalten), keine weiteren Dateien im App-Code.
- [ ] Alle Unit-Tests aus dem Test Plan grün (`Executed N tests`, N ≥ 1), inklusive Negativfall des Vollständigkeitstests.
- [ ] Komplette UI-Suite ohne neue Fehlschläge gegenüber dem Stand davor.
- [ ] Watch-Target baut fehlerfrei.
- [ ] Simulator-Durchlauf mit `enable-testing`: je Abspielstelle eine Logzeile mit Lautstärke 0; Gegenprobe ohne Argument zeigt Normalwerte.
- [ ] Logzeilen nur unter `#if DEBUG`, genau eine je Stelle.
- [ ] Issue #131 aktualisiert und geschlossen.

## Out of Scope

- `BackgroundAudioKeeper` (bereits stumm).
- Vereinheitlichung der drei bestehenden `enable-testing`-Erkennungen.
- Zusammenlegen der getrennten Gong-/Sound-Player zu einer gemeinsamen Klasse.
- Stummschalten des Simulators oder des Macs (kein Schalter in `xcodebuild`/`simctl`; Mac stumm würde Hennings eigene Wiedergabe treffen).
- Geräte-Tests.
- Neue Nutzereinstellung für Lautstärke.

## Risks

- Scope am Limit bei Dateien: 5 App-Dateien (Obergrenze), LoC dagegen weit unter 250. Die Logzeilen laufen über den zentralen Helfer `logVolume` (ein Aufruf je Stelle, ca. 6 bis 8 Zeilen plus Helfer ca. 6), das hält das Limit; das Logging bleibt deshalb je Stelle erhalten und muss nicht auf eine zentrale Stelle reduziert werden.
- Vollständigkeit: Es gibt keinen gemeinsamen Abspielpunkt. Eine künftig neue Klangstelle in einer anderen Datei wäre vom Test nicht erfasst, solange sie nicht in den Prüfumfang aufgenommen wird. Der Test deckt die fünf bekannten Dateien ab; die Regel steht in der Spec.
- Fade-Logik im `AmbientSoundPlayer` überschreibt `volume` laufend. Deshalb wirkt der Faktor im Zielwert.
- Textbasierter Vollständigkeitstest kann an Umformatierungen scheitern (Fenster von 8 Zeilen). Der Negativfall verhindert leeres Grün.
- Watch-Target kompiliert `Services/GongPlayer.swift` mit: keine iOS-only-API im Helfer.
- Unverifiziert: Sprachausgabe mit Lautstärke 0 dauert gleich lang. Ohne Belang, da kein Code auf ihr Ende wartet.

## Changelog

- 2026-11-27: Initial spec created (#131)
- 2026-11-27: Validator-Befunde eingearbeitet (type feature, Pflicht-Abschnitte, injizierbarer Ambient-Faktor, automatischer Vollständigkeitstest, Debug-Log-Nachweis)
