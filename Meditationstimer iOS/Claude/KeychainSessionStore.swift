import Foundation
import Security

/// Die vier Schlüsselbund-Aufrufe; in Tests ersetzt.
protocol KeychainOperations: Sendable {
    func add(_ attributes: [String: Any]) -> OSStatus
    func copyMatching(_ query: [String: Any]) -> (OSStatus, Data?)
    func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus
    func delete(_ query: [String: Any]) -> OSStatus
}

/// Der echte Schlüsselbund: nur die `SecItem*`-Aufrufe, keine Logik.
struct SystemKeychain: KeychainOperations {
    func add(_ attributes: [String: Any]) -> OSStatus { SecItemAdd(attributes as CFDictionary, nil) }

    func copyMatching(_ query: [String: Any]) -> (OSStatus, Data?) {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return (status, result as? Data)
    }

    func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus {
        SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    }

    func delete(_ query: [String: Any]) -> OSStatus { SecItemDelete(query as CFDictionary) }
}

/// Abfragen eines Eintrags: generisches Passwort, nur dieses Gerät, nie synchronisiert, Datenschutz-Schlüsselbund.
struct KeychainEntry {
    let service: String
    let account: String

    var base: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    var read: [String: Any] {
        base.merging([kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]) { _, new in new }
    }

    func add(_ data: Data) -> [String: Any] {
        base.merging([
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]) { _, new in new }
    }
}

/// Die Sitzung im Schlüsselbund, nie in `UserDefaults`.
struct KeychainSessionStore: SessionStoring {
    static let entry = KeychainEntry(service: "henemm.Meditationstimer-iOS.claude.session", account: "session")

    let operations: any KeychainOperations

    init(operations: any KeychainOperations = SystemKeychain()) {
        self.operations = operations
    }

    /// Bei Duplikat nur den Wert aktualisieren, nie vorher löschen; Update ohne Treffer ist ein Fehler, kein Retry.
    func save(_ token: String) throws {
        let data = Data(token.utf8)
        let status = operations.add(Self.entry.add(data))
        guard status == errSecDuplicateItem else { return try Self.check(status) }
        try Self.check(operations.update(Self.entry.base, [kSecValueData as String: data]))
    }

    func load() throws -> String? {
        let (status, data) = operations.copyMatching(Self.entry.read)
        if status == errSecItemNotFound { return nil }
        try Self.check(status)
        guard let data, !data.isEmpty, let token = String(data: data, encoding: .utf8) else {
            throw SessionStoreError.corruptData
        }
        return token
    }

    func clear() throws {
        let status = operations.delete(Self.entry.base)
        if status == errSecItemNotFound { return }
        try Self.check(status)
    }

    /// Jeder Status außer Erfolg ist ein Fehler, auch -34018: nie still "abgemeldet".
    private static func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else { throw SessionStoreError.keychain(status) }
    }
}
