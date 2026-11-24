import Foundation
import OSLog

/// Abgleich mit dem Claude-Dienst (#57 Schnitt 4): Lieferungen abholen, anwenden, melden, danach die Abschrift senden.
/// Jeder Fehler beendet den Durchlauf still; der nächste Auslöser ist die Wiederholung. Nie Token oder Körper im Log.
@MainActor final class ClaudeSync {
    enum Ending: Equatable, Sendable { case notSignedIn, busy, done, stopped }

    static let maxDeliveriesPerPass = 15
    static let lastSnapshotKey = "claudeLastSnapshotAt"
    private static let logger = Logger(subsystem: "com.henemm.Meditationstimer", category: "claude-sync")

    private let account: AccountState
    private let client: ServiceClient
    private let defaults: UserDefaults
    private let device: () throws -> UUID
    private let clock: () -> Date
    private var running = false

    init(account: AccountState, client: ServiceClient, defaults: UserDefaults = .standard,
         device: @escaping () throws -> UUID, clock: @escaping () -> Date = Date.init) {
        self.account = account
        self.client = client
        self.defaults = defaults
        self.device = device
        self.clock = clock
    }

    /// Zeitpunkt der zuletzt erfolgreich gesendeten Abschrift.
    var lastSnapshotAt: Date? { defaults.object(forKey: Self.lastSnapshotKey) as? Date }

    /// Unter Tests (Startargument oder Test-Host) läuft kein Abgleich.
    nonisolated static func isSilent(arguments: [String], environment: [String: String]) -> Bool {
        arguments.contains("enable-testing") || environment["XCTestConfigurationFilePath"] != nil
    }

    func run() async -> Ending {
        guard !running else { return .busy }
        running = true
        defer { running = false }
        do {
            return try await account.withSession { try await self.pass(token: $0) } ?? .notSignedIn
        } catch {
            Self.logger.info("sync stopped: \((error as? ServiceError).map { String(describing: $0) } ?? String(describing: type(of: error)), privacy: .public)")
            return .stopped
        }
    }

    private func pass(token: String) async throws -> Ending {
        let deviceId = try device()
        let snapshot = lastSnapshotAt
        for _ in 0..<Self.maxDeliveriesPerPass {
            guard let claimed = try await client.claimDelivery(token: token, device: deviceId) else { break }
            let body = Self.resultBody(deliveryId: claimed.deliveryId, result: apply(claimed.delivery, snapshot))
            do {
                try await client.reportResult(token: token, device: deviceId, body: body)
            } catch ServiceError.rejected(409) {
                continue
            }
        }
        let now = clock()
        let input = TranscriptBuilder.readCurrent(defaults: defaults)
        guard !input.unreadable else { return .done }
        let transcript = TranscriptBuilder.build(sets: input.sets, presets: input.presets,
                                                 claudeExercises: input.claudeExercises, log: input.log, now: now)
        try await client.sendTranscript(token: token, data: transcript)
        defaults.set(now, forKey: Self.lastSnapshotKey)
        return .done
    }

    private func apply(_ raw: Data, _ snapshot: Date?) -> ClaudeApplyResult {
        do {
            return ClaudeStore.apply(try ClaudeDelivery.read(raw), in: defaults, lastSnapshotAt: snapshot)
        } catch {
            return .rejected(code: error.code, reason: error.reason)
        }
    }

    /// Körper für `/app/deliveries/result` (Form: `server/src/app-routes.ts`, Längen in UTF-16-Einheiten).
    nonisolated static func resultBody(deliveryId: String, result: ClaudeApplyResult) -> Data {
        var body: [String: Any] = ["deliveryId": deliveryId, "outcome": "accepted"]
        if case .rejected(let code, let reason) = result {
            body["outcome"] = "rejected"
            body["errors"] = [["code": clamp(code, 100, "unknown"), "path": "",
                               "message": clamp(reason, 300, "no reason given")]]
        }
        return (try? JSONSerialization.data(withJSONObject: body)) ?? Data("{}".utf8)
    }

    /// Kürzt an Zeichengrenzen auf höchstens `limit` UTF-16-Einheiten; leer ergibt `fallback`.
    private nonisolated static func clamp(_ text: String, _ limit: Int, _ fallback: String) -> String {
        var out = "", units = 0
        for character in text {
            units += character.utf16.count
            if units > limit { break }
            out.append(character)
        }
        return out.isEmpty ? fallback : out
    }
}
