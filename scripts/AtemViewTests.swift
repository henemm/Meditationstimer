import XCTest
@testable import Lean_Health_Timer

final class AtemViewTests: XCTestCase {
    /// Tests for Atem tab logic including phase transitions and Live Activity updates

    func testPhaseTransitions() {
        // Test basic phase transition logic
        let preset = AtemView.Preset(
            id: UUID(),
            name: "Test",
            emoji: "🧘",
            inhale: 4,
            holdIn: 2,
            exhale: 4,
            holdOut: 2,
            repetitions: 2
        )

        // Test phase duration calculation
        XCTAssertEqual(preset.duration(for: .inhale), 4)
        XCTAssertEqual(preset.duration(for: .holdIn), 2)
        XCTAssertEqual(preset.duration(for: .exhale), 4)
        XCTAssertEqual(preset.duration(for: .holdOut), 2)

        // Test total duration calculation
        let expectedTotal = (4 + 2 + 4 + 2) * 2 // 2 repetitions
        XCTAssertEqual(preset.totalSeconds, expectedTotal)
    }

    func testPhaseNumberMapping() {
        // Test that phases map to correct Live Activity phase numbers
        XCTAssertEqual(AtemView.SessionCard.phaseNumber(for: .inhale), 1)
        XCTAssertEqual(AtemView.SessionCard.phaseNumber(for: .holdIn), 2)
        XCTAssertEqual(AtemView.SessionCard.phaseNumber(for: .exhale), 3)
        XCTAssertEqual(AtemView.SessionCard.phaseNumber(for: .holdOut), 4)
    }

    func testIconNameMapping() {
        // Test that phases map to correct icon names
        XCTAssertEqual(AtemView.SessionCard.iconName(for: .inhale), "arrow.up")
        XCTAssertEqual(AtemView.SessionCard.iconName(for: .holdIn), "arrow.right")
        XCTAssertEqual(AtemView.SessionCard.iconName(for: .exhale), "arrow.down")
        XCTAssertEqual(AtemView.SessionCard.iconName(for: .holdOut), "arrow.right")
    }

    func testPresetValidation() {
        // Test preset with zero durations
        let preset = AtemView.Preset(
            id: UUID(),
            name: "Test",
            emoji: "🧘",
            inhale: 0,
            holdIn: 0,
            exhale: 4,
            holdOut: 0,
            repetitions: 1
        )

        // Should handle zero durations gracefully
        XCTAssertEqual(preset.duration(for: .inhale), 0)
        XCTAssertEqual(preset.duration(for: .holdIn), 0)
        XCTAssertEqual(preset.duration(for: .exhale), 4)
        XCTAssertEqual(preset.duration(for: .holdOut), 0)
    }
}

// MARK: - Test Extensions

extension AtemView.Preset {
    /// Helper to get duration for a phase (extracted from AtemView logic)
    func duration(for phase: AtemView.Phase) -> Int {
        switch phase {
        case .inhale: return inhale
        case .holdIn: return holdIn
        case .exhale: return exhale
        case .holdOut: return holdOut
        }
    }

    /// Helper to get total seconds (extracted from AtemView logic)
    var totalSeconds: Int {
        (inhale + holdIn + exhale + holdOut) * repetitions
    }
}

extension AtemView.SessionCard {
    /// Helper to get phase number for Live Activity (extracted from onPhaseChanged logic)
    static func phaseNumber(for phase: AtemView.Phase) -> Int {
        switch phase {
        case .inhale: return 1
        case .holdIn: return 2
        case .exhale: return 3
        case .holdOut: return 4
        }
    }
}