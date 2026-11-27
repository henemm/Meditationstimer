import XCTest

/// Vollständigkeitstest (#131): Jede Klangstelle in den fünf App-Dateien setzt eine Testmodus-Lautstärke.
final class AudioTestModeCoverageTests: XCTestCase {

    private static let files = [
        "Services/GongPlayer.swift",
        "Services/AmbientSoundPlayer.swift",
        "Meditationstimer iOS/WorkoutSoundPlayer.swift",
        "Meditationstimer iOS/Tabs/AtemView.swift",
        "Meditationstimer iOS/Tabs/WorkoutProgramsView.swift"
    ]

    private enum Kind: String { case player = "AVAudioPlayer(contentsOf:", speech = "AVSpeechUtterance(" }

    /// Zeilennummern (1-basiert) von Klangstellen ohne Lautstärkezuweisung der gewünschten Art.
    private static func violations(in text: String, kind: Kind) -> [Int] {
        let lines = text.components(separatedBy: "\n")
        var bad: [Int] = []
        for (i, line) in lines.enumerated() where line.contains(kind.rawValue) {
            if kind == .player {
                guard let name = playerName(in: line), isPlayed(name, after: i, in: lines) else { continue }
            }
            let window = lines[i..<min(lines.count, i + 9)]
            let ok = window.contains {
                $0.contains(".volume") && ($0.contains("AudioTestMode") || $0.contains("volumeFactor"))
            }
            if !ok { bad.append(i + 1) }
        }
        return bad
    }

    private static func playerName(in line: String) -> String? {
        guard let eq = line.range(of: "=") else { return nil }
        let words = line[line.startIndex..<eq.lowerBound]
            .split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == "_") })
        guard let last = words.last, last != "let", last != "var" else { return nil }
        return String(last)
    }

    private static func isPlayed(_ name: String, after index: Int, in lines: [String]) -> Bool {
        lines[(index + 1)...].contains { $0.contains("\(name).play()") || $0.contains("\(name)?.play()") }
    }

    private func read(_ rel: String) throws -> String {
        // LeanHealthTimerTests/<Datei> -> Repo-Wurzel
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(rel), encoding: .utf8)
    }

    private func assertCovered(_ kind: Kind) throws {
        var found = 0
        for f in Self.files {
            let text = try read(f)
            found += text.components(separatedBy: kind.rawValue).count - 1
            let bad = Self.violations(in: text, kind: kind)
            XCTAssertEqual(bad, [], "\(f): \(kind.rawValue) ohne AudioTestMode-Lautstärke in Zeilen \(bad)")
        }
        XCTAssertGreaterThan(found, 0, "Prüfumfang darf nicht leer sein")
    }

    /// Verhalten: Jeder abspielende AVAudioPlayer hat eine Testmodus-Lautstärke (AC-7).
    func testAllPlayingAudioPlayersHaveFactorVolume() throws {
        try assertCovered(.player)
    }

    /// Verhalten: Jede Sprachausgabe hat eine Testmodus-Lautstärke (AC-6).
    func testAllSpeechUtterancesHaveFactorVolume() throws {
        try assertCovered(.speech)
    }

    /// Verhalten: Der Prüfer schlägt an, wenn die Zuweisung fehlt (nicht leer grün).
    func testCoverageCheckDetectsMissingAssignment() {
        let sample = """
        let p = try AVAudioPlayer(contentsOf: url)
        p.prepareToPlay()
        p.play()
        let u = AVSpeechUtterance(string: "Hallo")
        synth.speak(u)
        """
        XCTAssertEqual(Self.violations(in: sample, kind: .player), [1])
        XCTAssertEqual(Self.violations(in: sample, kind: .speech), [4])
    }

    /// Verhalten: Der Prüfer akzeptiert Stellen mit Zuweisung.
    func testCoverageCheckAcceptsAssignment() {
        let sample = """
        let p = try AVAudioPlayer(contentsOf: url)
        p.volume = AudioTestMode.volumeFactor()
        p.play()
        let u = AVSpeechUtterance(string: "Hallo")
        u.volume = u.volume * AudioTestMode.volumeFactor()
        """
        XCTAssertEqual(Self.violations(in: sample, kind: .player), [])
        XCTAssertEqual(Self.violations(in: sample, kind: .speech), [])
    }
}
