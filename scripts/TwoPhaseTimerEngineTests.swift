import XCTest
import Combine
@testable import Lean_Health_Timer

final class TwoPhaseTimerEngineTests: XCTestCase {

    var engine: TwoPhaseTimerEngine!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        engine = TwoPhaseTimerEngine()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        cancellables.removeAll()
        engine.cancel()
        engine = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertEqual(engine.state, .idle, "Engine should start in idle state")
        XCTAssertNil(engine.startDate, "Start date should be nil initially")
        XCTAssertNil(engine.phase1EndDate, "Phase 1 end date should be nil initially")
        XCTAssertNil(engine.endDate, "End date should be nil initially")
    }

    // MARK: - Start Tests

    func testStartSetsCorrectDates() {
        let beforeStart = Date()
        engine.start(phase1Minutes: 5, phase2Minutes: 3, sessionType: "Test")
        let afterStart = Date()

        XCTAssertNotNil(engine.startDate, "Start date should be set")
        XCTAssertNotNil(engine.phase1EndDate, "Phase 1 end date should be set")
        XCTAssertNotNil(engine.endDate, "End date should be set")

        // Verify start date is recent
        XCTAssertGreaterThanOrEqual(engine.startDate!, beforeStart)
        XCTAssertLessThanOrEqual(engine.startDate!, afterStart)

        // Verify phase 1 ends 5 minutes after start
        let phase1Duration = engine.phase1EndDate!.timeIntervalSince(engine.startDate!)
        XCTAssertEqual(phase1Duration, 5 * 60, accuracy: 0.1, "Phase 1 should be 5 minutes")

        // Verify end date is 8 minutes (5+3) after start
        let totalDuration = engine.endDate!.timeIntervalSince(engine.startDate!)
        XCTAssertEqual(totalDuration, 8 * 60, accuracy: 0.1, "Total duration should be 8 minutes")
    }

    func testStartTransitionsToPhase1() {
        engine.start(phase1Minutes: 5, phase2Minutes: 3, sessionType: "Test")

        if case .phase1(let remaining) = engine.state {
            XCTAssertEqual(remaining, 300, accuracy: 1, "Should start with ~300 seconds remaining in phase 1")
        } else {
            XCTFail("Engine should be in phase1 state after start, got \(engine.state)")
        }
    }

    func testStartWithZeroMinutes() {
        engine.start(phase1Minutes: 0, phase2Minutes: 0, sessionType: "Test")

        // Should transition to finished immediately or very quickly
        // Give it a tiny bit of time for the timer to tick
        let expectation = XCTestExpectation(description: "State updates to finished")

        engine.$state
            .dropFirst() // Skip initial state
            .sink { state in
                if state == .finished {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testStartWithNegativeMinutesClampedToZero() {
        engine.start(phase1Minutes: -5, phase2Minutes: -3, sessionType: "Test")

        // Should treat negative as 0
        XCTAssertNotNil(engine.startDate)
        XCTAssertNotNil(engine.phase1EndDate)
        XCTAssertNotNil(engine.endDate)

        // All dates should be essentially the same
        let phase1Duration = engine.phase1EndDate!.timeIntervalSince(engine.startDate!)
        let totalDuration = engine.endDate!.timeIntervalSince(engine.startDate!)

        XCTAssertEqual(phase1Duration, 0, accuracy: 0.1)
        XCTAssertEqual(totalDuration, 0, accuracy: 0.1)
    }

    // MARK: - Cancel Tests

    func testCancelResetsState() {
        engine.start(phase1Minutes: 5, phase2Minutes: 3, sessionType: "Test")

        // Verify it started
        XCTAssertNotEqual(engine.state, .idle)
        XCTAssertNotNil(engine.startDate)

        // Cancel
        engine.cancel()

        // Verify reset
        XCTAssertEqual(engine.state, .idle)
        XCTAssertNil(engine.startDate)
        XCTAssertNil(engine.phase1EndDate)
        XCTAssertNil(engine.endDate)
    }

    func testCancelWhileIdle() {
        // Should not crash or cause issues
        engine.cancel()
        XCTAssertEqual(engine.state, .idle)
    }

    func testMultipleStartsResetTimer() {
        engine.start(phase1Minutes: 10, phase2Minutes: 5, sessionType: "Test")
        let firstStartDate = engine.startDate

        // Wait a tiny bit
        Thread.sleep(forTimeInterval: 0.1)

        engine.start(phase1Minutes: 3, phase2Minutes: 2, sessionType: "Test")
        let secondStartDate = engine.startDate

        // Second start should have reset
        XCTAssertNotEqual(firstStartDate, secondStartDate)

        // Duration should reflect the second start
        let totalDuration = engine.endDate!.timeIntervalSince(engine.startDate!)
        XCTAssertEqual(totalDuration, 5 * 60, accuracy: 0.1, "Should be 5 minutes (3+2)")
    }

    // MARK: - TryStart Tests

    @MainActor
    func testTryStartSucceedsWhenIdle() {
        let result = engine.tryStart(phase1Minutes: 5, phase2Minutes: 3)

        if case .started = result {
            XCTAssertTrue(true, "TryStart should succeed when idle")
        } else {
            XCTFail("Expected .started, got \(result)")
        }

        // Verify it actually started
        XCTAssertNotEqual(engine.state, .idle)
    }

    @MainActor
    func testTryStartFailsWhenAlreadyRunning() {
        // Start normally first
        engine.start(phase1Minutes: 5, phase2Minutes: 3, sessionType: "Test")

        // Try to start again
        let result = engine.tryStart(phase1Minutes: 2, phase2Minutes: 1)

        if case .alreadyRunning = result {
            XCTAssertTrue(true, "TryStart should fail when already running")
        } else {
            XCTFail("Expected .alreadyRunning, got \(result)")
        }
    }

    // MARK: - Phase Transition Tests

    func testPhase1ToPhase2Transition() {
        // Start with very short phase 1 (1 second) and longer phase 2
        engine.start(phase1Minutes: 0, phase2Minutes: 1, sessionType: "Test")

        // Manually set dates to simulate being at the transition point
        let now = Date()
        engine.phase1EndDate = now.addingTimeInterval(-0.1) // Phase 1 just ended
        engine.endDate = now.addingTimeInterval(60) // 60 seconds remaining in phase 2

        let expectation = XCTestExpectation(description: "Transitions to phase2")

        engine.$state
            .sink { state in
                if case .phase2(let remaining) = state {
                    XCTAssertGreaterThan(remaining, 0, "Phase 2 should have time remaining")
                    XCTAssertLessThanOrEqual(remaining, 60, "Phase 2 should have ≤60 seconds")
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testPhase2ToFinishedTransition() {
        engine.start(phase1Minutes: 0, phase2Minutes: 0, sessionType: "Test")

        let expectation = XCTestExpectation(description: "Transitions to finished")

        engine.$state
            .sink { state in
                if state == .finished {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Time Calculation Tests

    func testRemainingTimeAccuracy() {
        engine.start(phase1Minutes: 1, phase2Minutes: 1, sessionType: "Test")

        // Check initial remaining time
        if case .phase1(let remaining) = engine.state {
            XCTAssertEqual(remaining, 60, accuracy: 2, "Should start with ~60 seconds in phase 1")
        } else {
            XCTFail("Should be in phase 1")
        }
    }

    func testZeroRemainingTimeHandling() {
        // Create engine with phases already completed
        engine.start(phase1Minutes: 0, phase2Minutes: 0, sessionType: "Test")

        // Manually set dates to past
        engine.endDate = Date().addingTimeInterval(-10)
        engine.phase1EndDate = Date().addingTimeInterval(-15)

        // Wait for state update
        let expectation = XCTestExpectation(description: "Updates to finished")

        engine.$state
            .dropFirst()
            .sink { state in
                if state == .finished {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Edge Case Tests

    func testStartCancelStartSequence() {
        // Start
        engine.start(phase1Minutes: 5, phase2Minutes: 3, sessionType: "Test")
        XCTAssertNotEqual(engine.state, .idle)

        // Cancel
        engine.cancel()
        XCTAssertEqual(engine.state, .idle)

        // Start again
        engine.start(phase1Minutes: 2, phase2Minutes: 1, sessionType: "Test")
        XCTAssertNotEqual(engine.state, .idle)
        XCTAssertNotNil(engine.startDate)
    }

    func testLargeMinuteValues() {
        engine.start(phase1Minutes: 1000, phase2Minutes: 2000, sessionType: "Test")

        let totalDuration = engine.endDate!.timeIntervalSince(engine.startDate!)
        XCTAssertEqual(totalDuration, 3000 * 60, accuracy: 0.1)
    }

    // MARK: - State Equality Tests

    func testStateEquality() {
        XCTAssertEqual(TwoPhaseTimerEngine.State.idle, .idle)
        XCTAssertEqual(TwoPhaseTimerEngine.State.phase1(remaining: 60), .phase1(remaining: 60))
        XCTAssertEqual(TwoPhaseTimerEngine.State.phase2(remaining: 30), .phase2(remaining: 30))
        XCTAssertEqual(TwoPhaseTimerEngine.State.finished, .finished)

        XCTAssertNotEqual(TwoPhaseTimerEngine.State.idle, .finished)
        XCTAssertNotEqual(TwoPhaseTimerEngine.State.phase1(remaining: 60), .phase1(remaining: 59))
    }
}
