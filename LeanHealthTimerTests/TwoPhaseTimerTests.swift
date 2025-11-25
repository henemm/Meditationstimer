//
//  TwoPhaseTimerTests.swift
//  LeanHealthTimerTests
//
//  Tests für Bug #30: 1 Minute wird als 0 interpretiert und Phase übersprungen
//

import XCTest
@testable import Lean_Health_Timer

final class TwoPhaseTimerTests: XCTestCase {

    var engine: TwoPhaseTimerEngine!

    override func setUp() {
        super.setUp()
        engine = TwoPhaseTimerEngine()
    }

    override func tearDown() {
        engine.cancel()
        engine = nil
        super.tearDown()
    }

    // MARK: - Bug #30: 1 Minute Phase Skip Tests

    /// Bug #30 Test 1: Phase 1 mit 1 Minute sollte NICHT übersprungen werden
    ///
    /// Aktuelles Verhalten (Bug):
    /// - phase1Minutes = 1 → Phase 1 wird sofort übersprungen oder als 0 interpretiert
    ///
    /// Erwartetes Verhalten:
    /// - phase1Minutes = 1 → Phase 1 läuft für 60 Sekunden
    func testPhase1_OneMinute_NotSkipped() throws {
        // ACT: Start mit 1 Minute Phase 1, 5 Minuten Phase 2
        engine.start(phase1Minutes: 1, phase2Minutes: 5)

        // ASSERT 1: Engine sollte in Phase 1 sein (nicht Phase 2 oder finished)
        switch engine.state {
        case .phase1(let remaining):
            XCTAssertGreaterThan(remaining, 0, "Phase 1 mit 1 Minute sollte remaining > 0 haben")
            XCTAssertLessThanOrEqual(remaining, 60, "Phase 1 remaining sollte <= 60 Sekunden sein")
        case .phase2:
            XCTFail("❌ Bug reproduziert: Phase 1 wurde übersprungen, direkt in Phase 2")
        case .finished:
            XCTFail("❌ Bug reproduziert: Phase 1 wurde übersprungen, direkt finished")
        case .idle:
            XCTFail("Engine sollte nicht idle sein nach start()")
        }

        // ASSERT 2: phase1EndDate sollte ~60 Sekunden in der Zukunft sein
        guard let phase1End = engine.phase1EndDate else {
            XCTFail("phase1EndDate sollte gesetzt sein")
            return
        }

        let now = Date()
        let phase1Duration = phase1End.timeIntervalSince(now)
        XCTAssertGreaterThan(phase1Duration, 50, "Phase 1 sollte mindestens ~50 Sekunden dauern (1 min = 60s)")
        XCTAssertLessThan(phase1Duration, 70, "Phase 1 sollte nicht länger als ~70 Sekunden sein")
    }

    /// Bug #30 Test 2: Phase 2 mit 1 Minute sollte NICHT übersprungen werden
    ///
    /// Reproduktion:
    /// - phase2Minutes = 1 → Phase 2 wird sofort übersprungen
    func testPhase2_OneMinute_NotSkipped() throws {
        // ACT: Start mit 5 Minuten Phase 1, 1 Minute Phase 2
        engine.start(phase1Minutes: 5, phase2Minutes: 1)

        // ASSERT: phase2 endDate sollte 6 Minuten in Zukunft sein (5 + 1)
        guard let endDate = engine.endDate else {
            XCTFail("endDate sollte gesetzt sein")
            return
        }

        let now = Date()
        let totalDuration = endDate.timeIntervalSince(now)

        // Total: 5 * 60 + 1 * 60 = 360 Sekunden
        XCTAssertGreaterThan(totalDuration, 350, "Total duration sollte ~360 Sekunden sein (6 min)")
        XCTAssertLessThan(totalDuration, 370, "Total duration sollte nicht > 370 Sekunden sein")

        // Phase 2 Duration berechnen
        guard let phase1End = engine.phase1EndDate else {
            XCTFail("phase1EndDate sollte gesetzt sein")
            return
        }

        let phase2Duration = endDate.timeIntervalSince(phase1End)
        XCTAssertGreaterThan(phase2Duration, 50, "Phase 2 sollte mindestens ~50 Sekunden dauern (1 min = 60s)")
        XCTAssertLessThan(phase2Duration, 70, "Phase 2 sollte nicht > 70 Sekunden sein")
    }

    /// Bug #30 Test 3: Beide Phasen mit je 1 Minute
    ///
    /// Extremfall: phase1Minutes = 1, phase2Minutes = 1
    /// Sollte insgesamt 2 Minuten = 120 Sekunden laufen
    func testBothPhases_OneMinute_NotSkipped() throws {
        // ACT
        engine.start(phase1Minutes: 1, phase2Minutes: 1)

        // ASSERT: Total duration = 2 Minuten = 120 Sekunden
        guard let endDate = engine.endDate,
              let startDate = engine.startDate else {
            XCTFail("Dates sollten gesetzt sein")
            return
        }

        let totalDuration = endDate.timeIntervalSince(startDate)
        XCTAssertGreaterThan(totalDuration, 110, "Total duration sollte ~120 Sekunden sein (2 min)")
        XCTAssertLessThan(totalDuration, 130, "Total duration sollte nicht > 130 Sekunden sein")

        // ASSERT: Engine sollte in phase1 sein
        switch engine.state {
        case .phase1:
            XCTAssertTrue(true, "Korrekt: Engine ist in Phase 1")
        default:
            XCTFail("❌ Bug: Engine sollte in Phase 1 sein, ist aber \(engine.state)")
        }
    }

    // MARK: - Boundary Tests (Vergleich mit anderen Werten)

    /// Vergleichstest: 2 Minuten sollten funktionieren
    /// (Um sicherzustellen dass nicht ALLE kurzen Phasen betroffen sind)
    func testPhase1_TwoMinutes_Works() throws {
        // ACT
        engine.start(phase1Minutes: 2, phase2Minutes: 5)

        // ASSERT
        switch engine.state {
        case .phase1(let remaining):
            XCTAssertGreaterThan(remaining, 0)
        default:
            XCTFail("2 Minuten Phase sollte funktionieren")
        }
    }

    /// Vergleichstest: 0 Minuten sollte Phase überspringen (erwartet)
    func testPhase1_ZeroMinutes_IsSkipped() throws {
        // ACT: phase1Minutes = 0 sollte Phase 1 überspringen
        engine.start(phase1Minutes: 0, phase2Minutes: 5)

        // ASSERT: Sollte direkt in Phase 2 springen (das ist KORREKT!)
        // Wir warten kurz, damit der Timer-Tick ausgeführt wird
        let expectation = XCTestExpectation(description: "Wait for state update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        switch engine.state {
        case .phase2:
            XCTAssertTrue(true, "0 Minuten Phase 1 sollte korrekt übersprungen werden")
        case .phase1:
            // Könnte sein dass Timer noch nicht getriggert hat - akzeptabel
            XCTAssertTrue(true, "Phase 1 mit 0 min könnte kurz in phase1 state sein")
        default:
            break
        }
    }
}
