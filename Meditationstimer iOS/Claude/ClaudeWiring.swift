import Foundation

/// Schalter, Dienstadresse und Konto der Claude-Verbindung (#57). Der App-Struct baut damit sein einziges Konto.
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

    /// Das Konto der App: nil bei ausgeschaltetem Schalter; im Debug-Bau unter `enable-testing` das Stand-in ohne Netz.
    /// Endet eine Sitzung, wird `lastSnapshotAt` gelöscht (danach gilt wieder „erster Lauf“).
    @MainActor static func makeAccount(info: [String: Any]?, arguments: [String], defaults: UserDefaults = .standard,
                                       debugBuild: Bool = ClaudeWiring.debugBuild) -> AccountState? {
        guard isEnabled(info: info, arguments: arguments, debugBuild: debugBuild) else { return nil }
        var client = ServiceClient(baseURL: serviceURL(info: info))
        var store: any SessionStoring = KeychainSessionStore()
        #if DEBUG
        if usesStandIn(arguments: arguments) {
            client = ServiceClient(baseURL: client.baseURL, transport: UITestTransport(arguments: arguments))
            store = InMemorySessionStore()
        }
        #endif
        let account = AccountState(client: client, store: store)
        account.onSessionEnded = { defaults.removeObject(forKey: ClaudeSync.lastSnapshotKey) }
        return account
    }

    /// Stand-in statt Apples Knopf: nur im Debug-Bau unter `enable-testing`.
    static func usesStandIn(arguments: [String]) -> Bool {
        #if DEBUG
        return arguments.contains("enable-testing")
        #else
        return false
        #endif
    }
}

#if DEBUG
/// Dienst-Attrappe für UI-Tests: Anmelden zugelassen, mit `uitest-claude-not-allowed` 401,
/// mit `uitest-claude-retry-later` 503; Abmelden und Trennen 204. Sendet nichts.
struct UITestTransport: HTTPTransport {
    let arguments: [String]

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url ?? ClaudeWiring.fallbackURL
        let (status, body) = url.lastPathComponent == "apple" ? signInReply : (204, Data())
        return (body, HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!)
    }

    private var signInReply: (Int, Data) {
        if arguments.contains("uitest-claude-not-allowed") { return (401, Data()) }
        if arguments.contains("uitest-claude-retry-later") { return (503, Data()) }
        return (200, Data(#"{"sessionToken":"uitest-session"}"#.utf8))
    }
}
#endif
