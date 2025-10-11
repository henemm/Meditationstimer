import Foundation
import os

// Skeleton SessionService - serializes ActivityKit calls and coordinates session lifecycle
@MainActor
final class SessionService {
    static let shared = SessionService()
    private let logger = Logger(subsystem: "henemm.Meditationstimer", category: "SESSION-SVC")

    // in-memory store for active sessions
    private var sessions: [UUID: SessionEntry] = [:]

    private init() {
        logger.debug("SessionService initialized")
    }

    func start(spec: SessionSpec) -> SessionHandle {
        logger.debug("start called for spec: \(spec.sessionUUID.uuidString, privacy: .public)")
        let handle = SessionHandle(sessionUUID: spec.sessionUUID, spec: spec)
        sessions[spec.sessionUUID] = SessionEntry(spec: spec, handle: handle)

        // enqueue work to request Live Activity serially
        Task { await self.processStart(for: spec.sessionUUID) }
        return handle
    }

    private func processStart(for uuid: UUID) async {
        guard let entry = sessions[uuid] else { return }
        logger.debug("processing start for \(uuid.uuidString, privacy: .public)")

        // TODO: call LiveActivityController.requestStart serially with retry/backoff
        // For now: simulate immediate success
        entry.handle.setRunning()
    }

    func update(sessionUUID: UUID, phase: Int, endDate: Date) {
        logger.debug("update session=\(sessionUUID.uuidString, privacy: .public) phase=\(phase)")
        // forward to LiveActivityController.update (to be implemented)
    }

    func end(sessionUUID: UUID, immediate: Bool) async {
        logger.debug("end called session=\(sessionUUID.uuidString, privacy: .public) immediate=\(immediate)")
        sessions[sessionUUID]?.handle.setFinished()
        sessions.removeValue(forKey: sessionUUID)
        // forward to LiveActivityController.end (to be implemented)
    }
}

// internal store entry
private final class SessionEntry {
    let spec: SessionSpec
    let handle: SessionHandle
    init(spec: SessionSpec, handle: SessionHandle) {
        self.spec = spec
        self.handle = handle
    }
}
