import Foundation
import SwiftUI
import os

public struct SessionSpec: Equatable {
    public enum Kind { case atem, offen, workout }
    public let kind: Kind
    public let presetId: UUID?
    public let presetName: String
    public let ownerId: String
    public let startDate: Date
    public let endDate: Date
    public let sessionUUID: UUID

    public init(kind: Kind, presetId: UUID? = nil, presetName: String = "", ownerId: String = "", startDate: Date = Date(), endDate: Date = Date(), sessionUUID: UUID = UUID()) {
        self.kind = kind
        self.presetId = presetId
        self.presetName = presetName
        self.ownerId = ownerId
        self.startDate = startDate
        self.endDate = endDate
        self.sessionUUID = sessionUUID
    }
}

public enum SessionState: Equatable {
    case idle
    case running(phase: Int, remaining: Int)
    case finished
    case failed(String)
}

@MainActor
public final class SessionHandle: ObservableObject {
    @Published public private(set) var state: SessionState = .idle
    public let sessionUUID: UUID
    public let spec: SessionSpec
    private let logger = Logger(subsystem: "henemm.Meditationstimer", category: "SESSION-SVC")

    init(sessionUUID: UUID, spec: SessionSpec) {
        self.sessionUUID = sessionUUID
        self.spec = spec
        logger.debug("SessionHandle created \(sessionUUID.uuidString, privacy: .public)")
    }

    public func end(immediate: Bool) {
        logger.debug("SessionHandle end called immediate=\(immediate)")
        Task { await SessionService.shared.end(sessionUUID: sessionUUID, immediate: immediate) }
    }

    fileprivate func setRunning() {
        logger.debug("SessionHandle setRunning")
        state = .running(phase: 1, remaining: 0)
    }

    fileprivate func setFinished() {
        logger.debug("SessionHandle setFinished")
        state = .finished
    }
}
