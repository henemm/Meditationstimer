//
//  ShortcutHandlerTests.swift
//  LeanHealthTimerTests
//
//  Unit tests for ShortcutHandler URL parsing logic.
//

import XCTest
@testable import Lean_Health_Timer

@MainActor
final class ShortcutHandlerTests: XCTestCase {

    var handler: ShortcutHandler!

    override func setUp() {
        super.setUp()
        handler = ShortcutHandler()
    }

    override func tearDown() {
        handler = nil
        super.tearDown()
    }

    // MARK: - Meditation (Legacy: Offen Tab → New: Meditation Tab)

    func testParseOffenURL_ValidParameters() {
        // Legacy URL with "offen" should map to new .meditation tab
        let url = URL(string: "henemm-lht://start?tab=offen&phase1=20&phase2=2")!
        let request = handler.parse(url)

        XCTAssertNotNil(request, "Request should be parsed")
        XCTAssertEqual(request?.tab, .meditation, "Legacy 'offen' should map to .meditation")

        if case let .meditation(phase1, phase2) = request?.action {
            XCTAssertEqual(phase1, 20)
            XCTAssertEqual(phase2, 2)
        } else {
            XCTFail("Expected meditation action")
        }
    }

    func testParseMeditationURL_ValidParameters() {
        // New URL with "meditation" tab
        let url = URL(string: "henemm-lht://start?tab=meditation&phase1=20&phase2=2")!
        let request = handler.parse(url)

        XCTAssertNotNil(request, "Request should be parsed")
        XCTAssertEqual(request?.tab, .meditation)

        if case let .meditation(phase1, phase2) = request?.action {
            XCTAssertEqual(phase1, 20)
            XCTAssertEqual(phase2, 2)
        } else {
            XCTFail("Expected meditation action")
        }
    }

    func testParseOffenURL_DefaultPhase2() {
        // phase2 is optional, defaults to 0
        let url = URL(string: "henemm-lht://start?tab=offen&phase1=15")!
        let request = handler.parse(url)

        XCTAssertNotNil(request)
        if case let .meditation(phase1, phase2) = request?.action {
            XCTAssertEqual(phase1, 15)
            XCTAssertEqual(phase2, 0)
        } else {
            XCTFail("Expected meditation action")
        }
    }

    func testParseOffenURL_MissingPhase1() {
        let url = URL(string: "henemm-lht://start?tab=offen&phase2=2")!
        let request = handler.parse(url)
        XCTAssertNil(request, "Should fail without phase1")
    }

    func testParseOffenURL_OutOfRangePhase1() {
        let url = URL(string: "henemm-lht://start?tab=offen&phase1=150&phase2=2")!
        let request = handler.parse(url)
        XCTAssertNil(request, "phase1 > 120 should fail")
    }

    func testParseOffenURL_OutOfRangePhase2() {
        let url = URL(string: "henemm-lht://start?tab=offen&phase1=20&phase2=50")!
        let request = handler.parse(url)
        XCTAssertNil(request, "phase2 > 30 should fail")
    }

    // MARK: - Breathing (Legacy: Atem Tab → New: Meditation Tab)

    func testParseAtemURL_ValidPreset() {
        // Legacy "atem" tab now maps to .meditation (breathing is part of meditation tab)
        let url = URL(string: "henemm-lht://start?tab=atem&preset=Box%20Breathing")!
        let request = handler.parse(url)

        XCTAssertNotNil(request)
        XCTAssertEqual(request?.tab, .meditation, "Legacy 'atem' should map to .meditation")

        if case let .breathing(presetName) = request?.action {
            XCTAssertEqual(presetName, "Box Breathing")
        } else {
            XCTFail("Expected breathing action")
        }
    }

    func testParseAtemURL_AllValidPresets() {
        let presets = ["Box Breathing", "Calming Breath", "Coherent Breathing", "Deep Calm", "Relaxing Breath", "Rhythmic Breath"]

        for preset in presets {
            let encoded = preset.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            let url = URL(string: "henemm-lht://start?tab=atem&preset=\(encoded)")!
            let request = handler.parse(url)

            XCTAssertNotNil(request, "Preset '\(preset)' should be valid")
            if case let .breathing(parsedName) = request?.action {
                XCTAssertEqual(parsedName, preset)
            } else {
                XCTFail("Expected breathing action for preset '\(preset)'")
            }
        }
    }

    func testParseAtemURL_InvalidPreset() {
        let url = URL(string: "henemm-lht://start?tab=atem&preset=InvalidPreset")!
        let request = handler.parse(url)
        XCTAssertNil(request, "Invalid preset should fail")
    }

    func testParseAtemURL_MissingPreset() {
        let url = URL(string: "henemm-lht://start?tab=atem")!
        let request = handler.parse(url)
        XCTAssertNil(request, "Missing preset should fail")
    }

    // MARK: - Workout (Legacy: Frei Tab → New: Workout Tab)

    func testParseWorkoutURL_ValidParameters() {
        // Use "frei" or "workout" tab (legacy "workouts" returns nil as it's not implemented)
        let url = URL(string: "henemm-lht://start?tab=frei&interval=30&rest=10&repeats=10")!
        let request = handler.parse(url)

        XCTAssertNotNil(request)
        XCTAssertEqual(request?.tab, .workout, "Legacy 'frei' should map to .workout")

        if case let .workout(interval, rest, repeats) = request?.action {
            XCTAssertEqual(interval, 30)
            XCTAssertEqual(rest, 10)
            XCTAssertEqual(repeats, 10)
        } else {
            XCTFail("Expected workout action")
        }
    }

    func testParseWorkoutURL_NewTabName() {
        // New URL with "workout" tab
        let url = URL(string: "henemm-lht://start?tab=workout&interval=30&rest=10&repeats=10")!
        let request = handler.parse(url)

        XCTAssertNotNil(request)
        XCTAssertEqual(request?.tab, .workout)

        if case let .workout(interval, rest, repeats) = request?.action {
            XCTAssertEqual(interval, 30)
            XCTAssertEqual(rest, 10)
            XCTAssertEqual(repeats, 10)
        } else {
            XCTFail("Expected workout action")
        }
    }

    func testParseWorkoutURL_LegacyWorkoutsTab() {
        // Legacy "workouts" tab returns nil (workout programs not yet implemented)
        let url = URL(string: "henemm-lht://start?tab=workouts&interval=30&rest=10&repeats=10")!
        let request = handler.parse(url)
        XCTAssertNil(request, "Legacy 'workouts' tab should return nil (not implemented)")
    }

    func testParseWorkoutURL_MissingParameters() {
        let url = URL(string: "henemm-lht://start?tab=frei&interval=30")!
        let request = handler.parse(url)
        XCTAssertNil(request, "Missing rest/repeats should fail")
    }

    func testParseWorkoutURL_OutOfRangeInterval() {
        let url = URL(string: "henemm-lht://start?tab=frei&interval=700&rest=10&repeats=10")!
        let request = handler.parse(url)
        XCTAssertNil(request, "interval > 600 should fail")
    }

    func testParseWorkoutURL_OutOfRangeRepeats() {
        let url = URL(string: "henemm-lht://start?tab=frei&interval=30&rest=10&repeats=300")!
        let request = handler.parse(url)
        XCTAssertNil(request, "repeats > 200 should fail")
    }

    // MARK: - Invalid URLs

    func testParseInvalidScheme() {
        let url = URL(string: "https://example.com/start?tab=offen&phase1=20")!
        let request = handler.parse(url)
        XCTAssertNil(request, "Wrong scheme should fail")
    }

    func testParseMissingTab() {
        let url = URL(string: "henemm-lht://start?phase1=20&phase2=2")!
        let request = handler.parse(url)
        XCTAssertNil(request, "Missing tab parameter should fail")
    }

    func testParseInvalidTab() {
        let url = URL(string: "henemm-lht://start?tab=invalid&phase1=20")!
        let request = handler.parse(url)
        XCTAssertNil(request, "Invalid tab should fail")
    }

    func testParseNoQueryParameters() {
        let url = URL(string: "henemm-lht://start")!
        let request = handler.parse(url)
        XCTAssertNil(request, "No query parameters should fail")
    }
}
