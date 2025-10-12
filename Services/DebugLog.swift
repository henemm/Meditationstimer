import Foundation
import os

/// Lightweight logging wrapper that writes to os.Logger and also prints to stdout
/// when running in DEBUG or when the env var TIMER_DEBUG_CONSOLE=1 is present.
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
