private func playStrongHaptic() {
    // Hinweis: watchOS lässt die Intensität nicht direkt steuern.
    // Wir simulieren "stärker/länger", indem wir eine kurze Sequenz abspielen.
    let device = WKInterfaceDevice.current()
    device.play(.notification) // Start-Impuls
    let intervals: [TimeInterval] = [0.35, 0.70] // zwei Nachklänge
    for delay in intervals {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            device.play(.success)
        }
    }
}

import SwiftUI
import WatchKit

struct ContentView: View {
    // Letzte Werte merken
    @AppStorage("phase1Minutes") private var phase1Minutes: Int = 15
    @AppStorage("phase2Minutes") private var phase2Minutes: Int = 3

    // Services
    private let hk = HealthKitManager()
    private let runtime = RuntimeSessionHelper()
    private let notifier = NotificationHelper()
    @StateObject private var engine = TwoPhaseTimerEngine()

    // UI
    @State private var showingError: String?
    @State private var askedPermissions = false
    @State private var lastState: TwoPhaseTimerEngine.State = .idle

    var body: some View {
        VStack(spacing: 10) {
            switch engine.state {
            case .idle, .finished:
                // Einstell-UI
                pickerSection

                Button("Start") { startSession() }
                    .buttonStyle(.borderedProminent)

            case .phase1(let remaining):
                phaseView(title: "Meditation", remaining: remaining)
                Button("Abbrechen", role: .destructive) { cancelSession() }

            case .phase2(let remaining):
                phaseView(title: "Besinnung", remaining: remaining)
                Button("Abbrechen", role: .destructive) { cancelSession() }
            }
        }
        .padding()
        .onAppear {
            // Berechtigungen einmalig anfragen
            if !askedPermissions {
                askedPermissions = true
                Task {
                    do {
                        try await notifier.requestAuthorization()
                        try await hk.requestAuthorization()
                    } catch {
                        // Nicht blockieren – nur Hinweis
                        showingError = "Berechtigungen eingeschränkt: \(error.localizedDescription)"
                    }
                }
            }
        }
        // Reagiere auf Zustandswechsel (für Haptik & Logik)
        .onChange(of: engine.state) { new in
            // Übergang Phase1 -> Phase2: spürbare Haptik, wenn App sichtbar
            if case .phase1 = lastState, case .phase2 = new {
                playStrongHaptic()
            }

            // Natürliches Ende
            if new == .finished {
                playStrongHaptic()
                finishSessionLogPhase1Only()
            }

            lastState = new
        }
        .alert("Hinweis", isPresented: .constant(showingError != nil), actions: {
            Button("OK") { showingError = nil }
        }, message: {
            Text(showingError ?? "")
        })
    }

    // MARK: - Subviews

    private var pickerSection: some View {
        VStack {
            HStack {
                Text("Meditation")
                Spacer()
                Picker("Meditation (min)", selection: $phase1Minutes) {
                    ForEach(0..<61) { Text("\($0)") }
                }
                .frame(width: 60)
                .labelsHidden()
                .pickerStyle(.wheel)
            }
            HStack {
                Text("Besinnung")
                Spacer()
                Picker("Besinnung (min)", selection: $phase2Minutes) {
                    ForEach(0..<61) { Text("\($0)") }
                }
                .frame(width: 60)
                .labelsHidden()
                .pickerStyle(.wheel)
            }
        }
    }

    private func phaseView(title: String, remaining: Int) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.headline)
            Text(format(remaining))
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
    }

    // MARK: - Actions

    private func startSession() {
        // 1) Extended Runtime (für ≤ 30 min sehr sinnvoll)
        runtime.start(
            onDidExpire: { /* optional: Hinweis anzeigen */ },
            onInvalidation: { _ in /* optional */ }
        )

        // 2) Notifications planen (Ende Phase 1 und Phase 2)
        let p1 = TimeInterval(max(0, phase1Minutes) * 60)
        let total = TimeInterval(max(0, phase1Minutes + phase2Minutes) * 60)

        Task {
            do {
                try await notifier.schedulePhaseEndNotification(
                    in: p1,
                    title: "Meditation – Phase 1 beendet",
                    body: "Weiter mit Besinnung.",
                    identifier: "phase1-end"
                )
                try await notifier.schedulePhaseEndNotification(
                    in: total,
                    title: "Medititation – fertig",
                    body: "Sitzung abgeschlossen.",
                    identifier: "phase2-end"
                )
            } catch {
                showingError = "Konnte Benachrichtigung nicht planen: \(error.localizedDescription)"
            }
        }

        // 3) Engine starten (nur UI-Anzeige)
        engine.start(phase1Minutes: phase1Minutes, phase2Minutes: phase2Minutes)
        lastState = .phase1(remaining: phase1Minutes * 60)
    }

    private func cancelSession() {
        Task { await notifier.cancelAll() }
        // Beim Abbruch IMMER loggen — nur Phase 1 bzw. bisherige Phase-1-Zeit
        Task { await logPhase1OnCancel() }
        runtime.stop()
        engine.cancel()
        lastState = .idle
    }

    /// Natürliches Ende: nur Phase 1 wird geloggt.
    private func finishSessionLogPhase1Only() {
        Task {
            await notifier.cancelAll()
            if let start = engine.startDate,
               let p1End = engine.phase1EndDate,
               p1End > start {
                do {
                    try await hk.logMindfulness(start: start, end: p1End)
                } catch {
                    showingError = "Health-Logging fehlgeschlagen: \(error.localizedDescription)"
                }
            }
            runtime.stop()
        }
    }

    /// Abbruch: in Phase 1 bis „jetzt“ loggen, in Phase 2 bis Ende Phase 1 loggen.
    private func logPhase1OnCancel() async {
        guard let start = engine.startDate else { return }
        let now = Date()

        let endForLogging: Date
        if let p1End = engine.phase1EndDate {
            endForLogging = min(now, p1End)
        } else {
            endForLogging = now
        }

        if endForLogging > start {
            do {
                try await hk.logMindfulness(start: start, end: endForLogging)
            } catch {
                showingError = "Health-Logging fehlgeschlagen: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Helpers

    private func playStrongHaptic() {
        // System-Haptik ist limitiert; wir simulieren "stärker/länger" mit einer kurzen Sequenz.
        let device = WKInterfaceDevice.current()
        device.play(.notification) // Start-Impuls
        let intervals: [TimeInterval] = [0.35, 0.70] // zwei Nachklänge
        for delay in intervals {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                device.play(.success)
            }
        }
    }

    private func format(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
