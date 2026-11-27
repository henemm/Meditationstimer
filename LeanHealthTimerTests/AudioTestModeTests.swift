import XCTest
@testable import Lean_Health_Timer

/// Stummschaltung im Testmodus (#131): Faktor aus Launch-Argumenten und Lautstärke der Player.
///
/// Annahme für den Developer (Spec nennt keinen Namen): `GongPlayer` bekommt, analog zum
/// `AmbientSoundPlayer`, einen lesenden internen Zugriff `currentVolumes: [Float]` auf die
/// `volume` seiner aktiven AVAudioPlayer. `AmbientSoundPlayer.currentVolumes` ist ein Tupel `(a:, b:)`.
final class AudioTestModeTests: XCTestCase {

    // MARK: - AC-1 / AC-2

    /// Verhalten: Mit Launch-Argument `enable-testing` ist alles stumm (Faktor 0).
    func testVolumeFactorIsZeroWithEnableTesting() {
        XCTAssertEqual(AudioTestMode.volumeFactor(arguments: ["App", "enable-testing"]), 0)
    }

    /// Verhalten: Ohne `enable-testing` bleibt alles hörbar (Faktor 1).
    func testVolumeFactorIsOneWithoutEnableTesting() {
        XCTAssertEqual(AudioTestMode.volumeFactor(arguments: []), 1)
        XCTAssertEqual(AudioTestMode.volumeFactor(arguments: ["App"]), 1)
    }

    /// Verhalten: Fremde Argumente und bloße Teilstrings schalten nicht stumm.
    func testVolumeFactorIsOneWithUnrelatedArguments() {
        XCTAssertEqual(AudioTestMode.volumeFactor(arguments: ["App", "-AppleLanguages", "(de)"]), 1)
        XCTAssertEqual(AudioTestMode.volumeFactor(arguments: ["App", "enable-testing-x"]), 1)
    }

    // MARK: - AC-3 GongPlayer

    /// Verhalten: Gong mit Faktor 0 spielt, aber mit Lautstärke 0.
    func testGongPlayerVolumeZeroWithFactorZero() {
        let gong = GongPlayer(volumeFactor: 0)
        gong.play(named: "gong-ende")
        let vols = waitForGongVolumes(gong)
        XCTAssertFalse(vols.isEmpty, "Gong muss einen aktiven Player haben (play() wurde aufgerufen)")
        XCTAssertTrue(vols.allSatisfy { $0 == 0 }, "Lautstärke muss 0 sein: \(vols)")
    }

    /// Verhalten: Gong mit Faktor 1 spielt mit voller Lautstärke.
    func testGongPlayerVolumeOneWithFactorOne() {
        let gong = GongPlayer(volumeFactor: 1)
        gong.play(named: "gong-ende")
        let vols = waitForGongVolumes(gong)
        XCTAssertFalse(vols.isEmpty, "Gong muss einen aktiven Player haben")
        XCTAssertTrue(vols.allSatisfy { $0 == 1 }, "Lautstärke muss 1 sein: \(vols)")
    }

    private func waitForGongVolumes(_ gong: GongPlayer) -> [Float] {
        let deadline = Date().addingTimeInterval(3)
        while gong.currentVolumes.isEmpty && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return gong.currentVolumes
    }

    // MARK: - AC-4 AmbientSoundPlayer

    /// Verhalten: Mit Faktor 0 ist die tatsächliche Lautstärke beider Player nie größer als 0
    /// (setVolume 100, Fade-in), auch nach Abwarten des Fade-in.
    func testAmbientActualVolumeNeverAboveZeroWithFactorZero() {
        let ambient = AmbientSoundPlayer(volumeFactor: 0)
        ambient.setVolume(percent: 100)
        XCTAssertLessThanOrEqual(maxVolume(ambient), 0)
        ambient.start(sound: .waves)
        var peak: Float = 0
        let end = Date().addingTimeInterval(4.0) // länger als Fade-in (3 s)
        while Date() < end {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            peak = max(peak, maxVolume(ambient))
        }
        ambient.stop()
        XCTAssertLessThanOrEqual(peak, 0, "Ambient darf mit Faktor 0 nie hörbar werden")
    }

    /// Verhalten: Normalmodus unverändert, 50 % ergibt nach dem Fade-in Lautstärke 0,5.
    func testAmbientActualVolumeReachesHalfWithFactorOne() {
        let ambient = AmbientSoundPlayer(volumeFactor: 1)
        ambient.setVolume(percent: 50)
        ambient.start(sound: .waves)
        var peak: Float = 0
        let end = Date().addingTimeInterval(6.0)
        while Date() < end && peak < 0.499 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            peak = max(peak, maxVolume(ambient))
        }
        ambient.stop()
        XCTAssertEqual(peak, 0.5, accuracy: 0.01)
    }

    private func maxVolume(_ a: AmbientSoundPlayer) -> Float {
        let v = a.currentVolumes
        return max(v.a, v.b)
    }
}
