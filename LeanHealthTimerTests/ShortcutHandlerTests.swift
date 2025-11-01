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

    // MARK: - Meditation (Offen Tab)

    func testParseOffenURL_ValidParameters() {
        let url = URL(string: "henemm-lht://start?tab=offen&phase1=20&phase2=2")!
        let request = handler.parse(url)

        XCTAssertNotNil(request, "Request should be parsed")
        XCTAssertEqual(request?.tab, .offen)

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

    // MARK: - Breathing (Atem Tab)

    func testParseAtemURL_ValidPreset() {
        let url = URL(string: "henemm-lht://start?tab=atem&preset=Box%204-4-4-4")!
        let request = handler.parse(url)

        XCTAssertNotNil(request)
        XCTAssertEqual(request?.tab, .atem)

        if case let .breathing(presetName) = request?.action {
            XCTAssertEqual(presetName, "Box 4-4-4-4")
        } else {
            XCTFail("Expected breathing action")
        }
    }

    func testParseAtemURL_AllValidPresets() {
        let presets = ["Box 4-4-4-4", "4-0-6-0", "Coherent 5-0-5-0", "7-0-5-0", "4-7-8", "Rectangle 6-3-6-3"]

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

    // MARK: - Workout

    func testParseWorkoutURL_ValidParameters() {
        let url = URL(string: "henemm-lht://start?tab=workouts&interval=30&rest=10&repeats=10")!
        let request = handler.parse(url)

        XCTAssertNotNil(request)
        XCTAssertEqual(request?.tab, .workouts)

        if case let .workout(interval, rest, repeats) = request?.action {
            XCTAssertEqual(interval, 30)
            XCTAssertEqual(rest, 10)
            XCTAssertEqual(repeats, 10)
        } else {
            XCTFail("Expected workout action")
        }
    }

    func testParseWorkoutURL_MissingParameters() {
        let url = URL(string: "henemm-lht://start?tab=workouts&interval=30")!
        let request = handler.parse(url)
        XCTAssertNil(request, "Missing rest/repeats should fail")
    }

    func testParseWorkoutURL_OutOfRangeInterval() {
        let url = URL(string: "henemm-lht://start?tab=workouts&interval=700&rest=10&repeats=10")!
        let request = handler.parse(url)
        XCTAssertNil(request, "interval > 600 should fail")
    }

    func testParseWorkoutURL_OutOfRangeRepeats() {
        let url = URL(string: "henemm-lht://start?tab=workouts&interval=30&rest=10&repeats=300")!
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
