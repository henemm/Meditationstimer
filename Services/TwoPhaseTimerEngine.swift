// MARK: - AI ORIENTATION (Read me first)
// Purpose:
//   TwoPhaseTimerEngine is the core timer state machine for the OffenView meditation timer.
//   Manages countdown logic for two sequential phases with precise time tracking.
//   Designed for foreground-only operation to avoid iOS background execution limits.
//
// Architecture Decision:
//   • Foreground-only timer prevents iOS from killing background execution
//   • Uses Combine + Timer.publish for reactive UI updates
//   • Date-based calculations ensure accuracy even with app interruptions
//   • State machine pattern with clear phase transitions
//
// State Flow:
//   .idle → .phase1(remaining) → .phase2(remaining) → .finished → .idle
//
// Integration Points:
//   • OffenView: Primary consumer, drives UI updates and Live Activity
//   • Watch App: Uses same engine for consistent behavior across platforms
//   • Live Activity: Reads startDate, phase1EndDate, endDate for precise timing
//
// Technical Implementation:
//   • Timer.publish(every: 1) for UI refresh rate
//   • Date arithmetic for remaining time calculations
//   • Automatic cleanup when reaching .finished state
//   • Weak self references prevent retain cycles
//
// Usage Pattern:
//   1. Call start(phase1Minutes:, phase2Minutes:) to begin
//   2. Observe @Published state for UI updates
//   3. Use date properties for external systems (Live Activity, notifications)
//   4. Call cancel() for early termination

import Foundation
import Combine

/// Einfache 2-Phasen-Engine für die UI-Anzeige.
/// Verlasst sich NICHT auf Hintergrund-Timer; weckt die UI nur im Vordergrund.
final class TwoPhaseTimerEngine: ObservableObject {

    enum State: Equatable {
        case idle
        case phase1(remaining: Int) // Sekunden
        case phase2(remaining: Int) // Sekunden
        case finished
    }

    @Published private(set) var state: State = .idle

    private var ticker: AnyCancellable?
    private var phase1Length: Int = 0
    private var phase2Length: Int = 0

    private(set) var startDate: Date?
    private(set) var phase1EndDate: Date?
    private(set) var endDate: Date?

    func start(phase1Minutes: Int, phase2Minutes: Int) {
        cancel()

        phase1Length = max(0, phase1Minutes) * 60
        phase2Length = max(0, phase2Minutes) * 60

        let now = Date()
        startDate = now
        phase1EndDate = now.addingTimeInterval(TimeInterval(phase1Length))
        endDate = phase1EndDate!.addingTimeInterval(TimeInterval(phase2Length))

        // Sofort initialen Zustand setzen
        updateState(at: now)

        // Ticker nur für UI im Vordergrund
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] t in
                self?.updateState(at: t)
            }
    }

    func cancel() {
        ticker?.cancel()
        ticker = nil
        startDate = nil
        phase1EndDate = nil
        endDate = nil
        state = .idle
    }

    // MARK: - Helpers

    private func updateState(at now: Date) {
        guard let start = startDate,
              let p1End = phase1EndDate,
              let end = endDate else {
            state = .idle
            return
        }

        if now < p1End {
            let remaining = Int(p1End.timeIntervalSince(now).rounded(.up))
            state = .phase1(remaining: max(0, remaining))
        } else if now < end {
            let remaining = Int(end.timeIntervalSince(now).rounded(.up))
            state = .phase2(remaining: max(0, remaining))
        } else {
            state = .finished
            ticker?.cancel()
            ticker = nil
        }
    }
}
