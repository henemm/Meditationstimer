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
