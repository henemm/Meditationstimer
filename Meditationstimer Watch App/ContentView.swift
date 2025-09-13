import SwiftUI
import WatchKit
import WatchConnectivity
import HealthKit

struct ContentView: View {
    // Letzte Werte merken
    @AppStorage("phase1Minutes") private var phase1Minutes: Int = 15
    @AppStorage("phase2Minutes") private var phase2Minutes: Int = 3

    // Services
    private let hk = HealthKitManager()
    private let runtime = RuntimeSessionHelper()
    private let notifier = NotificationHelper()
    @StateObject private var engine = TwoPhaseTimerEngine()
    @StateObject private var hrStream = HeartRateStream()

    // UI
    @State private var showingError: String?
    @State private var askedPermissions = false
    @State private var lastState: TwoPhaseTimerEngine.State = .idle
    @State private var showHRList = false

    var body: some View {
        VStack(spacing: 10) {
            switch engine.state {
            case .idle:
                // Einstell-UI
                pickerSection
                Button("Start") { startSession() }
                    .buttonStyle(.borderedProminent)

            case .finished:
                // Nach Ende: normale Start-UI + optional HR-Liste
                pickerSection
                Button("Start") { startSession() }
                    .buttonStyle(.borderedProminent)
                if !hrStream.samples.isEmpty {
                    Button("Herzfrequenz anzeigen") { showHRList = true }
                        .buttonStyle(.bordered)
                }

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
        .onChange(of: engine.state) { old, new in
            // Übergang Phase1 -> Phase2: spürbare Haptik, wenn App sichtbar
            if case .phase1 = old, case .phase2 = new {
                playStrongHaptic()
                hrStream.stop()
            }

            // Natürliches Ende
            if new == .finished {
                hrStream.stop()
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
        .sheet(isPresented: $showHRList) {
            HeartRateListView(samples: hrStream.samples)
        }
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
                    title: "Meditation – fertig",
                    body: "Sitzung abgeschlossen.",
                    identifier: "phase2-end"
                )
            } catch {
                showingError = "Konnte Benachrichtigung nicht planen: \(error.localizedDescription)"
            }
        }

        // 3) Engine starten (nur UI-Anzeige)
        engine.start(phase1Minutes: phase1Minutes, phase2Minutes: phase2Minutes)
        if let start = engine.startDate {
            hrStream.start(from: start)
        }
        lastState = .phase1(remaining: phase1Minutes * 60)
    }

    private func cancelSession() {
        Task { await notifier.cancelAll() }
        // Beim Abbruch IMMER loggen — nur Phase 1 bzw. bisherige Phase-1-Zeit
        Task { await logPhase1OnCancel() }
        hrStream.stop()
        runtime.stop()
        engine.cancel()
        lastState = .idle
    }

    /// Natürliches Ende: nur Phase 1 wird geloggt.
    private func finishSessionLogPhase1Only() {
        Task {
            hrStream.stop()
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

    // Sendet Start/Ende an die iPhone‑App; dort wird in HealthKit gespeichert.
    private func sendMindfulToPhone(start: Date, end: Date) {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        if s.activationState != .activated { s.activate() }
        let payload: [String: Any] = [
            "start": start.timeIntervalSince1970,
            "end":   end.timeIntervalSince1970
        ]
        if s.isReachable {
            s.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            s.transferUserInfo(payload) // wird nachgereicht, sobald erreichbar
        }
    }

    private func playStrongHaptic() {
        // System-Haptik: längere, deutlichere 5-Impuls-Sequenz (~1.6s)
        let device = WKInterfaceDevice.current()
        let pattern: [(WKHapticType, TimeInterval)] = [
            (.notification, 0.0),
            (.success,      0.4),
            (.success,      0.8),
            (.success,      1.2),
            (.success,      1.6)
        ]
        for (type, delay) in pattern {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                device.play(type)
            }
        }
    }

    private func format(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Heart Rate List

private struct HeartRateListView: View {
    let samples: [HKQuantitySample]

    private let bpmUnit = HKUnit.count().unitDivided(by: .minute())

    var body: some View {
        List {
            if samples.isEmpty {
                Text("Keine Herzfrequenzmessungen erfasst.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(samples.sorted(by: { $0.startDate < $1.startDate }), id: \.uuid) { s in
                    let bpm = s.quantity.doubleValue(for: bpmUnit)
                    HStack {
                        Text("\(Int(round(bpm))) BPM")
                            .font(.body.monospacedDigit())
                        Spacer()
                        Text(timeString(s.startDate))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Herzfrequenz")
    }

    private func timeString(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df.string(from: date)
    }
}
