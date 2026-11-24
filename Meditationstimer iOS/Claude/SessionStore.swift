import Foundation

/// Ablageort der Sitzung des Dienstes. `load` liefert `nil`, wenn nichts gespeichert ist; `clear` ohne Eintrag ist kein Fehler.
protocol SessionStoring: Sendable {
    func load() throws -> String?
    func save(_ token: String) throws
    func clear() throws
}

/// Fehler des Sitzungsspeichers; trägt nie das Token.
enum SessionStoreError: Error, Equatable {
    case keychain(OSStatus)
    case corruptData
    /// Nur für Tests: von `InMemorySessionStore.failNext` eingespeist.
    case injected
}
