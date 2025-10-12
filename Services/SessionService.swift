import Foundation

// SessionService - serializes ActivityKit calls and coordinates session lifecycle
@MainActor
final class SessionService {
    static let shared = SessionService()

    // in-memory store for active sessions
    private var sessions: [UUID: SessionEntry] = [:]
    // LiveActivityController is created on demand inside async flows to avoid
    // compile-order issues during incremental builds.

    private init() {
        DebugLog.debug("SessionService initialized", category: "SESSION-SVC")
    }

    func start(spec: SessionSpec) -> SessionHandle {
    DebugLog.debug("start called for spec: \(spec.sessionUUID.uuidString)", category: "SESSION-SVC")
        let handle = SessionHandle(sessionUUID: spec.sessionUUID, spec: spec)
        sessions[spec.sessionUUID] = SessionEntry(spec: spec, handle: handle)

        // enqueue work to request Live Activity serially
        Task { await self.processStart(for: spec.sessionUUID) }
        return handle
    }

    private func processStart(for uuid: UUID) async {
        guard let entry = sessions[uuid] else { return }
    DebugLog.debug("processing start for \(uuid.uuidString)", category: "SESSION-SVC")

    // Build a human title from spec if available
    let title = entry.spec.presetName.isEmpty ? "Meditation" : entry.spec.presetName
    let phase = 1
    let endDate = entry.spec.endDate

        // Try requestStart with a small retry and conflict handling
        var lastError: Error?
        for attempt in 1...3 {
            if Task.isCancelled { return }
            DebugLog.debug("attempt=\(attempt) requestStart for \(uuid.uuidString) owner=\(entry.spec.ownerId) title=\(title)", category: "SESSION-SVC")
            // instantiate controller on demand (MainActor)
            let controller = LiveActivityController()
            let result = controller.requestStart(title: title, phase: phase, endDate: endDate, ownerId: entry.spec.ownerId)
            switch result {
            case .started:
                DebugLog.info("requestStart -> started for \(uuid.uuidString) owner=\(entry.spec.ownerId)", category: "SESSION-SVC")
                entry.handle.setRunning()
                return
            case .conflict(let existingOwnerId, let existingTitle):
                DebugLog.debug("requestStart -> conflict existingOwner=\(existingOwnerId) title=\(existingTitle) — forcing start", category: "SESSION-SVC")
                // deterministically force a start (ends previous then starts)
                controller.forceStart(title: title, phase: phase, endDate: endDate, ownerId: entry.spec.ownerId)
                // assume forceStart will start quickly — mark running and return
                entry.handle.setRunning()
                return
            case .failed(let err):
                lastError = err
                DebugLog.debug("requestStart attempt=\(attempt) failed: \(String(describing: err))", category: "SESSION-SVC")
                // backoff a bit before retrying
                try? await Task.sleep(nanoseconds: UInt64(150_000_000 * UInt64(attempt)))
            }
        }

        // if we get here, all attempts failed
        if let err = lastError {
            DebugLog.error("start ultimately failed for \(uuid.uuidString): \(String(describing: err))", category: "SESSION-SVC")
            entry.handle.setFailed("LiveActivity start failed: \(err.localizedDescription)")
            // keep session in store so UI can inspect failure; caller may call end()
        } else {
            DebugLog.error("start ultimately failed (unknown) for \(uuid.uuidString)", category: "SESSION-SVC")
            entry.handle.setFailed("LiveActivity start failed")
        }
    }

    func update(sessionUUID: UUID, phase: Int, endDate: Date) {
        DebugLog.debug("update session=\(sessionUUID.uuidString) phase=\(phase)", category: "SESSION-SVC")
        Task { @MainActor in
            let controller = LiveActivityController()
            await controller.update(phase: phase, endDate: endDate)
            if let entry = self.sessions[sessionUUID] {
                // Best-effort update local handle state
                entry.handle.setPhase(phase: phase, remaining: Int(endDate.timeIntervalSinceNow))
            }
        }
    }

    func end(sessionUUID: UUID, immediate: Bool) async {
        DebugLog.debug("end called session=\(sessionUUID.uuidString) immediate=\(immediate)", category: "SESSION-SVC")
        // forward to LiveActivityController (on MainActor)
        let controller = LiveActivityController()
        await controller.end(immediate: immediate)
        sessions[sessionUUID]?.handle.setFinished()
        sessions.removeValue(forKey: sessionUUID)
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
