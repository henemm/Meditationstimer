import Foundation
import os

/// Watch-target copy of DebugLog to ensure the Watch App can compile when the shared Services
/// file isn't included in the Watch target. Keeps behaviour identical for DEBUG builds.
struct DebugLog {
    static let subsystem = "henemm.Meditationstimer"

    private static func logger(category: String) -> Logger {
        return Logger(subsystem: subsystem, category: category)
    }

    static var consoleEnabled: Bool {
        #if DEBUG
        return true
        #else
        return ProcessInfo.processInfo.environment["TIMER_DEBUG_CONSOLE"] == "1"
        #endif
    }

    private static func timestamp() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: Date())
    }

    static func debug(_ message: String, category: String = "GENERAL") {
        let l = logger(category: category)
        l.debug("\(message, privacy: .public)")
        if consoleEnabled { print("[DEBUG][\(category)] \(timestamp()) \(message)") }
    }

    static func info(_ message: String, category: String = "GENERAL") {
        let l = logger(category: category)
        l.info("\(message, privacy: .public)")
        if consoleEnabled { print("[INFO][\(category)] \(timestamp()) \(message)") }
    }

    static func error(_ message: String, category: String = "GENERAL") {
        let l = logger(category: category)
        l.error("\(message, privacy: .public)")
        if consoleEnabled { print("[ERROR][\(category)] \(timestamp()) \(message)") }
    }

    static func fault(_ message: String, category: String = "GENERAL") {
        let l = logger(category: category)
        l.fault("\(message, privacy: .public)")
        if consoleEnabled { print("[FAULT][\(category)] \(timestamp()) \(message)") }
    }
}
