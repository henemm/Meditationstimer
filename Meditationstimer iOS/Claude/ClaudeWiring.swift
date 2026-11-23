import Foundation

/// Schalter und Dienstadresse der Claude-Verbindung (#57 Schnitt 1). Nichts in der App ruft das bisher auf.
enum ClaudeWiring {
    static let fallbackURL = URL(string: "https://habits.henemm.com")!

    #if DEBUG
    static let debugBuild = true
    #else
    static let debugBuild = false
    #endif

    /// An im Debug-Bau und unter `enable-testing`; sonst nur bei einem echten Bool `true` unter `HHClaudeEnabled`.
    static func isEnabled(info: [String: Any]?, arguments: [String], debugBuild: Bool = ClaudeWiring.debugBuild) -> Bool {
        if debugBuild || arguments.contains("enable-testing") { return true }
        guard let number = info?["HHClaudeEnabled"] as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else {
            return false
        }
        return number.boolValue
    }

    /// `HHServiceURL`: https mit Host; http nur zu localhost/127.0.0.1 und nur bei `allowsLocalHTTP`. Sonst die Vorgabe.
    static func serviceURL(info: [String: Any]?, allowsLocalHTTP: Bool = ClaudeWiring.debugBuild) -> URL {
        guard let text = info?["HHServiceURL"] as? String,
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              let host = url.host(), !host.isEmpty else {
            return fallbackURL
        }
        switch scheme {
        case "https": return url
        case "http" where allowsLocalHTTP && ["localhost", "127.0.0.1"].contains(host.lowercased()): return url
        default: return fallbackURL
        }
    }
}
